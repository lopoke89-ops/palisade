/* ---------- Operation Whiteout and the Rime Colossus ---------- */
const CAMPAIGN={waves:13,raids:3,maps:['yard','river','quarry','frost'],bosses:['whitebutcher','whiteferryman','whiteforeman','rime'],
  story:['Secure the Yard and recover the mountain evacuation route.','Cross Riverbend and recover the stranded supply convoy.','Secure quarry power for the summit beacon.','Hold Frostpeak. Break the Rime Colossus and signal evacuation.']};
const campaign=()=>!!game&&!game.pvp&&game.mode==='campaign';
const finalWave=()=>campaign()?CAMPAIGN.waves:BLITZ.waves;
const campaignChapter=w=>Math.min(3,Math.floor(Math.max(0,w-1)/3));
const campaignMods=ids=>ids.filter(id=>!['bossrush','nightmare','blitzclock','hotlz','lockdown','scorched','barrage','onejob'].includes(id));
function chapterCredit(from,to){const out={yard:0,river:0,quarry:0,frost:0};for(let w=from+1;w<=Math.min(13,to);w++)out[CAMPAIGN.maps[campaignChapter(w)]]++;return out}
function changeChapter(ch,guest=false){
  if(ch===game.chapter&&game.map===CAMPAIGN.maps[ch])return;
  const hp=core.hp,max=core.max,L=layMap(CAMPAIGN.maps[ch],game.size,'');
  walls=new Array(N*N).fill(null);debris=new Int8Array(N*N);dist=new Float32Array(N*N);nodes=L.nodes;
  for(const[list,mat,ratio,char]of L.ruins)for(const[i,j]of list){const w=makeWall(mat,false,ratio);w.char=char;walls[idx(i,j)]=w}
  core={team:'',i:L.core[0],j:L.core[1],hp,max,flash:0};cores=[core];coreK=idx(core.i,core.j);coreKs=new Set([coreK]);
  game.map=CAMPAIGN.maps[ch];game.chapter=ch;game.lay=L;game.flood={t:0,warned:false};game.lockC=null;
  enemies=[];bullets=[];lobs=[];charges=[];rockets=[];fires=[];arcs=[];arcHaz.length=0;parts=[];flashes=[];floats=[];sacks=[];frostFields=[];
  let s=0;for(const p of players.values()){
    const spot=spawnNearCore();p.x=spot[0]+(s%2)*.3;p.y=spot[1]+Math.floor(s/2)*.22;p.z=heightAt(p.x,p.y);p.tp++;p.tx=p.x;p.ty=p.y;s++;
  }
  [qm.x,qm.y]=spawnNearCore();qm.z=heightAt(qm.x,qm.y);qm.tx=qm.x;qm.ty=qm.y;qm.next=-1;qm.pathT=0;qm.job='';qm.foe=null;
  caches=null;TERR_SPR.clear();computeFlow();flowDirty=false;NET.wlSent=null;NET.piSent=null;
  if(!guest)toastAll(`CHAPTER ${ch+1} · ${MAP.name}`,CAMPAIGN.story[ch]+' Your upgrades and supplies travel with you. Summit/core damage carries forward.');
}
function campaignAdvance(){
  if(!campaign())return false;
  if((game.wave===3||game.wave===6||game.wave===9)&&game.chapter<game.wave/3){changeChapter(game.wave/3);startBuild(30+game.Df.build);toastAll(`CHAPTER ${game.chapter+1} · ${MAP.name}`,CAMPAIGN.story[game.chapter]+' Prepare at the core.');return true}
  return false;
}
Object.assign(BOSSES,{
  rime:{name:'THE RIME COLOSSUS',hp:860,speed:1.2,scan:11,bounty:50,col:'#9cebdc',think:thinkRime,box:'winter',cases:2,
    look:{body:'#678c9a',vest:'#243f50',pants:'#344e60',head:'#bedce5',helmet:'#84cad8',pack:'#375d66',bandana:'#95f0bc',gl:22,weapon:'drill',nogun:true,winterBoss:true},
    intro:'Cracking ice marks a huge rupture. Step clear. His marked dash leaves poisoned frost that slows everyone crossing it.'},
  whitebutcher:{base:'butcher',campaign:true,name:'THE FROSTBOUND BUTCHER',hp:880,speed:2.05,scan:10,bounty:50,col:'#9be5ff',think:thinkWhiteButcher,box:'winter',cases:1,
    look:{...BOSSES.butcher.look,body:'#54788a',vest:'#1f394b',helmet:'#b9d8e2',bandana:'#98e3ed',weapon:'swordb'},intro:'A lunging ice arc and a marked frost rupture. Step sideways after his charge.'},
  whiteferryman:{base:'ferryman',campaign:true,name:'THE ICEBOUND FERRYMAN',hp:820,speed:1.45,scan:12,bounty:50,col:'#9ce6d1',think:thinkWhiteFerryman,raft:true,box:'winter',cases:1,
    look:{...BOSSES.ferryman.look,body:'#456774',vest:'#233f49',bandana:'#a5eedc'},intro:'Harpoons and boarding crews guard the river. A marked frost rupture forces you off his landing zone.'},
  whiteforeman:{base:'foreman',campaign:true,name:'THE PERMAFROST FOREMAN',hp:900,speed:1.35,scan:10,bounty:50,col:'#e6eeb6',think:thinkWhiteForeman,box:'winter',cases:1,
    look:{...BOSSES.foreman.look,body:'#536d7c',vest:'#b9c999',helmet:'#dbe9ad'},intro:'A fast marked charge and frost ruptures. Bait him into a wall to leave him dazed.'}
});
ECODE.push('boss:rime','boss:whitebutcher','boss:whiteferryman','boss:whiteforeman');
function winterRupture(e,Df,r=3.4){
  for(const a of allies())if(a.alive&&heightDist(e.lx,e.ly,a.x,a.y)<r)hurtAlly(a,30*Df.dmg);
  for(const c of cores)if(heightDist(e.lx,e.ly,c.i+.5,c.j+.5)<r)hurtStake(c,18*Df.dmg);
  for(let i=Math.floor(e.lx-r);i<=e.lx+r;i++)for(let j=Math.floor(e.ly-r);j<=e.ly+r;j++)if(inb(i,j)&&heightDist(e.lx,e.ly,i+.5,j+.5)<r&&walls[idx(i,j)])damageWall(idx(i,j),35*MAT[walls[idx(i,j)].mat].blast);
  ringFx(e.lx,e.ly,.2,r,.7,'#c0fff2','#426d91',2.5);sfx('bigboom',e.lx,e.ly);addShake(e.lx,e.ly,7);
  for(let q=0;q<12;q++)emit(e.lx+(rnd()-.5)*r,e.ly+(rnd()-.5)*r,WH*.6,'spark');
}
function winterVariant(e,dt,tgt,mv,aimAt,Df,base){
  e.winterT=(e.winterT??8)-dt;
  if(e.st===101){e.stT-=dt;aimAt(e.lx,e.ly);if(e.stT<=0){winterRupture(e,Df,2.3);e.st=0;e.cd=1;e.winterT=e.hp<e.max*.35?6:9}return{eng:true,mv:null}}
  if(!e.st&&e.winterT<=0&&e.foe){
    if(enemies.some(o=>o!==e&&!o.dead&&(o.st===101||o.st===102))){e.winterT=.6;return base(e,dt,tgt,mv,aimAt,Df)}
    e.st=101;e.stT=e.stM=1.5;e.lx=e.foe.x;e.ly=e.foe.y;sfx('charge',e.x,e.y);return{eng:true,mv:null}
  }
  return base(e,dt,tgt,mv,aimAt,Df);
}
function thinkWhiteButcher(e,dt,tgt,mv,aimAt,Df){return winterVariant(e,dt,tgt,mv,aimAt,Df,thinkBlueButcher)}
function thinkWhiteFerryman(e,dt,tgt,mv,aimAt,Df){return winterVariant(e,dt,tgt,mv,aimAt,Df,thinkFerryman)}
function thinkWhiteForeman(e,dt,tgt,mv,aimAt,Df){return winterVariant(e,dt,tgt,mv,aimAt,Df,thinkBulldozer)}
function thinkRime(e,dt,tgt,mv,aimAt,Df){
  const phase=e.hp<e.max*.35?2:e.hp<e.max*.7?1:0;
  e.rimePhase=phase;e.ab=(e.ab??3)-dt;
  if(e.st===101){e.stT-=dt;aimAt(e.lx,e.ly);if(e.stT<=0){winterRupture(e,Df);e.st=0;e.cd=1.2;e.ab=6-phase}return{eng:true,mv:null}}
  if(e.st===102){e.stT-=dt;aimAt(e.lx,e.ly);if(e.stT<=0){e.st=103;e.stT=1.05;e.dashHits=new Set();e.frostD=0;sfx('slash',e.x,e.y)}return{eng:true,mv:null}}
  if(e.st===103){
    e.stT-=dt;const dx=e.lx-e.x,dy=e.ly-e.y,l=Math.hypot(dx,dy)||1,step=Math.min(l,7.2*dt*Math.max(.5,slowAt(e.x,e.y)*(1-(e.slowT>0?e.slowPct||0:0)))),x=e.x,y=e.y;
    moveEnt(e,dx/l*step,dy/l*step,false);e.walk+=dt*15;e.frostD+=Math.hypot(e.x-x,e.y-y);
    if(e.frostD>=.32){addFrost(e.x,e.y);e.frostD=0}
    for(const a of allies())if(a.alive&&!e.dashHits.has(a)&&heightDist(e.x,e.y,a.x,a.y)<.85){e.dashHits.add(a);hurtAlly(a,26*Df.dmg)}
    if(l<.4||e.stT<=0||Math.hypot(e.x-x,e.y-y)<.01){e.st=0;e.cd=1.3;e.ab=5.5-phase}
    return{eng:true,mv:null};
  }
  const f=e.foe||tgt;
  if(!e.st&&e.ab<=0&&f&&heightDist(e.x,e.y,f.x,f.y)<10){
    if(enemies.some(o=>o!==e&&!o.dead&&(o.st===101||o.st===102))){e.ab=.6;return{eng:false,mv}}
    e.shots=(e.shots||0)+1;
    const dashTurn=phase===2?e.shots%3!==1:e.shots%2===0;
    if(!dashTurn||!travelClear(e.x,e.y,f.x,f.y,false)){
      e.st=101;e.stT=e.stM=1.5;e.lx=f.x;e.ly=f.y;
    }else{const a=aimAt(f.x,f.y),L=Math.min(6,Math.hypot(f.x-e.x,f.y-e.y)+1);e.lx=clamp(e.x+Math.cos(a)*L,.4,N-.4);e.ly=clamp(e.y+Math.sin(a)*L,.4,N-.4);e.st=102;e.stT=e.stM=.85}
    sfx(e.st===101?'winterwarn':'charge',e.x,e.y);return{eng:true,mv:null};
  }
  if(f)aimAt(f.x,f.y);
  if(tgt&&heightDist(e.x,e.y,tgt.x,tgt.y)<1.3&&e.cd<=0){const k=idx(Math.floor(tgt.x),Math.floor(tgt.y));if(walls[k])damageWall(k,22*MAT[walls[k].mat].bullet);else if(coreKs.has(k))hurtStake(stakeAt(k),8*Df.dmg);e.cd=1.1}
  return{eng:false,mv};
}
function drawWinterTelegraphs(){
  for(const e of enemies)if(e.type==='boss'&&(e.st===101||e.st===102)){
    if(e.st===101){const r=e.boss==='rime'?3.4:2.3;
      const key=[e.lx,e.ly,r,u,DPR,MAP.name,N].join('|');
      if(!e.warningArt||e.warningArt.key!==key)e.warningArt=makeWinterWarning(e,r,key);
      const a=e.warningArt;g.drawImage(a.cv,camX+a.x,camY+a.y,a.w,a.h);
      const c=iso(e.lx,e.ly);label('ICE RUPTURE',c[0],c[1]-WH,'#d8fff3',12);
    }else{g.save();g.strokeStyle='#d5fff0';g.lineWidth=5*u;g.setLineDash([6*u,4*u]);const a=iso(e.x,e.y),b=iso(e.lx,e.ly);g.beginPath();g.moveTo(a[0],a[1]);g.lineTo(b[0],b[1]);g.stroke();g.restore()}
  }
}
// A warning stays anchored for its full tell. Clip its per-height circle once,
// then stamp this bounded local raster while the camera moves.
function makeWinterWarning(e,r,key){
  const kg=g,kx=camX,ky=camY;camX=camY=0;
  const center=iso(e.lx,e.ly),pad=r*TW2*Math.SQRT2+4*u,x=center[0]-pad,y=center[1]-r*TH2*Math.SQRT2-2*heightPx()-4*u,w=pad*2,h=2*r*TH2*Math.SQRT2+4*heightPx()+8*u;
  const cv=document.createElement('canvas'),sc=Math.min(1.5,DPR);cv.width=Math.ceil(w*sc);cv.height=Math.ceil(h*sc);g=cv.getContext('2d');g.scale(sc,sc);camX=-x;camY=-y;
  try{
      const originZ=heightAt(e.lx,e.ly);
      for(let i=Math.floor(e.lx-r);i<=e.lx+r;i++)for(let j=Math.floor(e.ly-r);j<=e.ly+r;j++)if(inb(i,j)){
        const k=idx(i,j),z=heightAt(i+.5,j+.5),dz=Math.max(0,Math.abs(z-originZ)-(connectors[k] ? .5 : 0))*.8,R=Math.sqrt(Math.max(0,r*r-dz*dz)),c=iso(e.lx,e.ly,z);
        if(!R)continue;g.save();const A=iso(i,j,heights[k]+(connectors[k]?1:0)),B=iso(i+1,j,heights[k]+(connectors[k]?1:0)),C=iso(i+1,j+1,heights[k]),D=iso(i,j+1,heights[k]);
        g.beginPath();g.moveTo(...A);g.lineTo(...B);g.lineTo(...C);g.lineTo(...D);g.closePath();g.clip();
        g.fillStyle='rgba(120,255,220,.28)';g.strokeStyle='#d2fff0';g.lineWidth=1.2*u;g.beginPath();g.ellipse(c[0],c[1],TW2*R*Math.SQRT2,TH2*R*Math.SQRT2,0,0,Math.PI*2);g.fill();g.stroke();g.restore();
      }
  }finally{g=kg;camX=kx;camY=ky}
  return{key,cv,x,y,w,h};
}
