// Real six-browser floor and browser->handler->SQL ledger integration. All accounts/data are disposable.
const {chromium}=require('playwright'),{PGlite}=require('@electric-sql/pglite'),{citext}=require('@electric-sql/pglite/contrib/citext'),{setup}=require('./managed_casino'),{ready}=require('./lib'),assert=require('node:assert/strict'),fs=require('node:fs');
(async()=>{
 const {createCasinoService}=await import('../render/server.js'),{handle}=await import('../supabase/functions/tables/handler.js');const db=new PGlite({extensions:{citext}}),{D,ids}=await setup(db);
 await db.exec('update casino_world_config set admissions=true,new_wagers=true');let service=createCasinoService(D,{origins:['http://localhost:8080'],log:()=>{}});await service.start(10000,'127.0.0.1');
 const browser=await chromium.launch({executablePath:process.env.CHROMIUM||undefined,args:['--disable-background-timer-throttling','--disable-renderer-backgrounding','--disable-backgrounding-occluded-windows']}),pages=[],errors=[],requests=[],screens=__dirname+'/out/managed';fs.mkdirSync(screens,{recursive:true});let drops=0;
 const open=async k=>{const context=await browser.newContext({viewport:{width:1280,height:720}}),uid=ids[k];
  await context.route('https://puvjfhwxigxjpsvdwrwf.supabase.co/**',async route=>{
   const req=route.request(),url=new URL(req.url());let body;try{body=req.postDataJSON()}catch{}
   if(url.pathname==='/functions/v1/tables'){requests.push({uid,op:body?.op,opId:body?.opId});const r=await handle(body,req.headers().authorization?.replace('Bearer ',''),D);if(body.op==='spin'&&drops>0){drops--;return route.abort('connectionreset')}return route.fulfill({status:r.status,contentType:'application/json',body:JSON.stringify(r.body)});}
   if(url.pathname==='/rest/v1/rpc/get_my_locker')return route.fulfill({status:200,contentType:'application/json',body:JSON.stringify({owned:['skin:std'],eq:{},cases:0,shards:await D.balance(uid),bag:{},st:{},rev:1,username:'Casino'+k})});
   return route.fulfill({status:200,contentType:'application/json',body:'null'});
  });
  const p=await context.newPage();p.on('pageerror',e=>{errors.push(e.message);console.error('Browser exception:',e.stack)});p.on('request',r=>{if(/peerjs|palisade-turn/.test(r.url()))errors.push('casino loaded combat transport: '+r.url())});
  await p.addInitScript(s=>localStorage.setItem('palisade.auth.v1',s),JSON.stringify({access_token:uid,refresh_token:'test',expires_at:4e9,user:{id:uid,is_anonymous:false,email:'casino@example.test',user_metadata:{pw:true}}}));
  await p.goto(`http://localhost:${process.env.PORT||8080}/debug.html?debug=1&cloud=1`);await ready(p);await p.evaluate(()=>{globalThis.PALISADE_CASINO={enabled:true,url:'http://127.0.0.1:10000'};});return p;
 };
 try{
  for(let k=0;k<6;k++){const p=await open(k);pages.push(p);await p.click('[data-nav=tables]');await p.click('#casEnterBtn');await p.waitForFunction(()=>__pal.MC.connected&&__pal.NET.mode==='casino',null,{timeout:12000});}
  for(const p of pages)await p.waitForFunction(()=>__pal.players.size===6);
  const rooms=await Promise.all(pages.map(p=>p.evaluate(()=>__pal.casRoom())));assert.equal(new Set(rooms).size,1);assert.equal(service.people.size,6);
  await pages[0].close();await pages[1].waitForFunction(()=>__pal.players.size===5);assert.equal(service.people.size,5);
  const p=pages[1],uid=ids[1];await p.bringToFront();const moveStart=service.people.get(uid).x;await p.keyboard.down('d');
  await p.waitForFunction(()=>Math.hypot(...__pal.MC.input)>.1);const moveEnd=Date.now()+5000;while(service.people.get(uid).x===moveStart&&Date.now()<moveEnd)await p.waitForTimeout(20);await p.keyboard.up('d');assert.ok(service.people.get(uid).x!==moveStart,'keyboard reaches the authoritative floor');
  // Authoritative test fixture placement (not a browser teleport) walks the actor to a cabinet.
  const q=globalThis.CasinoFloor.CAS_SEAT.get(101),actor=service.people.get(uid);[actor.x,actor.y]=q.pos;actor.queue=[];
  await p.waitForFunction(()=>Math.hypot(__pal.player.x-2.5,__pal.player.y-1.4)<.2);
  await p.keyboard.press('e');await p.waitForFunction(()=>__pal.TB.v?.game==='sl'&&__pal.TB.v.me===0,null,{timeout:12000});
  const before=await D.balance(uid);drops=3;await p.evaluate(()=>__pal.tbSend({op:'spin',id:__pal.TB.id,amt:1}));assert.ok(await p.evaluate(()=>!!__pal.mcJournal()));
  const spinIds=requests.filter(x=>x.uid===uid&&x.op==='spin').map(x=>x.opId);assert.equal(new Set(spinIds).size,1);const tableBefore=await D.load(await p.evaluate(()=>__pal.TB.id));
  await p.reload();await ready(p);await p.evaluate(()=>{globalThis.PALISADE_CASINO={enabled:true,url:'http://127.0.0.1:10000'};return __pal.mcEnter('PALACE',true)});
  await p.waitForFunction(()=>__pal.MC.connected&&!__pal.mcJournal(),null,{timeout:15000});const tableAfter=await D.load(tableBefore.id);assert.equal(tableAfter.st.handNo,tableBefore.st.handNo,'reload resolves the original spin');assert.equal(await D.balance(uid),before,'spin uses stack; replay never debits wallet');
  const sentBeforeFailure=requests.length;await p.evaluate(async()=>{const set=Storage.prototype.setItem;Storage.prototype.setItem=function(k,v){if(k.startsWith('palisade.casino.ops.v1:'))throw new Error('fixture storage failure');return set.call(this,k,v)};try{await __pal.tbSend({op:'spin',id:__pal.TB.id,amt:1})}finally{Storage.prototype.setItem=set}});assert.equal(requests.slice(sentBeforeFailure).filter(r=>r.op==='spin').length,0,'storage failure prevents the first economic send');
  for(const vp of [{width:390,height:844},{width:844,height:390},{width:1280,height:720},{width:1440,height:900},{width:2560,height:1440}]){
   await p.setViewportSize(vp);await p.waitForTimeout(500);await p.waitForFunction(()=>{const [x,y]=__pal.scr(__pal.player.x,__pal.player.y);return x>40&&x<innerWidth-40&&y>70&&y<innerHeight-40});await p.screenshot({path:screens+`/floor-${vp.width}x${vp.height}.png`});assert.equal(await p.evaluate(()=>document.documentElement.scrollWidth>innerWidth),false,'no horizontal overflow');
  }
  const room=rooms[0];await service.stop();service=createCasinoService(D,{origins:['http://localhost:8080'],log:()=>{}});await service.start(10000,'127.0.0.1');
  for(const page of pages.slice(1))await page.waitForFunction(()=>__pal.MC.connected,null,{timeout:25000});assert.equal(await p.evaluate(()=>__pal.casRoom()),room,'service replacement preserves room');
  assert.deepEqual(errors,[]);console.log({sixBrowsers:'same permanent room',firstDeparture:'continued',lostSpin:'original operation after reload',restart:'same room',screens});console.log('errors: none');
 }finally{await browser.close();await service.stop();await db.close();}
})().catch(e=>{console.error(e);process.exitCode=1});
