"""Builds Navia's daily fuel price dataset from the Ministry's data.

The app cannot always reach the Ministry (MIMIT) from every network, so
this dataset is published as a release asset next to the place data. It
has the same format the app writes when it joins the Ministry files itself:

    {"version": 1, "extracted": "YYYY-MM-DD", "source": ..., "license": ...,
     "stations": [[id, lat, lon, brand, name, address, town,
                   [[fuel, price, self, "YYYY-MM-DDTHH:MM"], ...]], ...]}

Sources, in order:

1. the open data files (registry and prices at 8:00) on www.mimit.gov.it;
2. the Osservaprezzi API of carburanti.mise.gov.it, one request per
   region, used when www.mimit.gov.it does not answer GitHub's machines.
   Stations it returns without coordinates or details take them from the
   previously published dataset, when given.

Nothing is written when the result looks incomplete, so the published
dataset stays the previous one.

Usage:

    python tool/fuel/build_fuel_prices.py out/fuel-prices.json.gz \\
        [previous/fuel-prices.json.gz]

The data comes from MIMIT - Osservaprezzi carburanti, under the Italian
Open Data License 2.0 (IODL 2.0).
"""

import gzip
import json
import re
import sys
import urllib.request
from datetime import datetime
from zoneinfo import ZoneInfo

CSV_URL = 'https://www.mimit.gov.it/images/exportCSV/'
API_URL = 'https://carburanti.mise.gov.it/ospzApi'
USER_AGENT = 'Navia fuel-data (+https://github.com/biagio-scaglia/Navia)'
ROME = ZoneInfo('Europe/Rome')

# About 22,000 stations report prices: far fewer means a truncated answer.
MIN_STATIONS = 15_000


def get(url, body=None, timeout=60):
    data = json.dumps(body).encode() if body is not None else None
    headers = {'User-Agent': USER_AGENT, 'Accept': 'application/json'}
    if data is not None:
        headers['Content-Type'] = 'application/json'
    request = urllib.request.Request(url, data=data, headers=headers)
    with urllib.request.urlopen(request, timeout=timeout) as response:
        return response.read()


def text(raw):
    try:
        return raw.decode('utf-8')
    except UnicodeDecodeError:
        return raw.decode('latin-1')


def plausible(lat, lon, price):
    return 35 < lat < 48 and 6 < lon < 19 and 0.3 < price < 5


def clean(value):
    return re.sub(' +', ' ', (value or '').strip())


def ministry_time(value):
    """"23/10/2026 20:00:07" as "2026-10-23T20:00"."""
    match = re.match(r'^(\d{2})/(\d{2})/(\d{4}) (\d{2}):(\d{2})', value.strip())
    if not match:
        return None
    day, month, year, hour, minute = match.groups()
    return f'{year}-{month}-{day}T{hour}:{minute}'


def from_csv():
    """Joins the registry and price files, like the app does."""
    stations_csv = text(get(CSV_URL + 'anagrafica_impianti_attivi.csv', timeout=45))
    prices_csv = text(get(CSV_URL + 'prezzo_alle_8.csv', timeout=45))
    station_lines = stations_csv.splitlines()
    price_lines = prices_csv.splitlines()
    extracted = station_lines[0].replace('Estrazione del', '').strip()
    datetime.strptime(extracted, '%Y-%m-%d')
    station_header = station_lines[1].split('|')
    price_header = price_lines[1].split('|')
    s = {name: station_header.index(name) for name in station_header}
    p = {name: price_header.index(name) for name in price_header}

    prices = {}
    for line in price_lines[2:]:
        fields = line.split('|')
        if len(fields) < len(price_header):
            continue
        try:
            value = float(fields[p['prezzo']])
        except ValueError:
            continue
        reported = ministry_time(fields[p['dtComu']])
        fuel = fields[p['descCarburante']].strip()
        if reported is None or not fuel or not 0.3 < value < 5:
            continue
        prices.setdefault(fields[p['idImpianto']], []).append(
            [fuel, round(value, 3), fields[p['isSelf']] == '1', reported])

    def column(fields, name):
        # A "|" inside a name shifts the later columns: read those from
        # the end of the line.
        index = s[name]
        if index > s['Nome Impianto']:
            index = len(fields) - (len(station_header) - index)
        return clean(fields[index]) if 0 <= index < len(fields) else ''

    stations = []
    for line in station_lines[2:]:
        fields = line.split('|')
        if len(fields) < len(station_header):
            continue
        entries = prices.get(fields[s['idImpianto']])
        try:
            station_id = int(fields[s['idImpianto']])
            lat = float(column(fields, 'Latitudine'))
            lon = float(column(fields, 'Longitudine'))
        except ValueError:
            continue
        if not entries or not 35 < lat < 48 or not 6 < lon < 19:
            continue
        stations.append([
            station_id, lat, lon,
            column(fields, 'Bandiera'), column(fields, 'Nome Impianto'),
            column(fields, 'Indirizzo'), column(fields, 'Comune'),
            entries,
        ])
    return extracted, stations


