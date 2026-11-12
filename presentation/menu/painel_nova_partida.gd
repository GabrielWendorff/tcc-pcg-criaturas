class_name PainelNovaPartida
extends Control

## Tela de nova partida: a escolha da SEED.
##
## POR QUE ESTA TELA EXISTE. RF01 e "criacao de mundo via seed" e RF03 e
## "reprodutibilidade total pela seed" — e ate aqui os dois eram uma constante no
## codigo (`VilaInicial.SEED_DO_MUNDO = 123456789`). Um trabalho cuja contribuicao
## e que a mesma semente reproduz o mesmo bestiario precisa deixar o jogador
## digitar a semente; sem isso a propriedade existe e nao se demonstra.
##
## A tela mostra, ao vivo, o NUMERO em que o texto digitado foi convertido. E o
## que torna a promessa verificavel sem abrir o codigo: duas partidas com a mesma
## palavra exibem o mesmo numero, e o numero e o que o gerador recebe.
##
## Texto puramente numerico vale por si (ver Save.seed_de_texto). Digitar
## "123456789" abre o MESMO mundo do visualizador do bestiario e dos testes — e o
## que permite conferir, criatura por criatura, o que apareceu no mato.
##
## NAVEGACAO. Lista vertical, como todo menu do jogo. O campo de texto e a
## primeira linha e so captura teclado depois de confirmado (E/ENTER): sem isso,
## andar na lista com W/S digitaria "w" e "s" na seed.

signal comecar(semente: int, texto: String)
signal cancelado()

const LARGURA := 420.0

enum Linha { CAMPO, SORTEAR, COMECAR, VOLTAR }

var _coluna: VBoxContainer
var _campo: LineEdit
var _resolvida: Label
var _aviso: Label
var _itens: Array[PanelContainer] = []
var _rotulos: Array[Label] = []
var _indice: int = Linha.CAMPO
var _ativo: bool = false
var _editando: bool = false
var _slot: int = 0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	var centro := CenterContainer.new()
	centro.name = "Centro"
	centro.set_anchors_preset(Control.PRESET_FULL_RECT)
	centro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(centro)

	_coluna = VBoxContainer.new()
	_coluna.name = "Coluna"
	_coluna.add_theme_constant_override("separation", 7)
	_coluna.custom_minimum_size = Vector2(LARGURA, 0)
	_coluna.mouse_filter = Control.MOUSE_FILTER_IGNORE
	centro.add_child(_coluna)

	_montar_campo()
	_montar_leitura()
	for linha in [Linha.SORTEAR, Linha.COMECAR, Linha.VOLTAR]:
		_montar_item(linha)
	visible = false


func _montar_campo() -> void:
	var cartao := PanelContainer.new()
	cartao.name = "CartaoCampo"
	cartao.mouse_filter = Control.MOUSE_FILTER_STOP
	cartao.mouse_entered.connect(_selecionar.bind(Linha.CAMPO))
	cartao.gui_input.connect(_ao_clicar.bind(Linha.CAMPO))

	var margem := MarginContainer.new()
	for lado in ["left", "right", "top", "bottom"]:
		margem.add_theme_constant_override("margin_" + lado, 6)
	margem.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cartao.add_child(margem)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margem.add_child(col)
	col.add_child(TemaEncontro.rotulo("SEED DO MUNDO", TemaEncontro.OURO))

	_campo = LineEdit.new()
	_campo.name = "Campo"
	_campo.placeholder_text = "número ou palavra"
	# 24 e o que cabe na largura do cartao na fonte 5x7. A fonte do projeto tem
	# 127 glifos (ASCII + acentos do portugues): um caractere fora disso sai como
	# caixa vazia, e por isso o campo e curto e o resultado aparece logo abaixo.
	_campo.max_length = 24
	_campo.alignment = HORIZONTAL_ALIGNMENT_LEFT
	# A fonte do LineEdit e aplicada a mao: TemaEncontro.aplicar_fonte so sabe
	# escrever em Label, e o tamanho tem de ser o NATIVO da folha (ver o aviso no
	# cabecalho de TemaEncontro) ou o texto digitado sai borrado.
	_campo.add_theme_font_override("font", TemaEncontro.fonte())
	_campo.add_theme_font_size_override("font_size", TemaEncontro.TAM_TEXTO)
	_campo.add_theme_color_override("font_color", TemaEncontro.TINTA)
	_campo.add_theme_color_override("font_placeholder_color", TemaEncontro.TINTA_C)
	_campo.add_theme_color_override("caret_color", TemaEncontro.TINTA)
	_campo.add_theme_color_override("selection_color", TemaEncontro.OURO)
	_campo.add_theme_stylebox_override("normal", TemaEncontro.moldura("pergaminho"))
	_campo.add_theme_stylebox_override("focus", TemaEncontro.moldura("painel_ouro"))
	_campo.text_changed.connect(func(_t): _atualizar_leitura())
	_campo.text_submitted.connect(func(_t): _sair_da_edicao())
	col.add_child(_campo)

	_coluna.add_child(cartao)
	_itens.append(cartao)
	_rotulos.append(null)


## Linha de leitura: o numero em que a seed digitada foi convertida, mais o aviso
## de sobrescrita quando o slot ja tem save.
func _montar_leitura() -> void:
	var caixa := PanelContainer.new()
	caixa.name = "Leitura"
	caixa.add_theme_stylebox_override("panel", TemaEncontro.moldura("painel"))
	caixa.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 3)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caixa.add_child(col)

	_resolvida = TemaEncontro.rotulo("", TemaEncontro.PERG_C)
	_resolvida.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_resolvida)

	_aviso = TemaEncontro.rotulo("", TemaEncontro.ATENCAO)
	_aviso.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_aviso)

	_coluna.add_child(caixa)


