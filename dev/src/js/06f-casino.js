/* ================= v0.10.0 THE PALISADE FALLS CASINO ================= */
// A 16×16 casino floor in the yard's style: a blackjack table, a poker table and a roulette table you walk up to, slot
// banks, a bar and a cashier cage, all lit by chandeliers and neon. No raiders, no building, no weapons. You sit by
// walking to a free seat; the table itself (the cards, the wheel, every shard) is run by the server (21b-tables.js).
// Everything here is laid out from fixed numbers, so the host and every guest build the same room.
const casino=()=>!!game&&game.mode==='casino';
const CAS={name:'THE PALISADE FALLS CASINO',
  spawn:[[1.6,9.4],[1.6,10.6],[2.5,9.5],[2.5,10.5],[3.4,9.4],[3.4,10.6]],
  // seat k is the server's seat k at that table; a dealer stands behind each table
  tables:[
    {n:1,game:'bj',name:'BLACKJACK',col:'#ff4a6a',solid:[[3,4],[4,4],[5,4],[3,3],[4,3],[5,3]],c:[4.5,4.55],sign:[4.5,4.2],
     dealer:{x:4.5,y:3.55,face:{x:0,y:1},name:'VINNIE',look:'vinnie'},seats:[[2.7,5.15],[3.55,5.6],[4.5,5.8],[5.45,5.6],[6.3,5.15]]},
    {n:2,game:'he',name:'POKER',col:'#3ae0ff',solid:[[7,3],[8,3],[9,3],[7,4],[8,4],[9,4],[8,2]],c:[8.5,4],sign:[8.5,3.6],
     dealer:{x:8.5,y:2.5,face:{x:0,y:1},name:'ROSA',look:'rosa'},seats:[20,70,110,160,200,340].map(a=>[8.5+2.05*Math.cos(a*Math.PI/180),4+1.55*Math.sin(a*Math.PI/180)])},
    {n:3,game:'rl',name:'ROULETTE',col:'#ffb43a',solid:[[11,7],[12,7],[13,7],[11,8],[12,8],[13,8],[14,8],[14,7]],c:[12.5,8],sign:[12.3,7.6],wheel:[13.45,8],
     dealer:{x:14.5,y:7.9,face:{x:-1,y:0},name:'MARCO',look:'marco'},seats:[[11.2,6.4],[12.2,6.4],[13.2,6.4],[11.2,9.6],[12.2,9.6],[13.2,9.6]]}],
  slotsN:[2,3,4,5,6,7,8,9,10,11],slotsW:[2,3,4,5,6,7],
  bar:{back:[[13,0],[14,0],[15,0]],counter:[[12,2],[13,2],[14,2],[15,2]],stools:[[12.5,3.25],[13.5,3.25],[14.5,3.25],[15.4,3.25]],keep:{x:14,y:1.2}},
  cage:[[0,13],[1,13],[0,14],[1,14],[0,15],[1,15]],pillars:[[6,8],[10,11],[14,12]],couch:[[12,14],[13,14]],
  lamps:[[4.5,4.5],[8.5,4],[12.5,8],[4.5,10],[9,8.3],[8.6,12.6],[4,13.2],[13.2,12.4],[13.8,2.8]],
  // the dealers: built like player looks (a skin set each), so they can be a case collection later
  looks:{vinnie:{body:'#f1ede2',vest:'#18161a',pants:'#1c1b1f',head:'#d9a77c',hat:'#2a2420',gl:14,nogun:true},
    rosa:{body:'#f4efe6',vest:'#5a0f1c',pants:'#1c1b1f',head:'#b8805a',hat:'#1a1210',gl:14,nogun:true},
    marco:{body:'#efeadf',vest:'#13261c',pants:'#1c1b1f',head:'#e2b996',hat:'#5a4632',gl:14,nogun:true},
    keep:{body:'#e9e2d2',vest:'#2a1a12',pants:'#1c1b1f',head:'#c99a72',hat:'#1a1210',gl:14,nogun:true}}};
const casTable=g=>CAS.tables.find(t=>t.game===g);
// seat codes (also on the wire): 0 standing, table n and seat k -> n*10+k+1
const seatCode=(n,k)=>n*10+k+1,casSeatOf=c=>c?{t:CAS.tables[Math.floor(c/10)-1],k:c%10-1}:null;
function layCasino(){
  const L={core:[-9,-9],nodes:[],ruins:[],spawns:[],casino:true};
  const solid=(i,j)=>{if(inb(i,j))terr[idx(i,j)]=T_BLDG};
  for(const i of CAS.slotsN)solid(i,0);for(const j of CAS.slotsW)solid(0,j);
  for(const [i,j]of[...CAS.bar.back,...CAS.bar.counter,...CAS.cage,...CAS.pillars,...CAS.couch])solid(i,j);
  for(const t of CAS.tables)for(const [i,j]of t.solid)solid(i,j);
  return L;
}
MAPS.casino={name:CAS.name,short:'Casino',casino:true,night:true,hp:1,col:'#c2203a',from:'',bosses:[],blurb:'Blackjack, poker and roulette for shards.',lay(){return layCasino()}};

