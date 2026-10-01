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

-- v0.9.3.5 restore extension (same SQL as the versioned migration).
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
