/* ================= THE UNDERSTRIP: loot (M2: weapons, perks, relics, chests, elites) ================= */
// Plain tables, from dev/plans/understrip/tables/*.csv (dev/test/understrip_loot.js checks they still match), so balance is a
// one-line change and the Godot port copies them. The second weapon is held for the run and lost at its end; the class gun
// is always the first (infinite ammo). Perks last the run; one relic each. Loot rolls on the host from its own sub-seed.
const US_RAR=['c','r','e','l','g'];
const US_TIER={c:{x:1,mods:0,price:40},r:{x:1.08,mods:1,price:75},e:{x:1.16,mods:2,price:130},l:{x:1.25,mods:2,price:220,sig:true},g:{x:1.35,mods:3,price:380,sig:true}};
// gun: the game's own gun fields (01-setup CLASSES). magReload: a full reload's seconds (loaded a round at a time, as the
// Grenadier's tube is). reserve: rounds carried beyond the magazine (shrines refill it). fx: the weapon's own trick (usWeaponHit)
const US_WEAPONS={
  w_sawnoff:{region:1,name:'SAWN-OFF',gun:{dmg:10,pellets:9,cd:.22,spread:.34,range:4.2,speed:22,mag:2,snd:'shotgun',fall:[2,4.2,.5]},magReload:1.5,reserve:24,fx:'',sig:'BOTH BARRELS: 18 pellets a shot'},
  w_taser:{region:1,name:'SECURITY TASER',gun:{dmg:18,cd:.55,spread:.03,range:4,speed:30,mag:8,snd:'zap'},magReload:1.8,reserve:40,fx:'stun',sig:'ARC: jumps to three more'},
  w_nailgun:{region:1,name:'NAIL GUN',gun:{dmg:11,cd:.11,spread:.07,range:8,speed:18,pierce:1,mag:30,snd:'smg'},magReload:2.2,reserve:150,fx:'pin',sig:'RIVETS: every 5th nail deals triple'},
  w_smg:{region:2,name:'SHELTER SMG',gun:{dmg:8,cd:.075,spread:.14,range:9,speed:23,mag:32,snd:'smg'},magReload:2,reserve:192,fx:'',sig:'DRUM MAG: 64 rounds'},
  w_flare:{region:2,name:'FLARE LAUNCHER',gun:{dmg:15,cd:1.4,spread:.02,range:12,speed:12,mag:1,snd:'rocket'},magReload:1.4,reserve:8,fx:'flare',sig:'STARBURST: three flares in a fan'},
  w_riot:{region:2,name:'RIOT SHOTGUN',gun:{dmg:10,pellets:7,cd:.65,spread:.2,range:6,speed:24,mag:6,snd:'shotgun'},magReload:2.4,reserve:48,fx:'knock',sig:'SLUG: one 70-damage slug that pierces 3'},
  w_laser:{region:3,name:'LAB LASER',gun:{dmg:14,cd:.28,spread:0,range:12,speed:60,mag:10,snd:'zap'},magReload:2,reserve:120,fx:'bounce',sig:'PRISM: splits into three on the first bounce'},
  w_alien:{region:3,name:'ALIEN PISTOL',gun:{dmg:12,cd:.1,spread:.02,range:12,speed:30,mag:6,snd:'sniper'},magReload:1.8,reserve:60,fx:'charge',sig:'OVERCHARGE: full charge in 0.7 s'},
  w_antigrav:{region:3,name:'ANTI-GRAV LAUNCHER',gun:{dmg:22,cd:1.6,spread:.05,range:9,speed:10,mag:4,snd:'rocket'},magReload:2.5,reserve:16,fx:'lift',sig:'WELL: pulls raiders in first'}};
const US_WEAPON_IDS=Object.keys(US_WEAPONS);
const US_MODS={m_dmg:{name:'HOT',what:'+15% damage',min:'r',w:10},m_rate:{name:'QUICK',what:'+12% fire rate',min:'r',w:10},m_mag:{name:'DEEP',what:'+40% magazine',min:'r',w:8},
  m_reload:{name:'SLICK',what:'-25% reload time',min:'r',w:8},m_range:{name:'LONG',what:'+20% range and bullet speed',min:'r',w:7},m_steady:{name:'TRUE',what:'-30% spread',min:'r',w:7},
  m_ammo:{name:'STOCKED',what:'+50% reserve',min:'r',w:6},m_pierce:{name:'PIERCING',what:'+1 pierce',min:'e',w:5},m_crit:{name:'LUCKY',what:'8% chance a hit deals double',min:'e',w:5},
  m_light:{name:'BRIGHT',what:'+30% light cone while held',min:'e',w:4},m_vamp:{name:'THIRSTY',what:'heals 2% of damage dealt (5 HP/s at most)',min:'l',w:2}};
