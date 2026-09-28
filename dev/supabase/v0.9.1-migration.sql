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

