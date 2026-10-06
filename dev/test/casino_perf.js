// v0.10.3 casino performance: frame time (median and p95), JS heap and request rate in THE PALISADE FALLS CASINO, on the
// same machine and browser for two builds. Scenes both builds have: standing in the casino, walking round the floor, seated
// at blackjack with the sheet open (it polls once a second). The v0.10.3 build also: a slot cabinet spinning, the Plinko
// board dropping. The tables function runs locally behind a mocked Supabase (no network cost in the numbers).
// PORT=8080 node casino_perf.js new     (this checkout's build)
// PORT=8083 HANDLER=/path/to/old/dev/supabase/functions/tables/handler.js node casino_perf.js old
const {chromium}=require('playwright'),{ready,quiet}=require('./lib'),fs=require('node:fs'),path=require('node:path');
const label=process.argv[2]||'new',PORT=process.env.PORT||8080,Q='peerhost=127.0.0.1&peerport=9000&peerpath=/&debug=1&cloud=1';
(async()=>{const H=await import(process.env.HANDLER||'../supabase/functions/tables/handler.js');
 const U={id:'a0000000-0000-4000-8000-00000000000a',anon:false,name:'BigU'},bal={[U.id]:100000},tables=new Map(),opsLog=new Map();let nid=1,reqs=0;
 const tok='x.'+Buffer.from(JSON.stringify({sub:U.id,exp:4e9})).toString('base64url')+'.y';
 const D={now:()=>Date.now(),auth:async t=>t===tok?{id:U.id,anon:false}:null,name:async()=>U.name,balance:async id=>bal[id]||0,
  load:async id=>{const t=tables.get(id);return t&&JSON.parse(JSON.stringify(t))},byRoom:async(room,game,station)=>[...tables.values()].find(t=>t.open&&t.room===room&&t.game===game&&(t.station||'')===(station||''))||null,
  seatOf:async id=>{const t=[...tables.values()].find(t=>t.open&&t.humans.includes(id));return t?{id:t.id,code:t.code,game:t.game,room:t.room,station:t.station||''}:null},stale:async()=>[],botLeft:async()=>25,
  opGet:async(u,o)=>opsLog.get(u+'|'+o)||null,history:async()=>[],
  commit:async a=>{const t=tables.get(a.id);if(t.ver!==a.ver)return{conflict:true};for(const o of a.ops)if(o.uid&&o.d)bal[o.uid]+=o.d;Object.assign(t,{st:a.st,ver:t.ver+1,humans:a.humans,open:a.open});if(a.op)opsLog.set(a.op.uid+'|'+a.op.id,a.op);return{ok:true}},
  create:async a=>{for(const o of a.ops)if(o.uid&&o.d)bal[o.uid]+=o.d;const id=nid++;tables.set(id,{id,code:a.code,game:a.game,room:a.room,station:a.station||'',st:a.st,ver:0,humans:a.humans,open:true});return{ok:true,id}}};
 const b=await chromium.launch({executablePath:process.env.CHROMIUM||undefined,args:['--enable-precise-memory-info']}),ctx=await b.newContext({viewport:{width:1366,height:820}});
 await ctx.route('https://puvjfhwxigxjpsvdwrwf.supabase.co/**',async route=>{const r=route.request(),url=new URL(r.url());let body=null;try{body=r.postDataJSON()}catch(e){}
  if(url.pathname==='/functions/v1/tables'){reqs++;const res=await H.handle(body,(r.headers().authorization||'').replace('Bearer ',''),D);return route.fulfill({status:res.status,contentType:'application/json',body:JSON.stringify(res.body)})}
  if(url.pathname==='/rest/v1/rpc/get_my_locker')return route.fulfill({status:200,contentType:'application/json',body:JSON.stringify({owned:['skin:std'],eq:{},cases:0,shards:bal[U.id],bag:{},st:{},rev:1,username:U.name})});
  return route.fulfill({status:200,contentType:'application/json',body:'null'})});
 const p=await ctx.newPage();await p.addInitScript(([s])=>{localStorage.setItem('palisade.auth.v1',s)},[JSON.stringify({access_token:tok,refresh_token:'r',expires_at:4e9,user:{id:U.id,is_anonymous:false,email:'a@x.y',user_metadata:{pw:true}}})]);
 await p.goto(`http://localhost:${PORT}/debug.html?${Q}`);await ready(p);await p.click('[data-nav=tables]');await quiet(p);await p.click('#casEnterBtn');
 await p.waitForFunction(()=>__pal.game&&__pal.game.mode==='casino'&&document.getElementById('menu').hidden,null,{timeout:20000});await p.waitForTimeout(2500);
 // frame deltas over ms milliseconds, while `during` runs
 const measure=async(name,ms,during)=>{const r0=reqs;await p.evaluate(()=>{window.__fd=[];let last=performance.now();const f=t=>{window.__fd.push(t-last);last=t;if(window.__fdOn)requestAnimationFrame(f)};window.__fdOn=true;requestAnimationFrame(f)});
  const t0=Date.now();if(during)await during(ms);else await p.waitForTimeout(ms);const fd=await p.evaluate(()=>{window.__fdOn=false;return window.__fd.slice(2)});
  const heap=await p.evaluate(()=>performance.memory?Math.round(performance.memory.usedJSHeapSize/1048576*10)/10:null);fd.sort((a,b)=>a-b);
  const q=x=>+fd[Math.min(fd.length-1,Math.floor(fd.length*x))].toFixed(2);return{name,frames:fd.length,median:q(.5),p95:q(.95),max:+fd.at(-1).toFixed(1),heapMB:heap,reqPerMin:+((reqs-r0)/((Date.now()-t0)/60000)).toFixed(1)}};
 const out={label,machine:require('node:os').cpus()[0].model+' x'+require('node:os').cpus().length+', headless Chromium (software rendering)',scenes:[]};
 out.scenes.push(await measure('standing',10000));
 out.scenes.push(await measure('walking',10000,async ms=>{const keys=['d','s','a','w'];for(let k=0;k<ms/2500;k++){await p.keyboard.down(keys[k%4]);await p.waitForTimeout(2500);await p.keyboard.up(keys[k%4])}}));
 const sit=async(pos)=>{await p.evaluate(([x,y])=>{const P=__pal.player;P.x=x;P.y=y},pos);await p.waitForTimeout(200);await p.keyboard.press('e');await p.waitForSelector('#casSheet:not([hidden])',{timeout:10000});await p.waitForTimeout(1500)};
 const bj=await p.evaluate(()=>__pal.CAS.tables.find(t=>t.game==='bj').seats[0]);await sit(bj);
 out.scenes.push(await measure('blackjack sheet',12000));await p.click('#tbLeave');await p.waitForTimeout(1500);
 const hasMachines=await p.evaluate(()=>!!__pal.CAS.machines);
 if(hasMachines){const s1=await p.evaluate(()=>__pal.CAS.machines[0].stand);await sit(s1);await p.click('[data-top="100"]');await p.waitForTimeout(800);
  out.scenes.push(await measure('slots spinning',15000,async ms=>{const t0=Date.now();while(Date.now()-t0<ms){await p.click('#tbActs [data-act="spin"]:not([disabled])',{timeout:8000}).catch(()=>{});await p.waitForTimeout(400)}}));
  await p.click('#tbLeave');await p.waitForTimeout(1500);const p1=await p.evaluate(()=>__pal.CAS.machines[16].stand);await sit(p1);await p.click('[data-top="100"]');await p.waitForTimeout(800);
  out.scenes.push(await measure('plinko dropping',15000,async ms=>{const t0=Date.now();while(Date.now()-t0<ms){await p.click('#tbActs [data-act="drop"]:not([disabled])',{timeout:8000}).catch(()=>{});await p.waitForTimeout(400)}}))}
 fs.mkdirSync(__dirname+'/out',{recursive:true});fs.writeFileSync(__dirname+`/out/casino_perf_${label}.json`,JSON.stringify(out,null,1));console.log(JSON.stringify(out));await b.close();
})().catch(e=>{console.error(e);process.exit(1)});
