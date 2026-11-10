class_name TelaBolsa
extends CanvasLayer

## A bolsa do jogador: abas por categoria, lista do que ele tem e a ficha do
## item selecionado.
##
## TRES BLOCOS, UMA LEITURA
##   abas      que tipo de coisa estou vendo
##   lista     o que eu tenho, com icone e quantidade
##   ficha     o que ISTO faz                       (sempre do item sob o cursor)
##
## A ficha e o lado direito inteiro e nao um rodape de uma linha porque a
## descricao de um item de captura nao e decorativa: "bom vs asas · ruim vs
## garras" e a informacao que decide a escolha, e ela vem do MESMO
## `detalhe()` que a roda de captura usa. Um item visto na bolsa e um item visto
## na roda dizem a mesma coisa, porque e literalmente o mesmo metodo.
##
## ABA VAZIA NAO APARECE. A bolsa lista o que o jogador TEM, nao o que existe no
## jogo: uma aba de consumiveis permanentemente vazia seria ruido fixo na tela.
## A consequencia e que as abas mudam de numero ao longo da partida, e por isso a
## selecao e reancorada por ID de categoria, nunca por indice.
##
## Esta classe nao consome nada. Ela EMITE `item_usado` e quem tem o que curar
## resolve (a cena do mundo, pelo menu de pausa). Usar um item sem alvo responde com
## uma recusa escrita, em vez de gastar o item em silencio.

signal fechada()
signal item_usado(item: ItemJogo)

## ACIMA do menu de pausa (96), nao abaixo. Uma CanvasLayer filha de outra tem
## camada INDEPENDENTE do pai: com 95 aqui, o menu de pausa desenharia por cima
## da bolsa que ele mesmo abriu.
const CAMADA := 97

const LARGURA_LISTA := 452.0
const LARGURA_FICHA := 368.0
const ALTURA_CORPO := 376.0
const ESCALA_ICONE := 2
const ESCALA_ICONE_FICHA := 5
const TEXTO_RODAPE := "SETAS categoria e item     E usar     ESC fechar"

var _raiz: Control
var _abas: HBoxContainer
var _lista: VBoxContainer
var _rolagem: ScrollContainer
var _ficha: VBoxContainer
var _rodape: Label
var _gold: Label

var _categorias: Array = []
var _itens: Array[ItemJogo] = []
var _cartoes: Array[PanelContainer] = []
var _cartoes_aba: Array[PanelContainer] = []

var _cat_atual: String = ""
var _indice: int = 0
var _aberta: bool = false

## Criatura diante do jogador, quando a bolsa e aberta dentro de um encontro.
## E o que faz a ficha dizer "preferida por canino *" em vez de so "atrai
## canino" — a mesma diferenca que a roda de captura faz.
var criatura_em_foco: Criatura = null


func _ready() -> void:
	layer = CAMADA
	process_mode = Node.PROCESS_MODE_ALWAYS
	_montar()
	visible = false


# --------------------------------------------------------------- construcao

