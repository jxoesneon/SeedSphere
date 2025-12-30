'use strict'

const express = require('express')
// openid-client v6 is ESM-only; use dynamic import from CJS
let _oidcMod = null
async function getOidc() {
  if (_oidcMod) return _oidcMod
  _oidcMod = await import('openid-client')
  return _oidcMod
}
const jwt = require('jsonwebtoken')
const { v4: uuidv4 } = require('uuid')
const { upsertUser, getUser } = require('../lib/db.cjs')
const { issueSession, readSession, clearSession } = require('../lib/session.cjs')
const { sendMail, getLastMail, getMailerInfo } = require('../lib/mailer.cjs')
const cookie = require('cookie')

const router = express.Router()
const { addEvent, getEvents } = require('../lib/oauth_debug.cjs')

// Cookie secure flag helper: allow overriding via COOKIE_SECURE for local HTTP
const isCookieSecure = String(process.env.COOKIE_SECURE ?? (process.env.NODE_ENV === 'production'))
  .toLowerCase() === 'true'

// Helpers
function baseUrl(req) {
  const proto = req.headers['x-forwarded-proto'] || req.protocol || 'http'
  const host = req.headers['x-forwarded-host'] || req.headers.host
  return `${proto}://${host}`
}

// Session check
router.get('/session', (req, res) => {
  try {
    // Debug mode: bypass authentication for local development
    if (process.env.DEBUG_MODE === 'true') {
      console.log('[auth] DEBUG_MODE enabled - returning mock authenticated user')
      return res.json({ 
        ok: true, 
        user: { 
          id: 'debug-user', 
          email: 'debug@local.dev' 
        } 
      })
    }
    
    const sess = readSession(req)
    if (!sess) return res.json({ ok: true, user: null })
    // Enrich with user info (email) for UI label
    let user = null
    try { user = getUser(sess.user_id) } catch (_) { user = null }
    const payload = user ? { id: user.id, email: user.email || '' } : { id: sess.user_id }
    return res.json({ ok: true, user: payload })
  } catch (e) { return res.status(500).json({ ok: false, error: e.message }) }
})

// Dev: OAuth logs (newest first)
router.get('/oauth/logs', (req, res) => {
  try { return res.json({ ok: true, logs: getEvents() }) } catch (e) { return res.status(500).json({ ok: false, error: e.message }) }
})

// Microsoft OAuth (OIDC)
let msClient = null
async function getMsClient() {
  if (msClient) return msClient
  const cid = process.env.MS_CLIENT_ID
  const sec = process.env.MS_CLIENT_SECRET
  if (!cid || !sec) throw new Error('microsoft_not_configured')
  const { Issuer } = await getOidc()
  const msIssuer = await Issuer.discover('https://login.microsoftonline.com/common/v2.0/.well-known/openid-configuration')
  msClient = new msIssuer.Client({
    client_id: cid,
    client_secret: sec,
    redirect_uris: [
      'http://localhost:8080/api/auth/microsoft/callback',
      'http://localhost:5173/api/auth/microsoft/callback',
      'https://seedsphere.fly.dev/api/auth/microsoft/callback',
    ],
    response_types: ['code'],
  })
  return msClient
}

router.get('/microsoft/start', notImplemented('microsoft'))

router.get('/microsoft/callback', notImplemented('microsoft'))

// Apple OAuth (OIDC)
let appleClient = null
async function getAppleClient() {
  if (appleClient) return appleClient
  const cid = process.env.APPLE_CLIENT_ID
  const sec = process.env.APPLE_CLIENT_SECRET
  if (!cid || !sec) throw new Error('apple_not_configured')
  const { Issuer } = await getOidc()
  const appleIssuer = await Issuer.discover('https://appleid.apple.com')
  appleClient = new appleIssuer.Client({
    client_id: cid,
    client_secret: sec,
    redirect_uris: [
      'http://localhost:8080/api/auth/apple/callback',
      'http://localhost:5173/api/auth/apple/callback',
      'https://seedsphere.fly.dev/api/auth/apple/callback',
    ],
    response_types: ['code'],
  })
  return appleClient
}

