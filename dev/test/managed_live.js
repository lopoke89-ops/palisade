// Real browser -> deployed Render/Edge/Auth checks, restricted to isolated casino staging.
const {chromium}=require('playwright'),{ready}=require('./lib'),assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path');
const project='nxsqerlpqdzrjwqxhsdz',sb=`https://${project}.supabase.co`,service='https://palisade-casino-staging.onrender.com';
(async()=>{
 assert.equal(process.env.PALISADE_LIVE_STAGING,'1','Explicit live-staging opt-in is required');
 const credentials=JSON.parse(fs.readFileSync(process.env.STAGING_ACCOUNTS_FILE||path.join(__dirname,'out/staging-accounts.json'),'utf8'));
 const site=process.env.STAGING_SITE_URL||'http://localhost:8080/debug.html?debug=1&cloud=1';assert.equal(new URL(site).origin,'http://localhost:8080');
 assert.equal(credentials.project,project);assert.equal(credentials.users.length,7);
 assert.ok(credentials.users.every(u=>u.email.endsWith('@example.test')&&u.session?.user?.id===u.id&&!u.session.user.is_anonymous),'Use only verified disposable saved accounts');
 const browser=await chromium.launch({executablePath:process.env.CHROMIUM||undefined,args:['--disable-background-timer-throttling','--disable-renderer-backgrounding','--disable-backgrounding-occluded-windows']}),pages=[],errors=[],requests=[],denials=[];
 const out=path.join(__dirname,'out/managed-live');fs.mkdirSync(out,{recursive:true});
 const open=async k=>{
  const context=await browser.newContext({viewport:{width:1280,height:720}}),account=credentials.users[k];
  await context.route('https://puvjfhwxigxjpsvdwrwf.supabase.co/**',route=>route.abort('blockedbyclient'));
  assert.ok(account.session.expires_at*1000>Date.now()+60000,'Refresh real fixture sessions before testing');
  await context.addInitScript(({session,key})=>localStorage.setItem(key,JSON.stringify(session)),{session:account.session,key:'palisade.auth.v1:'+sb});
  const p=await context.newPage();p.on('pageerror',e=>errors.push(e.stack||e.message));
  if(k===6)p.on('websocket',ws=>ws.on('framereceived',({payload})=>{try{const m=JSON.parse(payload);if(m.type==='error')denials.push(m.error)}catch{}}));
  p.on('request',r=>{const u=r.url();if(/puvjfhwxigxjpsvdwrwf|peerjs\.com|palisade-turn/.test(u))errors.push('Unexpected environment/host transport request');if(u.startsWith(sb+'/functions/v1/tables'))requests.push({uid:account.id,path:new URL(u).pathname});});
  await p.goto(site);await ready(p,25000);
  assert.equal(await p.evaluate(()=>__pal.acct.s?.user?.id),account.id);
  return p;
 };
 try{
  const initial=await fetch(service+'/readyz').then(r=>r.json());assert.equal(initial.ready,true);assert.equal(initial.admissions,true);
  for(let k=0;k<6;k++){const p=await open(k);pages.push(p);await p.click('[data-nav=tables]');await p.click('#casTakeover');await p.waitForFunction(()=>__pal.MC.connected&&__pal.NET.mode==='casino',null,{timeout:25000});}
  for(const p of pages)await p.waitForFunction(()=>__pal.players.size===6,null,{timeout:20000});
  const rooms=await Promise.all(pages.map(p=>p.evaluate(()=>__pal.casRoom())));assert.equal(new Set(rooms).size,1);
  const health=await fetch(service+'/healthz').then(r=>r.json());assert.equal(health.occupants,6);assert.equal(health.rooms,1);
  await pages[0].close();await pages[1].waitForFunction(()=>__pal.players.size===5,null,{timeout:15000});
  const p=pages[1];await p.bringToFront();const start=await p.evaluate(()=>({x:__pal.player.x,y:__pal.player.y}));
  await p.keyboard.down('d');await p.waitForFunction(()=>Math.hypot(...__pal.MC.input)>.1,null,{timeout:5000});await p.waitForFunction(s=>Math.hypot(__pal.player.x-s.x,__pal.player.y-s.y)>.15,start,{timeout:10000});await p.keyboard.up('d');
  const lastMovementSeq=await p.evaluate(()=>__pal.MC.seq);await p.waitForFunction(seq=>__pal.MC.pending.every(b=>b.seq>seq),lastMovementSeq,{timeout:10000});
  const moved=await p.evaluate(()=>({x:__pal.player.x,y:__pal.player.y}));assert.ok(Math.hypot(moved.x-start.x,moved.y-start.y)>.15);
  await p.reload();await ready(p,25000);await p.click('[data-nav=tables]');await p.click('#casTakeover');await p.waitForFunction(()=>__pal.MC.connected,null,{timeout:25000});
  assert.equal(await p.evaluate(()=>__pal.casRoom()),rooms[1]);await p.waitForFunction(()=>__pal.players.size===5,null,{timeout:15000});
  await p.screenshot({path:out+'/live-floor.png'});
  const excluded=await open(6);pages.push(excluded);await excluded.click('[data-nav=tables]');await excluded.click('#casEnterBtn');
  const deniedUntil=Date.now()+15000;while(!denials.length&&Date.now()<deniedUntil)await new Promise(r=>setTimeout(r,50));assert.ok(denials.some(x=>/staging is limited/.test(x)),'Excluded account must receive the staging restriction');assert.equal(await excluded.evaluate(()=>__pal.MC.connected),false);assert.equal(await excluded.evaluate(()=>__pal.MC.active),false,'Permanent refusal must stop reconnect retries');
  const after=await fetch(service+'/healthz').then(r=>r.json());assert.equal(after.occupants,5);assert.equal(after.worker.errors,initial.worker.errors,'No new worker errors during the room check');
  assert.deepEqual(errors,[]);
  const report={time:new Date().toISOString(),project,service,realAuth:true,mockedEconomicRequests:false,checks:{sixSavedAccounts:'same durable room',firstDeparture:'five continue',keyboardMovement:'movement with acknowledged inputs',reload:'explicit takeover returns to same durable room with five occupants',excludedAccount:'explicit staging restriction',productionRequests:0,peerTransportRequests:0,workerErrorDelta:after.worker.errors-initial.worker.errors},room:rooms[0],movement:{start,moved},denials,apiRequests:requests.length,initialHealth:initial,afterHealth:after,errors};
  fs.writeFileSync(out+'/browser.json',JSON.stringify(report,null,2)+'\n');console.log(JSON.stringify({checks:report.checks,room:report.room,errors}));console.log('errors: none');
 }catch(e){
  const diagnostics=[];for(const p of pages.filter(p=>!p.isClosed())){diagnostics.push(await p.evaluate(()=>({state:__pal.acct.state,connected:__pal.MC.connected,active:__pal.MC.active,input:__pal.MC.input,pending:__pal.MC.pending.length,control:__pal.controlState(),player:__pal.player?{x:__pal.player.x,y:__pal.player.y,seat:__pal.player.seat}:null,hidden:document.hidden})).catch(()=>({unavailable:true})));}
  fs.writeFileSync(out+'/failure.json',JSON.stringify({time:new Date().toISOString(),message:e.message,diagnostics,errors},null,2));console.error(JSON.stringify({diagnostics,errors}));throw e;
 }finally{
  await Promise.allSettled(pages.map(async(p,k)=>{if(p.isClosed())return;const controller=await p.evaluate(()=>__pal.MC.controller);if(controller)await fetch(sb+'/functions/v1/tables',{method:'POST',headers:{apikey:'sb_publishable_m1R1Frx4Te72Yl2qrINhKQ_VxV02RvV',Authorization:'Bearer '+credentials.users[k].session.access_token,'Content-Type':'application/json'},body:JSON.stringify({op:'revoke',controller}),signal:AbortSignal.timeout(8000)});}));
  await browser.close();
 }
})().catch(e=>{console.error(e);process.exitCode=1});
