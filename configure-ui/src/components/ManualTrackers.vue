<script setup>
import { ref, onMounted, watch } from 'vue'

// LocalStorage keys from legacy UI
const MANUAL_KEY = 'seedsphere.manual_trackers'
const AUTOSAVE_KEY = 'seedsphere.manual_autosave'

// State
const items = ref([])            // in-memory editing list
const newValue = ref('')
const editing = ref(null)        // index being edited or null
const autosave = ref(false)

function isValidTracker(str) {
  return /^(udp|http|https|ws):\/\//i.test(String(str || '').trim())
}

function loadManual() {
  try {
    const raw = localStorage.getItem(MANUAL_KEY)
    const arr = raw ? JSON.parse(raw) : []
    items.value = Array.isArray(arr) ? arr.map((s) => String(s)) : []
  } catch (_) {
    items.value = []
  }
}
function saveManual() {
  try { localStorage.setItem(MANUAL_KEY, JSON.stringify(items.value)) } catch (_) {}
}

function addNew() {
  const v = String(newValue.value || '').trim()
  if (!v || !isValidTracker(v)) return
  if (!items.value.includes(v)) items.value.push(v)
  newValue.value = ''
  if (autosave.value) saveManual()
}
function startEdit(idx) { editing.value = idx }
function commitEdit(idx, val) {
  const v = String(val || '').trim()
  if (!v || !isValidTracker(v)) return
  items.value[idx] = v
  editing.value = null
  if (autosave.value) saveManual()
}
function deleteRow(idx) {
  items.value.splice(idx, 1)
  if (autosave.value) saveManual()
}
function revertAll() { loadManual() }
function saveAll() { saveManual() }

function exportTxt() {
  const blob = new Blob([(items.value.join('\n') + '\n')], { type: 'text/plain;charset=utf-8' })
  const url = URL.createObjectURL(blob)
  const a = document.createElement('a')
  a.href = url
  a.download = 'manual-trackers.txt'
  a.click()
  setTimeout(() => URL.revokeObjectURL(url), 1500)
}
async function importTxt() {
  const text = prompt('Paste trackers, one per line:')
  if (!text) return
  const lines = String(text).split('\n').map(s => s.trim()).filter(Boolean)
  const valids = Array.from(new Set(lines.filter(isValidTracker)))
  if (valids.length) {
    // merge unique
    const set = new Set(items.value)
    for (const v of valids) set.add(v)
    items.value = Array.from(set)
    if (autosave.value) saveManual()
  }
}

onMounted(() => {
  loadManual()
  try { autosave.value = (localStorage.getItem(AUTOSAVE_KEY) === '1') } catch (_) {}
})

watch(autosave, (v) => {
  try { localStorage.setItem(AUTOSAVE_KEY, v ? '1' : '0') } catch (_) {}
})
</script>

<template>
  <div class="grid gap-4">
    <div class="flex items-center gap-3">
      <input v-model="newValue" type="text" placeholder="udp://tracker:port or http(s)://..." class="input input-bordered w-full max-w-xl" @keyup.enter="addNew" />
      <button class="btn btn-primary" :disabled="!isValidTracker(newValue)" @click="addNew" title="Add">Add</button>
      <div class="form-control">
        <label class="label cursor-pointer gap-2">
          <span class="label-text">Auto-save</span>
          <input type="checkbox" class="toggle" v-model="autosave" />
        </label>
      </div>
    </div>

    <div class="overflow-x-auto">
      <table class="table table-zebra">
        <thead>
          <tr>
            <th class="w-12">#</th>
            <th>Tracker URL</th>
            <th class="w-40 text-center">Actions</th>
          </tr>
        </thead>
        <tbody>
          <tr v-if="items.length === 0">
            <td colspan="3" class="text-center opacity-70">No manual trackers yet</td>
          </tr>
          <tr v-for="(it, idx) in items" :key="idx">
            <td class="text-base-content/70">{{ idx + 1 }}</td>
            <td>
              <template v-if="editing === idx">
                <input :value="it" @keyup.enter="commitEdit(idx, $event.target.value)" class="input input-bordered w-full" />
              </template>
              <template v-else>
                <code class="break-all">{{ it }}</code>
              </template>
            </td>
            <td class="text-center">
              <div class="join justify-center">
                <button class="btn btn-sm join-item" v-if="editing !== idx" @click="startEdit(idx)" title="Edit">Edit</button>
                <button class="btn btn-sm btn-success join-item" v-else @click="commitEdit(idx, $event.target.closest('tr').querySelector('input').value)" title="Done">Done</button>
                <button class="btn btn-sm btn-error join-item" @click="deleteRow(idx)" title="Delete">Delete</button>
              </div>
            </td>
          </tr>
        </tbody>
        <tfoot>
          <tr>
            <th>#</th><th>Tracker URL</th><th class="text-center">Actions</th>
          </tr>
        </tfoot>
      </table>
    </div>

    <div class="flex flex-wrap gap-2">
      <button class="btn" @click="revertAll" title="Revert to last saved">Revert</button>
      <button class="btn btn-primary" @click="saveAll" title="Save changes">Save</button>
      <button class="btn" @click="importTxt" title="Import from pasted list">Import</button>
      <button class="btn" @click="exportTxt" title="Export to .txt">Export</button>
    </div>
  </div>
</template>

<style scoped>
code { word-break: break-word; }
</style>
