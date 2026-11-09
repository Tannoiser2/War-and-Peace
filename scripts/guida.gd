## Le regole in breve (riassunto in italiano delle regole base, con le note della versione digitale).
class_name Guida
extends RefCounted

const TESTO := """[b]Lo scopo[/b]
Ogni turno è un mese. Muovono prima i Francesi, poi la Coalizione. Si vince con le città obiettivo controllate a fine partita e con le battaglie vinte (si guadagna un punto entrando dopo la battaglia in un esagono che all'inizio del combattimento aveva almeno 5 punti forza nemici; la Coalizione ne guadagna 2 se lì c'era Napoleone).

[b]Le pedine[/b]
Le unità valgono in [i]punti forza[/i] (PF, circa 5.000 uomini ciascuno): fanteria, cavalleria, Guardia, Landwehr, milizie, cosacchi. Il [i]morale[/i] va da 0 a 3: Guardia 3; fanteria e cavalleria di Francia, Inghilterra e Russia 2; le altre e i minori 1; Landwehr, milizie, partigiani e cosacchi 0. I [i]capi[/i] hanno un valore di comando da 0 a 3 e non perdono punti forza.

[b]Il turno di ciascun lato[/b]
1. [b]Logoramento[/b]: un dado per tutti gli esagoni con almeno 3 PF; il risultato dipende dai PF ammassati. -1 se tutti francesi, -1 se in patria, +1 senza rifornimento, +1 d'inverno (novembre-febbraio), +1 nelle aree di mappa 1 (Spagna) e 4 (Russia), più il livello d'assedio per chi è assediato. Grandi armate ferme si consumano: meglio dividerle e riunirle per la battaglia.
2. [b]Alleanze[/b]: un dado (modificato dai punti vittoria) può far entrare in guerra un neutrale. Nel 1805: con 7 la Prussia si unisce alla Coalizione; con 0 dei Francesi resta neutrale per sempre.
3. [b]Rinforzi[/b] secondo lo scenario, e capi feriti che tornano.
4. [b]Movimento[/b].
5. [b]Combattimento[/b].
Il primo turno non ha logoramento né alleanze.

[b]Il movimento[/b]
La fanteria non si muove da sola: segue un capo del suo colore che era con lei a inizio movimento, al massimo 10 PF (12 con Napoleone e Wellington) e solo per i primi 3 punti movimento del capo. La cavalleria si muove anche da sola, fino a 4 punti. I capi hanno 10 punti (Napoleone e Wellington 12): dopo aver lasciato le truppe possono proseguire da soli, ma non raccolgono altre truppe dopo essersi mossi.
Costi: terreno aperto 1, foresta 2, montagna 3, palude 3, +1 per attraversare un fiume. I territori dei neutrali sono chiusi.
[b]Marcia forzata[/b]: per andare oltre si possono chiedere 1, 2 o 3 punti in più. Un dado decide quanti se ne ottengono, e con l'asterisco si perde un punto forza. -1 se sono tutti francesi (-2 se tutta Guardia), +1 senza rifornimento, +1 nelle aree 1 e 4, +1 d'inverno.
[b]Travolgimento[/b]: un gruppo rifornito che ha almeno 4 contro 1 (5 contro 1 in montagna o contro trincee) può entrare in un esagono nemico pagando 1 punto in più (niente con 6 contro 1) ed eliminare i difensori. Chi è in città non può essere travolto; contro la cavalleria serve almeno altrettanta cavalleria.
[b]Trincee[/b]: 3 o più PF fermi possono trincerarsi (non nelle città maggiori).

[b]Il rifornimento[/b]
Un esagono è rifornito se si arriva a meno di 3 punti movimento da una città maggiore della propria patria (o di un satellite), senza passare per esagoni nemici. Anche le unità dello stesso colore già rifornite fanno da deposito, a catena. Nel 1805 i Russi possono rifornirsi anche dalle città maggiori austriache.

[b]Il combattimento[/b]
Si attacca da un esagono a uno adiacente. Il capo che conta è quello dello stesso colore nella pila più grande. Chi ha più forza tira due dadi: + il suo comando e il suo morale, - quelli dell'avversario; il terreno aiuta chi è attaccato (foresta 1, montagna 2, palude 1, fiume 2, trincee 1); in tutto al massimo ±4. Il rapporto di forze (1:1, 3:2, 2:1; da 4:1 in su la forza piccola è travolta) e il risultato danno le perdite di entrambe le parti, in proporzione alla forza più piccola, e la [i]demoralizzazione[/i] (D1-D3, che abbassa il morale).
Dopo ogni round: l'attaccante decide se continuare, il difensore se ritirarsi, poi ogni esagono vicino può entrare in battaglia con un dado + comando di 5 o più (rinforzi). Chi arriva a morale 0 si ritira. Le unità senza rifornimento dell'attaccante valgono metà.
[b]Ritirata[/b]: di un esagono, non più lontano dai rifornimenti; se il nemico ha più cavalleria si perde un punto forza. Chi non ha via di scampo è catturato.
[b]Città[/b]: chi è attaccato in una sua città può chiudere dentro fino a 6 PF (4 nelle città minori). L'attaccante sceglie fra assalto (i difensori valgono doppio; con morale 0 si arrendono) e assedio: ogni mese un dado, se esce un numero non superiore ai mesi d'assedio la città si arrende.
[b]Capi[/b]: alla fine del combattimento ogni capo che ha partecipato tira due dadi: con 12 è ferito (torna dopo 1-5 mesi) o, con un altro 6, ucciso.

[b]Note sulla versione digitale[/b]
Il modulo di Tabletop Simulator contiene la mappa, le pedine e il regolamento, ma non la tabella dei combattimenti, quella delle perdite, del logoramento, della marcia forzata e degli effetti del terreno, né il libretto degli scenari. Le tabelle usate qui sono [b]ricostruite[/b] in modo coerente con gli esempi del regolamento e lo scenario del 1805 è [b]ricostruito[/b] sulla storia: appena saranno disponibili le tabelle e gli scenari originali verranno sostituiti.
Semplificazioni: niente movimento navale, niente contrattacchi di chi viene attaccato, i rinforzi in battaglia si tentano in automatico (si possono spegnere nel menu)."""
