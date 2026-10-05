#!/usr/bin/env node
// PALISADE test runner (replaces the one-at-a-time loop in run_all.sh; works the same on Linux, macOS and Windows).
//   node run_suite.js                    the full suite in suite.txt
//   node run_suite.js @hud @tables       tests with any of these tags      node run_suite.js solo lobby   exact tests
//   node run_suite.js --failed           only the tests that failed last run
//   node run_suite.js --changed          tests whose own file changed against main (plus uncommitted and new ones)
//   --jobs N (or JOBS=N)  parallel tests (default: half the CPU cores, at least 1)      --bail  stop after a failure
//   --build               rebuild the site first (one NOMIN build: index.html is always minified either way)
//   --stale-ok            run even if the built site is older than dev/src      --timeout S  per test (default 300)
//   --keep-servers        leave the :8080 / :9000 servers running afterwards      --list  print the selection only
// TESTS="a b" still works (the old run_all.sh way). Each test is its own process with its own browser, so tests
// can't see each other: they share only the static server and the PeerJS server (random room codes).
// Order: no-browser tests first (fast failures), then browser tests longest-first using the last run's timings,
// then the `serial` tests alone. Logs go to out/<test>.log as before; timings to out/timings.json.
const { spawn, execFileSync } = require('node:child_process'), fs = require('node:fs'), path = require('node:path'), os = require('node:os'), http = require('node:http');
const DIR = __dirname, OUT = path.join(DIR, 'out'), ROOT = path.resolve(DIR, '../..'), SRC = path.resolve(DIR, '../src');
fs.mkdirSync(OUT, { recursive: true });

// ---- options
const argv = process.argv.slice(2), flag = f => argv.includes(f), opt = (f, d) => { const i = argv.indexOf(f); return i >= 0 && argv[i + 1] ? argv[i + 1] : d };
const JOBS = Math.max(1, +opt('--jobs', process.env.JOBS || Math.floor(os.cpus().length / 2)) || 1);
const TIMEOUT = 1000 * (+opt('--timeout', 300) || 300);
const picks = argv.filter((a, i) => !a.startsWith('--') && !['--jobs', '--timeout'].includes(argv[i - 1]));

