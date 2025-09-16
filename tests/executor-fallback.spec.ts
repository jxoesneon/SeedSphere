import { test, expect } from '@playwright/test'

const BASE = process.env.BASE || 'http://127.0.0.1:8080'

// This test verifies that the Executor page can force an informative fallback stream
// by disabling all providers and using tiny timeouts.
// It expects at least one stream row to render with a SeedSphere informative title.

test('executor shows informative stream when forcing fallback', async ({ page }) => {
  await page.goto(`${BASE}/executor`, { waitUntil: 'domcontentloaded' })

  // Ensure the UI is rendered
  await expect(page.getByRole('heading', { name: 'Executor' })).toBeVisible()

  // Turn on Force fallback
  const checkbox = page.locator('#force-fallback')
  await checkbox.check()
  await expect(checkbox).toBeChecked()

  // Execute with defaults (movie + tt1254207)
  await page.getByRole('button', { name: 'Run' }).click()

  // Expect a result table to show at least one informative stream row
  const table = page.locator('table')
  await expect(table).toBeVisible({ timeout: 15000 })
  const titleCell = table.locator('tbody tr td').first()
  await expect(titleCell).toBeVisible({ timeout: 15000 })

  // Assert it reads as an informative fallback (robust check including reason or label)
  const text = (await titleCell.textContent()) || ''
  expect(/Configure SeedSphere|No providers enabled|Timed out|Installation not linked|Sign-in required/i.test(text)).toBeTruthy()
})
