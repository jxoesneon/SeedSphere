'use strict'

const express = require('express')
const { readSession } = require('../lib/session.cjs')
const { upsertAiKey, listAiKeys, deleteAiKey, getAiKey } = require('../lib/db.cjs')
const { encryptSecret, decryptSecret } = require('../lib/crypto.cjs')

const router = express.Router()

function requireUser(req, res) {
  const sess = readSession(req)
  if (!sess) { res.status(401).json({ ok: false, error: 'unauthorized' }); return null }
  return sess.user_id
}

// List providers saved (no secrets leaked)
router.get('/list', (req, res) => {
  try {
    const uid = requireUser(req, res)
    if (!uid) return
    const items = listAiKeys(uid)
    return res.json({ ok: true, items })
  } catch (e) { return res.status(500).json({ ok: false, error: e.message }) }
})

// Save/update secret for a provider
router.post('/set', (req, res) => {
  try {
    const uid = requireUser(req, res)
    if (!uid) return
    const provider = String(req.body?.provider || '').toLowerCase().trim()
    if (!provider) return res.status(400).json({ ok: false, error: 'missing_provider' })
    // Accept either a single key or a structured object for Azure-like providers
    const payload = {
      key: req.body?.key || req.body?.apiKey || '',
      endpoint: req.body?.endpoint || req.body?.baseUrl || '',
      apiVersion: req.body?.apiVersion || req.body?.version || '',
      deployment: req.body?.deployment || req.body?.model || '',
    }
    // Minimal validation
    if (!payload.key && provider !== 'azure' && provider !== 'azure_openai') {
      return res.status(400).json({ ok: false, error: 'missing_key' })
    }
    const secretJson = JSON.stringify(payload)
    const { nonce, enc } = encryptSecret(secretJson)
    upsertAiKey(uid, provider, enc, nonce)
    return res.json({ ok: true })
  } catch (e) { return res.status(500).json({ ok: false, error: e.message }) }
})

// Delete secret for a provider
router.delete('/:provider', (req, res) => {
  try {
    const uid = requireUser(req, res)
    if (!uid) return
    const provider = String(req.params.provider || '').toLowerCase().trim()
    if (!provider) return res.status(400).json({ ok: false, error: 'missing_provider' })
    deleteAiKey(uid, provider)
    return res.json({ ok: true })
  } catch (e) { return res.status(500).json({ ok: false, error: e.message }) }
})

// Internal helper endpoint (optional): decrypt by provider for current user
// NOTE: Do not expose in production unless protected; intended for backend-only consumption in future wiring.
router.post('/_get', (req, res) => {
  try {
    const uid = requireUser(req, res)
    if (!uid) return
    const provider = String(req.body?.provider || '').toLowerCase().trim()
    if (!provider) return res.status(400).json({ ok: false, error: 'missing_provider' })
    const row = getAiKey(uid, provider)
    if (!row) return res.json({ ok: true, secret: null })
    const plaintext = decryptSecret(row.enc_key, row.nonce)
    return res.json({ ok: true, secret: JSON.parse(plaintext) })
  } catch (e) { return res.status(500).json({ ok: false, error: e.message }) }
})

module.exports = router
