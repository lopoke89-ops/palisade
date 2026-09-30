/* ================= cosmetics, locker and cases ================= */
// Everything here is cosmetic. Items unlock by playing or come out of supply cases earned in
// play. Each item carries price:null so a store can be added later; grant() is the only way
// anything is added to a locker, so a purchase would go through the same door.
const RAR={c:{n:'COMMON',col:'#9a958a',sh:1},r:{n:'RARE',col:'#4f95e0',sh:3},e:{n:'EPIC',col:'#b168e0',sh:8},l:{n:'LEGENDARY',col:'#e2b436',sh:20},g:{n:'GOLD',col:'#ffe27a',sh:40}};
// Every case in the game. Accounts use the server's copy of this table (case_types), which is the one that counts;
// this one drives the locker screen and players with no account. A new case = a new entry here + items with its box.
const CASES={
  supply:{name:'SUPPLY CASE',short:'Supply Cases',col:'#e2b436',weights:{c:60,r:27,e:10,l:3},cost:null,
    how:'Co-op and Endless only: one every 3 raids you hold, plus wins.'},
  afterglow:{name:'AFTERGLOW CASE',short:'Afterglow Cases',col:'#ff5ad8',weights:{c:53,r:30,e:12,l:4,g:1},cost:10,
    drop:{base:{win:.45,loss:.2},ffa:{win:.5,loss:.2},boss:{each:1}},
    how:'One for everyone in the run when the Demolisher, the Stormcaller or the Foreman goes down. Base Battle and Free-for-all: 45-50% after a win, 20% after a loss. Or 10 shards.'},
  halloween:{name:'HALLOWEEN CASE',short:'Halloween Cases',col:'#ff7a1a',weights:{c:45,r:32,e:16,l:6,g:1},cost:12,
    how:'Dropped by the Butcher and the Ferryman. Or 12 shards.'},
  // v0.9.3: flags as lobby backgrounds and tracers. drop.win: the chance for everyone in the game after any win
  flags:{name:'FLAG CASE',short:'Flag Cases',col:'#5ab0ff',weights:{c:45,r:30,e:17,l:7,g:1},cost:10,drop:{win:.25},
    how:'A 25% chance for everyone after any win, co-op or PvP. Or 10 shards.'}
};
const CASE_IDS=Object.keys(CASES),pvpCase=m=>CASE_IDS.find(id=>CASES[id].drop&&CASES[id].drop[m]),bossCase=()=>CASE_IDS.find(id=>CASES[id].drop&&CASES[id].drop.boss),winCase=()=>CASE_IDS.find(id=>CASES[id].drop&&CASES[id].drop.win);
const SKINS={
  std:{body:'#b9aa82',vest:'#4d6b47',pants:'#4a4636',hat:'#4a5238'},
  desert:{body:'#d2bd92',vest:'#9c8456',pants:'#7c6a4a',hat:'#8e7b55',boonie:'#a58f62'},
  urban:{body:'#a3a6a6',vest:'#4f5456',pants:'#3f4345',hat:'#5c6163',boonie:'#5c6163'},
  forest:{body:'#6f7f52',vest:'#34442a',pants:'#3b4230',hat:'#34422a',boonie:'#465733'},
  night:{body:'#434a5a',vest:'#23283a',pants:'#262a33',hat:'#1d2130',boonie:'#262b3c'},
  redcoat:{body:'#a8392c',vest:'#e3dcc8',pants:'#2f2a2a',hat:'#1f1c1c',boonie:'#2c2626'},
  tiger:{body:'#8f944e',vest:'#4b5530',pants:'#3f4428',hat:'#4b5530',stripe:'#1f2414',boonie:'#5b6236'},
  arctic:{body:'#e4e8ec',vest:'#b3bec8',pants:'#9aa4ad',hat:'#cfd6dc',boonie:'#dfe5ea'},
  gold:{body:'#dab54e',vest:'#8a6a1c',pants:'#5a4718',hat:'#e6c65c',boonie:'#c9a13e',shine:true},
  ghost:{body:'#2c2f36',vest:'#121418',pants:'#1a1c20',hat:'#0e0f12',boonie:'#16181d',glow:'#7fe0ff'},
  // Afterglow Case outfits
  arcade:{body:'#3b4fb0',vest:'#1d2350',pants:'#232a58',hat:'#e2427f',boonie:'#e2427f',stripe:'#e2427f'},
  toxic:{body:'#58722a',vest:'#28320f',pants:'#2a2f1a',hat:'#3b4a14',boonie:'#4a5a1c',spots:'#b6ff3a'},
  frost:{body:'#cfe9f5',vest:'#7fb8d6',pants:'#44667e',hat:'#e8f8ff',boonie:'#dff2fb',frost:'#ffffff'},
  chrome:{body:'#c9ced3',vest:'#7d858c',pants:'#565c62',hat:'#e3e7ea',boonie:'#c9ced3',shine:true,chrome:true},
  neonops:{body:'#1c2029',vest:'#0f1117',pants:'#14161c',hat:'#12141a',boonie:'#1a1d24',neon:'#2af5ff'},
  neonpolice:{body:'#1b2342',vest:'#0d1226',pants:'#141a30',hat:'#101630',boonie:'#141a30',neon:'#3a8bff',badge:'#9fd0ff'},
  neonclown:{body:'#1d1426',vest:'#130c1a',pants:'#1a1222',hat:'#1a1222',boonie:'#1a1222',neon:'#ff3ad0',dots:'#3affd8',ruff:'#ff3ad0'},
  neonknight:{body:'#262a31',vest:'#171a1f',pants:'#1c1f24',hat:'#2a2e35',boonie:'#2a2e35',neon:'#8aff3a',plate:'#3a3f47'},
  galaxy:{body:'#2a1d56',vest:'#140d33',pants:'#170f38',hat:'#1a1140',boonie:'#221650',stars:true,glow:'#8a6aff'},
  holo:{body:'#7fe9ff',vest:'#3fb6d8',pants:'#2d8aa8',hat:'#a8f3ff',boonie:'#7fe9ff',holo:true},
  cyber:{body:'#2b1140',vest:'#ff2a8a',pants:'#1a0c28',hat:'#1c0d2a',boonie:'#2b1140',neon:'#ffe03a',glow:'#ff2a8a'},
  gclown:{body:'#e0b84a',vest:'#b8871c',pants:'#7a5a16',hat:'#f0cf5c',boonie:'#e0b84a',dots:'#fff3b0',ruff:'#fff0a0',shine:true,glitter:true},
  gpolice:{body:'#d9b24a',vest:'#8a6a1c',pants:'#5a4718',hat:'#e6c65c',boonie:'#d9b24a',badge:'#fffbe0',shine:true,glitter:true},
  gknight:{body:'#d4ae45',vest:'#a88428',pants:'#6e5418',hat:'#e6c65c',boonie:'#d4ae45',plate:'#f0cf5c',shine:true,glitter:true},
  // Halloween Case outfits. head: skin colour override; web / bones / wraps / reaper / phantom: extra detail drawn on the figure
  pumpkin:{body:'#d9731f',vest:'#3f6b2a',pants:'#4a3a26',hat:'#e07b22',boonie:'#3f6b2a',ribs:'#a8501a'},
  cobweb:{body:'#3a3a42',vest:'#1f1f25',pants:'#26262c',hat:'#2a2a30',boonie:'#2a2a30',web:'#d8d8e2'},
  skeleton:{body:'#141417',vest:'#0b0b0d',pants:'#141417',hat:'#141417',boonie:'#141417',head:'#e8e2d0',bones:'#ece6d4'},
  mummy:{body:'#cfc3a0',vest:'#b8aa84',pants:'#a8996f',hat:'#cfc3a0',boonie:'#cfc3a0',head:'#cfc3a0',wraps:'#e8dfc2'},
  reaper:{body:'#16141b',vest:'#0c0b10',pants:'#16141b',hat:'#16141b',boonie:'#16141b',head:'#0a090d',reaper:'#8fe0ff'},
  phantom:{body:'#bff5dc',vest:'#8fe8c0',pants:'#bff5dc',hat:'#dffcee',boonie:'#bff5dc',head:'#e6fff3',glow:'#6affb0',phantom:'#6affb0'},
  // v0.9.3 milestone outfits: one per boss and map, four steps each (base, colours, one moving effect, gold).
  // No 'glitter' on these: it makes the figure repaint 20 times a second; their sparkle is in the aura instead.
  // headwear: what the head wears when the Class Issue headgear is equipped. aura: a moving effect drawn over the
  // cached figure each frame (16b-auras.js), so the figure itself never has to be repainted to animate.
  butcher:{body:'#5c1d18',vest:'#2a0c09',pants:'#221412',hat:'#3a0f0c',boonie:'#3a0f0c',apron:'#1c1714',facewrap:'#140807'},
  butcher2:{body:'#d8d0c0',vest:'#4a4440',pants:'#2a2624',hat:'#bdb3a2',boonie:'#bdb3a2',apron:'#7a1f1a',facewrap:'#ece4d4'},
  butcher3:{body:'#7a1410',vest:'#1a0605',pants:'#1a0f0e',hat:'#2a0806',boonie:'#2a0806',apron:'#0e0a0a',facewrap:'#3a0a08',aura:'rage'},
  butcher4:{body:'#d9b24a',vest:'#5c1d18',pants:'#3a2a1a',hat:'#e6c65c',boonie:'#e6c65c',apron:'#6a1a14',facewrap:'#8a1a14',shine:true,aura:'gbutcher'},
  demo:{body:'#4b4a38',vest:'#23241c',pants:'#26241e',hat:'#1f201a',boonie:'#2a2a20',facewrap:'#c8551e',charges:'#a8342a'},
  demo2:{body:'#b8a27a',vest:'#6a5a3a',pants:'#7a6a4a',hat:'#8a7a55',boonie:'#a08c62',facewrap:'#2a5a9a',charges:'#d8c070'},
  demo3:{body:'#3a3a2e',vest:'#1a1a14',pants:'#22221a',hat:'#16160f',boonie:'#22221a',facewrap:'#ff7a1a',charges:'#d0401a',aura:'fuse'},
  demo4:{body:'#dab54e',vest:'#2a2418',pants:'#5a4718',hat:'#e6c65c',boonie:'#e0c060',stripe:'#1a1712',charges:'#f0cf5c',shine:true,aura:'gdemo'},
  storm:{body:'#26323f',vest:'#10171e',pants:'#1a2028',hat:'#1b2530',boonie:'#1b2530',neon:'#7fe0ff',glow:'#7fe0ff'},
  storm2:{body:'#2e1f45',vest:'#150d24',pants:'#1c1330',hat:'#1c1330',boonie:'#241838',neon:'#c07aff',glow:'#c07aff'},
  storm3:{body:'#1a2430',vest:'#0a1016',pants:'#121a22',hat:'#0e141b',boonie:'#141c26',neon:'#bff4ff',glow:'#7fe0ff',aura:'arcs'},
  storm4:{body:'#d4ae45',vest:'#10171e',pants:'#5a4718',hat:'#e6c65c',boonie:'#e0c060',neon:'#fff4b0',glow:'#fff0a0',shine:true,aura:'gstorm'},
  ferry:{body:'#34463f',vest:'#1d2925',pants:'#27302b',hat:'#2b3630',boonie:'#2b3630',coat:'#2e403a',facewrap:'#1d2925'},
  ferry2:{body:'#1a2230',vest:'#0e131c',pants:'#141a24',hat:'#141c28',boonie:'#141c28',coat:'#16202c',facewrap:'#2a3a4a'},
  ferry3:{body:'#2a4a44',vest:'#16302c',pants:'#1e3430',hat:'#1e3a36',boonie:'#1e3a36',coat:'#244440',facewrap:'#16302c',aura:'drowned'},
  ferry4:{body:'#34463f',vest:'#1d2925',pants:'#27302b',hat:'#e6c65c',boonie:'#e0c060',coat:'#c9a13e',facewrap:'#e6c65c',shine:true,aura:'gferry'},
  foreman:{body:'#5a4a2a',vest:'#e0a030',pants:'#3a3326',hat:'#f0b830',boonie:'#f0b830',reflect:'#e8e8d8',headwear:{hardhat:'#f0b830'}},
  foreman2:{body:'#1e1e22',vest:'#ff6a1a',pants:'#26262a',hat:'#f4f4f0',boonie:'#f4f4f0',reflect:'#d8ffd8',headwear:{hardhat:'#f4f4f0'}},
  foreman3:{body:'#4a3a22',vest:'#e0a030',pants:'#332c20',hat:'#f0b830',boonie:'#f0b830',reflect:'#e8e8d8',headwear:{hardhat:'#f0b830'},aura:'weld'},
  foreman4:{body:'#3a3326',vest:'#d9b24a',pants:'#2a2418',hat:'#e6c65c',boonie:'#e6c65c',reflect:'#fff6c8',headwear:{hardhat:'#f0cf5c'},shine:true,aura:'gforeman'},
  yard:{body:'#8e2f24',vest:'#3c5d7e',pants:'#4a3a28',hat:'#c9a45a',boonie:'#c9a45a',headwear:{straw:'#d4b46a'}},
  yard2:{body:'#2f6a3a',vest:'#6a4a2a',pants:'#3a3024',hat:'#c9a45a',boonie:'#c9a45a',headwear:{straw:'#c8a458'}},
  yard3:{body:'#2a3a4a',vest:'#1a2530',pants:'#262a2e',hat:'#6a5a3a',boonie:'#6a5a3a',headwear:{straw:'#8a7448'},aura:'firefly'},
  yard4:{body:'#dab54e',vest:'#3c5d7e',pants:'#5a4718',hat:'#f0cf5c',boonie:'#f0cf5c',headwear:{straw:'#f0d070'},shine:true,aura:'gyard'},
  river:{body:'#4a6a7a',vest:'#2a3a44',pants:'#2e4a36',hat:'#3a5040',boonie:'#3a5040',waders:'#2e4a36',headwear:{boonie:'#3a5040'}},
  river2:{body:'#8a7a5a',vest:'#4a3e2a',pants:'#5a4630',hat:'#6a5a3e',boonie:'#6a5a3e',waders:'#5a4630',headwear:{boonie:'#6a5a3e'}},
  river3:{body:'#d8b830',vest:'#8a7418',pants:'#2e4a36',hat:'#d8b830',boonie:'#d8b830',waders:'#2e4a36',headwear:{boonie:'#d8b830'},aura:'rain'},
  river4:{body:'#dab54e',vest:'#2a3a44',pants:'#c9a13e',hat:'#e6c65c',boonie:'#e6c65c',waders:'#c9a13e',headwear:{boonie:'#e6c65c'},shine:true,aura:'griver'},
  quarry:{body:'#6a6a66',vest:'#d0702a',pants:'#3a3a38',hat:'#2a2a28',boonie:'#4a4a46',headwear:{cap:'#2a2a28',lamp:'#fff2b0'}},
  quarry2:{body:'#2a2a2a',vest:'#a82a1e',pants:'#1e1e1e',hat:'#1a1a1a',boonie:'#2a2a2a',reflect:'#e0e0d0',headwear:{cap:'#1a1a1a',lamp:'#fff2b0'}},
  quarry3:{body:'#5a5550',vest:'#3a3634',pants:'#2e2c2a',hat:'#2a2826',boonie:'#3a3634',headwear:{cap:'#2a2826',lamp:'#ffb060'},aura:'ash'},
  quarry4:{body:'#3a3634',vest:'#d9b24a',pants:'#2a2826',hat:'#e6c65c',boonie:'#e6c65c',headwear:{cap:'#e6c65c',lamp:'#fff2b0'},shine:true,aura:'gquarry'},
  // v0.9.3 class rewards: the gold outfit at the top of each class's ladder
  gsoldier:{body:'#d9b24a',vest:'#2e3a2a',pants:'#5a4718',hat:'#e6c65c',boonie:'#e0c060',medals:true,shine:true,aura:'gsoldier'},
  gsniper:{body:'#d4ae45',vest:'#5a5a1c',pants:'#5a4718',hat:'#e6c65c',boonie:'#e0c060',ghillie:'#c9a13e',shine:true,aura:'gsniper'},
  ggren:{body:'#dab54e',vest:'#1a1814',pants:'#5a4718',hat:'#e6c65c',boonie:'#e0c060',stripe:'#e6c65c',charges:'#f0cf5c',shine:true,aura:'ggren'},
  gqm:{body:'#e0b84a',vest:'#f3ecd8',pants:'#5a4718',hat:'#e6c65c',boonie:'#e0c060',reflect:'#fff6c8',shine:true,aura:'gqm'},
  // v0.9.3 Halloween Case outfits (original takes; the monster follows the novel, not any film)
  sheetghost:{body:'#ece8df',vest:'#e2ddd2',pants:'#ece8df',hat:'#ece8df',boonie:'#ece8df',head:'#ece8df',sheet:'#efebe2',headwear:{}},
  scarecrow:{body:'#4a6a8a',vest:'#8a6a3a',pants:'#5a4a30',hat:'#b89a50',boonie:'#b89a50',head:'#c8a86a',sack:true,patches:true,straws:'#e0c060',headwear:{straw:'#b89a50'}},
  monster:{body:'#2b2622',vest:'#3a332b',pants:'#1f1c19',hat:'#1a1614',boonie:'#1a1614',head:'#c9c29a',coat:'#2b2622',stitches:'#2a1d1a',headwear:{mop:'#141210'}},
  clown:{body:'#c8a02a',vest:'#2a2420',pants:'#b08a22',hat:'#ff4fa8',boonie:'#ff4fa8',head:'#f2eee6',stripe:'#1c1814',ruff:'#f0ece0',clownface:true,headwear:{hair:'#ff4fa8'}},
  slasher:{body:'#2a3548',vest:'#1e2636',pants:'#2a3548',hat:'#1a1a18',boonie:'#2a2a24',hockey:'#e8e2cc',headwear:{}},
  dracula:{body:'#141016',vest:'#7a0f1a',pants:'#141016',hat:'#141016',boonie:'#141016',head:'#e4dccb',cape:'#0e0b10',lining:'#8a0f1f',collar:true,medal:'#e2c25a',headwear:{slick:'#0a0a0c'},aura:'bats'}};
