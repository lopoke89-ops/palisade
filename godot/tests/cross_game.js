// Cross-play, game to game: the browser build (debug.html in Chromium) and the Godot build (main.tscn) in one room.
//   node godot/tests/cross_game.js [--site DIR] [--godot BIN]        (exit 0 = pass)
// 1: Godot hosts, the browser joins as a guest. 2: the browser hosts, Godot joins.
// Both sides play through their real lobby and game code; the browser's Supabase calls are blocked (no live accounts).
// Starts dev/test/peer-server.js and a static server for the site; the Godot half is tests/cross_game_driver.gd.
const path = require('path'), fs = require('fs'), http = require('http'), net = require('net'), os = require('os');
const { spawn } = require('child_process');
const { chromium } = require('../../dev/test/node_modules/playwright');

const arg = (k, d) => { const i = process.argv.indexOf(k); return i > 0 ? process.argv[i + 1] : d };
const ROOT = path.resolve(__dirname, '..');
const SCRATCH = '/tmp/claude-0/-home-user-palisade/1491750c-0eda-570d-b463-0b660096a613/scratchpad';
const SITE = arg('--site', process.env.PALISADE_SITE || path.join(SCRATCH, 'site'));
const GODOT = arg('--godot', process.env.GODOT || path.join(SCRATCH, 'godot/Godot_v4.7.2-stable_linux.x86_64'));
const CHROMIUM = process.env.CHROMIUM || (() => {
  const base = process.env.PLAYWRIGHT_BROWSERS_PATH || '/opt/pw-browsers';
  try { for (const d of fs.readdirSync(base).filter(d => /^chromium-\d+$/.test(d)).sort().reverse()) { const exe = path.join(base, d, 'chrome-linux', 'chrome'); if (fs.existsSync(exe)) return exe } } catch (e) { }
  return undefined;
})();
const Q = 'peerhost=127.0.0.1&peerport=9000&peerpath=/&debug=1';
const sleep = ms => new Promise(r => setTimeout(r, ms));
const until = async (f, ms) => { const end = Date.now() + ms; while (Date.now() < end) { const v = await f(); if (v) return v; await sleep(150) } return await f() };
const portUp = port => new Promise(res => { const s = net.connect(port, '127.0.0.1'); s.on('connect', () => { s.destroy(); res(true) }); s.on('error', () => res(false)) });
let fails = 0, passes = 0;
const check = (ok, what) => { console.log((ok ? 'PASS ' : 'FAIL ') + what); ok ? passes++ : fails++ };

function serve(dir) {
  const types = { '.html': 'text/html', '.js': 'text/javascript', '.json': 'application/json', '.png': 'image/png', '.woff2': 'font/woff2', '.ogg': 'audio/ogg', '.m4a': 'audio/mp4', '.webmanifest': 'application/manifest+json' };
  const srv = http.createServer((q, r) => {
    const f = path.join(dir, decodeURIComponent(q.url.split('?')[0]).replace(/^\/+/, '') || 'index.html');
    fs.readFile(f, (e, b) => { if (e) { r.writeHead(404); r.end(); return } r.writeHead(200, { 'content-type': types[path.extname(f)] || 'application/octet-stream' }); r.end(b) });
  });
  return new Promise(res => srv.listen(0, '127.0.0.1', () => res(srv)));
}

