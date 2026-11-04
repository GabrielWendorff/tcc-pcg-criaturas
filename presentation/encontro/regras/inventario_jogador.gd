class_name InventarioJogador
extends RefCounted

## O que o jogador carrega: quantidades de dispositivos e iscas, e as criaturas ja
## capturadas.
##
## O projeto NAO tinha inventario (docs/pendencias.md, item 7 — "nao entrega
## batalha, captura, inventario"). Este e o primeiro, e por isso e proposital que
## ele seja pequeno: um dicionario id -> quantidade e um sinal. Dispositivos e
## iscas compartilham o mesmo espaco de nomes de id (garantido por
## TabelasCaptura._por_id), entao uma tabela unica de quantidades atende os dois —
## quando houver loja, chave, cura e material, o formato ja e o mesmo.
##
## Regra que o resto do sistema depende: consumir() so tira do estoque se HOUVER, e
## devolve se conseguiu. Quem chama nunca precisa conferir antes.

signal mudou(id: String, quantidade: int)
signal criatura_guardada(criatura: Criatura)

var _quantidades: Dictionary = {}

## Criaturas capturadas, na ordem em que entraram.
var colecao: Array[Criatura] = []


## Carga inicial declarada em data/captura/*.json.
static func inicial(tabelas: TabelasCaptura) -> InventarioJogador:
	var inv := InventarioJogador.new()
	for d in tabelas.dispositivos:
		inv.adicionar(d.id, d.quantidade_inicial)
	for i in tabelas.iscas:
		inv.adicionar(i.id, i.quantidade_inicial)
	return inv


func quantidade(id: String) -> int:
	return int(_quantidades.get(id, 0))


func tem(id: String, n: int = 1) -> bool:
	return quantidade(id) >= n


func adicionar(id: String, n: int = 1) -> void:
	if n == 0:
		return
	_quantidades[id] = maxi(0, quantidade(id) + n)
	mudou.emit(id, quantidade(id))


## Retira n unidades. Falso (e nada retirado) se nao houver o bastante.
func consumir(id: String, n: int = 1) -> bool:
	if not tem(id, n):
		return false
	_quantidades[id] = quantidade(id) - n
	mudou.emit(id, quantidade(id))
	return true


## Total de itens de uma lista que ainda existem no estoque. Serve a pergunta
## "vale abrir a roda?" sem a roda precisar saber o que e um dispositivo.
func total_de(itens: Array) -> int:
	var soma: int = 0
	for item: ItemCaptura in itens:
		soma += quantidade(item.id)
	return soma


## Retrato das quantidades, para o save. Copia: quem receber nao pode escrever
## no estoque por descuido.
func quantidades() -> Dictionary:
	return _quantidades.duplicate()


## Repoe o estoque inteiro a partir de um save. Emite `mudou` item a item em vez
## de um sinal novo de "tudo mudou": quem escuta ja sabe reagir a essa forma, e
## um segundo sinal exigiria que cada ouvinte tratasse os dois.
##
## Os ids ausentes do dicionario zeram, e nao ficam como estavam: um save e um
## retrato completo do estoque, nao um incremento sobre a carga inicial.
func repor(quantidades_: Dictionary) -> void:
	var ids: Dictionary = {}
	for id: String in _quantidades.keys():
		ids[id] = true
	for id: String in quantidades_.keys():
		ids[id] = true
	_quantidades.clear()
	for id: String in quantidades_.keys():
		_quantidades[id] = maxi(0, int(quantidades_[id]))
	for id: String in ids.keys():
		mudou.emit(id, quantidade(id))


func guardar_criatura(criatura: Criatura) -> void:
	colecao.append(criatura)
	criatura_guardada.emit(criatura)


func ja_capturou(criatura: Criatura) -> bool:
	for c in colecao:
		if c.id == criatura.id and c.world_seed == criatura.world_seed:
			return true
	return false
