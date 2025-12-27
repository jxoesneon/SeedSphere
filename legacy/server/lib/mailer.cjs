'use strict'

const nodemailer = require('nodemailer')

let lastMail = null
let lastResult = null

let transporter = null
let mailerMode = 'unknown'

function initMailer() {
  if (transporter) return transporter
  const host = process.env.SMTP_HOST
  const port = Number(process.env.SMTP_PORT || '587')
  const user = process.env.SMTP_USER
  const pass = process.env.SMTP_PASS
  const secure = String(process.env.SMTP_SECURE || 'false') === 'true'
  if (!host || !user || !pass) {
    // Dev fallback: capture emails to memory and console
    transporter = nodemailer.createTransport({
      streamTransport: true,
      buffer: true,
      newline: 'unix',
    })
    mailerMode = 'stream'
    return transporter
  }
  transporter = nodemailer.createTransport({ host, port, secure, auth: { user, pass } })
  mailerMode = 'smtp'
  return transporter
}

function parseFrom(str) {
  // Accept formats: "Name <email@host>" or plain email
  try {
    const m = String(str || '').match(/^(.*)<([^>]+)>\s*$/)
    if (m) return { name: m[1].trim().replace(/^"|"$/g, ''), email: m[2].trim() }
    return { name: '', email: String(str || '').trim() }
  } catch { return { name: '', email: '' } }
}

async function sendViaBrevo({ from, to, subject, text, html }) {
  const apiKey = process.env.BREVO_API_KEY
  if (!apiKey) return null
  const sender = parseFrom(from)
  const payload = {
    sender: { email: sender.email || process.env.SMTP_USER || 'no-reply@seedsphere.local', name: sender.name || 'SeedSphere' },
    to: [{ email: to }],
    subject,
    htmlContent: html,
    textContent: text,
  }
  const res = await fetch('https://api.brevo.com/v3/smtp/email', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', 'api-key': apiKey },
    body: JSON.stringify(payload),
  })
  const body = await res.json().catch(() => ({}))
  const ok = res.ok && (body?.messageId || body?.messageIds)
  mailerMode = 'api'
  const info = { messageId: body?.messageId || (Array.isArray(body?.messageIds) ? body.messageIds[0] : null), accepted: ok ? [to] : [], rejected: ok ? [] : [to], response: `${res.status}`, envelope: { from: sender.email, to: [to] }, api: { status: res.status, body } }
  return info
}

async function sendMail({ to, subject, text, html }) {
  const from = process.env.SMTP_FROM || `SeedSphere <no-reply@seedsphere.local>`
  // Prefer Brevo API when key is available
  if (process.env.BREVO_API_KEY) {
    try {
      const apiInfo = await sendViaBrevo({ from, to, subject, text, html })
      if (apiInfo) {
        try {
          lastMail = { to, subject, text, html, messageId: apiInfo.messageId || null }
          lastResult = { ...apiInfo }
          if (process.env.NODE_ENV !== 'production') console.log('[mail] brevo_api', lastResult)
        } catch (_) {}
        return apiInfo
      }
    } catch (e) {
      if (process.env.NODE_ENV !== 'production') console.error('[mail] brevo_api_error', e && e.message ? e.message : e)
      // fallthrough to SMTP
    }
  }
  const tx = initMailer()
  const info = await tx.sendMail({ from, to, subject, text, html })
  try {
    lastMail = { to, subject, text, html, messageId: info.messageId || null }
    lastResult = {
      messageId: info.messageId || null,
      accepted: info.accepted || [],
      rejected: info.rejected || [],
      pending: info.pending || [],
      response: info.response || null,
      envelope: info.envelope || null,
    }
    if (process.env.NODE_ENV !== 'production') {
      console.log('[mail] sent', { to, subject, messageId: info.messageId, accepted: info.accepted, rejected: info.rejected, response: info.response })
    }
  } catch (_) {}
  return info
}

function getLastMail() { return lastMail }
function getMailerInfo() {
  // Only return non-sensitive flags for debugging
  const hostSet = !!process.env.SMTP_HOST
  const userSet = !!process.env.SMTP_USER
  const from = process.env.SMTP_FROM || 'SeedSphere <no-reply@seedsphere.local>'
  const apiKeySet = !!process.env.BREVO_API_KEY
  return { mode: mailerMode, hostSet, userSet, apiKeySet, from, lastResult }
}

module.exports = { initMailer, sendMail, getLastMail, getMailerInfo }
