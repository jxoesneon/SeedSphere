<template>
  <div class="relative" @keydown.esc="closeAll">
    <!-- Account/Login button -->
    <button class="btn btn-sm" @click="toggleMenu" :aria-expanded="open ? 'true' : 'false'">
      <span v-if="!user">Login</span>
      <span v-else class="inline-flex items-center gap-2">
        <span class="i-ph-user-circle text-xl" aria-hidden="true"></span>
        <span>{{ userLabel }}</span>
      </span>
    </button>

    <!-- Dropdown when logged in -->
    <div v-if="open && user" class="menu menu-sm dropdown-content mt-2 p-2 shadow bg-base-200 rounded-box absolute right-0 z-20 w-48">
      <button class="btn btn-ghost btn-sm justify-start" @click="goConfigure">Manage account</button>
      <button class="btn btn-ghost btn-sm justify-start" @click="doLogout">Log out</button>
    </div>

    <!-- Modal for login methods -->
    <dialog ref="dlg" class="modal">
      <div class="modal-box">
        <h3 class="font-bold text-lg mb-4">Sign in to SeedSphere</h3>
        <!-- Toast -->
        <div v-if="toastMsg" class="toast toast-top toast-end z-20">
          <div class="alert" :class="toastType">{{ toastMsg }}</div>
        </div>
        <!-- Magic Link FIRST -->
        <div class="card bg-base-200 mb-4">
          <div class="card-body p-3 gap-2">
            <div class="text-sm">Magic link</div>
            <input v-model="email" type="email" class="input input-bordered input-sm" placeholder="you@example.com" />
            <button class="btn btn-sm" :disabled="sending" @click="sendMagic">
              <span v-if="!sending">Send link</span>
              <span v-else class="loading loading-spinner loading-sm"></span>
            </button>
            <p v-if="notice" class="text-xs opacity-70">{{ notice }}</p>
          </div>
        </div>

        <!-- Divider -->
        <div class="divider my-2">or continue with</div>

        <!-- Provider buttons, one per line -->
        <div class="flex flex-col gap-2 mt-2">
          <button class="btn btn-outline justify-start" @click="start('google')">
            <img src="https://www.gstatic.com/firebasejs/ui/2.0.0/images/auth/google.svg" alt="Google" class="h-5 w-5 mr-2" />
            Continue with Google
          </button>
        </div>

        <div class="modal-action">
          <button class="btn" @click="closeModal">Close</button>
        </div>
      </div>
      <form method="dialog" class="modal-backdrop" @click="closeModal">
        <button>close</button>
      </form>
    </dialog>
  </div>
</template>

<script setup>
import { ref, computed, onMounted, watch } from 'vue'
import { useRouter } from 'vue-router'
import { auth } from '../lib/auth'

const router = useRouter()
const open = ref(false)
const email = ref('')
const sending = ref(false)
const notice = ref('')
const dlg = ref(null)
const toastMsg = ref('')
const toastType = ref('alert-info')

const user = computed(() => auth.state.user)
const userLabel = computed(() => auth.parseUserLabel(user.value))

function toggleMenu() {
  if (user.value) {
    open.value = !open.value
  } else {
    open.value = false
    openModal()
  }
}

function openModal() {
  try { dlg.value?.showModal() } catch (_) {}
}
function closeModal() {
  try { dlg.value?.close() } catch (_) {}
}
function closeAll() { open.value = false; closeModal() }

function start(provider) {
  auth.loginWith(provider)
}

async function sendMagic() {
  const e = email.value.trim().toLowerCase()
  if (!e) { notice.value = 'Enter a valid email'; return }
  sending.value = true
  notice.value = ''
  console.info('[ui] magic_start_click', { email: e })
  const ok = await auth.startMagic(e)
  sending.value = false
  if (ok) {
    notice.value = 'Check your email for the sign-in link'
    toastType.value = 'alert-success'
    toastMsg.value = 'Magic link sent'
    setTimeout(() => { toastMsg.value = '' }, 3000)
  } else {
    notice.value = 'Could not send link'
    toastType.value = 'alert-error'
    toastMsg.value = 'Failed to send magic link'
    setTimeout(() => { toastMsg.value = '' }, 3000)
  }
}

async function doLogout() {
  await auth.logout()
  open.value = false
  // Refresh session state
  await auth.fetchSession()
}

function goConfigure() {
  open.value = false
  router.push('/configure')
}

onMounted(() => {
  // Close dropdown when clicking outside
  document.addEventListener('click', (e) => {
    if (!open.value) return
    const el = e.target
    if (!el) return
    const root = el.closest?.('.dropdown-content')
    const btn = el.closest?.('button')
    if (!root && !btn) open.value = false
  })
})

watch(() => router.currentRoute.value.fullPath, () => { open.value = false })
</script>

<style scoped>
/**** icons rely on existing styles; no extra CSS ****/
</style>
