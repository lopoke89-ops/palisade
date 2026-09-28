// v0.9.2 skill tree: a mock account server. Points from a finished run (1 per 5 raids, 1 per boss), the SKILLS page
// (points, buying, a node that needs another first, maxed nodes, the reset for shards that asks twice), the perks in
// a run (and at half strength in PvP), the class abilities (soldier rockets, sniper stealth, grenadier Molotovs,
// quartermaster Long Stride; all off in PvP), and the host checking a guest's tree with the server. node skilltree.js
const { chromium } = require('playwright'), assert = require('node:assert/strict');
const A = 'aaaaaaaa-aaaa-4aaa-aaaa-aaaaaaaaaaaa', B = 'bbbbbbbb-bbbb-4bbb-bbbb-bbbbbbbbbbbb';
const DEFS = { dmg: [1, 2, 3], rate: [1, 2, 3], reload: [1, 2], range: [1, 2], hp: [1, 2, 3], regen: [2, 3], revive: [1, 2], speed: [1, 2, 3], vest: [2, 3], haul: [1, 2], rockets: [1, 2, 3], pouch: [2, 3], molotov: [3], ghillie: [1, 2], stride: [1, 2] };
const L = { owned: ['skin:std', 'hat:class', 'hat:cap', 'trail:std', 'fx:none'], eq: { skin: 'std', hat: 'class', trail: 'std', fx: 'none' }, cases: 0, bag: {}, shards: 55, prog: 0, st: { raids: 0, wins: 0, drops: 0, endless: 0, hardWins: 0 },
  imported: true, sp: 0, sp_prog: 3, sp_total: 0, skills: {}, rev: 1 };