func _montar() -> void:
	_raiz = Control.new()
	_raiz.name = "Raiz"
	_raiz.set_anchors_preset(Control.PRESET_FULL_RECT)
	_raiz.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_raiz)

	var veu := ColorRect.new()
	veu.name = "Veu"
	veu.color = Color(TemaEncontro.CONTORNO, 0.72)
	veu.set_anchors_preset(Control.PRESET_FULL_RECT)
	veu.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_raiz.add_child(veu)

	var centro := CenterContainer.new()
	centro.set_anchors_preset(Control.PRESET_FULL_RECT)
	centro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_raiz.add_child(centro)

	var painel := PanelContainer.new()
	painel.name = "Painel"
	painel.add_theme_stylebox_override("panel", TemaEncontro.moldura("painel"))
	painel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	centro.add_child(painel)

	var margem := MarginContainer.new()
	for lado in ["left", "right", "top", "bottom"]:
		margem.add_theme_constant_override("margin_" + lado, 14)
	margem.mouse_filter = Control.MOUSE_FILTER_IGNORE
	painel.add_child(margem)

	var coluna := VBoxContainer.new()
	coluna.add_theme_constant_override("separation", 10)
	coluna.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margem.add_child(coluna)

	var topo := HBoxContainer.new()
	topo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	coluna.add_child(topo)
	var titulo := TemaEncontro.rotulo("BOLSA", TemaEncontro.OURO, TemaEncontro.Corpo.TITULO)
	titulo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	topo.add_child(titulo)
	_gold = TemaEncontro.rotulo("", TemaEncontro.OURO_C, TemaEncontro.Corpo.TITULO)
	topo.add_child(_gold)

	_abas = HBoxContainer.new()
	_abas.name = "Abas"
	_abas.add_theme_constant_override("separation", 6)
	_abas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	coluna.add_child(_abas)

	var corpo := HBoxContainer.new()
	corpo.add_theme_constant_override("separation", 14)
	corpo.custom_minimum_size = Vector2(0, ALTURA_CORPO)
	corpo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	coluna.add_child(corpo)

	# A lista rola; a ficha nao. Uma ficha que rolasse junto tiraria do campo de
	# visao justamente o texto que explica a linha sob o cursor.
	_rolagem = ScrollContainer.new()
	_rolagem.name = "Rolagem"
	_rolagem.custom_minimum_size = Vector2(LARGURA_LISTA, ALTURA_CORPO)
	_rolagem.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	corpo.add_child(_rolagem)

	_lista = VBoxContainer.new()
	_lista.name = "Lista"
	_lista.add_theme_constant_override("separation", 4)
	_lista.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rolagem.add_child(_lista)

	var caixa_ficha := PanelContainer.new()
	caixa_ficha.name = "Ficha"
	caixa_ficha.add_theme_stylebox_override("panel", TemaEncontro.moldura("pergaminho"))
	caixa_ficha.custom_minimum_size = Vector2(LARGURA_FICHA, 0)
	caixa_ficha.mouse_filter = Control.MOUSE_FILTER_IGNORE
	corpo.add_child(caixa_ficha)

	_ficha = VBoxContainer.new()
	_ficha.add_theme_constant_override("separation", 7)
	_ficha.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caixa_ficha.add_child(_ficha)

	_rodape = TemaEncontro.rotulo(TEXTO_RODAPE, TemaEncontro.PERG_E)
	coluna.add_child(_rodape)


# -------------------------------------------------------------------- fluxo

func abrir(criatura: Criatura = null) -> void:
	criatura_em_foco = criatura
	_categorias = Bolsa.categorias_com_itens()
	# Reancora por ID e nao por indice: as abas mudam de numero quando uma
	# categoria esvazia, e um indice guardado apontaria para outra categoria.
	if _cat_atual == "" or not _tem_categoria(_cat_atual):
		_cat_atual = String(_categorias[0]["id"]) if not _categorias.is_empty() else ""
	_aberta = true
	visible = true
	_gold.text = "%d GOLD" % Bolsa.gold
	_rodape.text = TEXTO_RODAPE
	_reconstruir_abas()
	_reconstruir_lista()


func fechar() -> void:
	_aberta = false
	visible = false
	criatura_em_foco = null
	fechada.emit()


func aberta() -> bool:
	return _aberta


func _tem_categoria(id_cat: String) -> bool:
	for c: Dictionary in _categorias:
		if String(c.get("id", "")) == id_cat:
			return true
	return false


# ------------------------------------------------------------------- abas

func _reconstruir_abas() -> void:
	for c: PanelContainer in _cartoes_aba:
		_abas.remove_child(c)
		c.queue_free()
	_cartoes_aba.clear()
	for i in _categorias.size():
		var cat: Dictionary = _categorias[i]
		var id_cat := String(cat.get("id", ""))
		var aba := PanelContainer.new()
		aba.name = "Aba_" + id_cat
		aba.mouse_filter = Control.MOUSE_FILTER_STOP
		aba.gui_input.connect(_ao_clicar_aba.bind(id_cat))
		var sel: bool = id_cat == _cat_atual
		aba.add_theme_stylebox_override("panel",
				TemaEncontro.moldura("cartao_selecionado" if sel else "cartao"))
		aba.add_child(TemaEncontro.rotulo(String(cat.get("rotulo", id_cat)),
				TemaEncontro.PERG_C if sel else TemaEncontro.PERG_E))
		_abas.add_child(aba)
		_cartoes_aba.append(aba)


