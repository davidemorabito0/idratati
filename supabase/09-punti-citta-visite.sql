-- ============================================================
-- IDRATATI — aggiornamento 8
-- La base dati per il pannello nuovo: dove sta ogni fontanella
-- attiva, in che citta' si trova, e quanta gente passa.
--
-- Tre cose nuove:
--   · citta  — 101 citta' italiane con centro, raggio e quante
--     fontanelle sono mappate dentro quel raggio. I conteggi vengono
--     dallo snapshot in data/, contati uno per uno, non stimati.
--   · punti  — una riga per ogni fontanella che ha ricevuto attivita',
--     con le sue coordinate e la citta'. Le segnalazioni portano solo
--     "osm/node/123": senza questa tabella non si puo' dire in che
--     citta' e' successo niente. Le coordinate sono quelle della
--     fontanella, pubbliche: non aggiungono nulla su chi contribuisce.
--   · visite — tre colonne e nessun identificatore. L'app tiene in
--     localStorage il segno "oggi ho gia' contato" e chiama ping() una
--     volta al giorno: l'unicita' la garantisce il telefono, qui resta
--     solo un numero. Visitatori unici al giorno senza tracciare
--     nessuno.
--
-- Piu' le viste che il pannello legge, per non far fare i conti al
-- browser.
--
-- Si puo' lanciare in qualsiasi momento: non tocca niente di esistente
-- e il sito attuale continua a funzionare identico. La modifica a
-- index.html che chiama ping() e punto() arriva dopo, e finche' non c'e'
-- le tabelle restano semplicemente vuote.
-- ============================================================

-- ------------------------------------------------------------
-- 1. LE CITTA'
-- ------------------------------------------------------------
create table if not exists public.citta (
  nome               text primary key,
  provincia          text not null,
  lat                double precision not null,
  lon                double precision not null,
  raggio_km          integer not null,
  fontanelle_mappate integer not null default 0
);

