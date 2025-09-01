import { reactive, readonly } from 'vue'

const state = reactive({
  user: null,
  loading: false,
  error: '',
})

function providerStartUrl(provider) {
  return `/api/auth/${provider}/start`
}

async function fetchSession() {
  state.loading = true
  state.error = ''
  try {
    const res = await fetch('/api/auth/session', { credentials: 'include', cache: 'no-store' })
    if (!res.ok) throw new Error(`session_http_${res.status}`)
    const data = await res.json()
    state.user = data && data.user ? data.user : null
  } catch (e) {
    state.error = e && e.message ? e.message : 'session_failed'
  } finally {
    state.loading = false
  }
}

function loginWith(provider) {
  const url = providerStartUrl(provider)
  try { window.location.href = url } catch (_) {}
}

async function startMagic(email) {
  state.error = ''
  try {
    console.info('[auth] magic_start_request', { email })
    const res = await fetch('/api/auth/magic/start', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ email }),
    })
    if (!res.ok) {
      console.error('[auth] magic_start_http_error', { status: res.status })
      throw new Error('magic_start_failed')
    }
    const data = await res.json()
    console.info('[auth] magic_start_response', { ok: data?.ok === true })
    if (!data || !data.ok) throw new Error('magic_start_failed')
    return true
  } catch (e) {
    console.error('[auth] magic_start_exception', { message: e?.message || String(e) })
    state.error = e && e.message ? e.message : 'magic_start_failed'
    return false
  }
}

async function logout() {
  try {
    await fetch('/api/auth/logout', { method: 'POST', credentials: 'include' })
  } catch (_) {}
  state.user = null
}

function parseUserLabel(u) {
  if (!u || !u.id) return 'Account'
  if (u.email && String(u.email).trim().length > 0) return u.email
  const id = String(u.id)
  const [prov, rest] = id.split(':', 2)
  if (prov === 'magic') return rest || 'magic user'
  return `${prov}`
}

function stripLoginOkParam() {
  try {
    const url = new URL(window.location.href)
    // support both query and hash query (/#/configure?login=ok)
    if (url.searchParams.has('login')) {
      url.searchParams.delete('login')
      window.history.replaceState({}, '', url.toString())
      return
    }
    if (url.hash && url.hash.includes('?')) {
      const [hashPath, hashQuery] = url.hash.split('?', 2)
      const params = new URLSearchParams(hashQuery)
      if (params.has('login')) {
        params.delete('login')
        const newHash = `${hashPath}${params.toString() ? '?' + params.toString() : ''}`
        const clean = url.origin + url.pathname + url.search + newHash
        window.history.replaceState({}, '', clean)
      }
    }
  } catch (_) {}
}

async function initAuth() {
  // If login=ok present, fetch session then clean param
  try {
    const href = window.location.href
    if (href.includes('login=ok')) {
      await fetchSession()
      stripLoginOkParam()
      // In rare cases, cookie propagation can lag in some environments. Re-fetch shortly after.
      try { setTimeout(() => { fetchSession() }, 500) } catch (_) {}
      return
    }
  } catch (_) {}
  await fetchSession()
}

export const auth = {
  state: readonly(state),
  fetchSession,
  loginWith,
  startMagic,
  logout,
  initAuth,
  parseUserLabel,
}
