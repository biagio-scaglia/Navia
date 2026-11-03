/**
 * Prezzi dei carburanti per le pagine /carburanti/: lo stesso dataset che l'app scarica
 * (workflow "Fuel data", dai dati aperti MIMIT, IODL 2.0), letto una volta per build.
 *
 * Voce del dataset: [id, lat, lon, marchio, nome, indirizzo, comune, [[carburante, prezzo, self, "YYYY-MM-DDTHH:MM"], ...]]
 * L'indirizzo finisce con " - COMUNE PR": comune e provincia vengono da lì.
 * Il nome del gestore non viene mostrato: spesso è il nome di una persona.
 */
import { gunzipSync } from 'node:zlib'
import { provinceByCode, provinces, type Province } from './provinces'

export const FUEL_SOURCE = 'https://github.com/biagio-scaglia/Navia/releases/download/fuel-data/fuel-prices.json.gz'
/** Prezzi comunicati negli ultimi N giorni rispetto all'estrazione: quelli più vecchi non contano. */
export const WINDOW_DAYS = 7
/**
 * Fascia accettata attorno alla mediana della provincia. I distributori scontati veri stanno
 * pochi centesimi sotto; un gasolio a 1,68 € dove tutti sono sopra 2,18 € è un dato sbagliato.
 * GPL e metano variano di più tra un impianto e l'altro.
 */
const BANDS = {
  Benzina: [0.92, 1.25],
  Gasolio: [0.92, 1.25],
  GPL: [0.8, 1.35],
  Metano: [0.75, 1.4],
} as const

export const fuels = [
  { key: 'Benzina|self', fuel: 'Benzina', label: 'Benzina self', short: 'Benzina', unit: '€/l' },
  { key: 'Gasolio|self', fuel: 'Gasolio', label: 'Gasolio self', short: 'Gasolio', unit: '€/l' },
  { key: 'GPL|any', fuel: 'GPL', label: 'GPL', short: 'GPL', unit: '€/l' },
  { key: 'Metano|any', fuel: 'Metano', label: 'Metano', short: 'Metano', unit: '€/kg' },
  { key: 'Benzina|servito', fuel: 'Benzina', label: 'Benzina servito', short: 'Benzina servito', unit: '€/l' },
  { key: 'Gasolio|servito', fuel: 'Gasolio', label: 'Gasolio servito', short: 'Gasolio servito', unit: '€/l' },
] as const
export type FuelKey = (typeof fuels)[number]['key']
/** Le quattro voci principali, nell'ordine in cui compaiono nelle pagine. */
export const headline = fuels.slice(0, 4)

export type Station = {
  id: number
  lat: number
  lon: number
  brand: string
  street: string
  town: string
  prov: string
  /** Miglior prezzo valido per voce, con la data in cui è stato comunicato. */
  prices: Partial<Record<FuelKey, { price: number; at: string }>>
}

export type Stat = { avg: number; min: number; count: number }
export type Summary = { stations: number; stats: Partial<Record<FuelKey, Stat>> }
export type Entry = { station: Station; price: number; at: string }

export type ProvinceReport = {
  province: Province
  summary: Summary
  cheapest: Partial<Record<FuelKey, Entry[]>>
  towns: { name: string; summary: Summary }[]
}

export type FuelReport = {
  extracted: string
  windowFrom: string
  source: string
  national: Summary
  regions: { name: string; summary: Summary; provinces: ProvinceReport[] }[]
  provinces: ProvinceReport[]
}

// ---------- Testo leggibile ----------

const SMALL = new Set(['di', 'del', 'della', 'dello', 'dei', 'degli', 'delle', 'e', 'in', 'a', 'al', 'alla', 'allo', 'ai', 'agli', 'alle', 'da', 'dal', 'dalla', 'sul', 'sulla', 'per', 'con', 'sotto', 'sopra'])

