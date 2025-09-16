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

test('revoke seedling from Account page', async ({ page }) => {
  await page.goto(`${BASE}/`, { waitUntil: 'domcontentloaded' })
  await loginViaMagic(page)

  // Navigate to Account and mint a seedling
  await page.goto(`${BASE}/account`, { waitUntil: 'domcontentloaded' })
  await page.waitForURL(/\/account$/, { timeout: 15000 })
  await page.getByRole('button', { name: 'Mint seedling' }).click()

  // Wait for the mint result and extract seedling_id from the manifest link
  await expect(page.getByRole('link', { name: 'Install / Open' })).toBeVisible({ timeout: 20000 })
  const manifestUrl = await page.evaluate(() => {
    const anchors = Array.from(document.querySelectorAll('a')) as HTMLAnchorElement[]
    const found = anchors.find(a => /\/manifest\.json$/.test(a.getAttribute('href') || ''))
    return found ? found.href : ''
  })
  expect(manifestUrl, 'manifestUrl not found after mint').toBeTruthy()
  const pathOnly = manifestUrl.replace(/^https?:\/\/[^/]+\//, '')
  const parts = pathOnly.split('/')
  const seedlingId = parts[1] === 's' ? parts[2] : parts[1]
  expect(seedlingId, 'seedlingId parse failed').toBeTruthy()

  // Reload to ensure the list reflects the newly minted seedling
  await page.goto(`${BASE}/account`, { waitUntil: 'domcontentloaded' })
  await page.waitForURL(/\/account$/, { timeout: 15000 })

  // Locate the row for this seedling and revoke it
  const targetRow = page.locator('tbody tr', { hasText: seedlingId })
  await expect(targetRow).toBeVisible({ timeout: 20000 })
  const revokeBtn = page.getByRole('button', { name: `Revoke ${seedlingId}` })
  await expect(revokeBtn).toBeVisible({ timeout: 20000 })
  await revokeBtn.click()
  // Confirm in modal
  const confirmBtn = page.getByRole('button', { name: 'Confirm revoke' })
  await expect(confirmBtn).toBeVisible({ timeout: 10000 })
  await confirmBtn.click()

  // Verify via API (with credentials) that this seedling is now revoked
  await page.waitForFunction(async (id) => {
    try {
      const r = await fetch('/api/seedlings', { credentials: 'include', cache: 'no-store' })
      if (!r.ok) return false
      const j = await r.json()
      const arr = Array.isArray(j.seedlings) ? j.seedlings : []
      const found = arr.find((x: any) => x && x.install_id === id)
      return !!found && String(found.status || '').toLowerCase() === 'revoked'
    } catch { return false }
  }, seedlingId, { timeout: 20000 })
})
