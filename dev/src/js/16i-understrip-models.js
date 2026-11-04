/* ================= v0.12 THE UNDERSTRIP CASE: its 30 items, and the ten skins' own models ================= */
// Work order 9.1-9.3; the tiers are dev/plans/understrip/tables/case_items.csv (D13, D14). Every skin here is its own model
// on the shared figure's frame (legs, body, head), drawn by the wardrobe painter (16-characters) through four hooks:
// usModelLeg, usModelBody, usModelArm and usModelHead, each handed the painter's own primitives (K). The same models are
// what the Locker, the lobby stage and the four-angle catalogue draw. LEGAL (work order 3): the King of the Strip is a
// lounge singer in a jumpsuit, never anyone's name or face; the Generalissimo's medals, sash and badge are invented.
const US_SKINS=[   // [key, name, rarity, body (sleeves), vest, pants, head (skin), helmet colour, open head (can wear hats), art note]
  ['pitboss','The Pit Boss','r','#2a2a30','#2a2a30','#26262c','#b08a6a','#1a1410',true,'The count room\'s boss: a torn casino-floor suit, a red tie, an earpiece, a pocketful of chips.'],
  ['shelterdweller','Shelter Dweller','r','#5d6236','#5d6236','#4e5230','#b58f6e','#5d6236',true,'A Shelter 7 jumpsuit in the Desert Civil Defence Authority\'s olive and orange, a 7 patch and a ration-pack belt.'],
  ['gunslinger','The Gunslinger','r','#8a6a44','#6a4c30','#3e3428','#b08868','#4a3424',false,'A long dust coat, a flat-brim hat that is part of the model, and a bandolier across the chest.'],
  ['highroller','High Roller','e','#151517','#151517','#151517','#c19a78','#151517',true,'A black-and-white checkerboard suit and tie, a red pocket square and two-tone shoes.'],
  ['generalissimo','El Generalissimo','e','#5c5a3a','#5c5a3a','#4a4830','#b08868','#4a4a30',false,'An invented generalissimo: a peaked cap, a red sash, a chest of made-up medals and gold epaulettes.'],
  ['sheriff','The Sheriff','e','#e4ddc8','#3a2a20','#4a3a2c','#b58f6e','#d8c8a0',false,'Shirt sleeves under a dark waistcoat, a gold star, a big moustache and a tall hat.'],
  ['stripking','King of the Strip','l','#f4f0e6','#f4f0e6','#f4f0e6','#c19a78','#1a1410',false,'A lounge singer\'s white jumpsuit sewn with rhinestones, a high collar, a cape, gold shades and a pompadour.'],
  ['custodian','The Custodian','l','#7d8a5a','#7d8a5a','#5e6a44','#6a7450','#6a7450',false,'Shelter 7\'s caretaker robot as a shell you wear: boxy, the mop holstered on its back, one cracked lens.'],
  ['cardsharp','The Card Sharp','l','#efe9dc','#7a1a2a','#2a2420','#c19a78','#2a2420',true,'A riverboat gambler: a brocade vest, sleeve garters, a string tie and a fan of cards in the off hand.'],
  ['visitor','The Visitor','g','#9a9aa8','#8a8a98','#8a8a98','#b8b8c4','#b8b8c4',false,'The finale\'s grey visitor: tall and thin, big black eyes, and a faint psychic glow round its feet.']];
const US_HATS=[['tinfoil','Tinfoil Hat','c','A crumpled foil cap, folded by someone sure they were being listened to.'],
  ['eyeshade','Dealer\'s Eyeshade','c','A blackjack dealer\'s green eyeshade on a black band.'],
  ['antennae','Antenna Headband','r','Two bobbing antennae with glowing tips on a black band.'],
  ['plumecrest','Showgirl Plume Crest','e','A sequined band and a fan of tall pink-and-white plumes that sway.'],
  ['neonhalo','Neon Halo','l','A casino-sign ring of pink neon over the head; a tube or two flickers.']];
