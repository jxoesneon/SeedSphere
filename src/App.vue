<template>
  <div class="min-h-screen bg-base-100 text-base-content relative">
    <!-- Global backdrop gradient -->
    <div class="backdrop" aria-hidden="true"></div>
    <div class="navbar bg-base-200">
      <div class="container mx-auto px-4 grid grid-cols-2 md:grid-cols-3 items-center">
        <!-- Left: Brand -->
        <div class="flex items-center gap-2 justify-start">
          <RouterLink to="/" class="flex items-center gap-2 text-lg font-semibold">
            <img src="/assets/icon.png" alt="SeedSphere" class="h-6 w-6" />
            <span>SeedSphere</span>
          </RouterLink>
        </div>

        <!-- Center: Gardener connection pill (PWA only) -->
        <div class="hidden md:flex justify-center" v-if="isStandalone">
          <div class="tooltip tooltip-bottom" :data-tip="seedlingTooltip">
            <div class="badge gap-2" :class="serverOnline ? 'badge-success' : 'badge-error'">
              <span class="inline-block h-2 w-2 rounded-full" :class="serverOnline ? 'bg-green-400' : 'bg-red-400'"></span>
              <span>Gardener {{ serverOnline ? 'Connected' : 'Offline' }}</span>
            </div>
          </div>
        </div>

        <!-- Right: Nav + Theme + Account -->
        <div class="flex flex-wrap items-center gap-2 justify-end">
          <RouterLink to="/" class="btn btn-ghost btn-sm">Home</RouterLink>
          <RouterLink to="/configure" class="btn btn-ghost btn-sm">Configure</RouterLink>
          <RouterLink to="/pair" class="btn btn-ghost btn-sm">Pair</RouterLink>
          <RouterLink to="/activity" class="btn btn-ghost btn-sm">Activity</RouterLink>
          <a class="btn btn-ghost btn-sm" :href="manifestUrl" target="_blank" rel="noopener">Manifest</a>
          <RouterLink v-if="isDev" to="/executor" class="btn btn-ghost btn-sm">Executor</RouterLink>
          <span v-if="gardenerId" class="badge badge-outline badge-sm" :title="`gardener_id: ${gardenerId}`">G: {{ gardenerId }}</span>
          <div class="form-control">
            <label class="label cursor-pointer gap-2">
              <span class="label-text">Theme</span>
              <select class="select select-bordered select-sm" v-model="theme" @change="applyTheme(theme)">
                <option value="seedsphere">Seedsphere</option>
                <option value="light">Light</option>
                <option value="dark">Dark</option>
              </select>
            </label>
          </div>
          <AccountMenu />
        </div>
      </div>
    </div>
    <RouterView />
    <!-- Dev drawer (visible only when ?dev=1 is present) -->
    <DevDrawer v-if="isDev" />
  </div>
  
</template>

<script setup>
import { ref, computed, onMounted, onBeforeUnmount } from 'vue'
import AccountMenu from './components/AccountMenu.vue'
import { auth } from './lib/auth'
import DevDrawer from './components/DevDrawer.vue'
import { gardener } from './lib/gardener'

const theme = ref('seedsphere')
const ALLOWED_THEMES = ['seedsphere', 'light', 'dark']
const isDev = ref(false)
const serverOnline = ref(false)
let pingTimer = null
const urlParams = new URLSearchParams(typeof window !== 'undefined' ? window.location.search : '')
const pwaOverride = urlParams.get('pwa') // '1' to force on, '0' to force off
const isStandalone = computed(() => {
  try {
    if (pwaOverride === '1') return true
    if (pwaOverride === '0') return false
    return (window.matchMedia && window.matchMedia('(display-mode: standalone)').matches) || (window.navigator && window.navigator.standalone)
  } catch (_) { return false }
})

