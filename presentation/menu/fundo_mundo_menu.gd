class_name FundoMundoMenu
extends Control

## Fundo do menu principal: a VILA DE VERDADE, montada do mesmo mapa do jogo, com a
## camera passeando devagar e algumas criaturas de uma seed sorteada andando pela
## praca.
##
## Nao ha ilustracao nova: o fundo e o proprio mundo e o proprio gerador. Quem abre
## o jogo ja ve, antes de qualquer botao, criaturas que nenhuma outra partida tera
## igual — a primeira tela mostra o ponto do trabalho.
##
## Vive numa CanvasLayer ABAIXO do menu, e quem se move e o palco, nao uma camera: uma
## Camera2D moveria o menu junto (ele esta na mesma camada padrao), e uma SubViewport
## dentro do menu aumentava o tamanho minimo dele e empurrava o titulo para fora do
## centro. A vinheta e um veu escuro mantem o texto legivel.
##
## Se o mapa nao carregar, o menu nao pode deixar de abrir: `pronto()` fica falso e o
## menu cai no fundo desenhado antigo (FundoMenu).

const QUANTAS_CRIATURAS := 6
## Raio, em celulas, em volta do spawn onde as criaturas nascem e passeiam.
const RAIO_DE_PASSEIO := 6
const VELOCIDADE := 22.0             # px de mundo por segundo
## Pequena de proposito: a praca (onde as criaturas andam) nao pode sair da tela.
const AMPLITUDE_CAMERA := Vector2(36.0, 18.0)
const PERIODO_CAMERA := 70.0         # segundos para uma volta completa
const FORCA_DO_VEU := 0.38
const TERRENOS_DE_PASSEIO := ["calcada", "caminho"]
## Onde a praca aparece na tela, em fracao: a esquerda e abaixo do titulo, onde nem a
## faixa do nome nem os botoes cobrem as criaturas.
const ONDE_FICA_A_PRACA := Vector2(0.24, 0.62)

var _palco: Node2D
var _mundo: MundoIso
var _centro: Vector2
var _tempo: float = 0.0
var _rng := RandomNumberGenerator.new()
var _criaturas: Array[Node2D] = []
var _ok: bool = false
var animado: bool = true


func _ready() -> void:
	# _and_offsets: so as ancoras deixavam o no com tamanho zero, e o veu e a vinheta,
	# ancorados nele, sumiam.
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rng.randomize()

	var camada := CanvasLayer.new()
	camada.name = "Mundo"
	camada.layer = -10
	add_child(camada)
	_palco = Node2D.new()
	_palco.name = "Palco"
	_palco.scale = Vector2(CameraExploracao.ZOOM, CameraExploracao.ZOOM)
	camada.add_child(_palco)

	_mundo = MundoIso.new()
	_mundo.name = "Vila"
	_palco.add_child(_mundo)
	_mundo.carregar()
	if _mundo.erro != "":
		push_warning("FundoMundoMenu: mapa nao carregou — " + _mundo.erro)
		camada.queue_free()
		return

	_centro = _mundo.spawn_do_jogador()
	_enquadrar(_centro)

	_soltar_criaturas()
	_montar_veu()
	animado = Opcoes.ligada("efeitos_de_tela")
	Opcoes.mudou.connect(_ao_mudar_opcao)
	_ok = true


func pronto() -> bool:
	return _ok


func _ao_mudar_opcao(id: String, valor: Variant) -> void:
	if id == "efeitos_de_tela":
		animado = bool(valor)


