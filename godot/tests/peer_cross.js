// Cross-play: PeerNet (scripts/peer_net.gd) against the real PeerJS 1.5.5 in Chromium, the same calls 21-online.js makes.
//   node godot/tests/peer_cross.js [--site DIR] [--godot BIN]        (exit 0 = pass)
// Starts the local PeerJS server (dev/test/peer-server.js) unless one already answers on 127.0.0.1:9000.
// a: the browser hosts 'palisade-yard-27-<code>', Godot joins, Godot closes the connection.
// b: Godot hosts, the browser joins with 'r' and 'u' and opens 'st' like openStateCh, the browser kicks (r.close()).
// c: as b, the browser leaves with peer.destroy() (what netReset does).
// d: Godot hosts, Chrome keeps hiding its own address behind an mDNS name (the default on real players' browsers).
const path = require('path'), fs = require('fs'), http = require('http'), net = require('net');
const { spawn } = require('child_process');
const { chromium } = require('../../dev/test/node_modules/playwright');

const arg = (k, d) => { const i = process.argv.indexOf(k); return i > 0 ? process.argv[i + 1] : d };
const ROOT = path.resolve(__dirname, '..');
const SCRATCH = '/tmp/claude-0/-home-user-palisade/1491750c-0eda-570d-b463-0b660096a613/scratchpad';
const SITE = arg('--site', process.env.PALISADE_SITE || path.join(SCRATCH, 'site'));
const GODOT = arg('--godot', process.env.GODOT || path.join(SCRATCH, 'godot/Godot_v4.7.2-stable_linux.x86_64'));
const PREFIX = 'palisade-yard-27-';
// Playwright may want a newer browser build than the one installed: fall back to whatever Chromium is there
const CHROMIUM = process.env.CHROMIUM || (() => {
  const base = process.env.PLAYWRIGHT_BROWSERS_PATH || '/opt/pw-browsers';
  try {
    for (const d of fs.readdirSync(base).filter(d => /^chromium-\d+$/.test(d)).sort().reverse()) {
      const exe = path.join(base, d, 'chrome-linux', 'chrome');
      if (fs.existsSync(exe)) return exe;
    }
  } catch (e) { }
  return undefined;
})();

const PAGE = `<!doctype html><meta charset="utf-8"><script src="/peerjs.min.js"></script><script>
const OPTS={host:'127.0.0.1',port:9000,path:'/',secure:false,debug:0,config:{iceServers:[]}};
const UNI='héllo ✓ 日本 "q"';
window.L=[];const log=(...a)=>L.push(a);
// verbatim from 21-online.js
function openStateCh(conn){
  try{const pc=conn.peerConnection;if(!pc||!pc.createDataChannel)return null;return pc.createDataChannel('st',{negotiated:true,id:1000,ordered:false,maxRetransmits:0})}catch(e){return null}
}
const S={r:null,u:null,st:null,role:'',pinged:false,acked:false,gotst:false};
function onMsg(ch,d){
  const show=Object.assign({},d);if(show.pad)show.pad='<'+show.pad.length+' chars>';if(show.t==='big')show.s='<'+show.s.length+' chars>';
  log('data',ch,show);
  if(ch==='st'&&d.t==='ping'&&!S.acked){S.acked=true;S.r.send({t:'gotst'})}
  if(d.t==='gotst')S.gotst=true;
}
function stOpen(conn){const st=openStateCh(conn);S.st=st;if(st)st.onmessage=ev=>{log('sttype',typeof ev.data);try{onMsg('st',JSON.parse(ev.data))}catch(e){log('stbad',String(e))}}}
function wire(){
  const tick=setInterval(()=>{
    if(!S.r||!S.r.open)return;
    if(!S.pinged&&S.u&&S.u.open&&S.st&&S.st.readyState==='open'){S.pinged=true;
      S.r.send({t:'ping',ch:'r',from:'browser',s:UNI});S.u.send({t:'ping',ch:'u',from:'browser',s:UNI});S.r.send({t:'big',s:'b'.repeat(12000)})}
    if(S.pinged&&!S.gotst){const m={t:'ping',ch:'st',from:'browser',s:UNI};if(S.role==='host')m.pad='S'.repeat(30000);S.st.send(JSON.stringify(m))}
    if(S.gotst)clearInterval(tick)},200)}
function watch(c){c.on('data',d=>onMsg(c.label,d));c.on('close',()=>log('close',c.label));c.on('error',e=>log('connerror',c.label,e.type))}
window.hostRoom=code=>{S.role='host';const peer=new Peer('${PREFIX}'+code,OPTS);window.peer=peer;
  peer.on('open',id=>log('open',id));peer.on('error',e=>log('error',e.type));
  peer.on('connection',conn=>{log('conn',conn.label,conn.serialization,conn.reliable);S[conn.label==='u'?'u':'r']=conn;
    conn.on('open',()=>{log('open_'+conn.label,conn.peer);if(conn.label!=='u')stOpen(conn)});watch(conn)});
  wire()};
window.joinRoom=code=>{S.role='guest';const peer=new Peer(undefined,OPTS);window.peer=peer;peer.on('error',e=>log('error',e.type));
  peer.on('open',id=>{log('open',id);const tgt='${PREFIX}'+code;
    const r=peer.connect(tgt,{label:'r',reliable:true,serialization:'json'}),u=peer.connect(tgt,{label:'u',reliable:false,serialization:'json'});
    S.r=r;S.u=u;r.on('open',()=>{log('open_r',r.peer);stOpen(r)});u.on('open',()=>log('open_u',u.peer));for(const c of[r,u])watch(c)});
  wire()};
</script>`;

