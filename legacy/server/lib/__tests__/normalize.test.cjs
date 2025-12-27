'use strict'

const assert = require('node:assert')
const { test } = require('node:test')

const { normalize } = require('../normalize.cjs')

const sample = {
  title: "Blade Runner (1982) — Director's Cut [Remastered HDR] 1080p",
  provider: 'yts.mx',
  quality: '1080p',
  language: ['en', 'es-419'],
  infohash: '0123456789abcdef0123456789abcdef01234567',
  extras: 'WEB H.264 HDR10 5.1-GROUP size: 8.7 GB v2 PROPER',
}

test('normalize produces Natural schema fields with mappings', () => {
  const out = normalize(sample)
  assert.ok(out)
  assert.equal(out.title_natural, 'Blade Runner')
  assert.equal(out.year, 1982)
  assert.equal(out.edition, "Director’s Cut")
  assert.ok(out.remaster && out.remaster.flag)
  assert.equal(out.quality, '1080p')
  // version tag may capture v2; tolerate others present
  assert.ok(out.version_tag === 'v2' || out.version_tag === 'PROPER' || out.version_tag === 'REPACK')
  assert.equal(out.provider_display, 'YTS')
  assert.ok(Array.isArray(out.languages_display) && out.languages_display.length >= 2)
  assert.ok(Array.isArray(out.languages_flags) && out.languages_flags.length >= 2)
  assert.equal(out.infohash, sample.infohash.toUpperCase())
  assert.ok(out.extras)
  assert.ok(out.internal)
})

test('normalize tolerates minimal input', () => {
  const out = normalize({ title: 'Movie Title' })
  assert.equal(out.title_natural, 'Movie Title')
  assert.equal(out.year, null)
  assert.equal(out.edition, null)
  assert.equal(out.quality, null)
  assert.equal(out.version_tag, null)
  assert.equal(out.provider_display, null)
  assert.ok(Array.isArray(out.languages_display))
  assert.ok(Array.isArray(out.languages_flags))
})