const US_MOD_IDS=Object.keys(US_MODS);
const US_PERKS={
  p_loaded:{name:'LOADED DICE',r:'r',what:'10% chance a shot deals double damage'},p_house:{name:'HOUSE EDGE',r:'e',what:'+1 Lucky Juice capacity (max 6)'},
  p_owl:{name:'NIGHT OWL',r:'c',what:'Your light cone reaches 40% further'},p_break:{name:'LUCKY BREAK',r:'l',what:'The first time you\'re downed each level, you stand back up at 20%'},
  p_comped:{name:'COMP\'D ROOM',r:'c',what:'Your next trade is 25% off'},p_steady:{name:'STEADY HANDS',r:'c',what:'25% tighter spread'},
  p_sip:{name:'QUICK SIP',r:'r',what:'Drinking takes 0.5 s'},p_gulp:{name:'BIG GULP',r:'r',what:'Each charge heals 25% more'},
  p_pocket:{name:'PICKPOCKET',r:'c',what:'+1 salvage a kill'},p_insure:{name:'INSURANCE',r:'e',what:'Only half your salvage drops when you fall'},
  p_sleeper:{name:'LIGHT SLEEPER',r:'r',what:'Unseen raiders within 8 tiles show at the screen\'s edge'},p_lung:{name:'IRON LUNG',r:'r',what:'Gas and radiation hurt half as much',from:2},
  p_footing:{name:'SURE FOOTING',r:'c',what:'Water and debris slow you half as much'},p_backstep:{name:'BACK STEP',r:'e',what:'The roll comes back 0.5 s sooner'},
  p_riposte:{name:'RIPOSTE',r:'l',what:'Roll through a shot: +30% damage for 2 s'},p_pockets:{name:'DEEP POCKETS',r:'r',what:'+50% reserve for the second weapon'},
  p_stack:{name:'BIG STACK',r:'e',what:'+20% damage while you carry 150+ salvage'},p_lastcall:{name:'LAST CALL',r:'e',what:'+20% fire rate below 30% health'},
  p_counter:{name:'CARD COUNTER',r:'r',what:'Chests and merchants show at the screen\'s edge'},p_pitcrew:{name:'PIT CREW',r:'r',what:'You revive teammates 40% faster'}};
const US_PERK_IDS=Object.keys(US_PERKS);
const US_RELICS={x_chip:{name:'CURSED CHIP',r:'l',up:'+30% damage',down:'Lucky Juice heals half'},x_crown:{name:'PAPER CROWN',r:'l',up:'+25% fire rate',down:'-25% max health'},
  x_lens:{name:'BLACKOUT LENS',r:'l',up:'Raiders in your light cone take +25% damage',down:'Your light cone is 40% shorter'},
  x_hand:{name:'DEAD MAN\'S HAND',r:'l',up:'Downed, you blow up (60 damage, radius 2)',down:'You heal 30% less'},
  x_deck:{name:'MARKED DECK',r:'l',up:'Merchants show 2 more items',down:'Prices +25%'},x_lead:{name:'LEAD BOOTS',r:'l',up:'Knockback and pulls don\'t move you',down:'-15% move speed',from:3},
  x_eye:{name:'THE VISITOR\'S EYE',r:'g',up:'See raiders through walls within 6 tiles',down:'Your light cone is 30% shorter',from:3}};
const US_RELIC_IDS=Object.keys(US_RELICS);
// where loot comes from: [what, weight] and rarity weights by region (tables/loot_sources.csv)
const US_LOOT={chest:{what:[['consumable',45],['salvage',25],['weapon',20],['perk',10]],rar:{1:{c:55,r:30,e:12,l:3},2:{c:40,r:35,e:18,l:7},3:{c:25,r:35,e:27,l:13}}},
  elite:{what:[['consumable',50],['weapon',30],['perk',20]],rar:{1:{r:65,e:30,l:5},2:{r:50,e:38,l:12},3:{r:35,e:45,l:20}},bounty:20},
  boss:{what:[['weapon',50],['perk',35],['relic',15]],rar:{1:{r:60,e:32,l:8},2:{r:40,e:42,l:18},3:{r:20,e:45,l:35}}}};
