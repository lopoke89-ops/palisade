// Open Games layout and browse states at the four menu audit viewports.
const {chromium}=require('playwright'),assert=require('node:assert/strict'),fs=require('node:fs');
const SIZES=[['desktop',1440,900,false],['laptop',1280,720,false],['portrait',390,844,true],['landscape',844,390,true]];
const OUT=__dirname+'/out/open_games_visibility';
const room={code:'AB12',name:'Visible Test Room',mode:'coop',length:'5',diff:'normal',players:2,in_game:false};
(async()=>{
 fs.mkdirSync(OUT,{recursive:true});
 const b=await chromium.launch({executablePath:process.env.CHROMIUM||undefined}),report={};
 for(const [name,width,height,mobile] of SIZES){
  const p=await b.newPage({viewport:{width,height},isMobile:mobile,hasTouch:mobile});
  const errors=[];p.on('pageerror',e=>errors.push(e.message));
  let rooms=[room],requests=0,published=[],browseStatus=200;
  await p.route('https://puvjfhwxigxjpsvdwrwf.supabase.co/**',route=>{
   if(route.request().url().includes('/rest/v1/lobbies?')){requests++;return route.fulfill({status:browseStatus,contentType:'application/json',body:JSON.stringify(rooms)})}
   if(route.request().url().endsWith('/rest/v1/lobbies')&&route.request().method()==='POST'){published.push(JSON.parse(route.request().postData()));return route.fulfill({status:201,contentType:'application/json',body:'{}'})}
   return route.fulfill({status:503,contentType:'application/json',body:'{}'});
  });
  await p.goto(`http://localhost:${process.env.PORT||8080}/debug.html?debug=1&cloud=1&peerhost=127.0.0.1&peerport=9000&peerpath=/`);
  await p.waitForFunction(()=>window.__pal);
  await p.evaluate(()=>{__pal.acct.s={access_token:'test',refresh_token:'test',expires_at:Math.floor(Date.now()/1000)+3600,user:{id:'test',is_anonymous:false}};__pal.acct.state='ready'});
  await p.click('[data-nav=multi]');
  await p.evaluate(()=>__pal.refreshLobbies());
  await p.waitForFunction(()=>document.querySelector('#lobList .lob'),null,{timeout:5000}).catch(async e=>{throw new Error(name+' '+JSON.stringify({requests,body:await p.locator('#lobList').innerText(),acct:await p.evaluate(()=>({state:__pal.acct.state,session:!!__pal.acct.s,page:document.querySelector('#menu').dataset.page})),errors}))});
  const measure=()=>p.evaluate(()=>{
   const box=document.getElementById('lobList'),row=box.querySelector('.lob'),heading=box.previousElementSibling,nav=document.querySelector('.partyNav'),rect=e=>{const r=e.getBoundingClientRect();return{x:r.x,y:r.y,w:r.width,h:r.height,b:r.bottom}},anc=[];
   let x=box;while(x){const s=getComputedStyle(x);if(x===box||/(auto|scroll|hidden|clip)/.test(s.overflowY))anc.push({id:x.id||x.className,overflow:s.overflowY,scroll:x.scrollTop,sh:x.scrollHeight,ch:x.clientHeight,rect:rect(x)});x=x.parentElement}
   let visible=rect(row),top=visible.y,bottom=visible.b;for(const a of anc){top=Math.max(top,a.rect.y);bottom=Math.min(bottom,a.rect.b)}top=Math.max(0,top);bottom=Math.min(innerHeight,bottom);
   return{box:rect(box),row:rect(row),heading:rect(heading),nav:rect(nav),visiblePixels:Math.max(0,bottom-top),ancestors:anc,text:box.textContent.trim(),page:document.getElementById('menu').dataset.page};
  });
  const initial=await measure();
  assert.equal(initial.page,'multi');assert.ok(requests>0,name+' did not browse');
  assert.ok(initial.box.w>40&&initial.box.h>20,name+' list has no dimensions');
  assert.ok(initial.visiblePixels>=initial.row.h-1,name+' room is initially clipped');
  if(name==='portrait')assert.ok(initial.row.b<initial.nav.y,name+' room is covered by phone tabs');
  assert.equal(await p.locator('#lobList .lob').isDisabled(),false,name+' join should be available');
  await p.locator('#lobList').scrollIntoViewIfNeeded().catch(()=>{});
  const scrolled=await measure();
  await p.screenshot({path:`${OUT}/${name}_rooms.png`});
  rooms=[];await p.evaluate(()=>__pal.refreshLobbies());
  const empty=await p.locator('#lobList').innerText();
  assert.match(empty,/No open games right now/);
  browseStatus=503;await p.evaluate(()=>__pal.refreshLobbies());const unavailable=await p.locator('#lobList').innerText();assert.match(unavailable,/Couldn't load the list/);browseStatus=200;
  rooms=[room];await p.evaluate(()=>{__pal.acct.s.user.is_anonymous=true;return __pal.refreshLobbies()});
  assert.equal(await p.locator('#lobList .lob').count(),1,name+' cloud guest can browse');
  rooms=[{...room,players:6}];await p.evaluate(()=>__pal.refreshLobbies());
  assert.equal(await p.locator('#lobList .lob').isDisabled(),true,name+' full room join must be disabled');
  rooms=[room];await p.evaluate(()=>{__pal.NET.mode='host';return __pal.refreshLobbies()});
  assert.equal(await p.locator('#lobList .lob').isDisabled(),true,name+' host join must be disabled');
  await p.evaluate(()=>{__pal.NET.mode='solo';__pal.acct.s=null;__pal.acct.state='wait';return __pal.refreshLobbies()});
  const connecting=await p.locator('#lobList').innerText();assert.match(connecting,/Connecting/);
  await p.evaluate(()=>{__pal.acct.state='down';__pal.acct.s=null;return __pal.refreshLobbies()});
  const down=await p.locator('#lobList').innerText();
  assert.match(down,/Can't reach the game server/);assert.doesNotMatch(down,/list is empty/);
  if(name==='desktop'){
   await p.evaluate(()=>{__pal.acct.s={access_token:'test',refresh_token:'test',expires_at:Math.floor(Date.now()/1000)+3600,user:{id:'test',is_anonymous:false}};__pal.acct.state='ready';__pal.showPage('multi')});
   await p.click('#hostBtn');await p.waitForFunction(()=>document.getElementById('menu').dataset.page==='lobby',{timeout:10000});
   await p.waitForTimeout(200);assert.ok(published.length,'host did not publish');assert.equal(published[0].proto,await p.evaluate(()=>__pal.PROTO));
   assert.equal(published[0].players,1);await p.evaluate(()=>__pal.showPage('multi'));assert.equal(await p.evaluate(()=>document.getElementById('menu').dataset.page),'lobby','active room redirect');
  }
  assert.deepEqual(errors,[],name+' page errors');report[name]={initial,scrolled,empty,unavailable,connecting,down,requests,published,errors};
  await p.close();
 }
 const offline=await b.newPage();await offline.goto(`http://localhost:${process.env.PORT||8080}/debug.html?debug=1`);await offline.waitForFunction(()=>window.__pal);
 await offline.click('[data-nav=multi]');report.offline=await offline.locator('#lobList').innerText();assert.match(report.offline,/web version/);await offline.close();
 fs.writeFileSync(`${OUT}/report.json`,JSON.stringify(report,null,2));
 console.log(JSON.stringify(Object.fromEntries(Object.entries(report).filter(([,v])=>v.initial).map(([k,v])=>[k,{first:v.initial.visiblePixels,afterScroll:v.scrolled.visiblePixels,requests:v.requests,empty:v.empty,down:v.down,errors:v.errors}]))));
 console.log('errors: none');await b.close();
})().catch(e=>{console.error(e);process.exit(1)});
