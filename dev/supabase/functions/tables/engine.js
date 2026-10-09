// v0.9.8 THE TABLES: the rules, run only on the server (the `tables` edge function). Blackjack from a 4-deck shoe that is
// reshuffled before every hand (so counting cards is worthless); Texas Hold'em from one 52-card deck. Straight shards:
// a seat's stack is shards brought to the table; the limit caps a single bet. No I/O here: the caller passes the time,
// a cryptographic rng(n) -> 0..n-1, and collects `ctx.ops` (shard and case moves for the ledger) and `ctx.hands` (the log).
// v0.9.8.1: no clock during a hand (nobody is auto-folded or auto-stood); 60 s between hands (Blackjack: the betting window,
// dealt as soon as everyone has bet; Hold'em: a break, dealt as soon as everyone taps READY). The host starts the table.
// v0.10.0: Roulette (American, 0 and 00, always no limit); every deal and spin comes from the server's seed (committed by its
// SHA-256 before anyone's seed locks) mixed with every seated player's own seed, so not even the server can pick a result;
// Hold'em also commits to each card on its own, so a hand can be checked without showing what folded players held.
// v0.10.3: every round ends in a review the server holds: nobody (readiness included) moves past it before the minimum,
// measured from the moment the last card turns, the dice stop or the ball lands (revealAt), not from the deal. Baccarat,
// craps, slots and Plinko (games.js) run through the same clock, ledger and receipts.
export const BUYIN=5,BET_MS=60000,NEXT_MS=60000,PAUSE_MS=0,BOT_MS=1300,AWAY_MS=60000,
  RAKE=.018,RAKE_CAP=6,SIDE_COST=1,SB=1,BB=2,SEATS={bj:5,he:6,rl:6,ba:6,cr:6,sl:1,pk:1},LIMITS=[100,250,0],SPIN_MS=6000,RL_SHOW_MS=6000,FV=2,
  CARD_MS=700,REVIEW={bj:8000,he:8000,ba:8000,rl:6000,cr:6000,sl:3000,pk:3000},
  RV={bj:'bj-2',he:'he-2',rl:'rl-2',ba:'ba-1',cr:'cr-1',sl:'sl-1',pk:'pk-1'};
export const PRIZES={hybrid:10,flags:15};   // the side bet: 10 Hybrid Theory Cases or 15 Flag Cases, the winner picks
import * as X from './games.js';   // v0.10.3: baccarat, craps, slots, Plinko
const XG=g=>X.GAMES[g]||null;

// ---------- cards ----------
// a card is 0..51 (in a shoe, any int: c%52): rank c%13 (0 = 2 … 8 = 10, 9 J, 10 Q, 11 K, 12 A), suit ((c%52)/13)|0
export const rankOf=c=>c%52%13,suitOf=c=>((c%52)/13)|0;
export function shuffle(n,rng){const d=Array.from({length:n},(_,i)=>i);for(let i=n-1;i>0;i--){const j=rng(i+1),t=d[i];d[i]=d[j];d[j]=t}return d}

// ---------- fair play (v0.10.0) ----------
// SHA-256 written out (synchronous, the same in Deno, Node and the browser's check; tested against Web Crypto)
const K256=new Int32Array([0x428a2f98,0x71374491,0xb5c0fbcf,0xe9b5dba5,0x3956c25b,0x59f111f1,0x923f82a4,0xab1c5ed5,0xd807aa98,0x12835b01,0x243185be,0x550c7dc3,0x72be5d74,0x80deb1fe,0x9bdc06a7,0xc19bf174,
  0xe49b69c1,0xefbe4786,0x0fc19dc6,0x240ca1cc,0x2de92c6f,0x4a7484aa,0x5cb0a9dc,0x76f988da,0x983e5152,0xa831c66d,0xb00327c8,0xbf597fc7,0xc6e00bf3,0xd5a79147,0x06ca6351,0x14292967,
  0x27b70a85,0x2e1b2138,0x4d2c6dfc,0x53380d13,0x650a7354,0x766a0abb,0x81c2c92e,0x92722c85,0xa2bfe8a1,0xa81a664b,0xc24b8b70,0xc76c51a3,0xd192e819,0xd6990624,0xf40e3585,0x106aa070,
  0x19a4c116,0x1e376c08,0x2748774c,0x34b0bcb5,0x391c0cb3,0x4ed8aa4a,0x5b9cca4f,0x682e6ff3,0x748f82ee,0x78a5636f,0x84c87814,0x8cc70208,0x90befffa,0xa4506ceb,0xbef9a3f7,0xc67178f2]);
