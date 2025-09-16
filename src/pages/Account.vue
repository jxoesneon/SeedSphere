<template>
  <main class="min-h-screen bg-base-100 text-base-content">
    <div class="container mx-auto p-6">
      <!-- Hero -->
      <section class="relative overflow-hidden rounded-2xl bg-gradient-to-br from-primary/15 via-base-200 to-secondary/10 border border-base-300/50 shadow p-6 md:p-10">
        <h1 class="text-3xl md:text-4xl font-extrabold tracking-tight">Account</h1>
        <p class="mt-3 opacity-80 max-w-prose">Manage your profile, session, and seedlings.</p>
      </section>

      <!-- Content grid -->
      <section class="mt-8 grid gap-6 md:grid-cols-2">
        <!-- Profile -->
        <div class="card bg-base-200 border border-base-300/50">
          <div class="card-body">
            <h2 class="card-title">Profile</h2>
            <div class="mt-2 space-y-2">
              <div class="flex items-center gap-2"><span class="opacity-70">User ID:</span><code class="whitespace-pre-wrap break-all">{{ user?.id || '—' }}</code></div>
              <div class="flex items-center gap-2"><span class="opacity-70">Email:</span><span>{{ user?.email || '—' }}</span></div>
              <div class="flex items-center gap-2"><span class="opacity-70">Provider:</span><span>{{ provider }}</span></div>
            </div>

            <div class="mt-4 flex gap-2">
              <button class="btn btn-outline btn-sm" @click="refreshSession" :disabled="loading">Refresh session</button>
              <button class="btn btn-error btn-sm" @click="logout" :disabled="loading">Sign out</button>
            </div>
            <p v-if="sessionNotice" class="mt-2 text-sm opacity-70">{{ sessionNotice }}</p>
          </div>
        </div>

        <!-- Gardener -->
        <div class="card bg-base-200 border border-base-300/50">
          <div class="card-body">
            <h2 class="card-title">Gardener</h2>
            <p class="opacity-80">Manage your Gardener PWA executor and view its identifiers.</p>
            <div class="mt-3 space-y-2">
              <div class="flex items-start gap-2">
                <span class="opacity-70 mt-1">Gardener ID:</span>
                <div class="flex-1 break-all">
                  <code class="font-mono">{{ gardenerId || '—' }}</code>
                </div>
                <button class="btn btn-ghost btn-xs rounded-full" :disabled="!gardenerId" @click="copy(gardenerId)">Copy</button>
              </div>
              <div class="flex items-start gap-2" v-if="gardenerId">
                <span class="opacity-70 mt-1">Manifest:</span>
                <div class="flex-1 break-all">
                  <a class="link" :href="manifestUrl" target="_blank" rel="noopener">{{ manifestUrl }}</a>
                </div>
                <button class="btn btn-ghost btn-xs rounded-full" @click="copy(manifestUrl)">Copy</button>
              </div>
              <div class="flex items-start gap-2" v-if="gardenerId">
                <span class="opacity-70 mt-1">Status:</span>
                <div class="flex-1 break-all">
                  <a class="link" :href="statusUrl" target="_blank" rel="noopener">{{ statusUrl }}</a>
                </div>
                <button class="btn btn-ghost btn-xs rounded-full" @click="copy(statusUrl)">Copy</button>
              </div>
              <div class="flex items-start gap-2" v-if="gardenerId">
                <span class="opacity-70 mt-1">SSE:</span>
                <div class="flex-1 break-all">
                  <code class="font-mono">{{ sseUrl }}</code>
                </div>
                <button class="btn btn-ghost btn-xs rounded-full" @click="copy(sseUrl)">Copy</button>
              </div>
            </div>
            <div class="mt-4 flex gap-2">
              <RouterLink class="btn btn-primary btn-sm" to="/gardener">Open Gardener</RouterLink>
              <button class="btn btn-ghost btn-sm" @click="refreshGardenerId">Refresh ID</button>
            </div>
            <p v-if="gardNotice" class="mt-2 text-sm opacity-70">{{ gardNotice }}</p>

            <div class="divider my-4"></div>
            <h3 class="font-semibold">My gardeners</h3>
            <div v-if="gardenerListError" class="alert alert-error mt-2">{{ gardenerListError }}</div>
            <div class="overflow-x-auto mt-2">
              <table class="table table-sm">
                <thead>
                  <tr>
                    <th>Gardener ID</th>
                    <th>Status</th>
                    <th>Created</th>
                    <th>Last seen</th>
                    <th></th>
                  </tr>
                </thead>
                <tbody>
                  <tr v-for="g in pagedGardeners" :key="g.gardener_id">
                    <td class="font-mono text-xs break-all">
                      {{ g.gardener_id }}
                      <button class="btn btn-ghost btn-xs ml-2" :aria-label="`Copy ID ${g.gardener_id}`" @click="copy(g.gardener_id)">Copy ID</button>
                    </td>
                    <td>
                      <span v-if="String(g.status||'active')==='active'" class="badge badge-success badge-sm">active</span>
                      <span v-else class="badge badge-error badge-sm">{{ g.status }}</span>
                    </td>
                    <td>{{ ts(g.created_at) }}</td>
                    <td>{{ ts(g.last_seen) }}</td>
                    <td>
                      <button v-if="String(g.status||'active')!=='revoked'" class="btn btn-ghost btn-xs" :aria-label="`Revoke ${g.gardener_id}`" :disabled="loading" @click="openGardenerRevokeConfirm(g.gardener_id)">Revoke</button>
                      <button v-else class="btn btn-error btn-xs" :aria-label="`Delete ${g.gardener_id}`" :disabled="loading" @click="openGardenerDeleteConfirm(g.gardener_id)">Delete</button>
                    </td>
                  </tr>
                  <tr v-if="!gardeners.length && !gardenerListError">
                    <td colspan="5" class="opacity-70">No gardeners yet.</td>
                  </tr>
                </tbody>
              </table>
            </div>
            <div class="mt-3 flex items-center justify-between">
              <div class="join">
                <button class="btn btn-xs join-item" :disabled="gardenerPage===1" @click="gardenerPage=gardenerPage-1">Prev</button>
                <button class="btn btn-xs join-item" disabled>Page {{ gardenerPage }} / {{ gardenerTotalPages }}</button>
                <button class="btn btn-xs join-item" :disabled="gardenerPage>=gardenerTotalPages" @click="gardenerPage=gardenerPage+1">Next</button>
              </div>
              <div class="flex items-center gap-3">
                <label class="label cursor-pointer gap-2">
                  <span class="label-text text-sm">Show revoked</span>
                  <input type="checkbox" class="toggle toggle-xs" v-model="showRevokedGardeners" @change="loadGardeners" />
                </label>
                <button class="btn btn-ghost btn-xs" :disabled="loading" @click="loadGardeners">Refresh</button>
              </div>
            </div>
          </div>
        </div>

        <!-- Seedlings -->
        <div class="card bg-base-200 border border-base-300/50">
          <div class="card-body">
            <h2 class="card-title">Seedlings</h2>
            <p class="opacity-80">Mint a new per-install identity and get its ready-to-use Stremio URL.</p>
            <div class="mt-3 flex gap-2">
              <button class="btn btn-primary btn-sm" @click="mintSeedling" :disabled="loading">Mint seedling</button>
            </div>
            <div v-if="mint" class="mt-4 space-y-2">
              <div class="flex items-start gap-2">
                <span class="opacity-70 mt-1">Manifest URL:</span>
                <div class="flex-1 break-all">
                  <a class="link" :href="mint.manifestUrl" target="_blank" rel="noopener">{{ mint.manifestUrl }}</a>
                </div>
                <button class="btn btn-ghost btn-xs rounded-full" @click="copy(mint.manifestUrl)">Copy</button>
              </div>
              <div class="flex items-start gap-2">
                <span class="opacity-70 mt-1">Stremio:</span>
                <div class="flex-1 break-all">
                  <a class="btn btn-outline btn-xs" :href="mint.stremioUrl">Install / Open</a>
                </div>
              </div>
              <p v-if="mintNotice" class="text-sm opacity-70">{{ mintNotice }}</p>
            </div>
            <div class="divider my-4"></div>
            <h3 class="font-semibold">My seedlings</h3>
            <div v-if="listError==='unauthorized'" class="alert alert-warning mt-2">
              You are not signed in on this origin. Please <RouterLink class="link" :to="{ name: 'start', query: { return: '/account' } }">sign in</RouterLink> to view your seedlings.
            </div>
            <div v-else-if="listError" class="alert alert-error mt-2">{{ listError }}</div>
            <div class="overflow-x-auto mt-2">
              <table class="table table-sm">
                <thead>
                  <tr>
                    <th>Install ID</th>
                    <th>Status</th>
                    <th>Created</th>
                    <th>Last seen</th>
                    <th></th>
                  </tr>
                </thead>
                <tbody>
                  <tr v-for="s in pagedSeedlings" :key="s.install_id">
                    <td class="font-mono text-xs break-all">
                      {{ s.install_id }}
                      <button class="btn btn-ghost btn-xs ml-2" :aria-label="`Copy ID ${s.install_id}`" @click="copy(s.install_id)">Copy ID</button>
                    </td>
                    <td>
                      <span v-if="String(s.status||'active')==='active'" class="badge badge-success badge-sm">active</span>
                      <span v-else class="badge badge-error badge-sm">{{ s.status }}</span>
                    </td>
                    <td>{{ ts(s.created_at) }}</td>
                    <td>{{ ts(s.last_seen) }}</td>
                    <td>
                      <button v-if="String(s.status||'active')!=='revoked'" class="btn btn-ghost btn-xs" :aria-label="`Revoke ${s.install_id}`" :disabled="loading" @click="openRevokeConfirm(s.install_id)">Revoke</button>
                      <button v-else class="btn btn-error btn-xs" :aria-label="`Delete ${s.install_id}`" :disabled="loading" @click="openDeleteConfirm(s.install_id)">Delete</button>
                    </td>
                  </tr>
                  <tr v-if="!seedlings.length && !listError">
                    <td colspan="5" class="opacity-70">No seedlings yet.</td>
                  </tr>
                </tbody>
              </table>
            </div>
            <div class="mt-3 flex items-center justify-between">
              <div class="join">
                <button class="btn btn-xs join-item" :disabled="page===1" @click="page=page-1">Prev</button>
                <button class="btn btn-xs join-item" disabled>Page {{ page }} / {{ totalPages }}</button>
                <button class="btn btn-xs join-item" :disabled="page>=totalPages" @click="page=page+1">Next</button>
              </div>
              <div class="flex items-center gap-3">
                <label class="label cursor-pointer gap-2">
                  <span class="label-text text-sm">Show revoked</span>
                  <input type="checkbox" class="toggle toggle-xs" v-model="showRevoked" @change="loadSeedlings" />
                </label>
                <button class="btn btn-ghost btn-xs" :disabled="loading" @click="loadSeedlings">Refresh</button>
              </div>
            </div>
          </div>
        </div>

        <!-- Revoke confirmation modal -->
        <dialog ref="revokeDlg" class="modal">
          <div class="modal-box">
            <h3 class="font-bold text-lg mb-2">Revoke seedling</h3>
            <p class="opacity-80">Are you sure you want to revoke seedling <code class="font-mono">{{ pendingRevokeId }}</code>? This will disable its access.</p>
            <div class="modal-action">
              <button class="btn btn-error" @click="confirmRevoke" :disabled="loading">Confirm revoke</button>
              <button class="btn" @click="closeRevoke">Cancel</button>
            </div>
          </div>
          <form method="dialog" class="modal-backdrop" @click="closeRevoke"><button>close</button></form>
        </dialog>

        <!-- Gardener revoke confirmation modal -->
        <dialog ref="gardRevokeDlg" class="modal">
          <div class="modal-box">
            <h3 class="font-bold text-lg mb-2">Revoke gardener</h3>
            <p class="opacity-80">Are you sure you want to revoke gardener <code class="font-mono">{{ pendingGardenerRevokeId }}</code>? This will disable it for dispatch.</p>
            <div class="modal-action">
              <button class="btn btn-error" @click="confirmGardenerRevoke" :disabled="loading">Confirm revoke</button>
              <button class="btn" @click="closeGardenerRevoke">Cancel</button>
            </div>
          </div>
          <form method="dialog" class="modal-backdrop" @click="closeGardenerRevoke"><button>close</button></form>
        </dialog>

        <!-- Gardener delete confirmation modal -->
        <dialog ref="gardDeleteDlg" class="modal">
          <div class="modal-box">
            <h3 class="font-bold text-lg mb-2">Delete gardener</h3>
            <p class="opacity-80">This will permanently remove gardener <code class="font-mono">{{ pendingGardenerDeleteId }}</code> and related links. This action cannot be undone.</p>
            <div class="modal-action">
              <button class="btn btn-error" @click="confirmGardenerDelete" :disabled="loading">Confirm delete</button>
              <button class="btn" @click="closeGardenerDelete">Cancel</button>
            </div>
          </div>
          <form method="dialog" class="modal-backdrop" @click="closeGardenerDelete"><button>close</button></form>
        </dialog>

        <!-- Delete confirmation modal -->
        <dialog ref="deleteDlg" class="modal">
          <div class="modal-box">
            <h3 class="font-bold text-lg mb-2">Delete seedling</h3>
            <p class="opacity-80">This will permanently remove seedling <code class="font-mono">{{ pendingDeleteId }}</code> and related links. This action cannot be undone.</p>
            <div class="modal-action">
              <button class="btn btn-error" @click="confirmDelete" :disabled="loading">Confirm delete</button>
              <button class="btn" @click="closeDelete">Cancel</button>
            </div>
          </div>
          <form method="dialog" class="modal-backdrop" @click="closeDelete"><button>close</button></form>
        </dialog>

        <!-- Security & Privacy -->
        <div class="card bg-base-200 border border-base-300/50 md:col-span-2">
          <div class="card-body">
            <h2 class="card-title">Security & Privacy</h2>
            <ul class="list-disc pl-6 mt-2 space-y-1">
              <li>Your website session is stored in a secure, HTTP-only cookie with SameSite=Lax.</li>
              <li>Seedlings use a per-install secret in the URL path; secrets are stored hashed with per-seedling salt.</li>
              <li>Sensitive path segments are masked in logs; rate limits protect sensitive endpoints.</li>
            </ul>
            <div class="mt-3 flex gap-2">
              <RouterLink to="/privacy" class="btn btn-ghost btn-sm rounded-full">Privacy</RouterLink>
              <RouterLink to="/terms" class="btn btn-ghost btn-sm rounded-full">Terms</RouterLink>
            </div>
          </div>
        </div>
      </section>
    </div>
  </main>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'
