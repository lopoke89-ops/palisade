// v0.9.8 THE TABLES: the rules, run only on the server (the `tables` edge function). Blackjack from a 4-deck shoe that is
// reshuffled before every hand (so counting cards is worthless); Texas Hold'em from one 52-card deck. Straight shards:
// a seat's stack is shards brought to the table; the limit caps a single bet. No I/O here: the caller passes the time,
// a cryptographic rng(n) -> 0..n-1, and collects `ctx.ops` (shard and case moves for the ledger) and `ctx.hands` (the log).
export const BUYIN=5,TURN_MS=20000,BET_MS=12000,INS_MS=10000,PAUSE_MS=5000,BOT_MS=1300,AWAY_MS=60000,
  RAKE=.018,RAKE_CAP=6,SIDE_COST=1,BOT_DAILY=25,SB=1,BB=2,SEATS={bj:5,he:6},LIMITS=[100,250,0];
export const PRIZES={hybrid:10,flags:15};   // the side bet: 10 Hybrid Theory Cases or 15 Flag Cases, the winner picks

// ---------- cards ----------
// a card is 0..51 (in a shoe, any int: c%52): rank c%13 (0 = 2 … 8 = 10, 9 J, 10 Q, 11 K, 12 A), suit ((c%52)/13)|0
export const rankOf=c=>c%52%13,suitOf=c=>((c%52)/13)|0;
export function shuffle(n,rng){const d=Array.from({length:n},(_,i)=>i);for(let i=n-1;i>0;i--){const j=rng(i+1),t=d[i];d[i]=d[j];d[j]=t}return d}

// ---------- poker hand values ----------
// a single number per 5-card hand: category (8 straight flush … 0 high card) then up to five kickers, base 13
const P13=[1,13,169,2197,28561,371293];
export const CAT=['HIGH CARD','PAIR','TWO PAIR','THREE OF A KIND','STRAIGHT','FLUSH','FULL HOUSE','FOUR OF A KIND','STRAIGHT FLUSH'];
export function eval5(cs){
  const r=cs.map(rankOf).sort((a,b)=>b-a),s0=suitOf(cs[0]),flush=cs.every(c=>suitOf(c)===s0),cnt=new Map();
  for(const x of r)cnt.set(x,(cnt.get(x)||0)+1);
  const g=[...cnt].sort((a,b)=>b[1]-a[1]||b[0]-a[0]),ks=g.map(x=>x[0]);
  let st=-1;if(g.length===5){if(r[0]-r[4]===4)st=r[0];else if(r[0]===12&&r[1]===3)st=3}   // the wheel (A-2-3-4-5) is a 5-high straight
  const v=(cat,k)=>cat*P13[5]+k.reduce((a,x,i)=>a+x*P13[4-i],0);
  if(st>=0&&flush)return v(8,[st]);if(g[0][1]===4)return v(7,ks);if(g[0][1]===3&&g[1][1]===2)return v(6,ks);
  if(flush)return v(5,r);if(st>=0)return v(4,[st]);if(g[0][1]===3)return v(3,ks);if(g[0][1]===2&&g[1][1]===2)return v(2,ks);if(g[0][1]===2)return v(1,ks);return v(0,r)}
const C7=[];for(let a=0;a<7;a++)for(let b=a+1;b<7;b++)C7.push([0,1,2,3,4,5,6].filter(i=>i!==a&&i!==b));
export function best(cs){if(cs.length<=5)return eval5(cs);let m=-1;if(cs.length===7){for(const ix of C7){const v=eval5(ix.map(i=>cs[i]));if(v>m)m=v}return m}
  for(let skip=0;skip<cs.length;skip++){const v=best(cs.filter((_,i)=>i!==skip));if(v>m)m=v}return m}
export const catOf=v=>Math.floor(v/P13[5]);

// ---------- blackjack values ----------
export const bjVal=c=>{const r=rankOf(c);return r<8?r+2:r<12?10:11};
export function bjTotal(cs){let t=0,a=0;for(const c of cs){const v=bjVal(c);t+=v;if(v===11)a++}while(t>21&&a){t-=10;a--}return{t,soft:a>0}}
const natural=h=>h.cards.length===2&&!h.split&&bjTotal(h.cards).t===21;

