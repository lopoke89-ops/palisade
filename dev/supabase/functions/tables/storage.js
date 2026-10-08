// The same transaction adapter for Deno player requests and Node recovery. No casino math here.
export const failed=m=>/duplicate op/.test(m)?{dup:true}:/insufficient/.test(m)?{error:'insufficient'}:/seated elsewhere/.test(m)?{error:'seated'}:{error:m};
export function managedStorage(D,rpc){
 D.world=p=>rpc('casino_world',{p});
 D.withManaged=(uid,body)=>{
  const guard={uid,op:body.op,session:body.controller?.session,generation:body.controller?.generation,
   wager:!['state','leave','pick','seed','ready','rlready'].includes(body.op),sit:body.op==='sit',
   ...(body.op==='sit'?{reservation:body.reservation,owner:body.controller?.owner,epoch:body.controller?.epoch}:{})};
  const wrap=g=>({...D,managed:true,request:body,
   commit:a=>commit(rpc,a,g),create:a=>create(rpc,a,g),afterCreate:()=>wrap({...g,sit:false,reservation:undefined})});
  return wrap(guard);
 };
 return D;
}
export async function commit(rpc,a,guard){try{return await rpc('casino_managed_step',{p_table:a.id,p_ver:a.ver,p_st:a.st,p_humans:a.humans,p_open:a.open,p_ops:a.ops,p_hands:a.hands,p_op:a.op,p_guard:guard})}catch(e){return failed(e.message)}}
export async function create(rpc,a,guard){try{return await rpc('casino_managed_start',{p_code:a.code,p_game:a.game,p_st:a.st,p_humans:a.humans,p_ops:a.ops,p_room:a.room,p_station:a.station||'',p_op:a.op,p_guard:guard})}catch(e){return failed(e.message)}}
export function restStorage(url,key){
 if(!url||!key)throw new Error('SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY are required');
 const request=async(path,body,token=key,method=body?'POST':'GET')=>{
  const headers={apikey:key,'Content-Type':'application/json'};
  // Modern server keys are opaque API keys, not user JWTs. Keep user tokens in Authorization.
  if(token&&!(token===key&&key.startsWith('sb_secret_')))headers.Authorization='Bearer '+token;
  const r=await fetch(url+path,{method,headers,body:body?JSON.stringify(body):undefined,signal:AbortSignal.timeout(10000)});
  // Successful PostgREST RETURNS void RPCs have no body (HTTP 204).
  const j=r.status===204?null:await r.json();if(!r.ok)throw new Error(j?.message||j?.msg||'Database request failed');return j;
 };
 const rpc=(name,p={})=>request('/rest/v1/rpc/'+name,p);
 const rows=(table,q)=>request('/rest/v1/'+table+'?'+new URLSearchParams(q));
 const first=async(table,q)=>(await rows(table,q))[0]||null;
 const D={now:()=>Date.now(),rpc,rows,request,
  auth:async token=>{if(typeof token!=='string'||!token)return null;try{const u=await request('/auth/v1/user',null,token);return {id:u.id,anon:!!u.is_anonymous}}catch{return null}},
  name:async uid=>(await first('profiles',{select:'username',id:'eq.'+uid}))?.username||'PLAYER',
  balance:async uid=>(await first('lockers',{select:'shards',user_id:'eq.'+uid}))?.shards||0,
  load:id=>first('casino_tables',{select:'id,code,game,st,ver,open,room,station',id:'eq.'+id}),
  byRoom:(room,game,station)=>first('casino_tables',{select:'id,code',room:'eq.'+room,game:'eq.'+game,station:'eq.'+(station||''),open:'eq.true'}),
  seatOf:uid=>first('casino_tables',{select:'id,code,game,room,station',humans:'cs.{'+uid+'}',open:'eq.true',limit:1}),
  opGet:(uid,id)=>first('casino_ops',{select:'req,table_id,res',user_id:'eq.'+uid,op_id:'eq.'+id}),
  history:(uid,n)=>rows('casino_hands',{select:'id,table_id,game,hand_no,hash,salt,deck,result,created_at','result->players':'cs.'+JSON.stringify([{uid}]),order:'id.desc',limit:n}),
  books:()=>rpc('casino_books_run'),botLeft:()=>rpc('casino_bot_left'),
  stale:ms=>rows('casino_tables',{select:'id',open:'eq.true',updated_at:'lt.'+new Date(Date.now()-ms).toISOString(),limit:10}),
  commit:async a=>{try{return await rpc('casino_step',{p_table:a.id,p_ver:a.ver,p_st:a.st,p_humans:a.humans,p_open:a.open,p_ops:a.ops,p_hands:a.hands,p_op:a.op})}catch(e){return failed(e.message)}},
  create:async a=>{try{return await rpc('casino_start',{p_code:a.code,p_game:a.game,p_st:a.st,p_humans:a.humans,p_ops:a.ops,p_room:a.room,p_station:a.station||'',p_op:a.op})}catch(e){return failed(e.message)}}};
 return managedStorage(D,rpc);
}
