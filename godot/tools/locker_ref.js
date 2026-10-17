// The browser's no-account run payouts (localRun) for a set of claims, to check the Godot locker against:
//   node godot/tools/locker_ref.js /tmp/site   ->  godot/tests/locker_ref.json
const path=require('node:path'),fs=require('node:fs'),http=require('node:http');
const {chromium}=require(path.resolve(__dirname,'../../dev/test/node_modules/playwright'));
const site=path.resolve(process.argv[2]||'.');
const base={diff:'normal',raid_from:0,shard_bosses:0,sb_keys:[],fb_keys:[],salvage:0,size:'std',mods:[],map:'yard',cls:'soldier',evac:'',cv:4,g_cleared:0,ch_evac:[]};
const claims=[
  ['5 raids, a win',{mode:'5',win:true,held:5,raid_to:5,kills:40,boss_keys:['butcher'],duration_s:600},3],
  ['endless, 12 held',{mode:'endless',win:false,held:12,raid_to:12,kills:90,boss_keys:['butcher','demolisher'],mods:['elite'],duration_s:900},10],
  ['10 raids XL on Hard, lost in raid 8',{mode:'10',diff:'hard',win:false,held:7,raid_to:7,kills:70,boss_keys:['butcher','demolisher','storm'],size:'xl',cls:'sniper',map:'river',duration_s:800},2],
  ['10 raids, a win on Hard',{mode:'10',diff:'hard',win:true,held:10,raid_to:10,kills:120,boss_keys:['ferryman','butcher'],map:'river',cls:'grenadier',mods:['nopatch','alone'],duration_s:1500},0],
  ['Black Out, all 8 and the Destroyer',{mode:'blackout',win:true,held:9,raid_to:9,kills:150,boss_keys:[],duration_s:900,cv:5,pois_held:8,pois_major:4,destroyer:true,map:'city'},4],
  ['Black Out, Command fell early',{mode:'blackout',win:false,held:3,raid_to:3,kills:30,boss_keys:[],duration_s:200,cv:5,pois_held:3,pois_major:0,destroyer:false,map:'city'},0],
  ['Blitz, left behind',{mode:'blitz',win:false,held:15,raid_to:15,kills:200,boss_keys:['bluebutcher','arsonist'],fb_keys:['bluebutcher','arsonist','tempest'],evac:'left',duration_s:1600},5],
  ['Campaign, out of the Gauntlet',{mode:'campaign',win:true,held:13,raid_to:13,kills:260,boss_keys:['whitebutcher','whiteferryman','whiteforeman','rime'],fb_keys:Array(9).fill('rime'),g_cleared:3,ch_evac:[true,true,false],evac:'evac',map:'yard',duration_s:2600},5]];
(async()=>{
  const server=http.createServer((req,res)=>{const f=path.resolve(site,'.'+decodeURIComponent(req.url.split('?')[0]));try{res.setHeader('Content-Type',f.endsWith('.html')?'text/html':'application/octet-stream');res.end(fs.readFileSync(f))}catch{res.writeHead(404).end()}});
  await new Promise(r=>server.listen(8094,'127.0.0.1',r));
  const browser=await chromium.launch({executablePath:process.env.CHROMIUM||'/opt/pw-browsers/chromium-1194/chrome-linux/chrome'});
  const page=await browser.newPage();await page.addInitScript(()=>{Math.random=()=>0.99});
  await page.goto('http://127.0.0.1:8094/debug.html?debug=1');await page.waitForFunction(()=>window.__pal&&window.__pal.localRun);
  const out=await page.evaluate(({claims,base})=>claims.map(([name,c,sh])=>{const L=__pal.locker;
    L.owned=__pal.COS.filter(x=>x.src==='free').map(x=>x.id);L.cases=0;L.bag={};L.shards=0;L.prog=0;L.st={raids:0,wins:0,drops:0,endless:0,hardWins:0};L.sp=0;L.spProg=0;L.spTotal=0;L.cloud=null;
    const claim={...base,...c},R=__pal.localRun(claim,sh);
    return {name,claim,shards:sh,out:{cases:L.cases,bag:{...L.bag},shards:L.shards,prog:L.prog,st:{...L.st},sp:L.sp,unlocked:R.unlocked,text:R.text}}}),{claims,base});
  fs.writeFileSync(path.resolve(__dirname,'../tests/locker_ref.json'),JSON.stringify(out,null,1));console.log(out.map(o=>o.name+': '+o.out.text).join('\n'));
  await browser.close();server.close();
})().catch(e=>{console.error(e);process.exit(1)});
