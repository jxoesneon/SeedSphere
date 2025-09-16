<template>
  <main class="min-h-screen text-base-content gardener-bg">
    <div v-if="!isInstalled" class="w-full min-h-screen grid place-items-center p-6">
      <div class="max-w-3xl w-full" style="max-width:95vw; max-height:95vh;">
        <div class="relative overflow-hidden rounded-3xl border border-base-300/50 shadow splash-card" style="max-width:95vw; max-height:95vh;">
          <img src="/assets/gardener-background.svg" alt="Gardener background" class="w-full h-auto block splash-img" />
          <div class="absolute inset-0 splash-gradient"></div>
          <div class="absolute bottom-0 left-0 right-0 p-6 md:p-8 splash-content">
            <h1 class="text-3xl md:text-4xl font-extrabold tracking-tight">SeedSphere Gardener</h1>
            <p class="mt-2 opacity-90 max-w-prose">Install the Gardener app to handle addon requests securely in the background. Minimal UI. Sign-in required.</p>
            <div class="mt-4 flex flex-wrap gap-2 items-center">
              <button class="btn btn-primary" type="button" :disabled="!canInstall || !splashMinElapsed" @click="installApp">Install app</button>
              <span v-if="!canInstall" class="text-sm opacity-80">Use your browser's Install option if disabled.</span>
            </div>
          </div>
        </div>
      </div>
    </div>

    <div v-else class="w-full min-h-screen grid place-items-center p-6">
      <!-- Gear trigger (top-left) -->
      <button
        class="gear-btn"
        type="button"
        aria-label="Open options"
        title="Options"
        @click="showDrawer = true"
      >
        <!-- Heroicons solid: cog-6-tooth -->
        <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="currentColor" width="18" height="18" aria-hidden="true">
          <path fill-rule="evenodd" d="M11.078 2.25c-.917 0-1.699.663-1.85 1.567l-.123.73a8.286 8.286 0 0 0-1.548.894l-.666-.386a1.875 1.875 0 0 0-2.51.684l-.75 1.3a1.875 1.875 0 0 0 .66 2.56l.666.386a8.365 8.365 0 0 0 0 1.788l-.666.386a1.875 1.875 0 0 0-.66 2.56l.75 1.3a1.875 1.875 0 0 0 2.51.684l.666-.386c.49.37 1.006.68 1.548.894l.123.73c.151.904.933 1.567 1.85 1.567h1.5c.917 0 1.699-.663 1.85-1.567l.123-.73c.542-.214 1.058-.524 1.548-.894l.666.386a1.875 1.875 0 0 0 2.51-.684l.75-1.3a1.875 1.875 0 0 0-.66-2.56l-.666-.386c.04-.593.04-1.195 0-1.788l.666-.386a1.875 1.875 0 0 0 .66-2.56l-.75-1.3a1.875 1.875 0 0 0-2.51-.684l-.666.386a8.286 8.286 0 0 0-1.548-.894l-.123-.73A1.875 1.875 0 0 0 12.578 2.25h-1.5ZM12 8.25a3.75 3.75 0 1 0 0 7.5 3.75 3.75 0 0 0 0-7.5Z" clip-rule="evenodd" />
        </svg>
      </button>
      <!-- Chart toggle (bottom-right) -->
      <button
        class="chart-btn"
        :class="{ active: showBottomChart }"
        type="button"
        aria-label="Toggle activity chart"
        :aria-pressed="showBottomChart ? 'true' : 'false'"
        title="Toggle activity chart"
        @click="toggleBottomChart"
      >
        <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="currentColor" width="18" height="18" aria-hidden="true">
          <path d="M3.75 4.5a.75.75 0 0 0-.75.75v13.5c0 .414.336.75.75.75h16.5a.75.75 0 0 0 .75-.75V5.25a.75.75 0 0 0-.75-.75H3.75Zm.75 1.5h15v12h-15v-12Z" />
          <path d="M7.5 15.75a.75.75 0 0 1-.75-.75v-3a.75.75 0 0 1 1.5 0v3a.75.75 0 0 1-.75.75Zm4.5 0a.75.75 0 0 1-.75-.75V9a.75.75 0 0 1 1.5 0v6a.75.75 0 0 1-.75.75Zm4.5 0a.75.75 0 0 1-.75-.75V12a.75.75 0 0 1 1.5 0v3a.75.75 0 0 1-.75.75Z" />
        </svg>
      </button>
      <div id="status" class="sr-only" aria-hidden="true"></div>
      <div class="max-w-xl w-full" style="max-width:95vw; max-height:95vh;">
        <!-- Window titlebar area (draggable) with Gardener ID -->
        <div class="wco-bar" :class="{ wco: isWco }">
          <div class="wco-inner">
            <div class="wco-gid no-drag" v-if="gardenerId">{{ gardenerId }}</div>
          </div>
        </div>

        <!-- Minimal running center indicator over background -->
        <section class="runner-host">
          <div v-if="!isOnline" class="mb-2">
            <div class="alert alert-warning shadow-sm text-sm">
              <span>Offline mode: changes will be queued and synced when connection is restored.</span>
            </div>
          </div>
          <div v-if="runnerTip" class="tooltip" :data-tip="runnerTip">
            <div class="runner" :class="runnerClass" :aria-label="`Status: ${runnerLabel}`" @dblclick="openDetails">
              <span>{{ runnerLabel }}</span>
            </div>
          </div>
          <div v-else>
            <div class="runner" :class="runnerClass" :aria-label="`Status: ${runnerLabel}`" @dblclick="openDetails">
              <span>{{ runnerLabel }}</span>
            </div>
          </div>
          <div
            class="mt-4 text-center text-xs opacity-90 cursor-pointer select-none hover:opacity-100"
            :title="'Click to refresh linked count'"
            role="button"
            tabindex="0"
            @click="refreshLinked"
            @keydown.enter.prevent="refreshLinked"
            @keydown.space.prevent="refreshLinked"
          >
            Linked: {{ linkedSeedlings.length || 0 }}
          </div>
          <div class="mt-1 text-center text-[11px] opacity-80">
            Throttling: <span class="font-mono">
              {{ cfgAdaptive ? 'Adaptive' : 'Static' }}
            </span>
            <span v-if="cfgAdaptive" class="opacity-80">(CPU ≤ {{ (cfgMaxCpu*100).toFixed(0) }}%, MEM ≤ {{ (cfgMaxMem*100).toFixed(0) }}%)</span>
            <span v-else class="opacity-80">(interval ≈ {{ cfgMinInterval }} ms)</span>
          </div>
          
          <div v-if="allSetMsg" class="allset">
            <button type="button" class="msg" @click="openStremio" title="Open Stremio">All set — open Stremio to start watching.</button>
          </div>
        </section>
      </div>
    </div>

    <!-- Bottom refresher removed; linked text is now clickable -->

    <!-- Local toast (forced top-right via Teleport) -->
    <teleport to="body">
      <div v-if="toastMsg" class="fixed top-3 right-3 z-[1000]">
        <div class="alert alert-success shadow-lg">
          <span>{{ toastMsg }}</span>
        </div>
      </div>
    </teleport>

    <!-- Bottom activity overlay -->
    <teleport to="body">
      <canvas v-if="showBottomChart" ref="bottomCanvas" class="bottom-activity"></canvas>
    </teleport>

    <!-- Details modal -->
    <teleport to="body">
      <div v-if="showDetails" class="modal-backdrop" @click.self="closeDetails">
        <div class="modal-card" role="dialog" aria-modal="true" aria-label="Connection details">
          <div class="modal-hd">
            <div class="title">Connection details</div>
            <button type="button" class="btn btn-ghost btn-xs" @click="closeDetails">Close</button>
          </div>
          <div class="modal-body">
            <div class="kv"><div class="k">Status</div><div class="v"><span class="badge">{{ runnerLabel }}</span> <span class="opacity-75">({{ effectiveStatus }})</span></div></div>
            <div class="kv"><div class="k">Gardener ID</div><div class="v"><code>{{ gardenerId }}</code> <button class="btn btn-ghost btn-xs" @click="copy(gardenerId)">Copy</button></div></div>
            <div class="kv"><div class="k">Linked seedlings</div><div class="v">{{ linkedSeedlings.length }}</div></div>
            <div class="kv"><div class="k">Status endpoint</div><div class="v"><code>/api/link/status?gardener_id={{ gardenerId }}</code> <button class="btn btn-ghost btn-xs" @click="copy(`/api/link/status?gardener_id=${encodeURIComponent(gardenerId)}`)">Copy</button></div></div>
            <div class="kv"><div class="k">SSE endpoint</div><div class="v"><code>{{ roomEndpoint }}</code> <button class="btn btn-ghost btn-xs" @click="copy(roomEndpoint)">Copy</button></div></div>
            <div class="kv"><div class="k">SSE state</div><div class="v">{{ sseReadyStateLabel }} • opens: {{ roomOpenCount }} • events: {{ roomEventCount }} • errors: {{ roomErrorCount }}</div></div>
            <div class="kv"><div class="k">SSE connected</div><div class="v">{{ ts(roomOpenedAt) }}</div></div>
            <div class="kv"><div class="k">Last event</div><div class="v">{{ ts(roomLastEventAt) }}</div></div>
            <div class="kv" v-if="roomErrorAt"><div class="k">Last error</div><div class="v">{{ ts(roomErrorAt) }}</div></div>
            <div class="kv"><div class="k">Last SSE type</div><div class="v">{{ roomLastEventType || '—' }}</div></div>
            <div class="kv"><div class="k">Last status refresh</div><div class="v">{{ ts(lastStatusRefreshAt) }}</div></div>
            <div class="kv"><div class="k">Installed</div><div class="v">{{ isInstalled ? 'Yes' : 'No' }}</div></div>
            <div class="kv"><div class="k">Service Worker</div><div class="v">scope: <code>{{ swInfo.scope }}</code> • active: {{ swInfo.active ? 'Yes' : 'No' }}</div></div>
            <div class="kv"><div class="k">WCO visible</div><div class="v">{{ isWco ? 'Yes' : 'No' }}</div></div>
            <div class="kv"><div class="k">Auth</div><div class="v">{{ authUserSummary }}</div></div>
            <div class="kv"><div class="k">Origin</div><div class="v"><code>{{ envInfo.origin }}</code></div></div>
            <div class="kv"><div class="k">Page</div><div class="v"><code>{{ envInfo.href }}</code></div></div>
            <div class="kv"><div class="k">User Agent</div><div class="v"><code>{{ envInfo.userAgent }}</code></div></div>
            <div class="kv"><div class="k">Platform</div><div class="v">{{ envInfo.platform }} • {{ envInfo.language }} • {{ envInfo.timezone }}</div></div>
            <div class="kv"><div class="k">SW states</div><div class="v">installing: {{ swDetails.installingState || '—' }} • waiting: {{ swDetails.waitingState || '—' }} • active: {{ swDetails.activeState || '—' }} • controller: {{ swDetails.controller ? 'Yes' : 'No' }}</div></div>
            <div class="kv"><div class="k">SW update found</div><div class="v">{{ ts(swDetails.updateFoundAt) }}</div></div>
            <div class="kv"><div class="k">SW last state change</div><div class="v">{{ ts(swDetails.lastStateChangeAt) }}</div></div>
            <div class="kv"><div class="k">API ping</div><div class="v">{{ apiPingMs == null ? '—' : apiPingMs + ' ms' }} <span class="opacity-75">{{ apiPingOk == null ? '' : (apiPingOk ? '(ok)' : '(fail)') }}</span></div></div>
            <div class="kv"><div class="k">SSE probe</div><div class="v">{{ sseProbeMs == null ? '—' : sseProbeMs + ' ms' }} <span class="opacity-75">{{ sseProbeOk == null ? '' : (sseProbeOk ? '(ok)' : '(fail)') }}</span></div></div>
            <div class="kv"><div class="k">SSE connect</div><div class="v">{{ sseConnectMs == null ? '—' : (sseConnectMs + ' ms to first event') }}</div></div>
            <div v-if="devMode" class="mt-2 grid gap-3">
              <div>
                <div class="opacity-80 text-sm mb-1">API ping history (ms)</div>
                <canvas ref="apiCanvas" class="chart-canvas" height="100"></canvas>
              </div>
              <div>
                <div class="opacity-80 text-sm mb-1">SSE probe history (ms)</div>
                <canvas ref="sseCanvas" class="chart-canvas" height="100"></canvas>
              </div>
            </div>
            <details class="mt-4" v-if="devMode">
              <summary class="cursor-pointer">Linked seedlings (raw)</summary>
              <pre class="pre">{{ JSON.stringify(linkedSeedlings, null, 2) }}</pre>
            </details>
            <details class="mt-2" v-if="devMode">
              <summary class="cursor-pointer">Recent SSE events</summary>
              <pre class="pre">{{ JSON.stringify(roomEventLog, null, 2) }}</pre>
            </details>
            <details class="mt-2" v-if="devMode && roomLastEventData">
              <summary class="cursor-pointer">Last SSE payload</summary>
              <pre class="pre">{{ roomLastEventData }}</pre>
            </details>
            <details class="mt-2" v-if="devMode">
              <summary class="cursor-pointer">Status history (last 20)</summary>
              <pre class="pre">{{ JSON.stringify(statusLog, null, 2) }}</pre>
            </details>
            <details class="mt-2" v-if="devMode">
              <summary class="cursor-pointer">Provider activity</summary>
              <pre class="pre">{{ JSON.stringify(providerActivity, null, 2) }}</pre>
            </details>
          </div>
          <div class="modal-ft">
            <div class="flex items-center gap-2">
              <button type="button" class="btn btn-ghost btn-sm" @click="runPingTests">Run ping tests</button>
              <button type="button" class="btn btn-ghost btn-sm" @click="downloadDiagnostics">Download logs</button>
              <button type="button" class="btn btn-ghost btn-sm" @click="checkSwUpdate">Check SW update</button>
              <button type="button" class="btn btn-ghost btn-sm" @click="copyDiagnostics">Copy diagnostics</button>
              <button type="button" class="btn btn-ghost btn-sm" @click="refreshLinked">Refresh status</button>
              <button type="button" class="btn btn-ghost btn-sm" @click="reconnectSse">Reconnect SSE</button>
              <button type="button" class="btn btn-primary btn-sm" @click="openStremio">Open Stremio</button>
            </div>
          </div>
        </div>
      </div>
    </teleport>

    <!-- Drawer -->
    <div v-if="showDrawer" class="drawer-backdrop" @click="closeDrawer"></div>
    <aside v-if="showDrawer" class="drawer left">
      <div class="drawer-hd">
        <div class="title">Options</div>
        <button class="btn btn-ghost btn-xs" type="button" @click="closeDrawer">Close</button>
      </div>
      <div class="drawer-body">
        <label class="label cursor-pointer gap-2 items-center">
          <span class="label-text">Developer mode</span>
          <input type="checkbox" class="toggle" v-model="devMode" />
        </label>
        <div class="mt-4" v-if="devMode">
          <label class="label" for="state-override"><span class="label-text">Runner state</span></label>
          <select id="state-override" class="select select-bordered w-full" v-model="stateOverride">
            <option value="auto">Auto (SSE)</option>
            <option value="waiting">Connecting</option>
            <option value="ok">Running</option>
            <option value="warn">Idle</option>
            <option value="error">Offline</option>
          </select>
          <div class="mt-3">
            <button type="button" class="btn btn-outline btn-sm" @click="triggerAllSetNow">Show "All set" message</button>
          </div>
          <div class="mt-4 grid gap-2">
            <label class="label" for="idle-wave-ratio"><span class="label-text">Idle wave ratio (amplitude : wavelength)</span></label>
            <input id="idle-wave-ratio" type="range" min="0.5" max="5" step="0.1" v-model.number="idleWaveRatio" />
            <div class="flex items-center gap-2">
              <input type="number" min="0.5" max="5" step="0.1" class="input input-bordered input-sm w-28" v-model.number="idleWaveRatio" />
              <span class="opacity-75 text-sm">Default: 2.5</span>
            </div>
          </div>
        </div>

        <!-- Settings -->
        <div class="mt-6">
          <div class="text-sm font-semibold mb-2">Settings</div>
          <div class="grid gap-3">
            <label class="label cursor-pointer gap-2 items-center">
              <span class="label-text">Adaptive throttling</span>
              <input type="checkbox" class="toggle" v-model="cfgAdaptive" />
            </label>
            <div class="grid gap-1">
              <label class="label" for="cfg-max-cpu"><span class="label-text">Max CPU ratio</span></label>
              <input id="cfg-max-cpu" type="number" step="0.05" min="0.2" max="1" class="input input-bordered input-sm w-32" v-model.number="cfgMaxCpu" />
              <span class="opacity-70 text-xs">Default: 0.85</span>
            </div>
            <div class="grid gap-1">
              <label class="label" for="cfg-max-mem"><span class="label-text">Max memory ratio</span></label>
              <input id="cfg-max-mem" type="number" step="0.05" min="0.5" max="0.98" class="input input-bordered input-sm w-32" v-model.number="cfgMaxMem" />
              <span class="opacity-70 text-xs">Default: 0.90</span>
            </div>
            <div class="grid gap-1">
              <label class="label" for="cfg-min-interval"><span class="label-text">Min interval (ms)</span></label>
              <input id="cfg-min-interval" type="number" step="50" min="200" class="input input-bordered input-sm w-32" v-model.number="cfgMinInterval" />
              <span class="opacity-70 text-xs">Default: 500</span>
            </div>
            <div class="grid gap-1">
              <label class="label" for="cfg-max-interval"><span class="label-text">Max interval (ms)</span></label>
              <input id="cfg-max-interval" type="number" step="100" :min="cfgMinInterval" class="input input-bordered input-sm w-32" v-model.number="cfgMaxInterval" />
              <span class="opacity-70 text-xs">Default: 8000</span>
            </div>
            <div class="grid gap-1">
              <label class="label" for="cfg-hb-every"><span class="label-text">Heartbeat every (loops)</span></label>
              <input id="cfg-hb-every" type="number" step="1" min="1" class="input input-bordered input-sm w-32" v-model.number="cfgHeartbeatEvery" />
              <span class="opacity-70 text-xs">Default: 3</span>
            </div>
            <div class="mt-2">
              <button class="btn btn-ghost btn-sm" type="button" @click="copyExecutorEnv">Copy CLI env for executor</button>
              <span class="opacity-70 text-xs ml-2">Paste into your terminal before running the executor CLI</span>
            </div>
            <div class="divider my-1"></div>
            <div class="grid gap-1">
              <div class="text-xs opacity-80">Effective settings</div>
              <div class="text-xs font-mono break-words">
                {{ effectiveSettingsSummary }}
              </div>
            </div>
            <div>
              <button class="btn btn-outline btn-xs" type="button" @click="resetExecutorPrefs">Reset to defaults</button>
              <button class="btn btn-outline btn-xs ml-2" type="button" @click="applyLowEndPreset">Low-end preset</button>
            </div>
          </div>
        </div>
      </div>
    </aside>

    <!-- User-triggered splash overlay -->
    <div v-if="showSplash" class="fixed inset-0 z-50" :class="{ wco: isWco }">
      <img src="/assets/gardener-background.svg" alt="Gardener background" class="splash-bg" />
      <div class="absolute inset-0 splash-gradient" aria-hidden="true"></div>
      <div class="absolute top-0 left-0 right-0 text-center top-title">
        <h1 class="text-3xl md:text-4xl font-extrabold tracking-tight">SeedSphere Gardener</h1>
      </div>
      <div class="absolute left-0 right-0 text-center bottom-loading">
        <div class="loading-text">Loading<span class="dots"><span>.</span><span>.</span><span>.</span></span></div>
      </div>
    </div>
  </main>