-- upsert e non truncate: il file si puo' rilanciare quando lo snapshot
-- viene rigenerato, e aggiorna i conteggi senza svuotare la tabella.
insert into public.citta (nome, provincia, lat, lon, raggio_km, fontanelle_mappate) values
  ('Roma', 'RM', 41.902800, 12.496400, 14, 1906),
  ('Milano', 'MI', 45.464200, 9.190000, 10, 879),
  ('Napoli', 'NA', 40.851800, 14.268100, 9, 148),
  ('Torino', 'TO', 45.070300, 7.686900, 9, 903),
  ('Palermo', 'PA', 38.115700, 13.361500, 9, 63),
  ('Genova', 'GE', 44.405600, 8.946300, 10, 499),
  ('Bologna', 'BO', 44.494900, 11.342600, 8, 170),
  ('Firenze', 'FI', 43.769600, 11.255800, 8, 292),
  ('Bari', 'BA', 41.117100, 16.871900, 8, 75),
  ('Catania', 'CT', 37.507900, 15.083000, 8, 397),
  ('Verona', 'VR', 45.438400, 10.991600, 7, 196),
  ('Venezia', 'VE', 45.440800, 12.315500, 8, 207),
  ('Messina', 'ME', 38.193800, 15.554000, 8, 63),
  ('Padova', 'PD', 45.406400, 11.876800, 7, 97),
  ('Trieste', 'TS', 45.649500, 13.776800, 7, 248),
  ('Brescia', 'BS', 45.541600, 10.211800, 7, 283),
  ('Parma', 'PR', 44.801500, 10.327900, 6, 45),
  ('Prato', 'PO', 43.877700, 11.102200, 6, 83),
  ('Modena', 'MO', 44.647100, 10.925200, 6, 41),
  ('Reggio Calabria', 'RC', 38.110500, 15.661300, 7, 21),
  ('Reggio Emilia', 'RE', 44.698900, 10.629700, 6, 98),
  ('Perugia', 'PG', 43.110700, 12.390800, 7, 94),
  ('Ravenna', 'RA', 44.418400, 12.203500, 7, 18),
  ('Livorno', 'LI', 43.548500, 10.310600, 6, 126),
  ('Rimini', 'RN', 44.067800, 12.569500, 6, 58),
  ('Cagliari', 'CA', 39.223800, 9.121700, 7, 75),
  ('Foggia', 'FG', 41.462200, 15.544600, 6, 6),
  ('Ferrara', 'FE', 44.838100, 11.619800, 6, 54),
  ('Salerno', 'SA', 40.682400, 14.768100, 6, 95),
  ('Latina', 'LT', 41.467600, 12.903700, 6, 47),
  ('Giugliano in Campania', 'NA', 40.928000, 14.195000, 5, 68),
  ('Monza', 'MB', 45.584500, 9.274400, 5, 131),
  ('Sassari', 'SS', 40.725900, 8.555600, 6, 14),
  ('Bergamo', 'BG', 45.698300, 9.677300, 6, 234),
  ('Pescara', 'PE', 42.464300, 14.214200, 6, 112),
  ('Trento', 'TN', 46.067900, 11.121100, 6, 297),
  ('Forlì', 'FC', 44.222600, 12.040700, 6, 57),
  ('Siracusa', 'SR', 37.075500, 15.286600, 6, 49),
  ('Vicenza', 'VI', 45.545500, 11.535400, 6, 111),
  ('Terni', 'TR', 42.563600, 12.642700, 5, 39),
  ('Bolzano', 'BZ', 46.498300, 11.354800, 5, 143),
  ('Piacenza', 'PC', 45.052600, 9.692900, 5, 24),
  ('Novara', 'NO', 45.446900, 8.622000, 5, 50),
  ('Ancona', 'AN', 43.615800, 13.518900, 6, 54),
  ('Andria', 'BT', 41.227000, 16.296000, 5, 37),
  ('Udine', 'UD', 46.071100, 13.234600, 5, 163),
  ('Arezzo', 'AR', 43.463300, 11.879600, 5, 31),
  ('Cesena', 'FC', 44.139100, 12.243100, 5, 57),
  ('Lecce', 'LE', 40.351500, 18.175000, 5, 22),
  ('Pesaro', 'PU', 43.910200, 12.913200, 5, 39),
  ('Barletta', 'BT', 41.314000, 16.281000, 5, 50),
  ('Alessandria', 'AL', 44.913300, 8.615100, 5, 30),
  ('La Spezia', 'SP', 44.102400, 9.824100, 5, 79),
  ('Pisa', 'PI', 43.716100, 10.396600, 5, 125),
  ('Catanzaro', 'CZ', 38.909800, 16.587700, 5, 16),
  ('Pistoia', 'PT', 43.933000, 10.917900, 5, 55),
  ('Guidonia Montecelio', 'RM', 41.993000, 12.723000, 5, 24),
  ('Lucca', 'LU', 43.843000, 10.507900, 5, 111),
  ('Brindisi', 'BR', 40.632700, 17.941800, 5, 17),
  ('Torre del Greco', 'NA', 40.786900, 14.367000, 4, 14),
  ('Treviso', 'TV', 45.666900, 12.243000, 5, 80),
  ('Busto Arsizio', 'VA', 45.612000, 8.851800, 4, 46),
  ('Como', 'CO', 45.808100, 9.085200, 5, 124),
  ('Marsala', 'TP', 37.797000, 12.437900, 5, 5),
  ('Grosseto', 'GR', 42.763500, 11.112900, 5, 12),
  ('Sesto San Giovanni', 'MI', 45.533300, 9.233300, 4, 112),
  ('Pozzuoli', 'NA', 40.844300, 14.092100, 4, 25),
  ('Varese', 'VA', 45.820600, 8.825100, 5, 64),
  ('Fiumicino', 'RM', 41.771400, 12.240000, 5, 36),
  ('Casoria', 'NA', 40.907000, 14.293000, 4, 14),
  ('Asti', 'AT', 44.900900, 8.206500, 4, 33),
  ('Caserta', 'CE', 41.072300, 14.332700, 5, 47),
  ('Cinisello Balsamo', 'MI', 45.557000, 9.217000, 4, 79),
  ('Gela', 'CL', 37.066500, 14.251000, 4, 2),
  ('Aprilia', 'LT', 41.594000, 12.654000, 4, 7),
  ('Ragusa', 'RG', 36.926900, 14.725500, 5, 24),
  ('Pavia', 'PV', 45.184700, 9.158200, 4, 45),
  ('Cremona', 'CR', 45.133200, 10.022700, 4, 19),
  ('Carpi', 'MO', 44.783000, 10.885000, 4, 42),
  ('Quartu Sant''Elena', 'CA', 39.241000, 9.184000, 4, 13),
  ('Lamezia Terme', 'CZ', 38.965000, 16.309000, 4, 17),
  ('Altamura', 'BA', 40.827000, 16.554000, 4, 16),
  ('Imola', 'BO', 44.353000, 11.714000, 4, 65),
  ('L''Aquila', 'AQ', 42.349800, 13.399500, 5, 41),
  ('Massa', 'MS', 44.035000, 10.141000, 4, 54),
  ('Trapani', 'TP', 38.017600, 12.536500, 5, 6),
  ('Viterbo', 'VT', 42.420700, 12.107700, 4, 26),
  ('Cosenza', 'CS', 39.298300, 16.253900, 5, 82),
  ('Potenza', 'PZ', 40.640800, 15.805600, 4, 29),
  ('Campobasso', 'CB', 41.560300, 14.662700, 4, 39),
  ('Aosta', 'AO', 45.737200, 7.320600, 4, 49),
  ('Matera', 'MT', 40.666400, 16.604300, 4, 41),
  ('Savona', 'SV', 44.309100, 8.477200, 4, 76),
  ('Benevento', 'BN', 41.129700, 14.782600, 4, 8),
  ('Avellino', 'AV', 40.914600, 14.790300, 4, 13),
  ('Siena', 'SI', 43.318800, 11.330800, 4, 61),
  ('Mantova', 'MN', 45.156400, 10.791400, 4, 60),
  ('Lodi', 'LO', 45.314000, 9.503000, 4, 23),
  ('Sondrio', 'SO', 46.170000, 9.870000, 4, 143),
  ('Belluno', 'BL', 46.140000, 12.217000, 4, 29),
  ('Rovigo', 'RO', 45.070000, 11.790000, 4, 5)
