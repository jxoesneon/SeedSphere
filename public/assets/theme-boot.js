/* SeedSphere theme bootstrap: runs before app CSS to avoid grey washout */
(function () {
  try {
    var t = localStorage.getItem('theme') || 'seedsphere';
    var ALLOWED = { seedsphere: 1, light: 1, dark: 1 };
    if (!ALLOWED[t]) t = 'seedsphere';
    document.documentElement.setAttribute('data-theme', t);
  } catch (e) {
    try { document.documentElement.setAttribute('data-theme', 'seedsphere'); } catch (_) {}
  }
  try {
    var coarse = false;
    if (typeof window !== 'undefined' && window.matchMedia) {
      coarse = window.matchMedia('(any-pointer: coarse)').matches || window.matchMedia('(pointer: coarse)').matches;
    }
    var ua = (typeof navigator !== 'undefined' && navigator.userAgent) ? navigator.userAgent : '';
    if (/TV|Tizen|Web0S|SmartTV|BRAVIA|AFTB|AFTM|AFTT/i.test(ua)) coarse = true;
    document.documentElement.setAttribute('data-input', coarse ? 'coarse' : 'fine');
  } catch (_) {}
})();
