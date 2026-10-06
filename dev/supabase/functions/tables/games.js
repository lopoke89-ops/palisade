// v0.10.3 the casino's new games, run only on the server like the rest of the tables (engine.js owns the seats, the clock,
// the ledger ops and the receipts; this file owns each game's rules). Baccarat (8-deck mini-baccarat from a persistent shoe),
// craps (the full first-release bet set, persistent bets), slots (3 reels, one line) and Plinko (12 rows). Every payout is
// whole shards: a bet whose payout ratio would make a fraction is refused before it is taken, never rounded afterwards.
// Nothing from engine.js is used at load time (the two files import each other), only inside functions.
import * as E from './engine.js';

const seatOf=(st,uid)=>st.seats[E.seatIx(st,uid)];
const active=st=>st.seats.filter(s=>s&&!s.bot&&!s.leaving&&!s.gone);
const MAX_BET=1e6;   // one spot's most: far below the database's integer range even at 30:1
const whole=a=>Number.isSafeInteger(a)&&a>=0&&a<=MAX_BET;
// a client must send numbers, not numeric strings: "5" is refused like "five"
const amount=x=>typeof x==='number'&&Number.isInteger(x)?x:NaN;

// ======================= BACCARAT (mini-baccarat, 8 decks) =======================
// Player / Banker / Tie. Player 1:1, Banker 19:20 (1:1 less 5% commission; Banker bets in 20s so it's whole), Tie 8:1 (a tie
// returns Player and Banker bets). The shoe is one shuffle of 416 cards, made when the shoe starts (the server's committed
// seed + every seated player's seed at that moment), burned by the first card's value, cut 16 cards from the end. A hand
// that has started always finishes; the shoe changes between hands once the cut card is reached.
export const BA={DECKS:8,CARDS:416,CUT:400,BET_MS:30000,MIN_MS:5000,PAY:{P:[1,1],B:[19,20],T:[8,1]},SPOTS:['P','B','T'],DEN:{P:1,B:20,T:1}};
export const baVal=c=>{const r=c%52%13;return r<=7?r+2:r===12?1:0};   // 2-9 face value, 10/J/Q/K 0, A 1
export const baBurnVal=c=>{const r=c%52%13;return r<=7?r+2:r===12?1:10};   // the burn: 10/J/Q/K burn ten
export const baTot=cs=>cs.reduce((a,c)=>a+baVal(c),0)%10;
// the third-card rules, as a pure function of the next cards: returns {P:[…],B:[…],used}
export function baDraw(next){let k=0;const n=()=>next[k++];const P=[],B=[];P.push(n());B.push(n());P.push(n());B.push(n());
  const p=baTot(P),b=baTot(B);
  if(p>=8||b>=8)return{P,B,used:k,natural:true};
  let p3=null;if(p<=5){p3=n();P.push(p3)}
  if(p3===null){if(b<=5)B.push(n())}
  else{const v=baVal(p3);if(baBankerDraws(b,v))B.push(n())}
  return{P,B,used:k,natural:false}}
export function baBankerDraws(b,v){return b<=2||b===3&&v!==8||b===4&&v>=2&&v<=7||b===5&&v>=4&&v<=7||b===6&&v>=6&&v<=7}
// what a set of bets returns on an outcome ('P','B','T'): the stake back plus the win, 0 if it lost; commission itemized
export function baPay(bets,win){const items=[];let back=0,com=0;
  for(const k of BA.SPOTS){const a=bets[k]|0;if(!a)continue;let b=0,c=0;
    if(win==='T'){b=k==='T'?a*9:a}   // a tie: Tie pays 8:1, Player and Banker are returned
    else if(k===win){if(k==='B'){b=a+a*19/20;c=a/20}else b=a*2}
    back+=b;com+=c;items.push({k,bet:a,back:b,commission:c,res:b>a?'win':b===a?'push':'lose'})}
  return{back,commission:com,items}}
function baNewShoe(st,ctx){const B=st.ba;
  if(B.shoe)baRetire(st,ctx);
  if(!st.next)st.next=E.mkNext(ctx);const seed=st.next.seed,commit=st.next.hash;st.next=E.mkNext(ctx);
  const seeds=active(st).map(s=>s.seed||''),no=++B.shoeNo,nonce=(st.tid||'t')+':shoe:'+no,cards=E.shuffle(BA.CARDS,E.fairRng(seed,seeds,nonce));
  const root=E.rootOf(E.cardHashes(seed,cards)),burn=baBurnVal(cards[0]);
  B.shoe={no,seed,commit,seeds,nonce,cards,root,first:cards[0],burn,pos:1+burn,cut:BA.CUT,uids:[]};
  E.note(st,'A new shoe: the first card burns '+burn)}
