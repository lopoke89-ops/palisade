// v0.9.8 THE TABLES: one request = load the table, run the clock, apply the player's move, run the clock, save (only if
// nobody saved in between; otherwise retry), reply with what that player may see. `D` is the storage (the database in
// the edge function, a Map in the tests). Randomness and the deck hashes use Web Crypto, the same in Deno and Node.
// v0.10.0: tables live in THE PALISADE FALLS CASINO: you sit at a table by walking to it (op 'sit' with the casino room),
// never from a menu list. Roulette; your own seed; hand history (with the check); the daily books check.
// v0.10.3: baccarat, craps, slots and Plinko. Machines are stations (one session per cabinet: station 's1'…'s16', 'p1').
// Money moves carry an operation id the client keeps until it has an answer: the same id again returns the first answer
// (never a second debit or payout), the same id with a different request is refused. The id is saved in the same database
// transaction as the move. Craps bets that must finish keep your account at that table until the dealer has rolled them out.
import * as E from './engine.js';
import * as X from './games.js';
import {isManaged,managedHash,decision,expectedOk,autoStart,exactSit,REVISION} from './managed.js';
const CODE='ABCDEFGHJKMNPQRSTUVWXYZ23456789',STALE_MS=180000;
export function rng(n){if(n<=1)return 0;const lim=Math.floor(4294967296/n)*n,a=new Uint32Array(1);for(;;){crypto.getRandomValues(a);if(a[0]<lim)return a[0]%n}}   // no modulo bias
const hex=n=>{const a=new Uint8Array(n);crypto.getRandomValues(a);return [...a].map(x=>x.toString(16).padStart(2,'0')).join('')},salt=()=>hex(12),seed=()=>hex(32);
export async function deckHash(salt,deck){const b=await crypto.subtle.digest('SHA-256',new TextEncoder().encode(salt+':'+deck.join(',')));return [...new Uint8Array(b)].map(x=>x.toString(16).padStart(2,'0')).join('')}
const R=(status,body)=>({status,body}),err=(status,error)=>R(status,{error});
const humansOf=st=>st.seats.filter(s=>s&&!s.bot).map(s=>s.uid);
const ROOM=/^[A-Za-z0-9:_-]{4,80}$/,GAMES=['bj','he','rl','ba','cr','sl','pk'],DAY=864e5;
// which stations a game has: the tables one each (''), sixteen slot cabinets, one Plinko board
export const STATIONS={sl:/^s(1[0-6]|[1-9])$/,pk:/^p1$/};
export const stationOk=(game,st)=>STATIONS[game]?STATIONS[game].test(st):st==='';
// the moves that can move shards: these take an operation id (the v0.10.3 games require one)
const MONEY=new Set(['sit','topup','leave','bet','insure','move','rlbets','babets','crbet','spin','drop','pick']),NEEDS_OP=new Set(['babets','crbet','spin','drop']);
const OPID=/^[A-Za-z0-9_-]{8,64}$/;
const canon=x=>Array.isArray(x)?'['+x.map(canon).join(',')+']':x&&typeof x==='object'?'{'+Object.keys(x).sort().map(k=>JSON.stringify(k)+':'+canon(x[k])).join(',')+'}':JSON.stringify(x===undefined?null:x);
// what an operation id stands for: the request itself (op, table, amounts, bets), never the seed or the id
export const reqHash=b=>{const o={...b};delete o.opId;delete o.seed;return E.sha256hex(canon(o))};

