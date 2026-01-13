// SeedSphere Portal — Interactive Features

document.addEventListener("DOMContentLoaded", () => {
  // Platform Detection for Auto-Download
  detectPlatform();

  // Smooth Scroll
  setupSmoothScroll();

  // Network Animation
  animateNetwork();

  // Setup Home Login Interactions
  setupHomeLogin();

  // Setup Install Button
  setupInstallButton();
});

/**
 * Initializes the Stremio Addon install/copy buttons.
 * Handles "Launch" (Protocol handler) and "Copy Manifest" actions with auth checks.
 */
function setupInstallButton() {
  const launchBtn = document.getElementById("btn-launch-stremio");
  const copyBtn = document.getElementById("btn-copy-manifest");
  // Determine API Base dynamically (relative path for same-origin)
  const API_BASE = "";

  if (launchBtn) {
    launchBtn.addEventListener("click", async () => {
      // 1. Check Session
      try {
        const res = await fetch(`${API_BASE}/api/auth/session`);
        const data = await res.json();

        if (data.ok && data.user) {
          const userId = data.user.id.split(":").pop() || data.user.id;
          const host = window.location.host;
          const manifestUrl = `stremio://${host}/u/${userId}/manifest.json`;
          window.location.href = manifestUrl;
        } else {
          // Not logged in -> Prompt to Login
          const overlay = document.getElementById("login-overlay");
          if (overlay) {
            overlay.style.display = "flex";
            // Ideally show a message saying "Login to install addon"
          } else {
            alert("Please sign in to install the addon.");
          }
        }
      } catch (e) {
        console.error("Install check failed", e);
      }
    });
  }

  if (copyBtn) {
    copyBtn.addEventListener("click", async () => {
      try {
        const res = await fetch(`${API_BASE}/api/auth/session`);
        const data = await res.json();

        if (data.ok && data.user) {
          const userId = data.user.id.split(":").pop() || data.user.id;
          const host = window.location.host;
          const manifestUrl = `https://${host}/u/${userId}/manifest.json`;

          navigator.clipboard.writeText(manifestUrl);
          const originalText = copyBtn.textContent;
          copyBtn.textContent = "Copied!";
          setTimeout(() => (copyBtn.textContent = originalText), 2000);
        } else {
          const overlay = document.getElementById("login-overlay");
          if (overlay) overlay.style.display = "flex";
        }
      } catch (e) {
        console.error("Copy check failed", e);
      }
    });
  }
}

/**
 * configures the login interactions for the home page (landing).
 * Includes the "Sign In" button overlay and the Magic Link form submission.
 */
function setupHomeLogin() {
  const signInBtn = document.querySelector(
    'a[href="dashboard.html"].btn-primary'
  );
  const overlay = document.getElementById("login-overlay");

  if (signInBtn && overlay) {
    signInBtn.addEventListener("click", (e) => {
      e.preventDefault();
      overlay.style.display = "flex";
    });

    // Click outside to close (Home specific)
    overlay.addEventListener("click", (e) => {
      if (e.target === overlay) {
        overlay.style.display = "none";
      }
    });
  }

  // Magic Link Form Logic (Duplicated from Dashboard for Home context)
  const magicForm = document.getElementById("magic-link-form");
  if (magicForm) {
    magicForm.addEventListener("submit", async (e) => {
      e.preventDefault();
      const email = document.getElementById("magic-email").value;
      const statusFn = document.getElementById("magic-status");

      try {
        statusFn.textContent = "Sending magic link...";
        const res = await fetch(`${API_BASE}/api/auth/magic/start`, {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({ email }),
        });
        if (!res.ok) throw new Error("Request failed");
        statusFn.textContent = "Check your email for the sign-in link!";
        statusFn.style.color = "#4ade80";
      } catch (err) {
        statusFn.textContent = "Failed to send link. Try again.";
        statusFn.style.color = "#ef4444";
      }
    });
  }
}

/**
 * Detects the user's OS to highlight the appropriate download option.
 * Falls back to Android/Desktop detection.
 */
function detectPlatform() {
  const userAgent = navigator.userAgent.toLowerCase();
  const downloadBtns = document.querySelectorAll(
    ".btn-download, .btn-download-platform"
  );

  let platform = "Android"; // default

  if (userAgent.includes("iphone") || userAgent.includes("ipad")) {
    platform = "iOS";
  } else if (userAgent.includes("windows")) {
    platform = "Desktop";
  } else if (userAgent.includes("mac")) {
    platform = "Desktop";
  } else if (userAgent.includes("linux")) {
    platform = "Desktop";
  }

  // Highlight detected platform
  const platformCards = document.querySelectorAll(".download-card");
  platformCards.forEach((card) => {
    const h3 = card.querySelector("h3");
    if (h3 && h3.textContent === platform) {
      card.style.border = "1px solid var(--aether-blue)";
      card.style.boxShadow = "0 0 30px rgba(56, 189, 248, 0.3)";
    }
  });
}

