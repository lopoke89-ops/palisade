/* ================= accounts and the cloud locker (Supabase) ================= */
// Everyone starts as a guest account, made quietly in the background, so the locker is backed up from the
// first case. Adding an email turns the guest into a full account that works on any device.
// Once an account exists the server owns the locker: cases are rolled there and rewards are checked there.
// This browser keeps a copy so the menu opens instantly and solo still plays with no signal.
// SB_KEY is Supabase's public "publishable" key. It can only do what the database's own rules allow.
const SB_URL='https://puvjfhwxigxjpsvdwrwf.supabase.co',SB_KEY='sb_publishable_xe3uY3icYguSM5pqlD7a1Q_7OD3B4v6';
const TURNSTILE_KEY='';   // Cloudflare Turnstile site key (public) once the robot check is switched on
const AUTH_KEY='palisade.auth.v1',GUEST_KEY='palisade.auth.guest',CLAIM_KEY='palisade.claims.v1';
const SITE_URL=location.origin+location.pathname;
const cloudOn=location.hostname==='lopoke89-ops.github.io'||/[?&]cloud=1\b/.test(location.search);
const acct={s:null,name:null,state:cloudOn?'wait':'off',msg:'',recovery:false,busy:false,t:0};
{const a=readJSON(AUTH_KEY);if(a.v&&a.v.access_token&&a.v.refresh_token)acct.s=a.v}
const isGuest=()=>!!(acct.s&&acct.s.user&&acct.s.user.is_anonymous);
const myUid=()=>acct.s&&acct.s.user?acct.s.user.id:acct.s?jwtSub(acct.s.access_token):null;
function jwtSub(t){try{return JSON.parse(atob(t.split('.')[1].replace(/-/g,'+').replace(/_/g,'/'))).sub||null}catch(e){return null}}
const needPw=()=>!!(acct.s&&acct.s.user&&!acct.s.user.is_anonymous&&acct.s.user.email&&!(acct.s.user.user_metadata||{}).pw);
function setSession(d){
  if(!d||!d.access_token){acct.s=null;try{localStorage.removeItem(AUTH_KEY)}catch(e){}return}
  const keepUser=acct.s&&acct.s.user&&acct.s.user.id===jwtSub(d.access_token)?acct.s.user:null;
  acct.s={access_token:d.access_token,refresh_token:d.refresh_token,expires_at:d.expires_at||Math.floor(Date.now()/1000)+(d.expires_in||3600),user:d.user||keepUser};
  try{localStorage.setItem(AUTH_KEY,JSON.stringify(acct.s))}catch(e){}
}
async function sbFetch(path,{method='GET',body,auth=true,timeout=9000,headers,keepalive=false}={}){
  const ctl=new AbortController(),to=setTimeout(()=>ctl.abort(),timeout),h={apikey:SB_KEY,'Content-Type':'application/json',...(headers||{})};
  if(auth&&acct.s)h.Authorization='Bearer '+acct.s.access_token;
  try{const r=await fetch(SB_URL+path,{method,headers:h,body:body===undefined?undefined:JSON.stringify(body),signal:ctl.signal,keepalive});
    const t=await r.text();let j=null;try{j=t?JSON.parse(t):null}catch(e){}
    return{ok:r.ok,status:r.status,j}}
  catch(e){return{ok:false,status:0,j:null}}finally{clearTimeout(to)}
}
function sbErr(r,fb){
  if(!r.status)return'Couldn\'t reach the account server. Check your signal and try again.';
  const j=r.j||{},m=j.message||j.msg||j.error_description||j.error||'',c=j.error_code||j.code||'';
  if(c==='email_exists'||/already been registered/i.test(m))return'That email already has an account. Sign in to it below instead.';
  if(c==='invalid_credentials'||/invalid login/i.test(m))return'That email and password don\'t match.';
  if(c==='email_not_confirmed'||/not confirmed/i.test(m))return'That email isn\'t confirmed yet. Open the link we sent, then sign in.';
  if(c==='weak_password'||/password should/i.test(m))return'Pick a longer password: at least 8 characters.';
  if(c==='same_password')return'That\'s already your password.';
  if(c==='over_email_send_rate_limit'||c==='over_request_rate_limit'||r.status===429)return'Too many tries. Wait a few minutes and try again.';
  if(/captcha/i.test(m))return'The robot check failed. Try again.';
  if(c==='validation_failed'&&/email/i.test(m))return'That doesn\'t look like an email address.';
  return m&&m.length<140?m:(fb||'Something went wrong. Try again.');
}
let refreshing=null;
function freshToken(){
  if(!acct.s)return Promise.resolve(false);
  if(acct.s.expires_at-Date.now()/1000>90)return Promise.resolve(true);
  return refreshing||(refreshing=(async()=>{
    const r=await sbFetch('/auth/v1/token?grant_type=refresh_token',{method:'POST',body:{refresh_token:acct.s.refresh_token},auth:false});
    refreshing=null;if(r.ok&&r.j&&r.j.access_token){setSession(r.j);return true}
    if(r.status===400||r.status===401||r.status===403)await endSession('Your sign-in ended. Sign in again to get your locker back.');
    return false})());
}
async function rpc(fn,args){
  if(!await freshToken())return{ok:false,status:acct.s?0:401,j:{message:'Sign in first.'}};
  let r=await sbFetch('/rest/v1/rpc/'+fn,{method:'POST',body:args||{}});
  if(r.status===401&&acct.s){acct.s.expires_at=0;if(await freshToken())r=await sbFetch('/rest/v1/rpc/'+fn,{method:'POST',body:args||{}})}
  return r;
}
// Cloudflare Turnstile: a robot check that is invisible unless it has doubts. Only loaded when it's switched on.
let tsLoad=null;
function captcha(){
  if(!TURNSTILE_KEY)return Promise.resolve(undefined);
  tsLoad=tsLoad||new Promise((res,rej)=>{const sc=document.createElement('script');sc.src='https://challenges.cloudflare.com/turnstile/v0/api.js?render=explicit';sc.async=true;
    sc.onload=()=>res();sc.onerror=()=>{tsLoad=null;sc.remove();rej(new Error('ts'))};document.head.append(sc)});
  return tsLoad.then(()=>new Promise((res,rej)=>{
    const box=$('capBox'),el=document.createElement('div');box.textContent='';box.append(el);box.hidden=false;
    const done=f=>x=>{box.hidden=true;box.textContent='';f(x)};
    window.turnstile.render(el,{sitekey:TURNSTILE_KEY,appearance:'interaction-only',theme:'dark',action:'auth',
      callback:done(res),'error-callback':done(()=>rej(new Error('ts'))),'timeout-callback':done(()=>rej(new Error('ts')))});
  }));
}
const withCap=async body=>{let t;try{t=await captcha()}catch(e){return null}if(t)body.gotrue_meta_security={captcha_token:t};return body};
const capFail={ok:false,status:400,j:{message:'The robot check didn\'t load. Try again.'}};