const SKIN_FX=['neon','dots','ruff','badge','plate','stars','holo','spots','frost','glitter','chrome','ribs','web','bones','wraps','reaper','phantom',
  'apron','facewrap','coat','cape','lining','collar','reflect','waders','charges','medals','ghillie','sheet','stitches','clownface','hockey','sack','patches','straws','medal','aura'];
const TRAILS={std:{c:'rgba(255,236,170,.95)'},green:{c:'#86ff7a'},red:{c:'#ff5a46'},blue:{c:'#9fe8ff'},pink:{c:'#ff5ad8'},
  gold:{c:'#ffd24a',w:1.35,snd:'ts_gold'},plasma:{c:'#7af2ff',w:1.5,glow:'rgba(106,240,255,.3)',len:1.7,snd:'ts_plasma'},rainbow:{rainbow:true,w:1.4,len:2.2,snd:'ts_rainbow'},
  // Afterglow Case tracers. grad: head→tail colours; pk/pr: particles shed along the way; head: a bright tip; core: white centre line
  sunset:{grad:['#ff5ad8','#ffa03a'],w:1.35,snd:'ts_grad'},lagoon:{grad:['#3affb0','#3a8bff'],w:1.35,snd:'ts_grad'},heat:{grad:['#ffe03a','#ff3a2a'],w:1.35,snd:'ts_grad'},
  aurora:{grad:['#6af0ff','#b06aff'],w:1.5,glow:'rgba(140,120,255,.28)',len:1.6,snd:'ts_aurora'},
  starlight:{c:'#fffbe8',w:1.2,pk:'star',pr:.55,len:1.5,snd:'ts_star'},
  comet:{grad:['#f2fcff','rgba(80,160,255,0)'],w:1.9,len:2.7,head:'#e6f8ff',glow:'rgba(120,190,255,.22)',snd:'ts_comet'},
  neonpulse:{c:'#ff3ad0',w:1.4,pulse:true,glow:'rgba(255,58,208,.32)',snd:'ts_neon'},
  nebula:{grad:['#c07aff','#3a6aff'],w:2.2,glow:'rgba(150,90,255,.35)',len:2,pk:'cosmic',pr:.45,snd:'ts_cosmic'},
  asteroid:{c:'#a89a88',w:1.3,pk:'rock',pr:.65,len:1.4,head:'#6a5e52',snd:'ts_rock'},
  solar:{grad:['#fff6a0','#ff5a1a'],w:1.8,glow:'rgba(255,140,40,.35)',pk:'flame',pr:.6,len:1.8,snd:'ts_solar'},
  glitch:{c:'#ffffff',w:1.25,glitch:true,snd:'ts_glitch'},
  galaxy:{grad:['#ff8ad8','#6a5aff'],w:1.8,glow:'rgba(120,100,255,.35)',pk:'cosmic',pr:.95,len:2.2,core:true,snd:'ts_galaxy'},
  blackhole:{c:'#0c0616',w:2.2,edge:'#b06aff',glow:'rgba(160,60,255,.42)',pk:'void2',pr:.6,len:1.8,snd:'ts_void'},
  grainbow:{rgrad:true,w:2,len:2.7,glow:'rgba(255,215,110,.42)',core:true,pk:'goldsp',pr:.95,snd:'ts_grainbow'},
  // Halloween Case tracers. bands: hard-edged stripes, head first
  candycorn:{bands:['#fff4d6','#ff8a1a','#ffd23a'],w:1.6,len:1.6,snd:'ts_grad'},
  ghostfire:{grad:['#eaffc8','#1ee860'],w:1.9,len:2,glow:'rgba(60,255,130,.32)',pk:'gflame',pr:.7,snd:'ts_solar'},
  // v0.9.3. New tracers only ever go on the END of this list: a shot sends its tracer as a number (its place here),
  // so inserting one in the middle would change what everyone else's tracers look like to older copies.
  // class rewards
  rocket:{grad:['#fff0b0','#ff6a1a'],w:1.7,len:1.9,glow:'rgba(255,120,40,.3)',pk:'flame',pr:.55,snd:'ts_solar'},
  hairline:{c:'#ff4040',w:.85,len:2.8,glow:'rgba(255,60,60,.22)',snd:'ts_star'},
  fuse:{bands:['#fff0a0','#ff8a1a','#6a4020'],w:1.4,len:1.5,pk:'goldsp',pr:.7,snd:'ts_solar'},
  supply:{bands:['#e8e2d0','#3d8a4a','#e8e2d0','#3d8a4a'],w:1.4,len:1.7,snd:'ts_neon'},
  // Halloween Case
  candle:{bands:['#fff6d0','#ffc84a','#ff8a2a'],w:1.3,len:1.4,pk:'flame',pr:.3,snd:'ts_grad'},
  poison:{grad:['#b6ff3a','#c8102e'],w:1.5,len:1.6,glow:'rgba(150,255,60,.28)',snd:'ts_aurora'},
  blood:{grad:['#ff4a3a','#4a0006'],w:1.8,len:2,glow:'rgba(200,0,20,.3)',pk:'blood',pr:.6,snd:'ts_void'},
  hellfire:{grad:['#fff2a0','#ff3a0a'],w:2.1,len:2.2,glow:'rgba(255,80,20,.4)',pk:'flame',pr:.9,head:'#fff8d0',snd:'ts_solar'}};
