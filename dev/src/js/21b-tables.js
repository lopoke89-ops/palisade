/* ================= v0.9.8 THE TABLES: Blackjack and Texas Hold'em for shards ================= */
// The server deals and decides everything (the `tables` edge function, dev/supabase/functions/tables). This page only
// shows what the server says this player may see, and sends moves. It polls once a second while you're seated.
// v0.9.8.1: a status line that always says what's happening and what to do, a bet stepper, a raise slider, READY between
// hands, the host's START, and a How to play panel.
// v0.10.0: the tables are in THE PALISADE FALLS CASINO (06f-casino.js). You sit by walking up to a seat; the table opens in
// a sheet over the casino floor. Roulette (American, always no limit); your own seed; hand history with the check, run here
// in the browser; the house rules. The TABLES page is the front door.
const TB={id:0,code:'',v:null,busy:false,lobbyT:0,amt:2,raise:0,balance:0,key:'',sheet:false,mine:null,
  peek:{},peekT:0,rl:{chip:5,bets:{},sent:'',dirty:0,last:{},hand:-1}};
const TB_SUIT=['♣','♦','♥','♠'],TB_RANK=['2','3','4','5','6','7','8','9','10','J','Q','K','A'];
const tbCard=c=>c===null||c===undefined?'<span class="tcard back"></span>':`<span class="tcard${(c%52/13|0)===1||(c%52/13|0)===2?' red':''}">${TB_RANK[c%52%13]}<i>${TB_SUIT[c%52/13|0]}</i></span>`;
const tbEsc=s=>String(s).replace(/[&<>"]/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;'}[c]));
const TB_NAME={bj:'BLACKJACK',he:'TEXAS HOLD\'EM',rl:'ROULETTE'};
const TB_HELP={bj:`<p><b>Goal:</b> finish closer to 21 than the dealer without going over. Number cards count their number, J/Q/K count 10, an ace counts 1 or 11.</p>
<p><b>Each hand:</b> place a bet (60 seconds; the cards come as soon as everyone has bet). You get two cards; the dealer shows one.</p>
<p><b>HIT</b> takes a card. <b>STAND</b> keeps what you have. <b>DOUBLE</b> doubles your bet for exactly one more card. <b>SPLIT</b> turns a pair into two hands (one more bet).</p>
<p><b>Pays:</b> a win pays 1:1, blackjack (ace + a 10 card) pays 3:2, a tie gets your bet back. The dealer stands on 17. If the dealer shows an ace you can buy <b>insurance</b> (half your bet, pays 2:1 if the dealer has blackjack).</p>
<p>4 decks, shuffled fresh every hand. No clock while you play.</p>`,
he:`<p><b>Goal:</b> make the best five-card hand from your two cards and the five shared cards, or make everyone else fold.</p>
<p><b>Each hand:</b> two players post blinds (1 and 2 shards). Then four rounds of betting: after your cards, after the flop (3 shared cards), the turn (4th) and the river (5th).</p>
<p>On your turn: <b>FOLD</b> (give up the hand), <b>CHECK</b> (pass, if nobody has bet), <b>CALL</b> (match the bet), <b>RAISE / BET</b> (put in more), <b>ALL IN</b> (everything at the table).</p>
<p><b>Hands, low to high:</b> high card, pair, two pair, three of a kind, straight, flush, full house, four of a kind, straight flush.</p>
<p>The house takes 1.8% of pots that reach the flop (6 shards at most). Between hands there's a 60-second break; it deals as soon as everyone taps READY. No clock while you play.</p>`,
rl:`<p><b>Goal:</b> guess where the ball lands. The wheel has 38 pockets: 1 to 36 (red or black), 0 and 00 (green).</p>
<p><b>Each spin:</b> 60 seconds to bet. Pick a chip, then tap the board: a number, the line between two numbers (split), the bottom edge of a column of three (street), a corner of four, the bottom corner between two streets (six line), or the outside boxes. Tap again to add another chip. The ball goes as soon as everyone with a bet taps SPIN.</p>
<p><b>Pays:</b> a number 35:1, split 17:1, street 11:1, corner 8:1, the top line (0, 00, 1, 2, 3) 6:1, six line 5:1, a dozen or a column 2:1, red/black, odd/even, 1-18/19-36 1:1. 0 and 00 lose every outside bet.</p>
<p>No limit: bet anything you have at the table.</p>`};
// the house rules (the TABLES page and the sheet both show them)
const TB_RULES=`<h4>THE HOUSE</h4><p>Every table is run by the server: it shuffles, deals, spins and pays. Your screen only shows what the server says you may see.</p>
<h4>WHAT THE HOUSE KEEPS</h4><ul><li><b>Blackjack:</b> about 0.5% of what's bet with perfect play (4 decks, dealer stands on 17, blackjack pays 3:2).</li>
<li><b>Hold'em:</b> 1.8% of pots that reach the flop, 6 shards at most. Nothing from pots that end before the flop.</li>
<li><b>Roulette:</b> the American double-zero wheel keeps 5.26% of every bet (2 pockets in 38); the top line (0, 00, 1, 2, 3) keeps 7.89%.</li>
<li><b>Side bets:</b> 1 shard a hand.</li></ul><p>What the house keeps is gone: it isn't paid to anyone. Shards can never be bought or cashed out.</p>
<h4>FAIR PLAY</h4><p>Before every hand or spin the server shows the fingerprint (SHA-256) of its secret seed. Your own seed (set it under FAIR PLAY at the table) and everyone else's are mixed in when the round starts, so nobody, the server included, can pick the cards. After the round the seed is revealed and anyone can rerun the shuffle or the spin: HAND HISTORY does it for you, right in your browser.</p>
<p>In Hold'em each card has its own fingerprint, so you can check the cards you saw without anyone seeing a folded hand. The seed and the whole deck show in your history after 24 hours.</p>
<h4>THE BOOKS</h4><p>Every day the server checks every table that closed: shards brought in minus shards taken home must equal what the house kept plus what was lost to the bot, to the shard.</p>
<h4>AT THE TABLE</h4><ul><li>The buy-in is 5 shards. Top up between hands. Standing up sends what's in front of you back to your balance.</li>
<li>Sit out 3 hands, or close the game for a minute, and you're stood up (your shards go home).</li>
<li>Blackjack and Hold'em: up to 5 and 6 players; the first to sit sets the table's limit and side bet and starts it. Roulette: up to 6, always no limit, nothing to start.</li>
<li>A bot sits in at Hold'em when there are only two of you; it never sees anyone's cards.</li></ul>`;
async function tbCall(body){
  if(!await freshToken())return{error:'Sign in to play at the tables'};
  let r=await sbFetch('/functions/v1/tables',{method:'POST',body,timeout:12000});
  if(r.status===401&&acct.s){acct.s.expires_at=0;if(await freshToken())r=await sbFetch('/functions/v1/tables',{method:'POST',body,timeout:12000})}
  if(!r.j)return{error:r.status?'The tables are busy. Try again.':'No connection'};return r.j}
const tbMsg=t=>{txt($('tbMsg'),t||'');txt($('tbSheetMsg'),t||'')};
function tbCanPlay(){if(!cloudOn)return 'The tables need the online version of the game.';if(!acct.s)return 'Sign in to play at the tables.';
  if(isGuest())return 'Make an account on the Account page to play at the tables. Guests can\'t.';return null}
// ---------- the front door (the TABLES page) ----------
function renderTables(){const no=tbCanPlay();$('casEnterBtn').disabled=$('tbJoinBtn').disabled=!!no;tbMsg(no||'');
  const m=TB.mine;hid($('tbMine'),!m||casino());if(m)txt($('tbMine').firstChild,`You're still seated at the ${TB_NAME[m.game]||'casino'} table from before. Stand up to take your shards home.`);
  if(!no)tbLobby()}
async function tbLobby(){if(TB.busy||tbCanPlay())return;TB.lobbyT=performance.now();const r=await tbCall({op:'lobby'});if(r.error){tbMsg(r.error);return}
  TB.balance=r.balance;txt($('tbBal'),String(r.balance));TB.mine=r.mine||null;hid($('tbMine'),!TB.mine||casino());
  if(TB.mine)txt($('tbMine').firstChild,`You're still seated at the ${TB_NAME[TB.mine.game]||'casino'} table from before. Stand up to take your shards home.`)}
async function tbSend(body,quiet){if(TB.busy&&!quiet)return;if(!quiet)TB.busy=true;try{const r=await tbCall(body);
  if(r.error&&!r.view){tbMsg(r.error);if(/closed/.test(r.error))tbGone();return r}
  if(r.view){TB.id=r.id;TB.code=r.code;TB.balance=r.balance;tbShow(r.view);tbMsg(r.error||'')}
  if(body.op==='leave'&&r.view&&r.view.me<0){tbGone();if(typeof syncLocker==='function')syncLocker()}
  return r}finally{if(!quiet)TB.busy=false}}
// you're no longer at a table: off the seat in the casino, the sheet closed
function tbGone(){TB.id=0;TB.v=null;TB.key='';TB.rl.bets={};TB.rl.sent='';if(casino()&&player&&player.seat)player.seat=0;tbSheet(false)}
// ---------- sitting down (called from the casino when you walk up to a seat) ----------
async function tbSitAt(gm,k){const p=player;tbMsg('Taking a seat…');
  const r=await tbSend({op:'sit',room:casRoom(),game:gm,seat:k,seed:tbSeedPref()});
  if(!r||!r.view||r.view.me<0){if(p&&casino())p.seat=0;toast('TABLES',(r&&r.error)||'Could not sit down');return}
  if(p&&casino()){const t=casTable(gm),me=r.view.me;if(me!==k&&t&&t.seats[me]){const [x,y]=t.seats[me];p.x=x;p.y=y;p.seat=seatCode(t.n,me)}}   // the server gave you the next free seat
  TB.key='';tbSheet(true)}
const tbSeedPref=()=>{try{return localStorage.getItem('pal_seed')||''}catch(e){return ''}};
// the sheet: your table over the casino floor (HIDE keeps you seated; STAND UP takes your shards home)
function tbSheet(open){TB.sheet=!!open&&!!TB.id;hid($('casSheet'),!TB.sheet);if(TB.sheet&&TB.v){TB.key='';tbShow(TB.v)}}
// what's on a table in the casino: your own from your seat, the one you're standing next to from a peek
function casView(gm){if(TB.v&&TB.v.game===gm&&TB.id)return TB.v;const pk=TB.peek[gm];return pk&&performance.now()-pk.t<6000?pk.v:null}
async function tbPeek(gm){const r=await tbCall({op:'peek',room:casRoom(),game:gm});if(r&&!r.error)TB.peek[gm]={v:r.view,t:performance.now()}}
setInterval(()=>{if(document.hidden)return;
  if(casino()){if(TB.id){tbSend({op:'state',id:TB.id},true);return}
    if(!player||tbCanPlay()||performance.now()-TB.peekT<2000)return;TB.peekT=performance.now();   // standing: look at the nearest table every 2 s
    let best=null,bd=3.6;for(const t of CAS.tables){const d=Math.hypot(player.x-t.c[0],player.y-t.c[1]);if(d<bd){bd=d;best=t}}if(best)tbPeek(best.game);return}
  if(!$('menu').hidden&&!$('pg-tables').hidden&&performance.now()-TB.lobbyT>5000)tbLobby()},1000);
const tbSecs=v=>Math.ceil(v.left/1000);
// one line that says what's going on, and what you should do
function tbStatus(v,me){const P=v.players||[],cur=v.game==='bj'?(v.turn&&P[v.turn.p]):P.find(p=>p.turn),hum=v.seats.filter(s=>s&&!s.bot).length;
  if(v.game==='rl'){const n=Object.keys(v.myBets||{}).length,tot=rlTotalC(TB.rl.bets);
    if(v.phase==='bet')return v.readyMe?['READY',`${v.readyN} ready · the ball goes in ${tbSecs(v)}s at most`,'wait']:n||tot?['PLACE YOUR BETS',`${tot}◆ on the board · tap SPIN when you're done · ${tbSecs(v)}s`,'you']:['PLACE YOUR BETS',`Pick a chip and tap the board · ${tbSecs(v)}s`,'you'];
    if(v.phase==='spin')return['NO MORE BETS','The ball is spinning…','wait'];
    if(v.phase==='done'&&v.last&&v.last.result)return['IT\'S '+rlName(v.last.result.number),tbResult(v),'done'];
    return['WAITING','','wait']}
  if(!v.started)return v.host?['WAITING TO START',`${hum} seated. Press START when everyone's sat down.`+(v.game==='he'&&hum<2?' Hold\'em needs 2 players.':''),'wait']
    :['WAITING FOR '+(v.hostName||'THE HOST'),`${v.hostName} starts the table when everyone's sat down.`,'wait'];
  if(me.stack<(v.game==='bj'?1:2)&&v.phase!=='play')return['OUT OF SHARDS AT THE TABLE','Top up (+5 or +25 below) to keep playing, or stand up.','warn'];
  if(v.game==='bj'){
    if(v.phase==='bet')return v.bets&&v.bets[v.me]!==undefined?['BET PLACED',`Waiting for the others · cards in ${tbSecs(v)}s at most`,'wait']:['PLACE YOUR BET',`Pick an amount and press BET · ${tbSecs(v)}s left`,'you'];
    if(v.phase==='ins')return v.insure?['DEALER SHOWS AN ACE','Insurance costs half your bet and pays 2:1 if the dealer has blackjack. Most players say no.','you']:['INSURANCE','Waiting for the others to decide.','wait'];
    if(v.phase==='play'){if(v.myTurn){const h=cur.hands[v.turn.h];return['YOUR TURN',`You have ${h.total}${h.soft&&h.total<21?' (soft)':''} · the dealer shows ${v.dealerTotal}`+(cur.hands.length>1?` · hand ${v.turn.h+1} of ${cur.hands.length}`:''),'you']}
      return['WAITING',`${cur?cur.name:'The dealer'} is playing`,'wait']}
    return['DEALING','','wait']}
  if(v.phase==='wait')return['WAITING FOR PLAYERS','Hold\'em needs 2 players with at least 2 shards at the table.','wait'];
  if(v.phase==='play'){if(v.myTurn){const c=v.can;return['YOUR TURN',(c.call?`${c.call} to call`:'Nobody has bet: check or bet')+` · pot ${v.pot}`,'you']}return['WAITING',`${cur?cur.name:'…'} is thinking${cur&&cur.bot?' (bot)':''}`,'wait']}
  if(v.phase==='done')return['HAND OVER',(v.last&&v.last.result?tbResult(v)+' · ':'')+(v.readyMe?`You're ready · next hand in ${tbSecs(v)}s (or when everyone's ready)`:`Next hand in ${tbSecs(v)}s · tap READY to deal sooner`),'done'];
  return['','','wait']}
function tbShow(v){TB.v=v;
  if(v.me<0){tbGone();return}
  const me=v.seats[v.me];
  if(v.game==='rl')rlSync(v);
  if(!TB.sheet)return;   // seated with the sheet hidden: the felt in the world shows the table, the poll keeps the state
  txt($('tbTitle'),TB_NAME[v.game]);txt($('tbInfo'),v.game==='rl'?'american wheel · no limit':(v.lim?'max bet '+v.lim:'no limit')+(v.side?' · side bet on':'')+' · '+v.hostName+' started it');
  txt($('tbStack'),String(me.stack));txt($('tbBalT'),String(TB.balance));
  const [t,sub,kind]=tbStatus(v,me),stEl=$('tbStatus');stEl.className='tbStatus '+kind;txt(stEl.children[0],t);txt(stEl.children[1],sub);
  const tm=v.left>0&&v.phase!=='spin';$('tbTimer').hidden=!tm;if(tm)$('tbTimer').firstChild.style.transform=`scaleX(${Math.min(1,v.left/60000)})`;
  const seat=(s,inner,turn,tag)=>`<div class="tseat${s.me?' me':''}${turn?' turn':''}${s.bot?' bot':''}"><b>${tbEsc(s.name)}${s.me?' <i>YOU</i>':''}${tag||''}</b><span>${s.stack} ◆ at the table</span>${inner||''}</div>`;
  const lastBj=v.game==='bj'&&(v.phase==='bet'||!v.dealer)&&v.last&&v.last.result&&v.last.result.dealer?v.last.result:null;
  let felt='';
  if(v.game==='rl')felt=rlFelt(v);
  else if(v.game==='bj'){
    const dealer=v.dealer||(lastBj&&lastBj.dealer),dt=v.dealer?v.dealerTotal:lastBj&&lastBj.total;
    felt+=`<div class="tdealer${lastBj?' old':''}"><b>DEALER${lastBj?' · LAST HAND':''}</b><div class="tcards">${dealer?dealer.map(tbCard).join(''):tbCard(null)+tbCard(null)}</div><em>${dt?dt+(dt>21?' · BUST':''):''}</em></div>`;
    felt+='<div class="tseats">'+v.seats.filter(Boolean).map(s=>{const p=v.players&&v.players.find(p=>p.seat===s.i),b=v.bets&&v.bets[s.i],lp=lastBj&&lastBj.players.find(x=>x.name===s.name);
      let inner='';
      if(p)inner=p.hands.map((h,hi)=>`<div class="thand${v.turn&&v.turn.p>=0&&v.players[v.turn.p]===p&&v.turn.h===hi&&v.phase==='play'?' turn':''}"><div class="tcards">${h.cards.map(tbCard).join('')}</div><em><b>${h.total}</b>${h.soft&&h.total<21?' soft':''} · bet ${h.bet}◆${h.result?' · <u class="r'+(h.result==='WIN'||h.result==='BLACKJACK'?'w':h.result==='PUSH'?'p':'l')+'">'+h.result+'</u>':''}</em></div>`).join('');
      else if(v.phase==='bet')inner=`<em>${b!==undefined?'BET '+b+'◆ ✓':'choosing a bet…'}</em>${lp?`<em class="old">last hand: ${lp.net>0?'+':''}${lp.net}◆</em>`:''}`;
      return seat(s,inner,p&&v.turn&&v.players[v.turn.p]===p&&v.phase==='play')}).join('')+'</div>'}
  else{
    felt+=`<div class="tdealer"><b>POT ${v.pot||0} ◆</b><div class="tcards">${(v.board||[]).map(tbCard).join('')}${'<span class="tcard slot"></span>'.repeat(5-(v.board||[]).length)}</div><em>${['BEFORE THE FLOP','FLOP','TURN','RIVER'][v.street||0]||''}${v.toCall?' · bet to match '+v.toCall+'◆':''}</em></div>`;
    felt+='<div class="tseats">'+v.seats.filter(Boolean).map(s=>{const p=v.players&&v.players.find(p=>p.seat===s.i);
      const inner=p?`<div class="tcards">${p.cards.map(tbCard).join('')}</div><em>${p.folded?'FOLDED':p.allin?'ALL IN':p.bet?'bet '+p.bet+'◆':'·'}${p.put?' · in pot '+p.put+'◆':''}</em>`:'<em>not in this hand</em>';
      return seat(s,inner,p&&p.turn,s.bot?' <i>BOT</i>':'')}).join('')+'</div>'}
  if(v.phase==='done'&&v.last&&v.last.result&&v.game==='he')felt+=`<div class="tresult">${tbResult(v)}</div>`;
  $('tbFelt').innerHTML=felt;tbActions(v,me);
  $('tbLog').textContent=v.log.join(' · ');$('tbHelpTxt').innerHTML=TB_HELP[v.game];
  $('tbFairTxt').innerHTML=tbFairText(v);const si=$('tbSeedIn');if(document.activeElement!==si)si.value=v.seed||'';
  const pk=$('tbPick');pk.hidden=!(v.picks>0);if(v.picks>0){const hit=v.last&&v.last.sideHits&&v.last.sideHits.find(x=>x);txt($('tbPickWhy'),(hit?hit.why+'! ':'')+'Pick your prize.')}}
function tbFairText(v){const L=v.last,o=[];
  if(v.next)o.push(`<p>The server's seed for the next ${v.game==='rl'?'spin':'hand'} is locked in. Its fingerprint (SHA-256): <code>${tbEsc(v.next)}</code></p>`);
  if(v.fair&&v.fair!==v.next)o.push(`<p>This ${v.game==='rl'?'spin':'hand'}'s fingerprint: <code>${tbEsc(v.fair)}</code></p>`);
  o.push(`<p>Your seed <b>${tbEsc(v.seed||'')}</b> is mixed into every ${v.game==='rl'?'spin':'deal'} from the next one on. Change it whenever you like.</p>`);
  if(L&&L.result&&L.result.seeds)o.push(`<p>Last ${v.game==='rl'?'spin':'hand'} #${L.no}: ${L.seed?'seed <code>'+tbEsc(L.seed)+'</code>, ':''}players' seeds ${tbEsc(L.result.seeds.join(', '))}. <button type="button" data-hist>CHECK IT IN HAND HISTORY</button></p>`);
  return o.join('')}
function tbResult(v){const r=v.last.result;
  if(v.game==='rl'){const mine=r.players.find(p=>p.seat===v.me);return rlName(r.number)+(mine?' · you '+(mine.net>0?'won +'+mine.net+'◆':mine.net<0?'lost '+(-mine.net)+'◆':'broke even'):'')}
  if(v.game==='bj'){const mine=r.players.find(p=>p.name===v.seats[v.me].name);return 'Dealer '+r.total+(r.total>21?' (bust)':'')+(mine?' · you '+(mine.net>0?'won +':mine.net<0?'lost ':'broke even ')+(mine.net?Math.abs(mine.net)+'◆':''):'')}
  const ws=r.players.filter(p=>p.won>0);return ws.map(p=>tbEsc(p.name)+' wins '+p.won+'◆'+(p.hand?' with '+p.hand.toLowerCase():'')).join(' · ')+(r.rake?' · house '+r.rake+'◆':'')}
const tbBtn=(id,label,{on=true,cl='',hint=''}={})=>`<button type="button" data-act="${id}" class="${cl}"${on?'':' disabled'}>${label}${hint?`<small>${hint}</small>`:''}</button>`;
function tbActions(v,me){const box=$('tbActs'),c=v.can||{};
  // rebuilt only when something you can do changes, so the raise slider isn't reset while you drag it
  const key=JSON.stringify([v.phase,v.started,v.host,v.myTurn,c,v.insure,v.readyMe,v.bets&&v.bets[v.me],TB.amt,me.side,me.stack,v.lim,v.side,v.game,v.seats.filter(s=>s&&!s.bot).length,v.game==='rl'?[TB.rl.chip,TB.rl.bets,TB.rl.last]:0]);
  if(key===TB.key)return;TB.key=key;let h='';
  if(v.game==='rl'){box.innerHTML=rlActions(v,me);return}
  if(!v.started&&v.host){const n=v.seats.filter(s=>s&&!s.bot).length,can=v.game==='bj'?n>=1:n>=2;
    h+=`<div class="trow">${tbBtn('start','START THE TABLE',{on:can,cl:'go big',hint:can?n+' seated':'needs 2 players'})}</div>`;
    h+=`<p class="tbHint">Table rules (you can change these until you start):</p><div class="trow">${[100,250,0].map(l=>tbBtn('lim:'+l,l?'MAX BET '+l:'NO LIMIT',{cl:v.lim===l?'sel':''})).join('')}</div>`;
    h+=`<div class="trow">${tbBtn('tside','SIDE BET '+(v.side?'ON':'OFF'),{cl:v.side?'sel':'',hint:'players opt in, 1◆ a hand'})}</div>`}
  const between=v.game==='bj'?v.phase==='bet'&&!(v.bets&&v.bets[v.me]!==undefined):v.phase!=='play';
  if(v.side&&v.started&&between)h+=`<div class="trow">${tbBtn('myside','MY SIDE BET: '+(me.side?'ON':'OFF'),{cl:me.side?'sel':'',hint:'1◆ a hand · double aces'+(v.game==='he'?' or a full house':'')+' wins 10 Hybrid / 15 Flag Cases'})}</div>`;
  if(v.game==='bj'){
    if(v.phase==='bet'&&!(v.bets&&v.bets[v.me]!==undefined)&&me.stack>=1){const mx=v.lim?Math.min(v.lim,me.stack):me.stack;TB.amt=Math.max(1,Math.min(TB.amt,mx));
      h+=`<div class="tbet">${tbBtn('amt-','−')}<div class="tamt"><b>${TB.amt}</b><span>shards</span></div>${tbBtn('amt+','+')}</div>`;
      h+=`<div class="trow chips">${[1,5,10,25].filter(x=>x<=mx).map(x=>tbBtn('set:'+x,String(x),{cl:TB.amt===x?'sel':''})).join('')}${tbBtn('set:'+mx,'MAX '+mx,{cl:TB.amt===mx?'sel':''})}</div>`;
      h+=`<div class="trow">${tbBtn('bet','BET '+TB.amt+'◆',{cl:'go big'})}</div>`}
    if(v.insure){const p=v.players.find(p=>p.seat===v.me),cost=Math.floor(p.hands[0].bet/2);h+=`<div class="trow">${tbBtn('ins:1','TAKE INSURANCE',{hint:'costs '+cost+'◆'})}${tbBtn('ins:0','NO INSURANCE',{cl:'go'})}</div>`}
    if(v.myTurn){const p=v.players.find(p=>p.seat===v.me),bet=p.hands[v.turn.h].bet;
      h+=`<div class="trow">${tbBtn('hit','HIT',{cl:'go big',hint:'take a card'})}${tbBtn('stand','STAND',{cl:'go big',hint:'keep your total'})}</div>`;
      h+=`<div class="trow">${tbBtn('double','DOUBLE',{on:c.double,hint:'+'+bet+'◆, one more card'})}${tbBtn('split','SPLIT',{on:c.split,hint:c.split?'+'+bet+'◆, two hands':'needs a pair'})}</div>`}}
  else{
    if(v.myTurn){TB.raise=Math.max(c.minPut,Math.min(TB.raise||c.minPut,c.maxPut));
      h+=`<div class="trow">${tbBtn('fold','FOLD',{hint:'give up this hand'})}${c.check?tbBtn('check','CHECK',{cl:'go big',hint:'pass'}):tbBtn('call','CALL '+c.call+'◆',{cl:'go big',hint:'match the bet'})}</div>`;
      if(c.raise)h+=`<div class="traise"><input type="range" id="tbRaise" min="${c.minPut}" max="${c.maxPut}" step="1" value="${TB.raise}" aria-label="Raise amount"><div class="trow">${tbBtn('raise',(c.call?'RAISE ':'BET ')+'<b id="tbRaiseN">'+TB.raise+'</b>◆',{cl:'go',hint:'put in '+c.minPut+'-'+c.maxPut})}${c.allin?tbBtn('allin','ALL IN '+c.stack+'◆',{hint:'everything at the table'}):''}</div></div>`;
      else if(c.allin&&c.stack>c.call)h+=`<div class="trow">${tbBtn('allin','ALL IN '+c.stack+'◆')}</div>`}
    if(v.phase==='done'&&!v.readyMe&&me.stack>=2)h+=`<div class="trow">${tbBtn('ready','READY FOR THE NEXT HAND',{cl:'go big'})}</div>`}
  box.innerHTML=h;
  const rg=$('tbRaise');if(rg)rg.addEventListener('input',()=>{TB.raise=+rg.value;const n=$('tbRaiseN');if(n)n.textContent=rg.value})}

/* ---------- roulette: the board ---------- */
// spot keys are the server's: n:X (00 is 37), sp:A-B, st:A, tr:0-1-2|0-2-37|2-3-37, co:A, tl, sl:A, dz:1-3, col:1-3,
// red, black, odd, even, low, high. The board: 0 and 00 on the left, 12 columns of three numbers (3 on top), 2:1 on the right.
const RL_RED=new Set([1,3,5,7,9,12,14,16,18,19,21,23,25,27,30,32,34,36]);
const rlName=n=>n===37?'00 GREEN':n===0?'0 GREEN':n+(RL_RED.has(n)?' RED':' BLACK');
const rlTotalC=b=>Object.values(b||{}).reduce((a,x)=>a+(x|0),0);
const RL_OUT=[['dz:1','1st 12'],['dz:2','2nd 12'],['dz:3','3rd 12'],['low','1-18'],['even','EVEN'],['red','RED'],['black','BLACK'],['odd','ODD'],['high','19-36']];
// which spot a tap on the numbers lands on: col 0-11, row 0 (top: 3,6,…) to 2 (bottom: 1,4,…), fx/fy where in the cell
function rlHit(col,row,fx,fy){const E=.24,L=fx<E,R=fx>1-E,T=fy<E,B=fy>1-E;
  if(L&&col>0)return rlHit(col-1,row,1,fy);
  if(T&&row>0)return rlHit(col,row-1,fx,1);
  const n=col*3+(3-row);
  if(L){   // the edge next to 0 and 00 (col 0): 00 is the top half, 0 the bottom half
    if(row===2)return B?'tl':T?'tr:0-1-2':'sp:0-1';
    if(row===1)return B?'tr:0-1-2':Math.abs(fy-.5)<.2?'tr:0-2-37':fy<.5?'sp:2-37':'sp:0-2';
    return B?'tr:2-3-37':'sp:3-37'}
  if(row===2&&B)return R&&col<11?'sl:'+n:'st:'+n;
  if(B&&R&&col<11)return 'co:'+(n-1);
  if(B)return 'sp:'+(n-1)+'-'+n;
  if(R&&col<11)return 'sp:'+n+'-'+(n+3);
  return 'n:'+n}
// where a spot's chips sit on the board, in board units (x: -1 to 12 with 0/00 in -1..0, y: 0 to 3; outside boxes below)
function rlPos(k){const m=String(k).match(/^([a-z]+)(?::([0-9-]+))?$/);if(!m)return null;const t=m[1],ns=(m[2]||'').split('-').map(Number);
  const at=n=>n===0?[-.5,2.25]:n===37?[-.5,.75]:[Math.floor((n-1)/3)+.5,2-(n-1)%3+.5];
  if(t==='n')return at(ns[0]);if(t==='tl')return[0,3];if(t==='st')return[Math.floor((ns[0]-1)/3)+.5,3];if(t==='sl')return[Math.floor((ns[0]-1)/3)+1,3];
  if(t==='co'){const p=at(ns[0]);return[p[0]+.5,p[1]-.5]}
  if(t==='sp'||t==='tr'){if(ns.includes(0)&&ns.includes(37)&&ns.length===2)return[-.5,1.5];const z=ns.some(n=>n===0||n===37),ps=ns.filter(n=>!z||(n&&n!==37)).map(at),y=ps.reduce((a,p)=>a+p[1],0)/ps.length;
    if(z)return[0,t==='tr'?(ns.includes(1)?2:ns.includes(3)?1:1.5):y];return[ps.reduce((a,p)=>a+p[0],0)/ps.length,y]}
  return null}
const RL_CHIPS=[1,5,25,100,500,1000],rlChipCol=a=>a>=1000?'#d6aa46':a>=500?'#8a4ad0':a>=100?'#141214':a>=25?'#1f8a4a':a>=5?'#c02030':'#e8e4dc';
const rlChipH=(a,cl='')=>`<i class="rchip${cl}" style="--c:${rlChipCol(a)}">${a>=1000?(a/1000).toFixed(a%1000?1:0)+'K':a}</i>`;
// keep your local board in step with the server's (it adopts what the server holds unless you've changed it since)
function rlSync(v){const R=TB.rl;if(v.handNo!==R.hand){if(R.hand>=0&&rlTotalC(R.sentBets))R.last={...R.sentBets};R.hand=v.handNo;R.bets={};R.sent='';R.sentBets={}}
  if(v.phase!=='bet'){R.bets={...(v.myBets||{})};return}
  if(!R.dirty&&JSON.stringify(v.myBets||{})!==R.sent){R.bets={...(v.myBets||{})};R.sent=JSON.stringify(R.bets);R.sentBets={...R.bets}}}
let rlSendT=0;
function rlQueue(){const R=TB.rl;R.dirty=1;TB.key='';if(TB.v)tbShow(TB.v);clearTimeout(rlSendT);rlSendT=setTimeout(rlFlush,260)}
async function rlFlush(){const R=TB.rl;if(!TB.id||!R.dirty)return;const want=JSON.stringify(R.bets);R.dirty=0;
  const r=await tbSend({op:'rlbets',id:TB.id,bets:R.bets},true);if(r&&r.error){toast('ROULETTE',r.error);R.dirty=0;R.sent='';if(TB.v)rlSync(TB.v)}else{R.sent=want;R.sentBets=JSON.parse(want)}if(TB.v){TB.key='';tbShow(TB.v)}}
function rlFelt(v){const R=TB.rl,open=v.phase==='bet'&&!v.readyMe,mine=open?R.bets:(v.myBets||{});let cells='';
  // a 6-row grid: each number spans two rows, so 00 (top) and 0 (bottom) can each take half the left column
  for(let row=0;row<3;row++)for(let col=0;col<12;col++){const n=col*3+(3-row);cells+=`<span class="rn ${RL_RED.has(n)?'r':'b'}${v.number===n&&v.phase==='done'?' hit':''}" style="grid-area:${row*2+1}/${col+2}/span 2/span 1">${n}</span>`}
  for(const[n,r0]of[[37,1],[0,4]])cells+=`<span class="rn g${v.number===n&&v.phase==='done'?' hit':''}" style="grid-area:${r0}/1/span 3/span 1">${n===37?'00':0}</span>`;
  const others={};for(const[si,b]of Object.entries(v.bets||{}))if(+si!==v.me)for(const[k,a]of Object.entries(b))others[k]=(others[k]||0)+a;
  const chipAt=(k,a,cl)=>{const p=rlPos(k);if(!p)return '';return `<span class="rspot" style="left:${(p[0]+1)/13*100}%;top:${p[1]/3*100}%">${rlChipH(a,cl)}</span>`};
  let chips='';for(const[k,a]of Object.entries(others))chips+=chipAt(k,a,' other');for(const[k,a]of Object.entries(mine))chips+=chipAt(k,a,'');
  const hist=(v.hist||[]).slice().reverse().map((n,i)=>`<b class="${n===0||n===37?'g':RL_RED.has(n)?'r':'b'}${i===0&&v.phase==='done'?' new':''}">${n===37?'00':n}</b>`).join('');
  const out=RL_OUT.map(([k,l])=>`<button type="button" class="rout${k==='red'?' r':k==='black'?' b':''}" data-spot="${k}"${open?'':' disabled'}>${l}${mine[k]?rlChipH(mine[k]):''}${others[k]?rlChipH(others[k],' other'):''}</button>`).join('');
  const cols=[3,2,1].map(c=>`<button type="button" class="rcol" data-spot="col:${c}"${open?'':' disabled'}>2:1${mine['col:'+c]?rlChipH(mine['col:'+c]):''}</button>`).join('');
  const num=v.phase!=='bet'&&v.number!==undefined?`<div class="rnum ${v.number===0||v.number===37?'g':RL_RED.has(v.number)?'r':'b'}${v.phase==='spin'?' spin':''}"><b>${v.phase==='spin'?'…':v.number===37?'00':v.number}</b><span>${v.phase==='spin'?'NO MORE BETS':rlName(v.number)}</span></div>`:'';
  return `<div class="rhist"><span>LAST SPINS</span>${hist||'<em>none yet</em>'}</div>${num}
<div class="rboard${open?'':' shut'}"><div class="rnums" id="rlNums">${cells}<div class="rchips">${chips}</div></div><div class="rcols">${cols}</div></div>
<div class="routs">${out}</div>`}
function rlActions(v,me){const R=TB.rl,open=v.phase==='bet'&&!v.readyMe,tot=rlTotalC(R.bets);if(v.phase!=='bet')return `<p class="tbHint">${v.phase==='spin'?'The ball is spinning.':'Next spin\'s betting opens in a moment.'}</p>`;
  if(v.readyMe)return `<p class="tbHint">You're in with ${rlTotalC(v.myBets)}◆. The ball goes when everyone's ready, or in ${tbSecs(v)}s.</p>`;
  const lastT=rlTotalC(R.last);
  return `<div class="trow chips rchips2">${RL_CHIPS.map(a=>tbBtn('chip:'+a,rlChipH(a),{cl:R.chip===a?'sel':'',on:a<=me.stack+tot})).join('')}</div>
<div class="trow">${tbBtn('rlclear','CLEAR',{on:tot>0})}${tbBtn('rlrebet','REBET',{on:open&&lastT>0&&lastT<=me.stack+tot,hint:lastT?lastT+'◆':''})}${tbBtn('rldouble','DOUBLE',{on:tot>0&&tot<=me.stack,hint:tot?'to '+tot*2+'◆':''})}</div>
<div class="trow">${tbBtn('rlspin','SPIN',{cl:'go big',on:tot>0,hint:tot?tot+'◆ on the board':'place a bet first'})}</div>`}
function rlAdd(k){const R=TB.rl,v=TB.v;if(!v||v.phase!=='bet'||v.readyMe)return;const me=v.seats[v.me],free=me.stack+rlTotalC(v.myBets)-rlTotalC(R.bets);
  if(free<1){toast('ROULETTE','Not enough shards at the table: top up (+5 or +25)');return}R.bets[k]=(R.bets[k]||0)+Math.min(R.chip,free);rlQueue()}
$('tbFelt').addEventListener('click',e=>{const b=e.target.closest('[data-spot]');if(b){if(!b.disabled)rlAdd(b.dataset.spot);return}
  const g2=e.target.closest('#rlNums');if(!g2||!TB.v||TB.v.game!=='rl')return;const r=g2.getBoundingClientRect(),x=(e.clientX-r.left)/r.width*13-1,y=(e.clientY-r.top)/r.height*3;
  if(x<0){rlAdd(Math.abs(y-1.5)<.25?'sp:0-37':y<1.5?'n:37':'n:0');return}
  const col=Math.min(11,Math.floor(x)),row=Math.min(2,Math.max(0,Math.floor(y)));rlAdd(rlHit(col,row,x-col,y-row))});
$('tbActs').addEventListener('click',e=>{const b=e.target.closest('button[data-act]');if(!b||b.disabled)return;const a=b.dataset.act,v=TB.v;if(!v)return;const me=v.seats[v.me],R=TB.rl;
  if(a.startsWith('chip:')){R.chip=+a.slice(5);TB.key='';tbActions(v,me);return}
  if(a==='rlclear'){R.bets={};rlQueue();return}
  if(a==='rlrebet'){R.bets={...R.last};rlQueue();return}
  if(a==='rldouble'){for(const k in R.bets)R.bets[k]*=2;rlQueue();return}
  if(a==='rlspin'){clearTimeout(rlSendT);(async()=>{if(R.dirty)await rlFlush();tbSend({op:'rlready',id:TB.id})})();return}
  if(a==='start')return tbSend({op:'start',id:TB.id});
  if(a.startsWith('lim:'))return tbSend({op:'settings',id:TB.id,lim:+a.slice(4)});if(a==='tside')return tbSend({op:'settings',id:TB.id,side:!v.side});
  if(a==='myside')return tbSend({op:'side',id:TB.id,on:!me.side});
  if(a==='amt-'||a==='amt+'){TB.amt=Math.max(1,TB.amt+(a==='amt+'?1:-1));TB.key='';tbActions(v,me);return}
  if(a.startsWith('set:')){TB.amt=+a.slice(4);TB.key='';tbActions(v,me);return}
  if(a==='bet')return tbSend({op:'bet',id:TB.id,amt:TB.amt,side:!!me.side});
  if(a.startsWith('ins:'))return tbSend({op:'insure',id:TB.id,yes:a==='ins:1'});
  if(a==='ready')return tbSend({op:'ready',id:TB.id});
  if(a==='raise')return tbSend({op:'move',id:TB.id,a:'raise',amt:TB.raise});
  tbSend({op:'move',id:TB.id,a})});

/* ---------- hand history and the check (run here, in the browser) ---------- */
// The same steps as the server (engine.js): SHA-256 of "seed:seeds joined by |:nonce" (first 48 hex) is the key; the random
// stream is SHA-256("key:0"), SHA-256("key:1"), … read 32 bits at a time with rejection sampling; the deck is a
// Fisher-Yates shuffle with it. Hold'em cards: salt = SHA-256("seed:card:i") (32 hex), fingerprint = SHA-256("salt:card").
const tbSha=async s=>[...new Uint8Array(await crypto.subtle.digest('SHA-256',new TextEncoder().encode(s)))].map(x=>x.toString(16).padStart(2,'0')).join('');
async function tbFairRng(seed,seeds,nonce){const key=(await tbSha(seed+':'+seeds.join('|')+':'+nonce)).slice(0,48)+':';let ctr=0,buf=[],pos=0;
  const next=async()=>{if(pos>=buf.length){const hx=await tbSha(key+(ctr++));buf=[];for(let i=0;i<64;i+=8)buf.push(parseInt(hx.slice(i,i+8),16));pos=0}return buf[pos++]};
  return async n=>{if(n<=1)return 0;const lim=Math.floor(4294967296/n)*n;for(;;){const x=await next();if(x<lim)return x%n}}}
async function tbShuffle(n,r){const d=Array.from({length:n},(_,i)=>i);for(let i=n-1;i>0;i--){const j=await r(i+1),t=d[i];d[i]=d[j];d[j]=t}return d}
// check one hand: returns [ok, what was checked]
async function tbVerify(h){const r=h.result||{};
  if(!r.seeds)return[null,'From before v0.10.0: checked by its deck fingerprint only.'];
  if(h.seed){if(await tbSha(h.seed)!==h.commit)return[false,'The seed does not match the fingerprint shown before the round.'];
    const rr=await tbFairRng(h.seed,r.seeds,r.nonce);
    if(h.game==='rl'){const n=await rr(38);return n===r.number?[true,`The seed matches its fingerprint and the spin reruns to ${rlName(n)}.`]:[false,'The spin does not rerun to the same number.']}
    const d=await tbShuffle(h.game==='bj'?208:52,rr),same=Array.isArray(h.deck)&&d.length===h.deck.length&&d.every((c,i)=>c===h.deck[i]);
    return same?[true,`The seed matches its fingerprint and the ${h.game==='bj'?'shoe':'deck'} reruns card for card.`]:[false,'The shuffle does not rerun to the same cards.']}
  if(h.cards&&h.cardHashes){if(await tbSha(h.cardHashes.join(','))!==h.root)return[false,'The card fingerprints do not build the hand\'s root.'];
    for(const[i,c,s]of h.cards)if(await tbSha(s+':'+c)!==h.cardHashes[i])return[false,'A card does not match its fingerprint.'];
    return[true,`The ${h.cards.length} cards you saw each match their fingerprint, and all 52 build the root shown at the deal. The seed and the whole deck show in ${Math.ceil((h.seedIn||0)/36e5)} h.`]}
  return[null,'Nothing to check yet.']}
const tbCards=a=>(a||[]).map(tbCard).join('');
function tbHistRow(h,i){const r=h.result||{},me=(r.players||[]).find(p=>p.uid===myUid()),net=me?me.net!==undefined?me.net:(me.won||0)-(me.put||me.bet||0):null;
  const what=h.game==='rl'?rlName(r.number):h.game==='bj'?'Dealer '+(r.total||'?'):(r.board?tbCards(r.board):'');
  return `<li><div class="hrow"><b>${TB_NAME[h.game]} #${h.no}</b><span>${new Date(h.at).toLocaleString()}</span><em class="${net>0?'w':net<0?'l':''}">${net===null?'':(net>0?'+':'')+net+'◆'}</em></div>
<div class="hwhat">${what}${h.mine?' · your cards '+tbCards(h.mine):''}</div><button type="button" data-check="${i}">CHECK</button><p class="hcheck" id="hc${i}"></p></li>`}
async function tbHistory(){const box=$('tbHistList');hid($('tbHist'),false);box.innerHTML='<p class="tbHint">Loading…</p>';const r=await tbCall({op:'history'});
  if(r.error){box.innerHTML=`<p class="tbHint">${tbEsc(r.error)}</p>`;return}TB.hist=r.hands||[];
  box.innerHTML=TB.hist.length?`<p class="tbHint">Your last ${TB.hist.length} hands and spins. CHECK reruns the shuffle or the spin here, from what the server revealed.</p><ul class="hlist">${TB.hist.map(tbHistRow).join('')}</ul>`:'<p class="tbHint">No hands yet. Sit down at a table in the casino.</p>'}
$('tbHistList').addEventListener('click',async e=>{const b=e.target.closest('button[data-check]');if(!b)return;const i=+b.dataset.check,h=TB.hist[i],out=$('hc'+i);out.textContent='Checking…';
  const [ok,why]=await tbVerify(h);out.className='hcheck '+(ok?'ok':ok===false?'bad':'');out.textContent=(ok?'✓ FAIR. ':ok===false?'✗ ':'')+why});
const tbRules=()=>{$('tbRulesTxt').innerHTML=TB_RULES;hid($('tbRules'),false)};
for(const m of[$('tbHist'),$('tbRules')])m.addEventListener('click',e=>{if(e.target===m||e.target.closest('[data-close]'))hid(m,true)});
document.addEventListener('click',e=>{if(e.target.closest('[data-hist]'))tbHistory();else if(e.target.closest('[data-rules]'))tbRules()});
$('tbHistBtn').addEventListener('click',tbHistory);$('tbRulesBtn').addEventListener('click',tbRules);

/* ---------- the rest of the sheet and the front door ---------- */
$('tbHide').addEventListener('click',()=>tbSheet(false));
$('tbLeave').addEventListener('click',()=>{if(casino())casStand();else tbSend({op:'leave',id:TB.id})});
for(const b of document.querySelectorAll('[data-top]'))b.addEventListener('click',()=>tbSend({op:'topup',id:TB.id,amt:+b.dataset.top}));
$('tbPick').addEventListener('click',async e=>{const b=e.target.closest('button[data-pick]');if(!b)return;await tbSend({op:'pick',id:TB.id,kind:b.dataset.pick});if(typeof syncLocker==='function')syncLocker()});
$('tbSeedBtn').addEventListener('click',async()=>{const s=$('tbSeedIn').value.replace(/[^0-9A-Za-z_-]/g,'').slice(0,64);if(!s){tbMsg('Pick a seed (letters and numbers)');return}
  try{localStorage.setItem('pal_seed',s)}catch(e){}const r=await tbSend({op:'seed',id:TB.id,seed:s});if(r&&!r.error)tbMsg('Your seed is in from the next round.')});
$('casEnterBtn').addEventListener('click',()=>casEnter());
$('tbJoinBtn').addEventListener('click',()=>{const c=$('tbCode').value.trim().toUpperCase();if(!/^[A-Z0-9]{4}$/.test(c)){tbMsg('Type your friend\'s 4-letter room code');return}casJoin(c)});
$('tbMineLeave').addEventListener('click',async()=>{const m=TB.mine;if(!m)return;await tbSend({op:'leave',id:m.id});TB.mine=null;tbGone();renderTables()});
