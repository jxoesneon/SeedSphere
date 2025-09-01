// Simple shared metadata for trackers fetch timing
let lastFetchTs = 0;

function setLastFetch(ts) {
  const n = Number(ts || Date.now());
  if (Number.isFinite(n) && n > 0) lastFetchTs = n;
}

function getLastFetch() {
  return lastFetchTs;
}

module.exports = { setLastFetch, getLastFetch };
