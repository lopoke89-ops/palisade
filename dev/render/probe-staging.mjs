// Read-only checks against the isolated staging project. Uses a public key only.
import assert from 'node:assert/strict';
import {writeFile} from 'node:fs/promises';

const project='nxsqerlpqdzrjwqxhsdz';
const url=process.env.SUPABASE_URL;
const key=process.env.SUPABASE_PUBLISHABLE_KEY;
assert.equal(url,`https://${project}.supabase.co`,'Probe must target the isolated staging project');
assert.ok(key?.startsWith('sb_publishable_'),'Supply the public staging publishable key');
const checks=[];
async function request(name,path,{body,authorization,method=body?'POST':'GET'}={}){
 const headers={apikey:key,'Content-Type':'application/json'};
 if(authorization)headers.Authorization='Bearer '+authorization;
 const r=await fetch(url+path,{method,headers,body:body?JSON.stringify(body):undefined,signal:AbortSignal.timeout(20000)});
 const text=await r.text();let data;try{data=JSON.parse(text)}catch{data=text}
 return {name,status:r.status,data};
}
const preflight=await request('Edge preflight','/functions/v1/tables',{method:'OPTIONS'});
assert.equal(preflight.status,200);checks.push(preflight);
for(const [kind,authorization] of [['missing',undefined],['forged','not-a-valid-user-jwt'],['publishable',key]]){
 for(const op of ['lobby','recover','revoke','sit','state','spin','history']){
  const r=await request(`Edge refuses ${kind} user credentials: ${op}`,'/functions/v1/tables',{body:{op},authorization});
  assert.ok([401,403].includes(r.status),JSON.stringify(r));checks.push(r);
 }
}
const rpc=await request('Public key cannot call world RPC','/rest/v1/rpc/casino_world',{body:{p:{action:'config'}}});
assert.equal(rpc.status,401);assert.equal(rpc.data.code,'42501');checks.push(rpc);
for(const [name,body] of [['buy_case',{p_case:'supply'}],['equip',{p_item:'hat:cap'}],['get_my_locker',{}],['import_local_save',{p_save:{}}],['set_username',{p_name:'StageProbe'}]]){
 const r=await request(`Legacy account RPC requires a signed-in user: ${name}`,`/rest/v1/rpc/${name}`,{body});
 assert.ok([401,403].includes(r.status),JSON.stringify(r));assert.equal(r.data.code,'28000',JSON.stringify(r));checks.push(r);
}
for(const table of ['casino_world_config','casino_rooms','casino_controllers','casino_ops','casino_ledger','casino_tables']){
 const r=await request(`Public key cannot read ${table}`,`/rest/v1/${table}?select=*&limit=1`);
 assert.ok((r.status===200&&Array.isArray(r.data)&&r.data.length===0)||([401,403].includes(r.status)&&r.data.code==='42501'),JSON.stringify(r));checks.push(r);
}
const result={time:new Date().toISOString(),project,mutations:false,checks};
if(process.env.STAGING_PROBE_OUTPUT)await writeFile(process.env.STAGING_PROBE_OUTPUT,JSON.stringify(result,null,2)+'\n');
console.log(JSON.stringify({project,checks:checks.length,passed:true,statuses:checks.map(({name,status})=>({name,status}))},null,2));
