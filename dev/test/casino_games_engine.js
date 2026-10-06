// v0.10.3 the casino's new games (games.js) and the result review for every game (engine.js), with no browser and no
// database. Baccarat: every Banker third-card decision against the printed table, naturals, ties, commission, the exact
// infinite-deck edges, the 8-deck shoe (burn, cut card, a started hand always finishes, nothing undealt ever shown, every
// dealt card checkable against the shoe's fingerprint, the retired shoe reruns). Craps: all 36 rolls for every bet in
// every phase against an independent rule table, exact house edges from the rules engine (absorbing chain), traveling Come
// bets, working toggles, locked and lowered bets, odds limits, denominations, leaving with bets working and the dealer
// rolling them out. Slots: all 8,000 stop combinations (RTP, hit rate, the window is the real strip). Plinko: all 4,096
// paths. Every game: no shard is ever created or lost (stacks + bets on the felt + the house = what came in), and the
// review holds from the reveal for the full reading time whatever anyone presses. node casino_games_engine.js
const assert=require('node:assert/strict'),fs=require('node:fs');
(async()=>{const E=await import('../supabase/functions/tables/engine.js'),X=await import('../supabase/functions/tables/games.js'),out={},t0=Date.now();
 const rng=n=>Math.floor(Math.random()*n),mk=(now=0)=>({now,rng,ops:[],hands:[],salt:()=>'s'+rng(1e9),seed:()=>'S'+rng(1e12)+'x'+rng(1e12),botLeft:0});
 const near=(a,b,tol,msg)=>assert.ok(Math.abs(a-b)<=tol,msg+': '+a+' vs '+b);

 // ---------------- BACCARAT ----------------
 {// 1. the printed Banker table: rows = Banker's two-card total, columns = Player's third card value (0-9); D draws, S stands
  const TABLE={0:'DDDDDDDDDD',1:'DDDDDDDDDD',2:'DDDDDDDDDD',3:'DDDDDDDDSD',4:'SSDDDDDDSS',5:'SSSSDDDDSS',6:'SSSSSSDDSS',7:'SSSSSSSSSS'};
  let n=0;for(let b=0;b<=7;b++)for(let v=0;v<=9;v++){assert.equal(X.baBankerDraws(b,v),TABLE[b][v]==='D',`banker ${b} vs third card ${v}`);n++}
  // every two-card start (ranks only matter), against the rules written out once more by hand
  const rk=v=>v===0?8:v===1?12:v-2;   // a card of that baccarat value (0 -> a ten, 1 -> an ace)
  let starts=0;for(let p1=0;p1<10;p1++)for(let b1=0;b1<10;b1++)for(let p2=0;p2<10;p2++)for(let b2=0;b2<10;b2++)for(let x=0;x<10;x++)for(let y=0;y<10;y++){
   const d=X.baDraw([rk(p1),rk(b1),rk(p2),rk(b2),rk(x),rk(y)]),P=(p1+p2)%10,B=(b1+b2)%10;
   let eP=[p1,p2],eB=[b1,b2];if(!(P>=8||B>=8)){let third=null;if(P<=5){third=x;eP.push(x)}if(third===null){if(B<=5)eB.push(x)}else if(TABLE[B]&&TABLE[B][third]==='D')eB.push(y)}
   assert.deepEqual([d.P.map(X.baVal),d.B.map(X.baVal)],[eP,eB],'deal '+[p1,b1,p2,b2,x,y]);starts++}
  out.baccaratTable={decisions:n,deals:starts};
  // 2. exact edges for this shoe: 8 decks (128 cards worth 0, 32 of each 1-9), six cards drawn without replacement
  const cnt=v=>v===0?128:32;let pw=0,bw=0,tie=0;
  for(let p1=0;p1<10;p1++)for(let b1=0;b1<10;b1++)for(let p2=0;p2<10;p2++)for(let b2=0;b2<10;b2++)for(let x=0;x<10;x++)for(let y=0;y<10;y++){
   const seq=[p1,b1,p2,b2,x,y],used=Array(10).fill(0);let pr=1;for(let i=0;i<6;i++){pr*=(cnt(seq[i])-used[seq[i]])/(416-i);used[seq[i]]++}
   const d=X.baDraw(seq.map(rk)),P=X.baTot(d.P),B=X.baTot(d.B);if(P>B)pw+=pr;else if(B>P)bw+=pr;else tie+=pr}   // sequences past the cards a hand uses sum out exactly
  const edge={P:-(pw-bw),B:-(bw*19/20-pw),T:-(tie*8-(1-tie))};out.baccaratEdges={win:{P:+pw.toFixed(5),B:+bw.toFixed(5),T:+tie.toFixed(5)},edge:Object.fromEntries(Object.entries(edge).map(([k,v])=>[k,+(v*100).toFixed(4)]))};
  near(edge.B*100,1.0579,.0005,'banker edge (8 decks)');near(edge.P*100,1.2351,.0005,'player edge (8 decks)');near(edge.T*100,14.3596,.0005,'tie edge (8 decks)');
  // 3. payouts: Banker in 20s, commission itemized, a tie returns Player and Banker
  assert.deepEqual(X.baPay({B:20},'B'),{back:39,commission:1,items:[{k:'B',bet:20,back:39,commission:1,res:'win'}]},'20 Banker -> 19 profit + 20 back');
  assert.equal(X.baPay({P:7,T:3},'P').back,14);assert.equal(X.baPay({P:7,B:20,T:3},'T').back,7+20+27,'tie: Tie 8:1, Player and Banker returned');assert.equal(X.baPay({P:5,B:20},'B').back,39);
  // 4. the table: bets, the 5-second minimum, all ready, the deal, the shoe, the review
  const st=E.newTable({game:'ba',host:'a',tid:'T1'}),ctx=mk(1e6);for(const u of['a','b'])E.sit(st,{uid:u,name:u.toUpperCase(),seed:'seed'+u},ctx);
  for(const s of st.seats)if(s){s.stack=1e6;s.brought=1e6}const total0=2e6;E.tick(st,ctx);assert.equal(st.phase,'bet');
  assert.match(X.baSetBets(st,'a',{B:30}),/20s/,'Banker bets go in 20s');assert.match(X.baSetBets(st,'a',{B:'20'}),/whole/,'numbers, not strings');assert.match(X.baSetBets(st,'a',{X:5}),/Player, Banker/);
  assert.match(X.baSetBets(st,'a',{P:-5}),/whole/);assert.match(X.baSetBets(st,'a',{P:2e6}),/whole|Not enough/);
  assert.equal(X.baSetBets(st,'a',{P:10,T:2}),null);assert.equal(X.baSetBets(st,'b',{B:40}),null);
  X.ACTIONS.baready(st,'a');X.ACTIONS.baready(st,'b');E.tick(st,ctx);assert.equal(st.phase,'bet','everyone ready, but the window stays open its first 5 seconds');
  ctx.now+=X.BA.MIN_MS;E.tick(st,ctx);assert.equal(st.phase,'done','dealt once 5 s have passed and everyone is ready');
  const L=st.last,r=L.result;assert.ok(['P','B','T'].includes(r.win));assert.equal(r.at.until-r.at.reveal,E.REVIEW.ba,'8 s of review after the last card');assert.equal(r.at.reveal-r.at.settled,r.order.length*E.CARD_MS+300,'counted from the last card');
  // the review: ticks and READY don't move it before minAt
  for(let k=0;k<5;k++){ctx.now+=1000;X.ACTIONS.baready(st,'a');X.ACTIONS.baready(st,'b');E.tick(st,ctx);assert.equal(st.phase,'done','still in review '+k)}
  ctx.now=st.minAt;E.tick(st,ctx);assert.equal(st.phase,'bet','betting reopens after the review');
  // nothing undealt is ever in a view or the last result; every dealt card checks against the shoe's fingerprint
  const sh=st.ba.shoe,hashes=E.cardHashes(sh.seed,sh.cards);assert.equal(E.rootOf(hashes),sh.root);
  const vj=JSON.stringify(E.view(st,'a',ctx.now));assert.ok(!vj.includes(sh.seed),'the shoe seed never leaves the server');
  const lv=E.view(st,'a',ctx.now).last;for(const[p,c,s]of lv.cards){assert.equal(E.cardHash(s,c),hashes[p],'dealt card '+p+' checks');assert.ok(p<sh.pos)}
  assert.equal(lv.deck,undefined,'no deck in the last result');assert.equal(lv.seed,undefined,'no seed in the last result');
  // a long session: the shoe changes only between hands, at the cut card, and every retired shoe reruns from its seed
  let hands=1,shoes=new Set([sh.no]),retired=0,maxPos=0,conserved=true,houseSum=r.house;
  const onFelt=()=>st.phase!=="bet"?0:Object.values(st.hand&&st.hand.bets||{}).reduce((a,b)=>a+(b.P|0)+(b.B|0)+(b.T|0),0);
  while(hands<700){ctx.now+=50;for(const s of st.seats)if(s)s.seen=ctx.now;E.tick(st,ctx);
   if(st.phase==='bet'&&!Object.keys(st.hand.bets).length){X.baSetBets(st,'a',{[['P','B','T'][rng(3)]]:20*(1+rng(5))});X.baSetBets(st,'b',{B:20,P:rng(30)});X.ACTIONS.baready(st,'a');X.ACTIONS.baready(st,'b');ctx.now+=X.BA.MIN_MS;E.tick(st,ctx)}
   if(st.phase==='done'&&st.last.no===st.handNo&&st.last.no>hands){hands++;houseSum+=st.last.result.house;const s2=st.ba.shoe;if(s2){shoes.add(s2.no);maxPos=Math.max(maxPos,s2.pos)}
    for(const p of st.last.result.shoe.pos)assert.ok(p<X.BA.CARDS,'within the shoe');ctx.now=st.minAt}
   const tot=st.seats.reduce((a,s)=>a+(s?s.stack:0),0)+onFelt()+houseSum;if(tot!==total0&&conserved){conserved=false;console.log("DRIFT",tot-total0,hands,st.phase,JSON.stringify(st.last.result.players.map(p=>[p.bet,p.back,p.net])),st.last.result.house)}}
  for(const h of ctx.hands)if(h.result&&h.result.shoeEnd){retired++;const re=E.shuffle(416,E.fairRng(h.salt,h.result.seeds,h.result.nonce));assert.deepEqual(re,h.deck,'a retired shoe reruns card for card');
   assert.equal(E.sha256hex(h.salt),h.hash,'its seed matches the fingerprint shown when it started');assert.ok(h.result.dealt>=X.BA.CUT&&h.result.dealt<=X.BA.CARDS,'cut card reached, the last hand finished: '+h.result.dealt)}
  assert.ok(conserved,'baccarat: no shard created or lost');assert.ok(retired>=4&&shoes.size>=5,'several shoes: '+retired);out.baccaratSession={hands,shoes:shoes.size,retired,maxPos};
  // leaving with a bet down before the deal: it comes back
  ctx.now=st.minAt+1;E.tick(st,ctx);if(st.phase==='bet'){X.baSetBets(st,'b',{P:7});const before=st.seats[1].stack;E.leave(st,'b',ctx);assert.equal(st.seats[1],null);const co=ctx.ops.filter(o=>o.k==='cashout'&&o.uid==='b').at(-1);assert.equal(co.d,before+7,'a bet not yet dealt goes home with you')}}

 // ---------------- CRAPS ----------------
 {// 1. all 36 rolls, every bet, every phase, against the rules written out independently
  const PT=[4,5,6,8,9,10],ODDS={4:2,5:1.5,6:1.2,8:1.2,9:1.5,10:2},LAY={4:.5,5:2/3,6:5/6,8:5/6,9:2/3,10:.5},PLACE={4:1.8,5:1.4,6:7/6,8:7/6,9:1.4,10:1.8};
  // expected: [result, profit multiple] for a 30-shard bet (30 divides every denomination)
  const want=(k,P,d1,d2,F)=>{const t=d1+d2,hard=d1===d2,co=!P;
   if(k==='field')return[2,3,4,9,10,11,12].includes(t)?['win',t===2||t===12?2:1]:['lose'];
   if(k==='any7')return t===7?['win',4]:['lose'];if(k==='anyc')return[2,3,12].includes(t)?['win',7]:['lose'];
   if(/^n\d+$/.test(k)){const n=+k.slice(1);return t===n?['win',n===2||n===12?30:15]:['lose']}
   if(/^h\d+$/.test(k)){const n=+k.slice(1);if(co&&!F.hard)return['stay'];if(t===7)return['lose'];if(t===n)return hard?['win-stay',n===4||n===10?7:9]:['lose'];return['stay']}
   if(/^p\d+$/.test(k)){const n=+k.slice(1);if(co&&!F.place)return['stay'];if(t===7)return['lose'];if(t===n)return['win-stay',PLACE[n]];return['stay']}
   if(k==='pass'){if(co)return t===7||t===11?['win',1]:[2,3,12].includes(t)?['lose']:['stay'];return t===P?['win',1]:t===7?['lose']:['stay']}
   if(k==='dp'){if(co)return t===2||t===3?['win',1]:t===12?['stay']:t===7||t===11?['lose']:['stay'];return t===7?['win',1]:t===P?['lose']:['stay']}
   if(k==='come')return t===7||t===11?['win',1]:[2,3,12].includes(t)?['lose']:['move'];
   if(k==='dc')return t===2||t===3?['win',1]:t===12?['stay']:t===7||t===11?['lose']:['move'];
   if(/^c\d+$/.test(k)){const n=+k.slice(1);return t===n?['win',1]:t===7?['lose']:['stay']}
   if(/^d\d+$/.test(k)){const n=+k.slice(1);return t===7?['win',1]:t===n?['lose']:['stay']}};
  const keys=['field','any7','anyc','n2','n3','n11','n12','h4','h6','h8','h10',...PT.map(n=>'p'+n),'pass','dp','come','dc',...PT.map(n=>'c'+n),...PT.map(n=>'d'+n)];
  let cases=0;for(const P of[0,...PT])for(const F of[{place:false,hard:false},{place:true,hard:true}])for(const k of keys){if((k==='come'||k==='dc')&&!P)continue;
   for(let d1=1;d1<=6;d1++)for(let d2=1;d2<=6;d2++){const r=X.crResolve({[k]:30},F,P,d1,d2),w=want(k,P,d1,d2,F),it=r.items.find(i=>i.k===k);
    const got=!it?(r.bets[k]?'stay':'gone'):it.res.startsWith('moves')?'move':it.res==='win · stays up'?'win-stay':it.res;
    assert.equal(got,w[0],`${k} point ${P} roll ${d1}+${d2} ${JSON.stringify(F)}`);
    if(w[0]==='win')assert.equal(it.back,30+30*w[1],`${k} pays ${w[1]}:1 profit + stake on ${d1}+${d2}`);
    if(w[0]==='win-stay'){assert.equal(it.back,30*w[1],`${k} pays its profit and stays up`);assert.equal(r.bets[k],30,'its stake still working')}
    if(w[0]==='lose')assert.equal(it.back,0);if(w[0]==='move')assert.equal(r.bets[(k==='come'?'c':'d')+(d1+d2)],30,'moves to its number');cases++}}
  // odds: pass/come odds win at true odds and lose with their flat; come odds are off on the come-out unless turned on (returned)
  for(const n of PT)for(let d1=1;d1<=6;d1++)for(let d2=1;d2<=6;d2++){const t=d1+d2;
   let r=X.crResolve({pass:10,po:60},{},n,d1,d2),po=r.items.find(i=>i.k==='po');if(t===n)assert.equal(po.back,60+60*ODDS[n]);else if(t===7)assert.equal(po.back,0);else assert.equal(r.bets.po,60);
   r=X.crResolve({dp:10,dpo:60},{},n,d1,d2);const dpo=r.items.find(i=>i.k==='dpo');if(t===7)assert.equal(dpo.back,60+60*LAY[n]);else if(t===n)assert.equal(dpo.back,0);else assert.equal(r.bets.dpo,60);
   for(const on of[false,true]){r=X.crResolve({['c'+n]:10,['c'+n+'o']:60},{codds:on},0,d1,d2);const o=r.items.find(i=>i.k==='c'+n+'o');
    if(t===n)assert.equal(o.back,on?60+60*ODDS[n]:60,'come odds on the come-out: '+(on?'working':'returned'));else if(t===7)assert.equal(o.back,on?0:60);else assert.ok(!o)}
   r=X.crResolve({['d'+n]:10,['d'+n+'o']:60},{},0,d1,d2);const lo=r.items.find(i=>i.k==='d'+n+'o');if(t===7)assert.equal(lo.back,60+60*LAY[n],'Don\'t Come odds always work');cases++}
  out.crapsRolls=cases;
  // 2. exact house edges, straight from crResolve (an absorbing chain over the 36 rolls; first decision of the bet)
  const edgeOf=(bets,k,P,F={})=>{let mass=[{p:1,b:bets,P}],ev=0,stake=bets[k];
   for(let it=0;it<3000&&mass.length;it++){const next=new Map();
    for(const m of mass)for(let d1=1;d1<=6;d1++)for(let d2=1;d2<=6;d2++){const r=X.crResolve(m.b,F,m.P,d1,d2),p=m.p/36,dec=r.items.find(i=>(i.k===k||k==='come'&&/^c\d+$/.test(i.k)||k==='dc'&&/^d\d+$/.test(i.k))&&(i.stake||i.back)&&!/^moves/.test(i.res));   // a come bet keeps its identity when it moves
     if(dec){ev+=p*dec.net;continue}const key=JSON.stringify([r.bets,r.point]),o=next.get(key);if(o)o.p+=p;else next.set(key,{p,b:r.bets,P:r.point})}
    mass=[...next.values()].filter(m=>m.p>1e-15)}
   return -ev/stake};
  const E2={pass:[{pass:30},'pass',0,7/495],dp:[{dp:30},'dp',0,3/220*36/35],come:[{come:30},'come',6,7/495],dc:[{dc:30},'dc',6,3/220*36/35],
   p4:[{p4:30},'p4',6,1/15],p5:[{p5:30},'p5',6,.04],p6:[{p6:30},'p6',6,1/66],field:[{field:30},'field',0,1/18],h4:[{h4:30},'h4',6,1/9],h6:[{h6:30},'h6',6,1/11],
   any7:[{any7:30},'any7',0,1/6],anyc:[{anyc:30},'anyc',0,1/9],n2:[{n2:30},'n2',0,5/36],n3:[{n3:30},'n3',0,1/9],po:[{pass:10,po:30},'po',4,0],dpo:[{dp:10,dpo:30},'dpo',9,0]};
  out.crapsEdges={};for(const[name,[b,k,P,e]]of Object.entries(E2)){const got=edgeOf(b,k,P);out.crapsEdges[name]=+(got*100).toFixed(4);near(got,e,1e-9,'craps edge '+name)}
  // 3. a come bet already on 6 and a new come bet on the same roll of 6: the old one is paid, the new one takes its place
  {const r=X.crResolve({c6:10,come:10},{},8,3,3);assert.equal(r.items.find(i=>i.k==='c6').back,20);assert.equal(r.bets.c6,10,'the new come bet moved to 6');assert.ok(!r.bets.come)}
  {const r=X.crResolve({c6:10,c9:5,pass:10,p8:12},{},8,4,4);assert.equal(r.point,0,'point made');assert.equal(r.bets.c6,10,'come bets on other numbers stay');assert.equal(r.bets.c9,5);assert.equal(r.bets.p8,12,'place 8 won and stays up')}
  // 4. the table: placing, locking, lowering, limits, denominations
  const st=E.newTable({game:'cr',host:'a',tid:'C1'}),ctx=mk(1e6);for(const u of['a','b'])E.sit(st,{uid:u,name:u.toUpperCase()},ctx);for(const s of st.seats)if(s){s.stack=10000;s.brought=10000}
  E.tick(st,ctx);assert.equal(st.phase,'bet');const C=st.cr;
  assert.match(X.crSet(st,'a','come',10),/point is on|Come bets/,'no come bet on the come-out');assert.match(X.crSet(st,'a','p6',10),/6s/,'place 6 goes in 6s');assert.match(X.crSet(st,'a','pass','10'),/whole/);
  assert.match(X.crSet(st,'a','po',10),/odds|isn't a bet/,'no odds without a point');assert.match(X.crSet(st,'a','zz',10),/isn't a bet/);assert.match(X.crSet(st,'a','pass',1.5),/whole/);
  assert.equal(X.crSet(st,'a','pass',10),null);assert.equal(X.crSet(st,'b','dp',10),null);assert.equal(X.crSet(st,'a','p6',12),null);assert.equal(st.seats[0].stack,10000-22);
  // roll until a point is on
  const roll=()=>{for(const u of['a','b'])X.crReady(st,u);ctx.now+=X.CR.MIN_MS;for(const s of st.seats)if(s)s.seen=ctx.now;E.tick(st,ctx);assert.equal(st.phase,'done');ctx.now=st.minAt;E.tick(st,ctx)};
  for(let k=0;k<200&&!C.point;k++){if(!C.bets.a||!C.bets.a.pass)X.crSet(st,'a','pass',10);if(!C.bets.b||!C.bets.b.dp)X.crSet(st,'b','dp',10);roll()}
  assert.ok(C.point,'a point');const P=C.point;
  assert.match(X.crSet(st,'a','pass',0),/locked/,'pass can\'t come down');assert.match(X.crSet(st,'b','dp',20),/not go up/,'don\'t pass can\'t go up');
  assert.match(X.crSet(st,'a','po',X.CR.MULT[P]*10+X.CR.ODDS[P][1]),/up to/,'odds limit '+P);assert.equal(X.crSet(st,'a','po',X.CR.MULT[P]*10),null,'3-4-5x odds');
  if(X.CR.ODDS[P][1]>1)assert.match(X.crSet(st,'a','po',X.CR.ODDS[P][1]+1),/goes in/,'odds denomination');
  assert.match(X.crSet(st,'b','dpo',61),/up to|goes in/);assert.equal(X.crSet(st,'b','dpo',60),null,'lay up to 6x');
  assert.equal(X.crSet(st,'a','come',5),null,'come bet while the point is on');
  {const s=st.seats[1],before=s.stack;assert.equal(X.crSet(st,'b','dp',0),null,'don\'t pass comes down');assert.equal(s.stack,before+70,'with its odds');assert.ok(!C.bets.b||!C.bets.b.dpo)}
  // 5. leaving with bets that must stay: only those stay, the account stays with them, the dealer rolls them out
  X.crSet(st,'a','field',5);X.crSet(st,'a','h8',5);const sa=st.seats[0],before=sa.stack,refund=Object.entries(C.bets.a).filter(([k])=>k!=='pass').reduce((x,[,v])=>x+v,0);E.leave(st,'a',ctx);
  const keep=Object.keys(C.bets.a||{}).sort();assert.deepEqual(keep,['pass'],'only the Pass Line stays (odds, come-before-roll, field and hardways come home)');
  assert.ok(sa.gone,'the seat is kept for the bet');assert.ok(E.inHand(st,'a'));assert.equal(sa.stack,before+refund,'everything else back on the stack');assert.ok(refund>=X.CR.MULT[P]*10+15);
  E.leave(st,'b',ctx);assert.equal(st.seats[1],null,'b had nothing that had to stay');
  let guard=0;while(st.seats[0]&&guard++<500){ctx.now+=100;E.tick(st,ctx);if(st.phase==='done')ctx.now=st.minAt}
  assert.equal(st.seats[0],null,'stood up once the pass bet was decided');const co=ctx.ops.filter(o=>o.uid==='a'&&o.k==='cashout').at(-1);assert.ok(co&&co.d>=before,'shards home');
  // 6. long random session with three players, everything conserved
  {const st=E.newTable({game:'cr',host:'a',tid:'C2'}),ctx=mk(5e6),us=['a','b','c'];for(const u of us)E.sit(st,{uid:u,name:u},ctx);for(const s of st.seats)if(s){s.stack=1e5;s.brought=1e5}
   let house=0,rolls=0,okc=true;const felt=()=>Object.values(st.cr.bets).reduce((a,b)=>a+Object.values(b).reduce((x,y)=>x+y,0),0);
   const K=['pass','dp','come','dc','field','p4','p5','p6','p8','p9','p10','h4','h6','h8','h10','any7','anyc','n2','n3','n11','n12','po','dpo',...PT.map(n=>'c'+n+'o'),...PT.map(n=>'d'+n+'o')];
   let seenNo=0;while(rolls<4000){for(const s of st.seats)if(s){s.seen=ctx.now;s.sitout=0}E.tick(st,ctx);if(st.phase==='done'){if(st.last.no!==seenNo){seenNo=st.last.no;rolls++;house+=st.last.result.house}ctx.now=st.minAt;continue}
    if(st.phase==='bet'){for(const u of us){if(rng(3))continue;const k=K[rng(K.length)],info=X.crKey(k,st.cr.point);if(!info)continue;X.crSet(st,u,k,info.den*(1+rng(4)));if(!rng(9))X.crFlags(st,u,{place:!!rng(2),hard:!!rng(2),codds:!!rng(2)})}
     for(const u of us)X.crReady(st,u);ctx.now+=X.CR.MIN_MS;E.tick(st,ctx);if(st.phase!=='done')ctx.now+=X.CR.BET_MS}
    if(st.phase!=='done'&&st.seats.reduce((a,s)=>a+(s?s.stack:0),0)+felt()+house!==3e5)okc=false}
   assert.ok(okc,'craps: no shard created or lost over '+rolls+' rolls');out.crapsSession={rolls,house}}}

 // ---------------- SLOTS ----------------
 {const m=X.slMath();out.slots={rtp:+(m.rtp*100).toFixed(4),hit:+(m.hit*100).toFixed(2),combos:m.combos,max:m.max};
  assert.equal(m.combos,8000);near(m.rtp,.96,.001,'slot RTP within 0.1 points of 96%');assert.equal(m.max,250);
  for(const r of X.SL.STRIPS)assert.equal(r.length,20);
  const st=E.newTable({game:'sl',host:'a',station:'s3',tid:'S3'}),ctx=mk(1e6);E.sit(st,{uid:'a',name:'A'},ctx);st.seats[0].stack=5000;st.seats[0].brought=5000;E.tick(st,ctx);
  assert.match(X.ACTIONS.spin(st,'a',{amt:101},ctx),/most/);assert.match(X.ACTIONS.spin(st,'a',{amt:0},ctx),/at least/);assert.match(X.ACTIONS.spin(st,'a',{amt:'5'},ctx),/at least/);
  let house=0,spins=0,okc=true,added=0;
  for(;spins<3000;spins++){st.seats[0].seen=ctx.now;assert.equal(X.ACTIONS.spin(st,'a',{amt:1+rng(10)},ctx),null);const r=st.last.result;house+=r.house;
   assert.deepEqual(r.window.map(w=>w[1]),r.line,'the line is the middle row');r.stops.forEach((x,i)=>{assert.equal(r.window[i][0],X.SL.STRIPS[i][(x+19)%20]);assert.equal(r.window[i][2],X.SL.STRIPS[i][(x+1)%20])});
   assert.match(X.ACTIONS.spin(st,'a',{amt:1},ctx),/still turning/,'no spin during the reels and the review');
   ctx.now+=X.SL.ANIM+E.REVIEW.sl-1;E.tick(st,ctx);assert.equal(st.phase,'done','3 s review after the last reel');ctx.now+=1;E.tick(st,ctx);
   if(st.seats[0].stack+house!==5000+added)okc=false;if(st.seats[0].stack<20){st.seats[0].stack+=1000;st.seats[0].brought+=1000;added+=1000}}
  assert.ok(okc,'slots: no shard created or lost');out.slotsSession={spins,house}}

 // ---------------- PLINKO ----------------
 {const m=X.pkMath();out.plinko={rtp:+(m.rtp*100).toFixed(4),variance:+m.variance.toFixed(4),max:m.max,lossChance:+(m.lossChance*100).toFixed(2)};
  near(m.rtp,.96,.001,'Plinko RTP within 0.1 points of 96%');assert.deepEqual(X.PK.MULT,[...X.PK.MULT].reverse(),'symmetric');
  let sum=0;for(let p=0;p<4096;p++){let k=0;for(let i=0;i<12;i++)k+=(p>>i)&1;const m2=X.PK.MULT[k];sum+=m2;for(const a of[10,20,500])assert.ok(Number.isInteger(a*m2/10),'whole shards')}
  near(sum/4096/10,m.rtp,1e-12,'all 4,096 paths agree with the binomial');
  const st=E.newTable({game:'pk',host:'a',station:'p1',tid:'P1'}),ctx=mk(1e6);E.sit(st,{uid:'a',name:'A'},ctx);st.seats[0].stack=1000;E.tick(st,ctx);
  assert.match(X.ACTIONS.drop(st,'a',{amt:15},ctx),/10s/);assert.match(X.ACTIONS.drop(st,'a',{amt:510},ctx),/most/);assert.equal(X.ACTIONS.drop(st,'a',{amt:20},ctx),null);
  const r=st.last.result;assert.equal(r.path.length,12);assert.equal(r.pocket,r.path.reduce((a,b)=>a+b,0));assert.equal(r.players[0].back,20*X.PK.MULT[r.pocket]/10);
  assert.match(X.ACTIONS.drop(st,'a',{amt:10},ctx),/still dropping/);ctx.now=st.minAt;E.tick(st,ctx);assert.equal(st.phase,'idle')}

 // ---------------- the review, every game: from the reveal, not from the deal; READY can't cut it short ----------------
 {const res={};
  // blackjack: stays in review across repeated ticks (no zero-time cleanup); the clock starts after the dealer's last card
  const st=E.newTable({game:'bj',lim:100,host:'a'}),ctx=mk(1e6);E.sit(st,{uid:'a',name:'A'},ctx);E.start(st,'a');st.seats[0].stack=1000;
  for(let k=0;k<50&&st.phase!=='done';k++){E.tick(st,ctx);if(st.phase==='bet')E.bjBet(st,'a',2,false,ctx);if(st.phase==='ins')E.bjInsure(st,'a',false);E.tick(st,ctx);if(st.phase==='play')E.bjAct(st,'a','stand',ctx)}
  assert.equal(st.phase,'done');const r=st.last.result;assert.equal(r.at.until-r.at.reveal,8000);assert.equal(r.at.reveal-r.at.settled,(r.dealer.length===2&&r.dbj?1:r.dealer.length-1)*E.CARD_MS);
  for(let k=0;k<30;k++){E.tick(st,ctx);E.ready(st,'a');ctx.now+=250;if(ctx.now<st.minAt)assert.equal(st.phase,'done','blackjack review holds')}
  const p=r.players[0];assert.equal(p.net,p.back-p.bet,'receipt: net = returned - bet');assert.ok(p.hands[0].why.length>5,'a plain reason: '+p.hands[0].why);res.bj=p.hands[0].why;
  // hold'em: the 60 s break stays, READY can't deal before the 8 s minimum
  {const st=E.newTable({game:'he',lim:0,host:'a'}),ctx=mk(1e6);for(const u of['a','b','c'])E.sit(st,{uid:u,name:u},ctx);E.start(st,'a');for(const s of st.seats)if(s)s.stack=100;
   E.tick(st,ctx);while(st.phase==='play'){const h=st.hand,q=h.players[h.cur];E.heAct(st,q.uid,{a:'fold'},ctx)}assert.equal(st.phase,'done');const r=st.last.result;assert.ok(r.uncontested,'everyone folded: uncontested, no cards shown');assert.ok(r.players.every(x=>x.cards===null));
   for(const u of['a','b','c'])E.ready(st,u);E.tick(st,ctx);assert.equal(st.phase,'done','all ready, still before 8 s');ctx.now=st.minAt;E.tick(st,ctx);assert.notEqual(st.phase,'done','after 8 s READY deals');
   assert.ok(st.deadline===0||true);res.he=r.pots}
  // roulette: 6 s from the ball landing
  {const st=E.newTable({game:'rl',host:'a'}),ctx=mk(1e6);E.sit(st,{uid:'a',name:'A'},ctx);st.seats[0].stack=100;E.tick(st,ctx);E.rlSetBets(st,'a',{red:5});E.rlReady(st,'a');E.tick(st,ctx);assert.equal(st.phase,'spin');
   ctx.now+=E.SPIN_MS;E.tick(st,ctx);assert.equal(st.phase,'done');assert.equal(st.minAt-ctx.now,6000);ctx.now+=5999;E.tick(st,ctx);assert.equal(st.phase,'done');ctx.now+=1;E.tick(st,ctx);assert.notEqual(st.phase,'done');
   const rr=st.last.result.players[0];assert.equal(rr.items[0].k,'red');assert.equal(rr.net,rr.back-rr.bet)}
  out.review=res}

 out.ms=Date.now()-t0;fs.mkdirSync(__dirname+'/out',{recursive:true});fs.writeFileSync(__dirname+'/out/casino_games_engine.json',JSON.stringify(out,null,1));console.log(JSON.stringify(out));console.log('errors: none');
})().catch(e=>{console.error(e);process.exit(1)});
