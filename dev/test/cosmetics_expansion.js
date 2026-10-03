const {chromium}=require('playwright'),assert=require('node:assert/strict'),fs=require('node:fs');
(async()=>{const b=await chromium.launch({executablePath:process.env.CHROMIUM||undefined}),p=await b.newPage({viewport:{width:1280,height:900}}),errors=[];p.on('pageerror',e=>errors.push(e.message));
await p.goto('http://localhost:8080/debug.html?debug=1');await p.waitForFunction(()=>window.__pal);
const r=await p.evaluate(()=>{const P=__pal,failures=[],hats=Object.keys(P.HALLOWEEN_HATS),allHats=P.COS.filter(c=>c.cat==='hat'),skins=Object.keys(P.SKINS),matrix={};
const cv=document.createElement('canvas');cv.width=300;cv.height=320;const x=cv.getContext('2d',{willReadFrequently:true});
const draw=(look,a=0,t=0,phase=0)=>{x.clearRect(0,0,300,320);const bounds=P.paintWardrobeCharacter(x,look,a,t,4,150,240,phase);const pixels=x.getImageData(0,0,300,320).data;return{bounds,pixels}};
for(const skin of skins){matrix[skin]={};for(const h of allHats){const yes=P.headwearAllowed(skin,h.key);if(hats.includes(h.key)||skin==='sahur')matrix[skin][h.key]=yes?'Allow':'Block';if(!yes){const a=P.lookOf({skin,hat:h.key},'soldier'),z=P.lookOf({skin,hat:'class'},'soldier');if(JSON.stringify(a)!==JSON.stringify(z))failures.push('blocked render '+skin+' '+h.key)}}}
const sahurHats=['crown','tophat','visor','headband','pcap','halo','witch','devilhorns',   // v0.9.5.1
  'snowgoggles','ushanka','surveyhelm','rescuehood','pinecrown','yulecap','icinghelm','shako','rimecrest','aurorahalo'];   // v0.9.6.0 winter hats
if(JSON.stringify(Object.keys(matrix.sahur).filter(k=>matrix.sahur[k]==='Allow').sort())!==JSON.stringify(['class',...sahurHats].sort()))failures.push('Sahur eight-hat compatibility');
// v0.9.3.9: the pieces were rebuilt as full headwear; they must stay no taller than our tallest existing hats (Top Hat, Witch)
let tallest=0;for(const ref of['tophat','witch'])for(let a=0;a<Math.PI*2;a+=Math.PI/8)tallest=Math.min(tallest,draw(P.lookOf({skin:'std',hat:ref},'soldier'),a).bounds.top);
for(const hat of hats){if(!P.COSBY['hat:'+hat]||P.COSBY['hat:'+hat].box!=='halloween')failures.push('catalog '+hat);for(let a=0;a<Math.PI*2;a+=Math.PI/8){const look=P.lookOf({skin:'std',hat},'soldier'),d=draw(look,a);if(d.bounds.top < tallest)failures.push('taller than the Top Hat/Witch '+hat)}}
let haloGap=100;
for(let a=0;a<Math.PI*2;a+=Math.PI/8)for(const t of [0,.65,1.95]){const base=P.lookOf({skin:'sheetghost',hat:'class'},'soldier'),plain=draw(base,a,t),halo=draw(P.lookOf({skin:'sheetghost',hat:'halo'},'soldier'),a,t);let ghostTop=320,ringBottom=-1;
for(let y=0;y<320;y++)for(let q=0;q<300;q++){const k=(y*300+q)*4;if(plain.pixels[k+3]>40)ghostTop=Math.min(ghostTop,y);if(halo.pixels[k+3]>40&&plain.pixels[k+3]<=40)ringBottom=Math.max(ringBottom,y)}
haloGap=Math.min(haloGap,ghostTop-ringBottom);if(ringBottom<0||ringBottom>=ghostTop-1)failures.push('halo sheet separation '+a+' '+t+' '+(ghostTop-ringBottom));}
const poses=new Set();for(const cls of Object.keys(P.CLASSES))for(let a=0;a<Math.PI*2;a+=Math.PI/4)for(const phase of [0,.8,2.2]){const look=P.lookOf({skin:'sahur',hat:'class'},cls);look.gaitWeight=1;look.bolt=.35;const d=draw(look,a,0,phase);if(!Object.values(d.bounds).every(Number.isFinite)||d.bounds.top<-52||d.bounds.left<-35||d.bounds.w>70)failures.push('sahur frame '+cls);poses.add(cv.toDataURL());const tile=document.createElement('canvas');tile.width=tile.height=128;P.locker.eq.hat='class';P.drawIcon(tile,P.COSBY['skin:sahur']);const td=tile.getContext('2d').getImageData(0,0,128,128).data;for(let i=0;i<128;i++)for(const k of[i,127*128+i,i*128,i*128+127])if(td[k*4+3]>40)failures.push('sahur tile crop');}
for(const downed of [false,true])draw({...P.lookOf({skin:'sahur',hat:'class'},'soldier'),downed,nogun:downed},.7);
if(P.RAR.u.sh!==80||P.COSBY['skin:sahur'].r!=='u'||P.COSBY['skin:sahur'].box!=='supply')failures.push('ultimate catalog');
const rolls={};for(let i=0;i<80000;i++){const it=P.rollCase('supply');rolls[it.r]=(rolls[it.r]||0)+1}if(Math.abs(rolls.u/80000-.0025)>.0008)failures.push('ultimate odds');
return{hats,skinCount:skins.length,matrix,haloGapPixels:haloGap,sahurDistinctPoses:poses.size,rolls,failures};});
fs.writeFileSync(__dirname+'/out/cosmetics_expansion.json',JSON.stringify({...r,errors},null,2));assert.deepEqual(r.failures,[]);assert.ok(r.sahurDistinctPoses>20);
// Actual Locker rule: blocked gear remains owned and cannot replace the selection.
await p.evaluate(()=>{const P=__pal;P.locker.owned.push(...P.COS.filter(c=>c.cat==='hat').map(c=>c.id));P.locker.eq.skin='sheetghost';P.locker.eq.hat='class';P.showPage('locker')});
await p.click('#lockTabs [data-cat=hat]');await p.click('#collection-hat-halloween');const tile=p.locator('[data-item="hat:gravecap"]');assert.equal(await tile.getAttribute('aria-disabled'),'true');await tile.evaluate(el=>el.click());assert.equal(await p.evaluate(()=>__pal.locker.eq.hat),'class');
await p.evaluate(()=>{__pal.locker.eq.skin='std';__pal.renderLocker()});await tile.click();assert.equal(await p.evaluate(()=>__pal.locker.eq.hat),'gravecap');
// Switching to a special head keeps the hat saved but renders Class Issue, so that tile reads EQUIPPED.
await p.evaluate(()=>{__pal.locker.eq.skin='sahur';__pal.renderLocker()});
assert.equal(await p.evaluate(()=>__pal.locker.eq.hat),'gravecap');assert.match(await p.locator('[data-item="hat:class"] i').textContent(),/EQUIPPED/);assert.match(await p.locator('[data-item="hat:gravecap"] i').textContent(),/DOES NOT FIT/);
// Contact sheet at useful review scale, with the actual shared painter.
const sheet=await p.evaluate(()=>{const P=__pal,cv=document.createElement('canvas');cv.width=1200;cv.height=750;const x=cv.getContext('2d');x.fillStyle='#202923';x.fillRect(0,0,1200,750);
const items=[...Object.keys(P.HALLOWEEN_HATS).map(h=>({skin:'std',hat:h,label:P.COSBY['hat:'+h].name})),{skin:'sheetghost',hat:'halo',label:'Sheet Ghost + Halo'},...['soldier','sniper','grenadier','quartermaster'].map(cls=>({skin:'sahur',hat:'class',cls,label:'Sahur / '+cls})),{skin:'sahur',hat:'class',downed:true,label:'Sahur / downed'}];
items.forEach((it,i)=>{const ox=i%6*200+100,oy=Math.floor(i/6)*370+295,look=P.lookOf(it,it.cls||'soldier');if(it.downed){look.downed=true;look.nogun=true}P.paintWardrobeCharacter(x,look,.55,0,5,ox,oy,.8);x.fillStyle='#efe8d6';x.font='13px sans-serif';x.textAlign='center';x.fillText(it.label,ox,oy+35);});return cv.toDataURL();});fs.writeFileSync(__dirname+'/out/cosmetics_expansion.png',Buffer.from(sheet.split(',')[1],'base64'));
assert.deepEqual(errors,[]);console.log({...r,matrix:'saved in JSON'});console.log('errors: none');await b.close();})().catch(e=>{console.error(e);process.exit(1)});
