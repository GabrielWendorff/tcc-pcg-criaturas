class_name TelaDesfecho
extends CanvasLayer

## Tela de vitoria ou derrota. So mostra o que recebe e devolve a opcao escolhida:
## quem calcula os dados da seed e quem recarrega o save e a cena do mundo.

signal opcao_escolhida(id: String)

const CAMADA := 94
const LARGURA := 520.0

var _raiz: Control
var _titulo: Label
var _corpo: RichTextLabel
var _menu: MenuEscolhas
var _opcoes: Array = []
var _aberta: bool = false


func _ready() -> void:
	layer = CAMADA
	_raiz = Control.new()
	_raiz.set_anchors_preset(Control.PRESET_FULL_RECT)
	_raiz.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_raiz)

	var veu := ColorRect.new()
	veu.color = Color(TemaEncontro.CONTORNO, 0.86)
	veu.set_anchors_preset(Control.PRESET_FULL_RECT)
	veu.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_raiz.add_child(veu)

	var centro := CenterContainer.new()
	centro.set_anchors_preset(Control.PRESET_FULL_RECT)
	centro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_raiz.add_child(centro)

	var coluna := VBoxContainer.new()
	coluna.add_theme_constant_override("separation", 14)
	coluna.custom_minimum_size = Vector2(LARGURA, 0)
	coluna.mouse_filter = Control.MOUSE_FILTER_IGNORE
	centro.add_child(coluna)

	_titulo = TemaEncontro.rotulo("", TemaEncontro.OURO, TemaEncontro.Corpo.TITULO)
	_titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	coluna.add_child(_titulo)

	var painel := PanelContainer.new()
	painel.add_theme_stylebox_override("panel", TemaEncontro.moldura("pergaminho"))
	painel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	coluna.add_child(painel)

	_corpo = TemaEncontro.texto_rico()
	_corpo.add_theme_color_override("default_color", TemaEncontro.TINTA)
	painel.add_child(_corpo)

	var linha_menu := CenterContainer.new()
	linha_menu.mouse_filter = Control.MOUSE_FILTER_IGNORE
	coluna.add_child(linha_menu)

	_menu = MenuEscolhas.new()
	_menu.ancorar_acima = false
	_menu.escolhido.connect(_ao_escolher)
	linha_menu.add_child(_menu)
	visible = false


func aberta() -> bool:
	return _aberta


## `opcoes`: [{"id", "texto"}], na ordem do menu.
func abrir(titulo: String, cor: Color, corpo: String, opcoes: Array) -> void:
	_titulo.text = titulo
	_titulo.add_theme_color_override("font_color", cor)
	_corpo.text = corpo
	_opcoes = opcoes
	var itens: Array = []
	for o: Dictionary in opcoes:
		itens.append({"texto": o["texto"]})
	_menu.abrir(itens)
	_aberta = true
	visible = true


func fechar() -> void:
	_aberta = false
	visible = false
	_menu.fechar()


func _ao_escolher(indice: int) -> void:
	if indice < 0 or indice >= _opcoes.size():
		return
	Som.tocar("ui_confirmar")
	var id := String(_opcoes[indice]["id"])
	fechar()
	opcao_escolhida.emit(id)


func _unhandled_input(evento: InputEvent) -> void:
	if _aberta and _menu.tratar_entrada(evento):
		get_viewport().set_input_as_handled()