const US_ELITE={hp:2.5,charger:{tell:.8,w:1,speed:6,dmg:24,knock:1.2,cd:5},caller:{lock:1.5,tell:1.2,r:1.5,dmg:26,cd:7}};
const usWeighted2=(r,obj)=>{const ks=Object.keys(obj);return usWeighted(r,ks,k=>obj[k])};
// a weapon as it drops: {id, r, mods:[...]} (legendary and gold also carry the signature)
function usRollWeapon(r,region,rar){const pool=US_WEAPON_IDS.filter(k=>US_WEAPONS[k].region<=region),id=usPick(r,pool.filter(k=>US_WEAPONS[k].region===region).concat(pool)),T=US_TIER[rar],mods=[];
  const ok=US_MOD_IDS.filter(m=>US_RAR.indexOf(US_MODS[m].min)<=US_RAR.indexOf(rar));
  for(let k=0;k<T.mods;k++){const left=ok.filter(m=>!mods.includes(m));if(!left.length)break;mods.push(usWeighted(r,left,m=>US_MODS[m].w))}
  return{id,r:rar,mods}}
// the gun a held weapon fires (from refit, with the armory upgrades and the skill tree on top, as the class gun)
function usWeaponGun(w,p){const W=US_WEAPONS[w.id],T=US_TIER[w.r]||US_TIER.c,m=k=>w.mods.includes(k),G=Object.assign({},W.gun);
  G.dmg*=T.x*(m('m_dmg')?1.15:1);if(m('m_rate'))G.cd/=1.12;if(m('m_mag'))G.mag=Math.round(G.mag*1.4);if(m('m_range')){G.range*=1.2;G.speed*=1.2}if(m('m_steady'))G.spread*=.7;if(m('m_pierce'))G.pierce=(G.pierce||0)+1;
  if(T.sig){if(w.id==='w_sawnoff')G.pellets=18;if(w.id==='w_smg')G.mag=64;if(w.id==='w_riot'){G.pellets=1;G.dmg=70*T.x;G.pierce=3;G.spread=.02}
    if(w.id==='w_flare'){G.pellets=3;G.spread=.5}if(w.id==='w_laser')G.prism=true;if(w.id==='w_taser')G.arc=3;if(w.id==='w_nailgun')G.rivets=true;if(w.id==='w_antigrav')G.well=true;if(w.id==='w_alien')G.chargeT=.7}
  if(W.fx==='charge'){G.chargeT=G.chargeT||1.2;G.chargeDmg=64*T.x*(m('m_dmg')?1.15:1)}
  G.reload=W.magReload*(m('m_reload')?.75:1)/G.mag;G.bolt=G.cd>=.5;G.us=w.id;G.usFx=W.fx;G.crit=m('m_crit')?.08:0;G.vamp=m('m_vamp');return G}
const usReserveMax=(w,p)=>Math.round(US_WEAPONS[w.id].reserve*(w.mods.includes('m_ammo')?1.5:1)*(usHas(p,'p_pockets')?1.5:1));
const usHas=(p,k)=>!!(p&&p.uPerks&&p.uPerks.includes(k));
const usRelic=(p,k)=>!!p&&p.uRelic===k;
// a pickup's label: name, rarity colour, one line (shown before you take it: work order 7.3)
function usLootLabel(l){if(l.kind==='weapon'){const W=US_WEAPONS[l.w.id],T=US_TIER[l.w.r];return{name:W.name,col:RAR[l.w.r].col,line:[RAR[l.w.r].n,...l.w.mods.map(m=>US_MODS[m].name),T.sig?W.sig:''].filter(Boolean).join(' · ')}}
  if(l.kind==='perk'){const P=US_PERKS[l.k]||US_SIG_PERKS[l.k];if(!P)return{name:'?',col:'#9a958a',line:''};return{name:P.name,col:RAR[P.r].col,line:P.what}}
  if(l.kind==='relic'){const R=US_RELICS[l.k];return{name:R.name,col:RAR[R.r].col,line:`${R.up} · ${R.down}`}}
  if(l.kind==='consumable'){const I=US_ITEMS[l.k];return{name:I.name,col:'#c8c3b8',line:I.what}}
  return{name:`${l.sal} SALVAGE`,col:'#e2b436',line:''}}
// one roll from a source (chest, elite, boss) in a region
function usRollLoot(r,src,region,nothing){const S=US_LOOT[src],what=usWeighted(r,S.what,x=>x[1])[0],rar=usWeighted2(r,S.rar[region]||S.rar[1]);
  if(what==='salvage')return{kind:'salvage',sal:15+Math.floor(r()*16)};
  if(what==='consumable')return{kind:'consumable',k:usPick(r,['c_nade','c_flare','c_bar','c_juice'])};
  if(what==='weapon')return{kind:'weapon',w:usRollWeapon(r,region,rar)};
  if(what==='perk'){const pool=US_PERK_IDS.filter(k=>!(US_PERKS[k].from>region)&&!(nothing||[]).includes(k)),near=pool.filter(k=>US_PERKS[k].r===rar);return{kind:'perk',k:usPick(r,near.length?near:pool)}}
  const pool=US_RELIC_IDS.filter(k=>!(US_RELICS[k].from>region));return{kind:'relic',k:usPick(r,pool)}}

