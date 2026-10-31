// @ts-check
import { defineConfig } from 'astro/config'
import tailwindcss from '@tailwindcss/vite'

// GitHub Pages project site: https://biagio-scaglia.github.io/Navia/
export default defineConfig({
  site: 'https://biagio-scaglia.github.io',
  base: '/Navia',
  trailingSlash: 'always',
  vite: {
    plugins: [tailwindcss()],
  },
})