// ---------- the floor (painted once into the cached layer) ----------
const casRunner=(i,j)=>i<=5&&(j===9||j===10);   // the red carpet in from the door
const casBar=(i,j)=>i>=12&&j<=3;
const casCage=(i,j)=>i<=2&&j>=12;
function casinoGroundCol(i,j,h){
  if(casRunner(i,j))return '#8f1622';
  if(casBar(i,j))return h<.5?'#3b2617':'#352214';
  if(casCage(i,j))return h<.5?'#7d776c':'#77716a';
  const ring=CAS.tables.some(t=>Math.hypot(i+.5-t.c[0],j+.5-t.c[1])<2.6);
  return ring?(h<.5?'#3a0a12':'#360910'):((i+j)%2?'#4a0f17':'#450e15')}
function casinoGroundDetail(i,j,h){
  if(casRunner(i,j)){g.strokeStyle='rgba(226,180,54,.55)';g.lineWidth=1.2*u;g.beginPath();
    if(j===9){const a=iso(i,j+.08),b=iso(i+1,j+.08);g.moveTo(a[0],a[1]);g.lineTo(b[0],b[1])}else{const a=iso(i,j+.92),b=iso(i+1,j+.92);g.moveTo(a[0],a[1]);g.lineTo(b[0],b[1])}g.stroke();return true}
  if(casBar(i,j)){g.strokeStyle='rgba(0,0,0,.25)';g.lineWidth=u;g.beginPath();for(const t of[.33,.66]){const a=iso(i,j+t),b=iso(i+1,j+t);g.moveTo(a[0],a[1]);g.lineTo(b[0],b[1])}g.stroke();return true}
  if(casCage(i,j))return true;
  // the casino carpet: a gold diamond on every tile, with a small four-point star where four tiles meet
  const m=iso(i+.5,j+.5),a=iso(i+.5,j+.22),b=iso(i+.78,j+.5),c=iso(i+.5,j+.78),d=iso(i+.22,j+.5);
  g.strokeStyle='rgba(214,170,70,.32)';g.lineWidth=1*u;g.beginPath();g.moveTo(a[0],a[1]);g.lineTo(b[0],b[1]);g.lineTo(c[0],c[1]);g.lineTo(d[0],d[1]);g.closePath();g.stroke();
  oval(m[0],m[1],1.6*u,.8*u,'rgba(214,170,70,.45)');
  if((i+j)%2===0){const k=iso(i,j);oval(k[0],k[1],1.2*u,.6*u,'rgba(60,170,160,.35)')}
  return true}
// the two back walls (north and west), the door, wainscot and gold trim; behind everything, so they go in the cached layer
function paintCasinoWalls(){
  const H=WH*3.4;
  const wall=(P,Q,face,trim)=>{quad(P,Q,up(Q,H),up(P,H),face);quad(P,Q,up(Q,H*.32),up(P,H*.32),'#24130d');
    g.strokeStyle=trim;g.lineWidth=1.6*u;g.beginPath();for(const v of[.32,.34,.97]){const a=up(P,H*v),b=up(Q,H*v);g.moveTo(a[0],a[1]);g.lineTo(b[0],b[1])}g.stroke()};
  for(let i=0;i<N;i++){const P=iso(i,0),Q=iso(i+1,0);wall(P,Q,i%2?'#3a0d16':'#360c14','rgba(214,170,70,.7)');
    g.strokeStyle='rgba(214,170,70,.18)';g.lineWidth=u;g.beginPath();const m=lerp2(P,Q,.5);g.moveTo(m[0],m[1]-H*.36);g.lineTo(m[0],m[1]-H*.95);g.stroke()}
  for(let j=0;j<N;j++){const P=iso(0,j),Q=iso(0,j+1),door=j===9||j===10;
    if(door){quad(P,Q,up(Q,H),up(P,H),'#2a0a10');quad(lerp2(P,Q,.06),lerp2(P,Q,.94),up(lerp2(P,Q,.94),H*.72),up(lerp2(P,Q,.06),H*.72),'#0c1622');
      g.strokeStyle='#d6aa46';g.lineWidth=1.8*u;g.beginPath();for(const t of[.06,.5,.94]){const a=lerp2(P,Q,t);g.moveTo(a[0],a[1]);g.lineTo(a[0],a[1]-H*.72)}const a=up(lerp2(P,Q,.06),H*.72),b=up(lerp2(P,Q,.94),H*.72);g.moveTo(a[0],a[1]);g.lineTo(b[0],b[1]);g.stroke();continue}
    wall(P,Q,j%2?'#300a12':'#2c0910','rgba(214,170,70,.6)')}
  // gold corner post
  const c0=iso(0,0);g.fillStyle='#b58a2e';g.fillRect(c0[0]-2*u,c0[1]-H,4*u,H);
}

