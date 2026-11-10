extends Node

## Autoload `Bolsa` — o que o jogador carrega.
##
## NAO REESCREVE O INVENTARIO QUE JA EXISTIA. `InventarioJogador` ja era a
## tabela id -> quantidade com sinais, ja era consumida pelo encontro e ja estava
## testada; o comentario no topo daquele arquivo previa este momento ("quando
## houver loja, chave, cura e material, o formato ja e o mesmo"). A Bolsa e o
## que faltava em volta dele: o CATALOGO (nome, descricao, categoria, icone,
## efeito), a carga inicial de todas as fontes e a persistencia.
##
##     Bolsa ──possui──▶ InventarioJogador   (quantidades + sinais, inalterado)
##           ──possui──▶ CatalogoItens       (o que cada id significa)
##
## Quem ja falava com o inventario continua falando com ele: a cena do mundo
## entrega `Bolsa.inventario` ao GerenciadorEncontro, e o encontro nao sabe que
## existe uma bolsa. Quem precisa de categoria, descricao ou icone fala com a
## Bolsa.
##
## API pedida, nos nomes do projeto:
##     add_item      -> adicionar(id, n)
##     remove_item   -> remover(id, n)
##     has_item      -> tem(id, n)
##     get_quantity  -> quantidade(id)
##
## SINAIS. `item_mudou` repassa o `mudou` do inventario — a interface escuta um
## sinal so, venha a mudanca de onde vier (captura, pesca, loja, diálogo).
##
## SAVE. A Bolsa registra a propria secao, como PERMANENTE: ela nasce antes de
## qualquer cena e sobrevive a todas, entao nao pode ser esquecida na troca de
## cena como as secoes do mundo sao. Ver GerenciadorSave.registrar_secao.

signal item_mudou(id: String, quantidade: int)
signal gold_mudou(valor: int)
signal catalogo_pronto()

## Quantidades e sinais. É este objeto que o GerenciadorEncontro recebe.
var inventario := InventarioJogador.new()

var catalogo: CatalogoItens
var erro: String = ""

## Dinheiro do jogador. Vive aqui porque atravessa as cenas junto com os itens e vai
## para o save na mesma secao.
var gold: int = 0
var economia: TabelasEconomia


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var captura := TabelasCaptura.carregar()
	if captura == null:
		erro = "tabelas de captura nao carregaram"
		push_error("Bolsa: " + erro)
		return
	catalogo = CatalogoItens.carregar(captura)
	if catalogo == null:
		erro = "catalogo de itens nao carregou"
		push_error("Bolsa: " + erro)
		return

	inventario.mudou.connect(func(id: String, n: int) -> void: item_mudou.emit(id, n))
	economia = TabelasEconomia.carregar()
	reiniciar()

	# Secao PERMANENTE: a bolsa atravessa a troca de cena, e esquece-la junto
	# com as secoes do mundo faria o save gravar uma bolsa vazia.
	Save.registrar_secao("itens", _colher, _repor, true)
	# Partida nova comeca com a carga inicial, e nao com o que sobrou da
	# anterior. `carregar` tambem emite este sinal, mas ali o _repor logo em
	# seguida sobrescreve com o que estava gravado.
	Save.partida_iniciada.connect(func(_d: DadosPartida) -> void: reiniciar())
	catalogo_pronto.emit()


func pronta() -> bool:
	return catalogo != null


## Devolve a bolsa a carga inicial declarada pelos JSONs, e o gold ao inicial.
func reiniciar() -> void:
	if catalogo != null:
		inventario.repor(catalogo.quantidades_iniciais())
	_definir_gold(economia.gold_inicial() if economia != null else 0)


func _definir_gold(valor: int) -> void:
	gold = maxi(0, valor)
	gold_mudou.emit(gold)


func ganhar_gold(n: int) -> void:
	_definir_gold(gold + maxi(0, n))


