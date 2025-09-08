<template>
  <div class="min-h-screen bg-base-100 text-base-content relative">
    <!-- Global backdrop gradient -->
    <div class="backdrop" aria-hidden="true"></div>
    <div class="navbar sticky top-0 z-40 bg-base-100/80 backdrop-blur supports-[backdrop-filter]:bg-base-100/60 border-b border-base-300/50">
      <div class="container mx-auto px-4 flex items-center justify-between gap-2 whitespace-nowrap">
        <!-- Left: Brand -->
        <div class="flex items-center gap-2 justify-start">
          <RouterLink to="/" class="flex items-center gap-2 text-lg font-semibold tooltip" data-tip="Home">
            <img src="/assets/icon-256.png" alt="SeedSphere logo" class="h-6 w-6" />
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

        <!-- Right: Nav + Theme + Account (desktop) -->
        <div class="hidden md:flex items-center gap-2 justify-end whitespace-nowrap">
          <RouterLink to="/" class="tooltip" data-tip="Home" :class="navLinkClasses('/')">Home</RouterLink>
          <RouterLink to="/configure" class="tooltip" data-tip="Configure addon" :class="navLinkClasses('/configure')">Configure</RouterLink>
          <RouterLink to="/pair" class="tooltip" data-tip="Pair a device" :class="navLinkClasses('/pair')">Pair</RouterLink>
          <RouterLink to="/activity" class="tooltip" data-tip="View activity" :class="navLinkClasses('/activity')">Activity</RouterLink>
          <a class="btn btn-ghost btn-sm rounded-full tooltip" data-tip="Open manifest JSON" :href="manifestUrl" target="_blank" rel="noopener">Manifest</a>
          <RouterLink v-if="isDev" to="/executor" class="tooltip" data-tip="Developer executor" :class="navLinkClasses('/executor')">Executor</RouterLink>
          <div class="form-control tooltip" data-tip="Change theme">
            <label class="label cursor-pointer gap-2">
              <span class="label-text">Theme</span>
              <select class="select select-bordered select-sm" v-model="theme" @change="applyTheme(theme)">
                <option value="seedsphere">Seedsphere</option>
                <option value="light">Light</option>
                <option value="dark">Dark</option>
              </select>
            </label>
          </div>
          <div class="tooltip" data-tip="Account and authentication">
            <AccountMenu />
          </div>
        </div>

        <!-- Right: Mobile hamburger -->
        <div class="flex items-center justify-end md:hidden relative">
          <button class="btn btn-ghost btn-sm tooltip" data-tip="Toggle menu" type="button" @click="toggleMobileMenu" :aria-expanded="showMobileMenu ? 'true' : 'false'" aria-controls="mobile-nav">
            <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="1.5">
              <path stroke-linecap="round" stroke-linejoin="round" d="M3.75 6.75h16.5M3.75 12h16.5m-16.5 5.25h16.5" />
            </svg>
            <span class="sr-only">Toggle navigation</span>
          </button>
          <!-- Backdrop -->
          <div v-if="showMobileMenu" class="fixed inset-0 bg-base-300/30 backdrop-blur-sm z-40" @click="closeMobileMenu"></div>
          <!-- Dropdown menu -->
          <div
            v-if="showMobileMenu"
            id="mobile-nav"
            class="absolute right-0 top-10 w-72 rounded-2xl bg-base-100/90 border border-base-300/50 shadow-lg p-2 z-50 backdrop-blur supports-[backdrop-filter]:bg-base-100/70">
            <div class="flex flex-col gap-1">
              <RouterLink @click="closeMobileMenu" to="/" class="btn btn-ghost btn-sm rounded-full justify-start" title="Home">Home</RouterLink>
              <RouterLink @click="closeMobileMenu" to="/configure" class="btn btn-ghost btn-sm rounded-full justify-start" title="Configure addon">Configure</RouterLink>
              <RouterLink @click="closeMobileMenu" to="/pair" class="btn btn-ghost btn-sm rounded-full justify-start" title="Pair a device">Pair</RouterLink>
              <RouterLink @click="closeMobileMenu" to="/activity" class="btn btn-ghost btn-sm rounded-full justify-start" title="View activity">Activity</RouterLink>
              <a @click="closeMobileMenu" class="btn btn-ghost btn-sm rounded-full justify-start" :href="manifestUrl" target="_blank" rel="noopener" title="Open manifest JSON">Manifest</a>
              <RouterLink v-if="isDev" @click="closeMobileMenu" to="/executor" class="btn btn-ghost btn-sm rounded-full justify-start" title="Developer executor">Executor</RouterLink>
              <div class="divider my-2"></div>
              <div class="flex items-center justify-between gap-2 px-1">
                <span class="text-sm">Theme</span>
                <select class="select select-bordered select-sm" v-model="theme" @change="applyTheme(theme)" title="Change theme">
                  <option value="seedsphere">Seedsphere</option>
                  <option value="light">Light</option>
                  <option value="dark">Dark</option>
                </select>
              </div>
              <div class="mt-1">
                <div title="Account and authentication">
                  <AccountMenu />
                </div>
              </div>
            </div>
          </div>
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
import { useRoute } from 'vue-router'
import AccountMenu from './components/AccountMenu.vue'
import { auth } from './lib/auth'
import DevDrawer from './components/DevDrawer.vue'
import { gardener } from './lib/gardener'