// ---------- the furniture (live, depth-sorted with the players) ----------
const casGlowQ=[];   // neon and bulbs, drawn after the lighting so they stay bright
function casSlot(x,y,face,k){   // one slot machine against a wall
  const t=game.time,w=.36;const fx=face==='s'?[x-w,y-.3,x+w,y+.25]:[x-.3,y-w,x+.25,y+w];
  const {A,B,C,D}=boxR(fx[0],fx[1],fx[2],fx[3],0,WH*1.35,'#2b2a30','#1c1b20','#151418');
  const fr=face==='s'?[D,C]:[B,C],m=lerp2(fr[0],fr[1],.5),scr=up(m,WH*.92);
  const hue=['#ff4a6a','#3ae0ff','#ffd24a','#9a6aff','#4aff9a'][k%5],on=Math.sin(t*3+k*1.7)>-.2;
  g.fillStyle='#0a0a10';g.fillRect(scr[0]-5*u,scr[1]-4*u,10*u,7*u);
  if(on){g.fillStyle=hue;for(let r=0;r<3;r++)g.fillRect(scr[0]-4*u+r*3*u,scr[1]-3*u+((Math.floor(t*6+k+r*2))%3)*1.4*u,2.2*u,1.6*u)}
  const top=up(m,WH*1.35);oval(top[0],top[1]+1*u,4.5*u,1.8*u,hue);casGlowQ.push(['dot',scr[0],scr[1],TW2*.45,hue,on?.5:.25]);
  g.fillStyle='#c9b27a';g.fillRect(scr[0]+5.5*u,scr[1]-2*u,1.2*u,6*u)}
function casStool(x,y,top='#7a1020'){const c=iso(x,y);g.fillStyle='#2a1b10';g.fillRect(c[0]-.8*u,c[1]-7*u,1.6*u,7*u);oval(c[0],c[1]-7*u,4.6*u,2.2*u,top);oval(c[0],c[1],3*u,1.2*u,'rgba(0,0,0,.35)')}
function casChair(x,y){const c=iso(x,y);oval(c[0],c[1],4*u,1.8*u,'rgba(0,0,0,.35)');boxR(x-.17,y-.17,x+.17,y+.17,WH*.22,WH*.08,'#7a1020','#5a0c18','#4a0a14')}
function casFeltEllipse(cx,cy,rx,ry,z,col,rim){const pts=[];for(let k=0;k<28;k++){const a=k/28*Math.PI*2;pts.push(iso(cx+Math.cos(a)*rx,cy+Math.sin(a)*ry))}
  g.beginPath();pts.forEach((p,k)=>k?g.lineTo(p[0],p[1]-z):g.moveTo(p[0],p[1]-z));g.closePath();g.fillStyle=col;g.fill();g.strokeStyle=rim;g.lineWidth=3*u;g.stroke()}
