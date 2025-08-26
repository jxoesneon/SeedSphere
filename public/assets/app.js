(function () {
  const manifestUrl = `${window.location.origin}/manifest.json`;
  const el = document.getElementById('manifestUrl');
  const copyBtn = document.getElementById('copyBtn');
  const yearEl = document.getElementById('year');
  const installLink = document.getElementById('installLink');
  const openStremioLink = document.getElementById('openStremioLink');
  const refreshLink = document.getElementById('refreshLink');
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

  // No JS navigation needed; use native anchor navigation for protocol links

  if (refreshLink) {
    refreshLink.href = buildPrimaryInstallLink(manifestUrl, version);
  }

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
    if (!installLink) return;
    installLink.textContent = installed ? 'Update in Stremio' : 'Install in Stremio';
    installLink.setAttribute('aria-label', installLink.textContent);
  }

  setInstallButtonLabel(localStorage.getItem(STORAGE_KEY) === '1');

  if (installLink) {
    installLink.href = buildPrimaryInstallLink(manifestUrl, version);
    installLink.addEventListener('click', () => {
      // Optimistically mark as installed to toggle label immediately
      setTimeout(() => {
        try { localStorage.setItem(STORAGE_KEY, '1'); } catch (_) {}
        setInstallButtonLabel(true);
      }, 1500);
    });
  }

  if (openStremioLink) {
    openStremioLink.href = 'stremio://addons';
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