</template>

<script setup>
import { ref, computed, onMounted, onBeforeUnmount, watch } from 'vue'
import { auth } from '../lib/auth'
import { emitLog } from '../lib/rolllog'

const busy = ref(false)
const notice = ref('')
const isOnline = ref(true)
const isInstalled = ref(false)
const deferredPrompt = ref(null)
const canInstall = ref(false)
const gardenerId = ref('')
const linkedSeedlings = ref([])
const splashMinElapsed = ref(false)
let splashMinTimer = null
let splashMaxTimer = null
let splashAutoHideTimer = null
const showSplash = ref(false)
const isWco = ref(false)
const toastMsg = ref('')
let toastTimer = null
function showToast(msg, duration = 1200) {
  try { if (toastTimer) clearTimeout(toastTimer) } catch (_) {}
  toastMsg.value = String(msg || '')
  if (duration > 0) {
    try { toastTimer = setTimeout(() => { toastMsg.value = '' }, duration) } catch (_) {}
  }
}
const roomStatus = ref('waiting') // waiting | ok | warn | error
let esRoom = null
const showDrawer = ref(false)
const devMode = ref(false)
const stateOverride = ref('auto') // 'auto' | waiting | ok | warn | error
const allSetMsg = ref(false)
let allSetTimer = null
const showDetails = ref(false)
const roomOpenedAt = ref(0)
const roomLastEventAt = ref(0)
const roomErrorAt = ref(0)
const roomEndpoint = ref('')
const lastStatusRefreshAt = ref(0)
const swInfo = ref({ scope: '/gardener/', active: false })
const roomEventCount = ref(0)
const roomErrorCount = ref(0)
const roomOpenCount = ref(0)
const roomEventLog = ref([])
const envInfo = ref({ origin: '', href: '', userAgent: '', platform: '', language: '', timezone: '' })
const roomLastEventType = ref('')
const roomLastEventData = ref('')
const swDetails = ref({ installingState: '', waitingState: '', activeState: '', controller: false, updateFoundAt: 0, lastStateChangeAt: 0 })
const statusLog = ref([])
const providerActivity = ref({})
const apiPingMs = ref(null)
const apiPingOk = ref(null)
const sseProbeMs = ref(null)
const sseProbeOk = ref(null)
const roomOpenToFirstMs = ref(null)
const apiPingHistory = ref([])
const sseProbeHistory = ref([])
const apiCanvas = ref(null)
const sseCanvas = ref(null)
let pingsLoopTimer = null
const showBottomChart = ref(false)
const bottomCanvas = ref(null)
const bottomActivityHistory = ref([])
const sseEventsSinceSample = ref(0)
const lastIdleDisplay = ref(0)
const idleWaveRatio = ref(2.5)