// ---------- the table ----------
export function newTable({game,lim,side,host}){
  return{game,lim:LIMITS.includes(lim)?lim:100,side:!!side,host,seats:Array(SEATS[game]).fill(null),phase:'wait',deadline:0,handNo:0,button:-1,
    hand:null,last:null,picks:{},log:[]}}
const humans=st=>st.seats.filter(s=>s&&!s.bot);
export const seatIx=(st,uid)=>st.seats.findIndex(s=>s&&s.uid===uid);
const note=(st,t)=>{st.log.push(t);if(st.log.length>8)st.log.shift()};
export function sit(st,{uid,name},ctx){
  if(seatIx(st,uid)>=0)return 'You are already at this table';
  const i=st.seats.findIndex(s=>!s);if(i<0)return 'The table is full';
  st.seats[i]={uid,name,stack:BUYIN,brought:BUYIN,sitout:0,side:false,seen:ctx.now};ctx.ops.push({uid,k:'buyin',d:-BUYIN});note(st,name+' sat down');return null}
export function topup(st,uid,amt,ctx){
  const s=st.seats[seatIx(st,uid)];if(!s)return 'You are not at this table';amt=Math.floor(+amt);if(!(amt>=1&&amt<=100000))return 'Pick an amount';
  if(inHand(st,uid))return 'Top up between hands';
  s.stack+=amt;s.brought+=amt;ctx.ops.push({uid,k:'topup',d:-amt});return null}
function inHand(st,uid){const h=st.hand;if(!h||st.phase==='wait'||st.phase==='done'||st.phase==='bet')return false;return h.players.some(p=>p.uid===uid)}
function standUp(st,i,ctx){const s=st.seats[i];if(!s)return;
  while(st.picks[s.uid]>0)pick(st,s.uid,'hybrid',ctx);   // an unpicked side-bet prize is never lost: Hybrid Theory by default
  if(s.bot)ctx.ops.push({k:'bot',d:s.stack-s.brought});else{if(s.stack>0)ctx.ops.push({uid:s.uid,k:'cashout',d:s.stack});note(st,s.name+' stood up')}
  st.seats[i]=null;if(st.host===s.uid){const h=humans(st)[0];st.host=h?h.uid:null}}
export function leave(st,uid,ctx){
  const i=seatIx(st,uid);if(i<0)return 'You are not at this table';const s=st.seats[i];
  if(inHand(st,uid)){s.leaving=true;const h=st.hand,p=h.players.find(p=>p.uid===uid);
    if(st.game==='he'){if(!p.folded){p.folded=true;p.acted=true;if(h.players[h.cur]===p)heAdvance(st,ctx);else heCheckEnd(st,ctx)}}
    else{for(const hh of p.hands)hh.done=true;if(st.phase==='ins')p.ins=0;if(st.phase==='play')bjAdvance(st,ctx)}
    return null}
  if(st.phase==='bet'&&st.hand&&st.hand.bets[uid]){s.stack+=st.hand.bets[uid].bet+st.hand.bets[uid].side;delete st.hand.bets[uid]}
  standUp(st,i,ctx);return null}
export function settings(st,uid,{lim,side}){if(st.host!==uid)return 'Only the host can change the table';if(st.handNo>0)return 'Settings lock once the first hand is dealt';
  if(lim!==undefined){if(!LIMITS.includes(lim))return 'Pick 100, 250 or No limit';st.lim=lim}if(side!==undefined)st.side=!!side;return null}
export function pick(st,uid,kind,ctx){if(!(st.picks[uid]>0))return 'No prize to pick';if(!PRIZES[kind])return 'Pick Hybrid Theory or Flag Cases';
  st.picks[uid]--;if(!st.picks[uid])delete st.picks[uid];ctx.ops.push({uid,k:'case',bag:kind,n:PRIZES[kind]});return null}
const maxBet=(st,stack)=>st.lim?Math.min(st.lim,stack):stack;
function sideHit(st,uid,why){st.picks[uid]=(st.picks[uid]||0)+1;st.hand.sideHits.push({uid,why})}

// ---------- the clock: everything automatic happens here (deals, timeouts, the bot, the pause between hands) ----------
export function tick(st,ctx){
  for(let guard=0;guard<40;guard++){const before=st.phase+'|'+(st.hand?st.hand.step:0);step(st,ctx);if(st.phase+'|'+(st.hand?st.hand.step:0)===before)break}}
