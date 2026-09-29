// The supplied menu/raid tracks should decode, loop and route without replacing build or Locker music.
const {chromium} = require('playwright');
const assert = require('node:assert/strict');
(async () => {
  const b = await chromium.launch({executablePath:process.env.CHROMIUM||undefined,args:['--autoplay-policy=no-user-gesture-required']});
  try {
    const p = await b.newPage({viewport:{width:390,height:844},deviceScaleFactor:2}), errors = [];
    p.on('pageerror',e=>errors.push(e.message));
    await p.goto('http://localhost:8080/debug.html?debug=1');
    assert.equal(await p.evaluate(()=>__pal.musicWant()),'menu');
    await p.click('#startBtn');
    const track = async name => {
      await p.waitForFunction(name=>__pal.mus.cur===name&&!!__pal.mus.src,name,{timeout:15000});
      return p.evaluate(()=>({want:__pal.musicWant(),cur:__pal.mus.cur,loop:__pal.mus.src.loopEnd,decoded:Object.keys(__pal.mus.bufs),gain:__pal.mus.bus.gain.value}));
    };
    const build = await track('between');
    await p.evaluate(()=>__pal.startRaid());
    const raid = await track('raid');
    await p.evaluate(()=>__pal.toMenu());
    const menu = await track('menu');
    await p.evaluate(()=>__pal.showPage('locker'));
    const locker = await track('locker');
    await p.evaluate(()=>{const s=document.getElementById('sMus');s.value=0;s.dispatchEvent(new Event('input'))});
    await p.waitForFunction(()=>__pal.musicWant()===null&&__pal.mus.cur===null);
    for (const [name,s] of Object.entries({between:build,raid,menu,locker})) {
      assert.equal(s.want,name); assert.equal(s.cur,name);
      assert.ok(s.loop>1,'loop length for '+name);
      assert.ok(s.decoded.length<=1,'only one decoded track for '+name);
      assert.ok(s.gain>0,'music volume for '+name);
    }
    assert.ok(Math.abs(raid.loop-5832911/48000)<.01,'raid WAV loop length');
    assert.ok(Math.abs(menu.loop-6764037/48000)<.01,'menu WAV loop length');
    assert.deepEqual(errors,[]);
    console.log('routes',JSON.stringify({build,raid,menu,locker}),'errors: none');
  } finally { await b.close() }
})().catch(e=>{console.error(e);process.exitCode=1});