on conflict (nome) do update
  set provincia          = excluded.provincia,
      lat                = excluded.lat,
      lon                = excluded.lon,
      raggio_km          = excluded.raggio_km,
      fontanelle_mappate = excluded.fontanelle_mappate;

-- Dati di riferimento pubblici: nomi, coordinate e conteggi da
-- OpenStreetMap. Nessun dato di persona, quindi lettura libera,
-- scrittura solo a te. Le policy ci sono comunque: una tabella
-- senza RLS in mezzo a tutte le altre che ce l'hanno e' solo un
-- giorno in cui qualcuno si dimentica perche' faceva eccezione.
alter table public.citta enable row level security;
drop policy if exists citta_read  on public.citta;
drop policy if exists citta_admin on public.citta;
create policy citta_read  on public.citta for select using (true);
create policy citta_admin on public.citta for all    using (public.is_admin());

grant select on public.citta to anon, authenticated;
grant all    on public.citta to authenticated;
-- Supabase concede d'ufficio i permessi ad anon su ogni tabella nuova.
-- L'RLS qui sopra basterebbe, ma due strati sono meglio di uno: se un
-- giorno una policy viene allargata per sbaglio, il permesso mancante
-- e' la seconda rete.
revoke insert, update, delete, truncate on public.citta from anon;


-- A quale citta' appartiene un punto: la piu' vicina fra quelle che se
-- lo tengono dentro il raggio. Fuori da tutte restituisce null, ed e' il
-- caso piu' comune: l'89% delle fontanelle dello snapshot sta in paesi e
-- campagna, fuori dalle 101 aree urbane.
create or replace function public.citta_di(p_lat double precision, p_lon double precision)
returns text
language sql stable
set search_path to 'public'
as $$
  select c.nome
    from public.citta c
   where 2 * 6371 * asin(sqrt(
           power(sin(radians(p_lat - c.lat) / 2), 2)
           + cos(radians(c.lat)) * cos(radians(p_lat))
           * power(sin(radians(p_lon - c.lon) / 2), 2)
         )) <= c.raggio_km
   order by 2 * 6371 * asin(sqrt(
           power(sin(radians(p_lat - c.lat) / 2), 2)
           + cos(radians(c.lat)) * cos(radians(p_lat))
           * power(sin(radians(p_lon - c.lon) / 2), 2)
         ))
   limit 1;
