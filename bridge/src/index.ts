import { Hono } from 'hono';
import { cors } from 'hono/cors';

const app = new Hono();

app.use('*', cors());

// --- UTILS & TYPES ---
const clean = (s: string) => (s || '').trim();

interface Stream {
  name: string;
  title: string;
  url?: string;
  infoHash?: string;
  behaviorHints?: any;
  sources?: string[];
  provider?: string;
  description?: string;
  seeds?: number;
  peers?: number;
  size?: string;
  sizeBytes?: number;
  languages?: string[];
}

// --- CACHE (SWR Parity) ---
const CACHE = new Map<string, { ts: number, ttl: number, streams: Stream[] }>();
const DEFAULT_TTL_MS = 90 * 1000;
const STALE_TTL_MS = 600 * 1000;

function getCache(key: string, allowStale = true): Stream[] | null {
  const e = CACHE.get(key);
  if (!e) return null;
  const age = Date.now() - e.ts;
  if (age <= e.ttl) return e.streams;
  if (allowStale && age <= e.ttl + STALE_TTL_MS) return e.streams;
  CACHE.delete(key);
  return null;
}

function setCache(key: string, streams: Stream[], ttl = DEFAULT_TTL_MS) {
  CACHE.set(key, { ts: Date.now(), ttl, streams });
}