const SW=new Uint32Array(64),SBUF=new Uint8Array(4096);
export function sha256hex(str){
  str=String(str);let l=0,m=SBUF;
  if(/^[\x00-\x7f]*$/.test(str)&&str.length<=4000){for(let i=0;i<str.length;i++)SBUF[i]=str.charCodeAt(i);l=str.length}else{m=new TextEncoder().encode(str);l=m.length}   // ASCII fast path (seeds, numbers)
  const nb=((l+9+63)>>6)<<6,b=new Uint8Array(nb);b.set(m.subarray(0,l));b[l]=0x80;
  const bits=l*8;for(let i=0;i<8;i++)b[nb-1-i]=i<4?(bits>>>(8*i))&255:Math.floor(bits/2**(8*i))&255;
  let h0=0x6a09e667,h1=0xbb67ae85,h2=0x3c6ef372,h3=0xa54ff53a,h4=0x510e527f,h5=0x9b05688c,h6=0x1f83d9ab,h7=0x5be0cd19;const w=SW;
  for(let o=0;o<nb;o+=64){for(let i=0;i<16;i++)w[i]=(b[o+4*i]<<24)|(b[o+4*i+1]<<16)|(b[o+4*i+2]<<8)|b[o+4*i+3];
    for(let i=16;i<64;i++){const x=w[i-15],y=w[i-2];w[i]=(w[i-16]+(((x>>>7)|(x<<25))^((x>>>18)|(x<<14))^(x>>>3))+w[i-7]+(((y>>>17)|(y<<15))^((y>>>19)|(y<<13))^(y>>>10)))|0}
    let a=h0,c=h1,d=h2,e=h3,f=h4,g=h5,h=h6,k=h7;
    for(let i=0;i<64;i++){const t1=(k+(((f>>>6)|(f<<26))^((f>>>11)|(f<<21))^((f>>>25)|(f<<7)))+((f&g)^(~f&h))+K256[i]+w[i])|0,
      t2=((((a>>>2)|(a<<30))^((a>>>13)|(a<<19))^((a>>>22)|(a<<10)))+((a&c)^(a&d)^(c&d)))|0;k=h;h=g;g=f;f=(e+t1)|0;e=d;d=c;c=a;a=(t1+t2)|0}
    h0=(h0+a)|0;h1=(h1+c)|0;h2=(h2+d)|0;h3=(h3+e)|0;h4=(h4+f)|0;h5=(h5+g)|0;h6=(h6+h)|0;h7=(h7+k)|0}
  let out='';for(const x of [h0,h1,h2,h3,h4,h5,h6,h7])out+=(x>>>0).toString(16).padStart(8,'0');return out}
// the round's random numbers. key = the first 48 hex digits of SHA-256("server seed:players' seeds joined by |:round");
// then SHA-256("key:0"), SHA-256("key:1"), … read 32 bits at a time, with rejection sampling so every outcome is exactly as
// likely (no modulo bias). Anyone with the revealed seed can rerun it (the in-game check does exactly this).
export function fairRng(seed,seeds,nonce){let ctr=0,buf=[],pos=0;const key=sha256hex(seed+':'+seeds.join('|')+':'+nonce).slice(0,48)+':';
  const next=()=>{if(pos>=buf.length){const hx=sha256hex(key+(ctr++));buf=[];for(let i=0;i<64;i+=8)buf.push(parseInt(hx.slice(i,i+8),16));pos=0}return buf[pos++]};
  return n=>{if(n<=1)return 0;const lim=Math.floor(4294967296/n)*n;for(;;){const x=next();if(x<lim)return x%n}}}
export const cleanSeed=x=>String(x||'').replace(/[^0-9A-Za-z_-]/g,'').slice(0,64);
export const mkNext=ctx=>{const seed=ctx.seed?ctx.seed():(ctx.salt()+ctx.salt());return{seed,hash:sha256hex(seed)}};   // next round's server seed and its public fingerprint
// take the committed seed for this round (and commit to the next one right away)
export function lockFair(st,ctx,seeds){if(!st.next)st.next=mkNext(ctx);const f={seed:st.next.seed,commit:st.next.hash,seeds,nonce:(st.tid||'t')+':'+st.handNo};st.next=mkNext(ctx);return f}
// Hold'em: each deck position has its own fingerprint; the hand's fingerprint (root) is built from all 52
export const cardSalt=(seed,i)=>sha256hex(seed+':card:'+i).slice(0,32);
export const cardHash=(salt,c)=>sha256hex(salt+':'+c);
export function cardHashes(seed,deck){return deck.map((c,i)=>cardHash(cardSalt(seed,i),c))}
export const rootOf=hs=>sha256hex(hs.join(','));

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
export function newTable({game,lim,side,host,tid,room,station}){const rl=game==='rl',x=XG(game);
  const st={game,lim:rl||x?0:LIMITS.includes(lim)?lim:100,side:rl||x?false:!!side,host,seats:Array(SEATS[game]).fill(null),phase:'wait',deadline:0,handNo:0,button:-1,
    hand:null,last:null,picks:{},log:[],started:rl||!!x,ready:{},fv:FV,tid:tid||'t',room:room||null,station:station||'',next:null,hist:[],minAt:0};   // roulette and the v0.10.3 games have no settings and no host start
  if(x&&x.init)x.init(st);return st}
const humans=st=>st.seats.filter(s=>s&&!s.bot);
export const humansAt=st=>st.seats.filter(s=>s&&!s.bot);
export const seatIx=(st,uid)=>st.seats.findIndex(s=>s&&s.uid===uid);
export const note=(st,t)=>{st.log.push(t);if(st.log.length>8)st.log.shift()};
export function sit(st,{uid,name,seed,seat},ctx){
  if(seatIx(st,uid)>=0)return 'You are already at this table';
  const want=Number.isInteger(seat)&&seat>=0&&seat<st.seats.length&&!st.seats[seat]?seat:-1,i=want>=0?want:st.seats.findIndex(s=>!s);   // the seat you walked up to, if it's free
  if(i<0)return 'The table is full';
  st.seats[i]={uid,name,stack:BUYIN,brought:BUYIN,sitout:0,side:false,seen:ctx.now,seed:cleanSeed(seed)||ctx.salt()};ctx.ops.push({uid,k:'buyin',d:-BUYIN});note(st,name+' sat down');return null}
