import type { APIRoute } from 'astro'
import { compareMeta } from '../data/compare'
import { getFuelReport } from '../data/fuel'
import { privacyMeta } from '../data/privacy'

type Page = { path: string; priority: string; changefreq: string; lastmod?: string }

export const GET: APIRoute = async ({ site }) => {
  const report = await getFuelReport()
  const pages: Page[] = [
    { path: '', priority: '1.0', changefreq: 'weekly' },
    { path: 'confronto/', priority: '0.8', changefreq: 'monthly', lastmod: compareMeta.checkedIso },
    { path: 'biagio-scaglia/', priority: '0.8', changefreq: 'monthly' },
    { path: 'privacy/', priority: '0.6', changefreq: 'monthly', lastmod: privacyMeta.lastUpdatedIso },
    ...(report
      ? [
          { path: 'carburanti/', priority: '0.9', changefreq: 'daily', lastmod: report.extracted },
          ...report.provinces
            .filter((r) => r.summary.stations > 0)
            .map((r) => ({
              path: `carburanti/${r.province.slug}/`,
              priority: r.province.code === 'BA' ? '0.9' : '0.7',
              changefreq: 'daily',
              lastmod: report.extracted,
            })),
        ]
      : []),
  ]

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
