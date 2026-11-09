import numpy as np,json
from PIL import Image
from griglia import *
im=np.asarray(Image.open('/home/claude/look/map_full.png').convert('RGB')).astype(int)
r_,g_,b_=im[...,0],im[...,1],im[...,2]
water=(b_>r_+15)&(g_>=r_)&(b_>110)
red=(r_>190)&(g_<90)&(b_<90)
black=(r_<60)&(g_<60)&(b_<60)
T=json.load(open('tipi.json'))
lati={}
def key(a,b): return '|'.join(sorted([a,b]))
for k,h in T.items():
    if h['t']=='mare': continue
    for (r2,c2) in vicini(h['r'],h['c']):
        k2=f'{r2},{c2}'
        if k2 not in T or T[k2]['t']=='mare': continue
        kk=key(k,k2)
        if kk in lati: continue
        v1=vertici(h['r'],h['c']);v2=vertici(r2,c2)
        sh=[p for p in v1 if min((p[0]-q[0])**2+(p[1]-q[1])**2 for q in v2)<4]
        if len(sh)!=2: continue
        (ax,ay),(bx,by)=sh
        dx,dy=bx-ax,by-ay;L=np.hypot(dx,dy);nx,ny=-dy/L,dx/L
        cnt=np.zeros(4);n=0
        for t in np.linspace(0.12,0.88,24):
            px,py=ax+dx*t,ay+dy*t
            hw=hr=hb=0
            for o in range(-7,8,2):
                x,y=int(px+nx*o),int(py+ny*o)
                hw|=water[y,x];hr|=red[y,x];hb|=black[y,x]
            ma=water[int(py+ny*22),int(px+nx*22)] and water[int(py-ny*22),int(px-nx*22)]
            cnt+=[hw,hr,hb,ma];n+=1
        f=cnt/n
        lati[kk]={'fiume':round(f[0],2),'conf':round(f[1],2),'nero':round(f[2],2),'mare':round(f[3],2)}
json.dump(lati,open('lati.json','w'))
import collections
print(len(lati))
for nm,i in (('fiume',0),('conf',1),('nero',2)):
    v=np.array([l[nm] for l in lati.values()]);print(nm,np.histogram(v,bins=10,range=(0,1))[0])