// v0.10.3: back to a seat you left while bets were still working (craps): you're playing again
export function rejoin(st,uid,ctx){const s=st.seats[seatIx(st,uid)];if(s&&(s.gone||s.leaving)&&!inHandLocked(st,uid)){s.gone=false;s.leaving=false;s.seen=ctx.now;note(st,s.name+' is back')}return null}
const inHandLocked=(st,uid)=>!XG(st.game)&&inHand(st,uid);   // a blackjack or hold'em hand you're leaving still has to finish
// your own seed: mixed into every deal or spin from the next one on (the server has already committed to its seed)
export function setSeed(st,uid,seed){const s=st.seats[seatIx(st,uid)];if(!s)return 'You are not at this table';const v=cleanSeed(seed);if(!v)return 'Pick a seed (letters and numbers)';s.seed=v;return null}
export function topup(st,uid,amt,ctx){
  const s=st.seats[seatIx(st,uid)];if(!s)return 'You are not at this table';amt=Math.floor(+amt);if(!(amt>=1&&amt<=100000))return 'Pick an amount';
  if(s.gone)return 'You have left this table';if(!XG(st.game)&&inHand(st,uid))return 'Top up between hands';   // v0.10.3: craps tops up while bets work
  s.stack+=amt;s.brought+=amt;ctx.ops.push({uid,k:'topup',d:-amt});return null}
export function inHand(st,uid){const x=XG(st.game);if(x)return x.inHand(st,uid);const h=st.hand;if(!h||st.phase==='wait'||st.phase==='done'||st.phase==='bet')return false;if(st.game==='rl')return !!(h.bets[uid]);return h.players.some(p=>p.uid===uid)}
export function standUp(st,i,ctx){const s=st.seats[i];if(!s)return;
  while(st.picks[s.uid]>0)pick(st,s.uid,'hybrid',ctx);   // an unpicked side-bet prize is never lost: Hybrid Theory by default
  if(s.bot){if(s.walletBot)ctx.ops.push({k:'bot_cashout',d:s.stack});ctx.ops.push({k:'bot',d:s.stack-s.brought})}else{if(s.stack>0)ctx.ops.push({uid:s.uid,k:'cashout',d:s.stack});note(st,s.name+' stood up')}
  st.seats[i]=null;if(st.host===s.uid){const h=humans(st)[0];st.host=h?h.uid:null}}
// the last person has left: the bot stands up too, so its result reaches the ledger before the table closes (v0.10.0)
export function closeOut(st,ctx){for(let i=0;i<st.seats.length;i++)if(st.seats[i]&&st.seats[i].bot)standUp(st,i,ctx)}
export function leave(st,uid,ctx){
  const i=seatIx(st,uid);if(i<0)return 'You are not at this table';const s=st.seats[i];const x=XG(st.game);if(x)return x.leave(st,uid,ctx);
  if(inHand(st,uid)){s.leaving=true;if(st.game==='rl')return null;   // roulette: the spin settles, then cleanup stands you up
    const h=st.hand,p=h.players.find(p=>p.uid===uid);
    if(st.game==='he'){if(!p.folded){p.folded=true;p.acted=true;if(h.players[h.cur]===p)heAdvance(st,ctx);else heCheckEnd(st,ctx)}}
    else{for(const hh of p.hands)hh.done=true;if(st.phase==='ins')p.ins=0;if(st.phase==='play')bjAdvance(st,ctx)}
    return null}
  if(st.phase==='bet'&&st.hand&&st.hand.bets[uid]){if(st.game==='rl')s.stack+=rlTotal(st.hand.bets[uid]);else s.stack+=st.hand.bets[uid].bet+st.hand.bets[uid].side;delete st.hand.bets[uid]}
  standUp(st,i,ctx);return null}
// the host deals the first hand (Blackjack: anyone seated; Hold'em: at least two people). After that it runs by itself.
export function start(st,uid){if(st.host!==uid)return 'Only the host can start the table';if(st.started)return null;
  const n=humans(st).length;if(st.game==='he'&&n<2)return 'Hold\'em needs at least 2 players';if(!n)return 'Nobody is seated';st.started=true;note(st,'The host started the table');return null}
