<template>
  <div class="container mx-auto p-4 space-y-6">
    <!-- Header -->
    <div class="flex flex-wrap items-center justify-between gap-3">
      <div class="flex items-center gap-3">
        <h1 class="text-2xl font-semibold">Activity</h1>
        <span class="badge" :class="sseConnected ? 'badge-success' : 'badge-error'">SSE {{ sseConnected ? 'Connected' : 'Disconnected' }}</span>
        <span class="badge badge-outline" :title="`gardener_id: ${gardenerId}`">G: {{ gardenerId }}</span>
      </div>
      <div class="flex items-center gap-2">
        <a class="btn btn-outline btn-sm" :href="roomEventsUrl" target="_blank" rel="noopener">Open SSE Stream</a>
        <button v-if="isDev" class="btn btn-primary btn-sm" @click="requestTestTask" :disabled="requesting">
          {{ requesting ? 'Sending…' : 'Issue Test Task' }}
        </button>
      </div>
    </div>

    <!-- Top stats -->
    <div class="grid grid-cols-1 md:grid-cols-4 gap-4">
      <div class="card bg-base-200">
        <div class="card-body">
          <div class="text-sm opacity-70">Linked Seedlings</div>
          <div class="text-2xl font-semibold">{{ linkedSeedlings.length }}</div>
          <div class="text-xs break-all" v-if="linkedSeedlings.length">{{ linkedSeedlings.join(', ') }}</div>
        </div>
      </div>
      <div class="card bg-base-200">
        <div class="card-body">
          <div class="text-sm opacity-70">Last Heartbeat</div>
          <div class="text-2xl font-semibold">{{ lastHeartbeatLabel }}</div>
          <div class="text-xs">{{ lastHeartbeatAt ? new Date(lastHeartbeatAt).toLocaleString() : '—' }}</div>
        </div>
      </div>
      <div class="card bg-base-200">
        <div class="card-body">
          <div class="text-sm opacity-70">Server</div>
          <div class="text-2xl font-semibold">v{{ serverVersion || '—' }}</div>
          <div class="text-xs">Uptime: {{ uptimeLabel }}</div>
        </div>
      </div>
      <div class="card bg-base-200">
        <div class="card-body">
          <div class="text-sm opacity-70">Trackers Health</div>
          <div class="text-2xl font-semibold">{{ trackersHealthy }}/{{ trackersTotal }}</div>
          <div class="text-xs">mode: {{ trackersMode }}</div>
        </div>
      </div>
    </div>

    <!-- Charts -->
    <div class="grid grid-cols-1 lg:grid-cols-3 gap-4">
      <div class="card bg-base-200">
        <div class="card-body">
          <div class="flex items-center justify-between">
            <h2 class="card-title">Heartbeats (last 30m)</h2>
            <span class="badge">{{ heartbeats.length }}</span>
          </div>
          <div class="chart" role="img" aria-label="Heartbeat chart">
            <div v-for="(v, i) in hbBuckets" :key="i" class="bar" :style="{ height: `${Math.min(100, v * 20)}%` }" :title="`${v} at ${bucketLabel(i)}`" />
          </div>
        </div>
      </div>
      <div class="card bg-base-200">
        <div class="card-body">
          <div class="flex items-center justify-between">
            <h2 class="card-title">Tasks (last 30m)</h2>
            <span class="badge">{{ tasks.length }}</span>
          </div>
          <div class="chart" role="img" aria-label="Tasks chart">
            <div v-for="(v, i) in taskBuckets" :key="i" class="bar bar-secondary" :style="{ height: `${Math.min(100, v * 20)}%` }" :title="`${v} at ${bucketLabel(i)}`" />
          </div>
        </div>
      </div>
      <div class="card bg-base-200">
        <div class="card-body">
          <div class="flex items-center justify-between">
            <h2 class="card-title">Results (last 30m)</h2>
            <span class="badge">{{ results.length }}</span>
          </div>
          <div class="chart" role="img" aria-label="Results chart">
            <div v-for="(v, i) in resultBuckets" :key="i" class="bar bar-accent" :style="{ height: `${Math.min(100, v * 20)}%` }" :title="`${v} at ${bucketLabel(i)}`" />
          </div>
        </div>
      </div>
    </div>

    <!-- Recent items -->
    <div class="grid grid-cols-1 xl:grid-cols-2 gap-4">
      <div class="card bg-base-200 overflow-x-auto">
        <div class="card-body">
          <div class="flex items-center justify-between">
            <h2 class="card-title">Recent Tasks</h2>
            <span class="badge">{{ tasks.length }}</span>
          </div>
          <table class="table table-zebra">
            <thead>
              <tr>
                <th>Type</th>
                <th>Received</th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="(t, idx) in tasks.slice().reverse().slice(0, 20)" :key="idx">
                <td class="font-mono">{{ t.type }}</td>
                <td>{{ new Date(t.t).toLocaleString() }}</td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>
      <div class="card bg-base-200 overflow-x-auto">
        <div class="card-body">
          <div class="flex items-center justify-between">
            <h2 class="card-title">Recent Results</h2>
            <span class="badge">{{ results.length }}</span>
          </div>
          <table class="table table-zebra">
            <thead>
              <tr>
                <th>Title</th>
                <th>Ok</th>
                <th>Received</th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="(r, idx) in results.slice().reverse().slice(0, 20)" :key="idx">
                <td class="truncate max-w-[24ch]" :title="resultTitle(r)">{{ resultTitle(r) }}</td>
                <td>{{ r.ok ? 'yes' : 'no' }}</td>
                <td>{{ new Date(r.t).toLocaleString() }}</td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>
    </div>

    <!-- Event log -->
    <div class="card bg-base-200">
      <div class="card-body">
        <div class="flex items-center justify-between">
          <h2 class="card-title">Event Log</h2>
          <button class="btn btn-ghost btn-sm" @click="clearLog" :disabled="!eventsLog.length">Clear</button>
        </div>
        <div class="max-h-[360px] overflow-auto font-mono text-xs">
          <div v-for="(e, i) in eventsLog" :key="i" class="whitespace-pre-wrap break-words">
            {{ e }}
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, onMounted, onBeforeUnmount, watch } from 'vue'
import { gardener } from '../lib/gardener'