// ---- the locker copy on this device vs. the account's locker
const lockerFresh=L=>L.cases<=1&&!L.shards&&!L.prog&&Object.values(L.st).every(v=>!v)&&!Object.values(L.bag||{}).some(v=>v>0)&&L.owned.every(id=>COSBY[id]&&COSBY[id].src==='free');
function takeLocker(j){
  if(!j||!Array.isArray(j.owned)||!acct.s)return;
  const L=normLocker({owned:j.owned,eq:j.eq,cases:j.cases,bag:j.bag,shards:j.shards,prog:j.prog,st:j.st});
  L.cloud={id:myUid(),guest:isGuest()};locker=L;saveLocker();lockerNote='';
  if(!$('pg-locker').hidden&&$('caseOv').hidden)renderLocker();
  mainLabels();
}
async function syncLocker(){
  await flushClaims();
  // a result that just went through already brought the locker back; no need to ask again
  const r=lastClaimLocker&&Date.now()-lastClaimLocker.at<5000?{ok:true,j:lastClaimLocker.j}:await rpc('get_my_locker');if(!r.ok)return r;lastClaimLocker=null;
  let j=r.j;const L=locker,uid=myUid();
  // a save made on this device before it had an account, or a guest's locker when signing in to a real
  // account, is merged in once; the server refuses a second merge into the same account
  const mine=!L.cloud||(L.cloud.guest&&L.cloud.id!==uid);
  if(!j.imported&&mine&&!lockerFresh(L)){
    const im=await rpc('import_local_save',{p_save:{owned:L.owned,eq:L.eq,cases:L.cases,bag:L.bag,shards:L.shards,prog:L.prog,st:L.st}});
    if(im.ok)j=im.j;
  }else if(j.imported&&mine&&L.cloud&&!lockerFresh(L))acct.msg='This account already took in a guest locker once, so this device\'s guest items stay with the guest. Sign out to get back to them.';
  takeLocker(j);return r;
}
async function loadProfile(){
  const uid=myUid();if(!uid||!await freshToken())return;
  const u=await sbFetch('/auth/v1/user');if(u.ok&&u.j&&u.j.id){acct.s.user=u.j;setSession(acct.s)}
  const r=await sbFetch('/rest/v1/profiles?select=username&id=eq.'+encodeURIComponent(uid));
  if(r.ok&&Array.isArray(r.j)&&r.j[0])acct.name=r.j[0].username||null;
}

