import { reactive, readonly } from 'vue'

function genId() {
  try {
    if (crypto && crypto.getRandomValues) {
      const arr = new Uint8Array(8); crypto.getRandomValues(arr)
      return 'g-' + Array.from(arr).map(b => b.toString(16).padStart(2, '0')).join('')
    }
  } catch (_) {}
  return 'g-' + Math.random().toString(36).slice(2, 10)
}

const state = reactive({ gardener_id: '' })

function load() {
  try {
    const v = localStorage.getItem('gardener_id')
    if (v && typeof v === 'string' && v.length >= 6) state.gardener_id = v
  } catch (_) {}
  if (!state.gardener_id) {
    state.gardener_id = genId()
    try { localStorage.setItem('gardener_id', state.gardener_id) } catch (_) {}
  }
}

function setGardenerId(id) {
  const v = String(id || '').trim()
  if (!v) return false
  state.gardener_id = v
  try { localStorage.setItem('gardener_id', v) } catch (_) {}
  return true
}

function getGardenerId() { return state.gardener_id }

load()

export const gardener = { state: readonly(state), getGardenerId, setGardenerId }