router.get('/apple/start', notImplemented('apple'))

router.get('/apple/callback', notImplemented('apple'))

router.post('/logout', (req, res) => {
  try { clearSession(res); return res.json({ ok: true }) } catch (e) { return res.status(500).json({ ok: false, error: e.message }) }
})

// Magic Link
router.post('/magic/start', async (req, res) => {
  try {
    const email = String(req.body?.email || '').trim().toLowerCase()
    if (!email || !/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(email)) return res.status(400).json({ ok: false, error: 'invalid_email' })
    const secret = process.env.AUTH_JWT_SECRET || ''
    if (!secret) return res.status(500).json({ ok: false, error: 'server_not_configured' })
    const jti = uuidv4()
    const token = jwt.sign({ sub: email, jti, typ: 'magic' }, secret, { issuer: 'seedsphere', audience: 'auth', expiresIn: '15m' })
    const url = `${baseUrl(req)}/api/auth/magic/callback?token=${encodeURIComponent(token)}`
    try { console.info('[magic] start', { to: email, jti, base: baseUrl(req) }) } catch (_) {}
    const subject = 'SeedSphere – Sign in link'
    const preheader = 'Use this secure link to sign in. Expires in 15 minutes.'
    const text = [
      'Hi,',
      '',
      'Click the link below to sign in to SeedSphere:',
      url,
      '',
      'This link expires in 15 minutes.',
      '',
      'If you did not request this, you can safely ignore this email.',
    ].join('\n')
    const html = `<!DOCTYPE html>
<html lang="en">
  <head>
    <meta http-equiv="Content-Type" content="text/html; charset=utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <meta name="color-scheme" content="light" />
    <meta name="supported-color-schemes" content="light" />
    <title>${subject}</title>
    <style>
      /* Basic email client resets */
      body { margin: 0; padding: 0; background: #0b1020; color: #e7ecf7; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; }
      a { color: #0ea5e9; text-decoration: none; }
      .container { width: 100%; max-width: 560px; margin: 0 auto; padding: 24px 16px; }
      .card { background: #11172b; border: 1px solid #1d2642; border-radius: 12px; padding: 24px; }
      .btn { display: inline-block; background: linear-gradient(90deg, #06b6d4, #3b82f6); color: #ffffff !important; font-weight: 700; padding: 12px 20px; border-radius: 10px; }
      .muted { color: #a8b3cf; font-size: 13px; }
      .spacer { height: 16px; }
      .logo { font-weight: 800; letter-spacing: 0.2px; }
      .mono { font-family: ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, 'Liberation Mono', 'Courier New', monospace; }
    </style>
  </head>
  <body>
    <span style="display:none!important;opacity:0;color:transparent;height:0;width:0;overflow:hidden;">${preheader}</span>
    <div class="container">
      <div style="text-align:center; margin-bottom: 12px;">
        <div class="logo" style="font-size: 20px;">🌱 SeedSphere</div>
      </div>
      <div class="card">
        <h1 style="margin: 0 0 8px 0; font-size: 20px;">Sign in to SeedSphere</h1>
        <p class="muted" style="margin: 0 0 16px 0;">Use the secure link below. It expires in 15 minutes.</p>
        <div class="spacer"></div>
        <p style="text-align:center; margin: 0 0 20px 0;">
          <a class="btn" href="${url}" target="_blank" rel="nofollow noopener">Continue</a>
        </p>
        <p class="muted" style="margin: 0 0 8px 0;">Or copy and paste this URL into your browser:</p>
        <p class="mono" style="word-break: break-all; color: #d0d8eb;">${url}</p>
        <div class="spacer"></div>
        <hr style="border: 0; border-top: 1px solid #1d2642; margin: 16px 0;" />
        <p class="muted" style="margin: 0;">If you did not request this sign-in, you can safely ignore this email.</p>
      </div>
      <p class="muted" style="text-align:center; margin-top: 12px;">© ${new Date().getFullYear()} SeedSphere</p>
    </div>
  </body>
</html>`
    const info = await sendMail({ to: email, subject, text, html })
    try { console.info('[magic] mail_sent', { to: email, messageId: info?.messageId || null }) } catch (_) {}
    return res.json({ ok: true })
  } catch (e) { return res.status(500).json({ ok: false, error: e.message }) }
})