// ---- finished runs: the server checks each result and hands out the cases. Kept here until it answers.
let lastClaimLocker=null;
let claims=(()=>{const a=readJSON(CLAIM_KEY);return a.v&&Array.isArray(a.v.q)?a.v.q:[]})(),flushing=null,flushT=0,flushWhy='';
function saveClaims(){try{localStorage.setItem(CLAIM_KEY,JSON.stringify({q:claims.slice(-8)}))}catch(e){}}
function queueClaim(c){
  if(!locker.cloud)return null;const q={...c,uid:locker.cloud.id,at:Date.now()};claims.push(q);saveClaims();game.claimAt=q.at;
  flushClaims().then(()=>{if(claims.includes(q)&&game.claimAt===q.at&&game.phase==='over')$('overLoot').textContent=flushWhy==='wait'?'Saving to your account in a few seconds…':flushWhy==='later'?'Kept on this device. It saves to your account in a few minutes (results can\'t add up to more play time than real time).':'No connection right now. Your result is kept on this device and reaches your account when you\'re back online.'});
  return {kind:c.kind,pending:true,cases:{},shards:0,unlocked:[],text:'Sending your result to your account…'};
}
function flushClaims(){
  if(flushing)return flushing;if(!claims.length||!acct.s)return Promise.resolve();
  const run=async()=>{
    while(claims.length&&acct.s){
      const c=claims[0];
      if(c.uid!==myUid()||Date.now()-c.at>30*864e5){claims.shift();saveClaims();continue}
      const{uid,at,...p}=c,r=await rpc('claim_match_reward',{p});
      if(r.ok){claims.shift();saveClaims();takeLocker(r.j.locker);lastClaimLocker={j:r.j.locker,at:Date.now()};
        const dropped=c.kind==='match'&&r.j.cases_granted>0||c.kind==='run'&&r.j.bonus&&r.j.bonus.n>0;
        claimShow(c,claimReward(c,r.j),dropped?'CASE DROP':'REWARDS SAVED');if(dropped)uiSfx('kx_confetti');continue}
      if(!r.status||r.status>=500||r.status===401){flushWhy='offline';break}
      if(/moment ago/.test(sbErr(r))){flushWhy='wait';clearTimeout(flushT);flushT=setTimeout(flushClaims,21000);break}
      if(/saved later/.test(sbErr(r))){flushWhy='later';clearTimeout(flushT);flushT=setTimeout(flushClaims,5*60e3);break}   // play-time budget: keep it, the server takes it once enough real time has passed
      claims.shift();saveClaims();       // refused for good: say so plainly instead of letting a reward quietly vanish
      claimShow(c,`The server didn't accept that result (${sbErr(r)}). Nothing was added.`,'NOT SAVED');
    }};
  return flushing=run().catch(()=>{}).finally(()=>{flushing=null});
}

