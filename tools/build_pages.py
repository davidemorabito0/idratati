#!/usr/bin/env python3
"""
IDRATATI — generatore delle pagine città.

L'app è una mappa che si riempie con JavaScript: per Google è una pagina
vuota. Questo script legge lo snapshot in ./data e scrive una pagina vera
per ogni città — con testo, numeri e nomi — che è quello che i motori di
ricerca sanno leggere e mostrare.

Uso:
    python3 tools/build_pages.py
    python3 tools/build_pages.py --dominio https://idratati.it
    python3 tools/build_pages.py --indirizzi 15    # cerca le vie per le prime 15 città

Le pagine finiscono in ./citta/, più sitemap.xml nella radice.
"""

import argparse, json, math, os, re, sys, time, unicodedata
import urllib.request, urllib.error

QUI = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DATI = os.path.join(QUI, "data")
FUORI = os.path.join(QUI, "citta")
CACHE_VIE = os.path.join(QUI, "tools", "vie-cache.json")

# Città italiane con coordinate del centro e raggio utile in km.
# Il raggio è tarato sull'area urbana, non sul confine comunale.
CITTA = [
    ("Roma", "RM", 41.9028, 12.4964, 14), ("Milano", "MI", 45.4642, 9.1900, 10),
    ("Napoli", "NA", 40.8518, 14.2681, 9), ("Torino", "TO", 45.0703, 7.6869, 9),
    ("Palermo", "PA", 38.1157, 13.3615, 9), ("Genova", "GE", 44.4056, 8.9463, 10),
    ("Bologna", "BO", 44.4949, 11.3426, 8), ("Firenze", "FI", 43.7696, 11.2558, 8),
    ("Bari", "BA", 41.1171, 16.8719, 8), ("Catania", "CT", 37.5079, 15.0830, 8),
    ("Verona", "VR", 45.4384, 10.9916, 7), ("Venezia", "VE", 45.4408, 12.3155, 8),
    ("Messina", "ME", 38.1938, 15.5540, 8), ("Padova", "PD", 45.4064, 11.8768, 7),
    ("Trieste", "TS", 45.6495, 13.7768, 7), ("Brescia", "BS", 45.5416, 10.2118, 7),
    ("Parma", "PR", 44.8015, 10.3279, 6), ("Prato", "PO", 43.8777, 11.1022, 6),
    ("Modena", "MO", 44.6471, 10.9252, 6), ("Reggio Calabria", "RC", 38.1105, 15.6613, 7),
    ("Reggio Emilia", "RE", 44.6989, 10.6297, 6), ("Perugia", "PG", 43.1107, 12.3908, 7),
    ("Ravenna", "RA", 44.4184, 12.2035, 7), ("Livorno", "LI", 43.5485, 10.3106, 6),
    ("Rimini", "RN", 44.0678, 12.5695, 6), ("Cagliari", "CA", 39.2238, 9.1217, 7),
    ("Foggia", "FG", 41.4622, 15.5446, 6), ("Ferrara", "FE", 44.8381, 11.6198, 6),
    ("Salerno", "SA", 40.6824, 14.7681, 6), ("Latina", "LT", 41.4676, 12.9037, 6),
    ("Giugliano in Campania", "NA", 40.9280, 14.1950, 5),
    ("Monza", "MB", 45.5845, 9.2744, 5), ("Sassari", "SS", 40.7259, 8.5556, 6),
    ("Bergamo", "BG", 45.6983, 9.6773, 6), ("Pescara", "PE", 42.4643, 14.2142, 6),
    ("Trento", "TN", 46.0679, 11.1211, 6), ("Forlì", "FC", 44.2226, 12.0407, 6),
    ("Siracusa", "SR", 37.0755, 15.2866, 6), ("Vicenza", "VI", 45.5455, 11.5354, 6),
    ("Terni", "TR", 42.5636, 12.6427, 5), ("Bolzano", "BZ", 46.4983, 11.3548, 5),
    ("Piacenza", "PC", 45.0526, 9.6929, 5), ("Novara", "NO", 45.4469, 8.6220, 5),
    ("Ancona", "AN", 43.6158, 13.5189, 6), ("Andria", "BT", 41.2270, 16.2960, 5),
    ("Udine", "UD", 46.0711, 13.2346, 5), ("Arezzo", "AR", 43.4633, 11.8796, 5),
    ("Cesena", "FC", 44.1391, 12.2431, 5), ("Lecce", "LE", 40.3515, 18.1750, 5),
    ("Pesaro", "PU", 43.9102, 12.9132, 5), ("Barletta", "BT", 41.3140, 16.2810, 5),
    ("Alessandria", "AL", 44.9133, 8.6151, 5), ("La Spezia", "SP", 44.1024, 9.8241, 5),
    ("Pisa", "PI", 43.7161, 10.3966, 5), ("Catanzaro", "CZ", 38.9098, 16.5877, 5),
    ("Pistoia", "PT", 43.9330, 10.9179, 5), ("Guidonia Montecelio", "RM", 41.9930, 12.7230, 5),
    ("Lucca", "LU", 43.8430, 10.5079, 5), ("Brindisi", "BR", 40.6327, 17.9418, 5),
    ("Torre del Greco", "NA", 40.7869, 14.3670, 4), ("Treviso", "TV", 45.6669, 12.2430, 5),
    ("Busto Arsizio", "VA", 45.6120, 8.8518, 4), ("Como", "CO", 45.8081, 9.0852, 5),
    ("Marsala", "TP", 37.7970, 12.4379, 5), ("Grosseto", "GR", 42.7635, 11.1129, 5),
    ("Sesto San Giovanni", "MI", 45.5333, 9.2333, 4), ("Pozzuoli", "NA", 40.8443, 14.0921, 4),
    ("Varese", "VA", 45.8206, 8.8251, 5), ("Fiumicino", "RM", 41.7714, 12.2400, 5),
    ("Casoria", "NA", 40.9070, 14.2930, 4), ("Asti", "AT", 44.9009, 8.2065, 4),
    ("Caserta", "CE", 41.0723, 14.3327, 5), ("Cinisello Balsamo", "MI", 45.5570, 9.2170, 4),
    ("Gela", "CL", 37.0665, 14.2510, 4), ("Aprilia", "LT", 41.5940, 12.6540, 4),
    ("Ragusa", "RG", 36.9269, 14.7255, 5), ("Pavia", "PV", 45.1847, 9.1582, 4),
    ("Cremona", "CR", 45.1332, 10.0227, 4), ("Carpi", "MO", 44.7830, 10.8850, 4),
    ("Quartu Sant'Elena", "CA", 39.2410, 9.1840, 4), ("Lamezia Terme", "CZ", 38.9650, 16.3090, 4),
    ("Altamura", "BA", 40.8270, 16.5540, 4), ("Imola", "BO", 44.3530, 11.7140, 4),
    ("L'Aquila", "AQ", 42.3498, 13.3995, 5), ("Massa", "MS", 44.0350, 10.1410, 4),
    ("Trapani", "TP", 38.0176, 12.5365, 5), ("Viterbo", "VT", 42.4207, 12.1077, 4),
    ("Cosenza", "CS", 39.2983, 16.2539, 5), ("Potenza", "PZ", 40.6408, 15.8056, 4),
    ("Campobasso", "CB", 41.5603, 14.6627, 4), ("Aosta", "AO", 45.7372, 7.3206, 4),
    ("Matera", "MT", 40.6664, 16.6043, 4), ("Savona", "SV", 44.3091, 8.4772, 4),
    ("Benevento", "BN", 41.1297, 14.7826, 4), ("Avellino", "AV", 40.9146, 14.7903, 4),
    ("Siena", "SI", 43.3188, 11.3308, 4), ("Mantova", "MN", 45.1564, 10.7914, 4),
    ("Lodi", "LO", 45.3140, 9.5030, 4), ("Sondrio", "SO", 46.1700, 9.8700, 4),
    ("Belluno", "BL", 46.1400, 12.2170, 4), ("Rovigo", "RO", 45.0700, 11.7900, 4),
]

