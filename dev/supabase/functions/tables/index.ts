// v0.9.8 THE TABLES edge function: checks who is calling, then hands the request to handler.js (the same code the tests run).
// Uses the service role for the database; players can't touch the casino tables or functions directly.
// v0.10.0: tables are found by casino room; hand history; the daily books check.
// v0.11.0: stations (one session per machine), operation ids, and casino_step / casino_start (seats enforced in the transaction).
import { createClient } from 'jsr:@supabase/supabase-js@2';
import { handle } from './handler.js';
const sb = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!, { auth: { persistSession: false } });
const users = new Map<string, { u: { id: string; anon: boolean }; t: number }>();
// what a refused step means: short shards, seated at another table, or this operation id already used (answer from casino_ops)
const failed = (m: string) => /insufficient/.test(m) ? { error: 'insufficient' } : /seated elsewhere/.test(m) ? { error: 'seated' } : /duplicate op/.test(m) ? { dup: true } : { error: 'Server error' };
const one = async (q: any) => { const { data, error } = await q; if (error) throw error; return data; };
const D = {
  now: () => Date.now(),
  auth: async (tok: string) => {
    if (!tok) return null;
    const c = users.get(tok); if (c && c.t > Date.now()) return c.u;
    const { data, error } = await sb.auth.getUser(tok); if (error || !data.user) return null;
    const u = { id: data.user.id, anon: !!data.user.is_anonymous };
    if (users.size > 500) users.clear(); users.set(tok, { u, t: Date.now() + 60000 }); return u;
  },
  name: async (uid: string) => (await one(sb.from('profiles').select('username').eq('id', uid).maybeSingle()))?.username || 'PLAYER',
  balance: async (uid: string) => (await one(sb.from('lockers').select('shards').eq('user_id', uid).maybeSingle()))?.shards ?? 0,
  load: async (id: number) => await one(sb.from('casino_tables').select('id,code,game,st,ver,open').eq('id', id).maybeSingle()),
  byRoom: async (room: string, game: string, station: string) => await one(sb.from('casino_tables').select('id,code').eq('room', room).eq('game', game).eq('station', station || '').eq('open', true).maybeSingle()),
  seatOf: async (uid: string) => (await one(sb.from('casino_tables').select('id,code,game,room,station').eq('open', true).contains('humans', [uid]).limit(1)))[0] || null,
  opGet: async (uid: string, op: string) => await one(sb.from('casino_ops').select('req,table_id,res').eq('user_id', uid).eq('op_id', op).maybeSingle()),
  history: async (uid: string, n: number) => await one(sb.from('casino_hands').select('id,game,hand_no,hash,salt,deck,result,created_at')
    .contains('result->players', JSON.stringify([{ uid }])).order('id', { ascending: false }).limit(n)),
  books: async () => { const { error } = await sb.rpc('casino_books_run'); if (error) console.error('books', error.message); },
  stale: async (ms: number) => await one(sb.from('casino_tables').select('id').eq('open', true).lt('updated_at', new Date(Date.now() - ms).toISOString()).limit(10)),
  botLeft: async () => (await one(sb.rpc('casino_bot_left'))) ?? 0,
  commit: async (a: any) => {
    const { data, error } = await sb.rpc('casino_step', { p_table: a.id, p_ver: a.ver, p_st: a.st, p_humans: a.humans, p_open: a.open, p_ops: a.ops, p_hands: a.hands, p_op: a.op });
    if (error) return failed(error.message); return data;
  },
  create: async (a: any) => {
    const { data, error } = await sb.rpc('casino_start', { p_code: a.code, p_game: a.game, p_st: a.st, p_humans: a.humans, p_ops: a.ops, p_room: a.room, p_station: a.station || '', p_op: a.op });
    if (error) return failed(error.message); return data;
  },
};
const cors = { 'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Headers': 'authorization, apikey, content-type, x-client-info', 'Access-Control-Allow-Methods': 'POST, OPTIONS' };
Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: cors });
  let body: any = {}; try { body = await req.json(); } catch (_) { /* empty body */ }
  const tok = (req.headers.get('Authorization') || '').replace(/^Bearer\s+/i, '');
  let r; try { r = await handle(body, tok, D); } catch (e) { console.error(e); r = { status: 500, body: { error: 'Server error' } }; }
  return new Response(JSON.stringify(r.body), { status: r.status, headers: { ...cors, 'Content-Type': 'application/json' } });
});
