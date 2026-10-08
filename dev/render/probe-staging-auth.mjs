// Authenticated read/access checks for disposable saved accounts in isolated staging.
// Credentials and session tokens stay in the ignored caller-supplied fixture file.
import assert from 'node:assert/strict';
import {readFile,writeFile} from 'node:fs/promises';

const project='nxsqerlpqdzrjwqxhsdz';
const url=process.env.SUPABASE_URL;
const key=process.env.SUPABASE_PUBLISHABLE_KEY;
assert.equal(url,`https://${project}.supabase.co`,'Probe must target isolated staging');
assert.ok(key?.startsWith('sb_publishable_'),'Supply the staging publishable key');
assert.ok(process.env.STAGING_ACCOUNTS_FILE,'Supply an ignored disposable-account fixture file');
const credentialsPath=process.env.STAGING_ACCOUNTS_FILE;
const credentials=JSON.parse(await readFile(credentialsPath,'utf8'));
assert.equal(credentials.project,project);
assert.ok(credentials.users.length>0&&credentials.users.length<=7,'Initial access probe accepts one to seven fixtures');
const checks=[];
async function request(path,body,token){
 const headers={apikey:key,'Content-Type':'application/json'};
 if(token)headers.Authorization='Bearer '+token;
 const response=await fetch(url+path,{method:body?'POST':'GET',headers,body:body?JSON.stringify(body):undefined,signal:AbortSignal.timeout(20000)});
 return {status:response.status,data:await response.json()};
}
for(const account of credentials.users){
 assert.ok(account.email.endsWith('@example.test'),'Fixtures must use reserved test email addresses');
 const login=await request('/auth/v1/token?grant_type=password',{email:account.email,password:account.password});
 assert.equal(login.status,200,`Sign-in failed with ${login.status}: ${login.data.error_code||login.data.code||'unknown'}`);
 assert.equal(login.data.user?.id,account.id);assert.equal(login.data.user?.is_anonymous,false);
 const verified=await request('/auth/v1/user',undefined,login.data.access_token);
 assert.equal(verified.status,200);assert.equal(verified.data.id,account.id);
 const wallet=await request('/rest/v1/rpc/get_my_locker',{},login.data.access_token);
 assert.equal(wallet.status,200);assert.equal(wallet.data.shards,5000,'Initial disposable wallet must have 5000 shards');
 const lobby=await request('/functions/v1/tables',{op:'lobby'},login.data.access_token);
 assert.equal(lobby.status,200);assert.equal(lobby.data.balance,5000);
 const privateRpc=await request('/rest/v1/rpc/casino_world',{p:{action:'config'}},login.data.access_token);
 assert.equal(privateRpc.status,403);assert.equal(privateRpc.data.code,'42501');
 const rawTable=await request('/rest/v1/casino_world_config?select=*&limit=1',undefined,login.data.access_token);
 assert.equal(rawTable.status,403);assert.equal(rawTable.data.code,'42501');
 account.session=login.data;
 checks.push({uid:account.id,login:login.status,verifiedUser:verified.status,wallet:wallet.status,edgeLobby:lobby.status,initialShards:wallet.data.shards,privateRpc:privateRpc.status,rawCasinoTable:rawTable.status});
 await writeFile(credentialsPath,JSON.stringify(credentials,null,2)+'\n');
}
const result={time:new Date().toISOString(),project,fixtureSeed:credentials.seed,accounts:checks.length,checksPerAccount:6,credentialsInEvidence:false,checks};
if(process.env.STAGING_AUTH_PROBE_OUTPUT)await writeFile(process.env.STAGING_AUTH_PROBE_OUTPUT,JSON.stringify(result,null,2)+'\n');
console.log(JSON.stringify({project,accounts:checks.length,checks:checks.length*6,passed:true,credentialsPrinted:false}));
