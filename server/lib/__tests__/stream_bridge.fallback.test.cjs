'use strict'

const assert = require('node:assert')
const { test } = require('node:test')

async function startServer() {
  const { createServer } = await import('../../index.js')
  const server = await createServer({ port: 0, disableVite: true, disablePrefetch: true })
  const addr = server.address()
  const baseURL = `http://127.0.0.1:${addr.port}`
  return { server, baseURL }
}

async function stopServer(server) {
  await new Promise((resolve) => server.close(resolve))
}

async function postJson(url, body, headers = {}) {
  const res = await fetch(url, { method: 'POST', headers: { 'Content-Type': 'application/json', Connection: 'close', ...headers }, body: JSON.stringify(body || {}) })
  const text = await res.text()
  try { return { status: res.status, json: JSON.parse(text) } } catch { return { status: res.status, text } }
}

test('bridge returns informative stream when identities are missing', { timeout: 15000 }, async () => {
  const { server, baseURL } = await startServer()
  try {
    const { status, json } = await postJson(`${baseURL}/api/stream/movie/tt0000001`, { filters: {} })
    assert.equal(status, 200)
    assert.ok(json && Array.isArray(json.streams) && json.streams.length === 1)
    const s = json.streams[0]
    assert.ok(typeof s.title === 'string' && /Sign-in required|Missing identities/i.test(s.title + ' ' + (s.description || '')))
  } finally {
    await stopServer(server)
  }
})

test('bridge returns informative stream when there is no binding', { timeout: 15000 }, async () => {
  const { server, baseURL } = await startServer()
  try {
    const headers = { 'X-SeedSphere-G': 'g-unknown', 'X-SeedSphere-Id': 's-unknown', 'X-SeedSphere-Ts': Date.now().toString(), 'X-SeedSphere-Nonce': 'n' }
    const { status, json } = await postJson(`${baseURL}/api/stream/movie/tt0000002`, { filters: {} }, headers)
    assert.equal(status, 200)
    assert.ok(Array.isArray(json.streams) && json.streams.length === 1)
    const s = json.streams[0]
    assert.ok(/Installation not linked|No binding/i.test(s.title + ' ' + (s.description || '')))
  } finally {
    await stopServer(server)
  }
})
