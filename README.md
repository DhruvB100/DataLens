# DataLens

## API

This is a small public API that lets you ask questions about earthquake data. It's backed by AWS Athena under the hood. Just hit one of the URLs below with a browser or curl and you'll get JSON back.

**Base URL:**

```text
https://66z1yldj84.execute-api.us-east-1.amazonaws.com/prod
```

Every endpoint below is a simple `GET` request — no login, no API key, nothing to set up. Just add the path to the base URL above.

---

### `GET /stats`

Gives you a quick daily summary: how many earthquakes happened, and how strong they were on average, grouped by day.

No parameters needed.

**Example:**

```bash
curl "https://66z1yldj84.execute-api.us-east-1.amazonaws.com/prod/stats"
```

**What you get back:**

```json
[
  { "dt": "2026-09-07", "num_events": "392", "avg_magnitude": "1.81" }
]
```

- `dt` — the date
- `num_events` — how many earthquakes were recorded that day
- `avg_magnitude` — the average strength of those earthquakes

---

### `GET /recent`

Gives you the most recent earthquakes, newest first.

**Parameter (optional):**

- `limit` — how many results you want back. If you don't pass this, default is 50.

**Example:**

```bash
curl "https://66z1yldj84.execute-api.us-east-1.amazonaws.com/prod/recent?limit=5"
```

**What you get back:** a list of earthquake records, each one looking like this:

```json
{
  "id": "aka2026rtrdfk",
  "magnitude": "1.2",
  "place": "32 km NE of Manley Hot Springs, Alaska",
  "event_time": "2026-09-07 22:49:47.981",
  "tsunami": "0",
  "longitude": "-150.137",
  "latitude": "65.205",
  "depth_km": "5.0",
  "dt": "2026-09-07"
}
```

- `magnitude` — how strong the earthquake was
- `place` — a human-readable description of where it happened
- `event_time` — when it happened (UTC)
- `tsunami` — `1` if a tsunami warning was tied to this event, otherwise `0`
- `longitude` / `latitude` — where it happened, as coordinates
- `depth_km` — how far below the surface it happened

---

### `GET /largest`

Same shape as `/recent`, but sorted by strength instead of time, the biggest earthquakes first.

**Parameter (optional):**

- `limit` — how many results you want back. If you don't pass this, defualt is 10.

**Example:**

```bash
curl "https://66z1yldj84.execute-api.us-east-1.amazonaws.com/prod/largest?limit=3"
```

**What you get back:** the same record shape as `/recent` above, just sorted differently.

---

### Notes:

- If you hit a path that doesn't exist, you'll get a `404` with a small JSON error message instead of a crash.
- If you call the exact same request twice within about 30 seconds, the second one will usually come back noticeably faster as results are cached briefly.
- All the number-looking fields (like `magnitude` or `num_events`) currently come back as text (e.g. `"1.2"` instead of `1.2`). That's a known quirk of how the underlying query engine returns data — if you're using these values in code, just convert them to numbers first.
