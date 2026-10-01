// Called at the catalog's existing initialization points, before saved equipment is parsed.
function registerWinterLooks(){
  for(const p of WINTER_PAIRS)SKINS[p[0]]={body:p[6],vest:p[7],pants:p[8],hat:p[7],winter:p[0],winterTrim:p[0]==='aurorasovereign'?'#83ead8':p[0]==='rimewarden'?'#c5efff':'#e2d9b9'};
  for(const p of WINTER_PAIRS)SAHUR_HATS.add(p[2]);
  for(const [id,,r,body,vest,pants]of WINTER_MODELS)SKINS[id]={body,vest,pants,hat:vest,head:body,winterModel:id,...(r==='g'?{aura:'frostborn'}:{})};
}
function registerWinterTrails(){
  for(const [id,name,r,col]of WINTER_TRACERS)TRAILS[id]={c:col,w:r==='g'?1.35:1,len:r==='g'?1.7:1.15,winter:id,pk:id==='solsticecomet'?'yulelight':id==='auroralance'?'snowdust':'ice',pr:r==='g'?.8:r==='l'?.18:.06,grad:id==='candyline'?['#fff5e4','#e3465c','#fff5e4']:id==='auroralance'?['#d2ffef','#77efd7','#b79dff']:id==='solsticecomet'?['#fff7db','#ffe097','#9beaff']:undefined};
}
function registerWinterCosmetics(){
  const add=(cat,key,name,r,need=null)=>COS.push({id:cat+':'+key,cat,key,name,r,description:WINTER_ART[key],src:need?'unlock':'case',box:need?null:'winter',need,how:need?`Reach ${Object.values(need)[0]} ${key==='rimewarden'?'Rime Colossus defeats':'winter milestone progress'}`:'Found in Winter Cases',price:null,collection:'winter'});
  for(const p of WINTER_PAIRS){add('skin',p[0],p[1],p[4],p[9]?{[p[9]]:p[10]}:null);add('hat',p[2],p[3],p[5])}
  for(const [key,name,r]of WINTER_TRACERS)add('trail',key,name,r);
  for(const [key,name,r]of WINTER_FX)add('fx',key,name,r);
  for(const [key,name,r,,,,description]of WINTER_MODELS){add('skin',key,name,r);COS[COS.length-1].description=description}
  for(const [id,st,title,kind,steps]of [['frost','map_frost','FROSTPEAK','map',[250,500,1000,2500]],['rime','boss_rime','THE RIME COLOSSUS','boss',[25,50,100,250]]]){
    const ps=WINTER_PAIRS.filter(p=>p[9]===st),unit=kind==='map'?'raids held on Frostpeak':'Rime Colossi beaten';
    const L={id,st,title,kind,steps,unit,how:n=>`Reach ${n} ${unit}`,items:ps.map(p=>['skin',p[0],p[1]])};LADDERS.push(L);
    for(const p of ps){const it=COS.find(c=>c.id==='skin:'+p[0]);it.ladder=id;it.how=L.how(p[10])}
  }
}
function registerWinterBackgrounds(){
  WINTER_BG.forEach(([id,name,r,animated],n)=>{BGS[id]={name,r,description:WINTER_ART[id],src:'case',box:'winter',collection:'winter',animated,
    draw(c,w,h,t){paintWinterBackground(c,w,h,animated&&!reduceMotion()?t:0,n,animated&&!reduceMotion())}};if(!animated)BGS[id].still=0});
}
