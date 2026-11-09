import json,os
from PIL import Image
U={u['i']:u for u in json.load(open('/home/claude/look/uniq.json'))}
BASE='/home/claude/src_wp/Mods/'
spec={}
def S(i,naz,tipo,sp,sub=''): spec[i]={'k':'u','naz':naz,'tipo':tipo,'sp':sp,'sub':sub}
def L(i,naz,nome,val,sub=''): spec[i]={'k':'l','naz':naz,'nome':nome,'val':val,'sub':sub}
for i,(t,v) in zip(range(0,9),[('I',1),('I',5),('I',10),('I',15),('I',20),('L',1),('L',5),('C',1),('C',5)]): S(i,'AU',t,v)
S(9,'AU','I',1,'Pm');S(10,'AU','I',5,'Pm');S(11,'AU','C',1,'Pm')
for i,(t,v) in zip(range(12,26),[('I',1),('I',5),('I',10),('I',15),('I',20),('GI',5),('GI',1),('P',1),('GC',1),('C',1),('C',5),('S',2),('S',1),('T',1)]): S(i,'FR',t,v)
for i,(sub,t,v) in zip(range(26,54),[('B','I',1),('B','I',5),('B','C',1),('D','I',1),('D','C',1),('D','S',2),('D','S',1),('D','T',1),('H','I',1),('H','C',1),('I','I',5),('Da','I',1),('I','I',1),('N','I',1),('Po','C',1),('Po','I',1),('Po','I',5),('Pt','I',1),('R','I',1),('S','I',1),('S','I',5),('S','C',1),('W','I',1),('W','I',5),('Sz','I',1),('Sp','I',1),('W','C',1),('Wu','I',1)]): S(i,'FR',t,v,sub)
for i,(t,v) in zip(range(54,65),[('I',1),('I',5),('L',1),('M',5),('M',1),('P',1),('M',1),('C',1),('S',1),('S',2),('T',1)]): S(i,'EN',t,v)
S(65,'EN','I',1,'K');S(66,'EN','I',5,'K')
for i,(sub,t,v) in zip(range(67,75),[('H','I',1),('H','I',5),('H','C',1),('Pt','I',1),('Pt','I',5),('Pt','C',1),('Pt','S',1),('Pt','T',1)]): S(i,'EN',t,v,sub)
for i,(n,v) in zip(range(78,85),[('Wellington',3),('Moore',2),('Beresford',1),('Hill',1),('Uxbridge',1),('Nelson',1),('Leader A',0)]): L(i,'EN',n,v)
L(85,'EN','Leader A',0,'Pt')
for i,(t,v) in zip(range(86,98),[('I',10),('I',15),('I',20),('I',1),('I',5),('L',5),('L',15),('L',20),('L',10),('L',1),('C',1),('C',5)]): S(i,'PR',t,v)
S(98,'PR','I',1,'Br');S(99,'PR','I',1,'He');S(100,'PR','I',1,'S');S(101,'PR','C',1,'S')
for i,(n,v) in zip(range(102,113),[('Blucher',2),('Brunswick',1),('Bulow',1),('Hohenlohe',1),('Kleist',1),('Ruchel',1),('Yorck',1),('Leader A',0),('Leader B',0),('Leader C',0),('Leader D',0)]): L(i,'PR',n,v)
L(113,'PR','Leader A',0,'S')
for i,(t,v) in zip(range(114,125),[('I',15),('I',20),('I',1),('I',5),('I',10),('GI',1),('C',1),('GC',1),('CC',1),('S',1),('T',1)]): S(i,'RU',t,v)
for i,(t,v) in zip(range(125,130),[('I',1),('I',5),('C',1),('S',1),('T',1)]): S(i,'RU',t,v,'Sw')
for i,(n,v) in zip(range(130,142),[('Bagration',2),('Barclay',2),('Kutusov',2),('Bennigsen',1),('Buxhowden',1),('Constantine',1),('Docturov',1),('Tormazov',1),('Wittgenstein',1),('Leader A',0),('Leader B',0),('Leader C',0)]): L(i,'RU',n,v)
L(142,'RU','Bernadotte',1,'Sw');L(143,'RU','Leader A',0,'Sw')
for i,(t,v) in zip(range(144,152),[('I',1),('I',5),('M',5),('M',1),('P',1),('C',1),('S',1),('T',1)]): S(i,'SP',t,v)
for i,(n,v) in zip(range(154,159),[('Blake',1),('Pallafox',1),('La Romana',1),('Castanos',0),('Cuesta',0)]): L(i,'SP',n,v)
S(159,'TU','I',10);S(163,'TU','I',1);S(164,'TU','I',5);S(160,'TU','C',1,'Mm')
for i,(n,v) in zip(range(176,198),[('Charles',2),('Schwarzenberg',2),('Bellegarde',1),('Hiller',1),('John',1),('Louis',1),('Mack',1),('Kray',1),('Melas',1),('Leader A',1),('Leader B',1),('Beaulieu',0),('Davidovich',0),('Meszaros',0),('Quasdanovich',0),('Wurmser',0),('Leader C',0),('Leader D',0),('Leader E',0),('Leader F',0),('Leader G',0),('Leader H',0)]): L(i,'AU',n,v)
L(198,'AU','Colli',0,'Pm');L(322,'AU','Ferdinand',1)
for i,(n,v) in zip(range(199,231),[('Napoleon',3),('Davout',2),('Soult',2),('Bonaparte',2),('Desaix',2),('Lannes',2),('Massena',2),('Kellermann',1),('Kleber',1),('Moreau',1),('Eugene',1),('Marmont',1),('Murat',1),('Ney',1),('Poniatowski',1),('Victor',1),('Bernadotte',1),('Bessieres',1),('Augereau',1),('Joubert',1),('Leader A',1),('Leader B',1),('Leader C',1),('Leader D',1),('Leader E',1),('Jerome',1),('Leader A',0),('Joseph',0),('Leader F',0),('Leader G',0),('Leader H',0),('Leader I',0)]): L(i,'FR',n,v)
spec[224]['sub']='W';spec[225]['sub']='I?'
S(231,'FR','C',1,'N');S(310,'FR','C',1,'I')
M={236:'battaglia',244:'assedio1',245:'assedio3',246:'assedio5',247:'fortezza',248:'demoralizzato',249:'nonrifornito',252:'esilio',323:'bandiera_FR',324:'bandiera_AU',325:'bandiera_PR',326:'bandiera_RU',327:'bandiera_EN',328:'bandiera_SP',329:'bandiera_TU'}
OUT='/home/claude/war-and-peace/assets/pedine/'
cat={'unita':[],'capi':[],'segnalini':{}}
seen={}
for i,s in spec.items():
    u=U[i];im=Image.open(BASE+u['front']).convert('RGBA').resize((128,120),Image.LANCZOS)
    if s['k']=='u':
        nm=f"{s['naz']}_{s['sub'] or 'x'}_{s['tipo']}_{s['sp']}"
        if nm in seen: continue
        seen[nm]=1
        im.save(OUT+nm+'.webp',quality=88)
        cat['unita'].append(dict(s,img=nm,n=u['n']))
    else:
        nm=f"capo_{s['naz']}_{s['sub'] or 'x'}_{s['nome'].replace(' ','_')}"
        if nm in seen: nm+='_'+str(i)
        seen[nm]=1
        im.save(OUT+nm+'.webp',quality=88)
        cat['capi'].append(dict(s,img=nm))
for i,n in M.items():
    Image.open(BASE+U[i]['front']).convert('RGBA').resize((128,120),Image.LANCZOS).save(OUT+'seg_'+n+'.webp',quality=88)
    cat['segnalini'][n]='seg_'+n
json.dump(cat,open('/home/claude/war-and-peace/assets/pedine/catalogo.json','w'),indent=1,ensure_ascii=False)
print(len(cat['unita']),len(cat['capi']))