// Effective status used by runner UI
const effectiveStatus = computed(() => (stateOverride.value !== 'auto' ? stateOverride.value : roomStatus.value))

const runnerClass = computed(() => {
  switch (effectiveStatus.value) {
    case 'ok': return 'runner-ok'
    case 'warn': return 'runner-warn'
    case 'error': return 'runner-error'
    default: return 'runner-wait'
  }
})

const runnerLabel = computed(() => {
  switch (effectiveStatus.value) {
    case 'ok': return 'Running'
    case 'warn': return 'Idle'
    case 'error': return 'Offline'
    default: return 'Connecting'
  }
})

// Tooltip text for abnormal statuses
const runnerTip = computed(() => {
  switch (effectiveStatus.value) {
    case 'warn':
      return 'No current activity. Gardener is connected and standing by.'
    case 'error':
      return 'Cannot reach executor room. Check network or try reopening the app.'
    case 'waiting':
      return 'Connecting to executor room…'
    default:
      return ''
  }
})

// Lightweight status refresh helper
async function refreshStatus() {
  busy.value = true
  try {
    const gid = gardenerId.value || localStorage.getItem('gardener_id') || ''
    if (!gid) return
    const url = `/api/link/status?gardener_id=${encodeURIComponent(gid)}`
    const res = await fetch(url, { cache: 'no-store' })
    if (res.ok) {
      const j = await res.json()
      try {
        const arr = (j && Array.isArray(j.bindings)) ? j.bindings : (j && Array.isArray(j.linked_seedlings)) ? j.linked_seedlings : []
        linkedSeedlings.value = arr
        try { emitLog('client_link_status', { gardener_id: gid, linked_count: arr.length, user_id: j && j.user_id }) } catch (_) {}
      } catch (_) {}
    }
  } catch (_) {}
  finally { busy.value = false; try { lastStatusRefreshAt.value = Date.now() } catch (_) {} }
}

// Effective settings summary for display in drawer
const effectiveSettingsSummary = computed(() => {
  try {
    if (!cfgAdaptive.value) {
      const minI = Math.max(200, Number(cfgMinInterval.value)||500)
      return `static interval=${minI}ms`
    }
    const cpu = (Number(cfgMaxCpu.value||0.85) * 100).toFixed(0)
    const mem = (Number(cfgMaxMem.value||0.9) * 100).toFixed(0)
    const minI = Math.max(200, Number(cfgMinInterval.value)||500)
    const maxI = Math.max(minI, Number(cfgMaxInterval.value)||8000)
    const hb = Math.max(1, Number(cfgHeartbeatEvery.value)||3)
    return `adaptive cpu<=${cpu}% mem<=${mem}% min=${minI}ms max=${maxI}ms hb=${hb}`
  } catch { return '—' }
})

// "All set" helper banner management
function maybeAllSet() {
  try { if (allSetTimer) clearTimeout(allSetTimer) } catch (_) {}
  allSetMsg.value = false
  try {
    const good = isInstalled.value && Boolean(gardenerId.value) && (effectiveStatus.value === 'ok' || effectiveStatus.value === 'warn')
    if (good) {
      allSetTimer = setTimeout(() => { allSetMsg.value = true }, 2000)
    }
  } catch (_) {}
}

// Simple timestamp formatter used in details modal
function ts(v) {
  try {
    const n = Number(v)
    if (!Number.isFinite(n) || n <= 0) return '—'
    const d = new Date(n)
    return d.toLocaleString()
  } catch (_) { return '—' }
}

// Copy helper for details modal buttons
async function copy(text) {
  try {
    await navigator.clipboard.writeText(String(text ?? ''))
    showToast('Copied')
  } catch (_) { showToast('Copy failed') }
}

// Linked refresher used by runner UI button
async function refreshLinked() {
  await refreshStatus()
  try { await loadServerPrefs() } catch (_) {}
  showToast('Linked count refreshed')
}

