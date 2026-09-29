// Collection browsing, lazy mounting, and equip navigation at phone and desktop sizes.
const {chromium}=require('playwright');
const assert=require('node:assert/strict');
(async()=>{
 const b=await chromium.launch({executablePath:process.env.CHROMIUM||undefined});
 try{for(const viewport of [{width:390,height:844},{width:844,height:390},{width:1280,height:900}]){
  const p=await b.newPage({viewport,hasTouch:viewport.width!==1280}),errors=[];
  p.on('pageerror',e=>errors.push(e.message));
  await p.goto('http://localhost:8080/debug.html?debug=1');
  await p.evaluate(()=>{const L=__pal.locker;L.cloud=null;L.owned.push('skin:arcade','skin:butcher');L.st.boss_butcher=26;__pal.showPage('locker')});
  assert.equal(await p.locator('.collectionItems canvas').count(),0,'collapsed collections allocate art');
  await p.evaluate(()=>document.getElementById('lockTabs').scrollIntoView({block:'start'}));await p.waitForTimeout(600);
  await p.screenshot({path:`${__dirname}/out/locker_collections_${viewport.width}_closed.png`});
  for(const cat of ['skin','hat','trail','fx','bg']){
   await p.click(`#lockTabs [data-cat=${cat}]`);
   const expected=await p.evaluate(cat=>__pal.COS.filter(c=>c.cat===cat&&!c.ladder).map(c=>c.id).sort(),cat);
   const headers=p.locator('.collectionToggle');
   for(let i=0;i<await headers.count();i++){
    assert.equal(await headers.nth(i).getAttribute('aria-expanded'),'false');
    await headers.nth(i).click();
   }
   assert.deepEqual(await p.locator('#lockGrid .item').evaluateAll(ts=>ts.map(t=>t.dataset.item).sort()),expected,cat+' catalog');
   for(let i=0;i<await headers.count();i++)await headers.nth(i).click();
   assert.equal(await p.locator('.collectionItems canvas').count(),0);
  }
  await p.click('#lockTabs [data-cat=ms]');
  const milestoneIds=await p.evaluate(()=>__pal.LADDERS.flatMap(l=>l.items.map(([cat,key])=>cat+':'+key)).sort());
  assert.deepEqual(await p.locator('#lockGrid .item').evaluateAll(ts=>ts.map(t=>t.dataset.item).sort()),milestoneIds);
  assert.equal(await p.locator('[data-item="skin:butcher2"] .iprog').textContent(),'26 / 50');
  await p.locator('[data-item="skin:butcher"]').click();
  assert.equal(await p.evaluate(()=>__pal.locker.eq.skin),'butcher');
  await p.click('#lockTabs [data-cat=skin]');
  const a=p.locator('#collection-skin-afterglow'),h=p.locator('#collection-skin-halloween');
  await a.focus();await p.keyboard.press('Enter');
  await h.focus();await p.keyboard.press('Space');
  assert.equal(await a.getAttribute('aria-expanded'),'true');assert.equal(await h.getAttribute('aria-expanded'),'true');
  const item=p.locator('[data-item="skin:arcade"]');await item.focus();
  const before=await p.evaluate(()=>{window.__tile=document.activeElement;return{grid:document.getElementById('lockGrid').scrollTop,panel:document.querySelector('#menu .panel').scrollTop}});
  await p.keyboard.press('Enter');
  assert.deepEqual(await p.evaluate(()=>({same:window.__tile===document.activeElement,eq:__pal.locker.eq.skin,grid:document.getElementById('lockGrid').scrollTop,panel:document.querySelector('#menu .panel').scrollTop})),{same:true,eq:'arcade',...before});
  await p.click('#lockTabs [data-cat=hat]');await p.click('#lockTabs [data-cat=skin]');
  assert.equal(await a.getAttribute('aria-expanded'),'true');assert.equal(await h.getAttribute('aria-expanded'),'true');
  // A cloud/ownership refresh updates counts without replacing the expanded collection.
  await p.evaluate(()=>{window.__section=document.getElementById('collection-skin-afterglow');__pal.locker.owned.push('skin:toxic');__pal.renderLocker()});
  assert.equal(await p.evaluate(()=>window.__section===document.getElementById('collection-skin-afterglow')),true);
  assert.match(await a.textContent(),/2 \/ \d+ owned/);
  if(viewport.width!==1280){await a.tap();assert.equal(await a.getAttribute('aria-expanded'),'false');await a.tap()}
  await a.scrollIntoViewIfNeeded();await p.screenshot({path:`${__dirname}/out/locker_collections_${viewport.width}_open.png`});
  assert.equal(await p.evaluate(()=>document.documentElement.scrollWidth>innerWidth),false,'horizontal page overflow');
  const overflow=await p.locator('.collectionToggle,#lockTabs button').evaluateAll(es=>es.some(e=>e.scrollWidth>e.clientWidth+1));
  assert.equal(overflow,false,'collection/tab text overflows');
  if(viewport.width===1280){
   // Newly won equipment must be revealed even when its collection was collapsed.
   await p.evaluate(()=>{__pal.locker.cases=1;__pal.renderLocker()});
   await p.click('[data-open=supply]');await p.click('#caseIntro');
   await p.waitForSelector('#caseEquip:not([hidden])',{timeout:10000});
   const name=await p.textContent('#caseName');await p.click('#caseEquip');
   const equipped=await p.evaluate(()=>({name:document.activeElement.querySelector('b')?.textContent,eq:document.activeElement.classList.contains('eq'),open:document.activeElement.closest('.lockerCollection')?.querySelector('button').getAttribute('aria-expanded')}));
   assert.deepEqual(equipped,{name,eq:true,open:'true'});
  }
  assert.deepEqual(errors,[]);await p.close();
 }
 console.log('collection catalog, disclosure, focus, touch, and case equip: errors: none');
 }finally{await b.close()}
})().catch(e=>{console.error(e);process.exitCode=1});
