'use strict'

const assert = require('node:assert')
const { test, describe } = require('node:test')

// Import provider modules
const torrentio = require('../../providers/torrentio.cjs')
const yts = require('../../providers/yts.cjs')
const eztv = require('../../providers/eztv.cjs')
const nyaa = require('../../providers/nyaa.cjs')
const x1337 = require('../../providers/x1337.cjs')
const piratebay = require('../../providers/piratebay.cjs')
const torrentgalaxy = require('../../providers/torrentgalaxy.cjs')
const torlock = require('../../providers/torlock.cjs')
const magnetdl = require('../../providers/magnetdl.cjs')
const anidex = require('../../providers/anidex.cjs')
const tokyotosho = require('../../providers/tokyotosho.cjs')
const zooqle = require('../../providers/zooqle.cjs')
const rutor = require('../../providers/rutor.cjs')

const providers = [
  torrentio, yts, eztv, nyaa, x1337, piratebay,
  torrentgalaxy, torlock, magnetdl, anidex, tokyotosho, zooqle, rutor,
]

function hasShape(res) {
  return res && typeof res === 'object' && typeof res.ok === 'boolean' &&
    typeof res.provider === 'string' && Array.isArray(res.streams)
}

describe('providers return standardized result shape', () => {
  for (const p of providers) {
    test(`provider ${p.name} returns { ok, provider, streams[] } and error on failure`, async (t) => {
      // Force a very small timeout to provoke quick failure where applicable.
      let res
      try { res = await p.fetchStreams('movie', 'tt0000001', 1) } catch (e) { res = { ok: false, provider: p.name, streams: [], error: e && e.message } }
      assert.ok(hasShape(res), `result shape invalid for ${p.name}`)
      assert.strictEqual(res.provider, p.name, `provider field mismatch for ${p.name}`)
      if (res.ok === false) {
        assert.ok(typeof res.error === 'string' && res.error.length > 0, `missing error message for ${p.name}`)
      } else {
        assert.ok(Array.isArray(res.streams), `streams should be an array for ${p.name}`)
      }
    })
  }
})

// Basic normalization test via aggregator with a fake provider
const { aggregateStreams } = require('../aggregate.cjs')

test('aggregate standardizes upstream stream fields', async () => {
  const fake = {
    name: 'FakeUp',
    async fetchStreams() {
      return {
        ok: true, provider: 'FakeUp', streams: [
          { title: 'Title Only' },
          { provider: 'X', url: 'magnet:?xt=urn:btih:ABC', behaviorHints: { bingeGroup: 'g' } },
          { provider: 'X', infoHash: 'abc123' },
          { provider: 'X', seeds: '10', leechers: '2', size: 1024, sizeBytes: '2048', language: 'en' },
        ]
      }
    }
  }
  const streams = await aggregateStreams({ type: 'movie', id: 'tt0000001', providers: [fake], trackers: [] })
  // Dedup preserves at least one
  assert.ok(streams.length >= 1)
  for (const s of streams) {
    // Provider field is not required in final aggregated stream; name/label + title are.
    assert.ok(typeof s.title === 'string', 'stream.title must be a string')
    assert.ok(s.behaviorHints && typeof s.behaviorHints === 'object', 'stream.behaviorHints must be an object')
    assert.ok('seeds' in s)
    assert.ok('leechers' in s)
    assert.ok('size' in s)
    assert.ok('sizeBytes' in s)
    assert.ok(Array.isArray(s.languages))
  }
})