MARCA = "#00A6A6"
INCHIOSTRO = "#07242F"


def slug(s):
    s = unicodedata.normalize("NFKD", s).encode("ascii", "ignore").decode()
    return re.sub(r"[^a-z0-9]+", "-", s.lower()).strip("-")


def distanza(la1, lo1, la2, lo2):
    R = 6371.0
    t = math.pi / 180
    dla, dlo = (la2 - la1) * t, (lo2 - lo1) * t
    a = (math.sin(dla / 2) ** 2 +
         math.cos(la1 * t) * math.cos(la2 * t) * math.sin(dlo / 2) ** 2)
    return 2 * R * math.asin(math.sqrt(a))


def carica_punti():
    if not os.path.isdir(DATI):
        return []
    punti = []
    for nome in os.listdir(DATI):
        if not nome.endswith(".json") or nome == "index.json":
            continue
        try:
            with open(os.path.join(DATI, nome), encoding="utf-8") as fh:
                for r in json.load(fh).get("p", []):
                    punti.append({
                        "id": r[0], "lat": r[1], "lon": r[2],
                        "casa": r[3] == 1, "nome": r[4] or "",
                        "flag": r[5] or 0,
                        "controllo": r[6] if len(r) > 6 else None,
                    })
        except Exception as e:
            print(f"  {nome} illeggibile ({e}), lo salto")
    return punti