// v0.9.3: the Flag Case. Every flag is a lobby background (18b-backgrounds.js draws it) and a tracer in the flag's
// colours as stripes. [id, name, rarity, tracer stripes]
const FLAGS=[
  ['pride','Rainbow Pride','g',['#e40303','#ff8c00','#ffed00','#008026','#004dff','#750787']],
  ['progress','Progress Pride','g',['#ffffff','#f5a9b8','#5bcefa','#613915','#000000','#e40303','#ff8c00','#ffed00','#008026','#004dff','#750787']],
  ['trans','Transgender','l',['#5bcefa','#f5a9b8','#ffffff','#f5a9b8','#5bcefa']],
  ['bi','Bisexual','l',['#d60270','#9b4f96','#0038a8']],
  ['lesbian','Lesbian','l',['#d52d00','#ff9a56','#ffffff','#d362a4','#a30262']],
  ['gay','Gay Men','l',['#078d70','#26ceaa','#98e8c1','#ffffff','#7bade2','#5049cc','#3d1a78']],
  ['pan','Pansexual','l',['#ff218c','#ffd800','#21b1ff']],
  ['nonbinary','Nonbinary','l',['#fcf434','#ffffff','#9c59d1','#2c2c2c']],
  ['ace','Asexual','l',['#000000','#a3a3a3','#ffffff','#800080']],
  ['aro','Aromantic','l',['#3da542','#a7d379','#ffffff','#a9a9a9','#000000']],
  ['fluid','Genderfluid','l',['#ff76a4','#ffffff','#c011d7','#000000','#2f3cbe']],
  ['agender','Agender','l',['#000000','#bcc4c7','#ffffff','#b7f684','#ffffff','#bcc4c7','#000000']],
  ['intersex','Intersex','l',['#ffd800','#7902aa','#ffd800']],
  ['usa','United States','e',['#b22234','#ffffff','#3c3b6e']],
  ['mexico','Mexico','e',['#006847','#ffffff','#ce1126']],
  ['brazil','Brazil','e',['#009c3b','#ffdf00','#002776']],
  ['japan','Japan','e',['#ffffff','#bc002d','#ffffff']],
  ['skorea','South Korea','e',['#ffffff','#cd2e3a','#0047a0','#000000']],
  ['puertorico','Puerto Rico','e',['#ed0000','#ffffff','#0050f0']],
  ['canada','Canada','r',['#d52b1e','#ffffff','#d52b1e']],
  ['uk','United Kingdom','r',['#012169','#ffffff','#c8102e']],
  ['germany','Germany','r',['#000000','#dd0000','#ffce00']],
  ['france','France','r',['#002395','#ffffff','#ed2939']],
  ['italy','Italy','r',['#009246','#ffffff','#ce2b37']],
  ['spain','Spain','r',['#aa151b','#f1bf00','#aa151b']],
  ['ireland','Ireland','r',['#169b62','#ffffff','#ff883e']],
  ['argentina','Argentina','r',['#74acdf','#ffffff','#74acdf']],
  ['philippines','Philippines','r',['#0038a8','#ce1126','#ffffff','#fcd116']],
  ['india','India','c',['#ff9933','#ffffff','#138808']],
  ['israel','Israel','c',['#0038b8','#ffffff','#0038b8']],
  ['russia','Russia','c',['#ffffff','#0039a6','#d52b1e']],
  ['nkorea','North Korea','c',['#024fa2','#ed1c27','#024fa2']]];
