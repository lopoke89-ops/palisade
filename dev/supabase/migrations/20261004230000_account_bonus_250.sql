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
