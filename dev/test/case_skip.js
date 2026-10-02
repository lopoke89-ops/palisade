// Skip must leave the actual committed winner visible, even before the intro/reels exist.
const {chromium}=require('playwright'),assert=require('node:assert/strict'),fs=require('node:fs');
(async()=>{
 const b=await chromium.launch({executablePath:process.env.CHROMIUM}),p=await b.newPage({viewport:{width:390,height:844},isMobile:true,hasTouch:true}),errors=[],checks=[];
 p.on('pageerror',e=>errors.push(e.message));
 try{
  await p.goto(`http://localhost:${process.env.PORT||8080}/debug.html?debug=1`);
  await p.waitForFunction(()=>window.__pal);
  await p.evaluate(()=>{__pal.cfg.music=0;__pal.locker.bag.flags=12;__pal.locker.bag.winter=40;__pal.saveLocker();__pal.showPage('locker')});
  for(const quantity of [1,5])for(const phase of ['pending','intro','reel']){
   const box=quantity===1?'flags':'winter';
   const before=await p.evaluate(box=>({count:__pal.caseCount(box),eq:{...__pal.locker.eq}}),box);
   if(phase==='pending'){
    await p.evaluate(()=>{window.__skipCommitHeld=false;const hold=new Promise(r=>window.__releaseSkipCommit=r);navigator.locks.request('palisade-case-opening',()=>{window.__skipCommitHeld=true;return hold})});
    await p.waitForFunction(()=>window.__skipCommitHeld);
   }
   await p.click(`[data-${quantity===5?'open5':'open'}=${box}]`);
   if(phase==='pending')assert.equal(await p.evaluate(()=>__pal.caseSession.results),null);
   else await p.waitForFunction(()=>!!__pal.caseSession?.results);
   if(phase==='reel'){
    await p.click('#caseIntro');
    await p.waitForFunction(()=>document.querySelectorAll('#reel .item').length>0);
    await p.waitForTimeout(250);
   }
   await p.click('#caseSkip');
   if(phase==='pending')await p.evaluate(()=>window.__releaseSkipCommit());
   await p.waitForSelector('#caseResult:not([hidden])');
   await p.waitForFunction(()=>[...document.querySelectorAll('#caseOv .reel img')].every(img=>img.complete&&img.naturalWidth>0));
   const result=await p.evaluate(()=>{
    const receipt=__pal.locker.lastOpening,rows=[...document.querySelectorAll('#caseOv .reel')];
    window.__skipResultNodes=rows.map(r=>r.querySelectorAll('.item')[r.dataset.win]);
    return {receipt,count:__pal.caseCount(receipt.case),eq:{...__pal.locker.eq},
     summary:receipt.quantity===5?[...document.querySelectorAll('.caseResultRow')].map(r=>r.dataset.item):[__pal.caseSession.results[0].it.id],
     winners:rows.map(r=>{const tile=r.querySelectorAll('.item')[r.dataset.win],tr=tile.getBoundingClientRect(),wr=r.parentElement.getBoundingClientRect();
      return {id:tile.dataset.item,name:tile.querySelector('b').textContent,art:tile.querySelector('img').naturalWidth,centerError:Math.abs(tr.left+tr.width/2-wr.left-wr.width/2)}}),
     name:document.getElementById('caseName').textContent};
   });
   assert.equal(result.count,before.count-quantity);
   assert.equal(result.receipt.results.length,quantity);
   assert.equal(result.winners.length,quantity);
   assert.deepEqual(result.winners.map(w=>w.id),result.receipt.results.map(r=>r.id));
   assert.deepEqual(result.summary,result.receipt.results.map(r=>r.id));
   assert.ok(result.winners.every(w=>w.centerError<1&&w.art>0));
   assert.deepEqual(result.eq,before.eq);
   if(quantity===1)assert.equal(result.name,result.winners[0].name);
   await p.waitForTimeout(150);
   assert.equal(await p.evaluate(()=>window.__skipResultNodes.every((node,i)=>node===document.querySelectorAll('#caseOv .reel')[i].querySelectorAll('.item')[document.querySelectorAll('#caseOv .reel')[i].dataset.win])),true,'intro continuation must not replace the revealed reels');
   assert.equal(await p.evaluate(()=>__pal.locker.lastOpening.operation),result.receipt.operation);
   if(phase==='intro')await p.screenshot({path:__dirname+`/out/case-skip-${quantity}.png`});
   await p.click('#caseDone');
   assert.equal(await p.locator('#caseOv .item').count(),0);
   checks.push({quantity,phase,winners:result.winners,consumed:quantity});
  }
  assert.deepEqual(errors,[]);
  fs.writeFileSync(__dirname+'/out/case-skip.json',JSON.stringify({checks,errors},null,2));
  console.log('Single/five Skip during pending rewards, intro and reel shows centered committed winners, readable art and unchanged equips; no reroll or repeated reveal. errors: none');
 }finally{await b.close()}
})().catch(e=>{console.error(e);process.exitCode=1});
