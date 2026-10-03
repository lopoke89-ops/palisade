/* ---------- raiders ---------- */
const RIOT_SHIELD_HITS=20;
function shieldBulletHit(e,b){
 if(NET.mode==='guest'||e.shieldBroken||b.shieldContact===e.id)return false;
 if(e.shieldHitsLeft===undefined){e.shieldHitsMax=RIOT_SHIELD_HITS;e.shieldHitsLeft=RIOT_SHIELD_HITS}
 b.shieldContact=e.id;e.shieldHitsLeft=Math.max(0,e.shieldHitsLeft-1);
 if(!e.shieldHitsLeft){e.shieldBroken=true;for(let n=0;n<6;n++)emit(e.x,e.y,WH*.5,'spark');sfx('collapse',e.x,e.y);flt(e.x,e.y,'SHIELD BROKEN','#d9e9e6')}
 return true;
}
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
// v0.9.2: a sniper in stealth is ignored; Nightmare raiders spot further, fire and move faster; Berserk bosses
// wind up their next attack sooner (their warnings, e.stT, keep their full length)
const seen=a=>a.alive&&!(a.stl>0);
function updateEnemies(dt){
  const Df=game.Df,NM=hasMod('nightmare'),BZ=hasMod('berserk'),EL=hasMod('elite');for(const a of allies())if(a.markT>0)a.markT-=dt;
  for(const e of enemies){const aimed=cityAim(e);try{   // v0.9.7: a POI attacker treats his POI as the core
    if(e.dead)continue;const boss=e.type==='boss',hurry=NM&&!boss?1.18:1;
    if(e.burnT>0){const tick=Math.min(dt,e.burnT);e.burnT=Math.max(0,e.burnT-dt);hurtEnemy(e,10*tick,e.burnOwn,true);if(e.dead)continue}
    if(e.slowT>0){e.slowT=Math.max(0,e.slowT-dt);if(!e.slowT)e.slowPct=0}
    e.cd=Math.max(e.cd-dt*hurry,-dt);e.flash=Math.max(0,e.flash-dt);e.scanT-=dt;
    if(BZ&&boss&&!e.st){e.cd-=dt*.33;if(e.ab!==undefined)e.ab-=dt*.33}
    const ti=e.x|0,tj=e.y|0;let tgt=null,moveTo=null;
    if(Math.abs(ti-core.i)<=1&&Math.abs(tj-core.j)<=1)tgt={x:core.i+.5,y:core.j+.5};
    else{const k=bestStep(ti,tj);if(k>=0){const c={x:k%N+.5,y:((k/N)|0)+.5};if(walls[k])tgt=c;else moveTo=c}}
    if(e.scanT<=0){e.scanT=.2;e.foe=null;let bd=(e.type==='boss'?BOSSES[e.boss].scan:e.type==='gren'?6.5:e.type==='spotter'?10:e.type==='medic'?5:e.type==='fire'?6.5:7)*(NM&&!boss?1.3:1);
      // spotted: riflemen go for the marked soldier first (Elite Raid: grenadiers and firebrands do, from further out)
      if(e.type==='rifle'||EL&&(e.type==='gren'||e.type==='fire')){for(const a of allies())if(seen(a)&&a.markT>0){const d=dist2(a,e);if(d<bd+3&&losClear(e.x,e.y,a.x,a.y)){e.foe=a;bd=-1;break}}}
      if(bd>=0)for(const a of allies()){if(!seen(a))continue;const d=dist2(a,e);if(d<bd&&losClear(e.x,e.y,a.x,a.y)){bd=d;e.foe=a}}}
    if(e.foe&&!seen(e.foe))e.foe=null;
    const aimAt=(x,y)=>{const dx=x-e.x,dy=y-e.y,l=Math.hypot(dx,dy)||1;e.aim={x:dx/l,y:dy/l};return Math.atan2(dy,dx)};
    let engaging=false;
    if(e.type==='boss'){const px=e.x,py=e.y,r=BOSSES[e.boss].think(e,dt,tgt,moveTo,aimAt,Df);engaging=r.eng;moveTo=r.mv;
      if(e.boss!=='rime'&&frostFields.length){const slow=frostSlow(px,py);e.x=px+(e.x-px)*slow;e.y=py+(e.y-py)*slow}
      if(!heightTravelClear(px,py,e.x,e.y)){e.x=px;e.y=py;e.st=0;e.ab=2;e.cd=1}e.z=heightAt(e.x,e.y);
      if(moveTo&&!travelClear(e.x,e.y,moveTo.x,moveTo.y,false))moveTo=moveTo===tgt?tgt:(()=>{const k=bestStep(e.x|0,e.y|0);return k>=0?{x:k%N+.5,y:((k/N)|0)+.5}:null})();
    }
    else if(e.type==='rifle'){
      // a spotter's mark tightens their aim a lot (0.2 rad spread down to 0.06) and adds a little range
      if(e.foe){engaging=true;const mk=e.foe.markT>0,a=aimAt(e.foe.x,e.foe.y);if(e.cd<=0){while(e.cd<=0){fire(e,a+(rnd()-.5)*(mk?.06:.2),1,{dmg:8*Df.dmg,speed:22,range:mk?13:11},-e.cd);e.cd+=.65+rnd()*.45}sfx('rifle',e.x,e.y)}}
      else if(tgt){const a=aimAt(tgt.x,tgt.y);if(e.cd<=0){while(e.cd<=0){fire(e,a+(rnd()-.5)*.1,1,{dmg:7*Df.dmg,speed:22,range:11,over:false},-e.cd);e.cd+=.6+rnd()*.3}sfx('rifle',e.x,e.y)}}
    }else if(e.type==='gren'){
      const lt=e.foe&&(dist2(e.foe,e)<(EL&&e.foe.markT>0?8.5:7))?{x:e.foe.x,y:e.foe.y}:lookAhead(e);if(lt)aimAt(lt.x,lt.y);
      if(e.cd<=0&&lt){const tx=clamp(lt.x+(rnd()-.5)*.8,.3,N-.3),ty=clamp(lt.y+(rnd()-.5)*.8,.3,N-.3),d=Math.hypot(tx-e.x,ty-e.y);
        lobs.push({x0:e.x,y0:e.y,x1:tx,y1:ty,t:0,T:.55+d*.08,R:1.65,power:Df.dmg});e.cd+=3.1+rnd()*1.2;sfx('lob',e.x,e.y)}
      if(e.foe&&dist2(e.foe,e)<3.5)engaging=true;
    }else if(e.type==='shield'){
      // shieldbearer: keeps walking the path with the shield turned to whoever is shooting at him, pistol over the top;
      // at a wall he bashes it. The shield stops bullets from the front (updateBullets); blasts still hurt.
      if(e.foe){const a=aimAt(e.foe.x,e.foe.y);if(e.cd<=0&&dist2(e.foe,e)<6.5){fire(e,a+(rnd()-.5)*.22,1,{dmg:6*Df.dmg,speed:20,range:7},0);e.cd=1.1+rnd()*.5;sfx('rifle',e.x,e.y)}}
      if(tgt&&heightDist(tgt.x,tgt.y,e.x,e.y)<1.3){if(!e.foe)aimAt(tgt.x,tgt.y);engaging=true;
        if(e.cd<=0){e.cd=1.2;const k=idx(Math.floor(tgt.x),Math.floor(tgt.y));if(e.shieldBroken){const a=aimAt(tgt.x,tgt.y);fire(e,a,1,{dmg:6*Df.dmg,speed:20,range:7},0);sfx('rifle',e.x,e.y)}else{if(walls[k])damageWall(k,16*MAT[walls[k].mat].bullet);else if(coreKs.has(k))hurtStake(stakeAt(k),6*Df.dmg);sfx('hit1',tgt.x,tgt.y)}}}
    }else if(e.type==='medic'){
      // field medic: hangs back behind the nearest raider and patches up everyone near him every 1.6 s
      e.ab-=dt;let buddy=null,bb=1e9;for(const o of enemies)if(o!==e&&!o.dead&&o.type!=='medic'&&!o.burrow){const d=dist2(o,e);if(d<bb){bb=d;buddy=o}}
      if(e.ab<=0){e.ab=1.6;let healed=0;for(const o of enemies)if(!o.dead&&o.hp<o.max&&dist2(o,e)<2.6){o.hp=Math.min(o.max,o.hp+o.max*(o.type==='boss'?.02:.14));healed++}
        if(healed){ringFx(e.x,e.y,.2,2.6,.5,'#8fe0a0','#2e7a48',2);sfx('medpulse',e.x,e.y)}}
      if(e.foe&&dist2(e.foe,e)<5){const a=aimAt(e.foe.x,e.foe.y);if(e.cd<=0){fire(e,a+(rnd()-.5)*.25,1,{dmg:5*Df.dmg,speed:20,range:6},0);e.cd=1.3+rnd()*.4;sfx('rifle',e.x,e.y)}}
      if(buddy&&bb>1.6&&bb<8){moveTo={x:buddy.x,y:buddy.y}}else if(buddy&&bb<=1.6){moveTo=null;engaging=true}
    }else if(e.type==='spotter'){
      // spotter: sits back at 6-9 tiles, and once he's had someone in sight for 0.8 s marks them (st 2) for as
      // long as he can still see them; riflemen then aim far better at that soldier
      const f=e.foe;
      if(f){const d=dist2(f,e);aimAt(f.x,f.y);e.lx=f.x;e.ly=f.y;
        if(!e.st){e.st=1;e.stT=e.stM=.8;sfx('mark',e.x,e.y)}
        else if(e.st===1){e.stT-=dt;if(e.stT<=0){e.st=2;e.stT=0;flt(f.x,f.y,'SPOTTED','#ff5a4a')}}
        if(e.st===2)f.markT=.35;
        if(d<5.5){const l=d||1;moveTo={x:clamp(e.x+(e.x-f.x)/l,.5,N-.5),y:clamp(e.y+(e.y-f.y)/l,.5,N-.5)}}else if(d<9.5){moveTo=null;engaging=true}
      }else if(e.st){e.st=0;e.stT=0}
    }else if(e.type==='fire'){
      // firebrand: lobs fire bottles at the wooden wall in his way (or at people close by); the glass bursts into a
      // patch of burning ground and sets wood alight
      let lt=null;if(e.foe&&dist2(e.foe,e)<(EL&&e.foe.markT>0?8.5:6.5))lt={x:e.foe.x,y:e.foe.y};else{const la=lookAhead(e);if(la){const w=walls[idx(Math.floor(la.x),Math.floor(la.y))];if(w&&w.mat===0&&!(w.fire>0))lt=la}}
      if(lt)aimAt(lt.x,lt.y);
      if(e.cd<=0&&lt){const tx=clamp(lt.x+(rnd()-.5)*.6,.3,N-.3),ty=clamp(lt.y+(rnd()-.5)*.6,.3,N-.3),d=Math.hypot(tx-e.x,ty-e.y);
        lobs.push({x0:e.x,y0:e.y,x1:tx,y1:ty,t:0,T:.5+d*.08,R:1,power:Df.dmg,k:1});e.cd+=3.6+rnd()*1.2;sfx('lob',e.x,e.y)}
      if(lt&&Math.hypot(lt.x-e.x,lt.y-e.y)<5)engaging=true;
    }else{ // breacher: run the satchel to the wall, then run
      if(!e.planted&&tgt){
        if(heightDist(tgt.x,tgt.y,e.x,e.y)<1.35){charges.push({x:e.x+(tgt.x-e.x)*.45,y:e.y+(tgt.y-e.y)*.45,fuse:2.4,beep:0});e.planted=true;e.fleeT=5;sfx('plant',e.x,e.y);flt(e.x,e.y,'SATCHEL','#d65a3a')}
        else moveTo=tgt; // walk right up to the wall
      }
      if(e.planted){e.fleeT-=dt;if(e.fleeT<=0){e.planted=false;flt(e.x,e.y,'RE-ARMED','#d65a3a')}}
      if(e.planted){let bk=-1,bv=-1;for(const[di,dj]of D4){const i=ti+di,j=tj+dj;if(!inb(i,j)||solidTile(i,j))continue;const k=idx(i,j);if(dist[k]>bv){bv=dist[k];bk=k}}
        moveTo=bk>=0?{x:bk%N+.5,y:((bk/N)|0)+.5}:null}
    }
    if(!engaging&&moveTo){const dx=moveTo.x-e.x,dy=moveTo.y-e.y,l=Math.hypot(dx,dy);if(l>.02){const s=Math.min(l,e.speed*dt*Math.max(.5,slowAt(e.x,e.y)*(1-(e.slowT>0?e.slowPct||0:0)))*(NM&&!boss?1.12:1));moveEnt(e,dx/l*s,dy/l*s,false);e.walk+=dt*9;if(!tgt&&!e.foe)e.aim={x:dx/l,y:dy/l}}}
  }finally{if(aimed)cityAimEnd()}}
  for(let a=0;a<enemies.length;a++)for(let b=a+1;b<enemies.length;b++){const A=enemies[a],B=enemies[b];if(A.raft||B.raft||A.burrow||B.burrow)continue;const dx=B.x-A.x,dy=B.y-A.y,d=Math.hypot(dx,dy);if(d<.5&&d>.001){const push=(.5-d)*.5;moveEnt(A,-dx/d*push,-dy/d*push,false);moveEnt(B,dx/d*push,dy/d*push,false)}}
  dropDead(enemies);
}
function ammoHit(e,b){
  if(!ammoMode()||!b.ammo||!b.ammo.length)return;
  const own=b.own||'',seen=e.ammoSeen||(e.ammoSeen={}),key=String(own);
  // Keep recent round IDs: pellets from different rounds can arrive interleaved.
  // The bounded history outlasts any bullet in flight without growing during Endless.
  const rounds=seen[key]||(seen[key]=[]);if(rounds.includes(b.shot))return;
  rounds.push(b.shot);if(rounds.length>128)rounds.shift();
  for(const [id,rank] of b.ammo){
    if(id==='fire'&&!e.dead){e.burnT=Math.max(e.burnT||0,3+.5*rank);e.burnOwn=own;emit(e.x,e.y,WH*.45,'fire')}
    else if(id==='blast'){
      const last=e.ammoBlast||(e.ammoBlast={});if(game.time-(last[key]??-1e9)<.4)continue;last[key]=game.time;
      for(const o of enemies)if(!o.dead&&!o.burrow){const d=heightDist(e.x,e.y,o.x,o.y);if(d<1.25)hurtEnemy(o,(8+2*rank)*(d<.35?1:1-(d-.35)/.9),own)}
      emit(e.x,e.y,WH*.55,'spark');addFlash({x:e.x,y:e.y,life:.14,max:.14,r:.7});
    }else if(id==='shock'){
      const near=enemies.filter(o=>o!==e&&!o.dead&&!o.burrow&&heightDist(e.x,e.y,o.x,o.y)<=3&&heightRayClear(e.x,e.y,o.x,o.y)).sort((a,c)=>Math.hypot(a.x-e.x,a.y-e.y)-Math.hypot(c.x-e.x,c.y-e.y)||a.id-c.id).slice(0,3);
      for(const o of[e,...near])if(!o.dead){o.slowT=Math.max(o.slowT||0,2);o.slowPct=Math.max(o.slowPct||0,Math.min(o.type==='boss'?.2:1,.25+.05*rank));emit(o.x,o.y,WH*.4,'arc')}
    }
  }
}
function updateBullets(dt){
  for(const b of bullets){
    const sp=Math.hypot(b.vx,b.vy),steps=Math.ceil(sp*dt/.15);
    for(let s=0;s<steps&&!b.dead;s++){
      b.x+=b.vx*dt/steps;b.y+=b.vy*dt/steps;b.dist+=sp*dt/steps;
      const i=Math.floor(b.x),j=Math.floor(b.y);
      if(!inb(i,j)||b.dist*bulletRangeScale(b)>b.range){b.dead=b.spent=true;break}
      const k=idx(i,j);
      if(heightAt(b.x,b.y)>bulletZ(b)-.08){hitFx(b.x,b.y,1);b.dead=true;break}
      if(coreKs.has(k)&&bulletZ(b)<heightAt(b.x,b.y)+1.35){const c=stakeAt(k);if(game.pvp?c.team!==b.pt:b.team===1)hurtStake(c,game.pvp?b.dmg*PVP.stakeHit:6*game.Df.dmg);else emit(b.x,b.y,WH*.5,'spark');b.dead=true;break}
      const n=nodeAt(i,j);if(n&&n.solid){hitFx(b.x,b.y,n.type);b.dead=true;break}
      if(terrShot(terr[k])){hitFx(b.x,b.y,1);b.dead=true;break}
      const w=walls[k];
      if(w&&k!==b.last&&bulletZ(b)<heightAt(b.x,b.y)+1.35){
        b.last=k;
        if(b.over&&!b.skipped&&b.dist<1.3){b.skipped=true}
        else{const st=wallState(w);if(rnd()>=(st===0?0:st===1?.35:.65)){
          const mult=b.team===0?(b.heavy?.6:.25):1;damageWall(k,bdmg(b)*MAT[w.mat].bullet*mult,b.own);hitFx(b.x,b.y,w.mat);sfx('hit'+w.mat,b.x,b.y);
          if(b.pierce>0&&w.mat===0){b.pierce--;b.dmg*=.8}else{b.dead=true;break}}}
      }
      if(game.pvp){for(const o of players.values())if(o.alive&&!(o.prot>0)&&o.id!==b.own&&(game.pvp==='ffa'||o.team!==b.pt)&&Math.hypot(o.x-b.x,o.y-b.y)<.3){hurtPlayer(o,bdmg(b)*(b.heavy?PVP.snipe:PVP.dmg),b.own);feelHit(b.own,b.heavy);b.dead=true;break}}
      else if(b.team===0){for(const e of enemies)if(!e.dead&&!e.burrow&&bulletAtActor(b,e)&&Math.hypot(e.x-b.x,e.y-b.y)<(e.big?.55:.34)){
          // a shieldbearer's shield covers his front (about 130°): the round sparks off it
          let shield=1;if(e.type==='shield'&&!e.shieldBroken){const l=Math.hypot(b.vx,b.vy)||1;if(-(b.vx*e.aim.x+b.vy*e.aim.y)/l>.42){shieldBulletHit(e,b);const ap=b.ammo&&b.ammo.find(x=>x[0]==='ap');if(!ap){hitFx(b.x,b.y,2);sfx('shieldhit',b.x,b.y);if(!b.pel||!b.felt){b.felt=1;feelHit(b.own,false)}b.dead=true;break}shield=[.5,.6,.7,.85,1][ap[1]]||.5}}
          hurtEnemy(e,bdmg(b)*shield*bossWeak(e,b),b.own);ammoHit(e,b);if(!b.pel||!b.felt){b.felt=1;feelHit(b.own,b.heavy)}b.dead=true;break}}
      else{for(const a of allies())if(a.alive&&bulletAtActor(b,a)&&Math.hypot(a.x-b.x,a.y-b.y)<.3){hurtAlly(a,b.dmg*(a===qm?.7:1));b.dead=true;break}}
    }
  }
  {const hit=[];for(const b of bullets)if(b.dead&&!b.spent&&b.id)hit.push(b.id);if(hit.length)rec(['bx',...hit])}   // guests expire misses on their own
  compactBullets();
}
// Compact in place: no replacement array on every simulation tick.
function compactBullets(){let n=0;for(let i=0;i<bullets.length;i++)if(!bullets[i].dead)bullets[n++]=bullets[i];bullets.length=n}
function updateLobs(dt){for(const l of lobs){l.t+=dt;if(l.t>=l.T){l.dead=true;if(l.k===1)bottleLand(l);else if(l.k===2)slabLand(l);else if(l.k===4)napalmLand(l);else if(l.k===3||l.k===5)explode(l.x1,l.y1,l.R,l.power,null,true);else{explode(l.x1,l.y1,l.R,l.power,l.own);if(l.own)molotovAt(l)}}}lobs=lobs.filter(l=>!l.dead)}
// a firebrand's bottle: burning ground for 5 s (it hurts people standing in it) and any wood within a tile catches
// Firestorm: the patch burns 8 s instead of 5 and is half again as wide, and catches wood further out
function bottleLand(l){
  const FS=hasMod('firestorm'),R=FS?1.9:1.3;
  fires.push({x:l.x1,y:l.y1,t:FS?8:5,max:FS?8:5,tick:.3,r:FS?1.35:.9});sfx('bottle',l.x1,l.y1);addFlash({x:l.x1,y:l.y1,life:.3,max:.3,r:FS?1.5:1});
  for(let n=0;n<10;n++)emit(l.x1,l.y1,4*u,'fire');
  for(let i=Math.floor(l.x1-R);i<=Math.floor(l.x1+R);i++)for(let j=Math.floor(l.y1-R);j<=Math.floor(l.y1+R);j++){if(!inb(i,j))continue;const w=walls[idx(i,j)];
    if(w&&w.mat===0&&groundReach(i+.5,j+.5,l.x1,l.y1,R)&&!(w.fire>0)){w.fire=FS?9:6;w.fireBy=null}}
}
function updateCharges(dt){for(const c of charges){c.fuse-=dt;c.beep-=dt;if(c.beep<=0){c.beep=Math.max(.12,c.fuse*.25);sfx('beep',c.x,c.y)}if(c.fuse<=0){c.dead=true;explode(c.x,c.y,2.1,1.6)}}charges=charges.filter(c=>!c.dead)}
function updateWalls(dt){
  const FS=hasMod('firestorm'),spread=FS?.8:.45,burn=FS?15:9;   // Firestorm: walls burn down faster and it spreads more
  for(let k=0;k<N*N;k++){
    const w=walls[k];if(!w)continue;w.flash=Math.max(0,w.flash-dt);
    if(w.fire>0){
      w.fire-=dt;w.char=Math.min(1,w.char+dt*.14);const i=k%N,j=(k/N)|0;
      if(rnd()<dt*spread)for(const[di,dj]of D4){const ni=i+di,nj=j+dj;if(!inb(ni,nj))continue;const nw=walls[idx(ni,nj)];if(nw&&nw.mat===0&&nw.fire<=0&&rnd()<.5){nw.fire=6;nw.fireBy=w.fireBy}}
      damageWall(k,burn*dt,w.fireBy);
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
  for(const e of enemies)if(e.type==='boss'&&bossBase(e.boss)==='storm'&&rnd()<dt*6)ambient(e.x+(rnd()-.5)*.5,e.y+(rnd()-.5)*.5,WH*(.3+rnd()*.8),'arc');
}
function ambient(x,y,z,kind){replaying=true;try{return emit(x,y,z,kind)}finally{replaying=false}}
// count an effect list down and drop what has run out, in place (no new array every frame)
function ageOut(a,dt){let j=0;for(let i=0;i<a.length;i++){const v=a[i];v.life-=dt;if(v.life>0)a[j++]=v}a.length=j}
const dropDead=a=>{let j=0;for(let i=0;i<a.length;i++){const v=a[i];if(!v.dead)a[j++]=v}a.length=j};
function updateParticles(dt){
  if(game.paused)return;
  ageFrost(dt);
  for(const p of parts){p.life-=dt;p.x+=p.vx*dt*.6;p.y+=p.vy*dt*.6;p.vz-=p.grav*dt;p.z+=p.vz*dt*u;if(p.z<0){p.z=0;p.vz*=-.3;p.vx*=.5;p.vy*=.5}}
  floodVisual(dt);ageOut(parts,0);ageOut(flashes,dt);ageOut(zaps,dt);ageOut(chains,dt);ageOut(rings,dt);ageOut(slashes,dt);ageOut(floats,dt);
  shake=Math.max(0,shake-dt*30);
  if(running())localAmbience(dt);
  // time of day: overcast → golden hour → night
  const tod=game.pvp?(hasMod('nightmare')?2:0):todStage(game.phase==='raid'?game.wave:game.wave+.5);
  const T=tod===2?{L:isCity()&&game.dark?.8:.7,r:5,g:8,b:22,warm:0}:tod===1?{L:.2,r:60,g:30,b:10,warm:.07}:{L:.12,r:28,g:34,b:44,warm:0};
  const k=Math.min(1,dt*.8);for(const key of['L','r','g','b','warm'])light[key]+=(T[key]-light[key])*k;
}