func _trocar_categoria(passo: int) -> void:
	if _categorias.size() <= 1:
		return
	var atual: int = 0
	for i in _categorias.size():
		if String(_categorias[i]["id"]) == _cat_atual:
			atual = i
			break
	_cat_atual = String(_categorias[posmod(atual + passo, _categorias.size())]["id"])
	_indice = 0
	_reconstruir_abas()
	_reconstruir_lista()


# ------------------------------------------------------------------- lista

func _reconstruir_lista() -> void:
	for c: PanelContainer in _cartoes:
		_lista.remove_child(c)
		c.queue_free()
	_cartoes.clear()
	_itens.clear()
	for i: ItemJogo in Bolsa.da_categoria(_cat_atual):
		_itens.append(i)
	_indice = clampi(_indice, 0, maxi(_itens.size() - 1, 0))

	for i in _itens.size():
		_lista.add_child(_montar_linha(_itens[i], i))
	_pintar_lista()
	_atualizar_ficha()


func _montar_linha(item: ItemJogo, indice: int) -> PanelContainer:
	var cartao := PanelContainer.new()
	cartao.name = "Item_" + item.id
	cartao.mouse_filter = Control.MOUSE_FILTER_STOP
	cartao.mouse_entered.connect(_selecionar.bind(indice))
	cartao.gui_input.connect(_ao_clicar_item.bind(indice))
	_cartoes.append(cartao)

	var linha := HBoxContainer.new()
	linha.name = "Linha"
	linha.add_theme_constant_override("separation", 8)
	linha.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cartao.add_child(linha)

	var icone := IconeCaptura.new(item.id, ESCALA_ICONE)
	icone.custom_minimum_size = icone.tamanho()
	linha.add_child(icone)

	var nome := TemaEncontro.rotulo(item.nome, TemaEncontro.PERG)
	nome.name = "Nome"
	nome.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nome.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	linha.add_child(nome)

	# Item nao empilhavel nao mostra contagem: "×1" numa vara de pesca sugere
	# que ter duas faria diferenca, e nao faz.
	var qtd := "" if not item.empilhavel else "×%d" % Bolsa.quantidade(item.id)
	var rotulo_qtd := TemaEncontro.rotulo(qtd, TemaEncontro.OURO)
	rotulo_qtd.name = "Qtd"
	rotulo_qtd.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	linha.add_child(rotulo_qtd)
	return cartao


func _pintar_lista() -> void:
	for i in _cartoes.size():
		var sel: bool = i == _indice
		_cartoes[i].add_theme_stylebox_override("panel",
				TemaEncontro.moldura("cartao_selecionado" if sel else "cartao"))
		var linha := _cartoes[i].get_node("Linha") as HBoxContainer
		(linha.get_node("Nome") as Label).add_theme_color_override("font_color",
				TemaEncontro.PERG_C if sel else TemaEncontro.PERG_E)


func _selecionar(i: int) -> void:
	if not _aberta or i == _indice or i < 0 or i >= _cartoes.size():
		return
	_indice = i
	_pintar_lista()
	_atualizar_ficha()
	_rolar_ate(i)


## Mantem a linha selecionada visivel. Sem isto, a navegacao por teclado some
## para fora da janela de rolagem assim que a lista passa de oito itens.
func _rolar_ate(i: int) -> void:
	if i < 0 or i >= _cartoes.size():
		return
	var cartao := _cartoes[i]
	var topo: float = cartao.position.y
	var base: float = topo + cartao.size.y
	var visao: float = _rolagem.size.y
	if topo < _rolagem.scroll_vertical:
		_rolagem.scroll_vertical = int(topo)
	elif base > _rolagem.scroll_vertical + visao:
		_rolagem.scroll_vertical = int(base - visao)


# ------------------------------------------------------------------- ficha

