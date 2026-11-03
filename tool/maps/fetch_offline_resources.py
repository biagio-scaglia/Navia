"""Downloads the resources that downloaded maps need on the device.

Usage: python tool/maps/fetch_offline_resources.py

Writes to assets/map_offline/:
- styles/liberty.json and styles/bright.json: copies of the OpenFreeMap
  styles, so that Standard and Vivace can also be drawn without a
  connection (Essenziale and Notte are already bundled);
- fonts/<font>/<range>.pbf: the glyphs of the fonts used by the styles, for
  the Unicode ranges of Italian and neighbouring languages. Font folders
  have no spaces (Noto Sans Regular -> noto-sans-regular); the app renames
  the fonts in the offline styles to match;
- sprites/ofm*.{json,png}: the icon sprite at 1x and 2x.

Rerun it when the OpenFreeMap styles change their fonts or sprite.
"""

import json
import os
import urllib.parse
import urllib.request

BASE = 'https://tiles.openfreemap.org'
STYLES = {'liberty': f'{BASE}/styles/liberty', 'bright': f'{BASE}/styles/bright'}

# Basic Latin to combining marks, and general punctuation (’ – …).
RANGES = ['0-255', '256-511', '512-767', '768-1023', '8192-8447']

ROOT = os.path.join(
    os.path.dirname(__file__), '..', '..', 'assets', 'map_offline'
)
USER_AGENT = 'Navia map resources (+https://github.com/biagio-scaglia/Navia)'


def fetch(url):
    request = urllib.request.Request(url, headers={'User-Agent': USER_AGENT})
    with urllib.request.urlopen(request, timeout=60) as response:
        return response.read()


def write(path, content):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, 'wb') as file:
        file.write(content)


def font_folder(name):
    return name.lower().replace(' ', '-')


def main():
    fonts = set()
    sprites = set()
    for name, url in STYLES.items():
        style = json.loads(fetch(url))
        write(
            os.path.join(ROOT, 'styles', f'{name}.json'),
            json.dumps(style, ensure_ascii=False, separators=(',', ':')).encode(),
        )
        sprites.add(style['sprite'])
        for layer in style['layers']:
            for font in layer.get('layout', {}).get('text-font', []):
                fonts.add(font)
    if len(sprites) != 1:
        raise SystemExit(f'expected one sprite, found {sorted(sprites)}')

    for font in sorted(fonts):
        for glyphs in RANGES:
            quoted = urllib.parse.quote(font)
            write(
                os.path.join(ROOT, 'fonts', font_folder(font), f'{glyphs}.pbf'),
                fetch(f'{BASE}/fonts/{quoted}/{glyphs}.pbf'),
            )

    sprite = sprites.pop()
    for suffix in ['', '@2x']:
        for extension in ['json', 'png']:
            write(
                os.path.join(ROOT, 'sprites', f'ofm{suffix}.{extension}'),
                fetch(f'{sprite}{suffix}.{extension}'),
            )
    print(f'{len(fonts)} fonts, sprite {sprite}')


if __name__ == '__main__':
    main()
