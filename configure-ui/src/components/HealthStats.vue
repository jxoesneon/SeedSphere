<script setup>
import { ref } from 'vue'

const output = ref('')

async function loadHealth() {
  output.value = 'Loading health stats...'
  try {
    const resp = await fetch('/api/trackers/health')
    if (!resp.ok) throw new Error('HTTP ' + resp.status)
    const data = await resp.json()
    output.value = JSON.stringify(data, null, 2)
  } catch (e) {
    output.value = 'Failed to fetch health stats: ' + (e && e.message ? e.message : String(e))
  }
}
</script>

<template>
  <div class="grid gap-3">
    <div class="flex gap-2">
      <button class="btn" @click="loadHealth">Load Health</button>
    </div>
    <pre class="mockup-code whitespace-pre-wrap text-left"><code>{{ output }}</code></pre>
  </div>
</template>
