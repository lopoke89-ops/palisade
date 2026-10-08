// Upgrade an installed v0.10.4 browser to this release, preserving its saved account and offline cache.
const fs=require('node:fs'),path=require('node:path'),http=require('node:http'),assert=require('node:assert/strict'),{chromium}=require('playwright');
const root=path.resolve(__dirname,'../..'),out=path.join(__dirname,'out'),read=f=>fs.readFileSync(f,'utf8').replace(/\r\n/g,'\n');
(async()=>{
 const oldIndex=read(path.join(out,'relay-upgrade-old.html')),oldSw=read(path.join(out,'relay-upgrade-old-sw.js')),newIndex=read(path.join(root,'index.html')),newSw=read(path.join(root,'sw.js'));
 assert.match(oldIndex,/v0\.10\.4/);assert.match(newIndex,/v0\.10\.5/);let phase=0;
 const files=new Set(fs.readdirSync(root).filter(f=>/\.(?:html|js|png|woff2|m4a|ogg|webmanifest)$/.test(f)));
 const server=http.createServer((req,res)=>{const leaf=path.posix.basename(new URL(req.url,'http://local').pathname)||'index.html';if(!files.has(leaf)){res.writeHead(404);return res.end()}
  const ext=path.extname(leaf),type={'.html':'text/html; charset=utf-8','.js':'application/javascript','.png':'image/png','.woff2':'font/woff2','.webmanifest':'application/manifest+json','.m4a':'audio/mp4','.ogg':'audio/ogg'}[ext];
  res.writeHead(200,{'Content-Type':type,'Cache-Control':'no-store'});res.end(leaf==='index.html'?(phase?newIndex:oldIndex):leaf==='sw.js'?(phase?newSw:oldSw):fs.readFileSync(path.join(root,leaf)));
 });await new Promise(resolve=>server.listen(8082,'127.0.0.1',resolve));
 const browser=await chromium.launch({executablePath:process.env.CHROMIUM||undefined}),ctx=await browser.newContext(),errors=[],violations=[];
 const uid='a0000000-0000-4000-8000-000000000001',user={id:uid,email:'upgrade@example.invalid',is_anonymous:false,user_metadata:{pw:true}},token='x.'+Buffer.from(JSON.stringify({sub:uid,exp:4e9})).toString('base64url')+'.y';
 await ctx.route('https://puvjfhwxigxjpsvdwrwf.supabase.co/**',route=>{const pathname=new URL(route.request().url()).pathname,body=pathname==='/rest/v1/rpc/get_my_locker'?{owned:['skin:std'],eq:{},cases:0,shards:1234,bag:{},st:{},rev:1,username:'Upgrade'}:pathname==='/auth/v1/user'?user:pathname==='/rest/v1/profiles'?[{id:uid,username:'Upgrade',banned:false}]:[];return route.fulfill({status:200,contentType:'application/json',body:JSON.stringify(body)})});
 const p=await ctx.newPage();p.on('pageerror',e=>errors.push(e.message));
 await p.addInitScript(s=>{if(!sessionStorage.getItem('upgrade-seeded')){localStorage.setItem('palisade.auth.v1',s);sessionStorage.setItem('upgrade-seeded','1')}document.addEventListener('securitypolicyviolation',e=>(window.__cspViolations??=[]).push(e.violatedDirective))},JSON.stringify({access_token:token,refresh_token:'fixture',expires_at:4e9,user}));
 try{
  await p.goto('http://127.0.0.1:8082/?cloud=1');await p.waitForFunction(()=>document.querySelector('#identityState').textContent.includes('SIGNED IN'));
  // The game registers its worker only on its published host; explicitly register the same worker for this local upgrade.
  await p.evaluate(()=>navigator.serviceWorker.register('sw.js'));await p.waitForFunction(()=>navigator.serviceWorker.controller);const before=await p.evaluate(()=>caches.keys());assert.ok(before.includes(oldSw.match(/const V='([^']+)'/)[1]));
  phase=1;await p.evaluate(async()=>{const registration=await navigator.serviceWorker.getRegistration();await registration.update()});
  const expected=newSw.match(/const V='([^']+)'/)[1];await p.waitForFunction(async version=>(await caches.keys()).includes(version),expected);await p.waitForFunction(async version=>(await caches.keys()).filter(k=>k.startsWith('palisade-')&&k!=='palisade-media-2').every(k=>k===version),expected);
  await p.reload();await p.waitForFunction(()=>document.querySelector('#identityState').textContent.includes('SIGNED IN'));
  assert.equal(await p.textContent('#identityName'),'Upgrade');assert.equal(await p.textContent('#identityShards'),'1234');assert.equal(await p.evaluate(()=>JSON.parse(localStorage.getItem('palisade.auth.v1')).user.id),uid);assert.equal(await p.evaluate(()=>globalThis.PALISADE_RELAY.enabled),true);violations.push(...await p.evaluate(()=>window.__cspViolations||[]));
  await ctx.setOffline(true);await p.reload();await p.waitForFunction(()=>globalThis.PALISADE_RELAY?.enabled===true);assert.match(await p.textContent('body'),/v0\.10\.5/);
  assert.deepEqual(errors,[]);assert.deepEqual(violations,[]);const report={oldCache:before,newCache:expected,accountPreserved:true,balancePreserved:true,offlineNewVersion:true,browserErrors:errors,cspViolations:violations,checkedAt:new Date().toISOString()};fs.writeFileSync(path.join(out,'relay-upgrade.json'),JSON.stringify(report,null,2));console.log(JSON.stringify(report));console.log('errors: none');
 }finally{await browser.close();await new Promise(resolve=>server.close(resolve))}
})().catch(e=>{console.error(e.message);process.exitCode=1});