// Seedling info for tooltip
const gardenerId = computed(() => {
  try { return gardener.getGardenerId() || '' } catch { return '' }
})
const manifestUrl = computed(() => {
  try {
    const base = new URL('/manifest.json', window.location.origin)
    const gid = gardener.getGardenerId()
    if (gid) base.searchParams.set('gardener_id', gid)
    return base.toString()
  } catch (_) { return '/manifest.json' }
})
const seedlingName = ref('Seedling')
const seedlingVersion = ref('')
const streamLabel = ref('')
const installId = ref('')
const deviceId = ref('')
const seedlingTooltip = computed(() => {
  const parts = []
  if (seedlingName.value) parts.push(`${seedlingName.value}${seedlingVersion.value ? ` v${seedlingVersion.value}` : ''}`)
  if (streamLabel.value) parts.push(`Stream label: ${streamLabel.value}`)
  if (deviceId.value) parts.push(`Seedling: ${deviceId.value}`)
  if (gardenerId.value) parts.push(`Gardener: ${gardenerId.value}`)
  if (manifestUrl.value) parts.push(manifestUrl.value)
  return parts.join(' • ')
})

function sanitizeTheme(t) {
  return ALLOWED_THEMES.includes(t) ? t : 'seedsphere'
}

function applyTheme(t) {
  const safe = sanitizeTheme(t)
  try { document.documentElement.setAttribute('data-theme', safe) } catch (_) {}
  try { localStorage.setItem('theme', safe) } catch (_) {}
  theme.value = safe
}

// Detect Chromium-based browsers (Chrome, Edge, Brave, etc.)
function isChromium() {
  try {
    const ua = navigator.userAgent || ''
    const brands = (navigator.userAgentData && Array.isArray(navigator.userAgentData.brands)) ? navigator.userAgentData.brands.map(b => b.brand).join(' ') : ''
    const s = `${ua} ${brands}`
    return /Chrome|Chromium|Edg\//.test(s) && !/Firefox|Safari\//.test(s)
  } catch (_) { return false }
}

// Minimal, theme-friendly floating Ko-fi fallback button (used only on Chromium)
function addKofiFallbackButton() {
  try {
    if (document.querySelector('[data-kofi="fallback"]')) return
    const a = document.createElement('a')
    a.href = 'https://ko-fi.com/jxoesneon'
    a.target = '_blank'
    a.rel = 'noopener'
    a.textContent = 'Support me'
    a.setAttribute('aria-label', 'Support me on Ko-fi')
    a.setAttribute('data-kofi', 'fallback')
    Object.assign(a.style, {
      position: 'fixed', left: '16px', bottom: '16px', zIndex: '2147483000',
      background: '#00b9fe', color: '#fff', padding: '8px 12px',
      borderRadius: '9999px', fontWeight: '600', boxShadow: '0 4px 14px rgba(0,0,0,0.25)',
      display: 'inline-flex', alignItems: 'center', gap: '6px', textDecoration: 'none',
      lineHeight: '1', fontSize: '13px'
    })
    document.body.appendChild(a)
  } catch (_) {}
}

