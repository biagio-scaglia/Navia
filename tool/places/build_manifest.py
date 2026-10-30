"""Writes the catalog of Navia's place datasets.

Usage: python tool/places/build_manifest.py DIR

DIR contains places-<region>.jsonl.gz files and, for each, the
places-<region>.json summary printed by build_places.py. The catalog
(DIR/manifest.json) lists every region with its size, checksum, number of
places and bounding box; the app reads it to offer the downloads.
"""

import datetime
import hashlib
import json
import os
import sys

# Geofabrik's Italian sub-regions, with the names shown in the app.
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


def main(directory):
    generated = datetime.datetime.now(datetime.timezone.utc).replace(microsecond=0)
    regions = []
    for region_id, (name, detail) in REGIONS.items():
        data = os.path.join(directory, f'places-{region_id}.jsonl.gz')
        summary_path = os.path.join(directory, f'places-{region_id}.json')
        if not os.path.exists(data) or not os.path.exists(summary_path):
            continue
        with open(summary_path, encoding='utf-8') as file:
            summary = json.load(file)
        regions.append({
            'id': region_id,
            'name': name,
            'detail': detail,
            'file': os.path.basename(data),
            'bytes': os.path.getsize(data),
            'sha256': sha256(data),
            'count': summary['count'],
            'bbox': summary['bbox'],
        })
    manifest = {
        'version': 1,
        'generated': generated.isoformat().replace('+00:00', 'Z'),
        'source': 'Geofabrik extracts of OpenStreetMap',
        'license': 'ODbL-1.0',
        'attribution': '© OpenStreetMap contributors',
        'regions': regions,
    }
    with open(os.path.join(directory, 'manifest.json'), 'w', encoding='utf-8') as file:
        json.dump(manifest, file, ensure_ascii=False, indent=2)
    print(f'{len(regions)} regions')


if __name__ == '__main__':
    if len(sys.argv) != 2:
        sys.exit('usage: build_manifest.py DIR')
    main(sys.argv[1])
