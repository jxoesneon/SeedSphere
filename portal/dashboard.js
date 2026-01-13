// Dashboard JavaScript

document.addEventListener("DOMContentLoaded", () => {
  // Load user data
  loadUserData();

  // Setup navigation
  setupDashboardNav();

  // Setup interactions
  setupInteractions();

  // Load Releases
  loadReleases();
});

// Dynamic API Base URL
// Dynamic API Base URL
// Dynamic API Base URL
const API_BASE = "";
let currentUser = null; // Cache for user session

/**
 * Fetches the current user session and updates the dashboard state.
 * Handles Guest vs Logged In views and loads user settings.
 */
async function loadUserData() {
  // API_BASE is global

  try {
    const res = await fetch(`${API_BASE}/api/auth/session`, {
      credentials: "include",
    });
    const data = await res.json();

    // Check for login triggers
    const urlParams = new URLSearchParams(window.location.search);
    const shouldShowLogin =
      urlParams.get("login") === "sw" || window.location.hash === "#login";

    if (data.ok && data.user) {
      // Logged in
      currentUser = data.user;
      document.getElementById("login-overlay").style.display = "none";
      document.getElementById("main-dashboard").style.filter = "none";
      updateUI(data.user);
      updateUI(data.user);
      fetchStats();
      fetchActivity(); // New: Load real activity
      fetchDevices(); // New: Load real linked devices

      // Load Linking Token & Settings
      try {
        const tokenRes = await fetch(`${API_BASE}/api/auth/token`);
        const tokenData = await tokenRes.json();
        if (tokenData.ok) {
          const el = document.getElementById("linking-token");
          if (el) el.textContent = tokenData.token;
        }

        if (data.user.settings) {
          if (data.user.settings.rd_key)
            document.getElementById("rd-key").value = data.user.settings.rd_key;
          if (data.user.settings.ad_key)
            document.getElementById("ad-key").value = data.user.settings.ad_key;
        }
      } catch (e) {
        console.error("Failed to load user extras", e);
      }
    } else {
      // Not logged in (Strict Mode)
      // Show overlay, keep background blurred
      document.getElementById("login-overlay").style.display = "flex";
      document.getElementById("main-dashboard").style.filter = "blur(10px)";

      // Clean URL but keep overlay
      if (shouldShowLogin) {
        window.history.replaceState(
          {},
          document.title,
          window.location.pathname
        );
      }

      currentUser = null;
      updateUI(null);
    }
  } catch (e) {
    console.error("Auth check failed:", e);
    // Fail safe: show login
    document.getElementById("login-overlay").style.display = "flex";
    document.getElementById("main-dashboard").style.filter = "blur(10px)";
  }
}

/**
 * Updates the Dashboard UI elements based on auth state.
 * @param {Object|null} user - The user object from session or null if guest.
 */
function updateUI(user) {
  const gardenerIdElement = document.getElementById("gardener-id");
  const userIdElement = document.getElementById("user-id");
  const logoutBtn = document.querySelector(".btn-logout");

  if (user) {
    // Logged In State
    const displayId = user.email || user.id.split(":").pop() || user.id;
    if (gardenerIdElement) gardenerIdElement.textContent = displayId;
    if (userIdElement)
      userIdElement.textContent = user.email
        ? user.email.split("@")[0]
        : "User";

    if (logoutBtn) {
      logoutBtn.textContent = "Sign Out";
      logoutBtn.onclick = async () => {
        await fetch(`${API_BASE}/api/auth/logout`, { method: "POST" });
        window.location.reload();
      };
    }
  } else {
    // Guest State
    if (gardenerIdElement) gardenerIdElement.textContent = "Guest Access";
    if (userIdElement) userIdElement.textContent = "Not Signed In";

    if (logoutBtn) {
      logoutBtn.textContent = "Sign In";
      logoutBtn.onclick = () => {
        document.getElementById("login-overlay").style.display = "flex";
      };
    }
  }
}

/**
 * Loads network statistics (node count, data shared) for display.
 */
async function fetchStats() {
  // Legacy mock stats or fetch from real API if available
  const stats = {
    nodes: 47,
    dataShared: 1247,
    uptime: 127,
  };
  document.getElementById("nodes-count").textContent = stats.nodes;
  document.getElementById("data-shared").textContent = `${stats.dataShared} MB`;
  document.getElementById("uptime").textContent = `${stats.uptime}h`;
}

/**
 * Sets up the sidebar navigation tab switching logic.
 */