// the shoe is done (cut card reached, or the table closes): its seed and every card go to the log, so the whole shuffle can be rerun
function baRetire(st,ctx){const sh=st.ba.shoe;if(!sh)return;
  ctx.hands.push({game:'ba',no:0,hash:sh.commit,salt:sh.seed,deck:sh.cards,rake:0,sideHits:[],
    result:{shoeEnd:sh.no,root:sh.root,commit:sh.commit,seeds:sh.seeds,nonce:sh.nonce,burn:sh.burn,dealt:sh.pos,house:0,rv:E.RV.ba,players:sh.uids.map(uid=>({uid}))}});
  st.ba.shoe=null}
function baOpen(st,ctx){if(!active(st).some(s=>s.stack>=1))return;st.phase='bet';st.deadline=ctx.now+BA.BET_MS;st.openAt=ctx.now;st.hand={bets:{},ready:{},step:(st.hand&&st.hand.step||0)+1,sideHits:[]}}
function baDeal(st,ctx){const h=st.hand,B=st.ba;
  for(const s of st.seats)if(s&&!s.bot)s.sitout=h.bets[s.uid]?0:(s.sitout||0)+1;
  if(!B.shoe||B.shoe.pos>=B.shoe.cut)baNewShoe(st,ctx);
  const sh=B.shoe,start=sh.pos,d=baDraw(sh.cards.slice(start,start+6));sh.pos+=d.used;st.handNo++;
  const pt=baTot(d.P),bt=baTot(d.B),win=pt>bt?'P':bt>pt?'B':'T';
  const players=Object.entries(h.bets).map(([uid,b])=>{const s=seatOf(st,uid),r=baPay(b,win),bet=BA.SPOTS.reduce((a,k)=>a+(b[k]|0),0);if(s)s.stack+=r.back;
    if(!sh.uids.includes(uid))sh.uids.push(uid);return{uid,name:s?s.name:'?',seat:E.seatIx(st,uid),bets:b,bet,back:r.back,net:r.back-bet,commission:r.commission,items:r.items}});
  const pos=[];for(let i=0;i<d.used;i++)pos.push(start+i);
  // the order the cards were dealt: Player, Banker, Player, Banker, then Player's third, then Banker's third
  const order=[];{let ip=0,ib=0;order.push(['P',ip++],['B',ib++],['P',ip++],['B',ib++]);if(d.P.length>2)order.push(['P',ip++]);if(d.B.length>2)order.push(['B',ib++])}
  Object.assign(h,{game:'ba',no:st.handNo,hash:sh.commit,salt:sh.seed,logSalt:sh.seed,logDeck:pos.map(i=>sh.cards[i]),fair:{seed:sh.seed,commit:sh.commit,seeds:sh.seeds,nonce:sh.nonce},
    P:d.P,B:d.B,pos,order});
  B.road=(B.road||[]).concat(win).slice(-60);
  const why=win==='T'?`Tie at ${pt}`:(win==='P'?`Player ${pt} beats Banker ${bt}`:`Banker ${bt} beats Player ${pt}`)+(d.natural?' (a natural)':'');
  E.finish(st,ctx,{player:d.P,banker:d.B,pt,bt,win,natural:d.natural,why,order,shoe:{no:sh.no,root:sh.root,commit:sh.commit,pos,left:BA.CARDS-sh.pos},
    house:players.reduce((a,p)=>a-p.net,0),players},d.used*E.CARD_MS+300)}
export function baSetBets(st,uid,bets){if(st.game!=='ba')return 'Not a baccarat table';if(st.phase!=='bet')return 'No more bets';const s=seatOf(st,uid);if(!s||s.leaving)return 'You are not at this table';
  if(!bets||typeof bets!=='object'||Array.isArray(bets))return 'Pick a bet';const nb={};
  for(const k of Object.keys(bets)){if(!BA.SPOTS.includes(k))return 'Bet on Player, Banker or Tie';const a=amount(bets[k]);if(!whole(a))return 'Bets are whole shards';
    if(a%BA.DEN[k])return 'Banker bets go in 20s (20 Banker pays 19 + your 20 back)';if(a)nb[k]=a}
  const h=st.hand,old=BA.SPOTS.reduce((a,k)=>a+((h.bets[uid]||{})[k]|0),0),tot=BA.SPOTS.reduce((a,k)=>a+(nb[k]|0),0);
  if(tot>s.stack+old)return 'Not enough shards at the table';s.stack+=old-tot;if(tot)h.bets[uid]=nb;else{delete h.bets[uid];delete h.ready[uid]}h.step++;return null}
