<template>
  <a href="#main-content" class="sr-only focus:not-sr-only focus:fixed focus:left-4 focus:top-4 focus:px-3 focus:py-2 focus:rounded focus:bg-base-100 focus:text-base-content focus:shadow focus:border focus:border-current z-50">Skip to main content</a>
  <main id="main-content" class="min-h-screen bg-base-100 text-base-content">
    <div class="container mx-auto p-6">
      

      <Transition name="slide-fade" appear>
        <div v-if="showUpdateBanner" class="alert alert-info mb-4" role="status">
          <span>Update available: SeedSphere v{{ latestVersion }} is available.</span>
          <button class="btn btn-sm" @click="dismissUpdate">Dismiss</button>
        </div>
      </Transition>

      <!-- Hero -->
      <Transition name="slide-fade" appear>
        <section class="relative overflow-hidden rounded-2xl bg-gradient-to-br from-primary/15 via-base-200 to-secondary/10 border border-base-300/50 shadow" role="region" aria-labelledby="hero-title">
        <div class="grid md:grid-cols-2 gap-6 p-6 md:p-10 items-center">
          <div>
            <h1 id="hero-title" class="text-3xl md:text-5xl font-extrabold tracking-tight">SeedSphere</h1>
            <p class="mt-3 text-base md:text-lg opacity-80 max-w-prose">
              Smarter trackers. Faster starts. SeedSphere validates and appends only healthy trackers to your magnet links for quicker discovery and fewer stalls.
            </p>
            <div class="mt-5 flex flex-wrap gap-2">
              <a v-if="isDevMode" class="btn btn-primary btn-lg" :href="manifestProtocol">Install / Update in Stremio</a>
              <a v-else class="btn btn-primary btn-lg" :href="baseManifestProtocol">Install in Stremio</a>
              <RouterLink to="/configure" class="btn btn-ghost btn-lg">Configure</RouterLink>
              <button class="btn btn-ghost btn-lg" type="button" @click="openStremio">Open Stremio</button>
              <button class="btn btn-outline btn-lg" type="button" @click="copyInstall">Copy Install Link</button>
            </div>
            <div class="mt-3 text-sm">
              <RouterLink to="/activity" class="link link-hover">See recent activity →</RouterLink>
            </div>
            <div class="mt-4 flex items-center gap-2">
              <label for="qr-toggle" class="text-sm opacity-80">Install via QR</label>
              <button id="qr-toggle" ref="qrToggleEl" class="btn btn-ghost btn-sm" type="button" @click="toggleQr" :aria-pressed="showQr ? 'true' : 'false'" :aria-expanded="showQr ? 'true' : 'false'" aria-controls="qr-panel" :aria-label="showQr ? 'Hide QR' : 'Show QR'">
                <svg v-if="showQr" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" class="h-5 w-5" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">
                  <path d="M6 18L18 6M6 6l12 12" />
                </svg>
                <svg v-else xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" class="h-5 w-5" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">
                  <path d="M2.25 12s3.75-7.5 9.75-7.5S21.75 12 21.75 12 18 19.5 12 19.5 2.25 12 2.25 12Z" />
                  <path d="M15 12a3 3 0 1 1-6 0 3 3 0 0 1 6 0Z" />
                </svg>
              </button>
            </div>
          </div>
          <div class="flex items-center justify-center">
            <Transition name="scale-fade">
              <div v-if="showQr" id="qr-panel" ref="qrPanelEl" tabindex="-1" role="region" aria-labelledby="qr-toggle" class="p-3 rounded-box bg-base-100/70 border border-base-300/50 shadow">
                <img :src="qrSrc" alt="QR to install SeedSphere addon in Stremio" class="w-full max-w-xs h-auto" />
                <div class="muted text-sm mt-1 text-center">Scan on mobile to open the manifest in Stremio</div>
              </div>
              <div v-else class="w-full max-w-sm">
                <BoostsTicker :max="5" />
              </div>
            </Transition>
          </div>
        </div>
        </section>
      </Transition>

      <!-- Feature highlights -->
      <section class="page-section grid app-grid sm:grid-cols-2 lg:grid-cols-4 auto-rows-fr" role="region" aria-labelledby="features-title">
        <h2 id="features-title" class="sr-only">Features</h2>
        <div class="card bg-base-200 border border-base-300/40 h-full">
          <div class="card-body flex flex-col">
            <h3 class="card-title text-base">Smart validation</h3>
            <p class="text-sm opacity-80">DNS/HTTP checks by default; optional aggressive mode with UDP handshakes.</p>
          </div>
        </div>
        <div class="card bg-base-200 border border-base-300/40 h-full">
          <div class="card-body flex flex-col">
            <h3 class="card-title text-base">Controlled boosts</h3>
            <p class="text-sm opacity-80">Unlimited by default; optionally cap how many trackers to add.</p>
          </div>
        </div>
        <div class="card bg-base-200 border border-base-300/40 h-full">
          <div class="card-body flex flex-col">
            <h3 class="card-title text-base">Privacy‑friendly</h3>
            <p class="text-sm opacity-80">No account required to use the addon; optional Magic Link to sync config.</p>
          </div>
        </div>
        <div class="card bg-base-200 border border-base-300/40 h-full">
          <div class="card-body flex flex-col">
            <h3 class="card-title text-base">Transparent</h3>
            <p class="text-sm opacity-80">Recent boosts and health stats reveal what happened and why.</p>
          </div>
        </div>
      </section>

      <!-- Live activity & stats -->
      <section class="page-section grid app-grid md:grid-cols-3 auto-rows-fr" role="region" aria-labelledby="live-title">
        <h2 id="live-title" class="sr-only">Live activity and stats</h2>
        <div class="md:col-span-2 h-full">
          <BoostsTicker :max="8" />
        </div>
        <div class="card bg-base-200 border border-base-300/50 h-full">
          <div class="card-body flex flex-col">
            <h3 class="card-title text-base">Tracker health</h3>
            <div class="text-sm opacity-80">Snapshot of the validation cache</div>
            <div class="mt-3 grid grid-cols-3 gap-2 text-center">
              <div>
                <div class="text-2xl font-bold">{{ healthStats.ok }}</div>
                <div class="text-xs opacity-70">Healthy</div>
              </div>
              <div>
                <div class="text-2xl font-bold">{{ healthStats.bad }}</div>
                <div class="text-xs opacity-70">Unhealthy</div>
              </div>
              <div>
                <div class="text-2xl font-bold">{{ healthStats.total }}</div>
                <div class="text-xs opacity-70">Total</div>
              </div>
            </div>
            <div class="mt-3">
              <progress class="progress progress-primary w-full" :value="healthStats.total ? Math.round(100 * (healthStats.ok / healthStats.total)) : 0" :aria-valuenow="healthStats.total ? Math.round(100 * (healthStats.ok / healthStats.total)) : 0" aria-valuemin="0" aria-valuemax="100" aria-describedby="health-percent" max="100" aria-label="Healthy trackers percentage"></progress>
              <div id="health-percent" class="text-xs mt-1 opacity-70">{{ healthStats.total ? Math.round(100 * (healthStats.ok / healthStats.total)) : 0 }}% healthy</div>
            </div>
            <div class="mt-3 text-right">
              <a href="/api/trackers/health" target="_blank" rel="noopener" class="link link-hover text-xs">View JSON →</a>
            </div>
          </div>
        </div>
      </section>

      <section class="card bg-base-200 shadow border border-base-300/50 page-section" role="region" aria-labelledby="install-title">
        <div class="card-body space-y-4">
          <h2 id="install-title" class="card-title">Install & Utilities</h2>
          <p>
            SeedSphere makes torrents connect faster and more reliably by validating trackers and appending only the healthy ones to your magnet links. The result is quicker starts, fewer stalls, and a smoother experience.
          </p>
          <ul class="list-disc pl-6">
            <li><strong>Smart validation</strong> — DNS/HTTP checks by default; optional aggressive mode with UDP handshakes.</li>
            <li><strong>Controlled boosts</strong> — Unlimited by default; optionally cap how many trackers to add.</li>
            <li><strong>Privacy-friendly</strong> — No account required to use the addon; Magic Link sign-in is available for configuration sync.</li>
            <li><strong>Full transparency</strong> — Recent Boosts and health stats show exactly what happened and why.</li>
          </ul>
          <div class="flex flex-wrap gap-2 items-center">
            <label v-if="isDevMode" class="text-sm opacity-80" for="manifest-variant">Manifest variant:</label>
            <select v-if="isDevMode" id="manifest-variant" class="select select-bordered select-sm max-w-xs" v-model="manifestVariant">
              <option v-for="opt in variantOptions" :key="opt.key" :value="opt.key">{{ opt.label }}</option>
            </select>
            <a v-if="isDevMode" class="btn btn-primary" :href="manifestProtocol">Install / Update in Stremio</a>
            <a v-if="!isDevMode" class="btn btn-primary" :href="baseManifestProtocol">Install in Stremio</a>
            <button class="btn" type="button" @click="openStremio">Open Stremio</button>
            <button class="btn" type="button" @click="copyInstall">Copy Install Link</button>
            <button v-if="canInstallPwa" class="btn" type="button" @click="installPwa">Install App</button>
            <a class="btn" href="/api/boosts/recent" target="_blank" rel="noopener">Recent boosts (JSON)</a>
            <a class="btn" href="/api/trackers/health" target="_blank" rel="noopener">Health stats (JSON)</a>
          </div>
          
          <!-- Platform-specific install instructions -->
          <div class="p-3 rounded-box bg-base-200/70">
            <div class="flex items-center gap-2">
              <div class="badge badge-info">Install Gardener</div>
              <span class="text-sm opacity-80">Based on your device/browser</span>
            </div>
            <ul class="list-disc pl-6 mt-2 text-sm">
              <li v-for="(msg, i) in installTips" :key="i">{{ msg }}</li>
            </ul>
            <div v-if="isStandalone" class="alert alert-success mt-2 text-sm">Gardener is installed. You can launch it from your apps/dock.</div>
          </div>
          <div class="text-sm opacity-70">
            <div>Manifest URL ({{ effectiveManifestVariantLabel }}): <code>{{ effectiveManifestHttp }}</code></div>
          </div>
          <!-- QR moved to Hero above -->
        </div>
      </section>
    </div>
  </main>
  
  <!-- Dev-only footer with Gardener ID -->
  <footer v-if="isDevMode && gardenerId" class="fixed bottom-2 left-1/2 -translate-x-1/2 z-50">
    <div class="badge badge-outline badge-info text-xs p-3 shadow">
      Gardener: <span class="ml-1 font-mono">{{ gardenerId }}</span>
    </div>
  </footer>