function step(st,ctx){
  const now=ctx.now;
  // a player who stopped polling for a minute is stood up (their shards go back to their balance)
  for(let i=0;i<st.seats.length;i++){const s=st.seats[i];if(s&&!s.bot&&now-s.seen>AWAY_MS&&!s.leaving){if(inHand(st,s.uid))leave(st,s.uid,ctx);else standUp(st,i,ctx)}}
  if(st.phase==='wait'){if(st.game==='bj')bjOpen(st,ctx);else heTryDeal(st,ctx);return}
  if(st.phase==='done'){if(now>=st.deadline)cleanup(st,ctx);return}
  if(st.game==='bj'){
    if(st.phase==='bet'){const el=bjEligible(st);if(now>=st.deadline||el.length&&el.every(s=>st.hand.bets[s.uid]))bjDeal(st,ctx);return}
    if(st.phase==='ins'){const h=st.hand;if(now>=st.deadline||h.players.every(p=>p.ins!==null))bjPeek(st,ctx);return}
    if(st.phase==='play'&&now>=st.deadline){const p=st.hand.players[st.hand.turn.p];if(p){p.hands[st.hand.turn.h].done=true;timeoutMark(st,p.uid)}bjAdvance(st,ctx)}
    return}
  if(st.phase==='play'){const h=st.hand,p=h.players[h.cur];if(!p)return;
    if(p.bot){if(now>=h.botAt){const c=heToCall(h,p);if(heAct(st,p.uid,botMove(st,p,ctx),ctx)&&heAct(st,p.uid,{a:c?'call':'check'},ctx))heAct(st,p.uid,{a:'fold'},ctx)}}
    else if(now>=st.deadline){timeoutMark(st,p.uid);heAct(st,p.uid,{a:heToCall(h,p)?'fold':'check'},ctx)}}
}
function timeoutMark(st,uid){const s=st.seats[seatIx(st,uid)];if(s)s.sitout++}
function cleanup(st,ctx){
  for(let i=0;i<st.seats.length;i++){const s=st.seats[i];if(!s)continue;
    if(s.leaving||!s.bot&&s.sitout>=3)standUp(st,i,ctx);
    else if(s.bot&&(s.stack<BB||st.game==='he'&&humans(st).length!==2))standUp(st,i,ctx)}
  st.phase='wait';st.hand=null;st.deadline=0}

// ---------- blackjack ----------
const bjEligible=st=>st.seats.filter(s=>s&&!s.bot&&!s.leaving&&s.stack>=1);
function bjOpen(st,ctx){if(!bjEligible(st).length)return;st.phase='bet';st.deadline=ctx.now+BET_MS;st.hand={bets:{},step:0,sideHits:[]}}
export function bjBet(st,uid,amt,side,ctx){
  if(st.phase!=='bet')return 'Wait for the next hand';const s=st.seats[seatIx(st,uid)];if(!s)return 'You are not at this table';
  amt=Math.floor(+amt);const prev=st.hand.bets[uid];if(prev){s.stack+=prev.bet+prev.side;delete st.hand.bets[uid]}
  const sb=st.side&&side?SIDE_COST:0;if(!(amt>=1))return 'Bet at least 1 shard';if(st.lim&&amt>st.lim)return 'The limit is '+st.lim;if(amt+sb>s.stack)return 'Not enough shards at the table';
  s.stack-=amt+sb;s.side=!!side;st.hand.bets[uid]={bet:amt,side:sb};st.hand.step++;return null}
function bjDeal(st,ctx){
  const h=st.hand,bets=h.bets,order=st.seats.map((s,i)=>[s,i]).filter(([s])=>s&&bets[s.uid]);
  for(const s of st.seats)if(s&&!s.bot)s.sitout=bets[s.uid]?0:s.sitout+1;   // counted once per hand, not per poll
  if(!order.length){st.phase='wait';st.hand=null;cleanupIdle(st,ctx);return}
  st.handNo++;
  const players=order.map(([s,i])=>({seat:i,uid:s.uid,name:s.name,hands:[{cards:[],bet:bets[s.uid].bet,done:false}],ins:null,side:bets[s.uid].side>0}));
  Object.assign(h,{game:'bj',no:st.handNo,shoe:shuffle(208,ctx.rng),pos:0,salt:ctx.salt(),hash:null,players,dealer:[],revealed:false,turn:{p:0,h:0},step:h.step+1});delete h.bets;
  const dealer=h.dealer;for(let r=0;r<2;r++){for(const p of players)p.hands[0].cards.push(draw(h));dealer.push(draw(h))}
  for(const p of players){const c=p.hands[0].cards;if(p.side&&rankOf(c[0])===12&&rankOf(c[1])===12)sideHit(st,p.uid,'DOUBLE ACES')}
  if(rankOf(dealer[0])===12){st.phase='ins';st.deadline=ctx.now+INS_MS;for(const p of players)if(natural(p.hands[0])||p.hands[0].bet<2||st.seats[p.seat].stack<Math.floor(p.hands[0].bet/2))p.ins=0;return}
  bjPeek(st,ctx)}
