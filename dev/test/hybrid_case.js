// v0.9.6.4 Hybrid Theory Case: catalog, case roll, jersey body, headgear fit (Dunce Cone on the Sheet Ghost),
// kill effects, animated backgrounds, and the local drop rules (one per co-op win on cv:4 claims; gauntlet payouts).
const {chromium}=require('playwright'),fs=require('node:fs'),assert=require('node:assert/strict');
(async()=>{const browser=await chromium.launch({executablePath:process.env.CHROMIUM||undefined}),page=await browser.newPage({viewport:{width:1360,height:950}}),errs=[];page.on('pageerror',e=>errs.push(e.message));await page.goto('http://localhost:8080/debug.html?debug=1');await page.waitForFunction(()=>__pal?.COS);
 const result=await page.evaluate(()=>{const P=__pal,items=P.COS.filter(it=>it.collection==='hybrid'),out={counts:{},rar:{},fit:[],fails:[]};
  for(const c of items){out.counts[c.cat]=(out.counts[c.cat]||0)+1;out.rar[c.cat+':'+c.r]=(out.rar[c.cat+':'+c.r]||0)+1;if(c.box!=='hybrid'||!c.description)out.fails.push('row '+c.id)}
  out.ids=new Set(P.COS.map(c=>c.id)).size===P.COS.length;
  out.case=P.CASES.hybrid;
  // rolls only ever give Hybrid items, and every tier shows up
  const seen={};for(let i=0;i<6000;i++){const it=P.rollCase('hybrid');const row=it&&(it.id?it:P.COS.find(c=>c.id===it));if(!row||row.collection!=='hybrid'){out.fails.push('roll '+JSON.stringify(it));break}seen[row.r]=(seen[row.r]||0)+1}out.seen=seen;
  // looks: jerseys are their own body with a trim headband by default; gold ones carry the shared aura
  const j=P.lookOf({skin:'hb_bakers',hat:'class'},'soldier');out.jersey={jersey:j.jersey,trim:j.jtrim,headband:j.headband,helmet:!!j.helmet,aura:P.SKINS.hb_bakers.aura};
  out.dunceSheet=P.headwearAllowed('sheetghost','dunce');out.capSheet=P.headwearAllowed('sheetghost','yamaka');
  const cv=document.createElement('canvas');cv.width=1360;cv.height=930;cv.style='position:fixed;inset:0;z-index:9999;background:#14232e';document.body.append(cv);const c=cv.getContext('2d');c.fillStyle='#14232e';c.fillRect(0,0,1360,930);c.font='11px monospace';c.textAlign='center';
  const skins=items.filter(i=>i.cat==='skin'),hats=items.filter(i=>i.cat==='hat'),fx=items.filter(i=>i.cat==='fx'),bgs=items.filter(i=>i.cat==='bg');
  skins.forEach((s,n)=>{const x=45+(n%15)*90,y=95+Math.floor(n/15)*150,hat=hats[n%hats.length].key;const look=P.lookOf({skin:s.key,hat:n<15?'class':hat,trail:'std',fx:'none'},'soldier');
   if(n>=15)out.fit.push({skin:s.key,hat,allowed:P.headwearAllowed(s.key,hat),field:look.hybridHat});P.paintWardrobeCharacter(c,look,.6,1,2.2,x,y,false);c.fillStyle='#e4eff1';c.fillText(s.name.split(' ').pop(),x,y+26)});
  const sheet=P.lookOf({skin:'sheetghost',hat:'dunce'},'soldier');out.sheetField=sheet.hybridHat;P.paintWardrobeCharacter(c,sheet,.6,1,2.2,680,365,false);c.fillStyle="#e4eff1";c.fillText("Sheet Ghost + Dunce Cone",680,392);
  fx.forEach((f,i)=>{const x=60+i*122;P.paintFinish(c,f.key,.4,1.5,x,470);c.fillStyle='#e4eff1';c.fillText(f.name,x,520)});
  bgs.forEach((b,i)=>{const x=(i%4)*340,y=550+Math.floor(i/4)*190;c.save();c.translate(x,y);P.BGS[b.key].draw(c,334,168,2);c.restore();c.fillStyle='#e4eff1';c.fillText(b.name,x+167,y+182)});
  // every finish draws something at every point of its life
  const t=document.createElement('canvas');t.width=120;t.height=120;const tc=t.getContext('2d');
  for(const f of fx){if(!P.FINISH_LIFE[f.key])out.fails.push('life '+f.key);for(const p of[.02,.25,.5,.75,.97]){tc.clearRect(0,0,120,120);P.paintFinish(tc,f.key,p,1.5,60,80);const d=tc.getImageData(0,0,120,120).data;let n=0;for(let k=3;k<d.length;k+=4)if(d[k])n++;if(!n)out.fails.push('empty '+f.key+p)}}
  // animated backgrounds move
  const blank=document.createElement('canvas');blank.width=200;blank.height=140;const bc=blank.getContext('2d');out.motion=bgs.map(b=>{bc.clearRect(0,0,200,140);P.BGS[b.key].draw(bc,200,140,1);const a=blank.toDataURL();bc.clearRect(0,0,200,140);P.BGS[b.key].draw(bc,200,140,3);return a!==blank.toDataURL()});
  // all jerseys and hats in every class, angle and downed pose
  out.poses=0;for(const s of skins)for(const hat of['class',...hats.map(h=>h.key)].slice(0,s.key.length%3?3:9))for(const cls of Object.keys(P.CLASSES))for(let a=0;a<8;a+=2)for(const downed of[false,true]){P.paintWardrobeCharacter(bc,{...P.lookOf({skin:s.key,hat},cls),downed},a*Math.PI/4,0,1.4,100,125,false);out.poses++}
  for(const hat of hats.map(h=>h.key))for(let a=0;a<8;a++){P.paintWardrobeCharacter(bc,P.lookOf({skin:'std',hat},'soldier'),a*Math.PI/4,0,1.4,100,125,false);out.poses++}
  // local drops: one Hybrid Theory Case per co-op win, only on cv:4 claims
  const L=P.locker,bag=()=>({...L.bag}),d=(a,b,k)=>(b[k]|0)-(a[k]|0),base={kind:'run',diff:'normal',kills:0,boss_keys:[],sb_keys:[],shard_bosses:0,size:'std',mods:[],cls:'soldier',map:'yard'};
  let b0=bag();P.localRun({...base,mode:'5',win:true,held:5,raid_from:0,raid_to:5,cv:4},0);out.win5=d(b0,bag(),'hybrid');
  b0=bag();P.localRun({...base,mode:'5',win:true,held:5,raid_from:0,raid_to:5},0);out.oldClient=d(b0,bag(),'hybrid');
  b0=bag();P.localRun({...base,mode:'5',win:false,held:3,raid_from:0,raid_to:3,cv:4},0);out.loss=d(b0,bag(),'hybrid');
  // campaign finale: 6 waves cleared (18 bosses), the final evac, two of three chapter evacs
  const W=P.CAMPAIGN.waves,fk=[];for(let w=0;w<6;w++)fk.push('rime','rime',P.GAUNTLET.pool[w]);
  const s0=L.shards|0,r0=L.st.boss_rime|0;b0=bag();
  const rw=P.localRun({...base,mode:'campaign',win:true,held:W,raid_from:0,raid_to:W,evac:'evac',fb_keys:fk,g_cleared:6,ch_evac:[true,false,true],cv:4},0);
  out.camp={winter:d(b0,bag(),'winter'),hybrid:d(b0,bag(),'hybrid'),shards:(L.shards|0)-s0,rime:(L.st.boss_rime|0)-r0,sp:rw.sp};
  // a wave count that the boss keys can't back up is clipped
  b0=bag();P.localRun({...base,mode:'campaign',win:false,held:W,raid_from:0,raid_to:W,evac:'left',fb_keys:fk.slice(0,4),g_cleared:6,ch_evac:[false,null,null],cv:4},0);out.clip=d(b0,bag(),'winter');
  return out;
 });
 assert.deepEqual(result.fails,[]);assert.ok(result.ids,'duplicate cosmetic ids');
 assert.deepEqual(result.counts,{skin:30,hat:8,fx:11,bg:8});
 assert.deepEqual(result.rar,{'skin:c':6,'skin:r':6,'skin:e':6,'skin:l':6,'skin:g':6,'hat:c':2,'hat:r':3,'hat:e':2,'hat:l':1,'fx:r':3,'fx:e':2,'fx:l':1,'fx:g':1,'fx:c':4,'bg:g':4,'bg:l':4});
 assert.equal(result.case.cost,12);assert.equal(result.case.col,'#c1d32f');assert.deepEqual(result.case.weights,{c:46,r:30,e:16,l:7,g:1});
 for(const r of['c','r','e','l','g'])assert.ok(result.seen[r]>0,'tier '+r);
 assert.deepEqual(result.jersey,{jersey:true,trim:'#111111',headband:'#111111',helmet:false,aura:'ghybrid'});
 assert.equal(result.dunceSheet,true);assert.equal(result.capSheet,false);assert.equal(result.sheetField,'dunce');
 result.fit.forEach(r=>{assert.ok(r.allowed,r.skin+' '+r.hat);assert.equal(r.field,r.hat)});
 assert.ok(result.motion.every(Boolean),'backgrounds move');
 assert.equal(result.win5,1);assert.equal(result.oldClient,0);assert.equal(result.loss,0);
 assert.deepEqual({...result.camp,shards:undefined},{winter:10,hybrid:1,shards:undefined,rime:12,sp:result.camp.sp});
 assert.ok(result.camp.shards>=18*5+25&&result.camp.shards<=18*10+25,'gauntlet shards '+result.camp.shards);
 assert.equal(result.clip,1,"left behind with 4 bosses: one wave case, kept after halving (odd counts round up)");
 assert.deepEqual(errs,[]);
 await page.screenshot({path:__dirname+'/out/hybrid_collection.png'});fs.writeFileSync(__dirname+'/out/hybrid_case.json',JSON.stringify(result,null,2));await browser.close();
 console.log({counts:result.counts,seen:result.seen,camp:result.camp,poses:result.poses});console.log('errors: none');
})().catch(e=>{console.error(e);process.exit(1)});
