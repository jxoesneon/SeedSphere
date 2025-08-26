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
  if (manifestEl) {
    const host = window.location.host || '127.0.0.1:55025';
    const url = `http://${host}/manifest.json`;
    manifestEl.textContent = url;
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
  async function loadBoosts() {
    if (!boostsList) return;
    try {
      const resp = await fetch('/api/boosts/recent');
      if (!resp.ok) throw new Error('HTTP ' + resp.status);
      const data = await resp.json();
      if (!data.ok) throw new Error(data.error || 'Load failed');
      const items = Array.isArray(data.items) ? data.items : [];
      boostsList.innerHTML = '';
      if (items.length === 0) {
        const li = document.createElement('li');
        li.textContent = 'No recent boosts yet. Play a stream to populate this.';
        boostsList.appendChild(li);
        return;
      }
      for (const it of items) {
        const li = document.createElement('li');
        const when = it.time ? new Date(it.time).toLocaleString() : '';
        const mode = (it.mode || '').toUpperCase();
        const limit = fmtLimit(it.limit);
        const src = truncate(it.source || '', 80);
        li.textContent = `${when} — Healthy ${it.healthy}/${it.total} • Mode: ${mode} • Limit: ${limit} • Source: ${src}`;
        boostsList.appendChild(li);
      }
    } catch (e) {
      if (boostsList) {
        boostsList.innerHTML = '';
        const li = document.createElement('li');
        li.textContent = 'Failed to load boosts: ' + (e && e.message ? e.message : String(e));
        boostsList.appendChild(li);
      }
    }
  }
  if (boostsRefresh) {
    boostsRefresh.addEventListener('click', loadBoosts);
  }
  // Auto-load once on page open
  loadBoosts();
})();
