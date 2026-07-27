-- ============================================================
-- IDRATATI — collaudo di sicurezza
--
-- Si finge un visitatore anonimo e prova a fare danni, poi prova a fare
-- le cose che invece deve poter fare. Non serve a cambiare niente:
-- serve a vedere nero su bianco che le regole funzionano davvero.
--
-- Incolla tutto nel SQL Editor di Supabase e premi Run.
-- Lascia qualche riga di prova nel database: in fondo trovi come pulirla.
-- ============================================================

do $$
declare esito text;
begin
  create temp table if not exists collaudo(prova text, risultato text);
  delete from collaudo;

  -- ---------- quello che NON deve riuscire ----------

  begin
    set local role anon;
    insert into public.fountains (lat, lon) values (45.4, 9.2);
    esito := '!!! RIUSCITO — MALE';
  exception when others then esito := 'bloccato, bene';
  end;
  reset role;
  insert into collaudo values ('1. anonimo crea una fontanella', esito);

  begin
    set local role anon;
    delete from public.fountains;
    esito := '!!! RIUSCITO — MALE';
  exception when others then esito := 'bloccato, bene';
  end;
  reset role;
  insert into collaudo values ('2. anonimo cancella le fontanelle', esito);

  begin
    set local role anon;
    perform 1 from public.submissions limit 1;
    esito := case when found then '!!! VEDE LA CODA — MALE' else 'non vede nulla, bene' end;
  exception when others then esito := 'bloccato, bene';
  end;
  reset role;
  insert into collaudo values ('3. anonimo legge la coda delle proposte', esito);

  begin
    set local role anon;
    insert into public.admins (user_id, email) values (gen_random_uuid(), 'ladro@esempio.it');
    esito := '!!! RIUSCITO — MALE';
  exception when others then esito := 'bloccato, bene';
  end;
  reset role;
  insert into collaudo values ('4. anonimo si nomina amministratore', esito);

  begin
    set local role anon;
    insert into public.photos (target, path, client_id, approved)
    values ('osm/node/1', 'prova.jpg', 'collaudo-0001', true);
    esito := '!!! RIUSCITO — MALE';
  exception when others then esito := 'bloccato, bene';
  end;
  reset role;
  insert into collaudo values ('5. anonimo pubblica una foto saltando il controllo', esito);

  begin
    set local role anon;
    insert into public.submissions (lat, lon, client_id) values (0, 0, 'collaudo-0001');
    esito := '!!! RIUSCITO — MALE';
  exception when others then esito := 'bloccato, bene';
  end;
  reset role;
  insert into collaudo values ('6. proposta in mezzo all''oceano', esito);

  -- ---------- quello che DEVE riuscire ----------

  begin
    set local role anon;
    insert into public.reports (target, status, client_id)
    values ('osm/node/999999', 'broken', 'collaudo-0001');
    esito := 'riesce, bene';
  exception when others then esito := '!!! BLOCCATO — MALE: ' || sqlerrm;
  end;
  reset role;
  insert into collaudo values ('7. anonimo segnala una fontanella rotta', esito);

  begin
    set local role anon;
    insert into public.reports (target, status, client_id)
    values ('osm/node/999999', 'missing', 'collaudo-0001');
    esito := 'riesce, bene';
  exception when others then esito := '!!! BLOCCATO — MALE: ' || sqlerrm;
  end;
  reset role;
  insert into collaudo values ('8. anonimo segnala "non la trovo"', esito);

  begin
    set local role anon;
    insert into public.reviews (target, findability, cleanliness, taste, temperature, client_id)
    values ('osm/node/999999', 4, 5, 4, 5, 'collaudo-0001');
    esito := 'riesce, bene';
  exception when others then esito := '!!! BLOCCATO — MALE: ' || sqlerrm;
  end;
  reset role;
  insert into collaudo values ('9. anonimo vota, temperatura compresa', esito);

  begin
    set local role anon;
    insert into public.submissions (lat, lon, kind, client_id)
    values (45.46, 9.19, 'fontanella', 'collaudo-0001');
    esito := 'riesce, bene';
  exception when others then esito := '!!! BLOCCATO — MALE: ' || sqlerrm;
  end;
  reset role;
  insert into collaudo values ('10. anonimo propone una fontanella', esito);
end $$;

select prova as "cosa ho provato a fare", risultato as "esito" from collaudo order by prova;

-- ============================================================
-- COME SI LEGGE
-- Le prime sei righe devono dire "bloccato" o "non vede nulla".
-- Le ultime quattro devono dire "riesce".
-- Qualsiasi riga con !!! è un problema: mandamela.
-- ============================================================

-- Pulizia delle righe lasciate dal collaudo:
delete from public.reports     where client_id = 'collaudo-0001';
delete from public.reviews     where client_id = 'collaudo-0001';
delete from public.submissions where client_id = 'collaudo-0001';