function godot(role, dir) {
  const p = spawn(GODOT, ['--headless', '--path', ROOT, '--script', 'res://tests/cross_game_driver.gd', '--', '--role', role, '--dir', dir], { stdio: ['ignore', 'pipe', 'pipe'] });
  const g = { lines: [], exit: null, errs: 0 };
  let buf = '';
  p.stdout.on('data', d => { buf += d; let i; while ((i = buf.indexOf('\n')) >= 0) { const l = buf.slice(0, i); buf = buf.slice(i + 1); if (/^(OK|FAIL|DRIVER)/.test(l)) { g.lines.push(l); console.log('  godot: ' + l) } else if (/SCRIPT ERROR/.test(l)) { if (g.errs++ < 5) console.log('  godot! ' + l) } } });
  p.stderr.on('data', d => { const s = String(d); if (/SCRIPT ERROR/.test(s) && g.errs++ < 5) console.log('  godot! ' + s.split('\n')[0]) });
  p.on('exit', c => { g.exit = c });
  return g;
}
const exists = (dir, f) => fs.existsSync(path.join(dir, f));
const put = (dir, f, t) => fs.writeFileSync(path.join(dir, f), t);

async function page(b, port, errs, tag) {
  const p = await b.newPage({ viewport: { width: 1280, height: 720 } });
  p.on('pageerror', e => errs.push(tag + ' ' + e.message));
  await p.route(/supabase\.co|palisade-turn|workers\.dev/, r => r.abort());   // never touch the live project
  await p.goto(`http://127.0.0.1:${port}/debug.html?${Q}`);
  await p.waitForFunction(() => window.__pal && __pal.ready, null, { timeout: 20000 });
  return p;
}

async function godotHosts(b, port) {
  console.log('1: Godot hosts, the browser joins');
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'xg1-')), errs = [];
  const G = godot('host', dir);
  const code = await until(() => exists(dir, 'code.txt') && fs.readFileSync(path.join(dir, 'code.txt'), 'utf8').trim(), 30000);
  check(!!code, 'Godot opened a room: ' + code);
  const P = await page(b, port, errs, 'GUEST');
  await P.click('[data-go=multi]'); await P.fill('#mName', 'Rook');
  await P.click('[data-setup=job]:visible'); await P.click('#setupSheet [data-c=grenadier]'); await P.click('#setupDone');
  await P.fill('#mCode', code); await P.click('#joinBtn');
  const inLobby = await P.waitForSelector('#pg-lobby:not([hidden])', { timeout: 20000 }).then(() => true, () => false);
  check(inLobby, 'the browser is in the Godot room\'s lobby');
  check(await until(() => P.evaluate(() => __pal.NET.roster.length === 2 && __pal.NET.roster[0].name === 'Godot'), 8000), 'the browser lists the Godot host by name');
  await P.click('#lReady');
  check(await until(() => P.evaluate(() => document.getElementById('menu').hidden && __pal.players.size === 2 && !!__pal.player), 30000), 'the match starts in the browser');
  check(await P.evaluate(() => __pal.player.id === 'g1' && __pal.player.cls === 'grenadier' && __pal.players.get('host').cls === 'soldier'), 'the browser has the crew: itself a grenadier, the Godot host a soldier');
  await P.keyboard.down('KeyD'); await sleep(1300); await P.keyboard.up('KeyD');
  await P.keyboard.down('KeyS'); await sleep(500); await P.keyboard.up('KeyS');
  check(await until(() => exists(dir, 'moved.txt'), 20000), 'Godot saw the browser walk');
  put(dir, 'rollnow.txt', '1');
  check(await until(() => exists(dir, 'rollgo.txt'), 20000), 'Godot is watching for the roll');
  check(await P.evaluate(() => { const q = __pal.player; q.aim = { x: 1, y: 0 }; __pal.localRoll(); return __pal.rolling(q) }), 'the browser rolls');
  check(await until(() => exists(dir, 'hostrolled.txt') && P.evaluate(() => __pal.rolling(__pal.players.get('host'))), 15000), 'the browser sees the Godot host roll');
  // a wall through the browser's own build message, at whichever neighbour the host accepts
  await P.evaluate(() => { const p = __pal.player, i = Math.floor(p.x), j = Math.floor(p.y); for (const [a, c] of [[0, 1], [1, 0], [0, -1], [-1, 0], [1, 1], [-1, 1]]) __pal.NET.toHost({ t: 'b', i: i + a, j: j + c, s: 0, d: false }) });
  const hw = await until(() => exists(dir, 'hostwall.txt') && fs.readFileSync(path.join(dir, 'hostwall.txt'), 'utf8').trim(), 30000);
  if (hw) { const [i, j] = hw.split(',').map(Number); check(await until(() => P.evaluate(([i, j]) => !!__pal.walls[j * 16 + i], [i, j]), 8000), 'the Godot host\'s wall appears in the browser (' + hw + ')') }
  check(await until(() => exists(dir, 'raid.txt') && P.evaluate(() => __pal.game.phase === 'raid' && __pal.enemies.length > 0), 20000), 'Godot\'s raiders show up in the browser');
  check(await P.evaluate(() => __pal.enemies.every(e => typeof e.type === 'string' && e.hp > 0 && e.hp <= 1)), 'raider rows decode (types, health shares)');
  await P.evaluate(() => __pal.NET.toHost({ t: 'c', m: 'hello from browser' }));
  check(await until(() => P.evaluate(() => (document.getElementById('chatLog') || {}).textContent || '').then(t => t.includes('hello from godot')), 15000), 'Godot\'s chat line shows in the browser');
  check(await until(() => exists(dir, 'hurt.txt') && P.evaluate(() => __pal.player.downed || !__pal.player.alive), 20000), 'the Godot host knocks the browser down; the browser shows it');
  put(dir, 'sawdown.txt', '1');
  await sleep(1500);
  check(errs.length === 0, 'no browser errors' + (errs.length ? ': ' + errs.slice(0, 3).join(' | ') : ''));
  put(dir, 'done.txt', '1');
  await until(() => G.exit !== null, 20000);
  check(G.exit === 0 && G.lines.includes('DRIVER PASS'), 'the Godot side passed');
  check(G.errs === 0, 'no Godot script errors (' + G.errs + ')');
  await P.close();
}

