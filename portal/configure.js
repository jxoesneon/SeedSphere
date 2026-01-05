/**
 * SeedSphere Configuration Portal Logic
 * optimized for TV Control and Glassmorphism UI
 */

const state = {
    deviceId: null,
    isLinked: false,
    user: null,
    neighbors: 0,
    owner: 'None'
};

const dom = {
    loading: document.getElementById('loading'),
    badge: document.getElementById('status-badge'),
    deviceIdBox: document.getElementById('device-id-box'),
    neighbors: document.getElementById('neighbors-val'),
    proof: document.getElementById('proof-val'),
    ownerEmail: document.getElementById('owner-email'),
    btnLogin: document.getElementById('btn-login'),
    btnLink: document.getElementById('btn-link'),
    btnUnlink: document.getElementById('btn-unlink'),
    error: document.getElementById('error-msg')
};

async function init() {
    const params = new URLSearchParams(window.location.search);
    state.deviceId = params.get('id');

    if (!state.deviceId) {
        showError("Invalid Device ID. Please open from Stremio.");
        hideLoading();
        return;
    }

    dom.deviceIdBox.textContent = `HEX ID: ${state.deviceId}`;
    
    await Promise.all([
        updateStatus(),
        checkAuth()
    ]);

    render();
    hideLoading();
}

async function updateStatus() {
    try {
        const resp = await fetch(`/api/devices/${state.deviceId}/status`);
        const data = await resp.json();
        
        if (data.ok) {
            state.isLinked = data.linked;
            state.neighbors = data.neighbors;
            state.owner = data.owner;
        }
    } catch (e) {
        console.error("Status check failed", e);
    }
}

async function checkAuth() {
    try {
        const resp = await fetch('/api/auth/session');
        const data = await resp.json();
        if (data.ok && data.user) {
            state.user = data.user;
        }
    } catch (e) {
        console.error("Auth check failed", e);
    }
}

function render() {
    // Status Badge
    dom.badge.textContent = state.isLinked ? '● Connected' : '○ Unlinked';
    dom.badge.className = `status-badge ${state.isLinked ? 'linked' : 'unlinked'}`;

    // Stats
    dom.neighbors.textContent = state.neighbors;
    dom.proof.textContent = state.isLinked ? 'Verified' : 'Pending';
    dom.ownerEmail.textContent = state.owner;

    // Actions
    dom.btnLogin.classList.add('hidden');
    dom.btnLink.classList.add('hidden');
    dom.btnUnlink.classList.add('hidden');

    if (!state.user) {
        dom.btnLogin.classList.remove('hidden');
    } else if (!state.isLinked) {
        dom.btnLink.classList.remove('hidden');
    } else {
        dom.btnUnlink.classList.remove('hidden');
    }

    // Auto-focus for TV
    const visibleBtn = [dom.btnLogin, dom.btnLink, dom.btnUnlink].find(b => !b.classList.contains('hidden'));
    if (visibleBtn) visibleBtn.focus();
}

/** Actions */

dom.btnLogin.onclick = () => {
    const redirect = encodeURIComponent(window.location.href);
    window.location.href = `/api/auth/google/start?redirect=${redirect}`;
};

dom.btnLink.onclick = async () => {
    showLoading();
    try {
        // 1. Get a linking token for the CURRENT logged-in user
        const tokenResp = await fetch('/api/auth/token');
        const tokenData = await tokenResp.json();

        if (!tokenData.ok) throw new Error("Failed to generate linking token. Are you logged in?");

        // 2. Complete Binding using that token and the target Device ID (seedling_id)
        const completeResp = await fetch('/api/link/complete', {
            method: 'POST',
            body: JSON.stringify({
                token: tokenData.token,
                seedling_id: state.deviceId
            })
        });
        
        const completeData = await completeResp.json();
        if (completeData.ok) {
            window.location.reload();
        } else {
            showError("Linking failed: " + (completeData.error || "Unknown"));
        }
    } catch (e) {
        showError(e.message);
    } finally {
        hideLoading();
    }
};

dom.btnUnlink.onclick = async () => {
    if (!confirm("Are you sure you want to unlink this device?")) return;
    showLoading();
    try {
        const resp = await fetch(`/api/devices/${state.deviceId}/unlink`, { method: 'POST' });
        const data = await resp.json();
        if (data.ok) {
            window.location.reload();
        } else {
            showError("Unlink failed: " + (data.error || "Unknown"));
        }
    } catch (e) {
        showError(e.message);
    } finally {
        hideLoading();
    }
};

function showLoading() {
    dom.loading.classList.remove('transparent');
    dom.loading.classList.remove('hidden');
}

function hideLoading() {
    dom.loading.classList.add('transparent');
    setTimeout(() => dom.loading.classList.add('hidden'), 500);
}

function showError(msg) {
    dom.error.textContent = msg;
    dom.error.classList.remove('hidden');
}

// Key handling for TV Remotes
window.onkeydown = (e) => {
    if (e.key === 'ArrowUp' || e.key === 'ArrowDown') {
        // Native tab cycle usually works, but we can enhance it
    }
};

init();