// ---------- the second weapon ----------
// p.w2: {id, r, mods, ammo (in the magazine), res (reserve)} or null. p.wSel: 0 the class gun, 1 the second weapon.
// refit (04) builds p.gun from whichever is in hand; the magazine and reserve live on p.w2 while it's put away.
function usGiveWeapon(p,w){if(!p)return;const old=p.w2;const G=usWeaponGun(w,p);p.w2={id:w.id,r:w.r,mods:w.mods.slice(),ammo:G.mag,res:usReserveMax(w,p)};p.wSel=1;usRefit(p);return old}
function usSwap(p,to){if(!p||!p.alive||!p.w2)return false;const t=to===undefined?(p.wSel?0:1):to;if(t===p.wSel)return false;
  if(p.wSel===1)p.w2.ammo=p.ammo;p.wSel=t;usRefit(p);p.cd=Math.max(p.cd,.25);p.rl=0;sfx('rack',p.x,p.y);return true}
// the gun in hand: the class gun, or the second weapon (with the armory's upgrades and the skill tree, as refit does)
function usRefit(p){refit(p);if(p.wSel===1&&p.w2){const U=p.up,K=p.perk||PERK0,B=usWeaponGun(p.w2,p);
    p.gun=Object.assign({},B,{dmg:B.dmg*(1+armBoost(U.d,.2,.05))*K.dmg,cd:B.cd*(1-armBoost(U.r,.1,.025))/K.rate,range:B.range*(1+armBoost(U.g,.12,.03))*K.range,speed:B.speed*(1+armBoost(U.g,.1,.025)),reload:B.reload*K.reload});
    p.ammo=clamp(p.w2.ammo|0,0,p.gun.mag)}
  else{p.ammo=p.gun.mag?Math.min(p.ammo>=0?p.ammo:p.gun.mag,p.gun.mag):p.ammo}
  usRunMods(p)}
// perks and relics that change the gun or the body (refit runs this last)
function usRunMods(p){if(!understrip())return;const G=p.gun;
  if(usHas(p,'p_steady'))G.spread*=.75;if(usRelic(p,'x_chip'))G.dmg*=1.3;if(usRelic(p,'x_crown')){G.cd/=1.25;const mx=Math.round(p.max*.75);p.hp=Math.min(p.hp,mx);p.max=mx}
  if(usHas(p,'p_house'))p.ujm=Math.min(US.juiceMax,US.juice+1);}
// a reload step for the second weapon takes from the reserve (simPlayer's tube reload); false: nothing left
function usReloadStep(p){if(!understrip()||p.wSel!==1||!p.w2)return true;if(p.w2.res<=0)return false;p.w2.res--;return true}
// shots: perks that change one shot (Loaded Dice, Big Stack, Last Call, Riposte)
function usShotMul(p){let m=1;if(p.gun.rivets&&(p.rivet=((p.rivet|0)+1)%5)===0)m*=3;   // RIVETS: every 5th nail
  if(usHas(p,'p_loaded')&&rnd()<.1)m*=2;if(usHas(p,'p_stack')&&p.sal>=150)m*=1.2;if(p.ripT>0)m*=1.3;if(p.gun.crit&&rnd()<p.gun.crit)m*=2;return m}
