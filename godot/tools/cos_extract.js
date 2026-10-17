// Pulls the cosmetics catalog out of the browser build's runtime registries (debug.html?debug=1 exposes window.__pal):
//   PALISADE_BUILD_OUTPUT=/tmp/site NOMIN=1 python3 dev/build.py && node godot/tools/cos_extract.js /tmp/site
// Writes godot/data/cosmetics.json: rarities, cases, every item (with how it's earned), skins, tracers, flags,
// milestone ladders, lobby backgrounds and auras. Art lives in code; this file is only the data.
const path=require('node:path'),fs=require('node:fs'),http=require('node:http');
const {chromium}=require(path.resolve(__dirname,'../../dev/test/node_modules/playwright'));
const site=path.resolve(process.argv[2]||'.');
(async()=>{
  const server=http.createServer((req,res)=>{const f=path.resolve(site,'.'+decodeURIComponent(req.url.split('?')[0]));try{res.setHeader('Content-Type',f.endsWith('.html')?'text/html':f.endsWith('.js')?'application/javascript':'application/octet-stream');res.end(fs.readFileSync(f))}catch{res.writeHead(404).end()}});
  await new Promise(r=>server.listen(8093,'127.0.0.1',r));
  const browser=await chromium.launch({executablePath:process.env.CHROMIUM||'/opt/pw-browsers/chromium-1194/chrome-linux/chrome'});
  const page=await browser.newPage(),errors=[];page.on('pageerror',e=>errors.push(e.message));
  await page.goto('http://127.0.0.1:8093/debug.html?debug=1');await page.waitForFunction(()=>window.__pal&&window.__pal.COS);
  const data=await page.evaluate(()=>{const P=__pal,plain=o=>JSON.parse(JSON.stringify(o,(k,v)=>typeof v==='function'?undefined:v));
    const ladders=P.LADDERS.map(L=>({...plain(L),hows:L.hows||L.steps.map(n=>L.how(n))}));
    const bgs={};for(const id in P.BGS){const B=P.BGS[id];bgs[id]=plain(B);bgs[id].animated=B.still===undefined;}
    const hats=P.COS.filter(c=>c.cat==='hat').map(c=>c.key),compat={};for(const s in P.SKINS)compat[s]=hats.filter(h=>P.headwearAllowed(s,h));
    return {RAR:plain(P.RAR),CASES:plain(P.CASES),COS:plain(P.COS),SKINS:plain(P.SKINS),TRAILS:plain(P.TRAILS),FLAGS:plain(P.FLAGS),LADDERS:ladders,BGS:bgs,AURAS:plain(P.AURAS),
      HALLOWEEN_HATS:plain(P.HALLOWEEN_HATS),hatsAllowed:compat,FINISH_LIFE:plain(P.FINISH_LIFE||{}),
      WINTER_PAIRS:plain(P.WINTER_PAIRS),WINTER_MODELS:plain(P.WINTER_MODELS),WINTER_TRACERS:plain(P.WINTER_TRACERS),WINTER_FX:plain(P.WINTER_FX),WINTER_BG:plain(P.WINTER_BG)}});
  fs.writeFileSync(path.resolve(__dirname,'../data/cosmetics.json'),JSON.stringify(data));
  console.log('items',data.COS.length,'skins',Object.keys(data.SKINS).length,'trails',Object.keys(data.TRAILS).length,'bgs',Object.keys(data.BGS).length,'auras',Object.keys(data.AURAS).length,'errors',errors.length?errors.slice(0,3):'none');
  await browser.close();server.close();
})().catch(e=>{console.error(e);process.exit(1)});
