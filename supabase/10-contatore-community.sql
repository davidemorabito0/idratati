-- ============================================================
-- 10 — Il contatore della community
--
-- Serve alla riga che compare sulla schermata d'apertura.
-- Conta i gesti delle persone — voti, segnalazioni, foto approvate,
-- fontanelle proposte e accettate — e NON le fontanelle totali:
-- quelle sono per il 99% OpenStreetMap, e un "103.000" non racconta
-- nessuna appartenenza a chi apre l'app.
--
-- Una vista sola invece di quattro conteggi separati: all'avvio
-- dell'app si paga una richiesta, non quattro.
--
-- security_invoker = off: la vista gira con i permessi di chi l'ha
-- creata, così può contare anche le righe che il pubblico non ha il
-- diritto di leggere una per una (le proposte in attesa, le foto non
-- ancora approvate). Esce solo un numero, mai il contenuto.
-- ============================================================

create or replace view v_community
with (security_invoker = off) as
select
  (select count(*) from reviews)                              as voti,
  (select count(*) from reports)                              as segnalazioni,
  (select count(*) from photos  where approved)               as foto,
  (select count(*) from submissions where state = 'approved') as fontanelle,
  (select count(*) from reviews)
  + (select count(*) from reports)
  + (select count(*) from photos where approved)
  + (select count(*) from submissions where state = 'approved') as totale;

grant select on v_community to anon, authenticated;