function setupDashboardNav() {
  const navItems = document.querySelectorAll(".nav-item");
  const sections = document.querySelectorAll(".dashboard-section");

  navItems.forEach((item) => {
    item.addEventListener("click", (e) => {
      e.preventDefault();

      // Remove active class from all items
      navItems.forEach((nav) => nav.classList.remove("active"));

      // Add active class to clicked item
      item.classList.add("active");

      // Hide all sections
      sections.forEach((section) => (section.style.display = "none"));

      // Show target section
      const targetId = item.getAttribute("href").substring(1);
      const targetSection = document.getElementById(targetId);
      if (targetSection) {
        targetSection.style.display = "block";
      }
    });
  });

  // Profile Navigation (User Badge)
  const userBadge = document.querySelector(".user-badge");
  if (userBadge) {
    userBadge.addEventListener("click", (e) => {
      e.preventDefault();

      // Remove active class from all items
      navItems.forEach((nav) => nav.classList.remove("active"));
      sections.forEach((section) => (section.style.display = "none"));

      const profileSection = document.getElementById("profile");
      if (profileSection) {
        profileSection.style.display = "block";
        loadProfile(); // Fetch fresh data
      }
    });
  }
}

/**
 * Initializes interactive elements: forms, buttons, and action cards.
 */
function setupInteractions() {
  // Magic Link Form
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
        if (!res.ok) {
          const errData = await res
            .json()
            .catch(() => ({ error: res.statusText }));
          throw new Error(errData.error || "Request failed");
        }
        statusFn.textContent = "Check your email for the sign-in link!";
        statusFn.style.color = "#4ade80";
      } catch (err) {
        console.error(err);
        statusFn.textContent = `Error: ${err.message}`;
        statusFn.style.color = "#ef4444";
      }
    });
  }

  // Logout/Login button logic moved to updateUI for dynamic state handling

  // Visibility Toggles
  document.querySelectorAll(".btn-toggle-visibility").forEach((btn) => {
    btn.addEventListener("click", (e) => {
      e.preventDefault();
      const targetId = btn.getAttribute("data-target");
      const input = document.getElementById(targetId);
      if (input) {
        if (input.type === "password") {
          input.type = "text";
          btn.textContent = "🔒";
        } else {
          input.type = "password";
          btn.textContent = "👁️";
        }
      }
    });
  });

  // Save API keys
  const saveBtns = document.querySelectorAll(".btn-save");
  saveBtns.forEach((btn) => {
    btn.addEventListener("click", async (e) => {
      e.preventDefault();
      // Navigate up to form then find input
      const form = btn.closest(".form-group");
      const input = form.querySelector(".form-input");
      const keyId = input.id;
      // Map IDs to API fields
      const keyMap = {
        "rd-key": "rd_key",
        "ad-key": "ad_key",
        "profile-rd-key": "rd_key",
        "profile-ad-key": "ad_key",
      };
      const keyType = keyMap[keyId];

      if (!keyType) return;

      // Validation
      const keyVal = input.value.trim();
      const alphanumericRegex = /^[a-zA-Z0-9]+$/;

      if (keyVal.length > 0 && !alphanumericRegex.test(keyVal)) {
        btn.textContent = "Invalid Format";
        btn.style.background = "#ef4444";
        setTimeout(() => {
          btn.textContent = "Save";
          btn.style.background = "";
        }, 2000);
        showToast(
          "API Key must be alphanumeric (no spaces or special chars)",
          "error"
        );
        return;
      }

      btn.textContent = "Saving...";
      try {
        await fetch(`${API_BASE}/api/auth/settings`, {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({ [keyType]: keyVal }),
        });
        btn.textContent = "Securely Saved";
        btn.style.background = "#4ade80";
        showToast("API Key encrypted and saved to your profile.", "success");

        // Sync values if multiple inputs exist for same key
        document.querySelectorAll(`input`).forEach((el) => {
          if (keyMap[el.id] === keyType) el.value = keyVal;
        });
      } catch (err) {
        btn.textContent = "Error";
        btn.style.background = "#ef4444";
      }

      setTimeout(() => {
        btn.textContent = "Save";
        btn.style.background = "";
      }, 2000);
    });
  });

  // Copy Token
  const copyBtn = document.querySelector(".btn-copy");
  if (copyBtn) {
    copyBtn.addEventListener("click", () => {
      const token = document.getElementById("linking-token").textContent;
      navigator.clipboard.writeText(token);
      copyBtn.textContent = "Copied!";
      setTimeout(() => (copyBtn.textContent = "Copy"), 2000);
    });
  }

  // Danger Zone
  const dangerBtns = document.querySelectorAll(".btn-danger");
  if (dangerBtns.length >= 2) {
    // Unlink
    dangerBtns[0].addEventListener("click", async () => {
      showConfirm(
        "Unlink All Devices?",
        "This will disconnect all devices from your account. You will need to re-link them manually.",
        async () => {
          try {
            const res = await fetch(`${API_BASE}/api/auth/unlink`, {
              method: "POST",
            });
            if (res.ok) {
              showToast("Devices unlinked successfully.", "success");
              fetchDevices();
              fetchActivity();
            } else {
              showToast("Failed to unlink devices.", "error");
            }
          } catch (e) {
            showToast("Network error.", "error");
          }
        },
        null, // cancel callback
        "Unlink", // confirm text
        true // isDanger
      );
    });

    // Delete
    dangerBtns[1].addEventListener("click", async () => {
      // Custom Prompt Logic for Deletion
      showPrompt(
        "Delete Account",
        "This action is irreversible. Type <strong>DELETE</strong> to confirm.",
        "DELETE",
        async () => {
          await fetch(`${API_BASE}/api/auth/account`, { method: "DELETE" });
          showToast("Account deleted.", "success");
          setTimeout(() => window.location.reload(), 1500);
        },
        true // isDanger
      );
    });
  }

  // Quick action cards
  const actionCards = document.querySelectorAll(".action-card");
  actionCards.forEach((card, index) => {
    card.addEventListener("click", () => {
      const actions = [
        () => {
          // Link new device
          const token = document.getElementById("linking-token").textContent;
          if (token && token !== "Loading...") {
            showQrModal(token);
          } else {
            showToast("Token loading... please wait", "error");
          }
        },
        () => {
          // Refresh P2P Status
          loadUserData();
          showToast("P2P status refreshed!", "success");
        },
        () => {
          // Download APK - Scroll to section
          document.querySelector('a[href="#downloads"]').click();
        },
        () => {
          // View API docs
          window.location.href = "docs.html";
        },
      ];

      if (actions[index]) {
        actions[index]();
      }
    });
  });
  // Install Addon (Stremio)
  const installBtn = document.querySelector(".btn-install-addon");
  if (installBtn) {
    installBtn.addEventListener("click", () => {
      try {
        if (currentUser) {
          const userId = currentUser.id.split(":").pop() || currentUser.id;

          // Determine Host: Use API_BASE host if set, otherwise current window host
          let host;
          if (API_BASE) {
            try {
              host = new URL(API_BASE).host;
            } catch (e) {
              host = window.location.host;
            }
          } else {
            host = window.location.host;
          }

          // Format: stremio://<host>/u/<userId>/manifest.json
          // Ensure we don't duplicate protocol if host has it (mostly host shouldn't)
          const manifestUrl = `stremio://${host}/u/${userId}/manifest.json`;

          window.location.href = manifestUrl;
        } else {
          showToast("Please sign in to install addons.", "info");
        }
      } catch (e) {
        console.error("Install failed", e);
        showToast("Failed to initiate install.", "error");
      }
    });
  }
}
// --- Profile Management ---