function cleanupIdle(st,ctx){for(let i=0;i<st.seats.length;i++){const s=st.seats[i];if(s&&!s.bot&&(s.sitout>=3||s.leaving))standUp(st,i,ctx)}}
const draw=h=>(h.shoe||h.deck)[h.pos++];
export function bjInsure(st,uid,yes){if(st.phase!=='ins')return 'No insurance now';const p=st.hand.players.find(p=>p.uid===uid);if(!p||p.ins!==null)return 'Already decided';
  const s=st.seats[p.seat],cost=yes?Math.floor(p.hands[0].bet/2):0;if(cost>s.stack)return 'Not enough shards';s.stack-=cost;p.ins=cost;st.hand.step++;return null}
function bjPeek(st,ctx){const h=st.hand;for(const p of h.players)if(p.ins===null)p.ins=0;
  const up=bjVal(h.dealer[0]);
  if((up===11||up===10)&&bjTotal(h.dealer).t===21){h.revealed=true;bjSettle(st,ctx);return}
  for(const p of h.players){p.insLost=p.ins;p.ins=0}   // no dealer blackjack: insurance is lost
  st.phase='play';for(const p of h.players)if(natural(p.hands[0]))p.hands[0].done=true;h.turn={p:0,h:0};h.step++;bjAdvance(st,ctx,true)}
function bjAdvance(st,ctx,fresh){const h=st.hand;
  for(let pi=fresh?0:h.turn.p;pi<h.players.length;pi++){const p=h.players[pi];
    for(let hi=pi===h.turn.p&&!fresh?h.turn.h:0;hi<p.hands.length;hi++){const hh=p.hands[hi];
      if(!hh.done&&bjTotal(hh.cards).t>=21)hh.done=true;
      if(!hh.done){h.turn={p:pi,h:hi};st.deadline=ctx.now+TURN_MS;h.step++;return}}}
  h.turn={p:-1,h:-1};bjDealer(st,ctx)}
export function bjAct(st,uid,a,ctx){
  if(st.phase!=='play')return 'Not now';const h=st.hand,p=h.players[h.turn.p];if(!p||p.uid!==uid)return 'Not your turn';
  const s=st.seats[p.seat],hh=p.hands[h.turn.h],two=hh.cards.length===2;
  if(a==='hit'){hh.cards.push(draw(h));if(bjTotal(hh.cards).t>=21)hh.done=true}
  else if(a==='stand')hh.done=true;
  else if(a==='double'){if(!two||hh.splitAces)return 'Double on your first two cards';if(s.stack<hh.bet)return 'Not enough shards to double';
    s.stack-=hh.bet;hh.bet*=2;hh.doubled=true;hh.cards.push(draw(h));hh.done=true}
  else if(a==='split'){if(!two||bjVal(hh.cards[0])!==bjVal(hh.cards[1]))return 'Split a pair';if(p.hands.length>=4)return 'Four hands at most';if(hh.splitAces)return 'Split aces get one card';
    if(s.stack<hh.bet)return 'Not enough shards to split';s.stack-=hh.bet;const aces=rankOf(hh.cards[0])===12;
    const nh={cards:[hh.cards.pop()],bet:hh.bet,done:false,split:true,splitAces:aces};hh.split=true;hh.splitAces=aces;
    hh.cards.push(draw(h));nh.cards.push(draw(h));p.hands.splice(h.turn.h+1,0,nh);if(aces){hh.done=true;nh.done=true}}
  else return 'Unknown move';
  s.sitout=0;h.step++;bjAdvance(st,ctx);return null}
