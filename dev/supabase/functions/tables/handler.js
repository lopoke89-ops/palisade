// v0.9.8 THE TABLES: one request = load the table, run the clock, apply the player's move, run the clock, save (only if
// nobody saved in between; otherwise retry), reply with what that player may see. `D` is the storage (the database in
// the edge function, a Map in the tests). Randomness and the deck hashes use Web Crypto, the same in Deno and Node.
// v0.10.0: tables live in THE PALISADE FALLS CASINO: you sit at a table by walking to it (op 'sit' with the casino room),
// never from a menu list. Roulette; your own seed; hand history (with the check); the daily books check.
import * as E from './engine.js';
const CODE='ABCDEFGHJKMNPQRSTUVWXYZ23456789',STALE_MS=180000;
export function rng(n){if(n<=1)return 0;const lim=Math.floor(4294967296/n)*n,a=new Uint32Array(1);for(;;){crypto.getRandomValues(a);if(a[0]<lim)return a[0]%n}}   // no modulo bias
const hex=n=>{const a=new Uint8Array(n);crypto.getRandomValues(a);return [...a].map(x=>x.toString(16).padStart(2,'0')).join('')},salt=()=>hex(12),seed=()=>hex(32);
export async function deckHash(salt,deck){const b=await crypto.subtle.digest('SHA-256',new TextEncoder().encode(salt+':'+deck.join(',')));return [...new Uint8Array(b)].map(x=>x.toString(16).padStart(2,'0')).join('')}
const R=(status,body)=>({status,body}),err=(status,error)=>R(status,{error});
const humansOf=st=>st.seats.filter(s=>s&&!s.bot).map(s=>s.uid);
const ROOM=/^[A-Za-z0-9:_-]{4,80}$/,GAMES=['bj','he','rl'],DAY=864e5;

async function run(D,id,uid,fn){
  for(let tries=0;tries<5;tries++){
    const t=await D.load(id);if(!t||!t.open)return err(404,'That table has closed');
    const st=t.st,now=D.now(),before=JSON.stringify(st),me=E.seatIx(st,uid),oldSeen=me>=0?st.seats[me].seen:0;
    const ctx={now,rng,salt,seed,ops:[],hands:[],botLeft:st.game==='he'&&st.phase==='wait'?await D.botLeft():0};
    E.tick(st,ctx);const e=fn?fn(st,ctx):null;E.tick(st,ctx);
    const dk=st.hand&&(st.hand.shoe||st.hand.deck);if(dk&&!st.hand.hash)st.hand.hash=await deckHash(st.hand.salt,dk);   // the deck's fingerprint, shown from the deal
    for(const h of ctx.hands)if(!h.hash)h.hash=await deckHash(h.salt,h.deck);if(st.last&&!st.last.hash&&ctx.hands.length)st.last.hash=ctx.hands.at(-1).hash;
    const meNow=E.seatIx(st,uid);
    // a plain poll that changed nothing skips the write; "seen" is refreshed every 15 s (a minute without polls stands you up)
    const changed=JSON.stringify(st)!==before||ctx.ops.length||ctx.hands.length;
    if(meNow>=0&&(changed||now-oldSeen>15000))st.seats[meNow].seen=now;
    if(changed||meNow>=0&&now-oldSeen>15000){
      const hs=humansOf(st);if(!hs.length)E.closeOut(st,ctx);   // closing: nobody's shards (not even the bot's) left unrecorded
      const c=await D.commit({id,ver:t.ver,st,humans:hs,open:hs.length>0,ops:ctx.ops,hands:ctx.hands});
      if(c.conflict)continue;if(c.error)return err(400,c.error==='insufficient'?'Not enough shards':c.error)}
    return R(200,{id,code:t.code,error:e||null,view:E.view(st,uid,now),balance:uid?await D.balance(uid):0})}
  return err(409,'The table is busy, try again')}

// tables nobody has touched for 3 minutes: everyone is stood up (their shards go home) and the table closes
async function sweep(D){for(const t of await D.stale(STALE_MS))await run(D,t.id,null,(st,ctx)=>{for(let k=0;k<6;k++){st.deadline=0;for(const s of st.seats)if(s&&!s.bot)s.seen=-1e15;E.tick(st,ctx)}
  for(let i=0;i<st.seats.length;i++)if(st.seats[i]&&st.phase==='wait')E.leave(st,st.seats[i].uid,ctx)})}

