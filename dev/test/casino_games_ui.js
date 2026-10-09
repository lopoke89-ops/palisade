// v0.10.3 the new casino games in the browser, through the real buttons, with the real request handler behind a mocked
// Supabase (in-memory tables, balances and operation ids) and a real PeerJS room. A desktop host (1366x820) plays baccarat
// (chips, Banker in 20s, DEAL, the cards turning, the receipt held for its review), craps (Pass Line, ROLL, Place 6 in 6s,
// the take-down mode, the receipt with what is still working), a slot cabinet (SPIN locked through the reels and the review;
// a spin whose answer is lost after the server took it is retried with the same operation id and paid once), and Plinko
// (the 10-shard minimum and the top-up path, the ball, the pocket). LAST RESULT after standing up. A phone guest in portrait
// plays another cabinet by touch; a landscape phone with reduced motion: no animation, the review still held. Screenshots
// in out/casino_games_*.png. node casino_games_ui.js
const {chromium}=require('playwright'),{ready,quiet}=require('./lib'),assert=require('node:assert/strict'),fs=require('node:fs');
const Q='peerhost=127.0.0.1&peerport=9000&peerpath=/&debug=1&cloud=1';
(async()=>{const H=await import('../supabase/functions/tables/handler.js');
 const users={A:{id:'a0000000-0000-4000-8000-00000000000a',anon:false,name:'BigU'},B:{id:'b0000000-0000-4000-8000-00000000000b',anon:false,name:'Rab'},C:{id:'c0000000-0000-4000-8000-00000000000c',anon:false,name:'Lan'}};
 const bal={[users.A.id]:2000,[users.B.id]:400,[users.C.id]:400},tables=new Map(),hands=[],opsLog=new Map(),out={},seenOps=[];let nid=1,dropNextSpin=0;
 const tok=u=>'x.'+Buffer.from(JSON.stringify({sub:u.id,exp:4e9})).toString('base64url')+'.y',byTok=t=>Object.values(users).find(u=>tok(u)===t);
 const applyOps=ops=>{for(const o of ops)if(o.uid&&o.d&&bal[o.uid]+o.d<0)return false;for(const o of ops)if(o.uid&&o.d)bal[o.uid]+=o.d;return true};
 const D={now:()=>Date.now(),auth:async t=>{const u=byTok(t);return u&&{id:u.id,anon:u.anon}},name:async id=>Object.values(users).find(u=>u.id===id).name,balance:async id=>bal[id]||0,
  load:async id=>{const t=tables.get(id);return t&&JSON.parse(JSON.stringify(t))},byRoom:async(room,game,station)=>[...tables.values()].find(t=>t.open&&t.room===room&&t.game===game&&t.station===(station||''))||null,
  seatOf:async id=>{const t=[...tables.values()].find(t=>t.open&&t.humans.includes(id));return t?{id:t.id,code:t.code,game:t.game,room:t.room,station:t.station}:null},stale:async()=>[],botLeft:async()=>25,
  opGet:async(u,o)=>opsLog.get(u+'|'+o)||null,history:async uid=>hands.filter(h=>(h.result.players||[]).some(p=>p.uid===uid)).slice(-50).reverse(),
  commit:async a=>{const t=tables.get(a.id);if(t.ver!==a.ver)return{conflict:true};if(a.op&&opsLog.has(a.op.uid+'|'+a.op.id))return{dup:true};if(!applyOps(a.ops))return{error:'insufficient'};
   Object.assign(t,{st:a.st,ver:t.ver+1,humans:a.humans,open:a.open});if(a.op)opsLog.set(a.op.uid+'|'+a.op.id,{req:a.op.req,table_id:a.id,res:a.op.res});
   for(const h of a.hands)hands.push({id:hands.length+1,game:t.game,hand_no:h.no,hash:h.hash,salt:h.salt,deck:h.deck,result:h.result,created_at:new Date().toISOString()});return{ok:true}},
  create:async a=>{if([...tables.values()].some(t=>t.open&&t.room===a.room&&t.game===a.game&&t.station===(a.station||'')))return{conflict:true};if(!applyOps(a.ops))return{error:'insufficient'};const id=nid++;
   tables.set(id,{id,code:a.code,game:a.game,room:a.room,station:a.station||'',st:a.st,ver:0,humans:a.humans,open:true});if(a.op)opsLog.set(a.op.uid+'|'+a.op.id,{req:a.op.req,table_id:id,res:a.op.res});return{ok:true,id}}};
 const relay=process.env.PALISADE_TEST_RELAY?await require('./relay-fixture').start(users,tok):null;
 const b=await chromium.launch({executablePath:process.env.CHROMIUM||undefined}),errors=[];
 const open=async(u,vp,m,extra={})=>{const ctx=await b.newContext({viewport:vp,isMobile:m,hasTouch:m,...extra});
  await ctx.route('https://puvjfhwxigxjpsvdwrwf.supabase.co/**',async route=>{const r=route.request(),url=new URL(r.url());let body=null;try{body=r.postDataJSON()}catch(e){}
   if(url.pathname==='/functions/v1/tables'){if(body&&body.opId)seenOps.push([body.op,body.opId]);const res=await H.handle(body,(r.headers().authorization||'').replace('Bearer ',''),D);
    if(body&&body.op==='spin'&&dropNextSpin){dropNextSpin--;return route.abort('connectionreset')}   // the server took it; the answer never arrives
    return route.fulfill({status:res.status,contentType:'application/json',body:JSON.stringify(res.body)})}
   if(url.pathname==='/rest/v1/rpc/get_my_locker')return route.fulfill({status:200,contentType:'application/json',body:JSON.stringify({owned:['skin:std'],eq:{},cases:0,shards:bal[u.id],bag:{},st:{},rev:1,username:u.name})});
   return route.fulfill({status:200,contentType:'application/json',body:'null'})});
  const p=await ctx.newPage();p.on('pageerror',e=>errors.push(u.name+': '+e.message));p.on('console',m=>{if(m.type()==='error'&&!/Failed to load|net::|404|ERR_CONNECTION/.test(m.text()))console.log('CONSOLE',u.name,m.text().slice(0,300))});
  await p.addInitScript(([s])=>{localStorage.setItem('palisade.auth.v1',s)},[JSON.stringify({access_token:tok(u),refresh_token:'r',expires_at:4e9,user:{id:u.id,is_anonymous:false,email:u.name+'@x.y',user_metadata:{pw:true}}})]);
  await p.goto(`http://localhost:${process.env.PORT||8080}/debug.html?${Q}`);await ready(p);
  await p.evaluate(on=>globalThis.PALISADE_RELAY=on?{enabled:true,url:'http://127.0.0.1:10000'}:{enabled:false,url:''},!!relay);
  if(relay)p.on('request',r=>{if(/peerjs|palisade-turn/.test(r.url()))errors.push('Relay loaded P2P: '+r.url())});return p};
 const host=await open(users.A,{width:1366,height:820},false);
 const V=p=>p.evaluate(()=>{const v=__pal.TB.v;return v&&JSON.parse(JSON.stringify(v))}),poke=p=>p.evaluate(()=>{const T=__pal.TB;if(T.id)return __pal.tbSend({op:'state',id:T.id},true)}).catch(()=>{});
 const until=async(p,f,ms=30000,why='')=>{const t=Date.now();for(;;){const v=await V(p);if(v&&f(v))return v;if(Date.now()-t>ms)throw new Error('timed out waiting '+why+': '+JSON.stringify(v&&{phase:v.phase,game:v.game,review:v.review}));await poke(p);await p.waitForTimeout(120)}};
 const act=(p,a)=>p.click(`#tbActs [data-act="${a}"]`);
 const spot=async(p,k)=>{const el=await p.$(`#tbFelt [data-cg="${k}"]`);const bb=await el.boundingBox();await p.mouse.click(bb.x+bb.width/2,bb.y+bb.height/2);await p.waitForTimeout(60)};
 const goTo=(p,pos)=>p.evaluate(([x,y])=>{const P=__pal.player;P.x=x;P.y=y},pos);
 const sit=async(p,pos,key=true)=>{await goTo(p,pos);await p.waitForTimeout(150);if(key)await p.keyboard.press('e');else await p.tap('#casSitBtn');await p.waitForSelector('#casSheet:not([hidden])',{timeout:10000});await quiet(p)};
 const stand=async p=>{await p.click('#tbLeave');await p.waitForFunction(()=>!__pal.TB.id&&!__pal.player.seat,null,{timeout:15000})};
 const rcpt=p=>p.evaluate(()=>{const e=document.querySelector('#tbFelt .trcpt:not(.live)');return e&&{verdict:e.querySelector('.trv b').textContent,nums:[...e.querySelectorAll('.trn b')].map(b=>b.textContent),text:e.textContent}});

 // the casino (a room of its own)
 await host.click('[data-nav=tables]');await quiet(host);await host.click('#casEnterBtn');await host.waitForFunction(()=>__pal.game&&__pal.game.mode==='casino'&&__pal.NET.inGame&&!__pal.NET.autoCasino,null,{timeout:15000});
 out.room=await host.evaluate(()=>__pal.NET.code);const T=await host.evaluate(()=>({ba:__pal.CAS.tables.find(t=>t.game==='ba').seats[2],cr:__pal.CAS.tables.find(t=>t.game==='cr').seats[1],s3:__pal.CAS.machines[2].stand,s4:__pal.CAS.machines[3].stand,p1:__pal.CAS.machines[16].stand}));

 // 1. BACCARAT
 await sit(host,T.ba);let v=await until(host,v=>v.game==='ba'&&v.phase==='bet',15000,'baccarat bets');
 assert.ok(await host.$eval('#tbActs [data-act="chip:20"]',b=>b.disabled),'5 shards at the table: the 20 chip waits for a top-up');await host.click('[data-top="100"]');await until(host,v=>v.seats[v.me].stack===105,8000,'top up');
 await act(host,'chip:20');await spot(host,'ba:B');await spot(host,'ba:B');await act(host,'chip:5');await spot(host,'ba:P');
 v=await until(host,v=>v.myBets&&v.myBets.B===40&&v.myBets.P===5,8000,'bets saved');out.baBets=v.myBets;
 assert.match(await host.textContent('#tbFelt'),/20 on Banker pays 19 plus your 20 back/,'the Banker rule is explained before the bet');
 await act(host,'ready');v=await until(host,v=>v.phase==='done',15000,'the deal');
 assert.ok(await host.$('#tbFelt .trcpt.live'),'while the cards turn: DEALING, no verdict yet');await host.screenshot({path:__dirname+'/out/casino_games_baccarat_deal.png'});
 await host.waitForSelector('#tbFelt .trcpt:not(.live)',{timeout:8000});const rb=await rcpt(host);out.baccarat=rb;
 assert.ok(['WIN','LOSS','PUSH','PARTIAL RESULT'].includes(rb.verdict),'a verdict in words: '+rb.verdict);assert.equal(rb.nums[0],'45◆','BET 45');assert.match(rb.text,/PLAYER \d/);assert.match(rb.text,/BANKER \d/);
 if(/Banker \d beats/.test(rb.text))assert.match(rb.text,/commission 2◆/,'commission itemized: 40 Banker -> 2');
 {const s=await V(host);assert.ok(s.review>3000,'the review is held after the last card (≈8 s)')}await host.screenshot({path:__dirname+'/out/casino_games_baccarat_review.png'});
 {const t0=Date.now();await until(host,v=>v.phase==='bet',20000,'next bets');out.baReviewMs=Date.now()-t0}
 await host.click('#tbLastBtn');await host.waitForSelector('#tbRcptM:not([hidden])');assert.match(await host.textContent('#tbRcptTxt'),/BACCARAT/,'LAST RESULT after betting reopened');await host.click('#tbRcptM [data-close]');
 await stand(host);

 // 2. CRAPS
 await sit(host,T.cr);v=await until(host,v=>v.game==='cr'&&v.phase==='bet',15000,'craps bets');await host.click('[data-top="100"]');await until(host,v=>v.seats[v.me].stack===105,8000,'top up');assert.equal(v.point,0,'come-out');
 assert.ok(await host.$eval('#tbFelt [data-cg="cr:come"]',b=>b.disabled),'no Come bet on the come-out');
 await act(host,'chip:10');await spot(host,'cr:pass');v=await until(host,v=>v.myBets.pass===10,8000,'pass line');
 let rolls=0;for(;rolls<30;rolls++){v=await V(host);if(v.point&&v.phase==='bet')break;if(v.phase==='bet'){if(!(v.myBets.pass>0)){await spot(host,'cr:pass');await until(host,v=>v.myBets.pass>0,8000)}
   await host.waitForSelector('#tbActs [data-act="ready"]',{timeout:8000});await act(host,'ready');await until(host,v=>v.phase==='done',20000,'the roll')}
  await host.waitForSelector('#tbFelt .trcpt:not(.live)',{timeout:8000});if(rolls===0){out.crapsFirst=await rcpt(host);await host.screenshot({path:__dirname+'/out/casino_games_craps_review.png'})}
  await until(host,v=>v.phase==='bet',20000,'betting again')}
 assert.ok(v.point>0,'a point is on');assert.ok(await host.$eval('#tbFelt [data-cg="cr:pass"]',b=>b.disabled),'the Pass Line is locked on a point');
 await act(host,'chip:5');await spot(host,'cr:p6');v=await until(host,v=>v.myBets.p6>0,8000,'place 6');assert.equal(v.myBets.p6%6,0,'Place 6 goes in 6s: a 5 chip becomes 6');
 await act(host,'down');await spot(host,'cr:p6');v=await until(host,v=>!v.myBets.p6,8000,'take down');await act(host,'down');
 await act(host,'adv');assert.ok(await host.$('#tbFelt [data-cg="cr:h8"]'),'ALL BETS shows hardways and props');await host.screenshot({path:__dirname+'/out/casino_games_craps_desktop.png'});
 out.craps={rolls,point:v.point};await stand(host);   // leaving on a point: the pass bet stays, the dealer rolls it out
 out.crapsPendingAfterStand=await host.evaluate(()=>!!__pal.TB.mine);

 // 3. SLOTS (cabinet 3)
 await host.evaluate(()=>{__pal.TB.mine=null});const crT=[...tables.values()].find(t=>t.game==='cr'&&t.open);
 if(crT){for(let k=0;k<80&&tables.get(crT.id).open;k++){await H.handle({op:'lobby'},tok(users.A),D);await new Promise(f=>setTimeout(f,150))}}   // the dealer rolls out what you left (the lobby asks)
 await sit(host,T.s3);v=await until(host,v=>v.game==='sl'&&v.phase==='idle',15000,'the machine');assert.equal(v.station,'s3');
 await host.click('#tbFoot [data-top="25"]').catch(()=>host.click('[data-top="25"]'));await until(host,v=>v.seats[0].stack===30,8000,'top up');
 await act(host,'set:5');await act(host,'spin');await host.waitForTimeout(300);
 assert.ok(await host.$eval('#tbActs [data-act="spin"]',b=>b.disabled),'SPIN locked while the reels turn');assert.ok(await host.$('#tbFelt .slreel.spin'),'reels spinning');
 await host.screenshot({path:__dirname+'/out/casino_games_slots_spin.png'});
 await host.waitForSelector('#tbFelt .trcpt:not(.live)',{timeout:8000});const rs=await rcpt(host);out.slots=rs;assert.equal(rs.nums[0],'5◆');
 assert.ok(await host.$eval('#tbActs [data-act="spin"]',b=>b.disabled),'SPIN still locked during the 3 s review');await host.screenshot({path:__dirname+'/out/casino_games_slots_review.png'});
 await until(host,v=>v.phase==='idle',10000,'machine idle');await host.waitForSelector('#tbActs [data-act="spin"]:not([disabled])',{timeout:5000});
 // the answer to a spin is lost after the server took it: the client retries with the same id, the server answers from its record
 const before=await V(host),bal0=bal[users.A.id];dropNextSpin=1;await act(host,'spin');
 v=await until(host,v=>v.handNo===before.handNo+1&&v.phase!=='idle',15000,'the retried spin');await host.waitForTimeout(800);
 const spins=seenOps.filter(x=>x[0]==='spin').slice(-2);assert.equal(spins.length,2);assert.equal(spins[0][1],spins[1][1],'the retry carries the same operation id');
 assert.equal((await V(host)).handNo,before.handNo+1,'one spin, not two');assert.equal(bal[users.A.id],bal0,'nothing extra left the balance');out.retry={id:spins[0][1]};
 await until(host,v=>v.phase==='idle',10000);await stand(host);

 // 4. PLINKO: the 10-shard minimum and the top-up path, then a drop
 await sit(host,T.p1);v=await until(host,v=>v.game==='pk'&&v.phase==='idle',15000,'plinko');
 assert.match(await host.textContent('#tbStatus'),/TOP UP/,'5 shards at the board: top up first');assert.ok(await host.$eval('#tbActs [data-act="drop"]',b=>b.disabled));
 await host.click('[data-top="25"]');await until(host,v=>v.seats[0].stack===30,8000);await act(host,'set:20');await act(host,'drop');
 // v0.10.3: the ball keeps falling through the whole drop. The table polls once a second, and each poll's view used to stop the
 // board's animation (the ball froze within a second, then jumped to its pocket). Tracked on the canvas: its height every 150 ms.
 await host.waitForFunction(()=>__pal.TB.v&&__pal.TB.v.phase==='done',null,{timeout:8000});
 const track=await host.evaluate(()=>new Promise(res=>{const out=[],t0=performance.now();const tick=()=>{const c=document.getElementById('cgPk');let y=null;
  if(c){const d=c.getContext('2d').getImageData(0,0,c.width,c.height).data;let n=0,s=0;for(let i=0;i<d.length;i+=4)if(d[i]>240&&d[i+1]>195&&d[i+1]<225&&d[i+2]<110){n++;s+=Math.floor(i/4/c.width)}if(n)y=Math.round(s/n)}
  out.push([Math.round(performance.now()-t0),y]);if(performance.now()-t0<2900)setTimeout(tick,150);else res(out)};tick()}));
 out.plinkoTrack=track;const late=new Set(track.filter(([t,y])=>t>=1300&&t<=2700&&y!==null).map(([,y])=>y));
 assert.ok(late.size>=4,'the ball still moves after the first poll (1.3-2.7 s into the drop): '+JSON.stringify(track));
 await host.screenshot({path:__dirname+'/out/casino_games_plinko_drop.png'});await host.waitForSelector('#tbFelt .trcpt:not(.live)',{timeout:8000});
 const rp=await rcpt(host);out.plinko=rp;assert.equal(rp.nums[0],'20◆');assert.match(rp.text,/Pocket \d+ of 13 pays/);await host.screenshot({path:__dirname+'/out/casino_games_plinko_review.png'});
 await until(host,v=>v.phase==='idle',10000);await stand(host);
 await host.click('[data-nav=tables]').catch(()=>{});
 // HAND HISTORY: CHECK every row in the browser (the baccarat hand against its shoe's fingerprints, the finished shoe rerun whole, rolls, spins, the drop)
 await host.evaluate(()=>__pal.tbHistory());await host.waitForSelector('#tbHistList button[data-check]',{timeout:8000});
 {const n=await host.$$eval('#tbHistList button[data-check]',x=>x.length);for(let i=0;i<n;i++){await host.click(`#tbHistList button[data-check="${i}"]`);await host.waitForFunction(i=>/FAIR|✗|reachable|No shoe|finished/.test(document.getElementById('hc'+i).textContent),i,{timeout:60000})}
  const res=await host.$$eval('.hcheck',x=>x.map(e=>e.textContent)),rows=await host.$$eval('#tbHistList .hrow b',x=>x.map(e=>e.textContent));out.history=rows.map((r,i)=>r+': '+res[i]);
  assert.ok(res.every(t=>/✓ FAIR/.test(t)),'every row checks: '+out.history.join(' | '));for(const g of['BACCARAT','CRAPS','SLOTS','PLINKO'])assert.ok(rows.some(r=>r.startsWith(g)),g+' in the history');
  assert.ok(res.some(t=>/whole shoe reruns/.test(t)),'the finished shoe reruns');assert.ok(res.some(t=>/fingerprint fixed when the shoe started/.test(t)),'the hand checks against the shoe')}
 await host.screenshot({path:__dirname+'/out/casino_games_history.png'});await host.evaluate(()=>{document.getElementById('tbHist').hidden=true});
 // LAST RESULT after standing up
 await host.evaluate(()=>__pal.tbLastResult());assert.match(await host.textContent('#tbRcptTxt'),/PLINKO/,'LAST RESULT after standing up');await host.evaluate(()=>{document.getElementById('tbRcptM').hidden=true});

 // 5. a phone guest in portrait plays cabinet 4 by touch
 const guest=await open(users.B,{width:390,height:844},true);await guest.click('[data-nav=tables]');await quiet(guest);await guest.fill('#tbCode',out.room);await guest.click('#tbJoinBtn');
 await guest.waitForFunction(()=>__pal.game&&__pal.game.mode==='casino'&&document.getElementById('menu').hidden,null,{timeout:20000});await guest.waitForTimeout(800);
 await host.evaluate(([x,y])=>{const P=[...__pal.players.values()].find(o=>o.id!=='host');P.x=x;P.y=y},T.s4);await guest.evaluate(([x,y])=>{const P=__pal.player;P.x=x;P.y=y},T.s4);await guest.waitForTimeout(300);
 await guest.waitForSelector('#casSitBtn:not([hidden])',{timeout:8000});assert.equal((await guest.textContent('#casSitBtn')).trim(),'PLAY','touch: PLAY at a machine');await guest.tap('#casSitBtn');
 await guest.waitForSelector('#casSheet:not([hidden])',{timeout:10000});v=await until(guest,v=>v.game==='sl'&&v.station==='s4'&&v.phase==='idle',15000);
 await guest.tap('#tbActs [data-act="spin"]');await guest.waitForSelector('#tbFelt .trcpt:not(.live)',{timeout:9000});await guest.screenshot({path:__dirname+'/out/casino_games_slots_portrait.png'});
 out.guestSlots=await rcpt(guest);await until(guest,v=>v.phase==='idle',10000);
 out.twoCabinets=[...tables.values()].filter(t=>t.game==='sl'&&t.open).map(t=>t.station).sort();
 // 6. a landscape phone with reduced motion: no reel animation, the review still held for its full time
 const land=await open(users.C,{width:844,height:390},true,{reducedMotion:'reduce'});await land.click('[data-nav=tables]');await quiet(land);await land.fill('#tbCode',out.room);await land.click('#tbJoinBtn');
 await land.waitForFunction(()=>__pal.game&&__pal.game.mode==='casino'&&document.getElementById('menu').hidden,null,{timeout:20000});await land.waitForTimeout(800);
 const s5=await land.evaluate(()=>__pal.CAS.machines[4].stand);await host.evaluate(([x,y,n])=>{const P=[...__pal.players.values()].find(o=>o.name===n||o.id!=='host'&&!o.seat);if(P){P.x=x;P.y=y}},[s5[0],s5[1],'Lan']);
 await land.evaluate(([x,y])=>{const P=__pal.player;P.x=x;P.y=y},s5);await land.waitForTimeout(300);await land.tap('#casSitBtn');await land.waitForSelector('#casSheet:not([hidden])',{timeout:10000});
 await until(land,v=>v.game==='sl'&&v.phase==='idle',15000);await land.tap('#tbActs [data-act="spin"]');await land.waitForTimeout(400);
 assert.ok(await land.$('#tbFelt .trcpt:not(.live)'),'reduced motion: the result shows at once');assert.ok(!(await land.$('#tbFelt .slreel.spin')),'no spinning reels');
 {const s=await V(land);assert.ok(s.phase==='done'&&s.review>4000,'but the server still holds the review (reveal + 3 s)')}await land.screenshot({path:__dirname+'/out/casino_games_slots_landscape.png'});
 assert.deepEqual(errors,[],'no page errors');fs.mkdirSync(__dirname+'/out',{recursive:true});fs.writeFileSync(__dirname+'/out/casino_games_ui.json',JSON.stringify(out,null,1));console.log(JSON.stringify(out).slice(0,1500));console.log('errors: none');await b.close();if(relay)await relay.stop();
})().catch(e=>{console.error(e);process.exit(1)});