$$;

-- ------------------------------------------------------------
-- 2. I PUNTI CON ATTIVITA'
-- ------------------------------------------------------------
create table if not exists public.punti (
  target      text primary key,
  lat         double precision not null,
  lon         double precision not null,
  nome        text,
  kind        text,
  citta       text references public.citta(nome) on delete set null,
  visto_prima timestamptz not null default now(),
  visto_dopo  timestamptz not null default now(),
  constraint punti_target_lungo   check (char_length(target) between 4 and 80),
  constraint punti_nome_breve     check (nome is null or char_length(nome) <= 120),
  constraint punti_kind_valido    check (kind is null or kind in ('casa','fontanella')),
  constraint punti_lat_valida     check (lat between -90 and 90),
  constraint punti_lon_valida     check (lon between -180 and 180)
);
create index if not exists punti_citta_idx on public.punti (citta);

-- la citta' non la scrive il client: la calcola il database dalle coordinate
create or replace function public.punti_citta()
returns trigger language plpgsql set search_path to 'public' as $$
begin
  new.citta := public.citta_di(new.lat, new.lon);
  return new;
end $$;

drop trigger if exists punti_citta_tg on public.punti;
create trigger punti_citta_tg before insert or update of lat, lon
  on public.punti for each row execute function public.punti_citta();

alter table public.punti enable row level security;
drop policy if exists punti_read  on public.punti;
drop policy if exists punti_admin on public.punti;
create policy punti_read  on public.punti for select using (true);
create policy punti_admin on public.punti for all    using (public.is_admin());

grant select on public.punti to anon, authenticated;
grant all    on public.punti to authenticated;
-- Supabase concede d'ufficio i permessi ad anon su ogni tabella nuova.
-- L'RLS qui sopra basterebbe, ma due strati sono meglio di uno: se un
-- giorno una policy viene allargata per sbaglio, il permesso mancante
-- e' la seconda rete.
revoke insert, update, delete, truncate on public.punti from anon;

-- L'app la chiama dopo ogni contributo. Le scritture passano da qui e
-- non dalla tabella, cosi' anon non ha bisogno di poterci scrivere.
create or replace function public.punto(
  p_target text, p_lat double precision, p_lon double precision,
  p_nome text default null, p_kind text default null)
returns void
language plpgsql security definer
set search_path to 'public'
as $$
begin
  if p_target is null or char_length(p_target) < 4 or char_length(p_target) > 80 then
    raise exception 'Fontanella non valida.';
  end if;
  if p_lat is null or p_lon is null
     or p_lat < -90 or p_lat > 90 or p_lon < -180 or p_lon > 180 then
    raise exception 'Coordinate non valide.';
  end if;

  insert into public.punti (target, lat, lon, nome, kind)
  values (p_target, p_lat, p_lon, nullif(left(coalesce(p_nome,''), 120), ''),
          case when p_kind in ('casa','fontanella') then p_kind end)
  on conflict (target) do update
    set visto_dopo = now(),
        nome       = coalesce(public.punti.nome, excluded.nome),
        kind       = coalesce(public.punti.kind, excluded.kind);
end $$;

revoke all on function public.punto(text, double precision, double precision, text, text) from public;
grant execute on function public.punto(text, double precision, double precision, text, text) to anon, authenticated;

-- ------------------------------------------------------------
-- 3. LE VISITE
--    Nessun identificatore, nessuna riga per persona: un contatore.
-- ------------------------------------------------------------
create table if not exists public.visite (
  giorno      date not null,
  dispositivo text not null,
  quante      integer not null default 0,
  primary key (giorno, dispositivo),
  constraint visite_dispositivo check (dispositivo in ('telefono', 'computer')),
  constraint visite_quante_sane check (quante >= 0)
);

alter table public.visite enable row level security;
drop policy if exists visite_admin on public.visite;
create policy visite_admin on public.visite for all using (public.is_admin());
-- anon non legge e non scrive: passa solo da ping(), che e' security
-- definer e quindi non ha bisogno di permessi sulla tabella.
grant select on public.visite to authenticated;
revoke all on public.visite from anon;