import { auth } from '../lib/auth'

const loading = ref(false)
const mint = ref(null)
const mintNotice = ref('')
const sessionNotice = ref('')
const user = computed(() => auth.state.user)
const seedlings = ref([])
const listError = ref('')
const showRevoked = ref(false)
// Gardeners management
const gardeners = ref([])
const gardenerListError = ref('')
const showRevokedGardeners = ref(false)
const page = ref(1)
const pageSize = 10
const totalPages = computed(() => Math.max(1, Math.ceil(seedlings.value.length / pageSize)))
const pagedSeedlings = computed(() => {
  const start = (page.value - 1) * pageSize
  return seedlings.value.slice(start, start + pageSize)
})
const gardenerPage = ref(1)
const gardenerPageSize = 10
const gardenerTotalPages = computed(() => Math.max(1, Math.ceil(gardeners.value.length / gardenerPageSize)))
const pagedGardeners = computed(() => {
  const start = (gardenerPage.value - 1) * gardenerPageSize
  return gardeners.value.slice(start, start + gardenerPageSize)
})

// Gardener card state
const gardenerId = ref('')
const gardNotice = ref('')
const origin = window.location.origin
const manifestUrl = computed(() => gardenerId.value ? `${origin}/manifest.json?gardener_id=${encodeURIComponent(gardenerId.value)}` : '')
const statusUrl = computed(() => gardenerId.value ? `${origin}/api/link/status?gardener_id=${encodeURIComponent(gardenerId.value)}` : '')
const sseUrl = computed(() => gardenerId.value ? `${origin}/api/rooms/${encodeURIComponent(gardenerId.value)}/events` : '')