</template>

<script setup>
import { ref, computed, onMounted, onBeforeUnmount, watch, nextTick } from 'vue'
import { gardener } from '../lib/gardener'
import BoostsTicker from '../components/BoostsTicker.vue'

const origin = typeof window !== 'undefined' ? window.location.origin : ''
const manifestVariant = ref('base')
const variantOptions = [
  { key: 'base', label: 'Base (manifest.json)' },
  { key: 'experiment', label: 'Experiment (extra fields)' },
  { key: 'endpoint', label: 'Variant: endpoint' },
  { key: 'dontannounce', label: 'Variant: dontAnnounce' },
  { key: 'listedon', label: 'Variant: listedOn' },
  { key: 'isfree', label: 'Variant: isFree' },
  { key: 'suggested', label: 'Variant: suggested' },
  { key: 'searchdebounce', label: 'Variant: searchDebounce' },
  { key: 'countryspecific', label: 'Variant: countrySpecific' },
  { key: 'zipspecific', label: 'Variant: zipSpecific' },
  { key: 'countryspecificstreams', label: 'Variant: countrySpecificStreams' },
]
const manifestVariantLabel = computed(() => {
  const f = variantOptions.find(o => o.key === manifestVariant.value)
  return f ? f.label : manifestVariant.value
})