create or replace function public.ping(p_device text)
returns void
language plpgsql security definer
set search_path to 'public'
as $$
begin
  if p_device not in ('telefono', 'computer') then
    return;                      -- niente errori all'apertura dell'app
  end if;
  insert into public.visite (giorno, dispositivo, quante)
  values (current_date, p_device, 1)
  on conflict (giorno, dispositivo) do update
    set quante = public.visite.quante + 1;
end $$;

revoke all on function public.ping(text) from public;
grant execute on function public.ping(text) to anon, authenticated;

-- ------------------------------------------------------------
-- 4. I PUNTI CHE HANNO GIA' ATTIVITA'
--    Coordinate e nomi presi dallo snapshot in data/, cercati uno per
--    uno fra i 102.952 punti: 36 su 36 trovati. Gli altri tre sono
--    fontanelle aggiunte a mano e le coordinate stanno in fountains.
-- ------------------------------------------------------------
insert into public.punti (target, lat, lon, nome, kind) values
('osm/node/10919457440', 45.4786830, 9.1533620, null, 'fontanella'),
  ('osm/node/13028194388', 45.4618260, 9.1363950, null, 'fontanella'),
  ('osm/node/13058811403', 45.4618060, 9.1361850, 'Casa dell''acqua', 'casa'),
  ('osm/node/1747484173', 38.2246690, 15.5671530, null, 'fontanella'),
  ('osm/node/1937726695', 45.4872020, 9.1568450, null, 'fontanella'),
  ('osm/node/2095675770', 45.4807840, 9.1874670, null, 'fontanella'),
  ('osm/node/2095675771', 45.4809000, 9.1865100, null, 'fontanella'),
  ('osm/node/2887034885', 45.4597760, 9.1472340, null, 'fontanella'),
  ('osm/node/2935108228', 45.4794630, 9.1426420, null, 'fontanella'),
  ('osm/node/306596229', 45.4620250, 9.1594820, null, 'fontanella'),
  ('osm/node/3154943663', 45.4619110, 9.1451660, null, 'fontanella'),
  ('osm/node/339564181', 45.4646160, 9.1924400, null, 'fontanella'),
  ('osm/node/3573223725', 45.4763660, 9.1382170, null, 'fontanella'),
  ('osm/node/3730553193', 45.4753910, 9.1330590, 'Casa dell''Acqua', 'casa'),
  ('osm/node/4080298153', 45.6498240, 13.7655160, null, 'fontanella'),
  ('osm/node/4809251642', 45.4766790, 9.1300030, null, 'fontanella'),
  ('osm/node/4809251735', 45.4767920, 9.1295560, null, 'fontanella'),
  ('osm/node/4953160498', 45.4766400, 9.1379660, null, 'fontanella'),
  ('osm/node/4953161479', 45.4620090, 9.1575870, null, 'fontanella'),
  ('osm/node/4953162335', 45.4666390, 9.1547600, null, 'fontanella'),
  ('osm/node/4953162365', 45.4721240, 9.1673710, null, 'fontanella'),
  ('osm/node/4953163064', 45.4552370, 9.1381560, null, 'fontanella'),
  ('osm/node/4953163074', 45.4777480, 9.1609990, null, 'fontanella'),
  ('osm/node/4953163133', 45.4568190, 9.1253360, null, 'fontanella'),
  ('osm/node/4953163438', 45.4647660, 9.1529470, null, 'fontanella'),
  ('osm/node/4953163451', 45.4610220, 9.1267130, null, 'fontanella'),
  ('osm/node/4953163453', 45.4651860, 9.1277440, null, 'fontanella'),
  ('osm/node/4953163493', 45.4754150, 9.1332840, null, 'fontanella'),
  ('osm/node/5601316339', 45.6519690, 13.7716430, null, 'fontanella'),
  ('osm/node/639780006', 45.4600940, 9.1287800, null, 'fontanella'),
  ('osm/node/639780016', 45.4599890, 9.1428490, null, 'fontanella'),
  ('osm/node/639780032', 45.4799800, 9.1435480, null, 'fontanella'),
  ('osm/node/660690372', 45.4585150, 9.1781840, null, 'fontanella'),
  ('osm/node/673971061', 45.4677480, 9.1817260, null, 'fontanella'),
  ('osm/node/7965881509', 45.4773970, 9.1533100, null, 'fontanella'),
  ('osm/node/9710714938', 45.4762480, 9.1377570, null, 'fontanella')