for(const[id,,r,b]of FLAGS)TRAILS['f_'+id]=Object.assign({bands:b,w:1.5,len:1.8,snd:r==='g'?'ts_grainbow':'ts_grad'},
  r==='l'||r==='g'?{glow:'rgba(255,255,255,.22)',w:1.6}:{},r==='g'?{pk:'goldsp',pr:.7,len:2.2}:{});
const TRAIL_IDS=Object.keys(TRAILS),ENEMY_TR={c:'rgba(255,140,90,.95)'};
const COS=[
  ['skin','std','Standard Issue','c','free'],['skin','desert','Desert','c','unlock',{raids:3},'Survive 3 raids'],
  ['skin','urban','Urban Grey','c','unlock',{wins:1},'Win any run'],['skin','forest','Deep Woods','r','case'],['skin','night','Nightwatch','r','case'],
  ['skin','redcoat','Redcoat','r','case'],['skin','tiger','Tigerstripe','e','case'],['skin','arctic','Arctic','e','case'],
  ['skin','gold','Gilded','l','case'],['skin','ghost','Ghost','l','unlock',{endless:15},'Hold 15 raids in Endless'],
  ['hat','class','Class Issue','c','free'],['hat','cap','Ball Cap','c','free'],['hat','beanie','Beanie','c','unlock',{raids:10},'Survive 10 raids'],
  ['hat','boonie','Boonie','c','case'],['hat','wrap','Head Wrap','r','case'],['hat','beret','Beret','r','case'],
  ['hat','tophat','Top Hat','e','case'],['hat','crown','Crown','l','case'],
  ['trail','std','Standard Tracer','c','free'],['trail','green','Green Tracer','c','unlock',{drops:50},'Drop 50 raiders'],
  ['trail','red','Hot Red','c','case'],['trail','blue','Ice Round','r','case'],['trail','pink','Neon','r','case'],
  ['trail','gold','Gold Round','e','case'],['trail','plasma','Plasma','e','case'],['trail','rainbow','Prism','l','case'],
  ['fx','none','Standard','c','free'],['fx','sparks','Sparks','c','case'],['fx','smoke','Smoke Puff','c','case'],
  ['fx','confetti','Confetti','r','case'],['fx','embers','Embers','r','unlock',{hardWins:1},'Win on Hard'],['fx','glint','Ice Glint','r','case'],
  ['fx','bolt','Lightning','e','case'],['fx','skull','Skull Pop','l','case'],
  // the Afterglow Case (same list as the database seed)
  ['skin','arcade','Arcade','c','case',null,null,'afterglow'],['skin','toxic','Toxic Waste','c','case',null,null,'afterglow'],['skin','frost','Frostbite','r','case',null,null,'afterglow'],['skin','chrome','Chrome','r','case',null,null,'afterglow'],
  ['skin','neonops','Neon Ops','e','case',null,null,'afterglow'],['skin','neonpolice','Neon Police','e','case',null,null,'afterglow'],['skin','neonclown','Neon Clown','e','case',null,null,'afterglow'],['skin','neonknight','Neon Knight','e','case',null,null,'afterglow'],
  ['skin','galaxy','Galaxy','l','case',null,null,'afterglow'],['skin','holo','Hologram','l','case',null,null,'afterglow'],['skin','cyber','Cyberpunk','l','case',null,null,'afterglow'],['skin','gclown','Gold Clown','g','case',null,null,'afterglow'],
  ['skin','gpolice','Gold Police','g','case',null,null,'afterglow'],['skin','gknight','Gold Metal Knight','g','case',null,null,'afterglow'],['hat','headband','Neon Headband','c','case',null,null,'afterglow'],['hat','acap','Arcade Cap','c','case',null,null,'afterglow'],
  ['hat','nhelm','Neon Helmet','r','case',null,null,'afterglow'],['hat','pcap','Police Cap','r','case',null,null,'afterglow'],['hat','ledmask','LED Mask','e','case',null,null,'afterglow'],['hat','visor','Cyber Visor','e','case',null,null,'afterglow'],
  ['hat','clownhair','Neon Clown Hair','e','case',null,null,'afterglow'],['hat','halo','Halo','l','case',null,null,'afterglow'],['hat','glitch','Glitch Head','l','case',null,null,'afterglow'],['hat','gclownhair','Gold Clown Hair','g','case',null,null,'afterglow'],
  ['hat','ghelm','Gold Knight Helm','g','case',null,null,'afterglow'],['trail','sunset','Sunset Fade','c','case',null,null,'afterglow'],['trail','lagoon','Lagoon Fade','c','case',null,null,'afterglow'],['trail','heat','Heatwave','c','case',null,null,'afterglow'],
  ['trail','aurora','Aurora','r','case',null,null,'afterglow'],['trail','starlight','Starlight','r','case',null,null,'afterglow'],['trail','comet','Comet','r','case',null,null,'afterglow'],['trail','neonpulse','Neon Pulse','r','case',null,null,'afterglow'],
  ['trail','nebula','Nebula','e','case',null,null,'afterglow'],['trail','asteroid','Asteroid Belt','e','case',null,null,'afterglow'],['trail','solar','Solar Flare','e','case',null,null,'afterglow'],['trail','glitch','Glitch Line','e','case',null,null,'afterglow'],
  ['trail','galaxy','Galaxy','l','case',null,null,'afterglow'],['trail','blackhole','Event Horizon','l','case',null,null,'afterglow'],['trail','grainbow','Gold Rainbow','g','case',null,null,'afterglow'],['fx','pixel','Pixel Pop','c','case',null,null,'afterglow'],
  ['fx','frost','Frost Shatter','c','case',null,null,'afterglow'],['fx','gradburst','Violet Fade','r','case',null,null,'afterglow'],['fx','sunburst','Sunset Burst','r','case',null,null,'afterglow'],['fx','toxic','Toxic Splash','r','case',null,null,'afterglow'],
  ['fx','supernova','Supernova','e','case',null,null,'afterglow'],['fx','glitchout','Glitch Out','e','case',null,null,'afterglow'],['fx','singularity','Singularity','l','case',null,null,'afterglow'],['fx','shockwave','Neon Shockwave','l','case',null,null,'afterglow'],
  ['fx','bubbles','Gold Bubbles','g','case',null,null,'afterglow'],
  // the Halloween Case
  ['skin','pumpkin','Pumpkin Patch','c','case',null,null,'halloween'],['trail','candycorn','Candy Corn','c','case',null,null,'halloween'],
  ['hat','jackolantern',"Jack-o'-Lantern",'r','case',null,null,'halloween'],['skin','cobweb','Cobweb','r','case',null,null,'halloween'],
  ['fx','bats','Bat Swarm','r','case',null,null,'halloween'],
  ['skin','skeleton','Skeleton','e','case',null,null,'halloween'],['skin','mummy','Mummy','e','case',null,null,'halloween'],['hat','witch','Witch Hat','e','case',null,null,'halloween'],
  ['trail','ghostfire','Ghostfire','e','case',null,null,'halloween'],['fx','spider','Spider Drop','e','case',null,null,'halloween'],
  ['skin','reaper','Grim Reaper','l','case',null,null,'halloween'],['hat','pumpkinking','Pumpkin King','l','case',null,null,'halloween'],['fx','souls','Soul Harvest','l','case',null,null,'halloween'],
  ['skin','phantom','Phantom','g','case',null,null,'halloween'],
  // v0.9.3 Halloween additions
  ['skin','sheetghost','Sheet Ghost','c','case',null,null,'halloween'],['trail','candle','Candle Flicker','c','case',null,null,'halloween'],
  ['skin','scarecrow','Scarecrow','r','case',null,null,'halloween'],['trail','poison','Poison Apple','r','case',null,null,'halloween'],
  ['skin','monster',"Frankenstein's Monster",'e','case',null,null,'halloween'],['skin','clown','Scary Clown','e','case',null,null,'halloween'],
  ['trail','blood','Blood Trail','e','case',null,null,'halloween'],
  ['skin','slasher','Hockey-Mask Slasher','l','case',null,null,'halloween'],['skin','dracula','Dracula','l','case',null,null,'halloween'],
  ['trail','hellfire','Hellfire','l','case',null,null,'halloween']
].map(([cat,key,name,r,src,need,how,box])=>{box=src==='case'?box||'supply':null;return{id:cat+':'+key,cat,key,name,r,src,box,need:need||null,how:how||(box?'Found in '+CASES[box].short:''),price:null}});
// v0.9.3 milestone ladders: four items each (rare, epic, legendary, gold) that unlock as one counter climbs.
// st: the locker counter (the server adds to the same one); how(n): what the item says while it's locked.
const LADDER_RAR=['r','e','l','g'];
const LADDERS=[
  {id:'butcher',kind:'boss',title:'THE BUTCHER',st:'boss_butcher',steps:[25,50,100,250],unit:'Butchers beaten',how:n=>`Beat the Butcher ${n} times`,
    items:[['skin','butcher','Butcher'],['skin','butcher2','Pale Butcher'],['skin','butcher3','Bloodrage Butcher'],['skin','butcher4','Gilded Butcher']]},
  {id:'demolisher',kind:'boss',title:'THE DEMOLISHER',st:'boss_demolisher',steps:[25,50,100,250],unit:'Demolishers beaten',how:n=>`Beat the Demolisher ${n} times`,
    items:[['skin','demo','Demolisher'],['skin','demo2','Desert Demolisher'],['skin','demo3','Live-Fuse Demolisher'],['skin','demo4','Gilded Demolisher']]},
  {id:'storm',kind:'boss',title:'THE STORMCALLER',st:'boss_storm',steps:[25,50,100,250],unit:'Stormcallers beaten',how:n=>`Beat the Stormcaller ${n} times`,
    items:[['skin','storm','Stormcaller'],['skin','storm2','Violet Stormcaller'],['skin','storm3','Crackling Stormcaller'],['skin','storm4','Gilded Stormcaller']]},
  {id:'ferryman',kind:'boss',title:'THE FERRYMAN',st:'boss_ferryman',steps:[25,50,100,250],unit:'Ferrymen beaten',how:n=>`Beat the Ferryman ${n} times`,
    items:[['skin','ferry','Ferryman'],['skin','ferry2','Blackwater Ferryman'],['skin','ferry3','Drowned Ferryman'],['skin','ferry4','Gilded Ferryman']]},
  {id:'foreman',kind:'boss',title:'THE FOREMAN',st:'boss_foreman',steps:[25,50,100,250],unit:'Foremen beaten',how:n=>`Beat the Foreman ${n} times`,
    items:[['skin','foreman','Foreman'],['skin','foreman2','Night-Shift Foreman'],['skin','foreman3','Sparking Foreman'],['skin','foreman4','Gilded Foreman']]},
  {id:'yard',kind:'map',title:'THE YARD',st:'map_yard',steps:[250,500,1000,2500],unit:'raids held on the Yard',how:n=>`Hold ${n} raids on the Yard`,
    items:[['skin','yard','Yard Hand'],['skin','yard2','Harvest Hand'],['skin','yard3','Firefly Hand'],['skin','yard4','Golden Yard']]},
  {id:'river',kind:'map',title:'RIVERBEND',st:'map_river',steps:[250,500,1000,2500],unit:'raids held on Riverbend',how:n=>`Hold ${n} raids on Riverbend`,
    items:[['skin','river','River Rat'],['skin','river2','Silt Rat'],['skin','river3','Rain Rat'],['skin','river4','Golden River']]},
  {id:'quarry',kind:'map',title:'ASHFALL QUARRY',st:'map_quarry',steps:[250,500,1000,2500],unit:'raids held in the Quarry',how:n=>`Hold ${n} raids in Ashfall Quarry`,
    items:[['skin','quarry','Quarry Hand'],['skin','quarry2','Oil-Drum Hand'],['skin','quarry3','Ashfall Hand'],['skin','quarry4','Golden Quarry']]},
  {id:'soldier',kind:'class',title:'SOLDIER',st:'cls_soldier_raids',steps:[250,500,1000,2500],unit:'raids held as a Soldier',how:n=>`Hold ${n} raids as a Soldier`,
    items:[['hat','officer',"Officer's Cap"],['trail','rocket','Rocket Trail'],['fx','rocketburst','Rocket Burst'],['skin','gsoldier','Gold Commander']]},
  {id:'sniper',kind:'class',title:'SNIPER',st:'cls_sniper_raids',steps:[250,500,1000,2500],unit:'raids held as a Sniper',how:n=>`Hold ${n} raids as a Sniper`,
    items:[['hat','ghood','Ghillie Hood'],['trail','hairline','Hairline'],['fx','reticle','Reticle'],['skin','gsniper','Gold Ghillie']]},
  {id:'grenadier',kind:'class',title:'GRENADIER',st:'cls_grenadier_raids',steps:[250,500,1000,2500],unit:'raids held as a Grenadier',how:n=>`Hold ${n} raids as a Grenadier`,
    items:[['hat','bombhelm','Blast Helmet'],['trail','fuse','Lit Fuse'],['fx','frag','Frag Burst'],['skin','ggren','Gold Demolitions']]},
  {id:'quartermaster',kind:'class',title:'QUARTERMASTER',st:'cls_quartermaster_raids',steps:[250,500,1000,2500],unit:'raids held as a Quartermaster',how:n=>`Hold ${n} raids as a Quartermaster`,
    items:[['hat','qmset','Supply Headset'],['trail','supply','Supply Line'],['fx','salvage','Salvage Pop'],['skin','gqm','Gold Quartermaster']]}];
