import { test, expect } from '@playwright/test'

const BASE = process.env.BASE || 'http://127.0.0.1:8080'

async function loginViaMagic(page, email = 'dev+e2e@example.com') {
  const start = await page.request.post(`${BASE}/api/auth/magic/start`, {
    headers: { 'Content-Type': 'application/json' },
    data: { email },
  })
  expect(start.ok()).toBeTruthy()
  const last = await page.request.get(`${BASE}/api/auth/magic/last`)
  expect(last.ok()).toBeTruthy()
  const lj = await last.json()
  expect(lj.ok).toBeTruthy()
  const link = lj.link as string
  await page.goto(link, { waitUntil: 'domcontentloaded' })
}

test('mint seedling and validate manifest.json', async ({ page }) => {
  // Boot and login
  await page.goto(`${BASE}/`, { waitUntil: 'domcontentloaded' })
  await loginViaMagic(page)

  // Go to account and mint
  await page.goto(`${BASE}/account`, { waitUntil: 'domcontentloaded' })
  await page.waitForURL(/\/account$/, { timeout: 15000 })
  await expect(page.locator('h1').filter({ hasText: 'Account' })).toBeVisible({ timeout: 15000 })

  await page.getByRole('button', { name: 'Mint seedling' }).click()

  // Wait for the 'Install / Open' link and a manifest link
  await expect(page.getByRole('link', { name: 'Install / Open' })).toBeVisible({ timeout: 15000 })

  // Extract the manifest URL from the page content
  const manifestUrl = await page.evaluate(() => {
    const anchors = Array.from(document.querySelectorAll('a')) as HTMLAnchorElement[]
    const found = anchors.find(a => /\/manifest\.json$/.test(a.getAttribute('href') || ''))
    return found ? found.href : ''
  })
  expect(manifestUrl, 'manifestUrl not found on Account page').toBeTruthy()

  // Fetch manifest and validate basic shape
  const r = await page.request.get(manifestUrl)
  expect(r.ok()).toBeTruthy()
  const j = await r.json()
  expect(j.id).toBe('community.SeedSphere')
  expect(typeof j.version).toBe('string')
  expect(Array.isArray(j.resources)).toBeTruthy()
})
