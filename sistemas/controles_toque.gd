extends CanvasLayer

## Autoload `ControlesToque` — joystick e botoes na tela, para jogar no celular.
##
## UM CONTROLE VIRTUAL, NAO UM ATALHO POR TELA. Cada toque vira um
## InputEventJoypadButton (Input.parse_input_event), como se fosse um controle de
## verdade. O InputMap ja diz o que cada botao do controle faz (project.godot), e
## todas as telas do jogo ja leem acoes: menus, dialogo, batalha, pesca e roda de
## itens passam a responder ao toque sem nenhuma linha nova nelas.
##
## Por que botao de controle, e nao InputEventAction: as telas testam duas acoes
## para a mesma coisa ("ui_accept" ou "interagir", "ui_down" ou "mover_baixo"). Um
## InputEventAction casa com uma so; o botao A casa com as duas NO MESMO evento, e a
## tela trata uma vez, igual a um controle de verdade. O joystick aperta o
## direcional (botoes 11 a 14), que tanto anda (mover_*) quanto navega (ui_*).
##
## QUANDO APARECE: com tela de toque (DisplayServer.is_touchscreen_available) ou no
## primeiro toque. Some quando uma tecla do teclado fisico e apertada, e volta no
## toque seguinte: quem tem teclado nao fica com botoes por cima do jogo.
##
## MULTITOQUE: cada dedo (indice do InputEventScreenTouch) e dono de um controle;
## andar com o joystick e apertar A ao mesmo tempo funciona. O toque emulado como
## mouse, que o Godot gera junto, e engolido por um Control STOP em cima de cada
## botao — o clique esquerdo tambem e `usar_item`, e tocar em "OK" nao pode
## arremessar a vara por baixo.

signal visibilidade_mudou(visivel: bool)

## Dispositivo dos eventos emitidos. O InputMap usa device -1 (qualquer um).
const DISPOSITIVO := 0
const CAMADA := 110

## Ate onde o polegar empurra o pino, e a partir de que fracao uma direcao conta.
const RAIO_BASE := 74.0
const RAIO_PINO := 32.0
const RAIO_TOQUE_JOYSTICK := 130.0
const LIMIAR_DIRECAO := 0.38
const MARGEM := 28.0

const DIRECIONAL := {
	"cima": JOY_BUTTON_DPAD_UP,
	"baixo": JOY_BUTTON_DPAD_DOWN,
	"esquerda": JOY_BUTTON_DPAD_LEFT,
	"direita": JOY_BUTTON_DPAD_RIGHT,
}

## Botoes redondos no canto direito de baixo. `centro` e relativo ao canto.
const BOTOES_ACAO := [
	{"id": "a", "rotulo": "OK", "botao": JOY_BUTTON_A, "centro": Vector2(-70, -96), "raio": 42.0},
	{"id": "b", "rotulo": "VOLTAR", "botao": JOY_BUTTON_B, "centro": Vector2(-166, -58), "raio": 34.0},
	{"id": "x", "rotulo": "USAR", "botao": JOY_BUTTON_X, "centro": Vector2(-166, -150), "raio": 34.0},
	{"id": "lb", "rotulo": "ITENS", "botao": JOY_BUTTON_LEFT_SHOULDER,
			"centro": Vector2(-70, -200), "raio": 30.0},
]

## Pilulas empilhadas na lateral direita, de cima para baixo: abaixo do cartao de
## OBJETIVO (canto de cima a direita) e acima do botao ITENS. O canto de cima a
## esquerda fica livre para as notas passageiras do HUD.
const BOTOES_MENU := [
	{"id": "menu", "rotulo": "MENU", "botao": JOY_BUTTON_BACK},
	{"id": "bolsa", "rotulo": "BOLSA", "botao": JOY_BUTTON_Y},
	{"id": "mapa", "rotulo": "MAPA", "botao": JOY_BUTTON_START},
	{"id": "bestiario", "rotulo": "BESTIÁRIO", "botao": JOY_BUTTON_RIGHT_SHOULDER},
	{"id": "pular", "rotulo": "PULAR", "botao": JOY_BUTTON_RIGHT_STICK},
]
const ALTURA_PILULA := 30.0
const FOLGA_PILULA := 8.0
const TOPO_PILULAS := 168.0

var visivel_agora: bool = false

## Geometria de cada botao: id -> {"botao", "rotulo", "forma": Rect2 ou circulo}.
var _botoes: Array = []
var _centro_joystick: Vector2 = Vector2.ZERO
## Indice do dedo -> id do botao (ou "joystick").
var _dedos: Dictionary = {}
## Botoes atualmente apertados (id -> true), para desenhar e soltar tudo.
var _apertados: Dictionary = {}
var _pino: Vector2 = Vector2.ZERO
var _direcoes: Dictionary = {}

var _tela: Control
var _bloqueios: Control