function refreshGardenerId() {
  try {
    const gid = localStorage.getItem('gardener_id') || ''
    gardenerId.value = gid
    gardNotice.value = gid ? 'Gardener ID loaded.' : 'No Gardener ID found on this device.'
    setTimeout(() => { gardNotice.value = '' }, 1500)
  } catch (_) {}
}
const revokeDlg = ref(null)
const pendingRevokeId = ref('')
const deleteDlg = ref(null)
const pendingDeleteId = ref('')
const gardRevokeDlg = ref(null)
const pendingGardenerRevokeId = ref('')
const gardDeleteDlg = ref(null)
const pendingGardenerDeleteId = ref('')
const provider = computed(() => {
  try {
    const id = user.value?.id || ''
    if (!id) return '—'
    const p = id.split(':')[0]
    return p || '—'
  } catch { return '—' }
})

async function refreshSession() {
  loading.value = true
  try {
    await auth.fetchSession()
    sessionNotice.value = 'Session refreshed.'
  } catch (_) {
    sessionNotice.value = 'Failed to refresh session.'
  } finally { loading.value = false }
}

async function logout() {
  loading.value = true
  try {
    await auth.logout()
    await auth.fetchSession()
    sessionNotice.value = 'Signed out.'
  } catch (_) {
    sessionNotice.value = 'Failed to sign out.'
  } finally { loading.value = false }
}