function casTableBody(t){
  const z=WH*.55;
  if(t.game==='bj'){   // a half-moon: flat edge to the dealer (north), the curve to the players
    boxR(3.1,3.75,5.9,4.95,0,z*.9,'#1d120b','#2a1a10','#22150d');
    const pts=[];for(let k=0;k<=20;k++){const a=Math.PI*k/20;pts.push(iso(4.5+Math.cos(a)*1.45,3.8+Math.sin(a)*1.15))}
    g.beginPath();pts.forEach((p,k)=>k?g.lineTo(p[0],p[1]-z):g.moveTo(p[0],p[1]-z));g.closePath();g.fillStyle='#0f5a34';g.fill();g.strokeStyle='#4a2a14';g.lineWidth=3.2*u;g.stroke();
    g.strokeStyle='rgba(226,200,120,.45)';g.lineWidth=u;g.beginPath();for(let k=0;k<=20;k++){const a=Math.PI*k/20,p=iso(4.5+Math.cos(a)*.95,3.8+Math.sin(a)*.72);k?g.lineTo(p[0],p[1]-z):g.moveTo(p[0],p[1]-z)}g.stroke();
    const sh=iso(5.6,3.95);boxR(5.45,3.85,5.75,4.1,z,WH*.12,'#d8cfb8','#a99e86','#8c826c');void sh}
  else if(t.game==='he'){boxR(7.1,3.2,9.9,4.8,0,z*.88,'#1d120b','#2a1a10','#22150d');casFeltEllipse(8.5,4,1.45,.95,z,'#0f5a34','#5a3412');
    g.strokeStyle='rgba(226,200,120,.4)';g.lineWidth=u;const r=iso(8.5,4);g.beginPath();g.ellipse(r[0],r[1]-z,TW2*.9,TH2*.6,0,0,Math.PI*2);g.stroke()}
  else{boxR(11.05,7.15,14.0,8.85,0,z*.88,'#1d120b','#2a1a10','#22150d');boxR(11.05,7.15,13.0,8.85,z*.88,WH*.04,'#0f5a34','#0b4528','#0a3d24');
    // the layout: three columns of numbers (drawn as a grid), the zero box at the wheel end
    g.strokeStyle='rgba(240,230,200,.5)';g.lineWidth=.8*u;g.beginPath();
    for(let q=0;q<=12;q++){const x=11.15+q*.15,a=iso(x,7.35),b=iso(x,8.65);g.moveTo(a[0],a[1]-z);g.lineTo(b[0],b[1]-z)}
    for(let r=0;r<=3;r++){const y=7.35+r*1.3/3,a=iso(11.15,y),b=iso(12.95,y);g.moveTo(a[0],a[1]-z);g.lineTo(b[0],b[1]-z)}g.stroke();
    for(let q=0;q<12;q++)for(let r=0;r<3;r++){const n=q*3+(3-r);if(!RL_REDC.has(n))continue;const c=iso(11.15+q*.15+.075,7.35+r*1.3/3+.21);oval(c[0],c[1]-z,1.3*u,.7*u,'rgba(200,30,40,.6)')}
    casWheel(t,z)}
  // the table's own lamp (a pool of light from above is added in casinoLights)
}
const RL_REDC=new Set([1,3,5,7,9,12,14,16,18,19,21,23,25,27,30,32,34,36]);
const RL_WHEELC=[0,28,9,26,30,11,7,20,32,17,5,22,34,15,3,24,36,13,1,37,27,10,25,29,12,8,19,31,18,6,21,33,16,4,23,35,14,2];
// the roulette wheel at the head of the table: turns slowly when idle; spins and lands on the server's number (casWheelState)
function casWheel(t,z){const [wx,wy]=t.wheel,c=iso(wx,wy),rx=TW2*.62,ry=TH2*.62,S=casWheelState();
  oval(c[0],c[1]-z-1*u,rx+3*u,ry+2*u,'#3a220f');
  for(let k=0;k<38;k++){const a0=S.rot+k/38*Math.PI*2,a1=a0+Math.PI*2/38,n=RL_WHEELC[k];g.beginPath();g.moveTo(c[0],c[1]-z-2*u);
    g.ellipse(c[0],c[1]-z-2*u,rx,ry,0,a0,a1);g.closePath();g.fillStyle=n===0||n===37?'#0e7a3a':RL_REDC.has(n)?'#b8202c':'#141214';g.fill()}
  oval(c[0],c[1]-z-2*u,rx*.45,ry*.45,'#5a3a14');oval(c[0],c[1]-z-3*u,rx*.12,ry*.12,'#d6aa46');
  if(S.ball){const b=S.ball;g.fillStyle='#f4f0e6';g.beginPath();g.arc(c[0]+Math.cos(b.a)*rx*b.r,c[1]-z-2*u+Math.sin(b.a)*ry*b.r,1.5*u,0,Math.PI*2);g.fill()}}
// wheel animation: an idle turn, or the 6-second spin that ends with the ball in the server's pocket
const CAS_W={spinAt:0,num:null,key:'',dur:6};
function casWheelState(){const now=performance.now()/1000,idle=now*.25;
  if(CAS_W.num===null)return{rot:idle,ball:null};
  const t=Math.min(1,(now-CAS_W.spinAt)/CAS_W.dur),e=1-Math.pow(1-t,3),k=RL_WHEELC.indexOf(CAS_W.num),rot=idle+e*Math.PI*6;
  const land=rot+(k+.5)/38*Math.PI*2,ba=land+(1-e)*Math.PI*-14,r=.93-(t>.7?(t-.7)/.3*.18:0);   // the ball runs the other way, drops in, settles in the pocket
  return{rot,ball:{a:ba,r}}}
function casWheelSpin(num,left){const key=String(num)+'|'+Math.round((performance.now()/1000-(CAS_W.dur-left))/2);
  if(CAS_W.num===num&&performance.now()/1000-CAS_W.spinAt<CAS_W.dur+6)return;CAS_W.num=num;CAS_W.spinAt=performance.now()/1000-Math.max(0,CAS_W.dur-left);CAS_W.key=key}
