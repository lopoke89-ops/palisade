// Exercise the saved lobby table and migration in disposable Postgres.
const {PGlite}=require('@electric-sql/pglite'),fs=require('node:fs'),assert=require('node:assert/strict');
(async()=>{
  const db=new PGlite(),checks=[];
  const schema=fs.readFileSync(__dirname+'/../supabase/schema.sql','utf8');
  const table=schema.match(/create table public\.lobbies \([\s\S]*?\n\);/)[0];
  const oldTable=table.replace(", 'blitz'::text",'');
  const file=fs.readdirSync(__dirname+'/../supabase/migrations').find(x=>/_blitz_open_lobbies\.sql$/.test(x));
  const migration=fs.readFileSync(__dirname+'/../supabase/migrations/'+file,'utf8');
  const uid='11111111-1111-4111-8111-111111111111';
  await db.exec(`create schema auth;create table auth.users(id uuid primary key);
    create function auth.uid() returns uuid language sql as $$select '${uid}'::uuid$$;
    insert into auth.users values('${uid}');`);
  await db.exec(oldTable);
  const publish=length=>db.query(`insert into public.lobbies(code,name,mode,length,diff,proto)
    values('TEST','Test room','coop',$1,'normal','yard-20')
    on conflict(host_id) do update set length=excluded.length`,[length]);
  await assert.rejects(publish('blitz'),/lobbies_length_check/);checks.push('reproduces rejected Blitz heartbeat');
  await db.exec(migration);await db.exec(migration);checks.push('migration applies twice');
  for(const length of ['5','10','endless','blitz',null]){
    await publish(length);assert.equal((await db.query('select length from public.lobbies')).rows[0].length,length);
    checks.push('accepts '+String(length));
  }
  await assert.rejects(publish('invalid'),/lobbies_length_check/);checks.push('invalid lengths rejected');
  await db.exec('drop table public.lobbies');await db.exec(table);
  await publish('blitz');checks.push('fresh schema accepts Blitz');
  await db.close();console.log(JSON.stringify({migration:file,checks}));console.log('errors: none');
})().catch(e=>{console.error(e);process.exit(1)});
