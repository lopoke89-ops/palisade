/* ================= audio ================= */
let AC=null,master=null,NB=null;const lastS={},voiceT=[],MUF=[];
function muffle(wb){if(!MUF[wb]){const lp=AC.createBiquadFilter();lp.type='lowpass';lp.frequency.value=9000*Math.pow(.22,wb)+200;lp.connect(master);MUF[wb]=lp}return MUF[wb]}
function initAudio(){
  if(AC){if(AC.state==='suspended')AC.resume();return}
  try{AC=new(window.AudioContext||window.webkitAudioContext)();master=AC.createGain();master.gain.value=.55*cfg.volume;master.connect(AC.destination);
    NB=AC.createBuffer(1,AC.sampleRate*2,AC.sampleRate);const d=NB.getChannelData(0);for(let i=0;i<d.length;i++)d[i]=rnd()*2-1}catch(e){AC=null}
}
/* ---- music. Each track is loaded the first time it's needed, looped with no gap (Web Audio, not an <audio> tag),
   faded in and out. Only the track this part of the game can play stays decoded (a decoded minute of music is
   ~20 MB), so only the track needed by the current screen or phase stays decoded.
   Each track comes in two formats: AAC for Safari/iPhone/Chrome, Opus for browsers without AAC; the first one
   this browser plays is used. len: the exact release loop length in seconds; results is trimmed to the original 164-second cue.
   New track: add an entry here, a case in musicRoute(), and both files to build.py's MUSIC_FILES. */
const MUSIC={menu:{src:['main_menu.m4a','main_menu.ogg'],len:458.352},between:{src:['between_raids.m4a','between_raids.ogg'],len:160.08408333333333},attitude:{src:['raid_attitude.m4a','raid_attitude.ogg'],len:198.76572916666666},cool:{src:['raid_cool.m4a','raid_cool.ogg'],len:181.1853125},express:{src:['raid_express.m4a','raid_express.ogg'],len:115.51347916666667},finale:{src:['final_blitz.m4a','final_blitz.ogg'],len:389.4266666666667},results:{src:['results.m4a','results.ogg'],len:143.61797916666666}};
/* v0.10.1: the casino's own playlist, heard only in the casino. A true shuffle: every track once in a random order,
   then a fresh shuffle (never the track that just ended first). After the first track, each one crossfades into the
   next over its last CASINO_XF seconds. Only the playing track and the next one are ever decoded. */
