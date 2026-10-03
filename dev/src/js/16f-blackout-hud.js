/* ================= v0.9.7 City Black Out: HUD, mini-map, network summary ================= */
const BO_STAGES=['gather','attack','gap','push','done'];
const boClock=t=>{const s=Math.max(0,Math.ceil(t));return`${Math.floor(s/60)}:${String(s%60).padStart(2,'0')}`};
// the phase box: GATHER / POI ATTACK / QUIET / FINAL PUSH
function boHudPhase(lab,host){
  const B=game.bo||{stage:'gather'},cls2=(on,ev)=>{lab.classList.toggle('raid',on);lab.classList.toggle('evac',!!ev)},set=(a,b)=>{if(lab.textContent!==a)lab.textContent=a;const v=$('phaseVal');if(v.textContent!==b)v.textContent=b};
  const nxt=cores.find(c=>c.next&&c.poi);
  if(game.phase==='build'){set('GATHER',`${boClock(game.timer)} · ${nxt?'first: '+nxt.poi.name.toLowerCase():'first attack'}`);cls2(false);$('skipBtn').hidden=!host;if($('skipLab').textContent!=='START NOW')$('skipLab').textContent='START NOW';return}
  $('skipBtn').hidden=true;
  if(B.stage==='attack'&&B.cur){const c=cores[B.cur.ci];set(W<700?'ATTACK':'POI ATTACK',`${c&&c.poi?c.poi.name.toLowerCase():''} · ${boClock(BO.cap-B.t)}`);cls2(true);return}
  if(B.stage==='push'||B.stage==='done'&&B.push){const F=B.push||{t:0,n:0};set(W<700?'PUSH':'FINAL PUSH',`${boClock(F.t)} · ${F.dest?'the destroyer':'boss '+Math.min(6,F.n)+'/6'}`);cls2(true,F.dest);return}
  const held=cores.filter(c=>c.poi&&!c.lost).length;
  set('QUIET',`${boClock(B.t)} · ${nxt?'next: '+nxt.poi.name.toLowerCase():held+'/8 held'}`);cls2(false);
}
// where the mini-map goes: under the vitals when they sit top-left (and under the tip box on narrow screens), else top-left
let BO_MAP=null;
function boMapBox(){const v=document.querySelector('#top .vitals'),r=v&&v.getBoundingClientRect(),desk=r&&r.top<H*.4&&r.bottom>0,
  w=Math.round(Math.min(desk?170:128,W*.3)),y=Math.round(Math.max(desk?r.bottom+12:10,W<700?(hud.tipB||0)+8:0));return{x:desk?Math.round(r.left):12,y,w,h:Math.round(w/2)}}
// the city drawn once, small: roads, buildings and the plaza in the same diamond the screen shows
function boMapImage(w,h){const key=w+'|'+N+'|'+DPR;if(BO_MAP&&BO_MAP.key===key)return BO_MAP.cv;
  const cv=document.createElement('canvas'),s=Math.min(DPR,2);cv.width=Math.ceil(w*s);cv.height=Math.ceil(h*s);const x=cv.getContext('2d');x.scale(s,s);
  const k=w/(2*N),P=(i,j)=>[(i-j)*k+w/2,(i+j)*k*.5];
  x.fillStyle='rgba(12,12,14,.82)';x.beginPath();for(const[a,b]of[[0,0],[N,0],[N,N],[0,N]]){const q=P(a,b);x.lineTo(q[0],q[1])}x.closePath();x.fill();
  for(let j=0;j<N;j++)for(let i=0;i<N;i++){const t=terr[idx(i,j)];const col=t===T_ROAD?'#5a5c60':t===T_BLDG?'#26272a':t===T_RUBBLE?'#3a342c':null;if(!col)continue;
    const q=P(i,j);x.fillStyle=col;x.fillRect(q[0]-k,q[1],k*2,k)}
  x.strokeStyle='rgba(226,180,54,.35)';x.lineWidth=1;x.beginPath();for(const[a,b]of[[0,0],[N,0],[N,N],[0,N],[0,0]]){const q=P(a,b);x.lineTo(q[0],q[1])}x.stroke();
  BO_MAP={key,cv};return cv}