function bjDealer(st,ctx){const h=st.hand;h.revealed=true;
  const live=h.players.some(p=>p.hands.some(hh=>bjTotal(hh.cards).t<=21&&!natural(hh)));
  if(live)for(;;){const t=bjTotal(h.dealer).t;if(t>=17)break;h.dealer.push(draw(h))}   // stands on all 17s, soft ones too
  bjSettle(st,ctx)}
function bjSettle(st,ctx){const h=st.hand,d=bjTotal(h.dealer).t,dbj=h.dealer.length===2&&d===21;
  for(const p of h.players){const s=st.seats[p.seat];let net=-(p.insLost||0);
    if(p.ins){if(dbj){s.stack+=p.ins*3;net+=p.ins*2}else net-=p.ins}
    for(const hh of p.hands){const t=bjTotal(hh.cards).t;let back=0,res;
      if(natural(hh)&&!dbj){back=hh.bet+Math.floor(hh.bet*3/2);res='BLACKJACK'}
      else if(dbj){back=natural(hh)?hh.bet:0;res=natural(hh)?'PUSH':'LOSE'}
      else if(t>21){res='BUST'}else if(d>21||t>d){back=hh.bet*2;res='WIN'}else if(t===d){back=hh.bet;res='PUSH'}else res='LOSE';
      if(s)s.stack+=back;hh.result=res;net+=back-hh.bet}
    if(p.side)net-=SIDE_COST;p.net=net}
  finish(st,ctx,{dealer:h.dealer,total:d,players:h.players.map(p=>({uid:p.uid,name:p.name,net:p.net,hands:p.hands.map(x=>({cards:x.cards,bet:x.bet,result:x.result}))}))})}
function finish(st,ctx,result){const h=st.hand;st.phase='done';st.deadline=ctx.now+PAUSE_MS;h.step++;h.result=result;
  st.last={no:h.no,hash:h.hash,salt:h.salt,deck:h.shoe||h.deck,result,sideHits:h.sideHits};   // the whole deck, so the hash can be checked
  ctx.hands.push({game:st.game,no:h.no,hash:h.hash,salt:h.salt,deck:h.shoe||h.deck,result,rake:h.rake||0,sideHits:h.sideHits});
  for(const x of h.sideHits)note(st,(st.seats.find(s=>s&&s.uid===x.uid)||{name:'?'}).name+' hit '+x.why+'!')}

// ---------- hold'em ----------
const heEligible=st=>st.seats.map((s,i)=>[s,i]).filter(([s])=>s&&!s.leaving&&s.stack>=BB);
function heTryDeal(st,ctx){
  const hs=humans(st).filter(s=>!s.leaving&&s.stack>=BB);
  // two people: a bot takes a third seat (while its daily budget lasts); three or more: people only; one: wait
  if(hs.length===2&&!st.seats.some(s=>s&&s.bot)&&(ctx.botLeft||0)>=BUYIN){const i=st.seats.findIndex(s=>!s);
    if(i>=0){st.seats[i]={uid:'bot:'+st.handNo,name:'SLIM (BOT)',bot:true,stack:BUYIN,brought:BUYIN,sitout:0,side:false,seen:ctx.now};ctx.botLeft-=BUYIN}}
  if(hs.length!==2){const b=st.seats.findIndex(s=>s&&s.bot);if(b>=0)standUp(st,b,ctx)}
  const el=heEligible(st);if(hs.length<2||el.length<2){cleanupIdle(st,ctx);return}
  for(const s of st.seats)if(s&&!s.bot&&s.stack<BB)s.sitout++;   // counted once per hand dealt without them
  st.handNo++;const deck=shuffle(52,ctx.rng),salt=ctx.salt();
  const seats=el.map(([,i])=>i);let b=seats.find(i=>i>st.button);if(b===undefined)b=seats[0];st.button=b;
  const order=[...seats.filter(i=>i>b),...seats.filter(i=>i<=b)];   // left of the button first; the button acts last after the flop
  const players=order.map(i=>{const s=st.seats[i];return{seat:i,uid:s.uid,name:s.name,bot:!!s.bot,cards:[],folded:false,allin:false,committed:0,bet:0,acted:false,side:false}});
  const h=st.hand={game:'he',no:st.handNo,deck,salt,hash:null,pos:0,board:[],players,street:0,cur:0,toCall:0,minRaise:BB,step:1,sideHits:[],shown:false,rake:0,botAt:0};
  for(const p of players){const s=st.seats[p.seat];if(st.side&&s.side&&s.stack>=BB+SIDE_COST){s.stack-=SIDE_COST;p.side=true}}
  for(let r=0;r<2;r++)for(const p of players)p.cards.push(draw(h));
  for(const p of players)if(p.side&&rankOf(p.cards[0])===12&&rankOf(p.cards[1])===12)sideHit(st,p.uid,'POCKET ACES');
  const n=players.length,sbI=n===2?n-1:0,bbI=n===2?0:1;   // heads-up: the button posts the small blind and acts first before the flop
  post(st,players[sbI],SB);post(st,players[bbI],BB);h.toCall=BB;h.minRaise=BB;
  st.phase='play';h.cur=(bbI+1)%n;heTurn(st,ctx,true)}
