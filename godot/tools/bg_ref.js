// A contact sheet of every lobby background as the browser paints it (drawBg), to compare with tests/bg_shot.gd:
//   node godot/tools/bg_ref.js /tmp/site out.png
const path=require('node:path'),fs=require('node:fs'),http=require('node:http');
const {chromium}=require(path.resolve(__dirname,'../../dev/test/node_modules/playwright'));
const site=path.resolve(process.argv[2]||'.');
(async()=>{
  const server=http.createServer((req,res)=>{const f=path.resolve(site,'.'+decodeURIComponent(req.url.split('?')[0]));try{res.setHeader('Content-Type',f.endsWith('.html')?'text/html':'application/octet-stream');res.end(fs.readFileSync(f))}catch{res.writeHead(404).end()}});
  await new Promise(r=>server.listen(8098,'127.0.0.1',r));
  const browser=await chromium.launch({executablePath:process.env.CHROMIUM||'/opt/pw-browsers/chromium-1194/chrome-linux/chrome'});
  const page=await browser.newPage();await page.emulateMedia({reducedMotion:'no-preference'});
  await page.goto('http://127.0.0.1:8098/debug.html?debug=1');await page.waitForFunction(()=>window.__pal&&window.__pal.drawBg);await page.evaluate(()=>document.fonts.ready);
  const d=await page.evaluate(()=>{const P=__pal,ids=Object.keys(P.BGS),C=6,CW=320,CH=200,cv=document.createElement('canvas');cv.width=C*CW;cv.height=Math.ceil(ids.length/C)*CH;const x=cv.getContext('2d');
    ids.forEach((id,i)=>{x.save();x.translate((i%C)*CW,Math.floor(i/C)*CH);x.beginPath();x.rect(0,0,CW,CH);x.clip();P.drawBg(id,x,CW,CH,1.3);x.restore()});return {png:cv.toDataURL(),ids}});
  fs.writeFileSync(process.argv[3],Buffer.from(d.png.split(',')[1],'base64'));console.log(d.ids.join(','));await browser.close();server.close();
})().catch(e=>{console.error(e);process.exit(1)});
