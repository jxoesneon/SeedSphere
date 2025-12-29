// SeedSphere Portal — Interactive Features

document.addEventListener('DOMContentLoaded', () => {
    // Platform Detection for Auto-Download
    detectPlatform();

    // Smooth Scroll
    setupSmoothScroll();

    // Network Animation
    animateNetwork();

    // Setup Home Login Interactions
    setupHomeLogin();

    // Setup Install Button
    setupInstallButton();
});

/**
 * Initializes the Stremio Addon install/copy buttons.
 * Handles "Launch" (Protocol handler) and "Copy Manifest" actions with auth checks.
 */
function setupInstallButton() {
    const launchBtn = document.getElementById('btn-launch-stremio');
    const copyBtn = document.getElementById('btn-copy-manifest');
    const API_BASE = (window.location.hostname === 'localhost' || window.location.hostname === '127.0.0.1')
        ? 'http://localhost:8080'
        : 'https://seedsphere-router.fly.dev';

    if (launchBtn) {
        launchBtn.addEventListener('click', async () => {
            // 1. Check Session
            try {
                const res = await fetch(`${API_BASE}/api/auth/session`);
                const data = await res.json();

                if (data.ok && data.user) {
                    const userId = data.user.id.split(':')[1] || data.user.id;
                    const host = window.location.hostname === 'localhost' ? 'localhost:8080' : window.location.host;
                    const manifestUrl = `stremio://${host}/u/${userId}/manifest.json`;
                    window.location.href = manifestUrl;
                } else {
                    // Not logged in -> Prompt to Login
                    const overlay = document.getElementById('login-overlay');
                    if (overlay) {
                        overlay.style.display = 'flex';
                        // Ideally show a message saying "Login to install addon"
                    } else {
                        alert('Please sign in to install the addon.');
                    }
                }
            } catch (e) {
                console.error('Install check failed', e);
            }
        });
    }

    if (copyBtn) {
        copyBtn.addEventListener('click', async () => {
            try {
                const res = await fetch(`${API_BASE}/api/auth/session`);
                const data = await res.json();

                if (data.ok && data.user) {
                    const userId = data.user.id.split(':')[1] || data.user.id;
                    const host = window.location.hostname === 'localhost' ? 'localhost:8080' : window.location.host;
                    const manifestUrl = `https://${host}/u/${userId}/manifest.json`;

                    navigator.clipboard.writeText(manifestUrl);
                    const originalText = copyBtn.textContent;
                    copyBtn.textContent = 'Copied!';
                    setTimeout(() => copyBtn.textContent = originalText, 2000);
                } else {
                    const overlay = document.getElementById('login-overlay');
                    if (overlay) overlay.style.display = 'flex';
                }
            } catch (e) {
                console.error('Copy check failed', e);
            }
        });
    }
}

/**
 * configures the login interactions for the home page (landing).
 * Includes the "Sign In" button overlay and the Magic Link form submission.
 */
function setupHomeLogin() {
    const signInBtn = document.querySelector('a[href="dashboard.html"].btn-primary');
    const overlay = document.getElementById('login-overlay');

    if (signInBtn && overlay) {
        signInBtn.addEventListener('click', (e) => {
            e.preventDefault();
            overlay.style.display = 'flex';
        });

        // Click outside to close (Home specific)
        overlay.addEventListener('click', (e) => {
            if (e.target === overlay) {
                overlay.style.display = 'none';
            }
        });
    }

    // Magic Link Form Logic (Duplicated from Dashboard for Home context)
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
}

/**
 * Detects the user's OS to highlight the appropriate download option.
 * Falls back to Android/Desktop detection.
 */
function detectPlatform() {
    const userAgent = navigator.userAgent.toLowerCase();
    const downloadBtns = document.querySelectorAll('.btn-download, .btn-download-platform');

    let platform = 'Android'; // default

    if (userAgent.includes('iphone') || userAgent.includes('ipad')) {
        platform = 'iOS';
    } else if (userAgent.includes('windows')) {
        platform = 'Desktop';
    } else if (userAgent.includes('mac')) {
        platform = 'Desktop';
    } else if (userAgent.includes('linux')) {
        platform = 'Desktop';
    }

    // Highlight detected platform
    const platformCards = document.querySelectorAll('.download-card');
    platformCards.forEach(card => {
        const h3 = card.querySelector('h3');
        if (h3 && h3.textContent === platform) {
            card.style.border = '1px solid var(--aether-blue)';
            card.style.boxShadow = '0 0 30px rgba(56, 189, 248, 0.3)';
        }
    });
}

function setupSmoothScroll() {
    const links = document.querySelectorAll('a[href^="#"]');

    links.forEach(link => {
        link.addEventListener('click', (e) => {
            e.preventDefault();
            const targetId = link.getAttribute('href');
            const targetElement = document.querySelector(targetId);

            if (targetElement) {
                targetElement.scrollIntoView({
                    behavior: 'smooth',
                    block: 'start'
                });
            }
        });
    });
}

/**
 * Animates the background network nodes with random pulses.
 */
function animateNetwork() {
    const nodes = document.querySelectorAll('.orbit-node');

    nodes.forEach((node, index) => {
        node.style.animationDelay = `${index * 0.3}s`;

        // Add random pulse variations
        node.style.animationDuration = `${2.5 + Math.random()}s`;
    });

    // Animate connections
    const connections = document.querySelectorAll('.connection');
    connections.forEach((conn, index) => {
        conn.style.animationDelay = `${index * 0.2}s`;
    });
}

// Download button interactions
/**
 * Handles the download button click action.
 * @param {string} platform - The target platform name (Android, iOS, Desktop)
 */
function handleDownload(platform) {
    console.log(`Downloading for ${platform}...`);

    // Trigger download
    const downloadUrls = {
        'Android': '/downloads/seedsphere-gardener-v2.0.0.apk',
        'iOS': '#beta-full',
        'Desktop': '#coming-soon'
    };

    const url = downloadUrls[platform];
    if (url && !url.startsWith('#')) {
        window.location.href = url;
    } else {
        if (platform === 'iOS') {
            alert('iOS Beta is currently full. Check back later for new slots!');
        } else {
            alert(`${platform} version coming Q2 2026!`);
        }
    }
}

// Add click handlers to download buttons
document.addEventListener('DOMContentLoaded', () => {
    const downloadCards = document.querySelectorAll('.download-card');

    downloadCards.forEach(card => {
        const btn = card.querySelector('.btn-download-platform');
        const platform = card.querySelector('h3').textContent;

        if (btn && !btn.disabled) {
            btn.addEventListener('click', () => handleDownload(platform));
        }
    });

    // Main hero download button
    const heroDownload = document.querySelector('.btn-download');
    if (heroDownload) {
        heroDownload.addEventListener('click', () => {
            // Scroll to download section
            document.querySelector('#download').scrollIntoView({
                behavior: 'smooth'
            });
        });
    }
});