export async function run(D,id,uid,fn,op){
  for(let tries=0;tries<5;tries++){
    const t=await D.load(id);if(!t||!t.open)return err(404,'That table has closed');
    const st=t.st,now=D.now(),before=JSON.stringify(st),me=E.seatIx(st,uid),oldSeen=me>=0?st.seats[me].seen:0;
    const ctx={now,rng,salt,seed,ops:[],hands:[],botLeft:st.game==='he'&&st.phase==='wait'?await D.botLeft():0};
    if(isManaged(st.room)&&(st.managedRevision!==REVISION||st.fv!==E.FV||st.rulesRevision&&st.rulesRevision!==`${E.FV}:${E.RV[st.game]}`))return err(409,'Unsupported casino revision');
    autoStart(st);E.tick(st,ctx);const no0=st.handNo,e=fn?(isManaged(st.room)&&D.request?.expected&&!expectedOk(st,D.request.expected)?'That decision has passed. Review the table before playing again.':fn(st,ctx)):null;autoStart(st);E.tick(st,ctx);
    const dk=st.hand&&(st.hand.shoe||st.hand.deck);if(dk&&!st.hand.hash)st.hand.hash=await deckHash(st.hand.salt,dk);   // the deck's fingerprint, shown from the deal
    for(const h of ctx.hands)if(!h.hash)h.hash=await deckHash(h.salt,h.deck);if(st.last&&!st.last.hash&&ctx.hands.length)st.last.hash=ctx.hands.at(-1).hash;
    const meNow=E.seatIx(st,uid);
    // a plain poll that changed nothing skips the write; "seen" is refreshed every 15 s (a minute without polls stands you up)
    const keep=op&&!e,changed=JSON.stringify(st)!==before||ctx.ops.length||ctx.hands.length||keep;
    if(meNow>=0&&(changed||now-oldSeen>15000))st.seats[meNow].seen=now;
    // the receipt this operation produced (a spin, a drop): replayed as is if the same id comes again
    const rcpt=keep&&st.handNo!==no0&&st.last&&st.last.result?{no:st.last.no,result:st.last.result}:null;
    if(changed||meNow>=0&&now-oldSeen>15000){
      const hs=humansOf(st);if(!hs.length)E.closeOut(st,ctx);   // closing: nobody's shards (not even the bot's) left unrecorded
      const c=await D.commit({id,ver:t.ver,st,humans:hs,open:hs.length>0,ops:ctx.ops,hands:ctx.hands,op:keep?{uid,id:op.id,req:op.req,res:{error:null,rcpt}}:null});
      if(c.conflict)continue;if(c.dup)return replay(D,uid,op);
      if(c.error)return err(400,c.error==='insufficient'?'Not enough shards':c.error==='seated'?'You are still seated at another table. Stand up there first.':c.error)}
    return R(200,{id,code:t.code,error:e||null,view:{...E.view(st,uid,now),...(isManaged(st.room)?{expected:decision(st)}:{})},balance:uid?await D.balance(uid):0,...(rcpt?{rcpt}:{})})}
  return err(409,'The table is busy, try again')}
// the same operation again: its first answer, with the table as it is now
async function replay(D,uid,op){const o=await D.opGet(uid,op.id);if(!o)return err(409,'The table is busy, try again');
  if(o.req!==op.req)return err(409,'That request id was already used for a different request');
  if(D.managed){const t=o.table_id?await D.load(o.table_id):null;return R(200,{replay:true,error:null,...(o.res||{}),...(t?{id:t.id,code:t.code,view:{...E.view(t.st,uid,D.now()),expected:decision(t.st)},balance:await D.balance(uid)}:{})})}
  const r=o.table_id?await run(D,o.table_id,uid,null,null):R(200,{});if(r.status!==200)return R(200,{replay:true,error:null,...(o.res||{})});
  r.body.replay=true;if(o.res&&o.res.rcpt)r.body.rcpt=o.res.rcpt;return r}

