// Runs the real migration in disposable in-memory Postgres. Never connects to live accounts.
const {PGlite}=require('@electric-sql/pglite'),fs=require('node:fs'),vm=require('node:vm'),assert=require('node:assert/strict');
const root=__dirname+'/..',migration=fs.readFileSync(root+'/supabase/migrations/20260930050715_palisade_v0935_cosmetics.sql','utf8'),schema=fs.readFileSync(root+'/supabase/schema.sql','utf8');
const src=fs.readFileSync(root+'/src/js/18-cosmetics.js','utf8'),catalog=vm.runInNewContext(src.slice(0,src.indexOf('// Saves live in this browser'))+';JSON.stringify({COS,CASES})');
(async()=>{const db=new PGlite(),id='11111111-1111-4111-8111-111111111111',other='22222222-2222-4222-8222-222222222222';
await db.exec(`create role anon;create role authenticated;create schema auth;create schema private;
create table auth.users(id uuid primary key);create table public.profiles(id uuid primary key,banned boolean default false);
create function auth.uid() returns uuid language sql stable as $$select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid$$;
insert into auth.users values('${id}'),('${other}');insert into public.profiles(id) select id from auth.users;`);
for(const table of ['case_types','cosmetics','lockers']){const match=schema.match(new RegExp('create table public\\.'+table+' \\([\\s\\S]*?\\n\\);'));assert.ok(match,table);await db.exec(match[0]+`alter table public.${table} enable row level security;`)}
for(const name of ['require_user','check_rev','bag_add','locker_out','roll_rarity','shard_value']){const start=schema.indexOf('CREATE OR REPLACE FUNCTION private.'+name+'('),end=schema.indexOf('$function$',schema.indexOf('AS $function$',start)+13)+10;assert.ok(start>=0&&end>start,name);await db.exec(schema.slice(start,end)+';');await db.exec(`revoke all on all functions in schema private from public,anon,authenticated;`)}
const {COS,CASES}=JSON.parse(catalog);for(const [key,c]of Object.entries(CASES))await db.query('insert into public.case_types(id,name,weights) values($1,$2,$3)',[key,c.name,JSON.stringify(key==='supply'?{c:60,r:27,e:10,l:3}:c.weights)]);
const newKeys=new Set(['sahur','gravecap','stemband','batcirclet','bonewrap','webpin','skullseal']);for(const c of COS.filter(c=>!newKeys.has(c.key)))await db.query('insert into public.cosmetics(id,cat,key,name,rarity,src,need,box) values($1,$2,$3,$4,$5,$6,$7,$8)',[c.id,c.cat,c.key,c.name,c.r,c.src,JSON.stringify(c.need),c.box]);
await db.exec(`insert into public.lockers(user_id,cases,bag) values('${id}',2000,'{"halloween":2000}'),('${other}',20,'{}');`);
await db.exec(migration);await db.exec(migration); // idempotent data and definitions
assert.equal((await db.query("select count(*)::int n from public.cosmetics where catalog_version=1")).rows[0].n,7);
const report={migration:'20260930050715_palisade_v0935_cosmetics',checks:[]};
const check=async(name,sql,fn)=>{const r=await db.query(sql);fn(r);report.checks.push(name)};
await check('old private helpers still inaccessible',"select has_function_privilege('authenticated','private.shard_value(text)','execute') ok",r=>assert.equal(r.rows[0].ok,false));
await check('anon cannot call either case API',"select has_function_privilege('anon','public.open_case_of(text,integer)','execute') old,has_function_privilege('anon','public.open_case_v0935(text,integer)','execute') new",r=>assert.deepEqual(r.rows[0],{old:false,new:false}));
await db.exec(`set role authenticated;select set_config('request.jwt.claim.sub','${id}',false);`);
const old=await db.query("select public.open_case_of('supply')->'item' as item from generate_series(1,120)");assert.ok(old.rows.every(r=>r.item.rarity!=='u'&&!newKeys.has(r.item.key)));report.checks.push('legacy Supply pool excludes Ultimate');
const oldHat=await db.query("select public.open_case_of('halloween')->'item' as item from generate_series(1,120)");assert.ok(oldHat.rows.every(r=>!newKeys.has(r.item.key)));report.checks.push('legacy Halloween pool excludes new hats');
const newHat=await db.query("select public.open_case_v0935('halloween')->'item' as item from generate_series(1,450)");const hats=new Set(newHat.rows.filter(r=>newKeys.has(r.item.key)).map(r=>r.item.key));assert.equal(hats.size,6);report.checks.push('all six hats reachable through new API');
await db.exec("reset role;update public.case_types set weights='{\"u\":1}' where id='supply';set role authenticated;");
const a=(await db.query("select public.open_case_v0935('supply') r")).rows[0].r;assert.equal(a.item.id,'skin:sahur');assert.equal(a.item.rarity,'u');assert.equal(a.dup,false);
const d=(await db.query("select public.open_case_v0935('supply') r")).rows[0].r;assert.equal(d.dup,true);assert.equal(d.locker.shards-a.locker.shards,80);assert.equal(a.locker.cases-d.locker.cases,1);report.checks.push('Ultimate unlock then duplicate pays 80 once');
await assert.rejects(db.query("select public.open_case_v0935('supply',0)"));report.checks.push('stale revision rejected');
await db.exec('reset role');const after=(await db.query(`select * from public.lockers where user_id='${id}'`)).rows[0];assert.equal(after.rev,d.locker.rev);assert.equal((await db.query(`select cases from public.lockers where user_id='${other}'`)).rows[0].cases,20);report.checks.push('failed call and other account unchanged');
await db.exec(`update public.lockers set cases=0 where user_id='${id}';set role authenticated;`);await assert.rejects(db.query("select public.open_case_v0935('supply')"));report.checks.push('empty case rejected');
await db.exec("select set_config('request.jwt.claim.sub','',false)");await assert.rejects(db.query("select public.open_case_v0935('supply')"));report.checks.push('missing identity rejected');
await db.exec(`reset role;update public.profiles set banned=true where id='${id}';set role authenticated;select set_config('request.jwt.claim.sub','${id}',false);`);await assert.rejects(db.query("select public.open_case_v0935('halloween')"));report.checks.push('banned account rejected');
await db.close();fs.writeFileSync(__dirname+'/out/cosmetics_migration.json',JSON.stringify(report,null,2));console.log(report);console.log('errors: none');})().catch(e=>{console.error(e);process.exit(1)});
