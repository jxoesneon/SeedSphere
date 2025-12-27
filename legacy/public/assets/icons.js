/* HeroIcons loader: replace <span class="icon" data-icon="name"></span> with inline SVG.
   Uses outline 24px set. Caches fetched SVGs in memory and localStorage. */
(function(){
  const CDN = 'https://unpkg.com/heroicons@2.1.5/24/outline/';
  const cache = new Map();
  function lsKey(name){ return 'seedsphere.icon.'+name; }
  async function fetchIcon(name){
    if (cache.has(name)) return cache.get(name);
    try {
      const fromLs = localStorage.getItem(lsKey(name));
      if (fromLs) { cache.set(name, fromLs); return fromLs; }
    } catch(_){}
    const url = CDN + encodeURIComponent(name) + '.svg';
    const resp = await fetch(url, { cache: 'force-cache' });
    if (!resp.ok) throw new Error('icon HTTP '+resp.status);
    const svg = await resp.text();
    cache.set(name, svg);
    try { localStorage.setItem(lsKey(name), svg); } catch(_){}
    return svg;
  }
  function normalize(svg){
    // Ensure currentColor and size without overriding existing attributes
    return svg
      .replace('<svg ', '<svg aria-hidden="true" focusable="false" width="24" height="24" fill="none" stroke="currentColor" ');
  }
  async function hydrate(el){
    const name = (el.getAttribute('data-icon')||'').trim();
    if (!name) return;
    try {
      const raw = await fetchIcon(name);
      el.innerHTML = normalize(raw);
      el.classList.add('icon-ready');
    } catch(_) { /* ignore */ }
  }
  async function run(root){
    const scope = root && root.querySelectorAll ? root : document;
    const nodes = scope.querySelectorAll('.icon[data-icon]:not(.icon-ready)');
    for (const el of nodes) hydrate(el);
  }
  // Observe future additions
  const mo = new MutationObserver((mutations) => {
    for (const m of mutations) {
      if (m.type === 'childList') {
        m.addedNodes && m.addedNodes.forEach((n) => {
          if (n.nodeType === 1) run(n);
        });
      }
      if (m.type === 'attributes' && m.target && m.attributeName === 'data-icon' && m.target.classList.contains('icon')) {
        run(m.target);
      }
    }
  });
  try { mo.observe(document.documentElement, { childList: true, subtree: true, attributes: true, attributeFilter: ['data-icon'] }); } catch(_) {}
  // Expose manual hydrate
  try { window.SeedSphereIcons = { hydrate: run }; } catch(_) {}
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', () => run());
  } else run();
})();
