'use strict'

const assert = require('node:assert')
const { test, beforeEach } = require('node:test')

const boosts = require('../boosts.cjs')

beforeEach(() => {
  // isolate tests
  boosts.__resetForTests()
})

test('push caps to 20 and stores latest first', () => {
  for (let i = 0; i < 25; i++) boosts.push({ id: `x${i}`, type: 'movie' })
  const list = boosts.recent()
  assert.equal(list.length, 20)
  // latest first
  assert.equal(list[0].id, 'x24')
  assert.equal(list.at(-1).id, 'x5')
})

test('subscribe receives events and unsubscribe stops them', () => {
  const seen = []
  const unsub = boosts.subscribe((it) => seen.push(it))
  boosts.push({ id: 'a', type: 'movie' })
  assert.equal(seen.length, 1)
  assert.equal(seen[0].id, 'a')
  unsub()
  boosts.push({ id: 'b', type: 'movie' })
  assert.equal(seen.length, 1)
})

test('push normalizes fields', () => {
  boosts.push({ id: 'n1', type: 'series', mode: 'OFF', healthy: '2', total: '5', season: '1', episode: '3', title: 'T' })
  const [it] = boosts.recent()
  assert.ok(typeof it.time === 'string' && it.time.includes('T'))
  assert.ok(Number.isFinite(it.ts))
  assert.equal(it.mode, 'off')
  assert.equal(it.healthy, 2)
  assert.equal(it.total, 5)
  assert.equal(it.type, 'series')
  assert.equal(it.id, 'n1')
  assert.equal(it.season, 1)
  assert.equal(it.episode, 3)
})