func _montar_item(linha: Linha) -> void:
	var cartao := PanelContainer.new()
	cartao.name = "Item%d" % int(linha)
	cartao.mouse_filter = Control.MOUSE_FILTER_STOP
	cartao.mouse_entered.connect(_selecionar.bind(linha))
	cartao.gui_input.connect(_ao_clicar.bind(linha))

	var caixa := HBoxContainer.new()
	caixa.add_theme_constant_override("separation", 6)
	caixa.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cartao.add_child(caixa)

	var seta := TemaEncontro.rotulo("▶", TemaEncontro.OURO)
	seta.name = "Seta"
	caixa.add_child(seta)

	var texto := TemaEncontro.rotulo(_texto_do_item(linha), TemaEncontro.PERG)
	texto.name = "Texto"
	caixa.add_child(texto)

	_coluna.add_child(cartao)
	_itens.append(cartao)
	_rotulos.append(texto)


func _texto_do_item(linha: Linha) -> String:
	match linha:
		Linha.SORTEAR:
			return "SORTEAR SEED"
		Linha.COMECAR:
			return "COMEÇAR"
		_:
			return "VOLTAR"


# ------------------------------------------------------------------- fluxo

## Abre a tela para gravar no `slot`. `ocupado` liga o aviso de sobrescrita.
func abrir(slot: int, ocupado: bool) -> void:
	_slot = slot
	_indice = Linha.CAMPO
	_editando = false
	_ativo = true
	visible = true
	if _campo.text == "":
		_campo.text = str(Semente.aleatoria())
	if ocupado:
		_aviso.text = "O slot %d já tem partida; ela será sobrescrita ao salvar." % slot
	else:
		_aviso.text = ""
	_aviso.visible = ocupado
	_atualizar_leitura()
	_pintar()


func fechar() -> void:
	_ativo = false
	_editando = false
	visible = false
	_campo.release_focus()


func ativo() -> bool:
	return _ativo


func semente() -> int:
	return Semente.de_texto(_campo.text)


## Texto digitado, guardado no save SO quando nao e um numero: para "123456789"
## o proprio numero ja e o rotulo, e repeti-lo em dois campos convidaria os dois
## a divergirem.
func texto_da_seed() -> String:
	var t := _campo.text.strip_edges()
	return "" if t.is_valid_int() else t


func _atualizar_leitura() -> void:
	var t := _campo.text.strip_edges()
	if t == "":
		_resolvida.text = "Sem seed não há mundo. Digite algo ou sorteie."
		_resolvida.add_theme_color_override("font_color", TemaEncontro.VERMELHO)
		return
	var s := Semente.de_texto(t)
	_resolvida.add_theme_color_override("font_color", TemaEncontro.PERG_C)
	if t.is_valid_int():
		_resolvida.text = "Mundo %d — a mesma seed gera sempre o mesmo bestiário." % s
	else:
		_resolvida.text = "\"%s\" → %d" % [t, s]


# ---------------------------------------------------------------- navegacao

func _selecionar(linha: int) -> void:
	if not _ativo or _editando or linha == _indice:
		return
	Som.tocar("ui_mover")
	_indice = linha
	_pintar()


func _pintar() -> void:
	for i in _itens.size():
		var selecionado: bool = i == _indice
		var nome := "cartao"
		if selecionado:
			nome = "cartao_ativo" if _editando and i == Linha.CAMPO \
					else "cartao_selecionado"
		_itens[i].add_theme_stylebox_override("panel", TemaEncontro.moldura(nome))
		if _rotulos[i] == null:
			continue
		var caixa := _itens[i].get_child(0) as HBoxContainer
		(caixa.get_node("Seta") as Label).modulate.a = 1.0 if selecionado else 0.0
		_rotulos[i].add_theme_color_override("font_color",
				TemaEncontro.PERG_C if selecionado else TemaEncontro.PERG_E)


func _ao_clicar(evento: InputEvent, linha: int) -> void:
	if not _ativo:
		return
	if evento is InputEventMouseButton and evento.pressed \
			and (evento as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		_indice = linha
		_pintar()
		_confirmar()


func tratar_entrada(evento: InputEvent) -> bool:
	if not _ativo:
		return false
	# Durante a edicao o campo e dono da entrada. ESC sai da edicao; TUDO MAIS e
	# engolido, porque uma seta para baixo que mudasse de linha com o campo
	# focado deixaria o cursor piscando numa linha que nao e mais a selecionada.
	if _editando:
		if evento.is_action_pressed("ui_cancel"):
			_sair_da_edicao()
			return true
		return true
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
	return false


func _confirmar() -> void:
	Som.tocar("ui_confirmar")
	match _indice:
		Linha.CAMPO:
			_entrar_na_edicao()
		Linha.SORTEAR:
			_campo.text = str(Semente.aleatoria())
			_atualizar_leitura()
		Linha.COMECAR:
			var s := semente()
			if s == 0:
				# Seed 0 e o sentinela de "sem partida" em DadosPartida._validar.
				# Barrar aqui e mais honesto que aceitar e falhar ao salvar.
				_atualizar_leitura()
				return
			comecar.emit(s, texto_da_seed())
		Linha.VOLTAR:
			cancelado.emit()


func _entrar_na_edicao() -> void:
	_editando = true
	_campo.grab_focus()
	_campo.caret_column = _campo.text.length()
	_pintar()


func _sair_da_edicao() -> void:
	_editando = false
	_campo.release_focus()
	_atualizar_leitura()
	_pintar()
