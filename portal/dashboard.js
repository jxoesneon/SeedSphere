// Dashboard JavaScript

document.addEventListener('DOMContentLoaded', () => {
    // Load user data
    loadUserData();

    // Setup navigation
    setupDashboardNav();

    // Setup interactions
    setupInteractions();
});

// Dynamic API Base URL
const API_BASE = (window.location.hostname === 'localhost' || window.location.hostname === '127.0.0.1')
    ? 'http://localhost:8080'
    : 'https://seedsphere-router.fly.dev';


/**
 * Fetches the current user session and updates the dashboard state.
 * Handles Guest vs Logged In views and loads user settings.
 */
async function loadUserData() {
    // API_BASE is global


    try {
        const res = await fetch(`${API_BASE}/api/auth/session`);
        const data = await res.json();


        // Check for login triggers
        const urlParams = new URLSearchParams(window.location.search);
        const shouldShowLogin = urlParams.get('login') === 'sw' || window.location.hash === '#login';

        if (data.ok && data.user) {
            // Logged in
            document.getElementById('login-overlay').style.display = 'none';
            document.getElementById('main-dashboard').style.filter = 'none';
            updateUI(data.user);
            fetchStats();

            // Load Linking Token & Settings
            try {
                const tokenRes = await fetch(`${API_BASE}/api/auth/token`);
                const tokenData = await tokenRes.json();
                if (tokenData.ok) {
                    const el = document.getElementById('linking-token');
                    if (el) el.textContent = tokenData.token;
                }

                if (data.user.settings) {
                    if (data.user.settings.rd_key) document.getElementById('rd-key').value = data.user.settings.rd_key;
                    if (data.user.settings.ad_key) document.getElementById('ad-key').value = data.user.settings.ad_key;
                }
            } catch (e) { console.error('Failed to load user extras', e); }
        } else {
            // Not logged in (Strict Mode)
            // Show overlay, keep background blurred
            document.getElementById('login-overlay').style.display = 'flex';
            document.getElementById('main-dashboard').style.filter = 'blur(10px)';

            // Clean URL but keep overlay
            if (shouldShowLogin) {
                window.history.replaceState({}, document.title, window.location.pathname);
            }

            updateUI(null);
        }
    } catch (e) {
        console.error('Auth check failed:', e);
        // Fail safe: show login
        document.getElementById('login-overlay').style.display = 'flex';
        document.getElementById('main-dashboard').style.filter = 'blur(10px)';
    }
}

/**
 * Updates the Dashboard UI elements based on auth state.
 * @param {Object|null} user - The user object from session or null if guest.
 */
function updateUI(user) {
    const gardenerIdElement = document.getElementById('gardener-id');
    const userIdElement = document.getElementById('user-id');
    const logoutBtn = document.querySelector('.btn-logout');

    if (user) {
        // Logged In State
        const displayId = user.email || user.id.split(':')[1] || user.id;
        if (gardenerIdElement) gardenerIdElement.textContent = displayId;
        if (userIdElement) userIdElement.textContent = user.email ? user.email.split('@')[0] : 'User';

        if (logoutBtn) {
            logoutBtn.textContent = 'Sign Out';
            logoutBtn.onclick = async () => {
                await fetch(`${API_BASE}/api/auth/logout`, { method: 'POST' });
                window.location.reload();
            };
        }
    } else {
        // Guest State
        if (gardenerIdElement) gardenerIdElement.textContent = 'Guest Access';
        if (userIdElement) userIdElement.textContent = 'Not Signed In';

        if (logoutBtn) {
            logoutBtn.textContent = 'Sign In';
            logoutBtn.onclick = () => {
                document.getElementById('login-overlay').style.display = 'flex';
            };
        }
    }
}

/**
 * Loads network statistics (node count, data shared) for display.
 */
async function fetchStats() {
    // Legacy mock stats or fetch from real API if available
    const stats = {
        nodes: 47,
        dataShared: 1247,
        uptime: 127
    };
    document.getElementById('nodes-count').textContent = stats.nodes;
    document.getElementById('data-shared').textContent = `${stats.dataShared} MB`;
    document.getElementById('uptime').textContent = `${stats.uptime}h`;
}

/**
 * Sets up the sidebar navigation tab switching logic.
 */
function setupDashboardNav() {
    const navItems = document.querySelectorAll('.nav-item');
    const sections = document.querySelectorAll('.dashboard-section');

    navItems.forEach(item => {
        item.addEventListener('click', (e) => {
            e.preventDefault();

            // Remove active class from all items
            navItems.forEach(nav => nav.classList.remove('active'));

            // Add active class to clicked item
            item.classList.add('active');

            // Hide all sections
            sections.forEach(section => section.style.display = 'none');

            // Show target section
            const targetId = item.getAttribute('href').substring(1);
            const targetSection = document.getElementById(targetId);
            if (targetSection) {
                targetSection.style.display = 'block';
            }
        });
    });
}

