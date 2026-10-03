// v0.9.6.4 campaign map evacs: after raids 3, 6 and 9 (not 12) a 15-second evacuation opens; only shieldbearers and
// grenadiers come; the core can't fall; downed players don't respawn; everyone out ends it early. A player left behind still
// moves on, but at 50% health with no salvage, and their claim says which chapters they missed. If nobody makes it, the
// campaign ends ("EVAC FAILED"). node campaign_map_evac.js
const { chromium } = require('playwright'), assert = require('node:assert/strict');
(async () => {
  const b = await chromium.launch({ executablePath: process.env.CHROMIUM || undefined }), errors = [], out = {};
  const p = await b.newPage({ viewport: { width: 1280, height: 800 } }); p.on('pageerror', e => errors.push(e.message));
  await p.goto(`http://localhost:${process.env.PORT || 8080}/debug.html?debug=1`); await p.waitForFunction(() => window.__pal);
  const fresh = (bots = 0) => p.evaluate(async bots => { const P = __pal; if (P.toMenu) P.toMenu(); P.pick.mode = 'campaign'; P.pick.size = 'std'; P.showPage('solo'); document.getElementById('startBtn').click(); await new Promise(r => setTimeout(r, 300));
    let s = 7; Math.random = () => (s = (s * 16807) % 2147483647) / 2147483647;
    for (let i = 0; i < bots; i++) { const q = P.makePlayer('bot' + i, 'Bot' + i, 'soldier', i + 1, '', ''); q.x = P.core.i + .5 + i; q.y = P.core.j + 2; P.players.set('bot' + i, q) }
    // the page's own loop is held paused between steps; only the test advances the game
    window.step = dt => { P.game.paused = false; P.update(dt); if (P.game.phase !== 'over') P.game.paused = true };
    window.endRaid = w => { const g = P.game; g.wave = w; g.phase = 'raid'; g.queue = []; for (const e of P.enemies) e.dead = true; P.enemies.length = 0; step(1 / 30) };
    window.run = (sec, fn) => { for (let i = 0; i < sec * 30 && P.game.phase !== 'over'; i++) { if (fn) fn(); step(1 / 30) } };
    P.game.paused = true }, bots);

  // 1. after raid 3: a 15 s map evac, ring open at once; raiders are only shieldbearers and grenadiers; the core can't fall
  await fresh();
  out.open = await p.evaluate(() => { const P = __pal, g = P.game; endRaid(3); const F = g.fb;
    const r = { mapEvac: !!(F && F.mapEvac), t: F && F.t, ring: !!(F && F.evac), r: F && F.evac && F.evac.r, phase: g.phase, ch: g.chapter, map: g.map, label: '' };
    const types = new Set(); P.player.x = P.core.i + .5; P.player.y = P.core.j + .5; P.core.hp = 1;
    run(10, () => { P.player.hp = P.player.max; for (const e of P.enemies) types.add(e.type); for (const k of g.queue) types.add(k); P.core.hp = 0 });
    r.types = [...types].sort(); r.stillRunning = g.phase === 'raid' && !!g.fb && !g.fb.done; P.core.hp = P.core.max; return r });
  assert.deepEqual({ ...out.open, types: undefined, label: undefined }, { mapEvac: true, t: 15, ring: true, r: 1.5, phase: 'raid', ch: 0, map: 'yard', stillRunning: true, types: undefined, label: undefined });
  assert.ok(out.open.types.length > 0 && out.open.types.every(t => t === 'shield' || t === 'gren'), 'only shieldbearers and grenadiers: ' + out.open.types);
  // 2. standing in the ring 3 s gets you out; everyone out ends it early and the next map loads with a build phase
  out.extract = await p.evaluate(() => { const P = __pal, g = P.game, E = g.fb.evac; run(3.3, () => { P.player.x = E.x; P.player.y = E.y; P.player.hp = P.player.max });
    return { map: g.map, ch: g.chapter, phase: g.phase, fb: !!g.fb, chEvac: P.player.chEvac, out: !!P.player.out, alive: P.player.alive, hp: P.player.hp === P.player.max } });
  assert.deepEqual(out.extract, { map: 'river', ch: 1, phase: 'build', fb: false, chEvac: [1], out: false, alive: true, hp: true });

  // 3. two soldiers: one makes it, one doesn't. The one left behind comes along at half health with no salvage
  await fresh(1);
  out.left = await p.evaluate(() => { const P = __pal, g = P.game, bot = P.players.get('bot0'); bot.sal = 40; P.player.sal = 40; endRaid(3); const E = g.fb.evac;
    window.__bh = undefined; run(16, () => { if (!g.fb) { if (window.__bh === undefined) window.__bh = bot.hp / bot.max; return } P.player.x = E.x; P.player.y = E.y; for (const q of P.players.values()) if (!q.out) q.hp = q.max; bot.x = P.core.i + .5; bot.y = P.core.j + .5 });
    return { map: g.map, me: P.player.chEvac, bot: bot.chEvac, botHp: Math.round(100 * window.__bh),   // read when the next map loads (health regenerates in the build phase)
       botSal: bot.sal - (8 + 3), mySal: P.player.sal > 40, claim: P.runClaim(3, false, 0).claim } });
  assert.equal(out.left.map, 'river'); assert.deepEqual(out.left.me, [1]); assert.deepEqual(out.left.bot, [0]);
  assert.equal(out.left.botHp, 50); assert.equal(out.left.botSal, 0, 'left behind: no salvage carried over (just the build pay)'); assert.ok(out.left.mySal, 'the one who made it keeps salvage');
  assert.equal(out.left.claim.cv, 4); assert.deepEqual(out.left.claim.ch_evac, [true, null, null]);
  // 4. downed in a map evac: no respawn clock; the wire encoding round-trips
  out.down = await p.evaluate(() => { const P = __pal, g = P.game, me = P.player; endRaid(6); P.hurtPlayer(me, 1e9); run(.5); const r = { downed: me.downed || !me.alive, rt: me.rt > 1e5, mapEvac: !!(g.fb && g.fb.mapEvac) };
    r.bits = P.chEvacFrom(P.chEvacBits({ chEvac: [1, 0, 1] })); r.none = P.chEvacFrom(P.chEvacBits({ chEvac: [] })); return r });
  assert.deepEqual(out.down, { downed: true, rt: true, mapEvac: true, bits: [1, 0, 1], none: [] });
  // 5. nobody makes it: the campaign ends, EVAC FAILED · CHAPTER 2, raids broken count in full
  out.fail = await p.evaluate(async () => { const P = __pal, g = P.game; run(16, () => { for (const q of P.players.values()) { q.x = P.core.i + .5; q.y = P.core.j + .5 } });
    await new Promise(r => setTimeout(r, 1200)); return { phase: g.phase, reason: g.endReason, won: g.won, eyebrow: document.getElementById('overEyebrow').textContent, lede: document.getElementById('overLede').textContent } });
  assert.equal(out.fail.phase, 'over'); assert.equal(out.fail.reason, 'evacfail'); assert.equal(out.fail.won, false);
  assert.match(out.fail.eyebrow, /EVAC FAILED · CHAPTER 2/); assert.match(out.fail.lede, /Nobody made the convoy out of RIVERBEND/);
  // 6. the evac comes after raids 3, 6 and 9 only; raid 12 goes straight to its build phase
  await fresh();
  out.which = await p.evaluate(() => { const P = __pal, g = P.game, seen = [];
    for (let w = 1; w <= 12; w++) { endRaid(w); if (g.fb && g.fb.mapEvac) { seen.push(w); P.player.out = true; P.finishMapEvac() } }
    return { seen, map: g.map, phase: g.phase, fb: !!g.fb } });
  assert.deepEqual(out.which, { seen: [3, 6, 9], map: 'frost', phase: 'build', fb: false });
  assert.deepEqual(errors, []); console.log(JSON.stringify(out)); console.log('errors: none'); await b.close();
})().catch(e => { console.error(e); process.exit(1) });