async function browserHosts(b, port) {
  console.log('2: the browser hosts, Godot joins');
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'xg2-')), errs = [];
  const G = godot('guest', dir);
  const H = await page(b, port, errs, 'HOST');
  await H.click('[data-go=multi]'); await H.fill('#mName', 'Big U');
  await H.click('[data-setup=job]:visible'); await H.click('#setupSheet [data-c=quartermaster]'); await H.click('#setupDone');
  await H.click('#hostBtn');
  await H.waitForSelector('#pg-lobby:not([hidden])', { timeout: 15000 });
  const code = (await H.textContent('#lCode')).trim();
  check(/^[A-Z0-9]{4}$/.test(code), 'the browser opened a room: ' + code);
  put(dir, 'code.txt', code);
  check(await until(() => H.evaluate(() => __pal.NET.roster.length === 2 && __pal.NET.roster[1].name === 'Godot' && __pal.NET.roster[1].cls === 'sniper'), 30000), 'Godot joins the browser\'s lobby as a sniper');
  check(await until(() => H.evaluate(() => __pal.NET.roster[1] && __pal.NET.roster[1].ready), 20000), 'Godot readies up');
  await H.click('#lStart');
  check(await until(() => H.evaluate(() => document.getElementById('menu').hidden && __pal.players.size === 2), 10000), 'the browser starts the match with Godot in it');
  const x0 = await H.evaluate(() => { const g = __pal.players.get('g1'); return [g.x, g.y] });
  check(await until(() => exists(dir, 'moved.txt'), 20000), 'Godot walked');
  check(await until(() => H.evaluate(([x, y]) => { const g = __pal.players.get('g1'); return Math.hypot(g.x - x, g.y - y) > 0.6 }, x0), 6000), 'the browser host sees Godot walk');
  put(dir, 'hostsaw.txt', '1');
  const r0 = await H.evaluate(() => { const g = __pal.players.get('g1'); return [g.x, g.y, g.tp] });
  put(dir, 'rollgo.txt', '1');
  check(await until(() => H.evaluate(() => __pal.rolling(__pal.players.get('g1'))), 15000), 'Godot\'s roll reaches the browser host');
  await sleep(1500);
  const r1 = await H.evaluate(() => { const g = __pal.players.get('g1'); return [g.x, g.y, g.tp, g.dgCd] }), rd = Math.hypot(r1[0] - r0[0], r1[1] - r0[1]);
  check(rd > 1.2 && rd < 2.3 && r1[2] === r0[2] && r1[3] > 0, `it travels on the browser host without a refused step (${rd.toFixed(2)} tiles, tp ${r0[2]} -> ${r1[2]})`);
  await H.evaluate(() => { const q = __pal.player; q.aim = { x: 0, y: 1 }; __pal.localRoll() });
  put(dir, 'hostrolled.txt', '1');
  const bt = await until(() => exists(dir, 'built.txt') && fs.readFileSync(path.join(dir, 'built.txt'), 'utf8').trim(), 20000);
  if (bt) { const [i, j] = bt.split(',').map(Number); const ok = await until(() => H.evaluate(([i, j]) => !!__pal.walls[j * 16 + i], [i, j]), 8000); check(ok, 'Godot\'s wall stands on the browser host (' + bt + ')'); if (ok) put(dir, 'wallok.txt', '1') }
  else check(false, 'Godot built nothing');
  await H.evaluate(() => { __pal.startRaid(); for (const p of __pal.players.values()) { p.max = 99999; p.hp = 99999 } });
  await sleep(2500);
  await H.evaluate(() => { const P = __pal; P.spawnBoss('butcher'); const e = P.enemies[P.enemies.length - 1], g = P.players.get('g1'); e.x = Math.min(14.5, g.x + 3); e.y = g.y; e.cd = .1 });
  // the host's chat line, as hostChat sends it
  await H.evaluate(() => { const NET = __pal.NET; for (const c of NET.conns.values()) if (c.pid) try { c.r.send({ t: 'c', id: 'host', n: 'Big U', m: 'hello from godot', tm: '' }) } catch (e) { } });
  await sleep(6000);
  await H.evaluate(() => { const g = __pal.players.get('g1'); g.max = 115; __pal.hurtPlayer(g, 99999) });
  check(await until(() => exists(dir, 'sawdown.txt'), 20000), 'Godot saw itself knocked down by the browser host');
  await sleep(1000);
  check(errs.length === 0, 'no browser errors' + (errs.length ? ': ' + errs.slice(0, 3).join(' | ') : ''));
  put(dir, 'done.txt', '1');
  await until(() => G.exit !== null, 20000);
  check(G.exit === 0 && G.lines.includes('DRIVER PASS'), 'the Godot side passed');
  check(G.errs === 0, 'no Godot script errors (' + G.errs + ')');
  await H.close();
}