function triggerAllSetNow() {
  try { if (allSetTimer) clearTimeout(allSetTimer) } catch (_) {}
  allSetMsg.value = true
}

// Executor adaptive settings (for external CLI; we provide copyable envs)
const cfgAdaptive = ref(true)
const cfgMaxCpu = ref(0.85)
const cfgMaxMem = ref(0.9)
const cfgMinInterval = ref(500)
const cfgMaxInterval = ref(8000)
const cfgHeartbeatEvery = ref(3)
const LS_EXECUTOR_PREFS = 'gardener_executor_prefs'
function saveExecutorPrefs() {
  try {
    const obj = {
      a: !!cfgAdaptive.value,
      c: Number(cfgMaxCpu.value)||0.85,
      m: Number(cfgMaxMem.value)||0.9,
      min: Math.max(200, Number(cfgMinInterval.value)||500),
      max: Math.max(Number(cfgMinInterval.value)||500, Number(cfgMaxInterval.value)||8000),
      hb: Math.max(1, Number(cfgHeartbeatEvery.value)||3),
    }
    localStorage.setItem(LS_EXECUTOR_PREFS, JSON.stringify(obj))
  } catch (_) {}
}
function loadExecutorPrefs() {
  try {
    const raw = localStorage.getItem(LS_EXECUTOR_PREFS)
    if (!raw) return
    const obj = JSON.parse(raw)
    if (obj && typeof obj === 'object') {
      if (typeof obj.a === 'boolean') cfgAdaptive.value = obj.a
      if (Number.isFinite(obj.c)) cfgMaxCpu.value = obj.c
      if (Number.isFinite(obj.m)) cfgMaxMem.value = obj.m
      if (Number.isFinite(obj.min)) cfgMinInterval.value = obj.min
      if (Number.isFinite(obj.max)) cfgMaxInterval.value = Math.max(obj.min || 500, obj.max)
      if (Number.isFinite(obj.hb)) cfgHeartbeatEvery.value = Math.max(1, obj.hb)
    }
  } catch (_) {}
}
watch([cfgAdaptive, cfgMaxCpu, cfgMaxMem, cfgMinInterval, cfgMaxInterval, cfgHeartbeatEvery], () => { try { saveExecutorPrefs() } catch (_) {} })

async function copyExecutorEnv() {
  try {
    const lines = []
    if (!cfgAdaptive.value) {
      // If adaptive is off, suggest conservative static pacing via min=max
      lines.push(`GARDENER_MIN_INTERVAL_MS=${Math.max(200, Number(cfgMinInterval.value)||500)}`)
      lines.push(`GARDENER_MAX_INTERVAL_MS=${Math.max(200, Number(cfgMinInterval.value)||500)}`)
    } else {
      lines.push(`GARDENER_MAX_CPU_RATIO=${Number(cfgMaxCpu.value||0.85).toFixed(2)}`)
      lines.push(`GARDENER_MAX_MEM_RATIO=${Number(cfgMaxMem.value||0.9).toFixed(2)}`)
      lines.push(`GARDENER_MIN_INTERVAL_MS=${Math.max(200, Number(cfgMinInterval.value)||500)}`)
      lines.push(`GARDENER_MAX_INTERVAL_MS=${Math.max(Math.max(200, Number(cfgMinInterval.value)||500), Number(cfgMaxInterval.value)||8000)}`)
      lines.push(`GARDENER_HEARTBEAT_EVERY=${Math.max(1, Number(cfgHeartbeatEvery.value)||3)}`)
    }
    const text = lines.join(' ')
    await navigator.clipboard.writeText(text)
    showToast('Executor env copied')
  } catch (_) { showToast('Copy failed') }

// --- Preferences helpers (server sync) ---
function currentPrefsObj() {
  return {
    adaptive: !!cfgAdaptive.value,
    max_cpu_ratio: Number(cfgMaxCpu.value)||0.85,
    max_mem_ratio: Number(cfgMaxMem.value)||0.9,
    min_interval_ms: Math.max(200, Number(cfgMinInterval.value)||500),
    max_interval_ms: Math.max(Math.max(200, Number(cfgMinInterval.value)||500), Number(cfgMaxInterval.value)||8000),
    heartbeat_every: Math.max(1, Number(cfgHeartbeatEvery.value)||3),
  }
}

async function loadServerPrefs() {
  try {
    const gid = gardenerId.value || localStorage.getItem('gardener_id') || ''
    if (!gid) return
    const res = await fetch(`/api/gardeners/${encodeURIComponent(gid)}/prefs`, { cache: 'no-store', credentials: 'include' })
    const j = await res.json()
    if (res.ok && j && j.ok !== false && j.prefs) {
      const p = j.prefs || {}
      if (typeof p.adaptive === 'boolean') cfgAdaptive.value = p.adaptive
      if (Number.isFinite(p.max_cpu_ratio)) cfgMaxCpu.value = p.max_cpu_ratio
      if (Number.isFinite(p.max_mem_ratio)) cfgMaxMem.value = p.max_mem_ratio
      if (Number.isFinite(p.min_interval_ms)) cfgMinInterval.value = p.min_interval_ms
      if (Number.isFinite(p.max_interval_ms)) cfgMaxInterval.value = Math.max(p.min_interval_ms || 500, p.max_interval_ms)
      if (Number.isFinite(p.heartbeat_every)) cfgHeartbeatEvery.value = Math.max(1, p.heartbeat_every)
      saveExecutorPrefs()
    }
  } catch (_) { /* ignore */ }
}

let prefsSaveTimer = null
function scheduleSaveServerPrefs() {
  try { if (prefsSaveTimer) clearTimeout(prefsSaveTimer) } catch (_) {}
  prefsSaveTimer = setTimeout(saveServerPrefs, 500)
}
}

function resetExecutorPrefs() {
  try {
    cfgAdaptive.value = true
    cfgMaxCpu.value = 0.85
    cfgMaxMem.value = 0.9
    cfgMinInterval.value = 500
    cfgMaxInterval.value = 8000
    cfgHeartbeatEvery.value = 3
    saveExecutorPrefs()
    scheduleSaveServerPrefs()
    showToast('Settings reset')
  } catch (_) {}
}

// (removed duplicate empty applyLowEndPreset)

async function saveServerPrefs() {
  try {
    const gid = gardenerId.value || localStorage.getItem('gardener_id') || ''
    if (!gid) return
    const prefs = currentPrefsObj()
    if (!navigator.onLine) {
      pendingPrefsQueue.push(prefs)
      showToast('Saved offline (queued)')
      return
    }
    const res = await fetch(`/api/gardeners/${encodeURIComponent(gid)}/prefs`, { method: 'POST', headers: { 'Content-Type': 'application/json' }, credentials: 'include', body: JSON.stringify({ prefs }) })
    const j = await res.json()
    if (!(res.ok && j && j.ok)) throw new Error('save_failed')
    showToast('Settings saved', 900)
  } catch (_) { try { showToast('Saving settings failed', 1500) } catch (_) {} }
}

