<template>
  <main class="min-h-screen bg-base-100 text-base-content">
    <div class="container mx-auto p-6">
      

      <div v-if="showUpdateBanner" class="alert alert-info mb-4" role="status">
        <span>Update available: SeedSphere v{{ latestVersion }} is available.</span>
        <button class="btn btn-sm" @click="dismissUpdate">Dismiss</button>
      </div>

      <div class="card bg-base-200 shadow">
        <div class="card-body">
          <h2 class="card-title">What is SeedSphere?</h2>
          <p>
            SeedSphere makes torrents connect faster and more reliably by validating trackers and appending only the healthy ones to your magnet links. The result is quicker starts, fewer stalls, and a smoother experience.
          </p>
          <ul class="list-disc pl-6">
            <li><strong>Smart validation</strong> — DNS/HTTP checks by default; optional aggressive mode with UDP handshakes.</li>
            <li><strong>Controlled boosts</strong> — Unlimited by default; optionally cap how many trackers to add.</li>
            <li><strong>Privacy-friendly</strong> — No account required to use the addon; Magic Link sign-in is available for configuration sync.</li>
            <li><strong>Full transparency</strong> — Recent Boosts and health stats show exactly what happened and why.</li>
          </ul>
          <div class="mt-4 flex flex-wrap gap-2">
            <a class="btn btn-primary" :href="manifestProtocol">Install / Update in Stremio</a>
            <a class="btn btn-secondary" :href="manifestExperimentalProtocol" title="Installs experimental manifest with non-official fields">Experimental Install</a>
            <button class="btn" type="button" @click="openStremio">Open Stremio</button>
            <button class="btn" type="button" @click="copyInstall">Copy Install Link</button>
            <button v-if="canInstallPwa" class="btn" type="button" @click="installPwa">Install App</button>
            <a class="btn" href="/api/boosts/recent" target="_blank" rel="noopener">Recent boosts (JSON)</a>
            <a class="btn" href="/api/trackers/health" target="_blank" rel="noopener">Health stats (JSON)</a>
          </div>
          
          <!-- Platform-specific install instructions -->
          <div class="mt-4 p-3 rounded-box bg-base-200/70">
            <div class="flex items-center gap-2">
              <div class="badge badge-info">Install Gardener</div>
              <span class="text-sm opacity-80">Based on your device/browser</span>
            </div>
            <ul class="list-disc pl-6 mt-2 text-sm">
              <li v-for="(msg, i) in installTips" :key="i">{{ msg }}</li>
            </ul>
            <div v-if="isStandalone" class="alert alert-success mt-2 text-sm">Gardener is installed. You can launch it from your apps/dock.</div>
          </div>
          <div class="mt-2 text-sm opacity-70">
            <div>Manifest URL: <code>{{ manifestHttp }}</code></div>
          </div>

          <!-- Install via QR header and toggle button -->
          <div class="mt-6 flex flex-wrap items-center gap-2">
            <h3 class="text-lg font-semibold">Install via QR code</h3>
            <button class="btn btn-ghost btn-sm" type="button" @click="toggleQr" :aria-label="showQr ? 'Hide QR' : 'Show QR'">
              <svg v-if="showQr" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" class="h-5 w-5" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round">
                <path d="M3 3l18 18"/>
                <path d="M10.477 10.477A3 3 0 0012 15a3 3 0 002.523-4.523M4.5 4.5C2.94 5.884 1.77 7.54 1 9c2.5 5 7 8 11 8 1.31 0 2.57-.27 3.74-.77M19.5 19.5C21.06 18.116 22.23 16.46 23 15c-2.5-5-7-8-11-8-1.31 0-2.57.27-3.74.77"/>
              </svg>
              <svg v-else xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" class="h-5 w-5" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round">
                <path d="M1 12s4-7 11-7 11 7 11 7-4 7-11 7S1 12 1 12z"/>
                <circle cx="12" cy="12" r="3"/>
              </svg>
            </button>
          </div>

          <div v-if="showQr" class="mt-4">
            <img :src="qrSrc" alt="QR to install/refresh addon in Stremio" class="w-full max-w-xs h-auto" />
            <div class="muted text-sm mt-1">Scan on mobile to open the manifest in Stremio</div>
          </div>
        </div>
      </div>
    </div>
  </main>
</template>

<script setup>
import { ref, computed, onMounted, onBeforeUnmount } from 'vue'
import { gardener } from '../lib/gardener'