/** "ACQUAVIVA DELLE FONTI" → "Acquaviva delle Fonti", "FIORENZUOLA D'ARDA" → "Fiorenzuola d'Arda" */
export const titleCase = (raw: string) =>
  raw
    .trim()
    .replace(/\s+/g, ' ')
    .split(' ')
    .map((word, i) => {
      if (/^([A-Z]\.){2,}$/.test(word) || /^[A-Z]{1,3}\d/.test(word) || (/^[IVXL]{2,}$/.test(word) && i > 0)) return word
      const lower = word.toLowerCase()
      if (i > 0 && SMALL.has(lower)) return lower
      const cased = lower.replace(/(^|[-'’.(/])([a-zà-ù])/g, (_, p, c) => p + c.toUpperCase())
      return i > 0 ? cased.replace(/^(D|Dell|Dall|Nell|Sull|All)(['’])/, (_, p, q) => p.toLowerCase() + q) : cased
    })
    .join(' ')

const BRANDS: Record<string, string> = {
  AgipEni: 'Eni',
  'Api-Ip': 'IP',
  PompeBianche: 'Pompe bianche',
  Sconosciuto: 'Senza marchio',
}
const brandName = (raw: string) =>
  BRANDS[raw] ??
  (raw === raw.toUpperCase() && raw.length > 3 ? titleCase(raw) : raw.replace(/([a-z])([A-Z])/g, '$1 $2'))

const parseAddress = (address: string) => {
  const m = / - (?!.* - )(.+?) ([A-Z]{2})\s*$/.exec(address)
  if (!m) return null
  const street = address
    .slice(0, m.index)
    .replace(/[\s-]+$/, '')
    .replace(/\s*\d{5}$/, '')
    .replace(/[\s-]+$/, '')
    // "SNC", "SN", "S.N.": senza numero civico, non aggiunge niente
    .replace(/[\s,]+S\.?\s?N\.?\s?(C\.?)?$/i, '')
  return { street: titleCase(street), town: titleCase(m[1]), prov: m[2] }
}

// ---------- Calcoli ----------

const median = (xs: number[]) => {
  const s = [...xs].sort((a, b) => a - b)
  return s.length ? s[Math.floor(s.length / 2)] : 0
}

const summarize = (stations: Station[]): Summary => {
  const stats: Summary['stats'] = {}
  for (const { key } of fuels) {
    const values = stations.flatMap((s) => (s.prices[key] ? [s.prices[key].price] : []))
    if (values.length) {
      stats[key] = {
        avg: values.reduce((a, b) => a + b, 0) / values.length,
        min: Math.min(...values),
        count: values.length,
      }
    }
  }
  return { stations: stations.length, stats }
}

const cheapestOf = (stations: Station[], key: FuelKey, n: number): Entry[] =>
  stations
    .flatMap((station) => (station.prices[key] ? [{ station, ...station.prices[key] }] : []))
    .sort((a, b) => a.price - b.price || b.at.localeCompare(a.at))
    .slice(0, n)

type RawStation = [number, number, number, string, string, string, string, [string, number, boolean, string][]]

function buildReport(raw: { extracted: string; source?: string; stations: RawStation[] }): FuelReport {
  const extracted = raw.extracted
  const from = new Date(`${extracted}T00:00:00Z`)
  from.setUTCDate(from.getUTCDate() - WINDOW_DAYS)
  const windowFrom = from.toISOString().slice(0, 10)

  // Prezzi recenti per voce; per GPL e metano conta il migliore tra self e servito
  type Candidate = { key: FuelKey; price: number; at: string }
  const parsed = raw.stations.flatMap(([id, lat, lon, brand, , address, , prices]) => {
    const place = parseAddress(address)
    if (!place || !provinceByCode.has(place.prov)) return []
    const candidates: Candidate[] = []
    for (const [fuel, price, self, at] of prices) {
      if (at.slice(0, 10) < windowFrom || typeof price !== 'number') continue
      if (fuel === 'Benzina' || fuel === 'Gasolio') candidates.push({ key: `${fuel}|${self ? 'self' : 'servito'}` as FuelKey, price, at })
      else if (fuel === 'GPL' || fuel === 'Metano') candidates.push({ key: `${fuel}|any` as FuelKey, price, at })
    }
    return [{ id, lat, lon, brand: brandName(brand), ...place, candidates }]
  })

  // Prezzi anomali (errori di inserimento o prezzi rimasti indietro): prima i refusi grossolani
  // rispetto alla mediana nazionale, poi chi è troppo lontano dalla mediana della sua provincia
  const pricesOf = (list: typeof parsed, key: FuelKey) =>
    list.flatMap((s) => s.candidates.filter((c) => c.key === key).map((c) => c.price))
  const national = Object.fromEntries(fuels.map(({ key }) => [key, median(pricesOf(parsed, key))])) as Record<FuelKey, number>

  const parsedByProvince = new Map<string, typeof parsed>()
  for (const s of parsed) parsedByProvince.set(s.prov, [...(parsedByProvince.get(s.prov) ?? []), s])

  const stations: Station[] = [...parsedByProvince.values()].flatMap((list) => {
    const local = Object.fromEntries(
      fuels.map(({ key }) => {
        const sane = pricesOf(list, key).filter((p) => p > national[key] * 0.5 && p < national[key] * 2)
        return [key, sane.length >= 8 ? median(sane) : national[key]]
      }),
    ) as Record<FuelKey, number>
    return list.map(({ candidates, ...s }) => {
      const best: Station['prices'] = {}
      for (const c of candidates) {
        const [low, high] = BANDS[c.key.split('|')[0] as keyof typeof BANDS]
        if (c.price < local[c.key] * low || c.price > local[c.key] * high) continue
        const prev = best[c.key]
        if (!prev || c.price < prev.price) best[c.key] = { price: c.price, at: c.at }
      }
      return { ...s, prices: best }
    })
  })

  const byProvince = new Map<string, Station[]>()
  for (const s of stations) byProvince.set(s.prov, [...(byProvince.get(s.prov) ?? []), s])

  const provinceReports: ProvinceReport[] = provinces.map((province) => {
    const list = byProvince.get(province.code) ?? []
    const byTown = new Map<string, Station[]>()
    for (const s of list) byTown.set(s.town, [...(byTown.get(s.town) ?? []), s])
    return {
      province,
      summary: summarize(list),
      cheapest: Object.fromEntries(fuels.map(({ key }) => [key, cheapestOf(list, key, 10)])),
      towns: [...byTown]
        .filter(([, l]) => l.length >= 3)
        .sort((a, b) => b[1].length - a[1].length || a[0].localeCompare(b[0], 'it'))
        .slice(0, 15)
        .map(([name, l]) => ({ name, summary: summarize(l) })),
    }
  })

  const regionNames = [...new Set(provinces.map((p) => p.region))]
  return {
    extracted,
    windowFrom,
    source: raw.source ?? 'MIMIT - Osservaprezzi carburanti',
    national: summarize(stations),
    provinces: provinceReports,
    regions: regionNames.map((name) => {
      const reports = provinceReports.filter((r) => r.province.region === name)
      return { name, provinces: reports, summary: summarize(stations.filter((s) => provinceByCode.get(s.prov)?.region === name)) }
    }),
  }
}

let loading: Promise<FuelReport | null> | undefined

/**
 * Il dataset, scaricato una volta per build. In CI un errore ferma la build (resta online la
 * versione precedente del sito); in locale le pagine dei carburanti vengono saltate.
 */
export const getFuelReport = () =>
  (loading ??= (async () => {
    try {
      const res = await fetch(FUEL_SOURCE, { headers: { 'User-Agent': 'navia-website-build' } })
      if (!res.ok) throw new Error(`HTTP ${res.status}`)
      let body = Buffer.from(await res.arrayBuffer())
      if (body[0] === 0x1f && body[1] === 0x8b) body = gunzipSync(body)
      return buildReport(JSON.parse(body.toString('utf8')))
    } catch (error) {
      if (process.env.CI) throw new Error(`Prezzi dei carburanti non disponibili: ${error}`)
      console.warn(`[carburanti] dati non disponibili, pagine saltate: ${error}`)
      return null
    }
  })())

// ---------- Formati ----------

const priceFormat = new Intl.NumberFormat('it-IT', { minimumFractionDigits: 3, maximumFractionDigits: 3 })
const centsFormat = new Intl.NumberFormat('it-IT', { maximumFractionDigits: 1, signDisplay: 'exceptZero' })

export const fmtPrice = (n: number) => priceFormat.format(n)
/** Differenza in centesimi: "−2,1", "+0,4", "0" */
export const fmtCents = (n: number) => centsFormat.format(Math.round(n * 1000) / 10).replace('-', '−')
export const fmtDay = (iso: string) =>
  new Intl.DateTimeFormat('it-IT', { day: 'numeric', month: 'long', year: 'numeric', timeZone: 'UTC' }).format(new Date(`${iso.slice(0, 10)}T12:00:00Z`))
export const fmtWhen = (at: string) => {
  const [date, time] = at.split('T')
  const day = new Intl.DateTimeFormat('it-IT', { day: 'numeric', month: 'short', timeZone: 'UTC' }).format(new Date(`${date}T12:00:00Z`))
  return time ? `${day}, ${time}` : day
}
export const osmLink = (s: Station) =>
  `https://www.openstreetmap.org/?mlat=${s.lat}&mlon=${s.lon}#map=18/${s.lat}/${s.lon}`
