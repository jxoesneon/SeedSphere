// AI description enhancer with lightweight adapters (OpenAI, Anthropic, Google Gemini)
const axios = require('axios')
const { getAiKey } = require('./db.cjs')
const { decryptSecret } = require('./crypto.cjs')

const CACHE = new Map()

function cacheKey(input) {
  try { return JSON.stringify(input) } catch (_) { return String(Date.now()) }
}

function buildPrompt({ title, releaseInfo, providerName, trackersAdded, baseDescription }) {
  const tech = [
    releaseInfo && releaseInfo.source,
    releaseInfo && releaseInfo.codec,
    releaseInfo && releaseInfo.hdr,
    releaseInfo && releaseInfo.audio,
  ].filter(Boolean).join(' • ')
  const lines = []
  lines.push(`Title: ${title}`)
  if (releaseInfo && releaseInfo.resolution) lines.push(`Resolution: ${releaseInfo.resolution}`)
  if (releaseInfo && releaseInfo.group) lines.push(`Group: ${releaseInfo.group}`)
  if (tech) lines.push(`Tech: ${tech}`)
  if (Array.isArray(releaseInfo && releaseInfo.languages) && releaseInfo.languages.length) lines.push(`Languages: ${releaseInfo.languages.join(', ')}`)
  if (releaseInfo && releaseInfo.sizeStr) lines.push(`Size: ${releaseInfo.sizeStr}`)
  if (typeof trackersAdded === 'number') lines.push(`TrackersAdded: ${trackersAdded}`)
  if (providerName) lines.push(`Provider: ${providerName}`)
  if (baseDescription) lines.push(`BaseDescription:\n${baseDescription}`)
  return `Given the torrent release details below, produce a concise, emoji-rich, MULTILINE description suitable for Stremio. Keep it under 6 lines. Preserve facts, do not hallucinate. Use the style similar to Torrentio. Do not repeat the title.

${lines.join('\n')}`
}

async function callOpenAI({ apiKey, model, prompt, timeoutMs }) {
  if (!apiKey) return null
  const url = 'https://api.openai.com/v1/chat/completions'
  const body = { model: model || 'gpt-4o', messages: [{ role: 'user', content: prompt }], temperature: 0.2 }
  const res = await axios.post(url, body, { timeout: timeoutMs, headers: { Authorization: `Bearer ${apiKey}` } })
  const txt = res && res.data && res.data.choices && res.data.choices[0] && res.data.choices[0].message && res.data.choices[0].message.content
  return txt ? String(txt).trim() : null
}

async function callAzureOpenAI({ endpoint, apiKey, deployment, apiVersion, prompt, timeoutMs }) {
  if (!endpoint || !apiKey || !deployment) return null
  const version = apiVersion || '2024-06-01'
  const url = `${endpoint.replace(/\/$/, '')}/openai/deployments/${encodeURIComponent(deployment)}/chat/completions?api-version=${encodeURIComponent(version)}`
  const body = { messages: [{ role: 'user', content: prompt }], temperature: 0.2 }
  const res = await axios.post(url, body, { timeout: timeoutMs, headers: { 'api-key': apiKey } })
  const txt = res && res.data && res.data.choices && res.data.choices[0] && res.data.choices[0].message && res.data.choices[0].message.content
  return txt ? String(txt).trim() : null
}

async function callAnthropic({ apiKey, model, prompt, timeoutMs }) {
  if (!apiKey) return null
  const url = 'https://api.anthropic.com/v1/messages'
  const body = { model: model || 'claude-3-5-sonnet-20240620', max_tokens: 300, temperature: 0.2, messages: [{ role: 'user', content: prompt }] }
  const res = await axios.post(url, body, { timeout: timeoutMs, headers: { 'x-api-key': apiKey, 'anthropic-version': '2023-06-01' } })
  const content = res && res.data && Array.isArray(res.data.content) ? res.data.content : []
  const txt = content[0] && content[0].text
  return txt ? String(txt).trim() : null
}