## Criaturas de uma seed sorteada a cada abertura: o gerador de verdade, com as
## tabelas de verdade. Nada disso vai para save nenhum.
func _soltar_criaturas() -> void:
	var tabelas := TabelasProbabilidade.carregar()
	if tabelas == null:
		return
	var catalogo := CatalogoCorpos.carregar(tabelas)
	var bestiario := GeradorCriaturas.new(tabelas, catalogo).gerar_bestiario(
			Semente.aleatoria(), QUANTAS_CRIATURAS)
	var origem := _mundo.mundo_para_celula(_centro)
	for c: Criatura in bestiario:
		var celula := _celula_livre_perto(origem)
		if celula == Vector2i(-1, -1):
			continue
		var no := Node2D.new()
		no.name = c.nome()
		no.position = _mundo.celula_para_mundo(celula)
		var render := CreatureSpriteRenderer.new()
		render.size = Vector2(32, 32)
		render.position = Vector2(-16, -30)
		render.mouse_filter = Control.MOUSE_FILTER_IGNORE
		no.add_child(render)
		render.configurar(c, catalogo)
		_mundo.entidades.add_child(no)
		_criaturas.append(no)
		_passear.call_deferred(no)


func _celula_livre_perto(origem: Vector2i) -> Vector2i:
	for tentativa in 40:
		var c := origem + Vector2i(_rng.randi_range(-RAIO_DE_PASSEIO, RAIO_DE_PASSEIO),
				_rng.randi_range(-RAIO_DE_PASSEIO, RAIO_DE_PASSEIO))
		# So o chao aberto da praca: perto das casas a criatura podia nascer atras de
		# uma delas e ser desenhada sobre o telhado.
		if not _mundo.bloqueia(c) and _mundo.terreno_em(c) in TERRENOS_DE_PASSEIO:
			return c
	return Vector2i(-1, -1)


## Anda ate uma celula livre perto do spawn, para um pouco e escolhe outra. Vira o
## corpo para o lado em que anda, e da pulinhos enquanto anda.
func _passear(no: Node2D) -> void:
	while is_instance_valid(no) and is_inside_tree():
		var alvo := _celula_livre_perto(_mundo.mundo_para_celula(_centro))
		if alvo != Vector2i(-1, -1) and animado:
			var destino := _mundo.celula_para_mundo(alvo)
			var duracao: float = no.position.distance_to(destino) / VELOCIDADE
			no.scale.x = -1.0 if destino.x < no.position.x else 1.0
			var t := create_tween()
			t.tween_property(no, "position", destino, maxf(duracao, 0.3))
			var render := no.get_child(0) as Control
			var pulos := create_tween().set_loops(maxi(1, int(duracao / 0.35)))
			pulos.tween_property(render, "position:y", -33.0, 0.17)
			pulos.tween_property(render, "position:y", -30.0, 0.18)
			await t.finished
		await get_tree().create_timer(_rng.randf_range(1.5, 4.0)).timeout


func _montar_veu() -> void:
	var veu := ColorRect.new()
	veu.name = "Veu"
	veu.color = Color(TemaEncontro.CONTORNO, FORCA_DO_VEU)
	veu.set_anchors_preset(Control.PRESET_FULL_RECT)
	veu.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(veu)
	var vinheta := TextureRect.new()
	vinheta.name = "Vinheta"
	vinheta.texture = load("res://arte/ui/vinheta.png")
	vinheta.set_anchors_preset(Control.PRESET_FULL_RECT)
	vinheta.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	vinheta.stretch_mode = TextureRect.STRETCH_SCALE
	vinheta.modulate.a = 0.3
	vinheta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(vinheta)


func _process(delta: float) -> void:
	if not _ok or not animado:
		return
	_tempo += delta
	var a: float = TAU * _tempo / PERIODO_CAMERA
	_enquadrar(_centro + Vector2(sin(a) * AMPLITUDE_CAMERA.x,
			sin(a * 2.0) * AMPLITUDE_CAMERA.y * 0.5))


## Poe o ponto `alvo` do mundo no centro da tela. Em pixels inteiros de tela: com
## meio pixel, a arte em escala 3 tremeria a cada quadro.
func _enquadrar(alvo: Vector2) -> void:
	var tela := get_viewport().get_visible_rect().size
	_palco.position = (tela * ONDE_FICA_A_PRACA - alvo * _palco.scale).round()
