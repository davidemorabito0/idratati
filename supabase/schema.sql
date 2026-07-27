-- ============================================================
-- IDRATATI — schema Supabase
-- Incolla TUTTO questo file nel SQL Editor di Supabase e premi Run.
-- Poi leggi la sezione finale per registrare il tuo utente admin.
-- ============================================================

create extension if not exists pgcrypto;

-- ------------------------------------------------------------
-- 1. ADMIN
-- ------------------------------------------------------------
create table if not exists public.admins (
  user_id    uuid primary key references auth.users(id) on delete cascade,
  email      text,
  created_at timestamptz not null default now()
);

create or replace function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (select 1 from public.admins a where a.user_id = auth.uid());
$$;

grant execute on function public.is_admin() to anon, authenticated;

-- ------------------------------------------------------------
-- 2. PUNTI D'ACQUA
--    Una riga può essere:
--      a) un OVERRIDE di un punto OpenStreetMap  -> osm_id valorizzato
--      b) una fontanella CUSTOM approvata da te  -> osm_id null
-- ------------------------------------------------------------
create table if not exists public.fountains (
  id             uuid primary key default gen_random_uuid(),
  osm_id         text unique,
  lat            double precision not null,
  lon            double precision not null,
  kind           text not null default 'fontanella'
                 check (kind in ('fontanella','casa')),
  name           text,
  notes          text,
  status         text not null default 'unknown'
                 check (status in ('ok','broken','removed','unknown')),
  status_locked  boolean not null default false,  -- true = i voti utenti non cambiano lo stato
  fee            text check (fee in ('free','paid') or fee is null),
  requires_card  boolean not null default false,  -- tessera sanitaria
  potable        boolean,
  hidden         boolean not null default false,
  photo_url      text,
  source         text not null default 'admin',
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now()
);

create index if not exists fountains_geo_idx on public.fountains (lat, lon);
create index if not exists fountains_osm_idx on public.fountains (osm_id);

create or replace function public.touch_updated_at()
returns trigger language plpgsql as $$
begin new.updated_at = now(); return new; end; $$;

drop trigger if exists fountains_touch on public.fountains;
create trigger fountains_touch before update on public.fountains
  for each row execute function public.touch_updated_at();

-- ------------------------------------------------------------
-- 3. SEGNALAZIONI DI STATO  (utente: "funziona" / "è rotta")
--    target = 'osm/node/123456'  oppure  'db/<uuid>'
-- ------------------------------------------------------------
create table if not exists public.reports (
  id         uuid primary key default gen_random_uuid(),
  target     text not null,
  status     text not null check (status in ('ok','broken')),
  note       text,
  client_id  text not null,
  created_at timestamptz not null default now()
);
create index if not exists reports_target_idx on public.reports (target, created_at desc);

-- ------------------------------------------------------------
-- 4. RECENSIONI (stelle multi-parametro)
-- ------------------------------------------------------------
create table if not exists public.reviews (
  id           uuid primary key default gen_random_uuid(),
  target       text not null,
  findability  int check (findability  between 1 and 5),
  cleanliness  int check (cleanliness  between 1 and 5),
  taste        int check (taste        between 1 and 5),
  flow         int check (flow         between 1 and 5),
  comment      text check (char_length(comment) <= 400),
  client_id    text not null,
  approved     boolean not null default true,
  created_at   timestamptz not null default now()
);
create index if not exists reviews_target_idx on public.reviews (target, created_at desc);

-- ------------------------------------------------------------
-- 5. FOTO (visibili solo dopo approvazione)
-- ------------------------------------------------------------
create table if not exists public.photos (
  id         uuid primary key default gen_random_uuid(),
  target     text not null,
  path       text not null,
  url        text,
  client_id  text,
  approved   boolean not null default false,
  created_at timestamptz not null default now()
);
create index if not exists photos_target_idx on public.photos (target) where approved;