function casDealer(t){const d=t.dealer;drawPerson(d.x,d.y,Object.assign({aim:d.face,walk:0,flash:false},CAS.looks[d.look]))}
// what's on a table you can see: your own table from your seat, the others from a peek while you stand near
function casFelt(t){const v=casView(t.game);if(!v)return;const z=WH*.55,card=(x,y,c)=>{const p=iso(x,y);g.fillStyle=c===null||c===undefined?'#3a5ab0':'#f4efe4';g.fillRect(p[0]-2.4*u,p[1]-z-6*u,4.8*u,6.6*u);
    g.strokeStyle='rgba(0,0,0,.5)';g.lineWidth=.6*u;g.strokeRect(p[0]-2.4*u,p[1]-z-6*u,4.8*u,6.6*u);if(c!==null&&c!==undefined){g.fillStyle=(c%52/13|0)===1||(c%52/13|0)===2?'#c02030':'#141214';g.fillRect(p[0]-1.2*u,p[1]-z-4.5*u,2.4*u,2.4*u)}};
  const chips=(x,y,n)=>{if(!(n>0))return;const p=iso(x,y),h=Math.min(8,1+Math.floor(Math.log2(n+1)));for(let q=0;q<h;q++)oval(p[0],p[1]-z-q*1.1*u,2.4*u,1.1*u,q%2?'#d6aa46':'#b8202c')};
  if(t.game==='bj'){(v.dealer||[]).forEach((c,q)=>card(4.1+q*.22,3.95,c));
    for(const p of v.players||[]){const s=t.seats[p.seat];if(!s)continue;const cx=4.5+(s[0]-4.5)*.62,cy=3.85+(s[1]-3.85)*.62;p.hands.forEach((h,hi)=>h.cards.forEach((c,q)=>card(cx-.1+q*.16+hi*.4,cy,c)));chips(cx+.25,cy+.18,p.hands.reduce((a,h)=>a+h.bet,0))}
    if(v.phase==='bet')for(const[si,b]of Object.entries(v.bets||{})){const s=t.seats[si];if(s)chips(4.5+(s[0]-4.5)*.62,3.85+(s[1]-3.85)*.62,b)}}
  else if(t.game==='he'){(v.board||[]).forEach((c,q)=>card(8.05+q*.22,3.95,c));chips(8.5,4.35,v.pot);
    for(const p of v.players||[]){const s=t.seats[p.seat];if(!s||p.folded)continue;const cx=8.5+(s[0]-8.5)*.55,cy=4+(s[1]-4)*.55;p.cards.forEach((c,q)=>card(cx-.08+q*.16,cy,c));chips(cx+.2,cy+.15,p.bet)}}
  else{const B=v.bets||{};for(const[si,bets]of Object.entries(B))for(const[k,a]of Object.entries(bets)){const sp=rlSpotC(k);if(!sp)continue;chips(sp[0],sp[1],a)}
    if((v.phase==='spin'||v.phase==='done')&&v.number!==undefined)casWheelSpin(v.number,v.phase==='spin'?v.left/1000:0);else if(v.phase==='bet')CAS_W.num=null}}
// where a roulette spot sits on the small in-world layout (approximate: the panel has the exact board)
function rlSpotC(k){const m=String(k).match(/^([a-z]+)(?::([0-9-]+))?$/);if(!m)return null;const ns=(m[2]||'').split('-').filter(Boolean).map(Number),pos=n=>n===0||n===37?[13.05,n?7.6:8.4]:[11.15+Math.floor((n-1)/3)*.15+.075,7.35+(2-(n-1)%3)*1.3/3+.21];
  if(ns.length){const ps=ns.map(pos);return[ps.reduce((a,p)=>a+p[0],0)/ps.length,ps.reduce((a,p)=>a+p[1],0)/ps.length]}
  return{red:[11.6,8.75],black:[12.1,8.75],odd:[12.5,8.75],even:[11.3,8.75],low:[11.2,8.75],high:[12.9,8.75],tl:[12.98,8]}[m[1]]||[12,8.7]}
function casBarDraw(){for(const [i,j]of CAS.bar.back)boxR(i+.05,j+.05,i+.95,j+.7,0,WH*1.6,'#2a1a10','#3a2414','#2e1c10');
  for(let q=0;q<9;q++){const c=iso(13.2+q*.3,.45);g.fillStyle=['#3ae08a','#d6aa46','#9a2a2a','#5ab0ff'][q%4];g.fillRect(c[0]-1*u,c[1]-WH*1.25,2*u,5*u)}
  boxR(12.05,2.15,16,2.85,0,WH*.85,'#5a3418','#3a2212','#2e1a0e');boxR(12,2.1,16,2.9,WH*.85,WH*.06,'#d6aa46','#a8832f','#8a6a26')}
