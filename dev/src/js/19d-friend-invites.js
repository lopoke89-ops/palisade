/* Authenticated invitation flow. Peer hello also checks the room incarnation. */
async function registerInviteRoom(){
 if(!socialAccount()||NET.mode!=='host'||!NET.code||!NET.incarnation)return;
 const uid=myUid(),inc=NET.incarnation,code=NET.code;
 if(!await freshToken()||uid!==myUid()||NET.mode!=='host'||inc!==NET.incarnation)return;
 return rpc('room_register',{p:{incarnation:inc,code,proto:PROTO,mode:pick.pvp||'coop',length:pick.mode,map:NET.inGame&&!demo?game.map:pick.mode==='campaign'?'yard':pick.map,
   chapter:NET.inGame&&!demo?game.chapter||0:0,players:NET.roster.length,locked:NET.roomLocked}});
}
const canInviteFriend=()=>socialAccount()&&NET.mode==='host'&&!!NET.code&&!NET.roomLocked&&NET.roster.length<6;
async function inviteFriend(f){
 if(!canInviteFriend()||FR.busy)return;const owner=myUid(),epoch=FR.accountEpoch,inc=NET.incarnation,current=()=>owner===myUid()&&epoch===FR.accountEpoch;FR.busy=true;FR.msg='';renderSocial();
 try{const reg=await registerInviteRoom();if(!current()||inc!==NET.incarnation)return;if(!reg?.ok){FR.msg='Your room could not be registered. Try again.';return}
   const r=await rpc('lobby_invite_send',{p_to:f.id});if(!current()||inc!==NET.incarnation)return;FR.msg=r.ok?(r.j.duplicate?'An active invitation is already waiting.':`Invitation sent to ${f.username}. Valid for five minutes.`):sbErr(r);
 }finally{if(current()){FR.busy=false;await friendsPoll();if(owner===myUid())renderSocial()}}
}
async function answerInvite(i,yes){
 if(!socialAccount()||FR.busy)return;
 const leaving=inRoom()||!demo&&inRun();
 if(yes&&leaving&&FR.invConfirm!==i.id){FR.invConfirm=i.id;FR.msg='Accepting leaves your current room or run. Select LEAVE & JOIN to confirm.';renderSocial();return}
 const owner=myUid(),epoch=FR.accountEpoch,scope=[NET.mode,NET.code,game.gid,demo].join('|'),current=()=>owner===myUid()&&epoch===FR.accountEpoch;FR.busy=true;renderSocial();
 try{const r=await rpc('lobby_invite_answer',{p_id:i.id,p_accept:yes,p_proto:PROTO});if(!current())return;
   if(!r.ok){FR.msg=sbErr(r);return}
   if(yes&&scope!==[NET.mode,NET.code,game.gid,demo].join('|')){FR.invConfirm='';FR.msg='Your room or run changed while accepting. Joining was canceled; ask your friend to resend.';return}
   FR.invConfirm='';FR.msg=yes?'Connecting to your friend…':'Invitation declined.';
   if(yes){if(leaving){leaveRun();netReset();toMenu()}closeFriends();showPage('multi');$('mCode').value=r.j.code;initAudio();netJoin(r.j.code,r.j.incarnation)}
 }finally{if(current()){FR.busy=false;await friendsPoll();if(owner===myUid()&&dropOpen())renderSocial()}}
}
function renderLobbyInvites(box){
 for(const i of FR.invites||[]){const r=i.room||{},who=i.user?.username||'Your friend',valid=Date.parse(i.expires_at)>Date.now();
   const mode=LEN_NAME[r.length]||MODE_NAME[r.mode]||'ROOM',map=MAPS[r.map]?.short||'ROOM',txt=`${mode} · ${map}${r.length==='campaign'?` · chapter ${(r.chapter||0)+1}`:''} · ${Math.max(0,6-(r.players||6))} slots · ${r.locked?'locked':'expires in '+Math.max(0,Math.ceil((Date.parse(i.expires_at)-Date.now())/60000))+' min'}`;
   box.append(personRow(i.user||{username:who},txt,[[FR.invConfirm===i.id?'LEAVE & JOIN':'ACCEPT',()=>answerInvite(i,true),{main:true,off:!valid}],['DECLINE',()=>answerInvite(i,false)]],'lobbyInvite'));
 }
}
