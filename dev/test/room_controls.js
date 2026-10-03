// Host kick and room lock apply to direct joins as well as listed rooms.
const {chromium}=require('playwright');
const assert=require('node:assert/strict');
const Q='peerhost=127.0.0.1&peerport=9000&peerpath=/&debug=1';
(async()=>{
  const b=await chromium.launch({executablePath:process.env.CHROMIUM||undefined,args:['--disable-features=WebRtcHideLocalIpsWithMdns']});
  const pages=[];
  try{
    const make=async()=>{const p=await b.newPage();p.errors=[];p.on('pageerror',e=>p.errors.push(e.message));pages.push(p);await p.goto('http://localhost:8080/debug.html?'+Q);return p};
    const h=await make(),g=await make(),other=await make();
    await h.click('[data-go=multi]');await h.click('#hostBtn');await h.waitForSelector('#pg-lobby:not([hidden])');
    const code=(await h.textContent('#lCode')).trim();
    const join=async p=>{await p.click('[data-go=multi]');await p.fill('#mCode',code);await p.click('#joinBtn')};
    await join(g);await g.waitForSelector('#pg-lobby:not([hidden])');await h.waitForFunction(()=>__pal.NET.roster.length===2);
    await h.locator('#lList .crewKick').click();
    await g.waitForFunction(()=>__pal.NET.mode==='solo'&&document.getElementById('mStatus').textContent.includes('removed'));
    await h.waitForFunction(()=>__pal.NET.roster.length===1);
    await g.click('#joinBtn');await g.waitForFunction(()=>document.getElementById('mStatus').textContent.includes('removed'),null,{timeout:8000});
    assert.equal(await h.evaluate(()=>__pal.NET.roster.length),1,'kicked browser rejoined');
    await h.click('#lLock');assert.equal(await h.evaluate(()=>__pal.NET.roomLocked),true);
    await join(other);await other.waitForFunction(()=>document.getElementById('mStatus').textContent.includes('locked'),null,{timeout:8000});
    assert.equal(await h.evaluate(()=>__pal.NET.roster.length),1,'locked room admitted a guest');
    await h.click('#lLock');await other.click('#joinBtn');await other.waitForSelector('#pg-lobby:not([hidden])');
    await h.waitForFunction(()=>__pal.NET.roster.length===2);
    await h.evaluate(()=>__pal.lobbyReadyAll());await h.click('#lStart');await other.waitForFunction(()=>document.getElementById('menu').hidden);
    await h.click('#pauseBtn');await h.locator('#pauseCrewList .crewKick').click();
    await other.waitForFunction(()=>__pal.NET.mode==='solo'&&document.getElementById('mStatus').textContent.includes('removed'));
    await h.waitForFunction(()=>__pal.NET.roster.length===1);
    for(const p of pages)assert.deepEqual(p.errors,[]);
    console.log('lobby and pause kick, rejoin refusal, locked direct join, unlock: errors: none');
  }finally{await b.close()}
})().catch(e=>{console.error(e);process.exitCode=1});