// Expose current gardener id for footer (dev-only)
const gardenerId = computed(() => {
  try { return gardener.getGardenerId() || '' } catch (_) { return '' }
})

// Helper to fetch and persist latest version for update banner
async function fetchLatestVersion() {
  try {
    const res = await fetch(effectiveManifestHttp.value, { cache: 'no-store' })
    if (!res.ok) return
    const m = await res.json()
    latestVersion.value = (m && m.version) || ''
    try { if (latestVersion.value) localStorage.setItem('seedsphere.version_latest', latestVersion.value) } catch (_) {}
    // Initialize seen on first-load for noise reduction
    try {
      if (!seenVersion.value && latestVersion.value) {
        localStorage.setItem('seedsphere.version_seen', latestVersion.value)
        seenVersion.value = latestVersion.value
      }
    } catch (_) {}
  } catch (_) { /* ignore */ }
}

// Fetch tracker health stats for the widget
async function fetchHealthStats() {
  try {
    const res = await fetch('/api/trackers/health', { cache: 'no-store' })
    if (!res.ok) return
    const json = await res.json()
    const ok = Number(json.ok || 0)
    const bad = Number(json.bad || 0)
    const total = Number(json.total || (ok + bad))
    healthStats.value = { ok, bad, total }
  } catch (_) { /* ignore */ }
}
const variantPath = computed(() => {
  const k = manifestVariant.value
  if (k === 'base') return '/manifest.json'
  if (k === 'experiment') return '/manifest.variant.experiment/manifest.json'
  // New preferred pattern: directory with manifest.json filename
  return `/manifest.variant.${k}/manifest.json`
})
const manifestHttp = computed(() => {
  try {
    const u = new URL(variantPath.value, origin || 'http://localhost')
    const gid = gardener.getGardenerId()
    if (gid) u.searchParams.set('gardener_id', gid)
    return u.toString()
  } catch (_) { return `${origin}${variantPath.value}` }
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
// Gate dev-only UI via ?dev=1
const isDevMode = computed(() => {
  try {
    const qs = typeof window !== 'undefined' ? window.location.search : ''
    const sp = new URLSearchParams(qs)
    return sp.get('dev') === '1'
  } catch (_) { return false }
})

// Base manifest helpers for normal mode
const baseManifestHttp = computed(() => {
  try {
    const u = new URL('/manifest.json', origin || 'http://localhost')
    const gid = gardener.getGardenerId()
    if (gid) u.searchParams.set('gardener_id', gid)
    return u.toString()
  } catch (_) { return `${origin}/manifest.json` }
})
const baseManifestProtocol = computed(() => toStremioProtocol(baseManifestHttp.value))

// Effective manifest link: base in normal mode, selected variant in dev mode
const effectiveManifestHttp = computed(() => (isDevMode.value ? manifestHttp.value : baseManifestHttp.value))
const manifestProtocol = computed(() => toStremioProtocol(effectiveManifestHttp.value))

// Re-fetch latest version whenever the effective manifest URL changes (e.g., dev mode / variant switch)
watch(effectiveManifestHttp, () => { fetchLatestVersion() })

// Label to display: force Base when not in dev mode
const effectiveManifestVariantLabel = computed(() => (isDevMode.value ? manifestVariantLabel.value : 'Base (manifest.json)'))

const latestVersion = ref('')
const seenVersion = ref('')
const healthStats = ref({ ok: 0, bad: 0, total: 0 })
let healthInterval = null
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
    await navigator.clipboard.writeText(effectiveManifestHttp.value)
  } catch (_) {
    // fallback
    const ta = document.createElement('textarea')
    ta.value = effectiveManifestHttp.value
    document.body.appendChild(ta)
    ta.select()
    document.execCommand('copy')
    document.body.removeChild(ta)
  }
}

