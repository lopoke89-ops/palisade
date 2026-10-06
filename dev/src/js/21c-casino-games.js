/* ================= v0.10.3 THE PALISADE FALLS CASINO: baccarat, craps, slots, Plinko, and the result review ================= */
// The sheets for the four new games, and the review every game shares: after a round the server holds the result on screen
// (8 s for cards, 6 for dice and roulette, 3 for slots and Plinko, counted from the last card or the ball landing) and the
// receipt says what you bet, what came back, the net and why. The server decides everything (games.js); this file shows
// what it says, animates exactly what it decided, and sends what you pick. LAST RESULT shows your last receipt any time.
const CG={},CGS={chip:{ba:10,cr:5,sl:1,pk:10},ba:{bets:{},sent:'',dirty:0,hand:-1,last:{},at:0},cr:{adv:false,down:false,q:Promise.resolve()},sl:{amt:1},pk:{amt:10},snd:{key:'',n:0}};
const cgRM=()=>{try{return matchMedia('(prefers-reduced-motion: reduce)').matches}catch(e){return false}};
const cgEsc=s=>tbEsc(s);
function cgReset(){CGS.ba.bets={};CGS.ba.sent='';CGS.ba.hand=-1}
// ---------- the reveal: how much of it is still running (the server's revealIn, less the time since that view arrived) ----------
const cgLeft=v=>!v||v.phase!=='done'||cgRM()?0:Math.max(0,(v.revealIn||0)-(performance.now()-(v._t||0)));
const cgReviewLeft=v=>!v||v.phase!=='done'?0:Math.max(0,(v.review||0)-(performance.now()-(v._t||0)));
const cgNet=n=>(n>0?'+':n<0?'−':'')+Math.abs(n)+'◆';
function tbRevealClock(v){if(!v._t)v._t=performance.now();if(cgLeft(v)>0&&!TB.animT)TB.animT=setTimeout(()=>{TB.animT=0;if(TB.v&&TB.sheet){TB.key='';tbShow(TB.v)}},110)}
function cgSound(v,stage,name){const k=v.game+':'+(v.station||'')+':'+(v.last&&v.last.no);if(CGS.snd.key!==k){CGS.snd.key=k;CGS.snd.n=0}if(stage>CGS.snd.n){CGS.snd.n=stage;if(typeof uiSfx==='function')uiSfx(name)}}

// ---------- the receipt (every game) ----------
const CR_LABEL={pass:'PASS LINE',dp:'DON\'T PASS',po:'PASS ODDS',dpo:'DON\'T PASS ODDS',come:'COME',dc:'DON\'T COME',field:'FIELD',any7:'ANY SEVEN',anyc:'ANY CRAPS',n2:'TWO',n3:'THREE',n11:'ELEVEN',n12:'TWELVE'};
const crLabel=k=>{if(CR_LABEL[k])return CR_LABEL[k];const m=/^([cdph])(\d+)(o?)$/.exec(k);if(!m)return k;return({c:'COME ',d:'DON\'T COME ',p:'PLACE ',h:'HARD '}[m[1]])+m[2]+(m[3]?' ODDS':'')};
const ITEM_LABEL={ins:'INSURANCE',side:'SIDE BET',line:'THE LINE',drop:'THE DROP',P:'PLAYER',B:'BANKER',T:'TIE'};
const itemLabel=(game,k)=>game==='cr'?crLabel(k):game==='rl'?rlSpotName(k):ITEM_LABEL[k]||k;
function rlSpotName(k){const m=String(k).match(/^([a-z]+)(?::([0-9-]+))?$/);if(!m)return k;const a=(m[2]||'').replace(/37/g,'00');
  return({n:'NUMBER ',sp:'SPLIT ',st:'STREET ',tr:'TRIO ',co:'CORNER ',sl:'SIX LINE ',dz:'DOZEN ',col:'COLUMN '}[m[1]]||m[1].toUpperCase())+(m[1]==='tl'?'TOP LINE':a)}
// WIN, LOSS, PUSH or PARTIAL RESULT, in words (the color only repeats it)
function cgVerdict(p){if(!p)return null;const it=p.items||[],hands=p.hands||[],won=it.some(x=>(x.back||0)>(x.bet||x.stake||0))||hands.some(h=>/WIN|BLACKJACK/.test(h.result||'')),
  lost=it.some(x=>(x.bet||x.stake||0)>0&&!x.back)||hands.some(h=>/LOSE|BUST/.test(h.result||''));
  if(p.net>0)return lost?'PARTIAL RESULT':'WIN';if(p.net<0)return won?'PARTIAL RESULT':'LOSS';if(!(p.bet>0)&&!(p.back>0))return 'NO DECISION';return won&&lost?'PARTIAL RESULT':'PUSH'}
