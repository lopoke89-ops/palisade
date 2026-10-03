/* ================= view ================= */
let W=0,H=0,DPR=1,TW2=32,TH2=16,WH=26,u=1,camX=0,camY=0,camSX=0,camSY=0,shake=0;
// desktop gets full-resolution scenery caches (sharper, and they blit 1:1); phones keep the smaller budget
const DESK=!matchMedia('(pointer: coarse)').matches;
const snapPx=v=>Math.round(v*DPR)/DPR;
const LQ=1;   // full size: a half-size lighting layer costs more to stretch back up than it saves
// iPhone home-screen apps with a see-through status bar report a window that is short by about the
// status bar's height, which left an empty band at the bottom. Use the real screen height there instead.
function appHeight(){
  let h=innerHeight;
  if(navigator.standalone===true&&screen&&screen.height){const full=innerWidth<=innerHeight?Math.max(screen.width,screen.height):Math.min(screen.width,screen.height);if(full>h&&full-h<120)h=full}
  return h;
}
function resize(){
  DPR=Math.min(2,window.devicePixelRatio||1);W=innerWidth;H=appHeight();
  document.documentElement.style.setProperty('--appH',H+'px');
  cv.width=Math.round(W*DPR);cv.height=Math.round(H*DPR);lc.width=Math.round(W*DPR*LQ);lc.height=Math.round(H*DPR*LQ);
  g.setTransform(DPR,0,0,DPR,0,0);lg.setTransform(DPR*LQ,0,0,DPR*LQ,0,0);
  // scale snaps to 5% steps so small height changes (iOS toolbars) don't force a rebuild of the scenery
  const S=Math.round(clamp(Math.min(W,H*1.15)/560,.72,1.35)*ZOOM*20)/20,old=u;TW2=40*S;TH2=TW2/2;WH=TH2*1.7;u=TW2/32;   // v0.9.7.1: × the desktop zoom
  const dprChanged=DPR!==resize.dpr;resize.dpr=DPR;
  return u!==old||dprChanged;
}
let resizeT=0;
// v0.9.7.1 zoom (desktops only; phones keep the screen-sized view): 70%-140% of the normal tile size. The scenery
// rebuilds once, a moment after the slider or the wheel stops, not on every step.
let ZOOM=1,zoomT=0;const ZOOM_MIN=.7,ZOOM_MAX=1.4;
function setZoom(z){const v=DESK?clamp(+z||1,ZOOM_MIN,ZOOM_MAX):1;if(v===ZOOM)return;ZOOM=v;clearTimeout(zoomT);zoomT=setTimeout(()=>{if(resize()){caches=null;resize.zooms=(resize.zooms|0)+1}},140)}
addEventListener('resize',()=>{clearTimeout(resizeT);resizeT=setTimeout(()=>{if(resize())caches=null;vignette=null;vignetteDemo=null},100)});resize();
let heightPreview=false;
const iso=(x,y,z=heightPreview?0:heightAt(x,y))=>[(x-y)*TW2+camX,(x+y)*TH2+camY-z*heightPx()];
function screenToWorld(sx,sy){
  const a=(sx-camX)/TW2;let best=null;
  const accept=(x,y)=>{if(inb(Math.floor(x),Math.floor(y))&&(!best||x+y>best.x+best.y))best={x,y}};
  // Intersect the viewing ray with the flat and connector planes analytically.
  for(let z=0;z<=2;z++){
    const b=(sy-camY+z*heightPx())/TH2,x=(a+b)/2,y=(b-a)/2;
    if(Math.abs(heightAt(x,y)-z)<.00001)accept(x,y);
  }
  if(MAP===MAPS.frost)for(let k=0;k<connectors.length;k++)if(connectors[k]){const j=(k/N)|0,y=(sy-camY-a*TH2+heightPx()*(heights[k]+1+j))/(2*TH2+heightPx()),x=y+a;if(Math.floor(x)===k%N&&Math.floor(y)===j)accept(x,y)}
  if(best)return best;const b=(sy-camY)/TH2;return{x:(a+b)/2,y:(b-a)/2};
}
// Bullets fly along the ground and hit a circle around each figure's feet, but the figure is drawn standing up.
// A cursor on someone's head used to turn into a ground point up to ~0.8 tiles behind them, so shots across the screen
// passed beside them. If the cursor is on a drawn body (feet to helmet), aim at that body's feet instead.
function bodyUnder(sx,sy,me){
  let best=null,by=-1e9;
  const test=(o,big)=>{const[x,y]=iso(o.x,o.y),k=u*FIG*(big||1);
    if(Math.abs(sx-x)<=9*k&&sy<=y+4*k&&sy>=y-37*k&&y>by){by=y;best={x:o.x,y:o.y}}};   // the front-most one wins
  if(game.pvp){for(const o of players.values())if(o!==me&&o.alive&&(game.pvp==='ffa'||o.team!==me.team))test(o,1)}
  else for(const e of enemies)if(!e.dead)test(e,e.big?1.45:1);
  return best;
}
function sdirToWorld(sx,sy){const a=sx/TW2,b=sy/TH2;let x=(a+b)/2,y=(b-a)/2;const l=Math.hypot(x,y)||1;return{x:x/l,y:y/l}}
function wdirToScreen(d){let x=(d.x-d.y)*TW2,y=(d.x+d.y)*TH2;const l=Math.hypot(x,y)||1;return{x:x/l,y:y/l}}

