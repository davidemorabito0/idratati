-- ============================================================
-- IDRATATI — aggiornamento 3
-- Aggiunge la segnalazione "non l'ho trovata": diversa da "è rotta",
-- perché una fontanella rotta esiste ancora, una che non c'è più
-- va tolta dalla mappa.
-- Incolla tutto nel SQL Editor di Supabase e premi Run.
-- ============================================================

alter table public.reports drop constraint if exists reports_status_check;
alter table public.reports add  constraint reports_status_check
  check (status in ('ok','broken','works','missing'));

-- La vista rifatta con il nuovo conteggio.
drop view if exists public.v_status;
create view public.v_status
with (security_invoker = on) as
select
  target,
  count(*) filter (where status = 'ok'      and created_at > now() - interval '180 days') as ok_votes,
  count(*) filter (where status = 'broken'  and created_at > now() - interval '180 days') as broken_votes,
  count(*) filter (where status = 'works'   and created_at > now() - interval '120 days') as works_votes,
  count(*) filter (where status = 'missing' and created_at > now() - interval '365 days') as missing_votes,
  max(created_at) as last_report,
  max(created_at) filter (where status = 'works')   as last_works,
  max(created_at) filter (where status = 'missing') as last_missing
from public.reports
group by target;

grant select on public.v_status to anon, authenticated;

-- Verifica: deve rispondere senza errori.
select * from public.v_status limit 1;