const mineOf=res=>(res&&res.players||[]).find(p=>p.uid===myUid());
// what decided it, game by game (the cards, the dice, the reels, the pocket)
function cgEvidence(game,res,me){const C=a=>(a||[]).map(tbCard).join('');
  if(game==='bj'){let h=`<div class="trow2"><b>DEALER</b> <span class="tcards sm">${C(res.dealer)}</span> <em>${res.total}${res.soft?' soft':''}${res.total>21?' · BUST':res.dbj?' · BLACKJACK':''}</em></div>`;
    for(const [i,x]of(me&&me.hands||[]).entries())h+=`<div class="trow2"><b>${me.hands.length>1?'HAND '+(i+1):'YOU'}</b> <span class="tcards sm">${C(x.cards)}</span> <em>${x.total}${x.soft?' soft':''} · ${x.result}${x.doubled?' (doubled)':''}</em><p>${cgEsc(x.why||'')}</p></div>`;
    return h}
  if(game==='he'){let h=`<div class="trow2"><b>BOARD</b> <span class="tcards sm">${C(res.board)}</span></div>`;
    if(res.uncontested){const w=(res.players||[]).find(p=>p.won>0);h+=`<p>${w?cgEsc(w.name)+' wins '+w.won+'◆ uncontested: everyone else folded, so no cards are shown.':'Everyone folded.'}</p>`}
    else for(const pt of res.pots||[]){const ws=pt.winners.map(s=>((res.players||[]).find(p=>p.seat===s)||{}).name||'?');h+=`<div class="trow2"><b>${pt.k?'SIDE POT':'POT'} ${pt.amount}◆</b> <em>${ws.map(cgEsc).join(' + ')} · ${pt.hand||''}</em> ${pt.five?`<span class="tcards sm">${C(pt.five)}</span>`:''}</div>`}
    for(const p of(res.players||[]).filter(p=>p.cards))h+=`<div class="trow2 dim"><b>${cgEsc(p.name)}</b> <span class="tcards sm">${C(p.cards)}</span> <em>${p.hand||''}</em></div>`;
    if(res.rake)h+=`<p class="dim">House cut ${res.rake}◆</p>`;return h}
  if(game==='rl')return `<div class="trow2"><b>THE BALL</b> <em class="rlc ${res.color}">${rlName(res.number)}</em></div>`;
  if(game==='ba')return `<div class="trow2"><b>PLAYER ${res.pt}</b> <span class="tcards sm">${C(res.player)}</span></div><div class="trow2"><b>BANKER ${res.bt}</b> <span class="tcards sm">${C(res.banker)}</span></div><p>${cgEsc(res.why)}</p>`;
  if(game==='cr'){const w=me&&me.working||[];return `<div class="trow2"><b>THE DICE</b> ${cgDiceHTML(res.dice)} <em>${res.total}${res.hard&&[4,6,8,10].includes(res.total)?' (hard)':''}</em></div><p>${cgEsc(res.why)} · point ${res.point?'was '+res.point:'off'} → ${res.newPoint?'now '+res.newPoint:'off'}</p>`+
    (w.length?`<p class="dim">Still working: ${w.map(x=>crLabel(x.k)+' '+x.a+'◆').join(' · ')}</p>`:'')}
  if(game==='sl')return `<div class="slwin sm">${cgReels(res.window,3,true)}</div><p>${cgEsc(res.why)}</p>`;
  if(game==='pk')return `<p>${cgEsc(res.why)}</p>`;return ''}
function tbReceiptHTML(game,res,opt={}){const me=mineOf(res);if(!res)return '';
  const vd=me?cgVerdict(me):null,cls=vd==='WIN'?'w':vd==='LOSS'?'l':vd==='PUSH'||vd==='NO DECISION'?'p':'m';
  let h=`<div class="trcpt ${cls}"><div class="trv"><b>${vd||'NOT IN THIS ROUND'}</b><span>${TB_NAME[game]}${res.rid?' · round '+cgEsc(String(res.rid).split(':').pop()):''}</span></div>`;
  if(me){h+=`<div class="trn"><div><span>BET</span><b>${me.bet||0}◆</b></div><div><span>RETURNED</span><b>${me.back||0}◆</b></div><div><span>NET</span><b class="${me.net>0?'w':me.net<0?'l':''}">${cgNet(me.net||0)}</b></div></div>`;
    const it=(me.items||[]).filter(x=>!/^moves/.test(x.res||''));
    if(it.length&&!(game==='sl'||game==='pk'))h+=`<ul class="tri">${it.map(x=>`<li><span>${itemLabel(game,x.k)}</span><em>${x.bet!==undefined?x.bet:x.stake}◆ → ${x.back}◆${x.commission?' (commission '+x.commission+'◆)':''}${x.res&&game==='cr'?' · '+cgEsc(x.res):''}</em></li>`).join('')}</ul>`;
    if(me.commission)h+=`<p class="dim">Banker commission ${me.commission}◆ (5% of the Banker win)</p>`}
  h+=`<div class="trev">${cgEvidence(game,res,me)}</div>`;
  if(opt.wallet)h+=`<p class="trwal">${opt.wallet}</p>`;if(opt.next)h+=`<p class="trnext">${opt.next}</p>`;return h+'</div>'}
// what's on the felt for you right now (committed, not yet decided) — never counted twice with the table stack
function tbCommitted(v){const sum=o=>Object.values(o||{}).reduce((a,x)=>a+(x|0),0);
  if(v.game==='rl'||v.game==='ba'||v.game==='cr')return v.phase==='bet'||v.game==='cr'?sum(v.myBets):v.game==='rl'&&v.phase==='spin'?sum(v.myBets):0;
  if(v.game==='bj'){if(v.phase==='bet')return v.bets&&v.bets[v.me]||0;if(v.phase==='play'||v.phase==='ins'){const p=(v.players||[]).find(p=>p.seat===v.me);return p?p.hands.reduce((a,h)=>a+h.bet,0):0}return 0}
  if(v.game==='he'&&v.phase==='play'){const p=(v.players||[]).find(p=>p.seat===v.me);return p?p.put:0}return 0}
