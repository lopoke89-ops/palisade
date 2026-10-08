// Real saved-account sessions for the isolated casino test project. Never logs credentials.
const assert=require('node:assert/strict'),fs=require('node:fs');
const project='nxsqerlpqdzrjwqxhsdz',url=`https://${project}.supabase.co`,key='sb_publishable_m1R1Frx4Te72Yl2qrINhKQ_VxV02RvV';
async function refresh(account){
 assert.ok(account.email.endsWith('@example.test')&&account.password&&account.id,'Only disposable saved staging accounts');
 const request=async(grant,body)=>{for(let attempt=0;attempt<3;attempt++){
  const r=await fetch(url+'/auth/v1/token?grant_type='+grant,{method:'POST',headers:{apikey:key,'Content-Type':'application/json'},body:JSON.stringify(body),signal:AbortSignal.timeout(20000)}),data=await r.json();
  if(r.status!==429||attempt===2)return {status:r.status,data};
  await new Promise(resolve=>setTimeout(resolve,Math.max(60000,Number(r.headers.get('retry-after'))*1000||0)));
 }};
 let r=account.session?.refresh_token?await request('refresh_token',{refresh_token:account.session.refresh_token}):null;
 if(!r||r.status!==200)r=await request('password',{email:account.email,password:account.password});
 assert.equal(r.status,200,'Staging sign-in refused: '+r.status);assert.equal(r.data.user?.id,account.id);assert.equal(r.data.user?.is_anonymous,false);
 const user=await fetch(url+'/auth/v1/user',{headers:{apikey:key,Authorization:'Bearer '+r.data.access_token},signal:AbortSignal.timeout(20000)});
 assert.equal(user.status,200);assert.equal((await user.json()).id,account.id);account.session=r.data;
}
async function refreshFile(file){const data=JSON.parse(fs.readFileSync(file,'utf8'));assert.equal(data.project,project);for(const u of data.users){
 if(u.session?.user?.id!==u.id||u.session.expires_at*1000<Date.now()+1800000){await refresh(u);fs.writeFileSync(file,JSON.stringify(data,null,2)+'\n');await new Promise(r=>setTimeout(r,3000));}
 }return data;}
module.exports={project,url,key,refresh,refreshFile};
if(require.main===module){assert.equal(process.env.PALISADE_LIVE_STAGING,'1');refreshFile(process.env.STAGING_ACCOUNTS_FILE||__dirname+'/out/staging-accounts.json').then(d=>console.log(JSON.stringify({project,accounts:d.users.length,realSessionsRefreshed:true,credentialsPrinted:false}))).catch(e=>{console.error(e.message);process.exitCode=1});}
