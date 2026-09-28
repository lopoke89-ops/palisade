/* ================= PvP layouts: every map has a Base Battle and a Free-for-all version (always 16×16) ================= */
// Base Battle is point-mirrored (tile i,j on one side is 15-i,15-j on the other), so both crews get the same ground.
// Free-for-all arenas are designed per map and turned four times (or mirrored) round the middle, with spawns on the
// same symmetry. Cover in Free-for-all can't be broken; each map dresses it differently (stacked timber, a shed's
// broken walls, stone). A layout returns {cores, nodes, ruins, cover:[[i,j,style]], pspawns:[[x,y]], teamSpawns, ramps}.
const PV_M2=([i,j])=>[15-i,15-j],PV_R4=([i,j])=>[15-j,i];
const pvMir=list=>[...list,...list.map(t=>[...PV_M2(t),...t.slice(2)])];
const pvRot=list=>{const out=[];for(const t of list){let c=t;for(let r=0;r<4;r++){out.push(c);c=[...PV_R4(c),...c.slice(2)]}}return out};
const pvPut=(list,t)=>{for(const[i,j]of list)if(inb(i,j))terr[idx(i,j)]=t};
const pvRotXY=list=>{const out=[];for(const p of list){let c=p;for(let r=0;r<4;r++){out.push(c);c=[16-c[1],c[0]]}}return out};
// the team spawn spots, laid out round a stake at (4,11); moved to the stake and mirrored for the other crew
const pvTeamSpawns=(ca)=>SPAWNS.map(([x,y])=>[x+ca[0]-4,y+ca[1]-11]);
const PVP_LAYOUTS={
  yard:{
    blurb:{base:'Today\'s yard, split down the middle: a stake each, the same piles and ruins on both sides.',ffa:'Stacked-timber lanes round an open middle, and two ruined sheds to fight over.'},
    base(){
      const L={cores:[[4,11],[11,4]],nodes:[],ruins:[]};
      L.nodes=pvMir([[2,8],[6,14],[1,13],[5,8]]).map(woodNode);
      L.nodes.push(kiln([1,6],0),kiln([14,9],0),scrap([7,13],0),scrap([8,2],0));
      L.ruins.push([pvMir([[3,9],[4,9],[5,9]]),0,.63,.25],[[[7,8],[8,7],[6,6],[9,9]],1,.55,.3]);
      return L},
    ffa(){
      // a ring of timber stacks three tiles in from the fence, open in the middle of each side and at the corners
      const cover=pvRot([[4,3,'timber'],[5,3,'timber'],[6,3,'timber'],[9,3,'timber'],[10,3,'timber'],[11,3,'timber'],[4,1,'timber'],[11,1,'timber']]);   // + a stack in each outer lane
      // two sheds in opposite inner corners, their open sides facing the middle
      cover.push(...pvMir([[4,5,'shed'],[4,6,'shed'],[5,5,'shed']]));
      return {cover,nodes:[],pspawns:pvRotXY([[1.5,1.5],[6.5,1.3]])}}
  },
  river:{
    blurb:{base:'The river runs corner to corner between the stakes. Two bridges and a ford on each side; both banks flood.',ffa:'Four islands round a deep pool, one bridge to each neighbour. Wading is slow.'},
    base(){
      const L={cores:[[3,12],[12,3]],nodes:[],ruins:[]};
      for(let j=0;j<16;j++)for(let i=0;i<16;i++)if(Math.abs(i-j)<=1)terr[idx(i,j)]=T_WATER;
      const block=(t,ty)=>{for(const[i,j]of[[t,t],[t+1,t],[t,t+1],[t+1,t+1]])if(inb(i,j)&&Math.abs(i-j)<=1)terr[idx(i,j)]=ty};
      for(const t of[1,5,9,13])block(t,T_BRIDGE);for(const t of[3,11])block(t,T_LOW);   // bridges, then the fords (shallow)
      const nearBridge=(i,j)=>{for(let a=-1;a<=1;a++)for(let b=-1;b<=1;b++)if(tAt(i+a,j+b)===T_BRIDGE)return true;return false};
      for(let j=0;j<16;j++)for(let i=0;i<16;i++)if(Math.abs(i-j)===2&&!nearBridge(i,j))terr[idx(i,j)]=T_LOW;   // low banks, the same on both sides
      L.nodes=pvMir([[1,9],[6,14],[5,7]]).map(woodNode);
      L.nodes.push(kiln([1,14],0),kiln([14,1],0),scrap([6,10],0),scrap([9,5],0),scrap([0,6],0),scrap([15,9],0));
      L.ruins.push([pvMir([[2,9],[3,9]]),0,.63,.25],[pvMir([[7,12],[8,12]]),1,.55,.3]);
      return L},
    ffa(){
      // channels along the middle row and column, widening into a pool; a bridge over each arm
      for(let j=0;j<16;j++)for(let i=0;i<16;i++)if(i===7||i===8||j===7||j===8||Math.hypot(i-7.5,j-7.5)<2.7)terr[idx(i,j)]=T_WATER;
      pvPut(pvRot([[7,3],[8,3],[7,4],[8,4]]),T_BRIDGE);
      const cover=pvRot([[3,3,'crate'],[4,3,'crate'],[3,4,'crate'],[6,5,'crate'],[3,1,'crate'],[1,5,'crate']]);
      return {cover,nodes:[],pspawns:pvRotXY([[1.5,1.5],[5.5,1.3]])}}
  },
  quarry:{
    blurb:{base:'Lit by drums, the same rock on both sides and a cracked middle. A ramp behind each stake.',ffa:'A stepped pit: a ring of ledges with ramps, rock pillars, and a cracked floor round a stone spire.'},
    base(){
      const L={cores:[[4,11],[11,4]],nodes:[],ruins:[],ramps:[[2,15],[3,15],[13,0],[12,0]]};
      for(let j=0;j<16;j++)for(let i=0;i<16;i++)if(Math.abs(i-7.5)+Math.abs(j-7.5)<=2.5)terr[idx(i,j)]=T_CRACK;
      pvPut(pvMir([[6,2],[2,6],[7,10],[10,13]]),T_ROCK);
      pvPut(pvMir([[1,9],[6,13],[5,6]]),T_DRUM);
      L.nodes=pvMir([[2,7],[5,13]]).map(woodNode);
      L.nodes.push(kiln([1,12],0),kiln([14,3],0),scrap([7,14],0),scrap([8,1],0),kiln([4,8],0),kiln([11,7],0));
      L.ruins.push([pvMir([[5,9],[6,9]]),1,.55,.3]);
      return L},
    ffa(){
      for(let j=0;j<16;j++)for(let i=0;i<16;i++)if(Math.abs(i-7.5)+Math.abs(j-7.5)<=3.5)terr[idx(i,j)]=T_CRACK;
      pvPut([[7,7],[8,7],[7,8],[8,8]],T_ROCK);                                              // the spire in the middle
      pvPut(pvRot([[5,5]]),T_ROCK);                                                        // four pillars
      pvPut(pvRot([[3,2],[4,2],[5,2],[10,2],[11,2],[12,2]]),T_ROCK);                        // the ledge ring; the gaps are ramps
      pvPut(pvRot([[4,1],[11,1]]),T_ROCK);                                                  // outcrops on the rim path
      pvPut(pvRot([[2,2],[7,4]]),T_DRUM);                                                  // drums light the rim and the ramps
      return {cover:[],nodes:[],pspawns:pvRotXY([[1.5,1.5],[8.5,.9]])}}
  }
};
for(const id in PVP_LAYOUTS){MAPS[id].pvpLay=PVP_LAYOUTS[id];MAPS[id].pvpBlurb=PVP_LAYOUTS[id].blurb;MAPS[id].modes=['coop','base','ffa']}
// lays a map's PvP version out (terrain first), for newGame and the map cards
function layPvp(id,pvp){
  const M=MAPS[id]||MAPS.yard,L=M.pvpLay[pvp]();
  const keep=new Set([...(L.cores||[]),...(L.nodes||[]).map(n=>[n.i,n.j]),...(L.ruins||[]).flatMap(r=>r[0]),...(L.cover||[])].map(([i,j])=>idx(i,j)));
  for(const k of keep)if(terr[k]!==T_GROUND&&terr[k]!==T_LOW&&terr[k]!==T_CRACK)terr[k]=T_GROUND;
  L.core=(L.cores&&L.cores[0])||[7,7];L.spawns=[];L.pvp=pvp;
  if(pvp==='base')L.teamSpawns=pvTeamSpawns(L.cores[0]);
  return L;
}
