// Sahur's eight approved hats: compatibility, cached-painter poses, Locker framing and review sheet.
const {chromium}=require('playwright'),assert=require('node:assert/strict'),fs=require('node:fs');
const HATS=['crown','tophat','visor','headband','pcap','halo','witch','devilhorns'];
(async()=>{
 const b=await chromium.launch({executablePath:process.env.CHROMIUM||undefined}),p=await b.newPage({viewport:{width:1280,height:900}}),errors=[];
 p.on('pageerror',e=>errors.push(e.message));await p.goto(`http://localhost:${process.env.PORT||8080}/debug.html?debug=1`);await p.waitForFunction(()=>window.__pal);
 const r=await p.evaluate(hats=>{
  const P=__pal,fail=[],all=P.COS.filter(c=>c.cat==='hat').map(c=>c.key),allowed=all.filter(h=>P.headwearAllowed('sahur',h));
  if(JSON.stringify(allowed.slice().sort())!==JSON.stringify(['class',...hats].sort()))fail.push('Sahur compatibility set');
  for(const skin of ['demon','reaper','sheetghost','mummy','phantom','scarecrow','slasher','clown'])if(!P.SKINS[skin])continue;else for(const h of hats)if(P.headwearAllowed(skin,h)&&!(skin==='sheetghost'&&h==='halo'))fail.push('special compatibility '+skin+' '+h);
  const cv=document.createElement('canvas');cv.width=300;cv.height=320;const x=cv.getContext('2d',{willReadFrequently:true});
  const paint=(look,a,phase)=>{x.clearRect(0,0,300,320);const bounds=P.paintWardrobeCharacter(x,look,a,0,4,150,250,phase);return{data:x.getImageData(0,0,300,320).data,bounds}};
  let combinations=0,smallestDiff=1e9;
  for(const h of hats)for(let a=0;a<Math.PI*2-1e-5;a+=Math.PI/4)for(const phase of [0,.8,2.2]){
   const base=P.lookOf({skin:'sahur',hat:'class'},'soldier'),hat=P.lookOf({skin:'sahur',hat:h},'soldier');base.gaitWeight=hat.gaitWeight=1;
   const A=paint(base,a,phase),B=paint(hat,a,phase);let diff=0;for(let k=0;k<A.data.length;k+=4)if(Math.abs(A.data[k]-B.data[k])+Math.abs(A.data[k+1]-B.data[k+1])+Math.abs(A.data[k+2]-B.data[k+2])+Math.abs(A.data[k+3]-B.data[k+3])>80)diff++;
   smallestDiff=Math.min(smallestDiff,diff);if(diff<25)fail.push('hat invisible '+h+' '+a+' '+phase);
   if(B.bounds.top<-51||B.bounds.left<-37||B.bounds.w>74)fail.push('frame '+h+' '+a+' '+phase+' '+JSON.stringify(B.bounds));combinations++;
  }
  for(const h of hats){const look=P.lookOf({skin:'sahur',hat:h},'soldier');if(look.demon||look.demonHorns||look.aura)fail.push('Demon geometry '+h);
   const downA=paint({...P.lookOf({skin:'sahur',hat:'class'},'soldier'),downed:true,nogun:true},.7,0),downB=paint({...look,downed:true,nogun:true},.7,0);
   let downDiff=0;for(let k=0;k<downA.data.length;k+=4)if(Math.abs(downA.data[k]-downB.data[k])+Math.abs(downA.data[k+1]-downB.data[k+1])+Math.abs(downA.data[k+2]-downB.data[k+2])+Math.abs(downA.data[k+3]-downB.data[k+3])>80)downDiff++;
   if(downDiff<20)fail.push('downed hat invisible '+h);
   P.locker.eq.skin='sahur';const tile=document.createElement('canvas');tile.width=tile.height=128;P.drawIcon(tile,P.COSBY['hat:'+h]);const d=tile.getContext('2d').getImageData(0,0,128,128).data;
   // Headwear thumbnails intentionally cut off the body; check the top and upper side edges around the hat.
   if(Array.from({length:128},(_,i)=>i).some(k=>d[k*4+3]>40)||Array.from({length:85},(_,i)=>i).some(y=>d[y*128*4+3]>40||d[(y*128+127)*4+3]>40))fail.push('tile hat crop '+h);
  }
  const sheet=document.createElement('canvas');sheet.width=1200;sheet.height=930;const g=sheet.getContext('2d');g.fillStyle='#182731';g.fillRect(0,0,sheet.width,sheet.height);
  for(const [i,h] of ['class',...hats].entries()){
   const col=i%3,row=Math.floor(i/3),left=col*400,top=row*310,look=P.lookOf({skin:'sahur',hat:h},'soldier');
   g.fillStyle='#263c46';g.fillRect(left+8,top+8,384,294);P.paintWardrobeCharacter(g,look,.55,0,4.5,left+120,top+250,.8);
   P.locker.eq.skin='sahur';const tile=document.createElement('canvas');tile.width=tile.height=128;P.drawIcon(tile,P.COSBY['hat:'+h]);g.drawImage(tile,left+227,top+74,128,128);
   g.fillStyle='#f3e9d6';g.textAlign='center';g.font='18px sans-serif';g.fillText(h==='class'?'Class Issue':P.COSBY['hat:'+h].name,left+200,top+37);
   g.font='11px sans-serif';g.fillText('GAME',left+120,top+282);g.fillText('LOCKER',left+291,top+226);
  }
  const angles=document.createElement('canvas');angles.width=8*150;angles.height=8*165;const ax=angles.getContext('2d');ax.fillStyle='#182731';ax.fillRect(0,0,angles.width,angles.height);
  for(const [col,h] of hats.entries())for(let row=0;row<8;row++){
   const left=col*150,top=row*165;ax.fillStyle='#263c46';ax.fillRect(left+2,top+2,146,161);
   P.paintWardrobeCharacter(ax,P.lookOf({skin:'sahur',hat:h},'soldier'),row*Math.PI/4,0,2.5,left+75,top+147,.8);
   ax.fillStyle='#f3e9d6';ax.textAlign='center';ax.font='10px sans-serif';ax.fillText(h+' · '+row*45+'°',left+75,top+14);
  }
  const downed=document.createElement('canvas');downed.width=4*240;downed.height=2*210;const dx=downed.getContext('2d');dx.fillStyle='#182731';dx.fillRect(0,0,downed.width,downed.height);
  for(const [i,h] of hats.entries()){const left=i%4*240,top=Math.floor(i/4)*210;dx.fillStyle='#263c46';dx.fillRect(left+3,top+3,234,204);
   P.paintWardrobeCharacter(dx,{...P.lookOf({skin:'sahur',hat:h},'soldier'),downed:true,nogun:true},.7,0,3.3,left+119,top+145,0);
   dx.fillStyle='#f3e9d6';dx.textAlign='center';dx.font='13px sans-serif';dx.fillText(h,left+120,top+26);
  }
  return{allowed,combinations,smallestDiff,fail,sheet:sheet.toDataURL(),angles:angles.toDataURL(),downed:downed.toDataURL()};
 },HATS);
 const out=__dirname+'/out';fs.writeFileSync(out+'/sahur_hats.png',Buffer.from(r.sheet.split(',')[1],'base64'));delete r.sheet;
 fs.writeFileSync(out+'/sahur_hats_angles.png',Buffer.from(r.angles.split(',')[1],'base64'));delete r.angles;
 fs.writeFileSync(out+'/sahur_hats_downed.png',Buffer.from(r.downed.split(',')[1],'base64'));delete r.downed;
 fs.writeFileSync(out+'/sahur_hats.json',JSON.stringify({...r,errors},null,2));
 await p.evaluate(hats=>{const P=__pal;for(const h of hats)if(!P.locker.owned.includes('hat:'+h))P.locker.owned.push('hat:'+h);P.locker.eq.skin='sahur';P.showPage('locker')},HATS);
 for(const h of HATS){
  const c=await p.evaluate(h=>__pal.COSBY['hat:'+h],h);
  await p.click(`#lockTabs [data-cat=${c.ladder?'ms':'hat'}]`);
  if(c.box){const toggle=p.locator(`#collection-hat-${c.box}`);if(await toggle.getAttribute('aria-expanded')!=='true')await toggle.click()}
  const tile=p.locator(`[data-item="hat:${h}"]`);assert.equal(await tile.getAttribute('aria-disabled'),'false',h+' must fit');await tile.evaluate(el=>el.click());
  assert.equal(await p.evaluate(()=>__pal.locker.eq.hat),h,h+' equips');
  assert.ok(await p.evaluate(h=>Object.values(localStorage).some(v=>v.includes('"hat":"'+h+'"')),h),h+' saves');
 }
 await p.evaluate(()=>{__pal.locker.eq.skin='std';__pal.renderLocker()});assert.equal(await p.evaluate(()=>__pal.locker.eq.hat),'devilhorns','saved hat remains after switching skin');
 assert.deepEqual(r.fail,[]);assert.deepEqual(errors,[]);console.log(JSON.stringify(r));console.log('errors: none');await b.close();
})().catch(e=>{console.error(e);process.exit(1)});
