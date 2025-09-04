'use strict'

const assert = require('node:assert')
const http = require('node:http')
const { once } = require('node:events')
const { test } = require('node:test')

const boosts = require('../boosts.cjs')

async function startServer() {
  const { createServer } = await import('../../index.js')
  const server = await createServer({ port: 0, disableVite: true, disablePrefetch: true })
  const addr = server.address()
  const baseURL = `http://127.0.0.1:${addr.port}`
  return { server, baseURL }
}

function httpGetJSON(url) {
  return new Promise((resolve, reject) => {
    http.get(url, (res) => {
      const chunks = []
      res.on('data', (c) => chunks.push(c))
      res.on('end', () => {
        try { resolve(JSON.parse(Buffer.concat(chunks).toString('utf8'))) } catch (e) { reject(e) }
      })
    }).on('error', reject)
  })
}

function connectSSE(url, onEvent) {
  const req = http.get(url, { headers: { Accept: 'text/event-stream' } }, (res) => {
    let buf = ''
    res.setEncoding('utf8')
    res.on('data', (chunk) => {
      buf += chunk
      let idx
      while ((idx = buf.indexOf('\n\n')) !== -1) {
        const block = buf.slice(0, idx)
        buf = buf.slice(idx + 2)
        const lines = block.split('\n')
        let event = ''
        let data = ''
        for (const ln of lines) {
          if (ln.startsWith('event:')) event = ln.slice(6).trim()
          else if (ln.startsWith('data:')) data += (data ? '\n' : '') + ln.slice(5).trim()
        }
        if (!event) event = 'message'
        let parsed
        try { parsed = data ? JSON.parse(data) : null } catch (_) { parsed = null }
        try { onEvent && onEvent({ event, data: parsed }) } catch (_) {}
      }
    })
  })
  return req
}

test('GET /api/boosts/recent returns ok with items array', async () => {
  boosts.__resetForTests()
  const { server, baseURL } = await startServer()
  try {
    const json = await httpGetJSON(`${baseURL}/api/boosts/recent`)
    assert.equal(json.ok, true)
    assert.ok(Array.isArray(json.items))
  } finally {
    await new Promise((r) => server.close(r))
  }
})

test('SSE /api/boosts/events emits snapshot then boost on push', async () => {
  boosts.__resetForTests()
  const { server, baseURL } = await startServer()
  try {
    let snapshotSeen = false
    let boostSeen = false
    const boostId = 'sse-test-1'

    const snapshotPromise = new Promise((resolve) => {
      const req = connectSSE(`${baseURL}/api/boosts/events`, ({ event, data }) => {
        if (event === 'snapshot') {
          snapshotSeen = true
          assert.ok(data && Array.isArray(data.items))
        }
        if (event === 'boost' && data && data.id === boostId) {
          boostSeen = true
          resolve()
          try { req.destroy() } catch (_) {}
        }
      })
    })

    // Wait for connection to establish and first events
    await new Promise((r) => setTimeout(r, 200))

    // Trigger a boost event
    boosts.push({ id: boostId, type: 'movie', title: 'Test' })

    const timeout = new Promise((_, rej) => setTimeout(() => rej(new Error('timeout')), 8000))
    await Promise.race([snapshotPromise, timeout])

    assert.equal(snapshotSeen, true)
    assert.equal(boostSeen, true)
  } finally {
    await new Promise((r) => server.close(r))
  }
})
