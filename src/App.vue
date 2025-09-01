<template>
  <div class="min-h-screen bg-base-100 text-base-content relative">
    <!-- Global backdrop gradient -->
    <div class="backdrop" aria-hidden="true"></div>
    <div class="navbar bg-base-200">
      <div class="container mx-auto px-4 grid grid-cols-3 items-center">
        <!-- Left: Brand -->
        <div class="flex items-center gap-2 justify-start">
          <RouterLink to="/" class="flex items-center gap-2 text-lg font-semibold">
            <img src="/assets/icon.png" alt="SeedSphere" class="h-6 w-6" />
            <span>SeedSphere</span>
          </RouterLink>
        </div>

        <!-- Center: Gardener connection pill (PWA only) -->
        <div class="flex justify-center" v-if="isStandalone">
          <div class="tooltip tooltip-bottom" :data-tip="seedlingTooltip">
            <div class="badge gap-2" :class="serverOnline ? 'badge-success' : 'badge-error'">
              <span class="inline-block h-2 w-2 rounded-full" :class="serverOnline ? 'bg-green-400' : 'bg-red-400'"></span>
              <span>Gardener {{ serverOnline ? 'Connected' : 'Offline' }}</span>
            </div>
          </div>
        </div>

        <!-- Right: Nav + Theme + Account -->
        <div class="flex items-center gap-2 justify-end">
          <RouterLink to="/" class="btn btn-ghost btn-sm">Home</RouterLink>
          <RouterLink to="/configure" class="btn btn-ghost btn-sm">Configure</RouterLink>
          <a class="btn btn-ghost btn-sm" href="/manifest.json" target="_blank" rel="noopener">Manifest</a>
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
const manifestUrl = computed(() => {
  try { return `${window.location.origin}/manifest.json` } catch (_) { return '/manifest.json' }
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

onMounted(() => {
  // Initialize auth session state and handle login=ok
  auth.initAuth()

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
        return true
      }
      return false
    }
    if (!existing) {
      const s = document.createElement('script')
      s.src = 'https://storage.ko-fi.com/cdn/scripts/overlay-widget.js'
      s.async = true
      s.setAttribute('data-kofi', 'overlay')
      s.onload = () => { ensure() }
      document.head.appendChild(s)
    } else {
      ensure()
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