const gardenerId = computed(() => {
  try { return gardener.getGardenerId() || '' } catch { return '' }
})
const sseConnected = ref(false)
const lastEventAt = ref(0)
const lastHeartbeatAt = ref(0)
const linkedSeedlings = ref([])
const serverVersion = ref('')
const serverUptime = ref(0)
const trackersHealthy = ref(0)
const trackersTotal = ref(0)
const trackersMode = ref('off')

const heartbeats = ref([]) // number[] timestamps
const tasks = ref([]) // { type, t }
const results = ref([]) // { ok, normalized, raw, t }
const eventsLog = ref([])
let es = null
const requesting = ref(false)

const roomEventsUrl = computed(() => `/api/rooms/${encodeURIComponent(gardenerId.value || 'default')}/events`)
const isDev = computed(() => {
  try {
    const url = new URL(window.location.href)
    const hasQueryDev = url.searchParams.get('dev') === '1'
    const hasHashDev = url.hash.includes('?') && new URLSearchParams(url.hash.split('?')[1]).get('dev') === '1'
    return Boolean(hasQueryDev || hasHashDev)
  } catch (_) { return false }
})

const lastHeartbeatLabel = computed(() => {
  if (!lastHeartbeatAt.value) return '—'
  const delta = Date.now() - lastHeartbeatAt.value
  if (delta < 5_000) return 'just now'
  if (delta < 60_000) return `${Math.floor(delta / 1000)}s ago`
  if (delta < 3_600_000) return `${Math.floor(delta / 60_000)}m ago`
  return `${Math.floor(delta / 3_600_000)}h ago`
})
const uptimeLabel = computed(() => {
  const s = serverUptime.value || 0
  const h = Math.floor(s / 3600)
  const m = Math.floor((s % 3600) / 60)
  const sec = Math.floor(s % 60)
  return `${h}h ${m}m ${sec}s`
})

// Buckets: 30 minutes, minute-sized
const BUCKETS = 30
function makeBuckets() { return Array.from({ length: BUCKETS }, () => 0) }
function buildBuckets(arr) {
  const now = Date.now()
  const out = makeBuckets()
  for (const t of arr) {
    const delta = now - t
    const idx = Math.floor(delta / 60_000)
    if (idx >= 0 && idx < BUCKETS) out[BUCKETS - 1 - idx] += 1
  }
  return out
}
const hbBuckets = computed(() => buildBuckets(heartbeats.value))
const taskBuckets = computed(() => buildBuckets(tasks.value.map(x => x.t)))
const resultBuckets = computed(() => buildBuckets(results.value.map(x => x.t)))
function bucketLabel(i) {
  const now = Date.now()
  const minsAgo = (BUCKETS - 1 - i)
  const dt = new Date(now - minsAgo * 60_000)
  return dt.toLocaleTimeString()
}

