# LaneSync Dashcam (iOS)

Implement your iOS app here against the comma **Dashcam API** (`dashcamd`, port **7720**).

## Endpoints

| Method | Path | Purpose |
|--------|------|---------|
| GET | `/health` | Check service |
| GET | `/clips` | List saved dashcam segments |
| GET | `/video/{segment_id}/{filename}` | Stream/download video |

Base URL example: `http://192.168.43.1:7720`

Optional header: `Authorization: Bearer <DashcamApiToken>`

## Reference

- API docs: `tools/dashcam/README.md`
- Android implementation: `../android/` (Kotlin + ExoPlayer)

## Suggested stack

- `URLSession` for API + downloads
- `AVPlayer` for `qcamera.ts` / HEVC playback
- Same Wi‑Fi / hotspot flow as the Android app