func _ready() -> void:
	layer = CAMADA
	# Responde com o jogo pausado: e da pausa que se sai apertando VOLTAR.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_bloqueios = Control.new()
	_bloqueios.name = "Bloqueios"
	_bloqueios.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bloqueios.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_bloqueios)
	_tela = Control.new()
	_tela.name = "Desenho"
	_tela.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tela.set_anchors_preset(Control.PRESET_FULL_RECT)
	_tela.draw.connect(_desenhar)
	add_child(_tela)
	get_viewport().size_changed.connect(_montar)
	_montar()
	_definir_visivel(DisplayServer.get_name() != "headless"
			and DisplayServer.is_touchscreen_available())


## Liga ou desliga os controles. Desligar solta tudo que estava apertado.
func mostrar(sim: bool) -> void:
	_definir_visivel(sim)


## O ponto (coordenadas da tela do jogo) esta sobre o joystick ou um botao visivel?
## Quem le a posicao do mouse usa isto: no celular o dedo do joystick tambem move o
## mouse emulado, e ele nao pode virar mira por baixo dos controles.
func ocupa(p: Vector2) -> bool:
	if not visivel_agora:
		return false
	return p.distance_to(_centro_joystick) <= RAIO_TOQUE_JOYSTICK or not _botao_em(p).is_empty()


func _input(evento: InputEvent) -> void:
	if evento is InputEventScreenTouch:
		var toque := evento as InputEventScreenTouch
		if toque.pressed and not visivel_agora:
			_definir_visivel(true)
		if toque.pressed:
			_apertar_dedo(toque.index, toque.position)
		else:
			_soltar_dedo(toque.index)
	elif evento is InputEventScreenDrag:
		var arrasto := evento as InputEventScreenDrag
		if _dedos.get(arrasto.index, "") == "joystick":
			_mover_joystick(arrasto.position)
	elif evento is InputEventKey and visivel_agora and (evento as InputEventKey).pressed:
		_definir_visivel(false)


func _notification(que: int) -> void:
	if que == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_soltar_tudo()


# ------------------------------------------------------------------- toques

func _apertar_dedo(indice: int, p: Vector2) -> void:
	if not visivel_agora:
		return
	if p.distance_to(_centro_joystick) <= RAIO_TOQUE_JOYSTICK:
		_dedos[indice] = "joystick"
		_mover_joystick(p)
		return
	var b: Dictionary = _botao_em(p)
	if b.is_empty():
		return
	_dedos[indice] = b["id"]
	if not _apertados.has(b["id"]):
		_apertados[b["id"]] = true
		_emitir(int(b["botao"]), true)
	_tela.queue_redraw()


func _soltar_dedo(indice: int) -> void:
	if not _dedos.has(indice):
		return
	var id: String = _dedos[indice]
	_dedos.erase(indice)
	if id == "joystick":
		_mover_joystick(_centro_joystick)
		return
	# Outro dedo ainda segurando o mesmo botao: continua apertado.
	if id in _dedos.values():
		return
	if _apertados.has(id):
		_apertados.erase(id)
		_emitir(_botao_do_id(id), false)
	_tela.queue_redraw()


## O pino segue o dedo, preso a base; cada direcao aperta ou solta o seu botao do
## direcional quando a fracao passa do limiar (diagonal = dois botoes).
func _mover_joystick(p: Vector2) -> void:
	var v: Vector2 = (p - _centro_joystick) / RAIO_BASE
	if v.length() > 1.0:
		v = v.normalized()
	_pino = v
	_definir_direcao("direita", v.x > LIMIAR_DIRECAO)
	_definir_direcao("esquerda", v.x < -LIMIAR_DIRECAO)
	_definir_direcao("baixo", v.y > LIMIAR_DIRECAO)
	_definir_direcao("cima", v.y < -LIMIAR_DIRECAO)
	_tela.queue_redraw()


func _definir_direcao(direcao: String, apertada: bool) -> void:
	if bool(_direcoes.get(direcao, false)) == apertada:
		return
	_direcoes[direcao] = apertada
	_emitir(int(DIRECIONAL[direcao]), apertada)


func _soltar_tudo() -> void:
	_dedos.clear()
	for id: String in _apertados.keys():
		_emitir(_botao_do_id(id), false)
	_apertados.clear()
	_mover_joystick(_centro_joystick)


func _emitir(botao: int, apertado: bool) -> void:
	var e := InputEventJoypadButton.new()
	e.device = DISPOSITIVO
	e.button_index = botao as JoyButton
	e.pressed = apertado
	e.pressure = 1.0 if apertado else 0.0
	Input.parse_input_event(e)


# ------------------------------------------------------------------ geometria

func _definir_visivel(sim: bool) -> void:
	if not sim:
		_soltar_tudo()
	var mudou: bool = sim != visivel_agora
	visivel_agora = sim
	visible = sim
	if mudou:
		visibilidade_mudou.emit(sim)


