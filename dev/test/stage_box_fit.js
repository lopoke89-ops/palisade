// v0.9.8.2 the Locker stage repaints only a box around your figure (instead of the whole stage layer). Every skin and
// every piece of headwear, for every class, at several turn angles, must draw inside that box, or part of it would be
// cut off. The box: 40 figure-units either side, 70 above the feet and 16 below (19b-social-lobby.js). node stage_box_fit.js
const {chromium}=require('playwright'),assert=require('node:assert/strict'),fs=require('node:fs');
(async()=>{const b=await chromium.launch({executablePath:process.env.CHROMIUM||undefined}),p=await b.newPage(),errors=[];p.on('pageerror',e=>errors.push(e.message));
 await p.goto(`http://localhost:${process.env.PORT||8080}/debug.html?debug=1`);await p.waitForFunction(()=>window.__pal);
 const r=await p.evaluate(()=>{const P=__pal,ms=3,W=520,H=520,mx=260,my=380,c=document.createElement('canvas');c.width=W;c.height=H;const x=c.getContext('2d');
  const cls=Object.keys(P.CLASSES||{soldier:1}),items=P.COS.filter(i=>i.cat==='hat'||i.cat==='skin');let worst={l:0,r:0,t:0,b:0},bad=[],n=0;
  for(const it of items)for(const k of cls)for(const ang of[-1.2,-.4,0,.6,1.5,3.1]){
   const eq=it.cat==='hat'?{hat:it.key}:{skin:it.key},lk=P.lookOf(eq,k);x.clearRect(0,0,W,H);P.paintWardrobeCharacter(x,lk,ang,0,ms,mx,my-4,false);n++;
   const d=x.getImageData(0,0,W,H).data;let l=W,rr=-1,t=H,bb=-1;for(let y=0;y<H;y++)for(let q=0;q<W;q++)if(d[(y*W+q)*4+3]>8){if(q<l)l=q;if(q>rr)rr=q;if(y<t)t=y;if(y>bb)bb=y}
   if(rr<0)continue;const e={l:(mx-l)/ms,r:(rr-mx)/ms,t:(my-4-t)/ms,b:(bb-(my-4))/ms};
   for(const s of['l','r','t','b'])worst[s]=Math.max(worst[s],e[s]);if(e.l>40||e.r>40||e.t>70||e.b>16)bad.push(it.id+'/'+k+'@'+ang+' '+JSON.stringify(e))}
  return{n,worst,bad:bad.slice(0,10),badN:bad.length}});
 fs.writeFileSync(__dirname+'/out/stage_box_fit.json',JSON.stringify(r,null,1));console.log(JSON.stringify(r));
 assert.equal(r.badN,0,'every outfit fits the repaint box');assert.deepEqual(errors,[]);console.log('errors: none');await b.close();
})().catch(e=>{console.error(e);process.exit(1)});
