<template>
  <main class="min-h-screen bg-base-100 text-base-content">
    <div class="w-full max-w-4xl mx-auto px-4 md:px-6 py-8">
      <!-- Hero -->
      <section class="relative overflow-hidden rounded-2xl bg-gradient-to-br from-error/15 via-base-200 to-warning/10 border border-base-300/50 shadow">
        <div class="p-6 md:p-10">
          <div class="flex items-start gap-4">
            <div class="shrink-0 w-12 h-12 rounded-full bg-error/20 text-error grid place-items-center text-2xl">🚫</div>
            <div class="flex-1">
              <div class="flex items-center gap-2 flex-wrap">
                <h1 class="text-3xl md:text-4xl font-extrabold tracking-tight">Access denied</h1>
                <span v-if="reasonLabel" class="badge badge-error badge-outline">{{ reasonLabel }}</span>
              </div>
              <p class="mt-2 opacity-80 max-w-prose">You do not have permission to configure this installation. Configure for a seedling is restricted to its owner account.</p>
              <div class="mt-3 text-sm opacity-70 flex flex-wrap items-center gap-2">
                <div v-if="sid"><span class="opacity-75">Seedling:</span> <code class="font-mono break-all">{{ sid }}</code></div>
                <div v-if="retPath"><span class="opacity-75">Requested:</span> <code class="font-mono break-all">{{ retPath }}</code></div>
              </div>
              <p v-if="reason==='owned'" class="mt-2 text-sm opacity-80">
                Owned by a different account; switch accounts or mint a new seedling.
              </p>
              <div class="mt-5 flex flex-wrap gap-2">
                <RouterLink
                  v-if="showClaim"
                  class="btn btn-primary btn-sm md:btn-md tooltip"
                  :to="{ name: 'start', query: { return: retPath || '/', sid, sk } }"
                  :title="'Sign in and claim this installation'"
                  data-tip="Sign in and claim"
                >Sign in & claim</RouterLink>
                <button
                  v-if="isAuthed"
                  class="btn btn-accent btn-sm md:btn-md tooltip"
                  type="button"
                  @click="mintNewSeedling"
                  :title="'Mint a fresh installation for your current account'"
                  data-tip="Mint new seedling"
                >Mint new seedling</button>
                <button
                  class="btn btn-warning btn-sm md:btn-md tooltip"
                  type="button"
                  @click="logoutAndSwitch"
                  :title="'Sign out and switch to the correct account to claim'"
                  data-tip="Switch account"
                >Switch account</button>
                <RouterLink class="btn btn-outline btn-sm md:btn-md tooltip" :to="{ name: 'account' }" data-tip="Open your Account">Account</RouterLink>
                <RouterLink class="btn btn-ghost btn-sm md:btn-md tooltip" :to="{ name: 'home' }" data-tip="Back to Home">Home</RouterLink>
                <button class="btn btn-ghost btn-sm md:btn-md tooltip" type="button" @click="copyContext" data-tip="Copy context to clipboard">Copy details</button>
              </div>
            </div>
          </div>
        </div>
      </section>

      <!-- Tips -->
      <section class="mt-6 grid md:grid-cols-2 gap-4">
        <div class="card bg-base-200 border border-base-300/50">
          <div class="card-body">
            <h2 class="card-title">Why am I seeing this?</h2>
            <ul class="list-disc ml-5 space-y-1 text-sm opacity-90">
              <li>You're signed in with a different account than the one that installed this seedling.</li>
              <li>The seedling belongs to a teammate or a test account.</li>
              <li>Your session expired and needs a quick refresh.</li>
            </ul>
          </div>
        </div>
        <div class="card bg-base-200 border border-base-300/50">
          <div class="card-body">
            <h2 class="card-title">What can I do?</h2>
            <ul class="list-disc ml-5 space-y-1 text-sm opacity-90">
              <li><b>Sign in & claim</b> to link this seedling to your account if appropriate.</li>
              <li>Open <b>Account</b> to view your seedlings and rotate links.</li>
              <li>Go <b>Home</b> to mint a fresh seedling and install it.</li>
            </ul>
          </div>
        </div>
      </section>
    </div>
  </main>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { auth } from '../lib/auth'

const route = useRoute()
const router = useRouter()
const sid = computed(() => String(route.query?.sid || ''))
const retPath = computed(() => String(route.query?.return || ''))
const sk = computed(() => String(route.query?.sk || ''))
const reason = computed(() => String(route.query?.reason || ''))
const reasonLabel = computed(() => {
  if (reason.value === 'owned') return 'Already owned'
  return ''
})
const claimable = ref(false)
const checked = ref(false)
const showClaim = computed(() => claimable.value && !!sid.value)
const isAuthed = computed(() => Boolean(auth.state.user))

async function copyContext() {
  try {
    const payload = { seedling_id: sid.value, return: retPath.value, when: new Date().toISOString() }
    await navigator.clipboard.writeText(JSON.stringify(payload, null, 2))
  } catch (_) {}
}

async function logoutAndSwitch() {
  try {
    await auth.logout()
  } catch (_) {}
  try {
    await auth.fetchSession()
  } catch (_) {}
  try {
    await router.replace({ name: 'start', query: { return: retPath.value || '/', sid: sid.value || '', sk: sk.value || '' } })
  } catch (_) {}
}

async function mintNewSeedling() {
  try {
    const r = await fetch('/api/seedlings', { method: 'POST', headers: { 'Content-Type': 'application/json' }, credentials: 'include' })
    if (!r.ok) return
    const j = await r.json().catch(() => null)
    if (!j || !j.ok || !j.seedling_id) return
    const next = { name: 'start', query: { sid: j.seedling_id, return: '/configure' } }
    await router.push(next)
  } catch (_) {}
}

onMounted(async () => {
  try {
    if (!sid.value || !sk.value) { checked.value = true; return }
    const r = await fetch(`/api/seedlings/${encodeURIComponent(sid.value)}/claimable?sk=${encodeURIComponent(sk.value)}`, { cache: 'no-store' })
    if (r.ok) {
      const j = await r.json().catch(() => ({ ok: false }))
      claimable.value = !!(j && j.ok && j.claimable)
    }
  } catch (_) { /* ignore */ }
  finally { checked.value = true }
})
</script>

<style scoped>
</style>
