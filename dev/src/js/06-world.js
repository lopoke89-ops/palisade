/* ================= pathing ================= */
function nodeAt(i,j){for(const n of nodes)if(n.i===i&&n.j===j)return n;return null}
// water costs about what walking round costs (wading is half speed), so raiders take a bridge when one is near
function enterCost(k){if(k===coreK)return 0;if(coreKs.has(k))return 1e6;const t=terr[k];if(terrSolid(t))return 1e6;const w=walls[k];if(w)return 1+w.hp/8;const n=nodeAt(k%N,(k/N)|0);if(n&&n.solid)return 1e6;return(debris[k]?1.4:1)+(t===T_WATER?2.4:t===T_LOW&&floodOn?1.1:0)}
function computeFlow(){
  dist.fill(1e9);if(coreK<0)return;const done=new Uint8Array(N*N);dist[coreK]=0;
  for(let it=0;it<N*N;it++){
    let uK=-1,bv=1e9;for(let k=0;k<N*N;k++)if(!done[k]&&dist[k]<bv){bv=dist[k];uK=k}
    if(uK<0)break;done[uK]=1;const ui=uK%N,uj=(uK/N)|0,c=enterCost(uK);
    for(const[di,dj]of D4){const i=ui+di,j=uj+dj;if(!inb(i,j))continue;const k=idx(i,j),nv=bv+c;if(nv<dist[k])dist[k]=nv}
  }
}
function markFlow(){if(!flowDirty){flowDirty=true;flowT=.3}}
function bestStep(ti,tj){let best=-1,bv=1e12;for(const[di,dj]of D4){const i=ti+di,j=tj+dj;if(!inb(i,j))continue;const k=idx(i,j),v=dist[k]+enterCost(k);if(v<bv){bv=v;best=k}}return best}
// breadth-first path for Delgado: doors are open to our side
function teamPath(si,sj,isGoal){
  const s=idx(si,sj);if(isGoal(s))return s;
  const prev=new Int16Array(N*N).fill(-1);prev[s]=s;const q=[s];
  for(let h=0;h<q.length;h++){
    const k=q[h];
    if(isGoal(k)){let c=k;while(prev[c]!==s)c=prev[c];return c}
    const i=k%N,j=(k/N)|0;
    for(const[di,dj]of D4){const ni=i+di,nj=j+dj;if(!inb(ni,nj)||solidTile(ni,nj,true))continue;const nk=idx(ni,nj);if(prev[nk]!==-1)continue;prev[nk]=k;q.push(nk)}
  }
  return -1;
}

/* ================= collision ================= */
function solidTile(i,j,team){if(!inb(i,j))return true;const k=idx(i,j);if(coreKs.has(k)||terrSolid(terr[k]))return true;const w=walls[k];if(w)return!(team&&w.door&&(team===true||w.tm===team));const n=nodeAt(i,j);return!!(n&&n.solid)}
function collides(x,y,r,team){
  if(x-r<0||y-r<0||x+r>N||y+r>N)return true;
  if(typeof team==='string'&&game.pvp==='base'&&game.phase==='build'&&(team==='a'?x-y>-.35:x-y<.35))return true;   // the truce line
  for(let i=Math.floor(x-r);i<=Math.floor(x+r);i++)for(let j=Math.floor(y-r);j<=Math.floor(y+r);j++)if(solidTile(i,j,team))return true;
  return false;
}
function moveEnt(e,dx,dy,team){const r=.27;if(!collides(e.x+dx,e.y,r,team))e.x+=dx;if(!collides(e.x,e.y+dy,r,team))e.y+=dy}
function losClear(x0,y0,x1,y1){
  const d=Math.hypot(x1-x0,y1-y0),st=Math.ceil(d/.2);let last=-1,skipped=false;
  for(let s=1;s<st;s++){
    const t=s/st,x=x0+(x1-x0)*t,y=y0+(y1-y0)*t,i=x|0,j=y|0;if(!inb(i,j))return false;const k=idx(i,j);
    if(coreKs.has(k)||terrShot(terr[k]))return false;const n=nodeAt(i,j);if(n&&n.solid)return false;
    const w=walls[k];if(w&&k!==last){last=k;if(!skipped&&d*t<1.35){skipped=true;continue}if(wallState(w)===0)return false}
  }
  return true;
}