async function mintSeedling() {
  loading.value = true
  mintNotice.value = ''
  mint.value = null
  try {
    const r = await fetch('/api/seedlings', { method: 'POST', headers: { 'Content-Type': 'application/json' } })
    if (!r.ok) {
      const t = await r.text()
      throw new Error(t || 'mint_failed')
    }
    const j = await r.json()
    if (!j || !j.ok) throw new Error('mint_failed')
    mint.value = { manifestUrl: j.manifestUrl, stremioUrl: j.stremioUrl }
    mintNotice.value = 'Seedling minted. Use the Stremio link to install.'
    await loadSeedlings()
  } catch (e) {
    mintNotice.value = 'Mint failed. Ensure you are logged in and within usage limits.'
  } finally { loading.value = false }
}

async function copy(text) {
  try {
    await navigator.clipboard.writeText(String(text || ''))
    // Prefer mint notice if present, else gardener notice
    if (typeof mintNotice !== 'undefined') {
      mintNotice.value = 'Copied to clipboard.'
      setTimeout(() => { mintNotice.value = '' }, 1500)
    } else {
      gardNotice.value = 'Copied to clipboard.'
      setTimeout(() => { gardNotice.value = '' }, 1500)
    }
  } catch (_) {}
}

async function loadSeedlings() {
  listError.value = ''
  try {
    const url = showRevoked.value ? '/api/seedlings?include_revoked=1' : '/api/seedlings'
    const r = await fetch(url, { headers: { 'Accept': 'application/json' }, credentials: 'include', cache: 'no-store' })
    if (r.status === 401) { listError.value = 'unauthorized'; seedlings.value = []; return }
    if (!r.ok) throw new Error('list_failed')
    const j = await r.json()
    if (!j || !j.ok) throw new Error('list_failed')
    seedlings.value = Array.isArray(j.seedlings) ? j.seedlings : []
  } catch (e) {
    listError.value = 'Could not load seedlings.'
  }
}