const usRateMul=p=>usHas(p,'p_lastcall')&&p.hp<p.max*.3?1.2:1;
// a bullet from a tunnel weapon hits a raider: the weapon's trick
function usBulletHit(e,b){if(e.dead)return;const P=b.own&&players.get(b.own);
  if(b.usFx==='stun'){if(e.type==='boss'){e.slowT=Math.max(e.slowT||0,1);e.slowPct=.4}else{e.stunT=e.elite?.25:.5;e.cd=Math.max(e.cd,e.stunT)}
    let from=e;const hit=new Set([e]);for(let k=0;k<Math.max(1,b.arc|0);k++){const n=enemies.find(o=>!hit.has(o)&&!o.dead&&Math.hypot(o.x-from.x,o.y-from.y)<2);if(!n)break;hit.add(n);hurtEnemy(n,b.dmg*.5,b.own);usZapFx(from.x,from.y,n.x,n.y);n.stunT=Math.max(n.stunT||0,.3);from=n}}
  else if(b.usFx==='pin'){e.stunT=Math.max(e.stunT||0,.2)}
  else if(b.usFx==='knock'&&e.type!=='boss'){knock(e,e.x-b.vx,e.y-b.vy,.4)}
  else if(b.usFx==='flare'){e.burnT=Math.max(e.burnT||0,4);e.burnOwn=b.own;game.us.flares.push({x:e.x,y:e.y,t:10,r:5})}
  else if(b.usFx==='lift'){if(b.well)for(const o of enemies)if(o!==e&&!o.dead&&o.type!=='boss'&&Math.hypot(o.x-e.x,o.y-e.y)<2.5){knock(o,o.x+(o.x-e.x),o.y+(o.y-e.y),.8);o.stunT=Math.max(o.stunT||0,1)}
    for(const o of enemies)if(!o.dead&&Math.hypot(o.x-e.x,o.y-e.y)<1.6){if(o!==e)hurtEnemy(o,b.dmg*.6,b.own);if(o.type==='boss'){o.slowT=Math.max(o.slowT||0,.5);o.slowPct=.6}else{o.stunT=2;o.lifted=2}}}
  if(P&&b.vamp)P.hp=Math.min(P.max,P.hp+Math.min(5/30,b.dmg*.02))
  // the Blackout Lens: +25% on raiders inside your (shorter) light cone
  if(P&&usRelic(P,'x_lens')&&!e.dead){const dx=e.x-P.x,dy=e.y-P.y,d=Math.hypot(dx,dy)||1;if(d<5.4*usConeMul(P)+.5&&(dx*P.aim.x+dy*P.aim.y)/d>.82)hurtEnemy(e,b.dmg*.25,b.own,true)}}
const usZapFx=(x0,y0,x1,y1)=>{if(typeof chains!=='undefined')chains.push({x0,y0,x1,y1,life:.18,max:.18})};

// ---------- loot on the floor (chests, elites, bosses): shown before it's taken (E takes it) ----------
// game.us.loot: [{n, x, y, kind, ...}]
function usDropLoot(x,y,l){const U=game.us;U.lootN=(U.lootN|0)+1;U.loot.push({n:U.lootN,x,y,...l});sfx('restock',x,y)}
const usLootAt=p=>game.us&&game.us.loot?game.us.loot.find(l=>Math.hypot(l.x-p.x,l.y-p.y)<1):null;
function usTakeLoot(p,n){const U=game.us,i=U.loot.findIndex(l=>l.n===n);if(i<0||!p.alive)return false;const l=U.loot[i];if(Math.hypot(l.x-p.x,l.y-p.y)>1.2)return false;
  if(!usApplyLoot(p,l,()=>U.loot.splice(i,1)))return false;U.stats.found=(U.stats.found|0)+1;return true}
// a pickup (or a purchase) into the player's kit: what it replaces goes on the floor. gone(): take it off the floor first
function usCanApply(p,l){if(l.kind==='perk')return!usHas(p,l.k);if(l.kind!=='consumable')return true;const I=US_ITEMS[l.k];
  return l.k==='c_nade'?p.nades<p.maxN:l.k==='c_juice'?p.uj<p.ujm:(p.ui[l.k==='c_bar'?'bar':'flare']|0)<I.max}
function usApplyLoot(p,l,gone){if(!usCanApply(p,l))return false;if(gone)gone();
  if(l.kind==='weapon'){const old=usGiveWeapon(p,l.w);if(old)usDropLoot(p.x+.3,p.y+.3,{kind:'weapon',w:{id:old.id,r:old.r,mods:old.mods}})}
  else if(l.kind==='perk'){p.uPerks=(p.uPerks||[]).concat([l.k]);usRefit(p)}
  else if(l.kind==='relic'){const old=p.uRelic;p.uRelic=l.k;if(old&&old!==l.k)usDropLoot(p.x+.3,p.y+.3,{kind:'relic',k:old});usRefit(p)}
  else if(l.kind==='consumable'){if(l.k==='c_nade')p.nades++;else if(l.k==='c_juice')p.uj++;else p.ui[l.k==='c_bar'?'bar':'flare']++}
  else p.sal+=l.sal;
  const lb=usLootLabel(l);toastTo(p,lb.name,lb.line);personal(p,'restock');return true}

