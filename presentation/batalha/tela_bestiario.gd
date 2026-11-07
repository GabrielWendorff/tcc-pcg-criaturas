class_name TelaBestiario
extends CanvasLayer

## O bestiario que a seed gerou, dentro do jogo: as ~100 criaturas, com uma marca nas
## que o jogador ja capturou, e a ficha da selecionada.
##
## Existe na build de entrega, ao contrario do visualizador de desenvolvimento (F2):
## e por aqui que quem joga ve a saida do gerador inteira, e nao so as criaturas que
## cruzaram o caminho. Nao gera nada: recebe o bestiario pronto (RF07).

signal fechada()

## Acima do menu de pausa (96), como a bolsa e a equipe.
const CAMADA := 97
const COLUNAS := 7
const LADO_CELULA := 76.0
const LADO_RETRATO := 72.0
const ALTURA_CORPO := 420.0
const LARGURA_FICHA := 330.0
const TAMANHO_RETRATO_FICHA := 144.0
const TEXTO_RODAPE := "SETAS criatura     ESC ou N fechar"

var _bestiario: Array = []
var _capturadas: Callable
var _catalogo: CatalogoCorpos
var _tabelas: TabelasBatalha
var _aberta: bool = false
var _indice: int = 0

var _subtitulo: Label
var _rolagem: ScrollContainer
var _grade: GridContainer
var _celulas: Array[PanelContainer] = []
var _ficha_render: CreatureSpriteRenderer
var _ficha_texto: RichTextLabel


func _ready() -> void:
	layer = CAMADA
	process_mode = Node.PROCESS_MODE_ALWAYS
	var raiz := Control.new()
	raiz.set_anchors_preset(Control.PRESET_FULL_RECT)
	raiz.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(raiz)

	var veu := ColorRect.new()
	veu.color = Color(TemaEncontro.CONTORNO, 0.78)
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
	coluna.add_theme_constant_override("separation", 8)
	coluna.mouse_filter = Control.MOUSE_FILTER_IGNORE
	painel.add_child(coluna)

	var topo := HBoxContainer.new()
	topo.add_theme_constant_override("separation", 16)
	topo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	coluna.add_child(topo)
	topo.add_child(TemaEncontro.rotulo("BESTIÁRIO", TemaEncontro.OURO, TemaEncontro.Corpo.TITULO))
	_subtitulo = TemaEncontro.rotulo("", TemaEncontro.PERG_E)
	_subtitulo.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	topo.add_child(_subtitulo)

	var corpo := HBoxContainer.new()
	corpo.add_theme_constant_override("separation", 14)
	corpo.custom_minimum_size = Vector2(0, ALTURA_CORPO)
	corpo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	coluna.add_child(corpo)

	_rolagem = ScrollContainer.new()
	_rolagem.custom_minimum_size = Vector2(COLUNAS * (LADO_CELULA + 4.0) + 14.0, ALTURA_CORPO)
	_rolagem.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	corpo.add_child(_rolagem)

	_grade = GridContainer.new()
	_grade.columns = COLUNAS
	_grade.add_theme_constant_override("h_separation", 4)
	_grade.add_theme_constant_override("v_separation", 4)
	_rolagem.add_child(_grade)

	var caixa := PanelContainer.new()
	caixa.add_theme_stylebox_override("panel", TemaEncontro.moldura("painel"))
	caixa.custom_minimum_size = Vector2(LARGURA_FICHA, 0)
	caixa.mouse_filter = Control.MOUSE_FILTER_IGNORE
	corpo.add_child(caixa)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caixa.add_child(v)

	var moldura := PanelContainer.new()
	moldura.add_theme_stylebox_override("panel", TemaEncontro.moldura("painel_ouro"))
	moldura.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	moldura.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(moldura)
	_ficha_render = CreatureSpriteRenderer.new()
	_ficha_render.custom_minimum_size = Vector2(TAMANHO_RETRATO_FICHA, TAMANHO_RETRATO_FICHA)
	_ficha_render.mouse_filter = Control.MOUSE_FILTER_IGNORE
	moldura.add_child(_ficha_render)

	_ficha_texto = TemaEncontro.texto_rico()
	_ficha_texto.custom_minimum_size = Vector2(LARGURA_FICHA - 28.0, 0)
	v.add_child(_ficha_texto)

	coluna.add_child(TemaEncontro.rotulo(TEXTO_RODAPE, TemaEncontro.PERG_E))
	visible = false


func aberta() -> bool:
	return _aberta


## `capturadas`: Callable(Criatura) -> bool. Consultada a cada abertura, para a marca
## acompanhar a colecao sem esta tela guardar copia dela.
func abrir(bestiario: Array, capturadas: Callable, catalogo: CatalogoCorpos,
		tabelas: TabelasBatalha, rotulo_seed: String) -> void:
	_bestiario = bestiario
	_capturadas = capturadas
	_catalogo = catalogo
	_tabelas = tabelas
	_aberta = true
	visible = true
	_reconstruir()
	_subtitulo.text = "SEED %s   ·   CAPTURADAS %d DE %d" % [rotulo_seed, total_capturadas(),
			_bestiario.size()]
	_selecionar(clampi(_indice, 0, maxi(_bestiario.size() - 1, 0)), true)


func fechar() -> void:
	if not _aberta:
		return
	_aberta = false
	visible = false
	fechada.emit()


func total_capturadas() -> int:
	var n: int = 0
	for c: Criatura in _bestiario:
		if _capturada(c):
			n += 1
	return n


