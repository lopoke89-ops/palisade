/* ================= THE UNDERSTRIP: the seeded level generator ================= */
// dev/plans/understrip-generator.md is the spec. A level is a square of 8×8-tile cells; hand-made pieces from the region's
// room kit (dev/data/understrip/rooms-r1.json, inlined by build.py) are joined door to door from a seed, so the host and
// every guest build the same level from the same number. Nothing here touches the game's own random stream (rnd), the
// map or the game state: usGenerate returns a plain description that usLayMap (below) turns into terrain and markers.
// dev/test/understrip_gen.js loads this file on its own (no browser) and checks 10,000 seeds.
const US_KITS={1:/*@@US_KIT_R1@@*/null,2:/*@@US_KIT_R2@@*/null,3:/*@@US_KIT_R3@@*/null};
const US_CELL=8,US_SLOTS=[3,4],US_SIDES=['N','E','S','W'],US_OPP={N:'S',S:'N',E:'W',W:'E'},US_STEP={N:[0,-1],S:[0,1],E:[1,0],W:[-1,0]};
const US_WALKABLE=c=>c!=='#'&&c!=='%'&&c!=='o'&&c!=='t';
// the one random-number generator (mulberry32) and the seed mixer; integer maths only, so the Godot port matches bit for bit
function usRng(seed){let a=seed|0;return function(){a=a+0x6D2B79F5|0;let t=Math.imul(a^a>>>15,1|a);t=t+Math.imul(t^t>>>7,61|t)^t;return((t^t>>>14)>>>0)/4294967296}}
function usHash(...v){let h=0x9E3779B9|0;for(const x of v){h=Math.imul(h^(x|0),0x85EBCA6B);h^=h>>>13;h=Math.imul(h,0xC2B2AE35);h^=h>>>16}return h>>>0}
const usPick=(r,a)=>a[Math.floor(r()*a.length)];
function usWeighted(r,list,w){let tot=0;for(const x of list)tot+=w(x);let v=r()*tot;for(const x of list){v-=w(x);if(v<0)return x}return list[list.length-1]}
function usShuffle(r,a){for(let i=a.length-1;i>0;i--){const j=Math.floor(r()*(i+1));[a[i],a[j]]=[a[j],a[i]]}return a}

// ---------- the kit's pieces in every allowed turn and mirror ----------
// a variant: its rows, size in cells, doors [{side,cell}] and the shortcut's opening side
function usVariants(p){
  const out=[],seen=new Set(),turns=p.rotate?[0,1,2,3]:[0],mirrors=p.rotate?[0,1]:[0];
  for(const m of mirrors)for(const r of turns){
    let g=p.grid.map(row=>row.split(''));if(m)g=g.map(row=>row.slice().reverse());
    let side=p.opensFrom||'';if(m&&(side==='E'||side==='W'))side=US_OPP[side];
    for(let k=0;k<r;k++){const H=g.length,W=g[0].length,n=[];for(let x=0;x<W;x++){const row=[];for(let y=H-1;y>=0;y--)row.push(g[y][x]);n.push(row)}g=n;   // a quarter turn clockwise
      if(side)side={N:'E',E:'S',S:'W',W:'N'}[side]}
    const rows=g.map(row=>row.join('')),key=rows.join('/');if(seen.has(key))continue;seen.add(key);
    const H=rows.length,W=rows[0].length,cw=W/US_CELL,ch=H/US_CELL,doors=[];
    const isDoor=c=>c==='D'||c==='G';
    for(let c=0;c<cw;c++){if(isDoor(rows[0][c*US_CELL+3]))doors.push({side:'N',cell:c,gate:rows[0][c*US_CELL+3]==='G'});if(isDoor(rows[H-1][c*US_CELL+3]))doors.push({side:'S',cell:c,gate:rows[H-1][c*US_CELL+3]==='G'})}
    for(let c=0;c<ch;c++){if(isDoor(rows[c*US_CELL+3][0]))doors.push({side:'W',cell:c,gate:rows[c*US_CELL+3][0]==='G'});if(isDoor(rows[c*US_CELL+3][W-1]))doors.push({side:'E',cell:c,gate:rows[c*US_CELL+3][W-1]==='G'})}
    out.push({rows,cw,ch,doors,opensFrom:side})}
  return out;
}
// the cell a door sits in, and the cell outside it, for a piece placed at (cx,cy)
function usDoorCells(v,cx,cy,d){let x,y;if(d.side==='N'){x=cx+d.cell;y=cy}else if(d.side==='S'){x=cx+d.cell;y=cy+v.ch-1}else if(d.side==='W'){x=cx;y=cy+d.cell}else{x=cx+v.cw-1;y=cy+d.cell}
  const s=US_STEP[d.side];return{x,y,ox:x+s[0],oy:y+s[1]}}

