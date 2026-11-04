class_name NoDialogo
extends RefCounted

## Um no da arvore de dialogo: o que e dito, o que pode ser escolhido depois e o
## que a passagem por aqui muda no mundo.
##
## FORMATO (autoral/dialogos/<id>.json, dentro de "nos"):
##
##   "raiz": {
##     "falas": ["Voce e novo por aqui?"],
##     "variantes": [
##       {"se": {"falou_com": "anselmo"}, "falas": ["De volta, hein?"]}
##     ],
##     "escolhas": [
##       {"texto": "Sim, acabei de chegar.", "destino": "chegou"},
##       {"texto": "Sobre o rio",  "destino": "rio", "se": {"visitou": "ribeira"}},
##       {"texto": "Sair", "destino": "fim"}
##     ],
##     "efeitos": {"definir": {"conheceu_anselmo": true}},
##     "seguinte": "outro_no",
##     "fim": false
##   }
##
## Uma FALA e uma String ou {"quem", "texto", "retrato"}. `quem` aceita "npc"
## (padrao), "jogador" ou um nome livre — e o que permite um terceiro personagem
## entrar na conversa sem nenhuma estrutura nova.
##
## VARIANTES sao o mecanismo de dialogo condicional: a primeira cujo `se` passa
## substitui `falas`. Nenhuma passando, vale `falas`. E o caso "ele diz outra
## coisa depois que voce ja o conheceu" sem duplicar o no inteiro.
##
## Precedencia ao terminar as falas:  escolhas  >  seguinte  >  fim.

const QUEM_NPC := "npc"
const QUEM_JOGADOR := "jogador"

var id: String = ""
var falas: Array[Dictionary] = []
var variantes: Array[Dictionary] = []      ## [{se, falas}]
var escolhas: Array[Dictionary] = []       ## [{texto, destino, se, efeitos}]
var seguinte: String = ""
## Cabecalho do menu de escolhas ("O que voce quer perguntar?"). Vazio esconde a
## faixa: nem toda ramificacao e uma pergunta.
var pergunta: String = ""
var efeitos: Dictionary = {}
var fim: bool = false


static func de_dicionario(id_do_no: String, d: Dictionary) -> NoDialogo:
	var no := NoDialogo.new()
	no.id = id_do_no
	no.falas = _falas_de(d.get("falas", []))
	for v: Dictionary in d.get("variantes", []):
		no.variantes.append({"se": v.get("se"), "falas": _falas_de(v.get("falas", []))})
	for e: Dictionary in d.get("escolhas", []):
		no.escolhas.append({
			"texto": String(e.get("texto", "")),
			"destino": String(e.get("destino", "")),
			"se": e.get("se"),
			"efeitos": e.get("efeitos", {}),
			"dica": String(e.get("dica", "")),
		})
	no.seguinte = String(d.get("seguinte", ""))
	no.pergunta = String(d.get("pergunta", ""))
	no.efeitos = d.get("efeitos", {})
	no.fim = bool(d.get("fim", false))
	return no


static func _falas_de(lista: Variant) -> Array[Dictionary]:
	var saida: Array[Dictionary] = []
	if lista is String:
		lista = [lista]
	for item: Variant in lista:
		if item is String:
			saida.append({"quem": QUEM_NPC, "texto": String(item), "retrato": ""})
		elif item is Dictionary:
			saida.append({
				"quem": String((item as Dictionary).get("quem", QUEM_NPC)),
				"texto": String((item as Dictionary).get("texto", "")),
				"retrato": String((item as Dictionary).get("retrato", "")),
			})
	return saida


## As falas que valem AGORA — a primeira variante cujo `se` passa, ou as falas
## base. Nunca devolve lista vazia quando ha escolhas a mostrar: um no sem fala
## nenhuma existe (e um puro ponto de ramificacao) e quem trata disso e a sessao.
func falas_para(estado: EstadoMundo) -> Array[Dictionary]:
	for v: Dictionary in variantes:
		if CondicaoDialogo.avaliar(v.get("se"), estado):
			return v["falas"]
	return falas


## Escolhas visiveis agora, na ordem do JSON. A ordem e autoral: o jogador
## aprende onde fica "sair" e nao pode ver isso mudar de lugar entre visitas.
func escolhas_para(estado: EstadoMundo) -> Array[Dictionary]:
	var visiveis: Array[Dictionary] = []
	for e: Dictionary in escolhas:
		if CondicaoDialogo.avaliar(e.get("se"), estado):
			visiveis.append(e)
	return visiveis


func termina_conversa() -> bool:
	return fim or (escolhas.is_empty() and seguinte == "")
