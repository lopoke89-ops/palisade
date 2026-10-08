const {PGlite}=require('@electric-sql/pglite'),{citext}=require('@electric-sql/pglite/contrib/citext'),fs=require('node:fs'),assert=require('node:assert/strict');
(async()=>{const db=new PGlite({extensions:{citext}});
 try{
  await db.exec(`create role anon;create role authenticated;create role service_role;create schema auth;create table auth.users(id uuid primary key,email text,is_anonymous boolean default false,raw_user_meta_data jsonb default '{}');create function auth.uid() returns uuid language sql stable as $$select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid$$;create function auth.jwt() returns jsonb language sql stable as $$select coalesce(nullif(current_setting('request.jwt.claims',true),''),'{}')::jsonb$$;`);
  await db.exec(fs.readFileSync(__dirname+'/../supabase/schema.sql','utf8'));
  const migration=fs.readFileSync(__dirname+'/../supabase/migrations/20261008213153_casino_relay_lobby_codes.sql','utf8');await db.exec(migration);await db.exec(migration);
  const a='a0000000-0000-4000-8000-00000000000a',b='b0000000-0000-4000-8000-00000000000b',inc='11111111-1111-4111-8111-111111111111';
  await db.exec(`insert into auth.users(id) values('${a}'),('${b}');update profiles set username='Alpha' where id='${a}';update profiles set username='Bravo' where id='${b}';set request.jwt.claim.sub='${a}';set role authenticated;`);
  const reg=async(code,length='casino')=>(await db.query('select room_register($1::jsonb) r',[JSON.stringify({incarnation:inc,code,proto:'yard-29',mode:'coop',length,map:length==='casino'?'casino':'yard',players:1,locked:false})])).rows[0].r;
  assert.ok((await reg('ABCD','5')).registered,'legacy room registration still works');
  assert.ok((await reg('RABCDE')).registered,'relay casino registration works');
  await assert.rejects(()=>reg('RABCDE','5'),/Invalid room/);
  await db.query(`insert into lobbies(host_id,code,name,mode,length,diff,players,in_game,proto) values($1,'RABCDE','Alpha casino','coop','casino','normal',1,true,'yard-29')`,[a]);
  await assert.rejects(()=>db.query("update lobbies set length='5' where host_id=$1",[a]),/lobbies_code_check/);
  await db.exec('reset role');await db.query('insert into friendships(user_a,user_b) values($1,$2)',[a,b]);await db.exec('set role authenticated');
  const sent=(await db.query('select lobby_invite_send($1) r',[b])).rows[0].r;
  await db.exec(`set request.jwt.claim.sub='${b}'`);const invite=(await db.query('select lobby_invite_answer($1,true,$2) r',[sent.id,'yard-29'])).rows[0].r;
  assert.equal(invite.code,'RABCDE');assert.equal(invite.incarnation,inc);assert.equal(invite.length,'casino');
  await db.exec(`set request.jwt.claims='{"is_anonymous":true}'`);await assert.rejects(()=>reg('RABCDE'),/saved account/);
  await db.exec('reset role');const permissions=(await db.query("select has_function_privilege('anon','public.room_register(jsonb)','execute') allowed")).rows[0];assert.equal(permissions.allowed,false);
  console.log('Legacy codes, relay codes, restricted casino shape, saved-account grants and friend invitation: errors: none');
 }finally{await db.close()}
})().catch(e=>{console.error(e);process.exitCode=1});