// the review at the top of the felt: while the reveal runs it says so; then the receipt, its countdown and what HIDE / STAND UP do
function tbReview(v){if(v.phase!=='done'||!v.last||!v.last.result)return '';tbKeep(v);
  if(cgLeft(v)>0)return `<div class="trcpt live"><div class="trv"><b>${v.game==='cr'?'ROLLING…':v.game==='sl'?'SPINNING…':v.game==='pk'?'DROPPING…':v.game==='rl'?'THE BALL HAS LANDED':'DEALING…'}</b></div></div>`;
  const me=v.seats[v.me],rl=Math.ceil(cgReviewLeft(v)/1000),nxt=v.game==='he'?Math.ceil(Math.max(0,v.left-(performance.now()-(v._t||0)))/1000):rl;
  const next=(rl>0?`Result on screen for ${rl}s more`:'Result reviewed')+(v.game==='he'?` · next hand in ${nxt}s${rl>0?'':' (READY deals sooner)'}`:v.game==='sl'||v.game==='pk'?'':' · then betting opens')+' · HIDE keeps your seat · STAND UP takes your shards home';
  return tbReceiptHTML(v.game,v.last.result,{wallet:`Balance ${TB.balance}◆ · at the table ${me?me.stack:0}◆ · on the felt ${tbCommitted(v)}◆`,next})}
// keep your last receipt (this tab): LAST RESULT shows it after the next round opens, after you stand up, after you come back
function tbKeep(v){const r=v.last&&v.last.result;if(!r||!mineOf(r))return;const k=v.game+':'+(v.station||'')+':'+v.last.no;if(TB.rcpt&&TB.rcpt.k===k)return;
  TB.rcpt={k,game:v.game,res:r,at:Date.now()};try{sessionStorage.setItem('pal_rcpt',JSON.stringify(TB.rcpt))}catch(e){}hid($('tbLastBtn'),false);hid($('tbDoorLast'),false)}
function cgOnRcpt(rc){if(rc&&rc.result&&TB.v)tbKeep({...TB.v,last:{no:rc.no,result:rc.result}})}
function tbLastResult(){let r=TB.rcpt;if(!r)try{r=JSON.parse(sessionStorage.getItem('pal_rcpt')||'null')}catch(e){}
  $('tbRcptTxt').innerHTML=r?tbReceiptHTML(r.game,r.res)+`<p class="tbHint">${new Date(r.at).toLocaleTimeString()} · every round is in HAND HISTORY too</p>`:'<p class="tbHint">No result yet this session. Every round you played is in HAND HISTORY.</p>';hid($('tbRcptM'),false)}

// ---------- cards, dice, reels ----------
const cgDiceHTML=d=>(d||[]).map(f=>`<i class="die">${'<s></s>'.repeat(f)}</i>`).join('');
const CG_PIP_HTML=f=>`<i class="die d${f}">${'<s></s>'.repeat(f)}</i>`;
function cgDiceNow(v){if(!v||!v.dice)return null;if(cgLeft(v)>0){const t=Math.floor(performance.now()/90);return[1+t%6,1+(t*7+3)%6]}return v.dice}
function cgBacShown(v){if(!v||!v.P||v.phase!=='done')return{P:[],B:[]};const n=v.order.length,left=cgLeft(v),k=left<=0?n:Math.max(0,Math.min(n,n-Math.ceil((left-300)/700)));
  const o={P:[],B:[]};v.order.slice(0,k).forEach(([s,i])=>o[s].push((s==='P'?v.P:v.B)[i]));if(v===TB.v)cgSound(v,k,'cas_card');return o}
const CG_SYM={P:'PALI',C:'CORE',W:'WALL',H:'HELM',N:'NADE',S:'◆',X:''},CG_SYM_COL={P:'#ffd24a',C:'#3ae0ff',W:'#d0603a',H:'#9ab0c0',N:'#7ad04a',S:'#9fd8ff',X:'#2a2a33'};
function cgReels(win,stopped,final){let h='';for(let i=0;i<3;i++){const w=win[i];h+=`<div class="slreel${i<stopped?'':' spin'}">${w.map((x,r)=>`<b class="sy ${x}${r===1&&final?' line':''}">${CG_SYM[x]}</b>`).join('')}</div>`}return h}
const CG_STRIPS=['SWNXHSWNSPWXNSHWCNSX','SWXNHXWNSPWXNXHWCNSX','SWXNHXWNXPWXNXHWCNSX'];
// what your own machine shows right now (the felt and the cabinet in the world): reels turning until each one's stop
function cgSlotWindow(v){const r=v&&v.last&&v.last.result;if(!r||!r.window)return{win:[['S','P','W'],['W','P','N'],['N','P','S']],stopped:3};
  const left=cgLeft(v),el=2600-left,stops=[1400,2000,2600],stopped=left<=0?3:stops.filter(t=>el>=t).length;if(v===TB.v)cgSound(v,stopped,'cas_reel');
  const t=Math.floor(performance.now()/70),win=r.window.map((w,i)=>i<stopped?w:[0,1,2].map(q=>CG_STRIPS[i][(t+q+i*7)%20]));return{win,stopped}}