function casCageDraw(){boxR(.05,13.05,2,16,0,WH*1.1,'#4a3a26','#3a2c1c','#2e2316');
  g.strokeStyle='rgba(214,170,70,.8)';g.lineWidth=1.1*u;g.beginPath();for(let q=0;q<9;q++){const a=iso(2,13.15+q*.32),h=WH*.75;g.moveTo(a[0],a[1]-WH*1.1);g.lineTo(a[0],a[1]-WH*1.1-h)}g.stroke();
  boxR(.05,13.05,2,16,WH*1.85,WH*.12,'#d6aa46','#a8832f','#8a6a26')}
function casPillar(i,j){boxR(i+.25,j+.25,i+.75,j+.75,0,WH*3.2,'#d6aa46','#9c7a2a','#7e6222');boxR(i+.18,j+.18,i+.82,j+.82,0,WH*.25,'#b58a2e','#7e6222','#66501c')}
function casCouch(){boxR(12.1,14.15,13.9,14.85,0,WH*.35,'#6a1424','#4a0e19','#3c0b14');boxR(12.1,14.6,13.9,14.85,WH*.35,WH*.4,'#7a1828','#5a1220','#4a0e19')}
function casRopes(){for(let q=0;q<5;q++)for(const y of[8.75,11.25]){const x=1.4+q*1.1,c=iso(x,y);g.fillStyle='#d6aa46';g.fillRect(c[0]-.8*u,c[1]-WH*.75,1.6*u,WH*.75);oval(c[0],c[1]-WH*.75,1.6*u,1*u,'#e8c86a');
    if(q<4){const d=iso(x+1.1,y);g.strokeStyle='#8a1020';g.lineWidth=1.8*u;g.beginPath();g.moveTo(c[0],c[1]-WH*.62);g.quadraticCurveTo((c[0]+d[0])/2,(c[1]+d[1])/2-WH*.4,d[0],d[1]-WH*.62);g.stroke()}}}
// everything above, queued into the depth-sorted draw list
function casinoItems(){
  casGlowQ.length=0;
  for(const i of CAS.slotsN)ritem(i+0+1,(k)=>casSlot(k+.5,.55,'s',k),i);
  for(const j of CAS.slotsW)ritem(0+j+1,(k)=>casSlot(.55,k+.5,'e',k+3),j);
  ritem(13+2+1.5,casBarDraw);ritem(CAS.bar.keep.x+CAS.bar.keep.y,()=>drawPerson(CAS.bar.keep.x,CAS.bar.keep.y,Object.assign({aim:{x:0,y:1},walk:0},CAS.looks.keep)));
  for(const [x,y]of CAS.bar.stools)ritem(x+y,()=>casStool(x,y));
  ritem(1+13+2,casCageDraw);for(const [i,j]of CAS.pillars)ritem(i+j+1,()=>casPillar(i,j));ritem(12+14+1.2,casCouch);ritem(1.4+9,casRopes);
  for(const t of CAS.tables){ritem(t.dealer.x+t.dealer.y,casDealer,t);ritem(t.c[0]+t.c[1]+.6,casTableBody,t);ritem(t.c[0]+t.c[1]+.65,casFelt,t);
    t.seats.forEach(([x,y],k)=>{const code=seatCode(t.n,k),taken=casTaken(code);ritem(x+y-.05,()=>t.game==='he'?casChair(x,y):casStool(x,y,taken?'#7a1020':'#a01830'));
      if(taken&&taken.bot){const dx=t.c[0]-x,dy=t.c[1]-y,l=Math.hypot(dx,dy)||1;ritem(x+y,()=>casSeated({x,y},()=>drawPerson(x,y,Object.assign({aim:{x:dx/l,y:dy/l},walk:0,flash:false},CAS_BOT))))}})}
  // neon over the tables, the bar and the cage, and the marquee over the door wall
  for(const t of CAS.tables)casGlowQ.push(['sign',t.sign[0],t.sign[1],t.name,t.col,WH*2.7]);
  casGlowQ.push(['sign',1,14.5,'CASHIER','#4aff9a',WH*2.3],['sign',14,1.4,'BAR ▽','#ff6ad0',WH*2.6]);
}
// neon, bulbs and slot screens: after the lighting, added on top (so the dark room makes them glow)
const CAS_GLOW=new Map();
function casGlowDot(col){let c=CAS_GLOW.get(col);if(c)return c;c=document.createElement('canvas');c.width=c.height=64;const x=c.getContext('2d'),gr=x.createRadialGradient(32,32,0,32,32,32);
  gr.addColorStop(0,col);gr.addColorStop(1,'rgba(0,0,0,0)');x.globalAlpha=.85;x.fillStyle=gr;x.fillRect(0,0,64,64);CAS_GLOW.set(col,c);return c}
