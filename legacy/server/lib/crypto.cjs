'use strict'

const sodium = require('libsodium-wrappers')

let ready = false
let masterKey = null // Uint8Array 32 bytes

async function initCrypto() {
  if (ready) return
  await sodium.ready
  let b64 = process.env.AI_KMS_KEY || ''
  if (!b64) throw new Error('AI_KMS_KEY missing (base64 32 bytes)')
  try {
    // Normalize: trim, remove whitespace, convert base64url -> base64
    b64 = String(b64).trim().replace(/\s+/g, '')
    b64 = b64.replace(/-/g, '+').replace(/_/g, '/')
    // Pad if needed
    const pad = b64.length % 4
    if (pad === 2) b64 += '=='
    else if (pad === 3) b64 += '='
    const raw = Buffer.from(b64, 'base64')
    if (raw.length !== 32) throw new Error('invalid_length')
    masterKey = new Uint8Array(raw)
    ready = true
  } catch (e) {
    throw new Error('AI_KMS_KEY invalid base64 or length (expect 32 bytes)')
  }
}

function _requireReady() {
  if (!ready || !masterKey) throw new Error('crypto_not_initialized')
}

function encryptSecret(plain) {
  _requireReady()
  const nonce = sodium.randombytes_buf(sodium.crypto_aead_xchacha20poly1305_ietf_NPUBBYTES)
  const ad = null
  const ct = sodium.crypto_aead_xchacha20poly1305_ietf_encrypt(
    Buffer.from(String(plain), 'utf8'), ad, null, nonce, masterKey,
  )
  return { nonce: Buffer.from(nonce), enc: Buffer.from(ct) }
}

function decryptSecret(encBuf, nonceBuf) {
  _requireReady()
  const ad = null
  const msg = sodium.crypto_aead_xchacha20poly1305_ietf_decrypt(
    null, new Uint8Array(encBuf), ad, new Uint8Array(nonceBuf), masterKey,
  )
  return Buffer.from(msg).toString('utf8')
}

module.exports = { initCrypto, encryptSecret, decryptSecret }
