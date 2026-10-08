// Opt-in real Auth/Render check, restricted to the existing isolated staging project.
const fs=require('node:fs'),assert=require('node:assert/strict'),{chromium}=require('playwright'),{ready}=require('./lib');
const project='nxsqerlpqdzrjwqxhsdz',endpoint='https://palisade-casino-staging.onrender.com';
(async()=>{
 assert.equal(process.env.PALISADE_LIVE_STAGING,'1');const accounts=JSON.parse(fs.readFileSync(process.env.STAGING_ACCOUNTS_FILE||__dirname+'/out/staging-accounts.json','utf8'));
 assert.equal(accounts.project,project);assert.ok(accounts.users.length>=6);for(const a of accounts.users.slice(0,6))assert.ok(a.session.expires_at*1000>Date.now()+300000,'refresh staging sessions first');
 const health=async()=>{const r=await fetch(endpoint+'/readyz',{signal:AbortSignal.timeout(70000)});assert.equal(r.status,200);const j=await r.json();assert.equal(j.kind,'player-hosted-relay');assert.equal(j.wire,'casino-relay-1');return j};
 const cold=process.env.PALISADE_RELAY_COLD_TEST==='1',initial=cold?null:await health();if(initial&&process.env.EXPECTED_RENDER_COMMIT)assert.equal(initial.build,process.env.EXPECTED_RENDER_COMMIT);
 let idleProof=null;if(cold){const r=await fetch(endpoint+'/robots.txt',{signal:AbortSignal.timeout(10000)}),body=await r.text();assert.match(body,/Disallow:\s*\//,'Render must actually be asleep before the cold test');idleProof={status:r.status,disallowAll:true,checkedAt:new Date().toISOString()}}
 const browser=await chromium.launch({executablePath:process.env.CHROMIUM||undefined,args:['--disable-background-timer-throttling','--disable-renderer-backgrounding','--disable-backgrounding-occluded-windows']}),pages=[],errors=[],badRequests=[],report={initial,idleProof,receivedPayloadBytes:0,sentPayloadBytes:0};
 const open=async i=>{
  const ctx=await browser.newContext({viewport:{width:i===1?390:1280,height:i===1?844:720},hasTouch:i===1,isMobile:i===1}),p=await ctx.newPage();
  p.on('pageerror',e=>errors.push(e.message));p.on('request',r=>{if(/peerjs|palisade-turn|puvjfhwxigxjpsvdwrwf/.test(r.url()))badRequests.push(r.url())});
  p.on('websocket',ws=>{ws.on('framesent',e=>report.sentPayloadBytes+=Buffer.byteLength(e.payload));ws.on('framereceived',e=>report.receivedPayloadBytes+=Buffer.byteLength(e.payload))});
  await p.addInitScript(s=>localStorage.setItem('palisade.auth.v1:nxsqerlpqdzrjwqxhsdz.supabase.co',s),JSON.stringify(accounts.users[i].session));
  await p.goto('http://localhost:8080/debug.html?debug=1&cloud=1');await ready(p);assert.equal(await p.evaluate(()=>globalThis.PALISADE_RELAY.supabaseUrl),'https://'+project+'.supabase.co');pages.push(p);return p;
 };
 try{
  const host=await open(0);await host.click('[data-nav=tables]');const entryAt=Date.now();await host.click('#casEnterBtn');
  await host.waitForFunction(()=>__pal.RLY.active);report.connectionStatus=await host.textContent('#tbMsg');assert.match(report.connectionStatus,/Connecting|Reconnecting/);
  if(cold||process.env.PALISADE_CAPTURE_CONNECTION==='1'){fs.mkdirSync(__dirname+'/out/relay-live',{recursive:true});await host.screenshot({path:__dirname+'/out/relay-live/'+(cold?'cold-connecting':'warm-connecting')+'.png'})}
  await host.waitForFunction(()=>__pal.RLY.connected&&__pal.NET.inGame,null,{timeout:125000});report.firstConnectionMilliseconds=Date.now()-entryAt;
  if(cold){report.initial=await health();if(process.env.EXPECTED_RENDER_COMMIT)assert.equal(report.initial.build,process.env.EXPECTED_RENDER_COMMIT);report.afterIdle=true}
  const code=await host.evaluate(()=>__pal.NET.code),joins=[];
  for(let i=1;i<6;i++){const p=await open(i),at=Date.now();await p.evaluate(code=>__pal.rlyEnter('guest',code),code);await p.waitForFunction(()=>__pal.NET.mode==='guest'&&__pal.NET.inGame,null,{timeout:70000});joins.push(Date.now()-at)}
  for(const p of pages)await p.waitForFunction(()=>__pal.players.size===6,null,{timeout:15000});report.sixBrowsers=true;report.joinMilliseconds=joins;
  const sixAt={time:Date.now(),received:report.receivedPayloadBytes,sent:report.sentPayloadBytes};
  await pages[1].click('#chatBtn');await pages[1].fill('#chatIn','Relay staging chat');await pages[1].press('#chatIn','Enter');
  for(const p of pages)await p.waitForFunction(()=>document.querySelector('#chatLog').textContent.includes('Relay staging chat'));report.chatReachedEveryone=true;
  const hostId=await host.evaluate(()=>__pal.RLY.peer);await host.evaluate(()=>__pal.RLY.ws.close(4002,'Staging host reconnect check'));
  await host.waitForFunction(()=>!__pal.RLY.connected);await host.waitForFunction(()=>__pal.RLY.connected,null,{timeout:20000});assert.equal(await host.evaluate(()=>__pal.RLY.peer),hostId);
  for(const p of pages)await p.waitForFunction(()=>__pal.players.size===6);report.hostReconnectSamePeer=true;
  const guest=pages[2],before=await host.evaluate(()=>({x:__pal.players.get('g2').x,y:__pal.players.get('g2').y}));await guest.bringToFront();await guest.keyboard.down('d');
  await host.waitForFunction(b=>{const p=__pal.players.get('g2');return Math.hypot(p.x-b.x,p.y-b.y)>.05},before,{timeout:15000});await guest.keyboard.up('d');report.movementReachedHost=true;
  const id=await guest.evaluate(()=>__pal.RLY.peer);await guest.evaluate(()=>__pal.RLY.ws.close(4002,'Staging reconnect check'));
  await guest.waitForFunction(()=>!__pal.RLY.connected);await guest.waitForFunction(()=>__pal.RLY.connected,null,{timeout:20000});assert.equal(await guest.evaluate(()=>__pal.RLY.peer),id);report.guestReconnectSamePeer=true;
  fs.mkdirSync(__dirname+'/out/relay-live',{recursive:true});await host.screenshot({path:__dirname+'/out/relay-live/host-six.png'});await pages[1].screenshot({path:__dirname+'/out/relay-live/phone-six.png'});
  await host.waitForTimeout(30000);report.sessionHealth=await health();assert.equal(report.sessionHealth.players,6);
  report.sixPlayerTraffic={durationMilliseconds:Date.now()-sixAt.time,receivedPayloadBytes:report.receivedPayloadBytes-sixAt.received,sentPayloadBytes:report.sentPayloadBytes-sixAt.sent};
  await pages[5].evaluate(()=>__pal.toMenu());await host.waitForFunction(()=>__pal.players.size===5);report.guestDepartureContinued=true;
  await host.evaluate(()=>__pal.toMenu());for(const p of pages.slice(1,5))await p.waitForFunction(()=>!__pal.RLY.active);report.hostDepartureClosesLobby=true;
  if(process.env.PALISADE_RELAY_RESTART_TEST==='1'){
   await host.evaluate(()=>__pal.rlyEnter('host'));await host.waitForFunction(()=>__pal.RLY.connected&&__pal.NET.inGame);const newCode=await host.evaluate(()=>__pal.NET.code);
   await pages[1].evaluate(code=>__pal.rlyEnter('guest',code),newCode);await pages[1].waitForFunction(()=>__pal.NET.mode==='guest'&&__pal.NET.inGame);
   const epoch=(await health()).epoch;console.log('LIVE_RELAY_RESTART_READY');
   await host.waitForFunction(()=>!__pal.RLY.active,null,{timeout:300000});await pages[1].waitForFunction(()=>!__pal.RLY.active,null,{timeout:300000});
   const after=await health();assert.notEqual(after.epoch,epoch);assert.equal(after.rooms,0);assert.equal(after.players,0);report.platformRestart={oldEpoch:epoch,newEpoch:after.epoch,hostMessage:await host.textContent('#mStatus'),guestMessage:await pages[1].textContent('#mStatus')};
  }
  assert.deepEqual(errors,[]);assert.deepEqual(badRequests,[]);report.final=await health();assert.equal(report.final.players,0);assert.equal(report.final.rooms,0);report.completed=true;report.checkedAt=new Date().toISOString();report.browserErrors=errors;report.forbiddenRequests=badRequests;
  fs.writeFileSync(__dirname+'/out/relay-live/'+(cold?'cold-report.json':'report.json'),JSON.stringify(report,null,2));console.log(JSON.stringify(report));console.log('errors: none');
 }finally{await browser.close()}
})().catch(e=>{console.error(e.message);process.exitCode=1});