// ---- starting up, and coming back to the app
async function acctBoot(){
  if(!cloudOn||acct.booting)return;acct.booting=true;
  try{await boot1()}finally{acct.booting=false;renderAcct()}
}
async function boot1(){
  readAuthHash();
  acct.state='wait';renderAcct();
  if(!acct.s){const g=readJSON(GUEST_KEY);if(g.v&&g.v.refresh_token){setSession({...g.v,expires_at:1});try{localStorage.removeItem(GUEST_KEY)}catch(e){}}}
  if(!acct.s){const r=await makeGuest();if(!r.ok){acct.state='down';if(r.status)acct.msg=sbErr(r);renderAcct();return}}
  const[r]=await Promise.all([syncLocker(),loadProfile()]);
  if(!acct.s){acct.state='down';renderAcct();return}      // the saved sign-in had ended
  if(!r.ok){acct.state='down';acct.msg=r.status?sbErr(r):'';renderAcct();return}
  acct.state=isGuest()?'guest':'full';acct.t=Date.now();renderAcct();
  if(acct.recovery||acct.hashMsg){showPage('account');acct.hashMsg=false}
}
function acctResume(){
  if(!cloudOn||acct.busy||Date.now()-acct.t<120000)return;acct.t=Date.now();
  if(acct.state==='down')acctBoot();else if(acct.state==='guest'||acct.state==='full')syncLocker().then(()=>renderAcct());
}
async function makeGuest(){
  const body=await withCap({data:{}});if(!body)return capFail;
  const r=await sbFetch('/auth/v1/signup',{method:'POST',body,auth:false});
  if(r.ok&&r.j&&r.j.access_token)setSession(r.j);else if(r.ok)return{ok:false,status:400,j:{message:'Guest accounts are switched off.'}};
  return r;
}
// the links in our emails come back to the game with the new sign-in in the address
function readAuthHash(){
  const h=location.hash.slice(1);if(!/(^|&)(access_token|error_description|error)=/.test(h))return;
  const q=new URLSearchParams(h);try{history.replaceState(null,'',location.pathname+location.search)}catch(e){}
  acct.hashMsg=true;
  if(!q.get('access_token')){acct.msg=(q.get('error_description')||'That link didn\'t work.')+'. Links only work once and expire after an hour; ask for a new one.';acct.msg=acct.msg.replace(/\.\./g,'.');return}
  const type=q.get('type')||'';keepGuest(jwtSub(q.get('access_token')));
  setSession({access_token:q.get('access_token'),refresh_token:q.get('refresh_token'),expires_at:+q.get('expires_at')||0,expires_in:+q.get('expires_in')||3600});
  if(type==='recovery'){acct.recovery=true;acct.msg='Choose a new password.'}
  else acct.msg='Email confirmed.';
}
// switching from a guest to a full account keeps the guest's sign-in, so signing out returns to it
function keepGuest(newUid){if(isGuest()&&acct.s.user.id!==newUid)try{localStorage.setItem(GUEST_KEY,JSON.stringify(acct.s))}catch(e){}}
async function endSession(msg){
  setSession(null);acct.name=null;acct.recovery=false;acct.state='down';if(msg)acct.msg=msg;
  locker=normLocker(null);saveLocker();claims=[];saveClaims();
  if(!$('pg-locker').hidden&&$('caseOv').hidden)renderLocker();
}

// ---- the account page
function mainLabels(){
  const lb=$('navLocker'),n=allCases();if(lb)lb.textContent=n?`LOCKER · ${n}`:'LOCKER';
  renderIdentity();   // the account button (top right) shows who you are and whether the account is saved
}
function renderAcct(){
  mainLabels();if($('pg-account').hidden)return;
  const st=acct.state,g=isGuest(),u=acct.s&&acct.s.user,live=st==='guest'||st==='full';
  // the profile header: your figure, your name and where your locker lives
  $('acName').textContent=$('identityName').textContent;$('acState').textContent=$('identityState').textContent;
  const av=$('acAvatar'),key=cosStr(locker.eq)+'|'+pick.cls;if(av.dataset.look!==key){av.dataset.look=key;const x=av.getContext('2d');x.clearRect(0,0,160,160);drawFig(x,160,160,lookOf(locker.eq,pick.cls),3.6,{x:.8,y:.3},152)}
  $('aLede').textContent=
    st==='off'?'This preview uses a local profile. Open the live site to sign in and sync your account.':
    st==='wait'?'Connecting to your account…':
    st==='down'?(acct.s?'Can\'t reach the account server right now. You can still play: finished runs are sent when you\'re back online, and opening cases waits for a connection.':'No account yet. Your locker is saved in this browser, and it moves into your account once one is made.'):
    g?'You\'re playing as a guest. Your locker is backed up online, but only this browser can get back into it. Add an email to keep it on any device, or sign in to an account you already have.':
    `Signed in${acct.name?' as '+acct.name:''}${u&&u.email?' · '+u.email:''}. Your locker is saved to your account and follows you to any device you sign in on.`;
  $('aStatus').textContent=acct.msg||'';
  $('aRetry').hidden=st!=='down';
  $('aNameBox').hidden=!live||acct.recovery;
  $('aLinkBox').hidden=!(live&&g);
  const pw=live&&!g&&(acct.recovery||needPw());$('aPwBox').hidden=!pw;
  if(pw){$('aPwHead').textContent=acct.recovery?'NEW PASSWORD':'SET A PASSWORD';$('aPwMail').value=u&&u.email||''}
  $('aInBox').hidden=!(st==='guest'||st==='down'&&!acct.s);
  $('aOut').hidden=!(live&&!g);
  if(document.activeElement!==$('aUser'))$('aUser').value=acct.name||'';
  for(const b of $('pg-account').querySelectorAll('button:not([data-go]),input'))b.disabled=acct.busy||st==='wait';
}
async function acctDo(fn){
  if(acct.busy)return;acct.busy=true;acct.msg='';renderAcct();
  try{acct.msg=await fn()||''}catch(e){acct.msg='Something went wrong. Try again.'}
  acct.busy=false;renderAcct();
}
$('aRetry').addEventListener('click',()=>{acct.msg='';acctBoot()});
$('aNameBox').addEventListener('submit',e=>{e.preventDefault();const n=$('aUser').value.trim();
  if(!/^[A-Za-z0-9_]{3,16}$/.test(n)){acct.msg='Usernames are 3 to 16 letters, numbers or _.';renderAcct();return}
  acctDo(async()=>{const r=await rpc('set_username',{p_name:n});if(!r.ok)return sbErr(r);
    acct.name=n;if(!(cfg.name||'').trim()){cfg.name=n.slice(0,12);saveCfg();applyCfg()}return'Username saved.'})});
