class_name CaixaDialogo
extends CanvasLayer

## A caixa de dialogo: retrato, placa de nome, texto e o menu de escolhas.
##
## DIRECAO VISUAL — a mesma da interface de encontro, pelos mesmos motivos
## (presentation/encontro/README.md): molduras 9-slice de madeira e pergaminho,
## fonte bitmap 5x7, nada de StyleBoxFlat com canto arredondado. O pergaminho e
## reservado a VOZ do jogo; a madeira escura, as acoes. Aqui a fala e voz: caixa
## de pergaminho, tinta escura.
##
## O TEXTO SAI LETRA A LETRA (visible_ratio). Nao e enfeite: e o que da ao
## dialogo uma cadencia propria e o que torna "avancar" uma acao com duas
## respostas uteis — com o texto correndo, confirmar COMPLETA a linha; com a
## linha inteira na tela, confirmar passa para a proxima. Sem isso, quem le
## rapido fica esperando e quem le devagar perde a fala.
##
## A caixa NAO decide nada do dialogo: nao sabe o que e um no, nao aplica efeito
## e nao escolhe destino. Ela recebe uma fala pronta e devolve sinais. Quem
## conduz e o GerenciadorDialogo, sobre a SessaoDialogo.

signal avancar_pedido()

const CAMADA := 70

## Velocidade PADRAO da maquina de escrever, em caracteres por segundo.
## Calibrada para leitura confortavel em voz alta — mais rapido que isso vira
## revelacao, nao cadencia.
##
## E so o padrao: a opcao "velocidade_texto" manda, e `0` nela significa texto
## inteiro de uma vez. Quem le rapido nao deve ter de apertar E duas vezes por
## fala, e quem le devagar nao deve correr atras do texto.
const CARACTERES_POR_SEGUNDO := 46.0

## Retrato do proprio jogador, para as falas com "quem": "jogador".
const RETRATO_JOGADOR := "res://autoral/npcs/retratos/jogador.png"

const MARGEM_LATERAL := 54.0
const MARGEM_INFERIOR := 34.0
const ALTURA_CAIXA := 124.0
const LADO_RETRATO := 96.0

var menu: MenuEscolhas

var _raiz: Control
var _caixa: PanelContainer
var _placa: PanelContainer
var _nome: Label
var _papel: Label
var _moldura_retrato: PanelContainer
var _retrato: TextureRect
var _texto: RichTextLabel
var _indicador: Label

var _tween_texto: Tween
var _tween_indicador: Tween
var _cache_retratos: Dictionary = {}


func _ready() -> void:
	layer = CAMADA
	_montar()
	visible = false


func _montar() -> void:
	_raiz = Control.new()
	_raiz.name = "Raiz"
	_raiz.set_anchors_preset(Control.PRESET_FULL_RECT)
	_raiz.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_raiz)

	# --- coluna inferior: placa de nome + caixa de fala ---
	var coluna := VBoxContainer.new()
	coluna.name = "Coluna"
	coluna.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	coluna.offset_left = MARGEM_LATERAL
	coluna.offset_right = -MARGEM_LATERAL
	coluna.offset_top = -(ALTURA_CAIXA + 24.0 + MARGEM_INFERIOR)
	coluna.offset_bottom = -MARGEM_INFERIOR
	coluna.add_theme_constant_override("separation", 2)
	coluna.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_raiz.add_child(coluna)

	# A placa fica num HBox com um espacador a direita para nao esticar: uma
	# placa da largura da tela deixa de ser placa e vira barra de titulo.
	var linha_placa := HBoxContainer.new()
	linha_placa.mouse_filter = Control.MOUSE_FILTER_IGNORE
	coluna.add_child(linha_placa)

	_placa = PanelContainer.new()
	_placa.name = "Placa"
	_placa.add_theme_stylebox_override("panel", TemaEncontro.moldura("cartao"))
	_placa.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var dentro_da_placa := HBoxContainer.new()
	dentro_da_placa.add_theme_constant_override("separation", 6)
	dentro_da_placa.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_nome = TemaEncontro.rotulo("", TemaEncontro.OURO_C)
	_papel = TemaEncontro.rotulo("", TemaEncontro.TEXTO_APOIO)
	dentro_da_placa.add_child(_nome)
	dentro_da_placa.add_child(_papel)
	_placa.add_child(dentro_da_placa)
	linha_placa.add_child(_placa)
	var espacador := Control.new()
	espacador.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	espacador.mouse_filter = Control.MOUSE_FILTER_IGNORE
	linha_placa.add_child(espacador)

	_caixa = PanelContainer.new()
	_caixa.name = "Caixa"
	_caixa.add_theme_stylebox_override("panel", TemaEncontro.moldura("pergaminho"))
	_caixa.custom_minimum_size = Vector2(0, ALTURA_CAIXA)
	_caixa.mouse_filter = Control.MOUSE_FILTER_STOP
	_caixa.gui_input.connect(_ao_clicar_na_caixa)
	coluna.add_child(_caixa)

	var conteudo := HBoxContainer.new()
	conteudo.add_theme_constant_override("separation", 12)
	conteudo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_caixa.add_child(conteudo)

	_moldura_retrato = PanelContainer.new()
	_moldura_retrato.name = "MolduraRetrato"
	_moldura_retrato.add_theme_stylebox_override("panel",
			TemaEncontro.moldura("painel_ouro"))
	_moldura_retrato.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_moldura_retrato.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_retrato = TextureRect.new()
	_retrato.name = "Retrato"
	_retrato.custom_minimum_size = Vector2(LADO_RETRATO, LADO_RETRATO)
	_retrato.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_retrato.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_retrato.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_retrato.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_moldura_retrato.add_child(_retrato)
	conteudo.add_child(_moldura_retrato)

	var col_texto := VBoxContainer.new()
	col_texto.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col_texto.mouse_filter = Control.MOUSE_FILTER_IGNORE
	conteudo.add_child(col_texto)

	# Centralizado na vertical: a maioria das falas tem uma ou duas linhas, e
	# texto colado no topo de uma caixa de 124px deixa um vazio embaixo que le
	# como erro de layout. fit_content faz o rotulo medir o proprio texto, e o
	# alinhamento do container cuida do resto.
	col_texto.alignment = BoxContainer.ALIGNMENT_CENTER
	_texto = TemaEncontro.texto_rico()
	_texto.add_theme_color_override("default_color", TemaEncontro.TINTA)
	_texto.fit_content = true
	_texto.scroll_active = false
	col_texto.add_child(_texto)

	# O indicador de "continua" fica FORA do fluxo, ancorado na quina da caixa:
	# dentro da coluna ele acompanharia o texto centralizado e ficaria boiando no
	# meio do pergaminho.
	var quina := Control.new()
	quina.name = "Quina"
	quina.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_caixa.add_child(quina)
	_indicador = TemaEncontro.rotulo("▶", TemaEncontro.TINTA_C)
	_indicador.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_indicador.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_indicador.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_indicador.offset_left = -26.0
	_indicador.offset_top = -22.0
	_indicador.offset_right = -10.0
	_indicador.offset_bottom = -6.0
	_indicador.modulate.a = 0.0
	quina.add_child(_indicador)

	# --- menu de escolhas, acima da caixa e alinhado a direita ---
	menu = MenuEscolhas.new()
	menu.name = "Escolhas"
	menu.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	menu.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	menu.grow_vertical = Control.GROW_DIRECTION_BEGIN
	menu.offset_left = -(MenuEscolhas.LARGURA + MARGEM_LATERAL)
	menu.offset_right = -MARGEM_LATERAL
	menu.offset_bottom = -(MARGEM_INFERIOR + ALTURA_CAIXA + 40.0)
	_raiz.add_child(menu)


