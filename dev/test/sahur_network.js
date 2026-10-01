// A host's Sahur + Devil Horns look reaches the guest stage and the first game snapshot.
const {chromium}=require('playwright'),assert=require('node:assert/strict'),fs=require('node:fs');
(async()=>{
 const b=await chromium.launch({executablePath:process.env.CHROMIUM||undefined,args:['--disable-features=WebRtcHideLocalIpsWithMdns']}),errors=[];
 const h=await b.newPage({viewport:{width:1280,height:720}}),g=await b.newPage({viewport:{width:390,height:844},isMobile:true,hasTouch:true});
 for(const p of[h,g])p.on('pageerror',e=>errors.push(e.message));
 const url=`http://localhost:${process.env.PORT||8080}/debug.html?debug=1&peerhost=127.0.0.1&peerport=9000&peerpath=/`;
 await h.goto(url);await g.goto(url);await h.waitForFunction(()=>window.__pal);await g.waitForFunction(()=>window.__pal);
 await h.evaluate(()=>{__pal.locker.eq.skin='sahur';__pal.locker.eq.hat='devilhorns'});
 await h.click('[data-nav=multi]');await h.click('#hostBtn');await h.waitForSelector('#pg-lobby:not([hidden])');
 const code=await h.textContent('#lCode');await g.click('[data-nav=multi]');await g.fill('#mCode',code);await g.click('#joinBtn');await g.waitForSelector('#pg-lobby:not([hidden])');
 await g.waitForFunction(()=>__pal.NET.roster.some(r=>r.cos.startsWith('sahur|devilhorns|')));
 const stage=await g.evaluate(()=>({cos:__pal.NET.roster.find(r=>r.cos.startsWith('sahur|')).cos,slots:document.querySelectorAll('.partySlot.occupied').length}));
 assert.equal(stage.slots,2);await g.screenshot({path:__dirname+'/out/sahur_remote_lobby.png'});
 await h.click('#lStart');await g.waitForFunction(()=>__pal.NET.inGame);
 const game=await g.evaluate(()=>{const P=__pal,remote=[...P.players.values()].find(x=>x!==P.player),look=P.playerLook(remote);return{skin:remote.cos.skin,hat:remote.cos.hat,sahur:look.sahur,horns:look.horns,demon:!!look.demon,demonHorns:!!look.demonHorns}});
 assert.equal(game.skin,'sahur');assert.equal(game.hat,'devilhorns');assert.ok(game.sahur&&game.horns);assert.equal(game.demon,false);assert.equal(game.demonHorns,false);
 await g.screenshot({path:__dirname+'/out/sahur_remote_game.png'});assert.deepEqual(errors,[]);
 fs.writeFileSync(__dirname+'/out/sahur_network.json',JSON.stringify({stage,game,errors},null,2));console.log(JSON.stringify({stage,game}));console.log('errors: none');await b.close();
})().catch(e=>{console.error(e);process.exit(1)});
