// Shared test helpers: wait for a condition instead of a fixed pause, so a test takes as long as the game needs.
//   const { ready, quiet, frames, until } = require('./lib');
//   await p.goto(url); await ready(p);          // instead of waitForTimeout(800..1500) after loading the debug page
//   await p.click('#x'); await quiet(p);        // instead of a pause for a (faked) server reply: no request in flight
//   await frames(p);                            // instead of a short pause for the page to redraw
//   await until(p, () => __pal.mus.cur === 'menu')   // instead of a pause for a known state
const tracked = new WeakMap();
function track(p) {   // requests in flight on this page (faked Supabase routes count too)
  let t = tracked.get(p); if (t) return t;
  t = { n: 0, at: Date.now() }; tracked.set(p, t);
  const on = () => { t.n++; t.at = Date.now() }, off = () => { t.n = Math.max(0, t.n - 1); t.at = Date.now() };
  p.on('request', on); p.on('requestfinished', off); p.on('requestfailed', off);
  return t;
}
// the debug page is up: frames running, fonts loaded, account boot done (window.__pal.ready, debug build only)
const ready = (p, timeout = 15000) => (track(p), p.waitForFunction(() => window.__pal && __pal.ready, null, { timeout }));
// no request in flight for `idle` ms (and at least one redraw), up to `timeout`
async function quiet(p, idle = 80, timeout = 10000) {
  const t = track(p), end = Date.now() + timeout;
  await frames(p, 1);
  while (Date.now() < end) { if (!t.n && Date.now() - t.at >= idle) break; await new Promise(r => setTimeout(r, 20)) }
  await frames(p, 1);
}
// n animation frames have been drawn (the page has caught up with what the test just did)
const frames = (p, n = 2) => p.evaluate(n => new Promise(r => { let k = 0; const f = () => ++k >= n ? r() : requestAnimationFrame(f); requestAnimationFrame(f) }), n);
const until = (p, fn, arg, timeout = 10000) => p.waitForFunction(fn, arg, { timeout });
// a networked raid has started: host and guest each see both players (the guest has its first snapshot), then a few frames
async function synced(H, G, timeout = 10000) {
  for (const x of [H, G]) await x.waitForFunction(() => window.__pal && __pal.players.size >= 2 && !!__pal.player, null, { timeout });
  await frames(H, 3); await frames(G, 3);
}
module.exports = { ready, quiet, frames, until, synced, track };