## Compra `n` unidades de `id` pelo preco da economia. Devolve "" ou o motivo da
## recusa, ja em texto de tela. So cobra o que coube na bolsa (max_pilha).
func comprar(id: String, n: int = 1) -> String:
	var i := item(id)
	if i == null or economia == null:
		return "Item desconhecido."
	var preco := economia.preco(id)
	if preco <= 0:
		return "%s não está à venda." % i.nome
	var teto: int = 1 if not i.empilhavel else i.max_pilha
	var cabe: int = mini(n, teto - quantidade(id))
	if cabe <= 0:
		return "A bolsa já está cheia de %s." % i.nome
	if gold < preco * cabe:
		return "Gold insuficiente: %s custa %d." % [i.nome, preco]
	adicionar(id, cabe)
	_definir_gold(gold - preco * cabe)
	return ""


# ----------------------------------------------------------------------- API

func quantidade(id: String) -> int:
	return inventario.quantidade(id)


func tem(id: String, n: int = 1) -> bool:
	return inventario.tem(id, n)


## Acrescenta. Respeita `max_pilha` do catalogo: um item nao empilhavel nunca
## passa de 1, e e o que impede o pescador de dar uma segunda vara ao jogador
## que volta para repetir o tutorial.
func adicionar(id: String, n: int = 1) -> int:
	var i := item(id)
	if i == null:
		push_warning("Bolsa: item desconhecido — " + id)
		return 0
	var teto: int = 1 if not i.empilhavel else i.max_pilha
	var cabe: int = mini(n, teto - quantidade(id))
	if cabe <= 0:
		return 0
	inventario.adicionar(id, cabe)
	return cabe


## Retira. Falso (e nada retirado) se nao houver o bastante ou se o item for
## permanente — perder a vara de pesca por um clique errado nao e uma decisao
## que o jogo deva oferecer.
func remover(id: String, n: int = 1) -> bool:
	var i := item(id)
	if i != null and i.permanente:
		return false
	return inventario.consumir(id, n)


func item(id: String) -> ItemJogo:
	return catalogo.item(id) if catalogo != null else null


# -------------------------------------------------------------------- listas

## Itens de uma categoria que o jogador DE FATO tem. `incluir_vazios` mostra
## tambem os zerados — util na roda de captura, que precisa dizer "você não tem
## mais", e errado na bolsa, que viraria uma lista de tudo que existe no jogo.
func da_categoria(id_cat: String, incluir_vazios: bool = false) -> Array:
	var saida: Array = []
	if catalogo == null:
		return saida
	for i: ItemJogo in catalogo.da_categoria(id_cat):
		if incluir_vazios or quantidade(i.id) > 0:
			saida.append(i)
	return saida


## Categorias que tem ao menos um item em estoque. A bolsa nao mostra aba vazia:
## uma aba que nunca tem nada e ruido permanente na tela.
func categorias_com_itens() -> Array:
	var saida: Array = []
	if catalogo == null:
		return saida
	for cat: Dictionary in catalogo.categorias:
		var id_cat := String(cat.get("id", ""))
		if not da_categoria(id_cat).is_empty():
			saida.append(cat)
	return saida


## Itens em estoque que carregam um marcador. É assim que a pesca pergunta "o
## jogador tem vara?" sem conhecer categoria nenhuma.
func com_marcador(m: String) -> Array:
	var saida: Array = []
	if catalogo == null:
		return saida
	for i: ItemJogo in catalogo.com_marcador(m):
		if quantidade(i.id) > 0:
			saida.append(i)
	return saida


func tem_marcador(m: String) -> bool:
	return not com_marcador(m).is_empty()


func total() -> int:
	var soma: int = 0
	if catalogo == null:
		return 0
	for i: ItemJogo in catalogo.itens:
		soma += quantidade(i.id)
	return soma


# ---------------------------------------------------------------------- save

func _colher(d: DadosPartida) -> void:
	d.itens = inventario.quantidades()
	d.gold = gold


func _repor(d: DadosPartida) -> void:
	# Secao ausente = partida nova: a carga inicial dos JSONs fica de pe.
	if not d.itens.is_empty():
		inventario.repor(d.itens)
	# Save sem gold (de antes da economia): comeca com o inicial, e nao com zero.
	_definir_gold(d.gold if d.gold >= 0 else (economia.gold_inicial() if economia != null else 0))
