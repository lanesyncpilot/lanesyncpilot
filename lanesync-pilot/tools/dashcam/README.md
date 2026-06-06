# LaneSync Dashcam API

HTTP server on the comma device (`dashcamd`, port **7720**) for companion apps to access **saved** dashcam footage.

## Enable

Enabled by default (`DashcamApiEnabled=1`). Optional auth:

```bash
params set DashcamApiToken "your-secret-token"
```

## Endpoints

### Health

```bash
curl http://192.168.43.1:7720/health
```

### List saved clips

```bash
curl http://192.168.43.1:7720/clips
# include all segments with video (not only bookmark-preserved):
curl "http://192.168.43.1:7720/clips?all=1"
```

Response:

```json
{
  "clips": [
    {
      "id": "2024-06-01--12-30-45--0",
      "preserved": true,
      "files": ["qcamera.ts", "fcamera.hevc", "qlog.zst"],
      "size_bytes": 52428800,
      "playback_file": "qcamera.ts",
      "dongle_id": "abcdef1234567890"
    }
  ],
  "count": 1
}
```

### Stream / download video

```bash
curl -O "http://192.168.43.1:7720/video/2024-06-01--12-30-45--0/qcamera.ts"
```

Supports HTTP Range requests for seeking in players.

## Companion apps

| Platform | Path |
|----------|------|
| Android | `mobile/android/` (included) |
| iOS | `mobile/ios/` (implement against this API) |

## How clips are saved

When you press the **bookmark** button on the comma, `loggerd` marks the segment with `user.preserve`. The deleter keeps preserved segments; `dashcamd` lists them for the app.
