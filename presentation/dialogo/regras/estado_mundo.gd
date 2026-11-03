class_name EstadoMundo
extends RefCounted

## Estado persistente da partida fora do bestiario: bandeiras de historia,
## regioes visitadas e o que cada NPC ja disse.
##
## E DELIBERADAMENTE MINIMO. Nao e sistema de missao nem de reputacao: e um
## dicionario de bandeiras com serializacao. Missao, loja e relacionamento, quando
## existirem, escrevem e leem bandeiras daqui em vez de inventar cada um o seu
## armazenamento — que e o que transforma tres sistemas novos em tres formatos de
## save incompativeis.
##
## PROVEDORES sao o que impede este arquivo de crescer. Uma condicao de dialogo
## pode perguntar por algo que NAO mora aqui (quantos itens o jogador tem, quantas
## criaturas capturou). Em vez de o EstadoMundo passar a conhecer o inventario, ele
## aceita um Callable por dominio:
##
##     estado.registrar_provedor("item", func(id): return inventario.quantidade(id))
##
## Assim a condicao {"item": "isca_frutada", "pelo_menos": 1} funciona sem que
## regras/ conheca presentation/encontro/, e um dominio novo ("missao", "hora")
## custa uma linha na cena, nao uma alteracao aqui.
##
## SAVE (RF futuro): para_dicionario()/de_dicionario() sao a interface pronta.
## Nao ha escrita em disco — o projeto ainda nao tem save, e inventar um formato
## de arquivo antes de existir o que salvar seria adivinhacao. Ver README.

signal bandeira_mudou(nome: String, valor: Variant)
signal regiao_visitada(id: String)

## Bandeiras de historia. Valor livre (bool, int, String) — quem escreve decide.
var bandeiras: Dictionary = {}

## Regioes do mapa em que o jogador ja pisou. Alimenta o mapa geral (M): o que
## nao foi visitado aparece apagado.
var regioes: Dictionary = {}

## Quantas vezes cada no de dialogo ja foi mostrado, por "npc:no". Permite
## "primeira vez que falo com ele" sem uma bandeira manual por NPC.
var vistos: Dictionary = {}

var _provedores: Dictionary = {}


# ------------------------------------------------------------------ bandeiras
func definir(nome: String, valor: Variant = true) -> void:
	if bandeiras.get(nome) == valor:
		return
	bandeiras[nome] = valor
	bandeira_mudou.emit(nome, valor)


func ler(nome: String, padrao: Variant = null) -> Variant:
	return bandeiras.get(nome, padrao)


func ativa(nome: String) -> bool:
	var v: Variant = bandeiras.get(nome, false)
	if v is bool:
		return v
	if v is int or v is float:
		return v != 0
	if v is String:
		return v != ""
	return v != null


func somar(nome: String, delta: float) -> void:
	definir(nome, float(bandeiras.get(nome, 0)) + delta)


# -------------------------------------------------------------------- regioes
## Marca a regiao como conhecida. Devolve true SO na primeira vez — e o que
## permite anunciar o nome da regiao na tela sem repetir a cada reentrada.
func visitar(id: String) -> bool:
	if id == "" or regioes.has(id):
		return false
	regioes[id] = true
	definir("visitou_" + id, true)
	regiao_visitada.emit(id)
	return true


func visitou(id: String) -> bool:
	return regioes.has(id)


# ------------------------------------------------------------ nos de dialogo
func marcar_visto(npc_id: String, no_id: String) -> void:
	var chave := npc_id + ":" + no_id
	vistos[chave] = int(vistos.get(chave, 0)) + 1


func quantas_vezes(npc_id: String, no_id: String) -> int:
	return int(vistos.get(npc_id + ":" + no_id, 0))


func ja_falou_com(npc_id: String) -> bool:
	for chave: String in vistos.keys():
		if chave.begins_with(npc_id + ":"):
			return true
	return false


# ----------------------------------------------------------------- provedores
func registrar_provedor(dominio: String, fonte: Callable) -> void:
	_provedores[dominio] = fonte


## Consulta um dominio externo. Devolve null quando ninguem registrou o
## provedor — e a condicao que depende dele simplesmente falha, em vez de o jogo
## quebrar porque a loja ainda nao existe.
func consultar(dominio: String, chave: String) -> Variant:
	if not _provedores.has(dominio):
		return null
	var fonte: Callable = _provedores[dominio]
	if not fonte.is_valid():
		return null
	return fonte.call(chave)


func tem_provedor(dominio: String) -> bool:
	return _provedores.has(dominio)


# ---------------------------------------------------------------------- save
## Retrato serializavel do estado. Provedores NAO entram: sao ligacoes vivas com
## outros sistemas, e cada um deles responde pelo proprio save.
func para_dicionario() -> Dictionary:
	return {
		"versao": 1,
		"bandeiras": bandeiras.duplicate(true),
		"regioes": regioes.keys(),
		"vistos": vistos.duplicate(true),
	}


func de_dicionario(dados: Dictionary) -> void:
	bandeiras = (dados.get("bandeiras", {}) as Dictionary).duplicate(true)
	vistos = (dados.get("vistos", {}) as Dictionary).duplicate(true)
	regioes = {}
	for id: String in dados.get("regioes", []):
		regioes[id] = true