onMounted(async () => {
  // Require login context to proceed further (router meta already enforces auth)
  try { if (!auth.state.user) await auth.fetchSession() } catch (_) {}
  // Prepare PWA metadata and SW for this subroute
  ensureGardenerManifest()
  await registerGardenerSw()
  try {
    const reg = await (navigator.serviceWorker && navigator.serviceWorker.getRegistration && navigator.serviceWorker.getRegistration('/gardener/'))
    if (reg) swInfo.value = { scope: reg.scope || '/gardener/', active: Boolean(reg.active || reg.waiting || reg.installing) }
    if (reg) attachSwListeners(reg)
  } catch (_) {}

  // beforeinstallprompt handling scoped to this page
  const handler = (e) => { e.preventDefault(); deferredPrompt.value = e; canInstall.value = true }
  const onInstalled = () => {
    try {
      isInstalled.value = true
      showSplash.value = true
      startSplashTimers()
    } catch (_) {}
  }
  try { window.addEventListener('beforeinstallprompt', handler) } catch (_) {}
  try { window.addEventListener('appinstalled', onInstalled) } catch (_) {}

  detectInstalled()
  // Load dev control: idle wave ratio
  try { const r = Number(localStorage.getItem('idle_wave_ratio') || '') ; if (!Number.isNaN(r) && r > 0) idleWaveRatio.value = Math.min(5, Math.max(0.5, r)) } catch (_) {}
  try {
    envInfo.value = {
      origin: window.location.origin,
      href: window.location.href,
      userAgent: navigator.userAgent,
      platform: navigator.platform || (navigator.userAgentData && navigator.userAgentData.platform) || '',
      language: navigator.language || (navigator.languages && navigator.languages[0]) || '',
      timezone: Intl.DateTimeFormat().resolvedOptions().timeZone || ''
    }
  } catch (_) {}
  // Load any previously registered gardener_id and status
  try { const gid = localStorage.getItem('gardener_id') || ''; if (gid) gardenerId.value = gid } catch (_) {}
  // Expose gardener_id via cookie so /configure can auto-link
  try { document.cookie = `gardener_id=${encodeURIComponent(gardenerId.value || '')}; Path=/; Max-Age=864000` } catch (_) {}
  // Load executor prefs for convenience
  try { loadExecutorPrefs() } catch (_) {}
  // Online/offline detection
  try {
    isOnline.value = navigator.onLine
    const onOnline = () => { try { isOnline.value = true; flushPendingPrefs(); emitLog('client_online', { online: true, gardener_id: gardenerId.value || localStorage.getItem('gardener_id') || '' }) } catch (_) {} }
    const onOffline = () => { try { isOnline.value = false; emitLog('client_online', { online: false, gardener_id: gardenerId.value || localStorage.getItem('gardener_id') || '' }) } catch (_) {} }
    window.addEventListener('online', onOnline)
    window.addEventListener('offline', onOffline)
  } catch (_) {}
  // Auto-register when installed and not yet registered
  if (isInstalled.value && !gardenerId.value) {
    await registerDevice()
  }
  await refreshStatus()
  // Load server-side prefs for this gardener
  try { await loadServerPrefs() } catch (_) {}
  // Connect room SSE once we know the gardenerId
  try { if (gardenerId.value) connectRoomSse() } catch (_) {}
  // Start 2s diagnostics ping loop
  try { startPingLoop() } catch (_) {}

  // Re-check installed state after a short delay (covers install flows on some browsers)
  setTimeout(detectInstalled, 1200)

  // If already running as PWA (installed), show splash automatically
  if (isInstalled.value) {
    showSplash.value = true
  }
  startSplashTimers()
  maybeAllSet()

  // Window Controls Overlay (desktop Chromium)
  try {
    const wco = navigator && navigator.windowControlsOverlay
    if (wco && typeof wco.visible === 'boolean') {
      isWco.value = Boolean(wco.visible)
      const onGeom = () => { try { isWco.value = Boolean(wco.visible) } catch (_) {} }
      try { wco.addEventListener('geometrychange', onGeom) } catch (_) {}
    }
  } catch (_) {}

  // Redraw charts on resize
  try { window.addEventListener('resize', handleResize) } catch (_) {}
})

// Top-level resize handler so we can unregister safely
function handleResize() { try { drawPingCharts(); if (showBottomChart.value) drawBottomActivity() } catch (_) {} }

onBeforeUnmount(() => {
  try { window.removeEventListener('beforeinstallprompt', () => {}) } catch (_) {}
  try { window.removeEventListener('appinstalled', () => {}) } catch (_) {}
  try { window.removeEventListener('resize', handleResize) } catch (_) {}
  try { splashMinTimer && clearTimeout(splashMinTimer) } catch (_) {}
  try { splashMaxTimer && clearTimeout(splashMaxTimer) } catch (_) {}
  try { splashAutoHideTimer && clearTimeout(splashAutoHideTimer) } catch (_) {}
  try { toastTimer && clearTimeout(toastTimer) } catch (_) {}
  try { esRoom && esRoom.close() } catch (_) {}
  try { allSetTimer && clearTimeout(allSetTimer) } catch (_) {}
  try { stopPingLoop() } catch (_) {}
})

function startSplashTimers() {
  try {
    // Reset gates
    splashMinElapsed.value = false
    if (splashMinTimer) clearTimeout(splashMinTimer)
    if (splashMaxTimer) clearTimeout(splashMaxTimer)
    if (splashAutoHideTimer) clearTimeout(splashAutoHideTimer)
    // Min duration 3s, then allow closing / CTA fully enabled
    splashMinTimer = setTimeout(() => { splashMinElapsed.value = true }, 3000)
    // Ensure CTA enabled by 10s in worst case
    splashMaxTimer = setTimeout(() => { splashMinElapsed.value = true }, 10000)
    // Auto-hide overlay after 10s if still shown
    splashAutoHideTimer = setTimeout(() => { if (showSplash.value) showSplash.value = false }, 10000)
  } catch (_) {}
}

function closeDrawer() { showDrawer.value = false }

function openDetails() { showDetails.value = true }
function closeDetails() { showDetails.value = false }

function reconnectSse() {
  try { if (!gardenerId.value) return; connectRoomSse() } catch (_) {}
}

function toggleBottomChart() { try { showBottomChart.value = !showBottomChart.value; if (showBottomChart.value) drawBottomActivity() } catch (_) {} }

function connectRoomSse() {
  try { if (!gardenerId.value) return }
  catch (_) { return }
  try { esRoom && esRoom.close() } catch (_) {}
  roomStatus.value = 'waiting'
  try {
    roomEndpoint.value = `/api/rooms/${encodeURIComponent(gardenerId.value)}/events`
    try { emitLog('sse_client_open', { gardener_id: gardenerId.value, url: roomEndpoint.value }) } catch (_) {}
    esRoom = new EventSource(roomEndpoint.value, { withCredentials: false })
    roomOpenedAt.value = Date.now()
    roomOpenCount.value += 1
    roomEventCount.value = 0
    roomOpenToFirstMs.value = null
    let firstEventSinceOpen = true
    const pushLog = (type, dataLen = 0) => {
      try {
        const entry = { type, at: Date.now(), len: dataLen }
        roomEventLog.value.push(entry)
        if (roomEventLog.value.length > 20) roomEventLog.value.shift()
      } catch (_) {}
    }
    esRoom.addEventListener('init', (e) => {
      roomStatus.value = 'ok'
      roomLastEventAt.value = Date.now()
      roomEventCount.value += 1
      roomLastEventType.value = 'init'
      roomLastEventData.value = (e && e.data) ? String(e.data).slice(0, 2000) : ''
      if (firstEventSinceOpen) { roomOpenToFirstMs.value = Date.now() - roomOpenedAt.value; firstEventSinceOpen = false }
      pushLog('init', (e && e.data && e.data.length) || 0)
      // Immediately refresh link status so header shows updated Linked count
      try { refreshStatus() } catch (_) {}
      try { emitLog('sse_client_event', { gardener_id: gardenerId.value, type: 'init', data_len: (e && e.data && e.data.length) || 0, url: roomEndpoint.value }) } catch (_) {}
    })
    esRoom.addEventListener('message', (e) => {
      roomStatus.value = 'ok'
      roomLastEventAt.value = Date.now()
      roomEventCount.value += 1
      roomLastEventType.value = 'message'
      roomLastEventData.value = (e && e.data) ? String(e.data).slice(0, 2000) : ''
      if (firstEventSinceOpen) { roomOpenToFirstMs.value = Date.now() - roomOpenedAt.value; firstEventSinceOpen = false }
      pushLog('message', (e && e.data && e.data.length) || 0)
      try { emitLog('sse_client_event', { gardener_id: gardenerId.value, type: 'message', data_len: (e && e.data && e.data.length) || 0, url: roomEndpoint.value }) } catch (_) {}
    })
    esRoom.onopen = () => {
      roomStatus.value = 'ok'
      roomLastEventAt.value = Date.now()
      roomLastEventType.value = 'open'
      pushLog('open')
      try { emitLog('sse_client_event', { gardener_id: gardenerId.value, type: 'open', url: roomEndpoint.value }) } catch (_) {}
    }
    esRoom.onerror = () => {
      roomStatus.value = 'error'
      roomErrorAt.value = Date.now()
      roomErrorCount.value += 1
      roomLastEventType.value = 'error'
      pushLog('error')
      try { emitLog('sse_client_event', { gardener_id: gardenerId.value, type: 'error', url: roomEndpoint.value }) } catch (_) {}
    }
  } catch (_) { roomStatus.value = 'error' }
}

function ensureGardenerManifest() {
  try {
    const existing = document.querySelector('link[rel="manifest"][href="/gardener/manifest.webmanifest"]')
    if (existing) return
    const link = document.createElement('link')
    link.rel = 'manifest'
    link.href = '/gardener/manifest.webmanifest'
    document.head.appendChild(link)
  } catch (_) {}
}

async function registerGardenerSw() {
  try {
    if (!('serviceWorker' in navigator)) return null
    const reg = await navigator.serviceWorker.register('/gardener/sw.js', { scope: '/gardener/' })
    try { swInfo.value = { scope: reg.scope || '/gardener/', active: Boolean(reg.active || reg.waiting || reg.installing) } } catch (_) {}
    try { attachSwListeners(reg) } catch (_) {}
    return reg
  } catch (_) { return null }
}

