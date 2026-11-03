// @ts-check
import { defineConfig } from 'astro/config'
import tailwindcss from '@tailwindcss/vite'

// GitHub Pages project site: https://biagio-scaglia.github.io/Navia/
export default defineConfig({
  site: 'https://biagio-scaglia.github.io',
  base: '/Navia',
  trailingSlash: 'always',
  // Il CSS sta nell'HTML: niente richiesta che blocca la prima visualizzazione.
  // Il precaricamento delle pagine è affidato alle Speculation Rules (BaseLayout), senza JavaScript.
  build: { inlineStylesheets: 'always' },
  vite: {
    plugins: [tailwindcss()],
  },
})
