// Exercise the actual client heartbeat, including rotation by a different account request.
const assert=require('node:assert/strict'),fs=require('node:fs'),vm=require('node:vm');
const source=fs.readFileSync(__dirname+'/../src/js/21a-casino-relay.js','utf8');
function fixture(){
 let now=1000;const packets=[],listeners={},session={access_token:'new-fixture-token',expires_at:4e9},sock={readyState:1,bufferedAmount:0,send:s=>packets.push(JSON.parse(s)),close(){this.readyState=3}};
 const context={console,Date,performance:{now:()=>now},WebSocket:{OPEN:1,CONNECTING:0},setTimeout,clearTimeout,setInterval,clearInterval,
  acct:{s:session},myUid:()=> 'fixture-user',freshToken:async()=>true,netLeave:()=>{throw new Error('Unexpected account logout')},
  document:{hidden:false,addEventListener:(k,f)=>listeners[k]=f},addEventListener:(k,f)=>listeners[k]=f};
 vm.createContext(context);const api=vm.runInContext(source+'\n({RLY,rlyHeartbeat,rlyDisconnect})',context);
 Object.assign(api.RLY,{active:true,connected:true,owner:'fixture-user',ws:sock,authToken:'old-fixture-token'});
 return {...api,packets,context,sock,listeners,advance:ms=>now+=ms};
}
(async()=>{
 const checks=[],ok=(name,b)=>{assert.ok(b,name);checks.push(name)};
 {const f=fixture();await f.rlyHeartbeat();ok('a token already refreshed by table polling is sent despite its distant expiry',f.packets.some(p=>p.type==='token'&&p.token==='new-fixture-token'));
  const sent=f.packets.filter(p=>p.type==='token').length;await f.rlyHeartbeat();ok('verification in flight is not flooded',f.packets.filter(p=>p.type==='token').length===sent);
  f.advance(10001);await f.rlyHeartbeat();ok('a missing acknowledgement retries the token',f.packets.filter(p=>p.type==='token').length===sent+1);
  f.RLY.authToken=f.RLY.pendingToken;f.RLY.pendingToken='';await f.rlyHeartbeat();ok('an acknowledged token is not repeatedly sent',f.packets.filter(p=>p.type==='token').length===sent+1)}
 {const f=fixture();f.RLY.authToken=f.context.acct.s.access_token;f.context.acct.s.expires_at=1;f.context.freshToken=async()=>{f.context.acct.s={access_token:'heartbeat-refreshed-token',expires_at:4e9};return true};await f.rlyHeartbeat();ok('heartbeat-triggered refresh also updates the relay',f.packets.some(p=>p.token==='heartbeat-refreshed-token'))}
 {const f=fixture();f.context.freshToken=async()=>false;await f.rlyHeartbeat();ok('temporary Auth failure does not close a working connection',f.RLY.active&&f.RLY.connected&&f.packets.every(p=>p.type==='ping'))}
 {const f=fixture();let release;f.context.freshToken=()=>new Promise(r=>release=r);const work=f.rlyHeartbeat();await f.rlyHeartbeat();ok('concurrent heartbeat skips duplicate refresh work',f.RLY.refreshing&&f.packets.every(p=>p.type==='ping'));f.RLY.ws={readyState:1};release(true);await work;ok('a refresh completing on an old socket cannot send to the new connection',f.packets.every(p=>p.type==='ping'))}
 {const f=fixture();f.RLY.connected=false;await f.rlyHeartbeat();ok('a disconnected socket is not reauthenticated by heartbeat',f.packets.every(p=>p.type==='ping'))}
 {const f=fixture();await f.rlyHeartbeat();f.rlyDisconnect();ok('logout clears relay token tracking',!f.RLY.authToken&&!f.RLY.pendingToken&&!f.RLY.active)}
 fs.mkdirSync(__dirname+'/out',{recursive:true});fs.writeFileSync(__dirname+'/out/casino_relay_auth.json',JSON.stringify({checks},null,2));console.log(checks.length+' checks; errors: none');
})().catch(e=>{console.error(e);process.exit(1)});
