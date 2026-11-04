/* v0.12 THE UNDERSTRIP CASE: catalog registration, called at the catalog's existing initialization points (as the Winter
   and Hybrid Theory cases are). The items, tiers and art notes are in 16i-understrip-models.js. */
function registerUnderstripLooks(){
  for(const [key,,r,body,vest,pants,head,hat,open]of US_SKINS)SKINS[key]={body,vest,pants,head,hat,usModel:key,...(open?{headwear:{}}:{}),
    ...(key==='visitor'||key==='custodian'?{usHead:true}:{}),...(r==='g'?{aura:'gvisitor'}:{})};
}
// tracers: the stamp's colours here; their decorations (chips, coins, the ring, the wobble) are 20d's
function registerUnderstripTrails(){
  const T={chips:{c:'#e8e2d0',grad:['#ffffff','#e8e2d0','#c42a3a'],w:1.1,len:1.2},neontube:{c:'#ff5ad8',grad:['#ffffff','#ff8ae4','#ff5ad8'],edge:'#5ab0ff',w:1.05,len:1.3},
    jackpotcoins:{c:'#ffd24a',grad:['#fff6c8','#ffd24a','#e2a030'],w:1.1,len:1.25,pk:'goldsp',pr:.22},tractorbeam:{c:'#b8ffa8',grad:['#f0fff0','#b8ffa8','#5ad86a'],w:1.35,len:1.5},
    saucerbolt:{c:'#7cff6b',grad:['#f4ffe8','#9aff7a','#3ad84a'],w:1.6,len:1.1,pr:.12,pk:'tealdust'}};
  for(const [id,name]of US_TRAILS)TRAILS[id]={...T[id],name,us:id};
}
function registerUnderstripCosmetics(){
  const how='Found in Understrip Cases';
  const add=(cat,key,name,r,description)=>COS.push({id:cat+':'+key,cat,key,name,r,description,src:'case',box:'understrip',need:null,how,price:null,collection:'understrip'});
  for(const [key,name,r,,,,,,,note]of US_SKINS)add('skin',key,name,r,note);
  for(const [key,name,r,note]of US_HATS)add('hat',key,name,r,note);
  for(const [key,name,r,,note]of US_TRAILS)add('trail',key,name,r,note);
  for(const [key,name,r,note]of US_FX)add('fx',key,name,r,note);
}
function registerUnderstripBackgrounds(){
  for(const [id,name,r,description]of US_BG){BGS[id]={name,r,description,src:'case',box:'understrip',collection:'understrip',animated:true,
    draw(c,w,h,t){paintUnderstripBackground(c,w,h,reduceMotion()?0:t,id,!reduceMotion())}}}
}
