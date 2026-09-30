// Opt-in verification of the documented single-scene rollback. Uses a temporary assembled fixture, never edits source.
const {chromium}=require('playwright'),fs=require('node:fs'),crypto=require('node:crypto'),assert=require('node:assert/strict');
(async()=>{const b=await chromium.launch({executablePath:process.env.CHROMIUM||undefined}),p=await b.newPage({deviceScaleFactor:1}),images={};
 for(const [key,name]of [['before','presentation-baseline'],['restored','presentation-rollback']]){
  await p.route('**/'+name+'.html*',r=>r.fulfill({contentType:'text/html',body:fs.readFileSync(__dirname+'/out/'+name+'.html','utf8')}));await p.goto('http://localhost:8080/'+name+'.html?debug=1');await p.waitForFunction(()=>window.__pal);
  images[key]=await p.evaluate(()=>{const c=document.createElement('canvas');c.width=390;c.height=844;__pal.drawBg('campfire',c.getContext('2d'),390,844,4);return c.toDataURL()});
 }
 assert.equal(images.before,images.restored,'single-ID rollback returns baseline pixels');const result={scene:'campfire',size:[390,844],dpr:1,time:4,match:true,pngDataUrlSHA256:crypto.createHash('sha256').update(images.before).digest('hex')};fs.writeFileSync(__dirname+'/out/presentation/restore-check.json',JSON.stringify(result,null,2));console.log(JSON.stringify(result));console.log('errors: none');await b.close();
})().catch(e=>{console.error(e);process.exit(1)});
