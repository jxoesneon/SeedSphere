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

function parseSessCookie(setCookieHeader) {
  if (!setCookieHeader) return null
  const parts = String(setCookieHeader).split(/,\s*(?=[^;]+=)/) // split multiple Set-Cookie
  for (const p of parts) {
    const m = /\bss_sess=([^;]+)/.exec(p)
    if (m) return m[1]
  }
  return null
}

async function devLogin(baseURL, email = 'dev+inttest@example.com') {
  // Get magic callback link
  const r1 = await fetch(`${baseURL}/api/auth/dev/magic?email=${encodeURIComponent(email)}`)
  assert.strictEqual(r1.ok, true, 'dev magic endpoint should return ok')
  const j1 = await r1.json()
  assert.ok(j1 && j1.ok && j1.link, 'dev magic response must include link')
  // Call magic callback to set the session cookie, but do not auto-follow redirects to capture Set-Cookie
  const r2 = await fetch(j1.link, { redirect: 'manual' })
  assert.ok([302, 303].includes(r2.status), 'magic callback should redirect')
  const setCookie = r2.headers.get('set-cookie')
  assert.ok(setCookie && setCookie.includes('ss_sess='), 'Set-Cookie with ss_sess must be present')
  const sid = parseSessCookie(setCookie)
  assert.ok(sid && sid.length > 0, 'parsed ss_sess value should be present')
  return sid
}

async function mintSeedling(baseURL, sidCookie) {
  const r = await fetch(`${baseURL}/api/seedlings`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', 'Cookie': `ss_sess=${sidCookie}` },
  })
  assert.ok(r.ok, 'mint should succeed')
  const j = await r.json()
  assert.ok(j && j.ok && j.seedling_id, 'mint must return seedling_id')
  return j.seedling_id
}

async function listSeedlings(baseURL, sidCookie) {
  const r = await fetch(`${baseURL}/api/seedlings`, {
    headers: { 'Accept': 'application/json', 'Cookie': `ss_sess=${sidCookie}` },
    cache: 'no-store',
  })
  assert.ok(r.ok || r.status === 401, 'list should return ok or 401')
  if (r.status === 401) return []
  const j = await r.json()
  assert.ok(j && j.ok && Array.isArray(j.seedlings), 'list should return seedlings array')
  return j.seedlings
}

test('account seedlings list includes newly minted seedling for logged-in user', async (t) => {
  const { server, baseURL } = await startServer()
  t.after(() => { try { server && server.close() } catch (_) {} })

  const sid = await devLogin(baseURL)
  const created = await mintSeedling(baseURL, sid)
  const list = await listSeedlings(baseURL, sid)

  assert.ok(Array.isArray(list) && list.length > 0, 'list should contain at least one item')
  const found = list.some((s) => String(s.install_id || '') === String(created))
  assert.ok(found, 'newly minted seedling should appear in account list')
})