function attachSwListeners(reg) {
  try {
    const setStates = () => {
      try {
        swDetails.value.installingState = (reg.installing && reg.installing.state) || ''
        swDetails.value.waitingState = (reg.waiting && reg.waiting.state) || ''
        swDetails.value.activeState = (reg.active && reg.active.state) || ''
        swDetails.value.controller = Boolean(navigator.serviceWorker && navigator.serviceWorker.controller)
        swDetails.value.lastStateChangeAt = Date.now()
      } catch (_) {}
    }
    try { setStates() } catch (_) {}
    try {
      reg.addEventListener('updatefound', () => {
        try { swDetails.value.updateFoundAt = Date.now() } catch (_) {}
        try { reg.installing && reg.installing.addEventListener('statechange', setStates) } catch (_) {}
      })
    } catch (_) {}
    try { reg.installing && reg.installing.addEventListener('statechange', setStates) } catch (_) {}
    try { reg.waiting && reg.waiting.addEventListener('statechange', setStates) } catch (_) {}
    try { reg.active && reg.active.addEventListener('statechange', setStates) } catch (_) {}
    try { navigator.serviceWorker && navigator.serviceWorker.addEventListener('controllerchange', setStates) } catch (_) {}
  } catch (_) {}
}

async function checkSwUpdate() {
  try {
    const reg = await (navigator.serviceWorker && navigator.serviceWorker.getRegistration && navigator.serviceWorker.getRegistration('/gardener/'))
    if (!reg) { showToast('No SW registration') ; return }
    try { await reg.update() } catch (_) {}
    showToast('Checked for SW update')
  } catch (_) {}
}

// PWA install detection and prompt handler
function detectInstalled() {
  try {
    const standalone = window.matchMedia && window.matchMedia('(display-mode: standalone)').matches
    const iosStandalone = window.navigator && window.navigator.standalone
    isInstalled.value = Boolean(standalone || iosStandalone)
  } catch (_) { isInstalled.value = false }
}

async function installApp() {
  try {
    if (!deferredPrompt.value) return
    deferredPrompt.value.prompt()
    await deferredPrompt.value.userChoice
    // Installation may complete asynchronously; re-detect shortly after
    setTimeout(detectInstalled, 1000)
  } catch (_) {}
}

const sseConnectMs = computed(() => {
  try { return roomOpenToFirstMs.value == null ? null : Number(roomOpenToFirstMs.value) } catch { return null }
})

async function runPingTests() {
  try {
    const tasks = [pingApiStatus()]
    // Avoid probing SSE if main room connection is already open/healthy
    const openish = (roomStatus.value === 'ok' || roomStatus.value === 'warn')
    if (!openish) tasks.push(probeSseEndpoint())
    await Promise.all(tasks)
    showToast('Pings done')
  } catch (_) {}
}

function pushHistory(arrRef, value, maxLen = 60) {
  try {
    const val = typeof value === 'number' && isFinite(value) ? Math.max(0, Math.min(2000, value)) : null
    const arr = arrRef.value || []
    if (val == null) { arr.push(null) } else { arr.push(val) }
    while (arr.length > maxLen) arr.shift()
    arrRef.value = arr
  } catch (_) {}
}

function drawHistory(canvas, series, color = '#10b981') {
  try {
    const el = canvas && canvas.value
    if (!el) return
    const ctx = el.getContext('2d')
    const w = el.width = el.clientWidth
    const h = el.height
    ctx.clearRect(0, 0, w, h)
    ctx.fillStyle = 'rgba(255,255,255,0.06)'
    ctx.fillRect(0, 0, w, h)
    const data = series.value || []
    if (!data.length) return
    const max = Math.max(100, ...data.filter(v => typeof v === 'number'))
    const dx = w / Math.max(1, data.length - 1)
    ctx.strokeStyle = color
    ctx.lineWidth = 2
    ctx.beginPath()
    data.forEach((v, i) => {
      const y = (typeof v === 'number') ? (h - (v / max) * (h - 8) - 4) : h - 4
      const x = i * dx
      if (i === 0) ctx.moveTo(x, y)
      else ctx.lineTo(x, y)
    })
    ctx.stroke()
  } catch (_) {}
}

function drawPingCharts() {
  try {
    drawHistory(apiCanvas, apiPingHistory, '#60a5fa')
    drawHistory(sseCanvas, sseProbeHistory, '#f59e0b')
  } catch (_) {}
}

function startPingLoop() {
  try { if (pingsLoopTimer) clearInterval(pingsLoopTimer) } catch (_) {}
  try { recordActivitySample(); runPingTests() } catch (_) {}
  // Probe less frequently to avoid hammering SSE endpoint
  pingsLoopTimer = setInterval(() => { try { recordActivitySample(); runPingTests() } catch (_) {} }, 10000)
}

function stopPingLoop() {
  try { if (pingsLoopTimer) clearInterval(pingsLoopTimer) } catch (_) {}
  pingsLoopTimer = null
}

watch([apiPingHistory, sseProbeHistory, showDetails], () => { try { drawPingCharts() } catch (_) {} })
watch([bottomActivityHistory, showBottomChart], () => { try { if (showBottomChart.value) drawBottomActivity() } catch (_) {} })
watch(idleWaveRatio, (v) => { try { if (typeof v === 'number') localStorage.setItem('idle_wave_ratio', String(v)) } catch (_) {} })

// When gardener id changes, reconnect SSE and fetch prefs
watch(gardenerId, (v) => { try { if (v) { document.cookie = `gardener_id=${encodeURIComponent(String(v))}; Path=/; Max-Age=864000`; connectRoomSse(); loadServerPrefs() } } catch (_) {} })

async function pingApiStatus() {
  try {
    const gid = gardenerId.value
    if (!gid) { apiPingMs.value = null; apiPingOk.value = null; return }
    const url = `/api/link/status?gardener_id=${encodeURIComponent(gid)}`
    const t0 = performance.now()
    const res = await fetch(url, { credentials: 'include', cache: 'no-store' })
    const t1 = performance.now()
    apiPingMs.value = Math.round(t1 - t0)
    apiPingOk.value = res.ok
    try { pushHistory(apiPingHistory, apiPingMs.value) ; drawPingCharts() } catch (_) {}
  } catch (e) {
    apiPingOk.value = false
  }
}

async function probeSseEndpoint() {
  try {
    const url = roomEndpoint.value
    if (!url) { sseProbeMs.value = null; sseProbeOk.value = null; return }
    const t0 = performance.now()
    let es = null
    let finished = false
    const finish = (ok) => {
      if (finished) return
      finished = true
      const t1 = performance.now()
      sseProbeMs.value = Math.round(t1 - t0)
      sseProbeOk.value = ok
      try { es && es.close() } catch (_) {}
      try { pushHistory(sseProbeHistory, sseProbeMs.value); drawPingCharts() } catch (_) {}
    }
    es = new EventSource(url)
    const timer = setTimeout(() => finish(false), 2000)
    es.onopen = () => { try { clearTimeout(timer) } catch (_) {}; finish(true) }
    es.onerror = () => { /* let timer determine fail; avoid console spam */ }
  } catch (_) {
    sseProbeOk.value = false
  }
}

function recordActivitySample() {
  try {
    const v = Number(sseEventsSinceSample.value || 0)
    sseEventsSinceSample.value = 0
    // Purely graphical idle animation: smooth low-amplitude waves (calm lake).
    // Use deterministic wave functions + EMA so it never looks like bursty activity.
    let displayValue = v
    if (v === 0) {
      const t = Date.now() / 1000
      // Two very gentle waves blended; bounded in [-1, 1]
      const baseF1 = 0.35
      const baseF2 = 0.17
      // Tie amplitude to wavelength via ratio: amplitude ≈ k / wavelength
      // Using ratio R = amplitude : wavelength => amplitude = R * wavelength
      // Here we approximate wavelength with 1/frequency, so amplitude scales with (R / f)
      const R = Number(idleWaveRatio.value || 2.5)
      const amp1 = Math.min(1, Math.max(0.1, R / baseF1))
      const amp2 = Math.min(1, Math.max(0.1, R / baseF2))
      const s1 = Math.sin(t * baseF1) * 0.6
      const s2 = Math.sin(t * baseF2 + 1.13) * 0.4
      const blended = s1 + s2 // in [-1, 1]
      const norm = (blended + 1) / 2 // 0..1
      // Base subtle range
      let minA = 0.005
      let maxA = 0.030
      // Apply ratio-influenced amplitude scaling
      const scale = Math.min(4, Math.max(0.25, (amp1 * 0.6 + amp2 * 0.4) * 0.02))
      minA *= scale
      maxA *= scale
      const target = minA + norm * (maxA - minA)
      // Exponential moving average for extra smoothness
      const alpha = 0.15
      displayValue = (1 - alpha) * (lastIdleDisplay.value || target) + alpha * target
      lastIdleDisplay.value = displayValue
    }
    pushHistory(bottomActivityHistory, displayValue, 120)
    if (showBottomChart.value) drawBottomActivity()
  } catch (_) {}
}