async function loadProfile() {
  if (!currentUser) return;

  // 1. Update Identity
  const idEl = document.getElementById("profile-user-id");
  const emailEl = document.getElementById("profile-email");
  if (idEl)
    idEl.textContent = currentUser.email
      ? currentUser.email.split("@")[0]
      : "User";
  if (emailEl) emailEl.textContent = currentUser.email || currentUser.id;

  // 2. Load Sessions
  const list = document.getElementById("sessions-list");
  if (list) {
    list.innerHTML = `<div class="session-item loading">Loading active sessions...</div>`;
    try {
      const res = await fetch(`${API_BASE}/api/auth/sessions`);
      const data = await res.json();
      if (data.ok && data.sessions) {
        renderSessions(data.sessions, list);
      } else {
        list.innerHTML = `<div class="text-muted">Failed to load sessions.</div>`;
      }
    } catch (e) {
      console.error("Session load failed", e);
      list.innerHTML = `<div class="text-muted">Error loading sessions.</div>`;
    }
  }

  // 3. Sync Settings (API Keys)
  // Already loaded in loadUserData, but we can refresh?
  // The inputs are populated on init, so we should be good.
  // Ensure inputs in profile match user settings if they exist
  if (currentUser.settings) {
    if (currentUser.settings.rd_key) {
      const el = document.getElementById("profile-rd-key");
      if (el) el.value = currentUser.settings.rd_key;
    }
    if (currentUser.settings.ad_key) {
      const el = document.getElementById("profile-ad-key");
      if (el) el.value = currentUser.settings.ad_key;
    }
  }
}