function cgSlotLine(){const w=cgSlotWindow(TB.v).win;return w.map(x=>x[1])}
// the Plinko ball for the board in the world (yours, or the one you're watching)
function cgPlinkoBall(){const v=casView('pk','p1');const r=v&&v.last&&v.last.result;if(!r||!r.path||v.phase!=='done')return null;const left=cgLeft(v);return{path:r.path,step:left<=0?12.5:(3100-left)/3100*12.5}}

// ---------- BACCARAT ----------
CG.ba={info:v=>'8 decks · Banker in 20s (pays 19:20) · Tie 8:1'+(v.shoe?` · shoe #${v.shoe.no}, ${v.shoe.left} cards left`:''),
  key:(v,me)=>[CGS.chip.ba,CGS.ba.bets,v.readyMe,v.minBetAt>0,me.stack],
  sync(v){const S=CGS.ba;if(v.handNo!==S.hand&&v.phase==='bet'){if(S.hand>=0&&tbSum(S.bets))S.last={...S.bets};S.hand=v.handNo;S.bets={};S.sent=''}
    if(v.phase!=='bet'){S.bets={...(v.myBets||{})};return}if(!S.dirty&&!S.inflight&&performance.now()-S.at>2000)S.bets={...(v.myBets||{})}},
  status(v,me){const tot=tbSum(CGS.ba.bets);if(v.phase==='bet')return v.readyMe?['READY',`${v.readyN} ready · the cards come when everyone is (at least 5 s after the bets open) or in ${tbSecs(v)}s`,'wait']:['PLACE YOUR BETS',(tot?tot+'◆ down · ':'')+`Player, Banker or Tie · ${tbSecs(v)}s`,'you'];
    if(v.phase==='done'){if(cgLeft(v)>0)return['DEALING','Player first, then Banker; third cards by the rules','wait'];const p=mineOf(v.last.result);return[cgVerdict(p)||'HAND OVER',v.last.result.why,'done']}
    return['WAITING','The next hand opens in a moment','wait']},
  felt(v,me){CG.ba.sync(v);const S=CGS.ba,open=v.phase==='bet'&&!v.readyMe,road=(v.road||[]).slice(-36).map(x=>`<b class="${x}">${x}</b>`).join('');
    const sh=cgBacShown(v),tot=a=>a.reduce((s,c)=>s+((c%52%13)<=7?(c%52%13)+2:(c%52%13)===12?1:0),0)%10;
    const lr=v.phase!=='done'&&v.last&&v.last.result&&v.last.result.player?v.last.result:null;
    const hand=(nm,cs,old)=>`<div class="bahand${old?' old':''}"><b>${nm}${cs.length?' '+tot(cs):''}</b><div class="tcards">${cs.length?cs.map(tbCard).join(''):tbCard(null)+tbCard(null)}</div></div>`;
    const others={};for(const[si,b]of Object.entries(v.bets||{}))if(+si!==v.me)for(const k in b)others[k]=(others[k]||0)+b[k];
    const spot=(k,nm,pay)=>`<button type="button" class="baspot ${k}" data-cg="ba:${k}"${open?'':' disabled'}><b>${nm}</b><small>${pay}</small>${S.bets[k]?rlChipH(S.bets[k]):''}${others[k]?`<em>others ${others[k]}◆</em>`:''}</button>`;
    return `<div class="rhist baroad"><span>ROAD (what happened, not a forecast)</span>${road||'<em>none yet</em>'}</div>
<div class="bahands">${lr?hand('PLAYER',lr.player,1)+hand('BANKER',lr.banker,1):hand('PLAYER',sh.P)+hand('BANKER',sh.B)}</div>
<div class="baspots">${spot('P','PLAYER','1:1')}${spot('T','TIE','8:1')}${spot('B','BANKER','19:20 · in 20s')}</div>
<p class="tbHint">Banker bets go in 20s: 20 on Banker pays 19 plus your 20 back. A tie returns Player and Banker bets.</p>`},
  acts(v,me){const S=CGS.ba,tot=tbSum(S.bets),lastT=tbSum(S.last);if(v.phase!=='bet')return `<p class="tbHint">${v.phase==='done'?'Next bets open after the result.':'Betting opens in a moment.'}</p>`;
    if(v.readyMe)return `<p class="tbHint">You're in with ${tbSum(v.myBets)}◆. Cards when everyone's ready, or in ${tbSecs(v)}s.</p>`;
    return `<div class="trow chips">${[5,10,20,50,100,500].map(a=>tbBtn('chip:'+a,rlChipH(a),{cl:CGS.chip.ba===a?'sel':'',on:a<=me.stack+tot})).join('')}</div>
<div class="trow">${tbBtn('clear','CLEAR',{on:tot>0})}${tbBtn('rebet','REBET',{on:lastT>0&&lastT<=me.stack+tot,hint:lastT?lastT+'◆':''})}</div>
<div class="trow">${tbBtn('ready','DEAL',{cl:'go big',on:tot>0,hint:tot?tot+'◆ down'+(v.minBetAt>0?' · cards no sooner than '+Math.ceil(v.minBetAt/1000)+'s':''):'place a bet first'})}</div>`},
  spot(k){const v=TB.v,S=CGS.ba;if(!v||v.phase!=='bet'||v.readyMe)return;const me=v.seats[v.me],free=me.stack+tbSum(v.myBets)-tbSum(S.bets);let add=CGS.chip.ba;
    if(k==='B')add=Math.max(20,Math.ceil(add/20)*20);if(add>free){toast('BACCARAT',k==='B'&&free>=1?'Banker bets go in 20s: top up for 20':'Not enough shards at the table: top up');return}S.bets[k]=(S.bets[k]||0)+add;CG.ba.queue()},
  queue(){const S=CGS.ba;S.dirty=1;S.at=performance.now();TB.key='';if(TB.v)tbShow(TB.v);clearTimeout(S.t);S.t=setTimeout(CG.ba.flush,260)},
  async flush(){const S=CGS.ba;if(!TB.id||!S.dirty)return;S.dirty=0;S.inflight=1;const want={...S.bets};const r=await tbSend({op:'babets',id:TB.id,bets:want},true).finally(()=>{S.inflight=0;S.at=performance.now()});
    if(r&&r.error){toast('BACCARAT',r.error);if(TB.v)S.bets={...(TB.v.myBets||{})}}if(TB.v){TB.key='';tbShow(TB.v)}},
  act(a,v,me){const S=CGS.ba;if(a.startsWith('chip:')){CGS.chip.ba=+a.slice(5);TB.key='';tbActions(v,me);return}
    if(a==='clear'){S.bets={};CG.ba.queue();return}if(a==='rebet'){S.bets={...S.last};CG.ba.queue();return}
    if(a==='ready'){clearTimeout(S.t);(async()=>{if(S.dirty)await CG.ba.flush();tbSend({op:'baready',id:TB.id})})()}}};