// tables nobody has touched for 3 minutes: everyone is stood up (their shards go home) and the table closes. Craps bets that
// must finish are rolled out first, a bounded batch at a time (the next sweep carries on where this one stopped).
// only bets of players who have left are on the table (nobody is playing): the dealer rolls them out without waiting
const fastForward=(st,ctx,n)=>{for(let k=0;k<n;k++){if(st.game!=='cr'||!st.seats.some(s=>s&&s.gone)||st.seats.some(s=>s&&!s.bot&&!s.gone))break;st.deadline=0;st.minAt=0;E.tick(st,ctx)}};
async function sweep(D){for(const t of await D.stale(STALE_MS)){const table=await D.load(t.id);if(isManaged(table?.st?.room))continue;await run(D,t.id,null,(st,ctx)=>{for(let k=0;k<6;k++){st.deadline=0;st.minAt=0;for(const s of st.seats)if(s&&!s.bot)s.seen=-1e15;E.tick(st,ctx)}
  if(st.game==='cr')fastForward(st,ctx,60);
  for(let i=0;i<st.seats.length;i++)if(st.seats[i]&&(st.phase==='wait'||st.phase==='idle'||st.phase==='bet'&&st.game!=='cr')&&!st.seats[i].gone)E.leave(st,st.seats[i].uid,ctx)})}}

// one row of your hand history, as you may see it (the same rules as the table: Hold'em hides what folded players held for
// 24 hours, then shows the whole deck and the seed so the shuffle itself can be rerun). Baccarat: a hand shows its own cards
// with each card's salt (checked against the shoe's fingerprint); the seed and the whole shoe come with the shoe's last row.
export function histRow(r,uid,now){const res=r.result||{},o={no:r.hand_no,game:r.game,at:r.created_at,commit:res.commit||r.hash,result:res,code:r.code||'',id:r.id,tid:r.table_id};
  if(r.game==='ba'){if(res.shoeEnd){o.seed=r.salt;o.deck=r.deck;return o}const sh=res.shoe;if(sh&&Array.isArray(sh.pos)&&Array.isArray(r.deck)){o.root=sh.root;o.cards=sh.pos.map((p,i)=>[p,r.deck[i],E.cardSalt(r.salt,p)])}return o}
  const age=now-new Date(r.created_at).getTime(),full=r.game!=='he'||age>=DAY;
  if(full){o.seed=r.salt;o.deck=r.deck;return o}
  if(!res.commit||!Array.isArray(r.deck))return o;   // a Hold'em hand from before v0.10.0: no per-card check
  const ps=res.players||[],n=ps.length,me=ps.findIndex(p=>p.uid===uid),vis=new Set(),bp=[2*n+1,2*n+2,2*n+3,2*n+5,2*n+7];
  (res.board||[]).forEach((_,k)=>vis.add(bp[k]));if(me>=0){vis.add(me);vis.add(me+n)}ps.forEach((p,i)=>{if(p.cards){vis.add(i);vis.add(i+n)}});
  o.cardHashes=E.cardHashes(r.salt,r.deck);o.root=E.rootOf(o.cardHashes);o.cards=[...vis].sort((a,b)=>a-b).map(i=>[i,r.deck[i],E.cardSalt(r.salt,i)]);
  if(me>=0)o.mine=[r.deck[me],r.deck[me+n]];o.seedIn=Math.max(0,DAY-age);return o}

