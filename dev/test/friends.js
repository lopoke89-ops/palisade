// v0.9.1 friends: a mock account server with two players. Requests (send, accept, decline, cancel), two-way
// friendships, the mailbox with a red dot and count on the badge, "mark as seen", removing a friend, rate-limit
// messages, and guests being asked to save their account first. node friends.js
const { chromium } = require('playwright'), assert = require('node:assert/strict');
const A = 'aaaaaaaa-aaaa-4aaa-aaaa-aaaaaaaaaaaa', B = 'bbbbbbbb-bbbb-4bbb-bbbb-bbbbbbbbbbbb';
const users = { [A]: { id: A, email: 'a@example.invalid', is_anonymous: false, user_metadata: { pw: true } }, [B]: { id: B, email: 'b@example.invalid', is_anonymous: false, user_metadata: { pw: true } } };
const profiles = [{ id: A, username: 'Captain', cos: 'gold|tophat|galaxy|skull' }, { id: B, username: 'Rook', cos: 'neonclown|glitch|plasma|none' }];
const L = { owned: ['skin:std', 'hat:class', 'hat:cap', 'trail:std', 'fx:none'], eq: { skin: 'std', hat: 'class', trail: 'std', fx: 'none' }, cases: 0, bag: {}, shards: 0, prog: 0, st: { raids: 0, wins: 0, drops: 0, endless: 0, hardWins: 0 }, imported: true };
const token = (id, anon) => Buffer.from('{}').toString('base64url') + '.' + Buffer.from(JSON.stringify({ sub: id, is_anonymous: !!anon })).toString('base64url') + '.test';
const session = (id, anon) => ({ access_token: token(id, anon), refresh_token: 'fixture', expires_at: Math.floor(Date.now() / 1000) + 3600, user: { ...users[id], is_anonymous: !!anon } });
// ---- the mock server: the same rules as the real functions (v0.9.1 migration)
let reqs = [], friends = [], notes = [], nid = 1, calls = [], rateLimited = false;
const prof = id => { const p = profiles.find(p => p.id === id); return { id: p.id, username: p.username, cos: p.cos } };
const areFriends = (a, b) => friends.some(f => (f[0] === a && f[1] === b) || (f[0] === b && f[1] === a));
const rpc = {
  social_state: me => ({ friends: friends.filter(f => f.includes(me)).map(f => ({ ...prof(f[0] === me ? f[1] : f[0]), since: new Date().toISOString() })),
    incoming: reqs.filter(r => r.to === me && r.status === 'pending').map(r => ({ id: r.id, user: prof(r.from), at: r.at })),
    outgoing: reqs.filter(r => r.from === me && r.status === 'pending').map(r => ({ id: r.id, user: prof(r.to), at: r.at })),
    notes: notes.filter(n => n.user === me).map(n => ({ id: n.id, kind: n.kind, data: {}, created_at: n.at, seen_at: n.seen, user: { id: n.from, username: prof(n.from).username } })).reverse(),
    unseen: notes.filter(n => n.user === me && !n.seen).length, is_anonymous: false }),
  friend_send: (me, a) => { if (rateLimited) return [400, { message: 'Too many requests. Try again in a few minutes' }];
    if (areFriends(me, a.p_to)) return { state: 'friends' };
    const back = reqs.find(r => r.from === a.p_to && r.to === me && r.status === 'pending');
    if (back) { back.status = 'accepted'; friends.push([me, a.p_to]); notes.push({ id: nid++, user: a.p_to, from: me, kind: 'friend_accepted', at: new Date().toISOString() }); return { state: 'friends' } }
    if (reqs.some(r => r.from === me && r.to === a.p_to && r.status === 'pending')) return { state: 'sent' };
    const r = { id: nid++, from: me, to: a.p_to, status: 'pending', at: new Date().toISOString() }; reqs.push(r);
    notes.push({ id: nid++, user: a.p_to, from: me, kind: 'friend_request', at: r.at }); return { state: 'sent', id: r.id } },
  friend_answer: (me, a) => { const r = reqs.find(r => r.id === a.p_id && r.to === me && r.status === 'pending'); if (!r) return [400, { message: 'That request is no longer open' }];
    if (a.p_accept) { r.status = 'accepted'; friends.push([r.from, me]); notes.push({ id: nid++, user: r.from, from: me, kind: 'friend_accepted', at: new Date().toISOString() }); return { state: 'friends' } }
    r.status = 'declined'; return { state: 'declined' } },
  friend_cancel: (me, a) => { const r = reqs.find(r => r.id === a.p_id && r.from === me && r.status === 'pending'); if (!r) return [400, { message: 'That request is no longer open' }]; r.status = 'cancelled';
    notes = notes.filter(n => !(n.kind === 'friend_request' && n.from === me && n.user === r.to && !n.seen)); return { state: 'cancelled' } },
  friend_remove: (me, a) => { friends = friends.filter(f => !(f.includes(me) && f.includes(a.p_other))); return { state: 'removed' } },
  notes_seen: me => { let n = 0; for (const x of notes) if (x.user === me && !x.seen) { x.seen = new Date().toISOString(); n++ } return { seen: n } },
  get_my_locker: () => L
};
(async () => {
  const b = await chromium.launch({ executablePath: process.env.CHROMIUM || undefined }), errors = [], out = {};
  const page = async (id, anon) => {
    const ctx = await b.newContext({ viewport: { width: 1400, height: 900 } });
    await ctx.route('https://puvjfhwxigxjpsvdwrwf.supabase.co/**', async route => {
      const req = route.request(), url = new URL(req.url()), path = url.pathname; let me; try { me = JSON.parse(Buffer.from(req.headers().authorization.split(' ')[1].split('.')[1], 'base64url')).sub } catch { }
      let data = {}, status = 200;
      if (path === '/auth/v1/user') data = { ...users[me], is_anonymous: !!anon };
      else if (path === '/rest/v1/profiles') { if (url.searchParams.has('username')) data = profiles.filter(p => p.username.toLowerCase() === url.searchParams.get('username').slice(3).toLowerCase()); else data = profiles.filter(p => (url.searchParams.get('id') || '').includes(p.id)) }
      else if (path === '/rest/v1/lobbies') data = [];
      else if (path.startsWith('/rest/v1/rpc/')) { const fn = path.slice(13); calls.push(fn); const f = rpc[fn]; if (!f) { status = 404; data = { message: 'unhandled' } } else { const r = f(me, req.postDataJSON() || {}); if (Array.isArray(r)) [status, data] = r; else data = r } }
      else { status = 404; data = { message: 'unhandled' } }
      await route.fulfill({ status, contentType: 'application/json', body: JSON.stringify(data) }) });
    const p = await ctx.newPage(); p.on('pageerror', e => errors.push(e.message));
    await p.addInitScript(s => localStorage.setItem('palisade.auth.v1', JSON.stringify(s)), session(id, anon));
    await p.goto('http://localhost:8080/debug.html?debug=1&cloud=1'); await p.waitForFunction(() => __pal.acct.state === 'full' || __pal.acct.state === 'guest', null, { timeout: 15000 }); return p };
  const pa = await page(A), pb = await page(B);
  const poll = p => p.evaluate(() => __pal.friendsPoll());
  const dot = p => p.evaluate(() => ({ hidden: document.getElementById('friendsDot').hidden, n: document.getElementById('friendsDot').textContent }));
  // the menu checks every 15 s while it is up
  out.polling = await pa.evaluate(() => !!__pal.FR.timer); assert.ok(out.polling, 'polling while the menu is open');
  // 1. A finds Rook and sends a request
  await pa.click('#friendsBtn'); await pa.fill('#friendName', 'Rook'); await pa.locator('#friendSearch button').click();
  await pa.waitForSelector('#friendResult .friendRow'); await pa.locator('#friendResult').getByRole('button', { name: 'ADD FRIEND' }).click();
  await pa.waitForFunction(() => __pal.FR.outgoing.length === 1); assert.match(await pa.textContent('#socialStatus'), /Request sent to Rook/);
  await pa.click('[data-ft=requests]'); assert.match(await pa.textContent('#reqOut'), /Rook/);
  // 2. B gets a red dot with a count; the Requests tab lists it
  await poll(pb); out.bDot = await dot(pb); assert.deepEqual(out.bDot, { hidden: false, n: '1' });
  assert.equal(await pb.evaluate(() => document.getElementById('fdReqN').textContent), '1');
  // 3. B opens the Requests tab: seen, dot gone; accepts
  await pb.click('#friendsBtn'); await pb.click('[data-ft=requests]'); await pb.waitForFunction(() => document.getElementById('friendsDot').hidden);
  for (let i = 0; i < 40 && !calls.includes('notes_seen'); i++) await pb.waitForTimeout(50); assert.ok(calls.includes('notes_seen'), 'viewing marks as seen');
  await pb.getByRole('button', { name: 'Accept Captain' }).click(); await pb.waitForFunction(() => __pal.FR.friends.length === 1);
  // 4. two-way: A sees Rook as a friend and has mail saying so
  await pa.click('[data-ft=friends]'); await poll(pa); out.aFriends = await pa.evaluate(() => __pal.FR.friends.map(f => f.username)); assert.deepEqual(out.aFriends, ['Rook']);
  out.aDot = await dot(pa); assert.equal(out.aDot.hidden, false, 'A has new mail');
  await pa.click('[data-ft=mail]'); assert.match(await pa.textContent('#mailList'), /Rook accepted your friend request/);
  await pa.waitForFunction(() => document.getElementById('friendsDot').hidden);
  await pa.click('[data-ft=friends]'); assert.match(await pa.textContent('#friendList'), /Rook/);
  await pa.screenshot({ path: __dirname + '/out/friends_a.png' });
  // 5. remove (asks once more first), then both lists are empty
  await pa.getByRole('button', { name: 'Remove Rook from friends' }).click(); assert.equal(friends.length, 1, 'first tap only asks');
  await pa.getByRole('button', { name: 'Remove Rook from friends' }).click(); await pa.waitForFunction(() => __pal.FR.friends.length === 0);
  await poll(pb); assert.equal(await pb.evaluate(() => __pal.FR.friends.length), 0, 'removed on both sides');
  // 6. send again and cancel it: the unread mail note goes too
  await pa.evaluate(() => { __pal.SOCIAL.result = null }); await pa.fill('#friendName', 'Rook'); await pa.locator('#friendSearch button').click(); await pa.waitForSelector('#friendResult .friendRow');
  await pa.locator('#friendResult').getByRole('button', { name: 'ADD FRIEND' }).click(); await pa.waitForFunction(() => __pal.FR.outgoing.length === 1);
  await pa.click('[data-ft=requests]'); await pa.getByRole('button', { name: 'Cancel request to Rook' }).click(); await pa.waitForFunction(() => __pal.FR.outgoing.length === 0);
  await poll(pb); out.afterCancel = await dot(pb); assert.equal(out.afterCancel.hidden, true, 'a cancelled request leaves no unread mail');
  // 7. decline
  await pa.click('[data-ft=friends]'); await pa.locator('#friendResult').getByRole('button', { name: 'ADD FRIEND' }).click(); await pa.waitForFunction(() => __pal.FR.outgoing.length === 1);
  await poll(pb); await pb.click('[data-ft=requests]'); await pb.getByRole('button', { name: 'Decline Captain' }).click(); await pb.waitForFunction(() => __pal.FR.incoming.length === 0);
  assert.equal(friends.length, 0);
  // 8. rate limits come back as a plain message
  rateLimited = true; reqs = []; await poll(pa); await pa.click('[data-ft=friends]');
  await pa.locator('#friendResult').getByRole('button', { name: 'ADD FRIEND' }).click(); await pa.waitForFunction(() => /Too many requests/.test(document.getElementById('socialStatus').textContent)); rateLimited = false;
  // 9. a guest is asked to save the account first
  const pg = await page(A, true); await pg.click('#friendsBtn'); out.guest = await pg.textContent('#friendList'); assert.match(out.guest, /Sign in with a saved account/);
  console.log(JSON.stringify(out)); console.log('errors:', errors.length ? errors : 'none'); assert.equal(errors.length, 0); await b.close();
})().catch(e => { console.log('Error:', e.message); process.exit(1) });
