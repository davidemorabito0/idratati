-- ============================================================
-- IDRATATI — aggiornamento 7
-- Meno dati addosso a chi contribuisce.
--
-- Tre cose cambiano, e nessuna toglie niente alla moderazione:
--   · la distanza non arriva piu' al metro ma a scaglioni. Le coordinate
--     delle fontanelle sono pubbliche: una distanza esatta disegna un
--     cerchio attorno a chi ha segnalato, e due cerchi fanno un punto.
--     Per sapere se era li' davanti bastano quattro gradini.
--   · il dispositivo non e' piu' il modello ma "telefono" o "computer".
--     La domanda vera e' sempre stata solo quella. Come effetto
--     secondario, il commento nell'aggiornamento 5 torna vero.
--   · sparisce reviews.flow, rimpiazzata da temperature e non piu'
--     letta da nessuno. Un dato raccolto e mai usato e' solo un rischio.
--
-- E si chiude un buco: su dettagli il codice del dispositivo era
-- leggibile da chiunque avesse la chiave pubblica. Su tutte le altre
-- tabelle era gia' revocato; li' era sfuggito.
--
-- >>> IMPORTANTISSIMO: PRIMA carica su GitHub index.html e admin.html
-- >>> nuovi, ASPETTA che il sito sia aggiornato, e SOLO DOPO lancia
-- >>> questo file. Al contrario, per qualche minuto il sito vecchio
-- >>> manderebbe i metri esatti e il database glieli rifiuterebbe.
--
-- Incolla tutto nel SQL Editor di Supabase e premi Run.
-- ============================================================

-- ------------------------------------------------------------
-- 1. I DATI GIA' RACCOLTI, RIPORTATI AGLI SCAGLIONI
--    Non si buttano: si arrotondano. Il valore preciso sparisce
--    davvero, anche dai backup futuri.
-- ------------------------------------------------------------
do $$
declare t text;
begin
  foreach t in array array['reports','reviews','photos','submissions','problemi','dettagli']
  loop
    execute format($f$
      update public.%I set distanza =
        case when distanza is null then null
             when distanza <=   50 then 50
             when distanza <=  200 then 200
             when distanza <= 1000 then 1000
             else 99999 end
      where distanza is not null
        and distanza not in (50, 200, 1000, 99999);
    $f$, t);

    execute format($f$
      update public.%I set device =
        case when device is null then null
             when device ~* 'iphone|ipad|ipod|android|mobile' then 'telefono'
             else 'computer' end
      where device is not null
        and device not in ('telefono', 'computer');
    $f$, t);
  end loop;
end $$;

-- ------------------------------------------------------------
-- 2. E D'ORA IN POI SI PUO' SCRIVERE SOLO COSI'
--    Il vincolo sta nel database, non nel JavaScript: cosi' vale
--    anche per chi si scrive le richieste a mano con la chiave
--    pubblica, che e' l'unico modo in cui conta davvero.
-- ------------------------------------------------------------
do $$
declare t text;
begin
  foreach t in array array['reports','reviews','photos','submissions','problemi','dettagli']
  loop
    execute format('alter table public.%I drop constraint if exists %I;', t, t||'_distanza_scaglioni');
    execute format($f$
      alter table public.%I add constraint %I
        check (distanza is null or distanza in (50, 200, 1000, 99999));
    $f$, t, t||'_distanza_scaglioni');

    execute format('alter table public.%I drop constraint if exists %I;', t, t||'_device_due_valori');
    execute format($f$
      alter table public.%I add constraint %I
        check (device is null or device in ('telefono', 'computer'));
    $f$, t, t||'_device_due_valori');
  end loop;
end $$;

-- ------------------------------------------------------------
-- 3. LA COLONNA MORTA
--    v_reviews usa temperature dall'aggiornamento 2. flow non lo
--    legge ne' l'app ne' il pannello: verificato in tutti e due i file.
-- ------------------------------------------------------------
drop view if exists public.v_reviews;
alter table public.reviews drop column if exists flow;

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

grant select on public.v_reviews to anon, authenticated;

-- ------------------------------------------------------------
-- 4. IL BUCO SU dettagli
--    dettagli_read e' "using (true)" perche' la vista v_dettagli gira
--    con i permessi di chi la chiama e le servono target, accessibile
--    e cani. Ma insieme passavano anche client_id, device e distanza:
--    bastava la chiave pubblica per scaricare la tabella e ricostruire
--    quali fontanelle ha visitato un certo apparecchio.
--    La vista continua a funzionare: quelle tre colonne non le usa.
-- ------------------------------------------------------------
revoke select (client_id, device, distanza) on public.dettagli from anon;

notify pgrst, 'reload schema';

-- ============================================================
-- VERIFICA — dovrebbero uscire solo scaglioni e solo due dispositivi,
-- e la riga finale deve dire "chiuso".
-- ============================================================
select 'distanze' as cosa, distanza::text as valore, count(*)
  from public.reports group by 2
union all
select 'dispositivi', coalesce(device,'(vuoto)'), count(*)
  from public.reports group by 2
union all
select 'colonna flow',
  case when exists (select 1 from information_schema.columns
                    where table_schema='public' and table_name='reviews'
                      and column_name='flow')
       then '!!! C E ANCORA' else 'eliminata' end, 1
union all
select 'client_id su dettagli',
  case when exists (select 1 from information_schema.column_privileges
                    where grantee='anon' and table_schema='public'
                      and table_name='dettagli' and column_name='client_id'
                      and privilege_type='SELECT')
       then '!!! ANCORA LEGGIBILE' else 'chiuso' end, 1
order by 1, 2;
