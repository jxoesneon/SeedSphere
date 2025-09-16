import { defineConfig, devices } from '@playwright/test'

const BASE = process.env.BASE || 'http://127.0.0.1:8080'

export default defineConfig({
  testDir: 'tests',
  timeout: 60_000,
  use: {
    baseURL: BASE,
    headless: true,
    trace: 'retain-on-failure',
  },
  projects: [
    {
      name: 'firefox',
      use: { ...devices['Desktop Firefox'] },
    },
  ],
})