function baStep(st,ctx){const now=ctx.now;
  if(st.phase==='wait'){baOpen(st,ctx);return}
  if(st.phase==='bet'){const h=st.hand,el=active(st),bettors=Object.keys(h.bets);
    if(!el.length&&!bettors.length){st.phase='wait';st.hand=null;return}
    if(now>=st.deadline){if(bettors.length)baDeal(st,ctx);else{st.deadline=now+BA.BET_MS;st.openAt=now;h.ready={};h.step++}return}
    if(now>=st.openAt+BA.MIN_MS&&bettors.length&&el.every(s=>h.ready[s.uid]))baDeal(st,ctx);return}
  if(st.phase==='done'&&now>=(st.minAt||0)){for(let i=0;i<st.seats.length;i++){const s=st.seats[i];if(s&&!s.bot&&(s.leaving||s.sitout>=3))E.standUp(st,i,ctx)}
    st.phase='wait';st.hand=null;st.deadline=0;st.ready={};baOpen(st,ctx)}}

// ======================= CRAPS =======================
// Standard casino craps. Pass/Don't Pass (bar 12), Come/Don't Come with their own points, odds 3-4-5x (Don't odds: lay up
// to 6x the flat, which wins at most 3/4/5x it), Place 4-10, Field (2 and 12 pay 2:1), Hardways, Any Seven, Any Craps, and
// 2, 3, 11, 12. Payouts are profit; a bet that closes gets its stake back too. Place and Hardways that win stay up (profit
// paid, stake still working). Place, Hardways and Come odds are off on the come-out unless you turn them on; Don't Come odds
// always work. Pass and an established Come can't come down; Don't bets can come down but not go back up.
export const CR={BET_MS:20000,MIN_MS:5000,DICE_MS:2200,PTS:[4,5,6,8,9,10],
  PLACE:{4:[9,5],5:[7,5],6:[7,6],8:[7,6],9:[7,5],10:[9,5]},ODDS:{4:[2,1],5:[3,2],6:[6,5],8:[6,5],9:[3,2],10:[2,1]},LAY:{4:[1,2],5:[2,3],6:[5,6],8:[5,6],9:[2,3],10:[1,2]},
  MULT:{4:3,5:4,6:5,8:5,9:4,10:3},LAYX:6,HARD:{4:[7,1],6:[9,1],8:[9,1],10:[7,1]},
  ONE:{any7:[4,1],anyc:[7,1],n2:[30,1],n3:[15,1],n11:[15,1],n12:[30,1]}};
const crPt=k=>{const m=/^([cdph])(\d+)(o?)$/.exec(k);return m?{t:m[1],n:+m[2],odds:!!m[3]}:null};
// is a bet key real, and the ratio its amount must divide by (so the payout is whole)
export function crKey(k,point){
  if(['pass','dp','come','dc','field'].includes(k))return{den:1};
  if(CR.ONE[k])return{den:1};
  if(k==='po'||k==='dpo'){if(!CR.PTS.includes(point))return null;return{den:(k==='po'?CR.ODDS:CR.LAY)[point][1]}}
  const m=crPt(k);if(!m||!CR.PTS.includes(m.n))return null;
  if(m.t==='p'&&!m.odds)return{den:CR.PLACE[m.n][1]};if(m.t==='h'&&!m.odds&&CR.HARD[m.n])return{den:1};
  if(m.t==='c')return{den:m.odds?CR.ODDS[m.n][1]:1};if(m.t==='d')return{den:m.odds?CR.LAY[m.n][1]:1};return null}
