-- ============================================================
-- IDRATATI — aggiornamento 2
-- Aggiunge: lo stato "lavori in corso" e la stella sulla temperatura.
-- Incolla tutto nel SQL Editor di Supabase e premi Run. Una volta sola.
-- ============================================================

-- 1. LAVORI IN CORSO -----------------------------------------
--    Un cantiere non è un guasto: la fontanella tornerà.
alter table public.reports   drop constraint if exists reports_status_check;
alter table public.reports   add  constraint reports_status_check
  check (status in ('ok','broken','works'));

alter table public.fountains drop constraint if exists fountains_status_check;
alter table public.fountains add  constraint fountains_status_check
  check (status in ('ok','broken','removed','works','unknown'));

-- 2. TEMPERATURA DELL'ACQUA ----------------------------------
alter table public.reviews
  add column if not exists temperature int check (temperature between 1 and 5);

-- 3. VISTE RIFATTE -------------------------------------------
--    Cambia il numero di colonne, quindi vanno ricreate da zero.
drop view if exists public.v_status;
create view public.v_status
with (security_invoker = on) as
select
  target,
  count(*) filter (where status = 'ok'     and created_at > now() - interval '180 days') as ok_votes,
  count(*) filter (where status = 'broken' and created_at > now() - interval '180 days') as broken_votes,
  count(*) filter (where status = 'works'  and created_at > now() - interval '120 days') as works_votes,
  max(created_at) as last_report,
  max(created_at) filter (where status = 'works') as last_works
from public.reports
group by target;

drop view if exists public.v_reviews;
create view public.v_reviews
with (security_invoker = on) as
select
  target,
  count(*)                             as n,
  round(avg(findability)::numeric, 1)  as findability,
  round(avg(cleanliness)::numeric, 1)  as cleanliness,
  round(avg(taste)::numeric, 1)        as taste,
  round(avg(temperature)::numeric, 1)  as temperature,
  round(avg((coalesce(findability,3) + coalesce(cleanliness,3)
           + coalesce(taste,3)       + coalesce(temperature,3))::numeric / 4), 1) as overall,
  max(created_at)                      as last_review
from public.reviews
where approved
group by target;

grant select on public.v_status, public.v_reviews to anon, authenticated;

-- 4. VERIFICA ------------------------------------------------
--    Devono uscire due righe vuote senza errori.
select * from public.v_status  limit 1;
select * from public.v_reviews limit 1;
