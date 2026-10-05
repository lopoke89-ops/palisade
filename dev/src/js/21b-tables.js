/* ================= v0.9.8 THE TABLES: Blackjack and Texas Hold'em for shards ================= */
// The server deals and decides everything (the `tables` edge function, dev/supabase/functions/tables). This page only
// shows what the server says this player may see, and sends moves. It polls once a second while a table is open.
// v0.9.8.1: a status line that always says what's happening and what to do, a bet stepper, a raise slider, READY between
// hands, the host's START, and a How to play panel.
const TB={id:0,code:'',v:null,busy:false,lobbyT:0,game:'bj',lim:100,side:false,amt:2,raise:0,balance:0,key:''};
const TB_SUIT=['♣','♦','♥','♠'],TB_RANK=['2','3','4','5','6','7','8','9','10','J','Q','K','A'];
const tbCard=c=>c===null||c===undefined?'<span class="tcard back"></span>':`<span class="tcard${(c%52/13|0)===1||(c%52/13|0)===2?' red':''}">${TB_RANK[c%52%13]}<i>${TB_SUIT[c%52/13|0]}</i></span>`;
const tbEsc=s=>String(s).replace(/[&<>"]/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;'}[c]));
const TB_HELP={bj:`<p><b>Goal:</b> finish closer to 21 than the dealer without going over. Number cards count their number, J/Q/K count 10, an ace counts 1 or 11.</p>
<p><b>Each hand:</b> place a bet (60 seconds; the cards come as soon as everyone has bet). You get two cards; the dealer shows one.</p>
<p><b>HIT</b> takes a card. <b>STAND</b> keeps what you have. <b>DOUBLE</b> doubles your bet for exactly one more card. <b>SPLIT</b> turns a pair into two hands (one more bet).</p>
<p><b>Pays:</b> a win pays 1:1, blackjack (ace + a 10 card) pays 3:2, a tie gets your bet back. The dealer stands on 17. If the dealer shows an ace you can buy <b>insurance</b> (half your bet, pays 2:1 if the dealer has blackjack).</p>
<p>4 decks, shuffled fresh every hand. No clock while you play.</p>`,
he:`<p><b>Goal:</b> make the best five-card hand from your two cards and the five shared cards, or make everyone else fold.</p>
<p><b>Each hand:</b> two players post blinds (1 and 2 shards). Then four rounds of betting: after your cards, after the flop (3 shared cards), the turn (4th) and the river (5th).</p>
<p>On your turn: <b>FOLD</b> (give up the hand), <b>CHECK</b> (pass, if nobody has bet), <b>CALL</b> (match the bet), <b>RAISE / BET</b> (put in more), <b>ALL IN</b> (everything at the table).</p>
<p><b>Hands, low to high:</b> high card, pair, two pair, three of a kind, straight, flush, full house, four of a kind, straight flush.</p>
<p>The house takes 1.8% of pots that reach the flop (6 shards at most). Between hands there's a 60-second break; it deals as soon as everyone taps READY. No clock while you play.</p>`};
async function tbCall(body){
  if(!await freshToken())return{error:'Sign in to play at the tables'};
  let r=await sbFetch('/functions/v1/tables',{method:'POST',body,timeout:12000});
  if(r.status===401&&acct.s){acct.s.expires_at=0;if(await freshToken())r=await sbFetch('/functions/v1/tables',{method:'POST',body,timeout:12000})}
  if(!r.j)return{error:r.status?'The tables are busy. Try again.':'No connection'};return r.j}
const tbMsg=t=>txt($('tbMsg'),t||'');
function tbCanPlay(){if(!cloudOn)return 'The tables need the online version of the game.';if(!acct.s)return 'Sign in to play at the tables.';
  if(isGuest())return 'Make an account on the Account page to play at the tables. Guests can\'t.';return null}
function renderTables(){const no=tbCanPlay();$('tbLobby').hidden=!!TB.id;$('tbTable').hidden=!TB.id;
  for(const b of $('tbGame').children)cls(b,'sel',b.dataset.g===TB.game);for(const b of $('tbLim').children)cls(b,'sel',+b.dataset.l===TB.lim);$('tbSide').checked=TB.side;
  $('tbOpenBtn').disabled=$('tbJoinBtn').disabled=!!no||TB.busy;tbMsg(no||'');if(!no&&!TB.id)tbLobby()}
async function tbLobby(){if(TB.busy||tbCanPlay())return;TB.lobbyT=performance.now();const r=await tbCall({op:'lobby'});if(r.error){tbMsg(r.error);return}
  TB.balance=r.balance;txt($('tbBal'),String(r.balance));
  if(r.mine&&!TB.id){TB.id=r.mine.id;TB.code=r.mine.code;renderTables();tbPoll();return}
  const ul=$('tbList');ul.innerHTML=r.tables.length?r.tables.map(t=>`<li><button type="button" data-code="${tbEsc(t.code)}"><b>${t.game==='bj'?'BLACKJACK':'HOLD\'EM'}</b><span>${tbEsc(t.host)}'s table · ${t.seated}/${t.seats} seated${t.bot?' · bot':''}</span><em>${t.lim?'MAX BET '+t.lim:'NO LIMIT'}${t.side?' · SIDE BET':''}<br>JOIN ›</em></button></li>`).join(''):'<li class="none">No open tables right now. Open one and share its code.</li>'}
async function tbSend(body,quiet){if(TB.busy&&!quiet)return;if(!quiet)TB.busy=true;try{const r=await tbCall(body);
  if(r.error&&!r.view){tbMsg(r.error);if(/closed/.test(r.error)){TB.id=0;TB.v=null;renderTables()}return r}
  if(r.view){TB.id=r.id;TB.code=r.code;TB.balance=r.balance;tbShow(r.view);tbMsg(r.error||'')}
  if(body.op==='leave'&&r.view&&r.view.me<0){TB.id=0;TB.v=null;renderTables();if(typeof syncLocker==='function')syncLocker()}
  return r}finally{if(!quiet)TB.busy=false}}
function tbPoll(){if(!TB.id||$('pg-tables').hidden||document.hidden)return;tbSend({op:'state',id:TB.id},true)}
setInterval(()=>{if($('menu').hidden||$('pg-tables').hidden)return;if(TB.id)tbPoll();else if(performance.now()-TB.lobbyT>5000)tbLobby()},1000);
const tbSecs=v=>Math.ceil(v.left/1000);
// one line that says what's going on, and what you should do
function tbStatus(v,me){const P=v.players||[],cur=v.game==='bj'?(v.turn&&P[v.turn.p]):P.find(p=>p.turn),hum=v.seats.filter(s=>s&&!s.bot).length;
  if(!v.started)return v.host?['WAITING TO START',`${hum} seated. Share the code ${TB.code}, then press START when everyone's in.`+(v.game==='he'&&hum<2?' Hold\'em needs 2 players.':''),'wait']
    :['WAITING FOR THE HOST',`${v.hostName} starts the table when everyone's in.`,'wait'];
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
  if(v.me<0){TB.id=0;renderTables();return}
  const me=v.seats[v.me];
  txt($('tbTitle'),v.game==='bj'?'BLACKJACK':'TEXAS HOLD\'EM');txt($('tbInfo'),(v.lim?'max bet '+v.lim:'no limit')+(v.side?' · side bet on':'')+' · host '+v.hostName);txt($('tbCodeTxt'),TB.code);
  txt($('tbStack'),String(me.stack));txt($('tbBalT'),String(TB.balance));
  const [t,sub,kind]=tbStatus(v,me),stEl=$('tbStatus');stEl.className='tbStatus '+kind;txt(stEl.children[0],t);txt(stEl.children[1],sub);
  const tm=v.left>0;$('tbTimer').hidden=!tm;if(tm)$('tbTimer').firstChild.style.transform=`scaleX(${Math.min(1,v.left/60000)})`;
  const seat=(s,inner,turn,tag)=>`<div class="tseat${s.me?' me':''}${turn?' turn':''}${s.bot?' bot':''}"><b>${tbEsc(s.name)}${s.me?' <i>YOU</i>':''}${tag||''}</b><span>${s.stack} ◆ at the table</span>${inner||''}</div>`;
  const lastBj=v.game==='bj'&&(v.phase==='bet'||!v.dealer)&&v.last&&v.last.result&&v.last.result.dealer?v.last.result:null;
  let felt='';
  if(v.game==='bj'){
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
  $('tbFairTxt').textContent=(v.fair?'This hand\'s deck fingerprint (SHA-256): '+v.fair+'. ':'')+(v.last?(v.last.deck?`Last hand #${v.last.no}: salt ${v.last.salt}, deck ${JSON.stringify(v.last.deck)}. SHA-256 of "salt:deck" (cards joined by commas) = ${v.last.hash}.`:`Last hand #${v.last.no}: fingerprint ${v.last.hash}. In Hold'em the deck stays in the server's hand log so folded hands stay private.`):'');
  const pk=$('tbPick');pk.hidden=!(v.picks>0);if(v.picks>0){const hit=v.last&&v.last.sideHits&&v.last.sideHits.find(x=>x);txt($('tbPickWhy'),(hit?hit.why+'! ':'')+'Pick your prize.')}}
function tbResult(v){const r=v.last.result;
  if(v.game==='bj'){const mine=r.players.find(p=>p.name===v.seats[v.me].name);return 'Dealer '+r.total+(r.total>21?' (bust)':'')+(mine?' · you '+(mine.net>0?'won +':mine.net<0?'lost ':'broke even ')+(mine.net?Math.abs(mine.net)+'◆':''):'')}
  const ws=r.players.filter(p=>p.won>0);return ws.map(p=>tbEsc(p.name)+' wins '+p.won+'◆'+(p.hand?' with '+p.hand.toLowerCase():'')).join(' · ')+(r.rake?' · house '+r.rake+'◆':'')}
const tbBtn=(id,label,{on=true,cl='',hint=''}={})=>`<button type="button" data-act="${id}" class="${cl}"${on?'':' disabled'}>${label}${hint?`<small>${hint}</small>`:''}</button>`;
function tbActions(v,me){const box=$('tbActs'),c=v.can||{};
  // rebuilt only when something you can do changes, so the raise slider isn't reset while you drag it
  const key=JSON.stringify([v.phase,v.started,v.host,v.myTurn,c,v.insure,v.readyMe,v.bets&&v.bets[v.me],TB.amt,me.side,me.stack,v.lim,v.side,v.game,v.seats.filter(s=>s&&!s.bot).length]);
  if(key===TB.key)return;TB.key=key;let h='';
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
$('tbActs').addEventListener('click',e=>{const b=e.target.closest('button[data-act]');if(!b||b.disabled)return;const a=b.dataset.act,v=TB.v;if(!v)return;const me=v.seats[v.me];
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
$('tbGame').addEventListener('click',e=>{const b=e.target.closest('button');if(b){TB.game=b.dataset.g;renderTables()}});
$('tbLim').addEventListener('click',e=>{const b=e.target.closest('button');if(b){TB.lim=+b.dataset.l;renderTables()}});
$('tbSide').addEventListener('change',e=>{TB.side=e.target.checked});
$('tbOpenBtn').addEventListener('click',async()=>{tbMsg('Opening a table…');await tbSend({op:'open',game:TB.game,lim:TB.lim,side:TB.side});if(TB.id){TB.key='';renderTables()}});
const tbJoin=async code=>{if(!code)return;tbMsg('Joining…');await tbSend({op:'join',code});if(TB.id){TB.key='';renderTables()}else{const m=$('tbMsg').textContent;TB.busy=false;await tbLobby();tbMsg(m)}};
$('tbJoinBtn').addEventListener('click',()=>tbJoin($('tbCode').value.trim().toUpperCase()));
$('tbList').addEventListener('click',e=>{const b=e.target.closest('button[data-code]');if(b)tbJoin(b.dataset.code)});
$('tbLeave').addEventListener('click',()=>tbSend({op:'leave',id:TB.id}));
for(const b of document.querySelectorAll('[data-top]'))b.addEventListener('click',()=>tbSend({op:'topup',id:TB.id,amt:+b.dataset.top}));
$('tbPick').addEventListener('click',async e=>{const b=e.target.closest('button[data-pick]');if(!b)return;await tbSend({op:'pick',id:TB.id,kind:b.dataset.pick});if(typeof syncLocker==='function')syncLocker()});