// one row of your hand history, as you may see it (the same rules as the table: Hold'em hides what folded players held for
// 24 hours, then shows the whole deck and the seed so the shuffle itself can be rerun)
export function histRow(r,uid,now){const res=r.result||{},o={no:r.hand_no,game:r.game,at:r.created_at,commit:res.commit||r.hash,result:res,code:r.code||''};
  const age=now-new Date(r.created_at).getTime(),full=r.game!=='he'||age>=DAY;
  if(full){o.seed=r.salt;o.deck=r.deck;return o}
  if(!res.commit||!Array.isArray(r.deck))return o;   // a Hold'em hand from before v0.10.0: no per-card check
  const ps=res.players||[],n=ps.length,me=ps.findIndex(p=>p.uid===uid),vis=new Set(),bp=[2*n+1,2*n+2,2*n+3,2*n+5,2*n+7];
  (res.board||[]).forEach((_,k)=>vis.add(bp[k]));if(me>=0){vis.add(me);vis.add(me+n)}ps.forEach((p,i)=>{if(p.cards){vis.add(i);vis.add(i+n)}});
  o.cardHashes=E.cardHashes(r.salt,r.deck);o.root=E.rootOf(o.cardHashes);o.cards=[...vis].sort((a,b)=>a-b).map(i=>[i,r.deck[i],E.cardSalt(r.salt,i)]);
  if(me>=0)o.mine=[r.deck[me],r.deck[me+n]];o.seedIn=Math.max(0,DAY-age);return o}

export async function handle(body,token,D){
  const u=await D.auth(token);if(!u)return err(401,'Sign in to play at the tables');
  if(u.anon)return err(403,'Make an account (Account page) to play at the tables; guests can\'t');
  const op=body&&body.op,id=+body.id||0;
  if(op==='lobby'){await sweep(D);if(D.books)await D.books();const mine=await D.seatOf(u.id);return R(200,{balance:await D.balance(u.id),mine:mine&&{id:mine.id,code:mine.code,game:mine.game,room:mine.room}})}
  if(op==='history'){const rows=D.history?await D.history(u.id,50):[],now=D.now();return R(200,{hands:rows.map(r=>histRow(r,u.id,now))})}
  // v0.10.0: walk to a table. One table of each game per casino room, found by the room; the first to sit opens it.
  if(op==='sit'){
    const room=String(body.room||''),game=GAMES.includes(body.game)?body.game:null;if(!ROOM.test(room)||!game)return err(400,'Walk up to a table in THE PALISADE FALLS CASINO to play');
    const mine=await D.seatOf(u.id);if(mine)return run(D,mine.id,u.id,null);   // already sitting somewhere: back to that table
    if(await D.balance(u.id)<E.BUYIN)return err(400,'The buy-in is '+E.BUYIN+' shards');
    const name=(await D.name(u.id)||'PLAYER').toUpperCase(),sd=E.cleanSeed(body.seed);
    for(let k=0;k<6;k++){
      const t=await D.byRoom(room,game);if(t)return run(D,t.id,u.id,(st,ctx)=>E.sit(st,{uid:u.id,name,seed:sd},ctx));
      const lim=E.LIMITS.includes(+body.lim)?+body.lim:100,st=E.newTable({game,lim,side:!!body.side,host:u.id,tid:salt(),room}),ctx={now:D.now(),rng,salt,seed,ops:[],hands:[]};
      E.sit(st,{uid:u.id,name,seed:sd},ctx);st.seats[0].seen=ctx.now;
      const code=Array.from({length:4},()=>CODE[rng(CODE.length)]).join(''),c=await D.create({code,game,st,humans:[u.id],ops:ctx.ops,room});
      if(c.ok)return run(D,c.id,u.id,null);if(c.error)return err(400,c.error==='insufficient'?'Not enough shards':c.error)}   // a conflict (someone opened it at the same moment, or the code was taken): look again
    return err(500,'Could not open a table')}
  if(op==='open'||op==='join')return err(400,'The tables are in THE PALISADE FALLS CASINO now: walk up to one to play');
  if(!id)return err(400,'Which table?');
  const M={state:null,
    bet:(st,ctx)=>E.bjBet(st,u.id,body.amt,!!body.side,ctx),
    insure:st=>E.bjInsure(st,u.id,!!body.yes),
    move:(st,ctx)=>st.game==='bj'?E.bjAct(st,u.id,body.a,ctx):E.heAct(st,u.id,{a:body.a,amt:body.amt},ctx),
    side:st=>{const s=st.seats[E.seatIx(st,u.id)];if(!s)return 'Not seated';s.side=!!body.on;return null},
    topup:(st,ctx)=>E.topup(st,u.id,body.amt,ctx),
    leave:(st,ctx)=>E.leave(st,u.id,ctx),
    start:st=>E.start(st,u.id),
    ready:st=>E.ready(st,u.id),
    settings:st=>E.settings(st,u.id,{lim:body.lim===undefined?undefined:+body.lim,side:body.side}),
    pick:(st,ctx)=>E.pick(st,u.id,body.kind,ctx),
    seed:st=>E.setSeed(st,u.id,body.seed),
    rlbets:st=>E.rlSetBets(st,u.id,body.bets),
    rlready:st=>E.rlReady(st,u.id)};
  if(!(op in M))return err(400,'Unknown request');
  if(op==='topup'&&await D.balance(u.id)<(+body.amt||0))return err(400,'Not enough shards');
  return run(D,id,u.id,M[op])}
