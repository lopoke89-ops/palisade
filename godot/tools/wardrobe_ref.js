// The browser's wardrobe looks (lookOf) for every skin and every headgear, and a contact sheet of them painted by
// paintWardrobeCharacter, to check the Godot wardrobe against:
//   node godot/tools/wardrobe_ref.js /tmp/site [sheet.png]   ->  godot/tests/wardrobe_looks.json (+ the sheet)
const path=require('node:path'),fs=require('node:fs'),http=require('node:http');
const {chromium}=require(path.resolve(__dirname,'../../dev/test/node_modules/playwright'));
const site=path.resolve(process.argv[2]||'.'),sheet=process.argv[3];
(async()=>{
  const server=http.createServer((req,res)=>{const f=path.resolve(site,'.'+decodeURIComponent(req.url.split('?')[0]));try{res.setHeader('Content-Type',f.endsWith('.html')?'text/html':'application/octet-stream');res.end(fs.readFileSync(f))}catch{res.writeHead(404).end()}});
  await new Promise(r=>server.listen(8095,'127.0.0.1',r));
  const browser=await chromium.launch({executablePath:process.env.CHROMIUM||'/opt/pw-browsers/chromium-1194/chrome-linux/chrome'});
  const page=await browser.newPage();
  await page.goto('http://127.0.0.1:8095/debug.html?debug=1');await page.waitForFunction(()=>window.__pal&&window.__pal.lookOf);
  const out=await page.evaluate(()=>{const P=__pal,list=[];
    for(const s of Object.keys(P.SKINS))list.push({skin:s,hat:'class',cls:'soldier'});
    for(const h of P.COS.filter(c=>c.cat==='hat').map(c=>c.key))if(h!=='class')list.push({skin:'std',hat:h,cls:'soldier'});
    for(const c of['sniper','grenadier','quartermaster'])list.push({skin:'std',hat:'class',cls:c});
    list.push({skin:'sahur',hat:'crown',cls:'soldier'},{skin:'arcade',hat:'tophat',cls:'sniper'});
    return list.map(e=>({...e,look:P.lookOf({skin:e.skin,hat:e.hat},e.cls)}))});
  fs.writeFileSync(path.resolve(__dirname,'../tests/wardrobe_looks.json'),JSON.stringify(out));
  if(sheet){
    const png=await page.evaluate(list=>{const P=__pal,C=14,CW=92,CH=104,rows=Math.ceil(list.length*2/C),cv=document.createElement('canvas');cv.width=C*CW;cv.height=rows*CH;
      const x=cv.getContext('2d');x.fillStyle='#1b2226';x.fillRect(0,0,cv.width,cv.height);
      list.forEach((e,i)=>{for(const k of[0,1]){const n=i*2+k,cx=(n%C)*CW+CW/2,cy=Math.floor(n/C)*CH+CH-14;P.paintWardrobeCharacter(x,e.look,k?3.6:.5,2,1.9,cx,cy,false)}});
      return cv.toDataURL()},out);
    fs.writeFileSync(sheet,Buffer.from(png.split(',')[1],'base64'));
  }
  console.log(out.length+' looks');await browser.close();server.close();
})().catch(e=>{console.error(e);process.exit(1)});
