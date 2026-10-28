# DuonSDK Flutter Demo

Sample Flutter app that lists malls from the Duon backend and displays the selected
map via **`duonsdk`**.

**This repo uses the published SDK** [`duonsdk` 2.1.0](https://pub.dev/packages/duonsdk)
from pub.dev (see `pubspec.yaml`).

Situm malls use native indoor positioning when location permission is granted; otherwise
the web viewer is used. Native Situm reports `poi_select`, category taps, directions, and
turn-by-turn start automatically. A POI tap is not counted as a search.

## Prerequisites

1. A Map Viewer scoped API key from Duon
2. At least one **active mall** assigned to that key
3. Flutter 3.10+ (`flutter doctor`)
4. iOS 16.0+ on the phone (required by `situm_flutter`)
5. **Physical devices only** (this guide): USB cable, and for a local backend, phone and Mac/PC on the **same Wi‑Fi**

For a local backend: `duon_backend` on port `8080` with an SDK key seeded.

## Install the published SDK

From this directory:

```bash
flutter pub get
```

`pubspec.yaml` depends on the hosted package:

```yaml
duonsdk: 2.1.0
```

A full rebuild is required after this switch (`flutter run` again). Hot reload does not
replace the native Situm library that ships inside `duonsdk`.

## Environment (`.env`)

```bash
cp .env.example .env
```

Edit `.env` for your backend and key:

| Variable | Description |
|----------|-------------|
| `DUON_API_URL` | Backend base URL (no trailing path required, but be consistent). **Physical device:** use your computer’s **LAN IP**, e.g. `http://192.168.1.42:8080`. `localhost` on the phone means the phone itself, not your Mac. **Cloud backend:** use the full HTTPS URL (as in `.env.example`). |
| `DUON_API_KEY` | SDK key with **Map Viewer** scope |

Run with:

```bash
flutter run --dart-define-from-file=.env
```

`--dart-define-from-file` bakes these into the binary (expected for Map Viewer keys).

### Local backend checklist (physical device)

1. Backend listening on `0.0.0.0:8080` (not only `127.0.0.1`).
2. Mac firewall allows inbound connections on 8080 (or temporarily disable for testing).
3. Phone Wi‑Fi same network as the dev machine.
4. `.env` uses `http://<your-lan-ip>:8080`.
5. **iPhone:** allow **Local Network** when prompted (Settings → Privacy & Security → Local Network → your app). `Info.plist` already allows local HTTP for development.
6. **Android:** `usesCleartextTraffic` is enabled in the demo manifest for HTTP dev URLs.

## Run on a physical iPhone

### One-time setup

1. Install **Xcode** from the App Store; open it once and accept licenses.
2. Install CocoaPods if needed: `sudo gem install cocoapods` (or via Homebrew).
3. Apple ID in Xcode: **Xcode → Settings → Accounts** → add your Apple ID.
4. On the iPhone: **Settings → Privacy & Security → Developer Mode** → On (iOS 16+), then restart if asked.
5. Plug in USB → tap **Trust** on the phone → enter passcode.

### Signing

1. Open `ios/Runner.xcworkspace` in Xcode (not `.xcodeproj`).
2. Select **Runner** target → **Signing & Capabilities**.
3. Set **Team** to your Apple Developer team (a free Apple ID works for device testing with limits).
4. Ensure **Bundle Identifier** is unique if you hit conflicts (e.g. `ph.duon.duonsdk_flutter_demo.dev`).

### Build and run from terminal

```bash
cd /Users/Work/Desktop/Duon_Projects/DuonSamples/duonsdk_flutter_demo
flutter pub get
cd ios && pod install && cd ..
flutter devices          # note your iPhone id, e.g. 00008110-...
flutter run --dart-define-from-file=.env -d <iphone-device-id>
```

First install may require unlocking the phone and tapping **Trust** for the developer app under **Settings → General → VPN & Device Management**.

### Permissions on device

When the demo loads a Situm mall, allow **Location** (choose **Precise** for indoor maps),
**Bluetooth**, and **Motion** if prompted.

## Run on a physical Android phone

### One-time setup

1. **Developer options** on the phone: Settings → About phone → tap **Build number** seven times.
2. **Settings → Developer options** → enable **USB debugging**.
3. Install [Android platform tools](https://developer.android.com/tools/releases/platform-tools) or use the SDK from Android Studio.
4. Connect USB; on the phone accept **Allow USB debugging** (check **Always allow** for your computer).

Verify:

```bash
adb devices
# should show your device as "device", not "unauthorized"
flutter devices
```

### Build and run

```bash
cd /Users/Work/Desktop/Duon_Projects/DuonSamples/duonsdk_flutter_demo
flutter pub get
flutter run --dart-define-from-file=.env -d <android-device-id>
```

Use your **LAN IP** in `DUON_API_URL` for a local backend (the demo does **not** rewrite
`localhost` to `10.0.2.2` on a real Android device—only on the emulator).

On Android 12+, grant **Location** and **Nearby devices / Bluetooth** when the app asks.

### Wireless debugging (optional)

Android 11+: Developer options → **Wireless debugging** → pair with `adb pair` / `adb connect`.
Then `flutter run -d <ip:port>` without USB.

## Architecture

```
lib/main.dart
  → DuonWayfinding.initialize + fetchMalls()
  → DuonMallSelector (pick mall)
  → DuonMapView(mall: …) for Situm when location is granted
  → DuonMapView(url: viewerUrl) fallback (kiosk, or Situm without permission)
```

## Troubleshooting

| Symptom | Likely fix |
|---------|------------|
| Empty mall list / network error on phone | Wrong `DUON_API_URL` (use LAN IP or cloud URL); backend not reachable; firewall |
| iOS “Could not connect” to local API | Local Network permission; use LAN IP not `localhost` |
| Situm map but no blue dot | Denied or **approximate** location on iOS; grant Precise Location |
| `pod install` fails after SDK change | `cd ios && pod repo update && pod install` |
| Xcode signing errors | Set Team in Runner target; unique bundle ID |

See also `DuonCore/DuonSDK/docs/flutter/troubleshooting.md`.
