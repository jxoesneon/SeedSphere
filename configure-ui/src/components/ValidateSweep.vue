<script setup>
import { ref, onMounted, watch } from 'vue'

const url = ref('')
const variant = ref('all')
const mode = ref('basic')
const limitEnable = ref(false)
const maxTrackers = ref(0)

const validateResult = ref('')
const sweepResult = ref('')

const saving = (k, v) => { try { localStorage.setItem(k, v) } catch (_) {} }
const loading = (k, d='') => { try { return localStorage.getItem(k) ?? d } catch (_) { return d } }

onMounted(() => {
  url.value = loading('seedsphere.trackers_url', '')
  variant.value = loading('seedsphere.variant', 'all')
  mode.value = loading('seedsphere.validation_mode', 'basic')
  limitEnable.value = loading('seedsphere.limit_enable', '0') === '1'
  maxTrackers.value = parseInt(loading('seedsphere.max_trackers', '0'), 10) || 0
})

watch(url, v => saving('seedsphere.trackers_url', v))
watch(variant, v => saving('seedsphere.variant', v))
watch(mode, v => saving('seedsphere.validation_mode', v))
watch(limitEnable, v => saving('seedsphere.limit_enable', v ? '1' : '0'))
watch(maxTrackers, v => saving('seedsphere.max_trackers', String(v || 0)))

function variantToUrl(v) {
  const x = String(v || 'all').toLowerCase()
  switch (x) {
    case 'best': return 'https://raw.githubusercontent.com/ngosang/trackerslist/master/trackers_best.txt'
    case 'all_udp': return 'https://raw.githubusercontent.com/ngosang/trackerslist/master/trackers_all_udp.txt'
    case 'all_http': return 'https://raw.githubusercontent.com/ngosang/trackerslist/master/trackers_all_http.txt'
    case 'all_ws': return 'https://raw.githubusercontent.com/ngosang/trackerslist/master/trackers_all_ws.txt'
    case 'all_ip': return 'https://raw.githubusercontent.com/ngosang/trackerslist/master/trackers_all_ip.txt'
    case 'best_ip': return 'https://raw.githubusercontent.com/ngosang/trackerslist/master/trackers_best_ip.txt'
    case 'all':
    default: return 'https://raw.githubusercontent.com/ngosang/trackerslist/master/trackers_all.txt'
  }
}

async function doValidate() {
  validateResult.value = 'Validating...'
  try {
    const custom = (url.value || '').trim()
    const target = custom || variantToUrl(variant.value)
    const resp = await fetch(`/api/validate?url=${encodeURIComponent(target)}`)
    if (!resp.ok) throw new Error('HTTP ' + resp.status)
    const data = await resp.json()
    if (data.ok) {
      validateResult.value = `Looks like a trackers list. Found ${data.count} lines. Sample: ${(data.sample||[]).slice(0,3).join(' | ')}`
    } else {
      validateResult.value = `Not a trackers list. Error: ${data.error || 'unknown'}`
    }
  } catch (e) {
    validateResult.value = 'Validation failed: ' + (e && e.message ? e.message : String(e))
  }
}

async function doSweep() {
  sweepResult.value = 'Running sweep...'
  try {
    const custom = (url.value || '').trim()
    const target = custom || variantToUrl(variant.value)
    const enabled = !!limitEnable.value
    const limit = enabled ? Math.max(0, parseInt(String(maxTrackers.value||'0'), 10) || 0) : 0
    const qs = new URLSearchParams({ url: target, mode: String(mode.value||'basic'), limit: String(limit), full: '1' })
    const resp = await fetch('/api/trackers/sweep?' + qs.toString())
    if (!resp.ok) throw new Error('HTTP ' + resp.status)
    const data = await resp.json()
    if (!data.ok) throw new Error(data.error || 'sweep failed')
    const pct = data.total ? Math.round((data.healthy / data.total) * 100) : 0
    sweepResult.value = `Healthy: ${data.healthy}/${data.total} (${pct}%). Limit: ${limit>0?limit:'Unlimited'}.`
  } catch (e) {
    sweepResult.value = 'Sweep failed: ' + (e && e.message ? e.message : String(e))
  }
}
</script>

<template>
  <div class="grid gap-4">
    <div class="grid sm:grid-cols-2 gap-3">
      <div class="form-control">
        <label class="label"><span class="label-text">Custom URL</span></label>
        <input v-model="url" type="text" class="input input-bordered" placeholder="https://... (optional)" />
        <label class="label"><span class="label-text-alt">Leave blank to use the Variant URL</span></label>
      </div>
      <div class="form-control">
        <label class="label"><span class="label-text">Variant</span></label>
        <select v-model="variant" class="select select-bordered">
          <option value="all">All</option>
          <option value="best">Best</option>
          <option value="all_udp">All UDP</option>
          <option value="all_http">All HTTP</option>
          <option value="all_ws">All WS</option>
          <option value="all_ip">All IP</option>
          <option value="best_ip">Best IP</option>
        </select>
      </div>
    </div>

    <div class="grid sm:grid-cols-3 gap-3">
      <div class="form-control">
        <label class="label"><span class="label-text">Validation Mode</span></label>
        <select v-model="mode" class="select select-bordered">
          <option value="off">Off</option>
          <option value="basic">Basic</option>
          <option value="aggressive">Aggressive</option>
        </select>
      </div>
      <div class="form-control">
        <label class="label cursor-pointer justify-start gap-2">
          <input type="checkbox" v-model="limitEnable" class="toggle" />
          <span class="label-text">Limit results</span>
        </label>
      </div>
      <div class="form-control">
        <label class="label"><span class="label-text">Max trackers</span></label>
        <input type="number" class="input input-bordered" :disabled="!limitEnable" v-model.number="maxTrackers" min="0" />
      </div>
    </div>

    <div class="flex flex-wrap gap-2">
      <button class="btn" @click="doValidate">Validate</button>
      <button class="btn btn-primary" @click="doSweep">Run Sweep</button>
    </div>

    <div class="grid gap-2">
      <div class="alert"><span>{{ validateResult }}</span></div>
      <div class="alert"><span>{{ sweepResult }}</span></div>
    </div>
  </div>
</template>
