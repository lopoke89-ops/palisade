// Cross-play over the casino relay: CasinoRelay (scripts/casino_relay.gd) with the browser's own client
// (21a-casino-relay.js in debug.html) in Chromium, both through the real relay (dev/render/relay.js) on localhost.
//   node godot/tests/relay_cross.js [--site DIR] [--godot BIN]        (exit 0 = pass)
// Auth is the fixture's (tests/relay_fixture.mjs); the browser's Supabase calls are answered locally or blocked.
// The page's CSP only admits the public relay, so the test bypasses it to point PALISADE_RELAY at localhost.
// 1: the browser opens the casino, Godot joins: game packets both ways, Godot's socket drops and resumes (the browser
//    host sends relayResume + a full state), the browser host leaves.
// 2: Godot hosts, browsers join: chat both ways, the browser's socket drops and resumes (Godot sends relayResume),
//    Godot's socket drops (the browser shows the host away, then back), lock, remove + ban, the host leaves.
// 3: the browser opens the casino, the real game (main.tscn through PalNet, tests/relay_game_driver.gd) joins and walks.
const path = require('path'), fs = require('fs'), http = require('http'), os = require('os');
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
const sleep = ms => new Promise(r => setTimeout(r, ms));
const until = async (f, ms) => { const end = Date.now() + ms; while (Date.now() < end) { const v = await f(); if (v) return v; await sleep(100) } return await f() };
let fails = 0, passes = 0;
const check = (ok, what) => { console.log((ok ? 'PASS ' : 'FAIL ') + what); ok ? passes++ : fails++ };

const users = Array.from({ length: 6 }, (_, i) => ({ id: `b0000000-0000-4000-8000-${String(i + 1).padStart(12, '0')}`, name: 'Relay' + i }));
const tok = u => 'x.' + Buffer.from(JSON.stringify({ sub: u.id, exp: Math.floor(Date.now() / 1000) + 3600, name: u.name })).toString('base64url') + '.y';

function serve(dir) {
  const types = { '.html': 'text/html', '.js': 'text/javascript', '.json': 'application/json', '.png': 'image/png', '.woff2': 'font/woff2', '.ogg': 'audio/ogg', '.m4a': 'audio/mp4', '.webmanifest': 'application/manifest+json' };
  const srv = http.createServer((q, r) => {
    const f = path.join(dir, decodeURIComponent(q.url.split('?')[0]).replace(/^\/+/, '') || 'index.html');
    fs.readFile(f, (e, b) => { if (e) { r.writeHead(404); r.end(); return } r.writeHead(200, { 'content-type': types[path.extname(f)] || 'application/octet-stream' }); r.end(b) });
  });
  return new Promise(res => srv.listen(0, '127.0.0.1', () => res(srv)));
}

function godot(role, url, token, code) {
  const cmd = path.join(fs.mkdtempSync(path.join(os.tmpdir(), 'rly-')), 'cmd');
  const p = spawn(GODOT, ['--headless', '--path', ROOT, '--script', 'res://tests/relay_cross_driver.gd', '--', role, url, token, cmd, ...(code ? [code] : [])], { stdio: ['ignore', 'pipe', 'pipe'] });
  const g = { ev: [], out: '', exit: null, proc: p };
  let buf = '';
  p.stdout.on('data', d => { g.out += d; buf += d; let i; while ((i = buf.indexOf('\n')) >= 0) { const l = buf.slice(0, i); buf = buf.slice(i + 1); if (l.startsWith('EV ')) g.ev.push(JSON.parse(l.slice(3))) } });
  p.stderr.on('data', d => { g.out += d });
  p.on('exit', c => { g.exit = c });
  g.has = (k, f) => g.ev.find(e => e[0] === k && (!f || f(e)));
  g.count = (k, f) => g.ev.filter(e => e[0] === k && (!f || f(e))).length;
  g.data = (t, f) => g.ev.find(e => e[0] === 'data' && e[3].t === t && (!f || f(e)));
  g.cmd = line => fs.appendFileSync(cmd, line + '\n');
  return g;
}