// ---------- elites: one a room cluster, a name tag, x2.5 health and a trick ----------
function usMakeElite(e,r){const kind=e.type==='spotter'?'caller':'charger';if(kind==='charger'&&e.type!=='shield')return;e.elite=kind;e.hp=e.max=e.max*US_ELITE.hp;e.eab=2+r()*2}
// the trick (updateEnemies, a hunting elite): the charger runs a lane at you; the caller lasers you and a mortar lands there
function usEliteTick(e,dt){if(!e.elite||e.dead||!e.us||e.us.st!=='hunt')return false;e.eab-=dt;const f=e.foe,E=US_ELITE;
  if(e.elite==='charger'){
    if(e.est===1){e.estT-=dt;e.aim={x:Math.cos(e.ea),y:Math.sin(e.ea)};if(e.estT<=0){e.est=2;e.estT=6/E.charger.speed;e.hitSet=new Set();sfx('charge',e.x,e.y)}return true}
    if(e.est===2){e.estT-=dt;const s=E.charger.speed*dt,nx=e.x+Math.cos(e.ea)*s,ny=e.y+Math.sin(e.ea)*s;if(e.estT<=0||terrSolid(terr[idx(nx|0,ny|0)])||walls[idx(nx|0,ny|0)]){e.est=0;e.eab=E.charger.cd;return true}
      e.x=nx;e.y=ny;for(const a of allies())if(a.alive&&!e.hitSet.has(a)&&Math.hypot(a.x-e.x,a.y-e.y)<.6){e.hitSet.add(a);hurtAlly(a,E.charger.dmg*game.Df.dmg);knock(a,e.x,e.y,E.charger.knock)}return true}
    if(f&&e.eab<=0&&Math.hypot(f.x-e.x,f.y-e.y)<7){e.est=1;e.estT=E.charger.tell;e.ea=Math.atan2(f.y-e.y,f.x-e.x);e.lx=e.x+Math.cos(e.ea)*6;e.ly=e.y+Math.sin(e.ea)*6;sfx('lock',e.x,e.y);return true}}
  else{
    if(e.est===1){e.estT-=dt;if(f){e.lx=f.x;e.ly=f.y}if(e.estT<=0){e.est=2;e.estT=E.caller.tell;sfx('lock',e.lx,e.ly)}return true}
    if(e.est===2){e.estT-=dt;if(e.estT<=0){e.est=0;e.eab=E.caller.cd;explode(e.lx,e.ly,E.caller.r,.9*game.Df.dmg,null,true)}return false}
    if(f&&e.eab<=0){e.est=1;e.estT=E.caller.lock;e.lx=f.x;e.ly=f.y;return false}}
  return false}

// ---------- how loot looks (15b's usItems queues it) ----------
function usDrawLoot(l){const c=iso(l.x,l.y),lb=usLootLabel(l),b=Math.sin(game.time*3+l.n)*2*u;
  g.fillStyle='rgba(0,0,0,.35)';g.beginPath();g.ellipse(c[0],c[1],8*u,3.5*u,0,0,Math.PI*2);g.fill();
  g.strokeStyle=lb.col;g.lineWidth=1.6*u;g.beginPath();g.ellipse(c[0],c[1],10*u+b*.5,4.5*u+b*.2,0,0,Math.PI*2);g.stroke();
  g.fillStyle=lb.col;if(l.kind==='weapon'){g.fillRect(c[0]-7*u,c[1]-7*u+b,14*u,4*u);g.fillRect(c[0]-7*u,c[1]-4*u+b,4*u,5*u)}
  else if(l.kind==='perk'){g.beginPath();g.arc(c[0],c[1]-6*u+b,4*u,0,Math.PI*2);g.fill()}
  else if(l.kind==='relic'){g.beginPath();g.moveTo(c[0],c[1]-11*u+b);g.lineTo(c[0]+5*u,c[1]-6*u+b);g.lineTo(c[0],c[1]-1*u+b);g.lineTo(c[0]-5*u,c[1]-6*u+b);g.closePath();g.fill()}
  else g.fillRect(c[0]-4*u,c[1]-8*u+b,8*u,6*u)}
// the label over loot you're standing at, and the E to take it
function usLootPrompt(p){const l=usLootAt(p);if(!l)return false;const c=iso(l.x,l.y),lb=usLootLabel(l);
  // under the figure (the loot is at your feet; your health is over your head)
  label(lb.name,c[0],c[1]+16*u,lb.col,12);if(lb.line)label(lb.line,c[0],c[1]+29*u,'#c8c3b8',9);
  label(ctl('TAP ARMORY · TAKE','E · TAKE',`${padKey('armory')} · TAKE`),c[0],c[1]+42*u,'#e8e2d0',10);return true}
// the kit's weapon button: the gun in hand, its magazine and reserve
function usWeaponHud(p){const b=$('usWpn');if(!b)return;hid(b,!p.w2);if(!p.w2)return;const W=US_WEAPONS[p.w2.id];
  txt($('usWpnLab'),p.wSel===1?W.name:CLASSES[p.cls].name.slice(0,4)+' GUN');txt($('usWpnN'),p.wSel===1?`${p.ammo|0}/${p.w2.res|0}`:'∞');
  b.style.borderColor=RAR[p.w2.r].col}

