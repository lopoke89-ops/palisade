-- Blitzkrieg Rush hosts publish length='blitz'. The original constraint rejected
-- every heartbeat, leaving working rooms absent from the Open Games list.
alter table public.lobbies drop constraint if exists lobbies_length_check;
alter table public.lobbies add constraint lobbies_length_check
  check (length in ('5', '10', 'endless', 'blitz'));
