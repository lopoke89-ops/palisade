/* ---------- raiders ---------- */
function lookAhead(e){
  let ti=e.x|0,tj=e.y|0;
  for(let s=0;s<8;s++){
    if(Math.abs(ti-core.i)<=1&&Math.abs(tj-core.j)<=1){const d=Math.hypot(core.i+.5-e.x,core.j+.5-e.y);return d<6.5?{x:core.i+.5,y:core.j+.5}:null}
    const k=bestStep(ti,tj);if(k<0)return null;const i=k%N,j=(k/N)|0;
    if(walls[k]){const d=Math.hypot(i+.5-e.x,j+.5-e.y);return d<6.5?{x:i+.5,y:j+.5}:null}
    ti=i;tj=j;
  }
  return null;
}
function updateEnemies(dt){
  const Df=game.Df;
  for(const e of enemies){
    if(e.dead)continue;e.cd=Math.max(e.cd-dt,-dt);e.flash=Math.max(0,e.flash-dt);e.scanT-=dt;
    const ti=e.x|0,tj=e.y|0;let tgt=null,moveTo=null;
    if(Math.abs(ti-core.i)<=1&&Math.abs(tj-core.j)<=1)tgt={x:core.i+.5,y:core.j+.5};
    else{const k=bestStep(ti,tj);if(k>=0){const c={x:k%N+.5,y:((k/N)|0)+.5};if(walls[k])tgt=c;else moveTo=c}}
    if(e.scanT<=0){e.scanT=.2;e.foe=null;let bd=e.type==='boss'?BOSSES[e.boss].scan:e.type==='gren'?6.5:7;for(const a of allies()){if(!a.alive)continue;const d=dist2(a,e);if(d<bd&&losClear(e.x,e.y,a.x,a.y)){bd=d;e.foe=a}}}
    if(e.foe&&!e.foe.alive)e.foe=null;
    const aimAt=(x,y)=>{const dx=x-e.x,dy=y-e.y,l=Math.hypot(dx,dy)||1;e.aim={x:dx/l,y:dy/l};return Math.atan2(dy,dx)};
    let engaging=false;
    if(e.type==='boss'){const r=BOSSES[e.boss].think(e,dt,tgt,moveTo,aimAt,Df);engaging=r.eng;moveTo=r.mv}
    else if(e.type==='rifle'){
      if(e.foe){engaging=true;const a=aimAt(e.foe.x,e.foe.y);if(e.cd<=0){while(e.cd<=0){fire(e,a+(rnd()-.5)*.2,1,{dmg:8*Df.dmg,speed:22,range:11},-e.cd);e.cd+=.65+rnd()*.45}sfx('rifle',e.x,e.y)}}
      else if(tgt){const a=aimAt(tgt.x,tgt.y);if(e.cd<=0){while(e.cd<=0){fire(e,a+(rnd()-.5)*.1,1,{dmg:7*Df.dmg,speed:22,range:11,over:false},-e.cd);e.cd+=.6+rnd()*.3}sfx('rifle',e.x,e.y)}}
    }else if(e.type==='gren'){
      const lt=e.foe?{x:e.foe.x,y:e.foe.y}:lookAhead(e);if(lt)aimAt(lt.x,lt.y);
      if(e.cd<=0&&lt){const tx=clamp(lt.x+(rnd()-.5)*.8,.3,N-.3),ty=clamp(lt.y+(rnd()-.5)*.8,.3,N-.3),d=Math.hypot(tx-e.x,ty-e.y);
        lobs.push({x0:e.x,y0:e.y,x1:tx,y1:ty,t:0,T:.55+d*.08,R:1.65,power:Df.dmg});e.cd+=3.1+rnd()*1.2;sfx('lob',e.x,e.y)}
      if(e.foe&&dist2(e.foe,e)<3.5)engaging=true;
    }else{ // breacher: run the satchel to the wall, then run
      if(!e.planted&&tgt){
        if(Math.hypot(tgt.x-e.x,tgt.y-e.y)<1.35){charges.push({x:e.x+(tgt.x-e.x)*.45,y:e.y+(tgt.y-e.y)*.45,fuse:2.4,beep:0});e.planted=true;e.fleeT=5;sfx('plant',e.x,e.y);flt(e.x,e.y,'SATCHEL','#d65a3a')}
        else moveTo=tgt; // walk right up to the wall
      }
      if(e.planted){e.fleeT-=dt;if(e.fleeT<=0){e.planted=false;flt(e.x,e.y,'RE-ARMED','#d65a3a')}}
      if(e.planted){let bk=-1,bv=-1;for(const[di,dj]of D4){const i=ti+di,j=tj+dj;if(!inb(i,j)||solidTile(i,j))continue;const k=idx(i,j);if(dist[k]>bv){bv=dist[k];bk=k}}
        moveTo=bk>=0?{x:bk%N+.5,y:((bk/N)|0)+.5}:null}
    }
    if(!engaging&&moveTo){const dx=moveTo.x-e.x,dy=moveTo.y-e.y,l=Math.hypot(dx,dy);if(l>.02){const s=Math.min(l,e.speed*dt);moveEnt(e,dx/l*s,dy/l*s,false);e.walk+=dt*9;if(!tgt&&!e.foe)e.aim={x:dx/l,y:dy/l}}}
  }
  for(let a=0;a<enemies.length;a++)for(let b=a+1;b<enemies.length;b++){const A=enemies[a],B=enemies[b],dx=B.x-A.x,dy=B.y-A.y,d=Math.hypot(dx,dy);if(d<.5&&d>.001){const push=(.5-d)*.5;moveEnt(A,-dx/d*push,-dy/d*push,false);moveEnt(B,dx/d*push,dy/d*push,false)}}
  dropDead(enemies);
}
function updateBullets(dt){
  for(const b of bullets){
    const sp=Math.hypot(b.vx,b.vy),steps=Math.ceil(sp*dt/.15);
    for(let s=0;s<steps&&!b.dead;s++){
      b.x+=b.vx*dt/steps;b.y+=b.vy*dt/steps;b.dist+=sp*dt/steps;
      const i=Math.floor(b.x),j=Math.floor(b.y);
      if(!inb(i,j)||b.dist>b.range){b.dead=b.spent=true;break}
      const k=idx(i,j);
      if(coreKs.has(k)){const c=stakeAt(k);if(game.pvp?c.team!==b.pt:b.team===1)hurtStake(c,game.pvp?b.dmg*PVP.stakeHit:6*game.Df.dmg);else emit(b.x,b.y,WH*.5,'spark');b.dead=true;break}
      const n=nodeAt(i,j);if(n&&n.solid){hitFx(b.x,b.y,n.type);b.dead=true;break}
      const w=walls[k];
      if(w&&k!==b.last){
        b.last=k;
        if(b.over&&!b.skipped&&b.dist<1.3){b.skipped=true}
        else{const st=wallState(w);if(rnd()>=(st===0?0:st===1?.35:.65)){
          const mult=b.team===0?(b.heavy?.6:.25):1;damageWall(k,bdmg(b)*MAT[w.mat].bullet*mult,b.own);hitFx(b.x,b.y,w.mat);sfx('hit'+w.mat,b.x,b.y);
          if(b.pierce>0&&w.mat===0){b.pierce--;b.dmg*=.8}else{b.dead=true;break}}}
      }
      if(game.pvp){for(const o of players.values())if(o.alive&&!(o.prot>0)&&o.id!==b.own&&(game.pvp==='ffa'||o.team!==b.pt)&&Math.hypot(o.x-b.x,o.y-b.y)<.3){hurtPlayer(o,bdmg(b)*(b.heavy?PVP.snipe:PVP.dmg),b.own);feelHit(b.own,b.heavy);b.dead=true;break}}
      else if(b.team===0){for(const e of enemies)if(!e.dead&&Math.hypot(e.x-b.x,e.y-b.y)<(e.big?.55:.34)){hurtEnemy(e,bdmg(b),b.own);if(!b.pel||!b.felt){b.felt=1;feelHit(b.own,b.heavy)}b.dead=true;break}}
      else{for(const a of allies())if(a.alive&&Math.hypot(a.x-b.x,a.y-b.y)<.3){hurtAlly(a,b.dmg*(a===qm?.7:1));b.dead=true;break}}
    }
  }
  {const hit=[];for(const b of bullets)if(b.dead&&!b.spent&&b.id)hit.push(b.id);if(hit.length)rec(['bx',...hit])}   // guests expire misses on their own
  bullets=bullets.filter(b=>!b.dead);
}
function updateLobs(dt){for(const l of lobs){l.t+=dt;if(l.t>=l.T){l.dead=true;explode(l.x1,l.y1,l.R,l.power,l.own)}}lobs=lobs.filter(l=>!l.dead)}
function updateCharges(dt){for(const c of charges){c.fuse-=dt;c.beep-=dt;if(c.beep<=0){c.beep=Math.max(.12,c.fuse*.25);sfx('beep',c.x,c.y)}if(c.fuse<=0){c.dead=true;explode(c.x,c.y,2.1,1.6)}}charges=charges.filter(c=>!c.dead)}
function updateWalls(dt){
  for(let k=0;k<N*N;k++){
    const w=walls[k];if(!w)continue;w.flash=Math.max(0,w.flash-dt);
    if(w.fire>0){
      w.fire-=dt;w.char=Math.min(1,w.char+dt*.14);const i=k%N,j=(k/N)|0;
      if(rnd()<dt*.45)for(const[di,dj]of D4){const ni=i+di,nj=j+dj;if(!inb(ni,nj))continue;const nw=walls[idx(ni,nj)];if(nw&&nw.mat===0&&nw.fire<=0&&rnd()<.5){nw.fire=6;nw.fireBy=w.fireBy}}
      damageWall(k,9*dt,w.fireBy);
    }
  }
}
function updateNodes(dt){for(const n of nodes)if(n.type===0&&n.amt<=0){n.rt+=dt;if(n.rt>25){n.amt=n.max;n.rt=0}}}
// flames, kiln smoke and satchel beeps are only for show, so every phone makes its own
function localAmbience(dt){
  if(!walls)return;
  for(let k=0;k<N*N;k++){const w=walls[k];if(!w||!(w.fire>0))continue;const i=k%N,j=(k/N)|0;
    if(rnd()<dt*14)ambient(i+.3+rnd()*.4,j+.3+rnd()*.4,WH*(.6+rnd()*.4),'flame');
    if(rnd()<dt*3)ambient(i+.5,j+.5,WH,'smoke')}
  for(const kiln of nodes)if(kiln.type===1&&!kiln.locked&&rnd()<dt*1.2)ambient(kiln.i+.68,kiln.j+.28,WH*2,'smoke');
  for(const r of rockets){if(rnd()<dt*30)ambient(r.x,r.y,WH*.55,'smoke');if(rnd()<dt*25)ambient(r.x,r.y,WH*.55,'ember')}
  for(const f of fires){if(rnd()<dt*16)ambient(f.x+(rnd()-.5)*1.1,f.y+(rnd()-.5)*1.1,WH*.2,'flame')}
  for(const e of enemies)if(e.type==='boss'&&e.boss==='storm'&&rnd()<dt*6)ambient(e.x+(rnd()-.5)*.5,e.y+(rnd()-.5)*.5,WH*(.3+rnd()*.8),'arc');
}
function ambient(x,y,z,kind){replaying=true;try{emit(x,y,z,kind)}finally{replaying=false}}
// count an effect list down and drop what has run out, in place (no new array every frame)
function ageOut(a,dt){let j=0;for(let i=0;i<a.length;i++){const v=a[i];v.life-=dt;if(v.life>0)a[j++]=v}a.length=j}
const dropDead=a=>{let j=0;for(let i=0;i<a.length;i++){const v=a[i];if(!v.dead)a[j++]=v}a.length=j};
function updateParticles(dt){
  if(game.paused)return;
  for(const p of parts){p.life-=dt;p.x+=p.vx*dt*.6;p.y+=p.vy*dt*.6;p.vz-=p.grav*dt;p.z+=p.vz*dt*u;if(p.z<0){p.z=0;p.vz*=-.3;p.vx*=.5;p.vy*=.5}}
  ageOut(parts,0);ageOut(flashes,dt);ageOut(zaps,dt);ageOut(rings,dt);ageOut(slashes,dt);ageOut(floats,dt);
  shake=Math.max(0,shake-dt*30);
  if(running())localAmbience(dt);
  // time of day: overcast → golden hour → night
  const tod=game.pvp?0:todStage(game.phase==='raid'?game.wave:game.wave+.5);
  const T=tod===2?{L:.7,r:5,g:8,b:22,warm:0}:tod===1?{L:.2,r:60,g:30,b:10,warm:.07}:{L:.12,r:28,g:34,b:44,warm:0};
  const k=Math.min(1,dt*.8);for(const key of['L','r','g','b','warm'])light[key]+=(T[key]-light[key])*k;
}