// Ko-fi overlay: force transparent backgrounds to avoid white blocks in dark theme
function injectKofiOverlayOverrides() {
  try {
    // 1) Inject style once
    if (!document.querySelector('style[data-kofi="overlay-override"]')) {
      const css = `
[id^="kofi-widget-overlay-"] {
  color-scheme: normal !important;
  isolation: isolate !important;
  will-change: transform, opacity !important;
  transform: translateZ(0) !important;
  backface-visibility: hidden !important;
  z-index: 2147483000 !important;
}
[id^="kofi-widget-overlay-"] .floatingchat-container-wrap,
[id^="kofi-widget-overlay-"] .floatingchat-container-wrap-mobi,
[id^="kofi-widget-overlay-"] .floating-chat-kofi-popup-iframe,
[id^="kofi-widget-overlay-"] .floating-chat-kofi-popup-iframe-mobi,
[id^="kofi-widget-overlay-"] .floating-chat-kofi-popup-iframe-notice,
[id^="kofi-widget-overlay-"] .floating-chat-kofi-popup-iframe-closer,
[id^="kofi-widget-overlay-"] .floating-chat-kofi-popup-iframe-container,
[id^="kofi-widget-overlay-"] .floating-chat-kofi-popup-iframe-container-mobi,
[id^="kofi-widget-overlay-"] .floatingchat-container-wrap::before,
[id^="kofi-widget-overlay-"] .floatingchat-container-wrap::after,
[id^="kofi-widget-overlay-"] .floatingchat-container-wrap-mobi::before,
[id^="kofi-widget-overlay-"] .floatingchat-container-wrap-mobi::after,
[id^="kofi-widget-overlay-"] .floating-chat-kofi-popup-iframe::before,
[id^="kofi-widget-overlay-"] .floating-chat-kofi-popup-iframe::after,
[id^="kofi-widget-overlay-"] .floating-chat-kofi-popup-iframe-mobi::before,
[id^="kofi-widget-overlay-"] .floating-chat-kofi-popup-iframe-mobi::after {
  background: transparent !important;
  box-shadow: none !important;
  border: none !important;
  outline: none !important;
  filter: none !important;
}
[id^="kofi-widget-overlay-"] a.kfds-text-is-link-dark { color: currentColor !important; }
[id^="kofi-widget-overlay-"] iframe {
  color-scheme: normal !important;
  background: transparent !important;
  box-shadow: none !important;
  border: 0 !important;
  outline: 0 !important;
  mix-blend-mode: normal !important;
  will-change: transform, opacity !important;
  transform: translateZ(0) !important;
  backface-visibility: hidden !important;
}
[id^="kofi-widget-overlay-"] .floatingchat-container-wrap,
[id^="kofi-widget-overlay-"] .floatingchat-container-wrap-mobi {
  overflow: visible !important;
  opacity: 1 !important;
}
[id^="kofi-widget-overlay-"] iframe.floatingchat-container,
[id^="kofi-widget-overlay-"] iframe.floatingchat-container-mobi {
  overflow: visible !important;
}
`
      const st = document.createElement('style')
      st.type = 'text/css'
      st.setAttribute('data-kofi', 'overlay-override')
      st.appendChild(document.createTextNode(css))
      document.head.appendChild(st)
    }
    // 2) Also directly style iframes in case Chrome paints white by default
    const tweak = () => {
      try {
        document
          .querySelectorAll('[id^="kofi-widget-overlay-"] iframe')
          .forEach((f) => {
            f.style.background = 'transparent'
            f.style.boxShadow = 'none'
            f.style.border = '0'
            f.style.outline = '0'
            try { f.setAttribute('allowtransparency', 'true') } catch (_) {}
          })
      } catch (_) {}
    }
    tweak()
    try { setTimeout(tweak, 150) } catch (_) {}

    // 3) Fade wrappers in after iframe load to prevent initial white flash in Chrome
    const fadeIn = () => {
      try {
        document
          .querySelectorAll('[id^="kofi-widget-overlay-"] .floatingchat-container-wrap, [id^="kofi-widget-overlay-"] .floatingchat-container-wrap-mobi')
          .forEach((el) => {
            try { el.style.setProperty('opacity', '1', 'important') } catch (_) { el.style.opacity = '1' }
          })
      } catch (_) {}
    }
    try {
      document
        .querySelectorAll('[id^="kofi-widget-overlay-"] iframe')
        .forEach((f) => { f.addEventListener('load', fadeIn, { once: true }) })
    } catch (_) {}
    // Redundant fallbacks in case the load event fires before listeners attach
    try { setTimeout(fadeIn, 0) } catch (_) {}
    try { setTimeout(fadeIn, 600) } catch (_) {}
    try { setTimeout(fadeIn, 1500) } catch (_) {}
  } catch (_) {}
}