on conflict (target) do nothing;

insert into public.punti (target, lat, lon, nome, kind)
select 'db/' || f.id, f.lat, f.lon, f.name, f.kind
  from public.fountains f
 where f.lat is not null and f.lon is not null
on conflict (target) do nothing;

-- ------------------------------------------------------------
-- 5. LE VISTE CHE LEGGE IL PANNELLO
--    security_invoker: girano coi permessi di chi chiama, quindi le
--    RLS delle tabelle sotto continuano a valere. Solo authenticated.
-- ------------------------------------------------------------

-- la fascia dei numeri in cima alla home, una riga sola
create or replace view public.v_numeri with (security_invoker = on) as
select
  (select coalesce(sum(quante),0) from visite where giorno = current_date)                   as visite_oggi,
  (select coalesce(sum(quante),0) from visite where giorno = current_date - 1)               as visite_ieri,
  (select coalesce(sum(quante),0) from visite where giorno >  current_date - 7)              as visite_7,
  (select coalesce(sum(quante),0) from visite where giorno >  current_date - 30)             as visite_30,
  (select coalesce(sum(quante),0) from visite where giorno >  current_date - 90)             as visite_90,
  (select coalesce(sum(quante),0) from visite where dispositivo='telefono' and giorno > current_date - 30) as visite_telefono_30,
  (select coalesce(sum(quante),0) from visite where dispositivo='computer' and giorno > current_date - 30) as visite_computer_30,

  (select count(*) from reviews where created_at > now() - interval  '7 days')               as recensioni_7,
  (select count(*) from reviews where created_at > now() - interval '30 days')               as recensioni_30,
  (select count(*) from reviews where created_at > now() - interval '90 days')               as recensioni_90,
  (select count(*) from reviews where created_at > now() - interval '14 days'
                                  and created_at <= now() - interval  '7 days')              as recensioni_7_prima,
  (select count(*) from reviews where created_at > now() - interval '60 days'
                                  and created_at <= now() - interval '30 days')              as recensioni_30_prima,
  (select count(*) from reviews)                                                             as recensioni_totali,

  (select count(*) from reports where created_at > now() - interval  '7 days')               as segnalazioni_7,
  (select count(*) from reports where created_at > now() - interval '30 days')               as segnalazioni_30,
  (select count(*) from reports)                                                             as segnalazioni_totali,

  (select count(*) from photos)                                                              as foto_totali,
  (select count(*) from photos where approved)                                               as foto_approvate,
  (select count(*) from photos where not approved)                                           as foto_attesa,
  (select count(*) from photos where created_at > now() - interval  '7 days')                 as foto_7,
  (select count(*) from photos where created_at > now() - interval '30 days')                 as foto_30,

  (select count(*) from submissions where state = 'pending')                                 as proposte_attesa,
  (select count(*) from problemi   where stato = 'aperto')                                   as problemi_aperti,
  (select count(*) from reports    where not approved)                                       as segnalazioni_attesa,

  (select count(*) from punti)                                                               as fontanelle_attive,
  (select count(distinct citta) from punti where citta is not null)                           as citta_attive,
  (select citta from punti where citta is not null
     group by citta order by count(*) desc, citta limit 1)                                   as citta_prima,
  (select count(*) from punti p where p.citta =
     (select citta from punti where citta is not null
        group by citta order by count(*) desc, citta limit 1))                               as citta_prima_quante,

  (select count(distinct client_id) from (
     select client_id, created_at from reports  union all
     select client_id, created_at from reviews  union all
     select client_id, created_at from photos   union all
     select client_id, created_at from dettagli) t
    where created_at > now() - interval '30 days')                                           as contributori_30,
  (select count(*) from (
     select client_id from reports where device='telefono' union all
     select client_id from reviews where device='telefono') t)                                as contributi_telefono,
  (select count(*) from (
     select client_id from reports where device='computer' union all
     select client_id from reviews where device='computer') t)                                as contributi_computer;

