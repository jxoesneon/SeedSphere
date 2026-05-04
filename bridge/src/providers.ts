import { Stream } from "./types";
import { Logger } from "./logger";

const logger = new Logger("Providers");

/**
 * Fetches streams from Torrentio for aggregation.
 */
export async function fetchTorrentio(
  type: string,
  id: string,
): Promise<Stream[]> {
  const base = "https://torrentio.strem.fun";
  const url = `${base}/stream/${type}/${id}.json`;
  try {
    const res = await fetch(url, {
      headers: {
        "User-Agent":
          "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
        Accept: "application/json, text/plain, */*",
        "Accept-Language": "en-US,en;q=0.9",
        Origin: "https://web.stremio.com",
        Referer: "https://web.stremio.com/",
      },
    });

    logger.info(`Torrentio fetch: ${url} -> ${res.status}`);
    if (!res.ok) {
      const txt = await res.text();
      logger.error(`Torrentio error response: ${txt}`);
      return [];
    }
    const data: any = await res.json();
    return (data.streams || []).map((s: any) => ({
      ...s,
      provider: "Torrentio",
      seeds: s.seeds || s.seeders,
      peers: s.peers || s.leechers,
    }));
  } catch (e: any) {
    logger.error(`Torrentio exception: ${e.message}`);
    return [];
  }
}

/**
 * Handles subtitle requests via OpenSubtitles.
 */
export async function fetchOpenSubtitles(type: string, imdbId: string, env: any) {
  const apiKey = env.OPENSUBTITLES_API_KEY;
  if (!apiKey) {
    logger.warn("OpenSubtitles API key missing");
    return [];
  }

  try {
    const cleanImdb = imdbId.replace(/^tt/, "");
    const response = await fetch(
      `https://api.opensubtitles.com/api/v1/subtitles?imdb_id=${cleanImdb}&type=${type === "series" ? "episode" : "movie"}`,
      {
        headers: {
          "Api-Key": apiKey,
          "Content-Type": "application/json",
        },
      },
    );

    if (!response.ok) return [];

    const data: any = await response.json();
    const results = Array.isArray(data.data) ? data.data : [];

    return results
      .slice(0, 20)
      .map((sub: any) => ({
        id: `opensubtitles:${sub.attributes?.files?.[0]?.file_id || sub.id}`,
        url: sub.attributes?.files?.[0]?.url || "",
        lang: sub.attributes?.language || "en",
      }))
      .filter((s: any) => s.url);
  } catch (e) {
    logger.error("OpenSubtitles exception", e);
    return [];
  }
}
