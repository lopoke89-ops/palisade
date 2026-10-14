const fs=require('fs'),dir=process.argv[2];
const src=fs.readFileSync(dir+'/06b-maps.js','utf8'),ele=fs.readFileSync(dir+'/06d-elevation.js','utf8');
let N=16;var connectors,MAP,MAPO,frostFields;const idx=(i,j)=>j*N+i,inb=(i,j)=>i>=0&&j>=0&&i<N&&j<N;
const hash=(i,j)=>{let h=(i*374761393+j*668265263)|0;h=Math.imul(h^(h>>>13),1274126177);return((h^(h>>>16))>>>0)/4294967295};
const T_BLDG=10,T_ROAD=8,T_RUBBLE=9;
const body=src.slice(0,src.indexOf('// a random free tile'))+'\n'+ele.slice(ele.indexOf('MAPS.frost='),ele.indexOf('function paintFrostTile'));
const out={};
eval(body.replace('let terr=','var terr=').replace('let heights=','var heights=')+`
for(const id of ['yard','river','quarry','frost'])for(const size of ['std','xl']){
  N=SIZES[size];terr=new Uint8Array(N*N);heights=new Uint8Array(N*N);connectors=new Uint8Array(N*N);
  MAP=MAPS[id];const o={ox:N>16?2:0,oy:N>16?N-16-2:0,xl:N>16,pvp:''};MAPO=o;const L=MAP.lay(o);
  for(const[i,j]of[L.core,...L.nodes.map(n=>[n.i,n.j]),...L.ruins.flatMap(r=>r[0])]){const k=idx(i,j);if(terr[k]!==T_GROUND&&terr[k]!==T_LOW)terr[k]=T_GROUND}
  out[id+'_'+size]={terr:Array.from(terr).join(''),heights:Array.from(heights).join(''),conn:Array.from(connectors).join(''),core:L.core,nodes:L.nodes.map(n=>[n.i,n.j,n.type,n.locked?n.unlock:0]),
    ruins:L.ruins.map(r=>[r[0],r[1]]),spawns:L.spawns.map(s=>[s.w,s.tiles.length]),bossAt:(L.bossAt||[]).length,raftAt:(L.raftAt||[]).length};
}`.replace(/let heights=new Uint8Array\(N\*N\),connectors=new Uint8Array\(N\*N\),frostFields=\[\];/,''));
// City Black Out's 64x64 city (06e-city.js), in its own scope: it has its own terrain codes
const city=fs.readFileSync(dir+'/06e-city.js','utf8');
eval(`{const T_GROUND=0,D4=[[1,0],[-1,0],[0,1],[0,-1]],LAMP_GAP=4;`+city.slice(0,city.indexOf('// ---------- drawing'))+`
  N=64;terr=new Uint8Array(N*N);const tAt=(i,j)=>inb(i,j)?terr[idx(i,j)]:T_GROUND;const L=layCity();
  for(const[i,j]of[L.core,...L.pois.map(p=>[p.i,p.j]),...L.nodes.map(n=>[n.i,n.j]),...L.ruins.flatMap(r=>r[0])])terr[idx(i,j)]=T_GROUND;
  out.city={terr:Array.from(terr).map(t=>t.toString(36)).join(''),core:L.core,pois:L.pois.map(p=>[p.id,p.i,p.j,p.major?1:0]),nodes:L.nodes.map(n=>[n.i,n.j,n.type]),
    ruins:L.ruins.map(r=>[r[0],r[1]]),lamps:L.lamps,edges:Object.fromEntries(Object.entries(L.edges).map(([k,v])=>[k,v.length])),near:[[5,30],[60,31],[31,2],[32,61],[10,10]].map(([i,j])=>cityEdgeFor(i,j))};
}`);
console.log(JSON.stringify(out));