function renderSessions(sessions, container) {
  container.innerHTML = "";
  if (sessions.length === 0) {
    container.innerHTML = `<div class="text-muted">No active sessions.</div>`;
    return;
  }

  sessions.forEach((s) => {
    const item = document.createElement("div");
    item.className = "session-item glass";
    item.style.display = "flex";
    item.style.justifyContent = "space-between";
    item.style.alignItems = "center";
    item.style.padding = "1rem";
    item.style.marginBottom = "0.5rem";
    item.style.background = s.is_current
      ? "rgba(74, 222, 128, 0.1)"
      : "rgba(255,255,255,0.03)";
    item.style.border = s.is_current
      ? "1px solid rgba(74, 222, 128, 0.3)"
      : "none";
    item.style.borderRadius = "8px";

    item.innerHTML = `
            <div class="session-info">
                <div style="font-weight: bold; color: ${
                  s.is_current ? "#4ade80" : "white"
                };">
                    ${s.is_current ? "Current Session" : "Active Session"}
                </div>
                <div style="font-size: 0.8rem; color: var(--text-secondary);">
                    Created ${timeAgo(s.created_at)}
                </div>
            </div>
            ${
              !s.is_current
                ? `
                <button class="btn-revoke" data-sid="${s.sid}" style="background: rgba(239, 68, 68, 0.2); color: #ef4444; border: 1px solid rgba(239, 68, 68, 0.3); padding: 0.25rem 0.75rem; border-radius: 4px; cursor: pointer;">
                    Revoke
                </button>
            `
                : ""
            }
        `;

    container.appendChild(item);

    // Revoke Handler
    const revokeBtn = item.querySelector(".btn-revoke");
    if (revokeBtn) {
      revokeBtn.addEventListener("click", () => revokeSession(s.sid));
    }
  });
}

async function revokeSession(sid) {
  if (!confirm("Are you sure you want to revoke this session?")) return;

  try {
    const res = await fetch(`${API_BASE}/api/auth/sessions/${sid}`, {
      method: "DELETE",
    });
    if (res.ok) {
      showToast("Session revoked.", "success");
      loadProfile(); // Refresh list
    } else {
      showToast("Failed to revoke session.", "error");
    }
  } catch (e) {
    showToast("Error revoking session.", "error");
  }
}

// --- UI Helpers ---

function showToast(message, type = "info") {
  const container = document.getElementById("toast-container");
  const toast = document.createElement("div");

  // Icon based on type
  let icon = "ℹ️";
  if (type === "success") icon = "✅";
  if (type === "error") icon = "⚠️";

  toast.className = `toast toast-${type}`;
  toast.innerHTML = `<span>${icon}</span> <span>${message}</span>`; // Use innerHTML for flex layout

  // Remove inline styles as we moved to CSS

  container.appendChild(toast);

  // Auto remove
  setTimeout(() => {
    toast.classList.add("hiding");
    // Wait for transition
    setTimeout(() => toast.remove(), 400);
  }, 4000);
}

// --- Dynamic Modal System ---
function showConfirm(
  title,
  message,
  onConfirm,
  onCancel,
  confirmText = "Confirm",
  isDanger = false
) {
  createModal(title, message, [
    {
      text: "Cancel",
      class: "btn-modal-cancel",
      action: (modal) => {
        if (onCancel) onCancel();
        closeModal(modal);
      },
    },
    {
      text: confirmText,
      class: isDanger ? "btn-modal-danger" : "btn-modal-confirm",
      action: (modal) => {
        if (onConfirm) onConfirm();
        closeModal(modal);
      },
    },
  ]);
}

function showPrompt(title, message, expectedValue, onCheck, isDanger = false) {
  const inputId = "modal-input-" + Date.now();
  const htmlMessage = `
        <p>${message}</p>
        <input type="text" id="${inputId}" class="form-input" style="margin-top: 1rem; text-transform: uppercase;" placeholder="Type ${expectedValue}">
     `;

  createModal(title, htmlMessage, [
    {
      text: "Cancel",
      class: "btn-modal-cancel",
      action: (modal) => closeModal(modal),
    },
    {
      text: "Confirm",
      class: isDanger ? "btn-modal-danger" : "btn-modal-confirm",
      action: (modal) => {
        const val = document.getElementById(inputId).value;
        if (val === expectedValue) {
          if (onCheck) onCheck();
          closeModal(modal);
        } else {
          showToast(`Incorrect confirmation. Type ${expectedValue}`, "error");
          // Don't close modal
        }
      },
    },
  ]);
}

