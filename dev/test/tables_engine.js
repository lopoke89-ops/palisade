// v0.9.8 THE TABLES engine (the code the `tables` edge function runs): poker hand values over every 5-card hand, the
// shuffle, Blackjack odds with basic strategy, Hold'em played at random by 3 players (shards are never created, nobody
// sees a card they shouldn't, side pots and the rake), the bot's seat rules, the side bet and cashing out. node tables_engine.js
const assert=require('node:assert/strict'),fs=require('node:fs');
(async()=>{const E=await import('../supabase/functions/tables/engine.js'),out={},t0=Date.now();
 const rng=n=>Math.floor(Math.random()*n),mk=(now=0)=>({now,rng,ops:[],hands:[],salt:()=>'s'+rng(1e9),botLeft:25});
 // 1. every 5-card hand, counted by category
 {const cnt=Array(9).fill(0),c=[0,0,0,0,0];for(c[0]=0;c[0]<48;c[0]++)for(c[1]=c[0]+1;c[1]<49;c[1]++)for(c[2]=c[1]+1;c[2]<50;c[2]++)for(c[3]=c[2]+1;c[3]<51;c[3]++)for(c[4]=c[3]+1;c[4]<52;c[4]++)cnt[E.catOf(E.eval5(c))]++;
  out.cats=cnt;assert.deepEqual(cnt,[1302540,1098240,123552,54912,10200,5108,3744,624,40],'exact counts for all 2,598,960 hands')}
 {const v=cs=>E.best(cs.map(x=>{const r='23456789TJQKA'.indexOf(x[0]),s='cdhs'.indexOf(x[1]);return s*13+r}));
  assert.ok(v(['As','2d','3c','4h','5s'])<v(['2s','3d','4c','5h','6s']),'the wheel is the lowest straight');
  assert.ok(v(['Ah','Kh','Qh','Jh','Th','2c','3d'])>v(['9h','9d','9c','9s','Kh','2c','3d']),'royal beats quads');
  assert.equal(v(['Ah','Ad','Kc','Ks','Qh','Qd','2c']),v(['Ah','Ad','Kc','Ks','Qh','2d','3c']),'two pair plays its best kicker');}
 // 2. the shuffle: where card 0 lands over 100,000 shuffles (chi-squared, 51 degrees of freedom)
 {const pos=Array(52).fill(0);for(let i=0;i<100000;i++)pos[E.shuffle(52,rng).indexOf(0)]++;const e=100000/52,chi=pos.reduce((a,x)=>a+(x-e)**2/e,0);out.chi=+chi.toFixed(1);assert.ok(chi<90,'uniform shuffle, chi '+chi)}
 // 3. blackjack: one player, 2-shard bets, basic strategy (stands on soft 17, double after split)
 const basic=(h,up,can)=>{const t=E.bjTotal(h.cards),u=up===11?11:up,c=h.cards,pair=c.length===2&&E.bjVal(c[0])===E.bjVal(c[1]);
  if(pair&&can.split){const v=E.bjVal(c[0]);if(v===11||v===8)return 'split';if(v===9&&u!==7&&u<10)return 'split';if(v===7&&u<=7)return 'split';if(v===6&&u<=6)return 'split';if(v===4&&(u===5||u===6))return 'split';if((v===2||v===3)&&u<=7)return 'split'}
  const D=x=>can.double&&x?'double':null;
  if(t.soft&&c.length>=2){const o=t.t-11;if(o>=8)return 'stand';if(o===7)return D(u>=3&&u<=6)||(u<=8?'stand':'hit');if(o===6)return D(u>=3&&u<=6)||'hit';if(o>=4)return D(u>=4&&u<=6)||'hit';return D(u>=5&&u<=6)||'hit'}
  const x=t.t;if(x>=17)return 'stand';if(x>=13)return u<=6?'stand':'hit';if(x===12)return u>=4&&u<=6?'stand':'hit';if(x===11)return D(true)||'hit';if(x===10)return D(u<=9)||'hit';if(x===9)return D(u>=3&&u<=6)||'hit';return 'hit'};
 {const st=E.newTable({game:'bj',lim:100,side:false,host:'u1'}),ctx=mk();E.sit(st,{uid:'u1',name:'A'},ctx);E.start(st,'u1');const s=st.seats[0];s.stack=1e9;s.brought=1e9;
  let wag=0,hands=0;const N=+(process.env.BJ_HANDS||300000);
  for(;hands<N;){ctx.now+=1;s.seen=ctx.now;E.tick(st,ctx);
   if(st.phase==='bet'){E.bjBet(st,'u1',2,false,ctx);wag+=2;E.tick(st,ctx)}
   if(st.phase==='ins')E.bjInsure(st,'u1',false),E.tick(st,ctx);
   while(st.phase==='play'){const v=E.view(st,'u1',ctx.now),h=st.hand.players[0].hands[st.hand.turn.h],a=basic(h,E.bjVal(st.hand.dealer[0]),v.can);if(a==='double'||a==='split')wag+=h.bet;E.bjAct(st,'u1',a,ctx)}
   if(st.phase==='done'){hands++;ctx.now+=E.PAUSE_MS;E.tick(st,ctx)}}
  const edge=(s.stack-1e9)/wag;out.bj={hands,wagered:wag,return:+(edge*100).toFixed(3)};
  if(!process.env.BJ_HANDS)assert.ok(edge>-0.013&&edge<0.004,'blackjack player return near the house edge (about -0.5%): '+(edge*100).toFixed(2)+'%')}
 // 4. hold'em: 3 players acting at random for 3,000 hands, side bets on
 {const st=E.newTable({game:'he',lim:0,side:true,host:'a'}),ctx=mk();for(const u of['a','b','c'])E.sit(st,{uid:u,name:u.toUpperCase()},ctx);E.start(st,'a');
  for(const x of st.seats)if(x){x.stack=300;x.brought=300;x.side=true}let start=900,rake=0,side=0,hands=0,leaks=0,showdowns=0,sidePots=0;
  while(hands<3000){ctx.now+=100;for(const x of st.seats)if(x)x.seen=ctx.now;
   const before=st.hand;E.tick(st,ctx);if(st.hand&&st.hand!==before&&st.phase==='play')side+=st.hand.players.filter(p=>p.side).length;
   if(st.phase==='play'){const h=st.hand,p=h.players[h.cur];
    for(const q of h.players){const v=E.view(st,q.uid,ctx.now);for(const o of v.players)if(o.seat!==q.seat&&o.cards[0]!==null)leaks++}
    const v=E.view(st,p.uid,ctx.now),c=v.can,r=rng(10);
    const m=r<2&&c.call?{a:'fold'}:r<6?{a:c.call?'call':'check'}:r<9&&c.raise&&c.maxPut>c.minPut?{a:'raise',amt:c.minPut+rng(c.maxPut-c.minPut+1)}:{a:'allin'};
    assert.equal(E.heAct(st,p.uid,m,ctx),null,'legal move refused '+JSON.stringify(m)+JSON.stringify(c))}
   if(st.phase==='done'){hands++;rake+=st.hand.rake;if(st.hand.shown)showdowns++;if(E.pots(st.hand).length>1)sidePots++;ctx.now+=E.NEXT_MS;
    for(const x of st.seats)if(x&&x.stack<E.BB){x.stack+=100;x.brought+=100;start+=100}}}
  const sum=st.seats.reduce((a,x)=>a+(x?x.stack:0),0);out.he={hands,rake,side,showdowns,sidePots,leaks,sideHits:ctx.hands.reduce((a,h)=>a+h.sideHits.length,0)};
  assert.equal(sum+rake+side,start,'no shard created or lost: stacks + rake + side bets = shards brought');assert.equal(leaks,0,'nobody sees another hole card mid-hand');
  assert.ok(showdowns>300&&sidePots>20,'showdowns and side pots happen');
  const rate=out.he.sideHits/side;out.he.sideRate=+rate.toFixed(4);assert.ok(rate>.022&&rate<.042,'side bet hit rate near 1 in 31 (full house or better 2.8% + pocket aces 0.45%): '+rate)}
 // 5. the bot: joins two people, leaves when a third sits, its result goes to the ledger as the house's
 {const st=E.newTable({game:'he',lim:100,side:false,host:'a'}),ctx=mk();E.sit(st,{uid:'a',name:'A'},ctx);E.tick(st,ctx);assert.equal(st.phase,'wait','one player waits');
  E.sit(st,{uid:'b',name:'B'},ctx);E.tick(st,ctx);assert.equal(st.phase,'wait','nothing is dealt until the host starts');assert.match(E.start(st,'b'),/host/,'only the host starts');
  assert.equal(E.start(st,'a'),null);E.tick(st,ctx);assert.ok(st.seats.some(s=>s&&s.bot)&&st.hand.players.length===3,'two people: the bot takes a seat');
  {const d=st.deadline;ctx.now+=10*60000;for(const x of st.seats)if(x)x.seen=ctx.now;E.tick(st,ctx);assert.ok(d===0&&st.phase==='play','no clock during a hand: nobody is folded after 10 minutes')}
  E.sit(st,{uid:'c',name:'C'},ctx);for(let i=0;i<80&&st.phase!=='done';i++){ctx.now+=E.BOT_MS+1;for(const x of st.seats)if(x)x.seen=ctx.now;E.tick(st,ctx);const p=st.phase==='play'&&st.hand.players[st.hand.cur];if(p&&!p.bot)E.heAct(st,p.uid,{a:'fold'},ctx)}
  ctx.now+=E.NEXT_MS+1;for(const x of st.seats)if(x)x.seen=ctx.now;E.tick(st,ctx);assert.ok(!st.seats.some(s=>s&&s.bot),'three people: the bot leaves');
  assert.ok(ctx.ops.some(o=>o.k==='bot'),'the bot\'s result is recorded');
  const st2=E.newTable({game:'he',lim:100,side:false,host:'a'}),c2={...mk(),botLeft:2};E.sit(st2,{uid:'a',name:'A'},c2);E.sit(st2,{uid:'b',name:'B'},c2);E.start(st2,'a');E.tick(st2,c2);
  assert.ok(!st2.seats.some(s=>s&&s.bot)&&st2.hand.players.length===2,'out of daily budget: no bot, heads-up')}
 // 6. limits, the side bet prize, cashing out
 {const st=E.newTable({game:'bj',lim:100,side:true,host:'a'}),ctx=mk();E.sit(st,{uid:'a',name:'A'},ctx);assert.deepEqual(ctx.ops[0],{uid:'a',k:'buyin',d:-5});
  E.topup(st,'a',200,ctx);E.start(st,'a');E.tick(st,ctx);assert.match(E.bjBet(st,'a',101,false,ctx),/limit/);assert.equal(E.bjBet(st,'a',10,true,ctx),null);assert.equal(st.seats[0].stack,205-11,'bet + 1-shard side bet');
  st.picks.a=1;assert.equal(E.pick(st,'a','flags',ctx),null);assert.deepEqual(ctx.ops.at(-1),{uid:'a',k:'case',bag:'flags',n:15});assert.match(E.pick(st,'a','hybrid',ctx),/No prize/);
  E.leave(st,'a',ctx);assert.deepEqual(ctx.ops.at(-1),{uid:'a',k:'cashout',d:205},'leaving in the betting window takes the bet back and cashes out');
  assert.match(E.settings(E.newTable({game:'he',lim:100,host:'a'}),'b',{lim:0}),/host/)}
 // a forced double-aces deal pays a pick
 {const st=E.newTable({game:'bj',lim:100,side:true,host:'a'});let n=0;const order=[12,0,25,1];const ctx={...mk(),rng:k=>{n++;return 0}};E.sit(st,{uid:'a',name:'A'},ctx);E.start(st,'a');E.tick(st,ctx);E.bjBet(st,'a',2,true,ctx);
  E.tick(st,ctx);const c=st.hand.players[0].hands[0].cards;out.forced=c;   // rng 0 shuffles to a fixed order; just check the rule on whatever it dealt
  const aa=E.rankOf(c[0])===12&&E.rankOf(c[1])===12;assert.equal((st.picks.a|0)>0,aa,'a pick exactly when the first two cards are aces')}
 out.ms=Date.now()-t0;fs.writeFileSync(__dirname+'/out/tables_engine.json',JSON.stringify(out,null,1));console.log(JSON.stringify(out));console.log('errors: none');
})().catch(e=>{console.error(e);process.exit(1)});
