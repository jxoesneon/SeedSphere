'use strict'

const cookie = require('cookie')
const { v4: uuidv4 } = require('uuid')
const { createSession, getSession, deleteSession } = require('./db.cjs')

const COOKIE_NAME = 'ss_sess'

function issueSession(res, user_id, opts = {}) {
  const sid = uuidv4()
  const ttlMs = opts.ttlMs || 30 * 24 * 60 * 60_000 // 30 days
  createSession(sid, user_id, ttlMs)
  // Align with auth route logic: allow COOKIE_SECURE to override NODE_ENV
  const secureFlag = String(process.env.COOKIE_SECURE ?? (process.env.NODE_ENV === 'production'))
    .toLowerCase() === 'true'
  const ck = cookie.serialize(COOKIE_NAME, sid, {
    httpOnly: true,
    secure: secureFlag,
    sameSite: 'lax',
    path: '/',
    maxAge: Math.floor(ttlMs / 1000),
  })
  try {
    const prev = res.getHeader && res.getHeader('Set-Cookie')
    const arr = prev ? (Array.isArray(prev) ? prev.concat([ck]) : [prev, ck]) : [ck]
    res.setHeader('Set-Cookie', arr)
  } catch (_) {
    // Fallback
    res.setHeader('Set-Cookie', ck)
  }
  return sid
}

function readSession(req) {
  const hdr = req.headers.cookie || ''
  const parsed = cookie.parse(hdr || '')
  const sid = parsed[COOKIE_NAME]
  const sess = getSession(sid)
  return sess
}

function clearSession(res) {
  const secureFlag = String(process.env.COOKIE_SECURE ?? (process.env.NODE_ENV === 'production'))
    .toLowerCase() === 'true'
  const ck = cookie.serialize(COOKIE_NAME, '', {
    httpOnly: true,
    secure: secureFlag,
    sameSite: 'lax',
    path: '/',
    maxAge: 0,
  })
  res.setHeader('Set-Cookie', ck)
}

module.exports = { issueSession, readSession, clearSession, COOKIE_NAME }