async function godotHostsFfa(b, port) {
  console.log('3: Godot hosts a Free-for-all, the browser joins');
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'xg3-')), errs = [];
  const G = godot('pvphost', dir);
  const code = await until(() => exists(dir, 'code.txt') && fs.readFileSync(path.join(dir, 'code.txt'), 'utf8').trim(), 30000);
  const P = await page(b, port, errs, 'GUEST');
  await P.click('[data-go=multi]'); await P.fill('#mName', 'Rook'); await P.fill('#mCode', code); await P.click('#joinBtn');
  await P.waitForSelector('#pg-lobby:not([hidden])', { timeout: 20000 });
  check(await until(() => P.evaluate(() => __pal.pick.pvp === 'ffa' && __pal.pick.map === 'quarry'), 8000), 'the browser sees the room is a Free-for-all on the Quarry');
  await P.click('#lReady');
  check(await until(() => P.evaluate(() => document.getElementById('menu').hidden && __pal.game.pvp === 'ffa' && __pal.players.size === 2), 30000), 'the Free-for-all starts in the browser');
  check(await P.evaluate(() => __pal.walls.filter(w => w && w.mat === 3).length === 0 && __pal.game.map === 'quarry'), 'the Quarry arena loads (stone cover, no timber)');
  put(dir, 'sawffa.txt', '1');
  check(await until(() => exists(dir, 'dropped.txt') && P.evaluate(() => __pal.players.get('host').kills === 1 && __pal.player.deaths === 1), 20000), 'the browser counts the drop: host 1 kill, itself 1 death');
  put(dir, 'sawdrop.txt', '1');
  await sleep(1000);
  check(errs.length === 0, 'no browser errors' + (errs.length ? ': ' + errs.slice(0, 3).join(' | ') : ''));
  put(dir, 'done.txt', '1');
  await until(() => G.exit !== null, 20000);
  check(G.exit === 0 && G.lines.includes('DRIVER PASS'), 'the Godot side passed');
  check(G.errs === 0, 'no Godot script errors (' + G.errs + ')');
  await P.close();
}