const tbSum=o=>Object.values(o||{}).reduce((a,x)=>a+(x|0),0);

// ---------- CRAPS ----------
const CR_PTS=[4,5,6,8,9,10],CR_ODDS_D={4:1,5:2,6:5,8:5,9:2,10:1},CR_LAY_D={4:2,5:3,6:6,8:6,9:3,10:2},CR_MULT_C={4:3,5:4,6:5,8:5,9:4,10:3};
// the smallest step a bet can move by (so its payout is whole shards)
function crDen(k,point){if(/^p(5|9|4|10)$/.test(k))return 5;if(/^p(6|8)$/.test(k))return 6;if(k==='po')return CR_ODDS_D[point]||1;if(k==='dpo')return CR_LAY_D[point]||1;
  const m=/^([cd])(\d+)o$/.exec(k);if(m)return(m[1]==='c'?CR_ODDS_D:CR_LAY_D)[m[2]]||1;return 1}
CG.cr={info:v=>(v.point?'point '+v.point:'come-out')+' · shooter '+(v.shooter>=0&&v.seats[v.shooter]?v.seats[v.shooter].name:'the dealer')+' · odds 3-4-5x',
  key:(v,me)=>[CGS.chip.cr,CGS.cr.adv,CGS.cr.down,v.readyMe,v.amShooter,v.point,v.myBets,v.flags,me.stack,v.minBetAt>0],
  status(v,me){if(v.phase==='bet'){const n=tbSum(v.myBets),sh=v.amShooter?'You have the dice: ROLL when your bets are down':v.shooter>=0&&v.seats[v.shooter]?v.seats[v.shooter].name+' shoots':'The dealer shoots';
      return v.readyMe?['READY',`${v.readyN} ready · the dice go when everyone is (at least 5 s after betting opens) or in ${tbSecs(v)}s`,'wait']:[v.point?'POINT IS '+v.point:'COME-OUT ROLL',`${sh} · ${n?n+'◆ on the layout · ':''}${tbSecs(v)}s`,'you']}
    if(v.phase==='done'){if(cgLeft(v)>0)return['ROLLING','The dice are in the air','wait'];const r=v.last.result,p=mineOf(r);return[(p?cgVerdict(p):'')||'THE DICE: '+r.total,r.why,'done']}
    return['WAITING','Betting opens in a moment','wait']},
  felt(v,me){const B=v.myBets||{},P=v.point,open=v.phase==='bet'&&!v.readyMe,lock=new Set(v.locked||[]);
    const d=cgDiceNow(v),hist=(v.rolls||[]).slice(-14).reverse().map(([a,b],i)=>`<b class="${a+b===7?'r':[2,3,12].includes(a+b)?'g':''}">${a+b}</b>`).join('');
    const can=k=>{if(!open)return false;if(k==='pass')return !P;if(k==='come'||k==='dc')return !!P;if(k==='po')return !!P&&B.pass>0;if(k==='dpo')return !!P&&B.dp>0;if(/^[cd]\d+$/.test(k))return false;
      const m=/^([cd])(\d+)o$/.exec(k);if(m)return !!B[m[1]+m[2]];return true};
    const btn=(k,nm,pay,cls='')=>{const a=B[k]|0,dn=CGS.cr.down;const on=dn?a>0&&!lock.has(k)&&!(k==='pass'&&P):can(k);
      return `<button type="button" class="crspot ${cls}${a?' has':''}" data-cg="cr:${k}"${on?'':' disabled'}><b>${nm}</b><small>${pay}</small>${a?rlChipH(a):''}${lock.has(k)&&a?'<i class="lk">LOCKED</i>':''}</button>`};
    const pts=CR_PTS.map(n=>`<div class="crpt${P===n?' on':''}"><b>${n}</b>${B['c'+n]?`<span>COME ${B['c'+n]}◆</span>`+btn('c'+n+'o','+ ODDS',(CR_ODDS_D[n]>1?'in '+CR_ODDS_D[n]+'s':'2:1'),'mini'):''}${B['d'+n]?`<span>DON'T ${B['d'+n]}◆</span>`+btn('d'+n+'o','+ LAY',(CR_LAY_D[n]>1?'in '+CR_LAY_D[n]+'s':''),'mini'):''}</div>`).join('');
    const F=v.flags||{},tog=(k,nm)=>`<button type="button" class="crtog${F[k]?' on':''}" data-cg="crf:${k}">${nm}: ${F[k]?'ON':'OFF'}</button>`;
    let h=`<div class="crtop"><div class="crpuck ${P?'on':''}">${P?'ON<b>'+P+'</b>':'OFF'}</div><div class="crdice">${d?d.map(CG_PIP_HTML).join(''):'<span class="tbHint">no roll yet</span>'}</div><div class="rhist crhist"><span>ROLLS</span>${hist||'<em>none</em>'}</div></div>
<div class="crpts">${pts}</div>
<div class="crgrid">${btn('pass','PASS LINE',P?'locked while the point is on':'1:1','wide')}${btn('dp','DON\'T PASS','1:1 · bar 12','wide')}
${P?btn('po','PASS ODDS','up to '+CR_MULT_C[P]+'x · '+({4:'2:1',10:'2:1',5:'3:2',9:'3:2',6:'6:5',8:'6:5'}[P])):''}${P?btn('dpo','LAY ODDS','up to 6x'):''}
${btn('come','COME','1:1 · point on')}${btn('dc','DON\'T COME','1:1 · bar 12')}
${btn('field','FIELD','2,3,4,9,10,11 1:1 · 2,12 2:1','wide')}${btn('p6','PLACE 6','7:6 · in 6s')}${btn('p8','PLACE 8','7:6 · in 6s')}</div>`;
    if(CGS.cr.adv)h+=`<div class="crgrid adv">${[4,5,9,10].map(n=>btn('p'+n,'PLACE '+n,(n===4||n===10?'9:5':'7:5')+' · in 5s')).join('')}${[4,6,8,10].map(n=>btn('h'+n,'HARD '+n,n===4||n===10?'7:1':'9:1')).join('')}
${btn('any7','ANY 7','4:1')}${btn('anyc','ANY CRAPS','7:1')}${btn('n2','TWO','30:1')}${btn('n3','THREE','15:1')}${btn('n11','ELEVEN','15:1')}${btn('n12','TWELVE','30:1')}</div>`;
    h+=`<div class="trow crtogs">${tog('place','PLACE ON COME-OUT')}${tog('hard','HARDWAYS ON COME-OUT')}${tog('codds','COME ODDS ON COME-OUT')}</div>`;
    const others=Object.entries(v.bets||{}).filter(([si])=>+si!==v.me).map(([si,b])=>`${cgEsc((v.seats[si]||{name:'?'}).name)}${v.gone&&v.gone[si]?' (left)':''} ${tbSum(b)}◆`).join(' · ');
    if(others)h+=`<p class="tbHint">On the layout: ${others}</p>`;return h},
  acts(v,me){const tot=tbSum(v.myBets);if(v.phase!=='bet')return `<p class="tbHint">${v.phase==='done'?'Betting opens after the result.':'Betting opens in a moment.'}</p>`;
    return `<div class="trow chips">${[1,5,10,25,100].map(a=>tbBtn('chip:'+a,rlChipH(a),{cl:CGS.chip.cr===a?'sel':''})).join('')}</div>
<div class="trow">${tbBtn('down',CGS.cr.down?'TAKING DOWN: ON':'TAKE DOWN',{cl:CGS.cr.down?'sel':'',hint:'tap a bet to take it off'})}${tbBtn('adv',CGS.cr.adv?'SIMPLE LAYOUT':'ALL BETS',{hint:CGS.cr.adv?'line, field, place 6/8':'place, hardways, props'})}</div>
<div class="trow">${v.readyMe?`<p class="tbHint">Ready. The dice go when everyone is, or in ${tbSecs(v)}s.</p>`:tbBtn('ready',v.amShooter?'ROLL':'READY',{cl:'go big',on:tot>0||v.amShooter,hint:(v.amShooter?'you have the dice':'done betting')+(v.minBetAt>0?' · no sooner than '+Math.ceil(v.minBetAt/1000)+'s':'')})}</div>`},
  spot(k){const v=TB.v;if(!v||v.phase!=='bet')return;const B=v.myBets||{},cur=B[k]|0,dn=crDen(k,v.point);let amt;
    if(CGS.cr.down)amt=0;else{amt=cur+Math.max(dn,Math.ceil(CGS.chip.cr/dn)*dn);
      if(k==='po')amt=Math.min(amt,CR_MULT_C[v.point]*(B.pass|0));if(k==='dpo')amt=Math.min(amt,6*(B.dp|0));const m=/^([cd])(\d+)o$/.exec(k);if(m)amt=Math.min(amt,(m[1]==='c'?CR_MULT_C[m[2]]:6)*(B[m[1]+m[2]]|0));
      amt-=amt%dn;if(amt<=cur){toast('CRAPS','That bet is at its limit');return}}
    CGS.cr.q=CGS.cr.q.then(()=>tbSend({op:'crbet',id:TB.id,k,amt},true)).then(r=>{if(r&&r.error)toast('CRAPS',r.error)})},
  act(a,v,me){if(a.startsWith('chip:')){CGS.chip.cr=+a.slice(5);TB.key='';tbActions(v,me);return}
    if(a==='down'){CGS.cr.down=!CGS.cr.down;TB.key='';$('tbFelt')._h='';tbShow(v);return}if(a==='adv'){CGS.cr.adv=!CGS.cr.adv;TB.key='';$('tbFelt')._h='';tbShow(v);return}
    if(a==='ready')CGS.cr.q=CGS.cr.q.then(()=>tbSend({op:'crready',id:TB.id},true))},
  flag(k){const v=TB.v;if(!v)return;const F={...(v.flags||{})};F[k]=!F[k];tbSend({op:'crflags',id:TB.id,flags:F},true)}};

// ---------- SLOTS ----------
CG.sl={info:()=>'PALISADE RUN · 1-100 a spin · one line · returns 96.03%',key:(v,me)=>[CGS.sl.amt,v.phase,me.stack,cgLeft(v)>0],
  status(v,me){if(v.phase==='done'){if(cgLeft(v)>0)return['SPINNING','Reels stop left to right','wait'];const r=v.last.result;return[r.mult?'WIN':'LOSS',r.why,'done']}
    return me.stack<1?['TOP UP','Add shards to the machine (+5, +25 or +100 below)','warn']:['PLACE A BET AND SPIN',`${CGS.sl.amt}◆ a spin · the line pays the single highest award`,'you']},
  felt(v){const w=cgSlotWindow(v),r=v.last&&v.last.result,done=w.stopped===3&&r&&v.phase==='done'&&cgLeft(v)<=0;if(done&&r.mult&&v===TB.v)cgSound(v,4,'cas_win');
    return `<div class="slcab"><div class="slwin${done&&r.mult?' won':''}">${cgReels(w.win,w.stopped,w.stopped===3)}</div><div class="slpay">${done?(r.mult?`<b>${cgEsc(r.combo)} · ${r.mult}x · +${r.players[0].back}◆</b>`:'<b class="l">NO WIN</b>'):'<b>&nbsp;</b>'}</div></div>
<details class="slpt"><summary>PAYTABLE (gross, your stake included)</summary><table>${[['PALI PALI PALI',250],['CORE CORE CORE',60],['WALL WALL WALL',25],['HELM HELM HELM',15],['NADE NADE NADE',10],['◆ ◆ ◆',6],['ANY THREE OF WALL / HELM / NADE',3],['◆ ◆ on reels 1-2',2],['◆ on reel 1 (your stake back)',1]].map(([a,b])=>`<tr><td>${a}</td><td>${b}x</td></tr>`).join('')}</table>
<p class="tbHint">20 stops a reel, each one as likely as the next: 8,000 combinations. The line pays on 37.5% of them, more than your stake on 16.3% (the rest of the 37.5% give the stake back); return 96.03% (math sl-1). Every spin is on its own: past spins, your balance and your account change nothing. The reels stop where the server's numbers say; the symbols above and below are the real reel.</p></details>`},
  acts(v,me){const busy=v.phase!=='idle';const am=CGS.sl.amt;return `<div class="tbet">${tbBtn('amt-','−',{on:am>1})}<div class="tamt"><b>${am}</b><span>shards a spin</span></div>${tbBtn('amt+','+',{on:am<100})}</div>
<div class="trow chips">${[1,5,10,25,50,100].map(a=>tbBtn('set:'+a,String(a),{cl:am===a?'sel':''})).join('')}</div>
<div class="trow">${tbBtn('spin',busy?'…':'SPIN '+am+'◆',{cl:'go big',on:!busy&&me.stack>=am,hint:busy?'the result stays up 3 s after the last reel':me.stack<am?'top up to spin':'one spin per press'})}</div>`},
  act(a,v,me){if(a==='amt-'||a==='amt+'){CGS.sl.amt=Math.max(1,Math.min(100,CGS.sl.amt+(a==='amt+'?1:-1)));TB.key='';tbActions(v,me);return}
    if(a.startsWith('set:')){CGS.sl.amt=+a.slice(4);TB.key='';tbActions(v,me);return}
    if(a==='spin'&&v.phase==='idle'){if(typeof uiSfx==='function')uiSfx('cas_lever');tbSend({op:'spin',id:TB.id,amt:CGS.sl.amt})}}};

// ---------- PLINKO ----------
const PK_MULT_D=[300,90,30,15,12,6,5,6,12,15,30,90,300];
CG.pk={info:()=>'12 rows · stakes in 10s · 0.5x to 30x · returns 96.01%',key:(v,me)=>[CGS.pk.amt,v.phase,me.stack,cgLeft(v)>0],
  status(v,me){if(v.phase==='done'){if(cgLeft(v)>0)return['DROPPING','Twelve bounces, decided before the ball moved','wait'];const r=v.last.result,p=r.players[0];return[p.net>0?'WIN':p.net<0?'LOSS':'PUSH',r.why+(r.mult<1?' (less than your stake: a loss, though some shards come back)':''),'done']}
    return me.stack<10?['TOP UP','Plinko needs at least 10 shards at the board (+5, +25 or +100 below)','warn']:['PICK A STAKE AND DROP',`${CGS.pk.amt}◆ · stakes go in 10s so every pocket pays whole shards`,'you']},
  felt(v){const r=v.last&&v.last.result,done=v.phase==='done'&&cgLeft(v)<=0;
    return `<canvas id="cgPk" width="360" height="300" aria-label="Plinko board"></canvas><div class="pkrow">${PK_MULT_D.map((m,k)=>`<b class="${m>=90?'hi':m>=30?'md':m>=10?'lo':'bl'}${done&&r&&r.pocket===k?' hit':''}">${m/10}x</b>`).join('')}</div>
<p class="tbHint">Each bounce is 50/50, so the middle pockets are the likeliest (pocket 7: 22.6%) and the edges the rarest (1 in 4,096 each). 1x returns your stake; under 1x some shards come back but it's a loss. Returns 96.01% (math pk-1).</p>`},
  // v0.10.3: the ball is drawn from the latest view (TB.v), not the one that made the canvas. The poll brings a new view every
  // second while the board's HTML stays the same, so the canvas isn't rebuilt; tied to its first view, the ball froze mid-drop.
  after(){const c=$('cgPk');if(!c)return;const x=c.getContext('2d'),W=c.width,H=c.height,rows=12,top=24,dy=(H-70)/rows,px=(r,k)=>W/2+(k-r/2)*(W*.84/12),py=r=>top+r*dy;
    const draw=()=>{x.clearRect(0,0,W,H);x.fillStyle='#e8e0cf';for(let r=0;r<=rows;r++)for(let k=0;k<=r;k++){x.beginPath();x.arc(px(r,k),py(r),2.4,0,7);x.fill()}
      const v=TB.v;if(!v||v.game!=='pk')return false;const r0=v.last&&v.last.result;if(!r0||!r0.path)return false;const left=cgLeft(v),f=v.phase==='done'?(left<=0?rows:(3100-left)/3100*rows):rows;
      const rr=Math.min(rows,Math.floor(f)),fr=f-rr,col=r0.path.slice(0,rr).reduce((a,b)=>a+b,0),nx=col+(r0.path[rr]||0);cgSound(v,rr,'cas_peg');
      const bx=rr>=rows?px(rows,col):px(rr,col)+(px(rr+1,nx)-px(rr,col))*fr,by=rr>=rows?py(rows)+10:py(rr)+(py(rr+1)-py(rr))*fr-dy*.35*Math.sin(fr*Math.PI);
      x.fillStyle='#ffd24a';x.beginPath();x.arc(bx,by-6,6,0,7);x.fill();return left>0};
    cancelAnimationFrame(CG.pk.raf);const loop=()=>{if(c.isConnected&&draw())CG.pk.raf=requestAnimationFrame(loop)};loop()},
  acts(v,me){const busy=v.phase!=='idle',am=CGS.pk.amt;return `<div class="trow chips">${[10,20,50,100,250,500].map(a=>tbBtn('set:'+a,String(a),{cl:am===a?'sel':''})).join('')}</div>
<div class="trow">${tbBtn('drop',busy?'…':'DROP '+am+'◆',{cl:'go big',on:!busy&&me.stack>=am,hint:busy?'the result stays up 3 s after the ball lands':me.stack<am?'top up to drop':'one ball per press'})}</div>`},
  act(a,v,me){if(a.startsWith('set:')){CGS.pk.amt=+a.slice(4);TB.key='';tbActions(v,me);return}if(a==='drop'&&v.phase==='idle'){if(typeof uiSfx==='function')uiSfx('cas_chip');tbSend({op:'drop',id:TB.id,amt:CGS.pk.amt})}}};

// ---------- taps on the felt (bet spots, toggles): on release, from where you pressed (a poll can redraw in between) ----------
let cgDown=null;
$('tbFelt').addEventListener('pointerdown',e=>{cgDown=e.isPrimary?{x:e.clientX,y:e.clientY,t:performance.now()}:null});
function cgTap(el){const b=el&&el.closest&&el.closest('[data-cg]');if(!b||b.disabled)return;const [g,k]=b.dataset.cg.split(':');
  if(g==='ba')CG.ba.spot(k);else if(g==='cr')CG.cr.spot(k);else if(g==='crf')CG.cr.flag(k)}
$('tbFelt').addEventListener('pointerup',e=>{const d=cgDown;cgDown=null;if(!d||performance.now()-d.t>700||Math.hypot(e.clientX-d.x,e.clientY-d.y)>12)return;const el=document.elementFromPoint(d.x,d.y);if(el&&el.closest('[data-cg]'))cgTap(el)});
$('tbFelt').addEventListener('click',e=>{if(e.detail===0)cgTap(e.target)});   // keyboard and controller: a click with no pointer
$('tbLastBtn').addEventListener('click',tbLastResult);$('tbDoorLast').addEventListener('click',tbLastResult);
$('tbRcptM').addEventListener('click',e=>{if(e.target===$('tbRcptM')||e.target.closest('[data-close]'))hid($('tbRcptM'),true)});
try{if(sessionStorage.getItem('pal_rcpt')){hid($('tbLastBtn'),false);hid($('tbDoorLast'),false)}}catch(e){}
