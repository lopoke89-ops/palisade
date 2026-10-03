/* v0.9.6.4 Hybrid Theory Case: catalog registration, called at the catalog's existing initialization points. */
function registerHybridLooks(){
  for(const [key,,r,jersey,shorts,trim]of HYBRID_SKINS)SKINS[key]={body:jersey,vest:jersey,pants:shorts,hat:jersey,jersey:true,jtrim:trim,...(r==='g'?{aura:'ghybrid'}:{})};
}
function registerHybridCosmetics(){
  const add=(cat,key,name,r)=>COS.push({id:cat+':'+key,cat,key,name,r,description:HYBRID_ART[key],src:'case',box:'hybrid',need:null,how:'Found in Hybrid Theory Cases',price:null,collection:'hybrid'});
  for(const [key,name,r]of HYBRID_SKINS)add('skin',key,name,r);
  for(const [key,name,r]of HYBRID_HATS)add('hat',key,name,r);
  for(const [key,name,r]of HYBRID_FX)add('fx',key,name,r);
}
function registerHybridBackgrounds(){
  HYBRID_BG.forEach(([id,name,r,pal],n)=>{BGS[id]={name,r,description:HYBRID_ART[id],src:'case',box:'hybrid',collection:'hybrid',animated:true,
    draw(c,w,h,t){paintHybridBackground(c,w,h,reduceMotion()?0:t,n,pal,!reduceMotion())}}});
}
// the gold jerseys share one feet aura: a gold pool and ring, a slow orbit and rising stars
Object.assign(AURAS,{ghybrid:[{p:'pool',col:'#ffd24a',a:.22},{p:'ring',col:'#ffd24a'},{p:'orbit',n:3,col:'#fff0b0',shape:'dot',size:1.2,glow:true,sp:1.1},{p:'rise',n:5,cols:GOLDS,shape:'star',sp:.45}]});