const CASINO=[['casino_1.m4a','casino_1.ogg',391.44],['casino_2.m4a','casino_2.ogg',84.0],['casino_3.m4a','casino_3.ogg',209.256],['casino_4.m4a','casino_4.ogg',233.832],['casino_5.m4a','casino_5.ogg',392.016],['casino_6.m4a','casino_6.ogg',336.6],['casino_7.m4a','casino_7.ogg',120.96],['casino_8.m4a','casino_8.ogg',192.0],['casino_9.m4a','casino_9.ogg',301.176],['casino_10.m4a','casino_10.ogg',321.48],['casino_11.m4a','casino_11.ogg',221.832]].map(([a,o,len],i)=>{const k='casino'+(i+1);MUSIC[k]={src:[a,o],len,list:1};return k}),CASINO_XF=5;
// equal-power crossfade curves (the two tracks are unrelated, so their powers add)
const XF_IN=new Float32Array(65).map((_,i)=>Math.sin(i/64*Math.PI/2)),XF_OUT=XF_IN.slice().reverse();
const cas={bag:[],up:null,last:null};
function casinoUp(){
  if(cas.up)return cas.up;
  if(!cas.bag.length){const b=CASINO.slice();for(let i=b.length-1;i>0;i--){const j=Math.floor(Math.random()*(i+1));[b[i],b[j]]=[b[j],b[i]]}   // Math.random: the game's rnd() stays untouched
    if(b.length>1&&b[b.length-1]===cas.last)[b[0],b[b.length-1]]=[b[b.length-1],b[0]];cas.bag=b}
  return cas.up=cas.bag.pop();
}
const mus={bufs:{},loading:{},failAt:{},src:null,g:null,bus:null,cur:null,token:'',resume:null,started:0,offset:0,starts:0,retiring:null};
// A route identity changes only at a real screen/raid entry. Snapshots and settings cannot advance it.
function musicRoute(){
  if(!demo&&!$('over').hidden)return {k:'results',token:'results:'+game.gid};
  if(!$('menu').hidden)return {k:'menu',token:'menu'};
  if(!demo&&playing()){
    if(game.mode==='casino')return {k:'casino',token:'casino:'+game.gid};   // v0.10.1: the casino's own shuffled playlist
    if(game.mode==='blackout'&&!game.pvp&&game.bo&&game.phase==='raid'){const st=game.bo.stage;   // v0.9.7: raid tracks for POI attacks, the finale for the final push
      if(st==='push'||st==='done')return {k:'finale',token:'finale:'+game.gid};
      if(st==='attack')return {k:['attitude','cool','express'][Math.max(0,game.wave-1)%3],token:'raid:'+game.gid+':'+game.wave};
      return {k:'between',token:'quiet:'+game.gid+':'+game.wave}}
    if((game.mode==='blitz'||game.fb&&game.fb.gauntlet)&&!game.pvp&&game.fb)return {k:'finale',token:'finale:'+game.gid};   // v0.9.6.4: the Whiteout Gauntlet gets the finale track too
    if(game.phase==='raid')return {k:['attitude','cool','express'][Math.max(0,game.wave-1)%3],token:'raid:'+game.gid+':'+game.wave};
    return {k:'between',token:'build:'+game.gid+':'+game.wave};
  }
  return null;
}
// the casino route wants whichever playlist track is playing, or the next one up when none is
function musicWant(){const r=musicRoute();if(!(cfg.music>0&&!document.hidden&&r))return null;
  return r.k!=='casino'?r.k:mus.cur&&MUSIC[mus.cur].list&&mus.token===r.token?mus.cur:casinoUp()}
