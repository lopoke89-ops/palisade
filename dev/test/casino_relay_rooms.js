// Six actual browser contexts over WSS. Auth is a fixture; no P2P requests are allowed.
const {chromium}=require('playwright'),{ready}=require('./lib'),assert=require('node:assert/strict'),fs=require('node:fs');
(async()=>{
 const users=Object.fromEntries(Array.from({length:8},(_,i)=>[i,{id:`a0000000-0000-4000-8000-${String(i+1).padStart(12,'0')}`,name:'Relay'+i}]));
 const tok=u=>'x.'+Buffer.from(JSON.stringify({sub:u.id,exp:4e9})).toString('base64url')+'.y';
 const relay=await require('./relay-fixture').start(users,tok),browser=await chromium.launch({executablePath:process.env.CHROMIUM||undefined,args:['--disable-background-timer-throttling','--disable-renderer-backgrounding','--disable-backgrounding-occluded-windows']}),pages=[],errors=[];
 const open=async i=>{
  const u=users[i],ctx=await browser.newContext({viewport:{width:i===1?390:1280,height:i===1?844:720},hasTouch:i===1,isMobile:i===1});
  await ctx.route('https://puvjfhwxigxjpsvdwrwf.supabase.co/**',route=>{
   const path=new URL(route.request().url()).pathname;
   const body=path==='/rest/v1/rpc/get_my_locker'?{owned:['skin:std'],eq:{},cases:0,shards:5000,bag:{},st:{},rev:1,username:u.name}:path==='/functions/v1/tables'?{tables:[],balance:5000}:null;
   return route.fulfill({status:200,contentType:'application/json',body:JSON.stringify(body)});
  });
  const p=await ctx.newPage();p.on('pageerror',e=>errors.push(e.message));p.on('request',r=>{if(/peerjs|palisade-turn/.test(r.url()))errors.push('P2P request: '+r.url())});
  await p.addInitScript(s=>localStorage.setItem('palisade.auth.v1',s),JSON.stringify({access_token:tok(u),refresh_token:'fixture',expires_at:4e9,user:{id:u.id,is_anonymous:false,email:u.name+'@example.test',user_metadata:{pw:true}}}));
  await p.goto(`http://localhost:${process.env.PORT||8080}/debug.html?debug=1&cloud=1`);await ready(p);await p.evaluate(()=>globalThis.PALISADE_RELAY={enabled:true,url:'http://127.0.0.1:10000'});pages.push(p);return p;
 };
 try{
  const host=await open(0);await host.click('[data-nav=tables]');await host.click('#casEnterBtn');await host.waitForFunction(()=>__pal.RLY.connected&&__pal.NET.inGame);
  const code=await host.evaluate(()=>__pal.NET.code),room=await host.evaluate(()=>__pal.casRoom());
  for(let i=1;i<6;i++){const p=await open(i);await p.evaluate(code=>__pal.rlyEnter('guest',code),code);await p.waitForFunction(()=>__pal.NET.mode==='guest'&&__pal.NET.inGame)}
  for(const p of pages)await p.waitForFunction(()=>__pal.players.size===6);assert.equal(relay.people.size,6);
  const guest=pages[2],before=await host.evaluate(()=>__pal.players.get('g2').x);
  await guest.bringToFront();await guest.keyboard.down('d');await host.waitForFunction(x=>Math.abs(__pal.players.get('g2').x-x)>.05,before);await guest.keyboard.up('d');
  const firstPeer=await guest.evaluate(()=>__pal.RLY.peer);relay.people.get(firstPeer).ws.terminate();
  await guest.waitForFunction(()=>!__pal.RLY.connected);await guest.waitForFunction(()=>__pal.RLY.connected);assert.equal(await guest.evaluate(()=>__pal.RLY.peer),firstPeer);assert.equal(await guest.evaluate(()=>__pal.casRoom()),room);
  const hostPeer=await host.evaluate(()=>__pal.RLY.peer);relay.people.get(hostPeer).ws.terminate();await host.waitForFunction(()=>!__pal.RLY.connected);await host.waitForFunction(()=>__pal.RLY.connected);
  assert.equal(relay.rooms.size,1);for(const p of pages)await p.waitForFunction(()=>__pal.players.size===6);
  const extra=await open(6);await extra.evaluate(code=>__pal.rlyEnter('guest',code),code);await extra.waitForFunction(()=>!__pal.RLY.active);assert.match(await extra.textContent('#mStatus'),/full/);
  await host.evaluate(()=>{__pal.NET.roomLocked=true;__pal.broadcastLobby()});await pages[5].evaluate(()=>__pal.toMenu());await pages[5].evaluate(()=>__pal.rlyDisconnect());
  const locked=await open(7);await locked.evaluate(code=>__pal.rlyEnter('guest',code),code);await locked.waitForFunction(()=>!__pal.RLY.active);assert.match(await locked.textContent('#mStatus'),/locked/);
  fs.mkdirSync(__dirname+'/out/relay',{recursive:true});await host.screenshot({path:__dirname+'/out/relay/host-six.png'});await pages[1].screenshot({path:__dirname+'/out/relay/phone.png'});
  await host.evaluate(()=>__pal.NET.toHost({t:'ping'}));
  await host.evaluate(()=>__pal.toMenu());await host.evaluate(()=>__pal.rlyDisconnect());
  for(const p of pages.slice(1,5))await p.waitForFunction(()=>!__pal.RLY.active);assert.equal(relay.people.size,0);assert.equal(relay.rooms.size,0);
  assert.deepEqual(errors,[]);console.log('Six browsers, movement, guest/host reconnect, full/locked rooms, host departure and zero P2P requests: errors: none');
 }finally{await browser.close();await relay.stop()}
})().catch(e=>{console.error(e);process.exitCode=1});
