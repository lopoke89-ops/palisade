/* ================= modifiers (v0.9.2) ================= */
// The host switches modifiers on before a match. Each one is data: the modes it works in, what it does to rewards
// (a percentage the server applies itself; the same table lives in the v0.9.2 migration), and the batch it
// shipped in. The game code checks game.mods through hasMod(); nothing else needs to know the list.
// ids are sent over the network and stored with results: never rename one, only add.
const MODS=[
  {id:'nopatch',name:'NO PATCH-UPS',what:'No core repair at the armory. Walls can still be fixed.',modes:['coop'],bonus:10},
  {id:'alone',name:'ON YOUR OWN',what:'No Delgado. Nobody hands out materials, fixes walls or picks you up but your crew.',modes:['coop'],bonus:20},
  {id:'firestorm',name:'FIRESTORM',what:'More firebrands from raid 1. Bigger, longer fires, and walls burn down faster.',modes:['coop'],bonus:10},
  {id:'adrenaline',name:'ADRENALINE',what:'Everyone moves 20% faster. Lowers rewards a little.',modes:['coop','base','ffa'],bonus:-15},
  {id:'laststand',name:'LAST STAND',what:'Go down in a raid and you stay down until it ends, unless a teammate, Delgado or a quartermaster gets you up.',modes:['coop'],bonus:10},
  {id:'elite',name:'ELITE RAID',what:'No riflemen: every raider is a special. Spotters mark you for the grenadiers and firebrands instead.',modes:['coop'],bonus:15},
  {id:'bossrush',name:'BOSS RUSH',what:'A boss every other raid. The extra bosses pay 15-30 shards each; raids 5, 10, 15 keep their case.',modes:['coop'],bonus:10},
  {id:'weather',name:'WEATHER',what:'A storm every other raid (every 40 s in PvP). It slows everyone, raiders and Delgado too; players lose 1 health every 2 s in it.',modes:['coop','base','ffa'],bonus:10},
  {id:'nightmare',name:'NIGHTMARE',what:'Always night. Raiders move, spot and fire faster, and any raid without a boss has a 1-in-12 surprise boss (15-30 shards). PvP: night only.',modes:['coop','base','ffa'],bonus:15},
  {id:'berserk',name:'BERSERK',what:'Bosses attack about a third more often. Their warnings are just as long, and they move no faster.',modes:['coop'],bonus:10},
  {id:'glass',name:'GLASS CANNON',what:'Everyone deals 50% more damage and has 30% less health.',modes:['base','ffa'],bonus:0},
  {id:'onejob',name:'ONE JOB',what:'The host picks one job for everyone. No job changes.',modes:['base','ffa'],bonus:0},
  {id:'scrap',name:'SCRAP SHORTAGE',what:'Kills pay half the salvage.',modes:['base'],bonus:0},
  {id:'frenzy',name:'GRENADE FRENZY',what:'A grenade comes back every 6 s, and blasts are a third bigger.',modes:['base','ffa'],bonus:0},
  {id:'sudden',name:'SUDDEN DEATH',what:'The last minute: every drop counts double and nobody gets spawn protection.',modes:['ffa'],bonus:0}];
const MODBY=Object.fromEntries(MODS.map(m=>[m.id,m]));
const modMode=pvp=>pvp==='base'||pvp==='ffa'?pvp:'coop';
// keep only known modifiers that work in this mode, in list order, no repeats
const cleanMods=(list,pvp)=>{const want=new Set(Array.isArray(list)?list:[]),m=modMode(pvp);return MODS.filter(x=>want.has(x.id)&&x.modes.includes(m)).map(x=>x.id)};
const hasMod=id=>!!(game&&game.mods&&game.mods.includes(id));
const modBonus=(list,pvp)=>{let b=0;for(const id of cleanMods(list,pvp))b+=MODBY[id].bonus;return clamp(b,-15,75)};
const modKey=list=>(list&&list.length?list.slice().sort().join('+'):'');
const modNames=list=>(list||[]).map(id=>(MODBY[id]||{name:id}).name);
const MOD_PRESETS={nightmare:['nightmare','berserk','nopatch']};   // a preset the Nightmare game mode will use later

