(function () {
  const manifestUrl = `${window.location.origin}/manifest.json`;
  const el = document.getElementById('manifestUrl');
  const copyBtn = document.getElementById('copyBtn');
  const yearEl = document.getElementById('year');
  const installBtn = document.getElementById('installBtn');
  const openStremioBtn = document.getElementById('openStremioBtn');
  const refreshBtn = document.getElementById('refreshBtn');
  const copyInstallLinkBtn = document.getElementById('copyInstallLink');
  const themeToggle = document.getElementById('themeToggle');
  const qrImg = document.getElementById('qrImg');

  if (el) el.textContent = manifestUrl;
  if (yearEl) yearEl.textContent = new Date().getFullYear();

  // Heuristic: remember if user attempted install before
  const STORAGE_KEY = 'seedsphereInstalledOnce';
  const version = (document.querySelector('meta[name="seedsphere-version"]')?.getAttribute('content')) || '0.0.3';
  function buildPrimaryInstallLink(u, v) {
    // Use a single canonical deep link to avoid multiple protocol errors
    return `stremio://addon-install?url=${encodeURIComponent(u)}&version=${encodeURIComponent(v)}`;
  }

  // Single JS-triggered attempt via window.open for protocol links (no HTTP fallback)

  if (copyInstallLinkBtn) {
    copyInstallLinkBtn.addEventListener('click', async () => {
      try {
        const link = buildPrimaryInstallLink(manifestUrl, version);
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
    const qrUrl = `https://api.qrserver.com/v1/create-qr-code/?size=180x180&data=${encodeURIComponent(manifestUrl)}`;
    qrImg.src = qrUrl;
  }

  function setInstallButtonLabel(installed) {
    if (!installBtn) return;
    installBtn.textContent = installed ? 'Update in Stremio' : 'Install in Stremio';
    installBtn.setAttribute('aria-label', installBtn.textContent);
  }

  setInstallButtonLabel(localStorage.getItem(STORAGE_KEY) === '1');

  if (installBtn) {
    installBtn.addEventListener('click', () => {
      try { window.open(buildPrimaryInstallLink(manifestUrl, version)); } catch (_) {}
      // Optimistically mark as installed to toggle label
      setTimeout(() => {
        try { localStorage.setItem(STORAGE_KEY, '1'); } catch (_) {}
        setInstallButtonLabel(true);
      }, 1500);
    });
  }

  if (openStremioBtn) {
    openStremioBtn.addEventListener('click', () => {
      try { window.open('stremio://addons'); } catch (_) {}
    });
  }

  if (refreshBtn) {
    refreshBtn.addEventListener('click', () => {
      try { window.open(buildPrimaryInstallLink(manifestUrl, version)); } catch (_) {}
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
