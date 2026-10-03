/* v0.9.6.4 Hybrid Theory Case: stable ids, palettes and art notes (Big U's prompt, October 3).
   Skins are palettes on one jersey body (sleeveless jersey, shorts, bare arms and calves, sneakers): jersey, shorts, trim.
   Parody names only: no crests, no real team names, no league marks. Tiers are as given in the prompt. */
const HYBRID_SKINS=[   // [key, name, rarity, jersey, shorts, trim]
  ['hb_lizards','Washington Lizards','c','#002B5C','#E31837','#C4CED4'],['hb_placers','Indiana Placers','c','#002D62','#FDBB30','#BEC0C2'],
  ['hb_vets','Brooklyn Vets','c','#111111','#F4F4F4','#A1A1A4'],['hb_rings','Sacramento Rings','c','#5A2D81','#63727A','#000000'],
  ['hb_jabs','Utah Jabs','c','#002B5C','#F9A01B','#00471B'],['hb_drizzlies','Memphis Drizzlies','c','#5D76A9','#12173F','#F5B112'],
  ['hb_saversicks','Dallas Saversicks','r','#0053BC','#002B5E','#B8C4CA'],['hb_relicans','New Orleans Relicans','r','#0C2340','#B4975A','#C8102E'],
  ['hb_pulls','Chicago Pulls','r','#CE1141','#111111','#FFFFFF'],['hb_ducks','Milwaukee Ducks','r','#00471B','#EEE1C6','#0077C0'],
  ['hb_worriers','Golden State Worriers','r','#1D428A','#FFC72C','#FFFFFF'],['hb_slippers','Los Angeles Slippers','r','#C8102E','#1D428A','#BEC0C2'],
  ['hb_sailglazers','Portland Sail Glazers','e','#E03A3E','#111111','#FFFFFF'],['hb_beat','Miami Beat','e','#98002E','#F9A01B','#111111'],
  ['hb_cornets','Charlotte Cornets','e','#1D1160','#00788C','#A1A1A4'],['hb_fixers','Philadelphia Fixers','e','#006BB6','#ED174C','#002B5C'],
  ['hb_static','Orlando Static','e','#0077C0','#C4CED4','#111111'],['hb_runs','Phoenix Runs','e','#1D1160','#E56020','#111111'],
  ['hb_squawks','Atlanta Squawks','l','#E03A3E','#C1D32F','#26282A'],['hb_captors','Toronto Captors','l','#CE1141','#111111','#A1A1A4'],
  ['hb_cinderwolves','Minnesota Cinderwolves','l','#0C2340','#78BE20','#236192'],['hb_lockets','Houston Lockets','l','#CE1141','#111111','#C4CED4'],
  ['hb_navaliers','Cleveland Navaliers','l','#6F263D','#FFB81C','#041E42'],['hb_bricks','New York Bricks','l','#006BB6','#F58426','#BEC0C2'],
  ['hb_bakers','Los Angeles Bakers','g','#552583','#FDB927','#111111'],['hb_budgets','Denver Budgets','g','#0E2240','#FEC524','#8B2131'],
  ['hb_kelpies','Boston Kelpies','g','#007A33','#BA9653','#FFFFFF'],['hb_whistlers','Detroit Whistlers','g','#1D42BA','#C8102E','#BEC0C2'],
  ['hb_burrs','San Antonio Burrs','g','#111111','#C4CED4','#FFFFFF'],['hb_hummers','Oklahoma City Hummers','g','#007AC1','#EF3B24','#FDBB30']
];
const HYBRID_HATS=[['shades','Sunglasses','c'],['yamaka','Yamaka','r'],['ballhelm','Ball Helm','r'],['gridhelm','Grid Helm','e'],
  ['dunce','Dunce Cone','e'],['prop','Prop Hat','c'],['conductor','Conductor Cap','r'],['skullhelm','Skull Helm','l']];
const HYBRID_HAT_SET=new Set(HYBRID_HATS.map(h=>h[0]));
const HYBRID_FX=[['leaf','Weed Leaf','r'],['bands','Money Explosion','e'],['swish','Hoop Swish','l'],['nuke','Nuke Pop','g'],['poop','Poop Pop','c'],
  ['demon','Purple Demon','e'],['hundo','100 Pop','r'],['fire','Fire Pop','r'],['eight','8=D Pop','c'],['sixty','67 Pop','c'],['zzz','Bed Nap','c']];
const HYBRID_BG=[   // [key, name, rarity, palette: ground, accent, second accent]
  ['yardneon','Yard Neon','g',['#0E2240','#FEC524','#3a5a8c']],['voltgrid','Volt Grid','g',['#0a0a0a','#C1D32F','#E03A3E']],
  ['viceblock','Vice Block','g',['#0a0a0a','#FF4FA3','#5ED0F5']],['crowncity','Crown City','g',['#2a1446','#FDB927','#552583']],
  ['peachwire','Peach Wire','l',['#0a0a0a','#E39A6A','#f3e6d4']],['lakeblocks','Lake Blocks','l',['#0C2340','#78BE20','#4fd3b8']],
  ['fiestastrip','Fiesta Strip','l',['#0a0a0a','#F26B8A','#2EC4B6']],['oaknight','Oak Night','l',['#1d140c','#F3E6D4','#c9a13a']]
];
const HYBRID_ART={
  shades:'Square black shades with a white glint.',yamaka:'A small plain black cap on the crown.',ballhelm:'An orange ball-pattern helmet with black seams.',
  gridhelm:'A navy grid helmet with a gray facemask.',dunce:'A tall cream dunce cone with a red band.',prop:'A beanie with a little propeller on top.',
  conductor:'A navy conductor cap with a gold band and brim.',skullhelm:'A bone-white skull helmet with dark sockets.',
  leaf:'Green and lime leaves burst, drift and fade.',bands:'Bills and coins pop and flutter down.',swish:'An orange rim and white net; the ball drops through.',
  nuke:'A white flash, an orange mushroom and a gray ring.',poop:'A brown swirl and stink puffs.',demon:'Purple horns and eyes over a small flame ring.',
  hundo:'White 100 stamps scale up and scatter.',fire:'Orange-yellow flame tongues, then embers.',eight:'A flat peach comic shape, then a white flash.',
  sixty:'Block numerals 6 and 7 in white and volt, then they crack.',zzz:'A flat bed, three Zs rise, a soft blue fade.',
  yardneon:'Block towers on navy with slow gold neon streaks.',voltgrid:'A black skyline with volt and red grid streaks.',viceblock:'Black blocks under pink and cyan neon.',
  crowncity:'Purple towers crowned in gold light.',peachwire:'Peach wires strung between cream-lit blocks.',lakeblocks:'Midnight blocks under a green aurora.',
  fiestastrip:'A pink and teal neon strip at night.',oaknight:'Cream and brown towers with gold windows.'
};
for(const s of HYBRID_SKINS)HYBRID_ART[s[0]]=`${s[1]}: a sleeveless jersey and shorts in their colors, trim on the neck, hem and sides.`;
