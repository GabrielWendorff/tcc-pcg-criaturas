extends Node

## Controles na tela: godot --headless --path . res://tools/test_controles_toque.tscn
##
## Toca a tela com Input.parse_input_event, como o navegador do celular faz, e
## confere as ACOES que o jogo le: o joystick anda e navega, os botoes casam com as
## acoes do InputMap num evento so, dois dedos funcionam juntos e o teclado esconde.

var _falhas: int = 0
var _total: int = 0
## Eventos de botao que chegaram as telas: [interagir?, ui_accept?] por evento.
var _confirmacoes: Array = []


func _input(evento: InputEvent) -> void:
	if evento is InputEventJoypadButton and evento.pressed \
			and (evento.is_action_pressed("interagir") or evento.is_action_pressed("ui_accept")):
		_confirmacoes.append([evento.is_action_pressed("interagir"),
				evento.is_action_pressed("ui_accept")])


func _ready() -> void:
	print("== Controles na tela ==")
	var ct: Node = get_tree().root.get_node_or_null("/root/ControlesToque")
	_ok(ct != null, "o autoload esta registrado")
	if ct == null:
		_fim()
		return
	await _quadros()
	_ok(not ct.visivel_agora, "sem tela de toque (headless) comeca escondido")

	# Primeiro toque, longe de tudo: so mostra.
	await _tocar(5, Vector2(600, 300), true)
	await _tocar(5, Vector2(600, 300), false)
	_ok(ct.visivel_agora, "o primeiro toque mostra os controles")

	var centro: Vector2 = ct._centro_joystick
	var raio: float = ct.RAIO_BASE
	_ok(ct.ocupa(centro) and ct.ocupa(_botao(ct, "a")["centro"]) and not ct.ocupa(Vector2(600, 300)),
			"ocupa(): joystick e botoes sim, meio da tela nao (a pesca le o mouse fora deles)")
	await _tocar(0, centro + Vector2(raio, 0), true)
	_ok(Input.is_action_pressed("mover_direita") and Input.is_action_pressed("ui_right"),
			"joystick a direita: anda (mover_direita) e navega (ui_right)")
	_ok(not Input.is_action_pressed("mover_esquerda") and not Input.is_action_pressed("mover_cima"),
			"so a direcao empurrada")
	_ok(Input.get_vector("mover_esquerda", "mover_direita", "mover_cima", "mover_baixo").x > 0.9,
			"Input.get_vector, que move o jogador, le o joystick")
	await _arrastar(0, centro + Vector2(-raio, -raio))
	_ok(Input.is_action_pressed("mover_cima") and Input.is_action_pressed("mover_esquerda")
			and not Input.is_action_pressed("mover_direita"),
			"diagonal aperta duas direcoes e solta a anterior")

	# Segundo dedo no OK enquanto o primeiro segura o joystick.
	var ok_b: Dictionary = _botao(ct, "a")
	_confirmacoes.clear()
	await _tocar(1, ok_b["centro"], true)
	_ok(Input.is_action_pressed("interagir") and Input.is_action_pressed("ui_accept"),
			"OK aperta interagir e ui_accept")
	_ok(Input.is_action_pressed("mover_cima"), "dois dedos: o joystick continua apertado")
	_ok(_confirmacoes.size() == 1 and _confirmacoes[0] == [true, true],
			"um evento so casa com as duas acoes (a tela trata uma vez)", str(_confirmacoes))
	await _tocar(1, ok_b["centro"], false)
	_ok(not Input.is_action_pressed("interagir"), "soltar o OK solta a acao")
	await _tocar(0, centro, false)
	_ok(Input.get_vector("mover_esquerda", "mover_direita", "mover_cima", "mover_baixo")
			== Vector2.ZERO, "soltar o joystick para o jogador")

	for par: Array in [["b", "ui_cancel"], ["x", "usar_item"], ["lb", "roda_itens"],
			["menu", "pausar"], ["bolsa", "abrir_bolsa"], ["mapa", "abrir_mapa"],
			["bestiario", "abrir_bestiario"], ["pular", "pular_tutorial"]]:
		var b: Dictionary = _botao(ct, par[0])
		var ponto: Vector2 = Rect2(b["retangulo"]).get_center() if b.has("retangulo") else b["centro"]
		await _tocar(2, ponto, true)
		var apertou: bool = Input.is_action_pressed(par[1])
		await _tocar(2, ponto, false)
		_ok(apertou and not Input.is_action_pressed(par[1]),
				"%s aperta e solta %s" % [String(b["rotulo"]), par[1]])

	# Teclado fisico esconde e solta o que estiver apertado.
	await _tocar(0, centro + Vector2(0, raio), true)
	var tecla := InputEventKey.new()
	tecla.keycode = KEY_W
	tecla.pressed = true
	Input.parse_input_event(tecla)
	await _quadros()
	_ok(not ct.visivel_agora, "uma tecla esconde os controles")
	_ok(not Input.is_action_pressed("mover_baixo"), "esconder solta o joystick")
	tecla = tecla.duplicate()
	tecla.pressed = false
	Input.parse_input_event(tecla)
	await _quadros()
	_fim()


func _botao(ct: Node, id: String) -> Dictionary:
	for b: Dictionary in ct._botoes:
		if b["id"] == id:
			return b
	return {}


func _tocar(indice: int, p: Vector2, apertado: bool) -> void:
	var e := InputEventScreenTouch.new()
	e.index = indice
	e.position = _na_janela(p)
	e.pressed = apertado
	Input.parse_input_event(e)
	await _quadros()


func _arrastar(indice: int, p: Vector2) -> void:
	var e := InputEventScreenDrag.new()
	e.index = indice
	e.position = _na_janela(p)
	Input.parse_input_event(e)
	await _quadros()


## O toque chega em pixels da JANELA; os controles vivem nas coordenadas da tela
## esticada (stretch canvas_items). O navegador manda o primeiro, o jogo le o segundo.
func _na_janela(p: Vector2) -> Vector2:
	return get_viewport().get_final_transform() * p


func _quadros() -> void:
	for i in 3:
		await get_tree().process_frame


func _fim() -> void:
	print("\nRESULTADO: %s" % ("TODOS OS TESTES PASSARAM (%d)" % _total if _falhas == 0
			else "%d VERIFICACAO(OES) FALHARAM" % _falhas))
	get_tree().quit(0 if _falhas == 0 else 1)


func _ok(cond: bool, nome: String, detalhe: String = "") -> void:
	_total += 1
	if not cond:
		_falhas += 1
	print("    %s %s  %s" % ["OK  " if cond else "FALHOU", nome, detalhe])