export const crProfit=(a,[n,d])=>a*n/d;
// set one bet to an amount (0 takes it down). The money moves between the bet and your table stack.
export function crSet(st,uid,k,amt){if(st.game!=='cr')return 'Not a craps table';if(st.phase!=='bet')return 'Wait for the dice to settle';const s=seatOf(st,uid);if(!s||s.leaving||s.gone)return 'You are not at this table';
  const C=st.cr,P=C.point,a=amount(amt),info=crKey(k,P);if(!info)return 'That isn\'t a bet on this table';if(!whole(a))return 'Bets are whole shards';
  if(a%info.den)return `That bet goes in ${info.den}s so it pays whole shards`;
  const B=C.bets[uid]||(C.bets[uid]={}),cur=B[k]|0;if(a===cur)return null;
  if(k==='pass'&&P)return 'Pass Line bets are locked once the point is on';
  if(k==='dp'&&P&&a>cur)return 'Don\'t Pass can come down, not go up, once the point is on';
  if((k==='come'||k==='dc')&&!P)return 'Come bets go down while a point is on (on the come-out, bet the Pass Line)';
  const m=crPt(k);
  if(m&&m.t==='c'&&!m.odds)return 'A Come bet that has moved to its number stays until it wins or loses';
  if(m&&m.t==='d'&&!m.odds&&a>cur)return 'A Don\'t Come bet on its number can come down, not go up';
  if(k==='po'){if(!P||!(B.pass>0))return 'Pass odds need a Pass Line bet and a point';if(a>CR.MULT[P]*B.pass)return `Odds on ${P}: up to ${CR.MULT[P]}x your Pass Line bet`}
  if(k==='dpo'){if(!P||!(B.dp>0))return 'Don\'t Pass odds need a Don\'t Pass bet and a point';if(a>CR.LAYX*B.dp)return `Lay odds: up to ${CR.LAYX}x your Don't Pass bet`}
  if(m&&m.odds){const flat=B[m.t+m.n]|0;if(!flat)return 'Odds need the Come bet on that number first';
    if(m.t==='c'&&a>CR.MULT[m.n]*flat)return `Odds on ${m.n}: up to ${CR.MULT[m.n]}x the Come bet`;if(m.t==='d'&&a>CR.LAYX*flat)return `Lay odds: up to ${CR.LAYX}x the Don't Come bet`}
  let free=a-cur,also=0;
  if(!a&&k==='dp'&&B.dpo){also=B.dpo}if(!a&&m&&m.t==='d'&&!m.odds&&B[k+'o'])also=B[k+'o'];   // a Don't bet that comes down takes its odds with it
  if(free>s.stack)return 'Not enough shards at the table';
  s.stack-=free;s.stack+=also;if(a)B[k]=a;else delete B[k];if(also){if(k==='dp')delete B.dpo;else delete B[k+'o']}
  delete C.ready[uid];st.hand.step++;return null}
export function crFlags(st,uid,f){const s=seatOf(st,uid);if(!s||s.gone)return 'You are not at this table';const F=st.cr.flags[uid]||(st.cr.flags[uid]={place:false,hard:false,codds:false});
  for(const k of['place','hard','codds'])if(f&&typeof f[k]==='boolean')F[k]=f[k];st.hand&&st.hand.step++;return null}
// one roll against one player's bets. Returns what was decided (items), and the bets still working. Pure: tests run all 36.
export function crResolve(bets,flags,point,d1,d2){const t=d1+d2,hard=d1===d2,co=!point,F=flags||{},B={...bets},items=[];
  const pay=(k,stake,back,res)=>{items.push({k,stake,back,net:back-stake,res})};
  const close=(k,win,ratio)=>{const a=B[k];delete B[k];if(win===null)pay(k,a,a,'push');else if(win)pay(k,a,a+crProfit(a,ratio),'win');else pay(k,a,0,'lose')};
  // one-roll bets
  if(B.field)close('field',[2,3,4,9,10,11,12].includes(t),[t===2||t===12?2:1,1]);
  for(const k of Object.keys(CR.ONE))if(B[k]){const win=k==='any7'?t===7:k==='anyc'?t===2||t===3||t===12:t===+k.slice(1);close(k,win,CR.ONE[k])}
  // hardways and place bets: they win and stay up
  for(const n of[4,6,8,10]){const k='h'+n;if(!B[k])continue;if(co&&!F.hard)continue;
    if(t===7||t===n&&!hard)close(k,false);else if(t===n&&hard)pay(k,0,crProfit(B[k],CR.HARD[n]),'win · stays up')}
  for(const n of CR.PTS){const k='p'+n;if(!B[k])continue;if(co&&!F.place)continue;
    if(t===7)close(k,false);else if(t===n)pay(k,0,crProfit(B[k],CR.PLACE[n]),'win · stays up')}
  // the line
  if(B.pass){if(co){if(t===7||t===11)close('pass',true,[1,1]);else if(t===2||t===3||t===12)close('pass',false)}
    else if(t===point){close('pass',true,[1,1]);if(B.po)close('po',true,CR.ODDS[point])}else if(t===7){close('pass',false);if(B.po)close('po',false)}}
  if(!B.pass&&B.po&&co)close('po',null);   // odds left over with no line bet: returned
  if(B.dp){if(co){if(t===2||t===3)close('dp',true,[1,1]);else if(t===7||t===11)close('dp',false)}   // 12 on the come-out: barred, the bet stays
    else if(t===7){close('dp',true,[1,1]);if(B.dpo)close('dpo',true,CR.LAY[point])}else if(t===point){close('dp',false);if(B.dpo)close('dpo',false)}}
  // come bets already on their numbers (before the new ones move)
  for(const n of CR.PTS){const k='c'+n,o=k+'o';if(!B[k])continue;const oddsOn=!co||F.codds;
    if(t===n){close(k,true,[1,1]);if(B[o])oddsOn?close(o,true,CR.ODDS[n]):close(o,null)}
    else if(t===7){close(k,false);if(B[o])oddsOn?close(o,false):close(o,null)}}
  for(const n of CR.PTS){const k='d'+n,o=k+'o';if(!B[k])continue;
    if(t===7){close(k,true,[1,1]);if(B[o])close(o,true,CR.LAY[n])}else if(t===n){close(k,false);if(B[o])close(o,false)}}
  // new come bets: like a come-out of their own
  if(B.come){if(t===7||t===11)close('come',true,[1,1]);else if(t===2||t===3||t===12)close('come',false);else{B['c'+t]=B.come;delete B.come;items.push({k:'come',stake:0,back:0,net:0,res:'moves to '+t})}}
  if(B.dc){if(t===2||t===3)close('dc',true,[1,1]);else if(t===7||t===11)close('dc',false);else if(t!==12){B['d'+t]=B.dc;delete B.dc;items.push({k:'dc',stake:0,back:0,net:0,res:'moves to '+t})}}
  const next=co?(CR.PTS.includes(t)?t:0):t===point||t===7?0:point;
  return{items,bets:B,point:next,sevenOut:!co&&t===7}}
