class_name TelaEquipe
extends CanvasLayer

## Equipe e deposito, no menu de pausa. A primeira da equipe e quem entra em campo.
##
## Duas teclas: E marca uma criatura, E em outra faz a troca. Sobra vaga na equipe, E
## numa criatura do deposito a sobe direto. A regra vive em EquipeJogador; aqui so se
## recusa, por escrito, a troca que deixaria a equipe sem ninguem de pe.

signal fechada()

## Acima do menu de pausa (96), pelo mesmo motivo da bolsa.
const CAMADA := 97
const LARGURA_LISTA := 430.0
const LARGURA_FICHA := 340.0
const ALTURA_CORPO := 392.0
const TAMANHO_RETRATO := 144.0
const TEXTO_RODAPE := "SETAS criatura     E marcar e trocar     ESC fechar"

var _equipe: EquipeJogador
var _catalogo: CatalogoCorpos
var _aberta: bool = false
var _raiz: Control
var _lista: VBoxContainer
var _ficha_render: CreatureSpriteRenderer
var _ficha_texto: RichTextLabel
var _rodape: Label

## Cada linha: {"c": Combatente, "ativo": bool, "i": int}
var _linhas: Array = []
var _cartoes: Array[PanelContainer] = []
var _indice: int = 0
var _marcado: int = -1


func _ready() -> void:
	layer = CAMADA
	process_mode = Node.PROCESS_MODE_ALWAYS
	_raiz = Control.new()
	_raiz.set_anchors_preset(Control.PRESET_FULL_RECT)
	_raiz.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_raiz)

	var veu := ColorRect.new()
	veu.color = Color(TemaEncontro.CONTORNO, 0.72)
	veu.set_anchors_preset(Control.PRESET_FULL_RECT)
	veu.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_raiz.add_child(veu)

	var centro := CenterContainer.new()
	centro.set_anchors_preset(Control.PRESET_FULL_RECT)
	centro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_raiz.add_child(centro)

	var painel := PanelContainer.new()
	painel.add_theme_stylebox_override("panel", TemaEncontro.moldura("painel"))
	painel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	centro.add_child(painel)

	var coluna := VBoxContainer.new()
	coluna.add_theme_constant_override("separation", 10)
	coluna.mouse_filter = Control.MOUSE_FILTER_IGNORE
	painel.add_child(coluna)

	coluna.add_child(TemaEncontro.rotulo("EQUIPE", TemaEncontro.OURO, TemaEncontro.Corpo.TITULO))

	var corpo := HBoxContainer.new()
	corpo.add_theme_constant_override("separation", 14)
	corpo.custom_minimum_size = Vector2(0, ALTURA_CORPO)
	corpo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	coluna.add_child(corpo)

	var rolagem := ScrollContainer.new()
	rolagem.custom_minimum_size = Vector2(LARGURA_LISTA, ALTURA_CORPO)
	rolagem.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	corpo.add_child(rolagem)

	_lista = VBoxContainer.new()
	_lista.add_theme_constant_override("separation", 4)
	_lista.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rolagem.add_child(_lista)

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
	_ficha_render.custom_minimum_size = Vector2(TAMANHO_RETRATO, TAMANHO_RETRATO)
	_ficha_render.mouse_filter = Control.MOUSE_FILTER_IGNORE
	moldura.add_child(_ficha_render)

	_ficha_texto = TemaEncontro.texto_rico()
	_ficha_texto.custom_minimum_size = Vector2(LARGURA_FICHA - 28.0, 0)
	v.add_child(_ficha_texto)

	_rodape = TemaEncontro.rotulo("", TemaEncontro.PERG_E)
	coluna.add_child(_rodape)
	visible = false


func aberta() -> bool:
	return _aberta


func abrir(equipe: EquipeJogador, catalogo: CatalogoCorpos) -> void:
	_equipe = equipe
	_catalogo = catalogo
	_indice = 0
	_marcado = -1
	_aberta = true
	visible = true
	_reconstruir()
	_dica_padrao()


func fechar() -> void:
	if not _aberta:
		return
	_aberta = false
	visible = false
	fechada.emit()


func _dica_padrao() -> void:
	_rodape.text = TEXTO_RODAPE


func _reconstruir() -> void:
	for c: PanelContainer in _cartoes:
		_lista.remove_child(c)
		c.queue_free()
	_cartoes.clear()
	_linhas.clear()
	for i in _equipe.ativos.size():
		_linhas.append({"c": _equipe.ativos[i], "ativo": true, "i": i})
	for i in _equipe.deposito.size():
		_linhas.append({"c": _equipe.deposito[i], "ativo": false, "i": i})
	_indice = clampi(_indice, 0, maxi(_linhas.size() - 1, 0))
	for i in _linhas.size():
		_lista.add_child(_montar_linha(i))
	_pintar()


