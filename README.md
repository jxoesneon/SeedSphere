# SeedSphere Trackers Addon for Stremio

This Stremio addon enhances your streaming experience by adding custom BitTorrent trackers to magnet links. It uses the comprehensive list of public trackers from [ngosang/trackerslist](https://github.com/ngosang/trackerslist).

## Features

- Automatically adds multiple public trackers to magnet links
- Caches trackers for 24 hours
- Easy to deploy and configure
- Full Configure button support (User Data) to choose trackers list
- Configure page includes a Boosts Metrics panel with totals, averages, and per-mode breakdown
- Live updates via Server-Sent Events (SSE) for recent boosts (falls back to polling if needed)

## Installation

1. Clone this repository
2. Install dependencies:

   ```bash
   npm install
   ```

3. Start the server:

   ```bash
   npm start
   ```

4. In Stremio, go to Addons > Community > Install via URL and paste:

   ```bash
   http://127.0.0.1:55025/manifest.json
   ```

## Configuration

This addon uses Stremio's User Data feature with an auto-generated Configure page.

- In the addon catalog, click the Configure button next to Install.
- Settings available:
  - `variant` (select): all (default), best, all_udp, all_http, all_ws, all_ip, best_ip
  - `trackers_url` (text): custom trackers URL; if set, it overrides `variant`

Environment variables (optional):

- `PORT`: Port to run the server on (default: 55025)
- `TRACKERS_VARIANT`: Default variant fallback (same options as above)
- `TRACKERS_URL`: Default trackers URL fallback (overrides variant)

## Usage

Once installed, the addon will automatically enhance streams with additional trackers. No further configuration is needed.

### Configure page

Open `/configure` to access advanced tools:

- Quick sweep of a trackers list with health filtering
- Recent boosts list with content context (`type`, `id`)
- Boosts Metrics panel: Requests, Avg healthy/total trackers, Avg health ratio, and per-mode mini bars

The recent boosts and metrics update live via SSE from `/api/boosts/events`.

## Development

- The addon interface is defined in `addon.js`
- The server entry is `server.js` using Stremio Addon SDK `serveHTTP`
- Trackers fetching: variant-specific TTL cache, in-flight de-duplication, startup warmup
- Health validation: bounded concurrency with retry/backoff
- Static caching: immutable for `public/assets/*`, short-lived for other static
- Health endpoint: `GET /health` returns `{ ok, version, uptime_s, last_trackers_fetch_ts }`

### Tests

Run the smoke tests:

```bash
npm test
```

CI runs the smoke tests on pushes and pull requests via GitHub Actions.

## License

MIT
