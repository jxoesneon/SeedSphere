<template>
  <main class="min-h-screen bg-base-100 text-base-content">
    <div class="container mx-auto p-6">
      <section class="relative overflow-hidden rounded-2xl bg-gradient-to-br from-primary/15 via-base-200 to-secondary/10 border border-base-300/50 shadow p-6 md:p-10">
        <h1 class="text-3xl md:text-4xl font-extrabold tracking-tight">Get Started</h1>
        <p class="mt-3 opacity-80 max-w-prose">Sign in to link this installation to your account. We will return you to Stremio automatically.</p>
        <div class="mt-6">
          <button class="btn btn-primary" type="button" @click="openLogin" v-if="!isAuthed">Sign in</button>
          <div v-else class="alert alert-success">You're signed in. Finalizing…</div>
        </div>
      </section>
    </div>

    <!-- Login Modal -->
    <dialog ref="dlg" class="modal" :open="!isAuthed">
      <div class="modal-box">
        <h3 class="font-bold text-lg mb-2">Sign in to SeedSphere</h3>
        <p class="text-sm opacity-80 mb-4">Sign in to bind this seedling to your account.</p>

        <div class="card bg-base-200 mb-3">
          <div class="card-body p-3 gap-2">
            <div class="text-sm">Magic link</div>
            <input v-model="email" type="email" class="input input-bordered input-sm w-full" placeholder="you@example.com" />
            <button class="btn btn-sm" :disabled="sending" @click="sendMagic">
              <span v-if="!sending">Send link</span>
              <span v-else class="loading loading-spinner loading-sm"></span>
            </button>
            <p v-if="notice" class="text-xs opacity-70">{{ notice }}</p>
          </div>
        </div>

        <div class="divider my-2">or continue with</div>
        <div class="flex flex-col gap-2">
          <button class="btn btn-outline justify-start" @click="start('google')">
            <img src="https://www.gstatic.com/firebasejs/ui/2.0.0/images/auth/google.svg" alt="Google" class="h-5 w-5 mr-2" />
            Continue with Google
          </button>
        </div>

        <div class="modal-action">
          <button class="btn" type="button" @click="closeLogin" :disabled="isAuthed">Close</button>
        </div>
      </div>
      <form method="dialog" class="modal-backdrop" @click="closeLogin">
        <button>close</button>
      </form>
    </dialog>
  </main>
</template>

<script setup>
import { ref, computed, onMounted, watch } from 'vue'
import { useRouter, useRoute } from 'vue-router'
import { auth } from '../lib/auth'

const router = useRouter()
const route = useRoute()
const dlg = ref(null)
const email = ref('')
const sending = ref(false)
const notice = ref('')
const seedlingId = ref('')
const seedlingSk = ref('')

const isAuthed = computed(() => Boolean(auth.state.user))
const returnPath = computed(() => {
  try {
    const q = route.query?.return || ''
    if (!q) return '/'
    const decoded = decodeURIComponent(String(q))
    // Basic safety: only allow same-origin path navigation
    return decoded.startsWith('/') ? decoded : '/'
  } catch (_) { return '/' }
})

function openLogin() { try { dlg.value?.showModal() } catch (_) {} }
function closeLogin() { try { dlg.value?.close() } catch (_) {} }
function start(provider) { auth.loginWith(provider) }

async function sendMagic() {
  const e = email.value.trim().toLowerCase()
  if (!e) { notice.value = 'Enter a valid email'; return }
  sending.value = true
  notice.value = ''
  const ok = await auth.startMagic(e)
  sending.value = false
  notice.value = ok ? 'Check your email for the sign-in link' : 'Could not send link'
}

async function bindSeedling() {
  const sid = seedlingId.value
  if (!sid) return true // nothing to do
  try {
    const r = await fetch('/api/seedlings/bind', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      credentials: 'include',
      body: JSON.stringify({ seedling_id: sid, sk: seedlingSk.value || undefined })
    })
    if (!r.ok) return false
    return true
  } catch (_) { return false }
}

function parseSeedlingId() {
  try {
    // support both history query and hash query (?sid=...)
    const sidQ = route.query.sid || ''
    if (sidQ) { seedlingId.value = String(sidQ) }
    const skQ = route.query.sk || ''
    if (skQ) { seedlingSk.value = String(skQ) }
    const hash = window.location.hash || ''
    if (hash.includes('?')) {
      const params = new URLSearchParams(hash.split('?')[1])
      const sidH = params.get('sid')
      const skH = params.get('sk')
      if (!seedlingId.value && sidH) seedlingId.value = String(sidH)
      if (!seedlingSk.value && skH) seedlingSk.value = String(skH)
    }
  } catch (_) {}
}

watch(isAuthed, async (ok) => {
  if (!ok) return
  closeLogin()
  const bound = await bindSeedling()
  // Short success delay then go to requested return path or home
  setTimeout(() => { router.replace(returnPath.value || '/') }, 800)
})

onMounted(async () => {
  parseSeedlingId()
  await auth.fetchSession()
  if (!isAuthed.value) openLogin()
  else {
    const bound = await bindSeedling()
    setTimeout(() => { router.replace(returnPath.value || '/') }, 800)
  }
})
</script>

<style scoped>
</style>
