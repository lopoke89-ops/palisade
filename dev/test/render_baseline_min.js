// Minify the preserved pre-edit debug page with the same options as build.py.
// Rehash its CSP; never use candidate source to create the baseline.
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),{minify}=require('terser');
(async()=>{
 const dir=path.join(__dirname,'out/render-perf');let page=fs.readFileSync(path.join(dir,'baseline-debug.html'),'utf8').replace(/\r\n/g,'\n');
 const begin=page.indexOf('<script>\n(()=>{')+'<script>\n'.length,end=page.indexOf('</script>',begin);
 if(begin<'<script>\n'.length||end<begin)throw new Error('preserved baseline game script not found');
 const code=(await minify(page.slice(begin,end),{compress:{passes:2},mangle:true,ecma:2020})).code;
 page=page.slice(0,begin)+code+page.slice(end);
 const scripts=[...page.matchAll(/<script(?:\s[^>]*)?>(.*?)<\/script>/gs)];if(scripts.length!==2)throw new Error('unexpected script count');
 const hashes=scripts.map(m=>"'sha256-"+crypto.createHash('sha256').update(m[1]).digest('base64')+"'");let n=0;
 page=page.replace(/'sha256-[^']+'/g,()=>hashes[n++]);if(n!==2)throw new Error('unexpected CSP hash count');
 fs.writeFileSync(path.join(dir,'baseline-debug-min.html'),page);console.log('preserved baseline minified; CSP rehashed');
})().catch(e=>{console.error(e);process.exit(1)});
