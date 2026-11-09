import json
from PIL import Image,ImageDraw,ImageFont
from griglia import *
H=json.load(open('frazioni.json'))
def tipo(h):
    if h['mar']>0.45: return None
    land=1-h['acq']-h['mar']
    if h['acq']>0.3 and 5250<h['x']<5950 and 2080<h['y']<2380: return 'palude'
    if h['acq']>0.72: return 'mare'
    if h['med']<108 and h['mg']>h['mr']+4 and h['sd']>22: return 'foresta'
    if h['sd']>28 and h['mr']>=h['mg']-14 and h['acq']<0.2: return 'montagna'
    return 'pianura'
out={}
for k,h in H.items():
    t=tipo(h)
    if t: out[k]=dict(h,t=t)
json.dump(out,open('tipi.json','w'))
im=Image.open('/home/claude/look/map_full.png').convert('RGB');d=ImageDraw.Draw(im)
col={'mare':(0,0,255),'foresta':(0,90,0),'montagna':(150,60,0),'pianura':(255,255,0),'palude':(0,255,255)}
fnt=ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf',30) if __import__('os').path.exists('/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf') else None
for k,h in out.items():
    x,y=h['x'],h['y'];d.ellipse([x-14,y-14,x+14,y+14],fill=col[h['t']],outline='black')
im.thumbnail((2400,2400));im.save('/home/claude/look/tipi.png')
import collections;print(collections.Counter(h['t'] for h in out.values()))