function drawBottomActivity() {
  try {
    const el = bottomCanvas && bottomCanvas.value
    if (!el) return
    const ctx = el.getContext('2d')
    const w = el.width = window.innerWidth
    const h = el.height = el.clientHeight || 64
    ctx.clearRect(0, 0, w, h)
    // subtle background
    const grad = ctx.createLinearGradient(0, 0, 0, h)
    grad.addColorStop(0, 'rgba(255,255,255,0.06)')
    grad.addColorStop(1, 'rgba(255,255,255,0.02)')
    ctx.fillStyle = grad
    ctx.fillRect(0, 0, w, h)
    const data = bottomActivityHistory.value || []
    if (!data.length) return
    const valid = data.filter(v => typeof v === 'number')
    let max = 0
    try { max = valid.length ? Math.max(...valid) : 0 } catch (_) { max = 0 }
    // Ensure small jitter remains visible; lift minimum max to 0.25 when data is tiny
    if (max < 0.25) max = 0.25
    const dx = w / Math.max(1, data.length - 1)
    // area under curve
    ctx.beginPath()
    data.forEach((v, i) => {
      const y = (typeof v === 'number') ? (h - (v / max) * (h - 10) - 5) : h - 5
      const x = i * dx
      if (i === 0) ctx.moveTo(x, y)
      else ctx.lineTo(x, y)
    })
    ctx.lineTo(w, h)
    ctx.lineTo(0, h)
    ctx.closePath()
    ctx.fillStyle = 'rgba(99,102,241,0.15)'
    ctx.fill()
    // line
    ctx.strokeStyle = 'rgba(99,102,241,0.7)'
    ctx.lineWidth = 2
    ctx.beginPath()
    data.forEach((v, i) => {
      const y = (typeof v === 'number') ? (h - (v / max) * (h - 10) - 5) : h - 5
      const x = i * dx
      if (i === 0) ctx.moveTo(x, y)
      else ctx.lineTo(x, y)
    })
    ctx.stroke()
  } catch (_) {}
}

const sseReadyStateLabel = computed(() => {
  switch (effectiveStatus.value) {
    case 'waiting': return 'CONNECTING'
    case 'ok': return 'OPEN'
    case 'warn': return 'OPEN (idle)'
    case 'error': return 'CLOSED'
    default: return 'UNKNOWN'
  }
})

const authUserSummary = computed(() => {
  try {
    const u = auth && auth.state && auth.state.user
    if (!u) return 'Not signed in'
    const name = u.name || u.username || ''
    const email = u.email || ''
    return [name, email].filter(Boolean).join(' • ') || 'Signed in'
  } catch (_) { return '—' }
})

function copyDiagnostics() {
  try {
    const snapshot = {
      gardenerId: gardenerId.value,
      status: effectiveStatus.value,
      runnerLabel: runnerLabel.value,
      linkedCount: linkedSeedlings.value.length,
      endpoints: {
        status: `/api/link/status?gardener_id=${encodeURIComponent(gardenerId.value)}`,
        sse: roomEndpoint.value,
      },
      sse: {
        state: sseReadyStateLabel.value,
        openedAt: roomOpenedAt.value,
        lastEventAt: roomLastEventAt.value,
        lastErrorAt: roomErrorAt.value,
        openCount: roomOpenCount.value,
        eventCount: roomEventCount.value,
        errorCount: roomErrorCount.value,
        lastType: roomLastEventType.value,
        connectMs: sseConnectMs.value,
      },
      pings: { apiMs: apiPingMs.value, apiOk: apiPingOk.value, sseMs: sseProbeMs.value, sseOk: sseProbeOk.value },
      lastStatusRefreshAt: lastStatusRefreshAt.value,
      installed: isInstalled.value,
      sw: swInfo.value,
      wco: isWco.value,
      env: envInfo.value,
      devMode: devMode.value,
      statusLog: statusLog.value,
      providers: providerActivity.value,
    }
    copy(JSON.stringify(snapshot, null, 2))
    showToast('Diagnostics copied')
  } catch (_) {}
}

function downloadDiagnostics() {
  try {
    const payload = {
      meta: { generatedAt: Date.now(), version: 1 },
      gardenerId: gardenerId.value,
      status: effectiveStatus.value,
      runnerLabel: runnerLabel.value,
      linkedSeedlings: linkedSeedlings.value,
      endpoints: {
        status: `/api/link/status?gardener_id=${encodeURIComponent(gardenerId.value)}`,
        sse: roomEndpoint.value,
      },
      sse: {
        openedAt: roomOpenedAt.value,
        lastEventAt: roomLastEventAt.value,
        lastErrorAt: roomErrorAt.value,
        openCount: roomOpenCount.value,
        eventCount: roomEventCount.value,
        errorCount: roomErrorCount.value,
        lastType: roomLastEventType.value,
        lastPayload: roomLastEventData.value,
        eventLog: roomEventLog.value,
        connectMs: sseConnectMs.value,
      },
      pings: {
        api: { ms: apiPingMs.value, ok: apiPingOk.value, history: apiPingHistory.value },
        sse: { ms: sseProbeMs.value, ok: sseProbeOk.value, history: sseProbeHistory.value },
      },
      statusLog: statusLog.value,
      providers: providerActivity.value,
      sw: { info: swInfo.value, details: swDetails.value },
      env: envInfo.value,
      isInstalled: isInstalled.value,
      wco: isWco.value,
      devMode: devMode.value,
    }
    const blob = new Blob([JSON.stringify(payload, null, 2)], { type: 'application/json' })
    const url = URL.createObjectURL(blob)
    const a = document.createElement('a')
    const ts = new Date().toISOString().replace(/[:.]/g, '-')
    a.href = url
    a.download = `gardener-diagnostics-${ts}.json`
    document.body.appendChild(a)
    a.click()
    setTimeout(() => { try { URL.revokeObjectURL(url); a.remove() } catch (_) {} }, 1000)
    showToast('Diagnostics downloaded')
  } catch (_) {}
}

// Close drawer on Escape
onMounted(() => {
  const onKey = (e) => { try {
    if (e.key === 'Escape') {
      if (showDetails.value) closeDetails()
      else closeDrawer()
    }
  } catch (_) {} }
  try { window.addEventListener('keydown', onKey) } catch (_) {}
  onBeforeUnmount(() => { try { window.removeEventListener('keydown', onKey) } catch (_) {} })
})
</script>

<style scoped>
.gardener-bg { position: relative; }
.gardener-bg::before {
  content: "";
  position: fixed; inset: 0; z-index: 0; pointer-events: none;
  background-image: url('/assets/gardener-background.svg');
  background-size: cover; background-position: center; background-repeat: no-repeat;
  filter: saturate(1.05);
}
.gardener-bg > * { position: relative; z-index: 1; }