function createModal(titleOrConfig, content, buttons) {
  const existing = document.getElementById("active-modal");
  if (existing) existing.remove();

  // 1. Resolve Config (Polyfill for object signature)
  let config = {};
  if (typeof titleOrConfig === "object" && titleOrConfig !== null) {
    config = titleOrConfig;
  } else {
    config = {
      title: titleOrConfig,
      body: content,
      actions: buttons,
    };
  }

  // 2. Create Overlay
  const overlay = document.createElement("div");
  overlay.id = "active-modal";
  overlay.className = "modal-overlay";

  // CLICK OUTSIDE TO DISMISS
  overlay.onclick = (e) => {
    if (e.target === overlay) {
      closeModal(overlay);
    }
  };

  const card = document.createElement("div");
  card.className = "modal-card glass";

  // 3. Title
  const h3 = document.createElement("h3");
  h3.className = "modal-title";
  h3.textContent = config.title;

  // 4. Body
  const body = document.createElement("div");
  body.className = "modal-body";
  // Check if body implies HTML
  const bodyContent = config.body || config.content || "";
  if (bodyContent.includes("<") && bodyContent.includes(">")) {
    body.innerHTML = bodyContent;
  } else {
    body.textContent = bodyContent;
  }

  // 5. Actions
  const actionContainer = document.createElement("div");
  actionContainer.className = "modal-actions";

  const actionList = config.actions || config.buttons || [];
  actionList.forEach((btnConfig) => {
    const btn = document.createElement("button");
    // Handle mapped properties (text vs label, class, action vs onClick)
    btn.className = `btn-modal ${
      btnConfig.class ||
      (btnConfig.primary ? "btn-modal-confirm" : "btn-modal-cancel")
    }`;
    btn.textContent = btnConfig.text || btnConfig.label;

    // Action wraper
    btn.onclick = () => {
      if (btnConfig.action) btnConfig.action(overlay);
      else if (btnConfig.onClick) {
        btnConfig.onClick();
        closeModal(overlay);
      }
    };
    actionContainer.appendChild(btn);
  });

  card.appendChild(h3);
  card.appendChild(body);
  card.appendChild(actionContainer);
  overlay.appendChild(card);

  document.body.appendChild(overlay);
}

function closeModal(modalElement) {
  modalElement.style.opacity = "0";
  setTimeout(() => modalElement.remove(), 200);
}

// --- Activity & Devices ---
async function fetchActivity() {
  try {
    const res = await fetch(`${API_BASE}/api/auth/activity`);
    const data = await res.json();
    const container = document.querySelector(".activity-feed");

    if (data.ok && data.activity && container) {
      container.innerHTML = ""; // Clear fake data

      if (data.activity.length === 0) {
        container.innerHTML = `<div style="padding: 2rem; text-align: center; color: var(--text-secondary);">No activity functionality yet.</div>`;
        return;
      }

      data.activity.forEach((item) => {
        const el = document.createElement("div");
        el.className = "activity-item glass";
        el.innerHTML = `
                    <span class="activity-icon">${item.icon || "📝"}</span>
                    <div class="activity-content">
                        <div>
                             <strong>${item.title}</strong>
                             ${
                               item.details
                                 ? `<div style="font-size: 0.85rem; opacity: 0.8;">${item.details}</div>`
                                 : ""
                             }
                        </div>
                        <span class="activity-time">${timeAgo(
                          item.timestamp
                        )}</span>
                    </div>
                `;
        container.appendChild(el);
      });
    }
  } catch (e) {
    console.error("Failed to load activity", e);
  }
}