async function callGemini({ apiKey, model, prompt, timeoutMs }) {
  if (!apiKey) return null
  const m = (model || 'gemini-1.5-pro')
  const url = `https://generativelanguage.googleapis.com/v1beta/models/${encodeURIComponent(m)}:generateContent?key=${encodeURIComponent(apiKey)}`
  const body = { contents: [{ role: 'user', parts: [{ text: prompt }] }], safetySettings: [], generationConfig: { temperature: 0.2, maxOutputTokens: 300 } }
  const res = await axios.post(url, body, { timeout: timeoutMs })
  const candidates = res && res.data && Array.isArray(res.data.candidates) ? res.data.candidates : []
  const parts = candidates[0] && candidates[0].content && candidates[0].content.parts
  const txt = parts && parts[0] && parts[0].text
  return txt ? String(txt).trim() : null
}

async function enhanceDescription({ baseDescription, title, releaseInfo, providerName, trackersAdded, magnet, meta, aiConfig }) {
  if (!aiConfig || !aiConfig.enabled) return null
  const key = cacheKey({ title, info: releaseInfo, providerName, trackersAdded, magnet, model: aiConfig.model, provider: aiConfig.provider })
  const now = Date.now()
  const cached = CACHE.get(key)
  if (cached && (now - cached.ts) < (aiConfig.cacheTtlMs || 60000)) return cached.val

  const provider = String(aiConfig.provider || '').toLowerCase()
  const timeoutMs = aiConfig.timeoutMs || 2500
  const prompt = buildPrompt({ title, releaseInfo, providerName, trackersAdded, baseDescription })

  // Attempt to resolve user-specific secrets from DB when available
  let resolved = null
  try {
    if (aiConfig.userId && provider) {
      const row = getAiKey(aiConfig.userId, provider)
      if (row && row.enc_key && row.nonce) {
        const plain = decryptSecret(row.enc_key, row.nonce)
        try { resolved = JSON.parse(plain) } catch (_) { resolved = null }
      }
    }
  } catch (_) { /* ignore secret resolution errors */ }

  let val = null
  try {
    if (provider === 'openai') {
      const apiKey = (resolved && resolved.key) || process.env.OPENAI_API_KEY
      val = await callOpenAI({ apiKey, model: aiConfig.model, prompt, timeoutMs })
    } else if (provider === 'azure' || provider === 'azure_openai') {
      const endpoint = (resolved && resolved.endpoint) || process.env.AZURE_OPENAI_ENDPOINT || ''
      const apiKey = (resolved && resolved.key) || process.env.AZURE_OPENAI_API_KEY || ''
      const deployment = (resolved && resolved.deployment) || (aiConfig && aiConfig.model) || process.env.AZURE_OPENAI_DEPLOYMENT || ''
      const apiVersion = (resolved && resolved.apiVersion) || process.env.AZURE_OPENAI_API_VERSION || '2024-06-01'
      val = await callAzureOpenAI({ endpoint, apiKey, deployment, apiVersion, prompt, timeoutMs })
    } else if (provider === 'anthropic') {
      const apiKey = (resolved && resolved.key) || process.env.ANTHROPIC_API_KEY
      val = await callAnthropic({ apiKey, model: aiConfig.model, prompt, timeoutMs })
    } else if (provider === 'google' || provider === 'gemini') {
      const apiKey = (resolved && resolved.key) || process.env.GOOGLE_API_KEY || process.env.GEMINI_API_KEY
      val = await callGemini({ apiKey, model: aiConfig.model, prompt, timeoutMs })
    } else if (provider === 'groq') {
      // Optional: map to OpenAI-compatible if GROQ key provided in future
      val = null
    } else {
      val = null
    }
  } catch (_) {
    val = null
  }

  CACHE.set(key, { ts: now, val })
  return val
}

module.exports = { enhanceDescription }