const others = { [B]: { dmg: 3, hp: 1 } };   // what the server says player B has
const token = id => Buffer.from('{}').toString('base64url') + '.' + Buffer.from(JSON.stringify({ sub: id, is_anonymous: false })).toString('base64url') + '.test';
const session = id => ({ access_token: token(id), refresh_token: 'fixture', expires_at: Math.floor(Date.now() / 1000) + 3600, user: { id, email: 'a@example.invalid', is_anonymous: false, user_metadata: { pw: true } } });
const calls = [], claims = [];
const spent = t => Object.entries(t).reduce((n, [k, v]) => n + DEFS[k].slice(0, v).reduce((a, b) => a + b, 0), 0);
const rpc = {
  get_my_locker: () => L,
  skill_buy: a => { const d = DEFS[a.p_node]; if (!d) return [400, { message: 'Unknown skill' }]; const lv = L.skills[a.p_node] | 0; if (lv >= d.length) return [400, { message: 'That skill is maxed' }];
    if (a.p_node === 'molotov' && !(L.skills.pouch >= 1)) return [400, { message: 'Unlock pouch first' }];
    if (L.sp < d[lv]) return [400, { message: `That takes ${d[lv]} skill points` }]; L.sp -= d[lv]; L.skills[a.p_node] = lv + 1; L.rev++; return L },
  skill_respec: () => { const back = spent(L.skills); if (!back) return [400, { message: 'There are no points in your tree' }]; if (L.shards < 40) return [400, { message: 'Resetting takes 40 shards' }];
    L.sp += back; L.skills = {}; L.shards -= 40; L.rev++; return L },
  skills_of: a => others[a.p_uid] || {},
  claim_match_reward: a => { const p = a.p; claims.push(p); const held = (p.raid_to | 0) - (p.raid_from | 0); L.sp_prog += held; const pts = Math.floor(L.sp_prog / 5) + (p.boss_keys || []).length; L.sp_prog %= 5; L.sp += pts; L.sp_total += pts;
    return { cases: { supply: 1 }, shards: 0, unlocked_ids: [], to_next: 2, skill_points: pts, sp: L.sp, sp_to_next: 5 - L.sp_prog, cases_granted: 1, locker: L } },
  social_state: () => ({ friends: [], incoming: [], outgoing: [], notes: [], unseen: 0 })
};
(async () => {
  const b = await chromium.launch({ executablePath: process.env.CHROMIUM || undefined }), errors = [], out = {};
  process.on('exit', () => console.log('OUT', JSON.stringify(out)));
  const ctx = await b.newContext({ viewport: { width: 1400, height: 900 } });
  await ctx.route('https://puvjfhwxigxjpsvdwrwf.supabase.co/**', async route => {
    const req = route.request(), url = new URL(req.url()), path = url.pathname; let data = {}, status = 200;
    if (path === '/auth/v1/user') data = session(A).user;
    else if (path === '/rest/v1/profiles') data = [{ id: A, username: 'Captain', cos: '' }];
    else if (path === '/rest/v1/lobbies') data = [];
    else if (path.startsWith('/rest/v1/rpc/')) { const fn = path.slice(13); calls.push(fn); const f = rpc[fn]; if (!f) { status = 404; data = { message: 'unhandled' } } else { const r = f(req.postDataJSON() || {}); if (Array.isArray(r)) [status, data] = r; else data = JSON.parse(JSON.stringify(r)) } }
    else { status = 404; data = { message: 'unhandled' } }
    await route.fulfill({ status, contentType: 'application/json', body: JSON.stringify(data) }) });
  const p = await ctx.newPage(); p.on('pageerror', e => errors.push(e.message));
  await p.addInitScript(s => localStorage.setItem('palisade.auth.v1', JSON.stringify(s)), session(A));
  await p.goto('http://localhost:8080/debug.html?debug=1&cloud=1'); await p.waitForFunction(() => __pal.acct.state === 'full' && !!__pal.locker.cloud, null, { timeout: 15000 });
  // 1. a 10-raid run with one boss: 3 + 10 raids = 2 points toward the tree, +1 for the boss
  await p.evaluate(() => { const P = __pal; P.demo = false; P.pick.mode = '10'; P.newGame(null, ''); P.enterGameHook(); P.game.wave = 10; P.game.won = true; P.game.time = 900; P.game.bossLog = ['demolisher']; P.game.phase = 'over'; P.showOver() });
  await p.waitForFunction(() => __pal.locker.sp === 3, null, { timeout: 8000 });
  out.claim = { from: claims[0].raid_from, to: claims[0].raid_to, gid: !!claims[0].game_id, mods: claims[0].mods };
  out.card = await p.evaluate(() => [...document.querySelectorAll('#overRewards .rwSkill small')].map(s => s.textContent)); assert.deepEqual(out.card, ['SKILL POINTS']);
  out.loot = await p.textContent('#overLoot'); assert.match(out.loot, /\+3 skill points/);
  await p.evaluate(() => __pal.toMenu());
  out.nav = await p.textContent('#navSkills'); assert.equal(out.nav, 'SKILLS · 3');
  // 2. the SKILLS page
  await p.click('#navSkills'); await p.waitForSelector('#pg-skills:not([hidden])');
  out.page = await p.evaluate(() => ({ pts: document.getElementById('skPts').textContent, rows: document.querySelectorAll('#skTree .skRow').length, lede: document.getElementById('skLede').textContent }));
  assert.equal(out.page.pts, '3'); assert.equal(out.page.rows, 15); assert.match(out.page.lede, /2 more to the next one/);
  out.molotovLocked = await p.textContent('[data-sk=molotov]'); assert.match(out.molotovLocked, /NEEDS EXTRA POUCH/);
  await p.click('[data-sk=dmg]'); await p.waitForFunction(() => __pal.locker.skills.dmg === 1);
  await p.click('[data-sk=pouch]'); await p.waitForFunction(() => __pal.locker.skills.pouch === 1);
  out.afterBuy = await p.evaluate(() => ({ sp: __pal.locker.sp, dmgBtn: document.querySelector('[data-sk=dmg]').textContent, cant: document.querySelector('[data-sk=molotov]').disabled, str: __pal.mySkills() }));
  assert.deepEqual(out.afterBuy, { sp: 0, dmgBtn: '2 PTS', cant: true, str: '100000000001000' });
  await p.screenshot({ path: __dirname + '/out/skilltree.png' });
  // reset: asks once more, costs 40 shards, every point comes back
  await p.click('#skReset'); out.ask = await p.textContent('#skReset'); assert.equal(out.ask, 'TAP AGAIN TO RESET'); assert.ok(!calls.includes('skill_respec'));
  await p.click('#skReset'); await p.waitForFunction(() => __pal.locker.sp === 3 && !__pal.locker.skills.dmg);
  out.afterReset = { shards: L.shards, sp: L.sp }; assert.deepEqual(out.afterReset, { shards: 15, sp: 3 });
  await p.waitForTimeout(100); out.resetOff = await p.evaluate(() => document.getElementById('skReset').disabled); assert.equal(out.resetOff, true, 'nothing to reset (and not enough shards)');
  // 3. perks in a run: give this phone a full tree (as if the server had it) and check the numbers
  out.perks = await p.evaluate(() => { const P = __pal; P.locker.skills = { dmg: 3, rate: 3, hp: 3, speed: 3, vest: 2, haul: 2, rockets: 3, pouch: 2, molotov: 1, ghillie: 2, stride: 2, regen: 2, revive: 2, reload: 2, range: 2 };
    const mk = (cls, pvp) => { P.pick.cls = cls; P.newGame([{ id: 'solo', name: 'A', cls, cos: '', sk: P.mySkills() }, ...(pvp ? [{ id: 'b', name: 'B', cls: 'soldier', cos: '' }] : [])], pvp); return P.player };
    const s = mk('soldier', ''), base = P.CLASSES.soldier;
    const r = { dmg: +(s.gun.dmg / base.gun.dmg).toFixed(3), max: s.max, cap: s.cap[0], rk: s.rk, ab: s.ab };
    const g = mk('grenadier', ''); r.gNades = g.maxN;
    const pv = mk('soldier', 'ffa'); r.pvpDmg = +(pv.gun.dmg / base.gun.dmg).toFixed(3); r.pvpMax = pv.max; r.pvpRockets = pv.rk; r.pvpAbility = P.hasAbilityHook ? null : undefined;
    return r });
  assert.equal(out.perks.dmg, 1.12); assert.equal(out.perks.max, Math.round(115 * 1.18)); assert.equal(out.perks.cap, 64 + 16); assert.equal(out.perks.rk, 8); assert.equal(out.perks.gNades, 5);
  assert.equal(out.perks.pvpDmg, 1.06, 'PvP: half strength'); assert.equal(out.perks.pvpRockets, 0);
  // 4. soldier rockets: fire at raiders, count down, 2 back each build phase
  out.rockets = await p.evaluate(() => { const P = __pal; P.pick.cls = 'soldier'; P.newGame([{ id: 'solo', name: 'A', cls: 'soldier', cos: '', sk: P.mySkills() }], ''); P.enterGameHook(); P.startRaid(); P.game.queue = [];
    for (const e of P.enemies) e.dead = true; P.update(.02); const pl = P.player; [pl.x, pl.y] = [3.5, 3.5]; for (let k = 0; k < P.N * P.N; k++) P.walls[k] = null;
    const e = P.spawnEnemyAt('shield', 7.5, 3.5); e.speed = 0; e.cd = 99; const hp0 = e.hp;
    P.useAbility(pl, 7.5, 3.5); const shot = { rk: pl.rk, rockets: P.rockets.length, ab: pl.ab }; P.useAbility(pl, 7.5, 3.5); const tooSoon = pl.rk;
    for (let i = 0; i < 40; i++) P.updateRockets(.02); shot.hit = +(hp0 - e.hp).toFixed(0);
    pl.rk = 1; P.startRaid(); P.game.queue = []; for (const x of P.enemies) x.dead = true; for (let i = 0; i < 4; i++) P.update(.05); shot.afterBuild = pl.rk; shot.tooSoon = tooSoon; return shot });
  assert.equal(out.rockets.rk, 7); assert.equal(out.rockets.rockets, 1); assert.equal(out.rockets.ab, 7); assert.equal(out.rockets.tooSoon, 7, '1.5 s between rockets'); assert.ok(out.rockets.hit > 60); assert.equal(out.rockets.afterBuild, 3);
  // 5. sniper stealth: raiders stop targeting you, then it recharges
  out.stealth = await p.evaluate(() => { const P = __pal; P.pick.cls = 'sniper'; P.newGame([{ id: 'solo', name: 'A', cls: 'sniper', cos: '', sk: P.mySkills() }], ''); P.enterGameHook(); P.startRaid(); P.game.queue = [];
    for (const e of P.enemies) e.dead = true; P.update(.02); const pl = P.player; [pl.x, pl.y] = [4.5, 4.5]; for (let k = 0; k < P.N * P.N; k++) P.walls[k] = null;
    const e = P.spawnEnemyAt('rifle', 7.5, 4.5); e.speed = 0; e.scanT = 0; P.updateEnemies(.02); const before = e.foe === pl;
    P.useAbility(pl, 0, 0); const len = +pl.stl.toFixed(1); e.scanT = 0; P.updateEnemies(.02); const during = e.foe; const seen = P.stealthed(pl);
    for (let i = 0; i < 400; i++) P.update(.05); return { before, len, during: during === null, seen, after: pl.stl, cd: Math.round(pl.stlCd), ab: pl.ab } });
  assert.deepEqual({ ...out.stealth, cd: out.stealth.cd > 0 }, { before: true, len: 18, during: true, seen: true, after: 0, cd: true, ab: -out.stealth.cd });
  // 6. grenadier Molotovs: burning ground that hurts raiders, not you; the switch turns it off
  const molo = off => p.evaluate(off => { const P = __pal; P.cfgMol = off; localStorage.setItem('x', 1); P.pick.cls = 'grenadier'; const sk = P.skillStr(P.locker.skills, off);
    P.newGame([{ id: 'solo', name: 'A', cls: 'grenadier', cos: '', sk }], ''); P.enterGameHook(); const pl = P.player; [pl.x, pl.y] = [2.5, 2.5]; pl.ncd = 0;
    P.throwNade(pl, 5.5, 5.5); for (let i = 0; i < 30; i++) P.updateLobs(.05); return P.fires2.filter(f => f.pl).length }, off);
  out.molotov = [await molo(false), await molo(true)]; assert.deepEqual(out.molotov, [1, 0]);
  // 7. PvP: no abilities
  out.pvpAb = await p.evaluate(() => { const P = __pal; P.newGame([{ id: 'solo', name: 'A', cls: 'soldier', cos: '', sk: P.mySkills() }, { id: 'b', name: 'B', cls: 'sniper', cos: '' }], 'ffa'); P.enterGameHook();
    const pl = P.player; P.useAbility(pl, 5, 5); P.hud(0); return { rockets: P.rockets.length, btn: document.getElementById('abBtn').hidden } });
  assert.deepEqual(out.pvpAb, { rockets: 0, btn: true });
  // 8. the host checks a guest's tree: only what the server says they have counts
  out.check = await p.evaluate(async B => { const P = __pal, c = { pid: 'g9', uid: B }; P.NET.roster.push({ id: 'g9', name: 'B', cls: 'soldier', cos: '', sk: '' });
    P.checkSkills(c, P.skillStr({ dmg: 3, hp: 3, rockets: 3 })); await new Promise(r => setTimeout(r, 600)); const noAcct = { pid: 'g8', uid: '' }; P.checkSkills(noAcct, '333333333333333');
    return { verified: c.sk, noAccount: noAcct.sk } }, B);
  assert.deepEqual(out.check, { verified: '300010000000000', noAccount: '' });
  console.log(JSON.stringify(out)); console.log('errors:', errors.length ? errors : 'none'); assert.equal(errors.length, 0); await b.close();
})().catch(e => { console.log('Error:', e.message, (e.stack || '').split('\n').find(l => /skilltree.js/.test(l))); process.exit(1) });
