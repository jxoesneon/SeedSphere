import { Stream } from "./types";

/**
 * Normalizes movie/series titles by removing release year, format info, and extra tags.
 */
export function toTitleNatural(title: string) {
  let t = (title || "").replace(/\(\s*(19|20)\d{2}\s*\)/g, "").trim();
  t = t.replace(/\[[^\]]*\]/g, "").trim();
  t = t
    .replace(
      /[\s]*[\u2014\-:][\s]*(Director(?:’|')s Cut|Extended(?: Edition)?|Ultimate(?: Edition)?|Theatrical(?: Cut)?|Unrated|IMAX|Special(?: Edition)?)(?:.*)?$/i,
      "",
    )
    .trim();
  t = t.replace(/HDR10\+/gi, "");
  t = t.replace(
    /\b(2160p|1080p|720p|480p|4k|HDR10|Dolby[ \-.]?Vision|DV|Atmos|BluRay|BRRip|BDRip|WEB[-_. ]?DL|WEB[-_. ]?Rip|X264|X265|HEVC|H\.264|H\.265)\b/gi,
    "",
  );
  return t.replace(/\s+/g, " ").trim();
}

/**
 * Standardizes episode numbering formats.
 */
export function normalizeSxxEyy(title: string): string {
  let t = title;

  t = t.replace(
    /(\d{1,2})x(\d{1,2})/gi,
    (_, s, e) => `S${s.padStart(2, "0")}E${e.padStart(2, "0")}`,
  );

  t = t.replace(
    /s(\d{1,2})e(\d{1,2})/gi,
    (_, s, e) => `S${s.padStart(2, "0")}E${e.padStart(2, "0")}`,
  );

  t = t.replace(
    /Season\s+(\d{1,2})\s+Episode\s+(\d{1,2})/gi,
    (_, s, e) => `S${s.padStart(2, "0")}E${e.padStart(2, "0")}`,
  );

  return t;
}

/**
 * Extracts release details (resolution, source, codec, HDR) from a raw release string.
 */
export function parseReleaseInfo(name: string) {
  const out: any = {
    resolution: null,
    source: null,
    codec: null,
    hdr: null,
    audio: null,
    group: null,
    languages: [],
  };
  const s = name;

  const res = (s.match(/(2160p|1080p|720p|480p)/i) || [])[1];
  if (res) out.resolution = res.toUpperCase();

  const src = (s.match(
    /(WEB[-_. ]?DL|WEB[-_. ]?Rip|BluRay|BDRip|BRRip|HDRip|DVDRip)/i,
  ) || [])[1];
  if (src) out.source = src.replace(/[_.]/g, "").toUpperCase();

  const codec = (s.match(/(HEVC|x265|H\.265|x264|H\.264|AV1)/i) || [])[1];
  if (codec)
    out.codec = codec.includes("265")
      ? "HEVC x265"
      : codec.includes("264")
        ? "x264"
        : codec;

  if (/HDR10\+/i.test(s)) out.hdr = "HDR10+";
  else if (/HDR10/i.test(s)) out.hdr = "HDR10";
  else if (/Dolby[ \-.]?Vision|\bDV\b/i.test(s)) out.hdr = "Dolby Vision";
  else if (/\bHDR\b/i.test(s)) out.hdr = "HDR";

  const audio = (s.match(
    /(DDP(?:\.?5\.1)?|E-?AC-?3|AC3|DTS(?:-HD)?(?: MA)?|TrueHD|AAC|Opus)/i,
  ) || [])[1];
  if (audio) out.audio = audio.replace(/_/g, " ").toUpperCase();

  return out;
}

export function buildDescriptionMultiline(s: Stream, config: any) {
  const info = parseReleaseInfo(s.title || s.name || "");
  const lines = [`⚡ SeedSphere Optimized`];
  if (s.provider) lines.push(`📦 Provider: ${s.provider}`);
  if (info.resolution) lines.push(`🖥️ Resolution: ${info.resolution}`);
  if (info.source) lines.push(`🧩 Source: ${info.source}`);
  if (info.codec) lines.push(`🎞️ Codec: ${info.codec}`);
  if (info.hdr) lines.push(`🌈 HDR: ${info.hdr}`);
  if (info.audio) lines.push(`🔊 Audio: ${info.audio}`);

  if (s.seeds !== undefined && s.seeds !== null)
    lines.push(`🌱 Seeds: ${s.seeds}`);
  if (s.peers !== undefined && s.peers !== null)
    lines.push(`👥 Peers: ${s.peers}`);
  if (s.size) lines.push(`🗜️ Size: ${s.size}`);

  lines.push("🌐 Faster peer discovery and startup time");

  let desc = lines.join("\n");
  if (config.desc_append_original === "on" && s.description) {
    desc += `\n\n— Original —\n${s.description}`;
  }
  return desc;
}
