const fs=require('node:fs'),vm=require('node:vm');
let gen=fs.readFileSync('dev/src/js/06g-understrip.js','utf8');
for (const r of [1,2,3]) gen=gen.replace(`/*@@US_KIT_R${r}@@*/null`,fs.readFileSync(`dev/data/understrip/rooms-r${r}.json`,'utf8'));
const loot=fs.readFileSync('dev/src/js/10j-understrip-loot.js','utf8');
const mode=fs.readFileSync('dev/src/js/10h-understrip.js','utf8');
const ctx=vm.createContext({MAPS:{}});
vm.runInContext(gen+'\n'+loot+'\n'+mode+'\n;globalThis.U={US_TIER,US_WEAPONS,US_MODS,US_PERKS:US_PERKS_ALL,US_RELICS,US_LOOT,US_ITEMS,usRollLoot,usStock,usLiftStock,usCollectorStock,usPopulate,usGenerate,US_KITS,usRng,usRollWeapon,usWeaponGun};',ctx);
const U=ctx.U;
fs.writeFileSync('godot/data/understrip/loot.json',JSON.stringify(Object.fromEntries(['US_TIER','US_WEAPONS','US_MODS','US_PERKS','US_RELICS','US_LOOT','US_ITEMS'].map(k=>[k.slice(3).toLowerCase(),U[k]])),null,2)+'\n');
const fixture=[];
for(let seed=0;seed<60;seed++)for(const reg of [1,2,3])for(const src of ['chest','elite','boss']) fixture.push([seed,reg,src,U.usRollLoot(U.usRng(seed),src,reg)]);
fs.writeFileSync('godot/tests/understrip_loot_fixture.json',JSON.stringify(fixture));
console.log('Exported browser tables and',fixture.length,'loot fixtures');
const stocks=[];
for (let seed=0;seed<20;seed++) for (const region of [1,2,3]) for (const kind of ['trader','lift','collector']) {
 const fn={trader:U.usStock,lift:U.usLiftStock,collector:U.usCollectorStock}[kind];
 stocks.push([seed,region,kind,fn(U.usRng(seed),region)]);
}
fs.writeFileSync('godot/tests/understrip_stock_fixture.json',JSON.stringify(stocks));
const population=[];
for (const region of [1,2,3]) for (const seed of [0,1,1234,0xffffffff]) {
 const level=U.usGenerate(U.US_KITS[region],seed,'normal','');
 population.push([region,seed,U.usPopulate(level,U.usRng((()=>{let h=0x9e3779b9;for(const x of [seed,77]){h=Math.imul(h^(x|0),0x85ebca6b);h^=h>>>13;h=Math.imul(h,0xc2b2ae35);h^=h>>>16}return h>>>0})()),region)]);
}
fs.writeFileSync('godot/tests/understrip_population_fixture.json',JSON.stringify(population));
console.log('Exported',stocks.length,'merchant stocks and',population.length,'raider populations');