function toggleQr() {
  showQr.value = !showQr.value
}

// Manage focus when toggling QR panel for better keyboard accessibility
const qrPanelEl = ref(null)
const qrToggleEl = ref(null)
watch(showQr, async (open) => {
  await nextTick()
  try {
    if (open && qrPanelEl.value) {
      qrPanelEl.value.focus()
    } else if (!open && qrToggleEl.value) {
      qrToggleEl.value.focus()
    }
  } catch (_) { /* ignore */ }
})

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

  // Load last seen and initial latest version
  try { seenVersion.value = localStorage.getItem('seedsphere.version_seen') || '' } catch (_) {}
  await fetchLatestVersion()

  // Theme on load
  const saved = localStorage.getItem('seedsphere-theme') || 'dark'
  applyTheme(saved)

  // Load and persist variant selection
  try {
    const savedVariant = localStorage.getItem('seedsphere.manifest_variant') || ''
    if (savedVariant) manifestVariant.value = savedVariant
  } catch (_) {}
  watch(manifestVariant, (v) => {
    try { localStorage.setItem('seedsphere.manifest_variant', v) } catch (_) {}
  })

  // Health stats initial load + interval
  await fetchHealthStats()
  healthInterval = setInterval(fetchHealthStats, 30_000)

  // Cleanup listener when component unmounts
  onBeforeUnmount(() => {
    window.removeEventListener('beforeinstallprompt', onBip)
    try { if (healthInterval) clearInterval(healthInterval) } catch (_) {}
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
/* Subtle transitions */
.slide-fade-enter-from,
.slide-fade-leave-to { opacity: 0; transform: translateY(-4px); }
.slide-fade-enter-active,
.slide-fade-leave-active { transition: opacity .25s ease, transform .25s ease; }

.scale-fade-enter-from,
.scale-fade-leave-to { opacity: 0; transform: scale(0.98); }
.scale-fade-enter-active,
.scale-fade-leave-active { transition: opacity .2s ease, transform .2s ease; }

/* Respect reduced motion preferences */
@media (prefers-reduced-motion: reduce) {
  .slide-fade-enter-active,
  .slide-fade-leave-active,
  .scale-fade-enter-active,
  .scale-fade-leave-active { transition: none !important; }
}

/* Focus outlines for keyboard navigation */
.btn:focus-visible,
.link:focus-visible,
button:focus-visible,
a:focus-visible,
select:focus-visible {
  outline: 2px solid hsl(var(--p));
  outline-offset: 2px;
}
</style>
