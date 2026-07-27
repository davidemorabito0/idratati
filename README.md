# IDRATATI

> **Idràtati, per rimanere idratàti.**

Un ordine e uno stato, nella stessa parola: cambia solo dove cade l'accento.
Trova la fontanella pubblica più vicina, sai se funziona **prima** di arrivarci, e ci arrivi a piedi con le mappe che usi già.

- `index.html` — l'app pubblica
- `admin.html` — il pannello riservato
- `supabase/schema.sql` — database e permessi
- `tools/build_data.py` — scarica tutte le fontanelle italiane da OpenStreetMap
- `.github/workflows/update-data.yml` — le riscarica da solo ogni mese

---

## 1. Metti in piedi il database (15 minuti, una volta sola)

1. Vai su [supabase.com](https://supabase.com), crea un progetto gratuito. Regione: **eu-central-1 (Francoforte)** — Supabase non ha datacenter in Italia, e Francoforte è il nodo europeo più vicino e meglio collegato.
2. Apri **SQL Editor**, incolla tutto `supabase/schema.sql`, premi **Run**.
3. **Authentication → Users → Add user**: la tua email e una password lunga. Spunta *Auto Confirm User*.
4. **Authentication → Providers → Email**: disattiva **Enable signup**. Da questo momento nessun altro può crearsi un account.
5. Torna nel SQL Editor e lancia:

   ```sql
   insert into public.admins (user_id, email)
   select id, email from auth.users where email = 'LA-TUA-EMAIL'
   on conflict (user_id) do nothing;
   ```

6. **Project Settings → API**: copia `Project URL` e la chiave `anon public`.
7. Incollale in cima allo `<script>` di **entrambi** i file, `index.html` e `admin.html`:

   ```js
   var CFG = {
     SUPABASE_URL: 'https://xxxxx.supabase.co',
     SUPABASE_ANON_KEY: 'eyJhbGciOi...'
   };
   ```

**La chiave anon sta nel codice ed è giusto così.** Non è una password: è un biglietto d'ingresso pubblico. Chi comanda davvero sono le policy RLS del database, che dicono "chiunque può segnalare, solo chi è nella tabella `admins` può modificare". Anche se qualcuno copia la chiave e prova a cancellare una fontanella, il database gli risponde di no. È per questo che il pannello non ha una password scritta nel JavaScript: quella si leggerebbe in tre secondi col tasto destro.

---

## 2. Scarica i dati

```bash
python3 tools/build_data.py --milano
```

Ci mette circa tre ore per tutta Italia — sono ~180 celle scaricate con calma per non pestare i piedi a Overpass. Per una prova veloce:

```bash
python3 tools/build_data.py --bbox 45.3,9.0,45.6,9.4     # solo Milano
```

Escono ~600 file dentro `data/`, uno ogni 55 km. L'app carica solo quello che ti serve: 30 KB invece di aspettare Overpass a ogni spostamento.

Poi non ci pensi più: la GitHub Action rifà tutto il primo del mese. La trovi anche nella tab **Actions → Run workflow** se vuoi forzarla.

---

## 3. Pubblica

Push su GitHub → **Settings → Pages → Deploy from branch: main / root**.

Serve HTTPS perché il browser dia la posizione, e GitHub Pages ce l'ha di suo.

Il pannello è su `tuosito.it/admin.html`. Non è linkato da nessuna parte ed è escluso da `robots.txt`, ma la vera protezione è il login.

---

## Come funziona lo stato "funzionante / rotta"

| Situazione | Cosa mostra |
|---|---|
| Tu hai deciso e messo il lucchetto | Quello che dici tu, sempre |
| 2+ segnalazioni di guasto in maggioranza | Segnata rotta, pin rosso |
| Almeno una conferma, nessuna prevalenza di guasti | Funzionante |
| Una sola segnalazione di guasto | Da verificare |
| Nessun dato | Stato sconosciuto |

I voti più vecchi di sei mesi smettono di contare: una fontanella riparata a marzo non deve restare rossa per sempre.

La fontanella indicata come "la più vicina" salta sempre quelle segnalate rotte. È il punto di tutta l'app: non farti fare la strada per niente.

---

## Cosa può fare chi usa l'app

Segnalare che una fontanella funziona o è rotta, dare le stelle su trovabilità, pulizia, sapore e getto, mandare una foto, proporre una fontanella che manca.

Non può modificare nulla. Le foto e le proposte restano invisibili finché non le approvi tu. Il limite è di 30 contributi l'ora per dispositivo.

## Cosa puoi fare tu

Nel pannello: approvare o rifiutare le proposte, pubblicare o cancellare le foto, nascondere o eliminare i voti, e nella tab **Mappa** modificare qualsiasi punto — anche quelli che arrivano da OpenStreetMap. Cambi nome, tipo, stato, costo, potabilità, note, coordinate, metti il lucchetto sullo stato o lo nascondi del tutto dalla mappa pubblica. Puoi anche aggiungere punti a mano.

Quando modifichi un punto OSM non tocchi OpenStreetMap: crei una riga tua che ci sta sopra. Se un giorno vuoi restituire il favore alla mappa libera, quelle correzioni sono anche il materiale giusto da caricare su OSM.

---

## Il sapore dell'acqua non è la potabilità

Le stelle raccontano com'è bere lì secondo chi c'è stato. Non sono un'analisi di laboratorio. Nell'app c'è scritto: se l'acqua sembra strana, non berla e segnala la fontanella. È il motivo per cui il pulsante "è rotta" è grande almeno quanto quello per navigare.

---

## Dati

Punti da **OpenStreetMap**, licenza ODbL — l'attribuzione è in fondo alla mappa e va lasciata. Le vedovelle di Milano dal portale open data del Comune. Ricerca città via Nominatim. Sfondo mappa CARTO.
