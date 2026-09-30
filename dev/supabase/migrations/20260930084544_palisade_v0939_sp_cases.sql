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
