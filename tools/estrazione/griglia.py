import numpy as np
W=116.6;X0=3046;Y0=1801;R=W*np.sqrt(3)/2;S=W/np.sqrt(3)
IMG_W,IMG_H=7439,5859
RMIN=int(np.floor((0-Y0)/R))-1  # row index offset so row 0 is top
CMIN=-int(X0/W)-1
def centro(r,c):
    rr=r+RMIN
    off=(W/2)*(rr%2)
    return (X0+off+(c+CMIN)*W+W/2, Y0+rr*R)
NR=int((IMG_H-Y0)/R)-RMIN+2
NC=int(IMG_W/W)+4
# rettangoli esclusi (pixel pieni)
s=1/0.24196
ESCLUSI=[(0,0,620,415),(430,10,620,130),(790,15,890,110),(135,435,235,535),(25,715,125,815),(1610,670,1720,755),(10,935,70,1315),(1265,1000,1800,1420)]
ESCLUSI=[(a*s,b*s,c*s,d*s) for a,b,c,d in ESCLUSI]
def escluso(x,y):
    tx,ty=x/s,y/s
    if 755<=ty<=1008 and tx<=1800 and tx>=1110+(1008-ty)*(1330-1110)/(1008-755): return True
    return any(a<=x<=c and b<=y<=d for a,b,c,d in ESCLUSI)
def vicini(r,c):
    rr=r+RMIN
    if rr%2==0: d=[(0,-1),(0,1),(-1,-1),(-1,0),(1,-1),(1,0)]
    else: d=[(0,-1),(0,1),(-1,0),(-1,1),(1,0),(1,1)]
    return [(r+a,c+b) for a,b in d]
def vertici(r,c):
    x,y=centro(r,c)
    return [(x+S*np.cos(np.radians(a)),y+S*np.sin(np.radians(a))) for a in (30,90,150,210,270,330)]
