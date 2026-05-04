/**
 * Represents a normalized media stream available in the swarm.
 */
export interface Stream {
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

export interface Config {
  auto_proxy?: string;
  desc_append_original?: string;
  sort_order?: string;
  [key: string]: string | undefined;
}