function drawBlackoutHud(){
  if(!isCity()||!game.lay||game.phase==='over')return;
  const M=boMapBox(),k=M.w/(2*N),P=(i,j)=>[M.x+(i-j)*k+M.w/2,M.y+(i+j)*k*.5],t=game.time,blink=Math.sin(t*8)>0;
  g.drawImage(boMapImage(M.w,M.h),M.x,M.y,M.w,M.h);
  // POIs: lit while held, red while attacked, dark once lost; the next target pulses
  for(const c of cores){const q=P(c.i+.5,c.j+.5),r=c.poi?(c.poi.major?3.4:2.6):4;
    if(!c.poi){g.fillStyle='#e2b436';g.fillRect(q[0]-r,q[1]-r,r*2,r*2);continue}
    g.fillStyle=c.lost?'#3a3a3a':c.attack?(blink?'#ff4a3a':'#8a2a20'):'#ffd88a';g.beginPath();g.arc(q[0],q[1],r,0,Math.PI*2);g.fill();
    if(c.lost){g.strokeStyle='#777';g.lineWidth=1;g.beginPath();g.moveTo(q[0]-r,q[1]-r);g.lineTo(q[0]+r,q[1]+r);g.moveTo(q[0]+r,q[1]-r);g.lineTo(q[0]-r,q[1]+r);g.stroke()}
    if(c.next&&!c.attack){g.strokeStyle=`rgba(255,120,80,${.5+.5*Math.sin(t*6)})`;g.lineWidth=1.5;g.beginPath();g.arc(q[0],q[1],r+3,0,Math.PI*2);g.stroke()}}
  for(const e of enemies)if(e.type==='boss'){const q=P(e.x,e.y),s=e.boss==='destroyer'?5:3.5;g.fillStyle=e.boss==='destroyer'?'#ff6a2a':'#ff3a2a';g.beginPath();g.moveTo(q[0],q[1]-s);g.lineTo(q[0]+s,q[1]);g.lineTo(q[0],q[1]+s);g.lineTo(q[0]-s,q[1]);g.closePath();g.fill()}
  for(const o of players.values())if(o!==player&&(o.alive||o.downed)){const q=P(o.x,o.y);g.fillStyle=o.alive?'#8fd0ff':'#d65a3a';g.beginPath();g.arc(q[0],q[1],2,0,Math.PI*2);g.fill()}
  if(player){const q=P(player.x,player.y);g.fillStyle='#fff';g.strokeStyle='#000';g.lineWidth=1;g.beginPath();g.arc(q[0],q[1],2.6,0,Math.PI*2);g.fill();g.stroke()}
  // a POI under attack off screen gets an arrow at the edge, like the evac site
  const A=cores.find(c=>c.attack&&c.poi);if(A){const c=iso(A.i+.5,A.j+.5),top=110;
    if(!(c[0]>20&&c[0]<W-20&&c[1]>top&&c[1]<H-20)){const ex=clamp(c[0],26,W-26),ey=clamp(c[1],top+14,H-26),a=Math.atan2(c[1]-H/2,c[0]-W/2),pz=.8+.2*Math.sin(t*6);
      g.save();g.translate(ex,ey);g.rotate(a);g.scale(1.9*pz,1.9*pz);g.fillStyle='#ff5a3a';g.strokeStyle='rgba(12,10,8,.8)';g.lineWidth=1.5;g.beginPath();g.moveTo(9,0);g.lineTo(-5,-7);g.lineTo(-2,0);g.lineTo(-5,7);g.closePath();g.stroke();g.fill();g.restore();
      label(A.poi.name,ex,ey+(ey>H/2?-20:24),'#ff8a6a',10)}}
}
/* ---------- network: the run's summary for guests (and rejoins) ---------- */
// [stage, t, attacked POI (core index, -1 none), lost bits, next bits, dark, held, lost, push t, push n, Destroyer up, Destroyer killed]
function boSnap(){const B=game.bo;if(!B)return null;let lost=0,next=0;cores.forEach((c,i)=>{if(c.lost)lost|=1<<i;if(c.next)next|=1<<i});const F=B.push;
  return[BO_STAGES.indexOf(B.stage),+(B.stage==='gather'?0:B.t).toFixed(2),B.cur?B.cur.ci:-1,lost,next,game.dark?1:0,B.held|0,B.lost|0,F?+F.t.toFixed(2):0,F?F.n:0,F&&F.dest?1:0,B.destroyer?1:0]}
function boApply(a){if(!Array.isArray(a))return;const B=game.bo||(game.bo={order:[],n:0,q:[],log:[]});
  B.stage=BO_STAGES[a[0]]||'gap';B.t=a[1]||0;B.cur=a[2]>=0?{ci:a[2]}:null;B.held=a[6]|0;B.lost=a[7]|0;B.destroyer=!!a[11];
  B.push=a[0]>=3?{t:a[8],n:a[9],dest:!!a[10]}:null;game.dark=!!a[5];
  cores.forEach((c,i)=>{if(!c.poi)return;const L=!!(a[3]&1<<i);if(L&&!c.lost)c.lostAt=game.time;c.lost=L;c.next=!!(a[4]&1<<i);c.attack=a[2]===i})}
// what's near: on the city each guest gets full rows for raiders within this many tiles of them (bosses always)
const BO_NEAR=22;
function boNearRows(rows,p){if(!p)return rows;
  return rows.filter(r=>{const c=ECODE[r[PE.type]]||'';return c.startsWith('boss:')||Math.hypot(r[PE.x]-p.x,r[PE.y]-p.y)<BO_NEAR})}