async function fetchDevices() {
  // We don't have a specific "Linked Devices" container in the HTML overview yet,
  // but the user asked for "Device Linked [tab?]... linked device doesn't show my actual...".
  // I will append a "Linked Devices" card TO THE SETTINGS tab or modify the overview.
  // Actually, let's put it in the "Settings" tab for now as "Linked Devices" list,
  // or maybe a new section in "Activity" tab?
  // The user mentioned "for the next tab still on portal under activity... device linked doesn't show my actual devices".
  // The activity feed itself shows "Device Linked" events.
  // I should also list the active devices somewhere.
  // I'll add a "Active Devices" list to the Settings tab dynamically.

  try {
    const res = await fetch(`${API_BASE}/api/auth/devices`);
    const data = await res.json();

    // Find a place to inject. The 'Linking Token' card in settings is good.
    // Or render in the Activity tab if there's space?
    // Let's add it to Settings -> Linking Token card (append).

    const settingsCard = document.querySelectorAll(".settings-card")[1]; // Linking Token card
    if (data.ok && data.devices && settingsCard) {
      // Remove old device list if any
      const oldList = document.getElementById("device-list-container");
      if (oldList) oldList.remove();

      const devContainer = document.createElement("div");
      devContainer.id = "device-list-container";
      devContainer.style.marginTop = "1.5rem";
      devContainer.style.borderTop = "1px solid rgba(255,255,255,0.1)";
      devContainer.style.paddingTop = "1rem";

      devContainer.innerHTML = `<h4 style="margin-bottom: 1rem; color: var(--text-secondary); font-size: 0.9rem; text-transform: uppercase; letter-spacing: 1px;">ACTIVE DEVICES (${data.devices.length})</h4>`;

      if (data.devices.length === 0) {
        devContainer.innerHTML += `<div style="font-size: 0.9rem; color: rgba(255,255,255,0.4);">No devices linked yet.</div>`;
      } else {
        data.devices.forEach((d) => {
          const row = document.createElement("div");
          row.style.display = "flex";
          row.style.justifyContent = "space-between";
          row.style.padding = "0.75rem";
          row.style.background = "rgba(255,255,255,0.03)";
          row.style.borderRadius = "8px";
          row.style.marginBottom = "0.5rem";

          // Mask ID for privacy? Or show first chunk.
          const shortId = d.device_id.substring(0, 8) + "...";

          row.innerHTML = `
                        <div style="display: flex; align-items: center; gap: 0.5rem;">
                             <span>📱</span>
                             <span>${shortId}</span>
                        </div>
                        <div style="font-size: 0.8rem; color: var(--text-secondary);">
                            ${timeAgo(d.linked_at)}
                        </div>
                     `;
          devContainer.appendChild(row);
        });
      }

      settingsCard.appendChild(devContainer);
    }
  } catch (e) {
    console.error("Failed to load devices", e);
  }
}

function timeAgo(timestamp) {
  const seconds = Math.floor((Date.now() - timestamp) / 1000);

  let interval = seconds / 31536000;
  if (interval > 1) return Math.floor(interval) + " years ago";
  interval = seconds / 2592000;
  if (interval > 1) return Math.floor(interval) + " months ago";
  interval = seconds / 86400;
  if (interval > 1) return Math.floor(interval) + " days ago";
  interval = seconds / 3600;
  if (interval > 1) return Math.floor(interval) + " hours ago";
  interval = seconds / 60;
  if (interval > 1) return Math.floor(interval) + " minutes ago";
  return Math.floor(seconds) + " seconds ago";
}
function showQrModal(tokenRaw) {
  const linkUrl = `${window.location.origin}/link?token=${tokenRaw}`;
  const qrSrc = `https://api.qrserver.com/v1/create-qr-code/?size=200x200&data=${encodeURIComponent(
    linkUrl
  )}`;

  const content = `
        <div style="display: flex; flex-direction: column; align-items: center; gap: 1.5rem; padding: 1rem 0;">
            <div style="background: white; padding: 1rem; border-radius: 12px; box-shadow: 0 4px 20px rgba(0,0,0,0.3);">
                <img src="${qrSrc}" alt="Scan QR Code" style="width: 200px; height: 200px; display: block;">
            </div>
            <div style="text-align: center; color: rgba(255,255,255,0.8);">
                <p style="margin-bottom: 0.5rem; font-size: 1rem;">Scan with the <strong>Gardener App</strong></p>
                <p style="font-size: 0.9rem; opacity: 0.7;">to link this device to your swarm.</p>
            </div>
            <div style="background: rgba(255,255,255,0.1); padding: 0.75rem 1rem; border-radius: 8px; font-family: monospace; font-size: 0.9rem; display: flex; align-items: center; gap: 0.5rem; max-width: 100%; overflow: hidden;">
                <span style="opacity: 0.6;">Token:</span>
                <span style="color: #4ade80;">${tokenRaw}</span>
            </div>
        </div>
    `;

  createModal({
    title: "Link New Device",
    body: content,
    actions: [
      {
        label: "Done",
        primary: true,
        onClick: () => {}, // Closes by default
      },
    ],
  });
}