function post(st,p,amt){const s=st.seats[p.seat],x=Math.min(amt,s.stack);s.stack-=x;p.bet+=x;p.committed+=x;if(!s.stack)p.allin=true}
export const heToCall=(h,p)=>Math.max(0,h.toCall-p.bet);
const active=h=>h.players.filter(p=>!p.folded);
function heTurn(st,ctx,fresh){const h=st.hand,n=h.players.length;
  for(let k=0;k<n;k++){const i=(h.cur+k)%n,p=h.players[i];if(!p.folded&&!p.allin){h.cur=i;st.deadline=ctx.now+TURN_MS;h.botAt=ctx.now+BOT_MS;h.step++;return}}
  heStreet(st,ctx)}
// a betting round is over when everyone who can still bet has acted and matched the bet (or only one such player is left, matched)
function roundDone(h){const live=h.players.filter(p=>!p.folded&&!p.allin);
  return live.length===0||live.length===1&&live[0].bet>=h.toCall||live.every(p=>p.acted&&p.bet===h.toCall)}
function heCheckEnd(st,ctx){const h=st.hand;if(active(h).length===1){heShowdown(st,ctx);return true}return false}
function heAdvance(st,ctx){const h=st.hand;if(heCheckEnd(st,ctx))return;if(roundDone(h)){heStreet(st,ctx);return}h.cur=(h.cur+1)%h.players.length;heTurn(st,ctx,true)}
function heStreet(st,ctx){const h=st.hand;
  if(active(h).length===1){heShowdown(st,ctx);return}
  for(const p of h.players){p.bet=0;p.acted=false}h.toCall=0;h.minRaise=BB;
  if(h.street===3){heShowdown(st,ctx);return}
  h.pos++;   // burn
  if(h.street===0)h.board.push(draw(h),draw(h),draw(h));else h.board.push(draw(h));h.street++;h.step++;
  const canAct=h.players.filter(p=>!p.folded&&!p.allin).length;
  if(canAct<2){heStreet(st,ctx);return}   // everyone left is all in: run the board out
  h.cur=0;heTurn(st,ctx,true)}
export function heAct(st,uid,{a,amt},ctx){
  if(st.phase!=='play'||st.game!=='he')return 'Not now';const h=st.hand,p=h.players[h.cur];if(!p||p.uid!==uid)return 'Not your turn';
  const s=st.seats[p.seat],call=heToCall(h,p);
  if(a==='fold'){p.folded=true}
  else if(a==='check'){if(call)return 'You have to call '+call}
  else if(a==='call'){if(!call)return 'Nothing to call';const x=Math.min(call,s.stack);s.stack-=x;p.bet+=x;p.committed+=x;if(!s.stack)p.allin=true}
  else if(a==='allin'&&s.stack<=call)return heAct(st,uid,{a:'call'},ctx);   // all in for no more than the call is a call
  else if(a==='raise'||a==='allin'){
    // amt = shards put in with this action (the call included). The limit caps that; going all in for less is always allowed.
    const put=a==='allin'?s.stack:Math.floor(+amt),cap=st.lim?Math.max(st.lim,call):Infinity;
    if(!(put>call))return 'Raise more than the call';if(put>s.stack)return 'Not enough shards';if(put>cap)return 'The limit is '+st.lim+' a bet';
    const allin=put===s.stack,inc=p.bet+put-h.toCall;if(!allin&&inc<h.minRaise)return 'Raise at least '+(call+h.minRaise);
    s.stack-=put;p.bet+=put;p.committed+=put;if(!s.stack)p.allin=true;
    if(inc>0){if(inc>=h.minRaise)h.minRaise=inc;h.toCall=p.bet;for(const q of h.players)if(q!==p)q.acted=false}}
  else return 'Unknown move';
  p.acted=true;if(!p.bot&&s)s.sitout=0;h.step++;heAdvance(st,ctx);return null}