const US_TRAILS=[['chips','Poker Chips','c','#e8e2d0','Chips tumble off the back of the shot: red, blue, green and white.'],
  ['neontube','Neon Tube','r','#ff5ad8','A pink neon tube with a blue core, humming.'],
  ['jackpotcoins','Jackpot Coins','r','#ffd24a','Gold coins spill along the shot.'],
  ['tractorbeam','Tractor Beam','e','#b8ffa8','A pale green beam that wobbles as it goes.'],
  ['saucerbolt','Saucer Bolt','e','#7cff6b','A fat green bolt with a ring round its head.']];
const US_FX=[['bust','Bust','c','Cards scatter, flip and land face down.'],['plumes','Showgirl Plumes','r','A burst of feathers and sequins.'],
  ['jackpot','Jackpot!','e','A slot machine pays out three 7s and the coins burst out.'],['dissolved','Dissolved','l','Green goo melts the raider to a bubbling puddle.'],
  ['abducted','Abducted','g','A beam from above lifts the raider up and away. The case\'s showpiece.']];
const US_BG=[['floodtunnels','The Flood Tunnels','c','Dripping concrete and a lit grate above.'],['vaultdoor','Casino Vault Door','r','Gold light through a huge round vault door.'],
  ['area67','Area 67 Fence at Dusk','r','A fence at dusk, sweeping searchlights and a light that hovers.'],['stripnight','The Strip at Night','e','A retro neon skyline, its signs chasing.'],
  ['specimenhall','Specimen Hall','e','Tanks glowing in a dark lab; something turns inside one.']];
const US_SKIN_BY=Object.fromEntries(US_SKINS.map(s=>[s[0],s])),US_HAT_SET=new Set(US_HATS.map(h=>h[0]));
Object.assign(AURAS,{gvisitor:[{p:'pool',col:'#b8a8ff',a:.24},{p:'ring',col:'#b8a8ff'},{p:'orbit',n:3,col:'#e0d8ff',shape:'dot',size:1.2,glow:true,sp:.8},{p:'rise',n:5,cols:['#b8a8ff','#7cff6b','#e0d8ff'],shape:'dot',sp:.4}]});

// ---------- the wardrobe painter's hooks ----------
// K: {box, column, beam, dome, brim, ball, mesh, bob, time, skin, B, V, T, tint, compact, o}
const usFlat=(K,pts,z,col,bias=1.2)=>{const v=pts.map(([x,y])=>[x,y+K.bob,z]);K.mesh(v,[v.map((_,i)=>i)],col,.08,bias)};
const usStar=(K,cx,cy,z,r,col)=>{const p=[];for(let i=0;i<10;i++){const a=Math.PI/2+i*Math.PI/5,rr=i%2?r*.45:r;p.push([cx+Math.cos(a)*rr,cy+Math.sin(a)*rr])}usFlat(K,p,z,col,1.3)};
// an egg: rings round a vertical axis, narrower toward the chin (taper < 1)
function usEgg(K,cx,cy,cz,rx,ry,rz,col,taper=1){const SEG=K.compact?10:18,RINGS=K.compact?5:9,v=[],ff=[];
  for(let r=0;r<=RINGS;r++){const a=-Math.PI/2+Math.PI*r/RINGS,y=Math.sin(a)*ry,k=Math.cos(a)*(r===0||r===RINGS?.2:1)*(a<0?1-(1-taper)*(-Math.sin(a)):1);
    for(let q=0;q<SEG;q++){const t=Math.PI*2*q/SEG;v.push([cx+Math.cos(t)*rx*k,cy+y+K.bob,cz+Math.sin(t)*rz*k])}}
  for(let r=0;r<RINGS;r++)for(let q=0;q<SEG;q++){const a0=r*SEG+q,a1=r*SEG+(q+1)%SEG;ff.push([a0,a1,a1+SEG,a0+SEG])}
  ff.push(Array.from({length:SEG},(_,q)=>RINGS*SEG+SEG-1-q),Array.from({length:SEG},(_,q)=>q));K.mesh(v,ff.map(f=>f.slice().reverse()),col,.55)}
