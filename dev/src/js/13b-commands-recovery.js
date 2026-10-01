/* Host-authoritative Delgado orders and terminal crew recovery. */
function setQMMode(mode){
 if(NET.mode==='guest'||qm.gone||game.pvp||game.phase==='over'||!['follow','defend'].includes(mode))return false;
 qm.mode=mode;qm.job='';qm.jobKey='';qm.pathT=0;qm.planT=0;qm.commandJob=null;syncQMControls();return true;
}
let qmControlKey='';
function syncQMControls(){
 const visible=!demo&&!game.pvp&&!qm.gone&&game.phase!=='over',guest=NET.mode==='guest';
 const key=[visible,guest,qm.mode,qm.status,qm.layoutSize,qm.completedRaids].join('|');if(key===qmControlKey)return;qmControlKey=key;
 $('qmCommand').hidden=!visible;$('qmOrders').hidden=!visible;
 $('qmCommand').disabled=guest;$('qmCommand').textContent=qm.mode==='defend'?'DELGADO · DEFEND':'DELGADO · FOLLOW';
 $('qmCommand').title=guest?'The host commands Delgado':'Switch Delgado between following the host and defending the core';
 for(const b of document.querySelectorAll('[data-qm]')){b.disabled=guest;b.classList.toggle('sel',b.dataset.qm===qm.mode);b.setAttribute('aria-pressed',String(b.dataset.qm===qm.mode))}
 $('qmOrderStatus').textContent=(guest?'Host command · ':'')+(qm.status||'')+(qm.mode==='defend'?` · ${qm.layoutSize||4}×${qm.layoutSize||4} · tier ${1+Math.min(2,Math.floor((qm.completedRaids||0)/5))}`:'');
}
function qmReach(goal){const k=tileOf(qm);return inb(k%N,(k/N)|0)&&teamPath(k%N,(k/N)|0,goal)>=0}
function qmSafePlacement(b){
 const k=idx(b.i,b.j);if(b.door||walls[k])return true;
 const starts=[...players.values()].filter(p=>p.alive||p.downed).concat(qm),goals=[t=>Math.max(Math.abs(t%N-core.i),Math.abs(((t/N)|0)-core.j))>2,t=>Math.max(Math.abs(t%N-core.i),Math.abs(((t/N)|0)-core.j))===1];
 const reachable=(p,goal)=>teamPath(Math.floor(p.x),Math.floor(p.y),goal)>=0;
 const before=starts.map(p=>goals.map(goal=>reachable(p,goal))),prev=walls[k];walls[k]={door:false};
 try{return starts.every((p,i)=>goals.every((goal,j)=>!before[i][j]||reachable(p,goal)))}finally{walls[k]=prev}
}
function qmCanRevive(p){
 if(!qm.alive||qm.gone||!p.downed||p.out)return false;
 const goal=k=>heightDist(k%N+.5,((k/N)|0)+.5,p.x,p.y)<.9&&heightRayClear(k%N+.5,((k/N)|0)+.5,p.x,p.y);
 return heightDist(qm.x,qm.y,p.x,p.y)<.9&&heightRayClear(qm.x,qm.y,p.x,p.y)||qmReach(goal);
}
function qmLayout(){
 const anchor=game.map+':'+core.i+':'+core.j;
 if(qm.layoutAnchor===anchor)return qm.layout;
 const make=n=>{const a=[];for(let y=0;y<n;y++)for(let x=0;x<n;x++)if(x===0||y===0||x===n-1||y===n-1){const i=core.i-1+x,j=core.j-1+y,k=idx(i,j);a.push({i,j,k,door:x===1||y===1})}return a};
 const legal=t=>inb(t.i,t.j)&&!coreKs.has(t.k)&&!nodeAt(t.i,t.j)&&!terrNoBuild(t.k,!!walls[t.k]);
 const four=make(4),three=make(3);qm.layoutSize=four.every(legal)?4:3;
 // Four starts one tile NW of the core; interior contains the core and three free cells. Doors on all sides preserve access.
 qm.layout=(qm.layoutSize===4?four:three).filter(legal).sort((a,b)=>Number(b.door)-Number(a.door)||a.k-b.k);qm.layoutAnchor=anchor;
 return qm.layout;
}
function qmGather(mat,limit=Infinity){
 const ns=nodes.filter(n=>n.type===mat&&!n.locked&&(mat!==0||n.amt>0)&&heightDist(qm.x,qm.y,n.i+.5,n.j+.5)<=limit).sort((a,b)=>Math.hypot(a.i+.5-qm.x,a.j+.5-qm.y)-Math.hypot(b.i+.5-qm.x,b.j+.5-qm.y));
 for(const n of ns){const nk=idx(n.i,n.j),goal=k=>mat===0?k===nk:adj4(k,nk);if(qmReach(goal))return{name:'gather',node:n,goal,pt:{x:n.i+.5,y:n.j+.5},near:mat===0?.9:1.3}}
 return null;
}
function qmCommandJob(){
 const q=qm,host=NET.mode==='guest'?null:players.get(myId),follow=q.mode==='follow'&&host&&!host.out;
 for(const p of [...players.values()].filter(p=>p.downed&&!p.out).sort((a,b)=>dist2(a,q)-dist2(b,q)))if(qmCanRevive(p))return{name:'revive',who:p,goal:k=>heightDist(k%N+.5,((k/N)|0)+.5,p.x,p.y)<.9,pt:p,near:.9};
 const layout=qmLayout(),allowed=new Set(layout.map(t=>t.k)),lock=hasMod('lockdown')&&!!game.fb;
 for(let k=0;k<walls.length;k++){const w=walls[k];if(lock||!w||w.skip>0||w.mat>2||!(w.fire>0||w.hp/w.max<.7))continue;
  if(follow?dist2(host,{x:k%N+.5,y:((k/N)|0)+.5})>3:!allowed.has(k))continue;
  if(q.mats[w.mat]<MAT[w.mat].rep&&!w.fire)continue;
  const goal=t=>adj4(t,k);if(qmReach(goal))return{name:'repair',k,goal,pt:{x:k%N+.5,y:((k/N)|0)+.5},near:1.35};
 }
 if(!follow&&game.phase==='build'&&!lockdown()){
  const tier=Math.min(2,Math.floor((q.completedRaids||0)/5));let need=-1,blocked=false;
  for(const t of layout){const w=walls[t.k];if(w&&w.mat>=tier)continue;
   const mat=w?Math.min(tier,w.mat+1):tier,goal=k=>adj4(k,t.k)&&heightRayClear(k%N+.5,((k/N)|0)+.5,t.i+.5,t.j+.5);
   q.C={build:1,repair:1};const b=buildEval(q,t.i,t.j,mat,w?w.door:t.door);
   if(!b.ok){if(b.reason.startsWith('Need'))need=mat;else blocked=true;continue}
   if(qmReach(goal)&&qmSafePlacement(b)){q.status=w?'Upgrading perimeter':'Building perimeter';return{name:'construct',k:t.k,goal,pt:{x:t.i+.5,y:t.j+.5},near:1.35,build:b}}blocked=true;
  }
  if(need>=0){q.status='Gathering '+MAT[need].name.toLowerCase();const job=qmGather(need);if(job)return job;q.status='Waiting for '+MAT[need].name.toLowerCase()}
  else q.status=blocked?'Perimeter partly blocked':'Perimeter ready';
 }else q.status=follow?'Following host':'Defending core';
 if(follow){
  if(game.phase==='build'&&dist2(q,host)<3){const needy=host.alive&&q.mats.some((n,m)=>n>QM_RESERVE[m]&&host.mats[m]<host.cap[m]);if(needy)return{name:'handoff',who:host,goal:k=>k===tileOf(host),pt:host,near:1.3};if(q.mats[0]<16){const job=qmGather(0,3);if(job)return job}}
  const goal=k=>heightDist(k%N+.5,((k/N)|0)+.5,host.x,host.y)<=1.8&&!solidTile(k%N,(k/N)|0,true);
  return{name:'follow',goal,hold:true,pt:host};
 }
 return{name:'hold',goal:k=>Math.max(Math.abs(k%N-core.i),Math.abs(((k/N)|0)-core.j))<=2&&!solidTile(k%N,(k/N)|0,true),hold:true};
}
function checkDeadEnd(){
 if(demo||NET.mode==='guest'||game.pvp||game.phase!=='raid')return false;
 const crew=[...players.values()].filter(p=>!p.out);if(!crew.length)return false;
 if(crew.some(p=>p.alive||p.downed&&Number.isFinite(p.rt)&&p.rt<100000))return false;
 // Remaining finite projectiles can settle into the already-earned preparation revival.
 if(!game.fb&&!game.queue.length&&!enemies.some(e=>!e.dead))return false;
 if(crew.some(qmCanRevive))return false;
 if(game.fb){game.fb.done=true;for(const p of players.values())p.res=p.out?'evac':'left'}
 endGame(!!(player&&player.out),'deadend');return true;
}
function showDeadEnd(){
 const run=game,remaining=Math.max(0,(run.endDeadline||performance.now()+2100)-performance.now());
 closeGameSettings(false);if(chatOpen())closeChat();
 $('pause').hidden=true;$('armory').hidden=true;$('deadEnd').hidden=remaining<=0;
 if(remaining>0){$('deadEnd').classList.remove('fading');setTimeout(()=>{if(game===run&&run.phase==='over')$('deadEnd').classList.add('fading')},Math.max(0,remaining-600))}
 setTimeout(()=>{if(game===run&&run.phase==='over'){$('deadEnd').hidden=true;$('over').hidden=false}},remaining);
}
