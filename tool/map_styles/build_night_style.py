"""Builds the "Navia Notte" map style from OpenFreeMap Liberty.

Liberty has the most detail (points of interest, parks, water, building
heights) but is designed for daylight; OpenFreeMap's dark style keeps too
little contrast to find your way. This script keeps Liberty's layers,
sources, sprites and fonts and recolors them for night use:

- dark navy land, deep blue water, muted dark greens;
- roads lighter than the land, major roads warmer, casings almost black;
- light labels with a dark halo.

Usage (from the repository root):

    python tool/map_styles/build_night_style.py

It downloads the current Liberty style and writes
assets/map_styles/navia_night.json. Commit the result.
"""

import colorsys
import json
import os
import re
import urllib.request

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
SOURCE = 'https://tiles.openfreemap.org/styles/liberty'
TARGET = os.path.join(ROOT, 'assets', 'map_styles', 'navia_night.json')

LAND = '#0f1726'
WATER = '#16314f'
WATERWAY = '#24507a'
BUILDING = '#1e2738'
BUILDING_3D = '#283349'
HALO = 'rgba(10,16,28,0.9)'

COLOR = re.compile(r'^(#[0-9a-fA-F]{3,8}|rgba?\(.*\)|hsla?\(.*\))$')


def parse(color):
    """Returns (h, l, s, a) with components in 0..1."""
    color = color.strip()
    if color.startswith('#'):
        digits = color[1:]
        if len(digits) in (3, 4):
            digits = ''.join(c * 2 for c in digits)
        r, g, b = (int(digits[i:i + 2], 16) / 255 for i in (0, 2, 4))
        a = int(digits[6:8], 16) / 255 if len(digits) == 8 else 1.0
        h, l, s = colorsys.rgb_to_hls(r, g, b)
        return h, l, s, a
    name, values = color.split('(', 1)
    parts = [p.strip() for p in values.rstrip(')').split(',')]
    a = float(parts[3]) if len(parts) > 3 else 1.0
    if name.startswith('rgb'):
        r, g, b = (float(p) / 255 for p in parts[:3])
        h, l, s = colorsys.rgb_to_hls(r, g, b)
        return h, l, s, a
    h = float(parts[0]) / 360
    s = float(parts[1].rstrip('%')) / 100
    l = float(parts[2].rstrip('%')) / 100
    return h, l, s, a


def css(h, l, s, a=1.0):
    r, g, b = colorsys.hls_to_rgb(h, max(0, min(1, l)), max(0, min(1, s)))
    return f'rgba({round(r * 255)},{round(g * 255)},{round(b * 255)},{round(a, 3)})'


def recolor(layer, prop, color):
    """Night color for [color], used by [prop] of [layer]."""
    lid = layer['id']
    kind = layer['type']
    source_layer = layer.get('source-layer', '')
    h, l, s, a = parse(color)

    if prop == 'background-color':
        return LAND
    if prop == 'text-halo-color':
        return HALO
    if prop == 'text-color':
        if 'water' in lid:
            return css(0.58, 0.72, 0.55)
        if source_layer == 'transportation_name':
            return css(0.6, 0.76, 0.18)
        if source_layer == 'poi':
            return css(h, 0.78, min(s, 0.35))
        return css(0.6, 0.9, 0.2)
    if source_layer == 'water' or lid == 'water':
        return css(*parse(WATER)[:3], a)
    if source_layer == 'waterway':
        return WATERWAY
    if prop == 'fill-extrusion-color':
        return BUILDING_3D
    if source_layer == 'building':
        return BUILDING
    if source_layer == 'transportation':
        if 'casing' in lid:
            return css(h, 0.07, min(s, 0.3), a)
        if 'path' in lid or 'pedestrian' in lid:
            return css(h, 0.34, s * 0.3, a)
        if 'rail' in lid:
            return css(0.6, 0.36, 0.1, a)
        # Lighter than the land; warm hues (major roads) keep some color.
        return css(h, 0.24 + 0.2 * l, s * 0.4, a)
    if source_layer == 'boundary':
        return css(0.62, 0.45, 0.15, a)
    if kind in ('fill', 'line'):
        # Land use and land cover: dark, low saturation, hue kept.
        return css(h, 0.1 + (1 - l) * 0.28, s * 0.45, a)
    return color


def transform(layer, prop, value):
    if isinstance(value, str) and COLOR.match(value):
        return recolor(layer, prop, value)
    if isinstance(value, list):
        return [transform(layer, prop, v) for v in value]
    if isinstance(value, dict):
        return {k: transform(layer, prop, v) for k, v in value.items()}
    return value


def build(style):
    style = json.loads(json.dumps(style))
    style['name'] = 'Navia Notte'
    for layer in style['layers']:
        paint = layer.setdefault('paint', {})
        for prop in list(paint):
            if 'color' in prop:
                paint[prop] = transform(layer, prop, paint[prop])
        if layer['type'] == 'background':
            paint['background-color'] = LAND
        if layer['type'] == 'raster':
            # Darkens the shaded relief shown at low zoom.
            paint['raster-brightness-max'] = 0.3
            paint['raster-saturation'] = -0.6
        if layer['type'] == 'symbol' and 'text-color' not in paint:
            if 'text-field' in layer.get('layout', {}):
                paint['text-color'] = css(0.6, 0.85, 0.2)
                paint['text-halo-color'] = HALO
                paint.setdefault('text-halo-width', 1.2)
        if layer['type'] == 'line' and 'line-color' not in paint:
            if layer.get('source-layer') == 'transportation':
                paint['line-color'] = css(0.08, 0.5, 0.45)
    return style


def main():
    request = urllib.request.Request(
        SOURCE,
        headers={'User-Agent': 'Navia style build (+https://github.com/biagio-scaglia/Navia)'},
    )
    with urllib.request.urlopen(request) as response:
        liberty = json.load(response)
    os.makedirs(os.path.dirname(TARGET), exist_ok=True)
    with open(TARGET, 'w', encoding='utf-8', newline='\n') as file:
        json.dump(build(liberty), file, ensure_ascii=False, separators=(',', ':'))
        file.write('\n')
    print(TARGET)


if __name__ == '__main__':
    main()
