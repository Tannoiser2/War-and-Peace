import json
from griglia import *
M=json.load(open('mappa.json'));E=M['esagoni']
for k in [k for k,h in E.items() if h['stato']=='']: del E[k]
MS=set(M['lati_mare'])
def nb(k):
    h=E[k];return [f'{r},{c}' for r,c in vicini(h['r'],h['c']) if f'{r},{c}' in E and '|'.join(sorted([k,f'{r},{c}'])) not in MS]
seen=set();comps=[]
for k in list(E):
    if k in seen: continue
    st=[k];c=[];seen.add(k)
    while st:
        x=st.pop();c.append(x)
        for y in nb(x):
            if y not in seen: seen.add(y);st.append(y)
    comps.append(c)
for c in comps:
    if len(c)<6:
        print('rimuovo',[(E[k].get('citta',{}).get('nome')) for k in c])
        for k in c: del E[k]
print(sorted(len(c) for c in comps),len(E))
M['fiumi']=[f for f in M['fiumi'] if all(p in E for p in f.split('|'))]
M['lati_mare']=[f for f in M['lati_mare'] if all(p in E for p in f.split('|'))]
M['confini']=[f for f in M['confini'] if all(p in E for p in f.split('|'))]
json.dump(M,open('mappa.json','w'))
