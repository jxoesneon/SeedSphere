<template>
  <div class="card bg-base-200 shadow h-full">
    <div class="card-body p-4">
      <div class="flex items-center justify-between">
        <h3 class="card-title text-base">Live boosts</h3>
        <span v-if="serverVersion" class="badge badge-ghost badge-sm">v{{ serverVersion }}</span>
      </div>
      <div v-if="items.length === 0" class="text-sm opacity-70 py-2">Awaiting activity…</div>
      <ul v-else class="space-y-2 max-h-80 overflow-auto pr-1" aria-live="polite">
        <li v-for="(it, idx) in items.slice(0, maxItems)" :key="idx" class="p-2 rounded-box bg-base-100 border border-base-300/40">
          <div class="flex items-center justify-between gap-2">
            <div class="flex items-center gap-2">
              <span class="badge badge-info badge-xs" :title="it.mode">{{ it.mode || 'normal' }}</span>
              <span class="text-xs opacity-80">{{ kindLabel(it) }}</span>
            </div>
            <div class="text-[11px] opacity-70 whitespace-nowrap">{{ timeAgo(it.ts || it.time) }}</div>
          </div>
          <div class="mt-1 text-sm font-medium truncate" :title="titleOf(it)">{{ titleOf(it) }}</div>
          <div class="mt-1 flex flex-wrap items-center gap-2 text-xs opacity-80">
            <span class="badge badge-ghost badge-xs">healthy {{ it.healthy }}</span>
            <span class="badge badge-ghost badge-xs">total {{ it.total }}</span>
            <span v-if="Number.isFinite(Number(it.limit)) && Number(it.limit) > 0" class="badge badge-ghost badge-xs">cap {{ it.limit }}</span>
            <span v-if="it.source" class="badge badge-ghost badge-xs">{{ it.source }}</span>
          </div>
        </li>
      </ul>
      <div class="mt-3 text-right">
        <a href="/api/boosts/recent" target="_blank" rel="noopener" class="link link-hover text-xs">View JSON →</a>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted, onBeforeUnmount, computed } from 'vue'

const props = defineProps({
  max: { type: Number, default: 8 },
})

const maxItems = computed(() => Math.max(1, Math.min(50, props.max)))
const items = ref([])
const serverVersion = ref('')
let es = null
let pingTimer = null

function titleOf(it) {
  const baseTitle = it.title || `${it.type}:${it.id}`
  if (Number.isFinite(Number(it.season)) && Number.isFinite(Number(it.episode))) {
    return `${baseTitle} • S${String(it.season).padStart(2,'0')}E${String(it.episode).padStart(2,'0')}`
  }
  return baseTitle
}

function kindLabel(it) {
  const type = String(it.type || '').toUpperCase()
  if (type === 'SERIES') return 'Series'
  if (type === 'MOVIE') return 'Movie'
  if (type) return type
  return 'Boost'
}

function timeAgo(ts) {
  try {
    const t = Number(ts) || Date.parse(ts)
    const d = Date.now() - t
    if (!Number.isFinite(d)) return ''
    const s = Math.floor(d / 1000)
    if (s < 10) return 'just now'
    if (s < 60) return `${s}s ago`
    const m = Math.floor(s / 60)
    if (m < 60) return `${m}m ago`
    const h = Math.floor(m / 60)
    if (h < 24) return `${h}h ago`
    const days = Math.floor(h / 24)
    return `${days}d ago`
  } catch (_) { return '' }
}

async function loadRecent() {
  try {
    const r = await fetch('/api/boosts/recent', { cache: 'no-store' })
    if (!r.ok) return
    const j = await r.json()
    if (j && j.ok && Array.isArray(j.items)) items.value = j.items
  } catch (_) { /* ignore */ }
}

function connectSSE() {
  try {
    if (es) { try { es.close() } catch (_) {} es = null }
    es = new EventSource('/api/boosts/events')
    es.addEventListener('server-info', (ev) => {
      try {
        const data = JSON.parse(ev.data)
        if (data && data.version) serverVersion.value = data.version
      } catch (_) {}
    })
    es.addEventListener('snapshot', (ev) => {
      try {
        const data = JSON.parse(ev.data)
        if (data && Array.isArray(data.items)) items.value = data.items
      } catch (_) {}
    })
    es.addEventListener('boost', (ev) => {
      try {
        const data = JSON.parse(ev.data)
        if (data) items.value = [data, ...items.value].slice(0, 50)
      } catch (_) {}
    })
    es.addEventListener('error', () => {
      // Try to reconnect in a bit
      try { es && es.close() } catch (_) {}
      es = null
      try { setTimeout(connectSSE, 2000) } catch (_) {}
    })
  } catch (_) {}
}

onMounted(() => {
  loadRecent()
  connectSSE()
  try {
    pingTimer = setInterval(loadRecent, 30000)
  } catch (_) {}
})

onBeforeUnmount(() => {
  try { pingTimer && clearInterval(pingTimer) } catch (_) {}
  try { es && es.close() } catch (_) {}
})
</script>

<style scoped>
</style>
