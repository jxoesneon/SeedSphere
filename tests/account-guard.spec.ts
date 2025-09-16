import { test, expect } from '@playwright/test'

const BASE = process.env.BASE || 'http://127.0.0.1:8080'

// Helper to request a magic link and fetch it from /api/auth/magic/last
async function getMagicLinkViaMailer(page, email = 'dev+e2e@example.com') {
  const start = await page.request.post(`${BASE}/api/auth/magic/start`, {
    headers: { 'Content-Type': 'application/json' },
    data: { email },
  })
  expect(start.ok()).toBeTruthy()
  const sj = await start.json()
  expect(sj.ok).toBeTruthy()
  // Fetch last mail which exposes first URL in body
  const last = await page.request.get(`${BASE}/api/auth/magic/last`)
  expect(last.ok()).toBeTruthy()
  const lj = await last.json()
  expect(lj.ok).toBeTruthy()
  expect(typeof lj.link).toBe('string')
  return lj.link as string
}

test('account guard redirects to start, then returns after login', async ({ page }) => {
  // 0) Boot SPA
  await page.goto(`${BASE}/`, { waitUntil: 'domcontentloaded' })
  // 1) Visit /account, expect redirect to /start or login modal visible
  await page.goto(`${BASE}/account`, { waitUntil: 'domcontentloaded' })
  await page.waitForFunction(() => {
    try {
      const redirected = location.pathname === '/start'
      const modal = !!document.querySelector('dialog.modal')
      return redirected || modal
    } catch { return false }
  }, { timeout: 30000 })

  // 2) Generate a magic link via mailer endpoints and hit it to set the session
  const link = await getMagicLinkViaMailer(page)
  // Navigate the browser to the magic callback to set the session cookie in the page context
  await page.goto(link, { waitUntil: 'domcontentloaded' })

  // 3) Navigate back to the return target
  await page.goto(`${BASE}/account`, { waitUntil: 'domcontentloaded' })
  await page.waitForURL(/\/account$/, { timeout: 15000 })
  await expect(page.locator('h1').filter({ hasText: 'Account' })).toBeVisible({ timeout: 15000 })
  await expect(page.getByRole('heading', { name: 'Profile' })).toBeVisible({ timeout: 15000 })
})