func _capturada(c: Criatura) -> bool:
	return _capturadas.is_valid() and bool(_capturadas.call(c))


func _reconstruir() -> void:
	for cel: PanelContainer in _celulas:
		_grade.remove_child(cel)
		cel.queue_free()
	_celulas.clear()
	for i in _bestiario.size():
		var cel := _montar_celula(_bestiario[i], i)
		_grade.add_child(cel)
		_celulas.append(cel)


func _montar_celula(c: Criatura, i: int) -> PanelContainer:
	var cel := PanelContainer.new()
	cel.name = "Celula_%03d" % c.id
	cel.custom_minimum_size = Vector2(LADO_CELULA, LADO_CELULA)
	cel.mouse_filter = Control.MOUSE_FILTER_STOP
	cel.mouse_entered.connect(_selecionar.bind(i, false))
	cel.gui_input.connect(_ao_clicar.bind(i))

	var area := Control.new()
	area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cel.add_child(area)

	var render := CreatureSpriteRenderer.new()
	render.size = Vector2(LADO_RETRATO, LADO_RETRATO)
	render.mouse_filter = Control.MOUSE_FILTER_IGNORE
	area.add_child(render)
	render.configurar(c, _catalogo)

	# No canto de cima: embaixo ficam as patas e as garras.
	var numero := TemaEncontro.rotulo("%03d" % c.id, TemaEncontro.PERG_E)
	numero.position = Vector2(3, 1)
	area.add_child(numero)

	if _capturada(c):
		var selo := SeloCapturada.new()
		selo.name = "Capturada"
		selo.position = Vector2(LADO_RETRATO - SeloCapturada.LADO, 0)
		area.add_child(selo)
	return cel


func _selecionar(i: int, forcar: bool = false) -> void:
	if not _aberta or i < 0 or i >= _celulas.size() or (i == _indice and not forcar):
		return
	_indice = i
	for j in _celulas.size():
		_celulas[j].add_theme_stylebox_override("panel",
				TemaEncontro.moldura("cartao_selecionado" if j == _indice else "cartao"))
	_atualizar_ficha()
	_rolar_ate(i)


func _atualizar_ficha() -> void:
	var c: Criatura = _bestiario[_indice]
	_ficha_render.configurar(c, _catalogo)
	var situacao := "[color=%s]CAPTURADA[/color]" % TemaEncontro.VERDE_C.to_html(false) \
			if _capturada(c) else "[color=%s]ainda não capturada[/color]" \
			% TemaEncontro.PERG_E.to_html(false)
	_ficha_texto.text = "[color=%s]%s[/color]\n%s\n%s" % [TemaEncontro.OURO_C.to_html(false),
			c.nome().to_upper(), situacao,
			TextoBatalha.ficha_em_bbcode(c, FichaCombate.de_criatura(c, _tabelas))]


func _rolar_ate(i: int) -> void:
	var linha: int = i / COLUNAS
	var topo: float = linha * (LADO_CELULA + 4.0)
	var base: float = topo + LADO_CELULA
	if topo < _rolagem.scroll_vertical:
		_rolagem.scroll_vertical = int(topo)
	elif base > _rolagem.scroll_vertical + ALTURA_CORPO:
		_rolagem.scroll_vertical = int(base - ALTURA_CORPO)


func _ao_clicar(evento: InputEvent, i: int) -> void:
	if _aberta and evento is InputEventMouseButton and evento.pressed \
			and (evento as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		_selecionar(i)


func _unhandled_input(evento: InputEvent) -> void:
	if not _aberta:
		return
	var n: int = _celulas.size()
	if evento.is_action_pressed("ui_cancel") or evento.is_action_pressed("abrir_bestiario"):
		fechar()
	elif evento.is_action_pressed("mover_direita") or evento.is_action_pressed("ui_right"):
		_selecionar(mini(_indice + 1, n - 1))
	elif evento.is_action_pressed("mover_esquerda") or evento.is_action_pressed("ui_left"):
		_selecionar(maxi(_indice - 1, 0))
	elif evento.is_action_pressed("mover_baixo") or evento.is_action_pressed("ui_down"):
		_selecionar(mini(_indice + COLUNAS, n - 1))
	elif evento.is_action_pressed("mover_cima") or evento.is_action_pressed("ui_up"):
		_selecionar(maxi(_indice - COLUNAS, 0))
	else:
		return
	get_viewport().set_input_as_handled()


## Marca de capturada: um visto em pixel art sobre um selo verde. Desenhado aqui
## porque a fonte do jogo nao tem o glifo, e um quadrado vazio no lugar da marca
## diria o contrario do que ela quer dizer.
class SeloCapturada extends Control:
	const PIXEL := 2.0
	const LADO := 20.0
	## O visto, em pixels de arte (7x6): 1 = tinta.
	const DESENHO := [
		"0000001",
		"0000011",
		"1000110",
		"1101100",
		"0111000",
		"0010000",
	]

	func _init() -> void:
		custom_minimum_size = Vector2(LADO, LADO)
		size = Vector2(LADO, LADO)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), TemaEncontro.CONTORNO)
		draw_rect(Rect2(Vector2(PIXEL, PIXEL), size - Vector2(PIXEL, PIXEL) * 2.0),
				TemaEncontro.VERDE)
		var origem := Vector2(3.0, 4.0)
		for y in DESENHO.size():
			var linha: String = DESENHO[y]
			for x in linha.length():
				if linha[x] == "1":
					draw_rect(Rect2(origem + Vector2(x, y) * PIXEL, Vector2(PIXEL, PIXEL)),
							TemaEncontro.PERG_C)