/**
 * Initializes interactive elements: forms, buttons, and action cards.
 */
function setupInteractions() {
    // Magic Link Form
    const magicForm = document.getElementById('magic-link-form');
    if (magicForm) {
        magicForm.addEventListener('submit', async (e) => {
            e.preventDefault();
            const email = document.getElementById('magic-email').value;
            const statusFn = document.getElementById('magic-status');

            try {
                statusFn.textContent = 'Sending magic link...';
                await fetch(`${API_BASE}/api/auth/magic/start`, {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({ email })
                });
                statusFn.textContent = 'Check your email for the sign-in link!';
                statusFn.style.color = '#4ade80';
            } catch (err) {
                statusFn.textContent = 'Failed to send link. Try again.';
                statusFn.style.color = '#ef4444';
            }
        });
    }

    // Logout/Login button logic moved to updateUI for dynamic state handling

    // Save API keys
    // Save API keys
    const saveBtns = document.querySelectorAll('.btn-save');
    saveBtns.forEach(btn => {
        btn.addEventListener('click', async (e) => {
            e.preventDefault();
            const input = btn.previousElementSibling;
            const keyId = input.id;
            const keyMap = { 'rd-key': 'rd_key', 'ad-key': 'ad_key' };
            const keyType = keyMap[keyId];

            if (!keyType) return;

            btn.textContent = 'Saving...';
            try {
                await fetch(`${API_BASE}/api/auth/settings`, {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({ [keyType]: input.value })
                });
                btn.textContent = 'Saved!';
            } catch (err) {
                btn.textContent = 'Error';
            }

            setTimeout(() => {
                btn.textContent = 'Save';
            }, 2000);
        });
    });

    // Copy Token
    const copyBtn = document.querySelector('.btn-copy');
    if (copyBtn) {
        copyBtn.addEventListener('click', () => {
            const token = document.getElementById('linking-token').textContent;
            navigator.clipboard.writeText(token);
            copyBtn.textContent = 'Copied!';
            setTimeout(() => copyBtn.textContent = 'Copy', 2000);
        });
    }

    // Danger Zone
    const dangerBtns = document.querySelectorAll('.btn-danger');
    if (dangerBtns.length >= 2) {
        // Unlink
        dangerBtns[0].addEventListener('click', async () => {
            if (confirm('Unlink all devices from this account?')) {
                await fetch(`${API_BASE}/api/auth/unlink`, { method: 'POST' });
                alert('Devices unlinked.');
                window.location.reload();
            }
        });

        // Delete
        dangerBtns[1].addEventListener('click', async () => {
            const confirmed = prompt('Type "DELETE" to confirm account deletion. This cannot be undone.');
            if (confirmed === 'DELETE') {
                await fetch(`${API_BASE}/api/auth/account`, { method: 'DELETE' });
                window.location.reload();
            }
        });
    }

    // Quick action cards
    const actionCards = document.querySelectorAll('.action-card');
    actionCards.forEach((card, index) => {
        card.addEventListener('click', () => {
            const actions = [
                () => {
                    // Link new device
                    alert('Generate QR code for device linking');
                },
                () => {
                    // Refresh P2P status
                    loadUserData();
                    alert('P2P status refreshed!');
                },
                () => {
                    // Download APK
                    window.location.href = '/downloads/seedsphere-gardener-v2.0.0.apk';
                },
                () => {
                    // View API docs
                    window.location.href = 'docs.html';
                }
            ];

            if (actions[index]) {
                actions[index]();
            }
        });
    });
    // Install Addon (Stremio)
    const installBtn = document.querySelector('.btn-install-addon'); // We need to add this class to the button in dashboard.html
    if (installBtn) {
        installBtn.addEventListener('click', async () => {
            try {
                const res = await fetch(`${API_BASE}/api/auth/session`);
                const data = await res.json();
                if (data.ok && data.user) {
                    const userId = data.user.id.split(':')[1] || data.user.id;
                    // Format: stremio://<host>/u/<userId>/manifest.json
                    const host = new URL(API_BASE).host;

                    // For localhost dev, usage: stremio://localhost:8080/u/magic:xxx/manifest.json
                    const manifestUrl = `stremio://${host}/u/${userId}/manifest.json`;

                    window.location.href = manifestUrl;
                } else {
                    alert('Please sign in first.');
                }
            } catch (e) {
                console.error('Install failed', e);
            }
        });
    }
}
