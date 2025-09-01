import { createApp } from 'vue'
import App from './App.vue'
import router from './router'

// Initialize theme early to avoid FOUC
const ALLOWED_THEMES = ['seedsphere', 'light', 'dark']

function sanitizeTheme(t) {
  return ALLOWED_THEMES.includes(t) ? t : null
}

function getInitialTheme() {
  try {
    const saved = localStorage.getItem('theme')
    const ok = sanitizeTheme(saved)
    if (ok) return ok
  } catch (_) { /* ignore */ }
  // Prefer system dark if available, else use our brand theme
  try {
    const prefersDark = window.matchMedia && window.matchMedia('(prefers-color-scheme: dark)').matches
    const fallback = prefersDark ? 'dark' : 'seedsphere'
    const ok = sanitizeTheme(fallback)
    return ok || 'seedsphere'
  } catch (_) {
    return 'seedsphere'
  }
}

const initialTheme = getInitialTheme()
try { document.documentElement.setAttribute('data-theme', initialTheme) } catch (_) {}

const app = createApp(App)
app.use(router)
app.mount('#app')

// Register service worker for PWA installability
try {
  if (typeof window !== 'undefined' && 'serviceWorker' in navigator) {
    window.addEventListener('load', () => {
      navigator.serviceWorker.register('/sw.js').catch(() => { /* ignore */ })
    })
  }
} catch (_) { /* ignore */ }
