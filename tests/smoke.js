/* Simple smoke tests for core modules without network calls. */

function assert(cond, msg) {
  if (!cond) throw new Error(msg || 'assertion failed');
}

(async () => {
  try {
    // boosts module
    const boosts = require('../lib/boosts');
    const received = [];
    const unsub = boosts.subscribe((it) => received.push(it));
    boosts.push({ mode: 'basic', limit: 0, healthy: 2, total: 5, source: 'unit', type: 'movie', id: 'x1' });
    boosts.push({ mode: 'aggressive', limit: 10, healthy: 4, total: 10, source: 'unit', type: 'series', id: 'y2' });
    const recent = boosts.recent();
    assert(Array.isArray(recent) && recent.length >= 2, 'boosts.recent should have at least 2 items');
    assert(received.length >= 2, 'subscribe should receive pushed items');
    unsub && unsub();

    // trackers_meta
    const { setLastFetch, getLastFetch } = require('../lib/trackers_meta');
    const before = getLastFetch();
    setLastFetch(Date.now());
    const after = getLastFetch();
    assert(typeof after === 'number' && after >= before, 'trackers_meta last fetch should be numeric and monotonic');

    // health utils
    const { isTrackerUrl, unique } = require('../lib/health');
    assert(isTrackerUrl('udp://tracker.example:80'), 'isTrackerUrl should accept udp');
    assert(isTrackerUrl('https://t.example'), 'isTrackerUrl should accept https');
    assert(!isTrackerUrl('file://nope'), 'isTrackerUrl should reject file');
    const arr = unique(['a', 'b', 'a']);
    assert(Array.isArray(arr) && arr.length === 2, 'unique should deduplicate');

    console.log('All smoke tests passed.');
  } catch (e) {
    console.error('Smoke test failed:', e && e.stack ? e.stack : e);
    process.exit(1);
  }
})();