# ---------- indirizzi (facoltativi, lenti: uno al secondo) ----------
def carica_cache():
    try:
        with open(CACHE_VIE, encoding="utf-8") as fh:
            return json.load(fh)
    except Exception:
        return {}


def salva_cache(c):
    os.makedirs(os.path.dirname(CACHE_VIE), exist_ok=True)
    with open(CACHE_VIE, "w", encoding="utf-8") as fh:
        json.dump(c, fh, ensure_ascii=False)


def cerca_via(lat, lon, cache):
    k = f"{lat:.5f},{lon:.5f}"
    if k in cache:
        return cache[k]
    url = (f"https://nominatim.openstreetmap.org/reverse?format=jsonv2&zoom=18"
           f"&addressdetails=1&lat={lat}&lon={lon}")
    try:
        req = urllib.request.Request(url, headers={
            "User-Agent": "idratati.it (mappa fontanelle pubbliche)"})
        with urllib.request.urlopen(req, timeout=25) as r:
            d = json.loads(r.read().decode())
        a = d.get("address", {})
        via = a.get("road") or a.get("pedestrian") or a.get("footway") or a.get("park")
        zona = a.get("suburb") or a.get("city_district") or a.get("neighbourhood")
        testo = ", ".join([x for x in (via, zona) if x]) or None
    except Exception:
        testo = None
    cache[k] = testo
    time.sleep(1.1)          # Nominatim accetta una richiesta al secondo
    return testo


# ---------- pagine ----------
STILE = """*{box-sizing:border-box}
body{margin:0;font-family:'Inter Tight',system-ui,-apple-system,sans-serif;
  background:#F2F7F6;color:#07242F;line-height:1.55}
a{color:#00807F}
header{background:#07242F;color:#F2F7F6;padding:26px 20px}
header .in{max-width:780px;margin:0 auto}
.marchio{font-family:'Bricolage Grotesque',system-ui,sans-serif;font-weight:800;
  letter-spacing:.15em;font-size:15px;color:#F2F7F6;text-decoration:none}
.motto{font-size:11px;letter-spacing:.13em;text-transform:uppercase;color:#00A6A6;margin-top:5px}
main{max-width:780px;margin:0 auto;padding:26px 20px 60px}
h1{font-family:'Bricolage Grotesque',system-ui,sans-serif;font-weight:800;
  font-size:clamp(26px,5vw,38px);line-height:1.12;margin:0 0 10px;letter-spacing:-.01em}
h2{font-family:'Bricolage Grotesque',system-ui,sans-serif;font-weight:600;
  font-size:21px;margin:34px 0 10px}
.sommario{font-size:17px;color:rgba(7,36,47,.72)}
.numeri{display:flex;flex-wrap:wrap;gap:10px;margin:22px 0}
.numero{background:#fff;border-radius:14px;padding:14px 18px;min-width:120px;flex:1 1 120px}
.numero b{display:block;font-family:'Bricolage Grotesque',system-ui,sans-serif;
  font-size:27px;font-weight:800;color:#00807F;line-height:1}
.numero span{font-size:12.5px;color:rgba(7,36,47,.6)}
/* La mappa e' la pagina. Sta subito sotto al titolo, alta quanto lo
   schermo permette, e dentro c'e' l'app vera: filtri, schede, voti,
   tutto quello che c'e' sulla home. Il testo per Google sta sotto,
   dove non da' fastidio a chi vuole solo bere. */
.mappa{position:relative;width:100%;height:min(68vh,620px);min-height:380px;
  border-radius:18px;overflow:hidden;background:#EBF5F3;
  box-shadow:0 4px 22px rgba(7,36,47,.13);margin:16px 0 6px}
.mappa iframe{position:absolute;inset:0;width:100%;height:100%;border:0;display:block}
.mappa-sotto{font-size:12.5px;color:rgba(7,36,47,.55);margin:0 0 22px;text-align:center}
.mappa-sotto a{color:#00807F}
.cta{display:inline-block;background:#07242F;color:#F2F7F6;text-decoration:none;
  padding:15px 26px;border-radius:14px;font-weight:600;margin:8px 0 4px}
details.piu{background:#fff;border-radius:14px;padding:2px 18px;margin:26px 0}
details.piu summary{padding:15px 0;font-family:'Bricolage Grotesque',system-ui,sans-serif;
  font-weight:600;font-size:16px;cursor:pointer}
details.piu[open] summary{border-bottom:1px solid rgba(7,36,47,.1);margin-bottom:8px}
details.piu h2{font-size:17px;margin:18px 0 8px}
details.piu > *:last-child{margin-bottom:16px}
.elenco{list-style:none;padding:0;margin:14px 0}
.elenco li{background:#fff;border-radius:12px;padding:13px 15px;margin-bottom:8px}
.elenco .n{font-weight:600}
.elenco .d{font-size:13px;color:rgba(7,36,47,.6)}
.eti{display:inline-block;font-size:11px;font-weight:600;padding:2px 8px;border-radius:6px;
  background:rgba(0,166,166,.13);color:#00807F;margin-right:5px}
.eti.g{background:rgba(255,176,32,.2);color:#8A5B00}
.griglia{display:grid;grid-template-columns:repeat(auto-fill,minmax(160px,1fr));gap:9px;padding:0;list-style:none}
.griglia a{display:block;background:#fff;border-radius:12px;padding:13px 15px;
  text-decoration:none;color:#07242F;font-weight:600}
.griglia small{display:block;font-weight:400;color:rgba(7,36,47,.55);font-size:12.5px}
footer{border-top:1px solid rgba(7,36,47,.1);margin-top:44px;padding-top:20px;
  font-size:12.5px;color:rgba(7,36,47,.55)}
"""

