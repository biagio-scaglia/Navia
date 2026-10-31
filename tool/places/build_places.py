"""Builds Navia's downloadable place datasets from OpenStreetMap extracts.

Reads an .osm.pbf extract (for example a Geofabrik region), keeps only the
objects that belong to a Navia place category (tool/places/poi_tags.json)
and writes them as gzipped JSON lines, one place per line:

    {"id": "node/123", "lat": 41.12, "lon": 16.87, "tags": {...}}

Only the tags the app displays are kept. Ways use the average of their
nodes, multipolygon relations the average of their outer rings.

Usage (requires pyosmium 4: pip install osmium):

    python tool/places/build_places.py sud.osm.pbf out/places-sud.jsonl.gz

The output is derived from OpenStreetMap data and is licensed under the
Open Database License (ODbL) 1.0, like its source.
"""

import gzip
import json
import os
import sys

import osmium
import osmium.filter

HERE = os.path.dirname(os.path.abspath(__file__))

KEEP_TAGS = {
    'name', 'name:it', 'amenity', 'shop', 'tourism', 'leisure', 'natural',
    'railway',
    'highway', 'addr:street', 'addr:housenumber', 'addr:city',
    'opening_hours', 'website', 'contact:website', 'phone', 'contact:phone',
    'cuisine', 'wheelchair', 'wikidata', 'wikipedia',
}


def category_tags():
    with open(os.path.join(HERE, 'poi_tags.json'), encoding='utf-8') as file:
        categories = json.load(file)
    return sorted({
        (key, value)
        for tags in categories.values()
        for key, values in tags.items()
        for value in values
    })


def _mean(points):
    if not points:
        return None
    lat = sum(p[0] for p in points) / len(points)
    lon = sum(p[1] for p in points) / len(points)
    return round(lat, 6), round(lon, 6)


def _way_center(way):
    points = []
    for node in way.nodes:
        if node.location.valid():
            points.append((node.location.lat, node.location.lon))
    # A closed way repeats its first node at the end.
    if len(points) > 1 and points[0] == points[-1]:
        points.pop()
    return _mean(points)


def _area_center(area):
    points = []
    for ring in area.outer_rings():
        ring_points = [(n.lat, n.lon) for n in ring if n.location.valid()]
        if len(ring_points) > 1 and ring_points[0] == ring_points[-1]:
            ring_points.pop()
        points.extend(ring_points)
    return _mean(points)


def _tags(obj):
    return {tag.k: tag.v for tag in obj.tags if tag.k in KEEP_TAGS and tag.v.strip()}


def build(source, target):
    wanted = category_tags()
    processor = (
        osmium.FileProcessor(source)
        .with_locations()
        .with_areas(osmium.filter.TagFilter(*wanted))
        .with_filter(osmium.filter.TagFilter(*wanted))
    )
    count = 0
    south = west = 90.0
    north = east = -90.0
    west, east = 180.0, -180.0
    with gzip.open(target, 'wt', encoding='utf-8', compresslevel=9) as out:
        for obj in processor:
            if obj.is_node():
                if not obj.location.valid():
                    continue
                ref = f'node/{obj.id}'
                center = (round(obj.location.lat, 6), round(obj.location.lon, 6))
            elif obj.is_way():
                ref = f'way/{obj.id}'
                center = _way_center(obj)
            elif obj.is_area():
                # Closed ways are already handled as ways.
                if obj.from_way():
                    continue
                ref = f'relation/{obj.orig_id()}'
                center = _area_center(obj)
            else:
                continue
            if center is None:
                continue
            lat, lon = center
            south, north = min(south, lat), max(north, lat)
            west, east = min(west, lon), max(east, lon)
            line = {'id': ref, 'lat': lat, 'lon': lon, 'tags': _tags(obj)}
            out.write(json.dumps(line, ensure_ascii=False, separators=(',', ':')))
            out.write('\n')
            count += 1
    return {
        'count': count,
        'bbox': [round(south, 4), round(west, 4), round(north, 4), round(east, 4)],
    }


if __name__ == '__main__':
    if len(sys.argv) != 3:
        sys.exit('usage: build_places.py SOURCE.osm.pbf TARGET.jsonl.gz')
    summary = build(sys.argv[1], sys.argv[2])
    print(json.dumps(summary))