export function ready(st,uid){if(seatIx(st,uid)<0)return 'You are not at this table';if(st.phase!=='done')return null;st.ready=st.ready||{};st.ready[uid]=true;return null}
export function settings(st,uid,{lim,side}){if(st.host!==uid)return 'Only the host can change the table';if(st.started)return 'Settings lock once the host starts the table';
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
  for(let i=0;i<st.seats.length;i++){const s=st.seats[i];if(s&&!s.bot&&now-s.seen>AWAY_MS&&!s.leaving&&!s.gone){if(inHand(st,s.uid)||XG(st.game))leave(st,s.uid,ctx);else standUp(st,i,ctx)}}
  if(!st.next)st.next=mkNext(ctx);   // the next round's server seed is committed (fingerprint shown) before anyone's seed locks
  if(st.started===false)return;   // waiting for the host (tables opened before v0.9.8.1 have no flag and keep running)
  if(XG(st.game)){XG(st.game).step(st,ctx);return}
  if(st.game==='rl'){rlStep(st,ctx);return}
  if(st.phase==='wait'){if(st.game==='bj')bjOpen(st,ctx);else heTryDeal(st,ctx);return}
  // the review: nothing moves on before minAt (the reveal + the game's reading time); then Hold'em's break (READY deals sooner)
  if(st.phase==='done'){if(now<(st.minAt||0))return;const hs=humans(st).filter(s=>!s.leaving&&s.stack>=BB);if(now>=st.deadline||hs.length&&hs.every(s=>(st.ready||{})[s.uid]))cleanup(st,ctx);return}   // busted players can't be dealt in, so nobody waits on them
  if(st.game==='bj'){
    if(st.phase==='bet'){const el=bjEligible(st);if(now>=st.deadline||el.length&&el.every(s=>st.hand.bets[s.uid]))bjDeal(st,ctx);return}
    if(st.phase==='ins'){const h=st.hand;if(h.players.every(p=>p.ins!==null))bjPeek(st,ctx);return}
    return}
  if(st.phase==='play'){const h=st.hand,p=h.players[h.cur];if(!p)return;
    if(p.bot&&now>=h.botAt){const c=heToCall(h,p);if(heAct(st,p.uid,botMove(st,p,ctx),ctx)&&heAct(st,p.uid,{a:c?'call':'check'},ctx))heAct(st,p.uid,{a:'fold'},ctx)}}
}
export function cleanup(st,ctx){
  for(let i=0;i<st.seats.length;i++){const s=st.seats[i];if(!s)continue;
    if(s.leaving||!s.bot&&s.sitout>=3)standUp(st,i,ctx);
    else if(s.bot&&(s.stack<BB||st.game==='he'&&humans(st).length!==2))standUp(st,i,ctx)}
  st.phase='wait';st.hand=null;st.deadline=0;st.ready={}}

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
  const f=lockFair(st,ctx,players.map(p=>st.seats[p.seat].seed||''));
  Object.assign(h,{game:'bj',no:st.handNo,shoe:shuffle(208,fairRng(f.seed,f.seeds,f.nonce)),pos:0,salt:f.seed,hash:f.commit,fair:f,players,dealer:[],revealed:false,turn:{p:0,h:0},step:h.step+1});delete h.bets;
  const dealer=h.dealer;for(let r=0;r<2;r++){for(const p of players)p.hands[0].cards.push(draw(h));dealer.push(draw(h))}
  for(const p of players){const c=p.hands[0].cards;if(p.side&&rankOf(c[0])===12&&rankOf(c[1])===12)sideHit(st,p.uid,'DOUBLE ACES')}
  if(rankOf(dealer[0])===12){st.phase='ins';st.deadline=0;for(const p of players)if(natural(p.hands[0])||p.hands[0].bet<2||st.seats[p.seat].stack<Math.floor(p.hands[0].bet/2))p.ins=0;return}
  bjPeek(st,ctx)}
function cleanupIdle(st,ctx){for(let i=0;i<st.seats.length;i++){const s=st.seats[i];if(s&&!s.bot&&(s.sitout>=3||s.leaving))standUp(st,i,ctx)}}
const draw=h=>(h.shoe||h.deck)[h.pos++];
export function bjInsure(st,uid,yes){if(st.phase!=='ins')return 'No insurance now';const p=st.hand.players.find(p=>p.uid===uid);if(!p||p.ins!==null)return 'Already decided';
  const s=st.seats[p.seat],cost=yes?Math.floor(p.hands[0].bet/2):0;if(cost>s.stack)return 'Not enough shards';s.stack-=cost;p.ins=cost;st.hand.step++;return null}
function bjPeek(st,ctx){const h=st.hand;for(const p of h.players)if(p.ins===null)p.ins=0;
  const up=bjVal(h.dealer[0]);
  if((up===11||up===10)&&bjTotal(h.dealer).t===21){h.revealed=true;h.anim=CARD_MS;bjSettle(st,ctx);return}
  for(const p of h.players){p.insLost=p.ins;p.ins=0}   // no dealer blackjack: insurance is lost
  st.phase='play';for(const p of h.players)if(natural(p.hands[0]))p.hands[0].done=true;h.turn={p:0,h:0};h.step++;bjAdvance(st,ctx,true)}
function bjAdvance(st,ctx,fresh){const h=st.hand;
  for(let pi=fresh?0:h.turn.p;pi<h.players.length;pi++){const p=h.players[pi];
    for(let hi=pi===h.turn.p&&!fresh?h.turn.h:0;hi<p.hands.length;hi++){const hh=p.hands[hi];
      if(!hh.done&&bjTotal(hh.cards).t>=21)hh.done=true;
      if(!hh.done){h.turn={p:pi,h:hi};st.deadline=0;h.step++;return}}}
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
  h.anim=(h.dealer.length-1)*CARD_MS;   // the hole card turns, then each card the dealer draws: the result counts from the last one
  bjSettle(st,ctx)}