// ---- the suite
const suite = fs.readFileSync(path.join(DIR, 'suite.txt'), 'utf8').split('\n').map(l => l.replace(/#.*/, '').trim()).filter(Boolean)
  .map(l => { const [name, ...tags] = l.split(/\s+/); return { name, tags } });
const byName = new Map(suite.map(t => [t.name, t]));
const entry = n => byName.get(n) || { name: n, tags: [] };
let sel;
if (flag('--failed')) { const f = path.join(OUT, 'last_failed.txt'); sel = fs.existsSync(f) ? fs.readFileSync(f, 'utf8').split(/\s+/).filter(Boolean).map(entry) : [] }
else if (flag('--changed')) {
  const git = a => { try { return execFileSync('git', a, { cwd: ROOT, encoding: 'utf8' }) } catch { return '' } };
  const files = (git(['diff', '--name-only', 'origin/main']) + git(['ls-files', '--others', '--exclude-standard'])).split('\n');
  const names = new Set(files.filter(f => /^dev\/test\/[a-z0-9_]+\.js$/.test(f)).map(f => path.basename(f, '.js')).filter(n => fs.existsSync(path.join(DIR, n + '.js')) && n !== 'run_suite' && n !== 'peer-server'));
  sel = [...names].map(entry);
} else if (process.env.TESTS && !picks.length) sel = process.env.TESTS.split(/\s+/).filter(Boolean).map(entry);
else if (picks.length) {
  const want = new Set(); for (const p of picks) {
    if (p.startsWith('@')) { const tag = p.slice(1), hit = suite.filter(t => t.tags.includes(tag)); if (!hit.length) die(`No test has the tag ${p}`); hit.forEach(t => want.add(t.name)) }
    else want.add(p) }
  sel = [...want].map(entry);
} else sel = suite.filter(t => !t.tags.includes('extra'));
for (const t of sel) if (!/^[a-z0-9_]+$/.test(t.name) || !fs.existsSync(path.join(DIR, t.name + '.js'))) die(`Unknown test: ${t.name}`);
if (!sel.length) { console.log('Nothing to run.'); process.exit(0) }

// longest first (from the last run); tests with no timing yet count as long so they start early
const TIMES = path.join(OUT, 'timings.json'); let times = {}; try { times = JSON.parse(fs.readFileSync(TIMES, 'utf8')) } catch { }
const est = t => times[t.name] ?? 120;
const nodeT = sel.filter(t => t.tags.includes('node')), serialT = sel.filter(t => t.tags.includes('serial') && !t.tags.includes('node'));
const browserT = sel.filter(t => !nodeT.includes(t) && !serialT.includes(t)).sort((a, b) => est(b) - est(a));
if (flag('--list')) { for (const [h, l] of [['no browser', nodeT], [`parallel x${JOBS}`, browserT], ['serial', serialT]]) if (l.length) console.log(`${h}: ${l.map(t => t.name).join(' ')}`); process.exit(0) }

function die(m) { console.error(m); process.exit(2) }

// ---- the built site must be newer than the source, or every test checks old code
function newest(d) { let m = 0; for (const e of fs.readdirSync(d, { withFileTypes: true })) { const p = path.join(d, e.name); m = Math.max(m, e.isDirectory() ? newest(p) : fs.statSync(p).mtimeMs) } return m }
if (flag('--build')) {
  console.log('Building (NOMIN=1 python3 dev/build.py)...');
  execFileSync(process.platform === 'win32' ? 'python' : 'python3', [path.join(ROOT, 'dev/build.py')], { cwd: ROOT, stdio: 'inherit', env: { ...process.env, NOMIN: '1' } });
  try { execFileSync('git', ['checkout', '--', '*.png'], { cwd: ROOT }) } catch { }
} else if (!flag('--stale-ok') && sel.some(t => !t.tags.includes('node'))) {
  const built = Math.min(...['index.html', 'debug.html'].map(f => { try { return fs.statSync(path.join(ROOT, f)).mtimeMs } catch { return 0 } }));
  const src = Math.max(newest(SRC), fs.statSync(path.join(ROOT, 'dev/build.py')).mtimeMs);
  if (built < src) die('The built site (index.html / debug.html) is older than dev/src. Run with --build (or build yourself), or pass --stale-ok.');
}

// ---- browser: Playwright's own build, else an installed Chromium (as run_all.sh did)
if (!process.env.CHROMIUM) {
  let ok = false; try { ok = fs.existsSync(require('playwright').chromium.executablePath()) } catch { }
  if (!ok) { const c = [...globDirs('/opt/pw-browsers', /^chromium-\d+$/).map(d => path.join(d, 'chrome-linux/chrome')), '/usr/bin/chromium', '/usr/bin/chromium-browser', '/usr/bin/google-chrome', 'C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe'].filter(f => fs.existsSync(f)).pop();
    if (c) { process.env.CHROMIUM = c; console.log('Using installed browser: ' + c) } }
}
function globDirs(d, re) { try { return fs.readdirSync(d).filter(n => re.test(n)).sort().map(n => path.join(d, n)) } catch { return [] } }

// ---- servers: reuse running ones, start missing ones, wait until they answer (no fixed sleep), stop ours at the end
const up = port => new Promise(r => { const q = http.get({ host: '127.0.0.1', port, path: '/', timeout: 800 }, s => { s.resume(); r(true) }); q.on('error', () => r(false)); q.on('timeout', () => { q.destroy(); r(false) }) });
const started = [];
async function server(port, cmd, args, cwd, log) {
  if (await up(port)) return;
  const fd = fs.openSync(path.join(OUT, log), 'w'), p = spawn(cmd, args, { cwd, stdio: ['ignore', fd, fd], detached: true }); started.push(p);
  for (let i = 0; i < 100; i++) { if (await up(port)) return; await new Promise(r => setTimeout(r, 100)) }
  die(`The server on :${port} didn't start (see out/${log})`);
}
const live = new Set();   // running tests, stopped with the runner
function stopServers() { for (const p of live) { try { process.platform === 'win32' ? p.kill() : process.kill(-p.pid, 'SIGKILL') } catch { } } if (flag('--keep-servers')) return; for (const p of started) { try { process.platform === 'win32' ? p.kill() : process.kill(-p.pid) } catch { } } }
for (const sig of ['SIGINT', 'SIGTERM', 'SIGHUP']) process.on(sig, () => { stopServers(); process.exit(130) });   // a stopped run doesn't leave servers behind

// ---- one test: same pass rule as before (exit 0, prints "errors: none" or similar, no uncaught errors)
const PASS = /errors?:? *(none|\[\])|ERRS \[\]/i, BAD = /Error:|TypeError|timed out/i;
function run(t) {
  return new Promise(res => {
    const t0 = Date.now(), p = spawn(process.execPath, [t.name + '.js'], { cwd: DIR, env: process.env, detached: process.platform !== 'win32' });
    live.add(p); let out = ''; p.stdout.on('data', d => out += d); p.stderr.on('data', d => out += d);
    const kill = setTimeout(() => { out += `\n[run_suite] timed out after ${TIMEOUT / 1000} s`; try { process.platform === 'win32' ? p.kill() : process.kill(-p.pid, 'SIGKILL') } catch { } }, TIMEOUT);
    p.on('close', rc => { clearTimeout(kill); live.delete(p); fs.writeFileSync(path.join(OUT, t.name + '.log'), out);
      const s = (Date.now() - t0) / 1000, ok = rc === 0 && PASS.test(out) && !BAD.test(out);
      res({ name: t.name, ok, s }) });
  });
}
const results = []; let bailed = false;
function report(r) { results.push(r); times[r.name] = Math.round(r.s); console.log(`${r.ok ? 'PASS' : 'FAIL'}  ${r.name.padEnd(24)} ${r.s.toFixed(1).padStart(6)} s${r.ok ? '' : `  (see out/${r.name}.log)`}`); if (!r.ok && flag('--bail')) bailed = true }
async function pool(list, n) {
  const q = [...list]; await Promise.all(Array.from({ length: Math.min(n, q.length) }, async () => { while (q.length && !bailed) report(await run(q.shift())) }));
}

(async () => {
  const T0 = Date.now();
  if (sel.some(t => !t.tags.includes('node'))) await Promise.all([
    server(8080, process.platform === 'win32' ? 'python' : 'python3', ['-m', 'http.server', '8080'], ROOT, 'http.log'),
    server(9000, process.execPath, ['peer-server.js'], DIR, 'peer.log')]);
  console.log(`${sel.length} tests: ${nodeT.length} without a browser, ${browserT.length} in parallel (x${JOBS}), ${serialT.length} serial`);
  await pool(nodeT, Math.max(JOBS, 4));   // no browser: cheap, run several at once
  await pool(browserT, JOBS);
  await pool(serialT, 1);
  stopServers();
  const failed = results.filter(r => !r.ok).map(r => r.name), wall = (Date.now() - T0) / 1000, sum = results.reduce((a, r) => a + r.s, 0);
  fs.writeFileSync(TIMES, JSON.stringify(times, null, 1)); fs.writeFileSync(path.join(OUT, 'last_failed.txt'), failed.join('\n'));
  const slow = [...results].sort((a, b) => b.s - a.s).slice(0, 5).map(r => `${r.name} ${r.s.toFixed(0)} s`).join(', ');
  console.log(`\n${results.length - failed.length}/${results.length} passed in ${(wall / 60).toFixed(1)} min (${(sum / 60).toFixed(1)} min of test time).${bailed ? ' Stopped early (--bail).' : ''}`);
  console.log(`Slowest: ${slow}`);
  if (failed.length) console.log(`Failed: ${failed.join(' ')}\nRe-run just those: node run_suite.js --failed`);
  process.exit(failed.length || bailed ? 1 : 0);
})();
