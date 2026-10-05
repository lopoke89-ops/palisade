// v0.9.8.2 animated menu backgrounds keep moving on every menu page (they used to freeze behind the Locker, Tables,
// Skills, Settings and Account), and a still background, or the system's reduced-motion setting, stays still.
// Three sizes; screenshots in out/menu_bg_*.png. node menu_bg_motion.js
const {chromium}=require('playwright'),{ready,frames}=require('./lib'),assert=require('node:assert/strict'),fs=require('node:fs');
(async()=>{const b=await chromium.launch({executablePath:process.env.CHROMIUM||undefined}),errors=[],out={};
 const PAGES=['solo','classes','multi','locker','tables','skills','settings','account'];
 for(const [n,vp,m]of[['desktop',{width:1366,height:820},false],['portrait',{width:390,height:844},true],['landscape',{width:844,height:390},true]])for(const rm of[false,true]){
  const ctx=await b.newContext({viewport:vp,isMobile:m,hasTouch:m,reducedMotion:rm?'reduce':'no-preference'}),p=await ctx.newPage();p.on('pageerror',e=>errors.push(n+': '+e.message));
  await p.goto(`http://localhost:${process.env.PORT||8080}/debug.html?debug=1`);await ready(p);
  const frame=()=>p.evaluate(()=>{const c=document.getElementById('lobbyBg'),x=document.createElement('canvas');x.width=64;x.height=36;x.getContext('2d').drawImage(c,0,0,64,36);return x.toDataURL()});
  const res={};
  for(const bg of['hellgate','campfire']){
   await p.evaluate(bg=>{__pal.locker.eq.bg=bg},bg);
   for(const pg of PAGES){await p.evaluate(pg=>__pal.showPage(pg),pg);if(rm)await p.waitForTimeout(250);else await frames(p,3);const a=await frame();let c=a;
    if(rm){await p.waitForTimeout(400);c=await frame()}else for(const t=Date.now();c===a&&Date.now()-t<1500;){await p.waitForTimeout(60);c=await frame()}   // moving: stop at the first changed frame; still: one 0.4 s window (a phone draws 6 frames in it)
    res[bg+'/'+pg]=a!==c;if(bg==='hellgate'&&!rm&&(pg==='locker'||pg==='tables'))await p.screenshot({path:`${__dirname}/out/menu_bg_${n}_${pg}.png`})}}
  out[n+(rm?'/reduced':'')]=res;await ctx.close()}
 fs.writeFileSync(__dirname+'/out/menu_bg_motion.json',JSON.stringify(out,null,1));
 const anim=await (async()=>{const p=await (await b.newContext()).newPage();await p.goto(`http://localhost:${process.env.PORT||8080}/debug.html?debug=1`);await p.waitForFunction(()=>window.__pal);
  const r=await p.evaluate(()=>{const B=__pal.BGS||null;return B?{hell:B.hellgate&&B.hellgate.still,camp:B.campfire&&B.campfire.still}:null});return r})();
 for(const [k,res]of Object.entries(out))for(const [kk,moved]of Object.entries(res)){
  const [bg,pg]=kk.split('/');
  if(k.endsWith('/reduced'))assert.equal(moved,false,k+' '+kk+': reduced motion shows a still');
  else if(bg==='hellgate')assert.equal(moved,true,k+' '+kk+': the animated background moves');}
 console.log(JSON.stringify({desktop:out.desktop,bgFlags:anim}));assert.deepEqual(errors,[]);console.log('errors: none');await b.close();
})().catch(e=>{console.error(e);process.exit(1)});