for(const L of LADDERS)L.items.forEach(([cat,key,name],i)=>COS.push({id:cat+':'+key,cat,key,name,r:LADDER_RAR[i],src:'unlock',box:null,
  need:{[L.st]:L.steps[i]},how:L.how(L.steps[i]),price:null,ladder:L.id}));
// the Flag Case's tracers (its backgrounds are added with the other backgrounds)
for(const[id,name,r]of FLAGS)COS.push({id:'trail:f_'+id,cat:'trail',key:'f_'+id,name:name+' Flag',r,src:'case',box:'flags',need:null,how:'Found in '+CASES.flags.short,price:null});
const COSBY=Object.fromEntries(COS.map(c=>[c.id,c]));
const CATN={skin:'SKIN',hat:'HEADGEAR',trail:'TRACER',fx:'KILL FX'};
const DEFAULT_COS={skin:'std',hat:'class',trail:'std',fx:'none'};
function parseCos(v){
  const o={...DEFAULT_COS},ks=['skin','hat','trail','fx'];
  if(typeof v==='string'){const a=v.split('|');ks.forEach((k,i)=>{if(a[i]&&COSBY[k+':'+a[i]])o[k]=a[i]})}
  else if(v&&typeof v==='object')for(const k of ks)if(COSBY[k+':'+v[k]])o[k]=v[k];
  return o;
}
const cosStr=c=>[c.skin,c.hat,c.trail,c.fx].join('|');
// Saves live in this browser's storage for this site, under keys that must never be renamed: pushing a new
// version of the site does not touch them. LOCK_BAK holds the previous good save, so a save that gets
// corrupted (a crash mid-write, a bad edit) falls back to it instead of starting over.
const LOCK_KEY='palisade.locker.v1',LOCK_BAK='palisade.locker.bak',LOCK_BAD='palisade.locker.corrupt';
let lockerNote='';
let locker=loadLocker();
function readJSON(key){let s=null;try{s=localStorage.getItem(key)}catch(e){return{none:true}}if(s===null)return{none:true};try{const v=JSON.parse(s);return v&&typeof v==='object'&&!Array.isArray(v)?{v}:{bad:s}}catch(e){return{bad:s}}}
function loadLocker(src){
  let L=src||null;
  if(!L){const a=readJSON(LOCK_KEY);
    if(a.v)L=a.v;
    else if(a.bad){try{if(typeof a.bad==='string')localStorage.setItem(LOCK_BAD,a.bad)}catch(e){}
      const b=readJSON(LOCK_BAK);if(b.v){L=b.v;lockerNote='Your save was damaged, so the last good copy was restored.'}else lockerNote='Your save was damaged and could not be read. Import a backup in Settings to restore it.'}}
  return normLocker(L);
}
function normLocker(L){
  const free=COS.filter(c=>c.src==='free').map(c=>c.id);
  const base={owned:free.slice(),eq:{...DEFAULT_COS},cases:1,bag:{},shards:0,prog:0,st:{raids:0,wins:0,drops:0,endless:0,hardWins:0}};   // one welcome case
  if(!L||typeof L!=='object')L=base;
  // items this build doesn't know (renamed or from a newer version) are kept, just not shown
  L.owned=Array.isArray(L.owned)?[...new Set(L.owned.filter(id=>typeof id==='string'&&id.length<40))]:free.slice();for(const id of free)if(!L.owned.includes(id))L.owned.push(id);
  L.st=Object.assign({},base.st,L.st||{});for(const k of['cases','shards','prog'])L[k]=Math.max(0,L[k]|0);
  // v0.9.2: the skill tree (accounts only; the server's copy is the real one)
  for(const k of['sp','spProg','spTotal'])L[k]=Math.max(0,L[k]|0);{const t={};if(L.skills&&typeof L.skills==='object')for(const S of SKILLS)if(L.skills[S.id]>0)t[S.id]=Math.min(S.max,L.skills[S.id]|0);L.skills=t}
  const bag={};if(L.bag&&typeof L.bag==='object')for(const k in L.bag)if(k!=='supply'&&/^[a-z0-9_]{1,24}$/.test(k))bag[k]=Math.max(0,L.bag[k]|0);L.bag=bag;   // unknown cases are kept
  const bg=L.eq&&typeof L.eq.bg==='string'?L.eq.bg:'campfire';
  L.eq=parseCos(L.eq);for(const k in L.eq)if(!L.owned.includes(k+':'+L.eq[k]))L.eq[k]=DEFAULT_COS[k];
  L.eq.bg=/^[a-z0-9_]{1,24}$/.test(bg)&&(typeof COSBY==='undefined'||!COSBY['bg:'+bg]||L.owned.includes('bg:'+bg))?bg:'campfire';   // the lobby background (unknown ids are kept)
  return L;
}
/* ---- save backup: one line of text holding the locker, best runs and settings, with a checksum ---- */
const SAVE_TAG='PALISADE-SAVE-1';
function crc32(s){let c,crc=~0;for(let i=0;i<s.length;i++){c=(crc^s.charCodeAt(i))&255;for(let k=0;k<8;k++)c=c&1?(c>>>1)^0xEDB88320:c>>>1;crc=(crc>>>8)^c}return((~crc)>>>0).toString(16).padStart(8,'0')}
const b64e=s=>btoa(unescape(encodeURIComponent(s))),b64d=s=>decodeURIComponent(escape(atob(s)));
function exportSave(){
  const L={owned:locker.owned,eq:locker.eq,cases:locker.cases,bag:locker.bag,shards:locker.shards,prog:locker.prog,st:locker.st};
  const c={name:cfg.name||'',volume:cfg.volume,music:cfg.music,shake:cfg.shake,haptics:cfg.haptics,fps:cfg.fps,build:cfg.build};
  const body=b64e(JSON.stringify({v:1,at:new Date().toISOString(),locker:L,best:loadBest(),cfg:c}));
  return SAVE_TAG+'.'+body+'.'+crc32(body);
}
function parseSave(text){
  const s=String(text||'').replace(/\s+/g,''),m=s.match(/PALISADE-SAVE-1\.([A-Za-z0-9+/=]+)\.([0-9a-f]{8})/);
  if(!m)return{err:'That isn\'t a PALISADE save code. It starts with PALISADE-SAVE-1.'};
  if(crc32(m[1])!==m[2])return{err:'That save code is damaged or incomplete. Copy the whole thing, or use the save file.'};
  let d;try{d=JSON.parse(b64d(m[1]))}catch(e){return{err:'That save code could not be read.'}}
  if(!d||d.v!==1||!d.locker||!Array.isArray(d.locker.owned))return{err:'That save code is from a version this game can\'t read.'};
  return{d};
}
function saveSummary(d){
  const L=normLocker(JSON.parse(JSON.stringify(d.locker))),n=L.owned.filter(id=>COSBY[id]&&COSBY[id].src!=='free').length,when=d.at?new Date(d.at):null;
  const nc=L.cases+Object.values(L.bag).reduce((a,v)=>a+v,0);
  return`${when&&!isNaN(when)?'Saved '+when.toLocaleString(undefined,{dateStyle:'medium',timeStyle:'short'})+' · ':''}${n} item${n===1?'':'s'} · ${nc} case${nc===1?'':'s'} · ${L.shards} shards · ${L.st.raids} raids held`;
}
function restoreSave(d){
  try{const cur=localStorage.getItem(LOCK_KEY);if(cur)localStorage.setItem(LOCK_BAK,cur)}catch(e){}
  locker=normLocker(JSON.parse(JSON.stringify(d.locker)));try{localStorage.setItem(LOCK_KEY,JSON.stringify(locker))}catch(e){}
  restoreExtras(d);lockerNote='';$('saveNote').hidden=true;keepStorage();
}
function restoreExtras(d){
  if(d.best&&typeof d.best==='object')try{localStorage.setItem(BEST_KEY,JSON.stringify(d.best))}catch(e){}
  if(d.cfg&&typeof d.cfg==='object'){for(const k of['name','volume','music','shake','haptics','fps','build'])if(d.cfg[k]!==undefined&&typeof d.cfg[k]===typeof cfg[k])cfg[k]=d.cfg[k];saveCfg();applyCfg()}
}
let saveMode='',savePending=null;
function openSaveOv(mode){
  saveMode=mode;savePending=null;const ov=$('saveOv'),ta=$('saveText');ov.hidden=false;$('saveMsg').textContent='';
  $('saveTitle').textContent=mode==='export'?'EXPORT SAVE':'IMPORT SAVE';
  $('saveExp').hidden=mode!=='export';$('saveImp').hidden=mode==='export';$('saveConfirm').hidden=true;
  if(mode==='export'){ta.readOnly=true;ta.value=exportSave();$('saveLede').textContent='Keep this somewhere safe: copy it into a note or email, or download the file. Import it later on any browser or device to get your locker back.'}
  else{ta.readOnly=false;ta.value='';ta.placeholder='Paste your PALISADE-SAVE-1 code here';$('saveLede').textContent='Paste a save code or load a save file. Restoring replaces the locker, best runs and settings in this browser.'}
}
function closeSaveOv(){$('saveOv').hidden=true;savePending=null}
function checkImport(text){
  const r=parseSave(text);$('saveConfirm').hidden=true;savePending=null;
  if(r.err){$('saveMsg').textContent=r.err;return}
  savePending=r.d;$('saveMsg').textContent=saveSummary(r.d);$('saveConfirm').hidden=false;
}
function saveFileName(){const d=new Date();return`palisade-save-${d.getFullYear()}-${String(d.getMonth()+1).padStart(2,'0')}-${String(d.getDate()).padStart(2,'0')}.txt`}
function saveLocker(){try{const cur=localStorage.getItem(LOCK_KEY);if(cur&&readJSON(LOCK_KEY).v)localStorage.setItem(LOCK_BAK,cur);locker.at=Date.now();localStorage.setItem(LOCK_KEY,JSON.stringify(locker))}catch(e){}keepStorage()}
// ask the browser not to clear this site's storage when space runs low (no prompt in Chrome, Edge or Safari)
let persistAsked=false;
function keepStorage(){if(persistAsked)return;persistAsked=true;try{if(navigator.storage&&navigator.storage.persist&&!/firefox/i.test(navigator.userAgent))navigator.storage.persisted().then(p=>{if(!p)navigator.storage.persist()}).catch(()=>{})}catch(e){}}
const myCos=()=>locker.eq,owns=id=>locker.owned.includes(id);
function grant(id){if(!COSBY[id]||owns(id))return false;locker.owned.push(id);return true}
const meets=need=>Object.entries(need).every(([k,v])=>(locker.st[k]|0)>=v);
function checkUnlocks(){const got=[];for(const c of COS)if(c.src==='unlock'&&!owns(c.id)&&meets(c.need)){grant(c.id);got.push(c)}return got}
// called once per finished run, on every player's own phone
// called once per run: when it ends, or when you leave it early (raids held so far count). With an account the
// server works out the reward and the text on screen is replaced by what it actually granted.
// salvage still unspent when a co-op / Endless run ends turns into shards: 20 to 1, no part shards,
// at most 2 per raid held and 10 a run (the server applies the same cap to accounts). Runs once per game (game.rewarded).
const SAL_SHARD={rate:20,perRaid:2,max:10};
const salvageShards=(sal,held)=>Math.max(0,Math.min(Math.floor(Math.max(0,sal)/SAL_SHARD.rate),SAL_SHARD.perRaid*Math.max(0,held|0),SAL_SHARD.max));
// what each boss that went down drops (the same rule as the server): the Butcher and the Ferryman a Halloween
// Case (two from the October Butcher), the rest an Afterglow Case; never more bosses than the raids held allow
// v0.9.2: `from` is the raid count when this player came in; only boss raids after it count
// v0.9.3: which of the bosses that went down this claim counts (the same cap the server uses)
function bossCounted(keys,held,from=0){
  const hi=Math.min(held+1,isFinite(game.waves)?game.waves:1e9),cap=Math.max(0,Math.floor(hi/5)-Math.floor(from/5))*(game.size==='xl'?2:1),out=[];   // XL boss raids have two bosses
  for(const k of keys){if(out.length>=cap)break;if(!BOSSES[k==='butcher_oct'?'butcher':k])continue;out.push(k)}
  return out;
}
function bossDrops(keys,held,from=0){
  const out={};for(const k of bossCounted(keys,held,from)){const box=bossBox(k==='butcher_oct'?'butcher':k);out[box]=(out[box]|0)+(k==='butcher_oct'?2:1)}
  return out;
}
// v0.9.3 milestone counters (the server keeps the same ones for accounts): each boss beaten, raids held on each map
// and raids held as each class (the class you ended the run as)
function addMilestones(st,keys,held,from,mine,cls,map){
  for(const k of bossCounted(keys,held,from)){const b='boss_'+(k==='butcher_oct'?'butcher':k);st[b]=(st[b]|0)+1}
  if(mine>0){if(MAP_IDS.includes(map))st['map_'+map]=(st['map_'+map]|0)+mine;if(CLASSES[cls])st['cls_'+cls+'_raids']=(st['cls_'+cls+'_raids']|0)+mine}
}
// the Flag Case's chance after any win (this browser's own locker; the server rolls for accounts)
function winDrop(){const id=winCase();if(!id||rnd()>=CASES[id].drop.win)return{};caseAdd(id,1);return{[id]:1}}
// Rewards come back as data (for the reward cards) with a sentence alongside (toasts, older screens):
// {kind, cases:{supply,afterglow,halloween,…}, shards, unlocked:[ids], toNext (raids to the next Supply Case),
//  prog (0-2 of 3), chance/missCase (PvP roll), pending (the server hasn't answered yet), text}
function rewardText(R){
  const bits=[],pl=(n,w)=>`${n} ${w}${n===1?'':'s'}`;
  if(R.pending)return R.text||'Sending your result to your account…';
  if(R.kind==='run'){
    if(R.cases.supply>0)bits.push(`+${pl(R.cases.supply,'supply case')}`);
    for(const id in R.cases)if(id!=='supply'&&R.cases[id]>0&&CASES[id])bits.push(`+${R.cases[id]} ${CASES[id].name.toLowerCase()}${R.cases[id]>1?'s':''} ${CASES[id].drop&&CASES[id].drop.win?'for the win':'from bosses'}`);
    if(R.bossShards>0)bits.push(`+${pl(R.bossShards,'shard')} from in-between bosses`);
    if(R.shards-(R.bossShards|0)>0)bits.push(`+${pl(R.shards-(R.bossShards|0),'shard')} from leftover salvage`);
    if(R.sp>0)bits.push(`+${pl(R.sp,'skill point')}`);
    bits.push(`${pl(R.toNext,'more raid')} to the next supply case`);
  }else{if(R.missCase&&CASES[R.missCase])bits.push(`No ${CASES[R.missCase].name.toLowerCase()} this time (${Math.round((R.chance||0)*100)}% chance)`);
    for(const id in R.cases)if(R.cases[id]>0&&CASES[id])bits.push(`+${R.cases[id]} ${CASES[id].name}`)}
  if(R.unlocked.length)bits.push('Unlocked '+R.unlocked.map(id=>(COSBY[id]||{name:id}).name).join(', '));
  return bits.join(' · ')+'.'+(R.cloud?' Saved to your account.':'');
}
const mkReward=(kind,o)=>{const R={kind,cases:{},shards:0,unlocked:[],toNext:3-(locker.prog|0),prog:locker.prog|0,...o};R.text=rewardText(R);return R};
// held = raids held in the whole game; a player who came in late (or came back) is paid from game.joinHeld on.
// left = they walked out before the end. Everything else about the game rides along for the match record.
function lockerReward(held,win,kills,left=false){
  if(demo)return null;
  const from=Math.min(held,game.joinHeld|0),mine=held-from,pct=modBonus(game.mods,'');
  const sal=Math.max(0,(player&&player.sal)|0),shards=Math.min(salvageShards(sal,mine),Math.floor(SAL_SHARD.max*(100+pct)/100));
  if(player&&shards)player.sal-=shards*SAL_SHARD.rate;   // what converts is spent, so it can't count twice
  const keys=(game.bossLog||[]).slice(game.joinBoss|0).slice(0,40),sb=Math.max(0,(game.sbN|0)-(game.joinSB|0)),dur=Math.round(game.time-(game.joinT||0));
  const claim={kind:'run',mode:game.mode,diff:pick.diff||'normal',win:!!win,held:mine,raid_from:from,raid_to:held,kills,bosses:keys.length,boss_keys:keys,shard_bosses:sb,
    salvage:sal,size:game.size||'std',duration_s:dur,game_id:game.gid,joined_s:Math.round(game.joinT||0),left_s:Math.round(game.time),left:!!left,
    upgrades:(player?player.upS:'')+':'+(game.dellLv|0),mods:game.mods||[],map:game.map,cls:player?player.cls:pick.cls};
  if(locker.cloud)return queueClaim(claim);
  // this browser's own locker (no account): the same rules as the server, minus skill points
  const st=locker.st,before=locker.cases,drops=bossDrops(keys,held,from),bshards=sb*(15+Math.floor(rnd()*16));
  locker.shards=(locker.shards|0)+shards+bshards;
  st.raids+=mine;st.drops+=kills;if(win&&from*2<=game.waves){st.wins++;if(pick.diff==='hard')st.hardWins++}
  if(game.mode==='endless')st.endless=Math.max(st.endless,held);
  locker.prog+=Math.floor(mine*(100+pct)/100);locker.cases+=Math.floor(locker.prog/3);locker.prog%=3;
  if(win&&from*2<=game.waves)locker.cases+=game.waves>=10?2:1;
  if(game.mode==='endless')locker.cases+=Math.floor(mine/5);
  for(const id in drops)caseAdd(id,drops[id]);
  addMilestones(st,keys,held,from,mine,player?player.cls:pick.cls,game.map);
  const won=win&&from*2<=game.waves?winDrop():{};
  const got=checkUnlocks();saveLocker();
  return mkReward('run',{cases:{supply:locker.cases-before,...drops,...won},shards:shards+bshards,bossShards:bshards,unlocked:got.map(c=>c.id)});
}
// a PvP match counts toward the next case like a raid does; a win is a case outright
// Base Battle and FFA don't pay Supply cases (those are co-op only). Each match rolls its mode's drop chance for
// the PvP case instead. With an account the server does the roll and the result arrives a moment later.
function pvpReward(win,kills){
  if(demo)return null;
  if(locker.cloud)return queueClaim({kind:'match',pvp:game.pvp,win:!!win,kills,duration_s:Math.round(game.time-(game.joinT||0)),game_id:game.gid,mods:game.mods||[],
    joined_s:Math.round(game.joinT||0),left_s:Math.round(game.time),map:game.map});
  const st=locker.st;
  st.drops+=kills;st.pvp=(st.pvp|0)+1;if(win)st.pvpWins=(st.pvpWins|0)+1;
  const cid=pvpCase(game.pvp),D=cid?CASES[cid].drop[game.pvp]:null,ch=(D?(win?D.win:D.loss):0)*(100+modBonus(game.mods,game.pvp))/100,cases={};let miss='';
  if(cid){if(rnd()<ch){caseAdd(cid,1);cases[cid]=1}else miss=cid}
  if(win)Object.assign(cases,winDrop());
  const got=checkUnlocks();saveLocker();
  return mkReward('match',{cases,chance:ch,missCase:miss,unlocked:got.map(c=>c.id)});
}
// what the server actually granted, as the same reward data (older servers: derived from the counts)
function claimReward(c,j){
  const cases={};
  if(j.cases&&typeof j.cases==='object')for(const id in j.cases)cases[id]=j.cases[id]|0;
  else if(c.kind==='run'){cases.supply=j.cases_granted|0;for(const b of j.bonuses||[j.bonus||{}])if(b&&b.case)cases[b.case]=(cases[b.case]|0)+(b.n|0)}
  else if(j.case_id)cases[j.case_id]=j.cases_granted|0;
  const prog=(j.locker&&j.locker.prog)|0,ids=Array.isArray(j.unlocked_ids)?j.unlocked_ids:(j.unlocked||[]).map(n=>(COS.find(x=>x.name===n)||{id:n}).id);
  const R={kind:c.kind,cases,shards:j.shards|0,unlocked:ids,prog,toNext:j.to_next!==undefined?j.to_next|0:3-prog,cloud:true,chance:j.chance||0,missCase:c.kind==='match'&&!(j.cases_granted>0)?j.case_id:'',
    bossShards:j.boss_shards|0,sp:j.skill_points|0,spToNext:j.sp_to_next|0};
  R.text=rewardText(R);return R;
}
const claimText=(c,j)=>claimReward(c,j).text;
// show a claim's outcome on the end screen if it's still up for that game, otherwise as a toast
function claimShow(c,R,big){
  const txt=typeof R==='string'?R:R.text;
  if(game.phase==='over'&&game.claimAt===c.at){$('overLoot').textContent=txt;$('overLoot').hidden=false;if(typeof R!=='string')showRewards(R)}else toast(big||'REWARDS',txt);   // the over panel fades in late; write into it even before it shows
}
const caseCount=id=>id==='supply'?locker.cases:(locker.bag[id]|0);
function caseAdd(id,n){if(id==='supply')locker.cases=Math.max(0,locker.cases+n);else locker.bag[id]=Math.max(0,(locker.bag[id]|0)+n)}
const allCases=()=>CASE_IDS.reduce((a,id)=>a+caseCount(id),0);
// rarest first against the case's weights, then any item of that rarity from that case's own pool
function rollCase(id='supply'){
  const C=CASES[id]||CASES.supply,W=Object.entries(C.weights).sort((a,b)=>a[1]-b[1]),tot=W.reduce((a,w)=>a+w[1],0);
  let x=rnd()*tot,want='c';for(const[k,v]of W){if(x<v){want=k;break}x-=v}
  let pool=COS.filter(c=>c.box===id&&c.r===want);if(!pool.length)pool=COS.filter(c=>c.box===id&&c.r==='c');
  return pool[Math.floor(rnd()*pool.length)];
}
function openCase(id='supply'){
  if(caseCount(id)<1)return null;caseAdd(id,-1);
  const it=rollCase(id),dup=owns(it.id);if(dup)locker.shards+=RAR[it.r].sh;else grant(it.id);
  saveLocker();return{it,dup,box:id};
}