function setupSmoothScroll() {
  const links = document.querySelectorAll('a[href^="#"]');

  links.forEach((link) => {
    link.addEventListener("click", (e) => {
      e.preventDefault();
      const targetId = link.getAttribute("href");
      const targetElement = document.querySelector(targetId);

      if (targetElement) {
        targetElement.scrollIntoView({
          behavior: "smooth",
          block: "start",
        });
      }
    });
  });
}

/**
 * Animates the background network nodes with random pulses.
 */
function animateNetwork() {
  const nodes = document.querySelectorAll(".orbit-node");

  nodes.forEach((node, index) => {
    node.style.animationDelay = `${index * 0.3}s`;

    // Add random pulse variations
    node.style.animationDuration = `${2.5 + Math.random()}s`;
  });

  // Animate connections
  const connections = document.querySelectorAll(".connection");
  connections.forEach((conn, index) => {
    conn.style.animationDelay = `${index * 0.2}s`;
  });
}

// Download button interactions
// Download button interactions
// We now rely on direct href links in the HTML or dynamically set by detectPlatform()
// handleDownload interception removed to allow direct navigation.

document.addEventListener("DOMContentLoaded", () => {
  // Main hero download button
  const heroDownload = document.querySelector(".btn-download");
  if (heroDownload) {
    heroDownload.addEventListener("click", () => {
      // Scroll to download section
      document.querySelector("#download").scrollIntoView({
        behavior: "smooth",
      });
    });
  }
});

// Platform Detection and Auto-Recommendation
async function detectPlatform() {
  const ua = navigator.userAgent.toLowerCase();
  const platform = navigator.platform.toLowerCase();

  let detectedOS = null;
  let icon = "";
  let name = "";
  let desc = "";
  let pattern = "";

  // 1. Detect OS
  if (ua.includes("android")) {
    detectedOS = "android";
    icon = "🤖";
    name = "Android APK";
    desc = "ARM64/x64/x86 • Universal";
    pattern = /gardener-android.*\.apk$/i;
  } else if (ua.includes("iphone") || ua.includes("ipad")) {
    detectedOS = "ios";
    icon = "🍎";
    name = "iOS";
    desc = "Requires manual signing";
    // iOS usually points to release page, no direct asset yet
  } else if (platform.includes("win") || ua.includes("windows")) {
    detectedOS = "windows";
    icon = "🪟";
    name = "Windows x64";
    desc = "Windows 10/11";
    pattern = /gardener-windows-x64.*\.zip$/i;
  } else if (platform.includes("mac") || ua.includes("mac os x")) {
    detectedOS = "macos";
    icon = "🍏";
    name = "macOS";
    desc = "Universal (Apple Silicon & Intel)";
    pattern = /gardener-macos.*\.zip$/i;
  } else if (platform.includes("linux") || ua.includes("linux")) {
    detectedOS = "linux";
    icon = "🐧";
    name = "Linux x64";
    desc = "Ubuntu 20.04+ / Debian 11+";
    pattern = /gardener-linux-x64.*\.zip$/i;
  }

  if (!detectedOS) return;

  // 2. Fetch Latest Release Info (Use local proxy to avoid rate limits)
  let downloadUrl = "/downloads/" + detectedOS; // Default fallback to smart proxy
  let version = "Latest";

  try {
    const res = await fetch("/api/releases");
    if (res.ok) {
      const releases = await res.json();
      // /api/releases returns a list. Find the first (latest) release.
      const data = Array.isArray(releases) ? releases[0] : releases;
      version = data.tag_name || "v1.9.5";

      if (pattern) {
        const asset = data.assets.find((a) => pattern.test(a.name));
        if (asset) downloadUrl = asset.browser_download_url;
      }

      // Update all-platforms grid
      const links = [
        { id: "dl-android", pattern: /gardener-android.*\.apk$/i },
        { id: "dl-windows", pattern: /gardener-windows-x64.*\.zip$/i },
        { id: "dl-macos", pattern: /gardener-macos.*\.zip$/i },
        { id: "dl-linux", pattern: /gardener-linux-x64.*\.zip$/i },
      ];
      links.forEach((link) => {
        const el = document.getElementById(link.id);
        if (el) {
          const asset = data.assets.find((a) => link.pattern.test(a.name));
          if (asset) el.href = asset.browser_download_url;
        }
      });
    }
  } catch (e) {
    console.warn("Failed to fetch latest release, falling back to default.", e);
  }

  // If platform detected, show recommendation
  if (detectedOS) {
    const recBox = document.getElementById("recommended-platform");
    const recIcon = document.getElementById("rec-icon");
    const recPlatform = document.getElementById("rec-platform");
    const recDesc = document.getElementById("rec-desc");
    const recDownload = document.getElementById("rec-download");
    const recVersion = document.getElementById("rec-version");

    if (
      recBox &&
      recIcon &&
      recPlatform &&
      recDesc &&
      recDownload &&
      recVersion
    ) {
      recIcon.textContent = icon;
      recPlatform.textContent = name;
      recDesc.textContent = desc;
      recDownload.href = downloadUrl;
      recVersion.textContent = version;
      recBox.style.display = "block";
    }
  }
}
