# Navia Privacy Policy

**Status: draft, prepared for legal review.** This document describes how
the Navia Android app actually handles data, as implemented in this
repository. It has not been reviewed by a lawyer, and it does not claim
certified compliance with the GDPR or any other law.

Last updated: 2026-10-30. Applies to Navia 0.4 and later.

The app shows the same policy in Italian under *Impostazioni → Privacy*.

## 1. Who we are

Navia is an open-source navigation app published at
<https://github.com/biagio-scaglia/Navia> under the MIT License.

| Role | Details |
| --- | --- |
| Maintainer | Biagio Scaglia (GitHub: `biagio-scaglia`) |
| Data controller | `[TO BE CONFIRMED: legal name and address of the data controller]` |
| Privacy contact | `[TO BE PROVIDED: privacy contact e-mail]`; until then, open an issue at <https://github.com/biagio-scaglia/Navia/issues> (issues are public, so do not post personal data there) |

Navia has **no backend of its own**. The maintainer does not run any server
that receives data from the app, and does not receive your location, your
searches or your saved places.

## 2. Summary

- No account, no registration, no login.
- No advertising SDKs, no analytics SDKs, no crash reporting SDKs.
- No advertising ID or other device identifiers are read or sent.
- No background location: the location is read only while the app is open,
  after you ask for it.
- Your saved places and settings stay on your device.
- To work, the app sends requests to third-party OpenStreetMap services.
  Those requests contain the data listed in section 4, including
  coordinates. Navia does not send your location anywhere unless a feature
  you used needs it, as explained below.
- Your data is not sold or shared for marketing.

## 3. Data kept on your device

Navia stores the following data in the app's private storage
(Android `SharedPreferences`):

| Data | Purpose | Retention |
| --- | --- | --- |
| Theme (system, light, dark) | Remember your choice | Until you change it or uninstall the app |
| Map appearance and 3D buildings setting | Remember your choice | Same |
| Favorites: the name you chose, coordinates, the time you saved it and, when available, the place's OpenStreetMap category, address and identifier | Show your saved places, also offline | Until you delete the favorite or uninstall the app |

This data never leaves the device through Navia. Android cloud backup is
disabled for the app (`android:allowBackup="false"`), so it is not copied
to your Google account backup. Uninstalling the app, or clearing its
storage in Android settings, deletes it.

Your device location is **not stored**. It is kept in memory while the app
is open and discarded when the app closes.

Search results, place results and routes are kept in memory only, to
avoid repeated requests, and are discarded when the app closes. Place
results expire after 15 minutes.

## 4. Data sent to third-party services

Navia uses public services built on OpenStreetMap data. Each request goes
directly from your device to the provider. Like any internet request, it
reveals your **IP address** and basic technical data (such as the time of
the request) to that provider. Every request identifies the app with a
User-Agent like `Navia/0.4.0 (+https://github.com/biagio-scaglia/Navia)`;
it contains no user or device identifier.

| Service | When | What it receives | Why |
| --- | --- | --- | --- |
| **OpenFreeMap** (`tiles.openfreemap.org`) | Whenever the map is shown | The map tiles for the area and zoom level you are viewing | Draw the map |
| **Photon by komoot** (`photon.komoot.io`) | When you search | The text you type; an approximate position rounded to about 1 km (your position if you located yourself, otherwise the default area of Bari) to rank nearby results first | Find places and addresses |
| **Photon by komoot** | When you long-press a point on the map | The exact coordinates of that point | Show its address |
| **Overpass API** (`overpass-api.de`) | When you select a place category, such as "Farmacie", and move the map while it is selected | The category and the area you are viewing, enlarged and rounded outwards to a grid of about 1 km | List real places of that category |
| **OSRM on FOSSGIS servers** (`routing.openstreetmap.de`) | When a route is calculated | Origin and destination coordinates, and the travel mode. If the origin is "La tua posizione", this is your current device location | Calculate the route |

Because the map area you view, your searches and route endpoints can reveal
where you are or where you are going, you should consider them personal
data. Navia limits them to what each feature needs: for example, search uses
a position rounded to about 1 km instead of your exact location.

These providers process data under their own policies, which Navia does not
control:

- OpenFreeMap: <https://openfreemap.org>
- komoot (Photon): <https://www.komoot.com/privacy>
- FOSSGIS e.V. (routing.openstreetmap.de):
  <https://www.fossgis.de/datenschutzerklaerung/>
- Overpass API main instance: <https://overpass-api.de>
  (`[TO BE VERIFIED: operator and privacy notice of the instance]`)

`[TO BE VERIFIED during legal review: the retention periods and legal bases
of each provider, and whether data is transferred outside the EU.]`

You can point Navia to self-hosted services when building the app (see the
README), in which case those services receive the same data instead.

## 5. Device location

- Navia requests the Android location permission (approximate and precise)
  only when you tap the location button or ask for a route starting from
  "La tua posizione". It never requests background location.
- While the app is open and you have activated location, the position is
  updated to show the blue dot. Updates stop when the app goes to the
  background.
- The location is used on the device to show the dot and center the map. It
  leaves the device only in the cases listed in section 4 (route origin,
  rounded search position).
- You can deny the permission. The map, search, place details and routes
  between places you choose still work; only "La tua posizione" does not.
- You can revoke the permission at any time in Android settings
  (*Impostazioni → Posizione → Gestisci nelle impostazioni di sistema*).

## 6. Actions that open other apps

Some actions hand data to another app only when you tap them:

- **Open website / view on OpenStreetMap:** opens the link in your browser.
- **Share:** opens the Android share sheet with the place name and a link;
  you choose the recipient app.

Those apps apply their own privacy policies.

## 7. Legal bases

`[TO BE CONFIRMED during legal review.]` The intended basis is that each
request is necessary to provide the feature you explicitly use
(GDPR art. 6(1)(b)), and location access relies on your permission, which
you can withdraw at any time.

## 8. Your rights

Navia's maintainer holds no personal data about you, so there is nothing
the maintainer can access, correct or delete on your behalf. You control
the data on your device directly: delete favorites in the app, or clear the
app storage or uninstall it.

For data received by third-party providers (section 4), you can exercise
your rights (access, rectification, erasure, restriction, objection) with
those providers. You also have the right to lodge a complaint with a
supervisory authority; in Italy, the Garante per la protezione dei dati
personali (<https://www.garanteprivacy.it>).

## 9. Children

Navia does not knowingly collect data from children and has no accounts or
profiles.

## 10. Changes to this policy

Changes are published in this file and in the app, with a new "Last
updated" date. The full history is available in the repository's Git log.
Significant changes, such as a new service receiving data, will be listed
in the release notes.