TESTA = """<!DOCTYPE html>
<html lang="it">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>{titolo}</title>
<meta name="description" content="{descrizione}">
<link rel="canonical" href="{canonico}">
<meta property="og:type" content="website">
<meta property="og:title" content="{titolo}">
<meta property="og:description" content="{descrizione}">
<meta property="og:url" content="{canonico}">
<meta property="og:locale" content="it_IT">
<meta property="og:image" content="{dominio}/icon-512.png">
<meta name="theme-color" content="#07242F">
<link rel="icon" href="{dominio}/icon-192.png">
<link rel="stylesheet" href="../vendor/fonts/fonts.css">
<style>{stile}</style>
{dati_strutturati}
</head>
<body>
<header><div class="in">
  <a class="marchio" href="{dominio}/">IDRATATI</a>
  <div class="motto">Idràtati, per rimanere idratàti</div>
</div></header>
<main>
"""

CODA = """
<footer>
  Dati da <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a>,
  licenza ODbL, aggiornati il {data}. Le fontanelle vengono verificate da chi le usa:
  se ne trovi una rotta o non segnalata, puoi dirlo dall'app.
  <br><br>
  <a href="{dominio}/">Torna alla mappa</a> ·
  <a href="{dominio}/citta/">Tutte le città</a>
</footer>
</main>
</body>
</html>
"""