async function page(b, port, relayUrl, u, errs, tag) {
  const ctx = await b.newContext({ bypassCSP: true, viewport: { width: 1280, height: 720 } });
  await ctx.route(/supabase\.co/, route => {   // the local stand-in for the account and table calls the casino makes
    const p = new URL(route.request().url()).pathname;
    const body = p === '/rest/v1/rpc/get_my_locker' ? { owned: ['skin:std'], eq: {}, cases: 0, shards: 5000, bag: {}, st: {}, rev: 1, username: u.name } : p === '/functions/v1/tables' ? { tables: [], balance: 5000 } : null;
    return route.fulfill({ status: 200, contentType: 'application/json', body: JSON.stringify(body) });
  });
  await ctx.route(/palisade-turn|workers\.dev|peerjs\.com|onrender\.com/, r => r.abort());   // nothing live
  const p = await ctx.newPage();
  p.on('pageerror', e => errs.push(tag + ' ' + e.message));
  await p.addInitScript(s => localStorage.setItem('palisade.auth.v1', s), JSON.stringify({ access_token: tok(u), refresh_token: 'fixture', expires_at: 4e9, user: { id: u.id, is_anonymous: false, email: u.name + '@example.test', user_metadata: { pw: true } } }));
  await p.goto(`http://127.0.0.1:${port}/debug.html?debug=1&cloud=1`);
  await p.waitForFunction(() => window.__pal && __pal.ready, null, { timeout: 20000 });
  await p.evaluate(url => { globalThis.PALISADE_RELAY = { enabled: true, url } }, relayUrl);
  p.ctx = ctx;
  return p;
}
const status = p => p.evaluate(() => document.getElementById('mStatus').textContent);
const quit = async g => { g.cmd('quit'); await until(() => g.exit !== null, 5000); if (g.exit === null) g.proc.kill() };
const dump = g => { if (fails) console.log('  Godot output:\n' + g.out.split('\n').filter(l => l && !/^Godot Engine/.test(l)).slice(-40).map(l => '    ' + l).join('\n')) };

async function browserHosts(b, port, fx, url) {
  console.log('1: the browser opens the casino, Godot joins');
  const errs = [];
  const H = await page(b, port, url, users[0], errs, 'host');
  await H.click('[data-nav=tables]'); await H.click('#casEnterBtn');
  check(!!await until(() => H.evaluate(() => __pal.RLY.connected && __pal.NET.inGame), 15000), 'the browser opens a casino through the relay');
  const code = await H.evaluate(() => __pal.NET.code), room = await H.evaluate(() => __pal.casRoom());
  const g = godot('guest', url, tok(users[1]), code);
  check(!!await until(() => g.has('connected'), 10000), `Godot joins ${code}: its peer is ${g.has('connected') && g.has('connected')[1]}`);
  check(!!await until(() => g.data('welcome') && g.data('start') && g.data('s', e => e[2] === 'st'), 10000), "Godot gets the browser host's welcome, start and state ('s' on st)");
  const st = g.data('start');
  check(st && st[3].mode === 'casino' && st[3].room === room, `the start names this casino room (${st && st[3].room})`);
  check(!!await until(() => H.evaluate(() => __pal.players.size === 2), 5000), 'the browser host has the Godot player in its game');
  const pid = g.data('welcome')[3].id;
  const named = await H.evaluate(pid => { const p = __pal.players.get(pid); return p && p.name }, pid);
  check(named === users[1].name, `the browser knows the Godot player by the relay-verified account name (${named})`);
  g.cmd('chat host hi from godot');
  check(!!await until(() => g.data('c', e => e[3].m === 'hi from godot'), 5000), "Godot's chat goes through the browser host and comes back to it");
  const gid = g.has('opened')[2];
  fx.drop(gid);
  check(!!await until(() => g.count('opened') >= 2, 8000), "Godot's socket is dropped by the relay and it resumes");
  check(g.ev.filter(e => e[0] === 'opened').every(e => e[2] === gid), 'with the same relay peer id');
  const at = g.ev.map((e, i) => e[0] === 'opened' ? i : -1).filter(i => i >= 0)[1];
  check(!!await until(() => g.ev.slice(at).some(e => e[0] === 'data' && e[3].t === 'x'), 5000), "the browser host resends its player list after the resume (its relayResume matched Godot's player id)");
  check(!g.has('error') && await H.evaluate(() => __pal.players.size === 2), 'nobody left');
  await H.evaluate(() => __pal.toMenu());
  check(!!await until(() => g.has('error'), 5000), 'the browser host leaves');
  const e = g.has('error');
  check(e && e[1] === 'host-closed' && e[2] === 'The host closed this casino.', `Godot gets the browser's words: ${JSON.stringify(e)}`);
  await until(() => g.exit !== null, 5000); if (g.exit === null) g.proc.kill();
  check(errs.length === 0, `no page errors ${errs.length ? JSON.stringify(errs) : ''}`);
  dump(g);
  await H.ctx.close();
}

