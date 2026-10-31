"""Builds the "Navia Essenziale" map style from OpenFreeMap Liberty.

OpenFreeMap's Positron is clean but drops points of interest, parks
details and building heights. This style keeps every Liberty layer and
mutes the palette instead: light gray land, soft blue water, pale greens,
white roads with light casings and gray labels, so routes and Navia's own
markers stand out.

Usage (from the repository root):

    python tool/map_styles/build_essential_style.py
"""

import json
import os
import urllib.request

import build_night_style as common

TARGET = os.path.join(common.ROOT, 'assets', 'map_styles', 'navia_essential.json')

LAND = '#f3f4f6'
WATER = '#cbdcee'
WATERWAY = '#b3cbe4'
BUILDING = '#e3e5e9'
BUILDING_3D = '#e8eaee'
HALO = 'rgba(255,255,255,0.9)'


def recolor(layer, prop, color):
    lid = layer['id']
    kind = layer['type']
    source_layer = layer.get('source-layer', '')
    h, l, s, a = common.parse(color)

    if prop == 'background-color':
        return LAND
    if prop == 'text-halo-color':
        return HALO
    if prop == 'text-color':
        if 'water' in lid:
            return common.css(0.58, 0.45, 0.35)
        if source_layer == 'poi':
            return common.css(h, 0.42, min(s, 0.25))
        return common.css(0.6, 0.3, 0.12)
    if source_layer == 'water' or lid == 'water':
        return common.css(*common.parse(WATER)[:3], a)
    if source_layer == 'waterway':
        return WATERWAY
    if prop == 'fill-extrusion-color':
        return BUILDING_3D
    if source_layer == 'building':
        return BUILDING
    if source_layer == 'transportation':
        if 'casing' in lid:
            return common.css(0.6, 0.8, 0.08, a)
        if 'rail' in lid:
            return common.css(0.6, 0.72, 0.06, a)
        # White minor roads; major roads keep a faint warm tint.
        return common.css(h, 0.97, s * 0.35, a)
    if source_layer == 'boundary':
        return common.css(0.62, 0.7, 0.08, a)
    if kind in ('fill', 'line'):
        return common.css(h, 0.9, s * 0.3, a)
    return color


def transform(layer, prop, value):
    if isinstance(value, str) and common.COLOR.match(value):
        return recolor(layer, prop, value)
    if isinstance(value, list):
        return [transform(layer, prop, v) for v in value]
    if isinstance(value, dict):
        return {k: transform(layer, prop, v) for k, v in value.items()}
    return value


def build(style):
    style = json.loads(json.dumps(style))
    style['name'] = 'Navia Essenziale'
    for layer in style['layers']:
        paint = layer.setdefault('paint', {})
        for prop in list(paint):
            if 'color' in prop:
                paint[prop] = transform(layer, prop, paint[prop])
        if layer['type'] == 'background':
            paint['background-color'] = LAND
        if layer['type'] == 'raster':
            paint['raster-saturation'] = -0.8
            paint['raster-opacity'] = 0.4
        if layer['type'] == 'line' and 'line-color' not in paint:
            if layer.get('source-layer') == 'transportation':
                paint['line-color'] = common.css(0.1, 0.94, 0.35)
    return style


def main():
    request = urllib.request.Request(
        common.SOURCE,
        headers={'User-Agent': 'Navia style build (+https://github.com/biagio-scaglia/Navia)'},
    )
    with urllib.request.urlopen(request) as response:
        liberty = json.load(response)
    with open(TARGET, 'w', encoding='utf-8', newline='\n') as file:
        json.dump(build(liberty), file, ensure_ascii=False, separators=(',', ':'))
        file.write('\n')
    print(TARGET)


if __name__ == '__main__':
    main()
