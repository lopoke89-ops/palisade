// The real casino relay (dev/render/relay.js) on localhost with fake Supabase auth, for tests/relay_test.gd and
// tests/relay_cross.js. Never the live relay or live Supabase.
//   node godot/tests/relay_fixture.mjs --port 18110 --control 18111 [--origin http://127.0.0.1:8080] [--native]
//        [--strict-port 18112] [--tls-port 18113] [--grace 120000]
// Auth: a token is 'x.' + base64url({sub, exp, name?, anon?}) + '.y' (what dev/test mints). verify() checks it the
// way supabaseIdentity does: a saved (non-anonymous) uuid account, and an unexpired exp.
// Origin: relay.js admits exact allowed origins, and with nativeClients (on in production) also a handshake with no
// Origin, which is what the Godot game sends. --native turns nativeClients on here. --strict-port also runs a relay
// with nativeClients off (only the --origin list), to check how the desktop game is told it can't get in.
// --tls-port puts a TLS listener (a fresh self-signed certificate for 127.0.0.1, made with openssl) in front of the
// same relay, for the wss:// path. Control (HTTP on --control, JSON): GET /state, GET /tls ({port, cert: PEM path}),
// GET /upgrades (the Origin each handshake carried),
// POST /drop?peer=ID (terminate that peer's socket server-side), POST /pause?peer=ID and /unpause (stop and resume
// reading that socket: a stalled network), POST /restart (stop the relay, start a new one), POST /quit.
import http from 'node:http';
import https from 'node:https';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import {execFileSync} from 'node:child_process';
import {createRelay} from '../../dev/render/relay.js';

const uidPattern = /^[0-9a-f-]{36}$/i;
export const identity = {
	async verify(token) {
		if (typeof token !== 'string' || token.length > 8192) throw new Error('Sign in to a saved account.');
		let c;
		try { c = JSON.parse(Buffer.from(token.split('.')[1], 'base64url')) } catch { throw new Error('Sign in to a saved account.') }
		if (!uidPattern.test(c.sub) || c.anon) throw new Error('Sign in to a saved account.');
		if (!Number.isFinite(c.exp) || c.exp * 1000 <= Date.now()) throw new Error('Sign in again.');
		return {uid: c.sub, name: String(c.name || 'Player').slice(0, 12), expires: c.exp * 1000};
	}
};

export async function startFixture({port = 0, controlPort = null, origins = [], native = false, strictPort = null, tlsPort = null, graceMs} = {}) {
	const upgrades = [], paused = [];
	const make = async (p, nativeClients) => {
		const relay = createRelay({identity, origins, nativeClients, ...(graceMs ? {graceMs} : {})});
		relay.server.on('upgrade', req => upgrades.push({port: p, origin: req.headers.origin ?? null, ua: req.headers['user-agent'] ?? null}));
		return {relay, port: await relay.start(p)};
	};
	let main = await make(port, native);
	const strict = strictPort != null ? await make(strictPort, false) : null;
	let tls = null;
	if (tlsPort != null) {
		const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'relay-tls-')), key = path.join(dir, 'key.pem'), cert = path.join(dir, 'cert.pem');
		execFileSync('openssl', ['req', '-x509', '-newkey', 'rsa:2048', '-nodes', '-keyout', key, '-out', cert, '-days', '1', '-subj', '/CN=127.0.0.1', '-addext', 'subjectAltName=IP:127.0.0.1'], {stdio: 'ignore'});
		const server = https.createServer({key: fs.readFileSync(key), cert: fs.readFileSync(cert)}, (req, res) => { res.writeHead(404); res.end() });
		// hand the upgrade to whichever relay is current (it survives /restart)
		server.on('upgrade', (req, socket, head) => main.relay.server.emit('upgrade', req, socket, head));
		await new Promise(r => server.listen(tlsPort, '127.0.0.1', r));
		tls = {server, port: server.address().port, cert};
	}
	const fx = {
		get relay() { return main.relay }, port: main.port, strict, upgrades, tls,
		state() {
			return {rooms: [...main.relay.rooms.values()].map(r => ({code: r.code, incarnation: r.incarnation, locked: r.locked, banned: r.banned.size,
				members: [...r.members.values()].map(p => ({id: p.id, role: p.role, uid: p.uid, name: p.name, expires: p.expires, connected: !!p.ws}))})),
				people: main.relay.people.size};
		},
		pause(peer) { const ws = main.relay.people.get(peer)?.ws; if (!ws) return false; ws._socket.pause(); paused.push(ws); return true },
		unpause() { for (const ws of paused.splice(0)) ws._socket?.resume(); return true },
		drop(peer) { const p = main.relay.people.get(peer); if (!p?.ws) return false; p.ws.terminate(); return true },
		async restart() { const p = main.port; await main.relay.stop(); main = await make(p, native); return true },
		async stop() { fx.unpause(); await main.relay.stop(); if (strict) await strict.relay.stop(); tls?.server.close(); control?.close() }
	};
	let control = null;
	if (controlPort != null) {
		control = http.createServer(async (req, res) => {
			const u = new URL(req.url, 'http://x');
			let body;
			try {
				if (u.pathname === '/state') body = fx.state();
				else if (u.pathname === '/upgrades') body = upgrades;
				else if (u.pathname === '/tls') body = tls ? {port: tls.port, cert: tls.cert} : null;
				else if (u.pathname === '/pause') body = {ok: fx.pause(u.searchParams.get('peer'))};
				else if (u.pathname === '/unpause') body = {ok: fx.unpause()};
				else if (u.pathname === '/drop') body = {ok: fx.drop(u.searchParams.get('peer'))};
				else if (u.pathname === '/restart') body = {ok: await fx.restart()};
				else if (u.pathname === '/quit') { body = {ok: true}; setTimeout(() => fx.stop().then(() => process.exit(0)), 20) }
				else body = {error: 'Not found'};
			} catch (e) { body = {error: String(e)} }
			res.writeHead(200, {'Content-Type': 'application/json'}); res.end(JSON.stringify(body));
		});
		await new Promise(r => control.listen(controlPort, '127.0.0.1', r));
		fx.controlPort = control.address().port;
	}
	return fx;
}

if (process.argv[1] && import.meta.url === new URL('file://' + process.argv[1]).href) {
	const arg = (k, d) => { const i = process.argv.indexOf(k); return i > 0 ? process.argv[i + 1] : d };
	const origins = process.argv.flatMap((a, i) => a === '--origin' ? [process.argv[i + 1]] : []);
	const fx = await startFixture({port: Number(arg('--port', 0)), controlPort: Number(arg('--control', 0)), origins,
		native: process.argv.includes('--native'), strictPort: arg('--strict-port') != null ? Number(arg('--strict-port')) : null,
		tlsPort: arg('--tls-port') != null ? Number(arg('--tls-port')) : null, graceMs: arg('--grace') ? Number(arg('--grace')) : undefined});
	console.log(JSON.stringify({relay: fx.port, control: fx.controlPort, strict: fx.strict?.port ?? null, tls: fx.tls?.port ?? null}));
	// the test that started us may die without asking: don't outlive it
	const ppid = process.ppid;
	setInterval(() => { try { process.kill(ppid, 0) } catch { fx.stop().then(() => process.exit(0)) } }, 1000).unref();
	process.on('SIGTERM', () => fx.stop().then(() => process.exit(0)));
	process.on('SIGINT', () => fx.stop().then(() => process.exit(0)));
}