/* Window titlebar-like area (draggable) */
.wco-bar { position: fixed; top: 0; left: 0; right: 0; z-index: 20; padding-top: max(10px, env(safe-area-inset-top)); -webkit-app-region: drag; }
.wco-inner { display: flex; align-items: center; justify-content: center; gap: 10px; padding: 6px 12px; color: #fff; text-shadow: 0 2px 10px rgba(0,0,0,0.6); font-weight: 700; letter-spacing: .02em; }
.wco-title { opacity: .95 }
.wco-gid { opacity: .85; font-family: ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, "Liberation Mono", "Courier New", monospace; font-size: .9rem; padding: 2px 8px; border-radius: 9999px; background: rgba(0,0,0,0.25); }
.no-drag { -webkit-app-region: no-drag }

/* Centered runner host with top padding to avoid titlebar overlap */
.runner-host { padding-top: calc(max(64px, env(safe-area-inset-top)) + 18px); display: grid; place-items: center; min-height: 60vh; }
.splash-card { animation: cardIn 800ms ease both; }
.splash-content { animation: contentIn 900ms 120ms ease both; }
.splash-img { animation: slowZoom 12s ease-in-out infinite alternate; transform-origin: center; }
.splash-gradient { position: absolute; inset: 0; background: linear-gradient(180deg, rgba(17,24,39,0.0) 0%, rgba(17,24,39,0.4) 38%, rgba(17,24,39,0.75) 100%); animation: drift 8s ease-in-out infinite alternate; }

/* Fullscreen overlay background */
.splash-bg { position: fixed; inset: 0; width: 100vw; height: 100dvh; object-fit: cover; animation: slowZoom 12s ease-in-out infinite alternate; }
.loading-text { font-weight: 700; font-size: 1.125rem; opacity: .9; }
.dots span { display: inline-block; opacity: 0; animation: blink 1.2s infinite; }
.dots span:nth-child(1) { animation-delay: 0s }
.dots span:nth-child(2) { animation-delay: .2s }
.dots span:nth-child(3) { animation-delay: .4s }
@keyframes blink { 0%, 20% { opacity: 0 } 50% { opacity: 1 } 100% { opacity: 0 } }

/* Safe areas and window-controls overlay padding */
.top-title { padding-top: max(1rem, env(safe-area-inset-top)); }
.bottom-loading { bottom: max(2rem, env(safe-area-inset-bottom)); }
.wco .top-title { padding-top: calc(max(1rem, env(safe-area-inset-top)) + 12px); }

/* Runner indicator */
.runner {
  width: 120px; height: 120px; border-radius: 9999px; display: grid; place-items: center;
  background: radial-gradient(closest-side, rgba(34,197,94,0.85), rgba(34,197,94,0.6));
  box-shadow: 0 0 0 6px rgba(34,197,94,0.15), 0 8px 24px rgba(0,0,0,0.25);
  position: relative; overflow: hidden;
}
/* Connecting: ripple pulse ring */
.runner-wait { background: radial-gradient(closest-side, rgba(59,130,246,0.85), rgba(59,130,246,0.6)); box-shadow: 0 0 0 6px rgba(59,130,246,0.15), 0 8px 24px rgba(0,0,0,0.25); }
.runner-wait::after {
  content: ""; position: absolute; inset: 8px; border-radius: inherit; border: 2px solid rgba(255,255,255,0.35);
  animation: ripple 1.6s ease-out infinite;
}
@keyframes ripple { 0% { opacity: .9; transform: scale(1) } 100% { opacity: 0; transform: scale(1.35) } }

/* Running: gentle breathing */
.runner-ok { background: radial-gradient(closest-side, rgba(34,197,94,0.85), rgba(34,197,94,0.6)); box-shadow: 0 0 0 6px rgba(34,197,94,0.15), 0 8px 24px rgba(0,0,0,0.25); animation: breathe 2.8s ease-in-out infinite; }
@keyframes breathe { 0%, 100% { transform: scale(1) } 50% { transform: scale(1.04) } }

/* Idle: scanning (conic spin) */
.runner-warn { background: radial-gradient(closest-side, rgba(45,212,191,0.85), rgba(45,212,191,0.6)); box-shadow: 0 0 0 6px rgba(45,212,191,0.15), 0 8px 24px rgba(0,0,0,0.25); }
.runner-warn::before { content: ""; position: absolute; inset: -20%; border-radius: inherit; background: conic-gradient(from 0deg, rgba(255,255,255,0.35), rgba(255,255,255,0) 60%); filter: blur(8px); animation: scan 3.2s linear infinite; }
@keyframes scan { to { transform: rotate(360deg) } }

/* Offline: alert throb */
.runner-error { background: radial-gradient(closest-side, rgba(239,68,68,0.85), rgba(239,68,68,0.6)); box-shadow: 0 0 0 6px rgba(239,68,68,0.15), 0 8px 24px rgba(0,0,0,0.25); animation: alert 1.4s ease-in-out infinite; }
@keyframes alert { 0%, 100% { transform: scale(1); filter: brightness(1) } 50% { transform: scale(0.98); filter: brightness(1.1) } }

.runner span { position: relative; font-weight: 800; color: #052e16; text-transform: uppercase; letter-spacing: .06em; }

@keyframes cardIn { from { opacity: 0; transform: translateY(8px) } to { opacity: 1; transform: translateY(0) } }
@keyframes contentIn { from { opacity: 0; transform: translateY(6px) } to { opacity: 1; transform: translateY(0) } }
@keyframes slowZoom { 0% { transform: scale(1.02) translateY(0) } 100% { transform: scale(1.07) translateY(-2px) } }
@keyframes drift { 0% { background: linear-gradient(180deg, rgba(17,24,39,0.0) 0%, rgba(17,24,39,0.35) 42%, rgba(17,24,39,0.75) 100%) } 100% { background: linear-gradient(180deg, rgba(17,24,39,0.0) 0%, rgba(17,24,39,0.45) 35%, rgba(17,24,39,0.82) 100%) } }

/* All set fade-in message */
.allset { display: grid; place-items: center; margin-top: 16px; animation: allsetIn .6s ease both; }
.allset .msg { background: rgba(17,24,39,0.7); color: #e5e7eb; padding: 8px 12px; border-radius: 9999px; font-weight: 600; letter-spacing: .02em; box-shadow: 0 4px 14px rgba(0,0,0,0.22); backdrop-filter: blur(6px); animation: breathe 3.8s ease-in-out 1.2s infinite; }
@keyframes allsetIn { from { opacity: 0; transform: translateY(6px) } to { opacity: 1; transform: translateY(0) } }

/* Gear button */
.gear-btn { position: fixed; top: max(10px, env(safe-area-inset-top)); left: max(10px, env(safe-area-inset-left)); z-index: 30; width: 32px; height: 32px; display: grid; place-items: center; border-radius: 9999px; color: #e5e7eb; background: rgba(0,0,0,0.28); backdrop-filter: blur(6px); box-shadow: 0 2px 12px rgba(0,0,0,0.25); }
.gear-btn:hover { background: rgba(0,0,0,0.38) }

/* Drawer */
.drawer-backdrop { position: fixed; inset: 0; background: rgba(0,0,0,0.35); backdrop-filter: blur(2px); z-index: 39; pointer-events: auto; }
.drawer { position: fixed; top: 0; right: auto; left: 0; width: min(92vw, 360px); height: 100dvh; background: rgba(17,24,39,0.9); color: #e5e7eb; border-right: 1px solid rgba(255,255,255,0.08); box-shadow: 10px 0 24px rgba(0,0,0,0.3); z-index: 40; display: flex; flex-direction: column; transform: translateX(-8px); animation: slideIn .18s ease-out both; }
.drawer.left { left: 0; right: auto; }
.drawer.right { right: 0; left: auto; border-right: none; border-left: 1px solid rgba(255,255,255,0.08); box-shadow: -10px 0 24px rgba(0,0,0,0.3); }
.drawer *, .drawer-backdrop { pointer-events: auto; }
@keyframes slideIn { from { opacity: 0; transform: translateX(-14px) } to { opacity: 1; transform: translateX(0) } }
.drawer-hd { display: flex; align-items: center; justify-content: space-between; padding: 12px 14px; border-bottom: 1px solid rgba(255,255,255,0.08); }
.drawer-hd .title { font-weight: 700; opacity: .95 }
.drawer-body { padding: 14px; display: grid; gap: 12px; }

/* Details modal */
.modal-backdrop { position: fixed; inset: 0; background: rgba(0,0,0,0.45); backdrop-filter: blur(2px); z-index: 50; display: grid; place-items: center; padding: 12px; }
.modal-card { width: 66.6667vw; max-width: 1200px; max-height: 88vh; overflow: auto; background: rgba(17,24,39,0.95); color: #e5e7eb; border-radius: 16px; border: 1px solid rgba(255,255,255,0.08); box-shadow: 0 10px 28px rgba(0,0,0,0.35); animation: cardIn .18s ease-out both; }
@media (max-width: 768px) { .modal-card { width: 96vw } }
.modal-hd { display: flex; align-items: center; justify-content: space-between; padding: 12px 14px; border-bottom: 1px solid rgba(255,255,255,0.08); position: sticky; top: 0; background: inherit; backdrop-filter: blur(2px); }
.modal-hd .title { font-weight: 800; letter-spacing: .02em; }
.modal-body { padding: 14px; display: grid; gap: 10px; }
.modal-ft { padding: 12px 14px; display: flex; justify-content: flex-end; border-top: 1px solid rgba(255,255,255,0.08); position: sticky; bottom: 0; background: inherit; }
.kv { display: grid; grid-template-columns: 160px 1fr; gap: 8px 12px; align-items: center; }
.kv .k { opacity: .8; font-weight: 600; }
.kv .v code { background: rgba(255,255,255,0.08); padding: 2px 6px; border-radius: 6px; }
.pre { white-space: pre-wrap; background: rgba(255,255,255,0.06); border: 1px solid rgba(255,255,255,0.08); border-radius: 8px; padding: 10px; }
@media (max-width: 640px) {
  .kv { grid-template-columns: 1fr }
}

/* Chart toggle button (bottom-right) */
.chart-btn { position: fixed; bottom: max(12px, env(safe-area-inset-bottom)); right: max(12px, env(safe-area-inset-right)); z-index: 30; width: 36px; height: 36px; display: grid; place-items: center; border-radius: 9999px; color: #e5e7eb; background: rgba(0,0,0,0.28); backdrop-filter: blur(6px); box-shadow: 0 2px 12px rgba(0,0,0,0.25); border: 1px solid rgba(255,255,255,0.08); }
.chart-btn:hover { background: rgba(0,0,0,0.38) }
.chart-btn.active { background: rgba(99,102,241,0.25); border-color: rgba(99,102,241,0.45) }

/* Bottom activity overlay */
.bottom-activity { position: fixed; left: 0; right: 0; bottom: 0; height: 64px; z-index: 20; pointer-events: none; width: 100vw; }
</style>