const usOval=(K,cx,cy,rx,ry,z,col,bias=1.3)=>{const p=[];for(let i=0;i<12;i++){const a=i*Math.PI/6;p.push([cx+Math.cos(a)*rx,cy+Math.sin(a)*ry])}usFlat(K,p,z,col,bias)};
// a leg: true when the model drew it
function usModelLeg(K,L,side){const m=K.o.usModel,{box,column,beam}=K,{x,z,lift,ankle,knee,hip}=L,T=K.T;
  if(m==='visitor'){column(x,1.2+lift,z+1.2,2.4,1.6,3.4,K.B,.9,.3);beam(ankle,knee,.85,K.B,.95,.3);beam(knee,hip,.95,K.B,1.15,.3);return true}
  if(m==='custodian'){column(x,2+lift,1.2+z,5,3.4,6.6,'#3a3f2c',.9,.4);box(x,.7+lift,1.3+z,5.2,.9,6.8,'#2a2c22',.3);beam(ankle,knee,2.2,T,2.4,.4);beam(knee,hip,2.4,T,2.7,.4);box(x,8.8+lift*.5,z+2.2,2.6,2.2,.8,'#d0782a',.2);return true}
  if(m==='stripking'){column(x,1.8+lift,1.1+z,4.1,2.6,5.8,'#f4f0e6',.87);beam(ankle,knee,2.45,T,2,.4);beam(knee,hip,2.05,T,2.35,.4);   // bell-bottoms flare to the boot
    column(ankle[0],ankle[1]+1.4,ankle[2],5.2,2.2,5.2,T,1.25,.3);for(let k=0;k<3;k++)box(ankle[0]+side*2.55,ankle[1]+2+k*2.2,ankle[2],.3,.5,.5,'#e2c25a',.05);return true}
  if(m==='highroller'){column(x,2+lift,1.05+z,4.3,3.1,6.1,'#f0ece0',.87);box(x,2.4+lift,3.3+z,4.4,2.2,1.6,'#141414',.25);box(x,.7+lift,1.2+z,4.35,.85,6.25,'#202020',.3);   // white spats, black toe caps
    beam(ankle,knee,1.7,T,2);beam(knee,hip,2.05,T,2.35);return true}
  if(m==='generalissimo'){column(x,4+lift,1.05+z,4.4,7,5.8,'#151515',.9,.45);box(x,.7+lift,1.3+z,4.5,.9,6.3,'#0c0c0c',.3);beam(ankle,knee,1.8,T,2.05);beam(knee,hip,2.1,T,2.4);
    const mid=knee.map((v,i)=>v+(hip[i]-v)*.5);box(mid[0]+side*2.2,mid[1],mid[2],.35,6.5,.9,'#c42a3a',.05);return true}   // a red stripe down the outside
  if(m==='gunslinger'||m==='sheriff'){column(x,2.6+lift,1.05+z,4.2,4.4,6.1,m==='sheriff'?'#4a3020':'#5a3a22',.9,.45);box(x,.7+lift,1.2+z,4.3,.9,6.6,'#2a1a10',.3);box(x,3.4+lift,-2.2+z,1.3,1.3,.8,'#c8b070',.1);   // boots and a spur
    beam(ankle,knee,1.7,T,2);beam(knee,hip,2.05,T,2.35);return true}
  return false}
