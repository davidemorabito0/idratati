#!/usr/bin/env python3
"""
IDRATATI — backup del database dentro il repository.

Scarica tutte le tabelle e TUTTE LE FOTO VERE. Il punto delicato e' questo:
salvare l'indirizzo di una foto non serve a niente, perche' se Supabase
sparisse quegli indirizzi punterebbero al nulla. Qui le immagini vengono
scaricate come file veri.

Le oltre centomila fontanelle di OpenStreetMap non finiscono qui: stanno
gia' in data/, si rigenerano da sole ogni mese, e comunque restano su
OpenStreetMap. Qui c'e' il lavoro delle persone, che non si puo' rifare.

Lo lancia GitHub ogni domenica. Serve che siano impostati due segreti nel
repository: SUPABASE_URL e SUPABASE_SERVICE_KEY.
"""

import json, os, sys, time, urllib.request, urllib.error, pathlib

URL     = os.environ.get('SUPABASE_URL', '').rstrip('/')
CHIAVE  = os.environ.get('SUPABASE_SERVICE', '')
FUORI   = pathlib.Path('backup')

TABELLE = ['fountains', 'reports', 'reviews', 'photos', 'submissions',
           'problemi', 'dettagli', 'punti', 'citta', 'visite', 'admins']


def chiama(percorso, binario=False):
    req = urllib.request.Request(URL + percorso, headers={
        'apikey': CHIAVE,
        'Authorization': 'Bearer ' + CHIAVE,
    })
    with urllib.request.urlopen(req, timeout=60) as r:
        return r.read() if binario else json.loads(r.read())


def leggi_tabella(nome):
    """A pagine da mille righe: quando un giorno saranno tante, non si rompe."""
    tutte, salto = [], 0
    while True:
        req = urllib.request.Request(
            f'{URL}/rest/v1/{nome}?select=*&limit=1000&offset={salto}',
            headers={'apikey': CHIAVE, 'Authorization': 'Bearer ' + CHIAVE})
        with urllib.request.urlopen(req, timeout=60) as r:
            pezzo = json.loads(r.read())
        tutte.extend(pezzo)
        if len(pezzo) < 1000:
            return tutte
        salto += 1000


def main():
    if not URL or not CHIAVE:
        print('Mancano i segreti SUPABASE_URL o SUPABASE_SERVICE_KEY.')
        return 1

    (FUORI / 'tabelle').mkdir(parents=True, exist_ok=True)
    (FUORI / 'foto').mkdir(parents=True, exist_ok=True)

    dati, conteggi, problemi = {}, {}, []

    for t in TABELLE:
        try:
            righe = leggi_tabella(t)
            dati[t] = righe
            conteggi[t] = len(righe)
            (FUORI / 'tabelle' / f'{t}.json').write_text(
                json.dumps(righe, indent=2, ensure_ascii=False), encoding='utf-8')
            print(f'  {t:14s} {len(righe):5d} righe')
        except Exception as e:
            conteggi[t] = f'ERRORE: {e}'
            problemi.append(f'tabella {t}: {e}')
            print(f'  {t:14s} ERRORE: {e}')

    # Ogni percorso di foto citato da qualunque tabella, non solo da photos:
    # una foto puo' essere agganciata a una proposta o a una fontanella.
    percorsi = set()
    for r in dati.get('photos', []):
        if r.get('path'):
            percorsi.add(r['path'])
    for r in dati.get('submissions', []):
        if r.get('photo_path'):
            percorsi.add(r['photo_path'])
    for t in ('fountains', 'reports'):
        for r in dati.get(t, []):
            u = r.get('photo_url') or ''
            if '/photos/' in u:
                percorsi.add(u.split('/photos/')[1])

    salvate, perse = 0, []
    for p in sorted(percorsi):
        dest = FUORI / 'foto' / p
        if dest.exists():          # gia' salvata in un backup precedente
            salvate += 1
            continue
        try:
            dest.parent.mkdir(parents=True, exist_ok=True)
            dest.write_bytes(chiama(f'/storage/v1/object/public/photos/{p}', binario=True))
            salvate += 1
        except Exception as e:
            perse.append(p)
            print(f'  foto persa: {p} ({e})')
        time.sleep(0.1)

    print(f'  foto: {salvate} salvate, {len(perse)} non riuscite')

    manifesto = {
        'creato': time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime()),
        'progetto': 'IDRATATI',
        'righe_per_tabella': conteggi,
        'foto_salvate': salvate,
        'foto_non_riuscite': perse,
        'problemi': problemi,
    }
    (FUORI / 'manifesto.json').write_text(
        json.dumps(manifesto, indent=2, ensure_ascii=False), encoding='utf-8')

    # IMPORTANTE, e non e' ovvio: qui NON si esce con errore anche se
    # qualcosa e' andato storto. Se questo passaggio fallisse, GitHub
    # salterebbe il passaggio successivo e il backup appena scritto non
    # verrebbe salvato: un guaio piccolo (una foto persa) butterebbe via
    # tutto il resto. I problemi restano scritti nel manifesto, e un
    # passaggio separato, DOPO il salvataggio, avvisa via mail.
    if problemi or perse:
        print('\nATTENZIONE, backup incompleto:')
        for p in problemi:
            print('  -', p)
        if perse:
            print(f'  - {len(perse)} foto non scaricate: ' + ', '.join(perse[:5])
                  + (' ...' if len(perse) > 5 else ''))
        print('Il backup viene comunque salvato: meglio parziale che assente.')
    else:
        print('\nBackup completo.')
    return 0


if __name__ == '__main__':
    sys.exit(main())
