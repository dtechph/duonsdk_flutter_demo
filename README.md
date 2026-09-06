# DuonSDK Flutter Demo

Sample Flutter app that lists malls from the Duon backend and displays the selected
map via the published pub.dev package [`duonsdk`](https://pub.dev/packages/duonsdk) **^1.5.0**.

This follows the DuonSDK Flutter getting-started guide. Situm malls use native indoor
positioning when location permission is granted; otherwise the web viewer is used.
Native Situm reports `poi_select`, category taps, directions, and turn-by-turn start
automatically. A POI tap is not counted as a search.

## Prerequisites

1. A Map Viewer scoped API key from Duon
2. At least one **active mall** assigned to that key
3. Flutter 3.10+ (`flutter doctor`)

For a local backend: `duon_backend` on `http://localhost:8080` with an SDK key seeded.

## Setup

```bash
cp .env.example .env
# Edit DUON_API_URL and DUON_API_KEY if needed

flutter pub get
flutter run --dart-define-from-file=.env
```

No GitHub access is required. `flutter pub get` installs `duonsdk` from pub.dev.

### Environment

| Variable | Description |
|----------|-------------|
| `DUON_API_URL` | Backend base URL. Prefer `http://localhost:8080` — Android emulator rewrites this to `10.0.2.2` automatically. Physical device: your PC LAN IP. |
| `DUON_API_KEY` | SDK key with **Map Viewer** scope |

`--dart-define-from-file` inlines these into the binary. That is expected for this key — it
can only read assigned malls and write analytics.

## Architecture

```
lib/main.dart
  → DuonWayfinding.initialize + fetchMalls()
  → DuonMallSelector (pick mall)
  → DuonMapView(mall: …) for Situm when location is granted
  → DuonMapView(url: viewerUrl) fallback (kiosk, or Situm without permission)
```

SDK package: `duonsdk` ^1.5.0 (pub.dev). `situm_flutter` and `webview_flutter` are pulled in
automatically.

## Scripts

- `flutter run --dart-define-from-file=.env` — iOS Simulator or connected device
- `flutter run --dart-define-from-file=.env -d android` — Android emulator/device