// the body (hips to neck): true when the model drew it
function usModelBody(K){const m=K.o.usModel,{box,column,beam,bob,B,V,T,skin}=K,b=bob;
  const neck=(col=skin)=>column(0,27+b,0,4.5,2.8,3.6,col,1,.32);
  switch(m){
    case'highroller':{column(0,15+b,0,9.1,3.8,5.2,T,1.06);column(0,21.2+b,0,10.2,10.8,5.6,B,1.15);
      for(let i=0;i<5;i++)for(let j=0;j<6;j++)if((i+j)%2){const x=-3.6+i*1.8,y=16.9+j*1.75;box(x,y+b,2.98,1.75,1.7,.16,'#ecebe4',.04,1);box(x,y+b,-2.98,1.75,1.7,.16,'#ecebe4',.04,1)}   // the checkerboard, front and back
      usFlat(K,[[-2.2,26.3],[2.2,26.3],[0,21.6]],3.06,'#f4f2ea');box(0,23.4+b,3.18,1.05,4.4,.22,'#141416',.05,1.4);for(const y of[22.4,24.4])box(0,y+b,3.3,1.05,1,.1,'#ecebe4',.02,1.5);   // shirt, the checked tie
      box(-3.4,24.6+b,3.1,1.5,1,.25,'#d42a2a',.05,1.3);neck();box(0,26.6+b,1.8,5,1,2.4,'#f4f2ea',.2);return true}
    case'pitboss':{column(0,15+b,0,9.1,3.8,5.2,T,1.06);column(0,21.2+b,0,10.2,10.8,5.6,B,1.15);
      usFlat(K,[[-2,26.3],[2,26.3],[0,21.8]],3.06,'#e8e2d0');box(0,23.6+b,3.18,1,4,.22,'#a8202a',.05,1.4);   // white shirt, red tie
      for(const [x,y,c]of[[3.2,24.6,'#c42a3a'],[3.6,24.9,'#2a5ac4'],[2.8,24.9,'#2fa04a']])column(x,y+b,3.2,1.1,.4,.4,c,1,.08);   // chips in the breast pocket
      for(const [x,y]of[[-4.4,16.4],[-3.4,15.9],[4.6,16.6]])usFlat(K,[[x-.7,y+.9],[x+.7,y+.9],[x,y-.6]],2.95,'#48485a');   // torn hem
      neck();return true}
    case'shelterdweller':{column(0,15+b,0,9.1,3.8,5.2,B,1.06);column(0,21.2+b,0,10.2,10.8,5.6,B,1.15);
      box(0,21.5+b,2.95,.6,9.4,.2,'#d0782a',.04,1);box(0,26.3+b,2.6,6.4,1.2,1.8,'#d0782a',.2);box(-2.9,24+b,3.02,2.4,2.4,.18,'#d0782a',.05,1.2);box(-2.9,24+b,3.12,1.4,1.5,.1,'#2e3020',.02,1.4);   // zip, collar, the 7 patch
      column(0,16.3+b,0,9.7,1.5,6,'#3a3a2a',1,.25);for(const [x,z]of[[-3.2,3],[0,3.1],[3.2,3],[-4.8,0],[4.8,0],[0,-3]])box(x,16.4+b,z,x&&!z?1.4:2,2,x&&!z?2.2:1.2,'#7a6a44',.25);   // the ration-pack belt
      neck();return true}
    case'cardsharp':{column(0,15+b,0,9.1,3.8,5.2,T,1.06);column(0,21.2+b,0,10.2,10.8,5.6,B,1.15);column(0,21.4+b,.15,10.3,9,6.1,V,1.02,.45);
      for(let i=0;i<4;i++)for(let j=0;j<4;j++)box(-3.2+i*2.1+(j%2)*1,17.5+j*2.2+b,3.1,.55,.55,.12,'#e2c25a',.02,1.2);   // the brocade
      usFlat(K,[[-1.6,26.3],[1.6,26.3],[0,23.2]],3.12,'#efe9dc');beam([-.2,26+b,3.3],[-.6,23.6+b,3.4],.12,'#141414',.12,.03);beam([.2,26+b,3.3],[.6,23.6+b,3.4],.12,'#141414',.12,.03);   // string tie
      box(-2.8,18.6+b,3.2,1.4,.3,.15,'#e2c25a',.02,1.2);neck();return true}
    case'sheriff':{column(0,15+b,0,9.1,3.8,5.2,T,1.06);column(0,21.2+b,0,10.2,10.8,5.6,B,1.15);column(0,21.4+b,.1,10.3,9.4,6.2,V,1.02,.45);
      usFlat(K,[[-1.8,26.3],[1.8,26.3],[0,22.4]],3.12,B);usStar(K,-2.7,23.2,3.22,1.5,'#e2c25a');
      column(0,16.3+b,0,9.7,1.4,6,'#4a3020',1,.25);box(0,16.3+b,3.05,1.8,1.3,.3,'#c8b070',.12);box(4.4,15+b,.8,1.6,4.6,2.6,'#3a2414',.3);   // gun belt, buckle, holster
      neck();box(0,26.6+b,2.2,3.4,.8,.3,'#a8202a',.08);return true}
    case'gunslinger':{column(0,15+b,0,9.1,3.8,5.2,T,1.06);column(0,21.2+b,0,10.6,10.8,6,B,1.15);
      column(0,11.4+b,-.2,11.2,9.6,6.6,B,1.12,.5);box(0,11.4+b,3.2,2.2,9.6,.3,T,.05,1);   // the long coat's skirt, open at the front
      column(0,25.4+b,0,11.6,2.6,6.8,tintK(K,B,.85),1,.35);   // the shoulder cape
      beam([-4.4,26+b,3.25],[4.6,15.6+b,3.35],.6,'#4a3020',.6,.2);for(let k=0;k<6;k++){const f=k/5;box(-4+f*8.2,25.2-f*9+b,3.75,.45,.9,.45,'#d8b45a',.05,1.3)}   // the bandolier
      neck();box(0,26.8+b,2,4.4,1.3,2,'#a8202a',.2);return true}
    case'generalissimo':{column(0,15+b,0,9.1,3.8,5.2,T,1.06);column(0,21.2+b,0,10.4,10.8,5.8,B,1.15);
      box(0,21.5+b,3,.5,9.5,.15,'#3a3820',.03,1);for(let k=0;k<4;k++)box(.6,18+k*2.2+b,3.1,.45,.45,.15,'#e2c25a',.02,1.2);   // buttons
      beam([-4.6,26.2+b,3.05],[4.7,16.5+b,3.25],.65,'#c42a3a',.6,.15);beam([-4.6,26.2+b,-3.05],[4.7,16.5+b,-3.25],.65,'#c42a3a',.6,.15);   // the sash
      const med=['#e2c25a','#c8ccd0','#c42a3a','#2a5ac4','#2fa04a','#e2c25a'];for(let i=0;i<3;i++)for(let j=0;j<2;j++){const x=-1.6-i*1.15,y=24.4-j*1.9;box(x,y+b,3.12,.9,.5,.12,med[(i+j*2)%6],.02,1.3);column(x,y-.75+b,3.18,.7,.55,.25,j?'#c8ccd0':'#e2c25a',1,.05)}   // the invented medals
      for(const s of[-1,1]){box(s*5.5,26.4+b,0,3,1,3.8,'#e2c25a',.25);for(let k=0;k<3;k++)beam([s*(4.5+k*.9),25.9+b,1.4-k*1.4],[s*(4.6+k*.9),24.6+b,1.4-k*1.4],.16,'#e2c25a',.12,.03)}   // epaulettes
      column(0,16.3+b,0,9.7,1.3,6,'#3a2414',1,.25);box(0,16.3+b,3.05,1.6,1.1,.3,'#e2c25a',.1);neck();box(0,26.5+b,1.8,5,1.2,2.4,B,.2);return true}
    case'stripking':{column(0,15+b,0,9.1,3.8,5.2,T,1.06);column(0,21.2+b,0,10.2,10.8,5.6,B,1.15);
      usFlat(K,[[-2.4,26.4],[2.4,26.4],[0,20.4]],3.02,skin);for(let k=0;k<6;k++){const f=k/5;for(const s of[-1,1])box(s*(2.6-f*2.3),26-f*5.4+b,3.1,.42,.42,.12,k%2?'#e2c25a':'#e6f0ff',.02,1.3)}   // the deep V, sewn with rhinestones
      for(let i=0;i<5;i++)box(-3.6+i*1.8,18.3+b,3.05,.5,.5,.12,i%2?'#e6f0ff':'#e2c25a',.02,1.3);
      column(0,16.3+b,0,9.8,1.8,6,'#e2c25a',1,.3);box(0,16.3+b,3.15,3.2,2.4,.4,'#f4dc7a',.15);   // the belt and its buckle
      column(0,27.9+b,-.8,7.8,3.2,5.2,B,1.18,.35);   // the high collar
      box(0,19.4+b,-3.7,11.4,13.4,.45,B,.3);box(0,19.4+b,-3.4,10.6,12.6,.2,'#c42a3a',.06);for(let k=0;k<4;k++)box(-3.6+k*2.4,14+b,-3.95,.45,.45,.12,'#e2c25a',.02,1.2);   // the cape, lined red
      return true}
    case'custodian':{box(0,15.4+b,0,9.6,4,6.4,'#5e6a44',.4);box(0,21.6+b,0,11.6,11.4,7.2,B,.5);box(4.2,21.6+b,0,2.6,11.6,7.3,'#6a7650',.3);
      box(0,19.4+b,3.7,11.8,1.4,.2,'#d0782a',.05,1);for(const [x,y]of[[-3,24.6],[0,24.6],[3,24.6]])box(x,y+b,3.7,1.8,1.6,.2,'#3a3f2c',.05,1);box(-3.6,17.2+b,3.7,1.4,.8,.2,'#ffd23a',.03,1.2);   // stripe, vents, a lamp
      for(const s of[-1,1])box(s*6,25.6+b,0,2.4,2.4,6,'#5e6a44',.35);   // shoulder caps
      beam([-2.4,12+b,-4.1],[3,33.4+b,-4.1],.42,'#8a7a5a',.42,.15);box(3.3,34.2+b,-4.1,3.2,1.5,1.8,'#c8c0a0',.25);box(0,26.6+b,0,4,1.6,4,'#3a3f2c',.3);return true}   // the mop, holstered on the back
    case'visitor':{column(0,15.4+b,0,6,3,4,B,.95);column(0,21.4+b,0,7,12,4.4,B,.82);column(0,27.6+b,0,2.2,3.2,2.2,B,1,.3);
      for(const s of[-1,1])beam([s*2,25.6+b,1.6],[s*1.2,17+b,2],.12,tintK(K,B,.8),.12,.03);return true}   // a thin frame, faint ribs
  }
  return false}
