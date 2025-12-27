(function () {
  const manifestUrl = `${window.location.origin}/manifest.json`;
  const el = document.getElementById('manifestUrl');
  const copyBtn = document.getElementById('copyBtn');
  const yearEl = document.getElementById('year');
  const installBtn = document.getElementById('installBtn');
  const openStremioBtn = document.getElementById('openStremioBtn');
  const refreshBtn = document.getElementById('refreshBtn');
  const copyInstallLinkBtn = document.getElementById('copyInstallLink');
  const copyProtocolBtn = document.getElementById('copyProtocolBtn');
  const themeToggle = document.getElementById('themeToggle');
  const qrImg = document.getElementById('qrImg');
  const updateBanner = document.getElementById('updateBanner');
  const dismissUpdate = document.getElementById('dismissUpdate');

  if (el) el.textContent = manifestUrl;
  if (yearEl) yearEl.textContent = new Date().getFullYear();

  // Heuristic: remember if user attempted install before
  const STORAGE_KEY = 'seedsphereInstalledOnce'
  const version = (document.querySelector('meta[name="seedsphere-version"]')?.getAttribute('content')) || '0.0.3';
  function buildPrimaryInstallLink(u) {
    // Canonical per Stremio docs: replace https?:// with stremio:// pointing to manifest.json
    return u.replace(/^https?:\/\//, 'stremio://');
  }

  if (copyProtocolBtn) {
    copyProtocolBtn.addEventListener('click', async () => {
      try {
        const link = buildPrimaryInstallLink(manifestUrl);
        await navigator.clipboard.writeText(link);
        copyProtocolBtn.textContent = 'Copied!';
        setTimeout(() => (copyProtocolBtn.textContent = 'Copy stremio://'), 1400);
      } catch (e) {
        console.error('Copy protocol link failed', e);
      }
    });
  }

  // Single JS-triggered attempt via window.open for protocol links (no HTTP fallback)

  if (copyInstallLinkBtn) {
    copyInstallLinkBtn.addEventListener('click', async () => {
      try {
        const link = buildPrimaryInstallLink(manifestUrl);
        await navigator.clipboard.writeText(link);
        copyInstallLinkBtn.textContent = 'Link Copied!';
        setTimeout(() => (copyInstallLinkBtn.textContent = 'Copy Install Link'), 1400);
      } catch (e) {
        console.error('Copy install link failed', e);
      }
    });
  }

  // Theme toggle with persistence
  const THEME_KEY = 'seedsphereTheme';
  function applyTheme(theme) {
    document.documentElement.setAttribute('data-theme', theme);
  }
  try {
    const saved = localStorage.getItem(THEME_KEY);
    if (saved === 'light' || saved === 'dark') applyTheme(saved);
  } catch (_) {}
  if (themeToggle) {
    themeToggle.addEventListener('click', () => {
      const current = document.documentElement.getAttribute('data-theme') || 'dark';
      const next = current === 'dark' ? 'light' : 'dark';
      applyTheme(next);
      try { localStorage.setItem(THEME_KEY, next); } catch (_) {}
    });
  }

  // Generate QR code (client-side via external image service)
  if (qrImg) {
    const protocolLink = buildPrimaryInstallLink(manifestUrl);
    const qrUrl = `https://api.qrserver.com/v1/create-qr-code/?size=180x180&data=${encodeURIComponent(protocolLink)}`;
    qrImg.src = qrUrl;
  }

  // Update banner logic: show when last seen version differs from current
  const VERSION_KEY = 'seedsphereLastSeenVersion';
  try {
    const last = localStorage.getItem(VERSION_KEY);
    // If we have seen a version before and it differs, show the banner
    if (updateBanner && last && last !== version) {
      updateBanner.style.display = 'flex';
    }
    // Initialize last seen on first visit if not set
    if (!last) {
      localStorage.setItem(VERSION_KEY, version);
    }
  } catch (_) {}

  if (dismissUpdate) {
    dismissUpdate.addEventListener('click', () => {
      try { localStorage.setItem(VERSION_KEY, version); } catch (_) {}
      if (updateBanner) updateBanner.style.display = 'none';
    });
  }

  function setInstallButtonLabel(installed) {
    if (!installBtn) return;
    installBtn.textContent = installed ? 'Update in Stremio' : 'Install in Stremio';
    installBtn.setAttribute('aria-label', installBtn.textContent);
  }

  // Helper to navigate to custom protocol using a temporary anchor element
  function navigateProtocol(url) {
    try {
      const a = document.createElement('a');
      a.href = url;
      a.style.display = 'none';
      document.body.appendChild(a);
      a.click();
      a.remove();
    } catch (_) {}
  }

  setInstallButtonLabel(localStorage.getItem(STORAGE_KEY) === '1');

  if (installBtn) {
    installBtn.addEventListener('click', () => {
      try { window.location.href = buildPrimaryInstallLink(manifestUrl); } catch (_) {}
      // Optimistically mark as installed to toggle label
      setTimeout(() => {
        try { localStorage.setItem(STORAGE_KEY, '1'); } catch (_) {}
        setInstallButtonLabel(true);
      }, 1500);
    });
  }

  if (openStremioBtn) {
    openStremioBtn.addEventListener('click', () => {
      navigateProtocol('stremio://');
    });
  }

  if (refreshBtn) {
    refreshBtn.addEventListener('click', () => {
      try { window.location.href = buildPrimaryInstallLink(manifestUrl); } catch (_) {}
    });
  }

  if (copyBtn) {
    copyBtn.addEventListener('click', async () => {
      try {
        await navigator.clipboard.writeText(manifestUrl);
        copyBtn.textContent = 'Copied!';
        setTimeout(() => (copyBtn.textContent = 'Copy'), 1200);
      } catch (e) {
        console.error('Copy failed', e);
      }
    });
  }
})();
