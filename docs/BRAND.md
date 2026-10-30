# Navia brand guide

## Logo

<img src="../assets/brand/navia_logo_512.png" alt="Navia logo" width="96">

The mark is a white arrowhead heading north-east, leaving a small origin ring
along a dotted path: "from here to there". It sits on a diagonal disc that
goes from Navia blue to aqua, with a soft top gloss, a restrained nod to the
Frutiger Aero style.

| Asset | Path | Use |
| --- | --- | --- |
| Vector logo | `assets/brand/navia_logo.svg` | In the app (`NaviaLogoMark`) |
| Raster logo, 512 px | `assets/brand/navia_logo_512.png` | README and store listings |
| Adaptive launcher icon | `android/app/src/main/res/drawable/ic_launcher_*.xml` | Android 8.0 and later, including the monochrome themed icon |
| Legacy launcher icons | `android/app/src/main/res/mipmap-*/ic_launcher.png` | Android 7.x |

All of these files are generated from a single geometry definition:

```sh
python tool/brand/generate_brand_assets.py   # requires Pillow
```

Change the geometry in the script, not the generated files.

Usage rules:

- Keep clear space of at least a quarter of the logo diameter on every side.
- Do not recolor, rotate, stretch or add effects to the mark.
- On photos or busy maps, place the mark on a solid surface.

## Colors

| Token | Hex | Role |
| --- | --- | --- |
| Brand | `#1677FF` | Fills, icons, route line in light mode |
| Brand deep | `#0B63E5` | Primary color in light mode, with text on it (5.3:1 against white) |
| Brand light | `#6AA8FF` | Primary color in dark mode |
| Aqua | `#00BFA6` | Secondary color, origin marker |
| Destination | `#E5483B` | Destination marker |
| Background light | `#F5F8FC` | Light background |
| Background dark | `#0B1220` | Dark background |
| Surface dark | `#151F30` | Dark surfaces |

All values are defined in `lib/app/theme/navia_tokens.dart`. Do not hard-code
colors in widgets.

## Icon set

Navia has its own icon set in `assets/icons/`. Use it through `NaviaIcon`:

```dart
const NaviaIcon(NaviaIcons.route)
NaviaIcon(NaviaIcons.destination, color: theme.colorScheme.error, size: 20)
```

Drawing rules for new icons:

- 24 × 24 viewBox, with content inside a 2 px margin
- 2 px strokes with round caps and joins, and no fill
- Fills only for small details, such as dots or the active location center
- Drawn in black (`#000`): `NaviaIcon` tints the icon at runtime with the
  current `IconTheme` color
- Simple, open shapes that stay readable at 20 px

Once you add the SVG, add an entry to `NaviaIcons`. A test makes sure that
every asset and enum entry match.

Available icons: bike, car, chevron (down, right, up), close, cloud off, code,
copyright, destination, directions, document, external link, info, layers,
locate (idle, fixed, off), origin, refresh, route, search, settings, shield,
swap, theme (dark, light, system), walk.

The logo and icon set are original Navia artwork, released under the
project's MIT License.