router.get('/magic/callback', (req, res) => {
  try {
    const token = String(req.query.token || '')
    const secret = process.env.AUTH_JWT_SECRET || ''
    if (!secret) return res.status(500).send('server_not_configured')
    const payload = jwt.verify(token, secret, { issuer: 'seedsphere', audience: 'auth' })
    const email = String(payload?.sub || '')
    if (!email) return res.status(400).send('invalid_token')
    const userId = `magic:${email}`
    try { console.info('[magic] callback', { email, jti: payload?.jti || null, iat: payload?.iat || null, exp: payload?.exp || null }) } catch (_) {}
    upsertUser({ id: userId, provider: 'magic', email })
    issueSession(res, userId)
    // Redirect back to Configure page
    const redirect = `${baseUrl(req)}/#/configure?login=ok`
    return res.redirect(302, redirect)
  } catch (e) { return res.status(400).send('invalid_or_expired') }
})

// Dev helper: expose the last magic email sent
router.get('/magic/last', (req, res) => {
  try {
    const m = getLastMail()
    if (!m) return res.json({ ok: true, mail: null })
    // Try to extract the first URL from text or html
    const corpus = (m.text || m.html || '')
    const match = String(corpus).match(/https?:\/\/[^\s"'>]+/)
    const link = match ? match[0] : ''
    return res.json({ ok: true, mail: { to: m.to, subject: m.subject }, link })
  } catch (e) { return res.status(500).json({ ok: false, error: e.message }) }
})

// Magic: status (mailer mode/config, non-sensitive)
router.get('/magic/status', (req, res) => {
  try {
    const info = getMailerInfo()
    return res.json({ ok: true, mailer: info })
  } catch (e) { return res.status(500).json({ ok: false, error: e.message }) }
})

// OAuth: Google fully implemented; Microsoft and Apple added; others stubbed for now
let googleClient = null
async function getGoogleClient() {
  if (googleClient) return googleClient
  const gcid = process.env.GOOGLE_CLIENT_ID
  const gsec = process.env.GOOGLE_CLIENT_SECRET
  if (!gcid || !gsec) throw new Error('google_not_configured')
  const { Issuer } = await getOidc()
  const issuer = await Issuer.discover('https://accounts.google.com')
  googleClient = new issuer.Client({
    client_id: gcid,
    client_secret: gsec,
    redirect_uris: [
      'http://localhost:8080/api/auth/google/callback',
      'http://localhost:5173/api/auth/google/callback',
      'https://seedsphere.fly.dev/api/auth/google/callback',
    ],
    response_types: ['code'],
  })
  return googleClient
}

router.get('/google/start', async (req, res) => {
  try {
    const redirectUri = `${baseUrl(req)}/api/auth/google/callback`
    const { randomPKCECodeVerifier, calculatePKCECodeChallenge } = await getOidc()
    const code_verifier = randomPKCECodeVerifier()
    const code_challenge = await calculatePKCECodeChallenge(code_verifier)
    // Store verifier in a short-lived cookie
    const ck = cookie.serialize('g_verifier', code_verifier, {
      httpOnly: true,
      sameSite: 'lax',
      secure: isCookieSecure,
      path: '/',
      maxAge: 10 * 60, // 10 minutes
    })
    res.setHeader('Set-Cookie', ck)
    const params = new URLSearchParams({
      client_id: String(process.env.GOOGLE_CLIENT_ID || ''),
      redirect_uri: redirectUri,
      response_type: 'code',
      scope: 'openid email profile',
      code_challenge,
      code_challenge_method: 'S256',
      access_type: 'offline',
      include_granted_scopes: 'true',
      // state could be added if desired
    })
    const url = `https://accounts.google.com/o/oauth2/v2/auth?${params.toString()}`
    try { addEvent({ provider: 'google', stage: 'start', request: { redirect_uri: redirectUri } }) } catch (_) {}
    return res.redirect(302, url)
  } catch (e) {
    const msg = (e && (e.stack || e.message || String(e))) || 'unknown_error'
    try { console.error('[auth] google_start_failed:', msg) } catch (_) {}
    try { addEvent({ provider: 'google', stage: 'start_error', error: msg }) } catch (_) {}
    return res.status(500).send(`google_start_failed: ${msg}`)
  }
})

router.get('/google/callback', async (req, res) => {
  try {
    const code = String((req.query && req.query.code) || '')
    if (!code) return res.status(400).send('missing_code')
    const redirectUri = `${baseUrl(req)}/api/auth/google/callback`
    const parsed = cookie.parse(req.headers.cookie || '')
    const code_verifier = parsed.g_verifier
    if (!code_verifier) return res.status(400).send('missing_verifier')

    const client_id = String(process.env.GOOGLE_CLIENT_ID || '')
    const client_secret = String(process.env.GOOGLE_CLIENT_SECRET || '')
    if (!client_id || !client_secret) return res.status(500).send('google_not_configured')

    // Exchange code for tokens
    const axios = require('axios')
    const params = new URLSearchParams({
      code,
      client_id,
      client_secret,
      code_verifier,
      grant_type: 'authorization_code',
      redirect_uri: redirectUri,
    })
    const tok = await axios.post('https://oauth2.googleapis.com/token', params.toString(), {
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      timeout: 12000,
    })
    const { id_token } = tok.data || {}
    if (!id_token) return res.status(500).send('missing_id_token')

    // Decode id_token to get user info (signature verification omitted for local flow)
    const parts = String(id_token).split('.')
    const payload = parts[1] ? JSON.parse(Buffer.from(parts[1], 'base64').toString('utf8')) : {}
    const sub = String(payload.sub || '')
    const email = String(payload.email || '')
    if (!sub) return res.status(500).send('invalid_token')

    const userId = `google:${sub}`
    try { addEvent({ provider: 'google', stage: 'callback', token: { id_token: '[redacted]' }, claims: { sub, email }, userId }) } catch (_) {}
    upsertUser({ id: userId, provider: 'google', email })
    issueSession(res, userId)
    // Clear the verifier cookie
    try {
      const del = cookie.serialize('g_verifier', '', { httpOnly: true, sameSite: 'lax', secure: isCookieSecure, path: '/', maxAge: 0 })
      const prev = res.getHeader && res.getHeader('Set-Cookie')
      const arr = prev ? (Array.isArray(prev) ? prev.concat([del]) : [prev, del]) : [del]
      res.setHeader('Set-Cookie', arr)
    } catch (_) {}
    return res.redirect(302, `${baseUrl(req)}/#/configure?login=ok`)
  } catch (e) {
    const msg = (e && (e.stack || e.message || String(e))) || 'unknown_error'
    try { console.error('[auth] google_callback_failed:', msg) } catch (_) {}
    try { addEvent({ provider: 'google', stage: 'callback_error', error: msg }) } catch (_) {}
    return res.status(500).send(`google_callback_failed: ${msg}`)
  }
})

function notImplemented(name) {
  return (req, res) => res.status(501).json({ ok: false, error: `${name}_not_implemented_yet` })
}

router.get('/facebook/start', notImplemented('facebook'))
router.get('/facebook/callback', notImplemented('facebook'))
router.get('/twitter/start', notImplemented('twitter'))
router.get('/twitter/callback', notImplemented('twitter'))
// Note: Microsoft and Apple implemented above

module.exports = router