const tintK=(K,c,k)=>K.tint(c,k);
// an arm, after it's drawn: garters, the card fan, the robot's plates
function usModelArm(K,sh,el,ha,left){const m=K.o.usModel,{beam,mesh}=K;
  if(m==='cardsharp'){const g=sh.map((v,i)=>v+(el[i]-v)*.55),g2=sh.map((v,i)=>v+(el[i]-v)*.68);beam(g,g2,2.25,'#c42a3a',2.25,.15);
    if(left){for(let k=0;k<5;k++){const a=-.7+k*.35,cx=ha[0]-.4,cy=ha[1]+1.2,cz=ha[2]+.4,dx=Math.sin(a),dy=Math.cos(a),W=1.1,H=2.6;
      const v=[[cx-dy*W*.5,cy+dx*W*.5,cz+k*.02],[cx+dy*W*.5,cy-dx*W*.5,cz+k*.02],[cx+dy*W*.5+dx*H,cy-dx*W*.5+dy*H,cz+k*.02],[cx-dy*W*.5+dx*H,cy+dx*W*.5+dy*H,cz+k*.02]];
      mesh(v,[[0,1,2,3],[3,2,1,0]],k===2?'#f4f0e6':'#ece6d8',.25,.4)}}}
  else if(m==='custodian'){const mid=sh.map((v,i)=>(v+el[i])/2);K.column(mid[0],mid[1],mid[2],3.2,3,3.2,'#5e6a44',1,.3)}}
