import { Hono } from "hono";
import { cors } from "hono/cors";
import { Stream, Config } from "./types";
import { Logger } from "./logger";
import { getCache, setCache } from "./cache";
import { toTitleNatural, normalizeSxxEyy, buildDescriptionMultiline } from "./normalizer";
import { fetchTorrentio, fetchOpenSubtitles } from "./providers";

const app = new Hono();
const logger = new Logger("Bridge");

app.use("*", cors());

const clean = (s: string) => (s || "").trim();

// --- ROUTES ---
app.get("/manifest.json", (c) => manifest(c));
app.get("/:config/manifest.json", (c) => manifest(c));

function manifest(c: any) {
  return c.json({
    id: "community.SeedSphere",
    version: "2.0.0",
    name: "SeedSphere",
    logo: "https://seedsphere.fly.dev/assets/icon.png",
    description: "SeedSphere 2.0: Absolute Logic Parity Edition.",
    resources: ["stream", "subtitles"],
    types: ["movie", "series"],
    idPrefixes: ["tt"],
    behaviorHints: { configurable: true, p2p: true },
    config: [
      {
        key: "auto_proxy",
        type: "select",
        default: "on",
        title: "Proxy upstream streams",
        options: [
          { value: "on", label: "On" },
          { value: "off", label: "Off" },
        ],
      },
      {
        key: "desc_append_original",
        type: "select",
        title: "Append original description",
        default: "off",
        options: [
          { value: "on", label: "On" },
          { value: "off", label: "Off" },
        ],
      },
      {
        key: "sort_order",
        type: "select",
        title: "Sorting",
        default: "desc",
        options: [
          { value: "desc", label: "Descending" },
          { value: "asc", label: "Ascending" },
        ],
      },
    ],
  });
}

app.get("/stream/:type/:id", async (c) => streamHandler(c));
app.get("/:config/stream/:type/:id", async (c) => streamHandler(c));

async function streamHandler(c: any) {
  let { type, id } = c.req.param();
  const configStr = c.req.param("config") || "";

  logger.info(`Stream request`, { type, id, config: configStr });

  if (id && id.endsWith(".json")) {
    id = id.replace(".json", "");
  }

  const config: Config = {};
  if (configStr) {
    configStr.split(",").forEach((kv: string) => {
      const [k, v] = kv.split("=");
      if (k && v) config[clean(k)] = clean(v);
    });
  }

  const cacheKey = `streams:${type}:${id}:${JSON.stringify(config)}`;
  const cached = await getCache(c.env.KV_CACHE, cacheKey);
  if (cached) return c.json({ streams: cached });

  const providers = [];
  if (config.auto_proxy !== "off") {
    providers.push(fetchTorrentio(type, id));
  }

  const routerUrl = c.env.ROUTER_URL || "https://seedsphere.fly.dev";
  const query = new URLSearchParams({
    id: id as string,
    type: type as string,
  }).toString();
  
  providers.push(
    fetch(`${routerUrl}/api/swarm/query?${query}`)
      .then((r) => r.json())
      .then((d: any) => d.results || [])
      .catch(() => []),
  );

  const allResults = await Promise.all(providers);
  let merged: Stream[] = allResults.flat();

  // Dedupe
  const seen = new Set();
  merged = merged.filter((kv: any) => {
    const hash = (kv?.infoHash || kv?.info_hash)?.toLowerCase() || kv?.url;
    if (!hash || seen.has(hash)) return false;
    seen.add(hash);
    return true;
  });

  // Tracker Optimization
  try {
    const allTrackers = new Set<string>();
    merged.forEach((s: any) => {
      if (s.url && s.url.startsWith("magnet:")) {
        const matches = s.url.matchAll(/&tr=([^&]+)/g);
        for (const m of matches) allTrackers.add(decodeURIComponent(m[1]));
      }
      if (Array.isArray(s.sources)) {
        s.sources.forEach((tr: string) => {
          if (tr.startsWith("udp:") || tr.startsWith("http"))
            allTrackers.add(tr);
        });
      }
    });

    if (allTrackers.size > 0) {
      const optRes = await fetch(`${routerUrl}/api/trackers/optimize`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ trackers: Array.from(allTrackers) }),
      });

      if (optRes.ok) {
        const optData: any = await optRes.json();
        const addedList = optData.added || [];
        merged = merged.map((s: any) => {
          let newUrl = s.url;
          if (newUrl && newUrl.startsWith("magnet:")) {
            addedList.forEach((tr: string) => {
              if (!newUrl.includes(encodeURIComponent(tr))) {
                newUrl += `&tr=${encodeURIComponent(tr)}`;
              }
            });
          }
          return { ...s, url: newUrl };
        });
      }
    }
  } catch (e) {
    logger.error("Tracker optimization failed", e);
  }

  // Final mapping
  const finalStreams = merged.map((s) => {
    let titleText = s.title || s.name || "";
    titleText = normalizeSxxEyy(titleText);
    const naturalTitle = toTitleNatural(titleText);
    return {
      ...s,
      name: naturalTitle || "SeedSphere",
      description: buildDescriptionMultiline(s, config),
    };
  });

  setCache(c.env.KV_CACHE, cacheKey, finalStreams);
  return c.json({ streams: finalStreams });
}

app.get("/subtitles/:type/:id.json", async (c) => subtitlesHandler(c));
app.get("/:config/subtitles/:type/:id.json", async (c) => subtitlesHandler(c));

async function subtitlesHandler(c: any) {
  const { type, id } = c.req.param();
  try {
    const subtitles = await fetchOpenSubtitles(type, id, c.env);
    return c.json({ subtitles });
  } catch (e) {
    return c.json({ subtitles: [] });
  }
}

export default app;