// ---------- the kit as the network carries it (PL_INFO usk): weapon, hand, perks, relic ----------
const usKitStr=p=>`${p.w2?p.w2.id+'.'+p.w2.r+'.'+p.w2.mods.join('+'):''}|${p.wSel|0}|${(p.uPerks||[]).join('+')}|${p.uRelic||''}`;
function usKitFrom(p,s){if(typeof s!=='string'||s===p.uKitS)return;p.uKitS=s;const[w,sel,perks,relic]=s.split('|');
  if(w){const[id,r,mods]=w.split('.');if(US_WEAPONS[id]&&US_TIER[r]){const ms=(mods||'').split('+').filter(m=>US_MODS[m]);if(!p.w2||p.w2.id!==id||p.w2.r!==r)p.w2={id,r,mods:ms,ammo:0,res:0};else p.w2.mods=ms}}else p.w2=null;
  p.wSel=sel==='1'&&p.w2?1:0;p.uPerks=(perks||'').split('+').filter(k=>US_PERKS[k]||US_SIG_PERKS[k]);p.uRelic=US_RELICS[relic]?relic:'';usRefit(p)}
// a boss's own drop (work order 8.2): the Pit Boss's tie-pin
const US_SIG_PERKS={p_tiepin:{name:'THE PIT BOSS\'S TIE-PIN',r:'l',what:'+1 salvage a kill (on top of Pickpocket)'}};
// the bosses' own drops (work order 8.2-8.5): the tie-pin, an epic flare launcher, a legendary anti-grav launcher, the Visitor's
// Eye (the Visitor's skin comes from the case, 9.2)
const US_SIG={pitboss:{kind:'perk',k:'p_tiepin'},custodian:{kind:'weapon',w:{id:'w_flare',r:'e',mods:['m_dmg','m_reload']}},
  gatekeeper:{kind:'weapon',w:{id:'w_antigrav',r:'l',mods:['m_dmg','m_mag']}},visitor:{kind:'relic',k:'x_eye'}};
const US_PERKS_ALL=Object.assign({},US_PERKS,US_SIG_PERKS);
const usBountyPlus=(p,e)=>(usHas(p,'p_pocket')?1:0)+(usHas(p,'p_tiepin')?1:0);
const usMoveMul=(p,s)=>(usHas(p,'p_footing')?1-(1-s)/2:s)*(usRelic(p,'x_lead')?.85:1);
const usConeMul=p=>(usHas(p,'p_owl')?1.4:1)*(usRelic(p,'x_lens')?.6:1)*(usRelic(p,'x_eye')?.7:1)*(p.wSel===1&&p.w2&&p.w2.mods.includes('m_light')?1.3:1);
const usHealMulK=p=>(usHas(p,'p_gulp')?1.25:1)*(usRelic(p,'x_chip')?.5:1)*(usRelic(p,'x_hand')?.7:1);
// a tunnel raider down (hurtEnemy): elites stay down past a rest and drop loot
function usEnemyDied(e,own){const U=game.us;if(!U||NET.mode==='guest')return;
  if(e.elite){U.eliteDown=U.eliteDown||[];U.eliteDown.push(e.us.sid);const r=usRng(usHash(U.seed,U.level,4000+e.us.sid));usDropLoot(e.x,e.y,usRollLoot(r,'elite',US_PLAN[U.level][0]));
    const p=own&&players.get(own);if(p){p.sal+=US_LOOT.elite.bounty;flt(e.x,e.y-.4,`+${US_LOOT.elite.bounty} ELITE`,'#e2b436')}}}
// a boss down: one rare-or-better drop for each of you, and the boss's own (the first time each of you beats him this run)
function usBossLoot(x,y,key){const U=game.us;let n=0;for(const p of players.values()){const r=usRng(usHash(U.seed,U.level,7000+n));usDropLoot(x+(n%3-1)*.8,y+Math.floor(n/3)*.8,{...usRollLoot(r,'boss',US_PLAN[U.level][0]),for:p.id});n++}
  const S=US_SIG[key];if(S)usDropLoot(x,y+1.2,JSON.parse(JSON.stringify(S)))}
