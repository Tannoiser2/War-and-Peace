import json,heapq,numpy as np
from griglia import *
T=json.load(open('tipi.json'));L=json.load(open('lati.json'));C=json.load(open('citta.json'))
FL=json.load(open('flag_tts.json'))
s,cx,cy=91.6,3700,2920
STATO={}
def add(st,names):
    for n in names.split(','): STATO[n.strip()]=st
add('FR','Paris,Lille,Rheims,Strasbourg,Brest,Lyon,Bordeaux,Toulouse,Bayonne,Toulon,Marseilles,Amiens,Verdun,Metz,Le Havre,Cherbourg,Lorient,Nantes,Tours,Dijon,Nevers,Grenoble,Avignon,Rochefort,Calais,Boulogne,Antwerp,Brussels,Liege,Namur,Cologne,Coblenz,Mainz,Turin,Genoa,Geneva')
add('EN','London,Yarmouth,Cardiff,Portsmouth,Plymouth,Dover,Gibraltar,Valletta')
add('SP','Madrid,San Sebastian,Burgos,Barcelona,Ciudad Rodrigo,Toledo,Valencia,Badajoz,Seville,Granada,Cadiz,Corunna,Pamplona,Saragossa,Talavera,Baylen,Cordoba,Cartagena')
add('Pt','Lisbon,Oporto,Vimeiro,Lagos')
add('AU','Vienna,Budapest,Prague,Innsbruck,Venice,Trieste,Leoben,Olmutz,Lemberg,Cracow,Lublin')
add('PR','Berlin,Konigsberg,Magdeburg,Posen,Warsaw,Breslau,Danzig,Stettin,Memel,Thorn,Munster,Bayreuth,Ansbach')
add('RU','Moscow,St Petersburg,Riga,Smolensk,Grodno,Minsk,Orel,Brest-Litovsk,Kiev,Kharkov,Novgorod,Pskov,Velikiye Luki,Kovno,Vilna,Pinsk,Vitebsk,Tula,Poltava,Narva,Alexandrov')
add('Ha','Hanover,Hamburg,Bremen,Lubeck'); add('He','Cassel'); add('S','Leipzig,Dresden,Weimar')
add('B','Munich,Ulm,Ratisbon'); add('Wu','Stuttgart'); add('Ba','Baden'); add('R','Frankfurt,Wurzburg')
add('Br','Brunswick'); add('H','Amsterdam'); add('Sz','Zurich,Basel,Neuchatel'); add('I','Milan,Mantua,Florence,Leghorn,San Marino')
add('N','Naples,Rome'); add('D','Copenhagen'); add('Sw','Stockholm,Orebro,Gothenburg,Stralsund')
MAGG={'FR':'FR','EN':'EN','SP':'SP','AU':'AU','PR':'PR','RU':'RU'}
def hex_di(x,y):
    k=min(T,key=lambda k:(T[k]['x']-x)**2+(T[k]['y']-y)**2)
    if T[k]['t']=='mare': T[k]['t']='pianura'
    return k
citta={}
for c in C:
    k=hex_di(c['x'],c['y'])
    tipo='capitale' if c.get('capitale') else ('maggiore' if c['maggiore'] else 'minore')
    rank={'capitale':3,'maggiore':2,'minore':1}
    if k in citta and rank[citta[k]['tipo']]>=rank[tipo]: continue
    citta[k]={'nome':c['nome'],'tipo':tipo,'stato':STATO.get(c['nome'],'?'),'px':c['x'],'py':c['y']}
# bandiere iniziali
for f,X,Z in FL:
    px,py=cx+s*X,cy-s*Z
    best=min(C,key=lambda c:(c['x']-px)**2+(c['y']-py)**2)
    if (best['x']-px)**2+(best['y']-py)**2<90**2:
        k=hex_di(best['x'],best['y'])
        if k in citta: citta[k]['bandiera']=f
print('citta',len(citta),'senza stato',[c['nome'] for c in citta.values() if c['stato']=='?'])
def lato(a,b): return L.get('|'.join(sorted([a,b])),{'fiume':0,'conf':0,'nero':0})
def adiac(k):
    h=T[k]
    for r,c in vicini(h['r'],h['c']):
        k2=f'{r},{c}'
        if k2 in T and T[k2]['t']!='mare': yield k2
terra=[k for k in T if T[k]['t']!='mare']
def bfs(seeds,campo,soglia,pen):
    dist={};lab={};pq=[]
    for k,v in seeds:
        dist[k]=0;lab[k]=v;heapq.heappush(pq,(0,k))
    while pq:
        d,k=heapq.heappop(pq)
        if d>dist[k]: continue
        for k2 in adiac(k):
            if lato(k,k2).get('mare',0)>0.5: continue
            nd=d+1+(pen if lato(k,k2)[campo]>soglia else 0)
            if nd<dist.get(k2,1e9): dist[k2]=nd;lab[k2]=lab[k];heapq.heappush(pq,(nd,k2))
    return lab
stati=bfs([(k,c['stato']) for k,c in citta.items() if c['stato']!='?'],'conf',0.3,40)
seed_area={'Madrid':1,'Paris':2,'London':2,'Vienna':3,'Berlin':3,'Moscow':4}
aree=bfs([(k,seed_area[c['nome']]) for k,c in citta.items() if c['nome'] in seed_area],'nero',0.45,60)
H={}
for k in terra:
    h=T[k]
    e={'r':h['r'],'c':h['c'],'x':h['x'],'y':h['y'],'t':h['t'],'stato':stati.get(k,''),'area':aree.get(k,2)}
    if k in citta: e['citta']=citta[k]
    H[k]=e
fiumi=[kk for kk,l in L.items() if l['fiume']>0.5]
confini=[kk for kk,l in L.items() if l['conf']>0.35]
mari=[kk for kk,l in L.items() if l.get('mare',0)>0.5]
fiumi=[f for f in fiumi if f not in mari]
json.dump({'griglia':{'W':W,'X0':X0,'Y0':Y0,'RMIN':RMIN,'CMIN':CMIN,'img':[IMG_W,IMG_H]},'esagoni':H,'fiumi':fiumi,'confini':confini,'lati_mare':mari},open('mappa.json','w'))
import collections
print(len(H),collections.Counter(e['stato'] for e in H.values()),collections.Counter(e['area'] for e in H.values()))