export function pots(h){
  const live=h.players.filter(p=>!p.folded),levels=[...new Set(live.map(p=>p.committed))].sort((a,b)=>a-b),out=[];let prev=0;
  for(const L of levels){let amount=0;for(const p of h.players)amount+=Math.max(0,Math.min(p.committed,L)-prev);out.push({amount,eligible:live.filter(p=>p.committed>=L)});prev=L}
  const extra=h.players.reduce((a,p)=>a+Math.max(0,p.committed-prev),0);if(extra&&out.length)out[out.length-1].amount+=extra;
  return out.filter(x=>x.amount>0)}
function heShowdown(st,ctx){const h=st.hand,live=active(h),ps=pots(h);
  // the house cut: 1.8% of a pot that saw a flop, at most 6 shards, rounded down
  const total=ps.reduce((a,x)=>a+x.amount,0);h.rake=h.board.length>=3?Math.min(RAKE_CAP,Math.floor(total*RAKE)):0;if(h.rake&&ps.length)ps[0].amount-=h.rake;
  const contest=live.length>1;h.shown=contest;
  if(contest)while(h.board.length<5){if(h.board.length===0){h.pos++;h.board.push(draw(h),draw(h),draw(h))}else{h.pos++;h.board.push(draw(h))}}
  const val=new Map(live.map(p=>[p,contest?best([...p.cards,...h.board]):0])),won=new Map();
  for(const pot of ps){const top=Math.max(...pot.eligible.map(p=>val.get(p))),ws=pot.eligible.filter(p=>val.get(p)===top),share=Math.floor(pot.amount/ws.length);let odd=pot.amount-share*ws.length;
    for(const w of ws){const x=share+(odd>0?1:0);if(odd>0)odd--;won.set(w,(won.get(w)||0)+x)}}
  for(const [p,x]of won){const s=st.seats[p.seat];if(s)s.stack+=x}
  // the side bet: pocket aces (at the deal), or a full house or better with the whole board (dealt out for the side bet if the hand ended early)
  const full=h.board.slice(),dk={pos:h.pos,deck:h.deck};while(full.length<5){if(full.length===0){dk.pos++;full.push(dk.deck[dk.pos++],dk.deck[dk.pos++],dk.deck[dk.pos++])}else{dk.pos++;full.push(dk.deck[dk.pos++])}}
  h.sideBoard=full;
  for(const p of h.players)if(p.side&&!h.sideHits.some(x=>x.uid===p.uid)&&catOf(best([...p.cards,...full]))>=6)sideHit(st,p.uid,CAT[catOf(best([...p.cards,...full]))]);
  finish(st,ctx,{board:h.board,rake:h.rake,players:h.players.map(p=>({uid:p.uid,name:p.name,cards:contest&&!p.folded?p.cards:null,folded:p.folded,put:p.committed,won:won.get(p)||0,
    hand:contest&&!p.folded?CAT[catOf(val.get(p))]:null}))})}

// ---------- the bot: a solid, honest player (it never sees anyone's cards) ----------
function equity(cards,board,opp,rng,n=160){
  const used=new Set([...cards,...board]),rest=[];for(let c=0;c<52;c++)if(!used.has(c))rest.push(c);let win=0;
  for(let k=0;k<n;k++){const d=rest.slice();for(let i=0;i<opp*2+(5-board.length);i++){const j=i+rng(d.length-i),t=d[i];d[i]=d[j];d[j]=t}
    const b=board.concat(d.slice(opp*2,opp*2+5-board.length)),me=best([...cards,...b]);let res=1;
    for(let o=0;o<opp;o++){const v=best([d[o*2],d[o*2+1],...b]);if(v>me){res=0;break}if(v===me)res=Math.min(res,.5)}win+=res}
  return win/n}
