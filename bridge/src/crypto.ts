/**
 * Canonicalizes a JSON-compatible object by sorting keys alphabetically.
 * Ensures consistent serialization for cryptographic signing.
 */
export function canonicalize(obj: any): string {
  if (obj === null || typeof obj !== 'object') {
    return JSON.stringify(obj);
  }

  if (Array.isArray(obj)) {
    return '[' + obj.map(canonicalize).join(',') + ']';
  }

  const sortedKeys = Object.keys(obj).sort();
  const pairs = sortedKeys.map((key) => {
    return `${JSON.stringify(key)}:${canonicalize(obj[key])}`;
  });

  return '{' + pairs.join(',') + '}';
}