$('aLinkBox').addEventListener('submit',e=>{e.preventDefault();const m=$('aLinkMail').value.trim();
  if(!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(m)){acct.msg='That doesn\'t look like an email address.';renderAcct();return}
  acctDo(async()=>{if(!await freshToken())return sbErr({status:0});
    const r=await sbFetch('/auth/v1/user?redirect_to='+encodeURIComponent(SITE_URL),{method:'PUT',body:{email:m}});
    if(!r.ok)return sbErr(r);return`Link sent to ${m}. Open it on any device (check spam too), then choose a password there.`})});
$('aPwBox').addEventListener('submit',e=>{e.preventDefault();const pw=$('aPwIn').value;
  if(pw.length<8){acct.msg='Pick a longer password: at least 8 characters.';renderAcct();return}
  acctDo(async()=>{if(!await freshToken())return sbErr({status:0});
    const r=await sbFetch('/auth/v1/user',{method:'PUT',body:{password:pw,data:{pw:1}}});
    if(!r.ok)return sbErr(r);if(r.j&&r.j.id){acct.s.user=r.j;setSession(acct.s)}
    acct.recovery=false;$('aPwIn').value='';return'Password saved. Sign in with your email and this password on any device.'})});
$('aInBox').addEventListener('submit',e=>{e.preventDefault();const m=$('aInMail').value.trim(),pw=$('aInPw').value;
  if(!m||!pw){acct.msg='Enter your email and password.';renderAcct();return}
  acctDo(async()=>{const body=await withCap({email:m,password:pw});if(!body)return sbErr(capFail);
    const r=await sbFetch('/auth/v1/token?grant_type=password',{method:'POST',body,auth:false});
    if(!r.ok||!r.j||!r.j.access_token)return sbErr(r);
    keepGuest(r.j.user&&r.j.user.id);setSession(r.j);acct.name=null;$('aInPw').value='';
    if(!(r.j.user.user_metadata||{}).pw)sbFetch('/auth/v1/user',{method:'PUT',body:{data:{pw:1}}});
    const s=await syncLocker();await loadProfile();acct.state='full';
    return s.ok?(acct.msg||'Signed in. Your locker is loaded.'):'Signed in, but your locker didn\'t load yet. It will when you\'re back online.'})});
$('aForgot').addEventListener('click',()=>{const m=$('aInMail').value.trim();
  if(!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(m)){acct.msg='Type your email above first, then tap Forgot password.';renderAcct();return}
  acctDo(async()=>{const body=await withCap({email:m});if(!body)return sbErr(capFail);
    const r=await sbFetch('/auth/v1/recover?redirect_to='+encodeURIComponent(SITE_URL),{method:'POST',body,auth:false});
    if(!r.ok)return sbErr(r);return`If ${m} has an account, a reset link is on its way. Open it, then choose a new password.`})});
$('aOut').addEventListener('click',()=>acctDo(async()=>{
  if(await freshToken())await sbFetch('/auth/v1/logout?scope=local',{method:'POST'});
  await endSession('');acct.busy=false;await acctBoot();acct.busy=true;return'Signed out. Sign back in any time to get your locker.'}));
addEventListener('online',()=>{acct.t=0;acctResume()});
document.addEventListener('visibilitychange',()=>{if(!document.hidden)acctResume()});

