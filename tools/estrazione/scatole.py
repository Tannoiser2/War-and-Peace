import json,numpy as np
from PIL import Image
from griglia import *
M=json.load(open('mappa.json'));E=M['esagoni']
im=np.asarray(Image.open('/home/claude/look/map_full.png').convert('RGB')).astype(int)
tan=(np.abs(im[...,0]-200)<30)&(np.abs(im[...,1]-160)<30)&(np.abs(im[...,2]-120)<30)
rm=[]
for k,h in E.items():
    X,Y=int(h['x']),int(h['y'])
    f=tan[Y-50:Y+50,X-50:X+50].mean()
    nmare=sum(1 for r,c in vicini(h['r'],h['c']) if f'{r},{c}' not in E)
    if f>0.38 and nmare>=2 and 'citta' not in h: rm.append((k,round(f,2),nmare))
print(rm)
for k,*_ in rm: del E[k]
for key in ('fiumi','confini','lati_mare'):
    M[key]=[f for f in M[key] if all(p in E for p in f.split('|'))]
json.dump(M,open('mappa.json','w'))
print(len(E))
