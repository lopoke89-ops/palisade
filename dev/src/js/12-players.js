/* ================= update ================= */
// host and solo: the real simulation
function update(dt){
  updateParticles(dt);
  if(!running()||game.paused||(NET.mode==='guest'&&NET.inGame))return;
  if(demo&&game.phase==='build'&&game.timer>8)game.timer=8;
  game.time+=dt;for(const c of cores)c.flash=Math.max(0,c.flash-dt);updateFlood(dt);
  if(game.pvp){updatePvp(dt);if(game.phase==='over')return}
  else if(game.phase==='build'){game.timer-=dt;if(game.timer<=0)startRaid()}
  else{
    if(game.queue.length){game.spawnT-=dt;if(game.spawnT<=0){spawnEnemy(game.queue.shift());game.spawnT=game.spawnGap||1.1}}
    else if(!enemies.length&&!charges.length&&!rockets.length){if(game.wave>=game.waves){endGame(true);return}startBuild(24+game.Df.build)}
  }
  if(flowDirty){flowT-=dt;if(flowT<=0){computeFlow();flowDirty=false}}
  for(const p of players.values())simPlayer(p,dt);
  updateQM(dt);updateEnemies(dt);updateBullets(dt);updateLobs(dt);updateCharges(dt);updateRockets(dt);updateWalls(dt);updateNodes(dt);
  if(game.pvp==='base'){for(const c of cores)if(c.hp<=0&&game.phase!=='over'){c.hp=0;explode(c.i+.5,c.j+.5,1.8,1.3);endPvp(c.team==='a'?'b':'a');return}}
  else if(!game.pvp&&core.hp<=0&&game.phase!=='over'){core.hp=0;explode(core.i+.5,core.j+.5,1.8,1.3);endGame(false)}
}
function assist(d){
  let best=null,ba=.32;const a0=Math.atan2(d.y,d.x),p=player;
  for(const e of foes()){const dx=e.x-p.x,dy=e.y-p.y,dd=Math.hypot(dx,dy);if(dd>p.gun.range)continue;let da=Math.abs(Math.atan2(dy,dx)-a0);if(da>Math.PI)da=2*Math.PI-da;if(da<ba){ba=da;best={x:dx/dd,y:dy/dd}}}
  return best||d;
}
// this phone's thumbs/keys drive this phone's soldier (on every kind of phone)
function controlLocal(dt){
  const p=player;if(!p||demo)return;p.fireIn=false;
  if(!p.alive||overlayOpen()||chatOpen())return;
  let mx=(keys.d||keys.arrowright?1:0)-(keys.a||keys.arrowleft?1:0),my=(keys.s||keys.arrowdown?1:0)-(keys.w||keys.arrowup?1:0);
  if(stickMove.id!==null){mx+=stickMove.vx;my+=stickMove.vy}
  const mag=Math.min(1,Math.hypot(mx,my));
  p.sprT=Math.max(0,(p.sprT||0)-dt);p.sprCd=Math.max(0,(p.sprCd||0)-dt);const spr=p.sprT>0;
  // 3.3 tiles a second is everyone's pace; the class sets a multiplier (sniper 1.1, grenadier 0.9)
  if(mag>.12){const d=sdirToWorld(mx,my),sp=3.3*mag*(p.C.spd||1)*(spr?SPRINT.mult:1)*(p.stun>0?.45:1)*slowAt(p.x,p.y);moveEnt(p,d.x*sp*dt,d.y*sp*dt,pt(p));p.walk+=dt*mag*(spr?13:10);p.moveDir=d;
    if(spr&&rnd()<dt*14)emit(p.x-d.x*.2,p.y-d.y*.2,3*u,'dust',0)}
  let firing=false;
  if(!touchMode&&mouse.seen){const w=bodyUnder(mouse.x,mouse.y,p)||screenToWorld(mouse.x,mouse.y+WH*.55);const dx=w.x-p.x,dy=w.y-p.y,l=Math.hypot(dx,dy)||1;p.aim={x:dx/l,y:dy/l};p.face=p.aim;firing=mouse.down}
  else if(stickAim.id!==null&&stickAim.mag>.2){const d=assist(sdirToWorld(stickAim.vx,stickAim.vy));p.aim=d;p.face=d;firing=stickAim.mag>.5}
  else if(mag>.12){p.face=p.moveDir;p.aim=p.moveDir}
  p.fireIn=firing&&!spr;p.autoFire=touchMode||!mouse.seen;
  if(p.pullIn!==mouse.pulls){if(p.pullIn===undefined)p.pullUsed=mouse.pulls;p.pullIn=mouse.pulls;p.pullT=game.time}
}
// host and solo: one soldier's timers, trigger, gathering, downed state
function simPlayer(p,dt){
  p.hurt+=dt;p.cd=Math.max(p.cd-dt,-dt);
  if(p.bolt>0){const b0=p.bolt;p.bolt=Math.max(0,p.bolt-dt);const open=p.boltT*.72;if(b0>open&&p.bolt<=open){sfx(p.gun.pump?'pump':'rack',p.x,p.y);emit(p.x,p.y,WH*.7,p.gun.pump?'hull':'shell')}}
  p.stun=Math.max(0,(p.stun||0)-dt);p.dryT=Math.max(0,(p.dryT||0)-dt);p.sinceShot=(p.sinceShot||0)+dt;p.bcd-=dt;p.gt=Math.max(p.gt-dt,-dt);p.ncd-=dt;p.flash=Math.max(0,p.flash-dt);p.prot=Math.max(0,(p.prot||0)-dt);
  if(!p.alive){p.bLeft=0;
    if(!p.downed)return;   // the menu's hidden demo soldier
    if(game.pvp!=='ffa')for(const o of players.values())if(o!==p&&o.alive&&dist2(o,p)<1&&(!game.pvp||o.team===p.team)){p.revive+=dt;break}
    if(p.revive>=2.2){revivePlayer(p);return}
    p.rt-=dt;
    if(p.rt<=0){
      const m=p.mats.map(v=>Math.floor(v/2));if(m.some(v=>v>0))sacks.push({x:p.x,y:p.y,mats:m});p.mats=p.mats.map((v,i)=>v-m[i]);
      [p.x,p.y]=respawnAt(p);p.tp++;
      p.alive=true;p.downed=false;p.hp=p.max;p.hurt=9;p.revive=0;p.stun=0;if(p.gun.mag){p.ammo=p.gun.mag;p.rl=0}
      if(game.pvp){p.prot=PVP.prot;p.nades=Math.max(p.nades,p.maxN);toastTo(p,game.pvp==='ffa'?'BACK IN':'BACK AT YOUR STAKE',m.some(v=>v>0)?'Half your pack is in a sack where you fell.':'')}
      else toastTo(p,'BACK AT THE STAKE',m.some(v=>v>0)?'Half your pack is in a sack where you fell.':'');
    }
    return;
  }
  const G=p.gun;
  // cooldowns keep leftover time, so the fire rate is the same at any frame rate
  // bolt-action: holding the trigger fires every bolt cycle, and a click during the cycle is kept for 0.6 s; touch aim auto-cycles
  // the pump shotgun: every click fires (0.12 s apart at most), and holding the trigger or touch-aiming fires on its own cadence
  const pump=!!G.clickCd,semi=G.bolt&&!pump&&p.autoFire===false,click=pump&&p.autoFire===false&&p.pullIn!==p.pullUsed&&game.time-(p.pullT||0)<.6;
  if(click&&p.sinceShot>=G.clickCd)p.cd=Math.min(p.cd,0);
  const want=semi?p.fireIn||p.pullIn!==p.pullUsed&&game.time-(p.pullT||0)<.6:pump?(click&&p.sinceShot>=G.clickCd)||(p.fireIn&&p.cd<=0):p.fireIn;
  if(semi&&p.pullIn!==p.pullUsed&&!want)p.pullUsed=p.pullIn;
  if(pump&&p.pullIn!==p.pullUsed&&!click)p.pullUsed=p.pullIn;
  medicTouch(p);
  const mag=G.mag|0;if(mag&&!(p.ammo>=0))p.ammo=mag;
  if(want&&truce()){p.cd=Math.max(p.cd,0);p.pullUsed=p.pullIn;if(p===player&&!game.truceTold){game.truceTold=true;toast('TRUCE','No shooting until the battle starts. Build.')}}
  else if(want&&mag&&p.ammo<=0){p.cd=Math.max(p.cd,0);if(semi||pump)p.pullUsed=p.pullIn;if(p.dryT<=0){p.dryT=.45;personal(p,'dry')}}   // empty tube: it keeps loading
  else if(want||p.bLeft>0){p.prot=0;let n=0;const slow=game.pvp&&G.pierce?PVP.snipeCd:1;
    while(p.cd<=0&&n<(G.bolt?1:6)&&!(mag&&p.ammo<=0)){
      if(G.burst){if(!(p.bLeft>0)){if(!want)break;p.bLeft=burstN(p)}p.bLeft--}   // a burst, once started, always finishes
      shoot(p,G,-p.cd);p.cd+=G.burst&&p.bLeft===0?burstGap(p):G.cd*slow;n++;if(mag)p.ammo--}   // after a burst's last round: the pause instead of the spacing
    if(n){sfx(G.snd,p.x,p.y);const TS=TRAILS[p.cos.trail];if(TS&&TS.snd&&game.time-(p.trT||0)>.22){p.trT=game.time;sfx(TS.snd,p.x,p.y)}personal(p,'~f');p.sinceShot=0;p.rl=0;if(G.bolt){p.pullUsed=p.pullIn;p.boltT=(pump?Math.min(G.cd,.36):G.cd)*slow*.92;p.bolt=p.boltT;if(p.cd<0)p.cd=0}}}
  else p.cd=Math.max(p.cd,0);
  // shells go in one at a time: when the tube is empty, after a second without firing, or on R. Firing stops it.
  if(mag&&p.ammo<mag){
    if((p.ammo<=0||p.sinceShot>1.1||p.rlReq)&&!(want&&p.ammo>0)){if(!(p.rl>0))p.rl=G.reload;p.rl-=dt;
      if(p.rl<=0){p.ammo++;p.rl=p.ammo<mag?G.reload+p.rl:0;sfx('shellin',p.x,p.y);if(p.ammo>=mag)p.rlReq=false}}
  }else{p.rl=0;p.rlReq=false}
  for(const n of nodes){
    if(n.locked||(n.type===0&&n.amt<=0))continue;
    const d=Math.hypot(p.x-(n.i+.5),p.y-(n.j+.5));
    if(d<(n.solid?1.3:1.05)&&p.gt<=0&&p.mats[n.type]<p.cap[n.type]){
      const y=Math.min(YIELD[n.type],p.cap[n.type]-p.mats[n.type],n.type===0?n.amt:99);p.mats[n.type]+=y;if(n.type===0)n.amt-=y;p.gt+=RATE[n.type]*(p.C.gather||1);personal(p,'gather');
      emit(n.i+.5,n.j+.5,10*u,n.type===0?'splinter':n.type===1?'dust':'spark',n.type);
      if(p===player&&n.type===0&&++game.gathered>=4&&game.tip===0){game.tip=1;setTip(touchMode?'Face a tile and tap BUILD to raise a wall.':'Face a tile with the mouse and press Space to raise a wall.')}
    }
  }
  for(let s=sacks.length-1;s>=0;s--){const k=sacks[s];if(Math.hypot(k.x-p.x,k.y-p.y)<.7){for(let m=0;m<3;m++)p.mats[m]=Math.min(p.cap[m],p.mats[m]+k.mats[m]);sacks.splice(s,1);personal(p,'gather');flt(p.x,p.y,'PACK RECOVERED')}}
  if(p.hurt>4)p.hp=Math.min(p.max,p.hp+4*dt);
}