function addLog(type, payload) {
  try {
    const rec = `[${new Date().toLocaleTimeString()}] ${type}: ${JSON.stringify(payload)}`
    eventsLog.value.push(rec)
    if (eventsLog.value.length > 200) eventsLog.value.shift()
  } catch (_) {}
}
function clearLog() { eventsLog.value = [] }

function resultTitle(r) {
  try {
    if (r && r.normalized && r.normalized.title) return r.normalized.title
    if (r && r.raw && (r.raw.title || r.raw.name)) return r.raw.title || r.raw.name
  } catch (_) {}
  return '(no title)'
}

async function fetchLinked() {
  try {
    const u = new URL('/api/link/status', window.location.origin)
    u.searchParams.set('gardener_id', gardenerId.value)
    const r = await fetch(u.toString(), { cache: 'no-store' })
    const j = await r.json().catch(() => null)
    if (j && j.ok && Array.isArray(j.linked_seedlings)) linkedSeedlings.value = j.linked_seedlings
  } catch (_) { /* ignore */ }
}
async function fetchHealth() {
  try {
    const r = await fetch('/health', { cache: 'no-store' })
    const j = await r.json().catch(() => null)
    if (j && j.ok) { serverVersion.value = j.version || ''; serverUptime.value = Number(j.uptime_s || 0) }
  } catch (_) { /* ignore */ }
}
async function fetchTrackersHealth() {
  try {
    const r = await fetch('/api/trackers/health', { cache: 'no-store' })
    const j = await r.json().catch(() => null)
    if (j && typeof j === 'object') {
      trackersHealthy.value = Number(j.healthy || 0)
      trackersTotal.value = Number(j.total || 0)
      trackersMode.value = String(j.mode || 'off')
    }
  } catch (_) { /* ignore */ }
}

function setupSSE() {
  try { if (es) { try { es.close() } catch (_) {} es = null } } catch (_) {}
  try {
    es = new EventSource(roomEventsUrl.value)
    es.onopen = () => { sseConnected.value = true }
    es.onerror = () => { sseConnected.value = false }
    es.addEventListener('init', (ev) => {
      lastEventAt.value = Date.now()
      addLog('init', safeParse(ev.data))
    })
    es.addEventListener('heartbeat', (ev) => {
      lastEventAt.value = Date.now()
      lastHeartbeatAt.value = Date.now()
      heartbeats.value.push(Date.now())
      if (heartbeats.value.length > 500) heartbeats.value.shift()
      addLog('heartbeat', safeParse(ev.data))
    })
    es.addEventListener('task', (ev) => {
      lastEventAt.value = Date.now()
      const data = safeParse(ev.data)
      tasks.value.push({ type: (data && data.type) || 'task', t: Date.now() })
      if (tasks.value.length > 200) tasks.value.shift()
      addLog('task', data)
    })
    es.addEventListener('result', (ev) => {
      lastEventAt.value = Date.now()
      const data = safeParse(ev.data)
      results.value.push({ ok: Boolean(data && data.ok), normalized: data && data.normalized, raw: data && data.raw, t: Date.now() })
      if (results.value.length > 200) results.value.shift()
      addLog('result', data)
    })
  } catch (_) { sseConnected.value = false }
}

function safeParse(s) { try { return JSON.parse(s) } catch { return s } }

async function requestTestTask() {
  if (!isDev.value) return
  try {
    requesting.value = true
    const room = gardenerId.value || 'default'
    const body = { room_id: room, type: 'normalize', params: { title: 'Test Release 1080p x264', size: 734003200, infohash: '0123456789ABCDEF0123456789ABCDEF01234567' } }
    const r = await fetch('/api/tasks/request', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(body) })
    await r.json().catch(() => null)
  } catch (_) { /* ignore */ }
  finally { requesting.value = false }
}

onMounted(() => {
  fetchLinked()
  fetchHealth()
  fetchTrackersHealth()
  setupSSE()
  try { setInterval(fetchHealth, 15_000) } catch (_) {}
  try { setInterval(fetchTrackersHealth, 60_000) } catch (_) {}
  try { setInterval(fetchLinked, 30_000) } catch (_) {}
})

onBeforeUnmount(() => {
  try { es && es.close() } catch (_) {}
})

// Reconnect SSE if gardenerId changes at runtime
watch(gardenerId, () => { try { setupSSE() } catch (_) {} })
</script>

<style scoped>
.chart { display: grid; grid-template-columns: repeat(30, minmax(2px, 1fr)); gap: 4px; align-items: end; height: 120px; }
.bar { background: hsl(var(--su)); opacity: 0.9; border-radius: 2px; }
.bar-secondary { background: hsl(var(--s)); }
.bar-accent { background: hsl(var(--a)); }
</style>