function bjSettle(st,ctx){const h=st.hand,dt=bjTotal(h.dealer),d=dt.t,dbj=h.dealer.length===2&&d===21;
  for(const p of h.players){const s=st.seats[p.seat];let net=-(p.insLost||0),bet=0,back=0;const items=[];
    const insCost=p.ins||p.insLost||0;if(insCost){bet+=insCost;const ib=p.ins&&dbj?p.ins*3:0;if(ib&&s)s.stack+=ib;back+=ib;items.push({k:'ins',bet:insCost,back:ib});if(p.ins){net+=dbj?p.ins*2:-p.ins}}
    for(const hh of p.hands){const ct=bjTotal(hh.cards),t=ct.t;let hb=0,res;
      if(natural(hh)&&!dbj){hb=hh.bet+Math.floor(hh.bet*3/2);res='BLACKJACK'}
      else if(dbj){hb=natural(hh)?hh.bet:0;res=natural(hh)?'PUSH':'LOSE'}
      else if(t>21){res='BUST'}else if(d>21||t>d){hb=hh.bet*2;res='WIN'}else if(t===d){hb=hh.bet;res='PUSH'}else res='LOSE';
      if(s)s.stack+=hb;hh.result=res;net+=hb-hh.bet;bet+=hh.bet;back+=hb;
      // the plain reason: what beat you, or what you beat
      hh.why=res==='BUST'?`You busted at ${t}`:res==='BLACKJACK'?'Blackjack pays 3:2':dbj?(res==='PUSH'?'Your blackjack ties the dealer\'s':'The dealer has blackjack')
        :d>21?`The dealer busted at ${d}`:res==='WIN'?`Your ${t} beat the dealer's ${d}`:res==='PUSH'?`Your ${t} ties the dealer's ${d}`:`Your ${t} lost to the dealer's ${d}`;
      hh.soft=ct.soft&&t<=21}
    if(p.side){net-=SIDE_COST;bet+=SIDE_COST;items.push({k:'side',bet:SIDE_COST,back:0})}
    p.net=net;p.bet=bet;p.back=back;p.items=items}
  finish(st,ctx,{house:-h.players.reduce((a,p)=>a+p.net,0),dealer:h.dealer,total:d,soft:dt.soft&&d<=21,dbj,players:h.players.map(p=>({uid:p.uid,name:p.name,seat:p.seat,net:p.net,bet:p.bet,back:p.back,items:p.items,
    hands:p.hands.map(x=>({cards:x.cards,bet:x.bet,result:x.result,total:bjTotal(x.cards).t,soft:x.soft,why:x.why,doubled:!!x.doubled,split:!!x.split}))}))},h.anim||0)}
// anim: how long the reveal takes on screen (cards turning, the dice, the reels); the review counts from its end
export function finish(st,ctx,result,anim){const h=st.hand,rev=ctx.now+(anim|0),minAt=rev+(REVIEW[st.game]||0);st.phase='done';st.minAt=minAt;
  st.deadline=st.game==='he'?Math.max(minAt,ctx.now+NEXT_MS):minAt;st.ready={};h.step++;h.result=result;h.revealAt=rev;
  Object.assign(result,{rv:RV[st.game]||st.game,rid:(st.tid||'t')+':'+h.no,at:{settled:ctx.now,reveal:rev,until:minAt}});
  for(const p of result.players||[]){if(p.bet===undefined&&p.put!==undefined)p.bet=p.put;if(p.back===undefined&&p.won!==undefined)p.back=p.won;if(p.net===undefined&&p.bet!==undefined)p.net=(p.back||0)-p.bet}
  const deck=st.game==='rl'?[h.number]:h.logDeck||h.shoe||h.deck;if(h.fair)Object.assign(result,{seeds:h.fair.seeds,nonce:h.fair.nonce,commit:h.fair.commit},h.root?{root:h.root}:{});
  // st.last stays on the server; view() decides what each player gets (Hold'em: never the seed or the deck)
  st.last={no:h.no,hash:h.hash,salt:h.salt,deck,result,sideHits:h.sideHits,cards:h.shown||null,fair:h.fair||null,root:h.root||null,cardHashes:h.cardHashes||null,pos:h.posOf||null,shownSeats:h.shownSeats||null,
    holes:st.game==='he'&&h.players?h.players.map(p=>({uid:p.uid,seat:p.seat,pos:p.pos||[]})):null};
  ctx.hands.push({game:st.game,no:h.no,hash:h.hash,salt:h.logSalt!==undefined?h.logSalt:h.salt,deck,result,rake:h.rake||0,sideHits:h.sideHits});
  for(const x of h.sideHits)note(st,(st.seats.find(s=>s&&s.uid===x.uid)||{name:'?'}).name+' hit '+x.why+'!')}

// ---------- hold'em ----------
const drawB=h=>{if(h.posOf)h.posOf.board.push(h.pos);return draw(h)};   // a board card, its deck position remembered for the per-card check
const heEligible=st=>st.seats.map((s,i)=>[s,i]).filter(([s])=>s&&!s.leaving&&s.stack>=BB);
function heTryDeal(st,ctx){
  const hs=humans(st).filter(s=>!s.leaving&&s.stack>=BB);
  // Two people: SLIM brings his entire available wallet. The database reserves it atomically for one table.
  // An old, already-seated bot finishes normally; its old allowance is never deposited into the new wallet.
  const balance=ctx.botLeft||0;
  if(hs.length===2&&!st.seats.some(s=>s&&s.bot)&&Number.isSafeInteger(balance)&&balance>=BB){const i=st.seats.findIndex(s=>!s);
    if(i>=0){st.seats[i]={uid:'bot:'+st.handNo,name:'SLIM (BOT)',bot:true,walletBot:true,stack:balance,brought:balance,sitout:0,side:false,seen:ctx.now};ctx.ops.push({k:'bot_buyin',d:-balance});ctx.botLeft=0}}
  if(hs.length!==2){const b=st.seats.findIndex(s=>s&&s.bot);if(b>=0)standUp(st,b,ctx)}
  const el=heEligible(st);if(hs.length<2||el.length<2){cleanupIdle(st,ctx);return}
  for(const s of st.seats)if(s&&!s.bot&&s.stack<BB)s.sitout++;   // counted once per hand dealt without them
  st.handNo++;
  const seats=el.map(([,i])=>i);let b=seats.find(i=>i>st.button);if(b===undefined)b=seats[0];st.button=b;
  const order=[...seats.filter(i=>i>b),...seats.filter(i=>i<=b)];   // left of the button first; the button acts last after the flop
  const players=order.map(i=>{const s=st.seats[i];return{seat:i,uid:s.uid,name:s.name,bot:!!s.bot,cards:[],pos:[],folded:false,allin:false,committed:0,bet:0,acted:false,side:false}});
  const f=lockFair(st,ctx,players.map(p=>st.seats[p.seat].seed||'')),deck=shuffle(52,fairRng(f.seed,f.seeds,f.nonce)),chs=cardHashes(f.seed,deck);
  const h=st.hand={game:'he',no:st.handNo,deck,salt:f.seed,hash:f.commit,fair:f,cardHashes:chs,root:rootOf(chs),posOf:{board:[],side:[]},pos:0,board:[],players,street:0,cur:0,toCall:0,minRaise:BB,step:1,sideHits:[],shown:false,rake:0,botAt:0};
  for(const p of players){const s=st.seats[p.seat];if(st.side&&s.side&&s.stack>=BB+SIDE_COST){s.stack-=SIDE_COST;p.side=true}}
  for(let r=0;r<2;r++)for(const p of players){p.pos.push(h.pos);p.cards.push(draw(h))}
  for(const p of players)if(p.side&&rankOf(p.cards[0])===12&&rankOf(p.cards[1])===12)sideHit(st,p.uid,'POCKET ACES');
  const n=players.length,sbI=n===2?n-1:0,bbI=n===2?0:1;   // heads-up: the button posts the small blind and acts first before the flop
  post(st,players[sbI],SB);post(st,players[bbI],BB);h.toCall=BB;h.minRaise=BB;
  st.phase='play';h.cur=(bbI+1)%n;heTurn(st,ctx,true)}