// Gardeners management
async function loadGardeners() {
  gardenerListError.value = ''
  try {
    const url = showRevokedGardeners.value ? '/api/gardeners?include_revoked=1' : '/api/gardeners'
    const r = await fetch(url, { headers: { 'Accept': 'application/json' }, credentials: 'include', cache: 'no-store' })
    if (r.status === 401) { gardenerListError.value = 'unauthorized'; gardeners.value = []; return }
    if (!r.ok) throw new Error('list_failed')
    const j = await r.json()
    if (!j || !j.ok) throw new Error('list_failed')
    gardeners.value = Array.isArray(j.gardeners) ? j.gardeners : []
  } catch (e) {
    gardenerListError.value = 'Could not load gardeners.'
  }
}

function openGardenerRevokeConfirm(gardener_id) {
  pendingGardenerRevokeId.value = String(gardener_id || '')
  try { gardRevokeDlg.value?.showModal() } catch (_) {}
}

function closeGardenerRevoke() {
  pendingGardenerRevokeId.value = ''
  try { gardRevokeDlg.value?.close() } catch (_) {}
}

async function revokeGardener(gardener_id) {
  if (!gardener_id) return
  loading.value = true
  try {
    const r = await fetch('/api/gardeners/revoke', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      credentials: 'include',
      cache: 'no-store',
      body: JSON.stringify({ gardener_id }),
    })
    if (!r.ok) {
      let msg = 'revoke_failed'
      try { const j = await r.json(); if (j && j.error) msg = String(j.error) } catch { try { msg = await r.text() } catch { /* ignore */ } }
      throw new Error(msg || 'revoke_failed')
    }
    await loadGardeners()
  } catch (e) {
    gardenerListError.value = 'Revoke failed.'
  } finally { loading.value = false }
}

