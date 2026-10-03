/* v0.9.6.5 the INDEX page (was CLASSES): classes, raiders and bosses. Health, speed, first raid and weakness are read from
   the game's own tables (ETYPES, BOSSES, BOSS_HP, BOSS_WEAK), so the page can't drift from the game; only the descriptions
   are written here. Portraits use the same painter as the wardrobe and are drawn once, when a tab is first opened. */
const IDX_RAIDERS=[   // [type, first raid, what he does]
  ['rifle',1,'The backbone of every raid. Walks the path and shoots whoever is closest.'],
  ['gren',2,'Lobs grenades over your walls at you and your defenses.'],
  ['fire',2,'Throws fire bottles at wooden walls, or at people close by. The glass bursts into burning ground and sets wood alight.'],
  ['breach',3,'Runs a satchel charge up to a wall and blows it open.'],
  ['shield',3,'Turns a riot shield toward whoever is shooting. Rounds from the front spark off: flank him, or use Armor Piercing or explosives.'],
  ['medic',4,'Hangs back behind other raiders and patches up everyone near him every 1.6 s. Take him out first.'],
  ['spotter',6,'Sits back 6 to 9 tiles and marks a soldier with a red laser. Riflemen aim far better at whoever is marked.']];
const IDX_BOSSES=[   // [group, [[key, where, attacks, phase]]]
  ['STANDARD RAIDS',[
    ['demolisher',null,['Rocket: a red line shows where it goes. Step out of it.','Rocket fan: every third volley is three rockets in a spread.'],''],
    ['butcher',null,['Blade: a red wedge up close, then a cut.','Charge: a red lane, then he runs it down, knocking people aside and smashing wood.'],'Below 40%: enraged, faster, cuts sooner.'],
    ['storm',null,['Chain lightning: a blue line tracks you, then locks. The bolt stuns and jumps to two more people.','Thunderstrike: three blue rings around you, then lightning drops into each one.','Static Pulse: get within 4 tiles and he crackles, then blasts everyone back.'],'Below 50%: fires his bolt twice.'],
    ['ferryman',null,['Harpoon: a chain line. Whoever it hits, or a wall, is dragged toward the water.','Boarding crews: lands two or three raiders on the bank.','Bridge ram: smashes a bridge into the river.'],'After a bridge falls: harpoons faster.'],
    ['foreman',null,['Rock slab: a ring shows where it lands. It stays as a stone block.','Burrow: drills underground where bullets can\'t reach, then bursts up through the wall above.','Rockfall: a marked lane of falling rock.'],'Rockfall only below 50%.']]],
  ['BLITZKRIEG RUSH',[
    ['harbinger','Blitzkrieg Rush',['Missile barrage: three arcing missiles, each with a red landing ring. Keep moving.','Boarding crews: lands raiders on the bank.'],'Below 50%: four missiles at a time.'],
    ['bluebutcher','Blitzkrieg Rush',['Blue arc: a teal lane, then a crescent that breaks wood and brick walls.','Blade: a close cut.','Charge: a lane charge, less often than the Butcher\'s.'],'Enraged: arcs more often.'],
    ['arsonist','Blitzkrieg Rush',['Napalm chain: a line of four rings, then burning napalm on each one for 10 s.','Flamethrower: an orange wedge up close, then a sweep of flame that lights wood.','Ring of Fire: napalm lands in a circle around you. Get out, or wait in the safe middle.'],''],
    ['tempest','Blitzkrieg Rush',['Twin lightning: two blue lines side by side. Caught by both, it hurts twice.','Cyclone: a marked path, then a whirlwind that shoves you along and rips out wood walls.','Storm Cage: a ring of lightning posts around you. Get out through the gap before it closes.'],'Below 50%: fires twice.'],
    ['bulldozer','Blitzkrieg Rush',['Charge: a lane, then a fast charge. Hitting a wall dazes him for 3 s.','Seismic Slam: a yellow ring around him, then a shockwave that knocks you back.','Overdrive: three lanes in a zig-zag, then three rams in a row.'],'']]],
  ['WINTER',[
    ['rime','Frostpeak boss raids · Campaign finale',['Frost rupture: cracking ice marks a huge ring. Step clear.','Frost dash: a marked dash that leaves slowing frost behind.'],'His attacks come faster as his health drops.'],
    ['whitebutcher','Campaign · chapter 1',['Ice arc: a lane, then a crescent through wood and brick.','Blade: a close cut.','Charge: a lane charge.','Frost rupture: a marked ring of cracking ice.'],'Enraged below 40%.'],
    ['whiteferryman','Campaign · chapter 2',['Harpoon: a chain line that drags you toward the water.','Boarding crews: raiders landed on the bank.','Bridge ram: a bridge goes into the river.','Frost rupture: a marked ring of cracking ice.'],'After a bridge falls: harpoons faster.'],
    ['whiteforeman','Campaign · chapter 3',['Charge: a fast marked charge. Bait him into a wall to daze him.','Frost rupture: a marked ring of cracking ice.'],'']]],
  ['CITY BLACK OUT',[
    ['destroyer','City Black Out · the last 2 minutes of the final push',['Back Rockets: six red landing rings round you, then missiles arc in. They break wood.','Fire barrel: an orange lane, then a stream of fire down it that burns and lights wood.','Lightning barrel: a blue line tracks you, then a heavy bolt that stuns and jumps to two more people.','Poison Gas: a green ring grows round him, then a gas cloud fills it for 8 s. Fight him from range.','Minefield: a marked area, then ten mines. Shoot one, or throw a grenade, to set them off safely.','Orbital Cannon: a targeting circle follows you for 3 s, stops, then a beam hits. It wrecks walls.'],'Below 40%: the Orbital Cannon, every 20 s.']]]];