// what must stay on the table if you leave: Pass once the point is on, and Come bets on their numbers
const crLocked=(B,point)=>Object.keys(B).filter(k=>k==='pass'&&point||/^c\d+$/.test(k));
function crShooter(st){const C=st.cr,n=st.seats.length,ok=i=>{const s=st.seats[i];if(!s||s.bot||s.leaving||s.gone)return false;const B=C.bets[s.uid]||{};return B.pass>0||B.dp>0};
  if(C.point&&C.shooter>=0&&st.seats[C.shooter]&&!st.seats[C.shooter].gone&&!st.seats[C.shooter].leaving)return C.shooter;   // the shooter keeps the dice through the point
  if(C.point)return -1;   // the shooter left mid-point: the dealer finishes it
  const from=C.passDice?C.shooter+1:Math.max(0,C.shooter);for(let k=0;k<n;k++){const i=((from+k)%n+n)%n;if(ok(i))return i}return -1}
function crOpen(st,ctx){st.phase='bet';st.deadline=ctx.now+CR.BET_MS;st.openAt=ctx.now;st.cr.ready={};st.hand={step:(st.hand&&st.hand.step||0)+1,sideHits:[]};st.cr.shooter=crShooter(st);st.cr.passDice=false}
function crRoll(st,ctx){const C=st.cr,h=st.hand;st.handNo++;
  const f=E.lockFair(st,ctx,active(st).map(s=>s.seed||'')),r=E.fairRng(f.seed,f.seeds,f.nonce),d1=r(6)+1,d2=r(6)+1,before=C.point,shooter=C.shooter;
  const players=[];
  for(const [uid,b]of Object.entries(C.bets)){if(!Object.keys(b).length){delete C.bets[uid];continue}
    const s=seatOf(st,uid),res=crResolve(b,C.flags[uid],before,d1,d2);let bet=0,back=0;for(const it of res.items){bet+=it.stake;back+=it.back}
    if(s)s.stack+=back;C.bets[uid]=res.bets;
    if(res.items.length||Object.keys(res.bets).length)players.push({uid,name:s?s.name:'?',seat:E.seatIx(st,uid),bet,back,net:back-bet,items:res.items,working:Object.entries(res.bets).map(([k,a])=>({k,a}))});
    if(!Object.keys(res.bets).length)delete C.bets[uid]}
  const after=crResolve({},{},before,d1,d2);C.point=after.point;if(after.sevenOut)C.passDice=true;
  C.rolls=(C.rolls||[]).concat([[d1,d2]]).slice(-20);C.dice=[d1,d2];
  for(const s of st.seats)if(s&&!s.bot&&!s.gone)s.sitout=C.bets[s.uid]?0:(s.sitout||0)+1;
  Object.assign(h,{game:'cr',no:st.handNo,fair:f,hash:f.commit,salt:f.seed,dice:[d1,d2],logDeck:[d1,d2]});
  const t=d1+d2,why=!before?(after.point?`Point is ${after.point}`:t===7||t===11?`${t}: Pass wins`:`${t}: craps`):t===before?`${t}: the point is made`:t===7?'Seven out':`${t}: no decision on the line`;
  E.finish(st,ctx,{dice:[d1,d2],total:t,hard:d1===d2,point:before,newPoint:after.point,sevenOut:after.sevenOut,why,shooter:shooter>=0&&st.seats[shooter]?st.seats[shooter].name:'DEALER',
    house:players.reduce((a,p)=>a-p.net,0),players},CR.DICE_MS)}