async function baseHandle(body,token,D){
  const u=await D.auth(token);if(!u)return err(401,'Sign in to play at the tables');
  if(u.anon)return err(403,'Make an account (Account page) to play at the tables; guests can\'t');
  const op=body&&body.op,id=+body.id||0;
  // an operation id: checked before anything runs, so a retry of something already done only gets its first answer
  let opx=null;if(MONEY.has(op)||D.managed&& !['state','peek','history','shoe','lobby'].includes(op)){const oid=body.opId;
    if(oid!==undefined&&oid!==null){if(typeof oid!=='string'||!OPID.test(oid))return err(400,'Bad request id');opx={id:oid,req:D.managed?managedHash(body):reqHash(body)}}
    else if(D.managed)return err(400,'A request id is required');
    else if(NEEDS_OP.has(op))return err(400,'Update the game (reload the page) to play this');
    if(opx&&D.opGet){const o=await D.opGet(u.id,opx.id);if(o)return replay(D,u.id,opx)}}
  if(op==='lobby'){await sweep(D);if(D.books)await D.books();let mine=await D.seatOf(u.id);
    // you left a craps table with bets still working: the dealer rolls them out now (you're waiting on them)
    if(mine&&mine.game==='cr'&&!isManaged(mine.room)){await run(D,mine.id,null,(st,ctx)=>{const s=st.seats[E.seatIx(st,u.id)];if(s&&s.gone)fastForward(st,ctx,60)});mine=await D.seatOf(u.id)}
    let pending=null;if(mine){const t=await D.load(mine.id);const s=t&&t.st.seats[E.seatIx(t.st,u.id)];if(s&&s.gone)pending={game:mine.game,bets:Object.keys((t.st.cr&&t.st.cr.bets[u.id])||{}).length}}
    return R(200,{balance:await D.balance(u.id),mine:mine&&{id:mine.id,code:mine.code,game:mine.game,room:mine.room,station:mine.station||'',pending}})}
  if(op==='history'){const rows=D.history?await D.history(u.id,50):[],now=D.now();return R(200,{hands:rows.map(r=>histRow(r,u.id,now))})}
  // walk to a table or a machine. One table of each game per casino room, one session per machine; the first to sit opens it.
  if(op==='sit'){
    const room=String(body.room||''),game=GAMES.includes(body.game)?body.game:null,station=String(body.station||'');
    if(!ROOM.test(room)||!game||!stationOk(game,station))return err(400,'Walk up to a table in THE PALISADE FALLS CASINO to play');
    const mine=await D.seatOf(u.id);if(mine){if(mine.room===room&&mine.game===game&&(mine.station||'')===station)return run(D,mine.id,u.id,(st,ctx)=>E.rejoin(st,u.id,ctx),opx);   // already in this seat: back to it
      return err(400,mine.game==='cr'?'Your craps bets are still being rolled out. Stand up there first, or wait for them to finish.':'You are still seated at another table. Stand up there first.')}
    if(await D.balance(u.id)<E.BUYIN)return err(400,'The buy-in is '+E.BUYIN+' shards');
    const name=(await D.name(u.id)||'PLAYER').toUpperCase(),sd=E.cleanSeed(body.seed),seat=Number.isInteger(body.seat)?body.seat:-1;
    for(let k=0;k<6;k++){
      const t=await D.byRoom(room,game,station);if(t)return run(D,t.id,u.id,(st,ctx)=>(D.managed?exactSit:E.sit)(st,{uid:u.id,name,seed:sd,seat},ctx),opx);
      const lim=D.managed?100:E.LIMITS.includes(+body.lim)?+body.lim:100,st=E.newTable({game,lim,side:D.managed?false:!!body.side,host:u.id,tid:salt(),room,station}),ctx={now:D.now(),rng,salt,seed,ops:[],hands:[]};
      if(D.managed){st.managedRevision=REVISION;st.rulesRevision=`${E.FV}:${E.RV[game]}`;}
      const sitError=(D.managed?exactSit:E.sit)(st,{uid:u.id,name,seed:sd,seat},ctx);if(sitError)return err(400,sitError);st.seats[E.seatIx(st,u.id)].seen=ctx.now;
      const code=Array.from({length:4},()=>CODE[rng(CODE.length)]).join(''),c=await D.create({code,game,st,humans:[u.id],ops:ctx.ops,room,station,op:opx?{uid:u.id,id:opx.id,req:opx.req,res:{error:null}}:null});
      if(c.ok)return run(D.afterCreate?D.afterCreate():D,c.id,u.id,null,null);if(c.dup)return replay(D,u.id,opx);if(c.error)return err(400,c.error==='insufficient'?'Not enough shards':c.error==='seated'?'You are still seated at another table. Stand up there first.':c.error)}   // a conflict (someone opened it at the same moment, or the code was taken): look again
    return err(500,'Could not open a table')}
  // what's on a table or machine you're standing next to (what anyone walking past could see: no hole cards)
  if(op==='peek'){const room=String(body.room||''),game=GAMES.includes(body.game)?body.game:null,station=String(body.station||'');if(!ROOM.test(room)||!game||!stationOk(game,station))return err(400,'Which table?');
    const t=await D.byRoom(room,game,station);if(!t)return R(200,{view:null});if(D.managed){const x=await D.load(t.id);return R(200,{view:E.view(x.st,null,D.now())})}const r=await run(D,t.id,null,null,null);if(r.body&&r.body.view)delete r.body.balance;return r}
  if(op==='open'||op==='join')return err(400,'The tables are in THE PALISADE FALLS CASINO now: walk up to one to play');
  if(!id)return err(400,'Which table?');
  // baccarat: the fingerprints of every card in the shoe in play (no card values), so a hand's cards can be checked now
  if(op==='shoe'){const t=await D.load(id);const sh=t&&t.st.ba&&t.st.ba.shoe;if(!sh||E.seatIx(t.st,u.id)<0&&!(+body.no))return err(404,'No shoe');
    if(+body.no&&+body.no!==sh.no)return err(404,'That shoe is finished: its full check is in your hand history');
    return R(200,{no:sh.no,root:sh.root,hashes:E.cardHashes(sh.seed,sh.cards)})}
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
  for(const [k,f]of Object.entries(X.ACTIONS))M[k]=(st,ctx)=>f(st,u.id,body,ctx);
  if(!(op in M))return err(400,'Unknown request');
  if(op==='topup'&&await D.balance(u.id)<(+body.amt||0))return err(400,'Not enough shards');
  return run(D,id,u.id,M[op],opx)}