function post(st,p,amt){const s=st.seats[p.seat],x=Math.min(amt,s.stack);s.stack-=x;p.bet+=x;p.committed+=x;if(!s.stack)p.allin=true}
export const heToCall=(h,p)=>Math.max(0,h.toCall-p.bet);
const active=h=>h.players.filter(p=>!p.folded);
function heTurn(st,ctx,fresh){const h=st.hand,n=h.players.length;
  for(let k=0;k<n;k++){const i=(h.cur+k)%n,p=h.players[i];if(!p.folded&&!p.allin){h.cur=i;st.deadline=0;h.botAt=ctx.now+BOT_MS;h.step++;return}}
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
  if(h.street===0)h.board.push(drawB(h),drawB(h),drawB(h));else h.board.push(drawB(h));h.street++;h.step++;
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
  const b0=h.board.length;if(contest)while(h.board.length<5){if(h.board.length===0){h.pos++;h.board.push(drawB(h),drawB(h),drawB(h))}else{h.pos++;h.board.push(drawB(h))}}
  const val=new Map(live.map(p=>[p,contest?best([...p.cards,...h.board]):0])),won=new Map();
  for(const pot of ps){const top=Math.max(...pot.eligible.map(p=>val.get(p))),ws=pot.eligible.filter(p=>val.get(p)===top),share=Math.floor(pot.amount/ws.length);let odd=pot.amount-share*ws.length;
    for(const w of ws){const x=share+(odd>0?1:0);if(odd>0)odd--;won.set(w,(won.get(w)||0)+x)}}
  for(const [p,x]of won){const s=st.seats[p.seat];if(s)s.stack+=x}
  // the side bet: pocket aces (at the deal), or a full house or better with the whole board (dealt out for the side bet if the hand ended early)
  const full=h.board.slice(),dk={pos:h.pos,deck:h.deck},sp=h.posOf?h.posOf.side:[],dd=()=>{sp.push(dk.pos);return dk.deck[dk.pos++]};while(full.length<5){if(full.length===0){dk.pos++;full.push(dd(),dd(),dd())}else{dk.pos++;full.push(dd())}}
  h.sideBoard=full;
  for(const p of h.players)if(p.side&&!h.sideHits.some(x=>x.uid===p.uid)&&catOf(best([...p.cards,...full]))>=6)sideHit(st,p.uid,CAT[catOf(best([...p.cards,...full]))]);
  h.shownSeats=contest?live.map(p=>p.seat):[];
  // what won each pot: the five cards, the hand's name, who shared it (an uncontested pot says so: nobody's cards are shown)
  const best5=p=>{let m=-1,b=null;const cs=[...p.cards,...h.board];for(const ix of C7){const v=eval5(ix.map(i=>cs[i]));if(v>m){m=v;b=ix.map(i=>cs[i])}}return b};
  const potLog=ps.map((pot,k)=>{const top=contest?Math.max(...pot.eligible.map(p=>val.get(p))):0,ws=pot.eligible.filter(p=>!contest||val.get(p)===top);
    return{k,amount:pot.amount,winners:ws.map(w=>w.seat),hand:contest?CAT[catOf(top)]:null,five:contest&&ws[0]?best5(ws[0]):null}});
  const anim=(h.board.length-b0)*CARD_MS+(contest?CARD_MS:0);
  finish(st,ctx,{house:h.rake+h.players.filter(p=>p.side).length*SIDE_COST,board:h.board,rake:h.rake,contest,pots:potLog,uncontested:!contest,players:h.players.map(p=>({uid:p.uid,name:p.name,seat:p.seat,cards:contest&&!p.folded?p.cards:null,folded:p.folded,put:p.committed,won:won.get(p)||0,
    bet:p.committed+(p.side?SIDE_COST:0),back:won.get(p)||0,net:(won.get(p)||0)-p.committed-(p.side?SIDE_COST:0),items:p.side?[{k:'side',bet:SIDE_COST,back:0}]:[],
    hand:contest&&!p.folded?CAT[catOf(val.get(p))]:null}))},anim)}