def pagina_citta(c, punti, dominio, data, cache, cerca_indirizzi):
    nome, prov, lat, lon, raggio = c
    s = slug(nome)
    canonico = f"{dominio}/citta/{s}.html"

    fontanelle = [p for p in punti if not p["casa"]]
    case = [p for p in punti if p["casa"]]
    accessibili = [p for p in punti if p["flag"] & 64]
    cani = [p for p in punti if p["flag"] & 256]
    gratis = [p for p in punti if p["flag"] & 8]
    a_pagamento = [p for p in punti if p["flag"] & 4]

    titolo = f"Fontanelle pubbliche a {nome}: {len(punti)} punti d'acqua gratuita | IDRATATI"
    descrizione = (f"{len(fontanelle)} fontanelle pubbliche e {len(case)} case dell'acqua "
                   f"a {nome} ({prov}). Mappa aggiornata con posizione, stato e indicazioni "
                   f"a piedi per riempire la borraccia gratis.")

    strutturati = json.dumps({
        "@context": "https://schema.org",
        "@type": "WebPage",
        "name": titolo,
        "description": descrizione,
        "url": canonico,
        "about": {"@type": "Place", "name": nome,
                  "geo": {"@type": "GeoCoordinates", "latitude": lat, "longitude": lon}},
        "isPartOf": {"@type": "WebSite", "name": "IDRATATI", "url": dominio},
    }, ensure_ascii=False)

    h = TESTA.format(titolo=titolo, descrizione=descrizione, canonico=canonico,
                     dominio=dominio, stile=STILE,
                     dati_strutturati=f'<script type="application/ld+json">{strutturati}</script>')

    h += f"<h1>Fontanelle a {nome}</h1>\n"
    h += (f'<p class="sommario"><strong>{len(punti)} punti d\'acqua</strong> gratuiti, '
          f'sulla mappa qui sotto. Sai se funzionano prima di arrivarci.</p>\n')

    # La mappa, subito. Dentro c'e' l'app vera, gia' centrata sulla citta':
    # chi apre questa pagina vede le fontanelle senza dover cliccare niente.
    h += ('<div class="mappa">'
          f'<iframe src="{dominio}/?c={lat},{lon}" loading="eager" '
          f'title="Mappa delle fontanelle pubbliche a {nome}" '
          'allow="geolocation" referrerpolicy="same-origin"></iframe>'
          '</div>\n')
    h += (f'<p class="mappa-sotto">Non si carica? '
          f'<a href="{dominio}/?c={lat},{lon}">Apri la mappa a tutto schermo</a></p>\n')

    h += '<div class="numeri">'
    h += f'<div class="numero"><b>{len(fontanelle)}</b><span>fontanelle</span></div>'
    if case:
        h += f'<div class="numero"><b>{len(case)}</b><span>case dell\'acqua</span></div>'
    if accessibili:
        h += f'<div class="numero"><b>{len(accessibili)}</b><span>accessibili in carrozzina</span></div>'
    if cani:
        h += f'<div class="numero"><b>{len(cani)}</b><span>con vaschetta per cani</span></div>'
    h += '</div>\n'

    # Da qui in giu' c'e' il testo. Serve a Google e a chi vuole capirci
    # di piu', ma sta sotto la mappa: chi ha solo sete non lo incontra mai.
    h += f"<h2>Come funziona</h2>\n"
    h += ("<p>L'app mostra la fontanella più vicina a te e quanti minuti servono per "
          "raggiungerla a piedi. Tocca un punto e ti porta lì con Google Maps o Apple Maps. "
          "Chi ci è già stato segnala se funziona, se è rotta o se c'è un cantiere: così "
          "sai com'è messa <em>prima</em> di fare la strada.</p>\n")

    if gratis or a_pagamento:
        h += "<h2>Si paga?</h2>\n<p>"
        if a_pagamento:
            h += (f"A {nome} risultano <strong>{len(a_pagamento)}</strong> punti a pagamento — "
                  "di solito distributori di acqua frizzante o refrigerata. ")
        h += ("Tutti gli altri sono gratuiti. Nelle case dell'acqua gestite dai Comuni "
              "capita che serva la tessera sanitaria per attivare l'erogatore.</p>\n")

    principali = [p for p in punti if p["nome"]][:40]
    if cerca_indirizzi:
        for p in principali[:25]:
            p["via"] = cerca_via(p["lat"], p["lon"], cache)

    if principali:
        h += (f'<details class="piu"><summary>I punti d\'acqua di {nome}, uno per uno'
              f' ({len(principali)})</summary>\n')
        h += '<ul class="elenco">\n'
        for p in principali:
            eti = ""
            if p["casa"]:
                eti += '<span class="eti g">casa dell\'acqua</span>'
            if p["flag"] & 64:
                eti += '<span class="eti">accessibile</span>'
            if p["flag"] & 256:
                eti += '<span class="eti">vaschetta cani</span>'
            dove = p.get("via") or f"{p['lat']:.5f}, {p['lon']:.5f}"
            h += (f'  <li><span class="n">{p["nome"]}</span>{eti}'
                  f'<div class="d">{dove} · '
                  f'<a href="{dominio}/?f=osm/{p["id"]}">apri sulla mappa</a></div></li>\n')
        h += "</ul>\n</details>\n"

    h += "<h2>Perché una mappa delle fontanelle</h2>\n"
    h += ("<p>Una bottiglietta da mezzo litro costa fino a due euro e resta nell'ambiente "
          "per secoli. L'acqua del rubinetto in Italia è controllata più spesso di quella "
          "in bottiglia, costa quasi nulla e nelle fontanelle pubbliche è gratis. "
          "Il problema è sempre stato solo uno: sapere dove sono.</p>\n")

    h += CODA.format(data=data, dominio=dominio)
    return s, h


