-- v0.12.3 THE UNDERSTRIP: the run's rewards scale with depth (the director, November 4, 2026).
-- Region 1 cleared pays 1 UNDERSTRIP CASE, 2 shards and 1 skill point; region 2 pays 3, 6 and 3; region 3 pays 6, 12 and 6.
-- The win pays 10 more cases. A full run: 20 cases, 20 shards and 10 skill points (was 4, 6 and 3).
-- Everything else in the v0.12 rules stays: each region pays once a run (the claim's levels), a level takes a minute, a win
-- under 15 minutes doesn't count, the us_regions ladder counter still counts regions.
-- Patches public.claim_match_reward(jsonb) as the v0.12 migration left it; safe to run twice.
create or replace function pg_temp.sub1(d text, a text, b text) returns text language plpgsql as $f$
begin
  if position(a in d) = 0 or (length(d) - length(replace(d, a, ''))) / length(a) <> 1 then
    raise exception 'v0.12.3 migration: anchor not found exactly once: %', left(a, 80);
  end if;
  return replace(d, a, b);
end $f$;

do $mig$
declare d text;
begin
  d := pg_get_functiondef('public.claim_match_reward(jsonb)'::regprocedure);
  if position('v_us boolean' in d) = 0 then raise exception 'v0.12.3 migration: apply v012_understrip first'; end if;
  if position('v_usm' in d) = 0 then
    d := pg_temp.sub1(d, $a$v_usr int := 0; v_usc int := 0;$a$, $b$v_usr int := 0; v_usc int := 0; v_usm int := 0;$b$);
    d := pg_temp.sub1(d, $a$    if v_us then   -- v0.12: regions cleared inside this claim's levels (at 3, 6 and 9 finished): a case, 2 shards and a skill point each
      for r in 1..3 loop if v_from < 3 * r and v_to >= 3 * r then v_usr := v_usr + 1; end if; end loop;
      v_usc := v_usr + case when v_win then 1 else 0 end;
      v_fbshards := v_fbshards + 2 * v_usr;$a$,
      $b$    if v_us then   -- v0.12.3: regions cleared inside this claim's levels (at 3, 6 and 9 finished) pay 1, 3 and 6 (cases and skill points; twice that in shards), the win 10 cases
      for r in 1..3 loop if v_from < 3 * r and v_to >= 3 * r then v_usr := v_usr + 1; v_usm := v_usm + (array[1, 3, 6])[r]; end if; end loop;
      v_usc := v_usm + case when v_win then 10 else 0 end;
      v_fbshards := v_fbshards + 2 * v_usm;$b$);
    d := pg_temp.sub1(d, $a$case when v_dest then 1 else 0 end + v_usr;$a$, $b$case when v_dest then 1 else 0 end + v_usm;$b$);
    execute d;
  end if;
end $mig$;
