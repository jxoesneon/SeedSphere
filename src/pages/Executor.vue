<script setup>
import { ref } from 'vue'

const type = ref('movie')
const id = ref('tt1254207')
const result = ref(null)
const error = ref('')
const forceFallback = ref(false)

async function run() {
  error.value = ''
  result.value = null
  try {
    const filters = forceFallback.value
      ? {
          providers_torrentio: 'off', providers_yts: 'off', providers_eztv: 'off', providers_nyaa: 'off',
          providers_1337x: 'off', providers_piratebay: 'off', providers_torrentgalaxy: 'off', providers_torlock: 'off',
          providers_magnetdl: 'off', providers_anidex: 'off', providers_tokyotosho: 'off', providers_zooqle: 'off', providers_rutor: 'off',
          provider_fetch_timeout_ms: 1, probe_providers: 'on', probe_timeout_ms: 1,
        }
      : { providers_torrentio: 'on' }
    const res = await fetch(`/api/stream/${encodeURIComponent(type.value)}/${encodeURIComponent(id.value)}`, {
      method: 'POST', headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ filters }),
    })
    const data = await res.json()
    if (!res.ok) throw new Error(data?.error || 'executor_failed')
    result.value = data
  } catch (e) { error.value = e?.message || 'executor_failed' }
}
</script>

<template>
  <div class="container mx-auto p-4">
    <h1 class="text-2xl font-semibold mb-4">Executor</h1>
    <div class="flex flex-wrap gap-2 mb-3">
      <select v-model="type" class="select select-bordered tooltip" data-tip="Select content type">
        <option value="movie">movie</option>
        <option value="series">series</option>
      </select>
      <input v-model="id" class="input input-bordered flex-1 min-w-[12rem] tooltip" placeholder="IMDb id (e.g., tt1254207)" data-tip="Media identifier (e.g., IMDb id)" />
      <button class="btn btn-primary tooltip" data-tip="Execute request with current inputs" @click="run">Run</button>
    </div>
    <div class="flex items-center gap-2 mb-2">
      <input id="force-fallback" type="checkbox" class="toggle toggle-warning" v-model="forceFallback" />
      <label for="force-fallback" class="text-sm">Force fallback (disable providers and set tiny timeouts)</label>
    </div>
    <div v-if="error" class="text-error mb-2">{{ error }}</div>
    <pre v-if="result" class="bg-base-200 p-3 rounded text-xs overflow-auto max-w-full">{{ result }}</pre>
    <div v-if="result && Array.isArray(result.streams)" class="mt-3 overflow-x-auto">
      <table class="table table-zebra table-sm">
        <thead>
          <tr><th>Title</th><th>Provider</th></tr>
        </thead>
        <tbody>
          <tr v-for="(s, i) in result.streams" :key="i">
            <td>{{ s.title }}</td>
            <td>{{ s.provider || 'SeedSphere' }}</td>
          </tr>
          <tr v-if="result.streams.length===0"><td colspan="2" class="opacity-60">No streams</td></tr>
        </tbody>
      </table>
    </div>
  </div>
</template>
