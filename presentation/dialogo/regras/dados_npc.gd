class_name DadosNpc
extends RefCounted

## Ficha de um NPC, lida de autoral/npcs/npcs.json.
##
## ISTO E O QUE FAZ UM NPC NOVO CUSTAR UMA ENTRADA DE JSON. Nao ha script por
## personagem: `Npc` (presentation/exploracao/npc.gd) e generico e se configura a
## partir desta ficha; o comportamento especifico mora na arvore de dialogo, que
## tambem e dado.
##
## CAMPOS
##   id           chave estavel, usada em bandeiras e em "falou_com"
##   nome         como aparece na placa da caixa de dialogo
##   papel        ocupacao, so exibicao ("Pescador", "Padeiro")
##   dialogo      id da arvore em autoral/dialogos/<dialogo>.json
##   celula       [gx, gy] na grade do mapa
##   direcao      para onde encara parado: baixo | cima | esquerda | direita
##   folha        folha de caminhada 4x4 (mesmo formato do protagonista)
##   retrato      PNG do busto, opcional — sem ele a caixa mostra so a placa
##   alcance      raio de interacao, em CELULAS
##   regiao       regiao do mapa (so informativo; quem marca visita e a area)
##   servico      {"tipo": "loja"|"pesca"|...} — gancho, sem implementacao
##   bloqueia     se o corpo do NPC barra o jogador (padrao: true)
##
## Campos desconhecidos sao PRESERVADOS em `extra`: quando existir missao ou
## agenda, o JSON ja pode declara-las sem que este arquivo mude.

const CONHECIDOS := ["id", "nome", "papel", "dialogo", "celula", "direcao",
	"folha", "retrato", "alcance", "regiao", "servico", "bloqueia"]

const DIRECOES := ["baixo", "esquerda", "direita", "cima"]

var id: String = ""
var nome: String = ""
var papel: String = ""
var dialogo: String = ""
var celula: Vector2i = Vector2i.ZERO
var direcao: String = "baixo"
var folha: String = ""
var retrato: String = ""
var alcance: float = 1.6
var regiao: String = ""
var servico: Dictionary = {}
var bloqueia: bool = true
var extra: Dictionary = {}


static func de_dicionario(d: Dictionary) -> DadosNpc:
	var n := DadosNpc.new()
	n.id = String(d.get("id", ""))
	n.nome = String(d.get("nome", n.id))
	n.papel = String(d.get("papel", ""))
	n.dialogo = String(d.get("dialogo", n.id))
	var c: Array = d.get("celula", [0, 0])
	n.celula = Vector2i(int(c[0]), int(c[1])) if c.size() >= 2 else Vector2i.ZERO
	n.direcao = String(d.get("direcao", "baixo"))
	n.folha = String(d.get("folha", ""))
	n.retrato = String(d.get("retrato", ""))
	n.alcance = float(d.get("alcance", 1.6))
	n.regiao = String(d.get("regiao", ""))
	n.servico = d.get("servico", {})
	n.bloqueia = bool(d.get("bloqueia", true))
	for chave: String in d.keys():
		if not chave in CONHECIDOS:
			n.extra[chave] = d[chave]
	return n


func tem_servico() -> bool:
	return not servico.is_empty()


func tipo_de_servico() -> String:
	return String(servico.get("tipo", ""))
