/** Tailwind v4 + DaisyUI (ESM config) */
export default {
  content: [
    './index.html',
    './src/**/*.{vue,js,ts,jsx,tsx}',
  ],
  theme: {
    extend: {},
  },
  // DaisyUI is loaded via CSS: `@plugin "daisyui";`
  daisyui: {
    themes: [
      'light',
      'dark',
      {
        seedsphere: {
          primary: '#7cc4fa',
          'primary-content': '#051423',
          secondary: '#9ef0a6',
          accent: '#2b8ad6',
          neutral: '#1b2430',
          'neutral-content': '#e8eef7',
          'base-100': '#0b0f17',
          'base-200': '#121826',
          'base-300': '#1a2332',
          'base-content': '#e8eef7',
          info: '#7cc4fa',
          success: '#1f9b58',
          warning: '#f6c860',
          error: '#ef5962',
        },
      },
    ],
  },
}
