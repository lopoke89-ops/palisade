// Contact sheets of the browser's tracers (traceSeg) and painted kill finishers (paintFinish), to compare with
// tests/fx_shot.gd:   node godot/tools/fx_ref.js /tmp/site out_prefix
const path=require('node:path'),fs=require('node:fs'),http=require('node:http');
const {chromium}=require(path.resolve(__dirname,'../../dev/test/node_modules/playwright'));
const site=path.resolve(process.argv[2]||'.'),pre=process.argv[3]||'fx';
(async()=>{
  const server=http.createServer((req,res)=>{const f=path.resolve(site,'.'+decodeURIComponent(req.url.split('?')[0]));try{res.setHeader('Content-Type',f.endsWith('.html')?'text/html':'application/octet-stream');res.end(fs.readFileSync(f))}catch{res.writeHead(404).end()}});
  await new Promise(r=>server.listen(8096,'127.0.0.1',r));
  const browser=await chromium.launch({executablePath:process.env.CHROMIUM||'/opt/pw-browsers/chromium-1194/chrome-linux/chrome'});
  const page=await browser.newPage();
  await page.goto('http://127.0.0.1:8096/debug.html?debug=1');await page.waitForFunction(()=>window.__pal&&window.__pal.traceSeg);
  const out=await page.evaluate(()=>{const P=__pal,R={};
    {const keys=Object.keys(P.TRAILS),C=4,CW=150,CH=26,cv=document.createElement('canvas');cv.width=C*CW;cv.height=Math.ceil(keys.length/C)*CH;const x=cv.getContext('2d');x.fillStyle='#1b2226';x.fillRect(0,0,cv.width,cv.height);
      keys.forEach((k,i)=>{const cx=(i%C)*CW,cy=Math.floor(i/C)*CH+13;P.traceSeg(x,cx+120,cy,cx+10,cy,P.TRAILS[k],4,1.3,false,1)});R.tracers=cv.toDataURL()}
    {const keys=Object.keys(P.FINISH_LIFE),C=8,CW=100,CH=100,cv=document.createElement('canvas');cv.width=C*CW;cv.height=Math.ceil(keys.length*4/C)*CH;const x=cv.getContext('2d');x.fillStyle='#1b2226';x.fillRect(0,0,cv.width,cv.height);
      keys.forEach((k,i)=>{[.12,.3,.55,.78].forEach((p,j)=>{const n=i*4+j,cx=(n%C)*CW+50,cy=Math.floor(n/C)*CH+62;P.paintFinish(x,k,p,1.5,cx,cy)})});R.finishes=cv.toDataURL();R.fkeys=keys}
    return R});
  for(const k of['tracers','finishes'])fs.writeFileSync(pre+'_'+k+'.png',Buffer.from(out[k].split(',')[1],'base64'));
  console.log(out.fkeys.join(','));await browser.close();server.close();
})().catch(e=>{console.error(e);process.exit(1)});