# --------------------------------------------------------------- apresentacao
func abrir() -> void:
	visible = true
	_raiz.modulate.a = 0.0
	create_tween().tween_property(_raiz, "modulate:a", 1.0, 0.12)


func fechar() -> void:
	_parar_tweens()
	menu.fechar()
	visible = false


## Mostra uma fala. `retrato` vazio esconde a moldura — um NPC sem arte de busto
## continua funcionando, com a caixa inteira dedicada ao texto.
func mostrar_fala(texto: String, nome: String, papel: String,
		caminho_retrato: String) -> void:
	_nome.text = nome
	_papel.text = ("· " + papel) if papel != "" else ""
	_placa.visible = nome != ""

	var textura := _carregar_retrato(caminho_retrato)
	_retrato.texture = textura
	_moldura_retrato.visible = textura != null

	_parar_tweens()
	_texto.text = texto
	_texto.visible_ratio = 0.0
	_indicador.modulate.a = 0.0
	var por_segundo := float(Opcoes.dado("velocidade_texto", CARACTERES_POR_SEGUNDO))
	if por_segundo <= 0.0:
		_texto.visible_ratio = 1.0
		_piscar_indicador()
		return
	var duracao := float(texto.length()) / por_segundo
	_tween_texto = create_tween()
	_tween_texto.tween_property(_texto, "visible_ratio", 1.0, duracao)
	_tween_texto.tween_callback(_piscar_indicador)


func texto_completo() -> bool:
	return _texto.visible_ratio >= 1.0


## Joga a linha inteira na tela. E a primeira resposta de "avancar".
func completar_texto() -> void:
	if _tween_texto != null and _tween_texto.is_valid():
		_tween_texto.kill()
	_texto.visible_ratio = 1.0
	_piscar_indicador()


func _piscar_indicador() -> void:
	if _tween_indicador != null and _tween_indicador.is_valid():
		_tween_indicador.kill()
	_indicador.modulate.a = 1.0
	_tween_indicador = create_tween().set_loops()
	_tween_indicador.tween_property(_indicador, "modulate:a", 0.25, 0.5)
	_tween_indicador.tween_property(_indicador, "modulate:a", 1.0, 0.5)


func _parar_tweens() -> void:
	for t: Tween in [_tween_texto, _tween_indicador]:
		if t != null and t.is_valid():
			t.kill()


func _carregar_retrato(caminho: String) -> Texture2D:
	if caminho == "":
		return null
	if not _cache_retratos.has(caminho):
		# load() e nao preload(): os *.import estao no .gitignore, e um preload de
		# PNG ainda nao importado e erro de PARSE — o script inteiro deixaria de
		# carregar (mesma politica de MundoIso).
		_cache_retratos[caminho] = load(caminho) if ResourceLoader.exists(caminho) \
				else null
	return _cache_retratos[caminho]


func _ao_clicar_na_caixa(evento: InputEvent) -> void:
	if evento is InputEventMouseButton and evento.pressed \
			and (evento as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT \
			and not menu.ativo():
		avancar_pedido.emit()