function crStep(st,ctx){const now=ctx.now,C=st.cr;
  // anyone who left with bets that must stay: stood up once those are settled
  for(let i=0;i<st.seats.length;i++){const s=st.seats[i];if(s&&s.gone&&!crLocked(C.bets[s.uid]||{},C.point).length&&st.phase!=='done'){crReturnAll(st,s.uid);E.standUp(st,i,ctx)}}
  if(st.phase==='wait'){if(st.seats.some(s=>s&&!s.bot))crOpen(st,ctx);return}
  if(st.phase==='bet'){const el=active(st),any=Object.values(C.bets).some(b=>Object.keys(b).length);
    if(!el.length){if(any)crRoll(st,ctx);else{st.phase='wait';st.hand=null}return}   // only bets that must finish are left: the dealer rolls them out
    if(now>=st.deadline){if(any)crRoll(st,ctx);else{st.deadline=now+CR.BET_MS;st.openAt=now;C.ready={}}return}
    if(any&&now>=st.openAt+CR.MIN_MS&&el.every(s=>C.ready[s.uid]))crRoll(st,ctx);return}
  if(st.phase==='done'&&now>=(st.minAt||0)){for(let i=0;i<st.seats.length;i++){const s=st.seats[i];if(s&&!s.bot&&!s.gone&&(s.leaving||s.sitout>=6&&!(C.bets[s.uid]&&Object.keys(C.bets[s.uid]).length)))crLeave(st,s.uid,ctx)}
    st.ready={};crOpen(st,ctx)}}
function crReturnAll(st,uid){const s=seatOf(st,uid),B=st.cr.bets[uid]||{};let back=0;for(const k of Object.keys(B)){back+=B[k];delete B[k]}if(s)s.stack+=back;delete st.cr.bets[uid];return back}
// leaving: every bet that may come down comes back to your stack; Pass (point on) and Come bets on numbers stay and are
// rolled out by the dealer; you're stood up (shards home) when the last one is settled. Your account stays at this table
// until then (you can't sit elsewhere).
function crLeave(st,uid,ctx){const i=E.seatIx(st,uid),s=st.seats[i];if(!s)return 'You are not at this table';const B=st.cr.bets[uid]||{},keep=crLocked(B,st.cr.point);
  for(const k of Object.keys(B))if(!keep.includes(k)){s.stack+=B[k];delete B[k]}
  delete st.cr.ready[uid];
  if(keep.length){s.gone=true;E.note(st,s.name+' left: '+keep.length+' bet'+(keep.length>1?'s':'')+' still working');return null}
  delete st.cr.bets[uid];E.standUp(st,i,ctx);return null}
export function crReady(st,uid){if(st.phase!=='bet')return null;const s=seatOf(st,uid);if(!s||s.gone)return 'You are not at this table';st.cr.ready[uid]=true;st.hand.step++;return null}

// ======================= SLOTS: PALISADE RUN (3 reels, one line) =======================
// Symbols: P the Palisade crest, C the core, W wall, H helmet, N nade, S shard, X blank. Gross multipliers (the stake
// included), the single highest award on the line: three of a kind P 250, C 60, W 25, H 15, N 10, S 6; any three of W/H/N
// 3; S S on reels 1-2 pays 2; S on reel 1 pays 1 (your stake back). 20 stops a reel, every stop equally likely; the reels
// stop where the server's numbers say, and the symbols above and below are the real strip.
export const SL={RV:'sl-1',STOPS:20,MAX:100,ANIM:2600,
  STRIPS:['SWNXHSWNSPWXNSHWCNSX','SWXNHXWNSPWXNXHWCNSX','SWXNHXWNXPWXNXHWCNSX'],
  NAMES:{P:'PALISADE',C:'CORE',W:'WALL',H:'HELMET',N:'NADE',S:'SHARD',X:'BLANK'}};
export function slPay(a,b,c){
  if(a===b&&b===c)return{P:250,C:60,W:25,H:15,N:10,S:6,X:0}[a]?{m:{P:250,C:60,W:25,H:15,N:10,S:6}[a],combo:'THREE '+SL.NAMES[a]+'S'}:{m:0,combo:null};
  const gear=x=>x==='W'||x==='H'||x==='N';if(gear(a)&&gear(b)&&gear(c))return{m:3,combo:'ANY THREE GEAR'};
  if(a==='S'&&b==='S')return{m:2,combo:'TWO SHARDS'};if(a==='S')return{m:1,combo:'ONE SHARD (STAKE BACK)'};return{m:0,combo:null}}
// the exact return: every one of the 8,000 stop combinations
export function slMath(){let tot=0,hit=0,n=0,max=0;const S=SL.STRIPS;for(let i=0;i<20;i++)for(let j=0;j<20;j++)for(let k=0;k<20;k++){const m=slPay(S[0][i],S[1][j],S[2][k]).m;tot+=m;if(m)hit++;n++;if(m>max)max=m}
  return{rtp:tot/n,hit:hit/n,combos:n,max,ret:tot}}