// ---------- roulette (v0.10.0): the American wheel (0 and 00; 00 is pocket 37), always no limit ----------
// A round: 60 s of betting (the ball goes early once everyone seated has pressed SPIN and someone has a bet down), a 6 s spin,
// the result on the felt for 4 s. Bets are a map of spot -> shards; every spot is checked here, never trusted from a phone.
export const RL_RED=[1,3,5,7,9,12,14,16,18,19,21,23,25,27,30,32,34,36];
export const RL_WHEEL=[0,28,9,26,30,11,7,20,32,17,5,22,34,15,3,24,36,13,1,37,27,10,25,29,12,8,19,31,18,6,21,33,16,4,23,35,14,2];
const RL_PAYS={1:35,2:17,3:11,4:8,5:6,6:5,12:2,18:1},RED=new Set(RL_RED),RL_SP0=new Set(['0-37','0-1','0-2','2-37','3-37']),RL_TR=new Set(['0-1-2','0-2-37','2-3-37']);
const rng36=(a,b)=>Array.from({length:b-a+1},(_,i)=>a+i);
// a spot's numbers and what it pays, or null for anything that isn't a real spot on the layout
export function rlSpot(key){const k=String(key),m=k.match(/^([a-z]+)(?::([0-9-]+))?$/);if(!m)return null;const t=m[1],arg=m[2],ns=arg?arg.split('-').map(Number):[];
  if(arg&&!arg.split('-').every(x=>/^(0|[1-9][0-9]?)$/.test(x)))return null;   // plain numbers only: "00" is pocket 37, never a second spelling of 0
  if(ns.some(x=>!Number.isInteger(x)))return null;let nums=null;
  if(t==='n'&&ns.length===1&&ns[0]>=0&&ns[0]<=37)nums=ns;
  else if(t==='sp'&&ns.length===2&&ns[0]<ns[1]){const[a,b]=ns;if(RL_SP0.has(arg)||a>=1&&b<=36&&(b-a===1&&a%3!==0||b-a===3))nums=ns}
  else if(t==='st'&&ns.length===1&&ns[0]>=1&&ns[0]<=34&&ns[0]%3===1)nums=rng36(ns[0],ns[0]+2);
  else if(t==='tr'&&RL_TR.has(arg))nums=ns;
  else if(t==='co'&&ns.length===1&&ns[0]>=1&&ns[0]<=32&&ns[0]%3!==0)nums=[ns[0],ns[0]+1,ns[0]+3,ns[0]+4];
  else if(t==='tl'&&!arg)nums=[0,37,1,2,3];
  else if(t==='sl'&&ns.length===1&&ns[0]>=1&&ns[0]<=31&&ns[0]%3===1)nums=rng36(ns[0],ns[0]+5);
  else if(t==='dz'&&ns.length===1&&ns[0]>=1&&ns[0]<=3)nums=rng36(ns[0]*12-11,ns[0]*12);
  else if(t==='col'&&ns.length===1&&ns[0]>=1&&ns[0]<=3)nums=rng36(1,36).filter(x=>x%3===ns[0]%3);
  else if(!arg&&t==='red')nums=RL_RED;else if(!arg&&t==='black')nums=rng36(1,36).filter(x=>!RED.has(x));
  else if(!arg&&t==='odd')nums=rng36(1,36).filter(x=>x%2);else if(!arg&&t==='even')nums=rng36(1,36).filter(x=>!(x%2));
  else if(!arg&&t==='low')nums=rng36(1,18);else if(!arg&&t==='high')nums=rng36(19,36);
  return nums?{nums,pays:RL_PAYS[nums.length]}:null}
export const rlTotal=b=>Object.values(b||{}).reduce((a,x)=>a+x,0);
// what a set of bets returns on a number (the stake back plus the win; 0 if it lost)
export function rlPay(bets,n){let back=0;for(const[k,a]of Object.entries(bets||{})){const sp=rlSpot(k);if(sp&&sp.nums.includes(n))back+=a*(sp.pays+1)}return back}
// replace your bets for this spin (place, remove, clear, rebet and double are all one call)
export function rlSetBets(st,uid,bets){if(st.game!=='rl')return 'Not a roulette table';if(st.phase!=='bet')return 'No more bets';const s=st.seats[seatIx(st,uid)];if(!s)return 'You are not at this table';
  const nb={},ent=Object.entries(bets||{});if(ent.length>80)return 'Too many spots';
  for(const[k,a0]of ent){const a=Math.floor(+a0);if(!a)continue;if(!rlSpot(k))return 'That isn\'t a spot on the table';if(!(a>=1&&a<=1e9))return 'Bet at least 1 shard';nb[k]=(nb[k]||0)+a}
  const h=st.hand,old=rlTotal(h.bets[uid]),tot=rlTotal(nb);if(tot>s.stack+old)return 'Not enough shards at the table';
  s.stack+=old-tot;if(tot)h.bets[uid]=nb;else{delete h.bets[uid];delete h.ready[uid]}h.step++;return null}
