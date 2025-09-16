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

async function getJson(url) {
  const res = await fetch(url, { method: 'GET' })
  const text = await res.text()
  try { return { status: res.status, json: JSON.parse(text) } } catch { return { status: res.status, text } }
}

test('SDK validator returns informative stream when installation missing', async () => {
  const { server, baseURL } = await startServer()
  try {
    const seedling = 'seed_missing'
    const sk = 'a' // any base64url-ish string
    const { status, json } = await getJson(`${baseURL}/s/${encodeURIComponent(seedling)}/${encodeURIComponent(sk)}/stream/movie/tt0000001.json`)
    assert.equal(status, 200)
    assert.ok(Array.isArray(json.streams) && json.streams.length === 1)
    const s = json.streams[0]
    assert.ok(/Installation not linked|account|binding/i.test(s.title + ' ' + (s.description || '')))
  } finally {
    await stopServer(server)
  }
})

test('SDK validator returns informative stream when installation is revoked', async () => {
  const { server, baseURL } = await startServer()
  const db = require('../db.cjs')
  try {
    const seedling = 'seed_revoked'
    db.upsertInstallation({ install_id: seedling, user_id: null, platform: 'test' })
    db.setInstallationStatus(seedling, 'revoked')
    const sk = 'a'
    const { status, json } = await getJson(`${baseURL}/s/${encodeURIComponent(seedling)}/${encodeURIComponent(sk)}/stream/movie/tt0000002.json`)
    assert.equal(status, 200)
    assert.ok(Array.isArray(json.streams) && json.streams.length === 1)
    const s = json.streams[0]
    assert.ok(/Installation revoked|revoked/i.test(s.title + ' ' + (s.description || '')))
  } finally {
    await stopServer(server)
  }
})

test('SDK validator returns informative stream on invalid signature', async () => {
  const { server, baseURL } = await startServer()
  const db = require('../db.cjs')
  try {
    const seedling = 'seed_bad_sig'
    db.upsertInstallation({ install_id: seedling, user_id: null, platform: 'test' })
    // Set a salt + key hash that won't match the provided sk
    const salt = Buffer.from('cafebabe', 'hex')
    const badHash = '0'.repeat(64)
    db.setInstallationSecret(seedling, salt, badHash)
    const sk = 'a' // will not match key_hash
    const { status, json } = await getJson(`${baseURL}/s/${encodeURIComponent(seedling)}/${encodeURIComponent(sk)}/stream/movie/tt0000003.json`)
    assert.equal(status, 200)
    assert.ok(Array.isArray(json.streams) && json.streams.length === 1)
    const s = json.streams[0]
    assert.ok(/Link invalid|signature/i.test(s.title + ' ' + (s.description || '')))
  } finally {
    await stopServer(server)
  }
})
