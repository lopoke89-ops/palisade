/* ================= network recording ================= */
// On the host, every sound, particle and floating word is also queued and shipped to the
// other phones in the next snapshot, so everyone sees and hears the same fight.
let replaying=false,bulletSeq=0;
function rec(e){
  if(NET.mode!=='host'||!NET.inGame||demo||replaying)return;
  const q=NET.fxq,l=q[q.length-1];   // the same particle again at the same spot: bump a count instead of a new entry
  if(e[0]==='e'&&l&&l[0]==='e'&&l[1]===e[1]&&l[2]===e[2]&&l[3]===e[3]&&l[4]===e[4]&&l[5]===e[5]){l[6]=(l[6]||1)+1;return}
  q.push(e);
}
// a burst of particles scattered around a point: one entry on the wire, the guest scatters its own
function emitSpread(x,y,sp,z0,z1,kind,mat,n){
  rec(['E',r2(x),r2(y),sp,Math.round(z0/u),Math.round(z1/u),kind,mat|0,n]);
  const k=replaying;replaying=true;try{for(let q=0;q<n;q++)emit(x+(rnd()-.5)*sp,y+(rnd()-.5)*sp,z0+(z1-z0)*rnd(),kind,mat)}finally{replaying=k}
}
const r2=v=>Math.round(v*100)/100;
function personal(p,name){   // a sound (or, for ~names, a screen feel) only that soldier's screen gets
  if(p.id===myId)feel(name);
  else rec(['p',p.id,name]);
}
function toastAll(big,small){rec(['t',big,small]);toast(big,small)}
function toastTo(p,big,small){if(p.id===myId)toast(big,small);else if(NET.mode==='host')NET.sendTo(p.id,{t:'t',b:big,s:small||''})}
function addFlash(f){rec(['h',r2(f.x),r2(f.y),f.r,f.muzzle?1:0,f.life]);flashes.push(f)}

