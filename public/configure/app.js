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
  const shareCopyBtn = document.getElementById('shareCopyBtn');
  const allowlistEl = document.getElementById('allowlist');
  const blocklistEl = document.getElementById('blocklist');
  const presetDefaultBtn = document.getElementById('presetDefault');
  const presetMinimalBtn = document.getElementById('presetMinimal');
  const presetAggressiveBtn = document.getElementById('presetAggressive');
  const installBtn = document.getElementById('installBtn');
  const manualTbody = document.getElementById('manualTbody');
  const manualNewInput = document.getElementById('manualNewInput');
  const manualAddRowBtn = document.getElementById('manualAddRowBtn');
  const manualCancelBtn = document.getElementById('manualCancelBtn');
  const manualSaveBtn = document.getElementById('manualSaveBtn');
  const manualRevertBtn = document.getElementById('manualRevertBtn');
  const manualMergeModeSel = document.getElementById('manualMergeMode');
  const manualImportBtn = document.getElementById('manualImportBtn');
  const manualExportBtn = document.getElementById('manualExportBtn');
  const manualStrictCk = document.getElementById('manualStrict');
  const manualAutoSaveCk = document.getElementById('manualAutoSave');
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
    const savedAllow = localStorage.getItem('seedsphere.allowlist');
    if (savedAllow && allowlistEl) allowlistEl.value = savedAllow;
    const savedBlock = localStorage.getItem('seedsphere.blocklist');
    if (savedBlock && blocklistEl) blocklistEl.value = savedBlock;
    const savedMerge = localStorage.getItem('seedsphere.manual_merge_mode');
    if (savedMerge && manualMergeModeSel) manualMergeModeSel.value = savedMerge;
    const savedStrict = localStorage.getItem('seedsphere.manual_strict');
    if (manualStrictCk) manualStrictCk.checked = savedStrict === '1';
    const savedAuto = localStorage.getItem('seedsphere.manual_autosave');
    if (manualAutoSaveCk) manualAutoSaveCk.checked = savedAuto === '1';
  } catch (_) {}

  // Presets
  const PRESET_KEY = 'seedsphere.preset';
  const presets = {
    default: { variant: 'all', validation_mode: 'basic', limit_enable: false, max_trackers: 0, trackers_url: '', allowlist: '', blocklist: '' },
    minimal: { variant: 'best', validation_mode: 'off', limit_enable: true, max_trackers: 30, trackers_url: '', allowlist: '', blocklist: '' },
    aggressive: { variant: 'all', validation_mode: 'aggressive', limit_enable: true, max_trackers: 0, trackers_url: '', allowlist: '', blocklist: '' },
  };
  function applyPreset(name) {
    const p = presets[name];
    if (!p) return;
    if (variantSel) variantSel.value = p.variant;
    if (modeSel) modeSel.value = p.validation_mode;
    if (limitEnable) {
      limitEnable.checked = !!p.limit_enable;
      if (maxInput) maxInput.disabled = !limitEnable.checked;
    }
    if (maxInput) maxInput.value = String(p.max_trackers || 0);
    if (urlInput) urlInput.value = p.trackers_url || '';
    if (allowlistEl) allowlistEl.value = p.allowlist || '';
    if (blocklistEl) blocklistEl.value = p.blocklist || '';
    // persist
    try {
      localStorage.setItem('seedsphere.variant', p.variant);
      localStorage.setItem('seedsphere.validation_mode', p.validation_mode);
      localStorage.setItem('seedsphere.limit_enable', p.limit_enable ? '1' : '0');
      localStorage.setItem('seedsphere.max_trackers', String(p.max_trackers || 0));
      localStorage.setItem('seedsphere.trackers_url', p.trackers_url || '');
      localStorage.setItem('seedsphere.allowlist', p.allowlist || '');
      localStorage.setItem('seedsphere.blocklist', p.blocklist || '');
      localStorage.setItem(PRESET_KEY, name);
    } catch (_) {}
  }
  if (presetDefaultBtn) presetDefaultBtn.addEventListener('click', () => applyPreset('default'));
  if (presetMinimalBtn) presetMinimalBtn.addEventListener('click', () => applyPreset('minimal'));
  if (presetAggressiveBtn) presetAggressiveBtn.addEventListener('click', () => applyPreset('aggressive'));
  if (installBtn) {
    installBtn.addEventListener('click', () => {
      const link = stremioDeepLink();
      navigateProtocol(link);
      // Record last seen to hide update banner after interaction
      if (latestVersion) { try { localStorage.setItem('seedsphere.version_seen', latestVersion); } catch (_) {} }
    });
  }

  // Manual Trackers Editor (batch edit with Save/Cancel)
  const MANUAL_KEY = 'seedsphere.manual_trackers';
  function loadManual() {
    try {
      const raw = localStorage.getItem(MANUAL_KEY);
      if (!raw) return [];
      const arr = JSON.parse(raw);
      return Array.isArray(arr) ? arr.map((s) => String(s)) : [];
    } catch (_) { return []; }
  }
  function saveManual(list) {
    try { localStorage.setItem(MANUAL_KEY, JSON.stringify(list)); } catch (_) {}
  }
  function isValidTracker(str) {
    return /^(udp|http|https|ws):\/\//i.test(String(str || '').trim());
  }
  function getHost(u) {
    try {
      if (/^(http|https|ws):\/\//i.test(u)) { return new URL(u).hostname.toLowerCase(); }
      if (/^udp:\/\//i.test(u)) {
        const rest = u.slice(6); // after udp://
        const host = rest.split(/[/:]/)[0];
        return String(host || '').toLowerCase();
      }
    } catch (_) {}
    return '';
  }
  function parseListTextarea(val) {
    return String(val || '')
      .split('\n')
      .map((t) => t.trim().toLowerCase())
      .filter(Boolean);
  }
  function hostMatches(host, entry) {
    if (!host || !entry) return false;
    if (host === entry) return true;
    return host.endsWith('.' + entry);
  }
  function applyAllowBlock(urls) {
    const allows = parseListTextarea(allowlistEl ? allowlistEl.value : '');
    const blocks = parseListTextarea(blocklistEl ? blocklistEl.value : '');
    const out = [];
    for (const s of urls) {
      const h = getHost(s);
      if (!h) continue;
      if (allows.length > 0 && !allows.some((e) => hostMatches(h, e))) continue; // not allowed
      if (blocks.some((e) => hostMatches(h, e))) continue; // blocked
      out.push(s);
    }
    return out;
  }
  function parseTrackersText(text) {
    return (String(text || '')
      .split('\n')
      .map((t) => t.trim())
      .filter((t) => t && !t.startsWith('#')));
  }
  function unique(arr) {
    const seen = new Set();
    const out = [];
    for (const s of arr) { const k = String(s); if (!seen.has(k)) { seen.add(k); out.push(k); } }
    return out;
  }
  // Keep the latest healthy list to support live recompute without refetching
  let lastHealthy = [];
  // Single-source mode: 'manual' when saved manual list is non-empty; otherwise 'sweep'
  let currentSource = 'manual';
  // Recompute merged preview when filters change and we have a recent healthy list
  function recomputeFromFiltersIfPossible() {
    if (lastHealthy && lastHealthy.length > 0 && manualMergeModeSel) {
      const filtered = applyAllowBlock(lastHealthy);
      const modeMerge = manualMergeModeSel.value;
      const manual = loadManual();
      const merged = modeMerge === 'replace' ? filtered.slice() : unique(manual.concat(filtered));
      manualEditing = merged.slice();
      editingRows.clear();
      renderManual();
    }
  }
  let manualEditing = loadManual();
  // Set initial source based on saved manual list
  currentSource = (Array.isArray(manualEditing) && manualEditing.length > 0) ? 'manual' : 'sweep';
  const editingRows = new Set();
  
  function renderManual() {
    if (!manualTbody) return;
    manualTbody.innerHTML = '';
    if (!Array.isArray(manualEditing) || manualEditing.length === 0) {
      const tr = document.createElement('tr');
      const td = document.createElement('td');
      td.colSpan = 3;
      td.className = 'muted';
      td.textContent = 'No trackers yet. Add one below or run a quick sweep to populate.';
      tr.appendChild(td);
      manualTbody.appendChild(tr);
      return;
    }
    manualEditing.forEach((value, idx) => {
      const tr = document.createElement('tr');
      const tdNum = document.createElement('td');
      tdNum.className = 'col-num';
      tdNum.textContent = String(idx + 1);
      const tdUrl = document.createElement('td');
      const tdAct = document.createElement('td');
      tdAct.className = 'actions';

      if (editingRows.has(idx)) {
        const input = document.createElement('input');
        input.type = 'text';
        input.value = value;
        input.placeholder = 'udp://tracker.example:80/announce';
        input.className = 'track-input';
        input.setAttribute('aria-label', 'Tracker URL');
        input.addEventListener('input', () => {
          manualEditing[idx] = input.value;
          input.classList.toggle('invalid', !!input.value && !isValidTracker(input.value));
        });
        input.classList.toggle('invalid', !!input.value && !isValidTracker(input.value));
        tdUrl.appendChild(input);
        const done = document.createElement('button');
        done.type = 'button'; done.className = 'btn small'; done.innerHTML = '<span class="icon" data-icon="check"></span>Done';
        done.addEventListener('click', () => { editingRows.delete(idx); renderManual(); });
        const del = document.createElement('button');
        del.type = 'button'; del.className = 'btn outline small'; del.innerHTML = '<span class="icon" data-icon="trash"></span>';
        del.setAttribute('aria-label', 'Delete');
        del.title = 'Delete';
        del.addEventListener('click', () => { manualEditing.splice(idx, 1); renderManual(); });
        tdAct.appendChild(done);
        tdAct.appendChild(del);
      } else {
        const span = document.createElement('span');
        span.textContent = String(value || '');
        span.style.fontFamily = "ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, 'Liberation Mono', 'Courier New', monospace";
        tdUrl.appendChild(span);
        const edit = document.createElement('button');
        edit.type = 'button'; edit.className = 'btn small'; edit.innerHTML = '<span class="icon" data-icon="pencil-square"></span>';
        edit.setAttribute('aria-label', 'Edit');
        edit.title = 'Edit';
        edit.addEventListener('click', () => { editingRows.add(idx); renderManual(); });
        const del = document.createElement('button');
        del.type = 'button'; del.className = 'btn outline small'; del.innerHTML = '<span class="icon" data-icon="trash"></span>';
        del.setAttribute('aria-label', 'Delete');
        del.title = 'Delete';
        del.addEventListener('click', () => { manualEditing.splice(idx, 1); renderManual(); });
        tdAct.appendChild(edit);
        tdAct.appendChild(del);
      }

      tr.appendChild(tdNum);
      tr.appendChild(tdUrl);
      tr.appendChild(tdAct);
      manualTbody.appendChild(tr);
    });
  }
  function addManualRowFromInput() {
    if (!manualNewInput) return;
    const val = String(manualNewInput.value || '').trim();
    if (!val) return;
    manualEditing.push(val);
    manualNewInput.value = '';
    renderManual();
  }
  if (manualAddRowBtn) manualAddRowBtn.addEventListener('click', addManualRowFromInput);
  if (manualNewInput) manualNewInput.addEventListener('keydown', (e) => { if (e.key === 'Enter') { e.preventDefault(); addManualRowFromInput(); } });
  if (manualCancelBtn) manualCancelBtn.addEventListener('click', () => {
    manualEditing = loadManual();
    editingRows.clear();
    // Update source based on saved content
    currentSource = (Array.isArray(manualEditing) && manualEditing.length > 0) ? 'manual' : 'sweep';
    renderManual();
    if (currentSource === 'sweep') { try { runSweep(); } catch (_) {} }
  });
  if (manualRevertBtn) manualRevertBtn.addEventListener('click', () => {
    manualEditing = loadManual();
    editingRows.clear();
    currentSource = (Array.isArray(manualEditing) && manualEditing.length > 0) ? 'manual' : 'sweep';
    renderManual();
    if (currentSource === 'sweep') { try { runSweep(); } catch (_) {} }
  });
  if (manualSaveBtn) manualSaveBtn.addEventListener('click', () => {
    // trim empties and ensure simple validity (but still allow saving invalid to let user refine)
    manualEditing = manualEditing.map((s) => String(s).trim()).filter((s) => s.length > 0);
    if (manualStrictCk && manualStrictCk.checked) {
      const invalidIdx = manualEditing.findIndex((s) => !isValidTracker(s));
      if (invalidIdx !== -1) {
        alert('Strict validation failed: some entries are not valid tracker URLs.');
        editingRows.add(invalidIdx);
        renderManual();
        return;
      }
    }
    saveManual(manualEditing);
    editingRows.clear();
    // Update source post-save
    currentSource = (Array.isArray(manualEditing) && manualEditing.length > 0) ? 'manual' : 'sweep';
    renderManual();
    if (currentSource === 'sweep') { try { runSweep(); } catch (_) {} }
    // Provide lightweight feedback
    try { manualSaveBtn.textContent = 'Saved!'; setTimeout(() => manualSaveBtn.textContent = 'Save changes', 1200); } catch (_) {}
  });
  if (manualMergeModeSel) {
    manualMergeModeSel.addEventListener('change', () => {
      try { localStorage.setItem('seedsphere.manual_merge_mode', manualMergeModeSel.value); } catch (_) {}
      // If we have a recent healthy list, recompute merged preview live without refetching
      if (currentSource === 'sweep' && lastHealthy && lastHealthy.length > 0) {
        const modeMerge = manualMergeModeSel.value;
        const manual = loadManual();
        const filtered = applyAllowBlock(lastHealthy);
        const merged = modeMerge === 'replace' ? filtered.slice() : unique(manual.concat(filtered));
        manualEditing = merged.slice();
        editingRows.clear();
        renderManual();
      }
    });
  }
  if (manualStrictCk) {
    manualStrictCk.addEventListener('change', () => {
      try { localStorage.setItem('seedsphere.manual_strict', manualStrictCk.checked ? '1' : '0'); } catch (_) {}
    });
  }
  if (manualAutoSaveCk) {
    manualAutoSaveCk.addEventListener('change', () => {
      try { localStorage.setItem('seedsphere.manual_autosave', manualAutoSaveCk.checked ? '1' : '0'); } catch (_) {}
    });
  }
  // Persist allow/block and live recompute preview when edited
  if (allowlistEl) allowlistEl.addEventListener('input', () => { try { localStorage.setItem('seedsphere.allowlist', allowlistEl.value); } catch (_) {} ; if (currentSource === 'sweep') recomputeFromFiltersIfPossible(); });
  if (blocklistEl) blocklistEl.addEventListener('input', () => { try { localStorage.setItem('seedsphere.blocklist', blocklistEl.value); } catch (_) {} ; if (currentSource === 'sweep') recomputeFromFiltersIfPossible(); });

  // When using sweep as the source, changes to variant/custom/mode/limit should trigger a fresh sweep
  function maybeAutoSweep() { if (currentSource === 'sweep') { try { runSweep(); } catch (_) {} } }
  const reSweepEvents = ['change', 'input'];
  if (variantSel) reSweepEvents.forEach(ev => variantSel.addEventListener(ev, maybeAutoSweep));
  if (urlInput) reSweepEvents.forEach(ev => urlInput.addEventListener(ev, maybeAutoSweep));
  if (modeSel) reSweepEvents.forEach(ev => modeSel.addEventListener(ev, maybeAutoSweep));
  if (limitEnable) reSweepEvents.forEach(ev => limitEnable.addEventListener(ev, maybeAutoSweep));
  if (maxInput) reSweepEvents.forEach(ev => maxInput.addEventListener(ev, maybeAutoSweep));
  
  // Initial render of manual table on load (single-source)
  renderManual();
  // Auto-load effective trackers on page load when using sweep source
  if (currentSource === 'sweep' && typeof runSweep === 'function') {
    setTimeout(() => { runSweep(); }, 50);
  }
  if (manualImportBtn) {
    manualImportBtn.addEventListener('click', async () => {
      const text = prompt('Paste tracker list (one per line). Lines starting with # are ignored.');
      if (text == null) return;
      const items = parseTrackersText(text);
      if (items.length === 0) return;
      const action = confirm('OK = Replace current list\nCancel = Append to current list') ? 'replace' : 'append';
      if (action === 'replace') manualEditing = items;
      else manualEditing = manualEditing.concat(items);
      currentSource = 'manual';
      renderManual();
    });
  }
  if (manualExportBtn) {
    manualExportBtn.addEventListener('click', () => {
      const list = loadManual().map((s) => String(s).trim()).filter(Boolean);
      const blob = new Blob([list.join('\n') + '\n'], { type: 'text/plain;charset=utf-8' });
      const url = URL.createObjectURL(blob);
      const a = document.createElement('a'); a.href = url; a.download = 'trackers-manual.txt';
      document.body.appendChild(a); a.click(); a.remove();
      setTimeout(() => URL.revokeObjectURL(url), 1000);
    });
  }
  // Initial render
  renderManual();

  // Apply URL params (override persisted) for shareable links
  (function applyParamsFromUrl(){
    try {
      const p = new URLSearchParams(window.location.search || '');
      if (p.has('preset')) {
        const name = String(p.get('preset') || '').toLowerCase();
        if (name && presets[name]) {
          applyPreset(name);
        }
      }
      if (p.has('variant') && variantSel) {
        variantSel.value = p.get('variant');
      }
      if (p.has('trackers_url') && urlInput) {
        urlInput.value = p.get('trackers_url');
      }
      if (p.has('validation_mode') && modeSel) {
        modeSel.value = p.get('validation_mode');
      }
      if (p.has('limit_enable') && limitEnable) {
        const en = p.get('limit_enable') === '1' || p.get('limit_enable') === 'true';
        limitEnable.checked = en;
        if (maxInput) maxInput.disabled = !en;
      }
      if (p.has('max_trackers') && maxInput) {
        maxInput.value = String(parseInt(p.get('max_trackers'), 10) || 0);
      }
      if (p.has('allowlist') && allowlistEl) {
        allowlistEl.value = p.get('allowlist');
      }
      if (p.has('blocklist') && blocklistEl) {
        blocklistEl.value = p.get('blocklist');
      }
    } catch (_) {}
  })();
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
  if (allowlistEl) {
    allowlistEl.addEventListener('change', () => {
      try { localStorage.setItem('seedsphere.allowlist', allowlistEl.value || ''); } catch (_) {}
    });
  }
  if (blocklistEl) {
    blocklistEl.addEventListener('change', () => {
      try { localStorage.setItem('seedsphere.blocklist', blocklistEl.value || ''); } catch (_) {}
    });
  }

  // Share link: build URL with current values and copy
  function buildShareUrl() {
    try {
      const u = new URL(window.location.href);
      u.search = '';
      const params = new URLSearchParams();
      // include preset if one was applied
      let lastPreset = '';
      try { lastPreset = localStorage.getItem(PRESET_KEY) || ''; } catch (_) {}
      if (lastPreset) params.set('preset', lastPreset);
      if (variantSel && variantSel.value) params.set('variant', variantSel.value);
      const turl = (urlInput && urlInput.value || '').trim();
      if (turl) params.set('trackers_url', turl);
      if (modeSel && modeSel.value) params.set('validation_mode', modeSel.value);
      const en = !!(limitEnable && limitEnable.checked);
      params.set('limit_enable', en ? '1' : '0');
      const max = (maxInput && maxInput.value) ? String(parseInt(maxInput.value, 10) || 0) : '0';
      params.set('max_trackers', max);
      const allow = (allowlistEl && allowlistEl.value || '').trim();
      if (allow) params.set('allowlist', allow);
      const block = (blocklistEl && blocklistEl.value || '').trim();
      if (block) params.set('blocklist', block);
      u.search = params.toString();
      return u.toString();
    } catch (_) {
      return window.location.href;
    }
  }
  if (shareCopyBtn) {
    shareCopyBtn.addEventListener('click', async () => {
      try {
        const link = buildShareUrl();
        await navigator.clipboard.writeText(link);
        shareCopyBtn.textContent = 'Link copied!';
        setTimeout(() => (shareCopyBtn.textContent = 'Copy share link'), 1400);
      } catch (e) {
        console.warn('Share copy failed:', e);
      }
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
      const params = new URLSearchParams({ url, mode, limit: String(limit), full: '1' });
      const resp = await fetch('/api/trackers/sweep?' + params.toString());
      if (!resp.ok) throw new Error('HTTP ' + resp.status);
      const data = await resp.json();
      if (!data.ok) throw new Error(data.error || 'Sweep failed');
      const pct = data.total ? Math.round((data.healthy / data.total) * 100) : 0;
      // Merge with manual trackers per selected mode (for live population)
      const modeMerge = manualMergeModeSel ? manualMergeModeSel.value : 'append';
      const manual = loadManual();
      // Prefer full list, but fall back to sample if server didn't include list
      const healthyListRaw = Array.isArray(data.list) ? data.list : (Array.isArray(data.sample) ? data.sample : []);
      // Apply allow/block filters before merge
      lastHealthy = healthyListRaw.slice();
      const healthyList = applyAllowBlock(lastHealthy);
      const merged = modeMerge === 'replace' ? healthyList.slice() : unique(manual.concat(healthyList));
      // Build a downloadable .txt of merged
      const blob = new Blob([(merged.join('\n') + '\n')], { type: 'text/plain;charset=utf-8' });
      const dlUrl = URL.createObjectURL(blob);
      sweepResult.classList.add('ok');
      const capTxt = (data.limit && data.limit > 0) ? `Showing up to ${data.limit}.` : 'Unlimited.';
      sweepResult.innerHTML = `Healthy: ${data.healthy}/${data.total} (${pct}%). ${capTxt} Merged (${modeMerge}): ${merged.length} trackers. `;
      const link = document.createElement('a');
      link.href = dlUrl; link.download = 'trackers-merged.txt'; link.className = 'btn outline'; link.style.marginLeft = '8px';
      link.textContent = 'Download merged (.txt)';
      sweepResult.appendChild(link);
      // Live-populate the Manual Trackers editor in-memory (optionally auto-save)
      manualEditing = merged.slice();
      editingRows.clear();
      renderManual();
      if (manualAutoSaveCk && manualAutoSaveCk.checked) {
        saveManual(manualEditing);
      }
      // Revoke URL after a while
      setTimeout(() => URL.revokeObjectURL(dlUrl), 60000);
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
