import { test, expect } from '@playwright/test'

// Verifies that when data-theme="seedsphere" is active, the core DaisyUI CSS
// variables are present on :root and match the tokens we define in our theme.
// This guards against regressions where the custom theme fails to ship in the
// compiled CSS bundle or loses precedence.

test('seedsphere theme CSS variables are applied on :root', async ({ page }) => {
  await page.goto('/')

  // Force the theme to seedsphere regardless of user/system preference.
  await page.evaluate(() => {
    document.documentElement.setAttribute('data-theme', 'seedsphere')
  })

  const cssVars = await page.evaluate(() => {
    const style = getComputedStyle(document.documentElement)
    const pick = (name: string) => (style.getPropertyValue(name) || '').trim()
    return {
      p: pick('--p'),
      pc: pick('--pc'),
      s: pick('--s'),
      a: pick('--a'),
      n: pick('--n'),
      b1: pick('--b1'),
      b2: pick('--b2'),
      b3: pick('--b3'),
      bc: pick('--bc'),
      in: pick('--in'),
      su: pick('--su'),
      wa: pick('--wa'),
      er: pick('--er'),
    }
  })

  // Sanity: ensure variables are non-empty
  for (const [k, v] of Object.entries(cssVars)) {
    expect(v, `css var ${k} should be set`).toBeTruthy()
  }

  // Exact match to our tokens (OKLCH values) defined in src/assets/main.css @layer theme
  expect(cssVars.p).toBe('0.84 0.11 240')
  expect(cssVars.pc).toBe('0.18 0.02 250')
  expect(cssVars.s).toBe('0.89 0.10 150')
  expect(cssVars.a).toBe('0.70 0.16 250')
  expect(cssVars.n).toBe('0.30 0.02 250')
  expect(cssVars.b1).toBe('0.18 0.02 250')
  expect(cssVars.b2).toBe('0.24 0.02 250')
  expect(cssVars.b3).toBe('0.30 0.03 250')
  expect(cssVars.bc).toBe('0.95 0.02 250')
  expect(cssVars.in).toBe('0.84 0.11 240')
  expect(cssVars.su).toBe('0.70 0.12 150')
  expect(cssVars.wa).toBe('0.87 0.12 95')
  expect(cssVars.er).toBe('0.70 0.18 25')
})
