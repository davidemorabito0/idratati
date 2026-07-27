-- ============================================================
-- IDRATATI — aggiornamento 6
-- Segnalazioni di problema: quando qualcosa non va e non è lo stato
-- della fontanella. Il segnaposto nel posto sbagliato, una foto che
-- non c'entra niente, un nome errato, un commento fuori luogo.
-- Incolla tutto nel SQL Editor di Supabase e premi Run.
-- ============================================================

create table if not exists public.problemi (
  id          uuid primary key default gen_random_uuid(),
  target      text not null,
  motivo      text not null,
  nota        text check (char_length(nota) <= 600),
  photo_path  text,
  photo_url   text,
  client_id   text,
  device      text,
  distanza    int,
  stato       text not null default 'aperto'
              check (stato in ('aperto','risolto','ignorato')),
  created_at  timestamptz not null default now(),
  chiuso_il   timestamptz,
  chiuso_da   uuid references auth.users(id)
);

create index if not exists problemi_aperti_idx
  on public.problemi (stato, created_at desc);
create index if not exists problemi_target_idx
  on public.problemi (target);

alter table public.problemi enable row level security;

-- Chiunque può segnalare un problema; solo l'amministratore li legge.
drop policy if exists problemi_insert on public.problemi;
create policy problemi_insert on public.problemi for insert with check (
  char_length(motivo) between 2 and 60
  and (nota is null or char_length(nota) <= 600)
  and stato = 'aperto'
);

drop policy if exists problemi_admin on public.problemi;
create policy problemi_admin on public.problemi for all to authenticated
  using (public.is_admin()) with check (public.is_admin());

-- Stesso freno anti-abuso delle altre tabelle: 30 all'ora per dispositivo.
drop trigger if exists problemi_rl on public.problemi;
create trigger problemi_rl before insert on public.problemi
  for each row execute function public.rate_limit();

-- Il codice del dispositivo non è affare di chi non ha fatto l'accesso.
revoke select (client_id) on public.problemi from anon;

notify pgrst, 'reload schema';

-- Verifica: deve rispondere senza errori, con zero righe.
select count(*) as problemi_aperti from public.problemi where stato = 'aperto';
