// Managed transport + real SQL adapter, disposable accounts only. No live financial data.
const {chromium}=require('playwright'),{PGlite}=require('@electric-sql/pglite'),{citext}=require('@electric-sql/pglite/contrib/citext'),{setup}=require('./managed_casino'),{ready}=require('./lib'),assert=require('node:assert/strict'),fs=require('node:fs'),{randomUUID}=require('node:crypto'),WS=require('../render/node_modules/ws');
const pause=ms=>new Promise(r=>setTimeout(r,ms));
async function until(fn,label,ms=25000){const end=Date.now()+ms;while(Date.now()<end){if(await fn())return;await pause(50);}throw Error('Timeout: '+label);}
(async()=>{
 const {createCasinoService}=await import('../render/server.js'),{handle}=await import('../supabase/functions/tables/handler.js'),db=new PGlite({extensions:{citext}}),{D,ids}=await setup(db);
 await db.exec('update casino_world_config set admissions=true,new_wagers=true');const service=createCasinoService(D,{origins:['http://localhost:8080'],log:()=>{}});await service.start(10000,'127.0.0.1');
 const browser=await chromium.launch({executablePath:process.env.CHROMIUM||undefined,args:['--disable-background-timer-throttling','--disable-renderer-backgrounding','--disable-backgrounding-occluded-windows']}),out=__dirname+'/out/managed-ui',errors=[],peers=[],sheets=[];fs.mkdirSync(out,{recursive:true});let p,timer;
 try{
  for(let i=1;i<=5;i++){const ws=new WS('ws://127.0.0.1:10000/casino',{origin:'http://localhost:8080'}),peer={ws,uid:ids[i],messages:[]};peers.push(peer);ws.on('error',()=>{});ws.on('message',raw=>{const m=JSON.parse(raw);peer.messages.push(m);if(m.type==='welcome')peer.welcome=m;});ws.on('open',()=>ws.send(JSON.stringify({type:'hello',protocol:'casino-1',token:ids[i],session:randomUUID(),code:'PALACE',cls:'soldier',takeover:true})));await until(()=>peer.welcome,'fixture floor');}
  timer=setInterval(()=>peers.forEach(q=>{if(q.ws.readyState===WS.OPEN)q.ws.send('{"type":"ping"}');}),5000);
  for(const vp of [{width:390,height:844},{width:844,height:390},{width:1280,height:720},{width:1440,height:900},{width:2560,height:1440}]){
   const touch=vp.width<900,ctx=await browser.newContext({viewport:vp,hasTouch:touch,isMobile:touch,recordVideo:{dir:out+'/videos',size:vp}});
   await ctx.route('https://*.supabase.co/**',async route=>{const req=route.request(),url=new URL(req.url());let b;try{b=req.postDataJSON();}catch{}
    if(url.pathname==='/functions/v1/tables'){const r=await handle(b,req.headers().authorization?.replace('Bearer ',''),D);return route.fulfill({status:r.status,contentType:'application/json',body:JSON.stringify(r.body)});}
    if(url.pathname==='/rest/v1/rpc/get_my_locker')return route.fulfill({status:200,contentType:'application/json',body:JSON.stringify({owned:['skin:std'],eq:{},cases:0,shards:await D.balance(ids[0]),bag:{},st:{},rev:1,username:'Casino0'})});
    return route.fulfill({status:200,contentType:'application/json',body:'null'});
   });
   await ctx.addInitScript(s=>localStorage.setItem('palisade.auth.v1',s),JSON.stringify({access_token:ids[0],refresh_token:'fixture',expires_at:4e9,user:{id:ids[0],is_anonymous:false,email:'casino@example.test',user_metadata:{pw:true}}}));
   p=await ctx.newPage();p.on('pageerror',e=>errors.push(e.message));p.on('request',r=>{if(/peerjs\.com|palisade-turn/.test(r.url()))errors.push('Managed casino requested combat transport');});
   await p.goto(`http://localhost:${process.env.PORT||8080}/debug.html?debug=1&cloud=1`);await ready(p);await p.evaluate(()=>{globalThis.PALISADE_CASINO={enabled:true,url:'http://127.0.0.1:10000'};return __pal.mcEnter('PALACE',true);});await p.waitForFunction(()=>__pal.MC.connected&&__pal.players.size===6);
   if(touch)assert.equal(await p.evaluate(()=>__pal.touchModeSet),true,'real touch context');
   for(const [game,seat]of [['bj',11],['he',21],['rl',31],['ba',51],['cr',41],['sl',101],['pk',117]]){
    const q=globalThis.CasinoFloor.CAS_SEAT.get(seat),a=service.people.get(ids[0]);await until(()=>performance.now()-(a.reservedAt||0)>=1100,'reservation cadence');[a.x,a.y]=q.pos;a.queue=[];
    await p.waitForFunction(pos=>Math.hypot(__pal.player.x-pos[0],__pal.player.y-pos[1])<.15,q.pos);if(touch){await p.waitForSelector('#casSitBtn:not([hidden])');await p.tap('#casSitBtn');}else await p.keyboard.press('e');
    await p.waitForFunction(g=>__pal.TB.v?.game===g&&__pal.TB.sheet&&__pal.player.seat!==0,game);
    let partner=null;if(game==='he'){
     partner=peers[0];const a2=service.people.get(partner.uid),q2=globalThis.CasinoFloor.CAS_SEAT.get(22);[a2.x,a2.y]=q2.pos;partner.messages=[];partner.ws.send('{"type":"reserve","seat":22}');await until(()=>partner.messages.some(m=>m.type==='reserved'),'shared Holdem reservation');const reservation=partner.messages.find(m=>m.type==='reserved').reservation;
     const r=await handle({op:'sit',room:partner.welcome.room,game:'he',seat:1,station:'',reservation,controller:partner.welcome.controller,opId:'ui_'+randomUUID()},partner.uid,D);assert.equal(r.status,200);partner.table=r.body.id;
     await p.evaluate(()=>__pal.tbSend({op:'state',id:__pal.TB.id},true));await p.waitForFunction(()=>__pal.TB.v.phase==='play');const view=await p.evaluate(()=>__pal.TB.v);assert.ok(view.players.filter(q=>q.seat!==view.me).every(q=>q.cards.every(c=>c===null)),'another player\'s hole cards remain hidden');
    }
    await p.waitForTimeout(250);const bounds=await p.evaluate(()=>{const sheet=document.getElementById('casSheet'),r=sheet.getBoundingClientRect(),[x,y]=__pal.scr(__pal.player.x,__pal.player.y);return {x,y,sheet:{left:r.left,right:r.right,top:r.top,bottom:r.bottom},overflow:document.documentElement.scrollWidth>innerWidth,sheetOverflow:sheet.scrollWidth>sheet.clientWidth+1,players:__pal.players.size};});
    assert.equal(bounds.overflow,false);assert.equal(bounds.sheetOverflow,false,'table has no horizontal overflow');assert.equal(bounds.players,6);assert.ok(bounds.x>12&&bounds.x<vp.width-12&&bounds.y>35&&bounds.y<vp.height-12,'player remains in view');assert.ok(bounds.y<bounds.sheet.top||bounds.x<bounds.sheet.left||bounds.x>bounds.sheet.right,'player remains beside or above the sheet');
    await p.screenshot({path:out+`/${game}-${vp.width}x${vp.height}.png`});sheets.push({game,...vp,touch,bounds});
    await p.click('#tbHide');assert.equal(await p.evaluate(()=>!!__pal.player.seat&&!!__pal.TB.id),true,'hide retains committed seat');if(touch)await p.tap('#casSitBtn');else await p.keyboard.press('e');await p.waitForSelector('#casSheet:not([hidden])');
    if(partner){const r=await handle({op:'leave',id:partner.table,controller:partner.welcome.controller,opId:'ui_'+randomUUID()},partner.uid,D);assert.equal(r.status,200);}
    await p.click('#tbLeave');await until(()=>service.people.get(ids[0])?.seat===0,'committed standing state',2500);await p.waitForFunction(()=>!__pal.player.seat&&!__pal.TB.id);await until(async()=>!await D.seatOf(ids[0])&&(!partner||!await D.seatOf(partner.uid)),'cashout',90000);await pause(200);
   }
   await p.emulateMedia({reducedMotion:'reduce'});assert.equal(await p.evaluate(()=>matchMedia('(prefers-reduced-motion: reduce)').matches),true);await p.screenshot({path:out+`/reduced-motion-${vp.width}x${vp.height}.png`});
   await p.evaluate(()=>__pal.mcSend({type:'depart'}));await until(()=>!service.people.has(ids[0]),'floor departure');await ctx.close();p=null;
  }
  assert.deepEqual(errors,[]);assert.equal(sheets.length,35);fs.writeFileSync(out+'/report.json',JSON.stringify({scope:'local managed WSS and SQL; authoritative placement fixtures for UI inspection',sheets,errors},null,2)+'\n');console.log({sheets:sheets.length,viewports:5,touch:'portrait and landscape',sixAvatars:true,sharedHoldemPrivateCards:'redacted',hideStand:'distinct',screens:out});console.log('errors: none');
 }catch(e){console.error('UI failure state',JSON.stringify({browser:p&&!p.isClosed()?await p.evaluate(()=>({seat:__pal.player?.seat,id:__pal.TB.id,busy:__pal.TB.busy,phase:__pal.TB.v?.phase,me:__pal.TB.v?.me,seatExpected:__pal.MC.seatExpected,syncBusy:__pal.MC.seatSyncBusy,message:document.getElementById('tbSheetMsg').textContent})):null,primarySeat:await D.seatOf(ids[0]),partnerSeat:await D.seatOf(ids[1]),floorSeats:[...service.people.values()].map(q=>q.seat),errors}));throw e;
 }finally{clearInterval(timer);peers.forEach(q=>q.ws.terminate());await browser.close();await service.stop();await db.close();}
})().catch(e=>{console.error(e);process.exitCode=1;});
