// THE UNDERSTRIP level generator (dev/src/js/06g-understrip.js, spec dev/plans/understrip-generator.md), with no browser:
// for thousands of seeds per level kind in every region (each boss's arena), every level builds; the same seed always gives the same tiles; everything is
// reachable from the start with the shortcut open; the exit is reachable with it shut; the shortcut really shortens the
// walk from the level's start to the far end; the boss arena is only reached through its gate; the path is 8-12 pieces and 30-40% of
// pieces are on branches; there is a merchant; the map's edge is wall. Also writes a seed->hash fixture for the Godot port.
// node understrip_gen.js [seeds per kind, default 3000]
const assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path'),vm=require('node:vm');
const ROOT=path.join(__dirname,'../..'),N=+process.argv[2]||3000;
function loadGen(){
  let src=fs.readFileSync(path.join(ROOT,'dev/src/js/06g-understrip.js'),'utf8');
  for(const r of[1,2,3]){const mark=`/*@@US_KIT_R${r}@@*/null`;assert.ok(src.includes(mark),'no marker for region '+r);src=src.replace(mark,fs.readFileSync(path.join(ROOT,`dev/data/understrip/rooms-r${r}.json`),'utf8'))}
  const ctx=vm.createContext({});vm.runInContext(src+'\n;globalThis.__us={usGenerate,usLevelSeed,usTileHash,usRng,usHash,US_KITS};',ctx);return ctx.__us;
}
const U=loadGen(),out={};
const walk=(c,open)=>c!=='#'&&c!=='%'&&c!=='o'&&c!=='t'&&(c!=='K'||open.K)&&(c!=='G'||open.G!==false);
function bfs(L,from,open){const T=L.T,d=new Int32Array(T*T).fill(-1),q=[from[1]*T+from[0]];d[q[0]]=0;
  for(let h=0;h<q.length;h++){const k=q[h],x=k%T,y=(k/T)|0;for(const[a,b]of[[1,0],[-1,0],[0,1],[0,-1]]){const X=x+a,Y=y+b;if(X<0||Y<0||X>=T||Y>=T)continue;const kk=Y*T+X;if(d[kk]>=0||!walk(L.tiles[Y][X],open))continue;d[kk]=d[k]+1;q.push(kk)}}
  return d}
const at=(L,p)=>p[1]*L.T+p[0];
// every region's level kinds: two normal levels and the boss's (region 3 has two bosses, the Gatekeeper and the finale).
// Region 1 gets the full count; the deeper kits share its shapes, so a third of it each
const CASES=[[1,'normal',''],[1,'boss','pitboss'],[2,'normal',''],[2,'boss','custodian'],[3,'normal',''],[3,'boss','gatekeeper'],[3,'boss','visitor']];
const t0=Date.now(),stats={},fixture=[];let built=0;
for(const[reg,kind,boss]of CASES){const key=`r${reg} ${boss||kind}`,kit=U.US_KITS[reg],n=reg===1?N:Math.ceil(N/3);stats[key]={att:0,max:0,path:[],br:[],n};
 for(let s=0;s<n;s++){built++;
  const seed=U.usLevelSeed(1234+s,reg,kind==='boss'?(boss==='visitor'?4:3):1+(s&1)),L=U.usGenerate(kit,seed,kind,boss),tag=`${key} seed ${seed}`;
  assert.ok(L.ok,`${tag}: no level after ${L.attempts} attempts`);
  if(boss)assert.equal(L.rooms.find(r=>r.role==='boss_arena').id,`r${reg}_boss_${boss}`,`${tag}: the wrong arena`);
  const L2=U.usGenerate(kit,seed,kind,boss);assert.equal(U.usTileHash(L2),U.usTileHash(L),`${tag}: not deterministic`);
  if(s<200)fixture.push([reg,boss||kind,seed,U.usTileHash(L)]);
  const S=stats[key];S.att+=L.attempts;S.max=Math.max(S.max,L.attempts);S.path.push(L.pathLen);S.br.push(L.branchN/(L.pathN+L.branchN+L.rooms.filter(r=>r.tag==='shortcut').length*0));
  assert.equal(L.T,L.G*8);assert.ok(L.T>=48&&L.T<=64,`${tag}: ${L.T} tiles`);
  for(let i=0;i<L.T;i++)for(const c of[L.tiles[0][i],L.tiles[L.T-1][i],L.tiles[i][0],L.tiles[i][L.T-1]])assert.equal(c,'#',`${tag}: the map's edge is open`);
  const M=L.marks;assert.equal((M.P||[]).length,6,`${tag}: start spots`);assert.equal((M.E||[]).length,1,`${tag}: one exit`);
  assert.ok((M.M||[]).length>=1,`${tag}: no merchant`);assert.ok((M.K||[]).length>=1,`${tag}: no shortcut`);
  assert.equal((M.S||[]).length,kind==='boss'?3:1,`${tag}: shrines (breather${kind==='boss'?', antechamber, arena':''})`);
  assert.ok(L.pathLen>=8&&L.pathLen<=12,`${tag}: path of ${L.pathLen}`);
  const frac=L.branchN/(L.pathLen+L.branchN);assert.ok(frac>=.3-1e-9&&frac<=.4+1e-9,`${tag}: ${(frac*100).toFixed(0)}% on branches`);
  // everything reachable with the shortcut open; the exit with it shut
  const start=M.P[0],all=bfs(L,start,{K:true});
  for(let y=0;y<L.T;y++)for(let x=0;x<L.T;x++)if(walk(L.tiles[y][x],{K:true}))assert.ok(all[y*L.T+x]>=0,`${tag}: tile ${x},${y} can't be reached`);
  const shut=bfs(L,start,{K:false});assert.ok(shut[at(L,M.E[0])]>=0,`${tag}: the exit needs the shortcut`);
  // the shortcut saves the walk from the level's start to the far side of the shortcut door
  const k0=M.K[0],dOpen=bfs(L,start,{K:true}),dShut=bfs(L,start,{K:false});
  const far=[[1,0],[-1,0],[0,1],[0,-1]].map(([a,b])=>[k0[0]+a,k0[1]+b]).filter(([x,y])=>walk(L.tiles[y][x],{K:false})).map(p=>[dOpen[at(L,p)],dShut[at(L,p)]]);
  assert.ok(far.some(([o,s])=>o>=0&&s>o+4),`${tag}: the shortcut doesn't shorten the walk back`);
  if(kind==='boss'){const noGate=bfs(L,start,{K:true,G:false});assert.equal(noGate[at(L,M.B[0])],-1,`${tag}: the boss can be reached without the gate`);
    assert.ok(all[at(L,M.B[0])]>=0,`${tag}: the boss can't be reached`)}
}}
const ms=Date.now()-t0,avg=a=>(a.reduce((x,y)=>x+y,0)/a.length);
for(const k in stats){const S=stats[k];out[k]={levels:S.n,meanAttempts:+(S.att/S.n).toFixed(2),maxAttempts:S.max,meanPath:+avg(S.path).toFixed(2),meanBranchShare:+avg(S.br).toFixed(3)}}
out.msPerLevel=+(ms/(2*built)).toFixed(2);
fs.mkdirSync(path.join(__dirname,'out'),{recursive:true});fs.writeFileSync(path.join(__dirname,'out/understrip_gen_fixture.json'),JSON.stringify(fixture));
console.log(JSON.stringify(out,null,1));
console.log('PASS understrip_gen; errors: none');
