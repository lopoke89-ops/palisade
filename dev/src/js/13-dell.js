/* ---------- Delgado, the quartermaster ---------- */
// Delgado's pump shotgun: 5 pellets x 6, every 0.8 s, full damage to 2.5 tiles, falling to 55% by 6.
// Each crew-bought level adds 15% damage, 15% reach (falloff and range) and 15% fire rate.
const DELL_GUN={dmg:6,cd:.8,spread:.2,range:6,speed:24,pellets:5,fall:[2.5,6,.55]};
function dellGun(){const L=game.dellLv|0,m=1+.15*L,G=DELL_GUN;
  return{dmg:G.dmg*m,cd:G.cd/m,spread:G.spread,range:G.range*m,speed:G.speed*(1+.1*L),pellets:G.pellets,fall:[G.fall[0]*m,G.fall[1]*m,G.fall[2]]}}
const tileOf=e=>idx(Math.floor(e.x),Math.floor(e.y));
const adj4=(k,t)=>{const a=k%N,b=(k/N)|0,c=t%N,d=(t/N)|0;return Math.abs(a-c)+Math.abs(b-d)===1};
function nearestPlayer(from,pred){let best=null,bd=1e9;for(const p of players.values()){if(!pred(p))continue;const d=dist2(p,from);if(d<bd){bd=d;best=p}}return best}
function qmJob(){
  const q=qm;
  const down=nearestPlayer(q,p=>p.downed);
  if(down){const tk=tileOf(down);return{name:'revive',who:down,goal:k=>k===tk,pt:down,near:.9}}
  // burning or battered walls inside the compound
  let best=null,bs=1e9;
  for(let k=0;k<N*N;k++){const w=walls[k];if(!w||w.skip>0)continue;const i=k%N,j=(k/N)|0;
    if(Math.max(Math.abs(i-core.i),Math.abs(j-core.j))>6)continue;
    if(!(w.fire>0||w.hp/w.max<.7))continue;if(q.mats[w.mat]<MAT[w.mat].rep&&!(w.fire>0))continue;
    const s=Math.hypot(i+.5-q.x,j+.5-q.y)-(w.fire>0?4:0);if(s<bs){bs=s;best=k}}
  if(best!==null){const k=best;return{name:'repair',k,goal:t=>adj4(t,k),pt:{x:k%N+.5,y:((k/N)|0)+.5},near:1.35}}
  if(game.phase==='build'){
    if(q.mats[0]<32){let n=null,nd=1e9;for(const o of nodes)if(o.type===0&&o.amt>0){const d=Math.hypot(o.i+.5-q.x,o.j+.5-q.y);if(d<nd){nd=d;n=o}}
      if(n)return{name:'gather',node:n,goal:k=>k===idx(n.i,n.j),pt:{x:n.i+.5,y:n.j+.5},near:.9}}
    for(const t of[1,2]){const n=nodes.find(o=>o.type===t&&!o.locked);if(n&&q.mats[t]<QM_RESERVE[t]+12){const nk=idx(n.i,n.j);return{name:'gather',node:n,goal:k=>adj4(k,nk),pt:{x:n.i+.5,y:n.j+.5},near:1.3}}}
    const needy=nearestPlayer(q,p=>p.alive&&[0,1,2].some(m=>q.mats[m]>QM_RESERVE[m]&&p.mats[m]<p.cap[m]));
    if(needy){const tk=tileOf(needy);return{name:'handoff',who:needy,goal:k=>k===tk,pt:needy,near:1.3}}
  }
  return{name:'hold',goal:k=>{const i=k%N,j=(k/N)|0,c=Math.max(Math.abs(i-core.i),Math.abs(j-core.j));return c===1&&!walls[k]},hold:true};
}
function updateQM(dt){
  const q=qm;if(q.gone)return;q.cd=Math.max(q.cd-dt,-dt);q.sup-=dt;q.pathT-=dt;q.gt=Math.max(q.gt-dt,-dt);q.scanT-=dt;q.hurt+=dt;q.flash=Math.max(0,q.flash-dt);
  for(const w of walls)if(w&&w.skip>0)w.skip-=dt;
  if(!q.alive){
    const helper=nearestPlayer(q,p=>p.alive);
    if(helper&&dist2(helper,q)<1.0){q.revive+=dt;if(q.revive>=2){q.alive=true;q.hp=q.max*.45;q.revive=0;game.stats.revives++;flt(q.x,q.y,'DELGADO IS UP','#a9bccb');sfx('revive',q.x,q.y)}}
    else q.revive=Math.max(0,q.revive-dt*.5);
    return;
  }
  if(q.hurt>5)q.hp=Math.min(q.max,q.hp+3*dt);
  const DG=dellGun();
  if(q.scanT<=0){q.scanT=.2;q.foe=null;let bd=Math.max(5.2,DG.range*.9);for(const e of enemies){if(e.burrow)continue;const d=dist2(e,q);if(d<bd&&losClear(q.x,q.y,e.x,e.y)){bd=d;q.foe=e}}}
  if(q.foe&&q.foe.dead)q.foe=null;
  const job=qmJob();if(job.name!==q.job){q.job=job.name;q.work=0;q.pathT=0}
  const here=tileOf(q);let busy=false,reached=job.hold?job.goal(here):dist2(q,job.pt)<=job.near;
  if(reached){
    if(job.name==='revive'){busy=true;job.who.revive+=dt*(job.who.perk||PERK0).revive}
    else if(job.name==='repair'){busy=true;q.work+=dt;const w=walls[job.k];if(w&&q.work>=.9){q.work=0;if(w.fire>0){w.fire=0;flt(job.pt.x,job.pt.y,'DOUSED','#a9bccb')}else{w.hp=Math.min(w.max,w.hp+w.max*.45);q.mats[w.mat]-=MAT[w.mat].rep;game.stats.repairs++;flt(job.pt.x,job.pt.y,'REPAIRED','#a9bccb')}markFlow();sfx('place'+w.mat,job.pt.x,job.pt.y)}}
    else if(job.name==='gather'){const n=job.node;if(q.gt<=0){const y=Math.min(YIELD[n.type],n.type===0?n.amt:99);q.mats[n.type]+=y;if(n.type===0)n.amt-=y;q.gt+=RATE[n.type]*1.5;emit(n.i+.5,n.j+.5,10*u,n.type===0?'splinter':n.type===1?'dust':'spark',n.type)}}
    else if(job.name==='handoff'){const p=job.who,got=[0,0,0];for(let m=0;m<3;m++){const give=Math.max(0,Math.min(q.mats[m]-QM_RESERVE[m],p.cap[m]-p.mats[m]));q.mats[m]-=give;p.mats[m]+=give;got[m]=give}
      const s=got.map((v,m)=>v?`+${v} ${MAT[m].name}`:'').filter(Boolean).join(' ');if(s){flt(p.x,p.y,s,'#e2b436');sfx('restock',p.x,p.y)}}
  }else{
    if(q.pathT<=0){q.pathT=.25;q.next=teamPath(here%N,(here/N)|0,job.goal)}
    if(q.next>=0){const tgt=q.next===here?(job.pt||{x:here%N+.5,y:((here/N)|0)+.5}):{x:q.next%N+.5,y:((q.next/N)|0)+.5};
      const dx=tgt.x-q.x,dy=tgt.y-q.y,l=Math.hypot(dx,dy);if(l>.03){const s=Math.min(l,2.9*dt*slowAt(q.x,q.y));moveEnt(q,dx/l*s,dy/l*s,true);q.walk+=dt*9;if(!q.foe)q.aim={x:dx/l,y:dy/l}}}
    else if(job.name==='repair'){const w=walls[job.k];if(w)w.skip=4}
  }
  if(q.foe){const dx=q.foe.x-q.x,dy=q.foe.y-q.y,l=Math.hypot(dx,dy)||1;q.aim={x:dx/l,y:dy/l};
    if(!busy&&q.cd<=0){const a=Math.atan2(dy,dx);while(q.cd<=0){for(let i=0;i<DG.pellets;i++)fire(q,a+(i/(DG.pellets-1)-.5)*DG.spread+(rnd()-.5)*DG.spread*.3,0,DG,-q.cd,i>0);q.cd+=DG.cd}sfx('shotgun',q.x,q.y)}}
  if(q.sup<=0){let gave=false;
    for(const p of players.values())if(p.alive&&dist2(p,q)<1.7&&(p.nades<p.maxN||p.hp<p.max*.7)){p.nades=Math.min(p.maxN+1,p.nades+1);p.hp=Math.min(p.max,p.hp+35);flt(p.x,p.y,'RESTOCK · +1 NADE','#e2b436');sfx('restock',p.x,p.y);gave=true}
    if(gave)q.sup=30}
}

