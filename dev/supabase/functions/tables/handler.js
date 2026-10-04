// v0.9.8 THE TABLES: one request = load the table, run the clock, apply the player's move, run the clock, save (only if
// nobody saved in between; otherwise retry), reply with what that player may see. `D` is the storage (the database in
// the edge function, a Map in the tests). Randomness and the deck hashes use Web Crypto, the same in Deno and Node.
import * as E from './engine.js';
const CODE='ABCDEFGHJKMNPQRSTUVWXYZ23456789',STALE_MS=180000;
export function rng(n){if(n<=1)return 0;const lim=Math.floor(4294967296/n)*n,a=new Uint32Array(1);for(;;){crypto.getRandomValues(a);if(a[0]<lim)return a[0]%n}}   // no modulo bias
const salt=()=>{const a=new Uint8Array(12);crypto.getRandomValues(a);return [...a].map(x=>x.toString(16).padStart(2,'0')).join('')};
export async function deckHash(salt,deck){const b=await crypto.subtle.digest('SHA-256',new TextEncoder().encode(salt+':'+deck.join(',')));return [...new Uint8Array(b)].map(x=>x.toString(16).padStart(2,'0')).join('')}
const R=(status,body)=>({status,body}),err=(status,error)=>R(status,{error});
const humansOf=st=>st.seats.filter(s=>s&&!s.bot).map(s=>s.uid);
export function summary(t){const st=t.st;return{id:t.id,code:t.code,game:st.game,lim:st.lim,side:st.side,seated:st.seats.filter(Boolean).length,seats:st.seats.length,
  host:(st.seats.find(s=>s&&s.uid===st.host)||{}).name||'',bot:st.seats.some(s=>s&&s.bot)}}

async function run(D,id,uid,fn){
  for(let tries=0;tries<5;tries++){
    const t=await D.load(id);if(!t||!t.open)return err(404,'That table has closed');
    const st=t.st,now=D.now(),before=JSON.stringify(st),me=E.seatIx(st,uid),oldSeen=me>=0?st.seats[me].seen:0;
    const ctx={now,rng,salt,ops:[],hands:[],botLeft:st.game==='he'&&st.phase==='wait'?await D.botLeft():0};
    E.tick(st,ctx);const e=fn?fn(st,ctx):null;E.tick(st,ctx);
    const dk=st.hand&&(st.hand.shoe||st.hand.deck);if(dk&&!st.hand.hash)st.hand.hash=await deckHash(st.hand.salt,dk);   // the deck's fingerprint, shown from the deal
    for(const h of ctx.hands)if(!h.hash)h.hash=await deckHash(h.salt,h.deck);if(st.last&&!st.last.hash&&ctx.hands.length)st.last.hash=ctx.hands.at(-1).hash;
    const meNow=E.seatIx(st,uid);
    // a plain poll that changed nothing skips the write; "seen" is refreshed every 15 s (a minute without polls stands you up)
    const changed=JSON.stringify(st)!==before||ctx.ops.length||ctx.hands.length;
    if(meNow>=0&&(changed||now-oldSeen>15000))st.seats[meNow].seen=now;
    if(changed||meNow>=0&&now-oldSeen>15000){
      const hs=humansOf(st),c=await D.commit({id,ver:t.ver,st,humans:hs,open:hs.length>0,ops:ctx.ops,hands:ctx.hands});
      if(c.conflict)continue;if(c.error)return err(400,c.error==='insufficient'?'Not enough shards':c.error)}
    return R(200,{id,code:t.code,error:e||null,view:E.view(st,uid,now),balance:uid?await D.balance(uid):0})}
  return err(409,'The table is busy, try again')}

// tables nobody has touched for 3 minutes: everyone is stood up (their shards go home) and the table closes
async function sweep(D){for(const t of await D.stale(STALE_MS))await run(D,t.id,null,(st,ctx)=>{for(let k=0;k<6;k++){st.deadline=0;for(const s of st.seats)if(s&&!s.bot)s.seen=-1e15;E.tick(st,ctx)}
  for(let i=0;i<st.seats.length;i++)if(st.seats[i]&&st.phase==='wait')E.leave(st,st.seats[i].uid,ctx)})}

export async function handle(body,token,D){
  const u=await D.auth(token);if(!u)return err(401,'Sign in to play at the tables');
  if(u.anon)return err(403,'Make an account (Account page) to play at the tables; guests can\'t');
  const op=body&&body.op,id=+body.id||0;
  if(op==='lobby'){await sweep(D);const mine=await D.seatOf(u.id);return R(200,{balance:await D.balance(u.id),mine:mine&&{id:mine.id,code:mine.code},tables:(await D.list()).map(summary)})}
  if(op==='open'||op==='join'){
    const mine=await D.seatOf(u.id);if(mine)return run(D,mine.id,u.id,null);   // already sitting somewhere: back to that table
    if(await D.balance(u.id)<E.BUYIN)return err(400,'The buy-in is '+E.BUYIN+' shards');
    const name=(await D.name(u.id)||'PLAYER').toUpperCase();
    if(op==='open'){const game=body.game==='he'?'he':'bj',lim=E.LIMITS.includes(+body.lim)?+body.lim:100,st=E.newTable({game,lim,side:!!body.side,host:u.id}),ctx={now:D.now(),rng,salt,ops:[],hands:[]};
      E.sit(st,{uid:u.id,name},ctx);st.seats[0].seen=ctx.now;
      for(let k=0;k<6;k++){const code=Array.from({length:4},()=>CODE[rng(CODE.length)]).join(''),c=await D.create({code,game,st,humans:[u.id],ops:ctx.ops});
        if(c.ok)return run(D,c.id,u.id,null);if(c.error)return err(400,c.error==='insufficient'?'Not enough shards':c.error)}
      return err(500,'Could not open a table')}
    const t=await D.byCode(String(body.code||'').toUpperCase().trim());if(!t)return err(404,'No open table with that code');
    return run(D,t.id,u.id,(st,ctx)=>E.sit(st,{uid:u.id,name},ctx))}
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
    pick:(st,ctx)=>E.pick(st,u.id,body.kind,ctx)};
  if(!(op in M))return err(400,'Unknown request');
  if(op==='topup'&&await D.balance(u.id)<(+body.amt||0))return err(400,'Not enough shards');
  return run(D,id,u.id,M[op])}
