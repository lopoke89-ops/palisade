-- PALISADE: Supabase backup (project puvjfhwxigxjpsvdwrwf), generated 2026-09-27 from the live database.
-- Restores the game's tables, rules, checked functions, permissions and case/cosmetic data into a fresh
-- Supabase project (paste into the SQL editor). It does NOT hold player accounts or lockers, the blocked-words
-- list (kept out of this public repo; export it from the table), or Auth settings (anonymous sign-ins on, SMTP).
-- Run once on an empty project:
create extension if not exists citext;
create schema if not exists private;

-- TABLES

create table public.blocked_words (
  word text not null,
  constraint blocked_words_pkey PRIMARY KEY (word)
);
alter table public.blocked_words enable row level security;

create table public.case_types (
  id text not null,
  name text not null,
  weights jsonb not null,
  shard_cost integer,
  modes text[] not null default '{}'::text[],
  drop jsonb not null default '{}'::jsonb,
  sort integer not null default 0,
  constraint case_types_pkey PRIMARY KEY (id)
);
alter table public.case_types enable row level security;

create table public.cosmetics (
  id text not null,
  cat text not null,
  key text not null,
  name text not null,
  rarity character(1) not null,
  src text not null,
  need jsonb,
  box text,
  constraint cosmetics_pkey PRIMARY KEY (id),
  constraint cosmetics_box_fkey FOREIGN KEY (box) REFERENCES case_types(id),
  constraint cosmetics_cat_check CHECK ((cat = ANY (ARRAY['skin'::text, 'hat'::text, 'trail'::text, 'fx'::text, 'bg'::text]))),
  constraint cosmetics_rarity_check CHECK ((rarity = ANY (ARRAY['c'::bpchar, 'r'::bpchar, 'e'::bpchar, 'l'::bpchar, 'g'::bpchar]))),
  constraint cosmetics_src_check CHECK ((src = ANY (ARRAY['free'::text, 'unlock'::text, 'case'::text])))
);
alter table public.cosmetics enable row level security;

create table public.lobbies (
  host_id uuid not null default auth.uid(),
  code text not null,
  name text not null,
  mode text not null,
  length text,
  diff text,
  players integer not null default 1,
  in_game boolean not null default false,
  proto text not null,
  updated_at timestamp with time zone not null default now(),
  constraint lobbies_pkey PRIMARY KEY (host_id),
  constraint lobbies_host_id_fkey FOREIGN KEY (host_id) REFERENCES auth.users(id) ON DELETE CASCADE,
  constraint lobbies_code_check CHECK ((code ~ '^[A-Z0-9]{4}$'::text)),
  constraint lobbies_diff_check CHECK ((diff = ANY (ARRAY['easy'::text, 'normal'::text, 'hard'::text]))),
  constraint lobbies_length_check CHECK ((length = ANY (ARRAY['5'::text, '10'::text, 'endless'::text, 'blitz'::text]))),
  constraint lobbies_mode_check CHECK ((mode = ANY (ARRAY['coop'::text, 'base'::text, 'ffa'::text]))),
  constraint lobbies_name_check CHECK (((char_length(name) >= 1) AND (char_length(name) <= 24))),
  constraint lobbies_players_check CHECK (((players >= 0) AND (players <= 6))),
  constraint lobbies_proto_check CHECK ((char_length(proto) <= 16))
);
alter table public.lobbies enable row level security;

create table public.lockers (
  user_id uuid not null,
  owned text[] not null default ARRAY['skin:std'::text, 'hat:class'::text, 'hat:cap'::text, 'trail:std'::text, 'fx:none'::text, 'bg:campfire'::text, 'bg:nightwatch'::text],
  eq jsonb not null default '{"fx": "none", "hat": "class", "skin": "std", "trail": "std"}'::jsonb,
  cases integer not null default 1,
  shards integer not null default 0,
  prog integer not null default 0,
  st jsonb not null default '{"pvp": 0, "wins": 0, "drops": 0, "raids": 0, "endless": 0, "pvpWins": 0, "hardWins": 0}'::jsonb,
  imported boolean not null default false,
  rev integer not null default 1,
  updated_at timestamp with time zone not null default now(),
  bag jsonb not null default '{}'::jsonb,
  play_budget real not null default 22200,
  budget_at timestamp with time zone not null default now(),
  constraint lockers_pkey PRIMARY KEY (user_id),
  constraint lockers_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE,
  constraint lockers_cases_check CHECK ((cases >= 0)),
  constraint lockers_prog_check CHECK (((prog >= 0) AND (prog <= 2))),
  constraint lockers_shards_check CHECK ((shards >= 0))
);
alter table public.lockers enable row level security;

create table public.match_results (
  id bigint generated always as identity,
  user_id uuid not null,
  kind text not null,
  mode text,
  pvp text,
  diff text,
  win boolean not null default false,
  held integer not null default 0,
  kills integer not null default 0,
  duration_s integer not null default 0,
  cases_granted integer not null default 0,
  created_at timestamp with time zone not null default now(),
  case_id text,
  bonus integer not null default 0,
  shards integer not null default 0,
  constraint match_results_pkey PRIMARY KEY (id),
  constraint match_results_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE,
  constraint match_results_kind_check CHECK ((kind = ANY (ARRAY['run'::text, 'match'::text])))
);
alter table public.match_results enable row level security;

create table public.player_stats (
  user_id uuid not null,
  raids integer not null default 0,
  wins integer not null default 0,
  drops integer not null default 0,
  best_endless integer not null default 0,
  pvp integer not null default 0,
  pvp_wins integer not null default 0,
  updated_at timestamp with time zone not null default now(),
  constraint player_stats_pkey PRIMARY KEY (user_id),
  constraint player_stats_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE
);
alter table public.player_stats enable row level security;

create table public.profiles (
  id uuid not null,
  username citext,
  cos text not null default 'std|class|std|none'::text,
  banned boolean not null default false,
  created_at timestamp with time zone not null default now(),
  constraint profiles_username_key UNIQUE (username),
  constraint profiles_pkey PRIMARY KEY (id),
  constraint profiles_id_fkey FOREIGN KEY (id) REFERENCES auth.users(id) ON DELETE CASCADE,
  constraint profiles_username_check CHECK ((username ~ '^[A-Za-z0-9_]{3,16}$'::citext))
);
alter table public.profiles enable row level security;

-- INDEXES

CREATE INDEX match_results_user_time ON public.match_results USING btree (user_id, created_at DESC);
CREATE INDEX lobbies_fresh ON public.lobbies USING btree (updated_at DESC);

-- FUNCTIONS

CREATE OR REPLACE FUNCTION public.buy_case(p_case text, p_rev integer DEFAULT NULL::integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare uid uuid := private.require_user(); l public.lockers; ct public.case_types;
begin
  select * into ct from public.case_types where id = p_case;
  if not found then raise exception 'Unknown case' using errcode = '22023'; end if;
  if ct.shard_cost is null then raise exception 'The % can''t be bought with shards', lower(ct.name) using errcode = '22023'; end if;
  select * into l from public.lockers where user_id = uid for update;
  perform private.check_rev(l, p_rev);
  if l.shards < ct.shard_cost then raise exception 'That takes % shards', ct.shard_cost using errcode = '22023'; end if;
  update public.lockers set shards = shards - ct.shard_cost, bag = private.bag_add(bag, p_case, 1), rev = rev + 1, updated_at = now()
    where user_id = uid returning * into l;
  return private.locker_out(l);
end $function$
;

CREATE OR REPLACE FUNCTION public.claim_match_reward(p jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare uid uuid := private.require_user(); l public.lockers; ct public.case_types; cb public.case_types;
  v_kind text := p->>'kind'; v_mode text := coalesce(p->>'mode', '5'); v_pvp text := coalesce(p->>'pvp', '');
  v_diff text := coalesce(p->>'diff', 'normal'); v_win boolean := coalesce(p->>'win' = 'true', false);
  v_held int := greatest(coalesce(private.num(p->>'held'), 0), 0)::int; v_kills int := greatest(coalesce(private.num(p->>'kills'), 0), 0)::int;
  v_dur int := coalesce(private.num(p->>'duration_s'), 0)::int; v_boss int := least(greatest(coalesce(private.num(p->>'bosses'), 0), 0), 100)::int;
  waves int := 0; v_st jsonb; v_prog int; earned int := 0; granted int; got text[]; v_case text := 'supply'; chance float8; v_bonus int := 0;
  v_budget float8;
  -- salvage left at the end of a co-op / Endless run: 20 to 1, at most 2 shards per raid held and 10 a run (same as the game)
  v_sal int := least(greatest(coalesce(private.num(p->>'salvage'), 0), 0), 1000000)::int; v_shards int := 0;
  -- v0.9.0: which bosses went down (each boss drops its own case; the October Butcher drops two Halloween Cases)
  v_keys jsonb := p->'boss_keys'; v_key text; v_cap int; v_n int := 0; v_hal int := 0; v_glow int := 0;
  v_oct boolean := (now() at time zone 'UTC') >= make_timestamp(extract(year from now())::int, 9, 30, 10, 0, 0)
               and (now() at time zone 'UTC') <  make_timestamp(extract(year from now())::int, 11, 1, 14, 0, 0);
begin
  if v_kind is null or v_kind not in ('run', 'match') then raise exception 'Unknown result' using errcode = '22023'; end if;
  if v_dur < 20 or v_dur > 21600 or (v_kind = 'match' and v_dur < 30) then raise exception 'That match length doesn''t add up' using errcode = '22023'; end if;
  -- real players land well under 0.3 drops a second; 1 a second leaves lots of room
  if v_kills > v_dur then raise exception 'That kill count doesn''t add up' using errcode = '22023'; end if;
  select * into l from public.lockers where user_id = uid for update;
  if exists (select 1 from public.match_results m where m.user_id = uid and m.created_at > now() - interval '20 seconds') then
    raise exception 'Rewards were claimed a moment ago' using errcode = '22023';
  end if;
  v_budget := least(22200, l.play_budget + extract(epoch from now() - l.budget_at));
  if v_dur > v_budget + 60 then
    raise exception 'More play time than real time so far; this result will be saved later' using errcode = '22023';
  end if;
  v_st := l.st; v_prog := l.prog;
  if v_kind = 'run' then
    if v_mode not in ('5', '10', 'endless') or v_diff not in ('easy', 'normal', 'hard') then raise exception 'Unknown mode' using errcode = '22023'; end if;
    waves := case v_mode when '5' then 5 when '10' then 10 else 0 end;
    -- each raid has to spawn its whole wave, and waves grow: at least ~8 s a raid plus more for later ones
    if (waves > 0 and v_held > waves) or v_dur + 20 < 8 * v_held + (v_held * v_held) / 4 then raise exception 'That raid count doesn''t add up' using errcode = '22023'; end if;
    if waves = 0 or v_held <> waves then v_win := false; end if;
    v_st := jsonb_set(v_st, '{raids}', to_jsonb(coalesce((v_st->>'raids')::int, 0) + v_held));
    v_st := jsonb_set(v_st, '{drops}', to_jsonb(coalesce((v_st->>'drops')::int, 0) + v_kills));
    if v_win then
      v_st := jsonb_set(v_st, '{wins}', to_jsonb(coalesce((v_st->>'wins')::int, 0) + 1));
      if v_diff = 'hard' then v_st := jsonb_set(v_st, '{hardWins}', to_jsonb(coalesce((v_st->>'hardWins')::int, 0) + 1)); end if;
    end if;
    if waves = 0 then v_st := jsonb_set(v_st, '{endless}', to_jsonb(greatest(coalesce((v_st->>'endless')::int, 0), v_held))); end if;
    v_prog := v_prog + v_held;
    earned := v_prog / 3 + case when v_win then (case when waves >= 10 then 2 else 1 end) else 0 end + case when waves = 0 then v_held / 5 else 0 end;
    v_prog := v_prog % 3;
    -- a boss every fifth raid: no more bosses than raids held allow
    v_cap := (v_held + 1) / 5;
    if waves > 0 then v_cap := least(v_cap, waves / 5); end if;
    if jsonb_typeof(v_keys) = 'array' then
      for v_key in select value from jsonb_array_elements_text(v_keys) limit 40 loop
        exit when v_n >= v_cap;
        if v_key in ('butcher', 'ferryman') then v_hal := v_hal + 1; v_n := v_n + 1;
        elsif v_key = 'butcher_oct' then v_hal := v_hal + case when v_oct then 2 else 1 end; v_n := v_n + 1;
        elsif v_key in ('demolisher', 'storm', 'foreman') then v_glow := v_glow + 1; v_n := v_n + 1;
        end if;
      end loop;
      v_boss := v_n;
    else
      -- older clients only send a count: those bosses pay Afterglow Cases as before
      v_boss := least(v_boss, v_cap); v_glow := v_boss;
    end if;
    select * into cb from public.case_types c where c.drop ? 'boss' order by c.sort limit 1;
    if found then v_glow := v_glow * coalesce((cb.drop->'boss'->>'each')::int, 1); end if;
    v_bonus := v_glow + v_hal;
    v_shards := least(v_sal / 20, 2 * v_held, 10);
  else
    if v_pvp not in ('base', 'ffa') then raise exception 'Unknown match type' using errcode = '22023'; end if;
    v_st := jsonb_set(v_st, '{drops}', to_jsonb(coalesce((v_st->>'drops')::int, 0) + v_kills));
    v_st := jsonb_set(v_st, '{pvp}', to_jsonb(coalesce((v_st->>'pvp')::int, 0) + 1));
    if v_win then v_st := jsonb_set(v_st, '{pvpWins}', to_jsonb(coalesce((v_st->>'pvpWins')::int, 0) + 1)); end if;
    v_case := null;
    select * into ct from public.case_types c where v_pvp = any(c.modes) order by c.sort limit 1;
    if found then
      v_case := ct.id;
      chance := coalesce((ct.drop->v_pvp->>(case when v_win then 'win' else 'loss' end))::float8, 0);
      if random() < chance then earned := 1; end if;
    end if;
  end if;
  granted := earned;
  update public.lockers set st = v_st, prog = v_prog,
      cases = cases + case when v_case = 'supply' then granted else 0 end,
      bag = private.bag_add(private.bag_add(
              case when v_case is not null and v_case <> 'supply' and granted > 0 then private.bag_add(bag, v_case, granted) else bag end,
              coalesce(cb.id, 'afterglow'), v_glow), 'halloween', v_hal),
      shards = shards + v_shards,
      play_budget = greatest(0, v_budget - v_dur), budget_at = now(),
      rev = rev + 1, updated_at = now()
    where user_id = uid;
  insert into public.match_results (user_id, kind, mode, pvp, diff, win, held, kills, duration_s, cases_granted, case_id, bonus, shards)
    values (uid, v_kind, case when v_kind = 'run' then v_mode end, nullif(v_pvp, ''), case when v_kind = 'run' then v_diff end,
            v_win, v_held, v_kills, v_dur, granted, v_case, v_bonus, v_shards);
  update public.player_stats s set
      raids = s.raids + case when v_kind = 'run' then v_held else 0 end,
      wins = s.wins + case when v_kind = 'run' and v_win then 1 else 0 end,
      drops = s.drops + v_kills,
      best_endless = greatest(s.best_endless, case when v_kind = 'run' and waves = 0 then v_held else 0 end),
      pvp = s.pvp + case when v_kind = 'match' then 1 else 0 end,
      pvp_wins = s.pvp_wins + case when v_kind = 'match' and v_win then 1 else 0 end,
      updated_at = now()
    where s.user_id = uid;
  got := private.apply_unlocks(uid);
  select * into l from public.lockers where user_id = uid;
  return jsonb_build_object('cases_granted', granted, 'case_id', v_case, 'capped', false, 'chance', chance,
    'bonus', jsonb_build_object('case', coalesce(cb.id, 'afterglow'), 'n', v_glow), 'shards', v_shards,
    'bonuses', jsonb_build_array(jsonb_build_object('case', coalesce(cb.id, 'afterglow'), 'n', v_glow), jsonb_build_object('case', 'halloween', 'n', v_hal)),
    'unlocked', to_jsonb(got), 'locker', private.locker_out(l));
end $function$
;

CREATE OR REPLACE FUNCTION public.equip(p_item text, p_rev integer DEFAULT NULL::integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare uid uuid := private.require_user(); l public.lockers; c public.cosmetics;
begin
  select * into l from public.lockers where user_id = uid for update;
  perform private.check_rev(l, p_rev);
  select * into c from public.cosmetics where id = p_item;
  if not found or not (p_item = any(l.owned)) then
    raise exception 'You don''t own that item' using errcode = '42501';
  end if;
  update public.lockers set eq = eq || jsonb_build_object(c.cat, c.key), rev = rev + 1, updated_at = now()
    where user_id = uid returning * into l;
  update public.profiles set cos = concat_ws('|', l.eq->>'skin', l.eq->>'hat', l.eq->>'trail', l.eq->>'fx') where id = uid;
  return private.locker_out(l);
end $function$
;

CREATE OR REPLACE FUNCTION public.get_my_locker()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare uid uuid := private.require_user(); l public.lockers;
begin
  select * into l from public.lockers where user_id = uid;
  if not found then
    insert into public.lockers (user_id) values (uid) returning * into l;
    insert into public.profiles (id) values (uid) on conflict do nothing;
    insert into public.player_stats (user_id) values (uid) on conflict do nothing;
  end if;
  return private.locker_out(l);
end $function$
;

CREATE OR REPLACE FUNCTION public.import_local_save(p_save jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare uid uuid := private.require_user(); l public.lockers; v_own text[]; v_eq jsonb := '{}'; v_cat text; v_st jsonb; k text; fresh boolean; v_bag jsonb; c record;
begin
  select * into l from public.lockers where user_id = uid for update;
  if l.imported then raise exception 'A local save was already brought into this account' using errcode = '22023'; end if;
  if jsonb_typeof(p_save->'owned') is distinct from 'array' then raise exception 'That save is missing its items' using errcode = '22023'; end if;
  fresh := l.eq = '{"skin":"std","hat":"class","trail":"std","fx":"none"}'::jsonb;
  select array(
    select distinct v from jsonb_array_elements_text(p_save->'owned') v
    where length(v) < 40 and v ~ '^[a-z]+:[A-Za-z0-9_]+$' limit 200) into v_own;
  v_own := array(select distinct u from unnest(l.owned || v_own) u);
  foreach v_cat in array array['skin','hat','trail','fx'] loop
    if fresh and (v_cat || ':' || coalesce(p_save->'eq'->>v_cat, '')) = any(v_own)
       and exists (select 1 from public.cosmetics cc where cc.id = v_cat || ':' || (p_save->'eq'->>v_cat)) then
      v_eq := v_eq || jsonb_build_object(v_cat, p_save->'eq'->>v_cat);
    else
      v_eq := v_eq || jsonb_build_object(v_cat, l.eq->>v_cat);
    end if;
  end loop;
  v_st := l.st;
  foreach k in array array['raids','wins','drops','endless','hardWins','pvp','pvpWins'] loop
    v_st := v_st || jsonb_build_object(k, greatest(coalesce((l.st->>k)::int, 0),
      least(greatest(coalesce(private.num(p_save->'st'->>k), 0), 0), 100000)::int));
  end loop;
  v_bag := l.bag;
  for c in select id from public.case_types where id <> 'supply' loop
    v_bag := private.bag_add(v_bag, c.id, least(greatest(coalesce(private.num(p_save->'bag'->>c.id), 0), 0), 50)::int);
  end loop;
  update public.lockers set
      owned = v_own, eq = v_eq, bag = v_bag,
      cases = least(l.cases + least(greatest(coalesce(private.num(p_save->>'cases'), 0), 0), 50)::int, 60),
      shards = least(l.shards + least(greatest(coalesce(private.num(p_save->>'shards'), 0), 0), 1000)::int, 1000),
      st = v_st, imported = true, rev = rev + 1, updated_at = now()
    where user_id = uid;
  update public.profiles set cos = concat_ws('|', v_eq->>'skin', v_eq->>'hat', v_eq->>'trail', v_eq->>'fx') where id = uid;
  perform private.apply_unlocks(uid);
  select * into l from public.lockers where user_id = uid;
  return private.locker_out(l);
end $function$
;

CREATE OR REPLACE FUNCTION public.open_case_of(p_case text, p_rev integer DEFAULT NULL::integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare uid uuid := private.require_user(); l public.lockers; ct public.case_types; it public.cosmetics; want text; have int; dup boolean;
begin
  select * into ct from public.case_types where id = p_case;
  if not found then raise exception 'Unknown case' using errcode = '22023'; end if;
  select * into l from public.lockers where user_id = uid for update;
  perform private.check_rev(l, p_rev);
  have := case when p_case = 'supply' then l.cases else coalesce((l.bag->>p_case)::int, 0) end;
  if have < 1 then raise exception 'No % to open', lower(ct.name) || 's' using errcode = '22023'; end if;
  want := private.roll_rarity(ct.weights);
  select * into it from public.cosmetics c where c.box = p_case and c.rarity = want order by random() limit 1;
  if not found then select * into it from public.cosmetics c where c.box = p_case order by c.rarity = 'c' desc, random() limit 1; end if;
  dup := it.id = any(l.owned);
  update public.lockers set
      cases = case when p_case = 'supply' then cases - 1 else cases end,
      bag = case when p_case = 'supply' then bag else private.bag_add(bag, p_case, -1) end,
      shards = shards + case when dup then private.shard_value(it.rarity) else 0 end,
      owned = case when dup then owned else owned || it.id end,
      rev = rev + 1, updated_at = now()
    where user_id = uid returning * into l;
  return jsonb_build_object('case', p_case, 'item', jsonb_build_object('id', it.id, 'cat', it.cat, 'key', it.key, 'name', it.name, 'rarity', it.rarity),
    'dup', dup, 'locker', private.locker_out(l));
end $function$
;

CREATE OR REPLACE FUNCTION public.set_username(p_name text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare uid uuid := private.require_user(); n text := btrim(coalesce(p_name, ''));
begin
  if n !~ '^[A-Za-z0-9_]{3,16}$' then
    raise exception 'Usernames are 3 to 16 letters, numbers or _' using errcode = '22023';
  end if;
  if exists (select 1 from public.blocked_words b where position(b.word in lower(n)) > 0) then
    raise exception 'That username isn''t allowed' using errcode = '22023';
  end if;
  begin
    update public.profiles set username = n where id = uid;
  exception when unique_violation then
    raise exception 'That username is taken' using errcode = '23505';
  end;
  return jsonb_build_object('username', n);
end $function$
;

CREATE OR REPLACE FUNCTION private.apply_unlocks(p_uid uuid)
 RETURNS text[]
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare l public.lockers; c record; got text[] := '{}'; ok boolean; k text;
begin
  select * into l from public.lockers where user_id = p_uid for update;
  for c in select * from public.cosmetics where src = 'unlock' and not (id = any(l.owned)) loop
    ok := true;
    for k in select jsonb_object_keys(c.need) loop
      if coalesce((l.st->>k)::int, 0) < (c.need->>k)::int then ok := false; end if;
    end loop;
    if ok then l.owned := l.owned || c.id; got := got || c.name; end if;
  end loop;
  if coalesce(array_length(got, 1), 0) > 0 then
    update public.lockers set owned = l.owned, rev = rev + 1, updated_at = now() where user_id = p_uid;
  end if;
  return got;
end $function$
;

CREATE OR REPLACE FUNCTION private.bag_add(b jsonb, k text, n integer)
 RETURNS jsonb
 LANGUAGE sql
 IMMUTABLE
 SET search_path TO ''
AS $function$
  select jsonb_set(coalesce(b,'{}'), array[k], to_jsonb(greatest(0, coalesce((b->>k)::int, 0) + n)));
$function$
;

CREATE OR REPLACE FUNCTION private.check_rev(l lockers, p_rev integer)
 RETURNS void
 LANGUAGE plpgsql
 IMMUTABLE
 SET search_path TO ''
AS $function$
begin
  if p_rev is not null and p_rev <> l.rev then
    raise exception 'Your locker changed on another device; refresh and try again' using errcode = '40001';
  end if;
end $function$
;

CREATE OR REPLACE FUNCTION private.handle_new_user()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
begin
  insert into public.profiles (id) values (new.id) on conflict do nothing;
  insert into public.lockers (user_id) values (new.id) on conflict do nothing;
  insert into public.player_stats (user_id) values (new.id) on conflict do nothing;
  return new;
end;
$function$
;

CREATE OR REPLACE FUNCTION private.lobby_stamp()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
begin
  new.updated_at := now();
  if exists (select 1 from public.blocked_words b where position(b.word in lower(new.name)) > 0) then new.name := 'Open game'; end if;
  delete from public.lobbies where updated_at < now() - interval '10 minutes';
  return new;
end $function$
;

CREATE OR REPLACE FUNCTION private.locker_out(l lockers)
 RETURNS jsonb
 LANGUAGE sql
 IMMUTABLE
 SET search_path TO ''
AS $function$
  select to_jsonb(l) - 'user_id';
$function$
;

CREATE OR REPLACE FUNCTION private.num(t text)
 RETURNS numeric
 LANGUAGE sql
 IMMUTABLE
 SET search_path TO ''
AS $function$
  select case when t ~ '^\s*-?\d+(\.\d+)?\s*$' then t::numeric end;
$function$
;

CREATE OR REPLACE FUNCTION private.require_user()
 RETURNS uuid
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare uid uuid := auth.uid();
begin
  if uid is null then raise exception 'Sign in first' using errcode = '28000'; end if;
  if exists (select 1 from public.profiles where id = uid and banned) then
    raise exception 'This account is banned' using errcode = '42501';
  end if;
  return uid;
end $function$
;

CREATE OR REPLACE FUNCTION private.roll_rarity(w jsonb)
 RETURNS text
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
declare tot numeric; x numeric; acc numeric := 0; k record;
begin
  select sum(value::numeric) into tot from jsonb_each_text(w);
  x := random() * tot;
  for k in select key, value::numeric v from jsonb_each_text(w) order by value::numeric asc loop
    acc := acc + k.v; if x < acc then return k.key; end if;
  end loop;
  return 'c';
end $function$
;

CREATE OR REPLACE FUNCTION private.shard_value(r text)
 RETURNS integer
 LANGUAGE sql
 IMMUTABLE
 SET search_path TO ''
AS $function$
  select case r when 'c' then 1 when 'r' then 3 when 'e' then 8 when 'l' then 20 when 'g' then 40 else 1 end;
$function$
;

-- TRIGGERS

CREATE TRIGGER lobby_stamp BEFORE INSERT OR UPDATE ON public.lobbies FOR EACH ROW EXECUTE FUNCTION private.lobby_stamp();

-- ROW LEVEL SECURITY POLICIES

create policy "case types are public" on public.case_types as permissive for select to public using (true);
create policy "catalog is public" on public.cosmetics as permissive for select to anon, authenticated using (true);
create policy "hosts list their own game" on public.lobbies as permissive for insert to authenticated with check ((host_id = ( SELECT auth.uid() AS uid)));
create policy "hosts remove their own game" on public.lobbies as permissive for delete to authenticated using ((host_id = ( SELECT auth.uid() AS uid)));
create policy "hosts update their own game" on public.lobbies as permissive for update to authenticated using ((host_id = ( SELECT auth.uid() AS uid))) with check ((host_id = ( SELECT auth.uid() AS uid)));
create policy "open games are visible to players" on public.lobbies as permissive for select to authenticated using ((updated_at > (now() - '00:00:45'::interval)));
create policy "own locker" on public.lockers as permissive for select to authenticated using ((( SELECT auth.uid() AS uid) = user_id));
create policy "own results" on public.match_results as permissive for select to authenticated using ((( SELECT auth.uid() AS uid) = user_id));
create policy "stats are public" on public.player_stats as permissive for select to anon, authenticated using (true);
create policy "profiles are visible to players" on public.profiles as permissive for select to authenticated using (true);

-- PERMISSIONS

grant REFERENCES, SELECT, TRIGGER on public.case_types to anon;
grant REFERENCES, SELECT, TRIGGER on public.case_types to authenticated;
grant REFERENCES, SELECT, TRIGGER on public.cosmetics to anon;
grant REFERENCES, SELECT, TRIGGER on public.cosmetics to authenticated;
grant DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE on public.lobbies to authenticated;
grant REFERENCES, SELECT, TRIGGER on public.lockers to anon;
grant REFERENCES, SELECT, TRIGGER on public.lockers to authenticated;
grant REFERENCES, SELECT, TRIGGER on public.match_results to anon;
grant REFERENCES, SELECT, TRIGGER on public.match_results to authenticated;
grant REFERENCES, SELECT, TRIGGER on public.player_stats to anon;
grant REFERENCES, SELECT, TRIGGER on public.player_stats to authenticated;
grant REFERENCES, SELECT, TRIGGER on public.profiles to anon;
grant REFERENCES, SELECT, TRIGGER on public.profiles to authenticated;

grant execute on function public.buy_case(p_case text, p_rev integer) to authenticated;
grant execute on function public.claim_match_reward(p jsonb) to authenticated;
grant execute on function public.equip(p_item text, p_rev integer) to authenticated;
grant execute on function public.get_my_locker() to authenticated;
grant execute on function public.import_local_save(p_save jsonb) to authenticated;
grant execute on function public.open_case_of(p_case text, p_rev integer) to authenticated;
grant execute on function public.set_username(p_name text) to authenticated;

-- GAME DATA

insert into public.case_types select * from json_populate_recordset(null::public.case_types, '[{"id":"supply","name":"SUPPLY CASE","weights":{"c": 60, "e": 10, "l": 3, "r": 27},"shard_cost":null,"modes":["coop"],"drop":{},"sort":0}, 
 {"id":"afterglow","name":"AFTERGLOW CASE","weights":{"c": 53, "e": 12, "g": 1, "l": 4, "r": 30},"shard_cost":10,"modes":["base","ffa"],"drop":{"ffa": {"win": 0.5, "loss": 0.2}, "base": {"win": 0.45, "loss": 0.2}, "boss": {"each": 1}},"sort":1}]');
insert into public.cosmetics select * from json_populate_recordset(null::public.cosmetics, '[{"id":"fx:bolt","cat":"fx","key":"bolt","name":"Lightning","rarity":"e","src":"case","need":null,"box":"supply"}, 
 {"id":"fx:bubbles","cat":"fx","key":"bubbles","name":"Gold Bubbles","rarity":"g","src":"case","need":null,"box":"afterglow"}, 
 {"id":"fx:confetti","cat":"fx","key":"confetti","name":"Confetti","rarity":"r","src":"case","need":null,"box":"supply"}, 
 {"id":"fx:embers","cat":"fx","key":"embers","name":"Embers","rarity":"r","src":"unlock","need":{"hardWins": 1},"box":null}, 
 {"id":"fx:frost","cat":"fx","key":"frost","name":"Frost Shatter","rarity":"c","src":"case","need":null,"box":"afterglow"}, 
 {"id":"fx:glint","cat":"fx","key":"glint","name":"Ice Glint","rarity":"r","src":"case","need":null,"box":"supply"}, 
 {"id":"fx:glitchout","cat":"fx","key":"glitchout","name":"Glitch Out","rarity":"e","src":"case","need":null,"box":"afterglow"}, 
 {"id":"fx:gradburst","cat":"fx","key":"gradburst","name":"Violet Fade","rarity":"r","src":"case","need":null,"box":"afterglow"}, 
 {"id":"fx:none","cat":"fx","key":"none","name":"Standard","rarity":"c","src":"free","need":null,"box":null}, 
 {"id":"fx:pixel","cat":"fx","key":"pixel","name":"Pixel Pop","rarity":"c","src":"case","need":null,"box":"afterglow"}, 
 {"id":"fx:shockwave","cat":"fx","key":"shockwave","name":"Neon Shockwave","rarity":"l","src":"case","need":null,"box":"afterglow"}, 
 {"id":"fx:singularity","cat":"fx","key":"singularity","name":"Singularity","rarity":"l","src":"case","need":null,"box":"afterglow"}, 
 {"id":"fx:skull","cat":"fx","key":"skull","name":"Skull Pop","rarity":"l","src":"case","need":null,"box":"supply"}, 
 {"id":"fx:smoke","cat":"fx","key":"smoke","name":"Smoke Puff","rarity":"c","src":"case","need":null,"box":"supply"}, 
 {"id":"fx:sparks","cat":"fx","key":"sparks","name":"Sparks","rarity":"c","src":"case","need":null,"box":"supply"}, 
 {"id":"fx:sunburst","cat":"fx","key":"sunburst","name":"Sunset Burst","rarity":"r","src":"case","need":null,"box":"afterglow"}, 
 {"id":"fx:supernova","cat":"fx","key":"supernova","name":"Supernova","rarity":"e","src":"case","need":null,"box":"afterglow"}, 
 {"id":"fx:toxic","cat":"fx","key":"toxic","name":"Toxic Splash","rarity":"r","src":"case","need":null,"box":"afterglow"}, 
 {"id":"hat:acap","cat":"hat","key":"acap","name":"Arcade Cap","rarity":"c","src":"case","need":null,"box":"afterglow"}, 
 {"id":"hat:beanie","cat":"hat","key":"beanie","name":"Beanie","rarity":"c","src":"unlock","need":{"raids": 10},"box":null}, 
 {"id":"hat:beret","cat":"hat","key":"beret","name":"Beret","rarity":"r","src":"case","need":null,"box":"supply"}, 
 {"id":"hat:boonie","cat":"hat","key":"boonie","name":"Boonie","rarity":"c","src":"case","need":null,"box":"supply"}, 
 {"id":"hat:cap","cat":"hat","key":"cap","name":"Ball Cap","rarity":"c","src":"free","need":null,"box":null}, 
 {"id":"hat:class","cat":"hat","key":"class","name":"Class Issue","rarity":"c","src":"free","need":null,"box":null}, 
 {"id":"hat:clownhair","cat":"hat","key":"clownhair","name":"Neon Clown Hair","rarity":"e","src":"case","need":null,"box":"afterglow"}, 
 {"id":"hat:crown","cat":"hat","key":"crown","name":"Crown","rarity":"l","src":"case","need":null,"box":"supply"}, 
 {"id":"hat:gclownhair","cat":"hat","key":"gclownhair","name":"Gold Clown Hair","rarity":"g","src":"case","need":null,"box":"afterglow"}, 
 {"id":"hat:ghelm","cat":"hat","key":"ghelm","name":"Gold Knight Helm","rarity":"g","src":"case","need":null,"box":"afterglow"}, 
 {"id":"hat:glitch","cat":"hat","key":"glitch","name":"Glitch Head","rarity":"l","src":"case","need":null,"box":"afterglow"}, 
 {"id":"hat:halo","cat":"hat","key":"halo","name":"Halo","rarity":"l","src":"case","need":null,"box":"afterglow"}, 
 {"id":"hat:headband","cat":"hat","key":"headband","name":"Neon Headband","rarity":"c","src":"case","need":null,"box":"afterglow"}, 
 {"id":"hat:ledmask","cat":"hat","key":"ledmask","name":"LED Mask","rarity":"e","src":"case","need":null,"box":"afterglow"}, 
 {"id":"hat:nhelm","cat":"hat","key":"nhelm","name":"Neon Helmet","rarity":"r","src":"case","need":null,"box":"afterglow"}, 
 {"id":"hat:pcap","cat":"hat","key":"pcap","name":"Police Cap","rarity":"r","src":"case","need":null,"box":"afterglow"}, 
 {"id":"hat:tophat","cat":"hat","key":"tophat","name":"Top Hat","rarity":"e","src":"case","need":null,"box":"supply"}, 
 {"id":"hat:visor","cat":"hat","key":"visor","name":"Cyber Visor","rarity":"e","src":"case","need":null,"box":"afterglow"}, 
 {"id":"hat:wrap","cat":"hat","key":"wrap","name":"Head Wrap","rarity":"r","src":"case","need":null,"box":"supply"}, 
 {"id":"skin:arcade","cat":"skin","key":"arcade","name":"Arcade","rarity":"c","src":"case","need":null,"box":"afterglow"}, 
 {"id":"skin:arctic","cat":"skin","key":"arctic","name":"Arctic","rarity":"e","src":"case","need":null,"box":"supply"}, 
 {"id":"skin:chrome","cat":"skin","key":"chrome","name":"Chrome","rarity":"r","src":"case","need":null,"box":"afterglow"}, 
 {"id":"skin:cyber","cat":"skin","key":"cyber","name":"Cyberpunk","rarity":"l","src":"case","need":null,"box":"afterglow"}, 
 {"id":"skin:desert","cat":"skin","key":"desert","name":"Desert","rarity":"c","src":"unlock","need":{"raids": 3},"box":null}, 
 {"id":"skin:forest","cat":"skin","key":"forest","name":"Deep Woods","rarity":"r","src":"case","need":null,"box":"supply"}, 
 {"id":"skin:frost","cat":"skin","key":"frost","name":"Frostbite","rarity":"r","src":"case","need":null,"box":"afterglow"}, 
 {"id":"skin:galaxy","cat":"skin","key":"galaxy","name":"Galaxy","rarity":"l","src":"case","need":null,"box":"afterglow"}, 
 {"id":"skin:gclown","cat":"skin","key":"gclown","name":"Gold Clown","rarity":"g","src":"case","need":null,"box":"afterglow"}, 
 {"id":"skin:ghost","cat":"skin","key":"ghost","name":"Ghost","rarity":"l","src":"unlock","need":{"endless": 15},"box":null}, 
 {"id":"skin:gknight","cat":"skin","key":"gknight","name":"Gold Metal Knight","rarity":"g","src":"case","need":null,"box":"afterglow"}, 
 {"id":"skin:gold","cat":"skin","key":"gold","name":"Gilded","rarity":"l","src":"case","need":null,"box":"supply"}, 
 {"id":"skin:gpolice","cat":"skin","key":"gpolice","name":"Gold Police","rarity":"g","src":"case","need":null,"box":"afterglow"}, 
 {"id":"skin:holo","cat":"skin","key":"holo","name":"Hologram","rarity":"l","src":"case","need":null,"box":"afterglow"}, 
 {"id":"skin:neonclown","cat":"skin","key":"neonclown","name":"Neon Clown","rarity":"e","src":"case","need":null,"box":"afterglow"}, 
 {"id":"skin:neonknight","cat":"skin","key":"neonknight","name":"Neon Knight","rarity":"e","src":"case","need":null,"box":"afterglow"}, 
 {"id":"skin:neonops","cat":"skin","key":"neonops","name":"Neon Ops","rarity":"e","src":"case","need":null,"box":"afterglow"}, 
 {"id":"skin:neonpolice","cat":"skin","key":"neonpolice","name":"Neon Police","rarity":"e","src":"case","need":null,"box":"afterglow"}, 
 {"id":"skin:night","cat":"skin","key":"night","name":"Nightwatch","rarity":"r","src":"case","need":null,"box":"supply"}, 
 {"id":"skin:redcoat","cat":"skin","key":"redcoat","name":"Redcoat","rarity":"r","src":"case","need":null,"box":"supply"}, 
 {"id":"skin:std","cat":"skin","key":"std","name":"Standard Issue","rarity":"c","src":"free","need":null,"box":null}, 
 {"id":"skin:tiger","cat":"skin","key":"tiger","name":"Tigerstripe","rarity":"e","src":"case","need":null,"box":"supply"}, 
 {"id":"skin:toxic","cat":"skin","key":"toxic","name":"Toxic Waste","rarity":"c","src":"case","need":null,"box":"afterglow"}, 
 {"id":"skin:urban","cat":"skin","key":"urban","name":"Urban Grey","rarity":"c","src":"unlock","need":{"wins": 1},"box":null}, 
 {"id":"trail:asteroid","cat":"trail","key":"asteroid","name":"Asteroid Belt","rarity":"e","src":"case","need":null,"box":"afterglow"}, 
 {"id":"trail:aurora","cat":"trail","key":"aurora","name":"Aurora","rarity":"r","src":"case","need":null,"box":"afterglow"}, 
 {"id":"trail:blackhole","cat":"trail","key":"blackhole","name":"Event Horizon","rarity":"l","src":"case","need":null,"box":"afterglow"}, 
 {"id":"trail:blue","cat":"trail","key":"blue","name":"Ice Round","rarity":"r","src":"case","need":null,"box":"supply"}, 
 {"id":"trail:comet","cat":"trail","key":"comet","name":"Comet","rarity":"r","src":"case","need":null,"box":"afterglow"}, 
 {"id":"trail:galaxy","cat":"trail","key":"galaxy","name":"Galaxy","rarity":"l","src":"case","need":null,"box":"afterglow"}, 
 {"id":"trail:glitch","cat":"trail","key":"glitch","name":"Glitch Line","rarity":"e","src":"case","need":null,"box":"afterglow"}, 
 {"id":"trail:gold","cat":"trail","key":"gold","name":"Gold Round","rarity":"e","src":"case","need":null,"box":"supply"}, 
 {"id":"trail:grainbow","cat":"trail","key":"grainbow","name":"Gold Rainbow","rarity":"g","src":"case","need":null,"box":"afterglow"}, 
 {"id":"trail:green","cat":"trail","key":"green","name":"Green Tracer","rarity":"c","src":"unlock","need":{"drops": 50},"box":null}, 
 {"id":"trail:heat","cat":"trail","key":"heat","name":"Heatwave","rarity":"c","src":"case","need":null,"box":"afterglow"}, 
 {"id":"trail:lagoon","cat":"trail","key":"lagoon","name":"Lagoon Fade","rarity":"c","src":"case","need":null,"box":"afterglow"}, 
 {"id":"trail:nebula","cat":"trail","key":"nebula","name":"Nebula","rarity":"e","src":"case","need":null,"box":"afterglow"}, 
 {"id":"trail:neonpulse","cat":"trail","key":"neonpulse","name":"Neon Pulse","rarity":"r","src":"case","need":null,"box":"afterglow"}, 
 {"id":"trail:pink","cat":"trail","key":"pink","name":"Neon","rarity":"r","src":"case","need":null,"box":"supply"}, 
 {"id":"trail:plasma","cat":"trail","key":"plasma","name":"Plasma","rarity":"e","src":"case","need":null,"box":"supply"}, 
 {"id":"trail:rainbow","cat":"trail","key":"rainbow","name":"Prism","rarity":"l","src":"case","need":null,"box":"supply"}, 
 {"id":"trail:red","cat":"trail","key":"red","name":"Hot Red","rarity":"c","src":"case","need":null,"box":"supply"}, 
 {"id":"trail:solar","cat":"trail","key":"solar","name":"Solar Flare","rarity":"e","src":"case","need":null,"box":"afterglow"}, 
 {"id":"trail:starlight","cat":"trail","key":"starlight","name":"Starlight","rarity":"r","src":"case","need":null,"box":"afterglow"}, 
 {"id":"trail:std","cat":"trail","key":"std","name":"Standard Tracer","rarity":"c","src":"free","need":null,"box":null}, 
 {"id":"trail:sunset","cat":"trail","key":"sunset","name":"Sunset Fade","rarity":"c","src":"case","need":null,"box":"afterglow"}]');

-- new accounts get a profile, locker and stats row
create trigger on_auth_user_created after insert on auth.users for each row execute function private.handle_new_user();

-- v0.9.0 data: the Halloween Case and lobby backgrounds
insert into public.case_types (id, name, weights, shard_cost, modes, drop, sort)
values ('halloween', 'HALLOWEEN CASE', '{"c":45,"r":32,"e":16,"l":6,"g":1}', 12, '{}', '{}', 2)
on conflict (id) do update set name = excluded.name, weights = excluded.weights, shard_cost = excluded.shard_cost, sort = excluded.sort;
insert into public.cosmetics select * from json_populate_recordset(null::public.cosmetics, '[{"id": "skin:pumpkin", "cat": "skin", "key": "pumpkin", "name": "Pumpkin Patch", "rarity": "c", "src": "case", "need": null, "box": "halloween"}, {"id": "trail:candycorn", "cat": "trail", "key": "candycorn", "name": "Candy Corn", "rarity": "c", "src": "case", "need": null, "box": "halloween"}, {"id": "hat:jackolantern", "cat": "hat", "key": "jackolantern", "name": "Jack-o''-Lantern", "rarity": "r", "src": "case", "need": null, "box": "halloween"}, {"id": "skin:cobweb", "cat": "skin", "key": "cobweb", "name": "Cobweb", "rarity": "r", "src": "case", "need": null, "box": "halloween"}, {"id": "fx:bats", "cat": "fx", "key": "bats", "name": "Bat Swarm", "rarity": "r", "src": "case", "need": null, "box": "halloween"}, {"id": "skin:skeleton", "cat": "skin", "key": "skeleton", "name": "Skeleton", "rarity": "e", "src": "case", "need": null, "box": "halloween"}, {"id": "skin:mummy", "cat": "skin", "key": "mummy", "name": "Mummy", "rarity": "e", "src": "case", "need": null, "box": "halloween"}, {"id": "hat:witch", "cat": "hat", "key": "witch", "name": "Witch Hat", "rarity": "e", "src": "case", "need": null, "box": "halloween"}, {"id": "trail:ghostfire", "cat": "trail", "key": "ghostfire", "name": "Ghostfire", "rarity": "e", "src": "case", "need": null, "box": "halloween"}, {"id": "fx:spider", "cat": "fx", "key": "spider", "name": "Spider Drop", "rarity": "e", "src": "case", "need": null, "box": "halloween"}, {"id": "skin:reaper", "cat": "skin", "key": "reaper", "name": "Grim Reaper", "rarity": "l", "src": "case", "need": null, "box": "halloween"}, {"id": "hat:pumpkinking", "cat": "hat", "key": "pumpkinking", "name": "Pumpkin King", "rarity": "l", "src": "case", "need": null, "box": "halloween"}, {"id": "fx:souls", "cat": "fx", "key": "souls", "name": "Soul Harvest", "rarity": "l", "src": "case", "need": null, "box": "halloween"}, {"id": "skin:phantom", "cat": "skin", "key": "phantom", "name": "Phantom", "rarity": "g", "src": "case", "need": null, "box": "halloween"}, {"id": "bg:campfire", "cat": "bg", "key": "campfire", "name": "Campfire Dusk", "rarity": "c", "src": "free", "need": null, "box": null}, {"id": "bg:nightwatch", "cat": "bg", "key": "nightwatch", "name": "Night Watch", "rarity": "c", "src": "free", "need": null, "box": null}, {"id": "bg:dawn", "cat": "bg", "key": "dawn", "name": "First Light", "rarity": "r", "src": "unlock", "need": {"wins": 1}, "box": null}, {"id": "bg:aurora", "cat": "bg", "key": "aurora", "name": "Aurora", "rarity": "e", "src": "unlock", "need": {"wins": 10}, "box": null}, {"id": "bg:emberfield", "cat": "bg", "key": "emberfield", "name": "Ember Field", "rarity": "r", "src": "unlock", "need": {"drops": 100}, "box": null}, {"id": "bg:crimson", "cat": "bg", "key": "crimson", "name": "Crimson Smoke", "rarity": "e", "src": "unlock", "need": {"drops": 500}, "box": null}, {"id": "bg:neongrid", "cat": "bg", "key": "neongrid", "name": "Neon Grid", "rarity": "l", "src": "unlock", "need": {"drops": 1000}, "box": null}, {"id": "bg:goldrush", "cat": "bg", "key": "goldrush", "name": "Gold Rush", "rarity": "l", "src": "unlock", "need": {"hardWins": 3}, "box": null}, {"id": "bg:harvestmoon", "cat": "bg", "key": "harvestmoon", "name": "Harvest Moon", "rarity": "r", "src": "case", "need": null, "box": "halloween"}, {"id": "bg:hauntedfog", "cat": "bg", "key": "hauntedfog", "name": "Haunted Fog", "rarity": "e", "src": "case", "need": null, "box": "halloween"}, {"id": "bg:fieldmap", "cat": "bg", "key": "fieldmap", "name": "Field Map", "rarity": "r", "src": "case", "need": null, "box": "supply"}, {"id": "bg:sandbags", "cat": "bg", "key": "sandbags", "name": "Sandbag Line", "rarity": "r", "src": "case", "need": null, "box": "supply"}, {"id": "bg:dogtags", "cat": "bg", "key": "dogtags", "name": "Dog Tags", "rarity": "e", "src": "case", "need": null, "box": "supply"}, {"id": "bg:watchtower", "cat": "bg", "key": "watchtower", "name": "Watchtower", "rarity": "e", "src": "case", "need": null, "box": "supply"}, {"id": "bg:searchlight", "cat": "bg", "key": "searchlight", "name": "Searchlight", "rarity": "l", "src": "case", "need": null, "box": "supply"}, {"id": "bg:sunsetfade", "cat": "bg", "key": "sunsetfade", "name": "Sunset Fade", "rarity": "r", "src": "case", "need": null, "box": "afterglow"}, {"id": "bg:lagoonwaves", "cat": "bg", "key": "lagoonwaves", "name": "Lagoon", "rarity": "r", "src": "case", "need": null, "box": "afterglow"}, {"id": "bg:nebula", "cat": "bg", "key": "nebula", "name": "Nebula", "rarity": "e", "src": "case", "need": null, "box": "afterglow"}, {"id": "bg:arcade", "cat": "bg", "key": "arcade", "name": "Arcade", "rarity": "e", "src": "case", "need": null, "box": "afterglow"}, {"id": "bg:neonpulse", "cat": "bg", "key": "neonpulse", "name": "Neon Pulse", "rarity": "l", "src": "case", "need": null, "box": "afterglow"}, {"id": "bg:eventhorizon", "cat": "bg", "key": "eventhorizon", "name": "Event Horizon", "rarity": "l", "src": "case", "need": null, "box": "afterglow"}, {"id": "bg:goldaurora", "cat": "bg", "key": "goldaurora", "name": "Gold Aurora", "rarity": "g", "src": "case", "need": null, "box": "afterglow"}, {"id": "bg:graveyard", "cat": "bg", "key": "graveyard", "name": "Graveyard", "rarity": "r", "src": "case", "need": null, "box": "halloween"}, {"id": "bg:witchbrew", "cat": "bg", "key": "witchbrew", "name": "Witch''s Brew", "rarity": "e", "src": "case", "need": null, "box": "halloween"}, {"id": "bg:bloodmoon", "cat": "bg", "key": "bloodmoon", "name": "Blood Moon", "rarity": "l", "src": "case", "need": null, "box": "halloween"}]')
on conflict (id) do update set cat = excluded.cat, key = excluded.key, name = excluded.name, rarity = excluded.rarity, src = excluded.src, need = excluded.need, box = excluded.box;
-- the two free backgrounds: in every new locker, and added to every existing one

-- Restore extensions, replayed in chronological order. Generated from checked-in migration sources.

-- SOURCE: v0.9.1-migration.sql
-- PALISADE v0.9.1 migration. APPLY WITH THE v0.9.1 PUSH (not before): run this whole file once in the Supabase SQL editor,
-- or through the migration tool. Both parts were tested in rolled-back transactions on the test account.

-- PALISADE v0.9.1, part 1 of the migration: friends (requests, two-way friendships) and a notification mailbox.
-- Accounts only (a guest must save their account first). No blocking or reporting: rate limits keep it quiet.
-- Every write goes through the functions below; the tables only let a player read their own rows.

create table if not exists public.friend_requests (
  id bigint generated always as identity primary key,
  from_id uuid not null references auth.users(id) on delete cascade,
  to_id uuid not null references auth.users(id) on delete cascade,
  status text not null default 'pending' check (status in ('pending', 'accepted', 'declined', 'cancelled')),
  created_at timestamptz not null default now(),
  answered_at timestamptz,
  check (from_id <> to_id)
);
-- one open request per pair and direction
create unique index if not exists friend_requests_open on public.friend_requests (from_id, to_id) where status = 'pending';
create index if not exists friend_requests_to on public.friend_requests (to_id) where status = 'pending';
create index if not exists friend_requests_from_time on public.friend_requests (from_id, created_at desc);

-- a friendship is one row per pair (lower id first), so it is always two-way
create table if not exists public.friendships (
  user_a uuid not null references auth.users(id) on delete cascade,
  user_b uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_a, user_b),
  check (user_a < user_b)
);
create index if not exists friendships_b on public.friendships (user_b);

create table if not exists public.notifications (
  id bigint generated always as identity primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  kind text not null check (kind in ('friend_request', 'friend_accepted', 'system')),
  from_id uuid references auth.users(id) on delete cascade,
  data jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  seen_at timestamptz
);
create index if not exists notifications_user on public.notifications (user_id, created_at desc);

alter table public.friend_requests enable row level security;
alter table public.friendships enable row level security;
alter table public.notifications enable row level security;
drop policy if exists "own requests" on public.friend_requests;
create policy "own requests" on public.friend_requests as permissive for select to authenticated
  using ((select auth.uid()) in (from_id, to_id));
drop policy if exists "own friendships" on public.friendships;
create policy "own friendships" on public.friendships as permissive for select to authenticated
  using ((select auth.uid()) in (user_a, user_b));
drop policy if exists "own mailbox" on public.notifications;
create policy "own mailbox" on public.notifications as permissive for select to authenticated
  using ((select auth.uid()) = user_id);
revoke all on public.friend_requests, public.friendships, public.notifications from anon;
revoke insert, update, delete, truncate on public.friend_requests, public.friendships, public.notifications from authenticated;
grant select on public.friend_requests, public.friendships, public.notifications to authenticated;

-- a signed-in, saved (not guest) account
create or replace function private.require_account()
 returns uuid language plpgsql stable security definer set search_path to ''
as $function$
declare uid uuid := private.require_user();
begin
  if coalesce((auth.jwt()->>'is_anonymous')::boolean, false) then
    raise exception 'Save your account first to add friends' using errcode = '42501';
  end if;
  return uid;
end $function$;
revoke all on function private.require_account() from public, anon, authenticated;

create or replace function private.are_friends(a uuid, b uuid)
 returns boolean language sql stable security definer set search_path to ''
as $function$ select exists (select 1 from public.friendships f where f.user_a = least(a, b) and f.user_b = greatest(a, b)) $function$;
revoke all on function private.are_friends(uuid, uuid) from public, anon, authenticated;

create or replace function private.befriend(a uuid, b uuid)
 returns void language plpgsql security definer set search_path to ''
as $function$
begin
  insert into public.friendships (user_a, user_b) values (least(a, b), greatest(a, b)) on conflict do nothing;
  -- anything still open between the two is settled by the friendship
  update public.friend_requests set status = 'accepted', answered_at = now()
    where status = 'pending' and ((from_id = a and to_id = b) or (from_id = b and to_id = a));
end $function$;
revoke all on function private.befriend(uuid, uuid) from public, anon, authenticated;

-- send a request. If they already asked you, this accepts theirs instead.
create or replace function public.friend_send(p_to uuid)
 returns jsonb language plpgsql security definer set search_path to ''
as $function$
declare uid uuid := private.require_account(); r public.friend_requests; n int;
begin
  if p_to is null or p_to = uid then raise exception 'That is your own account' using errcode = '22023'; end if;
  if not exists (select 1 from public.profiles p where p.id = p_to and not p.banned and p.username is not null) then
    raise exception 'No player with that name' using errcode = '22023'; end if;
  if private.are_friends(uid, p_to) then return jsonb_build_object('state', 'friends'); end if;
  select * into r from public.friend_requests where from_id = p_to and to_id = uid and status = 'pending';
  if found then
    perform private.befriend(uid, p_to);
    insert into public.notifications (user_id, kind, from_id) values (p_to, 'friend_accepted', uid);
    return jsonb_build_object('state', 'friends');
  end if;
  if exists (select 1 from public.friend_requests where from_id = uid and to_id = p_to and status = 'pending') then
    return jsonb_build_object('state', 'sent'); end if;
  -- rate limits (no blocking, so these keep requests from turning into spam)
  select count(*) into n from public.friend_requests where from_id = uid and created_at > now() - interval '10 minutes';
  if n >= 10 then raise exception 'Too many requests. Try again in a few minutes' using errcode = '22023'; end if;
  select count(*) into n from public.friend_requests where from_id = uid and created_at > now() - interval '1 day';
  if n >= 40 then raise exception 'Daily request limit reached. Try again tomorrow' using errcode = '22023'; end if;
  select count(*) into n from public.friend_requests where from_id = uid and status = 'pending';
  if n >= 30 then raise exception 'You have 30 requests waiting. Cancel some first' using errcode = '22023'; end if;
  select count(*) into n from public.friendships where uid in (user_a, user_b);
  if n >= 200 then raise exception 'Your friends list is full (200)' using errcode = '22023'; end if;
  -- a declined request can be sent again after a day, not straight away
  if exists (select 1 from public.friend_requests where from_id = uid and to_id = p_to and status = 'declined' and answered_at > now() - interval '1 day') then
    raise exception 'They passed on your last request. Try again tomorrow' using errcode = '22023'; end if;
  insert into public.friend_requests (from_id, to_id) values (uid, p_to) returning * into r;
  -- one mailbox note per sender per day, however often they re-send after cancelling
  if not exists (select 1 from public.notifications where user_id = p_to and from_id = uid and kind = 'friend_request' and created_at > now() - interval '1 day') then
    insert into public.notifications (user_id, kind, from_id, data) values (p_to, 'friend_request', uid, jsonb_build_object('request', r.id));
  end if;
  return jsonb_build_object('state', 'sent', 'id', r.id);
end $function$;

create or replace function public.friend_answer(p_id bigint, p_accept boolean)
 returns jsonb language plpgsql security definer set search_path to ''
as $function$
declare uid uuid := private.require_account(); r public.friend_requests; n int;
begin
  select * into r from public.friend_requests where id = p_id and to_id = uid and status = 'pending' for update;
  if not found then raise exception 'That request is no longer open' using errcode = '22023'; end if;
  if p_accept then
    select count(*) into n from public.friendships where uid in (user_a, user_b);
    if n >= 200 then raise exception 'Your friends list is full (200)' using errcode = '22023'; end if;
    perform private.befriend(uid, r.from_id);
    insert into public.notifications (user_id, kind, from_id) values (r.from_id, 'friend_accepted', uid);
    return jsonb_build_object('state', 'friends');
  end if;
  update public.friend_requests set status = 'declined', answered_at = now() where id = p_id;
  return jsonb_build_object('state', 'declined');
end $function$;

create or replace function public.friend_cancel(p_id bigint)
 returns jsonb language plpgsql security definer set search_path to ''
as $function$
declare uid uuid := private.require_account();
begin
  update public.friend_requests set status = 'cancelled', answered_at = now() where id = p_id and from_id = uid and status = 'pending';
  if not found then raise exception 'That request is no longer open' using errcode = '22023'; end if;
  -- take back the unread mailbox note too
  delete from public.notifications where kind = 'friend_request' and from_id = uid and seen_at is null and (data->>'request')::bigint = p_id;
  return jsonb_build_object('state', 'cancelled');
end $function$;

create or replace function public.friend_remove(p_other uuid)
 returns jsonb language plpgsql security definer set search_path to ''
as $function$
declare uid uuid := private.require_account();
begin
  delete from public.friendships where user_a = least(uid, p_other) and user_b = greatest(uid, p_other);
  return jsonb_build_object('state', 'removed');
end $function$;

-- everything the Friends menu shows, in one call (the menu checks every 15 s while it is open)
create or replace function public.social_state()
 returns jsonb language plpgsql stable security definer set search_path to ''
as $function$
declare uid uuid := private.require_user();
begin
  return jsonb_build_object(
    'friends', coalesce((select jsonb_agg(jsonb_build_object('id', p.id, 'username', p.username, 'cos', p.cos, 'since', f.created_at) order by lower(p.username::text))
        from public.friendships f join public.profiles p on p.id = case when f.user_a = uid then f.user_b else f.user_a end
        where uid in (f.user_a, f.user_b) and not p.banned), '[]'::jsonb),
    'incoming', coalesce((select jsonb_agg(jsonb_build_object('id', r.id, 'user', jsonb_build_object('id', p.id, 'username', p.username, 'cos', p.cos), 'at', r.created_at) order by r.created_at desc)
        from public.friend_requests r join public.profiles p on p.id = r.from_id
        where r.to_id = uid and r.status = 'pending' and not p.banned), '[]'::jsonb),
    'outgoing', coalesce((select jsonb_agg(jsonb_build_object('id', r.id, 'user', jsonb_build_object('id', p.id, 'username', p.username, 'cos', p.cos), 'at', r.created_at) order by r.created_at desc)
        from public.friend_requests r join public.profiles p on p.id = r.to_id
        where r.from_id = uid and r.status = 'pending'), '[]'::jsonb),
    'notes', coalesce((select jsonb_agg(x order by x.created_at desc) from (
        select n.id, n.kind, n.data, n.created_at, n.seen_at, jsonb_build_object('id', p.id, 'username', p.username) as "user"
        from public.notifications n left join public.profiles p on p.id = n.from_id
        where n.user_id = uid order by n.created_at desc limit 40) x), '[]'::jsonb),
    'unseen', (select count(*) from public.notifications n where n.user_id = uid and n.seen_at is null),
    'is_anonymous', coalesce((auth.jwt()->>'is_anonymous')::boolean, false));
end $function$;

-- the mailbox was looked at: mark it seen (and tidy away seen notes older than a month)
create or replace function public.notes_seen(p_upto bigint default null)
 returns jsonb language plpgsql security definer set search_path to ''
as $function$
declare uid uuid := private.require_user(); n int;
begin
  update public.notifications set seen_at = now() where user_id = uid and seen_at is null and (p_upto is null or id <= p_upto);
  get diagnostics n = row_count;
  delete from public.notifications where user_id = uid and seen_at < now() - interval '30 days';
  return jsonb_build_object('seen', n);
end $function$;

revoke all on function public.friend_send(uuid), public.friend_answer(bigint, boolean), public.friend_cancel(bigint),
  public.friend_remove(uuid), public.social_state(), public.notes_seen(bigint) from public, anon;
grant execute on function public.friend_send(uuid), public.friend_answer(bigint, boolean), public.friend_cancel(bigint),
  public.friend_remove(uuid), public.social_state(), public.notes_seen(bigint) to authenticated;

-- PALISADE v0.9.1, part 2 of the migration: structured claim results (cases per type, unlocked item ids, raids to
-- the next Supply Case), two bosses per XL boss raid (checked against play time), and "Glitch Mask" -> "Glitch Head".
-- Older clients keep working: they send no size, and the old fields are all still returned.
update public.cosmetics set name = 'Glitch Head' where id = 'hat:glitch';
CREATE OR REPLACE FUNCTION public.claim_match_reward(p jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare uid uuid := private.require_user(); l public.lockers; ct public.case_types; cb public.case_types;
  v_kind text := p->>'kind'; v_mode text := coalesce(p->>'mode', '5'); v_pvp text := coalesce(p->>'pvp', '');
  v_diff text := coalesce(p->>'diff', 'normal'); v_win boolean := coalesce(p->>'win' = 'true', false);
  v_held int := greatest(coalesce(private.num(p->>'held'), 0), 0)::int; v_kills int := greatest(coalesce(private.num(p->>'kills'), 0), 0)::int;
  v_dur int := coalesce(private.num(p->>'duration_s'), 0)::int; v_boss int := least(greatest(coalesce(private.num(p->>'bosses'), 0), 0), 100)::int;
  waves int := 0; v_st jsonb; v_prog int; earned int := 0; granted int; got text[]; v_case text := 'supply'; chance float8; v_bonus int := 0;
  v_budget float8;
  -- salvage left at the end of a co-op / Endless run: 20 to 1, at most 2 shards per raid held and 10 a run (same as the game)
  v_sal int := least(greatest(coalesce(private.num(p->>'salvage'), 0), 0), 1000000)::int; v_shards int := 0;
  -- v0.9.0: which bosses went down (each boss drops its own case; the October Butcher drops two Halloween Cases)
  v_keys jsonb := p->'boss_keys'; v_key text; v_cap int; v_n int := 0; v_hal int := 0; v_glow int := 0;
  -- v0.9.1: an XL (24x24) boss raid has two bosses. The size only counts when the play time backs it up.
  v_xl boolean := coalesce(p->>'size', 'std') = 'xl'; v_before text[]; v_new text[];
  v_oct boolean := (now() at time zone 'UTC') >= make_timestamp(extract(year from now())::int, 9, 30, 10, 0, 0)
               and (now() at time zone 'UTC') <  make_timestamp(extract(year from now())::int, 11, 1, 14, 0, 0);
begin
  if v_kind is null or v_kind not in ('run', 'match') then raise exception 'Unknown result' using errcode = '22023'; end if;
  if v_dur < 20 or v_dur > 21600 or (v_kind = 'match' and v_dur < 30) then raise exception 'That match length doesn''t add up' using errcode = '22023'; end if;
  -- real players land well under 0.3 drops a second; 1 a second leaves lots of room
  if v_kills > v_dur then raise exception 'That kill count doesn''t add up' using errcode = '22023'; end if;
  select * into l from public.lockers where user_id = uid for update;
  if exists (select 1 from public.match_results m where m.user_id = uid and m.created_at > now() - interval '20 seconds') then
    raise exception 'Rewards were claimed a moment ago' using errcode = '22023';
  end if;
  v_budget := least(22200, l.play_budget + extract(epoch from now() - l.budget_at));
  if v_dur > v_budget + 60 then
    raise exception 'More play time than real time so far; this result will be saved later' using errcode = '22023';
  end if;
  v_st := l.st; v_prog := l.prog;
  if v_kind = 'run' then
    if v_mode not in ('5', '10', 'endless') or v_diff not in ('easy', 'normal', 'hard') then raise exception 'Unknown mode' using errcode = '22023'; end if;
    waves := case v_mode when '5' then 5 when '10' then 10 else 0 end;
    -- each raid has to spawn its whole wave, and waves grow: at least ~8 s a raid plus more for later ones
    if (waves > 0 and v_held > waves) or v_dur + 20 < 8 * v_held + (v_held * v_held) / 4 then raise exception 'That raid count doesn''t add up' using errcode = '22023'; end if;
    if waves = 0 or v_held <> waves then v_win := false; end if;
    v_st := jsonb_set(v_st, '{raids}', to_jsonb(coalesce((v_st->>'raids')::int, 0) + v_held));
    v_st := jsonb_set(v_st, '{drops}', to_jsonb(coalesce((v_st->>'drops')::int, 0) + v_kills));
    if v_win then
      v_st := jsonb_set(v_st, '{wins}', to_jsonb(coalesce((v_st->>'wins')::int, 0) + 1));
      if v_diff = 'hard' then v_st := jsonb_set(v_st, '{hardWins}', to_jsonb(coalesce((v_st->>'hardWins')::int, 0) + 1)); end if;
    end if;
    if waves = 0 then v_st := jsonb_set(v_st, '{endless}', to_jsonb(greatest(coalesce((v_st->>'endless')::int, 0), v_held))); end if;
    v_prog := v_prog + v_held;
    earned := v_prog / 3 + case when v_win then (case when waves >= 10 then 2 else 1 end) else 0 end + case when waves = 0 then v_held / 5 else 0 end;
    v_prog := v_prog % 3;
    -- a boss every fifth raid: no more bosses than raids held allow
    v_cap := (v_held + 1) / 5;
    if waves > 0 then v_cap := least(v_cap, waves / 5); end if;
    -- XL: two bosses per boss raid, but only if the run took at least 35 s a raid (a false "xl" earns nothing extra)
    if v_xl and v_dur >= 35 * v_held then v_cap := v_cap * 2; end if;
    if jsonb_typeof(v_keys) = 'array' then
      for v_key in select value from jsonb_array_elements_text(v_keys) limit 40 loop
        exit when v_n >= v_cap;
        if v_key in ('butcher', 'ferryman') then v_hal := v_hal + 1; v_n := v_n + 1;
        elsif v_key = 'butcher_oct' then v_hal := v_hal + case when v_oct then 2 else 1 end; v_n := v_n + 1;
        elsif v_key in ('demolisher', 'storm', 'foreman') then v_glow := v_glow + 1; v_n := v_n + 1;
        end if;
      end loop;
      v_boss := v_n;
    else
      -- older clients only send a count: those bosses pay Afterglow Cases as before
      v_boss := least(v_boss, v_cap); v_glow := v_boss;
    end if;
    select * into cb from public.case_types c where c.drop ? 'boss' order by c.sort limit 1;
    if found then v_glow := v_glow * coalesce((cb.drop->'boss'->>'each')::int, 1); end if;
    v_bonus := v_glow + v_hal;
    v_shards := least(v_sal / 20, 2 * v_held, 10);
  else
    if v_pvp not in ('base', 'ffa') then raise exception 'Unknown match type' using errcode = '22023'; end if;
    v_st := jsonb_set(v_st, '{drops}', to_jsonb(coalesce((v_st->>'drops')::int, 0) + v_kills));
    v_st := jsonb_set(v_st, '{pvp}', to_jsonb(coalesce((v_st->>'pvp')::int, 0) + 1));
    if v_win then v_st := jsonb_set(v_st, '{pvpWins}', to_jsonb(coalesce((v_st->>'pvpWins')::int, 0) + 1)); end if;
    v_case := null;
    select * into ct from public.case_types c where v_pvp = any(c.modes) order by c.sort limit 1;
    if found then
      v_case := ct.id;
      chance := coalesce((ct.drop->v_pvp->>(case when v_win then 'win' else 'loss' end))::float8, 0);
      if random() < chance then earned := 1; end if;
    end if;
  end if;
  granted := earned;
  v_before := l.owned;
  update public.lockers set st = v_st, prog = v_prog,
      cases = cases + case when v_case = 'supply' then granted else 0 end,
      bag = private.bag_add(private.bag_add(
              case when v_case is not null and v_case <> 'supply' and granted > 0 then private.bag_add(bag, v_case, granted) else bag end,
              coalesce(cb.id, 'afterglow'), v_glow), 'halloween', v_hal),
      shards = shards + v_shards,
      play_budget = greatest(0, v_budget - v_dur), budget_at = now(),
      rev = rev + 1, updated_at = now()
    where user_id = uid;
  insert into public.match_results (user_id, kind, mode, pvp, diff, win, held, kills, duration_s, cases_granted, case_id, bonus, shards)
    values (uid, v_kind, case when v_kind = 'run' then v_mode end, nullif(v_pvp, ''), case when v_kind = 'run' then v_diff end,
            v_win, v_held, v_kills, v_dur, granted, v_case, v_bonus, v_shards);
  update public.player_stats s set
      raids = s.raids + case when v_kind = 'run' then v_held else 0 end,
      wins = s.wins + case when v_kind = 'run' and v_win then 1 else 0 end,
      drops = s.drops + v_kills,
      best_endless = greatest(s.best_endless, case when v_kind = 'run' and waves = 0 then v_held else 0 end),
      pvp = s.pvp + case when v_kind = 'match' then 1 else 0 end,
      pvp_wins = s.pvp_wins + case when v_kind = 'match' and v_win then 1 else 0 end,
      updated_at = now()
    where s.user_id = uid;
  got := private.apply_unlocks(uid);
  select * into l from public.lockers where user_id = uid;
  v_new := array(select u from unnest(l.owned) u where not (u = any(v_before)));
  return jsonb_build_object(
    -- v0.9.1: structured, for the reward cards
    'cases', case when v_kind = 'run'
        then jsonb_build_object('supply', granted, coalesce(cb.id, 'afterglow'), v_glow, 'halloween', v_hal)
        else case when v_case is not null then jsonb_build_object(v_case, granted) else '{}'::jsonb end end,
    'unlocked_ids', to_jsonb(v_new), 'to_next', 3 - l.prog, 'size', case when v_xl and v_dur >= 35 * v_held then 'xl' else 'std' end,
    'cases_granted', granted, 'case_id', v_case, 'capped', false, 'chance', chance,
    'bonus', jsonb_build_object('case', coalesce(cb.id, 'afterglow'), 'n', v_glow), 'shards', v_shards,
    'bonuses', jsonb_build_array(jsonb_build_object('case', coalesce(cb.id, 'afterglow'), 'n', v_glow), jsonb_build_object('case', 'halloween', 'n', v_hal)),
    'unlocked', to_jsonb(got), 'locker', private.locker_out(l));
end $function$;

-- SOURCE: v0.9.2-migration.sql
-- PALISADE v0.9.2 migration. APPLY WITH THE v0.9.2 PUSH (not before): run this whole file once in the Supabase SQL editor,
-- or through the migration tool. Tested in rolled-back transactions on the test account.
--
-- Part 1: match records. Every co-op/PvP result now carries the shared game id, which raids the player was there for
--   (joined at / left at, raid number and seconds), whether they left early, their armory upgrades, the salvage they
--   ended with, the modifiers and the map. Old rows keep empty values.
-- Part 2: the rejoin fix. A player is only paid for the raids they were there for, and never twice for the same raids
--   of the same game: a second claim with the same game id starts where the first one ended (bosses too).
-- Part 3: modifiers. The server keeps its own table of what each modifier does to rewards and works the bonus out
--   from the list; in-between bosses (Boss Rush, Nightmare) pay 15-30 shards each, only when the run has one of those
--   modifiers, the count fits the raids held and the play time backs it up.
-- Part 4: skill points and the skill tree. 1 point per 5 raids held, 1 per boss. Nodes are bought and reset (for
--   shards) through the functions below; the tree itself is in private.skill_defs().

-- ---------- part 1: columns
alter table public.match_results
  add column if not exists game_id text,
  add column if not exists raid_from int,
  add column if not exists raid_to int,
  add column if not exists joined_s int,
  add column if not exists left_s int,
  add column if not exists left_early boolean,
  add column if not exists upgrades text,
  add column if not exists salvage int,
  add column if not exists mods text[],
  add column if not exists map text,
  add column if not exists size text,
  add column if not exists shard_bosses int not null default 0,
  add column if not exists skill_points int not null default 0;
create index if not exists match_results_game on public.match_results (user_id, game_id) where game_id is not null;
create index if not exists match_results_game_all on public.match_results (game_id) where game_id is not null;

alter table public.lockers
  add column if not exists sp int not null default 0,          -- skill points not spent yet
  add column if not exists sp_prog int not null default 0,     -- raids held toward the next point (0-4)
  add column if not exists sp_total int not null default 0,    -- every point ever earned
  add column if not exists skills jsonb not null default '{}'::jsonb;   -- {node id: level}

-- ---------- part 3: what each modifier does to rewards (percent; the game has the same table)
CREATE OR REPLACE FUNCTION private.mod_bonus(p_id text, p_pvp text)
 RETURNS int LANGUAGE sql IMMUTABLE SET search_path TO '' AS $function$
  select case when coalesce(p_pvp, '') in ('base', 'ffa') then
      case p_id when 'adrenaline' then -15 when 'weather' then 0 when 'nightmare' then 0 when 'glass' then 0 when 'onejob' then 0
        when 'scrap' then case when p_pvp = 'base' then 0 end when 'frenzy' then 0 when 'sudden' then case when p_pvp = 'ffa' then 0 end end
    else
      case p_id when 'nopatch' then 10 when 'alone' then 20 when 'firestorm' then 10 when 'adrenaline' then -15 when 'laststand' then 10
        when 'elite' then 15 when 'bossrush' then 10 when 'weather' then 10 when 'nightmare' then 15 when 'berserk' then 10 end
    end
$function$;
-- the known modifiers in a claim for this mode (unknown ones and repeats are dropped), at most 15
CREATE OR REPLACE FUNCTION private.clean_mods(p jsonb, p_pvp text)
 RETURNS text[] LANGUAGE sql IMMUTABLE SET search_path TO '' AS $function$
  select coalesce(array_agg(distinct m order by m), '{}'::text[]) from (
    select value as m from jsonb_array_elements_text(case when jsonb_typeof(p) = 'array' then p else '[]'::jsonb end) limit 30) s
  where private.mod_bonus(m, p_pvp) is not null
$function$;

-- ---------- part 4: the tree (same order and costs as SKILLS in the game)
CREATE OR REPLACE FUNCTION private.skill_defs()
 RETURNS jsonb LANGUAGE sql IMMUTABLE SET search_path TO '' AS $function$
  select '{"dmg":{"cost":[1,2,3]},"rate":{"cost":[1,2,3]},"reload":{"cost":[1,2]},"range":{"cost":[1,2]},
    "hp":{"cost":[1,2,3]},"regen":{"cost":[2,3]},"revive":{"cost":[1,2]},"speed":{"cost":[1,2,3]},"vest":{"cost":[2,3]},"haul":{"cost":[1,2]},
    "rockets":{"cost":[1,2,3]},"pouch":{"cost":[2,3]},"molotov":{"cost":[3],"req":["pouch",1]},"ghillie":{"cost":[1,2]},"stride":{"cost":[1,2]}}'::jsonb
$function$;
CREATE OR REPLACE FUNCTION private.respec_cost() RETURNS int LANGUAGE sql IMMUTABLE SET search_path TO '' AS $function$ select 40 $function$;
CREATE OR REPLACE FUNCTION private.skill_spent(t jsonb)
 RETURNS int LANGUAGE sql IMMUTABLE SET search_path TO '' AS $function$
  select coalesce(sum((d.value->'cost'->>(l - 1))::int), 0)::int
  from jsonb_each(private.skill_defs()) d
  cross join lateral generate_series(1, least(coalesce((t->>d.key)::int, 0), jsonb_array_length(d.value->'cost'))) l
$function$;
revoke all on function private.mod_bonus(text, text), private.clean_mods(jsonb, text), private.skill_defs(), private.respec_cost(), private.skill_spent(jsonb)
  from public, anon, authenticated;

-- buy the next level of a node with skill points
CREATE OR REPLACE FUNCTION public.skill_buy(p_node text, p_rev integer DEFAULT NULL)
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO '' AS $function$
declare uid uuid := private.require_user(); l public.lockers; d jsonb := private.skill_defs()->p_node; lv int; cost int;
begin
  if d is null then raise exception 'Unknown skill' using errcode = '22023'; end if;
  select * into l from public.lockers where user_id = uid for update;
  perform private.check_rev(l, p_rev);
  lv := coalesce((l.skills->>p_node)::int, 0);
  if lv >= jsonb_array_length(d->'cost') then raise exception 'That skill is maxed' using errcode = '22023'; end if;
  if d ? 'req' and coalesce((l.skills->>(d->'req'->>0))::int, 0) < (d->'req'->>1)::int then
    raise exception 'Unlock % first', d->'req'->>0 using errcode = '22023'; end if;
  cost := (d->'cost'->>lv)::int;
  if l.sp < cost then raise exception 'That takes % skill point%', cost, case when cost = 1 then '' else 's' end using errcode = '22023'; end if;
  update public.lockers set sp = sp - cost, skills = jsonb_set(skills, array[p_node], to_jsonb(lv + 1)), rev = rev + 1, updated_at = now()
    where user_id = uid returning * into l;
  return private.locker_out(l);
end $function$;
-- take every point back out of the tree, for shards
CREATE OR REPLACE FUNCTION public.skill_respec(p_rev integer DEFAULT NULL)
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO '' AS $function$
declare uid uuid := private.require_user(); l public.lockers; back int; cost int := private.respec_cost();
begin
  select * into l from public.lockers where user_id = uid for update;
  perform private.check_rev(l, p_rev);
  back := private.skill_spent(l.skills);
  if back = 0 then raise exception 'There are no points in your tree' using errcode = '22023'; end if;
  if l.shards < cost then raise exception 'Resetting takes % shards', cost using errcode = '22023'; end if;
  update public.lockers set sp = sp + back, skills = '{}'::jsonb, shards = shards - cost, rev = rev + 1, updated_at = now()
    where user_id = uid returning * into l;
  return private.locker_out(l);
end $function$;
-- another player's tree, so the host can check what a guest says they have (levels only)
CREATE OR REPLACE FUNCTION public.skills_of(p_uid uuid)
 RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO '' AS $function$
declare uid uuid := private.require_user();
begin
  return coalesce((select l.skills from public.lockers l where l.user_id = p_uid), '{}'::jsonb);
end $function$;
revoke all on function public.skill_buy(text, integer), public.skill_respec(integer), public.skills_of(uuid) from public, anon;
grant execute on function public.skill_buy(text, integer), public.skill_respec(integer), public.skills_of(uuid) to authenticated;

-- ---------- parts 1-4: the claim
CREATE OR REPLACE FUNCTION public.claim_match_reward(p jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare uid uuid := private.require_user(); l public.lockers; ct public.case_types; cb public.case_types;
  v_kind text := p->>'kind'; v_mode text := coalesce(p->>'mode', '5'); v_pvp text := coalesce(p->>'pvp', '');
  v_diff text := coalesce(p->>'diff', 'normal'); v_win boolean := coalesce(p->>'win' = 'true', false);
  v_held int; v_kills int := greatest(coalesce(private.num(p->>'kills'), 0), 0)::int;
  v_dur int := coalesce(private.num(p->>'duration_s'), 0)::int; v_boss int := least(greatest(coalesce(private.num(p->>'bosses'), 0), 0), 100)::int;
  waves int := 0; v_st jsonb; v_prog int; earned int := 0; granted int; got text[]; v_case text := 'supply'; chance float8; v_bonus int := 0;
  v_budget float8;
  v_sal int := least(greatest(coalesce(private.num(p->>'salvage'), 0), 0), 1000000)::int; v_shards int := 0;
  v_keys jsonb := p->'boss_keys'; v_key text; v_cap int; v_n int := 0; v_hal int := 0; v_glow int := 0;
  v_xl boolean := coalesce(p->>'size', 'std') = 'xl'; v_before text[]; v_new text[];
  v_oct boolean := (now() at time zone 'UTC') >= make_timestamp(extract(year from now())::int, 9, 30, 10, 0, 0)
               and (now() at time zone 'UTC') <  make_timestamp(extract(year from now())::int, 11, 1, 14, 0, 0);
  -- v0.9.2
  v_gid text := nullif(left(coalesce(p->>'game_id', ''), 40), '');
  v_to int := greatest(coalesce(private.num(p->>'raid_to'), private.num(p->>'held'), 0), 0)::int;
  v_from int := greatest(coalesce(private.num(p->>'raid_from'), 0), 0)::int;
  v_prev int; v_first int; v_join int; v_blo int; v_bhi int; v_seen boolean := false;
  v_mods text[]; v_pct int := 0; v_credit int := 0; v_scap int;
  v_sbreq int := least(greatest(coalesce(private.num(p->>'shard_bosses'), 0), 0), 100)::int; v_sb int := 0; v_sbcap int := 0; v_sbshards int := 0;
  v_sp int := 0; v_spprog int; r int;
begin
  if v_kind is null or v_kind not in ('run', 'match') then raise exception 'Unknown result' using errcode = '22023'; end if;
  if v_dur < 20 or v_dur > 21600 or (v_kind = 'match' and v_dur < 30) then raise exception 'That match length doesn''t add up' using errcode = '22023'; end if;
  if v_kills > v_dur then raise exception 'That kill count doesn''t add up' using errcode = '22023'; end if;
  select * into l from public.lockers where user_id = uid for update;
  if exists (select 1 from public.match_results m where m.user_id = uid and m.created_at > now() - interval '20 seconds') then
    raise exception 'Rewards were claimed a moment ago' using errcode = '22023';
  end if;
  v_budget := least(22200, l.play_budget + extract(epoch from now() - l.budget_at));
  if v_dur > v_budget + 60 then
    raise exception 'More play time than real time so far; this result will be saved later' using errcode = '22023';
  end if;
  v_mods := private.clean_mods(p->'mods', v_pvp);
  select coalesce(sum(private.mod_bonus(m, v_pvp)), 0) into v_pct from unnest(v_mods) m;
  v_pct := least(greatest(v_pct, -15), 75);
  -- the same game claimed before (the player left and came back): this claim starts where that one ended
  if v_gid is not null then
    select max(m.raid_to), min(m.raid_from), count(*) > 0 into v_prev, v_first, v_seen from public.match_results m where m.user_id = uid and m.game_id = v_gid;
  end if;
  v_st := l.st; v_prog := l.prog; v_spprog := l.sp_prog;
  if v_kind = 'run' then
    if v_mode not in ('5', '10', 'endless') or v_diff not in ('easy', 'normal', 'hard') then raise exception 'Unknown mode' using errcode = '22023'; end if;
    waves := case v_mode when '5' then 5 when '10' then 10 else 0 end;
    if waves > 0 and v_to > waves then raise exception 'That raid count doesn''t add up' using errcode = '22023'; end if;
    v_from := least(v_from, v_to); v_join := least(v_from, coalesce(v_first, v_from));
    if v_prev is not null then v_from := greatest(v_from, least(v_prev, v_to)); end if;
    v_held := v_to - v_from;
    -- each raid has to spawn its whole wave, and waves grow: at least ~8 s a raid plus more for later ones
    if v_dur + 20 < 8 * v_held + (v_held * v_held) / 4 then raise exception 'That raid count doesn''t add up' using errcode = '22023'; end if;
    -- a win counts for players who were there for at least half the run, once per game
    if waves = 0 or v_to <> waves or v_join * 2 > waves or (v_seen and v_prev >= waves) then v_win := false; end if;
    v_st := jsonb_set(v_st, '{raids}', to_jsonb(coalesce((v_st->>'raids')::int, 0) + v_held));
    v_st := jsonb_set(v_st, '{drops}', to_jsonb(coalesce((v_st->>'drops')::int, 0) + v_kills));
    if v_win then
      v_st := jsonb_set(v_st, '{wins}', to_jsonb(coalesce((v_st->>'wins')::int, 0) + 1));
      if v_diff = 'hard' then v_st := jsonb_set(v_st, '{hardWins}', to_jsonb(coalesce((v_st->>'hardWins')::int, 0) + 1)); end if;
    end if;
    if waves = 0 then v_st := jsonb_set(v_st, '{endless}', to_jsonb(greatest(coalesce((v_st->>'endless')::int, 0), v_to))); end if;
    -- modifiers move the raid credit toward Supply Cases (harder: more, Adrenaline: less)
    v_credit := floor(v_held * (100 + v_pct) / 100.0)::int;
    v_prog := v_prog + v_credit;
    earned := v_prog / 3 + case when v_win then (case when waves >= 10 then 2 else 1 end) else 0 end + case when waves = 0 then v_held / 5 else 0 end;
    v_prog := v_prog % 3;
    -- bosses: the raids this claim covers are v_from+1 .. v_to+1 (a boss can fall in the raid that was lost or left),
    -- minus any raid an earlier claim for the same game already covered
    v_blo := v_from; if v_prev is not null then v_blo := greatest(v_from, v_prev + 1); end if;
    v_bhi := v_to + 1; if waves > 0 then v_bhi := least(v_bhi, waves); end if;
    v_cap := greatest(0, v_bhi / 5 - v_blo / 5);
    -- XL: two bosses per boss raid, but only if the run took at least 35 s a raid (a false "xl" earns nothing extra)
    if v_xl and v_dur >= 35 * v_held then v_cap := v_cap * 2; end if;
    if jsonb_typeof(v_keys) = 'array' then
      for v_key in select value from jsonb_array_elements_text(v_keys) limit 40 loop
        exit when v_n >= v_cap;
        if v_key in ('butcher', 'ferryman') then v_hal := v_hal + 1; v_n := v_n + 1;
        elsif v_key = 'butcher_oct' then v_hal := v_hal + case when v_oct then 2 else 1 end; v_n := v_n + 1;
        elsif v_key in ('demolisher', 'storm', 'foreman') then v_glow := v_glow + 1; v_n := v_n + 1;
        end if;
      end loop;
      v_boss := v_n;
    else
      v_boss := least(v_boss, v_cap); v_glow := v_boss; v_n := v_boss;
    end if;
    select * into cb from public.case_types c where c.drop ? 'boss' order by c.sort limit 1;
    if found then v_glow := v_glow * coalesce((cb.drop->'boss'->>'each')::int, 1); end if;
    v_bonus := v_glow + v_hal;
    -- in-between bosses (Boss Rush: the even raids; Nightmare: any raid without a boss), 15-30 shards each
    if v_sbreq > 0 and ('bossrush' = any(v_mods) or 'nightmare' = any(v_mods)) and v_dur >= 25 * greatest(v_held, 1) then
      for r in (v_blo + 1) .. v_bhi loop
        if r % 5 <> 0 and ('nightmare' = any(v_mods) or r % 2 = 0) then v_sbcap := v_sbcap + 1; end if;
      end loop;
      v_sb := least(v_sbreq, v_sbcap);
      for r in 1 .. v_sb loop v_sbshards := v_sbshards + 15 + floor(random() * 16)::int; end loop;
    end if;
    -- leftover salvage: 20 to 1, at most 2 a raid held and 10 a run (modifiers move the cap too)
    v_scap := greatest(0, floor(10 * (100 + v_pct) / 100.0)::int);
    v_shards := least(v_sal / 20, 2 * v_held, v_scap) + v_sbshards;
    -- skill points: 1 per 5 raids held, 1 per boss
    v_spprog := v_spprog + v_held;
    v_sp := v_spprog / 5 + v_n + v_sb;
    v_spprog := v_spprog % 5;
  else
    if v_pvp not in ('base', 'ffa') then raise exception 'Unknown match type' using errcode = '22023'; end if;
    v_held := 0;
    v_st := jsonb_set(v_st, '{drops}', to_jsonb(coalesce((v_st->>'drops')::int, 0) + v_kills));
    if not v_seen then
      v_st := jsonb_set(v_st, '{pvp}', to_jsonb(coalesce((v_st->>'pvp')::int, 0) + 1));
      if v_win then v_st := jsonb_set(v_st, '{pvpWins}', to_jsonb(coalesce((v_st->>'pvpWins')::int, 0) + 1)); end if;
    end if;
    v_case := null;
    select * into ct from public.case_types c where v_pvp = any(c.modes) order by c.sort limit 1;
    if found then
      v_case := ct.id;
      chance := coalesce((ct.drop->v_pvp->>(case when v_win then 'win' else 'loss' end))::float8, 0) * (100 + v_pct) / 100.0;
      if v_seen then chance := 0; end if;   -- one roll per match
      if random() < chance then earned := 1; end if;
    end if;
  end if;
  granted := earned;
  v_before := l.owned;
  update public.lockers set st = v_st, prog = v_prog,
      cases = cases + case when v_case = 'supply' then granted else 0 end,
      bag = private.bag_add(private.bag_add(
              case when v_case is not null and v_case <> 'supply' and granted > 0 then private.bag_add(bag, v_case, granted) else bag end,
              coalesce(cb.id, 'afterglow'), v_glow), 'halloween', v_hal),
      shards = shards + v_shards,
      sp = sp + v_sp, sp_total = sp_total + v_sp, sp_prog = v_spprog,
      play_budget = greatest(0, v_budget - v_dur), budget_at = now(),
      rev = rev + 1, updated_at = now()
    where user_id = uid;
  insert into public.match_results (user_id, kind, mode, pvp, diff, win, held, kills, duration_s, cases_granted, case_id, bonus, shards,
      game_id, raid_from, raid_to, joined_s, left_s, left_early, upgrades, salvage, mods, map, size, shard_bosses, skill_points)
    values (uid, v_kind, case when v_kind = 'run' then v_mode end, nullif(v_pvp, ''), case when v_kind = 'run' then v_diff end,
            v_win, v_held, v_kills, v_dur, granted, v_case, v_bonus, v_shards,
            v_gid, case when v_kind = 'run' then v_from end, case when v_kind = 'run' then v_to end,
            least(greatest(private.num(p->>'joined_s'), 0), 86400)::int, least(greatest(private.num(p->>'left_s'), 0), 86400)::int,
            coalesce(p->>'left' = 'true', false), left(regexp_replace(coalesce(p->>'upgrades', ''), '[^0-9a-z:]', '', 'g'), 16), v_sal,
            v_mods, left(regexp_replace(coalesce(p->>'map', ''), '[^a-z]', '', 'g'), 12), case when v_xl then 'xl' else 'std' end, v_sb, v_sp);
  update public.player_stats s set
      raids = s.raids + case when v_kind = 'run' then v_held else 0 end,
      wins = s.wins + case when v_kind = 'run' and v_win then 1 else 0 end,
      drops = s.drops + v_kills,
      best_endless = greatest(s.best_endless, case when v_kind = 'run' and waves = 0 then v_to else 0 end),
      pvp = s.pvp + case when v_kind = 'match' and not v_seen then 1 else 0 end,
      pvp_wins = s.pvp_wins + case when v_kind = 'match' and v_win and not v_seen then 1 else 0 end,
      updated_at = now()
    where s.user_id = uid;
  got := private.apply_unlocks(uid);
  select * into l from public.lockers where user_id = uid;
  v_new := array(select u from unnest(l.owned) u where not (u = any(v_before)));
  return jsonb_build_object(
    'cases', case when v_kind = 'run'
        then jsonb_build_object('supply', granted, coalesce(cb.id, 'afterglow'), v_glow, 'halloween', v_hal)
        else case when v_case is not null then jsonb_build_object(v_case, granted) else '{}'::jsonb end end,
    'unlocked_ids', to_jsonb(v_new), 'to_next', 3 - l.prog, 'size', case when v_xl and v_dur >= 35 * v_held then 'xl' else 'std' end,
    'cases_granted', granted, 'case_id', v_case, 'capped', false, 'chance', chance,
    'bonus', jsonb_build_object('case', coalesce(cb.id, 'afterglow'), 'n', v_glow), 'shards', v_shards,
    'bonuses', jsonb_build_array(jsonb_build_object('case', coalesce(cb.id, 'afterglow'), 'n', v_glow), jsonb_build_object('case', 'halloween', 'n', v_hal)),
    -- v0.9.2
    'held', v_held, 'raid_from', v_from, 'mods', to_jsonb(v_mods), 'mod_pct', v_pct, 'shard_bosses', v_sb, 'boss_shards', v_sbshards,
    'skill_points', v_sp, 'sp', l.sp, 'sp_to_next', 5 - l.sp_prog, 'repeat', v_seen,
    'unlocked', to_jsonb(got), 'locker', private.locker_out(l));
end $function$;

-- SOURCE: v0.9.3-migration.sql
-- PALISADE v0.9.3: milestone cosmetics, class rewards, more Halloween, the Flag Case.
-- Run once, when v0.9.3 is published (not before). Tested first inside a rolled-back transaction on the test account.
--  * the Flag Case (drop.win: the chance for everyone after any win; 10 shards)
--  * 122 new items: 48 milestone unlocks (need: a locker counter), 10 Halloween Case items, 64 Flag Case items
--  * claim_match_reward adds to the new counters (boss_<boss>, map_<map>, cls_<class>_raids) and rolls the Flag Case;
--    older copies of the game keep working (their claims just add nothing to the new counters)
--  * match_results.cls: the class a player ended a run as, so it's on record from now on
-- Nothing here touches existing players' lockers: every counter starts at zero.

alter table public.match_results add column if not exists cls text;

insert into public.case_types (id, name, weights, shard_cost, modes, drop, sort)
values ('flags', 'FLAG CASE', '{"c":45,"r":30,"e":17,"l":7,"g":1}'::jsonb, 10, '{}', '{"win":0.25}'::jsonb, 3)
on conflict (id) do nothing;

insert into public.cosmetics (id, cat, key, name, rarity, src, need, box) values
  ('skin:sheetghost', 'skin', 'sheetghost', 'Sheet Ghost', 'c', 'case', null, 'halloween'),
  ('trail:candle', 'trail', 'candle', 'Candle Flicker', 'c', 'case', null, 'halloween'),
  ('skin:scarecrow', 'skin', 'scarecrow', 'Scarecrow', 'r', 'case', null, 'halloween'),
  ('trail:poison', 'trail', 'poison', 'Poison Apple', 'r', 'case', null, 'halloween'),
  ('skin:monster', 'skin', 'monster', 'Frankenstein''s Monster', 'e', 'case', null, 'halloween'),
  ('skin:clown', 'skin', 'clown', 'Scary Clown', 'e', 'case', null, 'halloween'),
  ('trail:blood', 'trail', 'blood', 'Blood Trail', 'e', 'case', null, 'halloween'),
  ('skin:slasher', 'skin', 'slasher', 'Hockey-Mask Slasher', 'l', 'case', null, 'halloween'),
  ('skin:dracula', 'skin', 'dracula', 'Dracula', 'l', 'case', null, 'halloween'),
  ('trail:hellfire', 'trail', 'hellfire', 'Hellfire', 'l', 'case', null, 'halloween'),
  ('skin:butcher', 'skin', 'butcher', 'Butcher', 'r', 'unlock', '{"boss_butcher":25}'::jsonb, null),
  ('skin:butcher2', 'skin', 'butcher2', 'Pale Butcher', 'e', 'unlock', '{"boss_butcher":50}'::jsonb, null),
  ('skin:butcher3', 'skin', 'butcher3', 'Bloodrage Butcher', 'l', 'unlock', '{"boss_butcher":100}'::jsonb, null),
  ('skin:butcher4', 'skin', 'butcher4', 'Gilded Butcher', 'g', 'unlock', '{"boss_butcher":250}'::jsonb, null),
  ('skin:demo', 'skin', 'demo', 'Demolisher', 'r', 'unlock', '{"boss_demolisher":25}'::jsonb, null),
  ('skin:demo2', 'skin', 'demo2', 'Desert Demolisher', 'e', 'unlock', '{"boss_demolisher":50}'::jsonb, null),
  ('skin:demo3', 'skin', 'demo3', 'Live-Fuse Demolisher', 'l', 'unlock', '{"boss_demolisher":100}'::jsonb, null),
  ('skin:demo4', 'skin', 'demo4', 'Gilded Demolisher', 'g', 'unlock', '{"boss_demolisher":250}'::jsonb, null),
  ('skin:storm', 'skin', 'storm', 'Stormcaller', 'r', 'unlock', '{"boss_storm":25}'::jsonb, null),
  ('skin:storm2', 'skin', 'storm2', 'Violet Stormcaller', 'e', 'unlock', '{"boss_storm":50}'::jsonb, null),
  ('skin:storm3', 'skin', 'storm3', 'Crackling Stormcaller', 'l', 'unlock', '{"boss_storm":100}'::jsonb, null),
  ('skin:storm4', 'skin', 'storm4', 'Gilded Stormcaller', 'g', 'unlock', '{"boss_storm":250}'::jsonb, null),
  ('skin:ferry', 'skin', 'ferry', 'Ferryman', 'r', 'unlock', '{"boss_ferryman":25}'::jsonb, null),
  ('skin:ferry2', 'skin', 'ferry2', 'Blackwater Ferryman', 'e', 'unlock', '{"boss_ferryman":50}'::jsonb, null),
  ('skin:ferry3', 'skin', 'ferry3', 'Drowned Ferryman', 'l', 'unlock', '{"boss_ferryman":100}'::jsonb, null),
  ('skin:ferry4', 'skin', 'ferry4', 'Gilded Ferryman', 'g', 'unlock', '{"boss_ferryman":250}'::jsonb, null),
  ('skin:foreman', 'skin', 'foreman', 'Foreman', 'r', 'unlock', '{"boss_foreman":25}'::jsonb, null),
  ('skin:foreman2', 'skin', 'foreman2', 'Night-Shift Foreman', 'e', 'unlock', '{"boss_foreman":50}'::jsonb, null),
  ('skin:foreman3', 'skin', 'foreman3', 'Sparking Foreman', 'l', 'unlock', '{"boss_foreman":100}'::jsonb, null),
  ('skin:foreman4', 'skin', 'foreman4', 'Gilded Foreman', 'g', 'unlock', '{"boss_foreman":250}'::jsonb, null),
  ('skin:yard', 'skin', 'yard', 'Yard Hand', 'r', 'unlock', '{"map_yard":250}'::jsonb, null),
  ('skin:yard2', 'skin', 'yard2', 'Harvest Hand', 'e', 'unlock', '{"map_yard":500}'::jsonb, null),
  ('skin:yard3', 'skin', 'yard3', 'Firefly Hand', 'l', 'unlock', '{"map_yard":1000}'::jsonb, null),
  ('skin:yard4', 'skin', 'yard4', 'Golden Yard', 'g', 'unlock', '{"map_yard":2500}'::jsonb, null),
  ('skin:river', 'skin', 'river', 'River Rat', 'r', 'unlock', '{"map_river":250}'::jsonb, null),
  ('skin:river2', 'skin', 'river2', 'Silt Rat', 'e', 'unlock', '{"map_river":500}'::jsonb, null),
  ('skin:river3', 'skin', 'river3', 'Rain Rat', 'l', 'unlock', '{"map_river":1000}'::jsonb, null),
  ('skin:river4', 'skin', 'river4', 'Golden River', 'g', 'unlock', '{"map_river":2500}'::jsonb, null),
  ('skin:quarry', 'skin', 'quarry', 'Quarry Hand', 'r', 'unlock', '{"map_quarry":250}'::jsonb, null),
  ('skin:quarry2', 'skin', 'quarry2', 'Oil-Drum Hand', 'e', 'unlock', '{"map_quarry":500}'::jsonb, null),
  ('skin:quarry3', 'skin', 'quarry3', 'Ashfall Hand', 'l', 'unlock', '{"map_quarry":1000}'::jsonb, null),
  ('skin:quarry4', 'skin', 'quarry4', 'Golden Quarry', 'g', 'unlock', '{"map_quarry":2500}'::jsonb, null),
  ('hat:officer', 'hat', 'officer', 'Officer''s Cap', 'r', 'unlock', '{"cls_soldier_raids":250}'::jsonb, null),
  ('trail:rocket', 'trail', 'rocket', 'Rocket Trail', 'e', 'unlock', '{"cls_soldier_raids":500}'::jsonb, null),
  ('fx:rocketburst', 'fx', 'rocketburst', 'Rocket Burst', 'l', 'unlock', '{"cls_soldier_raids":1000}'::jsonb, null),
  ('skin:gsoldier', 'skin', 'gsoldier', 'Gold Commander', 'g', 'unlock', '{"cls_soldier_raids":2500}'::jsonb, null),
  ('hat:ghood', 'hat', 'ghood', 'Ghillie Hood', 'r', 'unlock', '{"cls_sniper_raids":250}'::jsonb, null),
  ('trail:hairline', 'trail', 'hairline', 'Hairline', 'e', 'unlock', '{"cls_sniper_raids":500}'::jsonb, null),
  ('fx:reticle', 'fx', 'reticle', 'Reticle', 'l', 'unlock', '{"cls_sniper_raids":1000}'::jsonb, null),
  ('skin:gsniper', 'skin', 'gsniper', 'Gold Ghillie', 'g', 'unlock', '{"cls_sniper_raids":2500}'::jsonb, null),
  ('hat:bombhelm', 'hat', 'bombhelm', 'Blast Helmet', 'r', 'unlock', '{"cls_grenadier_raids":250}'::jsonb, null),
  ('trail:fuse', 'trail', 'fuse', 'Lit Fuse', 'e', 'unlock', '{"cls_grenadier_raids":500}'::jsonb, null),
  ('fx:frag', 'fx', 'frag', 'Frag Burst', 'l', 'unlock', '{"cls_grenadier_raids":1000}'::jsonb, null),
  ('skin:ggren', 'skin', 'ggren', 'Gold Demolitions', 'g', 'unlock', '{"cls_grenadier_raids":2500}'::jsonb, null),
  ('hat:qmset', 'hat', 'qmset', 'Supply Headset', 'r', 'unlock', '{"cls_quartermaster_raids":250}'::jsonb, null),
  ('trail:supply', 'trail', 'supply', 'Supply Line', 'e', 'unlock', '{"cls_quartermaster_raids":500}'::jsonb, null),
  ('fx:salvage', 'fx', 'salvage', 'Salvage Pop', 'l', 'unlock', '{"cls_quartermaster_raids":1000}'::jsonb, null),
  ('skin:gqm', 'skin', 'gqm', 'Gold Quartermaster', 'g', 'unlock', '{"cls_quartermaster_raids":2500}'::jsonb, null),
  ('trail:f_pride', 'trail', 'f_pride', 'Rainbow Pride Flag', 'g', 'case', null, 'flags'),
  ('trail:f_progress', 'trail', 'f_progress', 'Progress Pride Flag', 'g', 'case', null, 'flags'),
  ('trail:f_trans', 'trail', 'f_trans', 'Transgender Flag', 'l', 'case', null, 'flags'),
  ('trail:f_bi', 'trail', 'f_bi', 'Bisexual Flag', 'l', 'case', null, 'flags'),
  ('trail:f_lesbian', 'trail', 'f_lesbian', 'Lesbian Flag', 'l', 'case', null, 'flags'),
  ('trail:f_gay', 'trail', 'f_gay', 'Gay Men Flag', 'l', 'case', null, 'flags'),
  ('trail:f_pan', 'trail', 'f_pan', 'Pansexual Flag', 'l', 'case', null, 'flags'),
  ('trail:f_nonbinary', 'trail', 'f_nonbinary', 'Nonbinary Flag', 'l', 'case', null, 'flags'),
  ('trail:f_ace', 'trail', 'f_ace', 'Asexual Flag', 'l', 'case', null, 'flags'),
  ('trail:f_aro', 'trail', 'f_aro', 'Aromantic Flag', 'l', 'case', null, 'flags'),
  ('trail:f_fluid', 'trail', 'f_fluid', 'Genderfluid Flag', 'l', 'case', null, 'flags'),
  ('trail:f_agender', 'trail', 'f_agender', 'Agender Flag', 'l', 'case', null, 'flags'),
  ('trail:f_intersex', 'trail', 'f_intersex', 'Intersex Flag', 'l', 'case', null, 'flags'),
  ('trail:f_usa', 'trail', 'f_usa', 'United States Flag', 'e', 'case', null, 'flags'),
  ('trail:f_mexico', 'trail', 'f_mexico', 'Mexico Flag', 'e', 'case', null, 'flags'),
  ('trail:f_brazil', 'trail', 'f_brazil', 'Brazil Flag', 'e', 'case', null, 'flags'),
  ('trail:f_japan', 'trail', 'f_japan', 'Japan Flag', 'e', 'case', null, 'flags'),
  ('trail:f_skorea', 'trail', 'f_skorea', 'South Korea Flag', 'e', 'case', null, 'flags'),
  ('trail:f_puertorico', 'trail', 'f_puertorico', 'Puerto Rico Flag', 'e', 'case', null, 'flags'),
  ('trail:f_canada', 'trail', 'f_canada', 'Canada Flag', 'r', 'case', null, 'flags'),
  ('trail:f_uk', 'trail', 'f_uk', 'United Kingdom Flag', 'r', 'case', null, 'flags'),
  ('trail:f_germany', 'trail', 'f_germany', 'Germany Flag', 'r', 'case', null, 'flags'),
  ('trail:f_france', 'trail', 'f_france', 'France Flag', 'r', 'case', null, 'flags'),
  ('trail:f_italy', 'trail', 'f_italy', 'Italy Flag', 'r', 'case', null, 'flags'),
  ('trail:f_spain', 'trail', 'f_spain', 'Spain Flag', 'r', 'case', null, 'flags'),
  ('trail:f_ireland', 'trail', 'f_ireland', 'Ireland Flag', 'r', 'case', null, 'flags'),
  ('trail:f_argentina', 'trail', 'f_argentina', 'Argentina Flag', 'r', 'case', null, 'flags'),
  ('trail:f_philippines', 'trail', 'f_philippines', 'Philippines Flag', 'r', 'case', null, 'flags'),
  ('trail:f_india', 'trail', 'f_india', 'India Flag', 'c', 'case', null, 'flags'),
  ('trail:f_israel', 'trail', 'f_israel', 'Israel Flag', 'c', 'case', null, 'flags'),
  ('trail:f_russia', 'trail', 'f_russia', 'Russia Flag', 'c', 'case', null, 'flags'),
  ('trail:f_nkorea', 'trail', 'f_nkorea', 'North Korea Flag', 'c', 'case', null, 'flags'),
  ('bg:f_pride', 'bg', 'f_pride', 'Rainbow Pride Flag', 'g', 'case', null, 'flags'),
  ('bg:f_progress', 'bg', 'f_progress', 'Progress Pride Flag', 'g', 'case', null, 'flags'),
  ('bg:f_trans', 'bg', 'f_trans', 'Transgender Flag', 'l', 'case', null, 'flags'),
  ('bg:f_bi', 'bg', 'f_bi', 'Bisexual Flag', 'l', 'case', null, 'flags'),
  ('bg:f_lesbian', 'bg', 'f_lesbian', 'Lesbian Flag', 'l', 'case', null, 'flags'),
  ('bg:f_gay', 'bg', 'f_gay', 'Gay Men Flag', 'l', 'case', null, 'flags'),
  ('bg:f_pan', 'bg', 'f_pan', 'Pansexual Flag', 'l', 'case', null, 'flags'),
  ('bg:f_nonbinary', 'bg', 'f_nonbinary', 'Nonbinary Flag', 'l', 'case', null, 'flags'),
  ('bg:f_ace', 'bg', 'f_ace', 'Asexual Flag', 'l', 'case', null, 'flags'),
  ('bg:f_aro', 'bg', 'f_aro', 'Aromantic Flag', 'l', 'case', null, 'flags'),
  ('bg:f_fluid', 'bg', 'f_fluid', 'Genderfluid Flag', 'l', 'case', null, 'flags'),
  ('bg:f_agender', 'bg', 'f_agender', 'Agender Flag', 'l', 'case', null, 'flags'),
  ('bg:f_intersex', 'bg', 'f_intersex', 'Intersex Flag', 'l', 'case', null, 'flags'),
  ('bg:f_usa', 'bg', 'f_usa', 'United States Flag', 'e', 'case', null, 'flags'),
  ('bg:f_mexico', 'bg', 'f_mexico', 'Mexico Flag', 'e', 'case', null, 'flags'),
  ('bg:f_brazil', 'bg', 'f_brazil', 'Brazil Flag', 'e', 'case', null, 'flags'),
  ('bg:f_japan', 'bg', 'f_japan', 'Japan Flag', 'e', 'case', null, 'flags'),
  ('bg:f_skorea', 'bg', 'f_skorea', 'South Korea Flag', 'e', 'case', null, 'flags'),
  ('bg:f_puertorico', 'bg', 'f_puertorico', 'Puerto Rico Flag', 'e', 'case', null, 'flags'),
  ('bg:f_canada', 'bg', 'f_canada', 'Canada Flag', 'r', 'case', null, 'flags'),
  ('bg:f_uk', 'bg', 'f_uk', 'United Kingdom Flag', 'r', 'case', null, 'flags'),
  ('bg:f_germany', 'bg', 'f_germany', 'Germany Flag', 'r', 'case', null, 'flags'),
  ('bg:f_france', 'bg', 'f_france', 'France Flag', 'r', 'case', null, 'flags'),
  ('bg:f_italy', 'bg', 'f_italy', 'Italy Flag', 'r', 'case', null, 'flags'),
  ('bg:f_spain', 'bg', 'f_spain', 'Spain Flag', 'r', 'case', null, 'flags'),
  ('bg:f_ireland', 'bg', 'f_ireland', 'Ireland Flag', 'r', 'case', null, 'flags'),
  ('bg:f_argentina', 'bg', 'f_argentina', 'Argentina Flag', 'r', 'case', null, 'flags'),
  ('bg:f_philippines', 'bg', 'f_philippines', 'Philippines Flag', 'r', 'case', null, 'flags'),
  ('bg:f_india', 'bg', 'f_india', 'India Flag', 'c', 'case', null, 'flags'),
  ('bg:f_israel', 'bg', 'f_israel', 'Israel Flag', 'c', 'case', null, 'flags'),
  ('bg:f_russia', 'bg', 'f_russia', 'Russia Flag', 'c', 'case', null, 'flags'),
  ('bg:f_nkorea', 'bg', 'f_nkorea', 'North Korea Flag', 'c', 'case', null, 'flags')
on conflict (id) do nothing;

CREATE OR REPLACE FUNCTION public.claim_match_reward(p jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare uid uuid := private.require_user(); l public.lockers; ct public.case_types; cb public.case_types;
  v_kind text := p->>'kind'; v_mode text := coalesce(p->>'mode', '5'); v_pvp text := coalesce(p->>'pvp', '');
  v_diff text := coalesce(p->>'diff', 'normal'); v_win boolean := coalesce(p->>'win' = 'true', false);
  v_held int; v_kills int := greatest(coalesce(private.num(p->>'kills'), 0), 0)::int;
  v_dur int := coalesce(private.num(p->>'duration_s'), 0)::int; v_boss int := least(greatest(coalesce(private.num(p->>'bosses'), 0), 0), 100)::int;
  waves int := 0; v_st jsonb; v_prog int; earned int := 0; granted int; got text[]; v_case text := 'supply'; chance float8; v_bonus int := 0;
  v_budget float8;
  v_sal int := least(greatest(coalesce(private.num(p->>'salvage'), 0), 0), 1000000)::int; v_shards int := 0;
  v_keys jsonb := p->'boss_keys'; v_key text; v_cap int; v_n int := 0; v_hal int := 0; v_glow int := 0;
  v_xl boolean := coalesce(p->>'size', 'std') = 'xl'; v_before text[]; v_new text[];
  v_oct boolean := (now() at time zone 'UTC') >= make_timestamp(extract(year from now())::int, 9, 30, 10, 0, 0)
               and (now() at time zone 'UTC') <  make_timestamp(extract(year from now())::int, 11, 1, 14, 0, 0);
  -- v0.9.2
  v_gid text := nullif(left(coalesce(p->>'game_id', ''), 40), '');
  v_to int := greatest(coalesce(private.num(p->>'raid_to'), private.num(p->>'held'), 0), 0)::int;
  v_from int := greatest(coalesce(private.num(p->>'raid_from'), 0), 0)::int;
  v_prev int; v_first int; v_join int; v_blo int; v_bhi int; v_seen boolean := false;
  v_mods text[]; v_pct int := 0; v_credit int := 0; v_scap int;
  v_sbreq int := least(greatest(coalesce(private.num(p->>'shard_bosses'), 0), 0), 100)::int; v_sb int := 0; v_sbcap int := 0; v_sbshards int := 0;
  v_sp int := 0; v_spprog int; r int;
  -- v0.9.3: milestone counters (map, class) and the Flag Case
  v_map text := left(regexp_replace(coalesce(p->>'map', ''), '[^a-z]', '', 'g'), 12);
  v_cls text := left(regexp_replace(coalesce(p->>'cls', ''), '[^a-z]', '', 'g'), 16);
  v_bk text; cf public.case_types; v_flag int := 0;
begin
  if v_kind is null or v_kind not in ('run', 'match') then raise exception 'Unknown result' using errcode = '22023'; end if;
  if v_dur < 20 or v_dur > 21600 or (v_kind = 'match' and v_dur < 30) then raise exception 'That match length doesn''t add up' using errcode = '22023'; end if;
  if v_kills > v_dur then raise exception 'That kill count doesn''t add up' using errcode = '22023'; end if;
  select * into l from public.lockers where user_id = uid for update;
  if exists (select 1 from public.match_results m where m.user_id = uid and m.created_at > now() - interval '20 seconds') then
    raise exception 'Rewards were claimed a moment ago' using errcode = '22023';
  end if;
  v_budget := least(22200, l.play_budget + extract(epoch from now() - l.budget_at));
  if v_dur > v_budget + 60 then
    raise exception 'More play time than real time so far; this result will be saved later' using errcode = '22023';
  end if;
  v_mods := private.clean_mods(p->'mods', v_pvp);
  select coalesce(sum(private.mod_bonus(m, v_pvp)), 0) into v_pct from unnest(v_mods) m;
  v_pct := least(greatest(v_pct, -15), 75);
  -- the same game claimed before (the player left and came back): this claim starts where that one ended
  if v_gid is not null then
    select max(m.raid_to), min(m.raid_from), count(*) > 0 into v_prev, v_first, v_seen from public.match_results m where m.user_id = uid and m.game_id = v_gid;
  end if;
  v_st := l.st; v_prog := l.prog; v_spprog := l.sp_prog;
  if v_kind = 'run' then
    if v_mode not in ('5', '10', 'endless') or v_diff not in ('easy', 'normal', 'hard') then raise exception 'Unknown mode' using errcode = '22023'; end if;
    waves := case v_mode when '5' then 5 when '10' then 10 else 0 end;
    if waves > 0 and v_to > waves then raise exception 'That raid count doesn''t add up' using errcode = '22023'; end if;
    v_from := least(v_from, v_to); v_join := least(v_from, coalesce(v_first, v_from));
    if v_prev is not null then v_from := greatest(v_from, least(v_prev, v_to)); end if;
    v_held := v_to - v_from;
    -- each raid has to spawn its whole wave, and waves grow: at least ~8 s a raid plus more for later ones
    if v_dur + 20 < 8 * v_held + (v_held * v_held) / 4 then raise exception 'That raid count doesn''t add up' using errcode = '22023'; end if;
    -- a win counts for players who were there for at least half the run, once per game
    if waves = 0 or v_to <> waves or v_join * 2 > waves or (v_seen and v_prev >= waves) then v_win := false; end if;
    v_st := jsonb_set(v_st, '{raids}', to_jsonb(coalesce((v_st->>'raids')::int, 0) + v_held));
    v_st := jsonb_set(v_st, '{drops}', to_jsonb(coalesce((v_st->>'drops')::int, 0) + v_kills));
    if v_win then
      v_st := jsonb_set(v_st, '{wins}', to_jsonb(coalesce((v_st->>'wins')::int, 0) + 1));
      if v_diff = 'hard' then v_st := jsonb_set(v_st, '{hardWins}', to_jsonb(coalesce((v_st->>'hardWins')::int, 0) + 1)); end if;
    end if;
    if waves = 0 then v_st := jsonb_set(v_st, '{endless}', to_jsonb(greatest(coalesce((v_st->>'endless')::int, 0), v_to))); end if;
    -- v0.9.3 milestones: raids held on each map and as each class (the class the player ended the run as)
    if v_held > 0 and v_map in ('yard', 'river', 'quarry') then
      v_st := jsonb_set(v_st, array['map_' || v_map], to_jsonb(coalesce((v_st->>('map_' || v_map))::int, 0) + v_held));
    end if;
    if v_held > 0 and v_cls in ('soldier', 'sniper', 'grenadier', 'quartermaster') then
      v_st := jsonb_set(v_st, array['cls_' || v_cls || '_raids'], to_jsonb(coalesce((v_st->>('cls_' || v_cls || '_raids'))::int, 0) + v_held));
    end if;
    -- modifiers move the raid credit toward Supply Cases (harder: more, Adrenaline: less)
    v_credit := floor(v_held * (100 + v_pct) / 100.0)::int;
    v_prog := v_prog + v_credit;
    earned := v_prog / 3 + case when v_win then (case when waves >= 10 then 2 else 1 end) else 0 end + case when waves = 0 then v_held / 5 else 0 end;
    v_prog := v_prog % 3;
    -- bosses: the raids this claim covers are v_from+1 .. v_to+1 (a boss can fall in the raid that was lost or left),
    -- minus any raid an earlier claim for the same game already covered
    v_blo := v_from; if v_prev is not null then v_blo := greatest(v_from, v_prev + 1); end if;
    v_bhi := v_to + 1; if waves > 0 then v_bhi := least(v_bhi, waves); end if;
    v_cap := greatest(0, v_bhi / 5 - v_blo / 5);
    -- XL: two bosses per boss raid, but only if the run took at least 35 s a raid (a false "xl" earns nothing extra)
    if v_xl and v_dur >= 35 * v_held then v_cap := v_cap * 2; end if;
    if jsonb_typeof(v_keys) = 'array' then
      for v_key in select value from jsonb_array_elements_text(v_keys) limit 40 loop
        exit when v_n >= v_cap;
        -- v0.9.3 milestones: every boss that counts toward the reward also counts toward that boss's outfits
        v_bk := case when v_key = 'butcher_oct' then 'butcher' when v_key in ('butcher', 'ferryman', 'demolisher', 'storm', 'foreman') then v_key end;
        if v_bk is not null then v_st := jsonb_set(v_st, array['boss_' || v_bk], to_jsonb(coalesce((v_st->>('boss_' || v_bk))::int, 0) + 1)); end if;
        if v_key in ('butcher', 'ferryman') then v_hal := v_hal + 1; v_n := v_n + 1;
        elsif v_key = 'butcher_oct' then v_hal := v_hal + case when v_oct then 2 else 1 end; v_n := v_n + 1;
        elsif v_key in ('demolisher', 'storm', 'foreman') then v_glow := v_glow + 1; v_n := v_n + 1;
        end if;
      end loop;
      v_boss := v_n;
    else
      v_boss := least(v_boss, v_cap); v_glow := v_boss; v_n := v_boss;
    end if;
    select * into cb from public.case_types c where c.drop ? 'boss' order by c.sort limit 1;
    if found then v_glow := v_glow * coalesce((cb.drop->'boss'->>'each')::int, 1); end if;
    v_bonus := v_glow + v_hal;
    -- in-between bosses (Boss Rush: the even raids; Nightmare: any raid without a boss), 15-30 shards each
    if v_sbreq > 0 and ('bossrush' = any(v_mods) or 'nightmare' = any(v_mods)) and v_dur >= 25 * greatest(v_held, 1) then
      for r in (v_blo + 1) .. v_bhi loop
        if r % 5 <> 0 and ('nightmare' = any(v_mods) or r % 2 = 0) then v_sbcap := v_sbcap + 1; end if;
      end loop;
      v_sb := least(v_sbreq, v_sbcap);
      for r in 1 .. v_sb loop v_sbshards := v_sbshards + 15 + floor(random() * 16)::int; end loop;
    end if;
    -- leftover salvage: 20 to 1, at most 2 a raid held and 10 a run (modifiers move the cap too)
    v_scap := greatest(0, floor(10 * (100 + v_pct) / 100.0)::int);
    v_shards := least(v_sal / 20, 2 * v_held, v_scap) + v_sbshards;
    -- skill points: 1 per 5 raids held, 1 per boss
    v_spprog := v_spprog + v_held;
    v_sp := v_spprog / 5 + v_n + v_sb;
    v_spprog := v_spprog % 5;
  else
    if v_pvp not in ('base', 'ffa') then raise exception 'Unknown match type' using errcode = '22023'; end if;
    v_held := 0;
    v_st := jsonb_set(v_st, '{drops}', to_jsonb(coalesce((v_st->>'drops')::int, 0) + v_kills));
    if not v_seen then
      v_st := jsonb_set(v_st, '{pvp}', to_jsonb(coalesce((v_st->>'pvp')::int, 0) + 1));
      if v_win then v_st := jsonb_set(v_st, '{pvpWins}', to_jsonb(coalesce((v_st->>'pvpWins')::int, 0) + 1)); end if;
    end if;
    v_case := null;
    select * into ct from public.case_types c where v_pvp = any(c.modes) order by c.sort limit 1;
    if found then
      v_case := ct.id;
      chance := coalesce((ct.drop->v_pvp->>(case when v_win then 'win' else 'loss' end))::float8, 0) * (100 + v_pct) / 100.0;
      if v_seen then chance := 0; end if;   -- one roll per match
      if random() < chance then earned := 1; end if;
    end if;
  end if;
  -- v0.9.3: the Flag Case, a chance for everyone after any win (a win already counts once per game)
  if v_win and not (v_kind = 'match' and v_seen) then
    select * into cf from public.case_types c where c.drop ? 'win' order by c.sort limit 1;
    if found and random() < coalesce((cf.drop->>'win')::float8, 0) then v_flag := 1; end if;
  end if;
  granted := earned;
  v_before := l.owned;
  update public.lockers set st = v_st, prog = v_prog,
      cases = cases + case when v_case = 'supply' then granted else 0 end,
      bag = private.bag_add(private.bag_add(
              case when v_case is not null and v_case <> 'supply' and granted > 0 then private.bag_add(bag, v_case, granted) else bag end,
              coalesce(cb.id, 'afterglow'), v_glow), 'halloween', v_hal)
            || case when v_flag > 0 then jsonb_build_object(cf.id, coalesce((bag->>cf.id)::int, 0) + v_flag) else '{}'::jsonb end,
      shards = shards + v_shards,
      sp = sp + v_sp, sp_total = sp_total + v_sp, sp_prog = v_spprog,
      play_budget = greatest(0, v_budget - v_dur), budget_at = now(),
      rev = rev + 1, updated_at = now()
    where user_id = uid;
  insert into public.match_results (user_id, kind, mode, pvp, diff, win, held, kills, duration_s, cases_granted, case_id, bonus, shards,
      game_id, raid_from, raid_to, joined_s, left_s, left_early, upgrades, salvage, mods, map, size, shard_bosses, skill_points, cls)
    values (uid, v_kind, case when v_kind = 'run' then v_mode end, nullif(v_pvp, ''), case when v_kind = 'run' then v_diff end,
            v_win, v_held, v_kills, v_dur, granted, v_case, v_bonus, v_shards,
            v_gid, case when v_kind = 'run' then v_from end, case when v_kind = 'run' then v_to end,
            least(greatest(private.num(p->>'joined_s'), 0), 86400)::int, least(greatest(private.num(p->>'left_s'), 0), 86400)::int,
            coalesce(p->>'left' = 'true', false), left(regexp_replace(coalesce(p->>'upgrades', ''), '[^0-9a-z:]', '', 'g'), 16), v_sal,
            v_mods, left(regexp_replace(coalesce(p->>'map', ''), '[^a-z]', '', 'g'), 12), case when v_xl then 'xl' else 'std' end, v_sb, v_sp,
            nullif(v_cls, ''));
  update public.player_stats s set
      raids = s.raids + case when v_kind = 'run' then v_held else 0 end,
      wins = s.wins + case when v_kind = 'run' and v_win then 1 else 0 end,
      drops = s.drops + v_kills,
      best_endless = greatest(s.best_endless, case when v_kind = 'run' and waves = 0 then v_to else 0 end),
      pvp = s.pvp + case when v_kind = 'match' and not v_seen then 1 else 0 end,
      pvp_wins = s.pvp_wins + case when v_kind = 'match' and v_win and not v_seen then 1 else 0 end,
      updated_at = now()
    where s.user_id = uid;
  got := private.apply_unlocks(uid);
  select * into l from public.lockers where user_id = uid;
  v_new := array(select u from unnest(l.owned) u where not (u = any(v_before)));
  return jsonb_build_object(
    'cases', (case when v_kind = 'run'
        then jsonb_build_object('supply', granted, coalesce(cb.id, 'afterglow'), v_glow, 'halloween', v_hal)
        else case when v_case is not null then jsonb_build_object(v_case, granted) else '{}'::jsonb end end)
      || case when v_flag > 0 then jsonb_build_object(cf.id, v_flag) else '{}'::jsonb end,
    'unlocked_ids', to_jsonb(v_new), 'to_next', 3 - l.prog, 'size', case when v_xl and v_dur >= 35 * v_held then 'xl' else 'std' end,
    'cases_granted', granted, 'case_id', v_case, 'capped', false, 'chance', chance,
    'bonus', jsonb_build_object('case', coalesce(cb.id, 'afterglow'), 'n', v_glow), 'shards', v_shards,
    'bonuses', jsonb_build_array(jsonb_build_object('case', coalesce(cb.id, 'afterglow'), 'n', v_glow), jsonb_build_object('case', 'halloween', 'n', v_hal)),
    -- v0.9.2
    'held', v_held, 'raid_from', v_from, 'mods', to_jsonb(v_mods), 'mod_pct', v_pct, 'shard_bosses', v_sb, 'boss_shards', v_sbshards,
    'skill_points', v_sp, 'sp', l.sp, 'sp_to_next', 5 - l.sp_prog, 'repeat', v_seen,
    'flag_case', v_flag,
    'unlocked', to_jsonb(got), 'locker', private.locker_out(l));
end $function$;

-- SOURCE: 20260930050715_palisade_v0935_cosmetics.sql
-- v0.9.3.5: additive cosmetics and a versioned case pool. No player-data backfill.
-- Old clients retain their original Supply odds and cannot roll catalog_version 1.
alter table public.cosmetics add column if not exists catalog_version integer not null default 0;
alter table public.cosmetics drop constraint cosmetics_rarity_check;
alter table public.cosmetics add constraint cosmetics_rarity_check check (rarity in ('c','r','e','l','g','u'));

insert into public.cosmetics(id,cat,key,name,rarity,src,need,box,catalog_version) values
 ('skin:sahur','skin','sahur','Tung Tung Tung Sahur','u','case',null,'supply',1),
 ('hat:gravecap','hat','gravecap','Gravestone Cap','c','case',null,'halloween',1),
 ('hat:stemband','hat','stemband','Pumpkin Stem Band','c','case',null,'halloween',1),
 ('hat:batcirclet','hat','batcirclet','Bat-Notch Circlet','r','case',null,'halloween',1),
 ('hat:bonewrap','hat','bonewrap','Bone-Button Wrap','r','case',null,'halloween',1),
 ('hat:webpin','hat','webpin','Cobweb Brow Pin','e','case',null,'halloween',1),
 ('hat:skullseal','hat','skullseal','Crescent Skull Seal','l','case',null,'halloween',1)
on conflict(id) do update set name=excluded.name,rarity=excluded.rarity,box=excluded.box,catalog_version=excluded.catalog_version;
update public.case_types set weights='{"c":59.75,"r":27,"e":10,"l":3,"u":0.25}'::jsonb where id='supply';

create or replace function private.shard_value(r text) returns integer
language sql immutable set search_path='' as $function$
 select case r when 'c' then 1 when 'r' then 3 when 'e' then 8 when 'l' then 20 when 'g' then 40 when 'u' then 80 else 1 end;
$function$;

-- Definer logic is private. The public entrypoints below are invokers with fixed catalog versions.
create or replace function private.open_case_catalog(p_case text,p_rev integer,p_catalog integer)
returns jsonb language plpgsql security definer set search_path='' as $function$
declare uid uuid := private.require_user(); l public.lockers; ct public.case_types; it public.cosmetics;
 want text; have int; dup boolean; weights jsonb;
begin
 if p_catalog is null or p_catalog not in (0,1) then raise exception 'Unknown cosmetic catalog' using errcode='22023'; end if;
 select * into ct from public.case_types where id=p_case;
 if not found then raise exception 'Unknown case' using errcode='22023'; end if;
 select * into l from public.lockers where user_id=uid for update;
 if not found then raise exception 'Locker not found' using errcode='22023'; end if;
 perform private.check_rev(l,p_rev);
 have := case when p_case='supply' then l.cases else coalesce((l.bag->>p_case)::int,0) end;
 if have<1 then raise exception 'No % to open',lower(ct.name)||'s' using errcode='22023'; end if;
 weights := case when p_catalog=0 and p_case='supply' then '{"c":60,"r":27,"e":10,"l":3}'::jsonb else ct.weights end;
 want := private.roll_rarity(weights);
 select * into it from public.cosmetics c where c.box=p_case and c.rarity=want and c.catalog_version<=p_catalog order by random() limit 1;
 if not found then select * into it from public.cosmetics c where c.box=p_case and c.catalog_version<=p_catalog order by c.rarity='c' desc,random() limit 1; end if;
 if not found then raise exception 'Case catalog is empty' using errcode='22023'; end if;
 dup := it.id=any(l.owned);
 update public.lockers set
  cases=case when p_case='supply' then cases-1 else cases end,
  bag=case when p_case='supply' then bag else private.bag_add(bag,p_case,-1) end,
  shards=shards+case when dup then private.shard_value(it.rarity) else 0 end,
  owned=case when dup then owned else owned||it.id end,
  rev=rev+1,updated_at=now()
 where user_id=uid returning * into l;
 return jsonb_build_object('case',p_case,'item',jsonb_build_object('id',it.id,'cat',it.cat,'key',it.key,'name',it.name,'rarity',it.rarity),
  'dup',dup,'locker',private.locker_out(l));
end $function$;
revoke all on function private.open_case_catalog(text,integer,integer) from public,anon;
grant usage on schema private to authenticated;
grant execute on function private.open_case_catalog(text,integer,integer) to authenticated;

create or replace function public.open_case_of(p_case text,p_rev integer default null)
returns jsonb language sql security invoker set search_path='' as $function$
 select private.open_case_catalog(p_case,p_rev,0);
$function$;
create or replace function public.open_case_v0935(p_case text,p_rev integer default null)
returns jsonb language sql security invoker set search_path='' as $function$
 select private.open_case_catalog(p_case,p_rev,1);
$function$;
revoke all on function public.open_case_of(text,integer) from public,anon;
revoke all on function public.open_case_v0935(text,integer) from public,anon;
grant execute on function public.open_case_of(text,integer) to authenticated;
grant execute on function public.open_case_v0935(text,integer) to authenticated;

-- SOURCE: 20260930071534_palisade_v0936_rejoin_bosses.sql
-- v0.9.3.6: rejoin boss credit. No player-data backfill.
-- claim_match_reward capped bosses per claim starting at the previous claim's raid + 1, so a boss or in-between
-- (Boss Rush / Nightmare) boss on the first raid after a rejoin was paid to nobody. The cap now covers the player's
-- whole stay in the game minus what earlier claims for that game already paid. boss_n records bosses paid per claim;
-- older rows fall back to their bonus-case count, which can only under-count the earlier credit (safe direction).
alter table public.match_results add column if not exists boss_n integer;

CREATE OR REPLACE FUNCTION public.claim_match_reward(p jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare uid uuid := private.require_user(); l public.lockers; ct public.case_types; cb public.case_types;
  v_kind text := p->>'kind'; v_mode text := coalesce(p->>'mode', '5'); v_pvp text := coalesce(p->>'pvp', '');
  v_diff text := coalesce(p->>'diff', 'normal'); v_win boolean := coalesce(p->>'win' = 'true', false);
  v_held int; v_kills int := greatest(coalesce(private.num(p->>'kills'), 0), 0)::int;
  v_dur int := coalesce(private.num(p->>'duration_s'), 0)::int; v_boss int := least(greatest(coalesce(private.num(p->>'bosses'), 0), 0), 100)::int;
  waves int := 0; v_st jsonb; v_prog int; earned int := 0; granted int; got text[]; v_case text := 'supply'; chance float8; v_bonus int := 0;
  v_budget float8;
  v_sal int := least(greatest(coalesce(private.num(p->>'salvage'), 0), 0), 1000000)::int; v_shards int := 0;
  v_keys jsonb := p->'boss_keys'; v_key text; v_cap int; v_n int := 0; v_hal int := 0; v_glow int := 0;
  v_xl boolean := coalesce(p->>'size', 'std') = 'xl'; v_before text[]; v_new text[];
  v_oct boolean := (now() at time zone 'UTC') >= make_timestamp(extract(year from now())::int, 9, 30, 10, 0, 0)
               and (now() at time zone 'UTC') <  make_timestamp(extract(year from now())::int, 11, 1, 14, 0, 0);
  v_gid text := nullif(left(coalesce(p->>'game_id', ''), 40), '');
  v_to int := greatest(coalesce(private.num(p->>'raid_to'), private.num(p->>'held'), 0), 0)::int;
  v_from int := greatest(coalesce(private.num(p->>'raid_from'), 0), 0)::int;
  v_prev int; v_first int; v_join int; v_blo int; v_bhi int; v_seen boolean := false;
  v_pbn int := 0; v_psb int := 0;
  v_mods text[]; v_pct int := 0; v_credit int := 0; v_scap int;
  v_sbreq int := least(greatest(coalesce(private.num(p->>'shard_bosses'), 0), 0), 100)::int; v_sb int := 0; v_sbcap int := 0; v_sbshards int := 0;
  v_sp int := 0; v_spprog int; r int;
  v_map text := left(regexp_replace(coalesce(p->>'map', ''), '[^a-z]', '', 'g'), 12);
  v_cls text := left(regexp_replace(coalesce(p->>'cls', ''), '[^a-z]', '', 'g'), 16);
  v_bk text; cf public.case_types; v_flag int := 0;
begin
  if v_kind is null or v_kind not in ('run', 'match') then raise exception 'Unknown result' using errcode = '22023'; end if;
  if v_dur < 20 or v_dur > 21600 or (v_kind = 'match' and v_dur < 30) then raise exception 'That match length doesn''t add up' using errcode = '22023'; end if;
  if v_kills > v_dur then raise exception 'That kill count doesn''t add up' using errcode = '22023'; end if;
  select * into l from public.lockers where user_id = uid for update;
  if exists (select 1 from public.match_results m where m.user_id = uid and m.created_at > now() - interval '20 seconds') then
    raise exception 'Rewards were claimed a moment ago' using errcode = '22023';
  end if;
  v_budget := least(22200, l.play_budget + extract(epoch from now() - l.budget_at));
  if v_dur > v_budget + 60 then
    raise exception 'More play time than real time so far; this result will be saved later' using errcode = '22023';
  end if;
  v_mods := private.clean_mods(p->'mods', v_pvp);
  select coalesce(sum(private.mod_bonus(m, v_pvp)), 0) into v_pct from unnest(v_mods) m;
  v_pct := least(greatest(v_pct, -15), 75);
  if v_gid is not null then
    select max(m.raid_to), min(m.raid_from), count(*) > 0, coalesce(sum(coalesce(m.boss_n, m.bonus)), 0), coalesce(sum(m.shard_bosses), 0)
      into v_prev, v_first, v_seen, v_pbn, v_psb from public.match_results m where m.user_id = uid and m.game_id = v_gid;
  end if;
  v_st := l.st; v_prog := l.prog; v_spprog := l.sp_prog;
  if v_kind = 'run' then
    if v_mode not in ('5', '10', 'endless') or v_diff not in ('easy', 'normal', 'hard') then raise exception 'Unknown mode' using errcode = '22023'; end if;
    waves := case v_mode when '5' then 5 when '10' then 10 else 0 end;
    if waves > 0 and v_to > waves then raise exception 'That raid count doesn''t add up' using errcode = '22023'; end if;
    v_from := least(v_from, v_to); v_join := least(v_from, coalesce(v_first, v_from));
    if v_prev is not null then v_from := greatest(v_from, least(v_prev, v_to)); end if;
    v_held := v_to - v_from;
    if v_dur + 20 < 8 * v_held + (v_held * v_held) / 4 then raise exception 'That raid count doesn''t add up' using errcode = '22023'; end if;
    if waves = 0 or v_to <> waves or v_join * 2 > waves or (v_seen and v_prev >= waves) then v_win := false; end if;
    v_st := jsonb_set(v_st, '{raids}', to_jsonb(coalesce((v_st->>'raids')::int, 0) + v_held));
    v_st := jsonb_set(v_st, '{drops}', to_jsonb(coalesce((v_st->>'drops')::int, 0) + v_kills));
    if v_win then
      v_st := jsonb_set(v_st, '{wins}', to_jsonb(coalesce((v_st->>'wins')::int, 0) + 1));
      if v_diff = 'hard' then v_st := jsonb_set(v_st, '{hardWins}', to_jsonb(coalesce((v_st->>'hardWins')::int, 0) + 1)); end if;
    end if;
    if waves = 0 then v_st := jsonb_set(v_st, '{endless}', to_jsonb(greatest(coalesce((v_st->>'endless')::int, 0), v_to))); end if;
    if v_held > 0 and v_map in ('yard', 'river', 'quarry') then
      v_st := jsonb_set(v_st, array['map_' || v_map], to_jsonb(coalesce((v_st->>('map_' || v_map))::int, 0) + v_held));
    end if;
    if v_held > 0 and v_cls in ('soldier', 'sniper', 'grenadier', 'quartermaster') then
      v_st := jsonb_set(v_st, array['cls_' || v_cls || '_raids'], to_jsonb(coalesce((v_st->>('cls_' || v_cls || '_raids'))::int, 0) + v_held));
    end if;
    v_credit := floor(v_held * (100 + v_pct) / 100.0)::int;
    v_prog := v_prog + v_credit;
    earned := v_prog / 3 + case when v_win then (case when waves >= 10 then 2 else 1 end) else 0 end + case when waves = 0 then v_held / 5 else 0 end;
    v_prog := v_prog % 3;
    -- v0.9.3.6: bosses are capped over the whole stretch this player was in the game (first join to now), minus
    -- what earlier claims for the same game already paid. The old per-claim window started at v_prev + 1, so a
    -- boss killed after a rejoin (e.g. leave after raid 4, back for raid 5) was never paid to anyone.
    v_blo := v_join;
    v_bhi := v_to + 1; if waves > 0 then v_bhi := least(v_bhi, waves); end if;
    v_cap := greatest(0, v_bhi / 5 - v_blo / 5);
    if v_xl and v_dur >= 35 * v_held then v_cap := v_cap * 2; end if;
    v_cap := greatest(0, v_cap - v_pbn);
    if jsonb_typeof(v_keys) = 'array' then
      for v_key in select value from jsonb_array_elements_text(v_keys) limit 40 loop
        exit when v_n >= v_cap;
        v_bk := case when v_key = 'butcher_oct' then 'butcher' when v_key in ('butcher', 'ferryman', 'demolisher', 'storm', 'foreman') then v_key end;
        if v_bk is not null then v_st := jsonb_set(v_st, array['boss_' || v_bk], to_jsonb(coalesce((v_st->>('boss_' || v_bk))::int, 0) + 1)); end if;
        if v_key in ('butcher', 'ferryman') then v_hal := v_hal + 1; v_n := v_n + 1;
        elsif v_key = 'butcher_oct' then v_hal := v_hal + case when v_oct then 2 else 1 end; v_n := v_n + 1;
        elsif v_key in ('demolisher', 'storm', 'foreman') then v_glow := v_glow + 1; v_n := v_n + 1;
        end if;
      end loop;
      v_boss := v_n;
    else
      v_boss := least(v_boss, v_cap); v_glow := v_boss; v_n := v_boss;
    end if;
    select * into cb from public.case_types c where c.drop ? 'boss' order by c.sort limit 1;
    if found then v_glow := v_glow * coalesce((cb.drop->'boss'->>'each')::int, 1); end if;
    v_bonus := v_glow + v_hal;
    if v_sbreq > 0 and ('bossrush' = any(v_mods) or 'nightmare' = any(v_mods)) and v_dur >= 25 * greatest(v_held, 1) then
      for r in (v_blo + 1) .. v_bhi loop
        if r % 5 <> 0 and ('nightmare' = any(v_mods) or r % 2 = 0) then v_sbcap := v_sbcap + 1; end if;
      end loop;
      v_sb := least(v_sbreq, greatest(0, v_sbcap - v_psb));
      for r in 1 .. v_sb loop v_sbshards := v_sbshards + 15 + floor(random() * 16)::int; end loop;
    end if;
    v_scap := greatest(0, floor(10 * (100 + v_pct) / 100.0)::int);
    v_shards := least(v_sal / 20, 2 * v_held, v_scap) + v_sbshards;
    v_spprog := v_spprog + v_held;
    v_sp := v_spprog / 5 + v_n + v_sb;
    v_spprog := v_spprog % 5;
  else
    if v_pvp not in ('base', 'ffa') then raise exception 'Unknown match type' using errcode = '22023'; end if;
    v_held := 0;
    v_st := jsonb_set(v_st, '{drops}', to_jsonb(coalesce((v_st->>'drops')::int, 0) + v_kills));
    if not v_seen then
      v_st := jsonb_set(v_st, '{pvp}', to_jsonb(coalesce((v_st->>'pvp')::int, 0) + 1));
      if v_win then v_st := jsonb_set(v_st, '{pvpWins}', to_jsonb(coalesce((v_st->>'pvpWins')::int, 0) + 1)); end if;
    end if;
    v_case := null;
    select * into ct from public.case_types c where v_pvp = any(c.modes) order by c.sort limit 1;
    if found then
      v_case := ct.id;
      chance := coalesce((ct.drop->v_pvp->>(case when v_win then 'win' else 'loss' end))::float8, 0) * (100 + v_pct) / 100.0;
      if v_seen then chance := 0; end if;
      if random() < chance then earned := 1; end if;
    end if;
  end if;
  if v_win and not (v_kind = 'match' and v_seen) then
    select * into cf from public.case_types c where c.drop ? 'win' order by c.sort limit 1;
    if found and random() < coalesce((cf.drop->>'win')::float8, 0) then v_flag := 1; end if;
  end if;
  granted := earned;
  v_before := l.owned;
  update public.lockers set st = v_st, prog = v_prog,
      cases = cases + case when v_case = 'supply' then granted else 0 end,
      bag = private.bag_add(private.bag_add(
              case when v_case is not null and v_case <> 'supply' and granted > 0 then private.bag_add(bag, v_case, granted) else bag end,
              coalesce(cb.id, 'afterglow'), v_glow), 'halloween', v_hal)
            || case when v_flag > 0 then jsonb_build_object(cf.id, coalesce((bag->>cf.id)::int, 0) + v_flag) else '{}'::jsonb end,
      shards = shards + v_shards,
      sp = sp + v_sp, sp_total = sp_total + v_sp, sp_prog = v_spprog,
      play_budget = greatest(0, v_budget - v_dur), budget_at = now(),
      rev = rev + 1, updated_at = now()
    where user_id = uid;
  insert into public.match_results (user_id, kind, mode, pvp, diff, win, held, kills, duration_s, cases_granted, case_id, bonus, shards,
      game_id, raid_from, raid_to, joined_s, left_s, left_early, upgrades, salvage, mods, map, size, shard_bosses, skill_points, cls, boss_n)
    values (uid, v_kind, case when v_kind = 'run' then v_mode end, nullif(v_pvp, ''), case when v_kind = 'run' then v_diff end,
            v_win, v_held, v_kills, v_dur, granted, v_case, v_bonus, v_shards,
            v_gid, case when v_kind = 'run' then v_from end, case when v_kind = 'run' then v_to end,
            least(greatest(private.num(p->>'joined_s'), 0), 86400)::int, least(greatest(private.num(p->>'left_s'), 0), 86400)::int,
            coalesce(p->>'left' = 'true', false), left(regexp_replace(coalesce(p->>'upgrades', ''), '[^0-9a-z:]', '', 'g'), 16), v_sal,
            v_mods, left(regexp_replace(coalesce(p->>'map', ''), '[^a-z]', '', 'g'), 12), case when v_xl then 'xl' else 'std' end, v_sb, v_sp,
            nullif(v_cls, ''), case when v_kind = 'run' then v_n end);
  update public.player_stats s set
      raids = s.raids + case when v_kind = 'run' then v_held else 0 end,
      wins = s.wins + case when v_kind = 'run' and v_win then 1 else 0 end,
      drops = s.drops + v_kills,
      best_endless = greatest(s.best_endless, case when v_kind = 'run' and waves = 0 then v_to else 0 end),
      pvp = s.pvp + case when v_kind = 'match' and not v_seen then 1 else 0 end,
      pvp_wins = s.pvp_wins + case when v_kind = 'match' and v_win and not v_seen then 1 else 0 end,
      updated_at = now()
    where s.user_id = uid;
  got := private.apply_unlocks(uid);
  select * into l from public.lockers where user_id = uid;
  v_new := array(select u from unnest(l.owned) u where not (u = any(v_before)));
  return jsonb_build_object(
    'cases', (case when v_kind = 'run'
        then jsonb_build_object('supply', granted, coalesce(cb.id, 'afterglow'), v_glow, 'halloween', v_hal)
        else case when v_case is not null then jsonb_build_object(v_case, granted) else '{}'::jsonb end end)
      || case when v_flag > 0 then jsonb_build_object(cf.id, v_flag) else '{}'::jsonb end,
    'unlocked_ids', to_jsonb(v_new), 'to_next', 3 - l.prog, 'size', case when v_xl and v_dur >= 35 * v_held then 'xl' else 'std' end,
    'cases_granted', granted, 'case_id', v_case, 'capped', false, 'chance', chance,
    'bonus', jsonb_build_object('case', coalesce(cb.id, 'afterglow'), 'n', v_glow), 'shards', v_shards,
    'bonuses', jsonb_build_array(jsonb_build_object('case', coalesce(cb.id, 'afterglow'), 'n', v_glow), jsonb_build_object('case', 'halloween', 'n', v_hal)),
    'held', v_held, 'raid_from', v_from, 'mods', to_jsonb(v_mods), 'mod_pct', v_pct, 'shard_bosses', v_sb, 'boss_shards', v_sbshards,
    'skill_points', v_sp, 'sp', l.sp, 'sp_to_next', 5 - l.sp_prog, 'repeat', v_seen,
    'flag_case', v_flag,
    'unlocked', to_jsonb(got), 'locker', private.locker_out(l));
end $function$;

revoke all on function public.claim_match_reward(jsonb) from public, anon;
grant execute on function public.claim_match_reward(jsonb) to authenticated;

-- SOURCE: 20260930075446_palisade_v0938_all_boss_milestones.sql
-- v0.9.3.8: every boss kill counts toward boss milestones, for everyone in the match. No backfill.
-- In-between bosses (Boss Rush, Nightmare surprise, the Nightmare + Boss Rush second boss) paid shards and skill points
-- but never milestone credit. A claim may now name them (sb_keys); each paid one adds +1 to its boss_* counter.
-- Older clients send no sb_keys and behave exactly as before.
CREATE OR REPLACE FUNCTION public.claim_match_reward(p jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare uid uuid := private.require_user(); l public.lockers; ct public.case_types; cb public.case_types;
  v_kind text := p->>'kind'; v_mode text := coalesce(p->>'mode', '5'); v_pvp text := coalesce(p->>'pvp', '');
  v_diff text := coalesce(p->>'diff', 'normal'); v_win boolean := coalesce(p->>'win' = 'true', false);
  v_held int; v_kills int := greatest(coalesce(private.num(p->>'kills'), 0), 0)::int;
  v_dur int := coalesce(private.num(p->>'duration_s'), 0)::int; v_boss int := least(greatest(coalesce(private.num(p->>'bosses'), 0), 0), 100)::int;
  waves int := 0; v_st jsonb; v_prog int; earned int := 0; granted int; got text[]; v_case text := 'supply'; chance float8; v_bonus int := 0;
  v_budget float8;
  v_sal int := least(greatest(coalesce(private.num(p->>'salvage'), 0), 0), 1000000)::int; v_shards int := 0;
  v_keys jsonb := p->'boss_keys'; v_key text; v_cap int; v_n int := 0; v_hal int := 0; v_glow int := 0;
  v_xl boolean := coalesce(p->>'size', 'std') = 'xl'; v_before text[]; v_new text[];
  v_oct boolean := (now() at time zone 'UTC') >= make_timestamp(extract(year from now())::int, 9, 30, 10, 0, 0)
               and (now() at time zone 'UTC') <  make_timestamp(extract(year from now())::int, 11, 1, 14, 0, 0);
  v_gid text := nullif(left(coalesce(p->>'game_id', ''), 40), '');
  v_to int := greatest(coalesce(private.num(p->>'raid_to'), private.num(p->>'held'), 0), 0)::int;
  v_from int := greatest(coalesce(private.num(p->>'raid_from'), 0), 0)::int;
  v_prev int; v_first int; v_join int; v_blo int; v_bhi int; v_seen boolean := false;
  v_pbn int := 0; v_psb int := 0;
  v_mods text[]; v_pct int := 0; v_credit int := 0; v_scap int;
  v_sbreq int := least(greatest(coalesce(private.num(p->>'shard_bosses'), 0), 0), 100)::int; v_sb int := 0; v_sbcap int := 0; v_sbshards int := 0;
  v_sp int := 0; v_spprog int; r int;
  v_map text := left(regexp_replace(coalesce(p->>'map', ''), '[^a-z]', '', 'g'), 12);
  v_cls text := left(regexp_replace(coalesce(p->>'cls', ''), '[^a-z]', '', 'g'), 16);
  v_bk text; cf public.case_types; v_flag int := 0;
begin
  if v_kind is null or v_kind not in ('run', 'match') then raise exception 'Unknown result' using errcode = '22023'; end if;
  if v_dur < 20 or v_dur > 21600 or (v_kind = 'match' and v_dur < 30) then raise exception 'That match length doesn''t add up' using errcode = '22023'; end if;
  if v_kills > v_dur then raise exception 'That kill count doesn''t add up' using errcode = '22023'; end if;
  select * into l from public.lockers where user_id = uid for update;
  if exists (select 1 from public.match_results m where m.user_id = uid and m.created_at > now() - interval '20 seconds') then
    raise exception 'Rewards were claimed a moment ago' using errcode = '22023';
  end if;
  v_budget := least(22200, l.play_budget + extract(epoch from now() - l.budget_at));
  if v_dur > v_budget + 60 then
    raise exception 'More play time than real time so far; this result will be saved later' using errcode = '22023';
  end if;
  v_mods := private.clean_mods(p->'mods', v_pvp);
  select coalesce(sum(private.mod_bonus(m, v_pvp)), 0) into v_pct from unnest(v_mods) m;
  v_pct := least(greatest(v_pct, -15), 75);
  if v_gid is not null then
    select max(m.raid_to), min(m.raid_from), count(*) > 0, coalesce(sum(coalesce(m.boss_n, m.bonus)), 0), coalesce(sum(m.shard_bosses), 0)
      into v_prev, v_first, v_seen, v_pbn, v_psb from public.match_results m where m.user_id = uid and m.game_id = v_gid;
  end if;
  v_st := l.st; v_prog := l.prog; v_spprog := l.sp_prog;
  if v_kind = 'run' then
    if v_mode not in ('5', '10', 'endless') or v_diff not in ('easy', 'normal', 'hard') then raise exception 'Unknown mode' using errcode = '22023'; end if;
    waves := case v_mode when '5' then 5 when '10' then 10 else 0 end;
    if waves > 0 and v_to > waves then raise exception 'That raid count doesn''t add up' using errcode = '22023'; end if;
    v_from := least(v_from, v_to); v_join := least(v_from, coalesce(v_first, v_from));
    if v_prev is not null then v_from := greatest(v_from, least(v_prev, v_to)); end if;
    v_held := v_to - v_from;
    if v_dur + 20 < 8 * v_held + (v_held * v_held) / 4 then raise exception 'That raid count doesn''t add up' using errcode = '22023'; end if;
    if waves = 0 or v_to <> waves or v_join * 2 > waves or (v_seen and v_prev >= waves) then v_win := false; end if;
    v_st := jsonb_set(v_st, '{raids}', to_jsonb(coalesce((v_st->>'raids')::int, 0) + v_held));
    v_st := jsonb_set(v_st, '{drops}', to_jsonb(coalesce((v_st->>'drops')::int, 0) + v_kills));
    if v_win then
      v_st := jsonb_set(v_st, '{wins}', to_jsonb(coalesce((v_st->>'wins')::int, 0) + 1));
      if v_diff = 'hard' then v_st := jsonb_set(v_st, '{hardWins}', to_jsonb(coalesce((v_st->>'hardWins')::int, 0) + 1)); end if;
    end if;
    if waves = 0 then v_st := jsonb_set(v_st, '{endless}', to_jsonb(greatest(coalesce((v_st->>'endless')::int, 0), v_to))); end if;
    if v_held > 0 and v_map in ('yard', 'river', 'quarry') then
      v_st := jsonb_set(v_st, array['map_' || v_map], to_jsonb(coalesce((v_st->>('map_' || v_map))::int, 0) + v_held));
    end if;
    if v_held > 0 and v_cls in ('soldier', 'sniper', 'grenadier', 'quartermaster') then
      v_st := jsonb_set(v_st, array['cls_' || v_cls || '_raids'], to_jsonb(coalesce((v_st->>('cls_' || v_cls || '_raids'))::int, 0) + v_held));
    end if;
    v_credit := floor(v_held * (100 + v_pct) / 100.0)::int;
    v_prog := v_prog + v_credit;
    earned := v_prog / 3 + case when v_win then (case when waves >= 10 then 2 else 1 end) else 0 end + case when waves = 0 then v_held / 5 else 0 end;
    v_prog := v_prog % 3;
    -- v0.9.3.6: bosses are capped over the whole stretch this player was in the game (first join to now), minus
    -- what earlier claims for the same game already paid. The old per-claim window started at v_prev + 1, so a
    -- boss killed after a rejoin (e.g. leave after raid 4, back for raid 5) was never paid to anyone.
    v_blo := v_join;
    v_bhi := v_to + 1; if waves > 0 then v_bhi := least(v_bhi, waves); end if;
    v_cap := greatest(0, v_bhi / 5 - v_blo / 5);
    if v_xl and v_dur >= 35 * v_held then v_cap := v_cap * 2; end if;
    v_cap := greatest(0, v_cap - v_pbn);
    if jsonb_typeof(v_keys) = 'array' then
      for v_key in select value from jsonb_array_elements_text(v_keys) limit 40 loop
        exit when v_n >= v_cap;
        v_bk := case when v_key = 'butcher_oct' then 'butcher' when v_key in ('butcher', 'ferryman', 'demolisher', 'storm', 'foreman') then v_key end;
        if v_bk is not null then v_st := jsonb_set(v_st, array['boss_' || v_bk], to_jsonb(coalesce((v_st->>('boss_' || v_bk))::int, 0) + 1)); end if;
        if v_key in ('butcher', 'ferryman') then v_hal := v_hal + 1; v_n := v_n + 1;
        elsif v_key = 'butcher_oct' then v_hal := v_hal + case when v_oct then 2 else 1 end; v_n := v_n + 1;
        elsif v_key in ('demolisher', 'storm', 'foreman') then v_glow := v_glow + 1; v_n := v_n + 1;
        end if;
      end loop;
      v_boss := v_n;
    else
      v_boss := least(v_boss, v_cap); v_glow := v_boss; v_n := v_boss;
    end if;
    select * into cb from public.case_types c where c.drop ? 'boss' order by c.sort limit 1;
    if found then v_glow := v_glow * coalesce((cb.drop->'boss'->>'each')::int, 1); end if;
    v_bonus := v_glow + v_hal;
    if v_sbreq > 0 and ('bossrush' = any(v_mods) or 'nightmare' = any(v_mods)) and v_dur >= 25 * greatest(v_held, 1) then
      for r in (v_blo + 1) .. v_bhi loop
        if r % 5 <> 0 and ('nightmare' = any(v_mods) or r % 2 = 0) then v_sbcap := v_sbcap + 1; end if;
      end loop;
      v_sb := least(v_sbreq, greatest(0, v_sbcap - v_psb));
      -- v0.9.3.8: every paid in-between boss also counts toward its boss milestone (clients send which bosses they were)
      if v_sb > 0 and jsonb_typeof(p->'sb_keys') = 'array' then
        for v_key in select value from jsonb_array_elements_text(p->'sb_keys') limit v_sb loop
          v_bk := case when v_key in ('butcher', 'ferryman', 'demolisher', 'storm', 'foreman') then v_key end;
          if v_bk is not null then v_st := jsonb_set(v_st, array['boss_' || v_bk], to_jsonb(coalesce((v_st->>('boss_' || v_bk))::int, 0) + 1)); end if;
        end loop;
      end if;
      for r in 1 .. v_sb loop v_sbshards := v_sbshards + 15 + floor(random() * 16)::int; end loop;
    end if;
    v_scap := greatest(0, floor(10 * (100 + v_pct) / 100.0)::int);
    v_shards := least(v_sal / 20, 2 * v_held, v_scap) + v_sbshards;
    v_spprog := v_spprog + v_held;
    v_sp := v_spprog / 5 + v_n + v_sb;
    v_spprog := v_spprog % 5;
  else
    if v_pvp not in ('base', 'ffa') then raise exception 'Unknown match type' using errcode = '22023'; end if;
    v_held := 0;
    v_st := jsonb_set(v_st, '{drops}', to_jsonb(coalesce((v_st->>'drops')::int, 0) + v_kills));
    if not v_seen then
      v_st := jsonb_set(v_st, '{pvp}', to_jsonb(coalesce((v_st->>'pvp')::int, 0) + 1));
      if v_win then v_st := jsonb_set(v_st, '{pvpWins}', to_jsonb(coalesce((v_st->>'pvpWins')::int, 0) + 1)); end if;
    end if;
    v_case := null;
    select * into ct from public.case_types c where v_pvp = any(c.modes) order by c.sort limit 1;
    if found then
      v_case := ct.id;
      chance := coalesce((ct.drop->v_pvp->>(case when v_win then 'win' else 'loss' end))::float8, 0) * (100 + v_pct) / 100.0;
      if v_seen then chance := 0; end if;
      if random() < chance then earned := 1; end if;
    end if;
  end if;
  if v_win and not (v_kind = 'match' and v_seen) then
    select * into cf from public.case_types c where c.drop ? 'win' order by c.sort limit 1;
    if found and random() < coalesce((cf.drop->>'win')::float8, 0) then v_flag := 1; end if;
  end if;
  granted := earned;
  v_before := l.owned;
  update public.lockers set st = v_st, prog = v_prog,
      cases = cases + case when v_case = 'supply' then granted else 0 end,
      bag = private.bag_add(private.bag_add(
              case when v_case is not null and v_case <> 'supply' and granted > 0 then private.bag_add(bag, v_case, granted) else bag end,
              coalesce(cb.id, 'afterglow'), v_glow), 'halloween', v_hal)
            || case when v_flag > 0 then jsonb_build_object(cf.id, coalesce((bag->>cf.id)::int, 0) + v_flag) else '{}'::jsonb end,
      shards = shards + v_shards,
      sp = sp + v_sp, sp_total = sp_total + v_sp, sp_prog = v_spprog,
      play_budget = greatest(0, v_budget - v_dur), budget_at = now(),
      rev = rev + 1, updated_at = now()
    where user_id = uid;
  insert into public.match_results (user_id, kind, mode, pvp, diff, win, held, kills, duration_s, cases_granted, case_id, bonus, shards,
      game_id, raid_from, raid_to, joined_s, left_s, left_early, upgrades, salvage, mods, map, size, shard_bosses, skill_points, cls, boss_n)
    values (uid, v_kind, case when v_kind = 'run' then v_mode end, nullif(v_pvp, ''), case when v_kind = 'run' then v_diff end,
            v_win, v_held, v_kills, v_dur, granted, v_case, v_bonus, v_shards,
            v_gid, case when v_kind = 'run' then v_from end, case when v_kind = 'run' then v_to end,
            least(greatest(private.num(p->>'joined_s'), 0), 86400)::int, least(greatest(private.num(p->>'left_s'), 0), 86400)::int,
            coalesce(p->>'left' = 'true', false), left(regexp_replace(coalesce(p->>'upgrades', ''), '[^0-9a-z:]', '', 'g'), 16), v_sal,
            v_mods, left(regexp_replace(coalesce(p->>'map', ''), '[^a-z]', '', 'g'), 12), case when v_xl then 'xl' else 'std' end, v_sb, v_sp,
            nullif(v_cls, ''), case when v_kind = 'run' then v_n end);
  update public.player_stats s set
      raids = s.raids + case when v_kind = 'run' then v_held else 0 end,
      wins = s.wins + case when v_kind = 'run' and v_win then 1 else 0 end,
      drops = s.drops + v_kills,
      best_endless = greatest(s.best_endless, case when v_kind = 'run' and waves = 0 then v_to else 0 end),
      pvp = s.pvp + case when v_kind = 'match' and not v_seen then 1 else 0 end,
      pvp_wins = s.pvp_wins + case when v_kind = 'match' and v_win and not v_seen then 1 else 0 end,
      updated_at = now()
    where s.user_id = uid;
  got := private.apply_unlocks(uid);
  select * into l from public.lockers where user_id = uid;
  v_new := array(select u from unnest(l.owned) u where not (u = any(v_before)));
  return jsonb_build_object(
    'cases', (case when v_kind = 'run'
        then jsonb_build_object('supply', granted, coalesce(cb.id, 'afterglow'), v_glow, 'halloween', v_hal)
        else case when v_case is not null then jsonb_build_object(v_case, granted) else '{}'::jsonb end end)
      || case when v_flag > 0 then jsonb_build_object(cf.id, v_flag) else '{}'::jsonb end,
    'unlocked_ids', to_jsonb(v_new), 'to_next', 3 - l.prog, 'size', case when v_xl and v_dur >= 35 * v_held then 'xl' else 'std' end,
    'cases_granted', granted, 'case_id', v_case, 'capped', false, 'chance', chance,
    'bonus', jsonb_build_object('case', coalesce(cb.id, 'afterglow'), 'n', v_glow), 'shards', v_shards,
    'bonuses', jsonb_build_array(jsonb_build_object('case', coalesce(cb.id, 'afterglow'), 'n', v_glow), jsonb_build_object('case', 'halloween', 'n', v_hal)),
    'held', v_held, 'raid_from', v_from, 'mods', to_jsonb(v_mods), 'mod_pct', v_pct, 'shard_bosses', v_sb, 'boss_shards', v_sbshards,
    'skill_points', v_sp, 'sp', l.sp, 'sp_to_next', 5 - l.sp_prog, 'repeat', v_seen,
    'flag_case', v_flag,
    'unlocked', to_jsonb(got), 'locker', private.locker_out(l));
end $function$;

revoke all on function public.claim_match_reward(jsonb) from public, anon;
grant execute on function public.claim_match_reward(jsonb) to authenticated;

-- SOURCE: 20260930084544_palisade_v0939_sp_cases.sql
-- v0.9.3.9: trade 3 unspent skill points for 1 Supply Case. No cap (Big U). No player-data change.
-- Spends only unspent points (lockers.sp). sp_total (lifetime) is unchanged; skill_respec refunds private.skill_spent(skills),
-- the tree's own costs, so points traded for cases can never be refunded by a reset.
create or replace function public.buy_case_sp(p_rev integer default null)
returns jsonb language plpgsql security definer set search_path = '' as $function$
declare uid uuid := private.require_user(); l public.lockers; cost constant int := 3;
begin
  select * into l from public.lockers where user_id = uid for update;
  if not found then raise exception 'Locker not found' using errcode = '22023'; end if;
  perform private.check_rev(l, p_rev);
  if l.sp < cost then raise exception 'A Supply Case takes % skill points', cost using errcode = '22023'; end if;
  update public.lockers set sp = sp - cost, cases = cases + 1, rev = rev + 1, updated_at = now()
    where user_id = uid returning * into l;
  return private.locker_out(l);
end $function$;
revoke all on function public.buy_case_sp(integer) from public, anon;
grant execute on function public.buy_case_sp(integer) to authenticated;

-- SOURCE: 20260930141401_palisade_v0940_blitz.sql
-- v0.9.4.0: Blitzkrieg Rush (a new co-op length: 15 raids, then the Final Blitz and the evacuation).
-- * case_types: the Blitzkrieg Case (14 shards); cosmetics: its 10 items and the 5 BLITZKRIEG RUSH ladder rewards
--   (catalog_version 2, so older clients never roll or see art they can't draw; open_case_v094 opens catalog 2).
-- * mod_bonus: the Blitzkrieg list (co-op minus Boss Rush, plus Hot LZ, Double Time, Artillery Barrage, Lockdown,
--   Scorched Earth). clean_mods/mod_bonus are called with 'blitz' for these runs; other modes are unchanged.
-- * claim_match_reward: mode 'blitz' (15 raids). Blitzkrieg bosses pay 2 Blitzkrieg Cases each; Final Blitz bosses
--   (fb_keys) also 15-30 shards and a skill point; making the evacuation pays 1 more case and 25 shards. A player left
--   behind (evac = 'left') keeps half of every case and of the shards, odd counts rounded up (7 -> 4); raids, boss
--   kills, skill points and milestones are never halved. Every Blitzkrieg boss adds to its base boss's counter and to
--   mode_blitz_bosses. Older clients (modes 5/10/endless) behave exactly as before.
alter table public.match_results add column if not exists fb_n integer default 0;
alter table public.match_results add column if not exists evac text;

create or replace function private.blitz_base(k text) returns text language sql immutable set search_path = '' as $$
  select case k when 'harbinger' then 'ferryman' when 'bluebutcher' then 'butcher' when 'arsonist' then 'demolisher'
    when 'tempest' then 'storm' when 'bulldozer' then 'foreman' end
$$;
revoke all on function private.blitz_base(text) from public, anon, authenticated;

create or replace function private.mod_bonus(p_id text, p_pvp text)
 returns integer language sql immutable set search_path to ''
as $function$
  select case when coalesce(p_pvp, '') in ('base', 'ffa') then
      case p_id when 'adrenaline' then -15 when 'weather' then 0 when 'nightmare' then 0 when 'glass' then 0 when 'onejob' then 0
        when 'scrap' then case when p_pvp = 'base' then 0 end when 'frenzy' then 0 when 'sudden' then case when p_pvp = 'ffa' then 0 end end
    when p_pvp = 'blitz' then
      case p_id when 'nopatch' then 10 when 'alone' then 20 when 'firestorm' then 10 when 'adrenaline' then -15 when 'laststand' then 10
        when 'elite' then 15 when 'weather' then 10 when 'nightmare' then 15 when 'berserk' then 10
        when 'hotlz' then 15 when 'blitzclock' then 15 when 'barrage' then 10 when 'lockdown' then 10 when 'scorched' then 10 end
    else
      case p_id when 'nopatch' then 10 when 'alone' then 20 when 'firestorm' then 10 when 'adrenaline' then -15 when 'laststand' then 10
        when 'elite' then 15 when 'bossrush' then 10 when 'weather' then 10 when 'nightmare' then 15 when 'berserk' then 10 end
    end
$function$;

insert into public.case_types (id, name, weights, shard_cost, modes, drop, sort)
  values ('blitz', 'BLITZKRIEG CASE', '{"c":45,"r":32,"e":16,"l":6,"g":1}', 14, '{}', '{}', 4)
  on conflict (id) do update set name = excluded.name, weights = excluded.weights, shard_cost = excluded.shard_cost, sort = excluded.sort;
insert into public.cosmetics (id, cat, key, name, rarity, src, need, box, catalog_version) values
  ('hat:devilhorns', 'hat', 'devilhorns', 'Devil Horns', 'r', 'unlock', '{"mode_blitz_bosses":10}', null, 2),
  ('trail:bluearc', 'trail', 'bluearc', 'Blue Arc', 'e', 'unlock', '{"mode_blitz_bosses":25}', null, 2),
  ('skin:bluebutcher', 'skin', 'bluebutcher', 'Blue Butcher', 'e', 'unlock', '{"mode_blitz_bosses":50}', null, 2),
  ('fx:hellportal', 'fx', 'hellportal', 'Hell Portal', 'l', 'unlock', '{"mode_blitz_bosses":75}', null, 2),
  ('skin:demon', 'skin', 'demon', 'Demon', 'g', 'unlock', '{"mode_blitz_bosses":100}', null, 2),
  ('trail:brimstone', 'trail', 'brimstone', 'Brimstone', 'c', 'case', null, 'blitz', 2),
  ('trail:tealwake', 'trail', 'tealwake', 'Teal Wake', 'r', 'case', null, 'blitz', 2),
  ('trail:hellchain', 'trail', 'hellchain', 'Hellfire Chain', 'e', 'case', null, 'blitz', 2),
  ('trail:sigil', 'trail', 'sigil', 'Infernal Sigil', 'l', 'case', null, 'blitz', 2),
  ('fx:cinder', 'fx', 'cinder', 'Cinder Burst', 'c', 'case', null, 'blitz', 2),
  ('fx:tealslash', 'fx', 'tealslash', 'Teal Slash', 'r', 'case', null, 'blitz', 2),
  ('fx:ashbrand', 'fx', 'ashbrand', 'Brand of Ash', 'e', 'case', null, 'blitz', 2),
  ('fx:demonclaw', 'fx', 'demonclaw', 'Demon Claw', 'l', 'case', null, 'blitz', 2),
  ('bg:scorched', 'bg', 'scorched', 'Scorched Front', 'e', 'case', null, 'blitz', 2),
  ('bg:hellgate', 'bg', 'hellgate', 'Hellgate', 'g', 'case', null, 'blitz', 2)
  on conflict (id) do update set cat = excluded.cat, key = excluded.key, name = excluded.name, rarity = excluded.rarity, src = excluded.src,
    need = excluded.need, box = excluded.box, catalog_version = excluded.catalog_version;

-- open_case_catalog: catalog 2 (v0.9.4.0 and later clients) sees the Blitzkrieg items
CREATE OR REPLACE FUNCTION private.open_case_catalog(p_case text, p_rev integer, p_catalog integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare uid uuid := private.require_user(); l public.lockers; ct public.case_types; it public.cosmetics;
 want text; have int; dup boolean; weights jsonb;
begin
 if p_catalog is null or p_catalog not in (0,1,2) then raise exception 'Unknown cosmetic catalog' using errcode='22023'; end if;
 select * into ct from public.case_types where id=p_case;
 if not found then raise exception 'Unknown case' using errcode='22023'; end if;
 select * into l from public.lockers where user_id=uid for update;
 if not found then raise exception 'Locker not found' using errcode='22023'; end if;
 perform private.check_rev(l,p_rev);
 have := case when p_case='supply' then l.cases else coalesce((l.bag->>p_case)::int,0) end;
 if have<1 then raise exception 'No % to open',lower(ct.name)||'s' using errcode='22023'; end if;
 weights := case when p_catalog=0 and p_case='supply' then '{"c":60,"r":27,"e":10,"l":3}'::jsonb else ct.weights end;
 want := private.roll_rarity(weights);
 select * into it from public.cosmetics c where c.box=p_case and c.rarity=want and c.catalog_version<=p_catalog order by random() limit 1;
 if not found then select * into it from public.cosmetics c where c.box=p_case and c.catalog_version<=p_catalog order by c.rarity='c' desc,random() limit 1; end if;
 if not found then raise exception 'Case catalog is empty' using errcode='22023'; end if;
 dup := it.id=any(l.owned);
 update public.lockers set
  cases=case when p_case='supply' then cases-1 else cases end,
  bag=case when p_case='supply' then bag else private.bag_add(bag,p_case,-1) end,
  shards=shards+case when dup then private.shard_value(it.rarity) else 0 end,
  owned=case when dup then owned else owned||it.id end,
  rev=rev+1,updated_at=now()
 where user_id=uid returning * into l;
 return jsonb_build_object('case',p_case,'item',jsonb_build_object('id',it.id,'cat',it.cat,'key',it.key,'name',it.name,'rarity',it.rarity),
  'dup',dup,'locker',private.locker_out(l));
end $function$;

CREATE OR REPLACE FUNCTION public.open_case_v094(p_case text, p_rev integer DEFAULT NULL::integer)
 RETURNS jsonb
 LANGUAGE sql
 SET search_path TO ''
AS $function$
 select private.open_case_catalog(p_case,p_rev,2);
$function$;
revoke all on function public.open_case_v094(text, integer) from public, anon;
grant execute on function public.open_case_v094(text, integer) to authenticated;

CREATE OR REPLACE FUNCTION public.claim_match_reward(p jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare uid uuid := private.require_user(); l public.lockers; ct public.case_types; cb public.case_types;
  v_kind text := p->>'kind'; v_mode text := coalesce(p->>'mode', '5'); v_pvp text := coalesce(p->>'pvp', '');
  v_diff text := coalesce(p->>'diff', 'normal'); v_win boolean := coalesce(p->>'win' = 'true', false);
  v_held int; v_kills int := greatest(coalesce(private.num(p->>'kills'), 0), 0)::int;
  v_dur int := coalesce(private.num(p->>'duration_s'), 0)::int; v_boss int := least(greatest(coalesce(private.num(p->>'bosses'), 0), 0), 100)::int;
  waves int := 0; v_st jsonb; v_prog int; earned int := 0; granted int; got text[]; v_case text := 'supply'; chance float8; v_bonus int := 0;
  v_budget float8;
  v_sal int := least(greatest(coalesce(private.num(p->>'salvage'), 0), 0), 1000000)::int; v_shards int := 0;
  v_keys jsonb := p->'boss_keys'; v_key text; v_cap int; v_n int := 0; v_hal int := 0; v_glow int := 0;
  v_xl boolean := coalesce(p->>'size', 'std') = 'xl'; v_before text[]; v_new text[];
  v_oct boolean := (now() at time zone 'UTC') >= make_timestamp(extract(year from now())::int, 9, 30, 10, 0, 0)
               and (now() at time zone 'UTC') <  make_timestamp(extract(year from now())::int, 11, 1, 14, 0, 0);
  v_gid text := nullif(left(coalesce(p->>'game_id', ''), 40), '');
  v_to int := greatest(coalesce(private.num(p->>'raid_to'), private.num(p->>'held'), 0), 0)::int;
  v_from int := greatest(coalesce(private.num(p->>'raid_from'), 0), 0)::int;
  v_prev int; v_first int; v_join int; v_blo int; v_bhi int; v_seen boolean := false;
  v_pbn int := 0; v_psb int := 0;
  v_mods text[]; v_pct int := 0; v_credit int := 0; v_scap int;
  v_sbreq int := least(greatest(coalesce(private.num(p->>'shard_bosses'), 0), 0), 100)::int; v_sb int := 0; v_sbcap int := 0; v_sbshards int := 0;
  v_sp int := 0; v_spprog int; r int;
  v_map text := left(regexp_replace(coalesce(p->>'map', ''), '[^a-z]', '', 'g'), 12);
  v_cls text := left(regexp_replace(coalesce(p->>'cls', ''), '[^a-z]', '', 'g'), 16);
  v_bk text; cf public.case_types; v_flag int := 0;
  -- v0.9.4.0 Blitzkrieg Rush
  v_blitz boolean := coalesce(p->>'mode', '') = 'blitz' and p->>'kind' = 'run'; v_evac text := coalesce(p->>'evac', ''); v_left boolean := false;
  v_blz int := 0; v_fbn int := 0; v_fbcap int := 0; v_pfb int := 0; v_every int := 30; v_fbshards int := 0; v_mk text;
begin
  if v_kind is null or v_kind not in ('run', 'match') then raise exception 'Unknown result' using errcode = '22023'; end if;
  if v_dur < 20 or v_dur > 21600 or (v_kind = 'match' and v_dur < 30) then raise exception 'That match length doesn''t add up' using errcode = '22023'; end if;
  if v_kills > v_dur then raise exception 'That kill count doesn''t add up' using errcode = '22023'; end if;
  select * into l from public.lockers where user_id = uid for update;
  if exists (select 1 from public.match_results m where m.user_id = uid and m.created_at > now() - interval '20 seconds') then
    raise exception 'Rewards were claimed a moment ago' using errcode = '22023';
  end if;
  v_budget := least(22200, l.play_budget + extract(epoch from now() - l.budget_at));
  if v_dur > v_budget + 60 then
    raise exception 'More play time than real time so far; this result will be saved later' using errcode = '22023';
  end if;
  v_mk := case when v_blitz then 'blitz' else v_pvp end;   -- v0.9.4.0: Blitzkrieg Rush has its own modifier list
  v_mods := private.clean_mods(p->'mods', v_mk);
  select coalesce(sum(private.mod_bonus(m, v_mk)), 0) into v_pct from unnest(v_mods) m;
  v_pct := least(greatest(v_pct, -15), 75);
  if v_gid is not null then
    select max(m.raid_to), min(m.raid_from), count(*) > 0, coalesce(sum(coalesce(m.boss_n, m.bonus)), 0), coalesce(sum(m.shard_bosses), 0), coalesce(sum(m.fb_n), 0)
      into v_prev, v_first, v_seen, v_pbn, v_psb, v_pfb from public.match_results m where m.user_id = uid and m.game_id = v_gid;
  end if;
  v_st := l.st; v_prog := l.prog; v_spprog := l.sp_prog;
  if v_kind = 'run' then
    if v_mode not in ('5', '10', 'endless', 'blitz') or v_diff not in ('easy', 'normal', 'hard') then raise exception 'Unknown mode' using errcode = '22023'; end if;
    waves := case v_mode when '5' then 5 when '10' then 10 when 'blitz' then 15 else 0 end;
    if waves > 0 and v_to > waves then raise exception 'That raid count doesn''t add up' using errcode = '22023'; end if;
    v_from := least(v_from, v_to); v_join := least(v_from, coalesce(v_first, v_from));
    if v_prev is not null then v_from := greatest(v_from, least(v_prev, v_to)); end if;
    v_held := v_to - v_from;
    if v_dur + 20 < 8 * v_held + (v_held * v_held) / 4 then raise exception 'That raid count doesn''t add up' using errcode = '22023'; end if;
    -- v0.9.4.0: Blitzkrieg Rush. Once raid 15's evacuation is open each player reports their own result: 'evac' (made it
    -- out: the win) or 'left' (left behind: half their cases and shards, odd counts rounded up first).
    if not v_blitz or v_to < waves or v_evac not in ('evac', 'left') then v_evac := ''; end if;
    v_left := v_evac = 'left';
    if v_blitz and v_evac <> 'evac' then v_win := false; end if;
    if waves = 0 or v_to <> waves or v_join * 2 > waves or (v_seen and v_prev >= waves) then v_win := false; end if;
    v_st := jsonb_set(v_st, '{raids}', to_jsonb(coalesce((v_st->>'raids')::int, 0) + v_held));
    v_st := jsonb_set(v_st, '{drops}', to_jsonb(coalesce((v_st->>'drops')::int, 0) + v_kills));
    if v_win then
      v_st := jsonb_set(v_st, '{wins}', to_jsonb(coalesce((v_st->>'wins')::int, 0) + 1));
      if v_diff = 'hard' then v_st := jsonb_set(v_st, '{hardWins}', to_jsonb(coalesce((v_st->>'hardWins')::int, 0) + 1)); end if;
    end if;
    if waves = 0 then v_st := jsonb_set(v_st, '{endless}', to_jsonb(greatest(coalesce((v_st->>'endless')::int, 0), v_to))); end if;
    if v_held > 0 and v_map in ('yard', 'river', 'quarry') then
      v_st := jsonb_set(v_st, array['map_' || v_map], to_jsonb(coalesce((v_st->>('map_' || v_map))::int, 0) + v_held));
    end if;
    if v_held > 0 and v_cls in ('soldier', 'sniper', 'grenadier', 'quartermaster') then
      v_st := jsonb_set(v_st, array['cls_' || v_cls || '_raids'], to_jsonb(coalesce((v_st->>('cls_' || v_cls || '_raids'))::int, 0) + v_held));
    end if;
    v_credit := floor(v_held * (100 + v_pct) / 100.0)::int;
    v_prog := v_prog + v_credit;
    earned := v_prog / 3 + case when v_win then (case when waves >= 10 then 2 else 1 end) else 0 end + case when waves = 0 then v_held / 5 else 0 end;
    v_prog := v_prog % 3;
    -- v0.9.3.6: bosses are capped over the whole stretch this player was in the game (first join to now), minus
    -- what earlier claims for the same game already paid. The old per-claim window started at v_prev + 1, so a
    -- boss killed after a rejoin (e.g. leave after raid 4, back for raid 5) was never paid to anyone.
    v_blo := v_join;
    v_bhi := v_to + 1; if waves > 0 then v_bhi := least(v_bhi, waves); end if;
    v_cap := greatest(0, v_bhi / 5 - v_blo / 5);
    if v_xl and v_dur >= 35 * v_held then v_cap := v_cap * 2; end if;
    v_cap := greatest(0, v_cap - v_pbn);
    if jsonb_typeof(v_keys) = 'array' then
      for v_key in select value from jsonb_array_elements_text(v_keys) limit 40 loop
        exit when v_n >= v_cap;
        v_bk := case when v_key = 'butcher_oct' then 'butcher' when v_key in ('butcher', 'ferryman', 'demolisher', 'storm', 'foreman') then v_key
          when v_blitz then private.blitz_base(v_key) end;
        if v_bk is not null then v_st := jsonb_set(v_st, array['boss_' || v_bk], to_jsonb(coalesce((v_st->>('boss_' || v_bk))::int, 0) + 1)); end if;
        if v_blitz and private.blitz_base(v_key) is not null then   -- a Blitzkrieg boss (raids 5 and 10): two Blitzkrieg Cases, and the mode's ladder
          v_st := jsonb_set(v_st, '{mode_blitz_bosses}', to_jsonb(coalesce((v_st->>'mode_blitz_bosses')::int, 0) + 1));
          v_blz := v_blz + 2; v_n := v_n + 1;
        elsif v_key in ('butcher', 'ferryman') then v_hal := v_hal + 1; v_n := v_n + 1;
        elsif v_key = 'butcher_oct' then v_hal := v_hal + case when v_oct then 2 else 1 end; v_n := v_n + 1;
        elsif v_key in ('demolisher', 'storm', 'foreman') then v_glow := v_glow + 1; v_n := v_n + 1;
        end if;
      end loop;
      v_boss := v_n;
    else
      v_boss := least(v_boss, v_cap); v_glow := v_boss; v_n := v_boss;
    end if;
    select * into cb from public.case_types c where c.drop ? 'boss' order by c.sort limit 1;
    if found then v_glow := v_glow * coalesce((cb.drop->'boss'->>'each')::int, 1); end if;
    -- v0.9.4.0: the Final Blitz bosses. At most 10 (15 with Double Time) per game, one per spawn beat of the time played,
    -- less what earlier claims for this game already paid. Each: two Blitzkrieg Cases, 15-30 shards, a skill point,
    -- +1 to its base boss's milestone and +1 to the BLITZKRIEG RUSH ladder.
    if v_blitz and v_to >= waves and jsonb_typeof(p->'fb_keys') = 'array' then
      v_every := case when 'blitzclock' = any(v_mods) then 20 else 30 end;
      v_fbcap := least(case when 'blitzclock' = any(v_mods) then 15 else 10 end, greatest(0, 1 + (v_dur - 20) / v_every)) - v_pfb;
      for v_key in select value from jsonb_array_elements_text(p->'fb_keys') limit 20 loop
        exit when v_fbn >= v_fbcap;
        v_bk := private.blitz_base(v_key);
        continue when v_bk is null;
        v_st := jsonb_set(v_st, array['boss_' || v_bk], to_jsonb(coalesce((v_st->>('boss_' || v_bk))::int, 0) + 1));
        v_st := jsonb_set(v_st, '{mode_blitz_bosses}', to_jsonb(coalesce((v_st->>'mode_blitz_bosses')::int, 0) + 1));
        v_blz := v_blz + 2; v_fbn := v_fbn + 1; v_fbshards := v_fbshards + 15 + floor(random() * 16)::int;
      end loop;
    end if;
    if v_blitz then v_sbreq := 0; end if;   -- no in-between bosses in Blitzkrieg Rush
    if v_blitz and v_win then v_blz := v_blz + 1; v_fbshards := v_fbshards + 25; end if;   -- making the evacuation
    if v_sbreq > 0 and ('bossrush' = any(v_mods) or 'nightmare' = any(v_mods)) and v_dur >= 25 * greatest(v_held, 1) then
      for r in (v_blo + 1) .. v_bhi loop
        if r % 5 <> 0 and ('nightmare' = any(v_mods) or r % 2 = 0) then v_sbcap := v_sbcap + 1; end if;
      end loop;
      v_sb := least(v_sbreq, greatest(0, v_sbcap - v_psb));
      -- v0.9.3.8: every paid in-between boss also counts toward its boss milestone (clients send which bosses they were)
      if v_sb > 0 and jsonb_typeof(p->'sb_keys') = 'array' then
        for v_key in select value from jsonb_array_elements_text(p->'sb_keys') limit v_sb loop
          v_bk := case when v_key in ('butcher', 'ferryman', 'demolisher', 'storm', 'foreman') then v_key end;
          if v_bk is not null then v_st := jsonb_set(v_st, array['boss_' || v_bk], to_jsonb(coalesce((v_st->>('boss_' || v_bk))::int, 0) + 1)); end if;
        end loop;
      end if;
      for r in 1 .. v_sb loop v_sbshards := v_sbshards + 15 + floor(random() * 16)::int; end loop;
    end if;
    v_scap := greatest(0, floor(10 * (100 + v_pct) / 100.0)::int);
    v_shards := least(v_sal / 20, 2 * v_held, v_scap) + v_sbshards + v_fbshards;
    v_spprog := v_spprog + v_held;
    v_sp := v_spprog / 5 + v_n + v_sb + v_fbn;
    v_spprog := v_spprog % 5;
  else
    if v_pvp not in ('base', 'ffa') then raise exception 'Unknown match type' using errcode = '22023'; end if;
    v_held := 0;
    v_st := jsonb_set(v_st, '{drops}', to_jsonb(coalesce((v_st->>'drops')::int, 0) + v_kills));
    if not v_seen then
      v_st := jsonb_set(v_st, '{pvp}', to_jsonb(coalesce((v_st->>'pvp')::int, 0) + 1));
      if v_win then v_st := jsonb_set(v_st, '{pvpWins}', to_jsonb(coalesce((v_st->>'pvpWins')::int, 0) + 1)); end if;
    end if;
    v_case := null;
    select * into ct from public.case_types c where v_pvp = any(c.modes) order by c.sort limit 1;
    if found then
      v_case := ct.id;
      chance := coalesce((ct.drop->v_pvp->>(case when v_win then 'win' else 'loss' end))::float8, 0) * (100 + v_pct) / 100.0;
      if v_seen then chance := 0; end if;
      if random() < chance then earned := 1; end if;
    end if;
  end if;
  if v_win and not (v_kind = 'match' and v_seen) then
    select * into cf from public.case_types c where c.drop ? 'win' order by c.sort limit 1;
    if found and random() < coalesce((cf.drop->>'win')::float8, 0) then v_flag := 1; end if;
  end if;
  granted := earned;
  if v_left then   -- left behind: half of every case and of the shards (odd counts round up first); nothing else is halved
    granted := ceil(granted / 2.0)::int; v_glow := ceil(v_glow / 2.0)::int; v_hal := ceil(v_hal / 2.0)::int; v_blz := ceil(v_blz / 2.0)::int;
    v_shards := ceil(v_shards / 2.0)::int; v_fbshards := ceil(v_fbshards / 2.0)::int; v_sbshards := ceil(v_sbshards / 2.0)::int;
  end if;
  v_bonus := v_glow + v_hal + v_blz;
  v_before := l.owned;
  update public.lockers set st = v_st, prog = v_prog,
      cases = cases + case when v_case = 'supply' then granted else 0 end,
      bag = private.bag_add(private.bag_add(
              case when v_case is not null and v_case <> 'supply' and granted > 0 then private.bag_add(bag, v_case, granted) else bag end,
              coalesce(cb.id, 'afterglow'), v_glow), 'halloween', v_hal)
            || case when v_blz > 0 then jsonb_build_object('blitz', coalesce((bag->>'blitz')::int, 0) + v_blz) else '{}'::jsonb end
            || case when v_flag > 0 then jsonb_build_object(cf.id, coalesce((bag->>cf.id)::int, 0) + v_flag) else '{}'::jsonb end,
      shards = shards + v_shards,
      sp = sp + v_sp, sp_total = sp_total + v_sp, sp_prog = v_spprog,
      play_budget = greatest(0, v_budget - v_dur), budget_at = now(),
      rev = rev + 1, updated_at = now()
    where user_id = uid;
  insert into public.match_results (user_id, kind, mode, pvp, diff, win, held, kills, duration_s, cases_granted, case_id, bonus, shards,
      game_id, raid_from, raid_to, joined_s, left_s, left_early, upgrades, salvage, mods, map, size, shard_bosses, skill_points, cls, boss_n, fb_n, evac)
    values (uid, v_kind, case when v_kind = 'run' then v_mode end, nullif(v_pvp, ''), case when v_kind = 'run' then v_diff end,
            v_win, v_held, v_kills, v_dur, granted, v_case, v_bonus, v_shards,
            v_gid, case when v_kind = 'run' then v_from end, case when v_kind = 'run' then v_to end,
            least(greatest(private.num(p->>'joined_s'), 0), 86400)::int, least(greatest(private.num(p->>'left_s'), 0), 86400)::int,
            coalesce(p->>'left' = 'true', false), left(regexp_replace(coalesce(p->>'upgrades', ''), '[^0-9a-z:]', '', 'g'), 16), v_sal,
            v_mods, left(regexp_replace(coalesce(p->>'map', ''), '[^a-z]', '', 'g'), 12), case when v_xl then 'xl' else 'std' end, v_sb, v_sp,
            nullif(v_cls, ''), case when v_kind = 'run' then v_n end, v_fbn, nullif(v_evac, ''));
  update public.player_stats s set
      raids = s.raids + case when v_kind = 'run' then v_held else 0 end,
      wins = s.wins + case when v_kind = 'run' and v_win then 1 else 0 end,
      drops = s.drops + v_kills,
      best_endless = greatest(s.best_endless, case when v_kind = 'run' and waves = 0 then v_to else 0 end),
      pvp = s.pvp + case when v_kind = 'match' and not v_seen then 1 else 0 end,
      pvp_wins = s.pvp_wins + case when v_kind = 'match' and v_win and not v_seen then 1 else 0 end,
      updated_at = now()
    where s.user_id = uid;
  got := private.apply_unlocks(uid);
  select * into l from public.lockers where user_id = uid;
  v_new := array(select u from unnest(l.owned) u where not (u = any(v_before)));
  return jsonb_build_object(
    'cases', (case when v_kind = 'run'
        then jsonb_build_object('supply', granted, coalesce(cb.id, 'afterglow'), v_glow, 'halloween', v_hal) || case when v_blz > 0 then jsonb_build_object('blitz', v_blz) else '{}'::jsonb end
        else case when v_case is not null then jsonb_build_object(v_case, granted) else '{}'::jsonb end end)
      || case when v_flag > 0 then jsonb_build_object(cf.id, v_flag) else '{}'::jsonb end,
    'unlocked_ids', to_jsonb(v_new), 'to_next', 3 - l.prog, 'size', case when v_xl and v_dur >= 35 * v_held then 'xl' else 'std' end,
    'cases_granted', granted, 'case_id', v_case, 'capped', false, 'chance', chance,
    'bonus', jsonb_build_object('case', coalesce(cb.id, 'afterglow'), 'n', v_glow), 'shards', v_shards,
    'bonuses', jsonb_build_array(jsonb_build_object('case', coalesce(cb.id, 'afterglow'), 'n', v_glow), jsonb_build_object('case', 'halloween', 'n', v_hal), jsonb_build_object('case', 'blitz', 'n', v_blz)),
    'held', v_held, 'raid_from', v_from, 'mods', to_jsonb(v_mods), 'mod_pct', v_pct, 'shard_bosses', v_sb,
    'skill_points', v_sp, 'sp', l.sp, 'sp_to_next', 5 - l.sp_prog, 'repeat', v_seen,
    'flag_case', v_flag, 'left_behind', v_left, 'fb_bosses', v_fbn, 'evac', v_evac, 'boss_shards', v_sbshards + v_fbshards,
    'unlocked', to_jsonb(got), 'locker', private.locker_out(l));
end $function$;


revoke all on function public.claim_match_reward(jsonb) from public, anon;
grant execute on function public.claim_match_reward(jsonb) to authenticated;

-- SOURCE: 20261001045820_ammo_armory_expansion.sql
-- Four co-op special-ammo skill nodes. Based on the live skill_defs and skill_buy
-- function bodies read on 2026-10-01. The existing cost table and respec accounting
-- stay intact; skill_spent reads skill_defs dynamically.
create or replace function private.skill_defs()
returns jsonb language sql immutable set search_path to '' as $function$
  select '{"dmg":{"cost":[1,2,3]},"rate":{"cost":[1,2,3]},"reload":{"cost":[1,2]},"range":{"cost":[1,2]},
    "hp":{"cost":[1,2,3]},"regen":{"cost":[2,3]},"revive":{"cost":[1,2]},"speed":{"cost":[1,2,3]},"vest":{"cost":[2,3]},"haul":{"cost":[1,2]},
    "rockets":{"cost":[1,2,3]},"pouch":{"cost":[2,3]},"molotov":{"cost":[3],"req":["pouch",1]},"ghillie":{"cost":[1,2]},"stride":{"cost":[1,2]},
    "ammo_ap":{"cost":[1,2,3,4],"gate":[5,10,15,20]},"ammo_fire":{"cost":[1,2,3,4],"gate":[5,10,15,20]},
    "ammo_blast":{"cost":[1,2,3,4],"gate":[5,10,15,20]},"ammo_shock":{"cost":[1,2,3,4],"gate":[5,10,15,20]}}'::jsonb
$function$;

create or replace function public.skill_buy(p_node text, p_rev integer default null)
returns jsonb language plpgsql security definer set search_path to '' as $function$
declare uid uuid := private.require_user(); l public.lockers; d jsonb := private.skill_defs()->p_node; lv int; cost int; gate int;
begin
  if d is null then raise exception 'Unknown skill' using errcode = '22023'; end if;
  select * into l from public.lockers where user_id = uid for update;
  perform private.check_rev(l, p_rev);
  lv := coalesce((l.skills->>p_node)::int, 0);
  if lv >= jsonb_array_length(d->'cost') then raise exception 'That skill is maxed' using errcode = '22023'; end if;
  if d ? 'req' and coalesce((l.skills->>(d->'req'->>0))::int, 0) < (d->'req'->>1)::int then
    raise exception 'Unlock % first', d->'req'->>0 using errcode = '22023'; end if;
  if d ? 'gate' then
    gate := (d->'gate'->>lv)::int;
    if l.sp_total < gate then raise exception 'Earn % lifetime skill points first', gate using errcode = '22023'; end if;
  end if;
  cost := (d->'cost'->>lv)::int;
  if l.sp < cost then raise exception 'That takes % skill point%', cost, case when cost = 1 then '' else 's' end using errcode = '22023'; end if;
  update public.lockers set sp = sp - cost, skills = jsonb_set(skills, array[p_node], to_jsonb(lv + 1)), rev = rev + 1, updated_at = now()
    where user_id = uid returning * into l;
  return private.locker_out(l);
end $function$;

revoke all on function private.skill_defs() from public, anon, authenticated;
revoke all on function public.skill_buy(text, integer) from public, anon;
grant execute on function public.skill_buy(text, integer) to authenticated;

-- SOURCE: 20261001053822_blitz_open_lobbies.sql
-- Blitzkrieg Rush hosts publish length='blitz'. The original constraint rejected
-- every heartbeat, leaving working rooms absent from the Open Games list.
alter table public.lobbies drop constraint if exists lobbies_length_check;
alter table public.lobbies add constraint lobbies_length_check
  check (length in ('5', '10', 'endless', 'blitz'));

-- SOURCE: 20261001081259_winter_whiteout.sql
-- v0.9.6.0: additive winter catalog, chapter accounting and retry receipts.
alter table public.lobbies drop constraint if exists lobbies_length_check;
alter table public.lobbies add constraint lobbies_length_check check(length in ('5','10','endless','blitz','campaign'));
create table if not exists private.reward_receipts(user_id uuid references public.profiles(id) on delete cascade,claim_key text,response jsonb not null,created_at timestamptz not null default now(),primary key(user_id,claim_key));
alter table private.reward_receipts enable row level security;
revoke all on private.reward_receipts from public,anon,authenticated;
create or replace function private.winter_base(k text) returns text language sql immutable set search_path='' as $$
 select case k when 'whitebutcher' then 'butcher' when 'whiteferryman' then 'ferryman' when 'whiteforeman' then 'foreman' when 'rime' then 'rime' else private.blitz_base(k) end
$$;
revoke all on function private.winter_base(text) from public,anon,authenticated;
insert into public.case_types(id,name,weights,shard_cost,modes,drop,sort) values('winter','WINTER CASE','{"c":45,"r":32,"e":16,"l":6,"g":1}',14,'{}','{}',6)
on conflict(id) do update set name=excluded.name,weights=excluded.weights,shard_cost=excluded.shard_cost;
CREATE OR REPLACE FUNCTION public.claim_match_reward(p jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare uid uuid := private.require_user(); l public.lockers; ct public.case_types; cb public.case_types;
  v_kind text := p->>'kind'; v_mode text := coalesce(p->>'mode', '5'); v_pvp text := coalesce(p->>'pvp', '');
  v_diff text := coalesce(p->>'diff', 'normal'); v_win boolean := coalesce(p->>'win' = 'true', false);
  v_held int; v_kills int := greatest(coalesce(private.num(p->>'kills'), 0), 0)::int;
  v_dur int := coalesce(private.num(p->>'duration_s'), 0)::int; v_boss int := least(greatest(coalesce(private.num(p->>'bosses'), 0), 0), 100)::int;
  waves int := 0; v_st jsonb; v_prog int; earned int := 0; granted int; got text[]; v_case text := 'supply'; chance float8; v_bonus int := 0;
  v_budget float8;
  v_sal int := least(greatest(coalesce(private.num(p->>'salvage'), 0), 0), 1000000)::int; v_shards int := 0;
  v_keys jsonb := p->'boss_keys'; v_key text; v_cap int; v_n int := 0; v_hal int := 0; v_glow int := 0;
  v_xl boolean := coalesce(p->>'size', 'std') = 'xl'; v_before text[]; v_new text[];
  v_oct boolean := (now() at time zone 'UTC') >= make_timestamp(extract(year from now())::int, 9, 30, 10, 0, 0)
               and (now() at time zone 'UTC') <  make_timestamp(extract(year from now())::int, 11, 1, 14, 0, 0);
  v_gid text := nullif(left(coalesce(p->>'game_id', ''), 40), '');
  v_to int := greatest(coalesce(private.num(p->>'raid_to'), private.num(p->>'held'), 0), 0)::int;
  v_from int := greatest(coalesce(private.num(p->>'raid_from'), 0), 0)::int;
  v_prev int; v_first int; v_join int; v_blo int; v_bhi int; v_seen boolean := false;
  v_pbn int := 0; v_psb int := 0;
  v_mods text[]; v_pct int := 0; v_credit int := 0; v_scap int;
  v_sbreq int := least(greatest(coalesce(private.num(p->>'shard_bosses'), 0), 0), 100)::int; v_sb int := 0; v_sbcap int := 0; v_sbshards int := 0;
  v_sp int := 0; v_spprog int; r int;
  v_map text := left(regexp_replace(coalesce(p->>'map', ''), '[^a-z]', '', 'g'), 12);
  v_cls text := left(regexp_replace(coalesce(p->>'cls', ''), '[^a-z]', '', 'g'), 16);
  v_bk text; cf public.case_types; v_flag int := 0;
  -- v0.9.4.0 Blitzkrieg Rush
  v_blitz boolean := coalesce(p->>'mode', '') in ('blitz','campaign') and p->>'kind' = 'run'; v_evac text := coalesce(p->>'evac', ''); v_left boolean := false;
  v_paid_keys text[]:='{}';
  v_campaign boolean := coalesce(p->>'mode','')='campaign'; v_winter int := 0; v_receipt text; v_cached jsonb; v_response jsonb;
  v_blz int := 0; v_fbn int := 0; v_fbcap int := 0; v_pfb int := 0; v_every int := 30; v_fbshards int := 0; v_mk text;
begin
  if v_kind is null or v_kind not in ('run', 'match') then raise exception 'Unknown result' using errcode = '22023'; end if;
  if v_dur < 20 or v_dur > 21600 or (v_kind = 'match' and v_dur < 30) then raise exception 'That match length doesn''t add up' using errcode = '22023'; end if;
  if v_kills > v_dur then raise exception 'That kill count doesn''t add up' using errcode = '22023'; end if;
  select * into l from public.lockers where user_id = uid for update;
  v_receipt := md5(coalesce(p->>'claim_id',p::text));
  select response into v_cached from private.reward_receipts where user_id=uid and claim_key=v_receipt;
  if found then return v_cached || jsonb_build_object('locker',private.locker_out(l),'retry',true); end if;
  if exists (select 1 from public.match_results m where m.user_id = uid and m.created_at > now() - interval '20 seconds') then
    raise exception 'Rewards were claimed a moment ago' using errcode = '22023';
  end if;
  v_budget := least(22200, l.play_budget + extract(epoch from now() - l.budget_at));
  if v_dur > v_budget + 60 then
    raise exception 'More play time than real time so far; this result will be saved later' using errcode = '22023';
  end if;
  v_mk := case when v_blitz and not v_campaign then 'blitz' else v_pvp end;   -- v0.9.4.0: Blitzkrieg Rush has its own modifier list
  v_mods := private.clean_mods(p->'mods', v_mk);
  if v_campaign then v_mods:=array(select m from unnest(v_mods) m where m not in ('bossrush','nightmare','blitzclock','hotlz','lockdown','scorched','barrage','onejob')); end if;
  select coalesce(sum(private.mod_bonus(m, v_mk)), 0) into v_pct from unnest(v_mods) m;
  v_pct := least(greatest(v_pct, -15), 75);
  if v_gid is not null then
    select max(m.raid_to), min(m.raid_from), count(*) > 0, coalesce(sum(coalesce(m.boss_n, m.bonus)), 0), coalesce(sum(m.shard_bosses), 0), coalesce(sum(m.fb_n), 0)
      into v_prev, v_first, v_seen, v_pbn, v_psb, v_pfb from public.match_results m where m.user_id = uid and m.game_id = v_gid;
  end if;
  v_st := l.st; v_prog := l.prog; v_spprog := l.sp_prog;
  if v_kind = 'run' then
    if v_mode not in ('5', '10', 'endless', 'blitz','campaign') or v_diff not in ('easy', 'normal', 'hard') then raise exception 'Unknown mode' using errcode = '22023'; end if;
    waves := case v_mode when '5' then 5 when '10' then 10 when 'blitz' then 15 when 'campaign' then 13 else 0 end;
    if waves > 0 and v_to > waves then raise exception 'That raid count doesn''t add up' using errcode = '22023'; end if;
    v_from := least(v_from, v_to); v_join := least(v_from, coalesce(v_first, v_from));
    if v_prev is not null then v_from := greatest(v_from, least(v_prev, v_to)); end if;
    v_held := v_to - v_from;
    if v_dur + 20 < 8 * v_held + (v_held * v_held) / 4 then raise exception 'That raid count doesn''t add up' using errcode = '22023'; end if;
    -- v0.9.4.0: Blitzkrieg Rush. Once raid 15's evacuation is open each player reports their own result: 'evac' (made it
    -- out: the win) or 'left' (left behind: half their cases and shards, odd counts rounded up first).
    if not v_blitz or v_to < waves or v_evac not in ('evac', 'left') then v_evac := ''; end if;
    v_left := v_evac = 'left';
    if v_blitz and v_evac <> 'evac' then v_win := false; end if;
    if waves = 0 or v_to <> waves or v_join * 2 > waves or (v_seen and v_prev >= waves) then v_win := false; end if;
    v_st := jsonb_set(v_st, '{raids}', to_jsonb(coalesce((v_st->>'raids')::int, 0) + v_held));
    v_st := jsonb_set(v_st, '{drops}', to_jsonb(coalesce((v_st->>'drops')::int, 0) + v_kills));
    if v_win then
      v_st := jsonb_set(v_st, '{wins}', to_jsonb(coalesce((v_st->>'wins')::int, 0) + 1));
      if v_diff = 'hard' then v_st := jsonb_set(v_st, '{hardWins}', to_jsonb(coalesce((v_st->>'hardWins')::int, 0) + 1)); end if;
    end if;
    if waves = 0 then v_st := jsonb_set(v_st, '{endless}', to_jsonb(greatest(coalesce((v_st->>'endless')::int, 0), v_to))); end if;
    if v_campaign and v_held>0 then
      for r in (v_from+1)..v_to loop
        v_bk:=case when r<=3 then 'yard' when r<=6 then 'river' when r<=9 then 'quarry' else 'frost' end;
        v_st:=jsonb_set(v_st,array['map_'||v_bk],to_jsonb(coalesce((v_st->>('map_'||v_bk))::int,0)+1));
      end loop;
    elsif v_held > 0 and v_map in ('yard', 'river', 'quarry','frost') then
      v_st := jsonb_set(v_st, array['map_' || v_map], to_jsonb(coalesce((v_st->>('map_' || v_map))::int, 0) + v_held));
    end if;
    if v_held > 0 and v_cls in ('soldier', 'sniper', 'grenadier', 'quartermaster') then
      v_st := jsonb_set(v_st, array['cls_' || v_cls || '_raids'], to_jsonb(coalesce((v_st->>('cls_' || v_cls || '_raids'))::int, 0) + v_held));
    end if;
    v_credit := floor(v_held * (100 + v_pct) / 100.0)::int;
    v_prog := v_prog + v_credit;
    earned := v_prog / 3 + case when v_win then (case when waves >= 10 then 2 else 1 end) else 0 end + case when waves = 0 then v_held / 5 else 0 end;
    v_prog := v_prog % 3;
    -- v0.9.3.6: bosses are capped over the whole stretch this player was in the game (first join to now), minus
    -- what earlier claims for the same game already paid. The old per-claim window started at v_prev + 1, so a
    -- boss killed after a rejoin (e.g. leave after raid 4, back for raid 5) was never paid to anyone.
    v_blo := v_join;
    v_bhi := v_to + 1; if waves > 0 then v_bhi := least(v_bhi, waves); end if;
    v_cap := case when v_campaign then greatest(0,least(12,v_bhi)/3-v_blo/3) else greatest(0, v_bhi / 5 - v_blo / 5) end;
    if not v_campaign and v_xl and v_dur >= 35 * v_held then v_cap := v_cap * 2; end if;
    v_cap := greatest(0, v_cap - v_pbn);
    if jsonb_typeof(v_keys) = 'array' then
      for v_key in select value from jsonb_array_elements_text(v_keys) limit 40 loop
        exit when v_n >= v_cap;
        if v_campaign then
          continue when v_key=any(v_paid_keys) or v_key not in ('whitebutcher','whiteferryman','whiteforeman','rime');
          continue when v_key='whitebutcher' and not(v_blo<3 and v_bhi>=3) or v_key='whiteferryman' and not(v_blo<6 and v_bhi>=6) or v_key='whiteforeman' and not(v_blo<9 and v_bhi>=9) or v_key='rime' and not(v_blo<12 and v_bhi>=12);
          v_paid_keys:=array_append(v_paid_keys,v_key);
        end if;
        v_bk := case when v_key = 'butcher_oct' then 'butcher' when v_key in ('butcher', 'ferryman', 'demolisher', 'storm', 'foreman') then v_key
          when v_key='rime' and v_map='frost' then 'rime' when v_campaign then private.winter_base(v_key) when v_blitz then private.blitz_base(v_key) end;
        if v_bk is not null then v_st := jsonb_set(v_st, array['boss_' || v_bk], to_jsonb(coalesce((v_st->>('boss_' || v_bk))::int, 0) + 1)); end if;
        if (v_campaign and v_key in ('whitebutcher','whiteferryman','whiteforeman','rime')) or (v_map='frost' and v_key='rime') then
          v_winter:=v_winter+case when v_key='rime' then 2 else 1 end;v_n:=v_n+1;
        elsif v_blitz and private.blitz_base(v_key) is not null then   -- a Blitzkrieg boss (raids 5 and 10): two Blitzkrieg Cases, and the mode's ladder
          v_st := jsonb_set(v_st, '{mode_blitz_bosses}', to_jsonb(coalesce((v_st->>'mode_blitz_bosses')::int, 0) + 1));
          v_blz := v_blz + 2; v_n := v_n + 1;
        elsif v_key in ('butcher', 'ferryman') then v_hal := v_hal + 1; v_n := v_n + 1;
        elsif v_key = 'butcher_oct' then v_hal := v_hal + case when v_oct then 2 else 1 end; v_n := v_n + 1;
        elsif v_key in ('demolisher', 'storm', 'foreman') then v_glow := v_glow + 1; v_n := v_n + 1;
        end if;
      end loop;
      v_boss := v_n;
    else
      v_boss := least(v_boss, v_cap); v_glow := v_boss; v_n := v_boss;
    end if;
    select * into cb from public.case_types c where c.drop ? 'boss' order by c.sort limit 1;
    if found then v_glow := v_glow * coalesce((cb.drop->'boss'->>'each')::int, 1); end if;
    -- v0.9.4.0: the Final Blitz bosses. At most 10 (15 with Double Time) per game, one per spawn beat of the time played,
    -- less what earlier claims for this game already paid. Each: two Blitzkrieg Cases, 15-30 shards, a skill point,
    -- +1 to its base boss's milestone and +1 to the BLITZKRIEG RUSH ladder.
    if v_blitz and v_to >= waves and jsonb_typeof(p->'fb_keys') = 'array' then
      v_every := case when 'blitzclock' = any(v_mods) then 20 else 30 end;
      v_fbcap := least(case when 'blitzclock' = any(v_mods) then 15 else 10 end, greatest(0, 1 + (v_dur - 20) / v_every)) - v_pfb;
      for v_key in select value from jsonb_array_elements_text(p->'fb_keys') limit 20 loop
        exit when v_fbn >= v_fbcap;
        if v_campaign and v_key not in ('whitebutcher','whiteforeman','rime','tempest','bulldozer') then continue;end if;
        v_bk := case when v_campaign or v_key='rime' and v_map='frost' then private.winter_base(v_key) else private.blitz_base(v_key) end;
        continue when v_bk is null;
        v_st := jsonb_set(v_st, array['boss_' || v_bk], to_jsonb(coalesce((v_st->>('boss_' || v_bk))::int, 0) + 1));
        if not v_campaign and v_key<>'rime' then v_st := jsonb_set(v_st, '{mode_blitz_bosses}', to_jsonb(coalesce((v_st->>'mode_blitz_bosses')::int, 0) + 1));end if;
        if v_key in ('whitebutcher','whiteferryman','whiteforeman','rime') then v_winter:=v_winter+case when v_key='rime' then 2 else 1 end;else v_blz:=v_blz+2;end if; v_fbn := v_fbn + 1; v_fbshards := v_fbshards + 15 + floor(random() * 16)::int;
      end loop;
    end if;
    if v_blitz then v_sbreq := 0; end if;   -- no in-between bosses in Blitzkrieg Rush
    if v_blitz and v_win then if v_campaign then v_winter:=v_winter+1;else v_blz := v_blz + 1;end if; v_fbshards := v_fbshards + 25; end if;   -- making the evacuation
    if v_sbreq > 0 and ('bossrush' = any(v_mods) or 'nightmare' = any(v_mods)) and v_dur >= 25 * greatest(v_held, 1) then
      for r in (v_blo + 1) .. v_bhi loop
        if r % 5 <> 0 and ('nightmare' = any(v_mods) or r % 2 = 0) then v_sbcap := v_sbcap + 1; end if;
      end loop;
      v_sb := least(v_sbreq, greatest(0, v_sbcap - v_psb));
      -- v0.9.3.8: every paid in-between boss also counts toward its boss milestone (clients send which bosses they were)
      if v_sb > 0 and jsonb_typeof(p->'sb_keys') = 'array' then
        for v_key in select value from jsonb_array_elements_text(p->'sb_keys') limit v_sb loop
          v_bk := case when v_key in ('butcher', 'ferryman', 'demolisher', 'storm', 'foreman') then v_key when v_key='rime' and v_map='frost' then 'rime' end;
          if v_bk is not null then v_st := jsonb_set(v_st, array['boss_' || v_bk], to_jsonb(coalesce((v_st->>('boss_' || v_bk))::int, 0) + 1)); end if;
        end loop;
      end if;
      for r in 1 .. v_sb loop v_sbshards := v_sbshards + 15 + floor(random() * 16)::int; end loop;
    end if;
    v_scap := greatest(0, floor(10 * (100 + v_pct) / 100.0)::int);
    v_shards := least(v_sal / 20, 2 * v_held, v_scap) + v_sbshards + v_fbshards;
    v_spprog := v_spprog + v_held;
    v_sp := v_spprog / 5 + v_n + v_sb + v_fbn;
    v_spprog := v_spprog % 5;
  else
    if v_pvp not in ('base', 'ffa') then raise exception 'Unknown match type' using errcode = '22023'; end if;
    v_held := 0;
    v_st := jsonb_set(v_st, '{drops}', to_jsonb(coalesce((v_st->>'drops')::int, 0) + v_kills));
    if not v_seen then
      v_st := jsonb_set(v_st, '{pvp}', to_jsonb(coalesce((v_st->>'pvp')::int, 0) + 1));
      if v_win then v_st := jsonb_set(v_st, '{pvpWins}', to_jsonb(coalesce((v_st->>'pvpWins')::int, 0) + 1)); end if;
    end if;
    v_case := null;
    select * into ct from public.case_types c where v_pvp = any(c.modes) order by c.sort limit 1;
    if found then
      v_case := ct.id;
      chance := coalesce((ct.drop->v_pvp->>(case when v_win then 'win' else 'loss' end))::float8, 0) * (100 + v_pct) / 100.0;
      if v_seen then chance := 0; end if;
      if random() < chance then earned := 1; end if;
    end if;
  end if;
  if v_win and not (v_kind = 'match' and v_seen) then
    select * into cf from public.case_types c where c.drop ? 'win' order by c.sort limit 1;
    if found and random() < coalesce((cf.drop->>'win')::float8, 0) then v_flag := 1; end if;
  end if;
  granted := earned;
  if v_left then   -- left behind: half of every case and of the shards (odd counts round up first); nothing else is halved
    granted := ceil(granted / 2.0)::int; v_glow := ceil(v_glow / 2.0)::int; v_hal := ceil(v_hal / 2.0)::int; v_blz := ceil(v_blz / 2.0)::int;
    v_shards := ceil(v_shards / 2.0)::int; v_fbshards := ceil(v_fbshards / 2.0)::int; v_sbshards := ceil(v_sbshards / 2.0)::int;
  end if;
  if v_left then v_winter:=ceil(v_winter/2.0)::int;end if;
  v_bonus := v_glow + v_hal + v_blz+v_winter;
  v_before := l.owned;
  update public.lockers set st = v_st, prog = v_prog,
      cases = cases + case when v_case = 'supply' then granted else 0 end,
      bag = private.bag_add(private.bag_add(
              case when v_case is not null and v_case <> 'supply' and granted > 0 then private.bag_add(bag, v_case, granted) else bag end,
              coalesce(cb.id, 'afterglow'), v_glow), 'halloween', v_hal)
            || case when v_blz > 0 then jsonb_build_object('blitz', coalesce((bag->>'blitz')::int, 0) + v_blz) else '{}'::jsonb end
            || case when v_flag > 0 then jsonb_build_object(cf.id, coalesce((bag->>cf.id)::int, 0) + v_flag) else '{}'::jsonb end
            || case when v_winter>0 then jsonb_build_object('winter',coalesce((bag->>'winter')::int,0)+v_winter) else '{}'::jsonb end,
      shards = shards + v_shards,
      sp = sp + v_sp, sp_total = sp_total + v_sp, sp_prog = v_spprog,
      play_budget = greatest(0, v_budget - v_dur), budget_at = now(),
      rev = rev + 1, updated_at = now()
    where user_id = uid;
  insert into public.match_results (user_id, kind, mode, pvp, diff, win, held, kills, duration_s, cases_granted, case_id, bonus, shards,
      game_id, raid_from, raid_to, joined_s, left_s, left_early, upgrades, salvage, mods, map, size, shard_bosses, skill_points, cls, boss_n, fb_n, evac)
    values (uid, v_kind, case when v_kind = 'run' then v_mode end, nullif(v_pvp, ''), case when v_kind = 'run' then v_diff end,
            v_win, v_held, v_kills, v_dur, granted, v_case, v_bonus, v_shards,
            v_gid, case when v_kind = 'run' then v_from end, case when v_kind = 'run' then v_to end,
            least(greatest(private.num(p->>'joined_s'), 0), 86400)::int, least(greatest(private.num(p->>'left_s'), 0), 86400)::int,
            coalesce(p->>'left' = 'true', false), left(regexp_replace(coalesce(p->>'upgrades', ''), '[^0-9a-z:]', '', 'g'), 16), v_sal,
            v_mods, left(regexp_replace(coalesce(p->>'map', ''), '[^a-z]', '', 'g'), 12), case when v_xl then 'xl' else 'std' end, v_sb, v_sp,
            nullif(v_cls, ''), case when v_kind = 'run' then v_n end, v_fbn, nullif(v_evac, ''));
  update public.player_stats s set
      raids = s.raids + case when v_kind = 'run' then v_held else 0 end,
      wins = s.wins + case when v_kind = 'run' and v_win then 1 else 0 end,
      drops = s.drops + v_kills,
      best_endless = greatest(s.best_endless, case when v_kind = 'run' and waves = 0 then v_to else 0 end),
      pvp = s.pvp + case when v_kind = 'match' and not v_seen then 1 else 0 end,
      pvp_wins = s.pvp_wins + case when v_kind = 'match' and v_win and not v_seen then 1 else 0 end,
      updated_at = now()
    where s.user_id = uid;
  got := private.apply_unlocks(uid);
  select * into l from public.lockers where user_id = uid;
  v_new := array(select u from unnest(l.owned) u where not (u = any(v_before)));
  v_response := jsonb_build_object(
    'cases', (case when v_kind = 'run'
        then jsonb_build_object('supply', granted, coalesce(cb.id, 'afterglow'), v_glow, 'halloween', v_hal) || case when v_blz > 0 then jsonb_build_object('blitz', v_blz) else '{}'::jsonb end
        else case when v_case is not null then jsonb_build_object(v_case, granted) else '{}'::jsonb end end)
      || case when v_flag > 0 then jsonb_build_object(cf.id, v_flag) else '{}'::jsonb end
      || case when v_winter>0 then jsonb_build_object('winter',v_winter) else '{}'::jsonb end,
    'unlocked_ids', to_jsonb(v_new), 'to_next', 3 - l.prog, 'size', case when v_xl and v_dur >= 35 * v_held then 'xl' else 'std' end,
    'cases_granted', granted, 'case_id', v_case, 'capped', false, 'chance', chance,
    'bonus', jsonb_build_object('case', coalesce(cb.id, 'afterglow'), 'n', v_glow), 'shards', v_shards,
    'bonuses', jsonb_build_array(jsonb_build_object('case', coalesce(cb.id, 'afterglow'), 'n', v_glow), jsonb_build_object('case', 'halloween', 'n', v_hal), jsonb_build_object('case', 'blitz', 'n', v_blz)),
    'held', v_held, 'raid_from', v_from, 'mods', to_jsonb(v_mods), 'mod_pct', v_pct, 'shard_bosses', v_sb,
    'skill_points', v_sp, 'sp', l.sp, 'sp_to_next', 5 - l.sp_prog, 'repeat', v_seen,
    'flag_case', v_flag, 'left_behind', v_left, 'fb_bosses', v_fbn, 'evac', v_evac, 'boss_shards', v_sbshards + v_fbshards,
    'unlocked', to_jsonb(got), 'locker', private.locker_out(l));
  insert into private.reward_receipts(user_id,claim_key,response) values(uid,v_receipt,v_response);
  delete from private.reward_receipts where user_id=uid and created_at<now()-interval '31 days';
  return v_response;
end $function$;

revoke all on function public.claim_match_reward(jsonb) from public,anon;
grant execute on function public.claim_match_reward(jsonb) to authenticated;

-- Exactly 42 items, eight milestone skins and 34 Winter Case items.
insert into public.cosmetics(id,cat,key,name,rarity,src,need,box,catalog_version) values
('skin:snowline','skin','snowline','Snowline Scout','r','unlock','{"map_frost":250}',null,2),
('hat:snowgoggles','hat','snowgoggles','Snowline Goggles','c','case',null,'winter',2),
('skin:summitranger','skin','summitranger','Summit Ranger','e','unlock','{"map_frost":500}',null,2),
('hat:ushanka','hat','ushanka','Ranger Ushanka','r','case',null,'winter',2),
('skin:glacierengineer','skin','glacierengineer','Glacier Engineer','l','unlock','{"map_frost":1000}',null,2),
('hat:surveyhelm','hat','surveyhelm','Surveyor Helmet','r','case',null,'winter',2),
('skin:polarrescue','skin','polarrescue','Polar Rescue','r','unlock','{"boss_rime":25}',null,2),
('hat:rescuehood','hat','rescuehood','Rescue Hood','e','case',null,'winter',2),
('skin:evergreen','skin','evergreen','Evergreen Sentinel','e','unlock','{"boss_rime":50}',null,2),
('hat:pinecrown','hat','pinecrown','Evergreen Crown','e','case',null,'winter',2),
('skin:yuletideqm','skin','yuletideqm','Yuletide Quartermaster','r','case',null,'winter',2),
('hat:yulecap','hat','yulecap','Quartermaster Cap','c','case',null,'winter',2),
('skin:gingergren','skin','gingergren','Gingerbread Grenadier','e','case',null,'winter',2),
('hat:icinghelm','hat','icinghelm','Icing Helmet','c','case',null,'winter',2),
('skin:nutcracker','skin','nutcracker','Nutcracker Vanguard','l','unlock','{"boss_rime":100}',null,2),
('hat:shako','hat','shako','Parade Shako','l','case',null,'winter',2),
('skin:rimewarden','skin','rimewarden','Rimebound Warden','g','unlock','{"boss_rime":250}',null,2),
('hat:rimecrest','hat','rimecrest','Rime Crest','l','case',null,'winter',2),
('skin:aurorasovereign','skin','aurorasovereign','Aurora Sovereign','g','unlock','{"map_frost":2500}',null,2),
('hat:aurorahalo','hat','aurorahalo','Aurora Halo','g','case',null,'winter',2),
('trail:snowstreak','trail','snowstreak','Snowstreak','r','case',null,'winter',2),
('trail:glaciershard','trail','glaciershard','Glacier Shard','r','case',null,'winter',2),
('trail:candyline','trail','candyline','Candyline','e','case',null,'winter',2),
('trail:polarspark','trail','polarspark','Polar Spark','l','case',null,'winter',2),
('trail:auroralance','trail','auroralance','Aurora Lance','g','case',null,'winter',2),
('trail:solsticecomet','trail','solsticecomet','Solstice Comet','g','case',null,'winter',2),
('fx:snowpuff','fx','snowpuff','Snow Puff','r','case',null,'winter',2),
('fx:frostfracture','fx','frostfracture','Frost Fracture','r','case',null,'winter',2),
('fx:ornamentpop','fx','ornamentpop','Ornament Pop','e','case',null,'winter',2),
('fx:winterbloom','fx','winterbloom','Winter Bloom','l','case',null,'winter',2),
('fx:borealiscollapse','fx','borealiscollapse','Borealis Collapse','g','case',null,'winter',2),
('fx:solsticenova','fx','solsticenova','Solstice Supernova','g','case',null,'winter',2),
('bg:summitcommand','bg','summitcommand','Summit Command','c','case',null,'winter',2),
('bg:frozenriver','bg','frozenriver','Frozen River Crossing','r','case',null,'winter',2),
('bg:snowquarry','bg','snowquarry','Snowed-In Quarry','r','case',null,'winter',2),
('bg:skistation','bg','skistation','Abandoned Ski Station','e','case',null,'winter',2),
('bg:winterdepot','bg','winterdepot','Winter Supply Depot','c','case',null,'winter',2),
('bg:lanternoutpost','bg','lanternoutpost','Lanternlit Outpost','e','case',null,'winter',2),
('bg:aurorafrostpeak','bg','aurorafrostpeak','Aurora Over Frostpeak','l','case',null,'winter',2),
('bg:whiteouttower','bg','whiteouttower','Whiteout Watchtower','e','case',null,'winter',2),
('bg:yulehangar','bg','yulehangar','Yuletide Hangar','l','case',null,'winter',2),
('bg:midnightevac','bg','midnightevac','Midnight Evacuation','g','case',null,'winter',2)
on conflict(id) do update set name=excluded.name,rarity=excluded.rarity,src=excluded.src,need=excluded.need,box=excluded.box,catalog_version=excluded.catalog_version;

-- Catalog descriptions are metadata; existing IDs, ownership and packet indices stay stable.
alter table public.cosmetics add column if not exists description text;
update public.cosmetics c set description=d.description from (values
 ('skin:snowline','White insulated scout jacket, wrapped boots and climbing straps.'),
 ('hat:snowgoggles','Amber snow lenses in a compact insulated frame.'),
 ('skin:summitranger','Deep green mountain kit, rope harness and reinforced shoulders.'),
 ('hat:ushanka','Fur-lined field cap with folded winter ear flaps.'),
 ('skin:glacierengineer','Blue-gray utility suit, repair tools and frost-marked plates.'),
 ('hat:surveyhelm','Angular survey helmet with a bright expedition lamp.'),
 ('skin:polarrescue','Rescue-orange parka, reflective trim and medical packs.'),
 ('hat:rescuehood','Structured orange storm hood with a pale insulated face opening.'),
 ('skin:evergreen','Layered green armor with pine details and bark-toned straps.'),
 ('hat:pinecrown','A branching evergreen crown with restrained pine accents.'),
 ('skin:yuletideqm','Burgundy supply coat with brass hardware and field pouches.'),
 ('hat:yulecap','Fitted burgundy seasonal cap with a pale winter cuff.'),
 ('skin:gingergren','Biscuit-toned combat plates with inset icing seams and candy accents.'),
 ('hat:icinghelm','Shaped biscuit helmet edged in pale icing.'),
 ('skin:nutcracker','Red and navy parade armor with sculpted plates and brass fasteners.'),
 ('hat:shako','Tall red military shako with brass parade trim.'),
 ('skin:rimewarden','Angular expedition armor with fractured ice plates and luminous frost edges.'),
 ('hat:rimecrest','A jagged translucent ice crest on an expedition helmet.'),
 ('skin:aurorasovereign','Premium polar armor with aurora trim and a luminous chest crest.'),
 ('hat:aurorahalo','A segmented aurora halo with gentle motion; still with reduced motion.'),
 ('trail:snowstreak','Fine white rounds with sparse snowflake motes.'),
 ('trail:glaciershard','Translucent blue ice fragments along a short trail.'),
 ('trail:candyline','A restrained red-and-white candy spiral.'),
 ('trail:polarspark','Cool sparks with a crystalline tail.'),
 ('trail:auroralance','Layered mint and violet aurora ribbon with an icy core.'),
 ('trail:solsticecomet','Warm gold core, winter-star accents and a crisp frost wake.'),
 ('fx:snowpuff','A compact snow burst that fades quickly.'),
 ('fx:frostfracture','Small ice crystals break into readable blue shards.'),
 ('fx:ornamentpop','A brief seasonal ornament burst with restrained fragments.'),
 ('fx:winterbloom','An expanding snowflake and a ring of frost petals.'),
 ('fx:borealiscollapse','Aurora orbits collapse into a crystalline ring.'),
 ('fx:solsticenova','A gold-white winter starburst, ice halo and trailing snow stars.'),
 ('bg:summitcommand','A snowy summit outpost above three mountain ridges.'),
 ('bg:frozenriver','An icy supply crossing with branching river cracks.'),
 ('bg:snowquarry','Snow-covered quarry terraces and an abandoned crane.'),
 ('bg:skistation','A deserted cable lift suspended above snowy pines.'),
 ('bg:winterdepot','Expedition supply crates beside a sheltered mountain depot.'),
 ('bg:lanternoutpost','A warm lanternlit outpost in the winter dusk.'),
 ('bg:aurorafrostpeak','Aurora ribbons and sparse drifting snow over Frostpeak.'),
 ('bg:whiteouttower','Wind-driven snow and a slow watchtower beacon.'),
 ('bg:yulehangar','Warm seasonal hangar lights and gentle steam.'),
 ('bg:midnightevac','A midnight landing pad, sweeping searchlights and a distant helicopter.')
) d(id,description) where c.id=d.id;

-- SOURCE: 20261001081316_friend_lobby_invites.sql
-- v0.9.6.0 authenticated private/public room records and in-app friend invitations.
create table if not exists private.room_sessions(
 host_id uuid primary key references public.profiles(id) on delete cascade,
 incarnation uuid not null,code text not null check(code ~ '^[A-Z0-9]{4}$'),proto text not null check(length(proto)<=16),
 mode text not null check(mode in ('coop','base','ffa')),length text,map text,chapter integer not null default 0 check(chapter between 0 and 3),
 players integer not null check(players between 1 and 6),locked boolean not null,updated_at timestamptz not null default now());
create table if not exists private.lobby_invites(
 id uuid primary key default gen_random_uuid(),from_id uuid not null references public.profiles(id) on delete cascade,
 to_id uuid not null references public.profiles(id) on delete cascade,incarnation uuid not null,code text not null,
 status text not null default 'pending' check(status in ('pending','accepted','declined')),
 created_at timestamptz not null default now(),expires_at timestamptz not null default now()+interval '5 minutes');
create index if not exists lobby_invites_recipient on private.lobby_invites(to_id,expires_at desc);
create index if not exists lobby_invites_sender on private.lobby_invites(from_id,created_at desc);
alter table private.room_sessions enable row level security;
alter table private.lobby_invites enable row level security;
revoke all on private.room_sessions,private.lobby_invites from public,anon,authenticated;

create or replace function public.room_register(p jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
declare uid uuid:=private.require_user();inc uuid:=(p->>'incarnation')::uuid;r private.room_sessions;
begin
 if coalesce((auth.jwt()->>'is_anonymous')::boolean,false) then raise exception 'Use a saved account for friend invitations';end if;
 perform pg_advisory_xact_lock(hashtextextended(uid::text,0));
 if p->>'close'='true' then delete from private.room_sessions where host_id=uid and incarnation=inc;return '{"closed":true}'::jsonb;end if;
 if inc is null or coalesce(p->>'proto','')<>'yard-21' or coalesce(p->>'code','')!~'^[A-Z0-9]{4}$' or coalesce(p->>'mode','') not in ('coop','base','ffa')
    or coalesce(p->>'map','') not in ('yard','river','quarry','frost') or coalesce(p->>'length','') not in ('5','10','endless','blitz','campaign') then raise exception 'Invalid room registration';end if;
 insert into private.room_sessions(host_id,incarnation,code,proto,mode,length,map,chapter,players,locked)
 values(uid,inc,p->>'code',p->>'proto',p->>'mode',p->>'length',p->>'map',coalesce((p->>'chapter')::int,0),(p->>'players')::int,coalesce((p->>'locked')::boolean,false))
 on conflict(host_id) do update set incarnation=excluded.incarnation,code=excluded.code,proto=excluded.proto,mode=excluded.mode,length=excluded.length,map=excluded.map,chapter=excluded.chapter,players=excluded.players,locked=excluded.locked,updated_at=now();
 return '{"registered":true}'::jsonb;
end $$;

create or replace function public.lobby_invite_send(p_to uuid) returns jsonb language plpgsql security definer set search_path='' as $$
declare uid uuid:=private.require_user();r private.room_sessions;i private.lobby_invites;
begin
 if coalesce((auth.jwt()->>'is_anonymous')::boolean,false) then raise exception 'Use a saved account for friend invitations';end if;
 perform pg_advisory_xact_lock(hashtextextended(uid::text,0));
 delete from private.lobby_invites where from_id=uid and created_at<now()-interval '31 days';
 if not exists(select 1 from public.friendships where user_a=least(uid,p_to) and user_b=greatest(uid,p_to))
    or exists(select 1 from public.profiles where id=p_to and banned) then raise exception 'Invite an accepted friend';end if;
 select * into r from private.room_sessions where host_id=uid and updated_at>now()-interval '45 seconds';
 if not found then raise exception 'Create or refresh your room first';end if;
 if r.locked then raise exception 'Unlock your room before inviting';end if;
 if r.players>=6 then raise exception 'Your room is full';end if;
 select * into i from private.lobby_invites where from_id=uid and to_id=p_to and incarnation=r.incarnation and status='pending' and expires_at>now() order by created_at desc limit 1;
 if found then return jsonb_build_object('id',i.id,'duplicate',true,'expires_at',i.expires_at);end if;
 if (select count(*) from private.lobby_invites where from_id=uid and created_at>now()-interval '1 minute')>=10
    or (select count(*) from private.lobby_invites where from_id=uid and created_at>now()-interval '1 hour')>=30 then raise exception 'Invitation limit reached. Try later';end if;
 insert into private.lobby_invites(from_id,to_id,incarnation,code) values(uid,p_to,r.incarnation,r.code) returning * into i;
 insert into public.notifications(user_id,from_id,kind,data) values(p_to,uid,'system',jsonb_build_object('text','Lobby invitation','invite_id',i.id));
 return jsonb_build_object('id',i.id,'expires_at',i.expires_at);
end $$;

create or replace function public.lobby_invite_answer(p_id uuid,p_accept boolean,p_proto text) returns jsonb language plpgsql security definer set search_path='' as $$
declare uid uuid:=private.require_user();i private.lobby_invites;r private.room_sessions;
begin
 if coalesce((auth.jwt()->>'is_anonymous')::boolean,false) then raise exception 'Use a saved account for friend invitations';end if;
 select * into i from private.lobby_invites where id=p_id and to_id=uid for update;
 if not found then raise exception 'Invitation not found';end if;
 if not p_accept then
   if i.status<>'accepted' then update private.lobby_invites set status='declined' where id=p_id;end if;
   return jsonb_build_object('status',case when i.status='accepted' then 'accepted' else 'declined' end);
 end if;
 if i.status='declined' then raise exception 'Invitation was declined';end if;
 if i.expires_at<=now() then raise exception 'Invitation expired';end if;
 if not exists(select 1 from public.friendships where user_a=least(uid,i.from_id) and user_b=greatest(uid,i.from_id)) then raise exception 'Friendship no longer active';end if;
 select * into r from private.room_sessions where host_id=i.from_id and incarnation=i.incarnation and code=i.code and updated_at>now()-interval '45 seconds';
 if not found then raise exception 'That room has closed or changed';end if;
 if r.proto<>p_proto then raise exception 'Different game version. Reload before joining';end if;
 if r.locked then raise exception 'Room is locked';end if;
 if r.players>=6 then raise exception 'Room is full';end if;
 if exists(select 1 from public.profiles where id=i.from_id and banned) then raise exception 'Host unavailable';end if;
 update private.lobby_invites set status='accepted' where id=p_id;
 return jsonb_build_object('status','accepted','code',r.code,'incarnation',r.incarnation,'mode',r.mode,'length',r.length,'map',r.map,'chapter',r.chapter,'slots',6-r.players);
end $$;

revoke all on function public.room_register(jsonb),public.lobby_invite_send(uuid),public.lobby_invite_answer(uuid,boolean,text) from public,anon;
grant execute on function public.room_register(jsonb),public.lobby_invite_send(uuid),public.lobby_invite_answer(uuid,boolean,text) to authenticated;
CREATE OR REPLACE FUNCTION public.social_state()
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare uid uuid := private.require_user();
begin
  return jsonb_build_object(
    'friends', coalesce((select jsonb_agg(jsonb_build_object('id', p.id, 'username', p.username, 'cos', p.cos, 'since', f.created_at) order by lower(p.username::text))
        from public.friendships f join public.profiles p on p.id = case when f.user_a = uid then f.user_b else f.user_a end
        where uid in (f.user_a, f.user_b) and not p.banned), '[]'::jsonb),
    'incoming', coalesce((select jsonb_agg(jsonb_build_object('id', r.id, 'user', jsonb_build_object('id', p.id, 'username', p.username, 'cos', p.cos), 'at', r.created_at) order by r.created_at desc)
        from public.friend_requests r join public.profiles p on p.id = r.from_id
        where r.to_id = uid and r.status = 'pending' and not p.banned), '[]'::jsonb),
    'outgoing', coalesce((select jsonb_agg(jsonb_build_object('id', r.id, 'user', jsonb_build_object('id', p.id, 'username', p.username, 'cos', p.cos), 'at', r.created_at) order by r.created_at desc)
        from public.friend_requests r join public.profiles p on p.id = r.to_id
        where r.from_id = uid and r.status = 'pending'), '[]'::jsonb),
    'notes', coalesce((select jsonb_agg(x order by x.created_at desc) from (
        select n.id, n.kind, n.data, n.created_at, n.seen_at, jsonb_build_object('id', p.id, 'username', p.username) as "user"
        from public.notifications n left join public.profiles p on p.id = n.from_id
        where n.user_id = uid order by n.created_at desc limit 40) x), '[]'::jsonb),
    'unseen', (select count(*) from public.notifications n where n.user_id = uid and n.seen_at is null),
    'invites',coalesce((select jsonb_agg(jsonb_build_object('id',i.id,'created_at',i.created_at,'expires_at',i.expires_at,'user',jsonb_build_object('id',p.id,'username',p.username,'cos',p.cos),'room',jsonb_build_object('code',i.code,'length',r.length,'mode',r.mode,'map',r.map,'chapter',r.chapter,'players',r.players,'locked',r.locked)) order by i.created_at desc) from private.lobby_invites i join public.profiles p on p.id=i.from_id left join private.room_sessions r on r.host_id=i.from_id and r.incarnation=i.incarnation where i.to_id=uid and i.status='pending' and i.expires_at>now() and not p.banned),'[]'::jsonb),
    'is_anonymous', coalesce((auth.jwt()->>'is_anonymous')::boolean, false));
end $function$
;
revoke all on function public.social_state() from public,anon;
grant execute on function public.social_state() to authenticated;

-- SOURCE: 20261001214620_winter_models.sql
-- v0.9.6.1: append distinct Winter Case models. Old clients retain catalog cap 2.
insert into public.cosmetics(id,cat,key,name,rarity,src,need,box,catalog_version) values
 ('skin:yulemaw','skin','yulemaw','Yulemaw','e','case',null,'winter',3),
 ('skin:rednosedemolisher','skin','rednosedemolisher','Rednose Demolisher','l','case',null,'winter',3),
 ('skin:gildedfrostborn','skin','gildedfrostborn','Gilded Frostborn','g','case',null,'winter',3)
on conflict(id) do update set name=excluded.name,rarity=excluded.rarity,src=excluded.src,need=excluded.need,box=excluded.box,catalog_version=excluded.catalog_version;
create or replace function public.open_case_v0961(p_case text,p_rev integer default null)
returns jsonb language sql security invoker set search_path='' as $$
 select private.open_case_catalog(p_case,p_rev,3);
$$;
revoke all on function public.open_case_v0961(text,integer) from public,anon;
grant execute on function public.open_case_v0961(text,integer) to authenticated;

CREATE OR REPLACE FUNCTION private.open_case_catalog(p_case text, p_rev integer, p_catalog integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare uid uuid := private.require_user(); l public.lockers; ct public.case_types; it public.cosmetics;
 want text; have int; dup boolean; weights jsonb;
begin
 if p_catalog is null or p_catalog not in (0,1,2,3) then raise exception 'Unknown cosmetic catalog' using errcode='22023'; end if;
 select * into ct from public.case_types where id=p_case;
 if not found then raise exception 'Unknown case' using errcode='22023'; end if;
 select * into l from public.lockers where user_id=uid for update;
 if not found then raise exception 'Locker not found' using errcode='22023'; end if;
 perform private.check_rev(l,p_rev);
 have := case when p_case='supply' then l.cases else coalesce((l.bag->>p_case)::int,0) end;
 if have<1 then raise exception 'No % to open',lower(ct.name)||'s' using errcode='22023'; end if;
 weights := case when p_catalog=0 and p_case='supply' then '{"c":60,"r":27,"e":10,"l":3}'::jsonb else ct.weights end;
 want := private.roll_rarity(weights);
 select * into it from public.cosmetics c where c.box=p_case and c.rarity=want and c.catalog_version<=p_catalog order by random() limit 1;
 if not found then select * into it from public.cosmetics c where c.box=p_case and c.catalog_version<=p_catalog order by c.rarity='c' desc,random() limit 1; end if;
 if not found then raise exception 'Case catalog is empty' using errcode='22023'; end if;
 dup := it.id=any(l.owned);
 update public.lockers set
  cases=case when p_case='supply' then cases-1 else cases end,
  bag=case when p_case='supply' then bag else private.bag_add(bag,p_case,-1) end,
  shards=shards+case when dup then private.shard_value(it.rarity) else 0 end,
  owned=case when dup then owned else owned||it.id end,
  rev=rev+1,updated_at=now()
 where user_id=uid returning * into l;
 return jsonb_build_object('case',p_case,'item',jsonb_build_object('id',it.id,'cat',it.cat,'key',it.key,'name',it.name,'rarity',it.rarity),
  'dup',dup,'locker',private.locker_out(l));
end $function$;

-- SOURCE: 20261001225643_music_case_batches.sql
-- v0.9.6.2: one atomic operation for one or five cases, with durable retry receipts.
create table private.case_openings (
 user_id uuid not null references auth.users(id) on delete cascade,
 operation_id uuid not null,
 case_id text not null references public.case_types(id),
 quantity integer not null check (quantity in (1,5)),
 results jsonb not null,
 created_at timestamptz not null default now(),
 primary key(user_id,operation_id)
);
alter table private.case_openings enable row level security;
revoke all on private.case_openings from public,anon,authenticated;

create or replace function private.open_cases_v0962(p_case text,p_quantity integer,p_operation uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare uid uuid:=private.require_user(); l public.lockers; receipt private.case_openings;
 have integer; result jsonb; awarded jsonb:='[]'::jsonb; i integer;
begin
 if p_operation is null or p_quantity is null or p_quantity not in (1,5) then
  raise exception 'Choose one or five cases and a valid opening ID' using errcode='22023';
 end if;
 select * into l from public.lockers where user_id=uid for update;
 if not found then raise exception 'Locker not found' using errcode='22023'; end if;
 select * into receipt from private.case_openings where user_id=uid and operation_id=p_operation;
 if found then
  if receipt.case_id<>p_case or receipt.quantity<>p_quantity then
   raise exception 'Opening ID already belongs to a different request' using errcode='22023';
  end if;
  return jsonb_build_object('operation',p_operation,'case',p_case,'quantity',p_quantity,'results',receipt.results,'locker',private.locker_out(l),'retry',true);
 end if;
 if not exists(select 1 from public.case_types where id=p_case) then raise exception 'Unknown case' using errcode='22023'; end if;
 have:=case when p_case='supply' then l.cases else coalesce((l.bag->>p_case)::integer,0) end;
 if have<p_quantity then raise exception 'Not enough cases to open %',p_quantity using errcode='22023'; end if;
 -- Each roll sees the ownership updated by the preceding roll in this transaction.
 for i in 1..p_quantity loop
  result:=private.open_case_catalog(p_case,null,3);
  awarded:=awarded||jsonb_build_array(jsonb_build_object('item',result->'item','dup',result->'dup',
   'shards',case when (result->>'dup')::boolean then private.shard_value(result->'item'->>'rarity') else 0 end));
 end loop;
 insert into private.case_openings(user_id,operation_id,case_id,quantity,results) values(uid,p_operation,p_case,p_quantity,awarded);
 select * into l from public.lockers where user_id=uid;
 return jsonb_build_object('operation',p_operation,'case',p_case,'quantity',p_quantity,'results',awarded,'locker',private.locker_out(l),'retry',false);
end $$;
revoke all on function private.open_cases_v0962(text,integer,uuid) from public,anon;
grant execute on function private.open_cases_v0962(text,integer,uuid) to authenticated;
create or replace function public.open_cases_v0962(p_case text,p_quantity integer,p_operation uuid)
returns jsonb language sql security invoker set search_path='' as $$
 select private.open_cases_v0962(p_case,p_quantity,p_operation);
$$;
revoke all on function public.open_cases_v0962(text,integer,uuid) from public,anon;
grant execute on function public.open_cases_v0962(text,integer,uuid) to authenticated;

-- SOURCE: 20261003040401_room_register_any_yard_proto.sql
-- v0.9.6.3: room_register accepted only proto 'yard-21', so every room hosted from v0.9.6.1 on (yard-22) failed to
-- register and friends couldn't be invited to it. Accept any 'yard-N' instead; lobby_invite_answer still refuses a
-- guest whose version differs from the room's ("Different game version"), so mismatched copies still can't meet.
-- Built from the live function text (October 3); only the proto check changed. Privileges are kept by CREATE OR REPLACE.
CREATE OR REPLACE FUNCTION public.room_register(p jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare uid uuid:=private.require_user();inc uuid:=(p->>'incarnation')::uuid;r private.room_sessions;
begin
 if coalesce((auth.jwt()->>'is_anonymous')::boolean,false) then raise exception 'Use a saved account for friend invitations';end if;
 perform pg_advisory_xact_lock(hashtextextended(uid::text,0));
 if p->>'close'='true' then delete from private.room_sessions where host_id=uid and incarnation=inc;return '{"closed":true}'::jsonb;end if;
 if inc is null or coalesce(p->>'proto','')!~'^yard-[0-9]{1,3}$' or coalesce(p->>'code','')!~'^[A-Z0-9]{4}$' or coalesce(p->>'mode','') not in ('coop','base','ffa')
    or coalesce(p->>'map','') not in ('yard','river','quarry','frost') or coalesce(p->>'length','') not in ('5','10','endless','blitz','campaign') then raise exception 'Invalid room registration';end if;
 insert into private.room_sessions(host_id,incarnation,code,proto,mode,length,map,chapter,players,locked)
 values(uid,inc,p->>'code',p->>'proto',p->>'mode',p->>'length',p->>'map',coalesce((p->>'chapter')::int,0),(p->>'players')::int,coalesce((p->>'locked')::boolean,false))
 on conflict(host_id) do update set incarnation=excluded.incarnation,code=excluded.code,proto=excluded.proto,mode=excluded.mode,length=excluded.length,map=excluded.map,chapter=excluded.chapter,players=excluded.players,locked=excluded.locked,updated_at=now();
 return '{"registered":true}'::jsonb;
end $function$;

-- SOURCE: 20261003080938_v0964_hybrid_catalog.sql
-- v0.9.6.4 (part 1 of 2): the Hybrid Theory Case, its 57 items (catalog 4) and the catalog-4 opener. Applied October 3.
insert into public.case_types(id,name,weights,shard_cost,modes,drop,sort) values('hybrid','HYBRID THEORY CASE','{"c":46,"r":30,"e":16,"l":7,"g":1}',12,'{}','{}',7)
on conflict(id) do update set name=excluded.name,weights=excluded.weights,shard_cost=excluded.shard_cost,sort=excluded.sort;

-- Exactly 57 items: 30 jerseys, 8 headgear, 11 kill effects, 8 backgrounds (catalog 4).
insert into public.cosmetics(id,cat,key,name,rarity,src,need,box,catalog_version) values
 ('skin:hb_lizards','skin','hb_lizards','Washington Lizards','c','case',null,'hybrid',4),
 ('skin:hb_placers','skin','hb_placers','Indiana Placers','c','case',null,'hybrid',4),
 ('skin:hb_vets','skin','hb_vets','Brooklyn Vets','c','case',null,'hybrid',4),
 ('skin:hb_rings','skin','hb_rings','Sacramento Rings','c','case',null,'hybrid',4),
 ('skin:hb_jabs','skin','hb_jabs','Utah Jabs','c','case',null,'hybrid',4),
 ('skin:hb_drizzlies','skin','hb_drizzlies','Memphis Drizzlies','c','case',null,'hybrid',4),
 ('skin:hb_saversicks','skin','hb_saversicks','Dallas Saversicks','r','case',null,'hybrid',4),
 ('skin:hb_relicans','skin','hb_relicans','New Orleans Relicans','r','case',null,'hybrid',4),
 ('skin:hb_pulls','skin','hb_pulls','Chicago Pulls','r','case',null,'hybrid',4),
 ('skin:hb_ducks','skin','hb_ducks','Milwaukee Ducks','r','case',null,'hybrid',4),
 ('skin:hb_worriers','skin','hb_worriers','Golden State Worriers','r','case',null,'hybrid',4),
 ('skin:hb_slippers','skin','hb_slippers','Los Angeles Slippers','r','case',null,'hybrid',4),
 ('skin:hb_sailglazers','skin','hb_sailglazers','Portland Sail Glazers','e','case',null,'hybrid',4),
 ('skin:hb_beat','skin','hb_beat','Miami Beat','e','case',null,'hybrid',4),
 ('skin:hb_cornets','skin','hb_cornets','Charlotte Cornets','e','case',null,'hybrid',4),
 ('skin:hb_fixers','skin','hb_fixers','Philadelphia Fixers','e','case',null,'hybrid',4),
 ('skin:hb_static','skin','hb_static','Orlando Static','e','case',null,'hybrid',4),
 ('skin:hb_runs','skin','hb_runs','Phoenix Runs','e','case',null,'hybrid',4),
 ('skin:hb_squawks','skin','hb_squawks','Atlanta Squawks','l','case',null,'hybrid',4),
 ('skin:hb_captors','skin','hb_captors','Toronto Captors','l','case',null,'hybrid',4),
 ('skin:hb_cinderwolves','skin','hb_cinderwolves','Minnesota Cinderwolves','l','case',null,'hybrid',4),
 ('skin:hb_lockets','skin','hb_lockets','Houston Lockets','l','case',null,'hybrid',4),
 ('skin:hb_navaliers','skin','hb_navaliers','Cleveland Navaliers','l','case',null,'hybrid',4),
 ('skin:hb_bricks','skin','hb_bricks','New York Bricks','l','case',null,'hybrid',4),
 ('skin:hb_bakers','skin','hb_bakers','Los Angeles Bakers','g','case',null,'hybrid',4),
 ('skin:hb_budgets','skin','hb_budgets','Denver Budgets','g','case',null,'hybrid',4),
 ('skin:hb_kelpies','skin','hb_kelpies','Boston Kelpies','g','case',null,'hybrid',4),
 ('skin:hb_whistlers','skin','hb_whistlers','Detroit Whistlers','g','case',null,'hybrid',4),
 ('skin:hb_burrs','skin','hb_burrs','San Antonio Burrs','g','case',null,'hybrid',4),
 ('skin:hb_hummers','skin','hb_hummers','Oklahoma City Hummers','g','case',null,'hybrid',4),
 ('hat:shades','hat','shades','Sunglasses','c','case',null,'hybrid',4),
 ('hat:yamaka','hat','yamaka','Yamaka','r','case',null,'hybrid',4),
 ('hat:ballhelm','hat','ballhelm','Ball Helm','r','case',null,'hybrid',4),
 ('hat:gridhelm','hat','gridhelm','Grid Helm','e','case',null,'hybrid',4),
 ('hat:dunce','hat','dunce','Dunce Cone','e','case',null,'hybrid',4),
 ('hat:prop','hat','prop','Prop Hat','c','case',null,'hybrid',4),
 ('hat:conductor','hat','conductor','Conductor Cap','r','case',null,'hybrid',4),
 ('hat:skullhelm','hat','skullhelm','Skull Helm','l','case',null,'hybrid',4),
 ('fx:leaf','fx','leaf','Weed Leaf','r','case',null,'hybrid',4),
 ('fx:bands','fx','bands','Money Explosion','e','case',null,'hybrid',4),
 ('fx:swish','fx','swish','Hoop Swish','l','case',null,'hybrid',4),
 ('fx:nuke','fx','nuke','Nuke Pop','g','case',null,'hybrid',4),
 ('fx:poop','fx','poop','Poop Pop','c','case',null,'hybrid',4),
 ('fx:demon','fx','demon','Purple Demon','e','case',null,'hybrid',4),
 ('fx:hundo','fx','hundo','100 Pop','r','case',null,'hybrid',4),
 ('fx:fire','fx','fire','Fire Pop','r','case',null,'hybrid',4),
 ('fx:eight','fx','eight','8=D Pop','c','case',null,'hybrid',4),
 ('fx:sixty','fx','sixty','67 Pop','c','case',null,'hybrid',4),
 ('fx:zzz','fx','zzz','Bed Nap','c','case',null,'hybrid',4),
 ('bg:yardneon','bg','yardneon','Yard Neon','g','case',null,'hybrid',4),
 ('bg:voltgrid','bg','voltgrid','Volt Grid','g','case',null,'hybrid',4),
 ('bg:viceblock','bg','viceblock','Vice Block','g','case',null,'hybrid',4),
 ('bg:crowncity','bg','crowncity','Crown City','g','case',null,'hybrid',4),
 ('bg:peachwire','bg','peachwire','Peach Wire','l','case',null,'hybrid',4),
 ('bg:lakeblocks','bg','lakeblocks','Lake Blocks','l','case',null,'hybrid',4),
 ('bg:fiestastrip','bg','fiestastrip','Fiesta Strip','l','case',null,'hybrid',4),
 ('bg:oaknight','bg','oaknight','Oak Night','l','case',null,'hybrid',4)
on conflict(id) do update set cat=excluded.cat,key=excluded.key,name=excluded.name,rarity=excluded.rarity,src=excluded.src,need=excluded.need,box=excluded.box,catalog_version=excluded.catalog_version;
update public.cosmetics c set description=d.description from (values
 ('skin:hb_lizards','Washington Lizards: a sleeveless jersey and shorts in their colors, trim on the neck, hem and sides.'),
 ('skin:hb_placers','Indiana Placers: a sleeveless jersey and shorts in their colors, trim on the neck, hem and sides.'),
 ('skin:hb_vets','Brooklyn Vets: a sleeveless jersey and shorts in their colors, trim on the neck, hem and sides.'),
 ('skin:hb_rings','Sacramento Rings: a sleeveless jersey and shorts in their colors, trim on the neck, hem and sides.'),
 ('skin:hb_jabs','Utah Jabs: a sleeveless jersey and shorts in their colors, trim on the neck, hem and sides.'),
 ('skin:hb_drizzlies','Memphis Drizzlies: a sleeveless jersey and shorts in their colors, trim on the neck, hem and sides.'),
 ('skin:hb_saversicks','Dallas Saversicks: a sleeveless jersey and shorts in their colors, trim on the neck, hem and sides.'),
 ('skin:hb_relicans','New Orleans Relicans: a sleeveless jersey and shorts in their colors, trim on the neck, hem and sides.'),
 ('skin:hb_pulls','Chicago Pulls: a sleeveless jersey and shorts in their colors, trim on the neck, hem and sides.'),
 ('skin:hb_ducks','Milwaukee Ducks: a sleeveless jersey and shorts in their colors, trim on the neck, hem and sides.'),
 ('skin:hb_worriers','Golden State Worriers: a sleeveless jersey and shorts in their colors, trim on the neck, hem and sides.'),
 ('skin:hb_slippers','Los Angeles Slippers: a sleeveless jersey and shorts in their colors, trim on the neck, hem and sides.'),
 ('skin:hb_sailglazers','Portland Sail Glazers: a sleeveless jersey and shorts in their colors, trim on the neck, hem and sides.'),
 ('skin:hb_beat','Miami Beat: a sleeveless jersey and shorts in their colors, trim on the neck, hem and sides.'),
 ('skin:hb_cornets','Charlotte Cornets: a sleeveless jersey and shorts in their colors, trim on the neck, hem and sides.'),
 ('skin:hb_fixers','Philadelphia Fixers: a sleeveless jersey and shorts in their colors, trim on the neck, hem and sides.'),
 ('skin:hb_static','Orlando Static: a sleeveless jersey and shorts in their colors, trim on the neck, hem and sides.'),
 ('skin:hb_runs','Phoenix Runs: a sleeveless jersey and shorts in their colors, trim on the neck, hem and sides.'),
 ('skin:hb_squawks','Atlanta Squawks: a sleeveless jersey and shorts in their colors, trim on the neck, hem and sides.'),
 ('skin:hb_captors','Toronto Captors: a sleeveless jersey and shorts in their colors, trim on the neck, hem and sides.'),
 ('skin:hb_cinderwolves','Minnesota Cinderwolves: a sleeveless jersey and shorts in their colors, trim on the neck, hem and sides.'),
 ('skin:hb_lockets','Houston Lockets: a sleeveless jersey and shorts in their colors, trim on the neck, hem and sides.'),
 ('skin:hb_navaliers','Cleveland Navaliers: a sleeveless jersey and shorts in their colors, trim on the neck, hem and sides.'),
 ('skin:hb_bricks','New York Bricks: a sleeveless jersey and shorts in their colors, trim on the neck, hem and sides.'),
 ('skin:hb_bakers','Los Angeles Bakers: a sleeveless jersey and shorts in their colors, trim on the neck, hem and sides.'),
 ('skin:hb_budgets','Denver Budgets: a sleeveless jersey and shorts in their colors, trim on the neck, hem and sides.'),
 ('skin:hb_kelpies','Boston Kelpies: a sleeveless jersey and shorts in their colors, trim on the neck, hem and sides.'),
 ('skin:hb_whistlers','Detroit Whistlers: a sleeveless jersey and shorts in their colors, trim on the neck, hem and sides.'),
 ('skin:hb_burrs','San Antonio Burrs: a sleeveless jersey and shorts in their colors, trim on the neck, hem and sides.'),
 ('skin:hb_hummers','Oklahoma City Hummers: a sleeveless jersey and shorts in their colors, trim on the neck, hem and sides.'),
 ('hat:shades','Square black shades with a white glint.'),
 ('hat:yamaka','A small plain black cap on the crown.'),
 ('hat:ballhelm','An orange ball-pattern helmet with black seams.'),
 ('hat:gridhelm','A navy grid helmet with a gray facemask.'),
 ('hat:dunce','A tall cream dunce cone with a red band.'),
 ('hat:prop','A beanie with a little propeller on top.'),
 ('hat:conductor','A navy conductor cap with a gold band and brim.'),
 ('hat:skullhelm','A bone-white skull helmet with dark sockets.'),
 ('fx:leaf','Green and lime leaves burst, drift and fade.'),
 ('fx:bands','Bills and coins pop and flutter down.'),
 ('fx:swish','An orange rim and white net; the ball drops through.'),
 ('fx:nuke','A white flash, an orange mushroom and a gray ring.'),
 ('fx:poop','A brown swirl and stink puffs.'),
 ('fx:demon','Purple horns and eyes over a small flame ring.'),
 ('fx:hundo','White 100 stamps scale up and scatter.'),
 ('fx:fire','Orange-yellow flame tongues, then embers.'),
 ('fx:eight','A flat peach comic shape, then a white flash.'),
 ('fx:sixty','Block numerals 6 and 7 in white and volt, then they crack.'),
 ('fx:zzz','A flat bed, three Zs rise, a soft blue fade.'),
 ('bg:yardneon','Block towers on navy with slow gold neon streaks.'),
 ('bg:voltgrid','A black skyline with volt and red grid streaks.'),
 ('bg:viceblock','Black blocks under pink and cyan neon.'),
 ('bg:crowncity','Purple towers crowned in gold light.'),
 ('bg:peachwire','Peach wires strung between cream-lit blocks.'),
 ('bg:lakeblocks','Midnight blocks under a green aurora.'),
 ('bg:fiestastrip','A pink and teal neon strip at night.'),
 ('bg:oaknight','Cream and brown towers with gold windows.')
) d(id,description) where c.id=d.id;

CREATE OR REPLACE FUNCTION private.open_case_catalog(p_case text, p_rev integer, p_catalog integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare uid uuid := private.require_user(); l public.lockers; ct public.case_types; it public.cosmetics;
 want text; have int; dup boolean; weights jsonb;
begin
 if p_catalog is null or p_catalog not in (0,1,2,3,4) then raise exception 'Unknown cosmetic catalog' using errcode='22023'; end if;
 select * into ct from public.case_types where id=p_case;
 if not found then raise exception 'Unknown case' using errcode='22023'; end if;
 select * into l from public.lockers where user_id=uid for update;
 if not found then raise exception 'Locker not found' using errcode='22023'; end if;
 perform private.check_rev(l,p_rev);
 have := case when p_case='supply' then l.cases else coalesce((l.bag->>p_case)::int,0) end;
 if have<1 then raise exception 'No % to open',lower(ct.name)||'s' using errcode='22023'; end if;
 weights := case when p_catalog=0 and p_case='supply' then '{"c":60,"r":27,"e":10,"l":3}'::jsonb else ct.weights end;
 want := private.roll_rarity(weights);
 select * into it from public.cosmetics c where c.box=p_case and c.rarity=want and c.catalog_version<=p_catalog order by random() limit 1;
 if not found then select * into it from public.cosmetics c where c.box=p_case and c.catalog_version<=p_catalog order by c.rarity='c' desc,random() limit 1; end if;
 if not found then raise exception 'Case catalog is empty' using errcode='22023'; end if;
 dup := it.id=any(l.owned);
 update public.lockers set
  cases=case when p_case='supply' then cases-1 else cases end,
  bag=case when p_case='supply' then bag else private.bag_add(bag,p_case,-1) end,
  shards=shards+case when dup then private.shard_value(it.rarity) else 0 end,
  owned=case when dup then owned else owned||it.id end,
  rev=rev+1,updated_at=now()
 where user_id=uid returning * into l;
 return jsonb_build_object('case',p_case,'item',jsonb_build_object('id',it.id,'cat',it.cat,'key',it.key,'name',it.name,'rarity',it.rarity),
  'dup',dup,'locker',private.locker_out(l));
end $function$;

create or replace function private.open_cases_v0964(p_case text,p_quantity integer,p_operation uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare uid uuid:=private.require_user(); l public.lockers; receipt private.case_openings;
 have integer; result jsonb; awarded jsonb:='[]'::jsonb; i integer;
begin
 if p_operation is null or p_quantity is null or p_quantity not in (1,5) then
  raise exception 'Choose one or five cases and a valid opening ID' using errcode='22023';
 end if;
 select * into l from public.lockers where user_id=uid for update;
 if not found then raise exception 'Locker not found' using errcode='22023'; end if;
 select * into receipt from private.case_openings where user_id=uid and operation_id=p_operation;
 if found then
  if receipt.case_id<>p_case or receipt.quantity<>p_quantity then
   raise exception 'Opening ID already belongs to a different request' using errcode='22023';
  end if;
  return jsonb_build_object('operation',p_operation,'case',p_case,'quantity',p_quantity,'results',receipt.results,'locker',private.locker_out(l),'retry',true);
 end if;
 if not exists(select 1 from public.case_types where id=p_case) then raise exception 'Unknown case' using errcode='22023'; end if;
 have:=case when p_case='supply' then l.cases else coalesce((l.bag->>p_case)::integer,0) end;
 if have<p_quantity then raise exception 'Not enough cases to open %',p_quantity using errcode='22023'; end if;
 -- Each roll sees the ownership updated by the preceding roll in this transaction.
 for i in 1..p_quantity loop
  result:=private.open_case_catalog(p_case,null,4);
  awarded:=awarded||jsonb_build_array(jsonb_build_object('item',result->'item','dup',result->'dup',
   'shards',case when (result->>'dup')::boolean then private.shard_value(result->'item'->>'rarity') else 0 end));
 end loop;
 insert into private.case_openings(user_id,operation_id,case_id,quantity,results) values(uid,p_operation,p_case,p_quantity,awarded);
 select * into l from public.lockers where user_id=uid;
 return jsonb_build_object('operation',p_operation,'case',p_case,'quantity',p_quantity,'results',awarded,'locker',private.locker_out(l),'retry',false);
end $$;
revoke all on function private.open_cases_v0964(text,integer,uuid) from public,anon;
grant execute on function private.open_cases_v0964(text,integer,uuid) to authenticated;
create or replace function public.open_cases_v0964(p_case text,p_quantity integer,p_operation uuid)
returns jsonb language sql security invoker set search_path='' as $$
 select private.open_cases_v0964(p_case,p_quantity,p_operation);
$$;
revoke all on function public.open_cases_v0964(text,integer,uuid) from public,anon;
grant execute on function public.open_cases_v0964(text,integer,uuid) to authenticated;

-- SOURCE: 20261003153435_v0964_gauntlet_rewards.sql
-- v0.9.6.4 (part 2 of 2): claim_match_reward rebuilt from the live text (20261001081259_winter_whiteout.sql). The Whiteout
-- Gauntlet payouts, chapter evacs and the Hybrid Theory drop apply only to cv:4 claims, so older clients are paid as before.
-- The 31-day receipt cleanup line was removed (Big U, October 3): the Supabase connector holds any statement containing a
-- delete for a confirmation this session could not answer. Old receipts now stay; prune them by hand if the table grows.
-- Applied by staging this exact text (md5 89a994bedbaa2beb423e60c1c9f85121) and executing it in one migration.
CREATE OR REPLACE FUNCTION public.claim_match_reward(p jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare uid uuid := private.require_user(); l public.lockers; ct public.case_types; cb public.case_types;
  v_kind text := p->>'kind'; v_mode text := coalesce(p->>'mode', '5'); v_pvp text := coalesce(p->>'pvp', '');
  v_diff text := coalesce(p->>'diff', 'normal'); v_win boolean := coalesce(p->>'win' = 'true', false);
  v_held int; v_kills int := greatest(coalesce(private.num(p->>'kills'), 0), 0)::int;
  v_dur int := coalesce(private.num(p->>'duration_s'), 0)::int; v_boss int := least(greatest(coalesce(private.num(p->>'bosses'), 0), 0), 100)::int;
  waves int := 0; v_st jsonb; v_prog int; earned int := 0; granted int; got text[]; v_case text := 'supply'; chance float8; v_bonus int := 0;
  v_budget float8;
  v_sal int := least(greatest(coalesce(private.num(p->>'salvage'), 0), 0), 1000000)::int; v_shards int := 0;
  v_keys jsonb := p->'boss_keys'; v_key text; v_cap int; v_n int := 0; v_hal int := 0; v_glow int := 0;
  v_xl boolean := coalesce(p->>'size', 'std') = 'xl'; v_before text[]; v_new text[];
  v_oct boolean := (now() at time zone 'UTC') >= make_timestamp(extract(year from now())::int, 9, 30, 10, 0, 0)
               and (now() at time zone 'UTC') <  make_timestamp(extract(year from now())::int, 11, 1, 14, 0, 0);
  v_gid text := nullif(left(coalesce(p->>'game_id', ''), 40), '');
  v_to int := greatest(coalesce(private.num(p->>'raid_to'), private.num(p->>'held'), 0), 0)::int;
  v_from int := greatest(coalesce(private.num(p->>'raid_from'), 0), 0)::int;
  v_prev int; v_first int; v_join int; v_blo int; v_bhi int; v_seen boolean := false;
  v_pbn int := 0; v_psb int := 0;
  v_mods text[]; v_pct int := 0; v_credit int := 0; v_scap int;
  v_sbreq int := least(greatest(coalesce(private.num(p->>'shard_bosses'), 0), 0), 100)::int; v_sb int := 0; v_sbcap int := 0; v_sbshards int := 0;
  v_sp int := 0; v_spprog int; r int;
  v_map text := left(regexp_replace(coalesce(p->>'map', ''), '[^a-z]', '', 'g'), 12);
  v_cls text := left(regexp_replace(coalesce(p->>'cls', ''), '[^a-z]', '', 'g'), 16);
  v_bk text; cf public.case_types; v_flag int := 0;
  -- v0.9.4.0 Blitzkrieg Rush
  v_blitz boolean := coalesce(p->>'mode', '') in ('blitz','campaign') and p->>'kind' = 'run'; v_evac text := coalesce(p->>'evac', ''); v_left boolean := false;
  v_paid_keys text[]:='{}';
  v_campaign boolean := coalesce(p->>'mode','')='campaign'; v_winter int := 0; v_receipt text; v_cached jsonb; v_response jsonb;
  v_blz int := 0; v_fbn int := 0; v_fbcap int := 0; v_pfb int := 0; v_every int := 30; v_fbshards int := 0; v_mk text;
  -- v0.9.6.4: Whiteout Gauntlet payouts, chapter evacs and the Hybrid Theory drop apply only to cv:4 claims
  v_cv int := least(greatest(coalesce(private.num(p->>'cv'), 0), 0), 99)::int; v_g4 boolean; v_gw int := 0; v_chev int := 0; v_hyb int := 0; v_ce jsonb := p->'ch_evac';
begin
  v_g4 := v_campaign and v_cv >= 4;
  if v_kind is null or v_kind not in ('run', 'match') then raise exception 'Unknown result' using errcode = '22023'; end if;
  if v_dur < 20 or v_dur > 21600 or (v_kind = 'match' and v_dur < 30) then raise exception 'That match length doesn''t add up' using errcode = '22023'; end if;
  if v_kills > v_dur then raise exception 'That kill count doesn''t add up' using errcode = '22023'; end if;
  select * into l from public.lockers where user_id = uid for update;
  v_receipt := md5(coalesce(p->>'claim_id',p::text));
  select response into v_cached from private.reward_receipts where user_id=uid and claim_key=v_receipt;
  if found then return v_cached || jsonb_build_object('locker',private.locker_out(l),'retry',true); end if;
  if exists (select 1 from public.match_results m where m.user_id = uid and m.created_at > now() - interval '20 seconds') then
    raise exception 'Rewards were claimed a moment ago' using errcode = '22023';
  end if;
  v_budget := least(22200, l.play_budget + extract(epoch from now() - l.budget_at));
  if v_dur > v_budget + 60 then
    raise exception 'More play time than real time so far; this result will be saved later' using errcode = '22023';
  end if;
  v_mk := case when v_blitz and not v_campaign then 'blitz' else v_pvp end;   -- v0.9.4.0: Blitzkrieg Rush has its own modifier list
  v_mods := private.clean_mods(p->'mods', v_mk);
  if v_campaign then v_mods:=array(select m from unnest(v_mods) m where m not in ('bossrush','nightmare','blitzclock','hotlz','lockdown','scorched','barrage','onejob')); end if;
  select coalesce(sum(private.mod_bonus(m, v_mk)), 0) into v_pct from unnest(v_mods) m;
  v_pct := least(greatest(v_pct, -15), 75);
  if v_gid is not null then
    select max(m.raid_to), min(m.raid_from), count(*) > 0, coalesce(sum(coalesce(m.boss_n, m.bonus)), 0), coalesce(sum(m.shard_bosses), 0), coalesce(sum(m.fb_n), 0)
      into v_prev, v_first, v_seen, v_pbn, v_psb, v_pfb from public.match_results m where m.user_id = uid and m.game_id = v_gid;
  end if;
  v_st := l.st; v_prog := l.prog; v_spprog := l.sp_prog;
  if v_kind = 'run' then
    if v_mode not in ('5', '10', 'endless', 'blitz','campaign') or v_diff not in ('easy', 'normal', 'hard') then raise exception 'Unknown mode' using errcode = '22023'; end if;
    waves := case v_mode when '5' then 5 when '10' then 10 when 'blitz' then 15 when 'campaign' then 13 else 0 end;
    if waves > 0 and v_to > waves then raise exception 'That raid count doesn''t add up' using errcode = '22023'; end if;
    v_from := least(v_from, v_to); v_join := least(v_from, coalesce(v_first, v_from));
    if v_prev is not null then v_from := greatest(v_from, least(v_prev, v_to)); end if;
    v_held := v_to - v_from;
    if v_dur + 20 < 8 * v_held + (v_held * v_held) / 4 then raise exception 'That raid count doesn''t add up' using errcode = '22023'; end if;
    -- v0.9.4.0: Blitzkrieg Rush. Once raid 15's evacuation is open each player reports their own result: 'evac' (made it
    -- out: the win) or 'left' (left behind: half their cases and shards, odd counts rounded up first).
    if not v_blitz or v_to < waves or v_evac not in ('evac', 'left') then v_evac := ''; end if;
    v_left := v_evac = 'left';
    if v_blitz and v_evac <> 'evac' then v_win := false; end if;
    if waves = 0 or v_to <> waves or v_join * 2 > waves or (v_seen and v_prev >= waves) then v_win := false; end if;
    v_st := jsonb_set(v_st, '{raids}', to_jsonb(coalesce((v_st->>'raids')::int, 0) + v_held));
    v_st := jsonb_set(v_st, '{drops}', to_jsonb(coalesce((v_st->>'drops')::int, 0) + v_kills));
    if v_win then
      v_st := jsonb_set(v_st, '{wins}', to_jsonb(coalesce((v_st->>'wins')::int, 0) + 1));
      if v_diff = 'hard' then v_st := jsonb_set(v_st, '{hardWins}', to_jsonb(coalesce((v_st->>'hardWins')::int, 0) + 1)); end if;
    end if;
    if waves = 0 then v_st := jsonb_set(v_st, '{endless}', to_jsonb(greatest(coalesce((v_st->>'endless')::int, 0), v_to))); end if;
    if v_campaign and v_held>0 then
      for r in (v_from+1)..v_to loop
        v_bk:=case when r<=3 then 'yard' when r<=6 then 'river' when r<=9 then 'quarry' else 'frost' end;
        v_st:=jsonb_set(v_st,array['map_'||v_bk],to_jsonb(coalesce((v_st->>('map_'||v_bk))::int,0)+1));
      end loop;
    elsif v_held > 0 and v_map in ('yard', 'river', 'quarry','frost') then
      v_st := jsonb_set(v_st, array['map_' || v_map], to_jsonb(coalesce((v_st->>('map_' || v_map))::int, 0) + v_held));
    end if;
    if v_held > 0 and v_cls in ('soldier', 'sniper', 'grenadier', 'quartermaster') then
      v_st := jsonb_set(v_st, array['cls_' || v_cls || '_raids'], to_jsonb(coalesce((v_st->>('cls_' || v_cls || '_raids'))::int, 0) + v_held));
    end if;
    v_credit := floor(v_held * (100 + v_pct) / 100.0)::int;
    v_prog := v_prog + v_credit;
    earned := v_prog / 3 + case when v_win then (case when waves >= 10 then 2 else 1 end) else 0 end + case when waves = 0 then v_held / 5 else 0 end;
    v_prog := v_prog % 3;
    -- v0.9.3.6: bosses are capped over the whole stretch this player was in the game (first join to now), minus
    -- what earlier claims for the same game already paid. The old per-claim window started at v_prev + 1, so a
    -- boss killed after a rejoin (e.g. leave after raid 4, back for raid 5) was never paid to anyone.
    v_blo := v_join;
    v_bhi := v_to + 1; if waves > 0 then v_bhi := least(v_bhi, waves); end if;
    v_cap := case when v_campaign then greatest(0,least(12,v_bhi)/3-v_blo/3) else greatest(0, v_bhi / 5 - v_blo / 5) end;
    if not v_campaign and v_xl and v_dur >= 35 * v_held then v_cap := v_cap * 2; end if;
    v_cap := greatest(0, v_cap - v_pbn);
    if jsonb_typeof(v_keys) = 'array' then
      for v_key in select value from jsonb_array_elements_text(v_keys) limit 40 loop
        exit when v_n >= v_cap;
        if v_campaign then
          continue when v_key=any(v_paid_keys) or v_key not in ('whitebutcher','whiteferryman','whiteforeman','rime');
          continue when v_key='whitebutcher' and not(v_blo<3 and v_bhi>=3) or v_key='whiteferryman' and not(v_blo<6 and v_bhi>=6) or v_key='whiteforeman' and not(v_blo<9 and v_bhi>=9) or v_key='rime' and not(v_blo<12 and v_bhi>=12);
          v_paid_keys:=array_append(v_paid_keys,v_key);
        end if;
        v_bk := case when v_key = 'butcher_oct' then 'butcher' when v_key in ('butcher', 'ferryman', 'demolisher', 'storm', 'foreman') then v_key
          when v_key='rime' and v_map='frost' then 'rime' when v_campaign then private.winter_base(v_key) when v_blitz then private.blitz_base(v_key) end;
        if v_bk is not null then v_st := jsonb_set(v_st, array['boss_' || v_bk], to_jsonb(coalesce((v_st->>('boss_' || v_bk))::int, 0) + 1)); end if;
        if (v_campaign and v_key in ('whitebutcher','whiteferryman','whiteforeman','rime')) or (v_map='frost' and v_key='rime') then
          v_winter:=v_winter+case when v_key='rime' then 2 else 1 end;v_n:=v_n+1;
        elsif v_blitz and private.blitz_base(v_key) is not null then   -- a Blitzkrieg boss (raids 5 and 10): two Blitzkrieg Cases, and the mode's ladder
          v_st := jsonb_set(v_st, '{mode_blitz_bosses}', to_jsonb(coalesce((v_st->>'mode_blitz_bosses')::int, 0) + 1));
          v_blz := v_blz + 2; v_n := v_n + 1;
        elsif v_key in ('butcher', 'ferryman') then v_hal := v_hal + 1; v_n := v_n + 1;
        elsif v_key = 'butcher_oct' then v_hal := v_hal + case when v_oct then 2 else 1 end; v_n := v_n + 1;
        elsif v_key in ('demolisher', 'storm', 'foreman') then v_glow := v_glow + 1; v_n := v_n + 1;
        end if;
      end loop;
      v_boss := v_n;
    else
      v_boss := least(v_boss, v_cap); v_glow := v_boss; v_n := v_boss;
    end if;
    select * into cb from public.case_types c where c.drop ? 'boss' order by c.sort limit 1;
    if found then v_glow := v_glow * coalesce((cb.drop->'boss'->>'each')::int, 1); end if;
    -- v0.9.4.0: the Final Blitz bosses. At most 10 (15 with Double Time) per game, one per spawn beat of the time played,
    -- less what earlier claims for this game already paid. Each: two Blitzkrieg Cases, 15-30 shards, a skill point,
    -- +1 to its base boss's milestone and +1 to the BLITZKRIEG RUSH ladder.
    -- v0.9.6.4 Whiteout Gauntlet (cv:4 campaign): six waves of 2 Rime + 1 boss, one wave per 30 s of play, so at most
    -- 18 bosses, three per wave beat. Each pays 5-10 shards, a skill point and +1 to its base boss's milestone (Rime
    -- counts toward its own ladder with no cap). Cases come from waves fully cleared: +1 Winter Case each, capped by the
    -- bosses actually paid (three per wave) and by the time played.
    if v_g4 and v_to >= waves and jsonb_typeof(p->'fb_keys') = 'array' then
      v_fbcap := least(18, 3 * greatest(0, 1 + (v_dur - 20) / 30)) - v_pfb;
      for v_key in select value from jsonb_array_elements_text(p->'fb_keys') limit 20 loop
        exit when v_fbn >= v_fbcap;
        continue when v_key not in ('rime','whitebutcher','whiteforeman','tempest','bulldozer','bluebutcher','arsonist');
        v_bk := private.winter_base(v_key);
        continue when v_bk is null;
        v_st := jsonb_set(v_st, array['boss_' || v_bk], to_jsonb(coalesce((v_st->>('boss_' || v_bk))::int, 0) + 1));
        v_fbn := v_fbn + 1; v_fbshards := v_fbshards + 5 + floor(random() * 6)::int;
      end loop;
      v_gw := least(6, greatest(0, coalesce(private.num(p->>'g_cleared'), 0))::int, v_fbn / 3, greatest(0, 1 + (v_dur - 20) / 30));
      v_winter := v_winter + v_gw;
    elsif v_blitz and v_to >= waves and jsonb_typeof(p->'fb_keys') = 'array' then
      v_every := case when 'blitzclock' = any(v_mods) then 20 else 30 end;
      v_fbcap := least(case when 'blitzclock' = any(v_mods) then 15 else 10 end, greatest(0, 1 + (v_dur - 20) / v_every)) - v_pfb;
      for v_key in select value from jsonb_array_elements_text(p->'fb_keys') limit 20 loop
        exit when v_fbn >= v_fbcap;
        if v_campaign and v_key not in ('whitebutcher','whiteforeman','rime','tempest','bulldozer') then continue;end if;
        v_bk := case when v_campaign or v_key='rime' and v_map='frost' then private.winter_base(v_key) else private.blitz_base(v_key) end;
        continue when v_bk is null;
        v_st := jsonb_set(v_st, array['boss_' || v_bk], to_jsonb(coalesce((v_st->>('boss_' || v_bk))::int, 0) + 1));
        if not v_campaign and v_key<>'rime' then v_st := jsonb_set(v_st, '{mode_blitz_bosses}', to_jsonb(coalesce((v_st->>'mode_blitz_bosses')::int, 0) + 1));end if;
        if v_key in ('whitebutcher','whiteferryman','whiteforeman','rime') then v_winter:=v_winter+case when v_key='rime' then 2 else 1 end;else v_blz:=v_blz+2;end if; v_fbn := v_fbn + 1; v_fbshards := v_fbshards + 15 + floor(random() * 16)::int;
      end loop;
    end if;
    if v_blitz then v_sbreq := 0; end if;   -- no in-between bosses in Blitzkrieg Rush
    if v_blitz and v_win then if v_g4 then v_winter:=v_winter+2;elsif v_campaign then v_winter:=v_winter+1;else v_blz := v_blz + 1;end if; v_fbshards := v_fbshards + 25; end if;   -- making the evacuation
    -- v0.9.6.4 chapter evacs (after raids 3, 6, 9): +1 Winter Case for each one made inside this claim's raids.
    -- Missing one costs that chapter's evac case; the chapter boss's single Winter Case halves to 1 (odd counts round up).
    if v_g4 and jsonb_typeof(v_ce) = 'array' then
      for r in 0..2 loop
        if v_ce->>r = 'true' and v_from < 3 * (r + 1) and v_to >= 3 * (r + 1) then v_chev := v_chev + 1; end if;
      end loop;
      v_winter := v_winter + v_chev;
    end if;
    if v_sbreq > 0 and ('bossrush' = any(v_mods) or 'nightmare' = any(v_mods)) and v_dur >= 25 * greatest(v_held, 1) then
      for r in (v_blo + 1) .. v_bhi loop
        if r % 5 <> 0 and ('nightmare' = any(v_mods) or r % 2 = 0) then v_sbcap := v_sbcap + 1; end if;
      end loop;
      v_sb := least(v_sbreq, greatest(0, v_sbcap - v_psb));
      -- v0.9.3.8: every paid in-between boss also counts toward its boss milestone (clients send which bosses they were)
      if v_sb > 0 and jsonb_typeof(p->'sb_keys') = 'array' then
        for v_key in select value from jsonb_array_elements_text(p->'sb_keys') limit v_sb loop
          v_bk := case when v_key in ('butcher', 'ferryman', 'demolisher', 'storm', 'foreman') then v_key when v_key='rime' and v_map='frost' then 'rime' end;
          if v_bk is not null then v_st := jsonb_set(v_st, array['boss_' || v_bk], to_jsonb(coalesce((v_st->>('boss_' || v_bk))::int, 0) + 1)); end if;
        end loop;
      end if;
      for r in 1 .. v_sb loop v_sbshards := v_sbshards + 15 + floor(random() * 16)::int; end loop;
    end if;
    v_scap := greatest(0, floor(10 * (100 + v_pct) / 100.0)::int);
    v_shards := least(v_sal / 20, 2 * v_held, v_scap) + v_sbshards + v_fbshards;
    v_spprog := v_spprog + v_held;
    v_sp := v_spprog / 5 + v_n + v_sb + v_fbn;
    v_spprog := v_spprog % 5;
  else
    if v_pvp not in ('base', 'ffa') then raise exception 'Unknown match type' using errcode = '22023'; end if;
    v_held := 0;
    v_st := jsonb_set(v_st, '{drops}', to_jsonb(coalesce((v_st->>'drops')::int, 0) + v_kills));
    if not v_seen then
      v_st := jsonb_set(v_st, '{pvp}', to_jsonb(coalesce((v_st->>'pvp')::int, 0) + 1));
      if v_win then v_st := jsonb_set(v_st, '{pvpWins}', to_jsonb(coalesce((v_st->>'pvpWins')::int, 0) + 1)); end if;
    end if;
    v_case := null;
    select * into ct from public.case_types c where v_pvp = any(c.modes) order by c.sort limit 1;
    if found then
      v_case := ct.id;
      chance := coalesce((ct.drop->v_pvp->>(case when v_win then 'win' else 'loss' end))::float8, 0) * (100 + v_pct) / 100.0;
      if v_seen then chance := 0; end if;
      if random() < chance then earned := 1; end if;
    end if;
  end if;
  if v_win and v_kind = 'run' and v_cv >= 4 then v_hyb := 1; end if;   -- v0.9.6.4: one Hybrid Theory Case for every co-op win
  if v_win and not (v_kind = 'match' and v_seen) then
    select * into cf from public.case_types c where c.drop ? 'win' order by c.sort limit 1;
    if found and random() < coalesce((cf.drop->>'win')::float8, 0) then v_flag := 1; end if;
  end if;
  granted := earned;
  if v_left then   -- left behind: half of every case and of the shards (odd counts round up first); nothing else is halved
    granted := ceil(granted / 2.0)::int; v_glow := ceil(v_glow / 2.0)::int; v_hal := ceil(v_hal / 2.0)::int; v_blz := ceil(v_blz / 2.0)::int;
    v_shards := ceil(v_shards / 2.0)::int; v_fbshards := ceil(v_fbshards / 2.0)::int; v_sbshards := ceil(v_sbshards / 2.0)::int;
  end if;
  if v_left then v_winter:=ceil(v_winter/2.0)::int;end if;
  v_bonus := v_glow + v_hal + v_blz+v_winter;
  v_before := l.owned;
  update public.lockers set st = v_st, prog = v_prog,
      cases = cases + case when v_case = 'supply' then granted else 0 end,
      bag = private.bag_add(private.bag_add(
              case when v_case is not null and v_case <> 'supply' and granted > 0 then private.bag_add(bag, v_case, granted) else bag end,
              coalesce(cb.id, 'afterglow'), v_glow), 'halloween', v_hal)
            || case when v_blz > 0 then jsonb_build_object('blitz', coalesce((bag->>'blitz')::int, 0) + v_blz) else '{}'::jsonb end
            || case when v_flag > 0 then jsonb_build_object(cf.id, coalesce((bag->>cf.id)::int, 0) + v_flag) else '{}'::jsonb end
            || case when v_winter>0 then jsonb_build_object('winter',coalesce((bag->>'winter')::int,0)+v_winter) else '{}'::jsonb end
            || case when v_hyb>0 then jsonb_build_object('hybrid',coalesce((bag->>'hybrid')::int,0)+v_hyb) else '{}'::jsonb end,
      shards = shards + v_shards,
      sp = sp + v_sp, sp_total = sp_total + v_sp, sp_prog = v_spprog,
      play_budget = greatest(0, v_budget - v_dur), budget_at = now(),
      rev = rev + 1, updated_at = now()
    where user_id = uid;
  insert into public.match_results (user_id, kind, mode, pvp, diff, win, held, kills, duration_s, cases_granted, case_id, bonus, shards,
      game_id, raid_from, raid_to, joined_s, left_s, left_early, upgrades, salvage, mods, map, size, shard_bosses, skill_points, cls, boss_n, fb_n, evac)
    values (uid, v_kind, case when v_kind = 'run' then v_mode end, nullif(v_pvp, ''), case when v_kind = 'run' then v_diff end,
            v_win, v_held, v_kills, v_dur, granted, v_case, v_bonus, v_shards,
            v_gid, case when v_kind = 'run' then v_from end, case when v_kind = 'run' then v_to end,
            least(greatest(private.num(p->>'joined_s'), 0), 86400)::int, least(greatest(private.num(p->>'left_s'), 0), 86400)::int,
            coalesce(p->>'left' = 'true', false), left(regexp_replace(coalesce(p->>'upgrades', ''), '[^0-9a-z:]', '', 'g'), 16), v_sal,
            v_mods, left(regexp_replace(coalesce(p->>'map', ''), '[^a-z]', '', 'g'), 12), case when v_xl then 'xl' else 'std' end, v_sb, v_sp,
            nullif(v_cls, ''), case when v_kind = 'run' then v_n end, v_fbn, nullif(v_evac, ''));
  update public.player_stats s set
      raids = s.raids + case when v_kind = 'run' then v_held else 0 end,
      wins = s.wins + case when v_kind = 'run' and v_win then 1 else 0 end,
      drops = s.drops + v_kills,
      best_endless = greatest(s.best_endless, case when v_kind = 'run' and waves = 0 then v_to else 0 end),
      pvp = s.pvp + case when v_kind = 'match' and not v_seen then 1 else 0 end,
      pvp_wins = s.pvp_wins + case when v_kind = 'match' and v_win and not v_seen then 1 else 0 end,
      updated_at = now()
    where s.user_id = uid;
  got := private.apply_unlocks(uid);
  select * into l from public.lockers where user_id = uid;
  v_new := array(select u from unnest(l.owned) u where not (u = any(v_before)));
  v_response := jsonb_build_object(
    'cases', (case when v_kind = 'run'
        then jsonb_build_object('supply', granted, coalesce(cb.id, 'afterglow'), v_glow, 'halloween', v_hal) || case when v_blz > 0 then jsonb_build_object('blitz', v_blz) else '{}'::jsonb end
        else case when v_case is not null then jsonb_build_object(v_case, granted) else '{}'::jsonb end end)
      || case when v_flag > 0 then jsonb_build_object(cf.id, v_flag) else '{}'::jsonb end
      || case when v_winter>0 then jsonb_build_object('winter',v_winter) else '{}'::jsonb end
      || case when v_hyb>0 then jsonb_build_object('hybrid',v_hyb) else '{}'::jsonb end,
    'unlocked_ids', to_jsonb(v_new), 'to_next', 3 - l.prog, 'size', case when v_xl and v_dur >= 35 * v_held then 'xl' else 'std' end,
    'cases_granted', granted, 'case_id', v_case, 'capped', false, 'chance', chance,
    'bonus', jsonb_build_object('case', coalesce(cb.id, 'afterglow'), 'n', v_glow), 'shards', v_shards,
    'bonuses', jsonb_build_array(jsonb_build_object('case', coalesce(cb.id, 'afterglow'), 'n', v_glow), jsonb_build_object('case', 'halloween', 'n', v_hal), jsonb_build_object('case', 'blitz', 'n', v_blz)),
    'held', v_held, 'raid_from', v_from, 'mods', to_jsonb(v_mods), 'mod_pct', v_pct, 'shard_bosses', v_sb,
    'skill_points', v_sp, 'sp', l.sp, 'sp_to_next', 5 - l.sp_prog, 'repeat', v_seen,
    'flag_case', v_flag, 'left_behind', v_left, 'fb_bosses', v_fbn, 'evac', v_evac, 'boss_shards', v_sbshards + v_fbshards,
    'gauntlet_waves', v_gw, 'chapter_evacs', v_chev, 'hybrid_case', v_hyb,
    'unlocked', to_jsonb(got), 'locker', private.locker_out(l));
  insert into private.reward_receipts(user_id,claim_key,response) values(uid,v_receipt,v_response);
  return v_response;
end $function$;

revoke all on function public.claim_match_reward(jsonb) from public,anon;
grant execute on function public.claim_match_reward(jsonb) to authenticated;

-- SOURCE: 20261003200000_v097_city_blackout.sql
-- v0.9.7 City Black Out: the new mode in claims, rooms and lobbies, its ladder (catalog 5), and two result columns.
-- Built from the live function text: claim_match_reward and room_register are read with pg_get_functiondef and patched
-- with anchored replacements (each anchor must match exactly once, or the whole migration stops). Safe to run twice.
--
-- Black Out claims (cv:5) count the run as 9 stages: 8 POI attacks plus the final push. raid_to is how many stages were
-- finished (9 = the run was won), so the existing join/rejoin windows and repeat checks apply unchanged.
--   pois_held   POIs held in this claim's stages (at most 8, the stages credited, and one per 30 s after the gathering)
--   pois_major  majors among them (at most 4): +1 Supply Case each
--   destroyer   the Supreme Destroyer went down (only counts on a win): +40 shards and +1 skill point
-- Supply Case progress counts POIs held (not stages). A win pays 2 Supply Cases and 25 shards and needs at least 7 minutes.
-- POI bosses pay no boss cases. Ladder counters: bo_pois, bo_wins, bo_dest, bo_perfect (a win holding all 8).

alter table public.match_results add column if not exists pois_held int, add column if not exists destroyer boolean;

alter table public.lobbies drop constraint if exists lobbies_length_check;
alter table public.lobbies add constraint lobbies_length_check check (length in ('5','10','endless','blitz','campaign','blackout'));

create or replace function pg_temp.sub1(d text, a text, b text) returns text language plpgsql as $f$
begin
  if position(a in d) = 0 or (length(d) - length(replace(d, a, ''))) / length(a) <> 1 then
    raise exception 'v0.9.7 migration: anchor not found exactly once: %', left(a, 80);
  end if;
  return replace(d, a, b);
end $f$;

do $mig$
declare d text;
begin
  d := pg_get_functiondef('public.claim_match_reward(jsonb)'::regprocedure);
  if position('v_bo boolean' in d) = 0 then
    d := pg_temp.sub1(d, $a$v_ce jsonb := p->'ch_evac';$a$,
      $b$v_ce jsonb := p->'ch_evac';
  -- v0.9.7 City Black Out (cv:5)
  v_bo boolean := coalesce(p->>'mode', '') = 'blackout' and p->>'kind' = 'run'; v_pois int := 0; v_major int := 0; v_dest boolean := false;$b$);
    d := pg_temp.sub1(d, $a$if v_mode not in ('5', '10', 'endless', 'blitz','campaign') or$a$,
      $b$if v_mode not in ('5', '10', 'endless', 'blitz','campaign','blackout') or (v_mode = 'blackout' and v_cv < 5) or$b$);
    d := pg_temp.sub1(d, $a$when 'campaign' then 13 else 0 end;$a$, $b$when 'campaign' then 13 when 'blackout' then 9 else 0 end;$b$);
    d := pg_temp.sub1(d, $a$    v_held := v_to - v_from;
$a$, $b$    v_held := v_to - v_from;
    if v_bo then   -- v0.9.7: POIs held can't pass 8, the stages credited, or one per 30 s after the 45 s gathering
      v_pois := least(greatest(coalesce(private.num(p->>'pois_held'), 0), 0)::int, 8, v_held, greatest(0, 1 + (v_dur - 45) / 30));
      v_major := least(greatest(coalesce(private.num(p->>'pois_major'), 0), 0)::int, 4, v_pois);
      if v_dur < 420 then v_win := false; end if;
    end if;
$b$);
    d := pg_temp.sub1(d, $a$    v_credit := floor(v_held * (100 + v_pct) / 100.0)::int;$a$,
      $b$    if v_bo then   -- v0.9.7: the BLACK OUT ladder's counters, the win's shards and the Destroyer's
      v_dest := coalesce(p->>'destroyer', '') = 'true' and v_win;
      v_st := jsonb_set(v_st, '{bo_pois}', to_jsonb(coalesce((v_st->>'bo_pois')::int, 0) + v_pois));
      if v_win then
        v_st := jsonb_set(v_st, '{bo_wins}', to_jsonb(coalesce((v_st->>'bo_wins')::int, 0) + 1));
        if v_pois >= 8 then v_st := jsonb_set(v_st, '{bo_perfect}', to_jsonb(coalesce((v_st->>'bo_perfect')::int, 0) + 1)); end if;
        v_fbshards := v_fbshards + 25;
      end if;
      if v_dest then v_st := jsonb_set(v_st, '{bo_dest}', to_jsonb(coalesce((v_st->>'bo_dest')::int, 0) + 1)); v_fbshards := v_fbshards + 40; end if;
    end if;
    v_credit := floor((case when v_bo then v_pois else v_held end) * (100 + v_pct) / 100.0)::int;$b$);
    d := pg_temp.sub1(d, $a$earned := v_prog / 3 + case when v_win then (case when waves >= 10 then 2 else 1 end) else 0 end + case when waves = 0 then v_held / 5 else 0 end;$a$,
      $b$earned := v_prog / 3 + case when v_win then (case when waves >= 10 or v_bo then 2 else 1 end) else 0 end + case when waves = 0 then v_held / 5 else 0 end + v_major;$b$);
    d := pg_temp.sub1(d, $a$v_cap := greatest(0, v_cap - v_pbn);$a$, $b$v_cap := greatest(0, v_cap - v_pbn); if v_bo then v_cap := 0; end if;   -- v0.9.7: POI bosses pay no boss cases$b$);
    d := pg_temp.sub1(d, $a$    v_sp := v_spprog / 5 + v_n + v_sb + v_fbn;$a$, $b$    v_sp := v_spprog / 5 + v_n + v_sb + v_fbn + case when v_dest then 1 else 0 end;$b$);
    d := pg_temp.sub1(d, $a$boss_n, fb_n, evac)$a$, $b$boss_n, fb_n, evac, pois_held, destroyer)$b$);
    d := pg_temp.sub1(d, $a$v_fbn, nullif(v_evac, ''));$a$, $b$v_fbn, nullif(v_evac, ''), case when v_bo then v_pois end, case when v_bo then v_dest end);$b$);
    d := pg_temp.sub1(d, $a$'gauntlet_waves', v_gw,$a$, $b$'gauntlet_waves', v_gw, 'pois_held', v_pois, 'pois_major', v_major, 'destroyer', v_dest,$b$);
    execute d;
  end if;
  d := pg_get_functiondef('public.room_register(jsonb)'::regprocedure);
  if position($a$'campaign','blackout'$a$ in d) = 0 then
    d := pg_temp.sub1(d, $a$not in ('yard','river','quarry','frost')$a$, $b$not in ('yard','river','quarry','frost','city')$b$);
    d := pg_temp.sub1(d, $a$not in ('5','10','endless','blitz','campaign')$a$, $b$not in ('5','10','endless','blitz','campaign','blackout')$b$);
    execute d;
  end if;
end $mig$;

-- the BLACK OUT ladder (catalog 5): each step has its own counter
insert into public.cosmetics (id, cat, key, name, rarity, src, need, box, catalog_version) values
  ('skin:nightshift', 'skin', 'nightshift', 'Night Shift', 'r', 'unlock', '{"bo_pois":10}', null, 5),
  ('hat:blackout', 'hat', 'blackout', 'Blackout Helmet', 'e', 'unlock', '{"bo_wins":1}', null, 5),
  ('trail:streetlight', 'trail', 'streetlight', 'Streetlight', 'e', 'unlock', '{"bo_pois":50}', null, 5),
  ('fx:orbital', 'fx', 'orbital', 'Orbital Strike', 'l', 'unlock', '{"bo_dest":1}', null, 5),
  ('bg:skyline', 'bg', 'skyline', 'Lit Skyline', 'l', 'unlock', '{"bo_perfect":1}', null, 5),
  ('skin:gnightshift', 'skin', 'gnightshift', 'Gold Night Shift', 'g', 'unlock', '{"bo_dest":10}', null, 5)
on conflict (id) do update set cat = excluded.cat, key = excluded.key, name = excluded.name, rarity = excluded.rarity, src = excluded.src,
  need = excluded.need, box = excluded.box, catalog_version = excluded.catalog_version;

-- SOURCE: 20261004200000_v098_tables.sql
-- v0.9.8 THE TABLES: Blackjack and Texas Hold'em for shards. The rules run in the `tables` edge function (service role);
-- this file stores the tables, logs every hand and every shard, and applies each step's shard and case moves atomically.
-- Nothing here is reachable by players directly: no policies, and the functions are granted to service_role only.
create table if not exists public.casino_tables(
  id bigint generated always as identity primary key,
  code text not null unique,
  game text not null check (game in ('bj','he')),
  st jsonb not null,
  ver integer not null default 0,
  humans uuid[] not null default '{}',
  open boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now());
create index if not exists casino_tables_open on public.casino_tables(open,updated_at);
create table if not exists public.casino_hands(
  id bigint generated always as identity primary key,
  table_id bigint not null,
  game text not null,
  hand_no integer not null,
  hash text,
  salt text,
  deck jsonb,
  result jsonb,
  rake integer not null default 0,
  side_hits jsonb,
  created_at timestamptz not null default now());
create table if not exists public.casino_ledger(
  id bigint generated always as identity primary key,
  table_id bigint not null,
  user_id uuid,
  kind text not null check (kind in ('buyin','topup','cashout','case','bot')),
  shards integer not null default 0,
  bag text,
  n integer,
  created_at timestamptz not null default now());
create index if not exists casino_ledger_user on public.casino_ledger(user_id,created_at);
create index if not exists casino_ledger_kind on public.casino_ledger(kind,created_at);
alter table public.casino_tables enable row level security;
alter table public.casino_hands enable row level security;
alter table public.casino_ledger enable row level security;
revoke all on public.casino_tables,public.casino_hands,public.casino_ledger from anon,authenticated;

-- one step's moves: buy-ins and top-ups take shards (refused if the balance is short, which undoes the whole step),
-- cash-outs return them, a side-bet prize adds cases to the bag, the bot's result is the house's
create or replace function private.casino_apply(p_table bigint,p_ops jsonb) returns void
language plpgsql security definer set search_path='' as $$
declare o jsonb; n integer; d integer;
begin
  for o in select * from jsonb_array_elements(coalesce(p_ops,'[]'::jsonb)) loop
    d:=coalesce((o->>'d')::integer,0);
    if o->>'k' in ('buyin','topup','cashout') then
      update public.lockers set shards=shards+d,rev=rev+1,updated_at=now() where user_id=(o->>'uid')::uuid and shards+d>=0;
      get diagnostics n=row_count;
      if n=0 then raise exception 'insufficient shards' using errcode='P0001'; end if;
    elsif o->>'k'='case' then
      if (o->>'bag') not in ('hybrid','flags') or (o->>'n')::integer not in (10,15) then raise exception 'bad prize'; end if;
      update public.lockers set bag=private.bag_add(bag,o->>'bag',(o->>'n')::integer),rev=rev+1,updated_at=now() where user_id=(o->>'uid')::uuid;
    elsif o->>'k'<>'bot' then raise exception 'bad op';
    end if;
    insert into public.casino_ledger(table_id,user_id,kind,shards,bag,n)
      values(p_table,case when o->>'k'='bot' then null else (o->>'uid')::uuid end,o->>'k',d,o->>'bag',(o->>'n')::integer);
  end loop;
end $$;

create or replace function public.casino_open(p_code text,p_game text,p_st jsonb,p_humans uuid[],p_ops jsonb) returns jsonb
language plpgsql security definer set search_path='' as $$
declare v_id bigint;
begin
  insert into public.casino_tables(code,game,st,humans) values(p_code,p_game,p_st,p_humans) returning id into v_id;
  perform private.casino_apply(v_id,p_ops);
  return jsonb_build_object('ok',true,'id',v_id);
exception when unique_violation then return jsonb_build_object('conflict',true);
end $$;

-- save a step: only if nobody else saved since this one was read (ver), then apply its moves and log its hands
create or replace function public.casino_commit(p_table bigint,p_ver integer,p_st jsonb,p_humans uuid[],p_open boolean,p_ops jsonb,p_hands jsonb) returns jsonb
language plpgsql security definer set search_path='' as $$
begin
  update public.casino_tables set st=p_st,ver=ver+1,humans=p_humans,open=p_open,updated_at=now() where id=p_table and ver=p_ver;
  if not found then return jsonb_build_object('conflict',true); end if;
  perform private.casino_apply(p_table,p_ops);
  insert into public.casino_hands(table_id,game,hand_no,hash,salt,deck,result,rake,side_hits)
    select p_table,h->>'game',(h->>'no')::integer,h->>'hash',h->>'salt',h->'deck',h->'result',coalesce((h->>'rake')::integer,0),h->'sideHits'
    from jsonb_array_elements(coalesce(p_hands,'[]'::jsonb)) h;
  return jsonb_build_object('ok',true);
end $$;

-- what the bot may still lose today (Eastern): 25 shards a day across every table
create or replace function public.casino_bot_left() returns integer
language sql stable security definer set search_path='' as $$
  select greatest(0,25+coalesce(sum(shards),0))::integer from public.casino_ledger
  where kind='bot' and created_at>=(date_trunc('day',now() at time zone 'America/New_York') at time zone 'America/New_York') $$;

revoke all on function private.casino_apply(bigint,jsonb) from public,anon,authenticated;
revoke all on function public.casino_open(text,text,jsonb,uuid[],jsonb) from public,anon,authenticated;
revoke all on function public.casino_commit(bigint,integer,jsonb,uuid[],boolean,jsonb,jsonb) from public,anon,authenticated;
revoke all on function public.casino_bot_left() from public,anon,authenticated;
grant execute on function public.casino_open(text,text,jsonb,uuid[],jsonb) to service_role;
grant execute on function public.casino_commit(bigint,integer,jsonb,uuid[],boolean,jsonb,jsonb) to service_role;
grant execute on function public.casino_bot_left() to service_role;
grant select,insert,update on public.casino_tables,public.casino_hands,public.casino_ledger to service_role;

-- SOURCE: 20261004230000_account_bonus_250.sql
-- October 4: 250 shards for every account (not guests), now and for anyone who makes one later (a new sign-up, or a guest
-- adding an email). Once per person, recorded in private.account_bonus. Granted by triggers on auth.users (when someone
-- becomes a real account) and on lockers (in case the locker is made after the account). Never blocks a sign-up: any
-- error inside the grant is swallowed. The player gets a notification.
-- APPLIED live on October 4 at Big U's request (in five steps: table, grant function, trigger functions, triggers, then the
-- existing accounts). 7 accounts were paid 250 each.
create table if not exists private.account_bonus(user_id uuid primary key,shards integer not null,granted_at timestamptz not null default now());

create or replace function private.grant_account_bonus(p_uid uuid) returns boolean
language plpgsql security definer set search_path='' as $$
declare n integer;
begin
  if p_uid is null then return false; end if;
  if not exists(select 1 from auth.users u where u.id=p_uid and not coalesce(u.is_anonymous,false)) then return false; end if;
  if not exists(select 1 from public.lockers l where l.user_id=p_uid) then return false; end if;
  insert into private.account_bonus(user_id,shards) values(p_uid,250) on conflict do nothing;
  get diagnostics n=row_count;
  if n=0 then return false; end if;
  update public.lockers set shards=shards+250,rev=rev+1,updated_at=now() where user_id=p_uid;
  insert into public.notifications(user_id,kind,data) values(p_uid,'system',jsonb_build_object('comp','account-bonus-250',
    'text','Welcome bonus: 250 shards for having a PALISADE account. Spend them on cases, or take them to the new Tables.'));
  return true;
exception when others then return false;
end $$;

create or replace function private.account_bonus_users() returns trigger
language plpgsql security definer set search_path='' as $$
begin
  if not coalesce(new.is_anonymous,false) then perform private.grant_account_bonus(new.id); end if;
  return new;
exception when others then return new;
end $$;

create or replace function private.account_bonus_lockers() returns trigger
language plpgsql security definer set search_path='' as $$
begin
  perform private.grant_account_bonus(new.user_id);
  return new;
exception when others then return new;
end $$;

create or replace trigger account_bonus after insert or update of is_anonymous on auth.users for each row execute function private.account_bonus_users();
create or replace trigger account_bonus after insert on public.lockers for each row execute function private.account_bonus_lockers();

revoke all on function private.grant_account_bonus(uuid) from public,anon,authenticated;
revoke all on function private.account_bonus_users() from public,anon,authenticated;
revoke all on function private.account_bonus_lockers() from public,anon,authenticated;

-- everyone who already has an account
select private.grant_account_bonus(u.id) from auth.users u where not coalesce(u.is_anonymous,false);

-- SOURCE: 20261005200000_v0100_casino.sql
-- v0.10.0 THE PALISADE FALLS CASINO: Roulette joins the tables; every table belongs to a casino room (you walk up to it);
-- hand history is looked up by player; the daily books check. Like v0.9.8, nothing here is reachable by players directly:
-- service role only. Safe to run twice.

-- 1. Roulette is a game
alter table public.casino_tables drop constraint if exists casino_tables_game_check;
alter table public.casino_tables add constraint casino_tables_game_check check (game in ('bj','he','rl'));

-- 2. one table of each game per casino room: walking up to the blackjack table finds the same table for everyone
alter table public.casino_tables add column if not exists room text;
create unique index if not exists casino_tables_room_game on public.casino_tables(room,game) where open and room is not null;

create or replace function public.casino_open(p_code text,p_game text,p_st jsonb,p_humans uuid[],p_ops jsonb,p_room text) returns jsonb
language plpgsql security definer set search_path='' as $$
declare v_id bigint;
begin
  insert into public.casino_tables(code,game,st,humans,room) values(p_code,p_game,p_st,p_humans,p_room) returning id into v_id;
  perform private.casino_apply(v_id,p_ops);
  return jsonb_build_object('ok',true,'id',v_id);
exception when unique_violation then return jsonb_build_object('conflict',true);   -- the code was taken, or someone opened this room's table first
end $$;

-- 3. hand history: your hands, newest first
create index if not exists casino_hands_players on public.casino_hands using gin ((result->'players') jsonb_path_ops);
create index if not exists casino_hands_table on public.casino_hands(table_id);

-- 4. the daily books check. For every table that closed that day (Eastern, the bot budget's clock), from v0.10.0 on:
--    shards brought in (buy-ins and top-ups) - shards taken home (cash-outs) must equal the house's take from that table's
--    hands (the poker cut and side-bet costs, blackjack's and roulette's net) plus what players lost to the bot.
--    A table that doesn't balance is listed in bad_tables and the day is marked not ok.
create table if not exists public.casino_books(
  day date primary key,
  tables_closed integer not null default 0,
  shards_in integer not null default 0,
  shards_out integer not null default 0,
  house_bj integer not null default 0,
  house_he integer not null default 0,
  house_rl integer not null default 0,
  bot integer not null default 0,
  bad_tables bigint[] not null default '{}',
  ok boolean not null default true,
  created_at timestamptz not null default now());
alter table public.casino_books enable row level security;
revoke all on public.casino_books from anon,authenticated;

create or replace function private.casino_books_day(p_day date) returns void
language plpgsql security definer set search_path='' as $$
declare t0 timestamptz:=(p_day::timestamp at time zone 'America/New_York'); t1 timestamptz:=((p_day+1)::timestamp at time zone 'America/New_York');
begin
  with tabs as (
    select t.id,t.game from public.casino_tables t
    where not t.open and t.st->>'fv'='2' and t.updated_at>=t0 and t.updated_at<t1),
  led as (
    select l.table_id,
      -sum(case when l.kind in ('buyin','topup') then l.shards else 0 end)::integer s_in,
      sum(case when l.kind='cashout' then l.shards else 0 end)::integer s_out,
      sum(case when l.kind='bot' then l.shards else 0 end)::integer bot
    from public.casino_ledger l join tabs on tabs.id=l.table_id group by l.table_id),
  hands as (
    select h.table_id,sum(coalesce((h.result->>'house')::integer,0))::integer house
    from public.casino_hands h join tabs on tabs.id=h.table_id group by h.table_id),
  per as (
    select tabs.id,tabs.game,coalesce(led.s_in,0) s_in,coalesce(led.s_out,0) s_out,coalesce(led.bot,0) bot,coalesce(hands.house,0) house
    from tabs left join led on led.table_id=tabs.id left join hands on hands.table_id=tabs.id)
  insert into public.casino_books(day,tables_closed,shards_in,shards_out,house_bj,house_he,house_rl,bot,bad_tables,ok)
  select p_day,count(*)::integer,coalesce(sum(s_in),0)::integer,coalesce(sum(s_out),0)::integer,
    coalesce(sum(house) filter (where game='bj'),0)::integer,coalesce(sum(house) filter (where game='he'),0)::integer,
    coalesce(sum(house) filter (where game='rl'),0)::integer,coalesce(sum(bot),0)::integer,
    coalesce(array_agg(id order by id) filter (where s_in-s_out<>house+bot),'{}'),
    coalesce(bool_and(s_in-s_out=house+bot),true)
  from per
  on conflict (day) do nothing;
end $$;

-- called by the edge function on a lobby request: fills in every finished day since the last row (at most 31 at a time)
create or replace function public.casino_books_run() returns integer
language plpgsql security definer set search_path='' as $$
declare v_today date:=(now() at time zone 'America/New_York')::date; v_from date; n integer:=0;
begin
  select coalesce(max(day)+1,v_today-1) into v_from from public.casino_books;
  v_from:=greatest(v_from,v_today-31);
  while v_from<v_today loop perform private.casino_books_day(v_from); v_from:=v_from+1; n:=n+1; end loop;
  return n;
end $$;

revoke all on function public.casino_open(text,text,jsonb,uuid[],jsonb,text) from public,anon,authenticated;
revoke all on function private.casino_books_day(date) from public,anon,authenticated;
revoke all on function public.casino_books_run() from public,anon,authenticated;
grant execute on function public.casino_open(text,text,jsonb,uuid[],jsonb,text) to service_role;
grant execute on function public.casino_books_run() to service_role;
grant select on public.casino_books to service_role;

-- SOURCE: 20261005200100_v0100_casino_rooms.sql
-- v0.10.0 casino rooms: Open Games and friend invites know THE PALISADE FALLS CASINO. A casino room is listed like any
-- room, with length 'casino' and map 'casino'. room_register is the live definition with those two values added (its
-- close branch removes the room session, as before). Safe to run twice.
alter table public.lobbies drop constraint if exists lobbies_length_check;
alter table public.lobbies add constraint lobbies_length_check check (length = any (array['5','10','endless','blitz','campaign','blackout','casino']));

create or replace function public.room_register(p jsonb) returns jsonb
language plpgsql security definer set search_path to '' as $function$
declare uid uuid:=private.require_user();inc uuid:=(p->>'incarnation')::uuid;r private.room_sessions;
begin
 if coalesce((auth.jwt()->>'is_anonymous')::boolean,false) then raise exception 'Use a saved account for friend invitations';end if;
 perform pg_advisory_xact_lock(hashtextextended(uid::text,0));
 if p->>'close'='true' then delete from private.room_sessions where host_id=uid and incarnation=inc;return '{"closed":true}'::jsonb;end if;
 if inc is null or coalesce(p->>'proto','')!~'^yard-[0-9]{1,3}$' or coalesce(p->>'code','')!~'^[A-Z0-9]{4}$' or coalesce(p->>'mode','') not in ('coop','base','ffa')
    or coalesce(p->>'map','') not in ('yard','river','quarry','frost','city','casino') or coalesce(p->>'length','') not in ('5','10','endless','blitz','campaign','blackout','casino') then raise exception 'Invalid room registration';end if;
 insert into private.room_sessions(host_id,incarnation,code,proto,mode,length,map,chapter,players,locked)
 values(uid,inc,p->>'code',p->>'proto',p->>'mode',p->>'length',p->>'map',coalesce((p->>'chapter')::int,0),(p->>'players')::int,coalesce((p->>'locked')::boolean,false))
 on conflict(host_id) do update set incarnation=excluded.incarnation,code=excluded.code,proto=excluded.proto,mode=excluded.mode,length=excluded.length,map=excluded.map,chapter=excluded.chapter,players=excluded.players,locked=excluded.locked,updated_at=now();
 return '{"registered":true}'::jsonb;
end $function$;

-- SOURCE: 20261006200000_v0103_casino_games.sql
-- v0.10.3 THE PALISADE FALLS CASINO, more games: baccarat, craps, slots and Plinko. Like v0.9.8 and v0.10.0 nothing here
-- is reachable by players directly (service role only). Safe to run twice. The v0.10.0 functions (casino_open and
-- casino_commit) are left in place so the edge function that is live before this deploy keeps working; the v0.10.3 edge
-- function calls casino_start and casino_step instead. No game record is deleted: the only rows ever removed are
-- casino_seats rows, when that player stands up.

-- 1. the games
alter table public.casino_tables drop constraint if exists casino_tables_game_check;
alter table public.casino_tables add constraint casino_tables_game_check check (game in ('bj','he','rl','ba','cr','sl','pk'));

-- 2. stations: one open session per (room, game, station). The tables keep station '' (one each per room, as before);
--    the sixteen slot cabinets are 's1'..'s16' and the Plinko board 'p1', so two cabinets never merge into one session.
alter table public.casino_tables add column if not exists station text not null default '';
create unique index if not exists casino_tables_room_game_station on public.casino_tables(room,game,station) where open and room is not null;
drop index if exists public.casino_tables_room_game;

-- 3. one activity per account, enforced in the same transaction as the move: an account is in casino_seats for exactly
--    one open table (a craps table keeps you there while bets you left behind are still working).
create table if not exists public.casino_seats(
  user_id uuid primary key,
  table_id bigint not null,
  at timestamptz not null default now());
alter table public.casino_seats enable row level security;
revoke all on public.casino_seats from anon,authenticated;
insert into public.casino_seats(user_id,table_id)
  select distinct on (u) u,id from (select unnest(humans) u,id,updated_at from public.casino_tables where open) x order by u,updated_at desc
  on conflict (user_id) do nothing;

-- 4. operation ids: a money move is saved with the id the client chose for it. The same id again is answered from here
--    (no second debit or payout); the same id with a different request is refused by the edge function.
create table if not exists public.casino_ops(
  user_id uuid not null,
  op_id text not null check (op_id ~ '^[A-Za-z0-9_-]{8,64}$'),
  req text not null,
  table_id bigint,
  res jsonb,
  created_at timestamptz not null default now(),
  primary key (user_id,op_id));
alter table public.casino_ops enable row level security;
revoke all on public.casino_ops from anon,authenticated;

-- the seats of one table after a step: who left is removed, who sat is added. Someone already seated at another open table
-- (and still listed there) can't be added: the whole step is undone. Rows left behind by a table that no longer lists that
-- player (a step saved by the v0.10.0 function during the deploy) are cleared first.
create or replace function private.casino_seat_sync(p_table bigint,p_humans uuid[],p_open boolean) returns void
language plpgsql security definer set search_path='' as $$
begin
  delete from public.casino_seats where table_id=p_table and (not p_open or not (user_id=any(coalesce(p_humans,'{}'))));
  if not p_open then return; end if;
  delete from public.casino_seats s using public.casino_tables t
    where s.user_id=any(p_humans) and s.table_id<>p_table and t.id=s.table_id and (not t.open or not (s.user_id=any(t.humans)));
  delete from public.casino_seats s where s.user_id=any(p_humans) and s.table_id<>p_table and not exists(select 1 from public.casino_tables t where t.id=s.table_id);
  insert into public.casino_seats(user_id,table_id) select u,p_table from unnest(p_humans) u on conflict (user_id) do nothing;
  if exists(select 1 from unnest(p_humans) u where not exists(select 1 from public.casino_seats s where s.user_id=u and s.table_id=p_table)) then
    raise exception 'seated elsewhere' using errcode='P0001'; end if;
end $$;

-- record an operation id; a second one with the same id undoes the step that tried it
create or replace function private.casino_op_record(p_table bigint,p_op jsonb) returns void
language plpgsql security definer set search_path='' as $$
declare n integer;
begin
  if p_op is null or jsonb_typeof(p_op)<>'object' then return; end if;
  insert into public.casino_ops(user_id,op_id,req,table_id,res) values((p_op->>'uid')::uuid,p_op->>'id',p_op->>'req',p_table,p_op->'res')
    on conflict (user_id,op_id) do nothing;
  get diagnostics n=row_count;
  if n=0 then raise exception 'duplicate op' using errcode='P0001'; end if;
end $$;

-- open a table or a machine session (the first to sit), with its station and the sitter's operation id
create or replace function public.casino_start(p_code text,p_game text,p_st jsonb,p_humans uuid[],p_ops jsonb,p_room text,p_station text,p_op jsonb) returns jsonb
language plpgsql security definer set search_path='' as $$
declare v_id bigint;
begin
  begin
    insert into public.casino_tables(code,game,st,humans,room,station) values(p_code,p_game,p_st,p_humans,p_room,coalesce(p_station,'')) returning id into v_id;
  exception when unique_violation then return jsonb_build_object('conflict',true);   -- the code was taken, or someone opened this station first
  end;
  perform private.casino_seat_sync(v_id,p_humans,true);
  perform private.casino_op_record(v_id,p_op);
  perform private.casino_apply(v_id,p_ops);
  return jsonb_build_object('ok',true,'id',v_id);
end $$;

-- save a step: only if nobody else saved since this one was read (ver); then the seats, the operation id, the shard and
-- case moves and the hand log, all or nothing
create or replace function public.casino_step(p_table bigint,p_ver integer,p_st jsonb,p_humans uuid[],p_open boolean,p_ops jsonb,p_hands jsonb,p_op jsonb) returns jsonb
language plpgsql security definer set search_path='' as $$
begin
  update public.casino_tables set st=p_st,ver=ver+1,humans=p_humans,open=p_open,updated_at=now() where id=p_table and ver=p_ver;
  if not found then return jsonb_build_object('conflict',true); end if;
  perform private.casino_seat_sync(p_table,p_humans,p_open);
  perform private.casino_op_record(p_table,p_op);
  perform private.casino_apply(p_table,p_ops);
  insert into public.casino_hands(table_id,game,hand_no,hash,salt,deck,result,rake,side_hits)
    select p_table,h->>'game',(h->>'no')::integer,h->>'hash',h->>'salt',h->'deck',h->'result',coalesce((h->>'rake')::integer,0),h->'sideHits'
    from jsonb_array_elements(coalesce(p_hands,'[]'::jsonb)) h;
  return jsonb_build_object('ok',true);
end $$;

-- 5. the daily books check covers the new games (one column each); the rule is unchanged: for every table or machine
--    session closed that day, shards brought in - shards taken home = the house's take from its rounds + the bot.
alter table public.casino_books add column if not exists house_ba integer not null default 0;
alter table public.casino_books add column if not exists house_cr integer not null default 0;
alter table public.casino_books add column if not exists house_sl integer not null default 0;
alter table public.casino_books add column if not exists house_pk integer not null default 0;
create or replace function private.casino_books_day(p_day date) returns void
language plpgsql security definer set search_path='' as $$
declare t0 timestamptz:=(p_day::timestamp at time zone 'America/New_York'); t1 timestamptz:=((p_day+1)::timestamp at time zone 'America/New_York');
begin
  with tabs as (
    select t.id,t.game from public.casino_tables t
    where not t.open and t.st->>'fv'='2' and t.updated_at>=t0 and t.updated_at<t1),
  led as (
    select l.table_id,
      -sum(case when l.kind in ('buyin','topup') then l.shards else 0 end)::integer s_in,
      sum(case when l.kind='cashout' then l.shards else 0 end)::integer s_out,
      sum(case when l.kind='bot' then l.shards else 0 end)::integer bot
    from public.casino_ledger l join tabs on tabs.id=l.table_id group by l.table_id),
  hands as (
    select h.table_id,sum(coalesce((h.result->>'house')::integer,0))::integer house
    from public.casino_hands h join tabs on tabs.id=h.table_id group by h.table_id),
  per as (
    select tabs.id,tabs.game,coalesce(led.s_in,0) s_in,coalesce(led.s_out,0) s_out,coalesce(led.bot,0) bot,coalesce(hands.house,0) house
    from tabs left join led on led.table_id=tabs.id left join hands on hands.table_id=tabs.id)
  insert into public.casino_books(day,tables_closed,shards_in,shards_out,house_bj,house_he,house_rl,house_ba,house_cr,house_sl,house_pk,bot,bad_tables,ok)
  select p_day,count(*)::integer,coalesce(sum(s_in),0)::integer,coalesce(sum(s_out),0)::integer,
    coalesce(sum(house) filter (where game='bj'),0)::integer,coalesce(sum(house) filter (where game='he'),0)::integer,
    coalesce(sum(house) filter (where game='rl'),0)::integer,coalesce(sum(house) filter (where game='ba'),0)::integer,
    coalesce(sum(house) filter (where game='cr'),0)::integer,coalesce(sum(house) filter (where game='sl'),0)::integer,
    coalesce(sum(house) filter (where game='pk'),0)::integer,coalesce(sum(bot),0)::integer,
    coalesce(array_agg(id order by id) filter (where s_in-s_out<>house+bot),'{}'),
    coalesce(bool_and(s_in-s_out=house+bot),true)
  from per
  on conflict (day) do nothing;
end $$;

-- 6. hand history looks rows up by id too (the baccarat check fetches its shoe's fingerprints)
create index if not exists casino_ops_table on public.casino_ops(table_id);

revoke all on function private.casino_seat_sync(bigint,uuid[],boolean) from public,anon,authenticated;
revoke all on function private.casino_op_record(bigint,jsonb) from public,anon,authenticated;
revoke all on function public.casino_start(text,text,jsonb,uuid[],jsonb,text,text,jsonb) from public,anon,authenticated;
revoke all on function public.casino_step(bigint,integer,jsonb,uuid[],boolean,jsonb,jsonb,jsonb) from public,anon,authenticated;
revoke all on function private.casino_books_day(date) from public,anon,authenticated;
grant execute on function public.casino_start(text,text,jsonb,uuid[],jsonb,text,text,jsonb) to service_role;
grant execute on function public.casino_step(bigint,integer,jsonb,uuid[],boolean,jsonb,jsonb,jsonb) to service_role;
grant select,insert,update,delete on public.casino_seats to service_role;
grant select,insert on public.casino_ops to service_role;