func _montar_linha(i: int) -> PanelContainer:
	var l: Dictionary = _linhas[i]
	var c: Combatente = l["c"]
	var cartao := PanelContainer.new()
	cartao.mouse_filter = Control.MOUSE_FILTER_STOP
	cartao.mouse_entered.connect(_selecionar.bind(i))
	cartao.gui_input.connect(_ao_clicar.bind(i))
	_cartoes.append(cartao)

	var h := HBoxContainer.new()
	h.name = "Linha"
	h.add_theme_constant_override("separation", 8)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cartao.add_child(h)

	var lugar := "%d" % (int(l["i"]) + 1) if l["ativo"] else "dep"
	h.add_child(TemaEncontro.rotulo(lugar, TemaEncontro.OURO if l["ativo"] else TemaEncontro.PERG_E))

	var nome := TemaEncontro.rotulo(c.nome(), TemaEncontro.PERG)
	nome.name = "Nome"
	nome.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(nome)

	var barra := MedidorChance.new(8, false)
	barra.valor = c.fracao()
	barra.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(barra)

	h.add_child(TemaEncontro.rotulo("%d/%d" % [c.vida, c.ficha.vida],
			TemaEncontro.PERG_C if c.viva() else TemaEncontro.FALHA))
	return cartao


func _pintar() -> void:
	for i in _cartoes.size():
		var nome := "cartao"
		if i == _indice or i == _marcado:
			nome = "cartao_selecionado"
		_cartoes[i].add_theme_stylebox_override("panel", TemaEncontro.moldura(nome))
		var rotulo := _cartoes[i].get_node("Linha/Nome") as Label
		rotulo.add_theme_color_override("font_color",
				TemaEncontro.OURO_C if i == _marcado else
				(TemaEncontro.PERG_C if i == _indice else TemaEncontro.PERG_E))
	_atualizar_ficha()


func _atualizar_ficha() -> void:
	if _linhas.is_empty():
		_ficha_render.configurar(null, _catalogo)
		_ficha_texto.text = "Nenhuma criatura ainda."
		return
	var c: Combatente = _linhas[_indice]["c"]
	_ficha_render.configurar(c.criatura, _catalogo)
	_ficha_texto.text = "[color=%s]%s[/color]\n%s" % [TemaEncontro.OURO_C.to_html(false),
			c.nome().to_upper(), TextoBatalha.ficha_em_bbcode(c.criatura, c.ficha)]


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
		_acionar()


## Primeiro E marca (ou sobe direto, se ha vaga); segundo E troca.
func _acionar() -> void:
	if _linhas.is_empty():
		return
	var atual: Dictionary = _linhas[_indice]
	if _marcado < 0:
		if not atual["ativo"] and _equipe.ativos.size() < _equipe.maximo:
			_equipe.promover(int(atual["i"]))
			_reconstruir()
			return
		_marcado = _indice
		_rodape.text = "Agora escolha com quem trocar."
		_pintar()
		return

	var marcado: Dictionary = _linhas[_marcado]
	var erro := _trocar(marcado, atual)
	_marcado = -1
	_reconstruir()
	if erro != "":
		_rodape.text = erro
	else:
		_dica_padrao()


func _trocar(a: Dictionary, b: Dictionary) -> String:
	if a["ativo"] and b["ativo"]:
		_equipe.trocar_posicoes(int(a["i"]), int(b["i"]))
		return ""
	if not a["ativo"] and not b["ativo"]:
		return "As duas estão no depósito: nada muda."
	var ativo: Dictionary = a if a["ativo"] else b
	var dep: Dictionary = b if a["ativo"] else a
	# Sem ninguem de pe a equipe nao entra em batalha nenhuma: nao se oferece isso.
	if _equipe.vivos() == 1 and (ativo["c"] as Combatente).viva() \
			and not (dep["c"] as Combatente).viva():
		return "A equipe ficaria sem ninguém de pé."
	_equipe.trocar_com_deposito(int(ativo["i"]), int(dep["i"]))
	return ""


func _unhandled_input(evento: InputEvent) -> void:
	if not _aberta:
		return
	if evento.is_action_pressed("ui_cancel") or evento.is_action_pressed("pausar"):
		if _marcado >= 0:
			_marcado = -1
			_dica_padrao()
			_pintar()
		else:
			fechar()
	elif evento.is_action_pressed("ui_accept") or evento.is_action_pressed("interagir"):
		_acionar()
	elif evento.is_action_pressed("mover_baixo") or evento.is_action_pressed("ui_down"):
		_selecionar(posmod(_indice + 1, maxi(_cartoes.size(), 1)))
	elif evento.is_action_pressed("mover_cima") or evento.is_action_pressed("ui_up"):
		_selecionar(posmod(_indice - 1, maxi(_cartoes.size(), 1)))
	else:
		return
	get_viewport().set_input_as_handled()
