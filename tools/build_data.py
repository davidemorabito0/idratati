#!/usr/bin/env python3
"""
IDRATATI — costruttore dello snapshot dati.

Scarica da OpenStreetMap tutti i punti d'acqua pubblici italiani e li salva
come tile statici da 0.5 gradi dentro ./data/.
L'app carica solo il tile che le serve: risposta immediata, niente rate limit
di Overpass, e funziona anche con la rete che va e viene.

Uso:
    python3 tools/build_data.py                 # tutta Italia
    python3 tools/build_data.py --bbox 45,9,46,10   # solo un'area (prove veloci)
    python3 tools/build_data.py --milano         # aggiunge le vedovelle dal Comune di Milano

Dati: OpenStreetMap contributors, licenza ODbL.
"""

import argparse, json, math, os, sys, time, urllib.request, urllib.error, urllib.parse
from collections import defaultdict

OVERPASS = [
    "https://overpass-api.de/api/interpreter",
    "https://overpass.kumi.systems/api/interpreter",
]
ITALY = (35.4, 6.5, 47.2, 18.6)      # sud, ovest, nord, est
STEP = 1.0                            # ampiezza della cella di download
TILE = 0.5                            # ampiezza del tile scritto su disco
OUT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "data")

QUERY = """[out:json][timeout:180];
(
  nwr["amenity"="drinking_water"]({s},{w},{n},{e});
  nwr["man_made"="water_tap"]["drinking_water"!="no"]({s},{w},{n},{e});
  nwr["amenity"="water_point"]({s},{w},{n},{e});
  nwr["amenity"="vending_machine"]["vending"~"water"]({s},{w},{n},{e});
  nwr["natural"="spring"]["drinking_water"="yes"]({s},{w},{n},{e});
);
out center tags;"""


def fetch(query, tries=4):
    body = urllib.parse.urlencode({"data": query}).encode()
    for attempt in range(tries):
        url = OVERPASS[attempt % len(OVERPASS)]
        try:
            req = urllib.request.Request(
                url, data=body,
                headers={"User-Agent": "idratati-build/1.0 (github pages app)"})
            with urllib.request.urlopen(req, timeout=240) as r:
                return json.loads(r.read().decode())
        except urllib.error.HTTPError as e:
            wait = 25 * (attempt + 1)
            print(f"    HTTP {e.code}, riprovo tra {wait}s", flush=True)
            time.sleep(wait)
        except Exception as e:
            wait = 15 * (attempt + 1)
            print(f"    {type(e).__name__}, riprovo tra {wait}s", flush=True)
            time.sleep(wait)
    print("    cella saltata dopo troppi errori", flush=True)
    return {"elements": []}


def kind_of(t):
    name = (t.get("name") or "").lower()
    if t.get("amenity") in ("vending_machine", "water_point"):
        return 1
    if "casa dell" in name or "casa acqua" in name or "casetta" in name:
        return 1
    if t.get("drinking_water:refill") == "yes" and t.get("amenity") != "drinking_water":
        return 1
    return 0


def flags_of(t):
    """Ogni bit è un'informazione. Stanno tutti in un numero solo per
    tenere i file leggeri: sono decine di migliaia di punti."""
    f = 0
    dw = t.get("drinking_water")
    if dw == "yes" or t.get("amenity") == "drinking_water":
        f |= 1
    if dw == "no" or t.get("potable") == "no":
        f |= 2
        f &= ~1
    if t.get("fee") == "yes":
        f |= 4
    if t.get("fee") == "no":
        f |= 8
    if t.get("bottle") == "yes":
        f |= 16
    if t.get("seasonal") == "yes":
        f |= 32
    # accessibile in sedia a rotelle
    if t.get("wheelchair") == "yes":
        f |= 64
    if t.get("wheelchair") == "limited":
        f |= 128
    # vaschetta o erogatore per i cani
    if (t.get("dog") == "yes" or t.get("bowl") == "yes"
            or t.get("drinking_water:dog") == "yes" or t.get("dog_bowl") == "yes"):
        f |= 256
    return f


def encode(el):
    lat = el.get("lat") or (el.get("center") or {}).get("lat")
    lon = el.get("lon") or (el.get("center") or {}).get("lon")
    if lat is None or lon is None:
        return None
    t = el.get("tags") or {}
    if t.get("access") in ("private", "no"):
        return None
    name = t.get("name") or ""
    if len(name) > 60:
        name = name[:60]
    row = [f"{el['type']}/{el['id']}", round(lat, 6), round(lon, 6),
           kind_of(t), name, flags_of(t)]
    cd = t.get("check_date") or t.get("survey:date")
    if cd:
        row.append(cd[:10])
    return row


def tile_key(lat, lon):
    return f"{math.floor(lat / TILE) * TILE:.1f}_{math.floor(lon / TILE) * TILE:.1f}"