// the head: true when the model replaced it (no ordinary face); its own hats and hair are drawn here too
function usModelHead(K){const m=K.o.usModel,{box,column,beam,dome,brim,ball,bob,skin}=K,b=bob,o=K.o;
  const hair=(c)=>dome(c,32.7,4.2,3.6,1.65);
  switch(m){
    case'visitor':{usEgg(K,0,32.4,.3,4.9,5.6,4.6,skin,.55);   // the big head, narrowing to the chin
      for(const s of[-1,1]){const p=[];for(let i=0;i<12;i++){const a=i*Math.PI/6;p.push([s*1.95+Math.cos(a)*1.25*Math.cos(s*.5)-Math.sin(a)*2.05*Math.sin(s*.5),31.6+Math.sin(a)*2.05*Math.cos(s*.5)+Math.cos(a)*1.25*Math.sin(s*.5)])}usFlat(K,p,4.55,'#08080c',1.4);
        usOval(K,s*1.6,32.4,.3,.35,4.62,'#f4f4ff',1.6)}box(0,29.4+b,4.05,1.2,.18,.12,'#6a6a78',.02,1.4);return true}
    case'custodian':{column(0,28.6+b,0,4.6,2.4,4.2,'#3a3f2c',1,.3);dome(skin,29.6,5.6,5,5.2);box(0,31.4+b,4.75,2.8,2.8,.6,'#2a2c22',.2,1.2);box(0,31.4+b,5.1,2,2,.2,'#ffd23a',.04,1.4);   // the one lens
      beam([-.8,32.4+b,5.25],[.7,30.2+b,5.25],.1,'#1a1a12',.1,.02);beam([.7,30.2+b,5.25],[.2,29.9+b,5.25],.08,'#1a1a12',.08,.02);   // its crack
      beam([2.4,34.2+b,0],[3.4,37.2+b,-.6],.18,'#2a2c22',.18,.05);ball(3.4,37.4+b,-.6,.45,'#ff3a2a');return true}
    case'stripking':{dome('#1a1410',32.4,4.5,4,2.4);beam([0,34.2+b,.6],[0,34.8+b,4.4],1.9,'#1a1410',1.3,.3);beam([-1.4,34+b,1],[-.6,34.6+b,4.1],1.1,'#2a2018',.9,.2);   // the pompadour
      for(const s of[-1,1])box(s*3.75,29.6+b,1.4,.7,3,1.4,'#1a1410',.12);box(0,30.9+b,4.02,6.6,1.35,.4,'#e2c25a',.15,1.3);for(const s of[-1,1])box(s*1.55,30.8+b,4.22,2.3,.95,.15,'#2a1a08',.03,1.5);return false}   // sideburns, gold shades
    case'generalissimo':{column(0,34+b,0,9.2,2.6,8.2,'#4a4a30',1.32,.45);column(0,32.7+b,0,9,1,8.1,'#c8a040',1,.2);box(0,32.4+b,4.4,6.6,.45,2.8,'#141414',.3);   // the peaked cap and its band
      usStar(K,0,34.1,4.9,1.1,'#e2c25a');box(0,29.1+b,3.62,3.2,.8,.42,'#2a1e14',.05,1.5);return false}   // an invented badge, a moustache
    case'gunslinger':{brim(32.5+b,13.6,.55,11.6,'#4a3424',.4,4.7,4.1);column(0,34.1+b,0,8.4,3.1,7.4,'#4a3424',.9,.45);column(0,33.1+b,0,8.5,.7,7.5,'#2a1a10',1,.15);   // the flat brim
      box(0,28.4+b,3.2,5.4,1.6,1.4,'#a8202a',.12,1.1);return false}   // the neckerchief pulled up
    case'sheriff':{brim(32.6+b,12.6,.55,10.8,'#d8c8a0',.4,4.6,4.1);column(0,35.6+b,0,8,6.2,7,'#d8c8a0',.88,.45);column(0,33.3+b,0,8.2,.8,7.2,'#3a2414',1,.15);box(0,37.6+b,0,.8,1.2,6,tintK(K,'#d8c8a0',.85),.1);   // the tall hat, its band and crease
      box(0,29.15+b,3.62,3.8,.85,.45,'#4a3020',.05,1.5);for(const s of[-1,1])beam([s*1.8,29+b,3.6],[s*2.2,27.9+b,3.5],.3,'#4a3020',.2,.05);return false}   // the moustache
    case'pitboss':{beam([4.1,30.3+b,.4],[3.4,27.2+b,1.6],.12,'#1a1a1a',.12,.03);box(4.3,30.5+b,.6,.6,.9,.7,'#1a1a1a',.08);if(o.usHair)hair('#2a2018');return false}   // the earpiece and its coil
    case'highroller':if(o.usHair)hair('#1a1410');return false;
    case'shelterdweller':if(o.usHair)hair('#6a4a2a');return false;
    case'cardsharp':if(o.usHair){hair('#2a1e14');box(0,29.2+b,3.6,2.8,.6,.4,'#2a1e14',.05,1.5)}return false;
  }
  return false}
