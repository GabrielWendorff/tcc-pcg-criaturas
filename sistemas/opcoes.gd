extends Node

## Autoload `Opcoes` — configuracoes do jogador.
##
## SEPARADO DO SAVE DA PARTIDA, de proposito. Vive em user://opcoes.json, e nao
## dentro de um slot: uma opcao vale para o JOGADOR, nao para o mundo. Trocar de
## slot nao pode religar um efeito que ele desligou, e apagar um save nao pode
## devolver um tremor de camera que ele nao quer ver.
##
## APLICADAS NA HORA. Nao ha "confirmar": `definir()` grava e emite `mudou`, e
## quem consome ou escuta o sinal ou le o valor no momento de usar. A segunda
## forma e a preferida, e e por isso que a maioria dos consumidores nao escuta
## nada: `CameraExploracao.tremer()` pergunta a Opcoes no instante em que o
## tremor comecaria, e com isso TODO chamador de tremer() passa a respeitar a
## opcao sem nenhuma alteracao — inclusive os que ainda nao existem (o minigame
## de pesca e um deles).
##
## ACRESCENTAR UMA OPCAO = UMA ENTRADA EM DEFINICOES. A tela se constroi varrendo
## a lista, a persistencia grava o que encontrar, e a validacao sai do tipo
## declarado. Ver DefinicaoOpcao.

signal mudou(id: String, valor: Variant)

const CAMINHO := "user://opcoes.json"
const VERSAO := 1

## As opcoes do jogo. Ordem = ordem na tela.
##
## Todas sao de EVENTO/APRESENTACAO de propósito: nenhuma mexe no modelo
## generativo. Desligar o tremor da camera ou os encontros aleatorios muda o que
## o jogador ve e quando, nunca qual criatura a seed produz — o bestiario de uma
## world_seed e o mesmo com qualquer configuracao (RF03).
const DEFINICOES := [
	{
		"id": "tremor_camera",
		"rotulo": "Tremor de câmera",
		"descricao": "Sacudida da tela no susto do encontro e nos puxões da pesca.",
		"padrao": true,
	},
	{
		"id": "encontros_aleatorios",
		"rotulo": "Encontros aleatórios",
		"descricao": "Criaturas aparecem sozinhas ao andar no mato. Desligado, só por pesca e pelo F4.",
		"padrao": true,
	},
	{
		"id": "efeitos_de_tela",
		"rotulo": "Efeitos de tela",
		"descricao": "Partículas, pulsos e animações de fundo. Não afeta a legibilidade.",
		"padrao": true,
	},
	{
		"id": "velocidade_texto",
		"rotulo": "Velocidade do texto",
		"descricao": "Ritmo da máquina de escrever nos diálogos.",
		"padrao": "normal",
		# `dado` e caracteres por segundo. 0 = aparece inteiro de uma vez.
		"valores": [
			{"id": "lento", "rotulo": "LENTO", "dado": 26.0},
			{"id": "normal", "rotulo": "NORMAL", "dado": 46.0},
			{"id": "rapido", "rotulo": "RÁPIDO", "dado": 84.0},
			{"id": "instantaneo", "rotulo": "INSTANTÂNEO", "dado": 0.0},
		],
	},
]

var _definicoes: Array[DefinicaoOpcao] = []
var _por_id: Dictionary = {}
var _valores: Dictionary = {}


func _ready() -> void:
	# ALWAYS: as opcoes tem de responder com o jogo pausado — e de dentro do menu
	# de pausa que a maioria delas sera mexida.
	process_mode = Node.PROCESS_MODE_ALWAYS
	for d: Dictionary in DEFINICOES:
		var def := DefinicaoOpcao.de_dicionario(d)
		_definicoes.append(def)
		_por_id[def.id] = def
		_valores[def.id] = def.padrao
	_carregar()


# -------------------------------------------------------------------- leitura

func definicoes() -> Array[DefinicaoOpcao]:
	return _definicoes


func definicao(id: String) -> DefinicaoOpcao:
	return _por_id.get(id)


## Valor BRUTO (bool, ou o id da escolha).
func ler(id: String) -> Variant:
	return _valores.get(id)


## Verdadeiro/falso de uma opcao booleana. Opcao inexistente devolve `padrao` —
## um consumidor nunca fica sem resposta por causa de um id digitado errado, e o
## jogo degrada para o comportamento normal em vez de desligar sozinho.
func ligada(id: String, padrao: bool = true) -> bool:
	var v: Variant = _valores.get(id)
	return bool(v) if v is bool else padrao


## O DADO associado ao valor corrente — o numero que o consumidor usa de fato
## (caracteres por segundo, multiplicador...). Ver DefinicaoOpcao.
func dado(id: String, padrao: Variant = null) -> Variant:
	var def: DefinicaoOpcao = _por_id.get(id)
	if def == null:
		return padrao
	var d: Variant = def.dado_do_valor(_valores.get(id, def.padrao))
	return d if d != null else padrao


func rotulo_do_valor(id: String) -> String:
	var def: DefinicaoOpcao = _por_id.get(id)
	return def.rotulo_do_valor(_valores.get(id)) if def != null else ""


# -------------------------------------------------------------------- escrita

func definir(id: String, valor: Variant) -> void:
	var def: DefinicaoOpcao = _por_id.get(id)
	if def == null or not def.aceita(valor):
		push_warning("Opcoes: valor recusado para '%s': %s" % [id, valor])
		return
	if _valores.get(id) == valor:
		return
	_valores[id] = valor
	mudou.emit(id, valor)
	_gravar()


## Avanca a opcao: inverte a booleana, cicla a escolha. E o unico gesto que a
## tela de opcoes precisa oferecer, e e o que permite que ela seja uma lista so.
func alternar(id: String) -> void:
	var def: DefinicaoOpcao = _por_id.get(id)
	if def != null:
		definir(id, def.proximo(_valores.get(id, def.padrao)))


func restaurar_padroes() -> void:
	for def: DefinicaoOpcao in _definicoes:
		definir(def.id, def.padrao)


# ---------------------------------------------------------------- persistencia

## Grava o arquivo inteiro a cada mudanca. Sao quatro chaves: um debounce para
## economizar essa escrita custaria mais codigo do que a escrita custa, e um
## jogo fechado a forca logo depois de mexer numa opcao tem de reabrir com ela
## mexida.
func _gravar() -> void:
	var f := FileAccess.open(CAMINHO, FileAccess.WRITE)
	if f == null:
		push_warning("Opcoes: nao foi possivel gravar " + CAMINHO)
		return
	f.store_string(JSON.stringify({"versao": VERSAO, "valores": _valores}, "  "))
	f.close()


## Le o arquivo. Chave desconhecida ou valor invalido e IGNORADA em silencio, e o
## padrao fica de pe: o arquivo e editavel a mao, e a configuracao e o lugar onde
## um dado estranho tem de degradar, nunca impedir o jogo de abrir.
func _carregar() -> void:
	if not FileAccess.file_exists(CAMINHO):
		return
	var bruto: Variant = JSON.parse_string(FileAccess.get_file_as_string(CAMINHO))
	if not (bruto is Dictionary):
		push_warning("Opcoes: arquivo invalido, usando padroes — " + CAMINHO)
		return
	var lidos: Dictionary = bruto.get("valores", {})
	for id: String in lidos.keys():
		var def: DefinicaoOpcao = _por_id.get(id)
		if def != null and def.aceita(lidos[id]):
			_valores[id] = lidos[id]
