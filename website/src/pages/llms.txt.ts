import type { APIRoute } from 'astro'
import { getFuelReport, fmtDay, fmtPrice } from '../data/fuel'
import { author, faq, features, limitations, site } from '../data/site'

/** Riassunto del sito per assistenti e motori di ricerca basati su modelli linguistici (llmstxt.org). */
export const GET: APIRoute = async ({ site: origin }) => {
  const root = new URL(import.meta.env.BASE_URL, origin)
  const url = (path: string) => new URL(path, root).href
  const fuel = await getFuelReport()
  const bari = fuel?.provinces.find((r) => r.province.code === 'BA')

  const text = `# ${site.name}

> ${site.description}

${site.name} è un'app Android open source (licenza ${site.license}) per la navigazione su OpenStreetMap, sviluppata a Bari da ${author.name}. Versione ${site.version}, in sviluppo: non c'è ancora un APK pubblico, si compila dal codice sorgente. Richiede ${site.minAndroid} o successivo.

## Pagine

- [Navia](${url('')}): funzioni, privacy, domande frequenti e informazioni per chi sviluppa
- [Confronto tra navigatori](${url('confronto/')}): Navia, Google Maps, Organic Maps e OsmAnd
- [Prezzi dei carburanti](${url('carburanti/')}): medie di oggi in Italia e nelle 107 province, dai dati MIMIT
- [Informativa sulla privacy](${url('privacy/')}): quali dati tratta l'app e quali servizi ricevono cosa
- [${author.name}](${url('biagio-scaglia/')}): l'autore, ${author.jobTitle.toLowerCase()} a ${author.city}
- [Codice sorgente](${site.github})

## Funzioni

${features.map((f) => `- ${f.title}: ${f.lead}`).join('\n')}

## Limiti attuali

${limitations.map((l) => `- ${l}`).join('\n')}

## Domande frequenti

${faq.map((f) => `### ${f.q}\n\n${f.a}`).join('\n\n')}
${
  fuel && bari
    ? `
## Prezzi dei carburanti

Dati MIMIT del ${fmtDay(fuel.extracted)}. Benzina self in media ${fmtPrice(fuel.national.stats['Benzina|self']!.avg)} €/l in Italia e ${fmtPrice(bari.summary.stats['Benzina|self']!.avg)} €/l in provincia di Bari; gasolio self ${fmtPrice(fuel.national.stats['Gasolio|self']!.avg)} €/l in Italia e ${fmtPrice(bari.summary.stats['Gasolio|self']!.avg)} €/l in provincia di Bari. Ogni provincia ha la sua pagina in ${url('carburanti/')}.
`
    : ''
}`
  return new Response(text, { headers: { 'Content-Type': 'text/plain; charset=utf-8' } })
}
