// Real firing, pellets, burst/full-auto scheduling, playback and all existing flag colors.
const {chromium}=require('playwright'),assert=require('node:assert/strict'),fs=require('node:fs');
(async()=>{const browser=await chromium.launch({executablePath:process.env.CHROMIUM||undefined}),p=await browser.newPage(),errors=[];
p.on('pageerror',e=>errors.push(e.message));await p.goto('http://localhost:8080/debug.html?debug=1');await p.waitForFunction(()=>window.__pal);
await p.click('[data-go=solo]');await p.click('#startBtn');
const result=await p.evaluate(()=>{const P=__pal,who=P.player,failures=[];P.game.paused=true;P.NET.mode='host';P.NET.inGame=true;
const reset=(trail)=>{P.bullets.length=0;P.NET.fxq=[];who.cos.trail=trail;delete who.trCycleKey;delete who.trCycleNext;who.aim={x:1,y:0}};
for(const [id,,,bands]of P.FLAGS){reset('f_'+id);const st=P.TRAILS['f_'+id],want=id==='trans'?['#5bcefa','#ffffff','#f5a9b8']:bands;
if(JSON.stringify(st.cycle)!==JSON.stringify(want)||st.bands||!!st.pk!==['l','g'].includes(P.COSBY['trail:f_'+id].r))failures.push('catalog '+id);
for(let i=0;i<want.length*2+1;i++)P.shoot(who,who.gun,0);
if(P.bullets.some((b,i)=>b.tc!==i%want.length))failures.push('sequence '+id);
}
reset('f_trans');const pelletGun={...who.gun,pellets:5,spread:.1};P.shoot(who,pelletGun,0);P.shoot(who,pelletGun,0);
const pellets=P.bullets.map(b=>b.tc);if(pellets.join(',')!=='0,0,0,0,0,1,1,1,1,1')failures.push('pellets');
const events=JSON.parse(JSON.stringify(P.NET.fxq.filter(e=>e[0]==='b')));P.bullets.length=0;P.replayFx(events);P.replayFx(events);
if(P.bullets.length!==10||P.bullets.map(b=>b.tc).join(',')!==pellets.join(','))failures.push('playback/dedup');
reset('f_trans');for(let i=0;i<3;i++)P.shoot(who,who.gun,0);
const snap=P.makeSnap(true),start=P.startMsg();P.bullets.length=0;P.applySnap(snap);
if(P.bullets.map(b=>b.tc).join(',')!=='0,1,2'||start.shots.map(e=>e[12]).join(',')!=='0,1,2')failures.push('snapshot');
for(const burst of [false,true]){reset('f_trans');who.gun={...who.gun,burst,pellets:0,bolt:false,cd:.1,mag:20};who.ammo=20;who.cd=0;who.bLeft=0;who.fireIn=true;who.alive=true;P.game.phase='raid';P.simPlayer(who,.25);
if(P.bullets.length<2||P.bullets.some((b,i)=>b.tc!==i%3))failures.push('scheduler '+burst);}
const cv=document.createElement('canvas');cv.width=80;cv.height=24;const x=cv.getContext('2d');let pixels=0;
for(const st of Object.values(P.TRAILS).filter(s=>s.cycle))for(let i=0;i<st.cycle.length;i++){x.clearRect(0,0,80,24);P.traceSeg(x,5,12,55,12,st,3,0,false,i);const d=x.getImageData(10,12,1,1).data,col='#'+[...d].slice(0,3).map(v=>v.toString(16).padStart(2,'0')).join('');if(col!==st.cycle[i])failures.push('pixel '+st.cycle[i]+' '+col);pixels++}
return {flags:P.FLAGS.length,pixels,pellets,failures};});assert.deepEqual(result.failures,[]);assert.deepEqual(errors,[]);fs.writeFileSync(__dirname+'/out/tracer_cycle.json',JSON.stringify(result,null,2));console.log(result);console.log('errors: none');await browser.close();})().catch(e=>{console.error(e);process.exit(1)});