async function gameJoins(b, port, fx, url) {
  console.log('3: the browser opens the casino, the real game (main scene, PalNet) joins');
  const errs = [], dir = fs.mkdtempSync(path.join(os.tmpdir(), 'rlyg-'));
  const H = await page(b, port, url, users[5], errs, 'host');
  await H.click('[data-nav=tables]'); await H.click('#casEnterBtn');
  check(!!await until(() => H.evaluate(() => __pal.RLY.connected && __pal.NET.inGame), 15000), 'the browser opens a casino through the relay');
  const code = await H.evaluate(() => __pal.NET.code);
  const p = spawn(GODOT, ['--headless', '--path', ROOT, '--script', 'res://tests/relay_game_driver.gd', '--', url, tok(users[1]), code, dir], { stdio: ['ignore', 'pipe', 'pipe'] });
  let out = '', exit = null;
  p.stdout.on('data', d => { out += d }); p.stderr.on('data', d => { out += d }); p.on('exit', c => { exit = c });
  const id = await until(() => fs.existsSync(dir + '/id.txt') && fs.readFileSync(dir + '/id.txt', 'utf8'), 30000);
  check(!!id && await H.evaluate(id => __pal.players.has(id), id), `the browser has the game's player (${id})`);
  const x0 = id && await H.evaluate(id => __pal.players.get(id).x, id);
  check(!!await until(() => fs.existsSync(dir + '/walked.txt'), 10000) && !!await until(() => H.evaluate(([id, x0]) => __pal.players.get(id).x > x0 + 0.5, [id, x0]), 5000), 'the game walks on the casino floor; the browser host sees it');
  await H.evaluate(() => __pal.NET.sendAll({ t: 'c', id: 'host', n: 'Relay5', m: 'hi from the browser', tm: '' }));
  await sleep(1500);
  await H.evaluate(() => __pal.toMenu());
  fs.writeFileSync(dir + '/done.txt', '1');
  await until(() => exit !== null, 15000); if (exit === null) p.kill();
  for (const l of out.split('\n').filter(l => /^(OK|FAIL) /.test(l))) check(l.startsWith('OK '), 'game: ' + l.slice(l.indexOf(' ') + 1));
  check(exit === 0, `the game driver passes (exit ${exit})`);
  if (exit !== 0) console.log(out.split('\n').slice(-30).join('\n'));
  check(errs.length === 0, `no page errors ${errs.length ? JSON.stringify(errs) : ''}`);
  await H.ctx.close();
}

