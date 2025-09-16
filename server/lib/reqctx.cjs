'use strict'

const { AsyncLocalStorage } = require('async_hooks')

const storage = new AsyncLocalStorage()

function run(ctx, fn) {
  return storage.run(ctx || {}, fn)
}

function get() {
  try { return storage.getStore() || {} } catch (_) { return {} }
}

function getSeedlingId() {
  try { const s = storage.getStore(); return s && s.seedling_id ? String(s.seedling_id) : '' } catch (_) { return '' }
}

module.exports = { run, get, getSeedlingId }