export function rlReady(st,uid){if(st.game!=='rl'||st.phase!=='bet')return null;if(seatIx(st,uid)<0)return 'You are not at this table';st.hand.ready[uid]=true;st.hand.step++;return null}
function rlStep(st,ctx){const now=ctx.now,hs=humans(st).filter(s=>!s.leaving);
  if(st.phase==='wait'){if(hs.length){st.phase='bet';st.deadline=now+BET_MS;st.hand={bets:{},ready:{},step:(st.hand&&st.hand.step||0)+1,sideHits:[]}}return}
  if(st.phase==='bet'){const h=st.hand,bettors=Object.keys(h.bets);
    if(now>=st.deadline){if(bettors.length)rlSpin(st,ctx);else{st.deadline=now+BET_MS;h.ready={};h.step++}return}
    if(bettors.length&&hs.length&&hs.every(s=>h.ready[s.uid]))rlSpin(st,ctx);return}
  if(st.phase==='spin'){if(now>=st.deadline)rlSettle(st,ctx);return}
  if(st.phase==='done'&&now>=st.deadline)cleanup(st,ctx)}
function rlSpin(st,ctx){const h=st.hand;st.handNo++;
  for(const s of st.seats)if(s&&!s.bot)s.sitout=h.bets[s.uid]?0:s.sitout+1;
  const f=lockFair(st,ctx,st.seats.filter(s=>s&&!s.bot).map(s=>s.seed||''));
  Object.assign(h,{game:'rl',no:st.handNo,fair:f,hash:f.commit,salt:f.seed,number:fairRng(f.seed,f.seeds,f.nonce)(38)});
  st.phase='spin';st.deadline=ctx.now+SPIN_MS;h.step++}
function rlSettle(st,ctx){const h=st.hand,n=h.number;let tb=0,tr=0;
  const players=Object.entries(h.bets).map(([uid,b])=>{const i=seatIx(st,uid),s=st.seats[i],bet=rlTotal(b),won=rlPay(b,n);if(s)s.stack+=won;tb+=bet;tr+=won;
    return{uid,name:s?s.name:'?',seat:i,bets:b,bet,won,back:won,net:won-bet,items:Object.entries(b).map(([k,a])=>({k,bet:a,back:rlPay({[k]:a},n)}))}});
  st.hist=(st.hist||[]).concat(n).slice(-12);
  finish(st,ctx,{number:n,color:n===0||n===37?'green':RED.has(n)?'red':'black',house:tb-tr,players},0)}

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
// the last round, as this player may see it. Blackjack and roulette: everything (the seed, the players' seeds, the deck or the
// number), so it can be rerun. Hold'em: the card fingerprints, and only the cards this player saw (with each card's salt), so
// nothing about a folded hand gets out; the seed itself stays on the server (hand history shows it after 24 hours).
function lastView(st,uid){const L=st.last;if(!L)return null;const x=XG(st.game);if(x&&x.lastView)return x.lastView(st,uid,L);const o={no:L.no,hash:L.hash,result:L.result,sideHits:L.sideHits};
  if(st.game!=='he'){o.deck=L.deck;o.salt=L.salt;if(L.fair)o.seed=L.fair.seed;return o}
  o.deck=null;if(!L.fair||!L.cardHashes)return o;
  const vis=new Set([...(L.pos?L.pos.board:[]),...(L.pos?L.pos.side:[])]);
  for(const x of L.holes||[])if(x.uid===uid||(L.shownSeats||[]).includes(x.seat))for(const i of x.pos)vis.add(i);
  o.root=L.root;o.cardHashes=L.cardHashes;o.cards=[...vis].sort((a,b)=>a-b).map(i=>[i,L.deck[i],cardSalt(L.fair.seed,i)]);return o}
// v0.9.9.1: Hold'em never sends the deck after a hand (cards are dealt in order, so it would show what folded players held);
// the whole deck stays in the server's hand log (casino_hands) for checks. Blackjack's shoe is fresh every hand and all face up.
export function view(st,uid,now){
  const h=st.hand,me=seatIx(st,uid),v={game:st.game,lim:st.lim,side:st.side,host:st.host===uid,hostName:(st.seats.find(s=>s&&s.uid===st.host)||{}).name||'',phase:st.phase,
    left:st.deadline?Math.max(0,st.deadline-now):0,handNo:st.handNo,me,picks:st.picks[uid]|0,log:st.log.slice(-5),started:st.started!==false,
    readyMe:!!(st.ready||{})[uid],readyN:Object.keys(st.ready||{}).length,
    seats:st.seats.map((s,i)=>s&&{i,name:s.name,stack:s.stack,bot:!!s.bot,me:i===me,side:!!s.side,leaving:!!s.leaving}),
    last:lastView(st,uid),fair:h&&h.hash||null,next:st.next?st.next.hash:null,seed:me>=0?st.seats[me].seed||'':'',station:st.station||'',
    review:st.phase==='done'?Math.max(0,(st.minAt||0)-now):0,revealIn:st.phase==='done'&&h&&h.revealAt?Math.max(0,h.revealAt-now):0};
  if(XG(st.game))return XG(st.game).view(st,uid,v,now);
  if(st.game==='rl'){v.hist=st.hist||[];if(!h)return v;
    v.bets=Object.fromEntries(Object.entries(h.bets||{}).map(([u,b])=>[seatIx(st,u),b]));v.myBets=(h.bets||{})[uid]||{};
    v.readyMe=!!(h.ready||{})[uid];v.readyN=Object.keys(h.ready||{}).length;
    if(st.phase==='bet')v.fair=v.next;   // this spin's server seed is the committed one until the ball goes
    if(st.phase==='spin'||st.phase==='done')v.number=h.number;   // never before betting has closed
    return v}
  if(!h)return v;
  if(h.root)v.root=h.root;
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