func _atualizar_ficha() -> void:
	for filho in _ficha.get_children():
		_ficha.remove_child(filho)
		filho.queue_free()

	if _itens.is_empty():
		var vazio := TemaEncontro.rotulo("Nada nesta categoria.", TemaEncontro.TINTA_C)
		vazio.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vazio.size_flags_vertical = Control.SIZE_EXPAND_FILL
		vazio.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_ficha.add_child(vazio)
		return

	var item := _itens[_indice]

	var topo := CenterContainer.new()
	topo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var icone := IconeCaptura.new(item.id, ESCALA_ICONE_FICHA)
	icone.custom_minimum_size = icone.tamanho()
	topo.add_child(icone)
	_ficha.add_child(topo)

	var nome := TemaEncontro.rotulo(item.nome.to_upper(), TemaEncontro.TINTA)
	nome.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_ficha.add_child(nome)
	_ficha.add_child(_regua())

	var desc := TemaEncontro.rotulo(item.descricao, TemaEncontro.TINTA)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.custom_minimum_size = Vector2(LARGURA_FICHA - 36.0, 0)
	_ficha.add_child(desc)

	# O MESMO detalhe que a roda de captura mostra. Com uma criatura em foco ele
	# muda de "atrai canino" para "preferida por canino (+45%)" — a ficha do
	# item vira leitura da criatura, que e o ponto do sistema de captura.
	var detalhe := item.detalhe(criatura_em_foco)
	if detalhe != "":
		var l := TemaEncontro.rotulo(detalhe, TemaEncontro.TINTA_C)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(LARGURA_FICHA - 36.0, 0)
		_ficha.add_child(l)

	var espaco := Control.new()
	espaco.size_flags_vertical = Control.SIZE_EXPAND_FILL
	espaco.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ficha.add_child(espaco)

	if item.permanente:
		_ficha.add_child(TemaEncontro.rotulo("Equipamento — não se gasta.",
				TemaEncontro.cor_da_chance_sobre_claro(0.7)))
	elif item.empilhavel:
		_ficha.add_child(TemaEncontro.rotulo("Você tem %d." % Bolsa.quantidade(item.id),
				TemaEncontro.TINTA_C))


func _regua() -> Control:
	var r := ColorRect.new()
	r.color = TemaEncontro.PERG_E
	r.custom_minimum_size = Vector2(0, 1)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


# ------------------------------------------------------------------ entrada

func _ao_clicar_aba(evento: InputEvent, id_cat: String) -> void:
	if evento is InputEventMouseButton and evento.pressed \
			and (evento as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		if id_cat != _cat_atual:
			_cat_atual = id_cat
			_indice = 0
			_reconstruir_abas()
			_reconstruir_lista()


func _ao_clicar_item(evento: InputEvent, i: int) -> void:
	if evento is InputEventMouseButton and evento.pressed \
			and (evento as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		_selecionar(i)
		_usar()


## Dona da entrada enquanto esta aberta. `_unhandled_input` proprio, e nao
## delegado pela cena, porque a bolsa e modal: ela cobre a tela e, enquanto
## cobre, nada atras dela deve ler tecla. Compare com MenuEscolhas, que divide a
## tela com a caixa de fala e por isso recebe o evento de fora.
func _unhandled_input(evento: InputEvent) -> void:
	if not _aberta:
		return
	if evento.is_action_pressed("ui_cancel") or evento.is_action_pressed("abrir_bolsa"):
		fechar()
	elif evento.is_action_pressed("ui_accept") or evento.is_action_pressed("interagir"):
		_usar()
	elif evento.is_action_pressed("mover_baixo") or evento.is_action_pressed("ui_down"):
		_selecionar(posmod(_indice + 1, maxi(_cartoes.size(), 1)))
	elif evento.is_action_pressed("mover_cima") or evento.is_action_pressed("ui_up"):
		_selecionar(posmod(_indice - 1, maxi(_cartoes.size(), 1)))
	elif evento.is_action_pressed("mover_direita") or evento.is_action_pressed("ui_right"):
		_trocar_categoria(1)
	elif evento.is_action_pressed("mover_esquerda") or evento.is_action_pressed("ui_left"):
		_trocar_categoria(-1)
	else:
		return
	get_viewport().set_input_as_handled()


func _usar() -> void:
	if _itens.is_empty():
		return
	item_usado.emit(_itens[_indice])


## Resultado de usar um item, no rodape. A lista e refeita porque a quantidade pode
## ter mudado, e a categoria pode ter esvaziado.
func avisar(texto: String) -> void:
	_categorias = Bolsa.categorias_com_itens()
	if not _tem_categoria(_cat_atual):
		_cat_atual = String(_categorias[0]["id"]) if not _categorias.is_empty() else ""
	_reconstruir_abas()
	_reconstruir_lista()
	_rodape.text = texto