const slWin=(stops)=>SL.STRIPS.map((r,i)=>[r[(stops[i]+19)%20],r[stops[i]],r[(stops[i]+1)%20]]);
function slSpin(st,uid,amt,ctx){if(st.game!=='sl')return 'Not a slot machine';const s=seatOf(st,uid);if(!s||s.leaving)return 'You are not at this machine';
  if(st.phase!=='idle')return 'The reels are still turning';const a=amount(amt);if(!(Number.isSafeInteger(a)&&a>=1))return 'Bet at least 1 shard';if(a>SL.MAX)return 'The most a spin is '+SL.MAX+' shards';if(a>s.stack)return 'Not enough shards in the machine: top up';
  s.stack-=a;st.handNo++;const f=E.lockFair(st,ctx,[s.seed||'']),r=E.fairRng(f.seed,f.seeds,f.nonce),stops=[r(20),r(20),r(20)],line=stops.map((x,i)=>SL.STRIPS[i][x]),p=slPay(...line),back=a*p.m;
  s.stack+=back;s.sitout=0;st.hand={game:'sl',no:st.handNo,fair:f,hash:f.commit,salt:f.seed,logDeck:stops,step:(st.hand&&st.hand.step||0)+1,sideHits:[]};
  E.finish(st,ctx,{stops,line,window:slWin(stops),mult:p.m,combo:p.combo,why:p.m?`${p.combo} pays ${p.m}x`:'No win on the line',house:a-back,
    players:[{uid,name:s.name,seat:0,bet:a,back,net:back-a,items:[{k:'line',bet:a,back}]}]},SL.ANIM);return null}

// ======================= PLINKO (12 rows, 13 pockets) =======================
// Twelve left/right bounces decided by the server, each 50/50; the pocket is the number of rights (0-12). Multipliers in
// tenths and stakes in 10s, so every return is whole shards. The board animates exactly the recorded path.
export const PK={RV:'pk-1',ROWS:12,MAX:500,DEN:10,ANIM:3100,MULT:[300,90,30,15,12,6,5,6,12,15,30,90,300]};   // tenths: 30x … 0.5x … 30x
export function pkMath(){const C=[1];for(let k=1;k<=12;k++)C.push(C[k-1]*(13-k)/k);let mean=0,sq=0;for(let k=0;k<13;k++){const m=PK.MULT[k]/10;mean+=C[k]/4096*m;sq+=C[k]/4096*m*m}
  return{rtp:mean,variance:sq-mean*mean,max:Math.max(...PK.MULT)/10,lossChance:C.reduce((a,c,k)=>a+(PK.MULT[k]<10?c:0),0)/4096,odds:C.map(c=>c/4096)}}
function pkDrop(st,uid,amt,ctx){if(st.game!=='pk')return 'Not a Plinko board';const s=seatOf(st,uid);if(!s||s.leaving)return 'You are not at this board';
  if(st.phase!=='idle')return 'The ball is still dropping';const a=amount(amt);if(!(Number.isSafeInteger(a)&&a>=PK.DEN))return 'Drop at least '+PK.DEN+' shards';
  if(a%PK.DEN)return 'Plinko stakes go in 10s so every pocket pays whole shards';if(a>PK.MAX)return 'The most a drop is '+PK.MAX+' shards';if(a>s.stack)return 'Not enough shards at the board: top up';
  s.stack-=a;st.handNo++;const f=E.lockFair(st,ctx,[s.seed||'']),r=E.fairRng(f.seed,f.seeds,f.nonce),path=[];for(let i=0;i<PK.ROWS;i++)path.push(r(2));
  const pocket=path.reduce((x,y)=>x+y,0),m=PK.MULT[pocket],back=a*m/PK.DEN;s.stack+=back;s.sitout=0;
  st.hand={game:'pk',no:st.handNo,fair:f,hash:f.commit,salt:f.seed,logDeck:path,step:(st.hand&&st.hand.step||0)+1,sideHits:[]};
  E.finish(st,ctx,{path,pocket,mult:m/10,why:`Pocket ${pocket+1} of 13 pays ${m/10}x`,house:a-back,players:[{uid,name:s.name,seat:0,bet:a,back,net:back-a,items:[{k:'drop',bet:a,back}]}]},PK.ANIM);return null}
// a machine: one seat; idle -> a spin or drop -> the reveal and its review -> idle
function machStep(st,ctx){if(st.phase==='wait'){st.phase='idle';return}if(st.phase==='done'&&ctx.now>=(st.minAt||0)){st.phase='idle';st.hand&&st.hand.step++}}

