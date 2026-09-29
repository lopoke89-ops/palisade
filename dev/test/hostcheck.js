// Malformed guest actions must not poison host state; an ordinary input and throw still work.
const {chromium} = require('playwright');
const assert = require('node:assert/strict');
(async () => {
  const b = await chromium.launch({executablePath:process.env.CHROMIUM||undefined});
  try {
    const page = await b.newPage(), errors = [];
    page.on('pageerror', e => errors.push(e.message));
    await page.goto('http://localhost:8080/debug.html?debug=1');
    await page.click('[data-go=solo]');
    await page.click('#startBtn');
    const result = await page.evaluate(() => {
      const P = __pal, p = P.player, peer = 'hostcheck-fixture';
      P.NET.mode = 'host'; P.NET.inGame = true;
      P.NET.conns.set(peer, {pid:p.id, heard:0});
      const input = extra => ({t:'i',x:p.x,y:p.y,ax:1,ay:0,tp:p.tp,n:0,f:0,a:1,...extra});
      const before = {x:p.x,y:p.y,aim:p.aim,nades:p.nades,rockets:p.rk,walls:P.walls.filter(Boolean).length};
      for (const bad of [
        {x:NaN,f:1},{y:Infinity,f:1},{ax:NaN,f:1},{ay:'1',f:1},
        {x:'1',f:1},{tp:'0',f:1},{n:Infinity,f:1}
      ]) P.hostData(peer,input(bad));
      P.hostData(peer,{t:'b',i:NaN,j:0,s:0});
      P.hostData(peer,{t:'b',i:'1',j:0,s:0});
      P.hostData(peer,{t:'n',x:Infinity,y:p.y});
      P.hostData(peer,{t:'n',x:'3',y:p.y});
      P.hostData(peer,{t:'ab',x:NaN,y:p.y});
      const refused = {x:p.x,y:p.y,aim:p.aim,nades:p.nades,rockets:p.rk,walls:P.walls.filter(Boolean).length,fire:p.fireIn};
      P.hostData(peer,input({ax:0,ay:1}));
      const acceptedAim = p.aim.x===0&&p.aim.y===1;
      P.hostData(peer,{t:'n',x:p.x+.5,y:p.y});
      const acceptedThrow = p.nades===before.nades-1;
      return {before,refused,acceptedAim,acceptedThrow};
    });
    assert.equal(result.refused.x,result.before.x);
    assert.equal(result.refused.y,result.before.y);
    assert.deepEqual(result.refused.aim,result.before.aim);
    assert.equal(result.refused.nades,result.before.nades);
    assert.equal(result.refused.rockets,result.before.rockets);
    assert.equal(result.refused.walls,result.before.walls);
    assert.equal(result.refused.fire,false);
    assert.equal(result.acceptedAim,true);
    assert.equal(result.acceptedThrow,true);
    assert.deepEqual(errors,[]);
    console.log('host inputs',JSON.stringify(result),'errors: none');
  } finally { await b.close() }
})().catch(e=>{console.error(e);process.exitCode=1});
