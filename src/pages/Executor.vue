<script setup>
import { ref } from 'vue'

const type = ref('movie')
const id = ref('tt1254207')
const result = ref(null)
const error = ref('')

async function run() {
  error.value = ''
  result.value = null
  try {
    const res = await fetch(`/api/stream/${encodeURIComponent(type.value)}/${encodeURIComponent(id.value)}`, {
      method: 'POST', headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ filters: { providers_torrentio: 'on' } }),
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
    <div v-if="error" class="text-error mb-2">{{ error }}</div>
    <pre v-if="result" class="bg-base-200 p-3 rounded text-xs overflow-auto max-w-full">{{ result }}</pre>
  </div>
</template>