function casinoGlow(){
  if(!MAP||!MAP.casino)return;const t=game.time;
  for(const q of casGlowQ){
    if(q[0]==='dot'){const [,x,y,r,col,a]=q;g.globalAlpha=a;g.drawImage(casGlowDot(col),x-r,y-r,r*2,r*2);continue}
    const [,wx,wy,text,col,h]=q,c=iso(wx,wy),y=c[1]-h,fl=Math.sin(t*23+wx*3)>.985?.35:1;   // a flicker now and then
    g.globalAlpha=.55*fl;g.drawImage(casGlowDot(col),c[0]-TW2*1.6,y-TW2*.8,TW2*3.2,TW2*1.6);
    g.globalAlpha=fl;g.font=`900 ${Math.round(9*u)}px "Big Shoulders Stencil Display","Arial Narrow",sans-serif`;g.textAlign='center';g.fillStyle=col;g.fillText(text,c[0],y+3*u);
    g.globalAlpha=.9*fl;g.fillStyle='#fff6e8';g.fillText(text,c[0],y+3*u-.4*u)}
  // the marquee on the north wall: the casino's name in lights, bulbs chasing round it
  const A=iso(4.2,0),B=iso(11.8,0),H=WH*3.4,m=lerp2(A,B,.5),top=m[1]-H*.86,hw=(B[0]-A[0])*.5;
  g.globalAlpha=.35;g.drawImage(casGlowDot('#ffb43a'),m[0]-hw*1.1,top-WH*.9,hw*2.2,WH*2.2);g.globalAlpha=1;
  g.font=`900 ${Math.round(10.5*u)}px "Big Shoulders Stencil Display","Arial Narrow",sans-serif`;g.textAlign='center';
  g.fillStyle='#ff8a2a';g.fillText('THE PALISADE FALLS',m[0],top+WH*.15);g.fillStyle='#fff3d6';g.fillText('THE PALISADE FALLS',m[0],top+WH*.15-.5*u);
  g.font=`900 ${Math.round(8*u)}px "Big Shoulders Stencil Display","Arial Narrow",sans-serif`;g.fillStyle='#ff4a6a';g.fillText('★ CASINO ★',m[0],top+WH*.62);
  const n=28,ph=Math.floor(t*10);for(let k=0;k<n;k++){const f=k/n,on=(k+ph)%4===0;const x=A[0]+(B[0]-A[0])*f,yy=A[1]+(B[1]-A[1])*f-H*.97;g.globalAlpha=on?1:.35;g.fillStyle=on?'#fff0b0':'#c8902a';g.beginPath();g.arc(x,yy,1.3*u,0,Math.PI*2);g.fill()}
  g.globalAlpha=1;
}
// light pools: chandeliers, a lamp over every table, the slots, bar and cage
function casinoLights(hole,at){
  for(const [x,y]of CAS.lamps){const c=at(x,y);hole(c[0],c[1],TW2*3.1,.88)}
  for(const t of CAS.tables){const c=at(t.c[0],t.c[1]);hole(c[0],c[1],TW2*2.4,.95)}
  for(const i of CAS.slotsN){const c=at(i+.5,.9);hole(c[0],c[1],TW2*1.1,.5)}for(const j of CAS.slotsW){const c=at(.9,j+.5);hole(c[0],c[1],TW2*1.1,.5)}
  {const c=at(1,14.5);hole(c[0],c[1],TW2*2,.7)}{const c=at(8,.6,WH*2.4);hole(c[0],c[1],TW2*3.6,.7)}
}

// ---------- seats: sitting down by walking up ----------
// who is in which seat, from every player's seat code (the host relays it like a position)
function casTaken(code){for(const o of players.values())if(o.seat===code)return o;const q=casSeatOf(code);return q&&q.t&&casBotAt(q.t,q.k)?{bot:true}:null}
// the free seat you're standing next to, if any
function casSeatNear(p){let best=null,bd=.75;for(const t of CAS.tables)t.seats.forEach(([x,y],k)=>{const d=Math.hypot(p.x-x,p.y-y);if(d<bd&&!casTaken(seatCode(t.n,k))){bd=d;best={t,k}}});return best}
// take the seat: snap onto it, face the table, and ask the server for that seat at that table
function casSit(){const p=player;if(!casino()||!p||p.seat)return;const s=casSeatNear(p);if(!s)return;
  const no=tbCanPlay();if(no){toast('TABLES',no);return}
  const [x,y]=s.t.seats[s.k];p.x=x;p.y=y;p.seat=seatCode(s.t.n,s.k);const dx=s.t.c[0]-x,dy=s.t.c[1]-y,l=Math.hypot(dx,dy)||1;p.aim=p.face={x:dx/l,y:dy/l};
  setTip('');tbSitAt(s.t.game,s.k)}
