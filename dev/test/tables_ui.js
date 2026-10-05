// v0.9.8 THE TABLES in the browser: a host (desktop) and a guest (phone portrait) play Blackjack and Hold'em through the
// real buttons, with the real request handler behind a mocked Supabase (in-memory tables and balances). The TABLES tab,
// opening and joining from the list, betting, playing, results, the bot joining two players, hidden hole cards, standing
// up (shards back), a guest account refused, and screenshots at three sizes in out/tables_*.png. node tables_ui.js
const {chromium}=require('playwright'),{ready,quiet}=require('./lib'),assert=require('node:assert/strict'),fs=require('node:fs');
(async()=>{const H=await import('../supabase/functions/tables/handler.js');
 const users={A:{id:'a0000000-0000-4000-8000-00000000000a',anon:false,name:'BigU'},B:{id:'b0000000-0000-4000-8000-00000000000b',anon:false,name:'Rab'},G:{id:'d0000000-0000-4000-8000-00000000000d',anon:true,name:'Guest'}};
 const bal={[users.A.id]:60,[users.B.id]:40,[users.G.id]:50},tables=new Map();let nid=1;
 const tok=u=>'x.'+Buffer.from(JSON.stringify({sub:u.id,exp:4e9})).toString('base64url')+'.y';
 const byTok=t=>Object.values(users).find(u=>tok(u)===t);
 const applyOps=ops=>{for(const o of ops)if(o.uid&&o.d&&bal[o.uid]+o.d<0)return false;for(const o of ops)if(o.uid&&o.d)bal[o.uid]+=o.d;return true};
 const D={now:()=>Date.now(),auth:async t=>{const u=byTok(t);return u&&{id:u.id,anon:u.anon}},name:async id=>Object.values(users).find(u=>u.id===id).name,balance:async id=>bal[id]||0,
  load:async id=>{const t=tables.get(id);return t&&JSON.parse(JSON.stringify(t))},byCode:async c=>[...tables.values()].find(t=>t.code===c&&t.open),
  seatOf:async id=>[...tables.values()].find(t=>t.open&&t.humans.includes(id))||null,list:async()=>[...tables.values()].filter(t=>t.open),stale:async()=>[],botLeft:async()=>25,
  commit:async a=>{const t=tables.get(a.id);if(t.ver!==a.ver)return{conflict:true};if(!applyOps(a.ops))return{error:'insufficient'};Object.assign(t,{st:a.st,ver:t.ver+1,humans:a.humans,open:a.open});return{ok:true}},
  create:async a=>{if(!applyOps(a.ops))return{error:'insufficient'};const id=nid++;tables.set(id,{id,code:a.code,game:a.game,st:a.st,ver:0,humans:a.humans,open:true});return{ok:true,id}}};
 const b=await chromium.launch({executablePath:process.env.CHROMIUM||undefined}),errors=[],out={};
 const open=async(u,vp,m)=>{const ctx=await b.newContext({viewport:vp,isMobile:m,hasTouch:m});
  await ctx.route('https://puvjfhwxigxjpsvdwrwf.supabase.co/**',async route=>{const r=route.request(),url=new URL(r.url());let body=null;try{body=r.postDataJSON()}catch(e){}
   if(url.pathname==='/functions/v1/tables'){const res=await H.handle(body,(r.headers().authorization||'').replace('Bearer ',''),D);return route.fulfill({status:res.status,contentType:'application/json',body:JSON.stringify(res.body)})}
   if(url.pathname==='/rest/v1/rpc/get_my_locker')return route.fulfill({status:200,contentType:'application/json',body:JSON.stringify({owned:['skin:std'],eq:{},cases:0,shards:bal[u.id],bag:{},st:{},rev:1,username:u.name})});
   return route.fulfill({status:200,contentType:'application/json',body:'null'})});
  const p=await ctx.newPage();p.on('pageerror',e=>errors.push(u.name+': '+e.message));
  await p.addInitScript(([s])=>{localStorage.setItem('palisade.auth.v1',s)},[JSON.stringify({access_token:tok(u),refresh_token:'r',expires_at:4e9,user:{id:u.id,is_anonymous:u.anon,email:u.anon?undefined:u.name+'@x.y',user_metadata:{pw:true}}})]);
  await p.goto(`http://localhost:${process.env.PORT||8080}/debug.html?debug=1&cloud=1`);await ready(p);return p};
 const host=await open(users.A,{width:1366,height:820},false),guest=await open(users.B,{width:390,height:844},true);
 const V=p=>p.evaluate(()=>__pal.TB.v),poke=p=>p.evaluate(()=>{const T=__pal.TB;if(T.id)__pal.tbSend({op:'state',id:T.id},true)}).catch(()=>{}),   // ask for the table now instead of waiting for the once-a-second poll
  until=async(p,f,ms=20000)=>{const t=Date.now();for(;;){const v=await V(p);if(v&&f(v))return v;if(Date.now()-t>ms)throw new Error('timed out waiting: '+JSON.stringify(v&&{phase:v.phase,myTurn:v.myTurn}));await poke(p);await p.waitForTimeout(80)}};
 const tab=async p=>{await p.click('[data-nav=tables]');await quiet(p)};
 // the tab and the lobby
 await tab(host);out.lobbyBalance=await host.textContent('#tbBal');assert.equal(out.lobbyBalance,'60','the lobby shows the shard balance');
 await host.screenshot({path:__dirname+'/out/tables_lobby_desktop.png'});
 // blackjack: the host opens, the guest joins from the list
 await host.click('#tbOpenBtn');await host.waitForSelector('#tbTable:not([hidden])');assert.equal(bal[users.A.id],55,'buy-in taken');
 await tab(guest);await guest.waitForSelector('#tbList button[data-code]',{timeout:8000});await guest.screenshot({path:__dirname+'/out/tables_lobby_portrait.png'});await guest.click('#tbList button[data-code]');await guest.waitForSelector('#tbTable:not([hidden])');
 {const v0=await until(guest,v=>v.seats.filter(Boolean).length===2);assert.ok(!v0.started&&v0.phase==='wait','nothing is dealt until the host starts');
  assert.match(await guest.textContent('#tbStatus'),/WAITING FOR THE HOST/,'the guest is told the host starts');await host.screenshot({path:__dirname+'/out/tables_start_desktop.png'});
  await host.click('[data-act=start]')}
 for(const p of[host,guest]){await until(p,v=>v.phase==='bet');assert.match(await p.textContent('#tbStatus'),/PLACE YOUR BET/);await p.click('[data-act="set:1"]');await p.click('[data-act=bet]')}
 for(let k=0;k<120;k++){let moved=false;for(const p of[host,guest]){const v=await V(p);if(v.insure){await p.click('[data-act="ins:0"]');moved=true}if(v.myTurn){await p.click('[data-act=stand]');moved=true}}if(!moved){const v=await V(host);if(v.phase==='done')break}await poke(host);await poke(guest);await host.waitForTimeout(80)}
 let v=await until(host,v=>v.last&&v.last.no===1);out.bj=v.last.result;await poke(host);await quiet(host);assert.match(await host.textContent('#tbFelt'),/LAST HAND/,'the last hand stays on the table while betting');
 assert.ok(v.last.hash&&v.last.deck.length===208&&(await H.deckHash(v.last.salt,v.last.deck))===v.last.hash,'the fair-deal check matches the 4-deck shoe');
 await host.screenshot({path:__dirname+'/out/tables_bj_desktop.png'});await guest.screenshot({path:__dirname+'/out/tables_bj_portrait.png'});
 // both stand up: shards back, table closes
 for(const p of[host,guest]){for(let k=0;k<20;k++){const v=await V(p);if(!v||v.me<0)break;if(v.phase!=='play'&&v.phase!=='ins'){await p.click('#tbLeave');await quiet(p)}else{if(v.myTurn)await p.click('[data-act=stand]');await poke(p);await quiet(p)}}
  await p.waitForSelector('#tbLobby:not([hidden])',{timeout:15000})}
 out.afterBj={a:bal[users.A.id],b:bal[users.B.id]};assert.ok(Math.abs(bal[users.A.id]+bal[users.B.id]-100)<=4,'shards back home (give or take the hand) '+JSON.stringify(out.afterBj));
 // hold'em: two people, the bot sits down; hole cards stay hidden
 await host.click('#tbGame [data-g=he]');await host.click('#tbOpenBtn');await host.waitForSelector('#tbTable:not([hidden])');
 {const code=await host.evaluate(()=>__pal.TB.code);await guest.evaluate(()=>__pal.TB.lobbyT=0);await guest.waitForSelector(`#tbList button[data-code="${code}"]`,{timeout:10000});await guest.click(`#tbList button[data-code="${code}"]`)}
 await until(host,v=>v.seats.filter(s=>s&&!s.bot).length===2);await host.click('[data-act=start]');v=await until(host,v=>v.phase==='play');assert.ok(v.seats.some(s=>s&&s.bot),'the bot takes the third seat');
 const hidden=await host.evaluate(()=>{const v=__pal.TB.v;return v.players.filter(p=>p.seat!==v.me).every(p=>p.cards[0]===null)});assert.ok(hidden,'other players\' cards are face down');
 await host.screenshot({path:__dirname+'/out/tables_he_desktop.png'});
 for(let k=0;k<300;k++){let any=false;for(const p of[host,guest]){const v=await V(p);if(v&&v.myTurn){await p.click(v.can.check?'[data-act=check]':'[data-act=call]');any=true}}const hv=await V(host);if(hv.phase==='done')break;await poke(host);await poke(guest);await host.waitForTimeout(any?50:100)}
 v=await until(host,v=>v.phase==='done',30000);out.he=v.last.result;assert.ok(v.last.result.players.length===3,'a 3-handed hand finishes');
 assert.ok(v.left>50000,'a 60-second break between hands');await until(guest,v=>v.phase==='done');for(const p of[host,guest]){const pv=await V(p);if(pv.seats[pv.me].stack<2){await p.click('[data-top="5"]');await quiet(p)}}for(const p of[host,guest]){await poke(p);await quiet(p);if(await p.$('[data-act=ready]'))await p.click('[data-act=ready]')}v=await until(host,v=>v.handNo===2,10000);assert.ok(v.handNo===2,'everyone ready: the next hand deals early');
 await guest.screenshot({path:__dirname+'/out/tables_he_portrait.png'});
 const land=await open(users.B,{width:844,height:390},true);await tab(land);await land.waitForSelector('#tbTable:not([hidden])',{timeout:8000});await quiet(land);await land.screenshot({path:__dirname+'/out/tables_he_landscape.png'});
 // a guest account is refused
 const g=await open(users.G,{width:390,height:844},true);await tab(g);out.guestMsg=await g.textContent('#tbMsg');assert.match(out.guestMsg,/account/i,'guests are told to make an account');
 fs.writeFileSync(__dirname+'/out/tables_ui.json',JSON.stringify(out,null,1));console.log(JSON.stringify({afterBj:out.afterBj,guest:out.guestMsg}));
 assert.deepEqual(errors,[]);console.log('errors: none');await b.close();
})().catch(e=>{console.error(e);process.exit(1)});