## Recalcula as posicoes (a tela do celular gira e muda de tamanho) e recria os
## bloqueios de mouse por cima de cada botao.
func _montar() -> void:
	var tam: Vector2 = get_viewport().get_visible_rect().size
	_centro_joystick = Vector2(MARGEM + RAIO_BASE + 18.0, tam.y - MARGEM - RAIO_BASE - 18.0)
	_botoes.clear()
	var canto := Vector2(tam.x - MARGEM, tam.y - MARGEM)
	for d: Dictionary in BOTOES_ACAO:
		_botoes.append({"id": d["id"], "rotulo": d["rotulo"], "botao": d["botao"],
				"centro": canto + Vector2(d["centro"]), "raio": float(d["raio"])})
	var largura: float = 0.0
	for d: Dictionary in BOTOES_MENU:
		largura = maxf(largura, _largura(String(d["rotulo"])) + 24.0)
	var y: float = TOPO_PILULAS
	for d: Dictionary in BOTOES_MENU:
		_botoes.append({"id": d["id"], "rotulo": d["rotulo"], "botao": d["botao"],
				"retangulo": Rect2(tam.x - MARGEM - largura, y, largura, ALTURA_PILULA)})
		y += ALTURA_PILULA + FOLGA_PILULA
	for filho: Node in _bloqueios.get_children():
		filho.queue_free()
	_bloquear(Rect2(_centro_joystick - Vector2.ONE * RAIO_TOQUE_JOYSTICK,
			Vector2.ONE * RAIO_TOQUE_JOYSTICK * 2.0))
	for b: Dictionary in _botoes:
		_bloquear(_caixa(b))
	_tela.queue_redraw()


func _bloquear(r: Rect2) -> void:
	var c := Control.new()
	c.mouse_filter = Control.MOUSE_FILTER_STOP
	c.position = r.position
	c.size = r.size
	_bloqueios.add_child(c)


func _caixa(b: Dictionary) -> Rect2:
	if b.has("retangulo"):
		return b["retangulo"]
	var r: float = b["raio"]
	return Rect2(Vector2(b["centro"]) - Vector2(r, r), Vector2(r, r) * 2.0)


## Botao sob o ponto. Os redondos tem uma folga de 20% para o polegar.
func _botao_em(p: Vector2) -> Dictionary:
	for b: Dictionary in _botoes:
		if b.has("retangulo"):
			if Rect2(b["retangulo"]).grow(6.0).has_point(p):
				return b
		elif p.distance_to(b["centro"]) <= float(b["raio"]) * 1.2:
			return b
	return {}


func _botao_do_id(id: String) -> int:
	for b: Dictionary in _botoes:
		if b["id"] == id:
			return int(b["botao"])
	return -1


# -------------------------------------------------------------------- desenho

func _desenhar() -> void:
	var fonte := TemaEncontro.fonte()
	# Joystick: base translucida e pino.
	_tela.draw_circle(_centro_joystick, RAIO_BASE, Color(TemaEncontro.NOITE_E, 0.35))
	_tela.draw_arc(_centro_joystick, RAIO_BASE, 0.0, TAU, 48, Color(TemaEncontro.PERG_C, 0.45), 2.0)
	var pino: Vector2 = _centro_joystick + _pino * (RAIO_BASE - RAIO_PINO * 0.5)
	var ativo: bool = "joystick" in _dedos.values()
	_tela.draw_circle(pino, RAIO_PINO, Color(TemaEncontro.PERG_C, 0.75 if ativo else 0.5))
	_tela.draw_arc(pino, RAIO_PINO, 0.0, TAU, 32, Color(TemaEncontro.CONTORNO, 0.7), 2.0)
	for b: Dictionary in _botoes:
		var apertado: bool = _apertados.has(b["id"])
		var fundo := Color(TemaEncontro.OURO, 0.8) if apertado else Color(TemaEncontro.NOITE, 0.7)
		var cor_texto: Color = TemaEncontro.CONTORNO if apertado else TemaEncontro.PERG_C
		var rotulo: String = b["rotulo"]
		var largura_texto: float = _largura(rotulo)
		var centro: Vector2
		if b.has("retangulo"):
			var r: Rect2 = b["retangulo"]
			_tela.draw_rect(r, fundo)
			_tela.draw_rect(r, Color(TemaEncontro.PERG_C, 0.5), false, 2.0)
			centro = r.get_center()
		else:
			centro = b["centro"]
			_tela.draw_circle(centro, b["raio"], fundo)
			_tela.draw_arc(centro, b["raio"], 0.0, TAU, 40, Color(TemaEncontro.PERG_C, 0.55), 2.0)
		var base_texto := Vector2(roundf(centro.x - largura_texto * 0.5),
				roundf(centro.y + fonte.get_ascent(TemaEncontro.TAM_TEXTO) * 0.5 - 1.0))
		_tela.draw_string(fonte, base_texto, rotulo, HORIZONTAL_ALIGNMENT_LEFT, -1,
				TemaEncontro.TAM_TEXTO, cor_texto)


func _largura(texto: String) -> float:
	return TemaEncontro.fonte().get_string_size(texto, HORIZONTAL_ALIGNMENT_LEFT, -1,
			TemaEncontro.TAM_TEXTO).x
