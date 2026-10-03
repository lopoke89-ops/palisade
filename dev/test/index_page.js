// v0.9.6.5 the INDEX page: three tabs, a card for every raider type and every boss, numbers read from the game's tables,
// fits at three sizes without sideways scrolling, and the setup sheet's link opens it on Classes.
const {chromium}=require('playwright'),assert=require('node:assert/strict');
(async()=>{const b=await chromium.launch({executablePath:process.env.CHROMIUM||undefined}),errors=[],out={};
 for(const [n,vp,m]of[['desktop',{width:1366,height:820},false],['portrait',{width:390,height:844},true],['landscape',{width:844,height:390},true]]){
  const p=await b.newPage({viewport:vp,isMobile:m,hasTouch:m});p.on('pageerror',e=>errors.push(n+': '+e.message));
  await p.goto(`http://localhost:${process.env.PORT||8080}/debug.html?debug=1`);await p.waitForFunction(()=>window.__pal);
  out[n]=await p.evaluate(async()=>{const P=__pal,r={};document.querySelector('[data-nav=classes]').click();await new Promise(z=>setTimeout(z,200));
    r.nav=document.querySelector('[data-nav=classes]').textContent.trim();r.title=document.querySelector('#pg-classes .pt').textContent;
    r.classes=document.querySelectorAll('#classes .cls').length;r.classesShown=!document.querySelector('[data-idxp=classes]').hidden;
    P.idxTab('raiders');r.raiders=[...document.querySelectorAll('#idxRaiders .idxCard')].map(c=>[c.querySelector('h3').textContent,c.querySelector('.idxStat').textContent]);
    r.raidersOk=P.IDX_RAIDERS.every(([k],i)=>r.raiders[i]&&r.raiders[i][1].startsWith(P.ETYPES?'':''));
    P.idxTab('bosses');const cards=[...document.querySelectorAll('#idxBosses .idxCard')];
    r.bosses=cards.map(c=>({name:c.querySelector('h3').textContent,stat:c.querySelector('.idxStat').textContent,atk:c.querySelectorAll('li').length,weak:(c.querySelector('.idxWeak')||{}).textContent||''}));
    r.expect=Object.keys(P.BOSSES).map(k=>({name:P.BOSSES[k].name,hp:Math.round(P.BOSSES[k].hp*P.BOSS_HP),weak:P.AMMO_BY[P.BOSS_WEAK[k]].name}));
    r.scroll=document.documentElement.scrollWidth>innerWidth+1;
    // the setup sheet's link reopens the Index on Classes
    P.showPage('solo');await new Promise(z=>setTimeout(z,100));const link=document.querySelector('[data-ss=job] [data-go=classes]');r.link=link&&link.textContent;if(link)link.click();await new Promise(z=>setTimeout(z,200));
    r.backToClasses=!document.querySelector('[data-idxp=classes]').hidden&&document.querySelector('[data-idxp=bosses]').hidden;
    return r});await p.close()}
 for(const [n,r]of Object.entries(out)){
  assert.equal(r.nav,'INDEX');assert.equal(r.title,'INDEX');assert.equal(r.classes,4);assert.ok(r.classesShown);
  assert.equal(r.raiders.length,7,n+' raiders');
  assert.equal(r.bosses.length,15,n+' bosses');   // v0.9.7: + the Supreme Destroyer
  for(const x of r.expect){const c=r.bosses.find(b=>b.name===x.name);assert.ok(c,n+' card for '+x.name);assert.ok(c.stat.startsWith(x.hp+' base health'),n+' '+x.name+' hp '+c.stat);
    assert.ok(c.weak.includes(x.weak),n+' '+x.name+' weak '+c.weak);assert.ok(c.atk>=2,n+' '+x.name+' lists its attacks')}
  for(const k of['THE STORMCALLER','THE TEMPEST','THE ARSONIST','THE BULLDOZER'])assert.equal(r.bosses.find(b=>b.name===k).atk,3,k+' has 3 attacks');
  assert.ok(!r.scroll,n+' no sideways scroll');assert.equal(r.link,'OPEN THE INDEX');assert.ok(r.backToClasses,n+' link opens Classes')}
 assert.deepEqual(errors,[]);console.log(JSON.stringify({sizes:Object.keys(out),bosses:out.desktop.bosses.length,raiders:out.desktop.raiders.length}));console.log('errors: none');await b.close();
})().catch(e=>{console.error(e);process.exit(1)});