const theme = ref('seedsphere')
const ALLOWED_THEMES = ['seedsphere', 'light', 'dark']
const isDev = ref(false)
const serverOnline = ref(false)
let pingTimer = null
// Feature flag: enable Ko‑fi overlay; we will load it programmatically on load
const ENABLE_KOFI_OVERLAY = true
// Mobile nav state
const showMobileMenu = ref(false)
function toggleMobileMenu() { showMobileMenu.value = !showMobileMenu.value }
function closeMobileMenu() { showMobileMenu.value = false }
const route = useRoute()
function navLinkClasses(path) {
  try {
    return 'btn btn-ghost btn-sm rounded-full' + (route.path === path ? ' btn-active' : '')
  } catch (_) {
    return 'btn btn-ghost btn-sm rounded-full'
  }
}
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

// Minimal, theme-friendly floating Ko‑fi fallback button
// Always visible, draggable horizontally across the viewport, never dismissible
function addKofiFallbackButton() {
  try {
    if (document.querySelector('[data-kofi="fallback"]')) return

    const posKey = 'kofi.xp' // horizontal position as 0..1
    const readXP = () => {
      try { const v = parseFloat(localStorage.getItem(posKey) || '0'); return isNaN(v) ? 0 : Math.min(1, Math.max(0, v)) } catch (_) { return 0 }
    }
    const writeXP = (xp) => { try { localStorage.setItem(posKey, String(Math.min(1, Math.max(0, xp)))) } catch (_) {} }

    const a = document.createElement('a')
    a.href = 'https://ko-fi.com/jxoesneon'
    a.target = '_blank'
    a.rel = 'noopener'
    a.setAttribute('aria-label', 'Support me on Ko-fi')
    a.setAttribute('data-kofi', 'fallback')
    a.setAttribute('draggable', 'false')
    Object.assign(a.style, {
      position: 'fixed', bottom: '16px', zIndex: '2147483000',
      background: '#00b9fe', color: '#fff', padding: '8px 12px',
      borderRadius: '9999px', fontWeight: '600', boxShadow: '0 4px 14px rgba(0,0,0,0.25)',
      display: 'inline-flex', alignItems: 'center', gap: '6px', textDecoration: 'none',
      lineHeight: '1', fontSize: '13px', cursor: 'grab', userSelect: 'none', touchAction: 'none',
      left: '16px'
    })

    // Icon + label
    const icon = document.createElement('span')
    icon.setAttribute('aria-hidden', 'true')
    icon.style.display = 'inline-flex'
    icon.style.alignItems = 'center'
    icon.style.justifyContent = 'center'
    icon.style.width = '16px'
    icon.style.height = '16px'
    icon.innerHTML = `
      <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" width="16" height="16" fill="currentColor" role="img">
        <path d="M6 4a1 1 0 00-1 1v6a5 5 0 005 5h3a5 5 0 005-5V9h1.5a2.5 2.5 0 010 5H18v-2h1.5a.5.5 0 000-1H18V5a1 1 0 00-1-1H6zm1 2h9v5a3 3 0 01-3 3H10a3 3 0 01-3-3V6z"/>
        <path d="M7 18h10a1 1 0 110 2H7a1 1 0 110-2z"/>
      </svg>`
    const text = document.createElement('span')
    text.textContent = 'Support me'
    a.appendChild(icon)
    a.appendChild(text)
    document.body.appendChild(a)

    // Position by XP once width is known
    const applyXP = (xp) => {
      try {
        const vw = window.innerWidth || 0
        const margin = 16
        const width = a.offsetWidth || 140
        const maxLeft = Math.max(margin, vw - width - margin)
        const left = Math.round(margin + xp * (maxLeft - margin))
        a.style.left = `${left}px`
        a.style.right = ''
      } catch (_) {}
    }
    requestAnimationFrame(() => applyXP(readXP()))

    // Drag logic
    let dragging = false
    let startX = 0
    let startLeft = 16
    let moved = false
    const onPointerDown = (e) => {
      try { a.setPointerCapture && a.setPointerCapture(e.pointerId) } catch (_) {}
      dragging = true
      moved = false
      startX = e.clientX
      startLeft = parseInt(a.style.left || '16', 10) || 16
      a.style.cursor = 'grabbing'
    }
    const onPointerMove = (e) => {
      if (!dragging) return
      const dx = e.clientX - startX
      if (Math.abs(dx) > 3) moved = true
      const vw = window.innerWidth || 0
      const width = a.offsetWidth || 140
      const margin = 16
      const minLeft = margin
      const maxLeft = Math.max(minLeft, vw - width - margin)
      const next = Math.min(maxLeft, Math.max(minLeft, startLeft + dx))
      a.style.left = `${next}px`
      a.style.right = ''
    }
    const onPointerUp = (e) => {
      if (!dragging) return
      dragging = false
      a.style.cursor = 'grab'
      const left = parseInt(a.style.left || '16', 10) || 16
      const vw = window.innerWidth || 0
      const width = a.offsetWidth || 140
      const margin = 16
      const minLeft = margin
      const maxLeft = Math.max(minLeft, vw - width - margin)
      const xp = (left - margin) / Math.max(1, (maxLeft - margin))
      writeXP(xp)
      if (moved) {
        e.preventDefault && e.preventDefault()
        e.stopPropagation && e.stopPropagation()
      }
      try { a.releasePointerCapture && a.releasePointerCapture(e.pointerId) } catch (_) {}
    }
    a.addEventListener('pointerdown', onPointerDown)
    window.addEventListener('pointermove', onPointerMove)
    window.addEventListener('pointerup', onPointerUp)
    const onResize = () => applyXP(readXP())
    window.addEventListener('resize', onResize)
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

  // Ko‑fi overlay widget: programmatic load (equivalent to placing script before </body>)
  try {
    if (ENABLE_KOFI_OVERLAY) {
      const existing = document.querySelector('script[data-kofi="overlay"]')
      let overlayReady = false
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
          overlayReady = true
          // Remove fallback if it exists to avoid duplication
          try { const fb = document.querySelector('[data-kofi="fallback"]'); if (fb && fb.parentNode) fb.parentNode.removeChild(fb) } catch (_) {}
          return true
        }
        return false
      }
      const loader = () => {
        if (!existing) {
          const s = document.createElement('script')
          s.src = 'https://storage.ko-fi.com/cdn/scripts/overlay-widget.js'
          s.async = true
          s.setAttribute('data-kofi', 'overlay')
          s.onload = () => { try { ensure() } finally { injectKofiOverlayOverrides() } }
          document.body.appendChild(s)
        } else {
          ensure(); injectKofiOverlayOverrides()
        }
      }
      if (document.readyState === 'complete') loader()
      else {
        let t
        try { t = setTimeout(loader, 0) } catch (_) {}
        try { window.addEventListener('load', () => { try { t && clearTimeout(t) } catch (_) {}; loader() }, { once: true }) } catch (_) { loader() }
      }
      // Fallback if overlay doesn't become ready within 5 seconds
      try {
        setTimeout(() => {
          if (!overlayReady) {
            try { addKofiFallbackButton() } catch (_) {}
          }
        }, 5000)
      } catch (_) {}
    } else {
      // Fallback button: always ensure visibility. If page not fully loaded, show by load or after 5s max
      const show = () => { try { addKofiFallbackButton() } catch (_) {} }
      if (document.readyState === 'complete') {
        show()
      } else {
        let t
        try { t = setTimeout(show, 5000) } catch (_) {}
        try { window.addEventListener('load', () => { try { t && clearTimeout(t) } catch (_) {}; show() }, { once: true }) } catch (_) { show() }
      }
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
    if (isDev.value) {
      // eslint-disable-next-line no-console
      console.log('[PWA] display-mode detection', { report, iosStandalone: (typeof window.navigator !== 'undefined' && 'standalone' in window.navigator) ? window.navigator.standalone : 'n/a', pwaOverride })
    }
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

