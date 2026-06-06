# LaneSync Dashcam (Android)

Browse, stream, and download **saved dashcam clips** from your comma device running LaneSync Pilot.

## Requirements

- Android 8.0+ (API 26)
- Phone on the same Wi‑Fi as the comma (hotspot or home network)
- LaneSync Pilot with `dashcamd` enabled (default on, port **7720**)

## Build

**Important:** open this exact folder in Android Studio, not the parent `lanesync-pilot` repo:

```
lanesync-pilot/mobile/android
```

1. Android Studio → **File → Open** → select `mobile/android`
2. Wait for **Gradle Sync** to finish (bottom status bar)
3. Run configuration **Module** should show `LaneSyncDashcam.app`
4. Click Run ▶

If Module shows `<no module>`: **File → Invalidate Caches → Restart**, then **File → Sync Project with Gradle Files**.

```bash
cd lanesync-pilot/mobile/android
./gradlew :app:assembleDebug
```

APK: `app/build/outputs/apk/debug/app-debug.apk`

## Setup

1. Join the comma Wi‑Fi network (often `192.168.43.1` on hotspot).
2. Open the app.
3. Set **Dashcam API URL** — default `http://192.168.43.1:7720`
4. Tap **Load saved clips**.

Optional: if you set `DashcamApiToken` on the comma, enter the same token in the app.

## Features

- Lists **preserved** (bookmark-saved) dashcam segments
- Stream playback in-app (ExoPlayer)
- Download clips to app storage

## API

See `tools/dashcam/README.md` in the repo root.

## iOS

Implement in `../ios/` using the same HTTP API.
