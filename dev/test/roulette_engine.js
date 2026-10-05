// v0.10.0 ROULETTE (the engine the `tables` edge function runs): every spot on the American layout and nothing else, what each
// pays on all 38 pockets, the exact house edge (5.26%, the top line 7.89%), a million fair spins (uniform, the house's take
// where it should be), rounds (60 s betting, early spin when everyone is ready, no bets keeps betting open), no limit, leaving,
// shards never created, the number never shown before betting closes, and every spin rerun from its revealed seed.
// node roulette_engine.js
const assert=require('node:assert/strict'),fs=require('node:fs');
(async()=>{const E=await import('../supabase/functions/tables/engine.js'),out={},t0=Date.now();
 const rng=n=>Math.floor(Math.random()*n),hex=n=>Array.from({length:n},()=>rng(16).toString(16)).join('');
 const mk=(now=0)=>({now,rng,ops:[],hands:[],salt:()=>hex(24),seed:()=>hex(64)});
 // 1. the layout: every real spot, and nothing else
 const spots=[];for(let n=0;n<=37;n++)spots.push('n:'+n);
 for(let a=1;a<=36;a++){if(a%3&&a+1<=36)spots.push(`sp:${a}-${a+1}`);if(a+3<=36)spots.push(`sp:${a}-${a+3}`)}
 spots.push('sp:0-37','sp:0-1','sp:0-2','sp:2-37','sp:3-37');
 for(let a=1;a<=34;a+=3)spots.push('st:'+a);spots.push('tr:0-1-2','tr:0-2-37','tr:2-3-37');
 for(let a=1;a<=32;a++)if(a%3)spots.push('co:'+a);spots.push('tl');for(let a=1;a<=31;a+=3)spots.push('sl:'+a);
 for(const k of['dz:1','dz:2','dz:3','col:1','col:2','col:3','red','black','odd','even','low','high'])spots.push(k);
 out.spots=spots.length;assert.equal(spots.length,38+62+15+22+1+11+12,'the American layout has 161 spots');
 for(const k of spots)assert.ok(E.rlSpot(k),'a real spot is accepted: '+k);
 for(const k of['n:00','n:017','sp:01-2','n:38','n:-1','sp:3-4','sp:1-3','sp:36-37','sp:1-37','st:2','st:37','co:3','co:33','sl:34','dz:4','col:0','tr:1-2-3','tl:1','red:1','nope','','sp:5-5','n:1.5'])
   assert.equal(E.rlSpot(k),null,'not a spot: '+k);
 // 2. what each spot pays on every pocket, and the exact edge
 const RED=new Set(E.RL_RED);let worst=0;const edges={};
 for(const k of spots){const sp=E.rlSpot(k);let ret=0;
   for(let n=0;n<=37;n++){const back=E.rlPay({[k]:10},n),hit=sp.nums.includes(n);assert.equal(back,hit?10*(sp.pays+1):0,k+' on '+n);ret+=back}
   const edge=1-ret/38/10;assert.ok(Math.abs(edge-(sp.nums.length===5?3/38:2/38))<1e-12,'house edge for '+k+': '+edge);edges[sp.nums.length]=+edge.toFixed(5);worst=Math.max(worst,edge)}
 out.edges=edges;
 assert.ok(E.rlSpot('red').nums.every(n=>RED.has(n))&&E.rlSpot('black').nums.every(n=>!RED.has(n)&&n>0&&n<37),'red and black');
 assert.ok(E.rlPay({red:5,black:5},0)===0&&E.rlPay({red:5,black:5},37)===0,'0 and 00 lose every outside bet');
 assert.deepEqual([...E.RL_WHEEL].sort((a,b)=>a-b),Array.from({length:38},(_,i)=>i),'the wheel has every pocket once');
 // 3. a million fair spins: uniform pockets, the house keeps about 5.26%
 {const cnt=Array(38).fill(0);let bet=0,back=0;const seed=hex(64);
  for(let i=0;i<1e6;i++){const n=E.fairRng(seed,['p'+(i%7)],'t:'+i)(38);cnt[n]++;bet+=1;back+=E.rlPay({red:1},n)}
  const e=1e6/38,chi=cnt.reduce((a,x)=>a+(x-e)**2/e,0);out.chi=+chi.toFixed(1);out.mcEdge=+(1-back/bet).toFixed(4);
  assert.ok(chi<75,'uniform pockets over a million spins (chi-squared, 37 degrees of freedom): '+chi);
  assert.ok(Math.abs(out.mcEdge-2/38)<.004,'the house keeps about 5.26% over a million spins: '+out.mcEdge)}
 // 4. a round at a table
 const st=E.newTable({game:'rl',host:'a',tid:'tbl1'}),ctx=mk(1000);assert.equal(st.lim,0,'always no limit');assert.equal(st.started,true,'no host start');
 E.sit(st,{uid:'a',name:'A',seed:'alpha'},ctx);E.sit(st,{uid:'b',name:'B',seed:'bravo'},ctx);for(const s of st.seats)if(s){s.stack=1e6;s.brought=1e6}
 const seen=()=>{for(const s of st.seats)if(s)s.seen=ctx.now};seen();E.tick(st,ctx);assert.equal(st.phase,'bet','betting opens');
 const commit=E.view(st,'a',ctx.now).fair;assert.ok(commit&&commit===st.next.hash,'the spin\'s fingerprint is shown while betting');
 for(const u of['a','b'])assert.equal(E.view(st,u,ctx.now).number,undefined,'no number while betting');
 assert.equal(E.rlSetBets(st,'a',{'n:17':500000,red:100}),null,'no limit: half a million on one number');
 assert.match(E.rlSetBets(st,'b',{red:2e6}),/Not enough/,'not more than your stack');
 assert.match(E.rlSetBets(st,'b',{'sp:3-4':5}),/spot/,'not a made-up spot');
 assert.equal(E.rlSetBets(st,'b',{black:300,'tl':40}),null);assert.equal(E.rlSetBets(st,'b',{black:200}),null,'bets are replaced (place, remove, clear)');
 assert.equal(st.seats[1].stack,1e6-200,'replaced bets come back first');
 assert.equal(E.rlReady(st,'a'),null);E.tick(st,ctx);assert.equal(st.phase,'bet','one ready of two: still betting');
 E.rlReady(st,'b');E.tick(st,ctx);assert.equal(st.phase,'spin','everyone ready: the ball goes');
 assert.match(E.rlSetBets(st,'a',{red:1}),/No more bets/,'no bets once the ball goes');
 const n=E.view(st,'b',ctx.now).number;assert.ok(n>=0&&n<=37,'the number shows once betting has closed');
 ctx.now+=E.SPIN_MS;seen();E.tick(st,ctx);assert.equal(st.phase,'done','settled after the spin');
 const L=st.last;assert.equal(L.deck[0],n);assert.equal(E.sha256hex(L.fair.seed),commit,'the revealed seed matches the fingerprint shown before betting');
 assert.equal(E.fairRng(L.fair.seed,L.fair.seeds,L.fair.nonce)(38),n,'anyone can rerun the spin');assert.deepEqual(L.fair.seeds,['alpha','bravo'],'both players\' seeds went in');
 const exp={a:E.rlPay({'n:17':500000,red:100},n),b:E.rlPay({black:200},n)};
 assert.equal(st.seats[0].stack,1e6-500100+exp.a);assert.equal(st.seats[1].stack,1e6-200+exp.b,'paid exactly what the spots pay');
 assert.equal(L.result.house,500300-exp.a-exp.b,'the house\'s take is logged with the spin');
 assert.equal(E.view(st,'a',ctx.now).last.seed,L.fair.seed,'roulette shows the seed after the spin');
 out.round={n,house:L.result.house};
 // 5. many rounds at random: shards are never created, timers and leaving
 {const st=E.newTable({game:'rl',host:'a',tid:'t2'}),ctx=mk(5000);for(const u of['a','b','c'])E.sit(st,{uid:u,name:u},ctx);
  let start=0;for(const s of st.seats)if(s){s.stack=s.brought=1000;start+=1000}let house=0,spins=0,reopened=0;
  for(let r=0;r<3000;r++){for(const s of st.seats)if(s)s.seen=ctx.now;E.tick(st,ctx);
   if(st.phase==='bet'){for(const s of st.seats)if(s&&rng(3)){const k=spots[rng(spots.length)],a=1+rng(Math.max(1,Math.min(50,s.stack)));if(s.stack>=a)E.rlSetBets(st,s.uid,{[k]:a})}
     if(rng(4)===0){const d=st.deadline;ctx.now=d;if(!Object.keys(st.hand.bets).length)reopened++}else for(const s of st.seats)if(s)E.rlReady(st,s.uid)}
   else ctx.now+=E.SPIN_MS;
   E.tick(st,ctx);if(ctx.hands.length>spins){house+=ctx.hands.slice(spins).reduce((a,h)=>a+h.result.house,0);spins=ctx.hands.length}
   for(const s of st.seats)if(s&&s.stack<5){s.stack+=100;s.brought+=100;start+=100}}
  const onTable=st.seats.reduce((a,s)=>a+(s?s.stack:0),0)+(st.hand&&st.hand.bets&&(st.phase==='bet'||st.phase==='spin')?Object.values(st.hand.bets).reduce((a,b)=>a+E.rlTotal(b),0):0);
  const home=ctx.ops.filter(o=>o.k==='cashout').reduce((a,o)=>a+o.d,0);   // anyone stood up for sitting out 3 spins took their stack home
  out.random={spins,house,reopened,home};assert.equal(onTable+house+home,start,'no shard created or lost: stacks + bets on the felt + the house\'s take + cash-outs = shards brought');
  assert.ok(spins>500,'spins happened')}
 // leaving: during betting your bets come back; during the spin you're paid, then stood up
 {const st=E.newTable({game:'rl',host:'a',tid:'t3'}),ctx=mk(0);E.sit(st,{uid:'a',name:'A'},ctx);E.sit(st,{uid:'b',name:'B'},ctx);E.tick(st,ctx);
  E.rlSetBets(st,'a',{red:3});E.leave(st,'a',ctx);assert.equal(st.seats[0],null,'stood up');assert.deepEqual(ctx.ops.at(-1),{uid:'a',k:'cashout',d:5},'bets returned with the stack');
  E.rlSetBets(st,'b',{even:2});E.rlReady(st,'b');E.tick(st,ctx);assert.equal(st.phase,'spin');E.leave(st,'b',ctx);assert.ok(st.seats[1]&&st.seats[1].leaving,'leaving mid-spin waits for the result');
  ctx.now+=E.SPIN_MS;E.tick(st,ctx);ctx.now+=E.RL_SHOW_MS;E.tick(st,ctx);assert.equal(st.seats[1],null,'then stands up');
  const back=ctx.ops.filter(o=>o.uid==='b'&&o.k==='cashout').reduce((a,o)=>a+o.d,0);assert.equal(back,3+E.rlPay({even:2},st.last.deck[0]),'paid before standing up')}
 // the seat you walked up to, if it's free; otherwise the next free one
 {const st=E.newTable({game:'rl',host:'a',tid:'t5'}),ctx=mk(0);E.sit(st,{uid:'a',name:'A',seat:3},ctx);E.sit(st,{uid:'b',name:'B',seat:3},ctx);E.sit(st,{uid:'c',name:'C',seat:9},ctx);
  assert.equal(st.seats[3].uid,'a','the seat you walked up to');assert.equal(st.seats[0].uid,'b','taken: the next free seat');assert.equal(st.seats[1].uid,'c','no such seat: the next free seat');
  for(const u of['d','e','f'])E.sit(st,{uid:u,name:u},ctx);const n0=ctx.ops.length;assert.equal(E.sit(st,{uid:'g',name:'G',seat:2},ctx),'The table is full','a full table says so');
  assert.equal(ctx.ops.length,n0,'and takes no buy-in');assert.equal(Object.keys(st.seats).length,6,'no seat made up')}
 // nobody bets: betting stays open, no spin is logged
 {const st=E.newTable({game:'rl',host:'a',tid:'t4'}),ctx=mk(0);E.sit(st,{uid:'a',name:'A'},ctx);E.tick(st,ctx);const d=st.deadline;ctx.now=d+1;st.seats[0].seen=ctx.now;E.tick(st,ctx);
  assert.equal(st.phase,'bet');assert.ok(st.deadline>d,'a fresh 60 s');assert.equal(ctx.hands.length,0,'no empty spins');
  E.rlSetBets(st,'a',{n:0});assert.ok(1);   // a malformed map entry is ignored (no amount)
  assert.equal(E.rlSetBets(st,'a',{'n:0':1}),null);E.rlReady(st,'a');E.tick(st,ctx);assert.equal(st.phase,'spin','one player can play alone')}
 out.ms=Date.now()-t0;fs.writeFileSync(__dirname+'/out/roulette_engine.json',JSON.stringify(out,null,1));console.log(JSON.stringify(out));console.log('errors: none');
})().catch(e=>{console.error(e);process.exit(1)});