def api_time(value, fallback):
    try:
        moment = datetime.fromisoformat(str(value).replace('Z', '+00:00'))
    except ValueError:
        return fallback
    if moment.tzinfo is not None:
        moment = moment.astimezone(ROME)
    return moment.strftime('%Y-%m-%dT%H:%M')


def from_api(previous):
    """All stations with their current prices, one request per region."""
    now = datetime.now(ROME)
    fallback = now.strftime('%Y-%m-%dT%H:%M')
    regions = json.loads(get(API_URL + '/registry/region'))['results']
    stations = {}
    for region in regions:
        answer = json.loads(
            get(API_URL + '/search/area', {'region': int(region['id'])}, timeout=120))
        for item in answer.get('results') or []:
            station_id = item.get('id')
            if not isinstance(station_id, int) or station_id in stations:
                continue
            known = previous.get(station_id)
            location = item.get('location') or {}
            lat, lon = location.get('lat'), location.get('lng')
            if not isinstance(lat, (int, float)) or not isinstance(lon, (int, float)):
                if known is None:
                    continue
                lat, lon = known[1], known[2]
            reported = api_time(item.get('insertDate'), fallback)
            entries = [
                [clean(fuel.get('name')), round(float(fuel['price']), 3),
                 bool(fuel.get('isSelf')), reported]
                for fuel in item.get('fuels') or []
                if isinstance(fuel.get('price'), (int, float)) and clean(fuel.get('name'))
                and plausible(lat, lon, float(fuel['price']))
            ]
            if not entries:
                continue
            stations[station_id] = [
                station_id, round(float(lat), 6), round(float(lon), 6),
                clean(item.get('brand')) or (known[3] if known else ''),
                clean(item.get('name')) or (known[4] if known else ''),
                clean(item.get('address')) or (known[5] if known else ''),
                known[6] if known else '',
                entries,
            ]
        print(f'Region {region["id"]}: {len(answer.get("results") or [])} stations.',
              file=sys.stderr)
    return now.date().isoformat(), list(stations.values())


def read_previous(path):
    if not path:
        return {}
    try:
        with gzip.open(path, 'rt', encoding='utf-8') as file:
            return {entry[0]: entry for entry in json.load(file)['stations']}
    except (OSError, ValueError, KeyError) as error:
        print(f'Previous dataset not used: {error}', file=sys.stderr)
        return {}


def main():
    out = sys.argv[1]
    previous = read_previous(sys.argv[2] if len(sys.argv) > 2 else None)
    try:
        extracted, stations = from_csv()
        source = 'csv'
    except Exception as error:  # noqa: BLE001 - any failure moves on to the API
        print(f'Ministry files unavailable ({error}): using the API.', file=sys.stderr)
        extracted, stations = from_api(previous)
        source = 'api'
    if len(stations) < MIN_STATIONS:
        sys.exit(f'Only {len(stations)} stations from the {source}: not published.')
    stations.sort(key=lambda entry: entry[0])
    dataset = {
        'version': 1,
        'extracted': extracted,
        'source': 'MIMIT - Osservaprezzi carburanti',
        'license': 'IODL-2.0',
        'stations': stations,
    }
    with gzip.open(out, 'wt', encoding='utf-8') as file:
        json.dump(dataset, file, ensure_ascii=False, separators=(',', ':'))
    print(json.dumps({
        'extracted': extracted,
        'from': source,
        'stations': len(stations),
        'prices': sum(len(entry[7]) for entry in stations),
    }))


if __name__ == '__main__':
    main()
