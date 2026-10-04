/* ================= v0.9.8 THE TABLES: Blackjack and Texas Hold'em for shards ================= */
// The server deals and decides everything (the `tables` edge function, dev/supabase/functions/tables). This page only
// shows what the server says this player may see, and sends moves. It polls once a second while a table is open.
const TB={id:0,code:'',v:null,busy:false,poll:0,lobbyT:0,game:'bj',lim:100,side:false,amt:2,raise:0,shown:'',balance:0};
const TB_SUIT=['♣','♦','♥','♠'],TB_RANK=['2','3','4','5','6','7','8','9','10','J','Q','K','A'];
const tbCard=c=>c===null||c===undefined?'<span class="tcard back"></span>':`<span class="tcard${(c%52/13|0)===1||(c%52/13|0)===2?' red':''}">${TB_RANK[c%52%13]}<i>${TB_SUIT[c%52/13|0]}</i></span>`;
const tbEsc=s=>String(s).replace(/[&<>"]/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;'}[c]));
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
  const ul=$('tbList');ul.innerHTML=r.tables.length?r.tables.map(t=>`<li><button type="button" data-code="${tbEsc(t.code)}"><b>${t.game==='bj'?'BLACKJACK':'HOLD\'EM'}</b><span>${tbEsc(t.host)} · ${t.seated}/${t.seats} seated${t.bot?' · bot':''}</span><em>${t.lim?'LIMIT '+t.lim:'NO LIMIT'}${t.side?' · SIDE BET':''}</em></button></li>`).join(''):'<li class="none">No open tables. Open one and invite your crew.</li>'}
async function tbSend(body,quiet){if(TB.busy&&!quiet)return;if(!quiet)TB.busy=true;try{const r=await tbCall(body);
  if(r.error&&!r.view){tbMsg(r.error);if(/closed/.test(r.error)){TB.id=0;TB.v=null;renderTables()}return r}
  if(r.view){TB.id=r.id;TB.code=r.code;TB.balance=r.balance;tbShow(r.view);tbMsg(r.error||'')}
  if(body.op==='leave'&&r.view&&r.view.me<0){TB.id=0;TB.v=null;renderTables();if(typeof syncLocker==='function')syncLocker()}
  return r}finally{if(!quiet)TB.busy=false}}
function tbPoll(){if(!TB.id||$('pg-tables').hidden||document.hidden)return;tbSend({op:'state',id:TB.id},true)}
setInterval(()=>{if($('menu').hidden||$('pg-tables').hidden)return;if(TB.id)tbPoll();else if(performance.now()-TB.lobbyT>5000)tbLobby()},1000);
function tbShow(v){TB.v=v;
  if(v.me<0){TB.id=0;renderTables();return}
  const me=v.seats[v.me],game=v.game==='bj'?'BLACKJACK':'HOLD\'EM';
  txt($('tbTitle'),game+' · '+TB.code);txt($('tbInfo'),(v.lim?'LIMIT '+v.lim:'NO LIMIT')+(v.side?' · SIDE BET ON':'')+' · HOST '+v.hostName);
  txt($('tbStack'),'AT THE TABLE '+me.stack+' · BALANCE '+TB.balance);
  $('tbTimer').firstChild.style.transform=`scaleX(${Math.min(1,v.left/(v.phase==='bet'?12000:v.phase==='done'?5000:20000))})`;
  const seat=(s,inner,turn)=>`<div class="tseat${s.me?' me':''}${turn?' turn':''}${s.bot?' bot':''}"><b>${tbEsc(s.name)}</b><span>${s.stack} ◆</span>${inner||''}</div>`;
  let felt='';
  if(v.game==='bj'){
    if(v.dealer)felt+=`<div class="tdealer"><b>DEALER</b><div class="tcards">${v.dealer.map(tbCard).join('')}</div><em>${v.dealerTotal||''}</em></div>`;
    else felt+=`<div class="tdealer"><b>DEALER</b><div class="tcards">${tbCard(null)}${tbCard(null)}</div><em>${v.phase==='bet'?'PLACE YOUR BETS':'WAITING'}</em></div>`;
    felt+='<div class="tseats">'+v.seats.filter(Boolean).map(s=>{const p=v.players&&v.players.find(p=>p.seat===s.i),b=v.bets&&v.bets[s.i];
      const inner=p?p.hands.map((h,hi)=>`<div class="thand${v.turn&&v.turn.p>=0&&v.players[v.turn.p]===p&&v.turn.h===hi?' turn':''}"><div class="tcards">${h.cards.map(tbCard).join('')}</div><em>${h.total}${h.soft&&h.total<21?' soft':''} · ${h.bet}◆${h.result?' · '+h.result:''}</em></div>`).join(''):b?`<em>BET ${b}◆</em>`:'';
      return seat(s,inner,p&&v.turn&&v.players[v.turn.p]===p)}).join('')+'</div>'}
  else{
    felt+=`<div class="tdealer"><b>POT ${v.pot||0} ◆</b><div class="tcards">${(v.board||[]).map(tbCard).join('')}${'<span class="tcard slot"></span>'.repeat(5-(v.board||[]).length)}</div><em>${v.phase==='wait'?'WAITING FOR PLAYERS':''}</em></div>`;
    felt+='<div class="tseats">'+v.seats.filter(Boolean).map(s=>{const p=v.players&&v.players.find(p=>p.seat===s.i);
      const inner=p?`<div class="tcards">${p.cards.map(tbCard).join('')}</div><em>${p.folded?'FOLDED':p.allin?'ALL IN':p.bet?'BET '+p.bet+'◆':''}</em>`:'<em>SITTING OUT</em>';return seat(s,inner,p&&p.turn)}).join('')+'</div>'}
  if(v.phase==='done'&&v.last&&v.last.result)felt+=`<div class="tresult">${tbResult(v)}</div>`;
  $('tbFelt').innerHTML=felt;tbActions(v,me);
  $('tbLog').textContent=v.log.join(' · ');
  $('tbFairTxt').textContent=(v.fair?'This hand\'s deck fingerprint (SHA-256): '+v.fair+'. ':'')+(v.last?`Last hand #${v.last.no}: salt ${v.last.salt}, deck ${JSON.stringify(v.last.deck)}. SHA-256 of "salt:deck" (cards joined by commas) = ${v.last.hash}.`:'');
  const pk=$('tbPick');pk.hidden=!(v.picks>0);if(v.picks>0){const hit=v.last&&v.last.sideHits&&v.last.sideHits.find(x=>x);txt($('tbPickWhy'),(hit?hit.why+'! ':'')+'Pick your prize.')}}
function tbResult(v){const r=v.last.result;
  if(v.game==='bj'){const mine=r.players.find(p=>p.name===v.seats[v.me].name);return 'DEALER '+r.total+(r.total>21?' · BUST':'')+(mine?' · YOU '+(mine.net>0?'+':'')+mine.net+'◆':'')}
  const ws=r.players.filter(p=>p.won>0);return ws.map(p=>tbEsc(p.name)+' wins '+p.won+'◆'+(p.hand?' with '+p.hand.toLowerCase():'')).join(' · ')+(r.rake?' · house '+r.rake+'◆':'')}
function tbActions(v,me){const box=$('tbActs'),B=(id,label,on=true,cl='')=>`<button type="button" data-act="${id}" class="${cl}"${on?'':' disabled'}>${label}</button>`;let h='';
  if(v.host&&v.handNo===0)h+=`<div class="trow">${[100,250,0].map(l=>B('lim:'+l,l?'LIMIT '+l:'NO LIMIT',true,v.lim===l?'sel':'')).join('')}${B('tside',v.side?'SIDE BET: ON':'SIDE BET: OFF',true,v.side?'sel':'')}</div>`;
  if(v.side&&(v.phase==='wait'||v.phase==='done'||v.phase==='bet'&&!(v.bets&&v.bets[v.me]!==undefined)))h+=`<div class="trow">${B('myside',me.side?'MY SIDE BET: ON (1◆ A HAND)':'MY SIDE BET: OFF',true,me.side?'sel':'')}</div>`;
  if(v.game==='bj'){
    if(v.phase==='bet'&&!(v.bets&&v.bets[v.me]!==undefined)){const mx=v.lim?Math.min(v.lim,me.stack):me.stack;TB.amt=Math.max(1,Math.min(TB.amt,mx));
      h+=`<div class="trow">${[1,5,25,100].map(c=>B('chip:'+c,'+'+c,c<=mx)).join('')}${B('clear','CLEAR')}</div><div class="trow">${B('bet','BET '+TB.amt+'◆',me.stack>=1,'go')}</div>`}
    if(v.insure)h+=`<div class="trow">${B('ins:1','INSURANCE')}${B('ins:0','NO INSURANCE')}</div>`;
    if(v.myTurn)h+=`<div class="trow">${B('hit','HIT',true,'go')}${B('stand','STAND',true,'go')}${B('double','DOUBLE',v.can.double)}${B('split','SPLIT',v.can.split)}</div>`}
  else if(v.myTurn){const c=v.can;TB.raise=Math.max(c.minPut,Math.min(TB.raise||c.minPut,c.maxPut));
    h+=`<div class="trow">${B('fold','FOLD')}${c.check?B('check','CHECK',true,'go'):B('call','CALL '+c.call+'◆',true,'go')}</div>`;
    if(c.raise)h+=`<div class="trow">${B('r-','−')}${B('raise',(c.call?'RAISE ':'BET ')+TB.raise+'◆',true,'go')}${B('r+','+')}${c.allin?B('allin','ALL IN '+c.stack+'◆'):''}</div>`;
    else if(c.allin&&c.stack>c.call)h+=`<div class="trow">${B('allin','ALL IN '+c.stack+'◆')}</div>`}
  if(me.stack<(v.game==='bj'?1:2))h+=`<p class="lede sm">You're out of shards at the table. Top up (+5 or +25) to keep playing.</p>`;
  if(v.phase==='wait'&&v.game==='he')h+=`<p class="lede sm">${v.seats.filter(s=>s&&!s.bot).length<2?'Waiting for one more player. Share the code '+TB.code+'.':'Dealing…'}</p>`;
  if(box._h!==h){box._h=h;box.innerHTML=h}}
$('tbActs').addEventListener('click',e=>{const b=e.target.closest('button[data-act]');if(!b||b.disabled)return;const a=b.dataset.act,v=TB.v;if(!v)return;
  if(a.startsWith('lim:'))return tbSend({op:'settings',id:TB.id,lim:+a.slice(4)});if(a==='tside')return tbSend({op:'settings',id:TB.id,side:!v.side});
  if(a==='myside')return tbSend({op:'side',id:TB.id,on:!v.seats[v.me].side});
  if(a.startsWith('chip:')){TB.amt=(TB.amt===2&&!TB.chipped?0:TB.amt)+(+a.slice(5));TB.chipped=1;tbActions(v,v.seats[v.me]);return}
  if(a==='clear'){TB.amt=1;TB.chipped=1;tbActions(v,v.seats[v.me]);return}
  if(a==='bet'){TB.chipped=0;return tbSend({op:'bet',id:TB.id,amt:TB.amt,side:!!v.seats[v.me].side})}
  if(a.startsWith('ins:'))return tbSend({op:'insure',id:TB.id,yes:a==='ins:1'});
  if(a==='r-'||a==='r+'){const c=v.can,step=Math.max(1,Math.round((c.maxPut-c.minPut)/10));TB.raise=Math.max(c.minPut,Math.min(c.maxPut,TB.raise+(a==='r+'?step:-step)));tbActions(v,v.seats[v.me]);return}
  if(a==='raise')return tbSend({op:'move',id:TB.id,a:'raise',amt:TB.raise});
  tbSend({op:'move',id:TB.id,a})});
$('tbGame').addEventListener('click',e=>{const b=e.target.closest('button');if(b){TB.game=b.dataset.g;renderTables()}});
$('tbLim').addEventListener('click',e=>{const b=e.target.closest('button');if(b){TB.lim=+b.dataset.l;renderTables()}});
$('tbSide').addEventListener('change',e=>{TB.side=e.target.checked});
$('tbOpenBtn').addEventListener('click',async()=>{tbMsg('Opening a table…');const r=await tbSend({op:'open',game:TB.game,lim:TB.lim,side:TB.side});if(TB.id)renderTables()});
const tbJoin=async code=>{if(!code)return;tbMsg('Joining…');await tbSend({op:'join',code});if(TB.id)renderTables();else{const m=$('tbMsg').textContent;TB.busy=false;await tbLobby();tbMsg(m)}};
$('tbJoinBtn').addEventListener('click',()=>tbJoin($('tbCode').value.trim().toUpperCase()));
$('tbList').addEventListener('click',e=>{const b=e.target.closest('button[data-code]');if(b)tbJoin(b.dataset.code)});
$('tbLeave').addEventListener('click',()=>tbSend({op:'leave',id:TB.id}));
for(const b of document.querySelectorAll('[data-top]'))b.addEventListener('click',()=>tbSend({op:'topup',id:TB.id,amt:+b.dataset.top}));
$('tbPick').addEventListener('click',async e=>{const b=e.target.closest('button[data-pick]');if(!b)return;await tbSend({op:'pick',id:TB.id,kind:b.dataset.pick});if(typeof syncLocker==='function')syncLocker()});