/* ---------- open games list ---------- */
// Hosts who tick "List my game" publish their room code to Supabase every 15 s while the room is open; the
// Multiplayer page lists rooms heard from in the last 45 s that run this same version. Joining is the usual
// room-code join, so the game itself still goes phone to phone.
const MODE_NAME={coop:'CO-OP',base:'BASE BATTLE',ffa:'FREE-FOR-ALL'},LEN_NAME={'5':'5 RAIDS','10':'10 RAIDS',endless:'ENDLESS'};
let lobTimer=0,lobBusy=false,pubTimer=0;
const listing=()=>cloudOn&&cfg.listGame!==false;
async function lobbyPublish(){
  if(!listing()||NET.mode!=='host'||!NET.code||!acct.s||!await freshToken())return;
  const coop=(pick.pvp||'coop')==='coop',n=NET.inGame&&!demo?players.size:NET.roster.length;
  const body={host_id:myUid(),code:NET.code,name:cleanChat(`${myName()}'s game`).slice(0,24)||'Open game',mode:pick.pvp||'coop',
    length:coop?pick.mode:null,diff:coop?pick.diff:null,players:Math.max(1,Math.min(6,n)),in_game:!!NET.inGame,proto:PROTO};
  await sbFetch('/rest/v1/lobbies',{method:'POST',body,headers:{Prefer:'resolution=merge-duplicates,return=minimal'}});
}
function lobbyUnpublish(){clearInterval(pubTimer);pubTimer=0;if(!cloudOn||!acct.s)return;
  sbFetch('/rest/v1/lobbies?host_id=eq.'+encodeURIComponent(myUid()),{method:'DELETE',keepalive:true})}
function lobbyStartPublishing(){clearInterval(pubTimer);if(!listing())return;lobbyPublish();pubTimer=setInterval(lobbyPublish,15000)}
async function refreshLobbies(){
  // the list is only rebuilt when what it would show changed (it refreshes every 6 s)
  const box=$('lobList'),same=k=>{if(box.dataset.k===k)return true;box.dataset.k=k;return false},
    say=t=>{if(same('say:'+t))return;box.textContent='';const p=document.createElement('p');p.className='lobEmpty';p.textContent=t;box.append(p)};
  if(!cloudOn){say('The Open Games list works on the web version of the game.');return}
  if(!acct.s){say(acct.state==='down'?'Can\'t reach the game server right now, so the list is empty. Joining by code still works.':'Connecting…');return}
  if(lobBusy)return;lobBusy=true;
  let r={ok:false,status:0};if(await freshToken())r=await sbFetch(`/rest/v1/lobbies?select=code,name,mode,length,diff,players,in_game&proto=eq.${PROTO}&order=updated_at.desc&limit=30`);
  lobBusy=false;
  if(!r.ok||!Array.isArray(r.j)){say('Couldn\'t load the list. Joining by code still works.');return}
  const rows=r.j.filter(g=>g.code!==NET.code);
  if(!rows.length){say('No open games right now. Host one and it shows up here for everyone.');return}
  if(same(NET.mode+JSON.stringify(rows)))return;
  box.textContent='';
  for(const g of rows){const b=document.createElement('button');b.type='button';b.className='lob';
    const nm=document.createElement('b');nm.textContent=g.name;
    const d=document.createElement('span');d.textContent=[MODE_NAME[g.mode]||g.mode,g.mode==='coop'&&g.length?LEN_NAME[g.length]:'',g.mode==='coop'&&g.diff?g.diff.toUpperCase():'',g.in_game?'IN PROGRESS':'IN LOBBY'].filter(Boolean).join(' · ');
    const c=document.createElement('i');c.textContent=`${g.players}/6`;
    b.append(nm,c,d);b.disabled=g.players>=6||NET.mode!=='solo';b.setAttribute('aria-label',`Join ${g.name}, ${d.textContent}, ${g.players} of 6 players`);
    b.addEventListener('click',()=>{initAudio();$('mCode').value=g.code;netJoin(g.code)});box.append(b)}
}
function lobbyBrowse(on){clearInterval(lobTimer);lobTimer=0;if(!on)return;refreshLobbies();lobTimer=setInterval(()=>{if($('pg-multi').hidden||$('menu').hidden){lobbyBrowse(false);return}refreshLobbies()},6000)}
addEventListener('pagehide',()=>{if(NET.mode==='host')lobbyUnpublish()});

