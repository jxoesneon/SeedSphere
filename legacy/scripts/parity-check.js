#!/usr/bin/env node
/*
  Temp parity check script for SeedSphere
  Verifies core API endpoints and basic behaviors on http://localhost:5173
*/

const BASE = process.env.BASE_URL || 'http://localhost:5173'

async function checkJson(path, validator) {
  const url = new URL(path, BASE)
  const res = await fetch(url, { cache: 'no-store' })
  if (!res.ok) throw new Error(`${path} -> HTTP ${res.status}`)
  const data = await res.json()
  if (validator) validator(data)
  return { ok: true, data }
}

async function checkSSEHeaders(path) {
  const url = new URL(path, BASE)
  const res = await fetch(url, { method: 'GET' })
  if (!res.ok) throw new Error(`${path} -> HTTP ${res.status}`)
  const ct = res.headers.get('content-type') || ''
  if (!ct.includes('text/event-stream')) {
    throw new Error(`${path} -> unexpected content-type: ${ct}`)
  }
  // We won't keep the connection open; this just validates headers.
  return { ok: true, contentType: ct }
}

function assertTruthy(cond, msg) {
  if (!cond) throw new Error(msg)
}

async function main() {
  const results = []
  try {
    // manifest
    results.push(['manifest.json', await checkJson('/manifest.json', (m) => {
      assertTruthy(typeof m.name === 'string' && m.name.length > 0, 'manifest.name missing')
      assertTruthy(typeof m.version === 'string' && m.version.length > 0, 'manifest.version missing')
    })])

    // health
    results.push(['health', await checkJson('/health', (h) => {
      assertTruthy(h && h.ok === true, 'health.ok !== true')
    })])

    // recent boosts
    results.push(['boosts/recent', await checkJson('/api/boosts/recent', (b) => {
      assertTruthy(Array.isArray(b.items), 'recent.items not array')
    })])

    // trackers health stats (structure only)
    results.push(['trackers/health', await checkJson('/api/trackers/health', (stats) => {
      assertTruthy(typeof stats === 'object' && stats !== null, 'health stats not object')
    })])

    // SSE endpoint header check
    results.push(['boosts/events (SSE)', await checkSSEHeaders('/api/boosts/events')])

    // Print summary
    console.log('Parity checks passed:')
    for (const [name, r] of results) {
      console.log(` - ${name}: OK`)
    }
    process.exit(0)
  } catch (e) {
    console.error('Parity check failed:', e && e.stack ? e.stack : e)
    process.exit(1)
  }
}

main()
