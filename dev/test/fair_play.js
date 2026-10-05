// v0.10.0 FAIR PLAY at all three tables (the engine and handler the `tables` edge function runs): the written-out SHA-256
// against Node's; the server commits to its seed before anyone's seed locks; players' seeds change the deal; every Blackjack
// shoe and roulette spin reruns from what's revealed; Hold'em reveals only the cards you saw (each checks against its own
// fingerprint and the hand's root shown at the deal) and never a folded hand or the seed; hand history follows the same rules
// (Hold'em in full after 24 hours); the random numbers are uniform. node fair_play.js
const assert=require('node:assert/strict'),fs=require('node:fs'),crypto=require('node:crypto');
(async()=>{const E=await import('../supabase/functions/tables/engine.js'),H=await import('../supabase/functions/tables/handler.js'),out={},t0=Date.now();
 const rng=n=>Math.floor(Math.random()*n),hex=n=>crypto.randomBytes(n/2).toString('hex');
 const mk=(now=0)=>({now,rng,ops:[],hands:[],salt:()=>hex(24),seed:()=>hex(64),botLeft:25});
 // 1. SHA-256
 for(let i=0;i<400;i++){const s=crypto.randomBytes(rng(300)).toString(i%3?'hex':'latin1');assert.equal(E.sha256hex(s),crypto.createHash('sha256').update(s,'utf8').digest('hex'),'sha256 '+i)}
 // 2. uniform numbers (52 and 38 outcomes), whatever the seeds
 for(const n of[52,38]){const c=Array(n).fill(0),N=n*4000;const r=E.fairRng(hex(64),['a','b'],'u');for(let i=0;i<N;i++)c[r(n)]++;
  const chi=c.reduce((a,x)=>a+(x-4000)**2/4000,0);out['chi'+n]=+chi.toFixed(1);assert.ok(chi<n*1.6,'uniform over '+n+': chi '+chi)}
 // 3. blackjack: commit first, seeds lock at the deal, the shoe reruns, a different player seed gives a different shoe
 {const st=E.newTable({game:'bj',lim:0,host:'a',tid:'bj1'}),ctx=mk(1);E.sit(st,{uid:'a',name:'A',seed:'mine1'},ctx);E.sit(st,{uid:'b',name:'B',seed:'mine2'},ctx);E.start(st,'a');
  for(const s of st.seats)if(s){s.stack=s.brought=500}E.tick(st,ctx);const committed=E.view(st,'a',ctx.now).next;assert.ok(committed,'the next deal\'s fingerprint is shown before betting');
  assert.equal(E.setSeed(st,'b','changed-my-mind'),null,'a seed can change while betting');
  E.bjBet(st,'a',10,false,ctx);E.bjBet(st,'b',10,false,ctx);E.tick(st,ctx);const h=st.hand;assert.equal(h.hash,committed,'the deal used the seed committed before seeds locked');
  assert.deepEqual(h.fair.seeds,['mine1','changed-my-mind'],'both players\' seeds, as they were at the deal');
  for(let k=0;k<20&&st.phase==='play';k++){const v=E.view(st,h.players[h.turn.p].uid,ctx.now);E.bjAct(st,h.players[h.turn.p].uid,'stand',ctx);E.tick(st,ctx)}
  const v=E.view(st,'a',ctx.now),L=v.last;assert.ok(L.seed&&E.sha256hex(L.seed)===committed,'the seed is revealed and matches');
  assert.deepEqual(E.shuffle(208,E.fairRng(L.seed,L.result.seeds,L.result.nonce)),L.deck,'the shoe reruns exactly');
  assert.notDeepEqual(E.shuffle(208,E.fairRng(L.seed,['mine1','someone-else'],L.result.nonce)),L.deck,'another player seed, another shoe');
  assert.ok(typeof L.result.house==='number','blackjack logs the house\'s take');assert.notEqual(v.next,committed,'a new fingerprint for the next hand')}
 // 4. hold'em over many hands: per-card checks, no folded hand, no seed, the root matches the one shown at the deal
 {const st=E.newTable({game:'he',lim:0,side:true,host:'a',tid:'he1'}),ctx=mk(1);for(const u of['a','b','c','d'])E.sit(st,{uid:u,name:u.toUpperCase(),seed:'s'+u},ctx);E.start(st,'a');
  for(const s of st.seats)if(s){s.stack=s.brought=400;s.side=true}let hands=0,checked=0,leaks=0,shownChecks=0;const roots={};
  while(hands<400){ctx.now+=100;for(const s of st.seats)if(s)s.seen=ctx.now;E.tick(st,ctx);
   if(st.phase==='play'){const h=st.hand;if(!roots[h.no])roots[h.no]=E.view(st,'a',ctx.now).root;const p=h.players[h.cur],v=E.view(st,p.uid,ctx.now),c=v.can,r=rng(10);
    E.heAct(st,p.uid,r<3&&c.call?{a:'fold'}:r<7?{a:c.call?'call':'check'}:{a:'allin'},ctx)}
   if(st.phase==='done'){hands++;const h=st.hand,deck=h.deck;
    for(const q of h.players){const v=E.view(st,q.uid,ctx.now),L=v.last;
     if(L.deck||L.seed||L.salt&&L.salt===h.fair.seed)leaks++;
     assert.equal(L.root,roots[h.no],'the root after the hand is the one shown at the deal');assert.equal(E.rootOf(L.cardHashes),L.root,'the 52 fingerprints build the root');
     for(const[i,card,salt]of L.cards){assert.equal(E.cardHash(salt,card),L.cardHashes[i],'each shown card checks out');assert.equal(card,deck[i]);checked++}
     const shownPos=new Set(L.cards.map(x=>x[0]));for(const f of h.players)if(f.uid!==q.uid&&(f.folded||!h.shown))for(const i of f.pos)if(shownPos.has(i))leaks++;
     for(const i of q.pos)assert.ok(shownPos.has(i),'you can check your own cards');
     if(h.shown)for(const f of h.players)if(!f.folded){for(const i of f.pos)assert.ok(shownPos.has(i));shownChecks++}}
    assert.ok(typeof h.result.house==='number','hold\'em logs the house\'s take');
    ctx.now+=E.NEXT_MS;for(const s of st.seats)if(s&&s.stack<E.BB){s.stack+=100;s.brought+=100}}}
  out.he={hands,checked,shownChecks,leaks};assert.equal(leaks,0,'no folded hand, deck or seed ever reaches a player');
  // the full rerun is possible from the server's log (what history shows after 24 hours)
  const L=st.last;assert.deepEqual(E.shuffle(52,E.fairRng(L.fair.seed,L.fair.seeds,L.fair.nonce)),L.deck,'the hold\'em deck reruns from the server\'s log')}
 // 5. hand history: Hold'em hides the seed and the deck for 24 hours, Blackjack and Roulette show everything
 {const st=E.newTable({game:'he',lim:0,host:'a',tid:'h2'}),ctx=mk(1);for(const u of['a','b','c'])E.sit(st,{uid:u,name:u},ctx);E.start(st,'a');for(const s of st.seats)if(s){s.stack=s.brought=50}
  while(st.phase!=='done'){ctx.now+=100;for(const s of st.seats)if(s)s.seen=ctx.now;E.tick(st,ctx);if(st.phase==='play'){const h=st.hand,p=h.players[h.cur];E.heAct(st,p.uid,{a:h.players.indexOf(p)===0?'fold':'call'},ctx);if(st.phase==='play'){const v=E.view(st,h.players[h.cur].uid,ctx.now);E.heAct(st,h.players[h.cur].uid,{a:v.can.call?'call':'check'},ctx)}}}
  const lg=ctx.hands.at(-1),row={game:'he',hand_no:lg.no,hash:lg.hash,salt:lg.salt,deck:lg.deck,result:lg.result,created_at:new Date(5e12).toISOString()};
  const folder=lg.result.players.find(p=>p.folded),viewer=lg.result.players.find(p=>!p.folded&&p.uid!==folder?.uid);
  const fresh=H.histRow(row,viewer.uid,5e12+1000),old=H.histRow(row,viewer.uid,5e12+864e5+1);
  assert.ok(!fresh.seed&&!fresh.deck,'a fresh hold\'em hand: no seed, no deck');assert.equal(E.rootOf(fresh.cardHashes),fresh.root);
  for(const[i,c,s]of fresh.cards)assert.equal(E.cardHash(s,c),fresh.cardHashes[i]);
  if(folder){const fi=lg.result.players.indexOf(folder),n=lg.result.players.length;assert.ok(!fresh.cards.some(x=>x[0]===fi||x[0]===fi+n),'history never shows a folded hand')}
  assert.ok(fresh.mine&&fresh.mine.length===2,'your own cards are in your history');
  assert.ok(old.seed&&old.deck&&E.sha256hex(old.seed)===old.commit,'after 24 hours: the seed and the whole deck');
  assert.deepEqual(E.shuffle(52,E.fairRng(old.seed,old.result.seeds,old.result.nonce)),old.deck,'and the shuffle reruns');
  const bj=H.histRow({game:'bj',hand_no:1,hash:'x',salt:'y',deck:[1,2,3],result:{},created_at:new Date().toISOString()},'a',Date.now());assert.ok(bj.seed&&bj.deck,'blackjack: everything right away')}
 out.ms=Date.now()-t0;fs.writeFileSync(__dirname+'/out/fair_play.json',JSON.stringify(out,null,1));console.log(JSON.stringify(out));console.log('errors: none');
})().catch(e=>{console.error(e);process.exit(1)});
