'use strict';
(function () {
  function qs(name) {
    try {
      const url = new URL(window.location.href);
      return url.searchParams.get(name) || '';
    } catch (_) { return ''; }
  }
  function setMsg(text) {
    var el = document.getElementById('msg');
    if (el) el.textContent = text;
  }
  const seedlingId = qs('seedling_id');
  // Enhance CTA links with seedling_id context so Start can pre-fill
  try {
    const signin = document.getElementById('signinLink');
    const linker = document.getElementById('linkSeedling');
    if (signin) signin.href = seedlingId ? `/#/start?seedling_id=${encodeURIComponent(seedlingId)}` : '/#/start';
    if (linker) linker.href = seedlingId ? `/#/start?seedling_id=${encodeURIComponent(seedlingId)}` : '/#/start';
  } catch (_) {}

  // If opened from a revoked or invalid link scenario, the page is still helpful;
  // provide a small contextual badge in the title by probing the referrer if present.
  try {
    const ref = document.referrer || '';
    if (ref.includes('/configure')) {
      setMsg('This Configure link was opened directly. Please sign in and review your seedling status.');
    }
  } catch (_) {}
})();
