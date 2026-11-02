import type { APIRoute } from 'astro'
import { compareMeta } from '../data/compare'
import { privacyMeta } from '../data/privacy'

const pages = [
  { path: '', priority: '1.0', changefreq: 'weekly' },
  { path: 'confronto/', priority: '0.8', changefreq: 'monthly', lastmod: compareMeta.checkedIso },
  { path: 'biagio-scaglia/', priority: '0.8', changefreq: 'monthly' },
  { path: 'privacy/', priority: '0.6', changefreq: 'monthly', lastmod: privacyMeta.lastUpdatedIso },
]

export const GET: APIRoute = ({ site }) => {
  const root = new URL(import.meta.env.BASE_URL, site)
  const urls = pages
    .map(
      (p) =>
        `  <url>\n    <loc>${new URL(p.path, root).href}</loc>\n` +
        (p.lastmod ? `    <lastmod>${p.lastmod}</lastmod>\n` : '') +
        `    <changefreq>${p.changefreq}</changefreq>\n    <priority>${p.priority}</priority>\n  </url>`,
    )
    .join('\n')
  return new Response(
    `<?xml version="1.0" encoding="UTF-8"?>\n<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">\n${urls}\n</urlset>\n`,
    { headers: { 'Content-Type': 'application/xml; charset=utf-8' } },
  )
}
