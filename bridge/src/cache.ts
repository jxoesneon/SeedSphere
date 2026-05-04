import { Stream } from "./types";
import { Logger } from "./logger";

const logger = new Logger("Cache");

const DEFAULT_TTL_MS = 90 * 1000;
const STALE_TTL_MS = 600 * 1000;

export async function getCache(
  kv: any,
  key: string,
  allowStale = true,
): Promise<Stream[] | null> {
  if (!kv) return null;
  try {
    const data = await kv.get(key, { type: "json" });
    if (!data) return null;

    const e = data as { ts: number; ttl: number; streams: Stream[] };
    const age = Date.now() - e.ts;

    if (age <= e.ttl) return e.streams;
    if (allowStale && age <= e.ttl + STALE_TTL_MS) {
      logger.info(`Serving STALE for ${key}`);
      return e.streams;
    }

    return null;
  } catch (e) {
    logger.error(`getCache failed for ${key}`, e);
    return null;
  }
}

export async function setCache(
  kv: any,
  key: string,
  streams: Stream[],
  ttl = DEFAULT_TTL_MS,
) {
  if (!kv) return;
  try {
    await kv.put(
      key,
      JSON.stringify({
        ts: Date.now(),
        ttl,
        streams,
      }),
      {
        expirationTtl: Math.ceil(
          (ttl + STALE_TTL_MS + 24 * 60 * 60 * 1000) / 1000,
        ),
      },
    );
  } catch (e) {
    logger.error(`setCache failed for ${key}`, e);
  }
}
