"""Builds Navia's fuel price dataset from the Italian Ministry open data.

The Ministero delle Imprese e del Made in Italy (MIMIT, "Osservaprezzi
carburanti") publishes every day the list of active fuel stations and the
prices they reported, under the Italian Open Data License 2.0:

    anagrafica_impianti_attivi.csv  stations: id, operator, brand, name,
                                    address, town, province, coordinates
    prezzo_alle_8.csv               prices valid at 8:00: station id, fuel,
                                    price, self service flag, report time

Both are pipe-separated and start with an "Estrazione del YYYY-MM-DD" line.
This script joins them into one gzipped JSON file:

    {"version": 1, "extracted": "2026-10-30", "license": "IODL-2.0",
     "stations": [[id, lat, lon, brand, name, address, town,
                   [[fuel, price, self, "YYYY-MM-DDTHH:MM"], ...]], ...]}

Usage: python tool/fuel/build_fuel_prices.py OUT_DIR
"""

import csv
import datetime
import gzip
import io
import json
import os
import sys
import urllib.request

BASE = 'https://www.mimit.gov.it/images/exportCSV'
AGENT = 'Navia fuel data (+https://github.com/biagio-scaglia/Navia)'


def fetch(name):
    request = urllib.request.Request(f'{BASE}/{name}', headers={'User-Agent': AGENT})
    with urllib.request.urlopen(request, timeout=120) as response:
        return response.read().decode('utf-8', errors='replace')


def rows(text):
    lines = text.splitlines()
    extracted = lines[0].replace('Estrazione del', '').strip()
    reader = csv.reader(io.StringIO('\n'.join(lines[1:])), delimiter='|')
    header = next(reader)
    return extracted, [dict(zip(header, row)) for row in reader if len(row) >= len(header)]


def parse_time(value):
    try:
        return datetime.datetime.strptime(value.strip(), '%d/%m/%Y %H:%M:%S').strftime('%Y-%m-%dT%H:%M')
    except ValueError:
        return None


def build(stations_text, prices_text):
    extracted, stations = rows(stations_text)
    _, prices = rows(prices_text)

    by_station = {}
    for price in prices:
        try:
            value = round(float(price['prezzo']), 3)
        except (KeyError, ValueError):
            continue
        reported = parse_time(price.get('dtComu', ''))
        fuel = price.get('descCarburante', '').strip()
        # Implausible values are reporting mistakes.
        if not fuel or reported is None or not 0.3 < value < 5:
            continue
        by_station.setdefault(price['idImpianto'], []).append(
            [fuel, value, price.get('isSelf') == '1', reported]
        )

    out = []
    for station in stations:
        entries = by_station.get(station.get('idImpianto'))
        if not entries:
            continue
        try:
            lat = round(float(station['Latitudine']), 6)
            lon = round(float(station['Longitudine']), 6)
        except (KeyError, ValueError):
            continue
        # Stations with coordinates outside Italy are data errors.
        if not (35 < lat < 48 and 6 < lon < 19):
            continue
        out.append([
            int(station['idImpianto']),
            lat,
            lon,
            station.get('Bandiera', '').strip(),
            station.get('Nome Impianto', '').strip(),
            ' '.join(station.get('Indirizzo', '').split()),
            station.get('Comune', '').strip(),
            sorted(entries),
        ])
    return {
        'version': 1,
        'extracted': extracted,
        'source': 'MIMIT - Osservaprezzi carburanti',
        'license': 'IODL-2.0',
        'stations': out,
    }


def main(out_dir):
    os.makedirs(out_dir, exist_ok=True)
    data = build(fetch('anagrafica_impianti_attivi.csv'), fetch('prezzo_alle_8.csv'))
    target = os.path.join(out_dir, 'fuel-prices.json.gz')
    with gzip.open(target, 'wt', encoding='utf-8', compresslevel=9) as file:
        json.dump(data, file, ensure_ascii=False, separators=(',', ':'))
    print(json.dumps({'stations': len(data['stations']), 'extracted': data['extracted'],
                      'bytes': os.path.getsize(target)}))


if __name__ == '__main__':
    if len(sys.argv) != 2:
        sys.exit('usage: build_fuel_prices.py OUT_DIR')
    try:
        main(sys.argv[1])
    except Exception as error:  # Reported as a GitHub annotation, then fails.
        print(f'::error title=Fuel data::{type(error).__name__}: {error}')
        raise