async function browserHostsBase(b, port) {
  console.log('4: the browser hosts a Base Battle, Godot joins');
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'xg4-')), errs = [];
  const G = godot('pvpguest', dir);
  const H = await page(b, port, errs, 'HOST');
  await H.click('[data-go=multi]'); await H.fill('#mName', 'Big U'); await H.click('#hostBtn');
  await H.waitForSelector('#pg-lobby:not([hidden])', { timeout: 15000 });
  await H.evaluate(() => { __pal.pick.pvp = 'base'; __pal.pick.map = 'yard'; __pal.broadcastLobby() });
  put(dir, 'code.txt', (await H.textContent('#lCode')).trim());
  check(await until(() => H.evaluate(() => __pal.NET.roster.length === 2 && __pal.NET.roster[1].ready), 30000), 'Godot joins and readies');
  await H.click('#lStart');
  check(await until(() => H.evaluate(() => document.getElementById('menu').hidden && __pal.game.pvp === 'base'), 10000), 'the browser starts the Base Battle');
  await sleep(1500);
  await H.evaluate(() => { __pal.game.timer = 0.05 });
  await sleep(1500);
  await H.evaluate(() => { __pal.hurtPlayer(__pal.players.get('g1'), 30, 'host') });
  check(await until(() => exists(dir, 'sawhit.txt'), 25000), 'Godot saw the battle start and the host\'s hit');
  await sleep(500);
  check(errs.length === 0, 'no browser errors' + (errs.length ? ': ' + errs.slice(0, 3).join(' | ') : ''));
  put(dir, 'done.txt', '1');
  await until(() => G.exit !== null, 30000);
  check(G.exit === 0 && G.lines.includes('DRIVER PASS'), 'the Godot side passed');
  check(G.errs === 0, 'no Godot script errors (' + G.errs + ')');
  await H.close();
}

(async () => {
  let peerProc = null;
  if (!(await portUp(9000))) { peerProc = spawn('node', ['peer-server.js'], { cwd: path.join(ROOT, '../dev/test'), stdio: 'ignore' }); await until(() => portUp(9000), 8000) }
  const srv = await serve(SITE), port = srv.address().port;
  const b = await chromium.launch({ executablePath: CHROMIUM, args: ['--disable-features=WebRtcHideLocalIpsWithMdns', '--autoplay-policy=no-user-gesture-required'] });
  try {
    if (!process.argv.includes('--pvp-only')) { await godotHosts(b, port); await browserHosts(b, port) }
    await godotHostsFfa(b, port);
    await browserHostsBase(b, port);
  } catch (e) { check(false, 'crashed: ' + (e && e.stack || e)) }
  await b.close(); srv.close(); if (peerProc) peerProc.kill();
  console.log(`${passes} passed, ${fails} failed`);
  console.log(fails ? 'RESULT: FAIL' : 'RESULT: PASS');
  process.exit(fails ? 1 : 0);
})();