async function loadReleases() {
  const container = document.getElementById("download-list-container");
  const hero = document.getElementById("latest-release-hero");
  const grid = document.getElementById("platform-grid");
  const historyList = document.querySelector(".history-list");

  try {
    const res = await fetch(`${API_BASE}/api/releases`);
    if (!res.ok) throw new Error("Failed to load");
    const releases = await res.json();

    container.innerHTML = "";
    grid.innerHTML = "";
    historyList.innerHTML = "";

    // 1. Find Latest Stable
    const latest = releases.find((r) => !r.prerelease) || releases[0];
    if (latest) {
      renderHero(latest, hero, grid);
    }

    // 2. Populate History (All versions)
    releases.forEach((r) => {
      const item = document.createElement("div");
      item.className = "history-item";
      item.innerHTML = `
            <span class="version-tag">${r.tag_name}</span>
            <span class="release-date">${new Date(
              r.published_at
            ).toLocaleDateString()}</span>
            <span class="release-notes" style="white-space: nowrap; overflow: hidden; text-overflow: ellipsis; max-width: 200px;">
                ${r.body ? r.body.split("\n")[0] : "No notes"}
            </span>
            <a href="${
              r.html_url
            }" target="_blank" style="margin-left: auto; color: var(--aether-blue);">View</a>
        `;
      historyList.appendChild(item);
    });
  } catch (e) {
    console.error(e);
    container.innerHTML = `
            <div style="text-align: center; padding: 2rem; color: #ef4444;">
                Failed to load releases. <br>
                <a href="https://github.com/jxoesneon/SeedSphere/releases" target="_blank" style="color: var(--aether-blue);">View on GitHub</a>
            </div>
        `;
  }
}

