import numpy as np,json,pytesseract
from PIL import Image,ImageOps
P=json.load(open('punti.json'))
im=Image.open('/home/claude/look/map_full.png').convert('RGB')
A=np.asarray(im).astype(int)
def ocr(box,red):
    c=A[box[1]:box[3],box[0]:box[2]]
    if c.size==0: return ''
    if red: m=(c[...,0]>180)&(c[...,1]<90)&(c[...,2]<90)
    else: m=(c.max(2)<60)
    g=Image.fromarray(np.where(m,0,255).astype(np.uint8)).resize(((box[2]-box[0])*2,(box[3]-box[1])*2))
    t=pytesseract.image_to_string(g,config='--psm 7').strip()
    return t
cities=[]
for kind,red in (('rossi',True),('neri',False)):
    for x,y,a in P[kind]:
        if not (140<a<260): continue
        x,y=int(x),int(y)
        cand=[]
        for box in [(x+12,y-28,x+300,y+22),(x-300,y-28,x-12,y+22),(x-150,y-60,x+150,y-12),(x-150,y+12,x+150,y+60)]:
            t=ocr(box,red)
            t=''.join(ch for ch in t if ch.isalpha() or ch in " .-'")
            cand.append(t.strip())
        best=max(cand,key=lambda t:sum(ch.isalpha() for ch in t))
        cities.append({'x':x,'y':y,'maggiore':red,'nome':best,'alt':cand})
json.dump(cities,open('citta_ocr.json','w'),indent=0,ensure_ascii=False)
for c in cities: print(c['maggiore'],c['x'],c['y'],c['nome'],'|',c['alt'])
