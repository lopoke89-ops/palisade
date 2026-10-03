// Real PeerJS host/guest purchases, snapshots, mode checks and same-match reconnect.
const {chromium}=require('playwright'),assert=require('node:assert/strict'),fs=require('node:fs');
const Q='peerhost=127.0.0.1&peerport=9000&peerpath=/&debug=1';
(async()=>{const b=await chromium.launch({executablePath:process.env.CHROMIUM||undefined,args:['--disable-features=WebRtcHideLocalIpsWithMdns']}),errors=[],out={modes:{}};
  const H=await b.newPage(),G=await(await b.newContext()).newPage();
  for(const [label,p] of [['H',H],['G',G]]){p.on('pageerror',e=>errors.push(label+' '+e.message));await p.goto('http://localhost:8080/debug.html?'+Q)}
  await H.waitForTimeout(800);await G.evaluate(()=>__pal.pick.cls='sniper');
  await H.click('[data-nav=multi]');await H.click('#hostBtn');await H.waitForFunction(()=>/^[A-Z0-9]{4}$/.test(document.getElementById('lCode').textContent));
  const code=await H.textContent('#lCode');
  const join=async()=>{await G.click('[data-nav=multi]');await G.fill('#mCode',code);await G.click('#joinBtn');await G.waitForFunction(()=>__pal.NET.inGame||!document.getElementById('pg-lobby').hidden)};
  await join();await H.evaluate(()=>__pal.lobbyReadyAll());await H.click('#lStart');await G.waitForFunction(()=>__pal.NET.inGame);await H.waitForTimeout(300);
  for(const mode of ['5','10','endless','blitz']){
    await H.evaluate(mode=>{const P=__pal;P.pick.mode=mode;P.newGame(P.NET.roster,'');P.game.timer=999;for(const p of P.players.values()){p.sal=1000;p.hp=p.max;p.x=P.core.i+.5;p.y=P.core.j+.5;p.tp++}P.NET.sendAll(P.startMsg())},mode);
    await G.waitForFunction(mode=>__pal.game.mode===mode&&__pal.player.sal===1000,mode);
    await G.evaluate(()=>{__pal.NET.toHost({t:'am',id:'fire',slot:0});__pal.NET.toHost({t:'am',id:'fire',slot:0})});
    await G.waitForFunction(()=>__pal.player.ammoEq[0]==='fire');
    await G.evaluate(()=>__pal.NET.toHost({t:'am',id:'shock',slot:0}));await G.waitForFunction(()=>__pal.player.ammoEq[0]==='shock');
    out.modes[mode]=await G.evaluate(()=>({sal:__pal.player.sal,ammo:__pal.player.ammoEq.slice()}));assert.deepEqual(out.modes[mode],{sal:775,ammo:['shock','']});
  }
  await H.evaluate(()=>{const P=__pal;P.game.timer=999;window.hold=setInterval(()=>{P.game.timer=999;P.core.hp=P.core.max;for(const p of P.players.values()){p.hp=p.max;p.x=P.core.i+.5;p.y=P.core.j+.5;p.tp++}},50)});
  await G.evaluate(()=>{document.getElementById('armory').hidden=false;__pal.renderArmory()});await G.click('#armAmmoTab');await G.click('[data-arm-slot="1"]');await G.click('[data-arm-ammo="fire"]');
  await G.evaluate(()=>{const P=__pal;for(const slot of [2,-1,.5,'0'])P.NET.toHost({t:'am',id:'blast',slot});P.NET.toHost({t:'am',id:'shock',slot:1});P.NET.toHost({t:'am',id:'unknown',slot:0})});
  await G.waitForFunction(()=>__pal.player.ammoEq[1]==='fire');await G.waitForTimeout(250);
  out.slots=await G.evaluate(()=>({sal:__pal.player.sal,ammo:__pal.player.ammoEq.slice()}));assert.deepEqual(out.slots,{sal:625,ammo:['shock','fire']});
  await H.evaluate(()=>{const P=__pal,q=[...P.players.values()].find(p=>p.id!=='host');for(const k of ['d','r','g','a','n']){q.sal=30000;for(let i=0;i<8;i++)P.buyUpgrade(q,k)}q.sal=625;
    const e=P.spawnEnemyAt('rifle',2.5,2.5);e.hp=e.max=1000;e.speed=0;e.cd=999;P.ammoHit(e,{own:q.id,shot:987654,ammo:[['fire',4],['shock',4]]});window.statusId=e.id});
  await G.waitForFunction(()=>__pal.player.upS==='88888'&&__pal.enemies.some(e=>e.burnT>0&&e.slowT>0));
  out.status=await G.evaluate(()=>{const e=__pal.enemies.find(e=>e.burnT>0);return{burn:e.burnT>0,slow:e.slowPct,up:__pal.player.upS}});assert.deepEqual(out.status,{burn:true,slow:.45,up:'88888'});
  await G.evaluate(()=>document.getElementById('quitBtn').click());await G.waitForFunction(()=>__pal.NET.mode==='solo');await H.waitForFunction(()=>__pal.players.size===1);
  await join();await G.waitForFunction(()=>__pal.NET.inGame&&__pal.player.upS==='88888');
  out.rejoin=await G.evaluate(()=>({sal:__pal.player.sal,ammo:__pal.player.ammoEq.slice(),up:__pal.player.upS}));assert.deepEqual(out.rejoin,{sal:625,ammo:['shock','fire'],up:'88888'});
  for(const pvp of ['base','ffa']){
    await H.evaluate(pvp=>{const P=__pal;P.newGame(P.NET.roster,pvp);P.game.timer=999;for(const p of P.players.values()){p.sal=500;p.x=P.core.i+.5;p.y=P.core.j+.5;p.tp++}P.NET.sendAll(P.startMsg())},pvp);
    await G.waitForFunction(pvp=>__pal.game.pvp===pvp&&__pal.player.sal===500,pvp);await G.evaluate(()=>__pal.NET.toHost({t:'am',id:'fire',slot:0}));await G.waitForTimeout(200);
    const r=await H.evaluate(()=>{const p=[...__pal.players.values()].find(p=>p.id!=='host');return{sal:p.sal,ammo:p.ammoEq.slice()}});assert.deepEqual(r,{sal:500,ammo:['','']});out[pvp]=r;
  }
  await H.evaluate(()=>clearInterval(window.hold));assert.deepEqual(errors,[]);fs.writeFileSync(__dirname+'/out/ammo_network.json',JSON.stringify(out,null,2));console.log(JSON.stringify(out));console.log('errors: none');await b.close();
})().catch(e=>{console.error(e);process.exit(1)});