function casStand(){const p=player;if(!p||!p.seat)return;p.seat=0;if(TB.id)tbSend({op:'leave',id:TB.id});tbSheet(false)}
// a seated player is drawn sitting: the lower half tucked behind the stool, a little lower
function casSeated(o,draw){const c=iso(o.x,o.y);g.save();g.beginPath();g.rect(-1e4,-1e4,2e4,c[1]-1.5*u+1e4);g.clip();g.translate(0,5*u);draw();g.restore()}
// names over heads (no health in the casino), and the dealers' names in gold
function casPlates(){const rec=drawNameplates.out=[];
  for(const o of players.values()){const c=iso(o.x,o.y),top=c[1]-46*u+(o.seat?5*u:0),me=o===player;rec.push({who:me?'me':o.name,bar:false,seat:o.seat||0});
    label((me?'YOU':o.name||'PLAYER').toUpperCase(),c[0],top-2*u,SLOTCOL[o.slot%6],9)}
  for(const t of CAS.tables){const d=t.dealer,c=iso(d.x,d.y);label(d.name+' · DEALER',c[0],c[1]-48*u,'#d6aa46',8)}}
// the SIT prompt over a free seat you're next to (touch: the SIT button does it)
function casPrompts(p){if(p.seat){if(!TB.sheet){const c=iso(p.x,p.y);keyCap(c[0],c[1]-50*u,ctl('','E',padKey('armory')),touchMode&&!padMode?'TAP TABLE':'OPEN THE TABLE','#d6aa46')}return}const s=casSeatNear(p);if(!s)return;
  const [x,y]=s.t.seats[s.k],c=iso(x,y);keyCap(c[0],c[1]-34*u,ctl('','E',padKey('armory')),touchMode&&!padMode?'TAP SIT':'SIT · '+s.t.name,'#d6aa46')}
// the top bar in the casino: where you are, the room code, your balance
function casHud(){hid($('qmM'),true);hid($('coreM'),true);hid($('core2M'),true);hid($('board'),true);hid($('salv'),true);hid($('skipBtn'),true);hid($('qmCommand'),true);
  const lab=$('phaseLab');txt(lab,W<700?'CASINO':'PALISADE FALLS CASINO');cls(lab,'raid',false);cls(lab,'evac',false);
  txt($('phaseVal'),(NET.mode!=='solo'&&NET.code?'ROOM '+NET.code+' · ':'')+'◆ '+(TB.balance||locker.shards||0)+(player&&player.seat?' · seated':''));
  const b=$('casSitBtn'),seated=!!(player&&player.seat);txt(b,seated?'TABLE':'SIT');hid(b,!touchMode||padMode||(seated?TB.sheet:!player||!casSeatNear(player)))}
// touch: SIT next to a free seat; TABLE when you're seated with the table hidden
$('casSitBtn').addEventListener('click',()=>{if(!casino()||!player)return;if(player.seat)tbSheet(true);else casSit()});

// ---------- the room: who's in this casino ----------
// a host's casino is its room code and incarnation; guests get it in the start message; alone, a room of your own
let CAS_PREV='5';
function casRoom(){if(NET.mode==='host'&&NET.code&&NET.incarnation)return 'R:'+NET.code+':'+NET.incarnation;if(NET.mode==='guest'&&NET.casRoom)return NET.casRoom;
  return game.casRoom||(game.casRoom='SOLO:'+String(myUid()||'x').slice(0,8)+':'+Date.now().toString(36))}
// ENTER THE CASINO: open a room (so the crew can drop in by code or invite) and walk straight in; offline, just you
async function casEnter(){const no=tbCanPlay();if(no){tbMsg(no);return}if(inRun()&&$('menu').hidden)return;
  if(pick.mode!=='casino')CAS_PREV=pick.mode;pick.mode='casino';pick.pvp='coop';initAudio();tbMsg('Opening the doors…');
  if(NET.mode==='host'&&!NET.inGame){startOnline();return}   // already hosting a lobby: everyone in it comes too
  NET.autoCasino=true;await netHost();if(NET.autoCasino&&NET.mode==='solo'){NET.autoCasino=false;casSolo()}}
function casSolo(){pick.mode='casino';tbMsg('');start()}
// JOIN BY CODE from the TABLES page: the same join as MULTIPLAYER (the host's start message brings you into their casino)
function casJoin(code){if(pick.mode!=='casino')CAS_PREV=pick.mode;showPage('multi');$('mCode').value=code;initAudio();netJoin(code)}
// a bot in a Hold'em seat (no player walks it in): drawn sitting there in a dealer's waistcoat
const CAS_BOT={body:'#d8d2c4',vest:'#2a2a33',pants:'#1c1b1f',head:'#9a9aa6',hat:'#33333c',gl:14,nogun:true};
function casBotAt(t,k){const v=casView(t.game);return !!(v&&v.seats&&v.seats[k]&&v.seats[k].bot)}