export function botMove(st,p,ctx){const h=st.hand,s=st.seats[p.seat],call=heToCall(h,p),pot=h.players.reduce((a,q)=>a+q.committed,0),opp=active(h).length-1;
  const e=equity(p.cards,h.board,Math.max(1,opp),ctx.rng),r=ctx.rng(100)/100,odds=call/(pot+call||1);
  const raiseTo=f=>{let put=call+Math.max(h.minRaise,Math.round(pot*f));if(st.lim)put=Math.min(put,Math.max(st.lim,call));if(put>=s.stack)return{a:'allin'};if(put<=call)return call?{a:'call'}:{a:'check'};return{a:'raise',amt:put}};
  if(!call){if(e>.62&&r<.8||r<.07)return raiseTo(.6);return{a:'check'}}
  if(e<odds-.04&&!(r<.05))return{a:'fold'};
  if(e>.72&&r<.7)return raiseTo(.75);
  if(call>=s.stack&&e<.5)return{a:'fold'};
  return{a:'call'}}

// ---------- what one player may see ----------
export function view(st,uid,now){
  const h=st.hand,me=seatIx(st,uid),v={game:st.game,lim:st.lim,side:st.side,host:st.host===uid,hostName:(st.seats.find(s=>s&&s.uid===st.host)||{}).name||'',phase:st.phase,
    left:Math.max(0,st.deadline-now),handNo:st.handNo,me,picks:st.picks[uid]|0,log:st.log.slice(-5),
    seats:st.seats.map((s,i)=>s&&{i,name:s.name,stack:s.stack,bot:!!s.bot,me:i===me,side:!!s.side,leaving:!!s.leaving}),
    last:st.last&&{no:st.last.no,hash:st.last.hash,salt:st.last.salt,deck:st.last.deck,result:st.last.result,sideHits:st.last.sideHits},fair:h&&h.hash||null};
  if(!h)return v;
  if(st.game==='bj'){
    if(st.phase==='bet'){v.bets=Object.fromEntries(Object.entries(h.bets).map(([u,b])=>[seatIx(st,u),b.bet]));return v}
    v.dealer=h.revealed||st.phase==='done'?h.dealer:[h.dealer[0],null];v.dealerTotal=h.revealed?bjTotal(h.dealer).t:bjTotal([h.dealer[0]]).t;
    v.players=h.players.map(p=>({seat:p.seat,name:p.name,ins:p.ins,side:p.side,hands:p.hands.map(x=>({cards:x.cards,bet:x.bet,total:bjTotal(x.cards).t,soft:bjTotal(x.cards).soft,done:x.done,result:x.result||null}))}));
    v.turn=h.turn;const tp=h.players[h.turn.p];v.myTurn=st.phase==='play'&&tp&&tp.uid===uid;
    if(v.myTurn){const x=tp.hands[h.turn.h],s=st.seats[tp.seat];v.can={hit:true,stand:true,double:x.cards.length===2&&!x.splitAces&&s.stack>=x.bet,
      split:x.cards.length===2&&bjVal(x.cards[0])===bjVal(x.cards[1])&&tp.hands.length<4&&!x.splitAces&&s.stack>=x.bet}}
    v.insure=st.phase==='ins'&&h.players.some(p=>p.uid===uid&&p.ins===null);return v}
  const done=st.phase==='done';
  v.board=h.board;v.pot=h.players.reduce((a,p)=>a+p.committed,0);v.toCall=h.toCall;v.street=h.street;
  v.players=h.players.map((p,i)=>({seat:p.seat,name:p.name,bot:p.bot,folded:p.folded,allin:p.allin,bet:p.bet,put:p.committed,turn:i===h.cur&&st.phase==='play',side:p.side,
    cards:p.uid===uid||done&&h.shown&&!p.folded?p.cards:[null,null]}));
  const mp=h.players.find(p=>p.uid===uid);v.myTurn=st.phase==='play'&&mp&&h.players[h.cur]===mp;
  if(v.myTurn){const s=st.seats[mp.seat],call=heToCall(h,mp),minPut=Math.min(s.stack,call+h.minRaise),maxPut=st.lim?Math.min(s.stack,Math.max(st.lim,call)):s.stack;
    v.can={call,check:!call,minPut,maxPut,raise:s.stack>call&&maxPut>call&&(maxPut>=minPut),stack:s.stack,allin:!st.lim||s.stack<=Math.max(st.lim,call)}}
  if(done&&h.sideBoard)v.sideBoard=h.sideBoard;return v}