// --- METADATA NORMALIZER (Ported from legacy) ---
function toTitleNatural(title: string) {
  let t = (title || '').replace(/\(\s*(19|20)\d{2}\s*\)/g, '').trim();
  t = t.replace(/\[\s*Remaster(?:ed)?[^\]]*\]/ig, '').trim();
  t = t.replace(/[\s]*[\u2014\-:][\s]*(Director(?:’|')s Cut|Extended(?: Edition)?|Ultimate(?: Edition)?|Theatrical(?: Cut)?|Unrated|IMAX|Special(?: Edition)?)(?:.*)?$/i, '').trim();
  t = t.replace(/\b(2160p|1080p|720p|480p|4k)\b\s*$/i, '').trim();
  return t.replace(/\s+/g, ' ').trim();
}

function parseReleaseInfo(name: string) {
  const out: any = { resolution: null, source: null, codec: null, hdr: null, audio: null, group: null, languages: [] };
  const s = name;

  const res = (s.match(/(2160p|1080p|720p|480p)/i) || [])[1];
  if (res) out.resolution = res.toUpperCase();

  const src = (s.match(/(WEB[-_. ]?DL|WEB[-_. ]?Rip|BluRay|BDRip|BRRip|HDRip|DVDRip)/i) || [])[1];
  if (src) out.source = src.replace(/[_.]/g, '').toUpperCase();

  const codec = (s.match(/(HEVC|x265|H\.265|x264|H\.264|AV1)/i) || [])[1];
  if (codec) out.codec = codec.includes('265') ? 'HEVC x265' : codec.includes('264') ? 'x264' : codec;

  if (/HDR10\+?/i.test(s)) out.hdr = 'HDR10+';
  else if (/Dolby[ \-.]?Vision|\bDV\b/i.test(s)) out.hdr = 'Dolby Vision';
  else if (/\bHDR\b/i.test(s)) out.hdr = 'HDR';

  const audio = (s.match(/(DDP(?:\.?5\.1)?|E-?AC-?3|AC3|DTS(?:-HD)?(?: MA)?|TrueHD|AAC|Opus)/i) || [])[1];
  if (audio) out.audio = audio.replace(/_/g, ' ').toUpperCase();

  return out;
}

function buildDescriptionMultiline(s: Stream, config: any) {
  const info = parseReleaseInfo(s.title || s.name || '');
  const lines = [`⚡ SeedSphere Optimized`];
  if (s.provider) lines.push(`📦 Provider: ${s.provider}`);
  if (info.resolution) lines.push(`🖥️ Resolution: ${info.resolution}`);
  if (info.source) lines.push(`🧩 Source: ${info.source}`);
  if (info.codec) lines.push(`🎞️ Codec: ${info.codec}`);
  if (info.hdr) lines.push(`🌈 HDR: ${info.hdr}`);
  if (info.audio) lines.push(`🔊 Audio: ${info.audio}`);

  if (s.seeds !== undefined && s.seeds !== null) lines.push(`🌱 Seeds: ${s.seeds}`);
  if (s.peers !== undefined && s.peers !== null) lines.push(`👥 Peers: ${s.peers}`);
  if (s.size) lines.push(`🗜️ Size: ${s.size}`);

  lines.push('🌐 Faster peer discovery and startup time');

  let desc = lines.join('\n');
  if (config.desc_append_original === 'on' && s.description) {
    desc += `\n\n— Original —\n${s.description}`;
  }
  return desc;
}

// --- AGGREGATION LOGIC ---
async function fetchTorrentio(type: string, id: string): Promise<Stream[]> {
  const base = 'https://torrentio.strem.fun';
  const url = `${base}/stream/${type}/${id}.json`;
  try {
    const res = await fetch(url);
    const data: any = await res.json();
    return (data.streams || []).map((s: any) => ({
      ...s,
      provider: 'Torrentio',
      seeds: s.seeds || s.seeders,
      peers: s.peers || s.leechers,
    }));
  } catch (e) { return []; }
}

// --- ROUTES ---
app.get('/manifest.json', (c) => manifest(c));
app.get('/:config/manifest.json', (c) => manifest(c));

function manifest(c: any) {
  return c.json({
    id: 'community.SeedSphere',
    version: '2.0.0',
    name: 'SeedSphere',
    logo: 'https://seedsphere.fly.dev/assets/icon.png',
    description: 'SeedSphere 2.0: Absolute Logic Parity Edition.',
    resources: ['stream'],
    types: ['movie', 'series'],
    idPrefixes: ['tt'],
    behaviorHints: { configurable: true, p2p: true },
    config: [
      { key: 'auto_proxy', type: 'select', default: 'on', title: 'Proxy upstream streams', options: [{ value: 'on', label: 'On' }, { value: 'off', label: 'Off' }] },
      { key: 'desc_append_original', type: 'select', title: 'Append original description', default: 'off', options: [{ value: 'on', label: 'On' }, { value: 'off', label: 'Off' }] },
      { key: 'sort_order', type: 'select', title: 'Sorting', default: 'desc', options: [{ value: 'desc', label: 'Descending' }, { value: 'asc', label: 'Ascending' }] }
    ]
  });
}

app.get('/stream/:type/:id.json', async (c) => streamHandler(c));
app.get('/:config/stream/:type/:id.json', async (c) => streamHandler(c));

async function streamHandler(c: any) {
  const { type, id } = c.req.param();
  const configStr = c.req.param('config') || '';
  const config: any = {};
  if (configStr) {
    configStr.split(',').forEach(kv => {
      const [k, v] = kv.split('=');
      if (k && v) config[clean(k)] = clean(v);
    });
  }

  const cacheKey = `streams:${type}:${id}:${JSON.stringify(config)}`;
  const cached = getCache(cacheKey);
  if (cached) return c.json({ streams: cached });

  const providers = [];
  if (config.auto_proxy !== 'off') {
    providers.push(fetchTorrentio(type, id));
  }

  // Router P2P Swarm Query (Optional enhancement)
  const routerUrl = c.env.ROUTER_URL || 'https://seedsphere-router.fly.dev';
  providers.push(fetch(`${routerUrl}/api/swarm/query?id=${id}&type=${type}`).then(r => r.json()).then((d: any) => d.results || []).catch(() => []));

  const allResults = await Promise.all(providers);
  let merged: Stream[] = allResults.flat();

  // Dedupe & Normalize
  const seen = new Set();
  merged = merged.filter(s => {
    const hash = s.infoHash?.toLowerCase() || s.url;
    if (!hash || seen.has(hash)) return false;
    seen.add(hash);
    return true;
  }).map(s => {
    const naturalTitle = toTitleNatural(s.title || s.name || '');
    return {
      ...s,
      name: naturalTitle || 'SeedSphere',
      description: buildDescriptionMultiline(s, config)
    };
  });

  setCache(cacheKey, merged);
  return c.json({ streams: merged });
}

export default app;