-- ------------------------------------------------------------
-- 6. PROPOSTE DI NUOVE FONTANELLE (coda di moderazione)
-- ------------------------------------------------------------
create table if not exists public.submissions (
  id          uuid primary key default gen_random_uuid(),
  lat         double precision not null,
  lon         double precision not null,
  kind        text not null default 'fontanella' check (kind in ('fontanella','casa')),
  name        text,
  note        text check (char_length(note) <= 400),
  photo_path  text,
  client_id   text,
  state       text not null default 'pending' check (state in ('pending','approved','rejected')),
  created_at  timestamptz not null default now(),
  reviewed_at timestamptz,
  reviewed_by uuid references auth.users(id)
);
create index if not exists submissions_state_idx on public.submissions (state, created_at desc);

-- ------------------------------------------------------------
-- 7. ANTI-SPAM: max 30 contributi/ora per dispositivo
-- ------------------------------------------------------------
create or replace function public.rate_limit()
returns trigger language plpgsql security definer set search_path = public as $$
declare n int;
begin
  if new.client_id is null then return new; end if;
  execute format(
    'select count(*) from public.%I where client_id = $1 and created_at > now() - interval ''1 hour''',
    tg_table_name)
  into n using new.client_id;
  if n >= 30 then
    raise exception 'Troppe segnalazioni ravvicinate. Riprova tra un''ora.';
  end if;
  return new;
end; $$;

drop trigger if exists reports_rl     on public.reports;
drop trigger if exists reviews_rl     on public.reviews;
drop trigger if exists submissions_rl on public.submissions;
drop trigger if exists photos_rl      on public.photos;
create trigger reports_rl     before insert on public.reports     for each row execute function public.rate_limit();
create trigger reviews_rl     before insert on public.reviews     for each row execute function public.rate_limit();
create trigger submissions_rl before insert on public.submissions for each row execute function public.rate_limit();
create trigger photos_rl      before insert on public.photos      for each row execute function public.rate_limit();