onMounted(() => {
  // Initialize auth session state and handle login=ok
  auth.initAuth()

  // Ensure Ko-fi override CSS is present ASAP to prevent any initial white flash
  try { injectKofiOverlayOverrides() } catch (_) {}

  try {
    const saved = localStorage.getItem('theme')
    if (saved) theme.value = sanitizeTheme(saved)
  } catch (_) {}
  applyTheme(theme.value)

  // Enable DevDrawer only when URL contains ?dev=1 (supports query or hash params)
  try {
    const url = new URL(window.location.href)
    const hasQueryDev = url.searchParams.get('dev') === '1'
    const hasHashDev = url.hash.includes('?') && new URLSearchParams(url.hash.split('?')[1]).get('dev') === '1'
    isDev.value = Boolean(hasQueryDev || hasHashDev)
  } catch (_) { isDev.value = false }

  // Ko‑fi overlay widget (match backup configure page)
  try {
    const existing = document.querySelector('script[data-kofi="overlay"]')
    const ensure = () => {
      if (window.kofiWidgetOverlay && typeof window.kofiWidgetOverlay.draw === 'function') {
        try {
          window.kofiWidgetOverlay.draw('jxoesneon', {
            type: 'floating-chat',
            'floating-chat.donateButton.text': 'Support me',
            'floating-chat.donateButton.background-color': '#00b9fe',
            'floating-chat.donateButton.text-color': '#fff',
          })
        } catch (_) {}
        // Ensure our overrides are applied after the Ko-fi CSS
        injectKofiOverlayOverrides()
        return true
      }
      return false
    }
    if (!existing) {
      const s = document.createElement('script')
      s.src = 'https://storage.ko-fi.com/cdn/scripts/overlay-widget.js'
      s.async = true
      s.setAttribute('data-kofi', 'overlay')
      s.onload = () => { try { ensure() } finally { injectKofiOverlayOverrides() } }
      document.head.appendChild(s)
    } else {
      ensure(); injectKofiOverlayOverrides()
    }
  } catch (_) {}

  // Connectivity: ping /health periodically and listen to online/offline
  const doPing = async () => {
    try {
      const r = await fetch('/health', { cache: 'no-store' })
      serverOnline.value = r.ok
    } catch (_) {
      serverOnline.value = false
    }
  }
  doPing()
  try { pingTimer = setInterval(doPing, 15000) } catch (_) {}
  try { window.addEventListener('online', doPing) } catch (_) {}
  try { window.addEventListener('offline', () => { serverOnline.value = false }) } catch (_) {}

  // Load Seedling info (manifest and saved Configure label)
  // Debug: log detected display-mode
  try {
    const modes = ['standalone','minimal-ui','fullscreen','browser']
    const report = {}
    for (const m of modes) {
      try { report[m] = window.matchMedia(`(display-mode: ${m})`).matches } catch { report[m] = 'n/a' }
    }
    // eslint-disable-next-line no-console
    console.log('[PWA] display-mode detection', { report, iosStandalone: (typeof window.navigator !== 'undefined' && 'standalone' in window.navigator) ? window.navigator.standalone : 'n/a', pwaOverride })
  } catch (_) {}
  try {
    fetch(manifestUrl.value, { cache: 'no-store' })
      .then((r) => r.ok ? r.json() : null)
      .then((j) => { if (j) { seedlingName.value = j.name || seedlingName.value; seedlingVersion.value = j.version || '' } })
      .catch(() => {})
  } catch (_) {}
  try {
    const raw = localStorage.getItem('seedsphere.configure')
    if (raw) {
      const saved = JSON.parse(raw)
      if (typeof saved.streamLabel === 'string') streamLabel.value = saved.streamLabel
    }
  } catch (_) {}

  // Load saved install_id and fetch pairing status if available
  try {
    const sid = localStorage.getItem('seedsphere.install_id') || ''
    if (sid) installId.value = sid
  } catch (_) {}
  async function fetchPairStatus() {
    if (!installId.value) return
    try {
      const u = new URL('/api/pair/status', window.location.origin)
      u.searchParams.set('install_id', installId.value)
      const r = await fetch(u.toString(), { cache: 'no-store' })
      if (!r.ok) return
      const j = await r.json()
      if (j && j.ok && j.paired && j.device_id) deviceId.value = j.device_id
    } catch (_) { /* ignore */ }
  }
  if (isStandalone.value) {
    fetchPairStatus()
    try { setInterval(fetchPairStatus, 30000) } catch (_) {}
  }
})

onBeforeUnmount(() => {
  try { pingTimer && clearInterval(pingTimer) } catch (_) {}
  try { window.removeEventListener('online', null) } catch (_) {}
  try { window.removeEventListener('offline', null) } catch (_) {}
})
</script>

<style scoped>
</style>