// where a standard boss shows up: the maps whose boss order includes him
function idxWhere(k){const m=Object.values(MAPS).filter(M=>(M.bosses||[]).includes(k)).map(M=>M.short||M.name);return m.length?m.join(', ')+' · every 5th raid':'Boss raids'}
function idxPortrait(look){const c=document.createElement('canvas');c.width=c.height=96;c.className='idxArt';c.setAttribute('aria-hidden','true');
  try{paintWardrobeCharacter(c.getContext('2d'),{...look,mark:look.mark||'#e2b436'},.6,1,2.05,48,90,false)}catch(err){}return c}
function idxCard(name,col,look,lines){const d=document.createElement('article');d.className='idxCard';d.tabIndex=0;d.append(idxPortrait(look));
  const t=document.createElement('div');const h=document.createElement('h3');h.textContent=name;if(col)h.style.color=col;t.append(h);
  for(const [cls,txt,c2]of lines){if(Array.isArray(txt)){const ul=document.createElement('ul');for(const s of txt){const li=document.createElement('li');li.textContent=s;ul.append(li)}t.append(ul);continue}
    const p=document.createElement('p');p.className=cls;p.textContent=txt;if(c2)p.style.color=c2;t.append(p)}
  d.append(t);return d}
function renderIndex(tab){
  if(tab==='raiders'){const box=$('idxRaiders');if(box.querySelector('.idxCard'))return;
    for(const [k,first,what]of IDX_RAIDERS){const E=ETYPES[k],nm=ENAMES[k][0];
      box.append(idxCard(nm.toUpperCase(),'',LOOK[k]||LOOK.rifle,[['idxStat',`${E.hp} health · speed ${E.speed} · from raid ${first}`],['idxWhat',what]]))}}
  if(tab==='bosses'){const box=$('idxBosses');if(box.querySelector('.idxCard'))return;
    for(const [grp,list]of IDX_BOSSES){const h=document.createElement('h3');h.className='idxGroup';h.textContent=grp;box.append(h);
      for(const [k,where,atk,phase]of list){const B=BOSSES[k];if(!B)continue;const wk=AMMO_BY[BOSS_WEAK[k]];
        const lines=[['idxStat',`${Math.round(B.hp*BOSS_HP)} base health · ${where||idxWhere(k)}`],['idxAtk',`${atk.length} ATTACK${atk.length>1?'S':''}`],['',atk]];
        if(phase)lines.push(['idxPhase',phase]);if(wk)lines.push(['idxWeak','WEAK TO '+wk.name+' (+35% bullet damage)',wk.col]);
        box.append(idxCard(B.name,B.col,B.look,lines))}
      if(grp==='CITY BLACK OUT'){   // v0.9.7: the eight points and what each one gives while it holds
        const d=document.createElement('article');d.className='idxPois';const t=document.createElement('div'),h=document.createElement('h3');h.textContent='THE EIGHT POINTS';t.append(h);
        const p=document.createElement('p');p.className='idxWhat';p.textContent='Each point gives a perk while it holds. A lost major point adds a squad to every final-push wave; a lost minor point gives final-push bosses +5% health.';t.append(p);
        const ul=document.createElement('ul');for(const [,name,major,,what]of CITY_POIS){const li=document.createElement('li');li.textContent=`${name}${major?' (major)':''}: ${what}`;ul.append(li)}t.append(ul);d.append(t);box.append(d)}}}
}
function idxTab(tab){
  for(const b of document.querySelectorAll('.idxTabs [data-idx]')){const on=b.dataset.idx===tab;b.classList.toggle('sel',on);b.setAttribute('aria-selected',on?'true':'false')}
  for(const p of document.querySelectorAll('[data-idxp]'))p.hidden=p.dataset.idxp!==tab;
  renderIndex(tab);
}
for(const b of document.querySelectorAll('.idxTabs [data-idx]'))b.addEventListener('click',()=>idxTab(b.dataset.idx));
document.querySelectorAll('[data-go=classes]').forEach(b=>b.addEventListener('click',()=>idxTab('classes')));   // the Index opens on Classes
