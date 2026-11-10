## Aggiunge alla mappa: zone di mare dei porti e degli esagoni costieri (Atlantico, Mare del Nord,
## Baltico, Mediterraneo occidentale e orientale) e gli esagoni del riquadro dell'Egitto.
## Uso: python3 mari_egitto.py <tipi.json> <mappa.json da aggiornare>
import json, math, sys
import os; sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from griglia import centro, vicini, escluso

T = json.load(open(sys.argv[1]))
M = json.load(open(sys.argv[2]))
SC = M['scala']
E = M['esagoni']
# togli eventuali esagoni d'Egitto di un'esecuzione precedente
for k in [k for k in E if k.startswith('e')]:
    del E[k]

def rc(k):
    r, c = k.split(','); return int(r), int(c)

mare = {}
for k, v in T.items():
    if v['t'] == 'mare' and not escluso(v['x'], v['y']):
        mare[k] = (v['x'], v['y'])

def bloccato(a, b):
    (xa, ya), (xb, yb) = a, b
    q = 4.0
    if 600*q <= ya <= 720*q and 600*q <= yb <= 720*q and ((xa+ya-1035*q) < 0) != ((xb+yb-1035*q) < 0):
        return True
    if ya > 1330*q and yb > 1330*q and (xa < 345*q) != (xb < 345*q):
        return True
    if ya < 420*q and yb < 420*q and (xa < 925*q) != (xb < 925*q):
        return True
    if ya > 1220*q and yb > 1220*q and (xa < 1060*q) != (xb < 1060*q):
        return True
    return False

semi = {'ATL': (860, 3600), 'NOR': (2600, 1680), 'BAL': (4400, 1000), 'MOC': (2600, 5000), 'MOR': (5000, 4720)}
zona = {}
for z, p in semi.items():
    s0 = min(mare, key=lambda k: (mare[k][0]-p[0])**2 + (mare[k][1]-p[1])**2)
    coda = [s0]
    zona.setdefault(s0, z)
    while coda:
        k = coda.pop()
        for n in vicini(*rc(k)):
            nk = '%d,%d' % n
            if nk in mare and nk not in zona and not bloccato(mare[k], mare[nk]):
                zona[nk] = z
                coda.append(nk)
from collections import Counter
print('celle di mare per zona', Counter(zona.values()), 'senza zona', len(mare) - len(zona))

# porti (le città con l'ancora sulla mappa) e le loro zone di mare
PORTI = {
    'NOR': ['Gothenburg', 'Hamburg', 'Bremen', 'Amsterdam', 'Antwerp', 'Yarmouth', 'London', 'Dover', 'Calais',
            'Boulogne', 'Portsmouth', 'Le Havre', 'Cherbourg', 'Copenhagen', 'Plymouth', 'Brest'],
    'BAL': ['Stockholm', 'St Petersburg', 'Narva', 'Riga', 'Memel', 'Konigsberg', 'Danzig', 'Stettin', 'Stralsund',
            'Lubeck', 'Copenhagen'],
    'ATL': ['Cardiff', 'Plymouth', 'Brest', 'Lorient', 'Nantes', 'Rochefort', 'Bordeaux', 'Bayonne', 'San Sebastian',
            'Corunna', 'Oporto', 'Vimeiro', 'Lisbon', 'Lagos', 'Cadiz', 'Gibraltar'],
    'MOC': ['Gibraltar', 'Cartagena', 'Valencia', 'Barcelona', 'Marseilles', 'Toulon', 'Genoa', 'Leghorn', 'Naples', 'Rome'],
    'MOR': ['Venice', 'Trieste'],
}
zone_porto = {}
for z, l in PORTI.items():
    for n in l:
        zone_porto.setdefault(n, []).append(z)
porti = []
for k, e in E.items():
    e.pop('mz', None); e.pop('porto', None)
    nome = e.get('c', {}).get('n', '')
    if nome in zone_porto:
        e['mz'] = sorted(zone_porto[nome]); e['porto'] = True
        porti.append(nome)
        continue
    zs = set()
    for n in vicini(*rc(k)):
        nk = '%d,%d' % n
        if nk in zona:
            zs.add(zona[nk])
    if zs and 'c' not in e:
        e['mz'] = sorted(zs)
