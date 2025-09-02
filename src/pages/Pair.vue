<script setup>
import { ref, onMounted, onBeforeUnmount } from 'vue'
import { useRouter, useRoute } from 'vue-router'
import { gardener } from '../lib/gardener'

const router = useRouter()
const route = useRoute()
const gardenerId = ref(gardener.getGardenerId())
const seedlingId = ref('')
const token = ref('')
const status = ref('')
const error = ref('')
const checking = ref(false)
let pollTimer = null
const showSuccessModal = ref(false)

// Pairing details (aligned to gardener_id/seedling_id)
const deviceId = ref('')
const pairingMsg = ref('')

function showToast(msg, css = 'success') {
  // minimal inline toast replacement for this page
  try { console.info('[toast]', css, msg) } catch (_) {}
}

async function checkLinkedOnce() {
  try {
    checking.value = true
    const url = new URL('/api/link/status', window.location.origin)
    url.searchParams.set('gardener_id', gardenerId.value || '')
    const res = await fetch(url.toString(), { method: 'GET' })
    const data = await res.json()
    if (res.ok && data?.ok && Array.isArray(data.linked_seedlings) && data.linked_seedlings.length > 0) {
      const first = String(data.linked_seedlings[0] || '')
      if (first) {
        deviceId.value = first
        pairingMsg.value = 'Linked'
      }
      status.value = 'Linked'
      return true
    } else {
      pairingMsg.value = 'Waiting for link…'
    }
    return false
  } catch (_) { return false }
  finally { checking.value = false }
}

async function autoPairOnce() {
  try {
    if (!gardenerId.value || !seedlingId.value) return false
    const res = await fetch('/api/link/auto', {
      method: 'POST', headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ gardener_id: gardenerId.value, seedling_id: seedlingId.value }),
    })
    const data = await res.json()
    if (res.ok && data?.ok) return true
    return false
  } catch (_) { return false }
}

function showModalThenRedirect() {
  showSuccessModal.value = true
  setTimeout(() => {
    showSuccessModal.value = false
    router.push({ name: 'configure' })
  }, 5000)
}

function startPolling() {
  if (pollTimer) return
  pollTimer = setInterval(() => { void checkLinkedOnce() }, 2000)
}

function stopPolling() {
  if (pollTimer) { clearInterval(pollTimer); pollTimer = null }
}

async function startLink() {
  error.value = ''
  status.value = 'requesting token...'
  try {
    const res = await fetch('/api/link/start', {
      method: 'POST', headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ gardener_id: gardenerId.value, platform: 'web' }),
    })
    if (!res.ok) throw new Error('link_start_http_' + res.status)
    const data = await res.json()
    if (!data || !data.ok) throw new Error('link_start_failed')
    token.value = data.token
    status.value = 'Token ready — paste this token into Seedling to complete linking'
  } catch (e) {
    error.value = e?.message || 'link_start_failed'
    status.value = ''
  }
}

async function completeDemo() {
  // For testing only: simulate a seedling completing the link using the same app as a client
  error.value = ''
  status.value = 'completing link...'
  try {
    if (!token.value) throw new Error('no_token')
    const seedling_id = 'seedling-demo-' + Math.random().toString(36).slice(2, 8)
    const res = await fetch('/api/link/complete', {
      method: 'POST', headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ token: token.value, seedling_id }),
    })
    const data = await res.json()
    if (!res.ok || !data?.ok) throw new Error(data?.error || ('link_complete_http_' + res.status))
    status.value = `linked with ${data.seedling_id}`
  } catch (e) { error.value = e?.message || 'link_complete_failed'; status.value = '' }
}

function copy(text) {
  try { navigator.clipboard.writeText(text); showToast('Copied', 'success') } catch (_) { showToast('Copy failed', 'error') }
}

onMounted(async () => {
  // If gardener_id is provided in query (from /configure redirect), persist it
  try {
    const gid = String(route.query.gardener_id || '').trim()
    if (gid) gardener.setGardenerId(gid)
  } catch (_) {}
  gardenerId.value = gardener.getGardenerId()
  try { seedlingId.value = String(route.query.seedling_id || '').trim() } catch (_) { seedlingId.value = '' }

  // If already linked, redirect quickly; otherwise, poll for pairing completion.
  const already = await checkLinkedOnce()
  if (already) {
    showModalThenRedirect()
    return
  }
  // Attempt auto-pair when both IDs are present
  const attempted = await autoPairOnce()
  if (attempted) {
    showModalThenRedirect()
    return
  }
  startPolling()
})

onBeforeUnmount(() => {
  stopPolling()
})
</script>

<template>
  <div class="container mx-auto p-4">
    <h1 class="text-2xl font-semibold mb-4">Link Seedling</h1>
    <div class="mb-1">Gardener ID: <code>{{ gardenerId }}</code></div>
    <div v-if="seedlingId" class="mb-3">Seedling ID (from link): <code>{{ seedlingId }}</code></div>
    <div v-if="deviceId" class="alert alert-success mb-3">
      <span>Paired to Seedling <b class="font-mono">{{ deviceId }}</b></span>
    </div>
    <div v-if="pairingMsg" class="text-xs mb-3" :class="pairingMsg.includes('error') ? 'text-error' : 'opacity-70'">{{ pairingMsg }}</div>

    <div v-if="checking" class="text-sm opacity-70 mb-2">Checking link status…</div>

    <!-- Advanced link token flow (optional) -->
    <details class="collapse">
      <summary class="collapse-title text-base font-semibold">Advanced link flow</summary>
      <div class="collapse-content p-0">
        <div class="p-3 rounded-box bg-base-300/50 space-y-2">
          <div class="flex flex-wrap items-center gap-2 mb-3">
            <button class="btn btn-primary" @click="startLink">Start Link</button>
            <button class="btn" :disabled="!token" @click="completeDemo">Complete (demo)</button>
          </div>
          <div v-if="token" class="mb-2">
            <div class="font-mono break-all">Token: {{ token }}</div>
          </div>
          <div v-if="status" class="text-success">{{ status }}</div>
          <div v-if="error" class="text-error">{{ error }}</div>
        </div>
      </div>
    </details>
  </div>

  <!-- Success Modal -->
  <div v-if="showSuccessModal" class="fixed inset-0 z-50 flex items-center justify-center">
    <div class="absolute inset-0 bg-black/60"></div>
    <div class="relative bg-white dark:bg-neutral-800 rounded-lg shadow-lg p-6 max-w-sm w-full mx-4 text-center">
      <h2 class="text-xl font-semibold mb-2">Paired successfully</h2>
      <p class="mb-4">Redirecting to configuration…</p>
      <button class="btn btn-primary" @click="showSuccessModal = false; router.push({ name: 'configure' })">Go now</button>
    </div>
  </div>
</template>
