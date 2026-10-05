// v0.10.0 THE PALISADE FALLS CASINO in the browser: a host (desktop) and a guest (phone portrait) play through the real
// buttons, with the real request handler behind a mocked Supabase (in-memory tables and balances) and a real PeerJS room.
// The TABLES front door (no table list: you walk), ENTER THE CASINO, joining by code, walking up to a seat and sitting
// (E on desktop, SIT on touch), the same table for both, a taken seat can't be taken, peeking at a table you stand next
// to, Blackjack, Roulette (the board, chips, SPIN, the result, last spins), Hold'em with the bot drawn in its seat and hole
// cards hidden, HAND HISTORY's CHECK (run in the browser), HOUSE RULES, no weapons, leaving the casino stands you up
// (shards home), a guest account refused, and screenshots in out/tables_*.png. node tables_ui.js
const {chromium}=require('playwright'),{ready,quiet}=require('./lib'),assert=require('node:assert/strict'),fs=require('node:fs');
const Q='peerhost=127.0.0.1&peerport=9000&peerpath=/&debug=1&cloud=1';
(async()=>{const H=await import('../supabase/functions/tables/handler.js');
 const users={A:{id:'a0000000-0000-4000-8000-00000000000a',anon:false,name:'BigU'},B:{id:'b0000000-0000-4000-8000-00000000000b',anon:false,name:'Rab'},G:{id:'d0000000-0000-4000-8000-00000000000d',anon:true,name:'Guest'}};
 const bal={[users.A.id]:600,[users.B.id]:400,[users.G.id]:50},tables=new Map(),hands=[],allOps=[];let nid=1;
 const tok=u=>'x.'+Buffer.from(JSON.stringify({sub:u.id,exp:4e9})).toString('base64url')+'.y';
 const byTok=t=>Object.values(users).find(u=>tok(u)===t);
 const applyOps=ops=>{for(const o of ops)if(o.uid&&o.d&&bal[o.uid]+o.d<0)return false;for(const o of ops)if(o.uid&&o.d)bal[o.uid]+=o.d;allOps.push(...ops);return true};
 const D={now:()=>Date.now(),auth:async t=>{const u=byTok(t);return u&&{id:u.id,anon:u.anon}},name:async id=>Object.values(users).find(u=>u.id===id).name,balance:async id=>bal[id]||0,
  load:async id=>{const t=tables.get(id);return t&&JSON.parse(JSON.stringify(t))},byRoom:async(room,game)=>[...tables.values()].find(t=>t.open&&t.room===room&&t.game===game)||null,
  seatOf:async id=>{const t=[...tables.values()].find(t=>t.open&&t.humans.includes(id));return t?{id:t.id,code:t.code,game:t.game,room:t.room}:null},stale:async()=>[],botLeft:async()=>25,
  history:async uid=>hands.filter(h=>(h.result.players||[]).some(p=>p.uid===uid)).slice(-50).reverse(),
  commit:async a=>{const t=tables.get(a.id);if(t.ver!==a.ver)return{conflict:true};if(!applyOps(a.ops))return{error:'insufficient'};Object.assign(t,{st:a.st,ver:t.ver+1,humans:a.humans,open:a.open});
   for(const h of a.hands)hands.push({game:t.game,hand_no:h.no,hash:h.hash,salt:h.salt,deck:h.deck,result:h.result,created_at:new Date().toISOString()});return{ok:true}},
  create:async a=>{if([...tables.values()].some(t=>t.open&&t.room===a.room&&t.game===a.game))return{conflict:true};if(!applyOps(a.ops))return{error:'insufficient'};const id=nid++;tables.set(id,{id,code:a.code,game:a.game,room:a.room,st:a.st,ver:0,humans:a.humans,open:true});return{ok:true,id}}};
 const b=await chromium.launch({executablePath:process.env.CHROMIUM||undefined}),errors=[],out={};
 const open=async(u,vp,m)=>{const ctx=await b.newContext({viewport:vp,isMobile:m,hasTouch:m});
  await ctx.route('https://puvjfhwxigxjpsvdwrwf.supabase.co/**',async route=>{const r=route.request(),url=new URL(r.url());let body=null;try{body=r.postDataJSON()}catch(e){}
   if(url.pathname==='/functions/v1/tables'){const res=await H.handle(body,(r.headers().authorization||'').replace('Bearer ',''),D);return route.fulfill({status:res.status,contentType:'application/json',body:JSON.stringify(res.body)})}
   if(url.pathname==='/rest/v1/rpc/get_my_locker')return route.fulfill({status:200,contentType:'application/json',body:JSON.stringify({owned:['skin:std'],eq:{},cases:0,shards:bal[u.id],bag:{},st:{},rev:1,username:u.name})});
   return route.fulfill({status:200,contentType:'application/json',body:'null'})});
  const p=await ctx.newPage();p.on('pageerror',e=>errors.push(u.name+': '+e.message));p.on('console',m=>{if(m.type()==='error'&&!/Failed to load|net::|404/.test(m.text()))console.log('CONSOLE',u.name,m.text().slice(0,300))});
  await p.addInitScript(([s])=>{localStorage.setItem('palisade.auth.v1',s)},[JSON.stringify({access_token:tok(u),refresh_token:'r',expires_at:4e9,user:{id:u.id,is_anonymous:u.anon,email:u.anon?undefined:u.name+'@x.y',user_metadata:{pw:true}}})]);
  await p.goto(`http://localhost:${process.env.PORT||8080}/debug.html?${Q}`);await ready(p);return p};
 const host=await open(users.A,{width:1366,height:820},false),guest=await open(users.B,{width:390,height:844},true);
 const V=p=>p.evaluate(()=>__pal.TB.v),poke=p=>p.evaluate(()=>{const T=__pal.TB;if(T.id)__pal.tbSend({op:'state',id:T.id},true)}).catch(()=>{}),
  until=async(p,f,ms=20000)=>{const t=Date.now();for(;;){const v=await V(p);if(v&&f(v))return v;if(Date.now()-t>ms)throw new Error('timed out waiting: '+JSON.stringify(v&&{phase:v.phase,myTurn:v.myTurn,game:v.game}));await poke(p);await p.waitForTimeout(80)}},
  wait=async(p,fn,arg,ms=15000)=>p.waitForFunction(fn,arg,{timeout:ms});
 const tab=async p=>{await p.click('[data-nav=tables]');await quiet(p)};
 // walk (well, step) next to a seat: table game, seat k
 const goSeat=async(p,gm,k)=>{const f=([gm,k,id])=>{const t=__pal.CAS.tables.find(t=>t.game===gm),[x,y]=t.seats[k],P=id?[...__pal.players.values()].find(o=>o.id!=='host'):__pal.player;P.x=x+.1;P.y=y+.1};
  if(p===guest)await host.evaluate(f,[gm,k,1]);await p.evaluate(f,[gm,k,0])};   // a guest's position is the host's too (it checks every step)
 const sitDesk=async(p,gm,k)=>{await goSeat(p,gm,k);await p.waitForTimeout(150);await p.keyboard.press('e');await p.waitForSelector('#casSheet:not([hidden])',{timeout:10000});await quiet(p)};
 const sitTouch=async(p,gm,k)=>{await goSeat(p,gm,k);await p.waitForSelector('#casSitBtn:not([hidden])',{timeout:5000});await p.tap('#casSitBtn');await p.waitForSelector('#casSheet:not([hidden])',{timeout:10000});await quiet(p)};
 const standUp=async(p,...also)=>{for(let k=0;k<80;k++){for(const q of also){const w=await V(q);if(w&&w.myTurn)await q.click(w.can.check?'[data-act=check]':'[data-act=call]').catch(()=>{})}const v=await V(p);if(!v||v.me<0)break;if(v.phase!=='play'&&v.phase!=='ins'&&v.phase!=='spin'){await p.click('#tbLeave');await quiet(p)}else{if(v.myTurn)await p.click(v.game==='bj'?'[data-act=stand]':'[data-act=fold]');await poke(p);await p.waitForTimeout(150)}}
  await wait(p,()=>!__pal.TB.id&&!__pal.player.seat)};

 // 1. the front door: the balance, ENTER THE CASINO, JOIN BY CODE; no list of tables to pick from
 await tab(host);assert.equal(await host.textContent('#tbBal'),'600','the front door shows the shard balance');
 assert.equal(await host.$('#tbList'),null,'no table list: you walk up to a table');assert.equal(await host.$('#tbOpenBtn'),null,'no OPEN A TABLE');
 await host.screenshot({path:__dirname+'/out/tables_door_desktop.png'});
 await host.click('#casEnterBtn');await wait(host,()=>__pal.game&&__pal.game.mode==='casino'&&__pal.NET.mode==='host'&&__pal.NET.inGame&&!__pal.NET.autoCasino);
 out.room=await host.evaluate(()=>__pal.NET.code);assert.ok(/^[A-Z0-9]{4}$/.test(out.room),'the casino is a room with a code');
 assert.equal(await host.evaluate(()=>__pal.game.map),'casino');assert.equal(await host.evaluate(()=>__pal.enemies.length),0,'no raiders');
 await tab(guest);await guest.screenshot({path:__dirname+'/out/tables_door_portrait.png'});await guest.fill('#tbCode',out.room);await guest.tap('#tbJoinBtn');
 await wait(guest,()=>__pal.game&&__pal.game.mode==='casino'&&__pal.NET.mode==='guest'&&__pal.NET.inGame,null,20000);
 await wait(host,()=>__pal.players.size===2);await host.waitForTimeout(600);
 assert.equal(await guest.evaluate(()=>__pal.NET.casRoom),await host.evaluate(()=>'R:'+__pal.NET.code+':'+__pal.NET.incarnation),'the guest is in the host\'s casino room');
 await host.screenshot({path:__dirname+'/out/tables_casino_desktop.png'});await guest.screenshot({path:__dirname+'/out/tables_casino_portrait.png'});
 // 2. no weapons in the casino
 {const n0=await host.evaluate(()=>__pal.bullets.length);await host.mouse.move(700,300);await host.mouse.down();await host.waitForTimeout(500);await host.mouse.up();assert.equal(await host.evaluate(()=>__pal.bullets.length),n0,'holding fire does nothing in the casino')}
 // 3. blackjack: the host walks up and presses E; the guest walks up and taps SIT; the same table
 await sitDesk(host,'bj',0);assert.equal(bal[users.A.id],595,'the buy-in');
 const hv=await V(host);assert.equal(hv.game,'bj');assert.equal(hv.me,0,'the seat you walked up to');
 assert.equal(await host.evaluate(()=>__pal.player.seat),11,'seat code: table 1 seat 0');
 await wait(guest,()=>{const h=[...__pal.players.values()].find(p=>p.id==='host');return h&&h.seat===11},null,8000);
 // the guest can't take the host's seat, but can peek at the table while standing next to it
 {await goSeat(guest,'bj',0);await guest.waitForTimeout(300);assert.equal(await guest.evaluate(()=>{const s=__pal.casSeatNearHook(__pal.player);return !!(s&&s.k===0)}),false,'a taken seat can\'t be taken');
  await wait(guest,()=>!!__pal.casView('bj'),null,8000);out.peek=true}
 await sitTouch(guest,'bj',1);
 {const gv=await V(guest);assert.equal(gv.me,1);assert.equal(await guest.evaluate(()=>__pal.TB.id),await host.evaluate(()=>__pal.TB.id),'one blackjack table for the room')}
 {const v0=await until(guest,v=>v.seats.filter(Boolean).length===2);assert.ok(!v0.started,'nothing is dealt until the first to sit starts it');assert.match(await guest.textContent('#tbStatus'),/WAITING FOR BIGU/i);
  await host.click('[data-act=start]')}
 for(const p of[host,guest]){await until(p,v=>v.phase==='bet');await p.click('[data-act="set:1"]');await p.click('[data-act=bet]')}
 for(let k=0;k<160;k++){let moved=false;for(const p of[host,guest]){const v=await V(p);if(v.insure){await p.click('[data-act="ins:0"]');moved=true}if(v.myTurn){await p.click('[data-act=stand]');await quiet(p);moved=true}}
  if(!moved){const v=await V(host);if(v.phase==='done'||(v.phase==='bet'&&v.last))break;await poke(host);await poke(guest);await host.waitForTimeout(100)}}
 let v=await until(host,v=>v.last&&v.last.no===1);out.bj=v.last.result;await host.waitForTimeout(400);
 await host.screenshot({path:__dirname+'/out/tables_bj_desktop.png'});await guest.screenshot({path:__dirname+'/out/tables_bj_portrait.png'});
 // HIDE keeps you seated; E opens the table again
 await host.click('#tbHide');assert.ok(await host.evaluate(()=>__pal.player.seat===11&&__pal.TB.id>0),'HIDE keeps your seat');await host.keyboard.press('e');await host.waitForSelector('#casSheet:not([hidden])');
 // 4. roulette: the host stands up (shards home) and walks to the wheel
 await standUp(host);assert.ok(bal[users.A.id]>=590,'standing up sends the stack home');
 await sitDesk(host,'rl',2);v=await until(host,v=>v.game==='rl'&&v.phase==='bet');assert.equal(v.me,2);assert.equal(v.lim,0,'roulette is always no limit');
 await host.waitForSelector('#rlNums');
 {for(const k of[0,1]){await host.click('[data-top="25"]');await quiet(host)}await until(host,v=>v.seats[2].stack===55);
  await host.click('[data-act="chip:5"]');const box=()=>host.$eval('#rlNums',e=>{const r=e.getBoundingClientRect();return{x:r.left,y:r.top,w:r.width,h:r.height}});
  const tapAt=async(col,row,fx,fy)=>{const bx=await box();await host.mouse.click(bx.x+(col+1+fx)/13*bx.w,bx.y+(row+fy)/3*bx.h);await host.waitForTimeout(60)};
  out.boardY=[(await box()).y];
  await tapAt(5,1,.5,.5);                       // the 17 (column 5, middle row)
  await tapAt(5,1,.97,.5);                      // the line between 17 and 20: a split
  await tapAt(0,2,.5,.97);                      // the bottom of 1-2-3: a street
  await tapAt(-1,0,.5,.8);                      // 00 (the top half of the left column)
  out.boardY.push((await box()).y);assert.equal(out.boardY[0],out.boardY[1],'the board doesn\'t move while you bet')
  await host.click('[data-act="chip:1"]');await host.click('.rout[data-spot=red]');await host.click('.rout[data-spot=red]');
  await host.waitForTimeout(700);await quiet(host);
  v=await until(host,v=>Object.keys(v.myBets||{}).length===5);assert.deepEqual(v.myBets,{'n:17':5,'sp:17-20':5,'st:1':5,'n:37':5,red:2},'what you tap is what the server holds');
  await host.screenshot({path:__dirname+'/out/tables_rl_desktop.png'});
  const before=v.seats[2].stack;await host.click('[data-act=rlspin]');v=await until(host,v=>v.phase==='spin');assert.ok(v.number>=0&&v.number<=37,'the number shows once the ball goes');
  await poke(host);await quiet(host);assert.equal(await host.$$eval('#rlNums .rn.hit',x=>x.length),0,'the board doesn\'t light the number while the ball is still spinning');
  await host.waitForTimeout(1500);await host.screenshot({path:__dirname+'/out/tables_rl_spin_desktop.png'});
  v=await until(host,v=>v.phase==='done'||v.phase==='bet'&&v.last,15000);const L=v.last,n=L.result.number,E=await import('../supabase/functions/tables/engine.js');
  const back=E.rlPay({'n:17':5,'sp:17-20':5,'st:1':5,'n:37':5,red:2},n);out.rl={n,back};assert.equal(v.seats[2].stack,before+back,'paid exactly what the spots pay');
  assert.ok((v.hist||[]).includes(n),'last spins shows it');await poke(host);await quiet(host);if((await V(host)).phase==='done')assert.equal(await host.$$eval('#rlNums .rn.hit',x=>x.length),1,'once it lands, the number lights up');await poke(host);await quiet(host);assert.match(await host.textContent('#tbFelt'),/LAST SPINS/);
  // REBET puts the same bets back
  await until(host,v=>v.phase==='bet'&&!v.number);await host.click('[data-act=rlrebet]');await host.waitForTimeout(700);v=await until(host,v=>Object.keys(v.myBets||{}).length===5);out.rebet=true}
 // the guest's phone shows roulette too: stand up at blackjack, sit at the wheel
 await standUp(guest);await sitTouch(guest,'rl',4);await until(guest,v=>v.game==='rl');await guest.waitForTimeout(300);await guest.screenshot({path:__dirname+'/out/tables_rl_portrait.png'});
 // 5. HAND HISTORY: CHECK reruns the spin and the shoe in the browser
 await host.click('.tbSheetBtns [data-hist]');await host.waitForSelector('#tbHistList button[data-check]',{timeout:8000});
 {const n=await host.$$eval('#tbHistList button[data-check]',x=>x.length);assert.ok(n>=2,'blackjack and roulette are in the history');
  for(let i=0;i<n;i++){await host.click(`#tbHistList button[data-check="${i}"]`);await host.waitForFunction(i=>/FAIR|✗/.test(document.getElementById('hc'+i).textContent),i,{timeout:20000})}
  const res=await host.$$eval('.hcheck',x=>x.map(e=>e.textContent));out.checks=res;assert.ok(res.every(t=>/✓ FAIR/.test(t)),'every hand checks out: '+res.join(' | '))}
 await host.screenshot({path:__dirname+'/out/tables_history_desktop.png'});await host.click('#tbHist [data-close]');
 await host.click('.tbSheetBtns [data-rules]');assert.match(await host.textContent('#tbRulesTxt'),/5\.26%/);assert.match(await host.textContent('#tbRulesTxt'),/7\.89%/);await host.click('#tbRules [data-close]');
 // 6. hold'em: both at the poker table; the bot takes a seat (and is drawn in it); other hole cards stay hidden
 await standUp(host);await standUp(guest);await sitDesk(host,'he',0);await sitTouch(guest,'he',2);
 await until(host,v=>v.seats.filter(s=>s&&!s.bot).length===2);await host.click('[data-act=start]');v=await until(host,v=>v.phase==='play');
 const botSeat=v.seats.findIndex(s=>s&&s.bot);assert.ok(botSeat>=0,'the bot sits in');
 await wait(host,k=>!!__pal.casTakenHook(20+k+1),botSeat,6000);
 assert.ok(await host.evaluate(()=>{const v=__pal.TB.v;return v.players.filter(p=>p.seat!==v.me).every(p=>p.cards[0]===null)}),'other players\' cards are face down');
 await host.screenshot({path:__dirname+'/out/tables_he_desktop.png'});
 // play the hand out, then HAND HISTORY checks the Hold'em cards you saw against their fingerprints (no seed for 24 hours)
 for(let k=0;k<400;k++){let hv2=await V(host);if(hv2.phase==='done'||hv2.last&&hv2.last.no>=1)break;for(const p of[host,guest]){const w=await V(p);if(w&&w.myTurn)await p.click(w.can.check?'[data-act=check]':'[data-act=call]').catch(()=>{})}await poke(host);await host.waitForTimeout(120)}
 await host.click('.tbSheetBtns [data-hist]');await host.waitForSelector('#tbHistList button[data-check]');
 {const i=await host.$$eval('#tbHistList .hrow b',x=>x.findIndex(e=>/HOLD/.test(e.textContent)));assert.ok(i>=0,'the hold\'em hand is in the history');
  await host.click(`#tbHistList button[data-check="${i}"]`);await host.waitForFunction(i=>/FAIR|✗/.test(document.getElementById('hc'+i).textContent),i,{timeout:20000});
  out.heCheck=await host.textContent('#hc'+i);assert.match(out.heCheck,/✓ FAIR\. The \d+ cards you saw/,'hold\'em: every card you saw checks out')}
 await host.click('#tbHist [data-close]');
 const land=await open(users.B,{width:844,height:390},true);await tab(land);await land.screenshot({path:__dirname+'/out/tables_door_landscape.png'});
 await land.waitForSelector('#tbMine:not([hidden])',{timeout:8000});assert.match(await land.textContent('#tbMine'),/HOLD'EM/,'on another device: you\'re still seated, and can stand up from here');await land.close();
 // 7. leaving the casino stands you up: shards home
 await standUp(guest,host);const g0=bal[users.B.id];
 await host.evaluate(()=>__pal.leaveRun());await host.waitForTimeout(800);assert.equal(await host.evaluate(()=>__pal.TB.id),0,'leaving the casino stands you up');
 assert.ok(![...tables.values()].some(t=>t.open&&t.humans.includes(users.A.id)),'not seated anywhere');out.after={a:bal[users.A.id],b:bal[users.B.id]};
 {const tables0=[...tables.values()].filter(t=>t.open);assert.equal(tables0.length,0,'every table closed');const house=hands.reduce((x,h)=>x+(h.result.house|0),0),bot=allOps.filter(o=>o.k==='bot').reduce((x,o)=>x+o.d,0);
  out.books={lost:1000-bal[users.A.id]-bal[users.B.id],house,bot};assert.equal(out.books.lost,house+bot,'the books balance to the shard: what left the balances = the house\'s take + the bot '+JSON.stringify(out.books))}void g0;
 // 8. a guest account is refused at the door
 const gp=await open(users.G,{width:390,height:844},true);await tab(gp);out.guestMsg=await gp.textContent('#tbMsg');assert.match(out.guestMsg,/account/i);assert.ok(await gp.isDisabled('#casEnterBtn'),'ENTER is off for guests');
 assert.deepEqual(errors,[],'no page errors');
 fs.writeFileSync(__dirname+'/out/tables_ui.json',JSON.stringify(out,null,1));console.log(JSON.stringify(out));console.log('errors: none');await b.close();
})().catch(e=>{console.error(e);process.exit(1)});
