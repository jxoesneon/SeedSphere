(function () {
  const manifestEl = document.getElementById('manifestUrl');
  const copyBtn = document.getElementById('copyBtn');
  const validateBtn = document.getElementById('validateBtn');
  const urlInput = document.getElementById('trackers_url');
  const variantSel = document.getElementById('variant');
  const resultEl = document.getElementById('validateResult');
  const modeSel = document.getElementById('validation_mode');
  const maxInput = document.getElementById('max_trackers');
  const limitEnable = document.getElementById('limit_enable');
  const healthBtn = document.getElementById('healthBtn');
  const healthResult = document.getElementById('healthResult');
  const sweepBtn = document.getElementById('sweepBtn');
  const sweepResult = document.getElementById('sweepResult');
  const boostsRefresh = document.getElementById('boostsRefresh');
  const boostsList = document.getElementById('boostsList');
  const boostsMetrics = document.getElementById('boostsMetrics');
  // Update banner elements (created dynamically)
  let updateBanner = null;
  function ensureUpdateBanner() {
    if (updateBanner) return updateBanner;
    const wrap = document.querySelector('.container') || document.body;
    const div = document.createElement('div');
    div.className = 'update-banner';
    div.innerHTML = '<span class="msg"></span> <a class="btn outline" target="_blank" rel="noopener">Update addon</a>';
    wrap.insertBefore(div, wrap.firstChild);
    updateBanner = div;
    return updateBanner;
  }
  function semverGt(a, b) {
    const pa = String(a||'0.0.0').split('.').map(n=>parseInt(n,10)||0);
    const pb = String(b||'0.0.0').split('.').map(n=>parseInt(n,10)||0);
    for (let i=0;i<Math.max(pa.length,pb.length);i++){
      const x = pa[i]||0, y = pb[i]||0; if (x>y) return true; if (x<y) return false;
    }
    return false;
  }
  function manifestUrl() {
    try { return `${window.location.origin}/manifest.json`; } catch (_) { return 'http://127.0.0.1:55025/manifest.json'; }
  }
  let lastSeenVersion = null;
  let latestVersion = null;
  try { lastSeenVersion = localStorage.getItem('seedsphere.version_seen') || null; } catch (_) {}
  function processServerInfo(v) {
    if (!v) return;
    latestVersion = v;
    if (!lastSeenVersion) { lastSeenVersion = v; try { localStorage.setItem('seedsphere.version_seen', v); } catch(_){} return; }
    if (semverGt(v, lastSeenVersion)) {
      const el = ensureUpdateBanner();
      const msg = el.querySelector('.msg');
      const btn = el.querySelector('a');
      if (msg) msg.textContent = `Update available: ${v}`;
      if (btn) { btn.href = stremioDeepLink(); }
      el.style.display = '';
      // Do not auto-update lastSeenVersion until user interacts; but persist latest known
      try { localStorage.setItem('seedsphere.version_latest', v); } catch(_){}
    }
  }
  function stremioDeepLink() {
    const u = manifestUrl();
    const v = latestVersion || (function(){ try { return localStorage.getItem('seedsphere.version_latest') || ''; } catch(_) { return ''; } })();
    try { return `stremio://addon-install?url=${encodeURIComponent(u)}${v ? `&version=${encodeURIComponent(v)}` : ''}`; } catch(_) { return '#'; }
  }
  if (manifestEl) {
    const host = window.location.host || '127.0.0.1:55025';
    const url = `http://${host}/manifest.json`;
    manifestEl.textContent = url;
  }
  async function checkHealthVersion() {
    try {
      const resp = await fetch('/health');
      if (!resp.ok) return;
      const data = await resp.json();
      if (data && data.version) processServerInfo(String(data.version));
    } catch (_) { /* ignore */ }
  }

  // Load persisted values
  try {
    const savedUrl = localStorage.getItem('seedsphere.trackers_url');
    if (savedUrl && urlInput) urlInput.value = savedUrl;
    const savedVariant = localStorage.getItem('seedsphere.variant');
    if (savedVariant && variantSel) variantSel.value = savedVariant;
    const savedMode = localStorage.getItem('seedsphere.validation_mode');
    if (savedMode && modeSel) modeSel.value = savedMode;
    const savedMax = localStorage.getItem('seedsphere.max_trackers');
    if (savedMax && maxInput) maxInput.value = savedMax;
    const savedLimitEnable = localStorage.getItem('seedsphere.limit_enable');
    if (limitEnable) {
      const enabled = savedLimitEnable === '1';
      limitEnable.checked = enabled;
      if (maxInput) maxInput.disabled = !enabled;
    }
  } catch (_) {}
  if (copyBtn && manifestEl) {
    copyBtn.addEventListener('click', async () => {
      try {
        await navigator.clipboard.writeText(manifestEl.textContent);
        copyBtn.textContent = 'Copied!';
        setTimeout(() => (copyBtn.textContent = 'Copy'), 1200);
      } catch (e) {
        console.warn('Clipboard failed:', e);
      }
    });
  }
  // Initialize manifest text and hide update banner by default
  if (manifestEl) {
    manifestEl.textContent = manifestUrl();
  }
  if (updateBanner) updateBanner.style.display = 'none';

  async function validateUrl() {
    if (!urlInput) return;
    const val = (urlInput.value || '').trim();
    if (!val) {
      setStatus('Please enter a URL to validate.', 'error');
      return;
    }
    setStatus('Validating…');
    try {
      const u = new URL(window.location.origin + '/api/validate');
      u.searchParams.set('url', val);
      const resp = await fetch(u.toString(), { method: 'GET' });
      const data = await resp.json();
      if (data.ok) {
        const sample = Array.isArray(data.sample) ? data.sample : [];
        const pretty = sample.length ? `\nSample:\n- ${sample.join('\n- ')}` : '';
        setStatus(`Looks good! Found ${data.count} entries.${pretty}`, 'success');
      } else {
        setStatus(`Could not validate URL${data.error ? `: ${data.error}` : ''}`, 'error');
      }
    } catch (e) {
      setStatus(`Validation failed: ${e.message}`, 'error');
    }
  }

  function setStatus(msg, kind) {
    if (!resultEl) return;
    resultEl.textContent = msg || '';
    resultEl.classList.remove('success', 'error');
    if (kind === 'success') resultEl.classList.add('success');
    if (kind === 'error') resultEl.classList.add('error');
  }

  if (validateBtn) {
    validateBtn.addEventListener('click', validateUrl);
  }

  // Persist on changes
  if (urlInput) {
    urlInput.addEventListener('change', () => {
      try { localStorage.setItem('seedsphere.trackers_url', (urlInput.value || '').trim()); } catch (_) {}
    });
  }
  if (variantSel) {
    variantSel.addEventListener('change', () => {
      try { localStorage.setItem('seedsphere.variant', variantSel.value); } catch (_) {}
    });
  }
  if (modeSel) {
    modeSel.addEventListener('change', () => {
      try { localStorage.setItem('seedsphere.validation_mode', modeSel.value); } catch (_) {}
    });
  }
  if (maxInput) {
    maxInput.addEventListener('change', () => {
      localStorage.setItem('seedsphere.max_trackers', String(maxInput.value || '0'));
    });
  }
  if (limitEnable && maxInput) {
    limitEnable.addEventListener('change', () => {
      const enabled = !!limitEnable.checked;
      maxInput.disabled = !enabled;
      localStorage.setItem('seedsphere.limit_enable', enabled ? '1' : '0');
    });
  }

  if (healthBtn && healthResult) {
    healthBtn.addEventListener('click', async () => {
      healthBtn.disabled = true;
      healthResult.classList.remove('ok', 'error');
      healthResult.textContent = 'Checking...';
      try {
        const resp = await fetch('/api/trackers/health');
        if (!resp.ok) throw new Error('HTTP ' + resp.status);
        const data = await resp.json();
        const pct = data.total ? Math.round((data.ok / data.total) * 100) : 0;
        healthResult.classList.add('ok');
        healthResult.textContent = `Healthy: ${data.ok}/${data.total} (${pct}%). Cache TTL: ${Math.round((data.ttlMs||0)/3600000)}h.`;
      } catch (e) {
        healthResult.classList.add('error');
        healthResult.textContent = 'Failed to fetch health stats: ' + (e && e.message ? e.message : String(e));
      } finally {
        healthBtn.disabled = false;
      }
    });
  }

  // Quick Sweep helpers
  function variantToUrl(variant) {
    const v = String(variant || 'all').toLowerCase();
    switch (v) {
      case 'best': return 'https://raw.githubusercontent.com/ngosang/trackerslist/master/trackers_best.txt';
      case 'all_udp': return 'https://raw.githubusercontent.com/ngosang/trackerslist/master/trackers_all_udp.txt';
      case 'all_http': return 'https://raw.githubusercontent.com/ngosang/trackerslist/master/trackers_all_http.txt';
      case 'all_ws': return 'https://raw.githubusercontent.com/ngosang/trackerslist/master/trackers_all_ws.txt';
      case 'all_ip': return 'https://raw.githubusercontent.com/ngosang/trackerslist/master/trackers_all_ip.txt';
      case 'best_ip': return 'https://raw.githubusercontent.com/ngosang/trackerslist/master/trackers_best_ip.txt';
      case 'all':
      default: return 'https://raw.githubusercontent.com/ngosang/trackerslist/master/trackers_all.txt';
    }
  }
  async function runSweep() {
    if (!sweepBtn || !sweepResult) return;
    sweepBtn.disabled = true;
    sweepResult.classList.remove('ok', 'error');
    sweepResult.textContent = 'Running sweep...';
    try {
      const custom = (urlInput && urlInput.value || '').trim();
      const variant = (variantSel && variantSel.value) || 'all';
      const url = custom || variantToUrl(variant);
      const mode = (modeSel && modeSel.value) || 'basic';
      const enabled = !!(limitEnable && limitEnable.checked);
      const limit = enabled ? Math.max(0, parseInt((maxInput && maxInput.value) || '0', 10) || 0) : 0;
      const params = new URLSearchParams({ url, mode, limit: String(limit) });
      const resp = await fetch('/api/trackers/sweep?' + params.toString());
      if (!resp.ok) throw new Error('HTTP ' + resp.status);
      const data = await resp.json();
      if (!data.ok) throw new Error(data.error || 'Sweep failed');
      const pct = data.total ? Math.round((data.healthy / data.total) * 100) : 0;
      sweepResult.classList.add('ok');
      const capTxt = (data.limit && data.limit > 0) ? `Showing up to ${data.limit}.` : 'Unlimited.';
      sweepResult.textContent = `Healthy: ${data.healthy}/${data.total} (${pct}%). ${capTxt}`;
    } catch (e) {
      sweepResult.classList.add('error');
      sweepResult.textContent = 'Sweep failed: ' + (e && e.message ? e.message : String(e));
    } finally {
      sweepBtn.disabled = false;
    }
  }
  if (sweepBtn) {
    sweepBtn.addEventListener('click', runSweep);
  }

  // Recent Boosts panel
  function fmtLimit(n) {
    return (!n || n <= 0) ? 'Unlimited' : String(n);
  }
  function truncate(s, n) {
    const t = String(s || '');
    return t.length > n ? t.slice(0, n - 1) + '…' : t;
  }
  function pct(n) { return Math.max(0, Math.min(100, Math.round(n))); }
  function renderList(items) {
    if (!boostsList) return;
    boostsList.innerHTML = '';
    const arr = Array.isArray(items) ? items : [];
    if (arr.length === 0) {
      const li = document.createElement('li');
      li.textContent = 'No recent boosts yet. Play a stream to populate this.';
      boostsList.appendChild(li);
      return;
    }
    for (const it of arr) {
      const li = document.createElement('li');
      const when = it.time ? new Date(it.time).toLocaleString() : '';
      const mode = (it.mode || '').toUpperCase();
      const limit = fmtLimit(it.limit);
      const src = truncate(it.source || '', 80);
      const type = it.type || '-';
      const cid = it.id || '-';
      li.textContent = `${when} — ${type}:${cid} • Healthy ${it.healthy}/${it.total} • Mode: ${mode} • Limit: ${limit} • Source: ${src}`;
      boostsList.appendChild(li);
    }
  }
  function renderMetrics(items) {
    if (!boostsMetrics) return;
    const arr = Array.isArray(items) ? items : [];
    if (arr.length === 0) { boostsMetrics.innerHTML = '<div class="muted">No data yet</div>'; return; }
    const totals = arr.reduce((acc, it) => {
      const total = Number(it.total || 0);
      const healthy = Number(it.healthy || 0);
      const mode = String(it.mode || '').toLowerCase();
      acc.count += 1;
      acc.total += total;
      acc.healthy += healthy;
      const m = acc.modes[mode] || { count: 0, healthy: 0, total: 0 };
      m.count += 1; m.healthy += healthy; m.total += total; acc.modes[mode] = m;
      return acc;
    }, { count: 0, total: 0, healthy: 0, modes: {} });
    const avgTotal = totals.count ? (totals.total / totals.count) : 0;
    const avgHealthy = totals.count ? (totals.healthy / totals.count) : 0;
    const ratio = avgTotal ? (avgHealthy / avgTotal) * 100 : 0;
    const modeRows = Object.entries(totals.modes).map(([mode, m]) => {
      const aT = m.count ? (m.total / m.count) : 0;
      const aH = m.count ? (m.healthy / m.count) : 0;
      const r = aT ? (aH / aT) * 100 : 0;
      const w = pct(r);
      return `<div class="row"><div class="label">Mode ${mode.toUpperCase()} (${m.count})</div><div class="bar"><span style="width:${w}%"></span></div></div>`;
    }).join('');
    boostsMetrics.innerHTML = `
      <div class="row"><div class="label">Requests</div><div>${totals.count}</div></div>
      <div class="row"><div class="label">Avg healthy trackers</div><div>${avgHealthy.toFixed(1)}</div></div>
      <div class="row"><div class="label">Avg total trackers</div><div>${avgTotal.toFixed(1)}</div></div>
      <div class="row"><div class="label">Avg health ratio</div><div>${pct(ratio)}%</div></div>
      ${modeRows}
    `;
  }
  async function loadBoosts() {
    if (!boostsList) return;
    try {
      const resp = await fetch('/api/boosts/recent');
      if (!resp.ok) throw new Error('HTTP ' + resp.status);
      const data = await resp.json();
      if (!data.ok) throw new Error(data.error || 'Load failed');
      const items = Array.isArray(data.items) ? data.items : [];
      renderList(items);
      renderMetrics(items);
    } catch (e) {
      if (boostsList) {
        boostsList.innerHTML = '';
        const li = document.createElement('li');
        li.textContent = 'Failed to load boosts: ' + (e && e.message ? e.message : String(e));
        boostsList.appendChild(li);
      }
      if (boostsMetrics) boostsMetrics.innerHTML = '<div class="muted">Failed to calculate metrics</div>';
    }
  }
  if (boostsRefresh) {
    boostsRefresh.addEventListener('click', loadBoosts);
  }
  // Live updates via SSE with polling fallback
  let sse = null;
  let sseItems = [];
  let sseBackoff = 1000;
  const sseMaxBackoff = 15000;
  function disconnectSSE() {
    if (sse) { try { sse.close(); } catch (_) {} sse = null; }
  }
  function connectSSE() {
    if (!window.EventSource) { startPolling(); return; }
    try {
      disconnectSSE();
      const es = new EventSource('/api/boosts/events');
      sse = es;
      es.addEventListener('server-info', (ev) => {
        try {
          const data = JSON.parse(ev.data || '{}');
          if (data && data.version) processServerInfo(String(data.version));
        } catch (_) {}
      });
      es.addEventListener('snapshot', (ev) => {
        try {
          const data = JSON.parse(ev.data || '{}');
          sseItems = Array.isArray(data.items) ? data.items : [];
          renderList(sseItems);
          renderMetrics(sseItems);
        } catch (_) {}
      });
      es.addEventListener('boost', (ev) => {
        try {
          const item = JSON.parse(ev.data || '{}');
          sseItems.unshift(item);
          if (sseItems.length > 50) sseItems.pop();
          renderList(sseItems);
          renderMetrics(sseItems);
        } catch (_) {}
      });
      es.onerror = () => {
        disconnectSSE();
        stopPolling(); // ensure no duplicate timers
        setTimeout(() => connectSSE(), sseBackoff);
        sseBackoff = Math.min(sseMaxBackoff, sseBackoff * 2);
      };
      es.onopen = () => { sseBackoff = 1000; stopPolling(); };
    } catch (_) {
      startPolling();
    }
  }

  let pollTimer = null;
  function startPolling() {
    if (pollTimer) return;
    loadBoosts();
    pollTimer = setInterval(loadBoosts, 10000);
    // Version polling (lightweight) when SSE is not connected
    checkHealthVersion();
    setTimeout(checkHealthVersion, 15000);
  }
  function stopPolling() {
    if (!pollTimer) return;
    clearInterval(pollTimer);
    pollTimer = null;
  }
  document.addEventListener('visibilitychange', () => {
    if (document.hidden) { stopPolling(); disconnectSSE(); }
    else { connectSSE(); }
  });
  connectSSE();
})();
