class_name Carte
## Carte evento comuni (cuori e quadri, più i due jolly) del supplemento "A Soul for War and Peace"
## (Avalon Digital 2025), da usare negli scenari come regola facoltativa.
## Finestre in cui si giocano: logoramento (prima del proprio logoramento), movimento (all'inizio del
## proprio movimento), round (all'inizio di un round di battaglia), dadi (dopo i dadi, prima dei
## risultati), dopo (dopo i risultati), auto (le gioca il gioco da solo quando servono), reazione
## (quando l'avversario gioca una carta).

const DATI := {
	"C1": {"nome": "Cannoni d'assedio", "f": "movimento", "testo": "Il livello di un tuo assedio sale di due (al massimo 5)."},
	"C2": {"nome": "Breccia nelle mura", "f": "round", "testo": "Nell'assalto a una città: il morale dei difensori scende di uno per il resto della battaglia."},
	"C3": {"nome": "Carri dei viveri", "f": "logoramento", "testo": "Le truppe di un esagono non subiscono logoramento e per questo turno sono rifornite."},
	"C4": {"nome": "Magazzini", "f": "logoramento", "testo": "Il dado del tuo logoramento scende di uno."},
	"C5": {"nome": "Trasporto su carri", "f": "auto", "testo": "Toglie uno al dado di una marcia forzata. Si gioca da sola quando migliora il risultato."},
	"C6": {"nome": "Marciare al rombo del cannone", "f": "auto", "testo": "Più due al valore del capo in un tiro per i rinforzi in battaglia. Si gioca da sola quando fa riuscire il tiro."},
	"C7": {"nome": "Pontieri", "f": "movimento", "testo": "In un esagono con un fiume il fiume non costa movimento per questo turno, come se ci fosse un ponte."},
	"C8": {"nome": "Incursione di cavalleria", "f": "movimento", "testo": "Un esercito nemico vicino al tuo tira subito per il logoramento, con più uno se ha meno cavalleria della tua."},
	"C9": {"nome": "Ponti rotti, strade bloccate", "f": "auto", "testo": "Un tentativo nemico di portare rinforzi in battaglia fallisce. Si gioca da sola contro rinforzi di almeno 3 PF."},
	"C10": {"nome": "La grande ridotta", "f": "dadi", "testo": "Per chi difende, dopo i dadi: D1 diventa 1, D2 diventa D1, D3 diventa D2 in questo round."},
	"C11": {"nome": "Tenete la linea!", "f": "dopo", "testo": "Dopo i risultati: la demoralizzazione delle tue truppe scende di un livello."},
	"C12": {"nome": "Raccolta attorno alle bandiere", "f": "dopo", "testo": "Dopo i risultati: la demoralizzazione delle tue truppe sparisce."},
	"C13": {"nome": "Cannoni da dodici", "f": "round", "testo": "Primo round, capo da 2 o 3 con almeno 5 PF: un dado; se supera di almeno 2 il morale nemico, il nemico perde un punto di morale per tutta la battaglia."},
	"Q1": {"nome": "Volteggiatori avanti!", "f": "reazione", "testo": "Annulla una carta nemica che cambia il tiro di battaglia: torna in mano a chi l'ha giocata, che non può usarla in questo turno."},
	"Q2": {"nome": "Un terreno eccellente", "f": "round", "testo": "Più uno a tuo favore in ogni round di una battaglia in cui difendi."},
	"Q3": {"nome": "Paese fortificato", "f": "round", "testo": "Nel turno dell'avversario: più uno a tuo favore in questo round."},
	"Q4": {"nome": "Granatieri in massa", "f": "round", "testo": "Più due a tuo favore in questo round, ma perdi un punto forza in più."},
	"Q5": {"nome": "Carica dei corazzieri", "f": "round", "testo": "Con cavalleria: più due a tuo favore in questo round; se il nemico non subisce almeno D1 perdi un punto forza di cavalleria in più. Non insieme alla carica di cavalleria (V)."},
	"Q6": {"nome": "Ingannati!", "f": "round", "testo": "Chi attacca, al primo round: il difensore non può giocare carte in questa battaglia."},
	"Q7": {"nome": "Si salvi chi può!", "f": "dopo", "testo": "Dopo aver inflitto un risultato D in battaglia campale: il nemico deve ritirarsi e perde tanti punti forza quanto vale il tuo capo."},
	"Q8": {"nome": "Inseguimento della cavalleria leggera", "f": "auto", "testo": "Quando un esercito nemico si ritira da una battaglia perde un punto forza in più. Si gioca da sola."},
	"Q9": {"nome": "Cornamuse, tamburi e canti patriottici", "f": "dadi", "testo": "Dopo un risultato D contro di te: le perdite restano, ma il morale non scende."},
	"Q10": {"nome": "La fortuna aiuta gli audaci", "f": "dadi", "testo": "Dopo i dadi: più o meno uno al tiro di battaglia."},
	"Q11": {"nome": "Capo fuori combattimento", "f": "round", "testo": "Il capo nemico che comanda la battaglia vale zero per il resto del turno."},
	"Q12": {"nome": "Rimonta della cavalleria", "f": "movimento", "testo": "Un punto forza di cavalleria nella tua capitale ora e nel turno dopo."},
	"Q13": {"nome": "Chiamata della nuova classe", "f": "movimento", "testo": "Due punti forza di fanteria nella tua capitale ora e nei due turni dopo."},
	"J1": {"nome": "Jolly", "f": "reazione", "testo": "Annulla una carta giocata dall'avversario: la carta e il jolly tornano nel mazzo."},
	"J2": {"nome": "Jolly", "f": "reazione", "testo": "Annulla una carta giocata dall'avversario: la carta e il jolly tornano nel mazzo."},
}

## Carte che cambiano il tiro di battaglia (le annullano i Volteggiatori)
const SUL_TIRO := ["Q2", "Q3", "Q4", "Q5", "Q10"]

## Quante carte può tenere in mano ogni potenza
const LIMITE := {"FR": 4, "EN": 3, "AU": 2, "RU": 2, "PR": 2, "SP": 1, "TU": 2}

## Capitali per le nuove leve
const CAPITALI := {"FR": ["Paris"], "AU": ["Vienna"], "PR": ["Berlin"], "RU": ["St Petersburg", "Moscow"], "EN": ["London"], "SP": ["Madrid"]}

static func seme(id: String) -> String:
	if id.begins_with("J"):
		return "Jolly"
	return "Cuori" if id.begins_with("C") else "Quadri"

static func valore(id: String) -> String:
	if id.begins_with("J"):
		return ""
	var n := int(id.substr(1))
	match n:
		1: return "Asso"
		11: return "Fante"
		12: return "Donna"
		13: return "Re"
	return str(n)

static func titolo(id: String) -> String:
	var c := id.split("@")[0]
	var segno := ""
	if c.begins_with("Q10") and c.length() > 3:
		segno = " (%s1)" % c.substr(3)
		c = "Q10"
	if c.begins_with("J"):
		return "Jolly"
	return "%s di %s: %s%s" % [valore(c), seme(c), DATI[c]["nome"], segno]
