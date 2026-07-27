-- ============================================================
-- IDRATATI — aggiornamento 5
-- Al posto del codice anonimo, due informazioni che servono davvero
-- a decidere se fidarsi di un contributo:
--   · con che tipo di dispositivo è arrivato
--   · se chi l'ha mandato era davvero lì, oppure a chilometri di distanza
-- Incolla tutto nel SQL Editor di Supabase e premi Run.
-- ============================================================

-- "telefono" / "computer": niente di più, nessuna impronta identificativa.
alter table public.reports     add column if not exists device text;
alter table public.reviews     add column if not exists device text;
alter table public.photos      add column if not exists device text;
alter table public.submissions add column if not exists device text;

-- Quanti metri c'erano fra chi ha mandato il contributo e la fontanella,
-- secondo il suo GPS. Vuoto se la posizione non era disponibile.
alter table public.reports     add column if not exists distanza int;
alter table public.reviews     add column if not exists distanza int;
alter table public.photos      add column if not exists distanza int;
alter table public.submissions add column if not exists distanza int;

-- Verifica: devono comparire le colonne nuove.
select column_name
from information_schema.columns
where table_schema = 'public' and table_name = 'photos'
order by column_name;