def load_milano(points, seen):
    """Vedovelle dal portale open data del Comune di Milano, dove OSM è incompleto."""
    url = ("https://dati.comune.milano.it/dataset/ds502_fontanelle-nel-comune-di-milano/"
           "resource/download/fontanelle.geojson")
    print("Scarico le vedovelle dal Comune di Milano…", flush=True)
    try:
        req = urllib.request.Request(url, headers={"User-Agent": "idratati-build/1.0"})
        with urllib.request.urlopen(req, timeout=90) as r:
            gj = json.loads(r.read().decode("utf-8", "replace"))
    except Exception as e:
        print(f"  non riuscito ({type(e).__name__}), salto. "
              f"Puoi scaricare il file a mano e passarlo con --geojson", flush=True)
        return 0
    return merge_geojson(gj, points, seen, "milano")


def merge_geojson(gj, points, seen, src):
    added = 0
    for feat in gj.get("features", []):
        geom = feat.get("geometry") or {}
        if geom.get("type") != "Point":
            continue
        lon, lat = geom["coordinates"][0], geom["coordinates"][1]
        # dedup: se c'è già un punto OSM entro ~18 m, non lo duplico
        if near(points, lat, lon, 18):
            continue
        pid = f"{src}/{len(seen)}"
        seen.add(pid)
        points.append([pid, round(lat, 6), round(lon, 6), 0,
                       (feat.get("properties") or {}).get("nome") or "", 1])
        added += 1
    return added


def near(points, lat, lon, meters):
    dlat = meters / 111320.0
    dlon = dlat / max(0.2, math.cos(math.radians(lat)))
    for p in points:
        if abs(p[1] - lat) < dlat and abs(p[2] - lon) < dlon:
            return True
    return False


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--bbox", help="s,w,n,e per limitare l'area")
    ap.add_argument("--milano", action="store_true", help="aggiungi le vedovelle del Comune di Milano")
    ap.add_argument("--geojson", help="unisci un GeoJSON locale di punti")
    ap.add_argument("--sleep", type=float, default=6.0, help="pausa tra le celle, in secondi")
    args = ap.parse_args()

    s, w, n, e = [float(x) for x in args.bbox.split(",")] if args.bbox else ITALY
    os.makedirs(OUT, exist_ok=True)

    cells = []
    la = s
    while la < n:
        lo = w
        while lo < e:
            cells.append((la, lo, min(la + STEP, n), min(lo + STEP, e)))
            lo += STEP
        la += STEP

    print(f"Scarico {len(cells)} celle da Overpass. "
          f"Ci vogliono circa {len(cells) * (args.sleep + 8) / 60:.0f} minuti.\n", flush=True)

    points, seen = [], set()
    for i, (cs, cw, cn, ce) in enumerate(cells, 1):
        print(f"[{i}/{len(cells)}] {cs:.1f},{cw:.1f} → {cn:.1f},{ce:.1f}", flush=True)
        data = fetch(QUERY.format(s=cs, w=cw, n=cn, e=ce))
        got = 0
        for el in data.get("elements", []):
            row = encode(el)
            if row and row[0] not in seen:
                seen.add(row[0])
                points.append(row)
                got += 1
        print(f"    {got} punti (totale {len(points)})", flush=True)
        time.sleep(args.sleep)

    if args.milano:
        print(f"  +{load_milano(points, seen)} da Milano", flush=True)
    if args.geojson:
        with open(args.geojson, encoding="utf-8") as fh:
            print(f"  +{merge_geojson(json.load(fh), points, seen, 'local')} dal file locale", flush=True)

    tiles = defaultdict(list)
    for p in points:
        tiles[tile_key(p[1], p[2])].append(p)

    for old in os.listdir(OUT):
        if old.endswith(".json"):
            os.remove(os.path.join(OUT, old))

    for key, rows in tiles.items():
        with open(os.path.join(OUT, key + ".json"), "w", encoding="utf-8") as fh:
            json.dump({"v": 1, "p": rows}, fh, ensure_ascii=False, separators=(",", ":"))

    with open(os.path.join(OUT, "index.json"), "w", encoding="utf-8") as fh:
        json.dump({
            "v": 1,
            "generated": time.strftime("%Y-%m-%d"),
            "count": len(points),
            "tiles": sorted(tiles.keys()),
            "license": "ODbL — © OpenStreetMap contributors"
        }, fh, ensure_ascii=False, separators=(",", ":"))

    size = sum(os.path.getsize(os.path.join(OUT, f)) for f in os.listdir(OUT))
    print(f"\nFatto: {len(points)} punti in {len(tiles)} tile, {size/1048576:.1f} MB in {OUT}")


if __name__ == "__main__":
    sys.exit(main())
