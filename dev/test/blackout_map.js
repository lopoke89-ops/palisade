// v0.9.7 the city: 64×64 (and the 48×48 fallback), Main Command in the centre, every POI reachable by road from it,
// raiders able to path from every edge to every POI, roads faster to walk and rubble slower, and the lights follow the
// POIs (held: lit, lost: dark after the flicker) and the Power Station (streetlamps). v0.9.7.3: lamps every 4 tiles,
// bigger pools, and the road between two lamps reads as lit.
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
   // v0.9.7.3: lamps every 4 tiles, 3.2-tile pools at 85%, and the road between two neighbours stays lit (the darkness
   // left at their midpoint, from every hole there, as a share of the unlit night: soft dots fall off linearly)
   const L=P.game.lay.lamps,iso=P.iso;r.lampRow=L.every(l=>(l[2]?l[1]:l[0])%4===0);
   const rec=[];P.cityLights((x,y,rr,s)=>rec.push([rr/P.TW2,s]),()=>[640,400]);r.lampHole=rec[rec.length-1];
   const mid=()=>{const res=[];for(const A of L)for(const B of L){if(A[2]!==B[2]||A[3]!==B[3])continue;if(!(A[2]?A[0]===B[0]&&B[1]-A[1]===4:A[1]===B[1]&&B[0]-A[0]===4))continue;
     const a=iso(A[0]+.5+A[2]*.7,A[1]+.5+A[3]*.7),c=iso(B[0]+.5+B[2]*.7,B[1]+.5+B[3]*.7),ox=(a[0]+c[0])/2-640,oy=(a[1]+c[1])/2-400,h=[];
     P.cityLights((x,y,rr,s)=>h.push([x,y,rr,s]),(x,y)=>{const q=iso(x,y);return[q[0]-ox,q[1]-oy]});
     let k=1;for(const[x,y,rr,s]of h){const d=Math.hypot(x-640,y-400);if(d<rr)k*=1-Math.min(1,s)*(1-d/rr)}res.push(k)}return res};
   const held=mid();P.game.dark=true;const out=mid();   // lamps only: held over out at the same point (POI and Main Command light cancel)
   const ratio=(a,b)=>a.map((v,n)=>+(v/b[n]).toFixed(3)).sort((x,y)=>x-y);r.mid=ratio(held,out);
   r.holesDark=count();
   return r},size)}
 fs.writeFileSync(__dirname+'/out/blackout_map.json',JSON.stringify(out,null,1));console.log(JSON.stringify(out));
 for(const [size,r]of Object.entries(out)){
  assert.equal(r.N,+size);assert.ok(r.centre,'Main Command in the centre');assert.equal(r.pois,8);assert.equal(r.majors,4);
  assert.ok(r.byRoad.every(Boolean),size+': every POI by road '+r.byRoad);assert.ok(r.flow.every(Boolean),size+': raiders reach every POI from every edge');
  assert.ok(r.speed.road>1.3&&r.speed.rubble<1,size+' road/rubble speed '+JSON.stringify(r.speed));
  assert.ok(r.lamps>20,'streetlamps '+r.lamps);assert.equal(r.holes0,9+r.lamps,'Main Command + 8 POIs + every lamp');assert.equal(r.holesLost,r.holes0-1,'a lost POI goes dark');assert.equal(r.holesDark,8,'power out: no streetlamps');
  assert.ok(r.lampRow,'lamps every 4 tiles');assert.deepEqual(r.lampHole.map(v=>+v.toFixed(2)),[3.5,.85],'lamp pool 3.5 tiles at 85%');
  const m=r.mid,med=m[m.length>>1];assert.ok(m.length>=6,'lamp pairs '+m.length);
  assert.ok(med<=.5&&m[m.length-1]<=.5,size+': lit between lamps (darkness left at the midpoint) '+m.join(','));
  }
 assert.deepEqual(errors,[]);console.log('errors: none');await b.close();
})().catch(e=>{console.error(e);process.exit(1)});
