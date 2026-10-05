// v0.9.7.2: the main menu's music starts on the first click anywhere (it used to wait for a menu tab, so the opening
// menu stayed silent), and it is the new Pali Mix: the menu track's loop is its full 458.352 s.
const {chromium}=require('playwright'),assert=require('node:assert/strict'), { ready, frames } = require('./lib');
(async()=>{const b=await chromium.launch({executablePath:process.env.CHROMIUM||undefined,args:['--autoplay-policy=user-gesture-required']}),errors=[];
 const p=await b.newPage({viewport:{width:1280,height:800}});p.on('pageerror',e=>errors.push(e.message));
 await p.goto(`http://localhost:${process.env.PORT||8080}/debug.html?debug=1`);await ready(p);
 const before=await p.evaluate(()=>({ac:__pal.AC?__pal.AC.state:null,cur:__pal.mus.cur}));
 // a first click on the page itself, not on a menu tab (the old code only woke the sound from the tabs or the game)
 await p.mouse.click(640,30);
 await p.waitForFunction(()=>__pal.AC&&__pal.AC.state==='running'&&__pal.mus.cur==='menu',null,{timeout:30000});
 const after=await p.evaluate(()=>({ac:__pal.AC.state,cur:__pal.mus.cur,loop:+__pal.mus.src.loopEnd.toFixed(3),page:document.getElementById('menu').dataset.page}));
 console.log(JSON.stringify({before,after}));
 assert.notEqual(before.cur,'menu','silent before any click (browsers require one)');
 assert.equal(after.ac,'running');assert.equal(after.cur,'menu','the menu music plays after the first click');assert.equal(after.page,before.page===undefined?after.page:after.page);
 assert.ok(Math.abs(after.loop-458.352)<.02,'the new mix loops at its full length: '+after.loop);
 assert.deepEqual(errors,[]);console.log('errors: none');await b.close();
})().catch(e=>{console.error(e);process.exit(1)});
