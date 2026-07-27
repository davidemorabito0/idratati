-- ============================================================
-- IDRATATI — aggiornamento 4
-- Le segnalazioni di stato diventano correggibili.
--
-- Da adesso ogni dispositivo ha UNA segnalazione per fontanella, che può
-- cambiare quando vuole: chi segnala "rotta" e poi scopre che funziona
-- deve poter rimediare. Come effetto secondario, nessuno può più gonfiare
-- il conteggio premendo lo stesso pulsante venti volte.
--
-- Incolla tutto nel SQL Editor di Supabase e premi Run.
-- ============================================================

-- 1. Se ci sono doppioni dal periodo precedente, tiene il più recente.
delete from public.reports a
using public.reports b
where a.target = b.target
  and a.client_id = b.client_id
  and a.created_at < b.created_at;

-- 2. D'ora in poi: uno solo per dispositivo per fontanella.
alter table public.reports drop constraint if exists reports_uno_per_dispositivo;
alter table public.reports add  constraint reports_uno_per_dispositivo
  unique (target, client_id);

-- 3. E lo si può correggere.
drop policy if exists reports_update on public.reports;
create policy reports_update on public.reports
  for update
  using (true)
  with check (
    client_id is not null and char_length(client_id) between 8 and 64
  );

-- 4. La data va aggiornata quando si corregge, altrimenti una segnalazione
--    modificata oggi continuerebbe a risultare vecchia di mesi.
create or replace function public.tocca_report()
returns trigger language plpgsql security invoker set search_path = public as $$
begin
  new.created_at = now();
  return new;
end $$;

drop trigger if exists reports_tocca on public.reports;
create trigger reports_tocca before update on public.reports
  for each row execute function public.tocca_report();

-- 5. Verifica: deve rispondere senza errori.
select count(*) as segnalazioni_totali from public.reports;
