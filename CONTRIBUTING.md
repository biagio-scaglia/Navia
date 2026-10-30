# Contributing to Navia

Thank you for helping build an open, privacy-friendly navigation app.

## Ground rules

- **Privacy first.** Do not add analytics, ads, crash reporters that send
  data, accounts or background location. Any new network request must be
  triggered by an explicit user action, and must be listed in the README
  table of online services and in the settings screen.
- **No fake functionality.** Do not show buttons for features that do not
  work, and do not ship mock data or simulated results in production code.
  Test doubles belong in `test/` only.
- **No secrets.** Never commit API keys, keystores or `key.properties`.
  Endpoints are configured with `--dart-define`.
- **Respect providers.** Follow the usage policies and attribution
  requirements of every map, search and routing service.
- **Language.** User-facing text is Italian and lives in
  `lib/core/l10n/app_strings.dart`. Code, comments, documentation and commit
  messages are in English.

## Development workflow

1. Fork the repository and create a branch from `main`.
2. Make a focused change. Keep business logic out of widgets: put it in
   repositories (data), domain models, and Riverpod notifiers.
3. Add or update tests. Network integrations are tested with
   `package:http/testing.dart` and injected repositories.
4. Run the checks that CI runs:

   ```sh
   dart format --output=none --set-exit-if-changed .
   flutter analyze
   flutter test
   flutter build apk --debug
   ```

5. Open a pull request that explains what changed and why. Include
   screenshots for UI changes, in both light and dark theme.

Do not disable lint rules to silence warnings: fix the code instead.

## Commit messages

Use [Conventional Commits](https://www.conventionalcommits.org/), in English,
with one logical change per commit:

```
feat: add cycling route profile
fix: keep route visible after theme change
perf: avoid rebuilding the map when the sheet expands
docs: document Photon configuration
test: cover OSRM error codes
```

## Code style

- Follow the existing feature-first structure (`data`, `domain`,
  `presentation` inside each feature) and see `docs/ARCHITECTURE.md`.
- Prefer immutable state and selective `ref.watch(provider.select(...))`
  subscriptions.
- Use `const` constructors wherever possible.
- Use the design tokens in `lib/app/theme/` and the Navia icon set
  (`NaviaIcon`) instead of hard-coded colors, sizes or Material icons.
- Use named `latitude` and `longitude` fields (`GeoPoint`). When you
  serialize for GeoJSON, OSRM or other APIs, remember they use
  `[longitude, latitude]` order.

## Reporting issues

Please include your device model, Android version, Navia version (shown in
*Impostazioni*), the steps to reproduce, and what you expected. For map data
errors, such as a wrong street or a missing address, please fix them directly
on [OpenStreetMap](https://www.openstreetmap.org/fixthemap). Everyone
benefits.