// ======================= the registry engine.js dispatches to =======================
export const GAMES={
  ba:{init(st){st.ba={shoe:null,shoeNo:0,road:[]}},step:baStep,inHand:()=>false,
    leave(st,uid,ctx){const i=E.seatIx(st,uid),h=st.hand;if(st.phase==='bet'&&h&&h.bets[uid]){st.seats[i].stack+=BA.SPOTS.reduce((a,k)=>a+(h.bets[uid][k]|0),0);delete h.bets[uid];delete h.ready[uid]}
      E.standUp(st,i,ctx);if(!st.seats.some(s=>s&&!s.bot))baRetire(st,ctx);return null},
    view(st,uid,v,now){const h=st.hand,B=st.ba,sh=B.shoe;v.road=B.road||[];v.shoe=sh?{no:sh.no,root:sh.root,commit:sh.commit,left:BA.CARDS-sh.pos,burn:sh.burn,first:sh.first,cut:sh.pos>=sh.cut}:null;
      v.minBetAt=st.phase==='bet'?Math.max(0,st.openAt+BA.MIN_MS-now):0;
      if(!h)return v;v.bets=Object.fromEntries(Object.entries(h.bets||{}).map(([u,b])=>[E.seatIx(st,u),b]));v.myBets=(h.bets||{})[uid]||{};v.readyMe=!!(h.ready||{})[uid];v.readyN=Object.keys(h.ready||{}).length;
      if(st.phase==='done'&&h.P){v.P=h.P;v.B=h.B;v.order=h.order}return v},
    lastView(st,uid,L){const o={no:L.no,hash:L.hash,result:L.result};const sh=L.result&&L.result.shoe;
      // the cards of this hand with each card's salt: checkable now against the shoe's root, without showing a card still in the shoe
      if(sh&&L.fair){o.root=sh.root;o.cards=sh.pos.map((p,i)=>[p,L.deck[i],E.cardSalt(L.fair.seed,p)])}return o}},
  cr:{init(st){st.cr={point:0,shooter:-1,passDice:false,rolls:[],dice:null,bets:{},flags:{},ready:{}}},step:crStep,
    inHand:(st,uid)=>crLocked(st.cr.bets[uid]||{},st.cr.point).length>0,leave:crLeave,
    view(st,uid,v,now){const C=st.cr,me=E.seatIx(st,uid);v.point=C.point;v.shooter=C.shooter;v.dice=C.dice;v.rolls=C.rolls;v.flags=C.flags[uid]||{place:false,hard:false,codds:false};
      v.bets=Object.fromEntries(Object.entries(C.bets).map(([u,b])=>[E.seatIx(st,u),b]));v.myBets=C.bets[uid]||{};v.readyMe=!!C.ready[uid];v.readyN=Object.keys(C.ready).length;
      v.amShooter=me>=0&&C.shooter===me;v.minBetAt=st.phase==='bet'?Math.max(0,st.openAt+CR.MIN_MS-now):0;v.locked=crLocked(C.bets[uid]||{},C.point);
      v.gone=st.seats.map(s=>!!(s&&s.gone));return v},
    lastView(st,uid,L){return{no:L.no,hash:L.hash,result:L.result,salt:L.salt,seed:L.fair&&L.fair.seed,deck:L.deck}}},
  sl:{init(){},step:machStep,inHand:()=>false,leave(st,uid,ctx){E.standUp(st,E.seatIx(st,uid),ctx);return null},
    view(st,uid,v){v.max=SL.MAX;v.strips=SL.STRIPS;return v},lastView(st,uid,L){return{no:L.no,hash:L.hash,result:L.result,salt:L.salt,seed:L.fair&&L.fair.seed,deck:L.deck}}},
  pk:{init(){},step:machStep,inHand:()=>false,leave(st,uid,ctx){E.standUp(st,E.seatIx(st,uid),ctx);return null},
    view(st,uid,v){v.max=PK.MAX;v.mult=PK.MULT;return v},lastView(st,uid,L){return{no:L.no,hash:L.hash,result:L.result,salt:L.salt,seed:L.fair&&L.fair.seed,deck:L.deck}}}};
export const ACTIONS={babets:(st,u,b)=>baSetBets(st,u,b.bets),baready:(st,u)=>{if(st.game!=='ba'||st.phase!=='bet')return null;if(E.seatIx(st,u)<0)return 'You are not at this table';st.hand.ready[u]=true;st.hand.step++;return null},
  crbet:(st,u,b)=>crSet(st,u,String(b.k||''),b.amt),crflags:(st,u,b)=>crFlags(st,u,b.flags),crready:(st,u)=>crReady(st,u),
  spin:(st,u,b,ctx)=>slSpin(st,u,b.amt,ctx),drop:(st,u,b,ctx)=>pkDrop(st,u,b.amt,ctx)};