/* ================= skill tree (v0.9.2) ================= */
// One tree for every class. Points come from the server (1 per 5 raids held, 1 per boss); what you unlock is kept
// on your account. Order is fixed: a player's tree travels as one digit per node in this order, so only add at the end.
// In PvP the stat perks count half and the class nodes don't count at all.
const SKILLS=[
  {id:'dmg',br:'WEAPON',name:'HOT LOADS',what:'+4% bullet damage',max:3,cost:[1,2,3]},
  {id:'rate',br:'WEAPON',name:'QUICK HANDS',what:'+4% fire rate',max:3,cost:[1,2,3]},
  {id:'reload',br:'WEAPON',name:'SPEED LOADER',what:'12% faster reloads and grenade cooldown',max:2,cost:[1,2]},
  {id:'range',br:'WEAPON',name:'LONG BARREL',what:'+6% range',max:2,cost:[1,2]},
  {id:'hp',br:'HEALTH',name:'TOUGH HIDE',what:'+6% max health',max:3,cost:[1,2,3]},
  {id:'regen',br:'HEALTH',name:'SECOND WIND',what:'Out of a fight, you start healing sooner and heal faster',max:2,cost:[2,3]},
  {id:'revive',br:'HEALTH',name:'BACK ON YOUR FEET',what:'Revive teammates and get revived 25% faster',max:2,cost:[1,2]},
  {id:'speed',br:'MOVEMENT',name:'LIGHT BOOTS',what:'+3% move speed',max:3,cost:[1,2,3]},
  {id:'vest',br:'MOVEMENT',name:'KEVLAR',what:'4% less damage taken',max:2,cost:[2,3]},
  {id:'haul',br:'MOVEMENT',name:'PACK MULE',what:'Gather 10% faster and carry 8 more of each material',max:2,cost:[1,2]},
  {id:'rockets',br:'SOLDIER',cls:'soldier',name:'BANDOLIER',what:'+1 rocket',max:3,cost:[1,2,3]},
  {id:'pouch',br:'GRENADIER',cls:'grenadier',name:'EXTRA POUCH',what:'+1 grenade',max:2,cost:[2,3]},
  {id:'molotov',br:'GRENADIER',cls:'grenadier',name:'MOLOTOVS',what:'Grenades leave burning ground that hurts raiders. Switch it on or off.',max:1,cost:[3],req:['pouch',1]},
  {id:'ghillie',br:'SNIPER',cls:'sniper',name:'GHILLIE SUIT',what:'+3 s of stealth',max:2,cost:[1,2]},
  {id:'stride',br:'QUARTERMASTER',cls:'quartermaster',name:'LONG STRIDE',what:'+0.6 s of sprint and 1 s less recharge',max:2,cost:[1,2]}];
const SKILLBY=Object.fromEntries(SKILLS.map(s=>[s.id,s]));
const RESPEC_COST=40;   // shards; the server has its own copy (private.respec_cost)
const skillSpent=t=>{let n=0;for(const S of SKILLS)for(let l=0;l<(t[S.id]|0)&&l<S.max;l++)n+=S.cost[l];return n};
// a tree as a string: one digit per node, then 'm' if Molotovs are switched off. Unknown or impossible levels are dropped.
function skillStr(t,molOff){return SKILLS.map(S=>clamp(t&&t[S.id]|0,0,S.max)).join('')+(molOff?'m':'')}
function parseSkills(s){const t={};s=String(s||'');SKILLS.forEach((S,i)=>{const v=+s[i]||0;if(v>0)t[S.id]=Math.min(v,S.max)});
  for(const S of SKILLS)if(S.req&&(t[S.req[0]]|0)<S.req[1])delete t[S.id];
  t.molOff=s.slice(SKILLS.length).includes('m');return t}
// the numbers each node gives (pvp: stat perks at half, class nodes off)
function perkMods(t,pvp){const k=pvp?.5:1,L=id=>(t&&t[id])|0,A=id=>pvp?0:L(id);
  return{dmg:1+.04*L('dmg')*k,rate:1+.04*L('rate')*k,reload:1-.12*L('reload')*k,range:1+.06*L('range')*k,hp:1+.06*L('hp')*k,
    regenAfter:4-.75*L('regen')*k,regen:4+2*L('regen')*k,revive:1+.25*L('revive')*k,speed:1+.03*L('speed')*k,vest:1-.04*L('vest')*k,
    gather:1-.1*L('haul')*k,carry:Math.round(8*L('haul')*k),rockets:A('rockets'),pouch:A('pouch'),molotov:A('molotov')>0&&!t.molOff,ghillie:3*A('ghillie'),stride:A('stride')}}

/* ================= class abilities (v0.9.2, co-op only) ================= */
// soldier: rockets from a stock (5 to start, 2 back each build phase); sniper: stealth, raiders and bosses ignore you.
// p.ab rides the network: rockets left (soldier), or stealth seconds left ×10 (sniper, negative while recharging).
const ABIL={rocket:{stock:5,refill:2,cd:1.5,speed:11,range:12,R:1.9,power:1.5},stealth:{dur:12,cd:30}};
const hasAbility=p=>!!p&&!game.pvp&&(p.cls==='soldier'||p.cls==='sniper');