/* ================= damage ================= */
// Knocking down a wall that isn't yours pays salvage: the yard's old ruins, or the other crew's walls in
// Base Battle. Your own side's walls never pay (or you could build and break them forever).
const WALL_SALVAGE=[5,8,15];
function wallPays(w,p){if(game.pvp==='ffa'||!p||w.slab)return false;if(w.tm)return w.tm!==p.team;return!w.crew}
function damageWall(k,amt,own){
  const w=walls[k];if(!w||w.mat===3)return;w.hp-=amt;w.flash=.08;markFlow();
  if(w.hp<=0){
    walls[k]=null;debris[k]=w.mat+1;game.stats.lost++;const i=k%N,j=(k/N)|0;
    const by=own&&own!=='dell'?players.get(own):null;   // walls[k] is already empty, so this can only pay once
    if(by&&!demo&&wallPays(w,by)){const v=WALL_SALVAGE[w.mat]||5;by.sal+=v;flt(i+.5,j+.3,`+${v} SALVAGE · ${MAT[w.mat].name} DOWN`,'#e2b436');personal(by,'restock')}
    emitSpread(i+.5,j+.5,.8,0,WH*.6,'chunk',w.mat,14);
    for(let n=0;n<6;n++)emit(i+.5,j+.5,WH*.4,'dust',w.mat);
    sfx('collapse',i+.5,j+.5);addShake(i+.5,j+.5,5);
  }
}
function hurtAlly(a,d){a===qm?hurtQM(d):hurtPlayer(a,d)}
function anyUp(p){if(qm.alive)return true;for(const o of players.values())if(o!==p&&o.alive)return true;return false}
function hurtPlayer(p,d,own){
  if(!p.alive||(game.pvp&&p.prot>0))return;
  d*=(p.perk||PERK0).vest;if(game.pvp&&hasMod('glass'))d*=1.5;   // Kevlar; Glass Cannon hits harder
  p.hp-=d;p.hurt=0;p.flash=.1;personal(p,'hurt');emit(p.x,p.y,16*u,'blood');
  if(p.hp<=0&&game.pvp){pvpDown(p,own);return}
  if(p.hp<=0){
    const help=anyUp(p),last=hasMod('laststand')&&game.phase==='raid';p.alive=false;p.downed=true;p.hp=0;p.revive=0;p.rt=last?1e6:help?10:4;
    if(p.id===myId)buzz(80);
    toastTo(p,'DOWN',last?'Last Stand: you\'re down until this raid is broken, unless someone gets you up.':help?'Hang on. Delgado or a teammate can pick you up.':'Back at the stake in a few seconds.');
    if(players.size>1)flt(p.x,p.y,`${p.name.toUpperCase()} IS DOWN`,'#d65a3a');
  }
}
function pvpDown(p,own){
  p.alive=false;p.downed=true;p.hp=0;p.revive=0;p.deaths++;if(p.id===myId)buzz(80);
  const k=own&&own!==p.id?players.get(own):null;
  sfx('drop',p.x,p.y);for(let n=0;n<6;n++)emit(p.x,p.y,10*u,'blood');
  if(k){k.kills+=game.sd?2:1;if(game.pvp==='base'){const v=hasMod('scrap')?Math.ceil(PVP.bounty/2):PVP.bounty;k.sal+=v;flt(p.x,p.y-.25,'+'+v,'#e2b436')}killFx(p.x,p.y,k.cos.fx);personal(k,'restock')}
  feed(k?`${k.name.toUpperCase()} ▸ ${p.name.toUpperCase()}`:`${p.name.toUpperCase()} WENT DOWN`,k?teamCol(k):'#9a8f7a');
  if(game.pvp==='base'){const help=[...players.values()].some(o=>o!==p&&o.alive&&o.team===p.team);p.rt=help?8:5;
    toastTo(p,'DOWN',help?'A teammate can pick you up. If not, you\'re back at your stake shortly.':'Back at your stake in a few seconds.')}
  else{p.rt=3;toastTo(p,'DROPPED',k?`${k.name} got you. Back in 3 seconds.`:'Back in 3 seconds.');
    if(k&&k.kills>=game.goal)endPvp(k.id)}
}
function revivePlayer(p,by){
  if(p.alive||!p.downed)return false;   // already up: a revive can only land once
  p.alive=true;p.downed=false;p.hp=p.max*(by?.6:.45);p.hurt=0;p.revive=0;game.stats.revives++;
  if(by){p.prot=Math.max(p.prot||0,.6);flt(p.x,p.y,`PATCHED UP BY ${by.name.toUpperCase()}`,'#8fe0a0');sfx('medic',p.x,p.y);emit(p.x,p.y,WH*.5,'heal');emit(p.x,p.y,WH*.7,'heal');emit(p.x,p.y,WH*.9,'heal');personal(by,'restock')}
  else{flt(p.x,p.y,'REVIVED','#a9bccb');sfx('revive',p.x,p.y)}
  return true;
}
// quartermaster: touching a downed teammate (or Delgado) gets them straight up, no kneeling
function medicTouch(p){
  if(!p.C.medic||!p.alive||game.pvp==='ffa')return;
  for(const o of players.values())if(o!==p&&o.downed&&!o.alive&&(!game.pvp||o.team===p.team)&&dist2(o,p)<.8)revivePlayer(o,p);
  if(!game.pvp&&!qm.alive&&!qm.gone&&dist2(qm,p)<.8){qm.alive=true;qm.hp=qm.max*.6;qm.revive=0;game.stats.revives++;flt(qm.x,qm.y,`DELGADO IS UP · ${p.name.toUpperCase()}`,'#8fe0a0');sfx('medic',qm.x,qm.y);emit(qm.x,qm.y,WH*.6,'heal');personal(p,'restock')}
}
function hurtQM(d){
  const q=qm;if(!q.alive)return;q.hp-=d;q.hurt=0;q.flash=.1;emit(q.x,q.y,16*u,'blood');
  if(q.hp<=0){q.alive=false;q.hp=0;q.revive=0;flt(q.x,q.y,'DELGADO IS DOWN','#d65a3a');toastAll('DELGADO IS DOWN','Stand over him to get him back up.')}
}
function hurtEnemy(e,d,own){
  e.hp-=d;e.flash=.08;emit(e.x,e.y,15*u,'blood');
  if(e.hp<=0&&!e.dead){e.dead=true;game.stats.dropped++;sfx('drop',e.x,e.y);for(let n=0;n<6;n++)emit(e.x,e.y,10*u,'blood');
    if(e.type==='boss'){if(!demo)bossDown(e,own);const p=own&&own!=='dell'?players.get(own):null;if(p){p.kills++;killFx(e.x,e.y,p.cos.fx)}}else award(own,e)}
}
function hurtStake(c,d){c.hp-=d;c.flash=.12;sfx('core',c.i+.5,c.j+.5);emit(c.i+.5,c.j+.5,WH*.8,'spark')}
function explode(x,y,R=1.65,power=1,own=null,raid=false){
  sfx(power>1.2?'bigboom':'boom',x,y);addShake(x,y,9*power);
  addFlash({x,y,life:.4,max:.4,r:R});
  for(let n=0;n<22*power;n++)emit(x,y,4*u,'fire');for(let n=0;n<10*power;n++)emit(x,y,4*u,'smoke');
  const fall=d=>d<.7?1:Math.max(0,1-(d-.7)/(R-.7));
  for(let i=Math.floor(x-R-1);i<=Math.floor(x+R+1);i++)for(let j=Math.floor(y-R-1);j<=Math.floor(y+R+1);j++){
    if(!inb(i,j))continue;const k=idx(i,j),f=fall(Math.hypot(i+.5-x,j+.5-y));if(f<=0)continue;
    const w=walls[k];if(w){if(w.mat===0&&f>.25){w.fire=6;w.fireBy=own}damageWall(k,80*f*power*MAT[w.mat].blast,own)}
  }
  crackBlast(x,y,R,power);
  const src=own?players.get(own):null;
  for(const c of cores){const f=fall(Math.hypot(c.i+.5-x,c.j+.5-y));if(f>0&&!(game.pvp&&src&&src.team===c.team))hurtStake(c,48*f*power)}
  if(!raid)for(const e of enemies){if(e.burrow)continue;const f=fall(Math.hypot(e.x-x,e.y-y));if(f>0)hurtEnemy(e,62*f*power,own)}
  if(game.pvp){for(const a of players.values()){if(!a.alive||(src&&!rivals(src,a)))continue;const f=fall(Math.hypot(a.x-x,a.y-y));if(f>0)hurtPlayer(a,50*f*power*PVP.nade,own)}}
  else for(const a of allies()){if(!a.alive)continue;const f=fall(Math.hypot(a.x-x,a.y-y));if(f>0)hurtAlly(a,50*f*power*(a===qm?.8:1))}
}
// Screen shake. `shake` is a decaying amplitude (px) for impacts and blasts; `kick` is a short directional
// shove for your own gunshots that springs back. Both follow the SCREEN SHAKE setting.
let kickX=0,kickY=0,shakeT=0;
function addShake(x,y,a){
  rec(['k',r2(x),r2(y),a]);
  const d=player?Math.hypot(x-player.x,y-player.y):6;const s=a*cfg.shake/(1+d*.35);shake=Math.min(12,shake+s);
  if(a>=10&&d<5&&!demo)buzz(35);
}
function localShake(a){if(!demo)shake=Math.min(12,shake+a*cfg.shake)}
function kickCam(dx,dy,a){if(demo)return;kickX+=dx*a*cfg.shake;kickY+=dy*a*cfg.shake;const l=Math.hypot(kickX,kickY);if(l>9){kickX*=9/l;kickY*=9/l}}
function shakeOffset(dt){
  shakeT+=dt;const k=Math.exp(-dt*18);kickX*=k;kickY*=k;
  if(shake<.05)return[kickX,kickY];
  const n=shakeT*60,s=shake*.5;   // two detuned waves read smoother than per-frame noise
  return[kickX+s*(Math.sin(n*1.71)*.6+Math.sin(n*3.13+1)*.4),kickY+s*(Math.sin(n*2.29+2)*.6+Math.sin(n*3.71)*.4)];
}
// feel for one soldier only: your own shots, your hits, getting hit
function feel(name){
  if(demo||!player)return;
  if(name==='~f'){const G=player.gun||{},sd=wdirToScreen(player.aim),heavy=!!G.pierce;kickCam(-sd.x,-sd.y,heavy?5:1.1);localShake(heavy?1.8:.25)}
  else if(name==='~h')localShake(.7);
  else if(name==='~H')localShake(2);
  else{sfx(name,undefined,undefined,true);if(name==='hurt'){buzz(15);localShake(2.4)}}
}
function feelHit(own,heavy){if(own==null||own==='dell')return;const p=players.get(own);if(p)personal(p,heavy?'~H':'~h')}

