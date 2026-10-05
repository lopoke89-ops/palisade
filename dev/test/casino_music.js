// v0.10.1 the casino's own playlist: only the casino plays it (and the casino plays nothing else); a true shuffle (each
// of the 11 tracks once per round, a fresh shuffle after, never the same track twice in a row); playlist tracks don't loop;
// the next track decodes in the last minute and comes in over the last CASINO_XF seconds with an equal-power crossfade;
// at most two tracks decoded; mute picks the same track up where it stopped; leaving and coming back moves on.
// Both formats (the ogg run blocks the m4a files). node casino_music.js
const { chromium } = require('playwright'), assert = require('node:assert/strict'), fs = require('node:fs'), { ready, until } = require('./lib');
const PORT = process.env.PORT || 8080;
(async () => {
  const b = await chromium.launch({ executablePath: process.env.CHROMIUM || undefined, args: ['--autoplay-policy=no-user-gesture-required'] }), errors = [], out = {};
  await Promise.all(['m4a', 'ogg'].map(async format => {
    const p = await b.newPage({ viewport: { width: 900, height: 700 } }), o = out[format] = {}; p.on('pageerror', e => errors.push(format + ' ' + e.message));
    if (format === 'ogg') await p.route('**/*.m4a*', r => r.abort());
    await p.goto(`http://localhost:${PORT}/debug.html?debug=1`); await ready(p); await p.mouse.click(5, 5); await p.evaluate(() => __pal.initAudio());
    const now = () => p.evaluate(() => ({ cur: __pal.mus.cur, up: __pal.cas.up, token: __pal.mus.token, loop: __pal.mus.src ? __pal.mus.src.loop : null, decoded: Object.keys(__pal.mus.bufs), t: __pal.AC.currentTime, end: __pal.mus.end, started: __pal.mus.started, starts: __pal.mus.starts }));
    const playing = (fn, arg) => until(p, fn, arg, 60000);
    await playing(() => __pal.mus.cur === 'menu' && !!__pal.mus.src);
    // 1. the shuffle on its own: 5 rounds drawn from a copy of the bag, then the real state put back
    o.rounds = await p.evaluate(() => {
      const c = __pal.cas, keep = { bag: c.bag.slice(), up: c.up, last: c.last }, seq = [];
      c.bag = []; c.up = null; c.last = null;
      for (let i = 0; i < __pal.CASINO.length * 5; i++) { const k = __pal.casinoUp(); seq.push(k); c.up = null; c.last = k }
      Object.assign(c, keep); return seq;
    });
    const n = await p.evaluate(() => __pal.CASINO.length); assert.equal(n, 11);
    for (let r = 0; r < 5; r++) assert.deepEqual(o.rounds.slice(r * n, r * n + n).sort(), (await p.evaluate(() => __pal.CASINO.slice())).sort(), 'round ' + r + ' plays every track once');
    assert.ok(o.rounds.every((k, i) => !i || k !== o.rounds[i - 1]), 'never the same track twice in a row, across rounds too');
    assert.notDeepEqual(o.rounds.slice(0, n), o.rounds.slice(n, 2 * n), 'a fresh shuffle each round');
    // 2. into the casino: a playlist track, not looped, nothing else decoded
    await p.evaluate(() => { __pal.pick.mode = 'casino'; __pal.newGame(null, null); __pal.demo = false; __pal.enterGameHook(); __pal.game.paused = true });
    assert.equal(await p.evaluate(() => __pal.game.mode), 'casino');
    assert.equal(await p.evaluate(() => __pal.musicRoute().k), 'casino');
    await playing(() => /^casino\d+$/.test(__pal.mus.cur) && !!__pal.mus.src);
    o.first = await now();
    assert.equal(o.first.loop, false, 'playlist tracks play once'); assert.deepEqual(o.first.decoded, [o.first.cur], 'only the playing track decoded');
    assert.ok(o.first.up && o.first.up !== o.first.cur, 'the next track is already picked');
    // 3. the last minute: the next one decodes (two at most), then comes in CASINO_XF seconds before the end
    await p.evaluate(() => { const m = __pal.mus; m.end = __pal.AC.currentTime + 40 });
    await playing(up => !!__pal.mus.bufs[up], o.first.up);
    o.preload = await now(); assert.deepEqual(o.preload.decoded.sort(), [o.first.cur, o.first.up].sort());
    const end = await p.evaluate(() => { const m = __pal.mus; return m.end = __pal.AC.currentTime + 7 });
    await playing(up => __pal.mus.cur === up, o.first.up);
    o.xf = await p.evaluate(() => ({ started: __pal.mus.started, retiring: !!__pal.mus.retiring, inGain: __pal.mus.g.gain.value, outGain: __pal.mus.retiring && __pal.mus.retiring.g.gain.value, t: __pal.AC.currentTime }));
    assert.ok(Math.abs(o.xf.started - (end - 5)) < .3, `the next track starts ${await p.evaluate(() => __pal.CASINO_XF)} s before the end (${o.xf.started} vs ${end - 5})`);
    assert.ok(o.xf.retiring, 'the old track is still fading out');
    await until(p, e => __pal.AC.currentTime > e - 2.5, end, 10000);
    o.mid = await p.evaluate(() => ({ in: __pal.mus.g.gain.value, out: __pal.mus.retiring && __pal.mus.retiring.g.gain.value }));
    assert.ok(o.mid.in > .3 && o.mid.in < .95 && o.mid.out > .3 && o.mid.out < .95, 'both tracks audible mid-crossfade: ' + JSON.stringify(o.mid));
    assert.ok(Math.abs(o.mid.in ** 2 + o.mid.out ** 2 - 1) < .1, 'equal power: ' + JSON.stringify(o.mid));
    await until(p, () => __pal.mus.retiring === null, null, 10000);
    o.after = await now(); assert.deepEqual(o.after.decoded, [o.first.up], 'the old track released'); assert.equal(o.after.loop, false);
    assert.ok(o.after.up && o.after.up !== o.after.cur);
    // 4. late decode: the track ends before the next is ready, so the next starts on its own with a fade-in
    await p.evaluate(() => { __pal.mus.end = __pal.AC.currentTime + .1 });
    const late = o.after.up; await playing(k => __pal.mus.cur === k && __pal.mus.src && !__pal.mus.retiring, late);
    // 5. mute and back: the same track, further along
    await until(p, () => __pal.AC.currentTime > __pal.mus.started + 1, null, 10000); const before = await now();
    await p.evaluate(() => { __pal.cfg.music = 0; __pal.musicTick() }); assert.equal(await p.evaluate(() => __pal.mus.cur), null);
    await p.evaluate(() => { __pal.cfg.music = .7; __pal.musicTick() }); await playing(k => __pal.mus.cur === k && !!__pal.mus.src, before.cur);
    assert.ok(await p.evaluate(() => __pal.mus.offset > .9), 'resumed where it stopped');
    // 6. leave: the menu track; nothing from the casino stays decoded. Come back: the next track in the shuffle, not the same one
    const left = await now();
    await p.evaluate(() => __pal.toMenu()); await playing(() => __pal.mus.cur === 'menu' && !!__pal.mus.src);
    await until(p, () => Object.keys(__pal.mus.bufs).every(k => k === 'menu'), null, 5000);
    await p.evaluate(() => { __pal.pick.mode = 'casino'; __pal.newGame(null, null); __pal.demo = false; __pal.enterGameHook(); __pal.game.paused = true });
    await playing(() => /^casino\d+$/.test(__pal.mus.cur) && !!__pal.mus.src);
    o.back = await now(); assert.notEqual(o.back.cur, left.cur, 'coming back moves on'); assert.equal(o.back.cur, left.up, 'to the next track in the shuffle');
    assert.equal(await p.evaluate(() => __pal.mus.offset), 0);
    // 7. the playlist is the casino's alone: other modes never pick it
    await p.evaluate(() => { __pal.toMenu(); __pal.pick.mode = '5'; __pal.showPage('solo') }); await p.click('#startBtn'); await p.evaluate(() => __pal.game.paused = true);
    await playing(() => __pal.mus.cur === 'between' && !!__pal.mus.src);
    for (const [mode, phase] of [['5', 'raid'], ['blitz', 'build'], ['campaign', 'raid']]) { await p.evaluate(([m, ph]) => { __pal.game.mode = m; __pal.game.phase = ph }, [mode, phase]); assert.ok(!/^casino/.test(await p.evaluate(() => __pal.musicWant())), mode) }
    await p.close();
  }));
  assert.deepEqual(errors, []);
  fs.mkdirSync(__dirname + '/out', { recursive: true }); fs.writeFileSync(__dirname + '/out/casino-music.json', JSON.stringify(out, null, 2));
  await b.close(); console.log('Casino playlist: true shuffle, casino only, 5 s equal-power crossfades, two tracks decoded at most, mute resume, late-decode fallback, both formats. errors: none');
})().catch(e => { console.error(e); process.exit(1) });
