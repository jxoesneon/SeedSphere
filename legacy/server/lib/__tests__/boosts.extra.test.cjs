'use strict'

const assert = require('node:assert')
const http = require('node:http')
const { test } = require('node:test')

const boosts = require('../boosts.cjs')

async function startServer() {
  const { createServer } = await import('../../index.js')
  const server = await createServer({ port: 0, disableVite: true, disablePrefetch: true })
  const addr = server.address()
  const baseURL = `http://127.0.0.1:${addr.port}`
  return { server, baseURL }
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

function httpGet(url) {
  return new Promise((resolve, reject) => {
    http.get(url, (res) => {
      const chunks = []
      res.on('data', (c) => chunks.push(c))
      res.on('end', () => {
        let body = Buffer.concat(chunks).toString('utf8')
        try { body = JSON.parse(body) } catch (_) { /* leave as string */ }
        resolve({ statusCode: res.statusCode || 0, body })
      })
    }).on('error', reject)
  })
}

// recent endpoint returns max 20 items, latest-first ordering
test('recent endpoint cap=20 and latest-first ordering', async () => {
  boosts.__resetForTests()
  for (let i = 0; i < 25; i++) boosts.push({ id: `http-${i}`, type: 'movie' })
  const { server, baseURL } = await startServer()
  try {
    const r = await httpGet(`${baseURL}/api/boosts/recent`)
    assert.equal(r.statusCode, 200)
    assert.equal(r.body.ok, true)
    const items = r.body.items || []
    assert.equal(items.length, 20)
    assert.equal(items[0].id, 'http-24')
    assert.equal(items.at(-1).id, 'http-5')
  } finally {
    await new Promise((r) => server.close(r))
  }
})

// Snapshot should contain items pushed before connection
test('SSE snapshot includes pre-pushed boost', async () => {
  boosts.__resetForTests()
  const preId = 'pre-boost-1'
  boosts.push({ id: preId, type: 'movie', title: 'Pre' })
  const { server, baseURL } = await startServer()
  try {
    await new Promise((resolve, reject) => {
      const req = connectSSE(`${baseURL}/api/boosts/events`, ({ event, data }) => {
        if (event === 'snapshot') {
          try {
            assert.ok(data && Array.isArray(data.items))
            const hasPre = data.items.some((it) => it && it.id === preId)
            assert.equal(hasPre, true)
            resolve()
            try { req.destroy() } catch (_) {}
          } catch (e) { reject(e) }
        }
      })
    })
  } finally {
    await new Promise((r) => server.close(r))
  }
})

// Should emit initial server-info event with version string
test('SSE emits initial server-info', async () => {
  boosts.__resetForTests()
  const { server, baseURL } = await startServer()
  try {
    await new Promise((resolve, reject) => {
      const req = connectSSE(`${baseURL}/api/boosts/events`, ({ event, data }) => {
        if (event === 'server-info') {
          try {
            assert.ok(data && typeof data.version === 'string')
            resolve()
            try { req.destroy() } catch (_) {}
          } catch (e) { reject(e) }
        }
      })
    })
  } finally {
    await new Promise((r) => server.close(r))
  }
})

// After 120 calls in a minute window, recent endpoint should rate limit
test('recent endpoint rate limits after 120 in window', async () => {
  boosts.__resetForTests()
  const { server, baseURL } = await startServer()
  try {
    for (let i = 0; i < 120; i++) {
      const r = await httpGet(`${baseURL}/api/boosts/recent`)
      assert.equal(r.statusCode, 200)
      assert.equal(r.body.ok, true)
    }
    const r2 = await httpGet(`${baseURL}/api/boosts/recent`)
    assert.equal(r2.statusCode, 429)
  } finally {
    await new Promise((r) => server.close(r))
  }
})