const origin = typeof window !== 'undefined' ? window.location.origin : ''
const manifestHttp = computed(() => {
  try {
    const u = new URL('/manifest.json', origin || 'http://localhost')
    const gid = gardener.getGardenerId()
    if (gid) u.searchParams.set('gardener_id', gid)
    return u.toString()
  } catch (_) { return `${origin}/manifest.json` }
})
// Per Stremio deep link docs: replace https?:// with stremio:// (do NOT URI-encode the URL)
// Also prefer 127.0.0.1 over localhost for local installs (HTTPS exception applies to 127.0.0.1)
function toStremioProtocol(uStr) {
  try {
    const u = new URL(uStr)
    if (u.hostname === 'localhost') u.hostname = '127.0.0.1'
    return u.toString().replace(/^https?:\/\//, 'stremio://')
  } catch (_) {
    return uStr.replace('localhost', '127.0.0.1').replace(/^https?:\/\//, 'stremio://')
  }
}
const manifestProtocol = computed(() => toStremioProtocol(manifestHttp.value))
const manifestExperimentalHttp = computed(() => {
  try {
    const u = new URL('/manifest.experiment.json', origin || 'http://localhost')
    const gid = gardener.getGardenerId()
    if (gid) u.searchParams.set('gardener_id', gid)
    return u.toString()
  } catch (_) { return `${origin}/manifest.experiment.json` }
})
const manifestExperimentalProtocol = computed(() => toStremioProtocol(manifestExperimentalHttp.value))

const latestVersion = ref('')
const seenVersion = ref('')
function cmpSemver(a, b) {
  try {
    const pa = String(a || '').split('.')
    const pb = String(b || '').split('.')
    for (let i = 0; i < 3; i++) {
      const na = parseInt(pa[i] || '0', 10)
      const nb = parseInt(pb[i] || '0', 10)
      if (Number.isNaN(na) || Number.isNaN(nb)) break
      if (na > nb) return 1
      if (na < nb) return -1
    }
    return 0
  } catch (_) { return 0 }
}
const showUpdateBanner = computed(() => {
  if (!latestVersion.value) return false
  if (!seenVersion.value) return false
  return cmpSemver(latestVersion.value, seenVersion.value) > 0
})
const showQr = ref(true)
const canInstallPwa = ref(false)
const deferredPrompt = ref(null)

// Platform detection
const ua = (typeof navigator !== 'undefined' ? navigator.userAgent : '')
const isIOS = computed(() => /iPad|iPhone|iPod/.test(ua) || (navigator.platform === 'MacIntel' && navigator.maxTouchPoints > 1))
const isAndroid = computed(() => /Android/.test(ua))
const isEdge = computed(() => /Edg\//.test(ua))
const isChrome = computed(() => /Chrome\//.test(ua) && !isEdge.value)
const isSafari = computed(() => /Safari\//.test(ua) && !isChrome.value && !isEdge.value)
const isMac = computed(() => /Macintosh|MacIntel/.test(ua))
const isStandalone = computed(() => {
  try {
    return (window.matchMedia && window.matchMedia('(display-mode: standalone)').matches) || (window.navigator && window.navigator.standalone)
  } catch (_) { return false }
})

const installTips = computed(() => {
  const tips = []
  if (isStandalone.value) return tips
  if (isIOS.value) {
    tips.push('iOS Safari: tap Share, then "Add to Home Screen" to install Gardener.')
  } else if (isAndroid.value) {
    tips.push('Android Chrome/Edge: use the browser menu and tap "Install app" to install Gardener.')
    if (canInstallPwa.value) tips.push('Or tap the "Install App" button above when it appears.')
  } else if (isMac.value && isSafari.value) {
    tips.push('macOS Safari: use File → Add to Dock to install Gardener (Safari 17+).')
  } else if (isChrome.value || isEdge.value) {
    tips.push('Desktop Chrome/Edge: click the install icon in the address bar, or Menu → Install "Gardener".')
    if (canInstallPwa.value) tips.push('Or click the "Install App" button above.')
  } else {
    tips.push('Your browser may support installing this app. Look for an Install option in the browser menu.')
  }
  return tips
})

const qrSrc = computed(() => {
  const data = encodeURIComponent(manifestProtocol.value)
  // Use a lightweight external QR generator
  return `https://api.qrserver.com/v1/create-qr-code/?size=300x300&data=${data}`
})

function openStremio() {
  try {
    window.location.href = 'stremio://'
  } catch (_) { /* ignore */ }
}

async function copyInstall() {
  try {
    await navigator.clipboard.writeText(manifestHttp.value)
  } catch (_) {
    // fallback
    const ta = document.createElement('textarea')
    ta.value = manifestHttp.value
    document.body.appendChild(ta)
    ta.select()
    document.execCommand('copy')
    document.body.removeChild(ta)
  }
}

function toggleQr() {
  showQr.value = !showQr.value
}

function applyTheme(theme) {
  document.documentElement.setAttribute('data-theme', theme)
}

function toggleTheme() {
  const current = document.documentElement.getAttribute('data-theme') || 'dark'
  const next = current === 'dark' ? 'light' : 'dark'
  localStorage.setItem('seedsphere-theme', next)
  applyTheme(next)
}

function dismissUpdate() {
  try {
    if (latestVersion.value) localStorage.setItem('seedsphere.version_seen', latestVersion.value)
    seenVersion.value = latestVersion.value
  } catch (_) {}
}

onMounted(async () => {
  // Handle PWA install prompt availability
  const onBip = (e) => {
    e.preventDefault()
    deferredPrompt.value = e
    canInstallPwa.value = true
  }
  window.addEventListener('beforeinstallprompt', onBip)

  try {
    // Load last seen
    try { seenVersion.value = localStorage.getItem('seedsphere.version_seen') || '' } catch (_) {}
    const res = await fetch(manifestHttp.value, { cache: 'no-store' })
    if (res.ok) {
      const m = await res.json()
      latestVersion.value = (m && m.version) || ''
      try { if (latestVersion.value) localStorage.setItem('seedsphere.version_latest', latestVersion.value) } catch (_) {}
      // Initialize seen on first load to avoid false-positive banner
      try {
        if (!seenVersion.value && latestVersion.value) {
          localStorage.setItem('seedsphere.version_seen', latestVersion.value)
          seenVersion.value = latestVersion.value
        }
      } catch (_) {}
    }
  } catch (_) { /* ignore */ }

  // Theme on load
  const saved = localStorage.getItem('seedsphere-theme') || 'dark'
  applyTheme(saved)

  // Cleanup listener when component unmounts
  onBeforeUnmount(() => {
    window.removeEventListener('beforeinstallprompt', onBip)
  })
})

async function installPwa() {
  try {
    if (!deferredPrompt.value) return
    deferredPrompt.value.prompt()
    const { outcome } = await deferredPrompt.value.userChoice
    if (outcome === 'accepted') {
      canInstallPwa.value = false
      deferredPrompt.value = null
    }
  } catch (_) { /* ignore */ }
}
</script>

<style scoped>
</style>