async function confirmGardenerRevoke() {
  const id = pendingGardenerRevokeId.value
  closeGardenerRevoke()
  if (!id) return
  await revokeGardener(id)
}

function openGardenerDeleteConfirm(gardener_id) {
  pendingGardenerDeleteId.value = String(gardener_id || '')
  try { gardDeleteDlg.value?.showModal() } catch (_) {}
}

function closeGardenerDelete() {
  pendingGardenerDeleteId.value = ''
  try { gardDeleteDlg.value?.close() } catch (_) {}
}

async function deleteGardener(gardener_id) {
  if (!gardener_id) return
  loading.value = true
  try {
    const r = await fetch('/api/gardeners/delete', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      credentials: 'include',
      cache: 'no-store',
      body: JSON.stringify({ gardener_id }),
    })
    if (!r.ok) {
      let msg = 'delete_failed'
      try { const j = await r.json(); if (j && j.error) msg = String(j.error) } catch { try { msg = await r.text() } catch { /* ignore */ } }
      throw new Error(msg || 'delete_failed')
    }
    await loadGardeners()
  } catch (e) {
    gardenerListError.value = 'Delete failed.'
  } finally { loading.value = false }
}

async function confirmGardenerDelete() {
  const id = pendingGardenerDeleteId.value
  closeGardenerDelete()
  if (!id) return
  await deleteGardener(id)
}

async function revoke(install_id) {
  if (!install_id) return
  loading.value = true
  try {
    const r = await fetch('/api/seedlings/revoke', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      credentials: 'include',
      cache: 'no-store',
      body: JSON.stringify({ install_id }),
    })
    if (!r.ok) {
      let msg = 'revoke_failed'
      try { const j = await r.json(); if (j && j.error) msg = String(j.error) } catch { try { msg = await r.text() } catch { /* ignore */ } }
      throw new Error(msg || 'revoke_failed')
    }
    await loadSeedlings()
  } catch (e) {
    listError.value = 'Revoke failed.'
  } finally { loading.value = false }
}

function openRevokeConfirm(install_id) {
  pendingRevokeId.value = String(install_id || '')
  try { revokeDlg.value?.showModal() } catch (_) {}
}

function closeRevoke() {
  pendingRevokeId.value = ''
  try { revokeDlg.value?.close() } catch (_) {}
}

async function confirmRevoke() {
  const id = pendingRevokeId.value
  closeRevoke()
  if (!id) return
  await revoke(id)
}

function openDeleteConfirm(install_id) {
  pendingDeleteId.value = String(install_id || '')
  try { deleteDlg.value?.showModal() } catch (_) {}
}

function closeDelete() {
  pendingDeleteId.value = ''
  try { deleteDlg.value?.close() } catch (_) {}
}

async function deleteSeedling(install_id) {
  if (!install_id) return
  loading.value = true
  try {
    const r = await fetch('/api/seedlings/delete', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      credentials: 'include',
      cache: 'no-store',
      body: JSON.stringify({ install_id }),
    })
    if (!r.ok) {
      let msg = 'delete_failed'
      try { const j = await r.json(); if (j && j.error) msg = String(j.error) } catch { try { msg = await r.text() } catch { /* ignore */ } }
      throw new Error(msg || 'delete_failed')
    }
    await loadSeedlings()
  } catch (e) {
    listError.value = 'Delete failed.'
  } finally { loading.value = false }
}

async function confirmDelete() {
  const id = pendingDeleteId.value
  closeDelete()
  if (!id) return
  await deleteSeedling(id)
}

function ts(v) {
  try { if (!v) return '—'; const d = new Date(Number(v)); if (isNaN(d.getTime())) return '—'; return d.toLocaleString() } catch { return '—' }
}

onMounted(async () => {
  if (!user.value) {
    try { await auth.fetchSession() } catch (_) {}
  }
  await loadSeedlings()
  await loadGardeners()
  refreshGardenerId()
})
</script>

<style scoped>
</style>
