import numpy as np,json
from PIL import Image
from griglia import *
im=np.asarray(Image.open('/home/claude/look/map_full.png').convert('RGB')).astype(int)
r_,g_,b_=im[...,0],im[...,1],im[...,2]
br=im.mean(2)
mx=im.max(2);mn=im.min(2);sat=mx-mn
maroon=(r_>g_+30)&(r_<170)&(b_<110)&(g_<90)
water=(b_>r_+15)&(g_>=r_)&(b_>110)
clear=(g_>r_+12)&(g_>b_+40)&(br>95)
forest=(g_>=r_-5)&(br<100)&(g_>b_+10)
mount=(np.abs(r_-g_)<22)&(r_>g_-8)&(b_<g_-5)&(~maroon)&(sat>15)
hexes={}
yy,xx=np.mgrid[-55:56,-55:56];disk=(xx**2+yy**2)<=52**2
for r in range(NR):
  for c in range(NC):
    x,y=centro(r,c)
    if x<60 or y<60 or x>IMG_W-60 or y>IMG_H-60: continue
    if escluso(x,y): continue
    X,Y=int(round(x)),int(round(y))
    sl=(slice(Y-55,Y+56),slice(X-55,X+56))
    n=disk.sum()
    land=(~maroon[sl])&(~water[sl])&disk&(sat[sl]<120)
    L=im[sl][land]
    bb=br[sl][land]
    f={k:float((m[sl]&disk).sum())/n for k,m in [('mar',maroon),('acq',water),('pia',clear),('for',forest),('mon',mount)]}
    ft={'mr':float(L[:,0].mean()) if len(L) else 0,'mg':float(L[:,1].mean()) if len(L) else 0,'mb':float(L[:,2].mean()) if len(L) else 0,'med':float(np.median(bb)) if len(bb) else 0,'sd':float(bb.std()) if len(bb) else 0}
    hexes[f'{r},{c}']={'r':r,'c':c,'x':round(x,1),'y':round(y,1),**{k:round(v,3) for k,v in f.items()},**{k:round(v,1) for k,v in ft.items()}}
json.dump(hexes,open('frazioni.json','w'))
print(len(hexes),NR,NC)
