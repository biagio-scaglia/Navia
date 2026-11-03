Offline maps for the Navia app, regenerated monthly by the `Map data`
workflow from [Geofabrik](https://download.geofabrik.de) extracts of
OpenStreetMap with [Planetiler](https://github.com/onthegomap/planetiler).

Each `map-<region>.pmtiles` file holds the vector tiles of one Italian
macro-region, up to zoom 14, in the [OpenMapTiles](https://openmaptiles.org)
schema used by the OpenFreeMap styles. `manifest.json` lists the files with
their size, SHA-256 checksum, bounding box and zoom range.

**License:** the map data is derived from OpenStreetMap and is made
available under the [Open Database License (ODbL) 1.0](https://opendatacommons.org/licenses/odbl/).
Data © OpenStreetMap contributors, <https://www.openstreetmap.org/copyright>.
The tile schema is © OpenMapTiles (CC-BY 4.0); the lower zoom levels include
[Natural Earth](https://www.naturalearthdata.com) data (public domain) and
water polygons by [OSMCode](https://osmdata.openstreetmap.de) (ODbL). The
MIT License of Navia's source code does not apply to them.
