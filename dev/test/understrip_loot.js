// THE UNDERSTRIP loot tables (dev/src/js/10j-understrip-loot.js) against their design source (dev/plans/understrip/tables/*.csv),
// with no browser: every weapon's numbers, the rarity tiers, the mods, the 20 perks, the relics and the loot sources match;
// rolled loot is always something real (a weapon of the region or below with the right number of mods, a perk or relic that
// exists, rarities from the source's table); the same seed rolls the same loot.
// node understrip_loot.js
const assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path'),vm=require('node:vm');
const ROOT=path.join(__dirname,'../..'),T=path.join(ROOT,'dev/plans/understrip/tables');
const csv=n=>{const L=fs.readFileSync(path.join(T,n+'.csv'),'utf8').trim().split('\n'),parse=l=>{const o=[];let c='',q=false;for(const ch of l){if(ch==='"'){q=!q;continue}if(ch===','&&!q){o.push(c);c='';continue}c+=ch}o.push(c);return o};
  const h=parse(L[0]);return L.slice(1).map(l=>{const v=parse(l);return Object.fromEntries(h.map((k,i)=>[k,v[i]]))})};
const gen=fs.readFileSync(path.join(ROOT,'dev/src/js/06g-understrip.js'),'utf8').replace('/*@@US_KIT_R1@@*/null','{"pieces":[]}');
const loot=fs.readFileSync(path.join(ROOT,'dev/src/js/10j-understrip-loot.js'),'utf8');
const ctx=vm.createContext({RAR:{c:{n:'COMMON',col:'#9a958a'},r:{n:'RARE',col:'#4f95e0'},e:{n:'EPIC',col:'#b168e0'},l:{n:'LEGENDARY',col:'#e2b436'},g:{n:'GOLD',col:'#ffe27a'}},US_ITEMS:{c_nade:{name:'GRENADE'},c_flare:{name:'ROAD FLARE'},c_bar:{name:'BARRICADE'},c_juice:{name:'SPARE JUICE'}}});
vm.runInContext(gen+'\n'+loot+'\n;globalThis.L={US_WEAPONS,US_TIER,US_MODS,US_PERKS,US_RELICS,US_LOOT,usRollLoot,usRollWeapon,usWeaponGun,usRng,usHash,US_RAR};',ctx);
const L=ctx.L,num=v=>+v,out={};
// weapons
const W=csv('weapons');assert.equal(W.length,Object.keys(L.US_WEAPONS).length,'weapon count');
for(const r of W){const w=L.US_WEAPONS[r.id];assert.ok(w,r.id+' missing');assert.equal(w.region,num(r.region),r.id+' region');assert.equal(w.name,r.name,r.id+' name');
  for(const k of['dmg','cd','spread','range','mag'])assert.equal(w.gun[k],num(r[k]),`${r.id} ${k}`);
  assert.equal(w.gun.pellets||1,num(r.pellets),r.id+' pellets');assert.equal(w.gun.pierce||0,num(r.pierce),r.id+' pierce');
  assert.equal(w.magReload,num(r.reload),r.id+' reload');assert.equal(w.reserve,num(r.reserve),r.id+' reserve');
  if(num(r.speed))assert.equal(w.gun.speed,num(r.speed),r.id+' speed')}
for(const r of csv('weapon_tiers')){const t=L.US_TIER[r.rarity];assert.equal(t.x,num(r.damage_x));assert.equal(t.mods,num(r.mod_slots));assert.equal(t.price,num(r.price_salvage));assert.equal(!!t.sig,r.signature==='yes')}
for(const r of csv('weapon_mods')){const m=L.US_MODS[r.id];assert.ok(m,r.id);assert.equal(m.name,r.name);assert.equal(m.min,r.min_rarity);assert.equal(m.w,num(r.weight))}
const P=csv('perks');assert.equal(P.length,20);assert.equal(Object.keys(L.US_PERKS).length,20);
for(const r of P){const p=L.US_PERKS[r.id];assert.ok(p,r.id);assert.equal(p.name,r.name,r.id);assert.equal(p.r,r.rarity,r.id)}
for(const r of csv('relics')){const x=L.US_RELICS[r.id];assert.ok(x,r.id);assert.equal(x.name,r.name);assert.equal(x.r,r.rarity)}
for(const r of csv('loot_sources')){const S=L.US_LOOT[r.source];if(!S)continue;const wts=Object.fromEntries([...r['contents (weights)'].matchAll(/([a-z]+) (\d+)/g)].map(m=>[m[1],+m[2]]));
  for(const[k,v]of S.what)assert.equal(wts[k],v,`${r.source} ${k}`);
  for(const reg of[1,2,3]){const s=r[`region${reg}_rarity`];if(!s)continue;const o=Object.fromEntries(s.split(' ').map(x=>x.split(':')).map(([k,v])=>[k,+v]));assert.deepEqual({...S.rar[reg]},o,`${r.source} region ${reg}`)}}
// rolls
const counts={},seen=new Set();
for(const src of['chest','elite','boss'])for(const reg of[1,2,3]){const r=L.usRng(L.usHash(7,reg,src.length));for(let n=0;n<4000;n++){const x=L.usRollLoot(r,src,reg);counts[src+reg+x.kind]=(counts[src+reg+x.kind]|0)+1;
  if(x.kind==='weapon'){const w=L.US_WEAPONS[x.w.id];assert.ok(w&&w.region<=reg,'weapon from a deeper region');assert.equal(x.w.mods.length,Math.min(L.US_TIER[x.w.r].mods,99));assert.equal(new Set(x.w.mods).size,x.w.mods.length,'no mod twice');
    assert.ok(Object.keys(L.US_LOOT[src].rar[reg]).includes(x.w.r),src+' rarity '+x.w.r);const G=L.usWeaponGun(x.w,{});assert.ok(G.dmg>0&&G.cd>0&&G.mag>0&&G.reload>0,'a working gun');seen.add(x.w.id)}
  else if(x.kind==='perk'){assert.ok(L.US_PERKS[x.k]);assert.ok(!(L.US_PERKS[x.k].from>reg),'a perk from a deeper region')}
  else if(x.kind==='relic'){assert.ok(L.US_RELICS[x.k]);assert.ok(!(L.US_RELICS[x.k].from>reg))}
  else if(x.kind==='salvage')assert.ok(x.sal>=15&&x.sal<=30)}}
assert.equal(seen.size,9,'every weapon drops somewhere');
assert.ok(!counts.chest1salvage||counts.chest1salvage>800,'chests: about a quarter salvage');assert.ok(!counts.boss1salvage&&!counts.boss1consumable,'bosses drop rare-or-better gear only');
const a=L.usRollLoot(L.usRng(99),'chest',1),b=L.usRollLoot(L.usRng(99),'chest',1);assert.deepEqual(JSON.parse(JSON.stringify(a)),JSON.parse(JSON.stringify(b)),'same seed, same loot');
console.log(JSON.stringify({weapons:W.length,perks:P.length,rolls:Object.values(counts).reduce((x,y)=>x+y,0)}));
console.log('PASS understrip_loot; errors: none');