function renderHero(release, hero, grid) {
  document.getElementById("hero-version").textContent = release.tag_name;
  document.getElementById("hero-notes").textContent =
    release.body || "No release notes provided.";
  hero.style.display = "block";

  // Detect User OS
  const userOS = detectOS();
  const osBadge = document.getElementById("os-detected");
  if (userOS !== "unknown") {
    document.getElementById("user-os").textContent = formatOSName(userOS);
    osBadge.style.display = "block";
  }

  // Clear grid
  grid.innerHTML = "";

  // Define Platforms & matchers
  // Prioritize x64 as default if multiple match
  const platforms = [
    {
      id: "android",
      name: "Android",
      icon: "🤖",
      matcher: /android/i,
      archMatcher: /arm64/i,
      formats: ["apk", "aab"],
    },
    {
      id: "windows",
      name: "Windows",
      icon: "🪟",
      matcher: /windows/i,
      archMatcher: /x64/i,
      formats: ["exe", "msi", "zip"],
    },
    {
      id: "macos",
      name: "macOS",
      icon: "🍎",
      matcher: /macos|universal/i,
      archMatcher: /universal/i,
      formats: ["zip"],
    },
    {
      id: "linux",
      name: "Linux",
      icon: "🐧",
      matcher: /linux/i,
      archMatcher: /x64/i,
      formats: ["deb", "rpm", "zip"],
    },
  ];

  platforms.forEach((p) => {
    // Find all assets matching this platform
    const assets = release.assets.filter((a) => p.matcher.test(a.name));

    let primaryAsset = null;
    if (assets.length > 0) {
      // Prioritize the arch-specific asset if defined, else first
      primaryAsset =
        assets.find((a) => p.archMatcher.test(a.name)) || assets[0];
    }

    const isRecommended = userOS === p.id;

    // Container for the button group (Main Button + Dropdown Toggle)
    const btnGroup = document.createElement("div");
    btnGroup.className = `platform-group glass ${
      isRecommended ? "recommended" : ""
    }`;
    btnGroup.style.cssText = `
            display: flex; flex-direction: column; position: relative;
            border-radius: 16px; border: 1px solid rgba(255,255,255,0.1);
            transition: all 0.3s ease;
            ${
              isRecommended
                ? "border-color: #4ade80; box-shadow: 0 0 20px rgba(74,222,128,0.15); background: rgba(74, 222, 128, 0.05);"
                : "background: rgba(255,255,255,0.03);"
            }
        `;

    // Main Download Area
    const mainBtn = document.createElement("a");
    mainBtn.href = primaryAsset
      ? `${API_BASE}/downloads/${primaryAsset.name}`
      : release.html_url;
    mainBtn.target = primaryAsset ? "" : "_blank";
    mainBtn.style.cssText = `
            flex: 1; display: flex; flex-direction: column; align-items: center; justify-content: center;
            padding: 1.5rem 1rem; text-decoration: none; color: white; width: 100%; box-sizing: border-box;
        `;

    const sizeInfo = primaryAsset
      ? (primaryAsset.size / 1024 / 1024).toFixed(1) + " MB"
      : "Source";

    let archInfo = "x64";
    if (primaryAsset) {
      if (primaryAsset.name.includes("arm64")) archInfo = "ARM64";
      else if (primaryAsset.name.includes("universal")) archInfo = "Universal";
      else if (primaryAsset.name.includes("android")) archInfo = "ARM64/x64"; // Android APKs are fat
    }

    mainBtn.innerHTML = `
            <div style="font-size: 2rem; margin-bottom: 0.5rem;">${p.icon}</div>
            <div style="font-weight: 600;">${p.name}</div>
            <div style="font-size: 0.8rem; color: rgba(255,255,255,0.5); margin-top: 0.2rem;">
                ${archInfo} • ${sizeInfo}
            </div>
             ${
               isRecommended
                 ? '<div style="margin-top: 0.5rem; font-size: 0.7rem; color: #4ade80; text-transform: uppercase; letter-spacing: 1px;">Recommended</div>'
                 : ""
             }
        `;

    // Dropdown Toggle (if multiple assets for this platform)
    let dropdownHtml = "";
    if (assets.length > 1) {
      dropdownHtml = `
                <div class="dropdown-toggle" style="
                    border-top: 1px solid rgba(255,255,255,0.1); padding: 0.5rem;
                    text-align: center; cursor: pointer; color: rgba(255,255,255,0.7); font-size: 0.8rem;
                ">
                    More Options ▼
                </div>
                <div class="dropdown-menu glass" style="
                    display: none; position: absolute; top: 100%; left: 0; width: 100%;
                    z-index: 10; margin-top: 0.5rem; padding: 0.5rem; border-radius: 12px;
                    border: 1px solid rgba(255,255,255,0.1); background: rgba(20, 20, 30, 0.95);
                    box-shadow: 0 4px 20px rgba(0,0,0,0.5);
                ">
                    ${assets
                      .map((a) => {
                        const isArm = a.name.includes("arm64");
                        const ext = a.name.split(".").pop();
                        return `
                            <a href="${API_BASE}/downloads/${a.name}" style="
                                display: block; padding: 0.5rem; color: white; text-decoration: none;
                                font-size: 0.9rem; border-radius: 8px; margin-bottom: 2px;
                            " onmouseover="this.style.background='rgba(255,255,255,0.1)'" onmouseout="this.style.background='transparent'">
                                ${
                                  a.name.includes("arm64")
                                    ? "ARM64"
                                    : a.name.includes("universal")
                                    ? "Universal"
                                    : "x64"
                                } <span style="opacity:0.5; font-size: 0.8rem;">.${ext}</span>
                            </a>
                        `;
                      })
                      .join("")}
                </div>
            `;
    }

    btnGroup.appendChild(mainBtn);
    if (dropdownHtml) {
      const dropdownContainer = document.createElement("div");
      dropdownContainer.style.width = "100%";
      dropdownContainer.innerHTML = dropdownHtml;
      btnGroup.appendChild(dropdownContainer);

      // Toggle Logic
      const toggle = dropdownContainer.querySelector(".dropdown-toggle");
      const menu = dropdownContainer.querySelector(".dropdown-menu");
      toggle.onclick = (e) => {
        e.preventDefault();
        e.stopPropagation();
        // Close others
        document.querySelectorAll(".dropdown-menu").forEach((el) => {
          if (el !== menu) el.style.display = "none";
        });
        menu.style.display = menu.style.display === "block" ? "none" : "block";
      };
    }

    // Hover effect for main group
    btnGroup.onmouseover = () => {
      btnGroup.style.background = isRecommended
        ? "rgba(74, 222, 128, 0.1)"
        : "rgba(255,255,255,0.06)";
      btnGroup.style.transform = "translateY(-2px)";
    };
    btnGroup.onmouseout = () => {
      btnGroup.style.background = isRecommended
        ? "rgba(74, 222, 128, 0.05)"
        : "rgba(255,255,255,0.03)";
      btnGroup.style.transform = "translateY(0)";
    };

    grid.appendChild(btnGroup);
  });

  // Close dropdowns on click outside
  document.addEventListener("click", () => {
    document
      .querySelectorAll(".dropdown-menu")
      .forEach((el) => (el.style.display = "none"));
  });
}

function formatOSName(os) {
  if (os === "macos") return "macOS";
  return os.charAt(0).toUpperCase() + os.slice(1);
}

function detectOS() {
  const ua = navigator.userAgent.toLowerCase();
  if (ua.includes("android")) return "android";
  if (ua.includes("win")) return "windows";
  if (ua.includes("mac")) return "macos";
  if (ua.includes("linux")) return "linux";
  return "unknown";
}
