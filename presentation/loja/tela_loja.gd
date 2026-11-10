class_name TelaLoja
extends CanvasLayer

## A loja de um NPC: o que ele vende, o preco, quanto o jogador ja tem e o gold dele.
## E compra uma unidade por vez.
##
## Nao decide preco nem estoque: o que a loja vende vem de autoral/lojas/lojas.json
## (CatalogoLojas), o preco de data/economia/economia.json, e quem cobra e guarda e a
## Bolsa (Bolsa.comprar). A tela so mostra e pede.

signal fechada()

## Abaixo do menu de pausa (96): a loja e uma tela de jogo, e a pausa pode abrir por
## cima dela.
const CAMADA := 88
const LARGURA_LISTA := 452.0
const LARGURA_FICHA := 340.0
const ALTURA_CORPO := 360.0
const TEXTO_RODAPE := "SETAS item     E comprar um     ESC sair"

var _aberta: bool = false
var _itens: Array[ItemJogo] = []
var _indice: int = 0
var _titulo: Label
var _gold: Label
var _lista: VBoxContainer
var _rolagem: ScrollContainer
var _cartoes: Array[PanelContainer] = []
var _ficha: RichTextLabel
var _rodape: Label


func _ready() -> void:
	layer = CAMADA
	var raiz := Control.new()
	raiz.set_anchors_preset(Control.PRESET_FULL_RECT)
	raiz.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(raiz)

	var veu := ColorRect.new()
	veu.color = Color(TemaEncontro.CONTORNO, 0.72)
	veu.set_anchors_preset(Control.PRESET_FULL_RECT)
	veu.mouse_filter = Control.MOUSE_FILTER_IGNORE
	raiz.add_child(veu)

	var centro := CenterContainer.new()
	centro.set_anchors_preset(Control.PRESET_FULL_RECT)
	centro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	raiz.add_child(centro)

	var painel := PanelContainer.new()
	painel.add_theme_stylebox_override("panel", TemaEncontro.moldura("painel"))
	painel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	centro.add_child(painel)

	var coluna := VBoxContainer.new()
	coluna.add_theme_constant_override("separation", 10)
	coluna.mouse_filter = Control.MOUSE_FILTER_IGNORE
	painel.add_child(coluna)

	var topo := HBoxContainer.new()
	topo.add_theme_constant_override("separation", 16)
	topo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	coluna.add_child(topo)
	_titulo = TemaEncontro.rotulo("", TemaEncontro.OURO, TemaEncontro.Corpo.TITULO)
	_titulo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	topo.add_child(_titulo)
	_gold = TemaEncontro.rotulo("", TemaEncontro.OURO_C, TemaEncontro.Corpo.TITULO)
	topo.add_child(_gold)

	var corpo := HBoxContainer.new()
	corpo.add_theme_constant_override("separation", 14)
	corpo.custom_minimum_size = Vector2(0, ALTURA_CORPO)
	corpo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	coluna.add_child(corpo)

	_rolagem = ScrollContainer.new()
	_rolagem.custom_minimum_size = Vector2(LARGURA_LISTA, ALTURA_CORPO)
	_rolagem.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	corpo.add_child(_rolagem)
	_lista = VBoxContainer.new()
	_lista.add_theme_constant_override("separation", 4)
	_lista.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rolagem.add_child(_lista)

	var caixa := PanelContainer.new()
	caixa.add_theme_stylebox_override("panel", TemaEncontro.moldura("pergaminho"))
	caixa.custom_minimum_size = Vector2(LARGURA_FICHA, 0)
	caixa.mouse_filter = Control.MOUSE_FILTER_IGNORE
	corpo.add_child(caixa)
	_ficha = TemaEncontro.texto_rico()
	_ficha.add_theme_color_override("default_color", TemaEncontro.TINTA)
	_ficha.custom_minimum_size = Vector2(LARGURA_FICHA - 28.0, 0)
	caixa.add_child(_ficha)

	_rodape = TemaEncontro.rotulo(TEXTO_RODAPE, TemaEncontro.PERG_E)
	coluna.add_child(_rodape)
	visible = false
	Bolsa.gold_mudou.connect(func(_v: int) -> void: _atualizar_gold())


func aberta() -> bool:
	return _aberta


## `loja`: uma entrada de CatalogoLojas ({id, nome, itens}).
func abrir(loja: Dictionary) -> void:
	_itens.clear()
	for id: String in loja.get("itens", []):
		var i := Bolsa.item(id)
		if i != null and Bolsa.economia.preco(id) > 0:
			_itens.append(i)
	_titulo.text = String(loja.get("nome", "LOJA"))
	_indice = 0
	_aberta = true
	visible = true
	_rodape.text = TEXTO_RODAPE
	_reconstruir()
	_atualizar_gold()


