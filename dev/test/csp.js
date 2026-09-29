// Production and debug pages must load their own scripts, renderer worker, and local PeerJS under CSP.
const {chromium}=require('playwright');
const assert=require('node:assert/strict');
(async()=>{
 const b=await chromium.launch({executablePath:process.env.CHROMIUM||undefined});
 try{for(const file of ['index.html','debug.html?debug=1']){
   const p=await b.newPage(),errors=[],violations=[];
   p.on('pageerror',e=>errors.push(e.message));
   await p.addInitScript(()=>document.addEventListener('securitypolicyviolation',e=>{(window.__cspViolations??=[]).push(e.violatedDirective+' '+e.blockedURI)}));
   await p.goto('http://localhost:8080/'+file);
   assert.ok(await p.locator('meta[http-equiv="Content-Security-Policy"]').count());
   await p.click('[data-go=locker]');await p.waitForTimeout(800);
   await p.click('[data-go=multi]');await p.waitForTimeout(500);
   violations.push(...await p.evaluate(()=>window.__cspViolations||[]));
   assert.deepEqual(errors,[],file+' page errors');assert.deepEqual(violations,[],file+' CSP violations');
   await p.close();
 }
 console.log('production/debug CSP, local renderer and PeerJS: errors: none');
 }finally{await b.close()}
})().catch(e=>{console.error(e);process.exitCode=1});
