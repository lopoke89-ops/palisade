// Exercise the adapter over HTTP with both server-key formats and separate user authentication.
const http=require('node:http'),assert=require('node:assert/strict');
(async()=>{
 const {restStorage}=await import('../supabase/functions/tables/storage.js');
 const modern='sb_secret_disposable_fixture',legacy='ey.fixture.service_role',userToken='ey.fixture.user',uid='11111111-1111-4111-8111-111111111111';
 const seen=[];
 const server=http.createServer(async(req,res)=>{
  let text='';for await(const b of req)text+=b;const body=text?JSON.parse(text):null;
  const key=req.headers.apikey,auth=req.headers.authorization;seen.push({path:req.url,key,auth,body});
  const out=(status,data)=>{res.writeHead(status,{'Content-Type':'application/json'});res.end(JSON.stringify(data))};
  if(![modern,legacy].includes(key))return out(401,{message:'Invalid API key'});
  if(req.url==='/auth/v1/user')return auth==='Bearer '+userToken?out(200,{id:uid,is_anonymous:false}):out(401,{message:'Invalid user JWT'});
  if(req.url==='/rest/v1/rpc/casino_world'){
   const allowed=key===modern?!auth:auth==='Bearer '+legacy;
   return allowed?out(200,{revision:1,action:body.p.action}):out(401,{message:'Invalid JWT'});
  }
  // PostgREST returns HTTP 204 with no JSON for successful RETURNS void functions.
  if(['/rest/v1/rpc/casino_recovery_idle','/rest/v1/rpc/casino_recovery_backoff'].includes(req.url)){
   res.writeHead(204);return res.end();
  }
  if(req.url==='/rest/v1/rpc/malformed_fixture'){res.writeHead(200,{'Content-Type':'application/json'});return res.end('{');}
  return out(404,{message:'Unknown fixture route'});
 });
 await new Promise(r=>server.listen(0,'127.0.0.1',r));
 try{
  for(const key of [modern,legacy]){
   const D=restStorage('http://127.0.0.1:'+server.address().port,key);
   assert.deepEqual(await D.world({action:'config'}),{revision:1,action:'config'});
   assert.equal(await D.rpc('casino_recovery_idle',{p_table:1}),null,'Successful void RPC is not a failed recovery');
   assert.equal(await D.rpc('casino_recovery_backoff',{p_table:1}),null,'Successful backoff has no response body');
   await assert.rejects(D.rpc('malformed_fixture'),SyntaxError,'A malformed non-void result is still refused');
   assert.deepEqual(await D.auth(userToken),{id:uid,anon:false});
   assert.equal(await D.auth('forged-user'),null);
   const count=seen.length;assert.equal(await D.auth(),null);assert.equal(await D.auth(''),null);assert.equal(seen.length,count,'missing user token never falls back to server identity');
  }
  assert.equal(seen.filter(r=>r.path==='/auth/v1/user'&&r.auth==='Bearer '+userToken).length,2);
  assert.equal(seen.some(r=>r.auth==='Bearer '+modern),false,'opaque server key never becomes a bearer JWT');
  const bad=restStorage('http://127.0.0.1:'+server.address().port,'sb_secret_wrong_fixture');
  await assert.rejects(bad.world({action:'config'}),/Invalid API key/);
  console.log({modernServerKey:'RPC access with apikey only',legacyServerKey:'compatible',userAuth:'distinct JWT; forged and missing refused',invalidServerKey:'refused',voidRpc:'HTTP 204 accepted; malformed non-void JSON refused'});
  console.log('errors: none');
 }finally{await new Promise(r=>server.close(r));}
})().catch(e=>{console.error(e);process.exit(1)});
