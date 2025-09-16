'use strict'

const assert = require('node:assert')
const { test } = require('node:test')

const { aggregateStreams } = require('../aggregate.cjs')

function fakeProviderOkEmpty(name = 'FakeOk') {
  return {
    name,
    async fetchStreams() { return { ok: true, provider: name, streams: [] } },
  }
}

function fakeProviderError(name = 'FakeErr') {
  return {
    name,
    async fetchStreams() { return { ok: false, provider: name, streams: [], error: 'boom' } },
  }
}

test('aggregateStreams returns informative stream when no providers enabled', async () => {
  const streams = await aggregateStreams({ type: 'movie', id: 'tt0000001', providers: [], trackers: [] })
  assert.ok(Array.isArray(streams) && streams.length === 1, 'should return exactly one informative stream')
  const s = streams[0]
  assert.ok(/No providers enabled/i.test(s.title), 'title should mention no providers enabled')
  assert.ok(s.infoHash && s.infoHash.length === 40, 'informative stream uses placeholder infoHash')
})

test('aggregateStreams returns informative stream when providers return zero results', async () => {
  const streams = await aggregateStreams({ type: 'movie', id: 'tt0000002', providers: [fakeProviderOkEmpty()], trackers: [] })
  assert.ok(Array.isArray(streams) && streams.length === 1)
  const s = streams[0]
  assert.ok(/No results/i.test(s.title) || /No results from providers/i.test(s.title))
})

test('aggregateStreams returns informative stream when providers error out', async () => {
  const streams = await aggregateStreams({ type: 'movie', id: 'tt0000003', providers: [fakeProviderError()], trackers: [] })
  assert.ok(Array.isArray(streams) && streams.length === 1)
  const s = streams[0]
  assert.ok(/Provider/i.test(s.title))
})
