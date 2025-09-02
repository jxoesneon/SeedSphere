<template>
  <div class="fixed inset-x-0 bottom-0 z-[1000] pointer-events-none">
    

    <!-- Drawer -->
    <div
      class="pointer-events-auto mx-auto max-w-5xl transition-transform duration-200"
      :class="open ? 'translate-y-0' : 'translate-y-[calc(100%_-_0.5rem)]'"
    >
      <div class="rounded-t-xl border border-base-300 bg-base-200 shadow-lg overflow-hidden">
        <div class="flex items-center justify-between px-3 py-2 bg-base-300">
          <div class="font-semibold text-sm">Dev Drawer</div>
          <div class="flex flex-wrap items-center gap-2">
            <span class="badge badge-ghost text-xs">env: {{ env }}</span>
            <button class="btn btn-ghost btn-xs" @click="refresh">Refresh</button>
          </div>
        </div>
        <div class="p-3 grid grid-cols-1 md:grid-cols-2 gap-3 text-sm">
          <!-- Auth state -->
          <div>
            <div class="font-medium mb-1">Auth session</div>
            <div class="space-y-1">
              <div><span class="opacity-70">userLabel:</span> <code class="break-all">{{ userLabel }}</code></div>
              <div><span class="opacity-70">auth.state.user:</span>
                <pre class="mt-1 whitespace-pre-wrap break-words">{{ pretty(auth.state.user) }}</pre>
              </div>
              <div><span class="opacity-70">/api/auth/session:</span>
                <pre class="mt-1 whitespace-pre-wrap break-words">{{ pretty(sessionApi) }}</pre>
              </div>
            </div>
            <div class="mt-2 flex gap-2">
              <button class="btn btn-xs" @click="auth.fetchSession()">Fetch session</button>
              <button class="btn btn-xs" @click="logout">Logout</button>
            </div>
          </div>

          <!-- Cookies / Magic link -->
          <div>
            <div class="font-medium mb-1">Browser & Magic link</div>
            <div class="space-y-1">
              <div><span class="opacity-70">cookies:</span>
                <pre class="mt-1 whitespace-pre-wrap break-words">{{ cookies }}</pre>
              </div>
              <div class="mt-2"><span class="opacity-70">/api/auth/magic/status:</span>
                <pre class="mt-1 whitespace-pre-wrap break-words">{{ pretty(magicStatus) }}</pre>
              </div>
              <div class="mt-2"><span class="opacity-70">/api/auth/magic/last:</span>
                <pre class="mt-1 whitespace-pre-wrap break-words">{{ pretty(magicLast) }}</pre>
              </div>
              <div v-if="magicLast && magicLast.link" class="mt-2">
                <a class="link link-primary" :href="magicLast.link" target="_self">Open last magic link</a>
              </div>
            </div>
          </div>
        </div>

        <!-- OAuth logs -->
        <div class="px-3 pb-3 text-sm">
          <div class="font-medium mb-1">OAuth logs (latest first)</div>
          <div class="flex flex-wrap items-center gap-2 mb-2">
            <button class="btn btn-ghost btn-xs" @click="fetchOauthLogs">Reload logs</button>
            <span class="opacity-70 text-xs">/api/auth/oauth/logs</span>
            <div class="flex items-center gap-1 ml-2">
              <label class="opacity-70 text-xs">Provider:</label>
              <select v-model="providerFilter" class="select select-xs select-bordered">
                <option value="google">google</option>
                <option value="all">all</option>
              </select>
            </div>
            <button class="btn btn-ghost btn-xs" @click="newestFirst = !newestFirst">
              {{ newestFirst ? 'Newest→Oldest' : 'Oldest→Newest' }}
            </button>
          </div>
          <div class="max-h-56 overflow-auto rounded border border-base-300 bg-base-100">
            <div v-if="visibleLogs.length === 0" class="p-2 opacity-70">No events yet</div>
            <ul v-else class="divide-y divide-base-300">
              <li v-for="(ev, i) in visibleLogs" :key="i" class="p-2">
                <div class="text-xs opacity-70">{{ ev.ts }} • {{ ev.provider }} • {{ ev.stage }}</div>
                <pre class="mt-1 whitespace-pre-wrap break-words">{{ pretty(ev) }}</pre>
              </li>
            </ul>
          </div>
        </div>
      </div>
    </div>

    <!-- Fallback floating button (bottom-right) -->
    <div class="pointer-events-auto fixed bottom-3 right-3">
      <button class="btn btn-sm btn-warning shadow" @click="toggle" aria-label="Toggle Dev Drawer (fallback)">
        {{ open ? 'Close Dev' : 'Dev' }}
      </button>
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted, computed, onBeforeUnmount } from 'vue'
import { auth } from '../lib/auth'

const open = ref(true)
const env = import.meta.env.MODE || (import.meta.env.DEV ? 'development' : 'production')
const cookies = ref('')
const sessionApi = ref(null)
const magicLast = ref(null)
const magicStatus = ref(null)
const oauthLogs = ref([])
const providerFilter = ref('google')
const newestFirst = ref(true)

const userLabel = computed(() => auth.parseUserLabel(auth.state.user))

function toggle() { open.value = !open.value }

function pretty(v) {
  try { return JSON.stringify(v, null, 2) } catch { return String(v) }
}

const visibleLogs = computed(() => {
  let arr = Array.isArray(oauthLogs.value) ? oauthLogs.value : []
  if (providerFilter.value !== 'all') arr = arr.filter((e) => e && e.provider === providerFilter.value)
  return newestFirst.value ? arr : arr.slice().reverse()
})

async function refresh() {
  try { cookies.value = document.cookie || '' } catch { cookies.value = '' }
  // fetch session API directly to compare with store
  try {
    const r = await fetch('/api/auth/session', { credentials: 'include', cache: 'no-store' })
    sessionApi.value = await r.json()
  } catch { sessionApi.value = { ok: false, error: 'fetch_failed' } }
  // dev helper: last magic link
  try {
    const r2 = await fetch('/api/auth/magic/last', { cache: 'no-store' })
    magicLast.value = await r2.json()
  } catch { magicLast.value = { ok: false, error: 'fetch_failed' } }
  // magic mailer status
  try {
    const r3 = await fetch('/api/auth/magic/status', { cache: 'no-store' })
    magicStatus.value = await r3.json()
  } catch { magicStatus.value = { ok: false, error: 'fetch_failed' } }
  // oauth logs
  try { await fetchOauthLogs() } catch {}
}

async function logout() {
  try { await auth.logout(); await refresh() } catch {}
}

onMounted(async () => {
  await refresh()
  try { window.devDrawerToggle = () => toggle() } catch {}
  // Keyboard toggle: Ctrl+Shift+D
  try {
    const handler = (e) => {
      if ((e.ctrlKey || e.metaKey) && e.shiftKey && (e.key === 'D' || e.key === 'd')) {
        e.preventDefault(); toggle()
      }
    }
    window.addEventListener('keydown', handler)
    onBeforeUnmount(() => { try { window.removeEventListener('keydown', handler) } catch {} })
  } catch {}
})

async function fetchOauthLogs() {
  try {
    const r = await fetch('/api/auth/oauth/logs', { cache: 'no-store' })
    const j = await r.json()
    oauthLogs.value = Array.isArray(j?.logs) ? j.logs : []
  } catch { oauthLogs.value = [] }
}
</script>

<style scoped>
</style>