func fechar() -> void:
	if not _aberta:
		return
	_aberta = false
	visible = false
	fechada.emit()


func _atualizar_gold() -> void:
	if _gold != null:
		_gold.text = "%d GOLD" % Bolsa.gold


func _reconstruir() -> void:
	for c: PanelContainer in _cartoes:
		_lista.remove_child(c)
		c.queue_free()
	_cartoes.clear()
	for i in _itens.size():
		_lista.add_child(_montar_linha(_itens[i], i))
	_pintar()


func _montar_linha(item: ItemJogo, indice: int) -> PanelContainer:
	var cartao := PanelContainer.new()
	cartao.mouse_filter = Control.MOUSE_FILTER_STOP
	cartao.mouse_entered.connect(_selecionar.bind(indice))
	cartao.gui_input.connect(_ao_clicar.bind(indice))
	_cartoes.append(cartao)

	var linha := HBoxContainer.new()
	linha.name = "Linha"
	linha.add_theme_constant_override("separation", 8)
	linha.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cartao.add_child(linha)

	var icone := IconeCaptura.new(item.id, 2)
	icone.custom_minimum_size = icone.tamanho()
	linha.add_child(icone)

	var nome := TemaEncontro.rotulo(item.nome, TemaEncontro.PERG)
	nome.name = "Nome"
	nome.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nome.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	linha.add_child(nome)

	var tem := TemaEncontro.rotulo("tem %d" % Bolsa.quantidade(item.id), TemaEncontro.PERG_E)
	tem.name = "Tem"
	tem.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	linha.add_child(tem)

	var preco := TemaEncontro.rotulo("%d G" % Bolsa.economia.preco(item.id), TemaEncontro.OURO)
	preco.custom_minimum_size = Vector2(56, 0)
	preco.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	preco.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	linha.add_child(preco)
	return cartao


func _pintar() -> void:
	for i in _cartoes.size():
		var sel: bool = i == _indice
		_cartoes[i].add_theme_stylebox_override("panel",
				TemaEncontro.moldura("cartao_selecionado" if sel else "cartao"))
		(_cartoes[i].get_node("Linha/Nome") as Label).add_theme_color_override("font_color",
				TemaEncontro.PERG_C if sel else TemaEncontro.PERG_E)
		(_cartoes[i].get_node("Linha/Tem") as Label).text = "tem %d" % Bolsa.quantidade(_itens[i].id)
	_atualizar_ficha()


func _atualizar_ficha() -> void:
	if _itens.is_empty():
		_ficha.text = "Nada à venda."
		return
	var item := _itens[_indice]
	var detalhe := item.detalhe(null)
	_ficha.text = "[color=%s]%s[/color]\n%d gold\n\n%s%s" % [TemaEncontro.TINTA.to_html(false),
			item.nome.to_upper(), Bolsa.economia.preco(item.id), item.descricao,
			("\n\n" + detalhe) if detalhe != "" else ""]


func _selecionar(i: int) -> void:
	if not _aberta or i == _indice or i < 0 or i >= _cartoes.size():
		return
	_indice = i
	_pintar()


func _ao_clicar(evento: InputEvent, i: int) -> void:
	if _aberta and evento is InputEventMouseButton and evento.pressed \
			and (evento as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		_indice = i
		comprar_selecionado()


## Compra uma unidade do item sob o cursor. Publica para o teste.
func comprar_selecionado() -> String:
	if _itens.is_empty():
		return "Nada à venda."
	var item := _itens[_indice]
	var erro := Bolsa.comprar(item.id)
	_rodape.text = erro if erro != "" else "Comprou: %s." % item.nome
	_pintar()
	return erro


func _unhandled_input(evento: InputEvent) -> void:
	if not _aberta:
		return
	if evento.is_action_pressed("ui_cancel") or evento.is_action_pressed("pausar"):
		fechar()
	elif evento.is_action_pressed("ui_accept") or evento.is_action_pressed("interagir"):
		comprar_selecionado()
	elif evento.is_action_pressed("mover_baixo") or evento.is_action_pressed("ui_down"):
		_selecionar(posmod(_indice + 1, maxi(_cartoes.size(), 1)))
	elif evento.is_action_pressed("mover_cima") or evento.is_action_pressed("ui_up"):
		_selecionar(posmod(_indice - 1, maxi(_cartoes.size(), 1)))
	else:
		return
	get_viewport().set_input_as_handled()