const sleep = ms => new Promise(r => setTimeout(r, ms));
const until = async (f, ms) => { const end = Date.now() + ms; while (Date.now() < end) { const v = await f(); if (v) return v; await sleep(100) } return await f() };
const portUp = port => new Promise(res => { const s = net.connect(port, '127.0.0.1'); s.on('connect', () => { s.destroy(); res(true) }); s.on('error', () => res(false)) });
const code = () => { const A = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789'; let s = ''; for (let i = 0; i < 4; i++)s += A[Math.floor(Math.random() * A.length)]; return s };

let fails = 0, passes = 0;
const check = (ok, what) => { console.log((ok ? 'PASS ' : 'FAIL ') + what); ok ? passes++ : fails++ };

function godot(args) {
  const p = spawn(GODOT, ['--headless', '--path', ROOT, '--script', 'res://tests/peer_cross_driver.gd', '--', ...args], { stdio: ['ignore', 'pipe', 'pipe'] });
  const g = { ev: [], out: '', exit: null, proc: p };
  let buf = '';
  p.stdout.on('data', d => { g.out += d; buf += d; let i; while ((i = buf.indexOf('\n')) >= 0) { const line = buf.slice(0, i); buf = buf.slice(i + 1); if (line.startsWith('EV ')) { const [, k, ...rest] = line.split(' '); g.ev.push([k, rest.join(' ')]) } } });
  p.stderr.on('data', d => { g.out += d });
  p.on('exit', c => { g.exit = c });
  g.has = (k, f) => g.ev.find(e => e[0] === k && (!f || f(e[1])));
  g.data = (ch, t) => g.ev.map(e => e[0] === 'data' ? JSON.parse(e[1]) : null).find(d => d && d.ch === ch && d.msg.t === t);
  return g;
}

async function scenario(b, name, godotHosts, finish) {
  console.log(`-- ${name}`);
  const ctx = await b.newContext(), page = await ctx.newPage();
  page.on('pageerror', e => console.log('  page error: ' + e.message));
  await page.goto(`http://127.0.0.1:${PORT}/cross.html`);
  const c = code(), L = () => page.evaluate(() => window.L);
  const has = async (k, f) => (await L()).find(e => e[0] === k && (!f || f(e)));
  const data = async (ch, t) => (await L()).find(e => e[0] === 'data' && e[1] === ch && e[2].t === t);
  let g;
  if (godotHosts) {
    g = godot(['host', c, finish]);
    check(!!await until(() => g.has('opened'), 8000), `Godot registers ${PREFIX}${c}`);
    await page.evaluate(c => joinRoom(c), c);
  } else {
    await page.evaluate(c => hostRoom(c), c);
    check(!!await until(() => has('open'), 5000), `browser registers ${PREFIX}${c}`);
    g = godot(['join', c, finish]);
  }
  const host = godotHosts ? 'Godot' : 'browser', guest = godotHosts ? 'browser' : 'Godot';
  check(!!await until(() => g.has('connected'), 15000), `Godot sees 'r' open (peer ${g.has('connected') ? g.has('connected')[1] : '?'})`);
  check(!!await until(() => has('open_r'), 5000) && !!await has('open_u'), `browser sees 'r' and 'u' open`);
  if (!godotHosts) {
    const conns = (await L()).filter(e => e[0] === 'conn');
    check(conns.length === 2 && conns.some(e => e[1] === 'r' && e[2] === 'json' && e[3] === true) && conns.some(e => e[1] === 'u' && e[2] === 'json' && e[3] === false),
      `browser host gets Godot's connections as PeerJS sees them: ${JSON.stringify(conns.map(e => e.slice(1)))}`);
  }
  check(!!await until(() => g.has('done'), 10000), 'Godot got r, u, st and the 12 KB message, and its st ping was acknowledged');
  for (const ch of ['r', 'u', 'st']) {
    const d = g.data(ch, 'ping');
    check(d && d.msg.from === 'browser' && d.msg.ch === ch && d.msg.s === 'héllo ✓ 日本 "q"', `browser -> Godot on ${ch}: ${d ? JSON.stringify(d.msg) : 'nothing'}`);
  }
  const gb = g.data('r', 'big');
  check(gb && gb.msg.s === '<12000 chars>', 'browser -> Godot 12 KB on r');
  if (!godotHosts) { const d = g.data('st', 'ping'); check(d && d.msg.pad === '<30000 chars>', 'browser host -> Godot 30 KB state frame on st') }
  check(g.has('refused_big', v => v === 'true'), 'Godot refuses a 17 KB message on r');
  check(!!await until(async () => (await data('r', 'ping')) && (await data('u', 'ping')) && (await data('st', 'ping')) && (await data('r', 'big')) && (await data('r', 'gotst')), 5000),
    'browser got r, u, st, the 12 KB message, and the st acknowledgement');
  for (const ch of ['r', 'u', 'st']) {
    const d = await data(ch, 'ping');
    check(d && d[2].from === 'godot' && d[2].ch === ch && d[2].s === 'héllo ✓ 日本 "q"', `Godot -> browser on ${ch}: ${d ? JSON.stringify(d[2]) : 'nothing'}`);
  }
  const big = await data('r', 'big');
  check(big && big[2].s === '<12000 chars>', 'Godot -> browser 12 KB on r');
  if (godotHosts) { const d = await data('st', 'ping'); check(d && d[2].pad === '<30000 chars>', 'Godot host -> browser 30 KB state frame on st') }
  const types = [...new Set((await L()).filter(e => e[0] === 'sttype').map(e => e[1]))];
  check(types.length === 1 && types[0] === 'string', `browser's st ev.data is text (${types})`);
  if (finish === 'close') {
    check(!!await until(() => has('close', e => e[1] === 'r'), 5000), "Godot's close_peer closes the browser's 'r'");
  } else {
    if (finish === 'kick') await page.evaluate(() => { S.r.close(); S.u.close() });
    else await page.evaluate(() => peer.destroy());
    check(!!await until(() => g.has('closed'), 8000), `Godot sees the browser's ${finish === 'kick' ? 'r.close()' : 'peer.destroy()'} as peer_closed`);
  }
  const errs = (await L()).filter(e => e[0] === 'error' || e[0] === 'connerror' || e[0] === 'stbad');
  check(errs.length === 0, `no browser errors ${errs.length ? JSON.stringify(errs) : ''}`);
  const gerr = g.ev.filter(e => e[0] === 'error' || e[0] === 'timeout');
  check(gerr.length === 0, `no Godot errors ${gerr.length ? JSON.stringify(gerr) : ''}`);
  await until(() => g.exit !== null, 5000);
  if (g.exit === null) g.proc.kill();
  check(g.exit === 0, `Godot driver exits cleanly (${g.exit})`);
  if (fails) console.log('  Godot output:\n' + g.out.split('\n').filter(l => !/juice: UDP socket creation failed|at: LogCallback|GDScript backtrace|^\s+\[\d\]/.test(l)).map(l => '    ' + l).join('\n'));
  await ctx.close();
}

let PORT = 0;
(async () => {
  if (!fs.existsSync(path.join(SITE, 'peerjs.min.js'))) { console.log('no peerjs.min.js in ' + SITE); process.exit(2) }
  let server = null;
  if (!await portUp(9000)) {
    server = spawn(process.execPath, ['peer-server.js'], { cwd: path.resolve(ROOT, '../dev/test'), stdio: 'ignore' });
    if (!await until(() => portUp(9000), 5000)) { console.log('the peer server did not start'); process.exit(2) }
  }
  const web = http.createServer((q, s) => {
    if (q.url.startsWith('/peerjs.min.js')) { s.writeHead(200, { 'content-type': 'text/javascript' }); s.end(fs.readFileSync(path.join(SITE, 'peerjs.min.js'))); return }
    s.writeHead(200, { 'content-type': 'text/html; charset=utf-8' }); s.end(PAGE);
  }).listen(0, '127.0.0.1');
  await new Promise(r => web.on('listening', r));
  PORT = web.address().port;
  const plain = await chromium.launch({ executablePath: CHROMIUM, args: ['--disable-features=WebRtcHideLocalIpsWithMdns'] });
  const mdns = await chromium.launch({ executablePath: CHROMIUM });
  try {
    await scenario(plain, 'a: browser hosts, Godot joins, Godot closes', false, 'close');
    await scenario(plain, 'b: Godot hosts, browser joins, browser kicks (r.close())', true, 'kick');
    await scenario(plain, 'c: Godot hosts, browser joins, browser leaves (peer.destroy())', true, 'destroy');
    await scenario(mdns, 'd: Godot hosts, browser joins with mDNS host candidates', true, 'destroy');
    await scenario(mdns, 'e: browser hosts with mDNS host candidates, Godot joins', false, 'close');
  } catch (e) { console.log('FAIL exception ' + (e.stack || e)); fails++ }
  await plain.close(); await mdns.close(); web.close(); if (server) server.kill();
  console.log(`${passes} passed, ${fails} failed`);
  console.log('RESULT: ' + (fails ? 'FAIL' : 'PASS'));
  process.exit(fails ? 1 : 0);
})();