// Resolve the table namespace from storage; a caller cannot bypass fencing by omitting a transport flag.
export async function handle(body,token,D){
 const u=await D.auth(token);if(!u||u.anon)return baseHandle(body,token,D);
 if(body?.op==='revoke'){if(!D.world)return err(503,'Managed casino unavailable');try{return R(200,await D.world({action:'revoke',uid:u.id,session:body.controller?.session,generation:body.controller?.generation}))}catch(e){return err(409,e.message)}}
 if(body?.op==='recover'){if(!D.world)return err(503,'Managed casino unavailable');try{return R(200,await D.world({action:'recover',uid:u.id,session:body.session,takeover:!!body.takeover}))}catch(e){return err(409,e.message)}}
 const table=body?.id?await D.load(+body.id):null,managed=isManaged(body?.room)||isManaged(table?.st?.room);
 if(!managed)return baseHandle(body,token,D);
 if(!D.withManaged)return err(503,'Update the table backend before opening managed rooms');
 if(!['state','peek','history','shoe','lobby','sit','topup','leave','pick'].includes(body.op)&&!body.expected)return err(409,'Review the current table before playing');
 if(['settings','start','side'].includes(body.op))return err(400,'Public casino tables use the house settings');
 const scope=D.withManaged(u.id,body);
 // Accepted retry is pure and authenticated, even after this tab has lost control.
 if(body.opId&&OPID.test(body.opId)&&await D.opGet(u.id,body.opId))return replay(scope,u.id,{id:body.opId,req:managedHash(body)});
 try{const c=await D.world({action:'controller',uid:u.id,session:body.controller?.session,generation:body.controller?.generation});scope.now=()=>c.now;
  const result=await baseHandle(body,token,scope);
  if(result.body?.error&&body.opId&&await D.opGet(u.id,body.opId))return replay(scope,u.id,{id:body.opId,req:managedHash(body)});
  return result;
 }catch(e){if(body.opId&&await D.opGet(u.id,body.opId))return replay(scope,u.id,{id:body.opId,req:managedHash(body)});return err(409,e.message||'Casino controller unavailable')}
}

// Natural deadlines only. Review windows remain intact; only entirely departed craps obligations accelerate.
export async function recoverTable(D,id){return run(D,id,null,(st,ctx)=>{if(st.game==='cr')fastForward(st,ctx,60)},null)}
