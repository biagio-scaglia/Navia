"""Writes the catalog of Navia's downloadable maps.

Usage: python tool/maps/build_manifest.py DIR

DIR contains map-<region>.pmtiles files built by Planetiler. The catalog
(DIR/manifest.json) lists every region with its size, checksum, bounding
box and maximum zoom, read from the PMTiles header; the app reads it to
offer the downloads.
"""

import datetime
import hashlib
import json
import os
import struct
import sys

# Geofabrik's Italian sub-regions, with the names shown in the app; the
# same as the offline places (tool/places/build_manifest.py).
REGIONS = {
    'nord-ovest': ('Nord-Ovest', 'Piemonte, Valle d’Aosta, Liguria, Lombardia'),
    'nord-est': (
        'Nord-Est',
        'Trentino-Alto Adige, Veneto, Friuli-Venezia Giulia, Emilia-Romagna',
    ),
    'centro': ('Centro', 'Toscana, Umbria, Marche, Lazio'),
    'sud': ('Sud', 'Abruzzo, Molise, Campania, Puglia, Basilicata, Calabria'),
    'isole': ('Isole', 'Sicilia, Sardegna'),
}


def sha256(path):
    digest = hashlib.sha256()
    with open(path, 'rb') as file:
        for chunk in iter(lambda: file.read(1 << 20), b''):
            digest.update(chunk)
    return digest.hexdigest()


def header(path):
    """Zoom range and bounds of a PMTiles v3 archive."""
    with open(path, 'rb') as file:
        data = file.read(127)
    if len(data) != 127 or data[:7] != b'PMTiles' or data[7] != 3:
        raise SystemExit(f'{path} is not a PMTiles v3 archive')
    min_zoom, max_zoom = data[100], data[101]
    west, south, east, north = (
        value / 1e7 for value in struct.unpack('<4i', data[102:118])
    )
    return {
        'minzoom': min_zoom,
        'maxzoom': max_zoom,
        'bbox': [round(south, 5), round(west, 5), round(north, 5), round(east, 5)],
    }


def main(directory):
    generated = datetime.datetime.now(datetime.timezone.utc).replace(microsecond=0)
    regions = []
    for region_id, (name, detail) in REGIONS.items():
        data = os.path.join(directory, f'map-{region_id}.pmtiles')
        if not os.path.exists(data):
            continue
        regions.append({
            'id': region_id,
            'name': name,
            'detail': detail,
            'file': os.path.basename(data),
            'bytes': os.path.getsize(data),
            'sha256': sha256(data),
            **header(data),
        })
    manifest = {
        'version': 1,
        'generated': generated.isoformat().replace('+00:00', 'Z'),
        'source': 'Geofabrik extracts of OpenStreetMap, built with Planetiler',
        'schema': 'OpenMapTiles',
        'license': 'ODbL-1.0',
        'attribution': '© OpenMapTiles © OpenStreetMap contributors',
        'regions': regions,
    }
    with open(os.path.join(directory, 'manifest.json'), 'w', encoding='utf-8') as file:
        json.dump(manifest, file, ensure_ascii=False, indent=2)
    print(f'{len(regions)} regions')


if __name__ == '__main__':
    if len(sys.argv) != 2:
        sys.exit('usage: build_manifest.py DIR')
    main(sys.argv[1])
