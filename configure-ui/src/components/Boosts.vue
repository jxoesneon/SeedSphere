<script setup>
import { ref, onMounted, onBeforeUnmount } from 'vue'

const items = ref([])
const status = ref('')
let es = null
let pollTimer = null

function renderStatus() {
  const count = items.value.length
  status.value = count ? `Loaded ${count} recent boost${count===1?'':'s'}` : 'No data yet'
}

async function loadRecent() {
  try {
    const resp = await fetch('/api/boosts/recent')
    if (!resp.ok) throw new Error('HTTP ' + resp.status)
    const data = await resp.json()
    items.value = Array.isArray(data.items) ? data.items : []
    renderStatus()
  } catch (e) {
    status.value = 'Failed to load: ' + (e && e.message ? e.message : String(e))
  }
}

function disconnect() { if (es) { try { es.close() } catch (_) {} es = null } }

function connectSSE() {
  if (!window.EventSource) { startPolling(); return }
  try {
    disconnect()
    es = new EventSource('/api/boosts/events')
    es.addEventListener('snapshot', (ev) => {
      try { const data = JSON.parse(ev.data || '{}'); items.value = Array.isArray(data.items) ? data.items : [] } catch (_) {}
      renderStatus()
    })
    es.addEventListener('boost', (ev) => {
      try { const it = JSON.parse(ev.data || '{}'); items.value.unshift(it); if (items.value.length > 50) items.value.pop() } catch (_) {}
      renderStatus()
    })
    es.onerror = () => { disconnect(); startPolling() }
    es.onopen = () => { stopPolling() }
  } catch (_) { startPolling() }
}

function startPolling() { if (pollTimer) return; loadRecent(); pollTimer = setInterval(loadRecent, 10000) }
function stopPolling() { if (!pollTimer) return; clearInterval(pollTimer); pollTimer = null }

onMounted(() => { connectSSE() })
onBeforeUnmount(() => { disconnect(); stopPolling() })
</script>

<template>
  <div class="grid gap-3">
    <div class="flex items-center justify-between">
      <div class="font-medium">Boost Events</div>
      <div class="text-sm opacity-70">{{ status }}</div>
    </div>
    <div class="overflow-x-auto">
      <table class="table">
        <thead>
          <tr>
            <th>When</th>
            <th>Type</th>
            <th>ID</th>
            <th>Mode</th>
            <th>Total</th>
            <th>Healthy</th>
            <th>Source</th>
          </tr>
        </thead>
        <tbody>
          <tr v-if="items.length === 0"><td colspan="7" class="text-center opacity-70">No recent boosts</td></tr>
          <tr v-for="(it, idx) in items" :key="idx">
            <td>{{ it.time ? new Date(it.time).toLocaleString() : '' }}</td>
            <td>{{ it.type || '-' }}</td>
            <td class="break-all">{{ it.id || '-' }}</td>
            <td>{{ (it.mode || '').toUpperCase() }}</td>
            <td>{{ it.total ?? '-' }}</td>
            <td>{{ it.healthy ?? '-' }}</td>
            <td class="break-all">{{ it.source || '' }}</td>
          </tr>
        </tbody>
      </table>
    </div>
  </div>
</template>