// the five hats (buildLook sets o.usHat)
function usHatPaint(K,h){const {box,column,beam,dome,ball,bob,time,o}=K,b=bob;
  const hair=()=>{if(!(o.bones||o.wraps||o.phantom))dome('#433b2b',32.7,4.2,3.6,1.65)};
  switch(h){
    case'tinfoil':{column(0,33+b,0,10.2,1.4,8.8,'#c8ccd0',1,.3);column(0,35+b,0,8.4,3,7.4,'#d8dce0',.75,.4);column(0,37.6+b,-.2,5.4,2.4,4.8,'#c0c4c8',.6,.35);beam([0,38.6+b,-.3],[.6,40.6+b,-.8],1.2,'#e4e8ec',.15,.25);
      for(let k=0;k<6;k++){const a=k*1.05+.3;box(Math.cos(a)*3.6,34.4+(k%3)*1.1+b,Math.sin(a)*3.1,1.3,.9,.3,k%2?'#f4f8ff':'#a8acb0',.05,.6)}break}   // facets catching the light
    case'eyeshade':{hair();column(0,32.5+b,0,10.1,1.1,8.6,'#1a1a1a',1,.2);box(0,32.3+b,5.4,7.6,.35,3.8,'#3f9a5a',.25,1);box(0,32.25+b,7.2,7.6,.3,.35,'#2a6a3e',.05,1)}break;
    case'antennae':{hair();column(0,32.6+b,0,10.1,1,8.6,'#1a1a1a',1,.2);for(const s of[-1,1]){const sw=Math.sin(time*5+s)*.6;beam([s*2.2,33.6+b,0],[s*3.6+sw,39.4+b,-.4],.22,'#2a2a2a',.2,.06);ball(s*3.6+sw,39.7+b,-.4,.75,'#7cff6b')}break}
    case'plumecrest':{hair();column(0,33.1+b,0,10.4,1.5,8.9,'#ff5ad8',1,.25);for(let k=0;k<6;k++)box(-3.6+k*1.45,33.1+b,4.3,.6,.6,.2,k%2?'#ffe39a':'#e6f0ff',.02,1.2);box(0,33.6+b,4.5,1.6,1.6,.4,'#ffe39a',.12,1.3);
      for(let k=0;k<5;k++){const a=(k-2)*.32,sw=Math.sin(time*2.2+k)*.4;beam([Math.sin(a)*2.2,34+b,1.6],[Math.sin(a)*6+sw,44.5-Math.abs(k-2)*1.4+b,-1],1.35,k%2?'#ffd0f0':'#ff8ad8',.25,.3)}break}
    case'neonhalo':{hair();const y=39.2+b+Math.sin(time*2.4)*.3;for(let i=0;i<16;i++){const a=i*Math.PI/8,a2=(i+1)*Math.PI/8,off=Math.sin(time*9+i*7)>.92&&i%5===2;
      beam([Math.cos(a)*6,y,Math.sin(a)*4.8],[Math.cos(a2)*6,y,Math.sin(a2)*4.8],.32,off?'#5a2048':'#ff5ad8',.32,.04)}break}   // one tube or two flickers
  }}
// which hats a model can wear (an open head wears any of them; a model with its own hat or head only the Class Issue)
const usHatsOk=(key,hat)=>{const S=US_SKIN_BY[key];return !!S&&(S[8]||hat==='class')};