async function godotHosts(b, port, fx, url) {
  console.log('2: Godot hosts, browsers join');
  const errs = [];
  const g = godot('host', url, tok(users[2]));
  check(!!await until(() => g.has('opened'), 10000), 'Godot opens a casino');
  const code = g.has('opened')[1], hostId = g.has('opened')[2];
  check(/^R[A-Z2-9]{5}$/.test(code), 'with a relay code: ' + code);
  const G = await page(b, port, url, users[3], errs, 'guest');
  await G.evaluate(code => __pal.rlyEnter('guest', code), code);
  check(!!await until(() => G.evaluate(() => __pal.RLY.connected && __pal.NET.mode === 'guest'), 15000), "the browser joins and takes Godot's welcome (NET.mode guest)");
  const bpeer = await G.evaluate(() => __pal.RLY.peer);
  check(!!g.has('connected', e => e[1] === bpeer), "Godot's peer is the browser's relay id");
  const hello = g.data('hello');
  check(hello && hello[3].uid === users[3].id && hello[3].name === users[3].name && hello[3].v === 'yard-30', `the browser's hello arrives with its verified account: ${hello && JSON.stringify(hello[3])}`);
  check(await G.evaluate(() => __pal.NET.code) === code, "the browser took Godot's lobby (its code)");
  await G.evaluate(() => __pal.NET.toHost({ t: 'c', m: 'hi from the browser' }));
  check(!!await until(() => g.data('c', e => e[3].m === 'hi from the browser' && e[1] === bpeer), 5000), 'browser -> Godot chat');
  fx.drop(bpeer);
  check(!!await until(() => g.has('resumed', e => e[1] === bpeer), 8000), "the browser's socket drops and comes back: Godot gets peer_resumed");
  await sleep(500);
  check(await G.evaluate(() => __pal.RLY.active && __pal.RLY.connected && __pal.NET.mode === 'guest') && await G.evaluate(() => __pal.RLY.peer) === bpeer,
    "the browser accepted Godot's relayResume and kept its seat");
  g.cmd('drop');
  check(!!await until(async () => /Reconnecting to the casino host/.test(await status(G)), 5000), "Godot's socket goes: the browser shows the host away");
  check(!!await until(async () => g.count('opened') >= 2 && (await status(G)) === '', 8000), 'Godot resumes and the browser clears it');
  check(g.ev.filter(e => e[0] === 'opened').every(e => e[1] === code && e[2] === hostId) && await G.evaluate(() => __pal.RLY.connected), 'same room, same host seat');
  g.cmd(`chat ${bpeer} after the host came back`);
  check(!!await until(() => g.has('sent', e => e[1] === true), 3000), 'Godot -> browser after its own resume');
  g.cmd('lock');
  await sleep(300);
  const L = await page(b, port, url, users[4], errs, 'locked');
  await L.evaluate(code => __pal.rlyEnter('guest', code), code);
  check(!!await until(() => L.evaluate(() => !__pal.RLY.active), 8000) && await status(L) === 'This casino is locked.', `a browser can't join Godot's locked room: "${await status(L)}"`);
  g.cmd('unlock');
  g.cmd(`remove ${bpeer} 1`);
  check(!!await until(() => G.evaluate(() => !__pal.RLY.active), 8000), 'Godot removes the browser');
  check(await status(G) === 'This connection was replaced or removed by the host.', `with the browser's words: "${await status(G)}"`);
  check(!!g.has('closed', e => e[1] === bpeer), "Godot's peer_closed for it");
  await G.evaluate(code => __pal.rlyEnter('guest', code), code);
  check(!!await until(() => G.evaluate(() => !__pal.RLY.active), 8000) && await status(G) === 'The host removed you from this casino.', `and the ban holds: "${await status(G)}"`);
  await L.evaluate(code => __pal.rlyEnter('guest', code), code);
  check(!!await until(() => L.evaluate(() => __pal.RLY.connected && __pal.NET.mode === 'guest'), 10000), 'unlocked, another browser gets in');
  g.cmd('leave');
  check(!!await until(() => L.evaluate(() => !__pal.RLY.active), 5000) && await status(L) === 'The host closed this casino.', `Godot leaves: "${await status(L)}"`);
  check(fx.state().rooms.length === 0 && fx.state().people === 0, 'the relay is empty');
  await quit(g);
  check(errs.length === 0, `no page errors ${errs.length ? JSON.stringify(errs) : ''}`);
  dump(g);
  await G.ctx.close(); await L.ctx.close();
}

(async () => {
  if (!fs.existsSync(path.join(SITE, 'debug.html'))) { console.log('no debug.html in ' + SITE); process.exit(2) }
  const web = await serve(SITE), port = web.address().port;
  const { startFixture } = await import('./relay_fixture.mjs');
  // the page's origin, and "no Origin" for Godot (nativeClients, as the live relay runs)
  const fx = await startFixture({ origins: [`http://127.0.0.1:${port}`], native: true });
  const url = `http://127.0.0.1:${fx.port}`;
  const b = await chromium.launch({ executablePath: CHROMIUM, args: ['--disable-background-timer-throttling', '--disable-renderer-backgrounding', '--disable-backgrounding-occluded-windows'] });
  try {
    await browserHosts(b, port, fx, url);
    await godotHosts(b, port, fx, url);
    await gameJoins(b, port, fx, url);
    check(fx.upgrades.some(u => u.origin === `http://127.0.0.1:${port}`) && fx.upgrades.some(u => u.origin === null), 'the browser sent its Origin; Godot sent none');
  } catch (e) { console.log('FAIL exception ' + (e.stack || e)); fails++ }
  await b.close(); web.close(); await fx.stop();
  console.log(`${passes} passed, ${fails} failed`);
  console.log('RESULT: ' + (fails ? 'FAIL' : 'PASS'));
  process.exit(fails ? 1 : 0);
})();
