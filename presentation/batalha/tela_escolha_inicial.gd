class_name TelaEscolhaInicial
extends CanvasLayer

## Escolha de 1 entre 3 criaturas da seed, no comeco da partida (a Mirela oferece).
##
## E o primeiro contato do jogador com o gerador, por isso cada cartao mostra o que a
## criatura TEM e o que isso faz em batalha: o traco no corpo explica o golpe no menu.
## Nao decide nada: recebe as opcoes prontas (SelecaoBestiario) e devolve a escolhida.

signal escolhida(criatura: Criatura)
signal cancelada()

const CAMADA := 88
const LARGURA_CARTAO := 280.0
const TAMANHO_RETRATO := 144.0
const TEXTO_RODAPE := "SETAS escolher     E confirmar     ESC decidir depois"

var _raiz: Control
var _linha: HBoxContainer
var _cartoes: Array[PanelContainer] = []
var _opcoes: Array = []
var _indice: int = 0
var _aberta: bool = false


func _ready() -> void:
	layer = CAMADA
	_raiz = Control.new()
	_raiz.set_anchors_preset(Control.PRESET_FULL_RECT)
	_raiz.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_raiz)

	var veu := ColorRect.new()
	veu.color = Color(TemaEncontro.CONTORNO, 0.78)
	veu.set_anchors_preset(Control.PRESET_FULL_RECT)
	veu.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_raiz.add_child(veu)

	var centro := CenterContainer.new()
	centro.set_anchors_preset(Control.PRESET_FULL_RECT)
	centro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_raiz.add_child(centro)

	var coluna := VBoxContainer.new()
	coluna.add_theme_constant_override("separation", 14)
	coluna.mouse_filter = Control.MOUSE_FILTER_IGNORE
	centro.add_child(coluna)

	var titulo := TemaEncontro.rotulo("ESCOLHA SUA PRIMEIRA CRIATURA", TemaEncontro.OURO,
			TemaEncontro.Corpo.TITULO)
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	coluna.add_child(titulo)

	_linha = HBoxContainer.new()
	_linha.add_theme_constant_override("separation", 12)
	_linha.mouse_filter = Control.MOUSE_FILTER_IGNORE
	coluna.add_child(_linha)

	var rodape := TemaEncontro.rotulo(TEXTO_RODAPE, TemaEncontro.PERG_E)
	rodape.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	coluna.add_child(rodape)
	visible = false


func aberta() -> bool:
	return _aberta


func abrir(opcoes: Array, catalogo: CatalogoCorpos, tabelas: TabelasBatalha) -> void:
	_opcoes = opcoes
	_indice = 0
	for c: PanelContainer in _cartoes:
		_linha.remove_child(c)
		c.queue_free()
	_cartoes.clear()
	for i in opcoes.size():
		var cartao := _montar_cartao(opcoes[i], catalogo, tabelas, i)
		_linha.add_child(cartao)
		_cartoes.append(cartao)
	_aberta = true
	visible = true
	_pintar()


func fechar() -> void:
	_aberta = false
	visible = false


func _montar_cartao(c: Criatura, catalogo: CatalogoCorpos, tabelas: TabelasBatalha,
		indice: int) -> PanelContainer:
	var ficha := FichaCombate.de_criatura(c, tabelas)
	var cartao := PanelContainer.new()
	cartao.custom_minimum_size = Vector2(LARGURA_CARTAO, 0)
	cartao.mouse_filter = Control.MOUSE_FILTER_STOP
	cartao.mouse_entered.connect(_selecionar.bind(indice))
	cartao.gui_input.connect(_ao_clicar.bind(indice))

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cartao.add_child(v)

	var nome := TemaEncontro.rotulo(c.nome().to_upper(), TemaEncontro.OURO_C)
	nome.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(nome)

	var moldura := PanelContainer.new()
	moldura.add_theme_stylebox_override("panel", TemaEncontro.moldura("painel_ouro"))
	moldura.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	moldura.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(moldura)
	var render := CreatureSpriteRenderer.new()
	render.custom_minimum_size = Vector2(TAMANHO_RETRATO, TAMANHO_RETRATO)
	render.mouse_filter = Control.MOUSE_FILTER_IGNORE
	moldura.add_child(render)
	render.configurar(c, catalogo)

	var texto := TemaEncontro.texto_rico(TextoBatalha.ficha_em_bbcode(c, ficha))
	texto.custom_minimum_size = Vector2(LARGURA_CARTAO - 28.0, 0)
	v.add_child(texto)
	return cartao


func _pintar() -> void:
	for i in _cartoes.size():
		_cartoes[i].add_theme_stylebox_override("panel",
				TemaEncontro.moldura("cartao_selecionado" if i == _indice else "cartao"))


func _selecionar(i: int) -> void:
	if not _aberta or i == _indice or i < 0 or i >= _cartoes.size():
		return
	Som.tocar("ui_mover")
	_indice = i
	_pintar()


func _ao_clicar(evento: InputEvent, i: int) -> void:
	if _aberta and evento is InputEventMouseButton and evento.pressed \
			and (evento as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		_indice = i
		_confirmar()


func _confirmar() -> void:
	if not _aberta or _opcoes.is_empty():
		return
	Som.tocar("ui_confirmar")
	var c: Criatura = _opcoes[_indice]
	fechar()
	escolhida.emit(c)


func _unhandled_input(evento: InputEvent) -> void:
	if not _aberta:
		return
	if evento.is_action_pressed("ui_accept") or evento.is_action_pressed("interagir"):
		_confirmar()
	elif evento.is_action_pressed("ui_cancel"):
		fechar()
		cancelada.emit()
	elif evento.is_action_pressed("mover_direita") or evento.is_action_pressed("mover_baixo"):
		_selecionar(posmod(_indice + 1, _cartoes.size()))
	elif evento.is_action_pressed("mover_esquerda") or evento.is_action_pressed("mover_cima"):
		_selecionar(posmod(_indice - 1, _cartoes.size()))
	else:
		return
	get_viewport().set_input_as_handled()
