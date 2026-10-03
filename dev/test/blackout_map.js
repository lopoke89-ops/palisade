// v0.9.7 the city: 64×64 (and the 48×48 fallback), Main Command in the centre, every POI reachable by road from it,
// raiders able to path from every edge to every POI, roads faster to walk and rubble slower, and the lights follow the
// POIs (held: lit, lost: dark after the flicker) and the Power Station (streetlamps).
const {chromium}=require('playwright'),assert=require('node:assert/strict'),fs=require('node:fs');
(async()=>{const b=await chromium.launch({executablePath:process.env.CHROMIUM||undefined}),errors=[],out={};
 const p=await b.newPage({viewport:{width:1280,height:800}});p.on('pageerror',e=>errors.push(e.message));
 await p.goto(`http://localhost:${process.env.PORT||8080}/debug.html?debug=1`);await p.waitForFunction(()=>window.__pal);
 for(const size of[64,48]){
  out[size]=await p.evaluate(async size=>{const P=__pal,r={};P.setCityN(size);if(P.game.phase!=='title')P.toMenu();
   P.pick.mode='blackout';P.showPage('solo');document.getElementById('startBtn').click();await new Promise(z=>setTimeout(z,400));P.game.paused=true;
   const N=P.N,T=P.terr,C=P.core,G=P.game.lay.city;r.N=N;r.core=[C.i,C.j];r.centre=C.i===N>>1&&C.j===N>>1;r.pois=P.cores.length-1;r.majors=P.cores.filter(c=>c.poi&&c.poi.major).length;
   // road-only walk from the inner ring to a road tile within 4 of each POI
   const seen=new Uint8Array(N*N),q=[];for(let j=0;j<N;j++)for(let i=0;i<N;i++){const k=j*N+i;if(T[k]===P.T_ROAD&&Math.max(Math.abs(i-C.i),Math.abs(j-C.j))<=G.ri+1){seen[k]=1;q.push(k)}}
   while(q.length){const k=q.pop(),i=k%N,j=(k/N)|0;for(const[a,c]of[[1,0],[-1,0],[0,1],[0,-1]]){const x=i+a,y=j+c;if(x<0||y<0||x>=N||y>=N)continue;const n=y*N+x;if(!seen[n]&&T[n]===P.T_ROAD){seen[n]=1;q.push(n)}}}
   r.byRoad=P.cores.filter(c=>c.poi).map(c=>{for(let j=c.j-4;j<=c.j+4;j++)for(let i=c.i-4;i<=c.i+4;i++)if(i>=0&&j>=0&&i<N&&j<N&&seen[j*N+i])return true;return false});
   // every POI's flow field reaches all four edges
   r.flow=P.cores.map((c,n)=>{if(!c.poi)return true;const f=P.poiFlow(n);return['n','e','s','w'].every(s=>P.game.lay.edges[s].some(([i,j])=>f[j*N+i]<1e5))});
   r.speed={road:P.slowAt(G.C+.5,G.C-G.ri+.5),rubble:(()=>{for(let k=0;k<N*N;k++)if(T[k]===P.T_RUBBLE)return P.slowAt(k%N+.5,((k/N)|0)+.5)})()};
   // the lights: record the holes cityLights cuts
   const count=()=>{const rec=[];P.cityLights((x,y,rr,s)=>rec.push(s),()=>[640,400]);return rec.length};
   r.lamps=P.game.lay.lamps.length;r.holes0=count();
   const c1=P.cores[1];c1.lost=true;c1.lostAt=P.game.time-5;r.holesLost=count();
   P.game.dark=true;r.holesDark=count();
   return r},size)}
 fs.writeFileSync(__dirname+'/out/blackout_map.json',JSON.stringify(out,null,1));console.log(JSON.stringify(out));
 for(const [size,r]of Object.entries(out)){
  assert.equal(r.N,+size);assert.ok(r.centre,'Main Command in the centre');assert.equal(r.pois,8);assert.equal(r.majors,4);
  assert.ok(r.byRoad.every(Boolean),size+': every POI by road '+r.byRoad);assert.ok(r.flow.every(Boolean),size+': raiders reach every POI from every edge');
  assert.ok(r.speed.road>1.3&&r.speed.rubble<1,size+' road/rubble speed '+JSON.stringify(r.speed));
  assert.ok(r.lamps>20,'streetlamps '+r.lamps);assert.equal(r.holes0,9+r.lamps,'Main Command + 8 POIs + every lamp');assert.equal(r.holesLost,r.holes0-1,'a lost POI goes dark');assert.equal(r.holesDark,8,'power out: no streetlamps')}
 assert.deepEqual(errors,[]);console.log('errors: none');await b.close();
})().catch(e=>{console.error(e);process.exit(1)});