// ---------- one level ----------
// seed: the level's own seed (usLevelSeed). kind: 'normal' or 'boss'; boss: which arena (a kit with two, region 3's). Returns {ok, seed, attempts, G, pieces, links, tiles, ...}
const US_GEN_FAILS={},usFail=why=>{US_GEN_FAILS[why]=(US_GEN_FAILS[why]|0)+1;return null};   // why attempts are thrown away (the generator test reports it)
const US_LEVEL={grid:{normal:7,boss:8},path:[8,12],branch:[.3,.4],tries:1500,restarts:120};
function usLevelSeed(runSeed,region,level){return usHash(runSeed,region,level)}
function usGenerate(kit,seed,kind='normal',boss=''){
  const V=kit.pieces.filter(p=>p.role!=='boss_arena'||!boss||!p.boss||p.boss===boss).map(p=>({p,vars:usVariants(p)}));
  for(let a=0;a<US_LEVEL.restarts;a++){const L=usTry(kit,V,(seed+a)>>>0,kind);if(L){L.seed=seed>>>0;L.attempts=a+1;return L}}
  return{ok:false,seed:seed>>>0,attempts:US_LEVEL.restarts};
}
function usTry(kit,V,seed,kind){
  const r=usRng(seed),G=US_LEVEL.grid[kind],occ=new Int16Array(G*G).fill(-1),pieces=[],links=[],used={};
  const byRole=role=>V.filter(x=>x.p.role===role);
  const inG=(x,y)=>x>=0&&y>=0&&x<G&&y<G;
  const free=(v,cx,cy)=>{if(cx<0||cy<0||cx+v.cw>G||cy+v.ch>G)return false;for(let y=0;y<v.ch;y++)for(let x=0;x<v.cw;x++)if(occ[(cy+y)*G+cx+x]>=0)return false;return true};
  const place=(e,v,cx,cy,tag)=>{const n=pieces.length;pieces.push({id:e.p.id,role:e.p.role,v,cx,cy,tag,ls:links.length});used[e.p.id]=(used[e.p.id]|0)+1;
    for(let y=0;y<v.ch;y++)for(let x=0;x<v.cw;x++)occ[(cy+y)*G+cx+x]=n;return n};
  // only the last piece is ever taken back, so every link made since it was placed goes with it
  const unplace=()=>{const P=pieces.pop();used[P.id]--;for(let y=0;y<P.v.ch;y++)for(let x=0;x<P.v.cw;x++)occ[(P.cy+y)*G+P.cx+x]=-1;links.length=P.ls};
  const link=(a,da,b,db,k)=>links.push({a,da,b,db,kind:k});
  const isLinked=(n,d)=>links.some(l=>(l.a===n&&l.da===d)||(l.b===n&&l.db===d));
  // a door of piece n whose outside cell is free, in the grid, and not linked yet
  const openDoors=n=>{const P=pieces[n],out=[];for(const d of P.v.doors){const c=usDoorCells(P.v,P.cx,P.cy,d);if(!inG(c.ox,c.oy)||occ[c.oy*G+c.ox]>=0||isLinked(n,d))continue;out.push({n,d,c})}return out};
  // every way a piece from entries can be placed so one of its doors meets the open door o.
  // A boss gate only ever joins the arena, and the arena only ever joins a gate.
  const fits=(entries,o,wantMore)=>{const out=[],arenaOpen=pieces[o.n].role==='boss_arena';
    for(const e of entries){if((used[e.p.id]|0)>=e.p.max)continue;const arena=e.p.role==='boss_arena';
      for(const v of e.vars)for(const d of v.doors){if(d.side!==US_OPP[o.d.side])continue;
        if(!((o.d.gate&&arena&&!d.gate)||(d.gate&&arenaOpen&&!o.d.gate)||(!o.d.gate&&!d.gate&&!arenaOpen&&!arena)))continue;
        const t=o.c,cx=d.side==='N'||d.side==='S'?t.ox-d.cell:d.side==='W'?t.ox:t.ox-v.cw+1,cy=d.side==='W'||d.side==='E'?t.oy-d.cell:d.side==='N'?t.oy:t.oy-v.ch+1;
        if(!free(v,cx,cy)||(wantMore&&v.doors.length<2))continue;out.push({e,v,cx,cy,d,o})}}
    return out};
  // 1-4. the critical path. A normal level grows from the entrance to the exit; a boss level grows backwards from the arena
  //      (arena, antechamber, ..., entrance) so the 3×3 arena always has room. Step s of the growth is path place at(s).
  const Lp=US_LEVEL.path[0]+Math.floor(r()*(US_LEVEL.path[1]-US_LEVEL.path[0]+1)),bMin=Math.max(2,Math.ceil(.4*(Lp-1))),bMax=Math.min(Lp-3,Math.floor(.7*(Lp-1))),bAt=bMin+Math.floor(r()*(bMax-bMin+1));
  const rev=kind==='boss',at=s=>rev?Lp-1-s:s;
  const mid=V.filter(x=>['corridor','junction','room'].includes(x.p.role)),narrow=V.filter(x=>x.p.role==='corridor'||x.p.role==='junction');
  const roleAt=i=>i===0?byRole('entrance'):i===bAt?byRole('breather'):rev&&i===Lp-2?byRole('boss_ante'):i===Lp-1?(rev?byRole('boss_arena'):byRole('exit')):i<=2?narrow:mid;
  {const e=usPick(r,roleAt(at(0))),v=usPick(r,e.vars);let ok=false;
    for(let t=0;t<80&&!ok;t++){const cx=Math.floor(r()*(G-v.cw+1)),cy=Math.floor(r()*(G-v.ch+1)),c=usDoorCells(v,cx,cy,v.doors[0]);
      const st=US_STEP[v.doors[0].side];if(inG(c.ox,c.oy)&&inG(c.ox+st[0],c.oy+st[1])){place(e,v,cx,cy,'path');ok=true}}
    if(!ok)return usFail('start');pieces[0].at=at(0)}
  let tries=0;const cand=[];
  for(let s=1;s<Lp;){
    if(++tries>US_LEVEL.tries)return usFail('path tries');
    if(!cand[s]){const last=s===Lp-1;let all=[];for(const o of openDoors(s-1))all.push(...fits(roleAt(at(s)),o,!last));
      if(rev&&s===1)all=all.filter(f=>f.d.gate);   // the antechamber joins the arena by its gate
      cand[s]=all}
    if(!cand[s].length){cand[s]=null;if(s===1)return usFail('path dead end');unplace();s--;continue}
    const f=usWeighted(r,cand[s],c=>c.e.p.weight);cand[s].splice(cand[s].indexOf(f),1);
    const n=place(f.e,f.v,f.cx,f.cy,'path');link(s-1,f.o.d,n,f.d,'path');pieces[n].at=at(s);s++;cand[s]=null}
  // 6. the shortcut: a route through free cells from a spare door of a late piece to a spare door of a piece at or before the
  //    breather, filled with one-cell pieces; the shortcut door sits on a straight stretch and opens only from the late side
  const lateFrom=Math.max(bAt+2,Math.ceil(Lp*2/3)),isLate=n=>pieces[n].tag==='path'&&pieces[n].at>=lateFrom&&!['boss_arena','boss_ante','exit'].includes(pieces[n].role);
  const one=V.filter(x=>['corridor','junction','room'].includes(x.p.role)&&x.vars[0].cw===1&&x.vars[0].ch===1),scE=byRole('shortcut');
  const isEarly=n=>pieces[n].tag==='path'&&pieces[n].at>0&&pieces[n].at<=bAt;
  const has=(v,sides)=>sides.every(sd=>v.doors.some(q=>q.side===sd&&q.cell===0));
  const sidesOf=n=>links.filter(l=>l.a===n||l.b===n).map(l=>l.a===n?l.da.side:l.db.side);
  // the ways out of piece n toward side sd: its own spare door, or (a one-cell corridor, junction or room) a swap to a piece
  // that has the doors it already uses plus that one
  const upgrade=(n,sd)=>{const P=pieces[n],cur=sidesOf(n).concat([sd]);if(P.v.cw!==1||P.v.ch!==1||!['corridor','junction','room'].includes(P.role))return null;
    const opts=[];for(const e of one)if(e.p.id===P.id||(used[e.p.id]|0)<e.p.max)for(const v of e.vars)if(has(v,cur))opts.push({e,v});return opts.length?opts:null};
  const ports=pred=>{const out=[];pieces.forEach((P,n)=>{if(!pred(n))return;
    for(const o of openDoors(n))out.push({n,side:o.d.side,ox:o.c.ox,oy:o.c.oy,d:o.d});
    if(P.v.cw===1&&P.v.ch===1)for(const sd of US_SIDES){if(P.v.doors.some(q=>q.side===sd))continue;const x=P.cx+US_STEP[sd][0],y=P.cy+US_STEP[sd][1];
      if(inG(x,y)&&occ[y*G+x]<0&&upgrade(n,sd))out.push({n,side:sd,ox:x,oy:y,up:true})}});return out};
  const applyUp=(pt)=>{if(!pt.up)return pt.d;const P=pieces[pt.n],f=usWeighted(r,upgrade(pt.n,pt.side),o=>o.e.p.id===P.id?4:o.e.p.weight);
    used[P.id]--;used[f.e.p.id]=(used[f.e.p.id]|0)+1;const old=P.v;P.id=f.e.p.id;P.role=f.e.p.role;P.v=f.v;
    for(const l of links){if(l.a===pt.n)l.da=f.v.doors.find(q=>q.side===l.da.side);if(l.b===pt.n)l.db=f.v.doors.find(q=>q.side===l.db.side)}
    return f.v.doors.find(q=>q.side===pt.side)};
  const earlyAt=new Map();for(const pt of ports(isEarly)){const k=pt.oy*G+pt.ox;earlyAt.set(k,(earlyAt.get(k)||[]).concat([pt]))}
  let scDone=false;
  for(const lo of usShuffle(r,ports(isLate))){if(scDone)break;
    // breadth-first over free cells from the cell outside the late piece
    const s0=lo.oy*G+lo.ox,prev=new Int16Array(G*G).fill(-2),dep=new Int8Array(G*G);prev[s0]=-1;const q=[s0],goals=[];
    for(let h=0;h<q.length;h++){const k=q[h];
      // the walk from the level's start to the late piece: along the path, or through the early piece and this route.
      // Keep routes that save at least two pieces (a squad that falls before resting doesn't redo the whole level)
      if(earlyAt.has(k))for(const e of earlyAt.get(k)){if(e.n===lo.n)continue;const gain=pieces[lo.n].at-(pieces[e.n].at+dep[k]+2);if(gain>=2)goals.push({k,e,gain})}
      if(dep[k]>=(kind==="boss"?5:4))continue;
      for(const sd of US_SIDES){const x=k%G+US_STEP[sd][0],y=((k/G)|0)+US_STEP[sd][1];if(!inG(x,y))continue;const kk=y*G+x;if(prev[kk]!==-2||occ[kk]>=0)continue;prev[kk]=k;dep[kk]=dep[k]+1;q.push(kk)}}
    if(!goals.length)continue;
    const best=Math.max(...goals.map(g2=>g2.gain)),gl=usPick(r,goals.filter(g2=>g2.gain===best)),goal=gl.k,eo=gl.e;
    const route=[];for(let k=goal;k!==-1;k=prev[k])route.unshift(k);
    const sideTo=(a,b)=>{const dx=b%G-a%G,dy=((b/G)|0)-((a/G)|0);return dx===1?'E':dx===-1?'W':dy===1?'S':'N'};
    const need=route.map((k,i)=>[i===0?US_OPP[lo.side]:sideTo(k,route[i-1]),i===route.length-1?US_OPP[eo.side]:sideTo(k,route[i+1])]);
    const straight=need.map((nd,i)=>US_OPP[nd[0]]===nd[1]?i:-1).filter(i=>i>=0);if(!straight.length)continue;
    // can every cell be filled? (checked before anything changes)
    const si=usPick(r,straight),plan=[];
    for(let i=0;i<route.length;i++){const[back,on]=need[i],opts=[];
      if(i===si){for(const e of scE)if((used[e.p.id]|0)<e.p.max)for(const v of e.vars)if(v.opensFrom===back&&has(v,[back,on]))opts.push({e,v,x:1})}
      else for(const e of one){const cnt=(used[e.p.id]|0)+plan.filter(o=>o.e===e).length;if(cnt<e.p.max)for(const v of e.vars)if(has(v,[back,on]))opts.push({e,v,x:v.doors.length===2?3:1})}
      if(!opts.length){plan.length=0;break}plan.push(usWeighted(r,opts,o=>o.e.p.weight*o.x))}
    if(plan.length!==route.length)continue;
    const dLate=applyUp(lo),dEarly=applyUp(eo);let prevN=lo.n,prevD=dLate;
    route.forEach((k,i)=>{const f=plan[i],[back,on]=need[i],n=place(f.e,f.v,k%G,(k/G)|0,'shortcut');link(prevN,prevD,n,f.v.doors.find(q=>q.side===back),'shortcut');prevN=n;prevD=f.v.doors.find(q=>q.side===on)});
    link(prevN,prevD,eo.n,dEarly,'shortcut');scDone=true}
  if(!scDone)return usFail('shortcut');
  // 5. branches: 30-40% of all pieces, the merchant first, then corridors and rooms ending in caches (or a second merchant).
  //    A branch starts at a spare door or, on a one-cell piece, at a door added by a swap (as the shortcut's ends are)
  const pathN=Lp,nbMin=Math.ceil(US_LEVEL.branch[0]*pathN/(1-US_LEVEL.branch[0])),nbMax=Math.floor(US_LEVEL.branch[1]*pathN/(1-US_LEVEL.branch[1]));
  const target=nbMin+Math.floor(r()*(nbMax-nbMin+1)),inner=V.filter(x=>['corridor','junction','room'].includes(x.p.role));
  const merchant=byRole('merchant'),cache=byRole('cache');let nb=0,merchants=0;
  const rootOK=n=>(pieces[n].tag==='path'||pieces[n].tag==='branch')&&!['boss_arena','boss_ante','exit','merchant','cache','entrance'].includes(pieces[n].role);
  const virt=pt=>({n:pt.n,d:pt.d||{side:pt.side,cell:0,gate:false},c:{ox:pt.ox,oy:pt.oy}});
  const attach=(pt,pool,wantMore)=>{const fs=fits(pool,virt(pt),wantMore);if(!fs.length)return -1;const real=applyUp(pt),f=usWeighted(r,fs,x=>x.e.p.weight);
    const b=place(f.e,f.v,f.cx,f.cy,'branch');link(pt.n,real,b,f.d,'branch');nb++;if(f.e.p.role==='merchant')merchants++;return b};
  // the merchant: straight off the path, or one corridor out
  for(const pt of usShuffle(r,ports(rootOK))){if(attach(pt,merchant,false)>=0)break}
  if(!merchants)for(const pt of usShuffle(r,ports(rootOK))){if(merchants)break;const fs=fits(inner,virt(pt),true);if(!fs.length)continue;
    const b=attach(pt,inner,true);for(const p2 of ports(n=>n===b))if(attach(p2,merchant,false)>=0)break;if(!merchants)break}
  for(let guard=0;nb<target&&guard<120;guard++){
    const opts=ports(rootOK);if(!opts.length)break;let pt=usPick(r,opts);const len=Math.min(target-nb,1+Math.floor(r()*3));
    for(let k=0;k<len;k++){const last=k===len-1,pool=last?(r()<.25?merchant:cache):inner;
      let b=attach(pt,pool,!last);if(b<0&&last)b=attach(pt,inner,false);if(b<0)break;if(last)break;
      const nx=ports(n=>n===b);if(!nx.length)break;pt=usPick(r,nx)}}
  if(nb<nbMin||nb>nbMax||!merchants)return usFail(!merchants?'no merchant':'branches');
  return usBuild(kit,seed,kind,G,pieces,links,{pathN,branchN:nb,breatherAt:bAt,pathLen:Lp});
}
// 7-8. seal the doors that meet nothing, lay the tiles and collect the markers
function usBuild(kit,seed,kind,G,pieces,links,info){
  const T=G*US_CELL,tiles=[];for(let y=0;y<T;y++)tiles.push(new Array(T).fill('#'));
  const linked=new Set();for(const l of links){linked.add(pieces[l.a].v.doors.indexOf(l.da)+'@'+l.a);linked.add(pieces[l.b].v.doors.indexOf(l.db)+'@'+l.b)}
  const rooms=[];
  pieces.forEach((P,n)=>{const ox=P.cx*US_CELL,oy=P.cy*US_CELL;
    for(let y=0;y<P.v.rows.length;y++)for(let x=0;x<P.v.rows[0].length;x++)tiles[oy+y][ox+x]=P.v.rows[y][x];
    P.v.doors.forEach((d,k)=>{if(linked.has(k+'@'+n))return;const c=usDoorCells(P.v,P.cx,P.cy,d),lx=(c.x-P.cx)*US_CELL,ly=(c.y-P.cy)*US_CELL;
      const at=d.side==='N'?[[3,0],[4,0]]:d.side==='S'?[[3,7],[4,7]]:d.side==='W'?[[0,3],[0,4]]:[[7,3],[7,4]];
      for(const[a,b]of at)tiles[oy+ly+b][ox+lx+a]='#'});
    rooms.push({id:P.id,role:P.role,tag:P.tag,at:P.at===undefined?-1:P.at,x:ox,y:oy,w:P.v.rows[0].length,h:P.v.rows.length,light:kit.pieces.find(q=>q.id===P.id).light,opensFrom:P.v.opensFrom||''})});
  const marks={};for(let y=0;y<T;y++)for(let x=0;x<T;x++){const c=tiles[y][x];if('PESMCABLnKG'.includes(c))(marks[c]=marks[c]||[]).push([x,y])}
  return{ok:true,kind,G,T,tiles:tiles.map(r=>r.join('')),rooms,marks,links:links.map(l=>({a:l.a,b:l.b,kind:l.kind})),...info};
}
// a level's fingerprint (the two-client and port tests compare these)
function usTileHash(L){let h=0x811C9DC5|0;for(const row of L.tiles)for(let i=0;i<row.length;i++){h^=row.charCodeAt(i);h=Math.imul(h,0x01000193)}return h>>>0}
