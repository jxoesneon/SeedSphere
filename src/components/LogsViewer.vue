<template>
  <div class="space-y-2">
    <div class="flex flex-wrap items-end gap-2">
      <div class="form-control w-full sm:w-40">
        <label class="label py-1"><span class="label-text text-xs">Type</span></label>
        <input v-model="filters.type" class="input input-bordered input-xs" placeholder="e.g. stream_result" />
      </div>
      <div class="form-control w-full sm:w-40">
        <label class="label py-1"><span class="label-text text-xs">Component</span></label>
        <input v-model="filters.component" class="input input-bordered input-xs" placeholder="addon|manifest|..." />
      </div>
      <div class="form-control w-full sm:w-52">
        <label class="label py-1"><span class="label-text text-xs">User ID</span></label>
        <input v-model="filters.user_id" class="input input-bordered input-xs font-mono" placeholder="user id" />
      </div>
      <div class="form-control w-full sm:w-52">
        <label class="label py-1"><span class="label-text text-xs">Gardener ID</span></label>
        <input v-model="filters.gardener_id" class="input input-bordered input-xs font-mono" placeholder="g-..." />
      </div>
      <div class="form-control w-full sm:w-52">
        <label class="label py-1"><span class="label-text text-xs">Seedling ID</span></label>
        <input v-model="filters.seedling_id" class="input input-bordered input-xs font-mono" placeholder="..." />
      </div>
      <div class="flex items-center gap-2 ml-auto w-full sm:w-auto justify-end mt-2 sm:mt-0">
        <button class="btn btn-xs" @click="reconnect">Reconnect</button>
        <button class="btn btn-ghost btn-xs" @click="toggle">{{ connected ? 'Pause' : 'Resume' }}</button>
        <button class="btn btn-ghost btn-xs" @click="exportJson">Export</button>
        <button class="btn btn-ghost btn-xs" @click="clearLocal">Clear</button>
      </div>
    </div>
    <div class="max-h-[50vh] sm:max-h-64 md:max-h-80 overflow-auto rounded border border-base-300 bg-base-100" ref="scroller">
      <div v-if="items.length === 0" class="p-2 text-xs opacity-70">No logs yet</div>
      <ul v-else class="divide-y divide-base-200" aria-live="polite">
        <li v-for="(it, idx) in items" :key="idx" class="p-2 text-xs">
          <div class="flex items-center gap-2">
            <span class="opacity-60 font-mono">{{ ts(it.ts) }}</span>
            <span class="badge badge-ghost badge-xs">{{ it.type }}</span>
            <span class="badge badge-outline badge-xs" v-if="it.data && it.data.component">{{ it.data.component }}</span>
            <span class="opacity-60 truncate" v-if="it.data && it.data.seedling_id">sid: {{ it.data.seedling_id }}</span>
            <span class="opacity-60 truncate" v-if="it.data && it.data.gardener_id">gid: {{ it.data.gardener_id }}</span>
          </div>
          <pre class="mt-1 whitespace-pre-wrap break-words">{{ pretty(it) }}</pre>
        </li>
      </ul>
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted, onBeforeUnmount, watch } from 'vue'

const props = defineProps({
  initialFilters: { type: Object, default: () => ({}) },
  snapshot: { type: Number, default: 200 },
})

const filters = ref({ ...props.initialFilters })
const items = ref([])
const connected = ref(false)
let es = null
const scroller = ref(null)

function pretty(v) { try { return JSON.stringify(v, null, 2) } catch { return String(v) } }
function ts(t) { try { return new Date(Number(t)).toLocaleString() } catch { return String(t) } }
function scrollToBottom() {
  try { const el = scroller.value; if (!el) return; el.scrollTop = el.scrollHeight } catch {}
}

function urlWithFilters() {
  const p = new URLSearchParams()
  const f = filters.value || {}
  for (const k of ['type','component','user_id','gardener_id','seedling_id']) {
    const v = String(f[k] || '').trim()
    if (v) p.set(k, v)
  }
  if (props.snapshot) p.set('snapshot', String(props.snapshot))
  return `/api/logs/events?${p.toString()}`
}

function connect() {
  try { if (es) es.close() } catch {}
  items.value = []
  const url = urlWithFilters()
  es = new EventSource(url)
  connected.value = true
  es.addEventListener('snapshot', (e) => {
    try { const j = JSON.parse(e.data || '{}'); if (Array.isArray(j.items)) items.value = j.items } catch {}
    scrollToBottom()
  })
  es.addEventListener('log', (e) => {
    try { const j = JSON.parse(e.data || '{}'); if (j && typeof j === 'object') items.value.push(j); if (items.value.length > 5000) items.value.shift() } catch {}
    scrollToBottom()
  })
  es.onerror = () => { connected.value = false }
}

function disconnect() {
  try { es && es.close() } catch {}
  es = null
  connected.value = false
}

function toggle() { connected.value ? disconnect() : connect() }
function reconnect() { disconnect(); connect() }
function clearLocal() { items.value = [] }
function exportJson() {
  try {
    const blob = new Blob([JSON.stringify(items.value, null, 2)], { type: 'application/json' })
    const url = URL.createObjectURL(blob)
    const a = document.createElement('a')
    a.href = url
    a.download = `seedsphere-logs-${Date.now()}.json`
    document.body.appendChild(a)
    a.click()
    document.body.removeChild(a)
    URL.revokeObjectURL(url)
  } catch {}
}

onMounted(connect)
onBeforeUnmount(disconnect)
watch(filters, () => { reconnect() }, { deep: true })
</script>

<style scoped>
</style>
