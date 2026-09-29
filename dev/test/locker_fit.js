// Effects that extend beyond the boots or head must fit in the Locker stage and skin tile.
const {chromium} = require('playwright');
const assert = require('node:assert/strict');
(async () => {
  const b = await chromium.launch({executablePath:process.env.CHROMIUM||undefined});
  try {
    for (const viewport of [{width:390,height:844},{width:1280,height:900}]) {
      const p = await b.newPage({viewport}), errors = [];
      p.on('pageerror',e=>errors.push(e.message));
      await p.goto('http://localhost:8080/debug.html?debug=1');
      for (const skin of ['galaxy','storm4','demo4']) {
        const bounds = await p.evaluate(async skin => {
          const P = __pal;P.locker.eq.skin=skin;P.showPage('locker');
          await new Promise(ok=>setTimeout(ok,550));
          const cv=document.getElementById('partyMe'),x=cv.getContext('2d'),d=x.getImageData(0,0,cv.width,cv.height).data;
          let top=cv.height,bottom=-1,left=cv.width,right=-1;
          for(let y=0;y<cv.height;y++)for(let q=0;q<cv.width;q++)if(d[(y*cv.width+q)*4+3]>40){top=Math.min(top,y);bottom=Math.max(bottom,y);left=Math.min(left,q);right=Math.max(right,q)}
          const tile=document.createElement('canvas');tile.width=tile.height=160;
          P.drawIcon(tile,P.COSBY['skin:'+skin]);const td=tile.getContext('2d').getImageData(0,0,160,160).data;
          let edge=0;for(let n=0;n<160;n++)for(const k of [n,(159*160+n),(n*160),(n*160+159)])if(td[k*4+3]>40)edge++;
          return {top,bottom,left,right,edge};
        },skin);
        assert.ok(bounds.top>5&&bounds.bottom<774,`${skin} stage vertical bounds ${JSON.stringify(bounds)}`);
        assert.ok(bounds.left>5&&bounds.right<994,`${skin} stage horizontal bounds ${JSON.stringify(bounds)}`);
        assert.equal(bounds.edge,0,`${skin} thumbnail clipped at the border`);
        if(skin==='galaxy')await p.screenshot({path:__dirname+'/out/locker_galaxy_'+viewport.width+'.png'});
        console.log(viewport.width,skin,JSON.stringify(bounds));
      }
      if(viewport.width===1280)for(const hat of ['jackolantern','tophat','witch','boonie','officer','clownhair','gclownhair','glitch','ledmask','visor']){
        await p.evaluate(hat=>{__pal.locker.eq.skin='std';__pal.locker.eq.hat=hat;__pal.showPage('locker')},hat);
        await p.waitForTimeout(500);
        await p.screenshot({path:__dirname+'/out/locker_'+hat+'.png'});
      }
      if(viewport.width===1280){
        await p.evaluate(()=>{__pal.locker.eq.skin='yard3';__pal.locker.eq.hat='class';__pal.showPage('locker')});
        await p.waitForTimeout(500);
        await p.screenshot({path:__dirname+'/out/locker_straw.png'});
      }
      if(viewport.width===1280)for(const skin of ['clown','slasher','scarecrow','butcher']){
        await p.evaluate(skin=>{__pal.locker.eq.skin=skin;__pal.locker.eq.hat='class';__pal.showPage('locker')},skin);
        await p.waitForTimeout(500);
        await p.screenshot({path:__dirname+'/out/locker_skin_'+skin+'.png'});
      }
      assert.deepEqual(errors,[]);
      await p.close();
    }
    console.log('errors: none');
  } finally { await b.close() }
})().catch(e=>{console.error(e);process.exitCode=1});