-- il grafico degli ultimi mesi
create or replace view public.v_visite with (security_invoker = on) as
select g::date as giorno,
  coalesce((select quante from visite v where v.giorno=g::date and v.dispositivo='telefono'),0) as telefono,
  coalesce((select quante from visite v where v.giorno=g::date and v.dispositivo='computer'),0) as computer,
  coalesce((select sum(quante) from visite v where v.giorno=g::date),0)                          as totale
from generate_series(current_date - 119, current_date, interval '1 day') g
order by 1;

-- la classifica delle citta', con la copertura vera
create or replace view public.v_citta with (security_invoker = on) as
select c.nome, c.provincia, c.fontanelle_mappate,
  count(distinct p.target)                                       as attive,
  case when c.fontanelle_mappate > 0
       then round(100.0 * count(distinct p.target) / c.fontanelle_mappate, 2)
       else null end                                             as copertura_pct,
  (select count(*) from reviews r  join punti pp on pp.target=r.target  where pp.citta=c.nome) as recensioni,
  (select count(*) from photos  ph join punti pp on pp.target=ph.target where pp.citta=c.nome) as foto,
  (select round(avg(v.overall),2) from v_reviews v join punti pp on pp.target=v.target where pp.citta=c.nome) as voto_medio,
  max(p.visto_dopo)                                              as ultima_attivita
from citta c
left join punti p on p.citta = c.nome
group by c.nome, c.provincia, c.fontanelle_mappate;

-- tutto il testo scritto dagli utenti, in un posto solo
create or replace view public.v_note with (security_invoker = on) as
select 'recensione'::text as fonte, r.id::text as id, r.target, r.comment as testo,
       r.client_id, r.device, r.created_at, char_length(r.comment) as lunghezza, r.approved
  from reviews r where r.comment is not null and btrim(r.comment) <> ''
union all
select 'segnalazione', p.id::text, p.target, p.note, p.client_id, p.device, p.created_at,
       char_length(p.note), p.approved
  from reports p where p.note is not null and btrim(p.note) <> ''
union all
select 'problema', q.id::text, q.target, q.nota, q.client_id, q.device, q.created_at,
       char_length(q.nota), true
  from problemi q where q.nota is not null and btrim(q.nota) <> ''
union all
select 'proposta', s.id::text, 'db/' || s.id, s.note, s.client_id, s.device, s.created_at,
       char_length(s.note), (s.state = 'approved')
  from submissions s where s.note is not null and btrim(s.note) <> '';

-- il flusso delle ultime cose accadute
create or replace view public.v_recenti with (security_invoker = on) as
select 'recensione'::text as tipo, r.target, r.created_at as quando, r.device,
       nullif(btrim(coalesce(r.comment,'')),'') as testo,
       round(((coalesce(r.findability,3)+coalesce(r.cleanliness,3)
             +coalesce(r.taste,3)+coalesce(r.temperature,3))::numeric)/4, 1) as voto,
       null::text as url, r.approved
  from reviews r
union all
select 'foto', f.target, f.created_at, f.device, null, null, f.url, f.approved
  from photos f
union all
select 'segnalazione', s.target, s.created_at, s.device,
       nullif(btrim(coalesce(s.note,'')),''), null, s.photo_url, s.approved
  from reports s
union all
select 'proposta', 'db/' || u.id, u.created_at, u.device,
       nullif(btrim(coalesce(u.name,'') || ' ' || coalesce(u.note,'')),''), null, null,
       (u.state = 'approved')
  from submissions u;

grant select on public.v_numeri, public.v_visite, public.v_citta,
                public.v_note,   public.v_recenti to authenticated;
grant select on public.citta to anon, authenticated;

notify pgrst, 'reload schema';

-- ============================================================
-- VERIFICA
-- ============================================================
select 'citta caricate'        as cosa, count(*)::text as valore from public.citta
union all select 'fontanelle mappate in totale', sum(fontanelle_mappate)::text from public.citta
union all select 'punti con attivita', count(*)::text from public.punti
union all select 'di cui dentro una citta', count(*)::text from public.punti where citta is not null
union all select 'citta con attivita', count(distinct citta)::text from public.punti where citta is not null
union all select 'citta prima',
  (select citta || ' (' || n || ')' from
     (select citta, count(*) n from public.punti where citta is not null
       group by citta order by 2 desc, 1 limit 1) x);
