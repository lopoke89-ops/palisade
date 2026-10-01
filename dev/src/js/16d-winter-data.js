/* Winter collection: stable IDs, art identities and the acquisition contract. */
const WINTER_PAIRS=[
  ['snowline','Snowline Scout','snowgoggles','Snowline Goggles','r','c','#e5eaf0','#5b7489','#637985','map_frost',250],
  ['summitranger','Summit Ranger','ushanka','Ranger Ushanka','e','r','#35544b','#7b8772','#283f3c','map_frost',500],
  ['glacierengineer','Glacier Engineer','surveyhelm','Surveyor Helmet','l','r','#718d9d','#31495c','#4a6577','map_frost',1000],
  ['polarrescue','Polar Rescue','rescuehood','Rescue Hood','r','e','#db713e','#e5e9df','#475a68','boss_rime',25],
  ['evergreen','Evergreen Sentinel','pinecrown','Evergreen Crown','e','e','#284f42','#8b7551','#293b30','boss_rime',50],
  ['yuletideqm','Yuletide Quartermaster','yulecap','Quartermaster Cap','r','c','#873f47','#dbc58b','#423641',null,0],
  ['gingergren','Gingerbread Grenadier','icinghelm','Icing Helmet','e','c','#b47f48','#f0e4c9','#885d38',null,0],
  ['nutcracker','Nutcracker Vanguard','shako','Parade Shako','l','l','#aa4144','#d6be71','#263a57','boss_rime',100],
  ['rimewarden','Rimebound Warden','rimecrest','Rime Crest','g','l','#779eae','#c3e8ee','#35556c','boss_rime',250],
  ['aurorasovereign','Aurora Sovereign','aurorahalo','Aurora Halo','g','g','#343c65','#65cfc6','#263553','map_frost',2500]
];
const WINTER_HATS=Object.fromEntries(WINTER_PAIRS.map(p=>[p[2],p]));
const WINTER_TRACERS=[['snowstreak','Snowstreak','r','#e7f5ff'],['glaciershard','Glacier Shard','r','#9fddf1'],['candyline','Candyline','e','#ed7a8b'],['polarspark','Polar Spark','l','#b4eafb'],['auroralance','Aurora Lance','g','#84ffd9'],['solsticecomet','Solstice Comet','g','#ffeab0']];
const WINTER_FX=[['snowpuff','Snow Puff','r'],['frostfracture','Frost Fracture','r'],['ornamentpop','Ornament Pop','e'],['winterbloom','Winter Bloom','l'],['borealiscollapse','Borealis Collapse','g'],['solsticenova','Solstice Supernova','g']];
const WINTER_BG=[['summitcommand','Summit Command','c',false],['frozenriver','Frozen River Crossing','r',false],['snowquarry','Snowed-In Quarry','r',false],['skistation','Abandoned Ski Station','e',false],['winterdepot','Winter Supply Depot','c',false],['lanternoutpost','Lanternlit Outpost','e',false],['aurorafrostpeak','Aurora Over Frostpeak','l',true],['whiteouttower','Whiteout Watchtower','e',true],['yulehangar','Yuletide Hangar','l',true],['midnightevac','Midnight Evacuation','g',true]];
const WINTER_ART={
 snowline:'White insulated scout jacket, wrapped boots and climbing straps.',snowgoggles:'Amber snow lenses in a compact insulated frame.',
 summitranger:'Deep green mountain kit, rope harness and reinforced shoulders.',ushanka:'Fur-lined field cap with folded winter ear flaps.',
 glacierengineer:'Blue-gray utility suit, repair tools and frost-marked plates.',surveyhelm:'Angular survey helmet with a bright expedition lamp.',
 polarrescue:'Rescue-orange parka, reflective trim and medical packs.',rescuehood:'Structured orange storm hood with a pale insulated face opening.',
 evergreen:'Layered green armor with pine details and bark-toned straps.',pinecrown:'A branching evergreen crown with restrained pine accents.',
 yuletideqm:'Burgundy supply coat with brass hardware and field pouches.',yulecap:'Fitted burgundy seasonal cap with a pale winter cuff.',
 gingergren:'Biscuit-toned combat plates with inset icing seams and candy accents.',icinghelm:'Shaped biscuit helmet edged in pale icing.',
 nutcracker:'Red and navy parade armor with sculpted plates and brass fasteners.',shako:'Tall red military shako with brass parade trim.',
 rimewarden:'Angular expedition armor with fractured ice plates and luminous frost edges.',rimecrest:'A jagged translucent ice crest on an expedition helmet.',
 aurorasovereign:'Premium polar armor with aurora trim and a luminous chest crest.',aurorahalo:'A segmented aurora halo with gentle motion; still with reduced motion.',
 snowstreak:'Fine white rounds with sparse snowflake motes.',glaciershard:'Translucent blue ice fragments along a short trail.',candyline:'A restrained red-and-white candy spiral.',polarspark:'Cool sparks with a crystalline tail.',auroralance:'Layered mint and violet aurora ribbon with an icy core.',solsticecomet:'Warm gold core, winter-star accents and a crisp frost wake.',
 snowpuff:'A compact snow burst that fades quickly.',frostfracture:'Small ice crystals break into readable blue shards.',ornamentpop:'A brief seasonal ornament burst with restrained fragments.',winterbloom:'An expanding snowflake and a ring of frost petals.',borealiscollapse:'Aurora orbits collapse into a crystalline ring.',solsticenova:'A gold-white winter starburst, ice halo and trailing snow stars.',
 summitcommand:'A snowy summit outpost above three mountain ridges.',frozenriver:'An icy supply crossing with branching river cracks.',snowquarry:'Snow-covered quarry terraces and an abandoned crane.',skistation:'A deserted cable lift suspended above snowy pines.',winterdepot:'Expedition supply crates beside a sheltered mountain depot.',lanternoutpost:'A warm lanternlit outpost in the winter dusk.',aurorafrostpeak:'Aurora ribbons and sparse drifting snow over Frostpeak.',whiteouttower:'Wind-driven snow and a slow watchtower beacon.',yulehangar:'Warm seasonal hangar lights and gentle steam.',midnightevac:'A midnight landing pad, sweeping searchlights and a distant helicopter.'
};
