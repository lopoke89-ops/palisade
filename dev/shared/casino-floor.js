// Shared layout. Embedded by assemble.py and imported by Render.
(()=>{
const CAS={name:'THE PALISADE FALLS CASINO',
  spawn:[[1.6,9.4],[1.6,10.6],[2.5,9.5],[2.5,10.5],[3.4,9.4],[3.4,10.6]],
  // seat k is the server's seat k at that table; a dealer stands behind each table
  tables:[
    {n:1,game:'bj',name:'BLACKJACK',col:'#ff4a6a',solid:[[3,4],[4,4],[5,4],[3,3],[4,3],[5,3]],c:[4.5,4.55],sign:[4.5,4.2],
     dealer:{x:4.5,y:3.55,face:{x:0,y:1},name:'VINNIE',look:'vinnie'},seats:[[2.7,5.15],[3.55,5.6],[4.5,5.8],[5.45,5.6],[6.3,5.15]]},
    {n:2,game:'he',name:'POKER',col:'#3ae0ff',solid:[[7,3],[8,3],[9,3],[7,4],[8,4],[9,4],[8,2]],c:[8.5,4],sign:[8.5,3.6],
     dealer:{x:8.5,y:2.5,face:{x:0,y:1},name:'ROSA',look:'rosa'},seats:[20,70,110,160,200,340].map(a=>[8.5+2.05*Math.cos(a*Math.PI/180),4+1.55*Math.sin(a*Math.PI/180)])},
    {n:3,game:'rl',name:'ROULETTE',col:'#ffb43a',solid:[[11,7],[12,7],[13,7],[11,8],[12,8],[13,8],[14,8],[14,7]],c:[12.5,8],sign:[12.3,7.6],wheel:[13.45,8],
     dealer:{x:14.5,y:7.9,face:{x:-1,y:0},name:'MARCO',look:'marco'},seats:[[11.2,6.4],[12.2,6.4],[13.2,6.4],[11.2,9.6],[12.2,9.6],[13.2,9.6]]},
    // v0.10.3: craps on a long table, three a side, the stickman at the east end; baccarat a half-moon like blackjack
    {n:4,game:'cr',name:'CRAPS',col:'#4aff9a',solid:[[4,12],[5,12],[6,12],[7,12],[4,13],[5,13],[6,13],[7,13]],c:[6,13],sign:[6,12.5],
     dealer:{x:8.45,y:13,face:{x:-1,y:0},name:'DUKE',look:'duke'},seats:[[4.5,11.55],[5.7,11.55],[6.9,11.55],[4.5,14.45],[5.7,14.45],[6.9,14.45]]},
    {n:5,game:'ba',name:'BACCARAT',col:'#c98aff',solid:[[7,7],[8,7],[9,7],[8,6]],c:[8.5,7.3],sign:[8.5,6.95],
     dealer:{x:8.5,y:6.55,face:{x:0,y:1},name:'LENA',look:'lena'},seats:[165,135,105,75,45,15].map(a=>[8.5+2*Math.cos(a*Math.PI/180),7.25+1.25*Math.sin(a*Math.PI/180)])}],
  slotsN:[2,3,4,5,6,7,8,9,10,11],slotsW:[2,3,4,5,6,7],plinko:{tile:[15,10],at:[15.5,10.5],stand:[14.4,10.5]},
  bar:{back:[[13,0],[14,0],[15,0]],counter:[[12,2],[13,2],[14,2],[15,2]],stools:[[12.5,3.25],[13.5,3.25],[14.5,3.25],[15.4,3.25]],keep:{x:14,y:1.2}},
  cage:[[0,13],[1,13],[0,14],[1,14],[0,15],[1,15]],pillars:[[6,8],[10,11],[14,12]],couch:[[12,14],[13,14]],
  lamps:[[4.5,4.5],[8.5,4],[12.5,8],[4.5,10],[9,8.3],[8.6,12.6],[4,13.2],[13.2,12.4],[13.8,2.8]],
  // the dealers: built like player looks (a skin set each), so they can be a case collection later
  looks:{vinnie:{body:'#f1ede2',vest:'#18161a',pants:'#1c1b1f',head:'#d9a77c',hat:'#2a2420',gl:14,nogun:true},
    rosa:{body:'#f4efe6',vest:'#5a0f1c',pants:'#1c1b1f',head:'#b8805a',hat:'#1a1210',gl:14,nogun:true},
    marco:{body:'#efeadf',vest:'#13261c',pants:'#1c1b1f',head:'#e2b996',hat:'#5a4632',gl:14,nogun:true},
    keep:{body:'#e9e2d2',vest:'#2a1a12',pants:'#1c1b1f',head:'#c99a72',hat:'#1a1210',gl:14,nogun:true},
    duke:{body:'#ece6d8',vest:'#1d3a24',pants:'#1c1b1f',head:'#8a5a3c',hat:'#2a2420',gl:14,nogun:true},
    lena:{body:'#f2ede4',vest:'#3a1a4a',pants:'#1c1b1f',head:'#e8c4a0',hat:'#3a2614',gl:14,nogun:true}}};
// v0.10.3 the machines: ten slot cabinets on the north wall (s1-s10), six on the west wall (s11-s16), the Plinko board (p1).
// You play standing at its front; one player per machine.
CAS.machines=[...CAS.slotsN.map((i,k)=>({id:'s'+(k+1),game:'sl',name:'SLOTS',at:[i+.5,.55],face:'s',stand:[i+.5,1.4]})),
  ...CAS.slotsW.map((j,k)=>({id:'s'+(11+k),game:'sl',name:'SLOTS',at:[.55,j+.5],face:'e',stand:[1.4,j+.5]})),
  {id:'p1',game:'pk',name:'PLINKO',at:CAS.plinko.at,face:'w',stand:CAS.plinko.stand}];
CAS.machines.forEach((m,k)=>{m.code=101+k});
const casTable=g=>CAS.tables.find(t=>t.game===g);
// seat codes (also on the wire): 0 standing, table n and seat k -> n*10+k+1 (v0.10.0, unchanged), machine k -> 101+k.
// CAS_SEAT is the registry: a code is a real seat only if it is in it (the host checks every code a guest sends against it).
const seatCode=(n,k)=>n*10+k+1;
const CAS_SEAT=new Map();for(const t of CAS.tables)t.seats.forEach((p,k)=>CAS_SEAT.set(seatCode(t.n,k),{t,k,pos:p,game:t.game,station:''}));
for(const m of CAS.machines)CAS_SEAT.set(m.code,{m,k:0,pos:m.stand,game:m.game,station:m.id});
const casSeatOf=c=>c&&CAS_SEAT.get(c)||null;
const casMachine=id=>CAS.machines.find(m=>m.id===id);
const solid=new Set([...CAS.slotsN.map(i=>[i,0]),...CAS.slotsW.map(j=>[0,j]),...CAS.bar.back,...CAS.bar.counter,...CAS.cage,...CAS.pillars,...CAS.couch,...CAS.tables.flatMap(t=>t.solid),CAS.plinko.tile].map(p=>p.join(',')));
const blocked=(x,y,r=.27)=>{if(!Number.isFinite(x+y)||x-r<0||y-r<0||x+r>=16||y+r>=16)return true;for(let i=Math.floor(x-r);i<=Math.floor(x+r);i++)for(let j=Math.floor(y-r);j<=Math.floor(y+r);j++)if(solid.has(i+','+j))return true;return false};
const move=(p,x,y,dt)=>{const l=Math.hypot(x,y);if(l>1){x/=l;y/=l}const dx=x*3.3*dt,dy=y*3.3*dt;if(!blocked(p.x+dx,p.y))p.x+=dx;if(!blocked(p.x,p.y+dy))p.y+=dy;return p};
globalThis.CasinoFloor=Object.freeze({CAS,CAS_SEAT,casSeatOf,seatCode,casTable,casMachine,blocked,move,revision:1});
})();
