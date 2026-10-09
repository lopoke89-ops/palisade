// Verify the generated release and, with --live, its actually served public assets.
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),assert=require('node:assert/strict');
const root=path.resolve(__dirname,'../..'),canonical=s=>s.replace(/\r\n/g,'\n'),hash=(s,kind='sha256')=>crypto.createHash(kind).update(s).digest('hex');
(async()=>{
 const read=f=>canonical(fs.readFileSync(path.join(root,f),'utf8')),index=read('index.html'),sw=read('sw.js'),peer=read('peerjs.min.js'),config=JSON.parse(read('dev/render/client.json'));
 assert.equal(config.enabled,true);assert.equal(config.url,'https://palisade-casino-staging.onrender.com');
 assert.match(index,/v0\.10\.5/);assert.match(index,/globalThis\.PALISADE_RELAY=\{enabled:(?:!0|true),url:/);assert.ok(index.includes(config.url));
 assert.equal(index.includes('window.__pal'),false);assert.equal(index.includes('nxsqerlpqdzrjwqxhsdz'),false);assert.equal(index.includes('SUPABASE_SERVICE_ROLE_KEY'),false);
 assert.ok(index.includes('https://puvjfhwxigxjpsvdwrwf.supabase.co'));
 const policy=index.match(/<meta http-equiv="Content-Security-Policy" content="([^"]+)"/)[1],scripts=[...index.matchAll(/<script(?:\s[^>]*)?>(.*?)<\/script>/gs)].map(m=>m[1]);assert.equal(scripts.length,2);
 for(const script of scripts)assert.ok(policy.includes("'sha256-"+crypto.createHash('sha256').update(script).digest('base64')+"'"),'the CSP must authorize the actual emitted script');
 assert.ok(policy.includes(config.url));assert.ok(policy.includes(config.url.replace(/^https:/,'wss:')));
 const build=hash(index+peer,'sha1').slice(0,10);assert.ok(sw.includes("const V='palisade-"+build+"'"));assert.ok(/exclude:[\s\S]*- dev/.test(read('_config.yml')));
 const report={version:'v0.10.5',build,relayEnabled:true,productionAuth:true,debugHooksAbsent:true,cspHashesMatch:true,canonicalSha256:{'index.html':hash(index),'sw.js':hash(sw)}};
 if(process.argv.includes('--live')){
  for(const [file,expected]of [['index.html',index],['sw.js',sw]]){const r=await fetch('https://lopoke89-ops.github.io/palisade/'+file+'?release='+build,{signal:AbortSignal.timeout(20000)});assert.equal(r.status,200);assert.equal(canonical(await r.text()),expected,'served '+file+' must match this release')}
  report.servedAssetsMatch=true;report.site='https://lopoke89-ops.github.io/palisade/';
 }
 report.checkedAt=new Date().toISOString();fs.mkdirSync(__dirname+'/out',{recursive:true});fs.writeFileSync(__dirname+'/out/relay-release.json',JSON.stringify(report,null,2));console.log(JSON.stringify(report));console.log('errors: none');
})().catch(e=>{console.error(e.message);process.exitCode=1});