-- ------------------------------------------------------------
-- 8. VISTE AGGREGATE (quello che legge l'app pubblica)
-- ------------------------------------------------------------
create or replace view public.v_status as
select
  target,
  count(*) filter (where status = 'ok'     and created_at > now() - interval '180 days') as ok_votes,
  count(*) filter (where status = 'broken' and created_at > now() - interval '180 days') as broken_votes,
  max(created_at) as last_report
from public.reports
group by target;

create or replace view public.v_reviews as
select
  target,
  count(*)                                as n,
  round(avg(findability)::numeric, 1)     as findability,
  round(avg(cleanliness)::numeric, 1)     as cleanliness,
  round(avg(taste)::numeric, 1)           as taste,
  round(avg(flow)::numeric, 1)            as flow,
  round(avg((coalesce(findability,3) + coalesce(cleanliness,3)
           + coalesce(taste,3) + coalesce(flow,3))::numeric / 4), 1) as overall
from public.reviews
where approved
group by target;

grant select on public.v_status, public.v_reviews to anon, authenticated;

-- ------------------------------------------------------------
-- 9. ROW LEVEL SECURITY
--    Regola d'oro: chiunque può SEGNALARE, solo l'admin può MODIFICARE.
-- ------------------------------------------------------------
alter table public.admins      enable row level security;
alter table public.fountains   enable row level security;
alter table public.reports     enable row level security;
alter table public.reviews     enable row level security;
alter table public.photos      enable row level security;
alter table public.submissions enable row level security;

-- admins: leggibile solo da se stessi, nessuna scrittura dal client
drop policy if exists admins_self on public.admins;
create policy admins_self on public.admins
  for select using (user_id = auth.uid());

-- fountains: tutti leggono i punti visibili, solo admin scrive
drop policy if exists fountains_read       on public.fountains;
drop policy if exists fountains_admin_all  on public.fountains;
create policy fountains_read on public.fountains
  for select using (not hidden or public.is_admin());
create policy fountains_admin_all on public.fountains
  for all using (public.is_admin()) with check (public.is_admin());

-- reports: chiunque inserisce e legge (servono per l'aggregato)
drop policy if exists reports_read   on public.reports;
drop policy if exists reports_insert on public.reports;
drop policy if exists reports_admin  on public.reports;
create policy reports_read   on public.reports for select using (true);
create policy reports_insert on public.reports for insert with check (
  client_id is not null and char_length(client_id) between 8 and 64
);
create policy reports_admin  on public.reports for all
  using (public.is_admin()) with check (public.is_admin());

-- reviews: chiunque inserisce, tutti leggono le approvate, admin vede tutto
drop policy if exists reviews_read   on public.reviews;
drop policy if exists reviews_insert on public.reviews;
drop policy if exists reviews_admin  on public.reviews;
create policy reviews_read   on public.reviews for select using (approved or public.is_admin());
create policy reviews_insert on public.reviews for insert with check (
  client_id is not null and char_length(client_id) between 8 and 64
);
create policy reviews_admin  on public.reviews for all
  using (public.is_admin()) with check (public.is_admin());

-- photos: chiunque carica, ma si vedono solo dopo approvazione
drop policy if exists photos_read   on public.photos;
drop policy if exists photos_insert on public.photos;
drop policy if exists photos_admin  on public.photos;
create policy photos_read   on public.photos for select using (approved or public.is_admin());
create policy photos_insert on public.photos for insert with check (true);
create policy photos_admin  on public.photos for all
  using (public.is_admin()) with check (public.is_admin());

-- submissions: chiunque propone, SOLO l'admin legge la coda
drop policy if exists submissions_insert on public.submissions;
drop policy if exists submissions_admin  on public.submissions;
create policy submissions_insert on public.submissions for insert with check (
  lat between 35 and 48 and lon between 6 and 19
);
create policy submissions_admin on public.submissions for all
  using (public.is_admin()) with check (public.is_admin());

-- ------------------------------------------------------------
-- 10. APPROVAZIONE PROPOSTA -> diventa fontanella pubblica
-- ------------------------------------------------------------
create or replace function public.approve_submission(sub_id uuid)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare s public.submissions; new_id uuid;
begin
  if not public.is_admin() then
    raise exception 'Non autorizzato';
  end if;

  select * into s from public.submissions where id = sub_id;
  if not found then raise exception 'Proposta inesistente'; end if;

  insert into public.fountains (lat, lon, kind, name, notes, status, source)
  values (s.lat, s.lon, s.kind, s.name, s.note, 'ok', 'utente')
  returning id into new_id;

  update public.submissions
     set state = 'approved', reviewed_at = now(), reviewed_by = auth.uid()
   where id = sub_id;

  return new_id;
end; $$;

grant execute on function public.approve_submission(uuid) to authenticated;

-- ------------------------------------------------------------
-- 11. STORAGE per le foto
-- ------------------------------------------------------------
insert into storage.buckets (id, name, public)
values ('photos', 'photos', true)
on conflict (id) do nothing;

drop policy if exists photos_pub_read   on storage.objects;
drop policy if exists photos_anon_write on storage.objects;
drop policy if exists photos_admin_all  on storage.objects;

create policy photos_pub_read on storage.objects
  for select using (bucket_id = 'photos');
create policy photos_anon_write on storage.objects
  for insert with check (bucket_id = 'photos');
create policy photos_admin_all on storage.objects
  for all using (bucket_id = 'photos' and public.is_admin())
  with check (bucket_id = 'photos' and public.is_admin());

-- ============================================================
-- ULTIMO PASSO — RENDITI ADMIN
-- ============================================================
-- 1) Supabase > Authentication > Users > "Add user"
--    email: info@davidemorabito.com   +  una password lunga
--    (spunta "Auto Confirm User")
-- 2) Authentication > Providers > Email: DISATTIVA "Enable signup".
--    Così nessun altro può crearsi un account.
-- 3) Torna qui e lancia, sostituendo l'email se serve:
--
--    insert into public.admins (user_id, email)
--    select id, email from auth.users where email = 'info@davidemorabito.com'
--    on conflict (user_id) do nothing;
--
-- 4) Verifica:  select * from public.admins;
-- ============================================================
