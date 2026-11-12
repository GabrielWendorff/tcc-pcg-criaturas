class_name PainelOpcoes
extends Control

## A tela de opcoes. UMA LISTA, construida varrendo `Opcoes.definicoes()`.
##
## Nenhum nome de opcao aparece neste arquivo. Acrescentar "desligar flashes" ao
## jogo e acrescentar uma entrada em Opcoes.DEFINICOES — esta tela ganha a linha
## sozinha, com o rotulo, o valor corrente e a descricao que a definicao declara.
## Era isso que o pedido chamava de "padrao facil de acrescentar novas opcoes".
##
## UM GESTO SO. Booleana e escolha se percorrem com a MESMA confirmacao
## (`DefinicaoOpcao.proximo`): ligar/desligar e ciclar lento→normal→rápido são a
## mesma acao do ponto de vista do jogador, e uma tela com dois gestos diferentes
## para duas linhas vizinhas obriga a aprender qual e qual.
##
## SERVE AS DUAS PORTAS — menu principal e menu de pausa. E o mesmo Control
## instanciado nos dois lugares, porque "opcoes" nao e uma tela do menu, e uma
## tela do jogo.

signal cancelado()

const LARGURA := 460.0


var _coluna: VBoxContainer
var _descricao: Label
var _itens: Array[PanelContainer] = []
var _ids: PackedStringArray = PackedStringArray()
var _indice: int = 0
var _ativo: bool = false


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	var centro := CenterContainer.new()
	centro.set_anchors_preset(Control.PRESET_FULL_RECT)
	centro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(centro)

	_coluna = VBoxContainer.new()
	_coluna.add_theme_constant_override("separation", 6)
	_coluna.custom_minimum_size = Vector2(LARGURA, 0)
	_coluna.mouse_filter = Control.MOUSE_FILTER_IGNORE
	centro.add_child(_coluna)

	_coluna.add_child(TemaEncontro.rotulo("OPÇÕES", TemaEncontro.OURO,
			TemaEncontro.Corpo.TITULO))

	for def: DefinicaoOpcao in Opcoes.definicoes():
		_montar_linha(def.id, def.rotulo)
	# As duas ultimas nao sao opcoes: sao acoes. Entram na MESMA lista para que a
	# navegacao seja uma so — uma fileira de botoes a parte exigiria um segundo
	# eixo de movimento numa tela de seis linhas.
	_montar_linha("", "RESTAURAR PADRÕES")
	_montar_linha("", "VOLTAR")

	var caixa := PanelContainer.new()
	caixa.add_theme_stylebox_override("panel", TemaEncontro.moldura("painel"))
	caixa.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_descricao = TemaEncontro.rotulo("", TemaEncontro.TEXTO_APOIO)
	_descricao.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_descricao.custom_minimum_size = Vector2(LARGURA - 30.0, 32)
	caixa.add_child(_descricao)
	_coluna.add_child(caixa)

	Opcoes.mudou.connect(func(_id: String, _v: Variant) -> void: _pintar())
	visible = false


func _montar_linha(id: String, rotulo: String) -> void:
	var i: int = _itens.size()
	var cartao := PanelContainer.new()
	cartao.name = "Linha%d" % i
	cartao.mouse_filter = Control.MOUSE_FILTER_STOP
	cartao.mouse_entered.connect(_selecionar.bind(i))
	cartao.gui_input.connect(_ao_clicar.bind(i))

	var linha := HBoxContainer.new()
	linha.name = "Linha"
	linha.add_theme_constant_override("separation", 8)
	linha.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cartao.add_child(linha)

	var seta := TemaEncontro.rotulo("▶", TemaEncontro.OURO)
	seta.name = "Seta"
	linha.add_child(seta)

	var texto := TemaEncontro.rotulo(rotulo, TemaEncontro.PERG)
	texto.name = "Texto"
	texto.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	linha.add_child(texto)

	var valor := TemaEncontro.rotulo("", TemaEncontro.OURO_C)
	valor.name = "Valor"
	linha.add_child(valor)

	_coluna.add_child(cartao)
	_itens.append(cartao)
	_ids.append(id)


func abrir() -> void:
	_indice = 0
	_ativo = true
	visible = true
	_pintar()


func fechar() -> void:
	_ativo = false
	visible = false


func ativo() -> bool:
	return _ativo


func _selecionar(i: int) -> void:
	if not _ativo or i == _indice or i < 0 or i >= _itens.size():
		return
	Som.tocar("ui_mover")
	_indice = i
	_pintar()


func _pintar() -> void:
	for i in _itens.size():
		var sel: bool = i == _indice
		_itens[i].add_theme_stylebox_override("panel",
				TemaEncontro.moldura("cartao_selecionado" if sel else "cartao"))
		var linha := _itens[i].get_node("Linha") as HBoxContainer
		(linha.get_node("Seta") as Label).modulate.a = 1.0 if sel else 0.0
		(linha.get_node("Texto") as Label).add_theme_color_override("font_color",
				TemaEncontro.PERG_C if sel else TemaEncontro.PERG_E)
		var id := _ids[i]
		var valor := linha.get_node("Valor") as Label
		valor.text = Opcoes.rotulo_do_valor(id) if id != "" else ""
	var id_sel := _ids[_indice]
	var def: DefinicaoOpcao = null
	if id_sel != "":
		def = Opcoes.definicao(id_sel)
	_descricao.text = def.descricao if def != null else ""


func _ao_clicar(evento: InputEvent, i: int) -> void:
	if not _ativo:
		return
	if evento is InputEventMouseButton and evento.pressed \
			and (evento as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		_indice = i
		_confirmar()


func tratar_entrada(evento: InputEvent) -> bool:
	if not _ativo:
		return false
	if evento.is_action_pressed("ui_accept") or evento.is_action_pressed("interagir"):
		_confirmar()
		return true
	if evento.is_action_pressed("ui_cancel"):
		cancelado.emit()
		return true
	if evento.is_action_pressed("mover_baixo") or evento.is_action_pressed("ui_down"):
		_selecionar(posmod(_indice + 1, _itens.size()))
		return true
	if evento.is_action_pressed("mover_cima") or evento.is_action_pressed("ui_up"):
		_selecionar(posmod(_indice - 1, _itens.size()))
		return true
	# Esquerda/direita tambem alternam: numa linha que mostra um valor, a seta
	# lateral e o gesto que o jogador tenta primeiro.
	if evento.is_action_pressed("mover_direita") or evento.is_action_pressed("ui_right") \
			or evento.is_action_pressed("mover_esquerda") or evento.is_action_pressed("ui_left"):
		if _ids[_indice] != "":
			Opcoes.alternar(_ids[_indice])
		return true
	return false


func _confirmar() -> void:
	Som.tocar("ui_confirmar")
	var id := _ids[_indice]
	if id != "":
		Opcoes.alternar(id)
		return
	# Linhas sem id sao as acoes, na ordem em que foram montadas.
	if _indice == _itens.size() - 1:
		cancelado.emit()
	else:
		Opcoes.restaurar_padroes()
		_pintar()