// edge markers: Light Sleeper (unseen raiders within 8), Card Counter (chests, merchants), the Visitor's Eye (raiders within 6, through walls)
function usPips(p){if(!p||!p.alive)return;const pip=(x,y,col,far)=>{const c=iso(x,y);const on=c[0]>14&&c[0]<W-14&&c[1]>110&&c[1]<H-14;
    if(on){if(!far){g.strokeStyle=col;g.lineWidth=1.5*u;g.beginPath();g.ellipse(c[0],c[1]-WH*.5,TW2*.5,TH2*.5,0,0,Math.PI*2);g.stroke()}return}
    const ex=clamp(c[0],18,W-18),ey=clamp(c[1],118,H-18);g.fillStyle=col;g.beginPath();g.arc(ex,ey,4,0,Math.PI*2);g.fill()};
  if(usHas(p,'p_sleeper'))for(const e of enemies)if(e.us&&e.us.st!=='hunt'&&!e.dead&&Math.hypot(e.x-p.x,e.y-p.y)<8)pip(e.x,e.y,'rgba(255,90,74,.7)',true);
  if(usRelic(p,'x_eye'))for(const e of enemies)if(!e.dead&&Math.hypot(e.x-p.x,e.y-p.y)<6)pip(e.x,e.y,'rgba(184,168,255,.85)',false);
  if(usHas(p,'p_counter')){const L=game.lay,U=game.us;L.chests.forEach((c,n)=>{if(!(U.chests&(1<<n)))pip(c.x,c.y,'#c88a3a',true)});for(const m of L.merchants)pip(m.x,m.y,'#c78bff',true)}}

// elites' tags and their tricks' warnings (every phone draws them from el, est, lx, ly)
function usEliteFx(){for(const e of enemies){if(!e.elite||e.dead)continue;const c=iso(e.x,e.y);label(e.elite==='charger'?'ELITE · CHARGER':'ELITE · CALLER',c[0],c[1]-WH*2.05,'#ffb13a',9);
  const pulse=.55+.45*Math.sin(game.time*22);
  if(e.elite==='charger'&&e.est===1){const dx=e.lx-e.x,dy=e.ly-e.y,l=Math.hypot(dx,dy)||1,nx=-dy/l*.5,ny=dx/l*.5,Q=[[e.x+nx,e.y+ny],[e.lx+nx,e.ly+ny],[e.lx-nx,e.ly-ny],[e.x-nx,e.y-ny]].map(q=>iso(q[0],q[1]));
    g.fillStyle=`rgba(255,60,40,${.14+.2*pulse})`;g.beginPath();Q.forEach((q,i)=>i?g.lineTo(q[0],q[1]):g.moveTo(q[0],q[1]));g.closePath();g.fill()}
  if(e.elite==='caller'&&e.est){const a=iso(e.x,e.y),b=iso(e.lx,e.ly);g.strokeStyle=`rgba(255,60,50,${e.est===2?.8:.35+.3*pulse})`;g.lineWidth=u;if(e.est===1){g.beginPath();g.moveTo(a[0],a[1]-WH*.55);g.lineTo(b[0],b[1]-WH*.55);g.stroke()}
    else{g.lineWidth=2*u;g.setLineDash([5*u,4*u]);g.beginPath();g.ellipse(b[0],b[1],TW2*US_ELITE.caller.r,TH2*US_ELITE.caller.r,0,0,Math.PI*2);g.stroke();g.setLineDash([])}}}}

// the lab laser off a wall: step back out, flip the side it crossed; PRISM splits it in three the first time
function usBounce(b,step){const px=b.x-b.vx*step,py=b.y-b.vy*step,ci=Math.floor(b.x)!==Math.floor(px),cj=Math.floor(b.y)!==Math.floor(py);
  b.x=px;b.y=py;if(ci||!cj)b.vx=-b.vx;if(cj)b.vy=-b.vy;b.bnc=(b.bnc|0)+1;b.last=-1;hitFx(b.x,b.y,2);
  if(b.prism&&b.bnc===1){const a=Math.atan2(b.vy,b.vx),sp=Math.hypot(b.vx,b.vy);for(const o of[-.35,.35])bullets.push({...b,id:++bulletSeq,vx:Math.cos(a+o)*sp,vy:Math.sin(a+o)*sp,prism:false})}
  return true}
// the alien pistol charges while the trigger is held and fires on release (12 to 64 damage; a full charge pierces 3).
// usTick runs it before the normal trigger (it takes the trigger for itself); a guest's trigger counts as held while its
// inputs keep saying so (they come about 20 times a second)
function usChargeTick(p,dt){const G=p.gun;if(!G||!G.chargeT||!p.alive)return;
  if(p.fireIn){p.chgSeen=game.time;p.chg=Math.min(G.chargeT,(p.chg||0)+dt);p.fireIn=false;return}
  if(p.chg>0&&game.time-(p.chgSeen||0)>(p===player?0:.12)){if(p.ammo>0&&p.cd<=0&&!(p.dgE>=0)){const f=p.chg/G.chargeT,full=f>=.999;
      shoot(p,Object.assign({},G,{dmg:G.dmg+(G.chargeDmg-G.dmg)*f,pierce:full?3:0,speed:G.speed*(full?1.4:1)}),0);p.ammo--;p.cd=G.cd;sfx(full?'sniper':'zap',p.x,p.y);p.sinceShot=0;p.rl=0}
    p.chg=0}}