const musicKeep=k=>{const w=musicWant();return k===w||!!w&&MUSIC[w].list&&k===cas.up};
function musicLoad(k){
  if(mus.bufs[k]||mus.loading[k]||performance.now()-(mus.failAt[k]||-1e9)<30000||!AC)return;
  const ctl=new AbortController();mus.loading[k]=ctl;
  const A=document.createElement('audio'),can=u=>/\.m4a/.test(u)?A.canPlayType('audio/mp4; codecs="mp4a.40.2"'):A.canPlayType('audio/ogg; codecs="opus"');
  const list=MUSIC[k].src.filter(u=>can(u)),get=u=>fetch(u,{signal:ctl.signal}).then(r=>{if(!r.ok)throw 0;return r.arrayBuffer()})
    .then(a=>{if(ctl.signal.aborted||!musicKeep(k))throw 0;return new Promise((ok,no)=>{const q=AC.decodeAudioData(a,ok,no);if(q&&q.catch)q.catch(no)})});
  list.reduce((pr,u)=>pr.catch(()=>{if(ctl.signal.aborted)throw 0;return get(u)}),Promise.reject())
    .then(b=>{delete mus.loading[k];if(musicKeep(k))mus.bufs[k]=b},()=>{delete mus.loading[k];if(!ctl.signal.aborted)mus.failAt[k]=performance.now()});
}
function musicStart(k,token,xf){
  const b=mus.bufs[k],s=AC.createBufferSource(),g=AC.createGain(),len=Math.min(b.duration,MUSIC[k].len);let t=AC.currentTime;
  const off=mus.resume?.token===token&&mus.resume.k===k?mus.resume.offset%len:0,list=MUSIC[k].list;
  s.buffer=b;s.loop=!list;s.loopStart=0;s.loopEnd=len;
  if(xf){t=xf.t;g.gain.setValueAtTime(0,AC.currentTime);g.gain.setValueCurveAtTime(XF_IN,t,xf.d)}   // a playlist crossfade: in while the last track goes out
  else{g.gain.setValueAtTime(.0001,t);g.gain.exponentialRampToValueAtTime(1,t+1.6)}
  s.connect(g);g.connect(mus.bus);s.start(t,off);
  if(list){if(cas.up===k)cas.up=null;cas.last=k;casinoUp()}   // draw the next one now, so it can load in time
  mus.src=s;mus.g=g;mus.cur=k;mus.token=token;mus.started=t;mus.offset=off;mus.end=t+len-off;mus.starts++;
  s.g=g;s.onended=()=>{s.disconnect();g.disconnect();if(mus.retiring===s)mus.retiring=null};
}
// the source still fading out: cut short, faded over `fade` where the browser can hold a ramp mid-curve
function musicRetire(t,fade){
  const r=mus.retiring;if(!r)return;
  if(fade&&r.g.gain.cancelAndHoldAtTime){r.g.gain.cancelAndHoldAtTime(t);r.g.gain.linearRampToValueAtTime(0,t+fade);try{r.stop(t+fade+.05)}catch(e){}}
  else try{r.stop(t)}catch(e){}
}
function musicStop(fade){
  const s=mus.src,g=mus.g,t=AC.currentTime,k=mus.cur;
  musicRetire(t,fade);mus.retiring=s;
  mus.resume={token:mus.token,k,offset:Math.max(0,mus.offset+t-mus.started)%s.loopEnd};mus.src=mus.g=null;mus.cur=null;
  if(MUSIC[k].list&&cas.up!==k){if(cas.up)cas.bag.push(cas.up);cas.up=k}   // a playlist track picks up where it stopped if the casino comes back
  g.gain.cancelScheduledValues(t);g.gain.setValueAtTime(Math.max(g.gain.value,.0001),t);g.gain.exponentialRampToValueAtTime(.0001,t+fade);
  try{s.stop(t+fade+.05)}catch(e){}
}
// playlist: the playing track goes out over its last CASINO_XF seconds while the next one comes in
function musicCrossfade(k,token){
  const s=mus.src,g=mus.g,now=AC.currentTime,t=Math.max(now+.05,mus.end-CASINO_XF),d=mus.end-t;
  musicRetire(now,0);mus.retiring=s;mus.resume=null;
  g.gain.cancelScheduledValues(now);g.gain.setValueAtTime(1,now);g.gain.setValueCurveAtTime(XF_OUT,t,d);
  try{s.stop(t+d+.05)}catch(e){}
  musicStart(k,token,{t,d});
}
function musicTick(){
  if(!AC)return;
  if(!mus.bus){mus.bus=AC.createGain();mus.bus.connect(master)}
  mus.bus.gain.value=.5*cfg.music;
  const route=musicRoute();let want=musicWant();
  if(mus.src&&(mus.cur!==want||mus.token!==route?.token))musicStop(game.phase==='raid'?.9:1.2);
  if(mus.resume&&mus.resume.token!==route?.token){if(cas.up===mus.resume.k)cas.up=null;mus.resume=null}   // left the casino: the next visit moves on
  if(want&&mus.src&&MUSIC[want].list){const left=mus.end-AC.currentTime,nx=cas.up;
    if(left<60)musicLoad(nx);   // the next track decodes during this one's last minute, not before (a decoded minute is ~22 MB)
    if(left>.3&&left<=CASINO_XF+.25&&mus.bufs[nx])musicCrossfade(nx,route.token);
    else if(left<=0){try{mus.src.stop()}catch(e){}mus.src=mus.g=null;mus.cur=null;want=musicWant()}}   // the next one wasn't ready in time: it starts with a normal fade-in once it is
  for(const k in mus.loading)if(!musicKeep(k))mus.loading[k].abort();
  if(want){musicLoad(want);if(!mus.src&&mus.bufs[want])musicStart(want,route.token)}
  for(const k in mus.bufs)if(!musicKeep(k))delete mus.bufs[k];
}
document.addEventListener('visibilitychange',musicTick);
const uiSfx=n=>sfx(n,undefined,undefined,true,true);
// the case reel: a soft click and a small beep as each item crosses the marker, higher for rarer items
function caseTick(r){
  if(!AC)return;const t=AC.currentTime;if(t-(caseTick.t||0)<.028)return;caseTick.t=t;
  nz(master,t,.012,'highpass',5200,.8,.14);osc(master,t,.05,'sine',({c:880,r:1040,e:1240,l:1480,g:1760,u:2093})[r]||880,.045);
}
function envG(t0,a,d,peak){const gg=AC.createGain();gg.gain.setValueAtTime(.0001,t0);gg.gain.exponentialRampToValueAtTime(Math.max(peak,.0002),t0+a);gg.gain.exponentialRampToValueAtTime(.0001,t0+a+d);return gg}
function nz(dest,t0,dur,type,f,q,peak,fEnd){const s=AC.createBufferSource();s.buffer=NB;const fl=AC.createBiquadFilter();fl.type=type;fl.frequency.setValueAtTime(f,t0);if(fEnd)fl.frequency.exponentialRampToValueAtTime(fEnd,t0+dur);fl.Q.value=q;const gg=envG(t0,.003,dur,peak);s.connect(fl);fl.connect(gg);gg.connect(dest);s.start(t0,rnd()*1.5);s.stop(t0+dur+.05)}
function osc(dest,t0,dur,type,f,peak,fEnd){const o=AC.createOscillator();o.type=type;o.frequency.setValueAtTime(f,t0);if(fEnd)o.frequency.exponentialRampToValueAtTime(fEnd,t0+dur);const gg=envG(t0,.004,dur,peak);o.connect(gg);gg.connect(dest);o.start(t0);o.stop(t0+dur+.05)}
function wallsBetween(x0,y0,x1,y1){let n=0,last=-1;const d=Math.hypot(x1-x0,y1-y0),st=Math.max(1,Math.ceil(d/.3));for(let s=1;s<st;s++){const x=x0+(x1-x0)*s/st,y=y0+(y1-y0)*s/st,i=x|0,j=y|0;if(!inb(i,j))continue;const k=idx(i,j);if(k!==last&&walls[k]&&wallState(walls[k])<2){n++;last=k}}return n}
function sfx(name,x,y,noRec,ui){
  if(!noRec)rec(['s',name,x===undefined?null:r2(x),y===undefined?null:r2(y)]);
  // ui: menu sounds, heard even with the demo game running behind the menu
  if(!AC||(!ui&&(game.paused||demo)))return;const t=AC.currentTime;
  if(lastS[name]&&t-lastS[name]<.035)return;
  // at most ~14 sounds start in any 0.12 s window; distant world sounds are the first to be skipped
  while(voiceT.length&&t-voiceT[0]>.12)voiceT.shift();
  if(x!==undefined&&voiceT.length>=14&&!ui)return;
  lastS[name]=t;voiceT.push(t);
  let dest=master;
  if(x!==undefined&&player){
    const d=Math.hypot(x-player.x,y-player.y),v=1/(1+d*.2);if(v<.07)return;   // too far to hear
    const gn=AC.createGain();gn.gain.value=v;
    // walls in between muffle it: one shared filter per wall count instead of a new filter for every sound
    const wb=d>1.2?Math.min(3,wallsBetween(x,y,player.x,player.y)):0;
    gn.connect(wb?muffle(wb):master);dest=gn;
  }
  switch(name){
    case'ar':nz(dest,t,.07,'highpass',900,.7,.5);osc(dest,t,.08,'triangle',150,.45,50);break;
    case'sniper':nz(dest,t,.2,'bandpass',700,.6,.8,200);osc(dest,t,.25,'sine',95,.7,35);nz(dest,t+.05,.4,'lowpass',400,.5,.2);break;
    case'rack':nz(dest,t,.035,'highpass',2600,1.2,.35);osc(dest,t,.03,'square',1250,.07,700);nz(dest,t+.13,.03,'bandpass',3400,2,.4);osc(dest,t+.13,.04,'square',1650,.08,900);osc(dest,t+.2,.05,'triangle',380,.1,200);break;
    case'shotgun':nz(dest,t,.16,'lowpass',2600,.6,.95,300);osc(dest,t,.2,'sine',85,.85,32);nz(dest,t,.05,'highpass',1600,.8,.45);break;
    case'pump':nz(dest,t,.06,'bandpass',1500,1.4,.4,700);osc(dest,t,.05,'square',260,.07,160);nz(dest,t+.12,.05,'bandpass',2100,1.6,.45,1100);osc(dest,t+.12,.05,'square',330,.08,200);break;
    case'shellin':nz(dest,t,.03,'bandpass',2800,2,.3);osc(dest,t,.035,'triangle',900,.08,600);break;
    case'dry':osc(dest,t,.03,'square',2200,.06);break;
    case'medic':[523,659,784,1046].forEach((f,i)=>osc(dest,t+i*.05,.16,'sine',f,.13));break;
    case'horn':osc(dest,t,1.1,'sawtooth',73,.16,68);osc(dest,t,1.1,'sawtooth',110,.1,104);osc(dest,t+.4,.8,'sawtooth',98,.08,92);nz(dest,t,.9,'lowpass',300,.5,.25);break;
    case'rocket':nz(dest,t,.5,'bandpass',900,.7,.6,300);osc(dest,t,.35,'sawtooth',160,.12,60);nz(dest,t,.08,'lowpass',1200,.8,.7);break;
    case'lock':osc(dest,t,.06,'square',1560,.09);osc(dest,t+.1,.06,'square',1560,.09);osc(dest,t+.2,.1,'square',2080,.1);break;
    case'slash':nz(dest,t,.18,'bandpass',3200,1.5,.55,900);osc(dest,t+.02,.25,'sine',1900,.08,1200);break;
    case'charge':osc(dest,t,.8,'sawtooth',220,.08,900);osc(dest,t,.8,'sine',440,.07,1800);break;
    case'winterwarn':nz(dest,t,.65,'highpass',2800,.8,.12,1100);[880,660,440].forEach((f,i)=>osc(dest,t+i*.17,.3,'triangle',f,.09,f*.72));break;
    case'zap':nz(dest,t,.35,'highpass',2500,.6,.9);osc(dest,t,.3,'square',95,.25,40);[0,.04,.09,.15].forEach(d=>nz(dest,t+d,.04,'bandpass',4200,3,.5));break;
    // tracer sounds: a soft layer on top of the gunshot (at most every 0.22 s per soldier)
    case'ts_gold':osc(dest,t,.12,'sine',2350,.035);osc(dest,t+.03,.12,'sine',3140,.025);break;
    case'ts_plasma':osc(dest,t,.1,'square',190,.035,95);nz(dest,t,.08,'bandpass',3200,4,.08);break;
    case'ts_rainbow':[1320,1660,1980].forEach((f,i)=>osc(dest,t+i*.025,.06,'sine',f,.03));break;
    case'ts_grad':osc(dest,t,.1,'sine',620,.03,940);break;
    case'ts_aurora':osc(dest,t,.2,'sine',880,.03,1100);osc(dest,t,.2,'sine',886,.025,1108);break;
    case'ts_star':osc(dest,t,.08,'sine',2600,.035);osc(dest,t+.05,.08,'sine',3300,.025);break;
    case'ts_comet':nz(dest,t,.18,'bandpass',2400,2,.07,700);break;
    case'ts_neon':osc(dest,t,.06,'square',880,.025);osc(dest,t+.035,.05,'square',1320,.02);break;
    case'ts_cosmic':osc(dest,t,.22,'sine',220,.04,440);osc(dest,t,.22,'triangle',330,.02,660);break;
    case'ts_rock':nz(dest,t,.07,'lowpass',500,1,.08);osc(dest,t,.06,'triangle',110,.04,70);break;
    case'ts_solar':nz(dest,t,.14,'lowpass',900,.7,.07,300);osc(dest,t,.1,'sawtooth',140,.02,90);break;
    case'ts_glitch':for(let k=0;k<3;k++)osc(dest,t+k*.02,.018,'square',400+Math.floor(rnd()*6)*240,.03);break;
    case'ts_galaxy':[523,659,784].forEach(f=>osc(dest,t,.25,'sine',f,.022,f*1.5));break;
    case'ts_void':osc(dest,t,.24,'sine',320,.05,55);nz(dest,t,.12,'lowpass',260,1,.05);break;
    case'ts_grainbow':[1568,1976,2349,3136].forEach((f,i)=>osc(dest,t+i*.03,.1,'sine',f,.03));nz(dest,t,.1,'highpass',6000,.5,.03);break;
    // kill-effect sounds
    case'kx_sparks':nz(dest,t,.12,'highpass',3000,.8,.12);break;
    case'kx_smoke':nz(dest,t,.3,'lowpass',500,.6,.1,200);break;
    case'kx_confetti':nz(dest,t,.05,'bandpass',1800,1,.2);[1046,1318,1568].forEach((f,i)=>osc(dest,t+.04+i*.05,.08,'triangle',f,.05));break;
    case'kx_embers':nz(dest,t,.35,'bandpass',700,.7,.1,300);break;
    case'kx_glint':osc(dest,t,.3,'sine',2093,.05);osc(dest,t+.06,.3,'sine',2637,.04);break;
    // Halloween Case: fluttering chirps; a creaking thread and a thump; a hollow rising wail
    case'kx_bats':for(let k=0;k<5;k++){nz(dest,t+k*.045,.04,'bandpass',2600+k*300,3,.08);osc(dest,t+k*.05,.05,'sine',3200-k*180,.025)}break;
    case'kx_spider':osc(dest,t,.5,'sawtooth',220,.03,110);nz(dest,t+.45,.08,'lowpass',400,.7,.12);break;
    case'kx_souls':osc(dest,t,.9,'sine',330,.05,660);osc(dest,t+.08,.9,'sine',392,.035,784);nz(dest,t,.6,'bandpass',900,1.4,.05,1800);break;
    // v0.9.3 class rewards: a short boom; a scope's click and ping; a crack and rattling shrapnel; clinking scrap
    case'kx_rocketburst':nz(dest,t,.45,'lowpass',900,.6,.16,120);osc(dest,t,.3,'sine',90,.1,40);break;
    case'kx_reticle':osc(dest,t,.03,'square',1200,.03);osc(dest,t+.05,.25,'sine',1760,.04);osc(dest,t+.05,.25,'sine',2640,.02);break;
    case'kx_frag':nz(dest,t,.1,'highpass',2500,.7,.14);nz(dest,t,.35,'lowpass',700,.7,.12,160);for(let k=0;k<4;k++)nz(dest,t+.08+k*.05,.03,'bandpass',3500+k*400,4,.05);break;
    // v0.9.4.0 Blitzkrieg: a deep rumbling rift that slams shut; crackling cinders; a bright blade swish; a searing hiss; a low growl and scrape
    case'kx_hellportal':osc(dest,t,.8,'sawtooth',70,.07,40);nz(dest,t,.7,'lowpass',400,.8,.12,120);nz(dest,t+.75,.12,'lowpass',900,.6,.16,120);break;
    case'kx_orbital':osc(dest,t,.35,'sine',1400,.04,300);nz(dest,t+.3,.5,'lowpass',700,.7,.16,90);osc(dest,t+.3,.4,'sine',60,.1,30);break;   // v0.9.7: a rising whine, then the beam lands
    case'kx_cinder':for(let k=0;k<5;k++)nz(dest,t+k*.04,.03,'bandpass',2000+rnd()*1500,3,.07);nz(dest,t,.3,'lowpass',600,.6,.06);break;
    case'kx_tealslash':nz(dest,t,.16,'bandpass',3200,1.4,.12,6000);osc(dest,t,.2,'sine',1320,.03,2640);break;
    case'kx_ashbrand':nz(dest,t,.5,'highpass',2800,.6,.1,1200);osc(dest,t,.3,'triangle',180,.04,90);break;
    case'kx_demonclaw':osc(dest,t,.5,'sawtooth',55,.08,35);nz(dest,t+.1,.3,'bandpass',900,1.2,.1,300);break;
    case'kx_salvage':[1318,1760,1568,2093].forEach((f,i)=>osc(dest,t+i*.06,.09,'triangle',f,.04));break;
    case'kx_bolt':nz(dest,t,.12,'highpass',3500,.6,.14);osc(dest,t,.1,'square',80,.06,40);break;
    case'kx_skull':osc(dest,t,.4,'triangle',196,.06,147);osc(dest,t,.4,'triangle',233,.04,175);break;
    case'kx_pixel':[523,784,1046,1568].forEach((f,i)=>osc(dest,t+i*.04,.05,'square',f,.04));break;
    case'kx_frost':nz(dest,t,.12,'highpass',5000,1,.14);osc(dest,t,.25,'sine',3520,.03);break;
    case'kx_gradburst':osc(dest,t,.3,'sine',400,.05,1200);osc(dest,t,.3,'triangle',600,.03,1800);break;
    case'kx_sunburst':osc(dest,t,.3,'sine',500,.05,1400);nz(dest,t,.1,'bandpass',1500,1,.08);break;
    case'kx_toxic':for(let k=0;k<4;k++)osc(dest,t+k*.05,.05,'sine',300+rnd()*300,.05,160);break;
    case'kx_supernova':nz(dest,t,.5,'lowpass',1200,.6,.18,150);[784,1175,1568].forEach((f,i)=>osc(dest,t+.05+i*.06,.4,'sine',f,.035));break;
    case'kx_glitchout':for(let k=0;k<6;k++)osc(dest,t+k*.025,.02,'square',200+Math.floor(rnd()*8)*180,.04);break;
    case'kx_singularity':osc(dest,t,.35,'sine',900,.06,60);nz(dest,t+.3,.15,'lowpass',800,.7,.15);break;
    case'kx_shockwave':osc(dest,t,.3,'sine',70,.12,35);osc(dest,t,.2,'sawtooth',880,.03,220);nz(dest,t,.08,'bandpass',2500,2,.08);break;
    case'kx_bubbles':for(let k=0;k<6;k++)osc(dest,t+k*.055,.07,'sine',600+k*180+rnd()*60,.05,1400+k*120);[1568,2093,2637].forEach((f,i)=>osc(dest,t+.34+i*.07,.35,'sine',f,.04));break;
    case'smg':nz(dest,t,.05,'highpass',1400,.7,.35);osc(dest,t,.05,'square',180,.1,70);break;
    case'rifle':nz(dest,t,.09,'bandpass',1300,.8,.5);osc(dest,t,.1,'square',110,.16,45);break;
    case'hit0':nz(dest,t,.08,'lowpass',520,1,.7);osc(dest,t,.07,'sine',190,.45,85);break;
    case'hit1':nz(dest,t,.12,'bandpass',2300,1.3,.55,800);break;
    case'hit2':osc(dest,t,.55,'sine',1230,.16);osc(dest,t,.42,'sine',1870,.09);osc(dest,t,.3,'sine',2930,.05);nz(dest,t,.03,'highpass',4200,.4,.3);break;
    case'boom':nz(dest,t,.9,'lowpass',1900,.7,1,110);osc(dest,t,.65,'sine',72,.9,28);break;
    case'bigboom':nz(dest,t,1.3,'lowpass',1500,.6,1,70);osc(dest,t,.9,'sine',60,1,22);break;
    case'splash':nz(dest,t,.45,'lowpass',1400,.7,.55,250);nz(dest,t+.05,.2,'highpass',2600,.8,.2);break;
    case'harpoon':nz(dest,t,.12,'bandpass',1800,1.2,.5,600);osc(dest,t,.18,'sawtooth',180,.12,60);break;
    case'chain':for(let k=0;k<5;k++)nz(dest,t+k*.05,.03,'bandpass',3600+k*200,4,.12);break;
    case'drill':osc(dest,t,.6,'sawtooth',70,.14,55);nz(dest,t,.6,'bandpass',900,1.5,.25,700);break;
    case'rumble':osc(dest,t,.7,'sine',42,.35,36);nz(dest,t,.7,'lowpass',180,1,.3,90);break;
    case'rockfall':for(let k=0;k<6;k++)nz(dest,t+k*.07,.25,'lowpass',700-k*60,.8,.45,150);osc(dest,t,.8,'sine',55,.4,30);break;
    case'flood':nz(dest,t,1.4,'lowpass',600,.6,.35,300);osc(dest,t,1.4,'sine',90,.1,70);break;
    case'bottle':nz(dest,t,.08,'highpass',4200,1,.4);nz(dest,t+.04,.5,'bandpass',800,.7,.4,300);break;
    case'shieldhit':osc(dest,t,.25,'square',880,.06,700);osc(dest,t,.2,'sine',1320,.06);nz(dest,t,.04,'highpass',3000,1,.25);break;
    case'medpulse':osc(dest,t,.3,'sine',660,.06,990);osc(dest,t+.08,.3,'sine',880,.04,1320);break;
    case'mark':osc(dest,t,.08,'square',2400,.05);osc(dest,t+.12,.08,'square',2400,.05);break;
    case'collapse':nz(dest,t,.55,'lowpass',950,.6,.75,140);osc(dest,t,.3,'sine',90,.3,40);break;
    case'place0':osc(dest,t,.06,'sine',230,.5,120);osc(dest,t+.09,.06,'sine',210,.45,110);nz(dest,t,.05,'lowpass',700,1,.25);break;
    case'place1':nz(dest,t,.28,'bandpass',650,2,.4,380);osc(dest,t+.2,.08,'sine',140,.3,70);break;
    case'place2':nz(dest,t,.7,'highpass',3200,.5,.28);osc(dest,t,.7,'sawtooth',96,.06);osc(dest,t+.62,.4,'sine',1100,.08);break;
    case'gather':osc(dest,t,.05,'triangle',540+rnd()*60,.1);break;
    case'siren':osc(dest,t,1.8,'sine',260,.14,640);osc(dest,t,1.8,'sine',263,.1,646);break;
    case'core':osc(dest,t,.32,'sine',82,.6,38);nz(dest,t,.1,'lowpass',300,1,.3);break;
    case'hurt':osc(dest,t,.13,'square',210,.12,90);break;
    case'drop':nz(dest,t,.16,'lowpass',420,1,.4);break;
    case'lob':osc(dest,t,.12,'triangle',620,.1,300);break;
    case'plant':osc(dest,t,.05,'square',1400,.12);osc(dest,t+.12,.05,'square',1400,.12);break;
    case'beep':osc(dest,t,.04,'square',1800,.08);break;
    case'revive':[330,440,550].forEach((f,i)=>osc(dest,t+i*.07,.15,'triangle',f,.12));break;
    case'restock':osc(dest,t,.08,'triangle',700,.12);osc(dest,t+.08,.12,'triangle',940,.12);break;
    case'deny':osc(dest,t,.1,'square',150,.08);break;
    case'chat':osc(dest,t,.05,'sine',1320,.07);osc(dest,t+.06,.07,'sine',1760,.06);break;
    case'win':[392,494,587,784].forEach((f,i)=>osc(master,t+i*.12,.5,'triangle',f,.14));break;
    case'lose':[220,196,165].forEach((f,i)=>osc(master,t+i*.2,.6,'sawtooth',f,.08));break;
  }
}
const buzz=ms=>{if(!cfg.haptics)return;try{navigator.vibrate&&navigator.vibrate(ms)}catch(e){}padRumble(ms)};   // v0.9.2.1: and the controller rumbles