def pagina_indice(righe, dominio, data, totale):
    titolo = "Fontanelle pubbliche in Italia: la mappa città per città | IDRATATI"
    descrizione = (f"{totale} fontanelle e case dell'acqua mappate in tutta Italia. "
                   "Trova il punto d'acqua gratuito più vicino, con lo stato aggiornato "
                   "da chi ci è passato.")
    strutturati = json.dumps({
        "@context": "https://schema.org", "@type": "WebSite",
        "name": "IDRATATI", "url": dominio, "description": descrizione,
        "inLanguage": "it-IT",
    }, ensure_ascii=False)

    h = TESTA.format(titolo=titolo, descrizione=descrizione,
                     canonico=f"{dominio}/citta/", dominio=dominio, stile=STILE,
                     dati_strutturati=f'<script type="application/ld+json">{strutturati}</script>')
    h += "<h1>Le fontanelle pubbliche, città per città</h1>\n"
    h += (f'<p class="sommario">Sono <strong>{totale}</strong> i punti d\'acqua gratuiti '
          "mappati in Italia. Scegli la tua città, oppure apri la mappa e trova quello "
          "più vicino a dove sei adesso.</p>\n")
    h += f'<a class="cta" href="{dominio}/">Apri la mappa</a>\n'
    h += "<h2>Città</h2>\n<ul class=\"griglia\">\n"
    for nome, s, quanti in righe:
        h += (f'  <li><a href="{dominio}/citta/{s}.html">{nome}'
              f'<small>{quanti} punti d\'acqua</small></a></li>\n')
    h += "</ul>\n"
    h += CODA.format(data=data, dominio=dominio)
    return h


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--dominio", default="https://idratati.it",
                    help="senza barra finale")
    ap.add_argument("--indirizzi", type=int, default=0,
                    help="per quante città cercare le vie (lento: 1 richiesta al secondo)")
    ap.add_argument("--minimo", type=int, default=3,
                    help="quanti punti servono perché la città abbia una pagina")
    args = ap.parse_args()
    dominio = args.dominio.rstrip("/")

    punti = carica_punti()
    if not punti:
        print("Nessun dato in ./data. Lancia prima tools/build_data.py")
        return 1
    print(f"{len(punti)} punti letti dallo snapshot")

    data = time.strftime("%d/%m/%Y")
    os.makedirs(FUORI, exist_ok=True)
    for vecchio in os.listdir(FUORI):
        if vecchio.endswith(".html"):
            os.remove(os.path.join(FUORI, vecchio))

    cache = carica_cache()
    righe, fatte = [], 0

    for i, c in enumerate(CITTA):
        nome, prov, lat, lon, raggio = c
        dentro = [p for p in punti if distanza(lat, lon, p["lat"], p["lon"]) <= raggio]
        if len(dentro) < args.minimo:
            continue
        s, html = pagina_citta(c, dentro, dominio, data, cache,
                               cerca_indirizzi=(i < args.indirizzi))
        with open(os.path.join(FUORI, s + ".html"), "w", encoding="utf-8") as fh:
            fh.write(html)
        righe.append((nome, s, len(dentro)))
        fatte += 1
        print(f"  {nome}: {len(dentro)} punti")

    righe.sort(key=lambda r: -r[2])
    with open(os.path.join(FUORI, "index.html"), "w", encoding="utf-8") as fh:
        fh.write(pagina_indice(righe, dominio, data, len(punti)))
    salva_cache(cache)

    # sitemap
    oggi = time.strftime("%Y-%m-%d")
    url = [f"{dominio}/", f"{dominio}/citta/"]
    url += [f"{dominio}/citta/{s}.html" for _, s, _ in righe]
    # Pagine fisse che non nascono da qui ma devono restare nel sitemap:
    # senza questa riga ogni rigenerazione le cancellava in silenzio.
    url += [f"{dominio}/privacy.html"]
    with open(os.path.join(QUI, "sitemap.xml"), "w", encoding="utf-8") as fh:
        fh.write('<?xml version="1.0" encoding="UTF-8"?>\n')
        fh.write('<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">\n')
        for u in url:
            priorita = "1.0" if u.endswith("/") and u.count("/") == 3 else "0.7"
            fh.write(f"  <url><loc>{u}</loc><lastmod>{oggi}</lastmod>"
                     f"<changefreq>monthly</changefreq><priority>{priorita}</priority></url>\n")
        fh.write("</urlset>\n")

    print(f"\nFatto: {fatte} pagine città + indice + sitemap con {len(url)} indirizzi.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