print(len(porti), 'porti', sorted(set(zone_porto) - set(porti)), 'mancanti')
print('costieri', sum(1 for e in E.values() if 'mz' in e))
# ---------------- riquadro dell'Egitto ----------------
W = 116.6; R = W*math.sqrt(3)/2
OX, OY = 5653 + 75, 4153 + 4
MARE_EG = {(r, c) for r in range(1, 5) for c in range(0, 8)} - {(1, 8), (2, 8), (3, 7), (4, 7)}
MARE_EG |= {(3, 6), (4, 6), (4, 0), (4, 1), (5, 0), (5, 5)}
MARE_EG -= {(3, 7), (4, 7)}
MARE_EG |= {(8, 5), (9, 5), (10, 6), (11, 6), (11, 7), (12, 7), (12, 8), (13, 7), (13, 8), (14, 8), (14, 9), (15, 8), (15, 9)}
ROSSO = {(8, 5), (9, 5), (10, 6), (11, 6), (11, 7), (12, 7), (12, 8), (13, 7), (13, 8), (14, 8), (14, 9), (15, 8), (15, 9)}
NILO = {(5, 1), (5, 2), (5, 3), (5, 4), (6, 1), (6, 2), (6, 3), (6, 4), (7, 2), (7, 3), (8, 2), (8, 3), (9, 2), (9, 3),
        (10, 3), (11, 3), (11, 4), (12, 4), (12, 5), (13, 4), (13, 5), (14, 5), (15, 4), (15, 5)}
MONTI = {(8, 0), (10, 7), (10, 8), (1, 10)}
LAGHI = {(3, 10), (4, 10)}
CITTA = {(6, 1): ('Alexandria', 'maggiore'), (5, 1): ('Rosetta', 'minore'), (5, 4): ('Damietta', 'minore'),
         (5, 6): ('El Arish', 'minore'), (3, 7): ('Gaza', 'minore'), (2, 8): ('Jaffa', 'minore'),
         (1, 8): ('Acre', 'maggiore'), (3, 9): ('Jerusalem', 'minore'), (8, 3): ('Cairo', 'capitale'),
         (9, 2): ('Beni Suef', 'minore'), (11, 3): ('Asyut', 'minore'), (13, 4): ('Girga', 'minore'),
         (13, 5): ('Dendara', 'minore'), (14, 7): ('Kosseir', 'minore'), (15, 5): ('Aswan', 'minore'),
         (10, 0): ('Bawiti', 'minore')}

def egitto(r, c):
    # Egitto a ovest del golfo di Suez e nella striscia costiera fino a El Arish; il resto è Siria
    if r <= 4:
        return False
    if (r, c) == (14, 7):
        return True  # Kosseir, sulla costa egiziana del Mar Rosso
    if r in (5, 6):
        return c <= 6
    if r == 7:
        return c <= 6
    return c <= 5

def centro_eg(r, c):
    return (OX + (W/2)*(r % 2) + c*W, OY + r*R)

terra = {}
for r in range(1, 16):
    for c in range(0, 13):
        if (r, c) in MARE_EG:
            continue
        terra[(r, c)] = centro_eg(r, c)
for (r, c), (x, y) in terra.items():
    k = 'e%d,%d' % (r, c)
    t = 'deserto'
    if (r, c) in NILO: t = 'pianura'
    if (r, c) in MONTI: t = 'montagna'
    if (r, c) in LAGHI: t = 'palude'
    if r == 1 and (r, c) not in CITTA and c >= 9: t = t
    e = {'x': round(x*SC, 1), 'y': round(y*SC, 1), 't': t, 'st': 'EG' if egitto(r, c) else 'SY', 'a': 5, 'v': []}
    if (r, c) in NILO: e['nilo'] = True
    if r == 1 and c >= 9: e['nord'] = True   # ultima fila a nord della Siria: fonte turca
    if (r, c) in CITTA:
        e['c'] = {'n': CITTA[(r, c)][0], 'tipo': CITTA[(r, c)][1], 'st': e['st']}
    zs = set()
    for (r2, c2) in MARE_EG:
        x2, y2 = centro_eg(r2, c2)
        if abs(x2-x) < W*1.1 and abs(y2-y) < W*1.1 and math.hypot(x2-x, y2-y) < W*1.05:
            zs.add('ROS' if (r2, c2) in ROSSO else 'MOR')
    if r == 1 or c == 0 and r <= 6:
        pass
    if zs:
        e['mz'] = sorted(zs)
        if 'c' in e: e['porto'] = True
    E[k] = e
for (r, c), (x, y) in terra.items():
    k = 'e%d,%d' % (r, c)
    for (r2, c2), (x2, y2) in terra.items():
        if (r2, c2) != (r, c) and math.hypot(x2-x, y2-y) < W*1.05:
            E[k]['v'].append(['e%d,%d' % (r2, c2), ''])
print('esagoni egiziani', len(terra), 'porti', [E[k]['c']['n'] for k in E if k.startswith('e') and E[k].get('porto')])
json.dump(M, open(sys.argv[2], 'w'), separators=(',', ':'))
