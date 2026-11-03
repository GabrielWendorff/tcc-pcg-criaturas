class_name RodaItens
extends CanvasLayer

## Roda radial de EQUIPAMENTO: segurar [Q], apontar, soltar.
##
## Prima da RodaCaptura (presentation/encontro/roda_captura.gd) na linguagem —
## madeira, pergaminho, ouro na selecao, fonte pixel, trilho pontilhado, um
## marcador dourado ligando o miolo ao escolhido — e diferente no gesto. A de captura e um MENU: abre,
## o jogador navega com calma e confirma. Esta e um ATALHO no meio da
## exploracao: abre enquanto a tecla esta segura e fecha ao soltar, entao tudo
## nela tem de ser lido de relance. Por isso os slots sao medalhoes so com o
## icone, e a unica palavra grande e o nome do item no miolo.
##
## DESENHADA POR _draw, NAO POR CONTAINERS. A de captura monta cartoes com
## PanelContainer porque cada cartao tem quatro linhas de informacao. Aqui cada
## slot e um circulo e um icone; dez Containers por abertura para isso seriam
## layout pagando por nada — e um Control invisivel nao passa pelo layout, o
## que obrigava a roda de captura a esperar um quadro antes de posicionar.
##
## SELECAO POR ANGULO. O slot destacado e o do SETOR para onde o mouse aponta
## a partir do centro (GeometriaRoda), nao o que esta sob o cursor: numa roda o
## gesto e apontar uma direcao, e exigir acerto dentro do icone tornaria o
## atalho mais lento que abrir a bolsa. Perto do centro ha uma ZONA MORTA:
## abrir e soltar sem mexer o mouse nao troca nada.
##
## PONTEIRO VIRTUAL, NAO O CURSOR. A direcao vem da soma do movimento RELATIVO
## do mouse desde a abertura, com o mouse capturado (escondido e preso)
## enquanto a roda esta aberta. A versao anterior levava o cursor ao centro com
## warp_mouse e lia a posicao absoluta — e no Wayland (inclusive via XWayland)
## a aplicacao nao pode mover o cursor: o warp vira no-op, o cursor fica onde
## estava, e o primeiro movimento ja destacava o slot na direcao de ONDE o
## cursor estava, nao do gesto. Somando o relativo, a roda sempre comeca na
## zona morta, em qualquer servidor grafico. A soma e limitada ao raio: sem
## teto, quem passou do slot teria de "desfazer" o excesso para voltar.
##
## QUEM ABRE E A CENA. A roda trata so a entrada de quando ja esta aberta. O
## pressionar de "roda_itens" e de mundo.gd, que e quem sabe se pode (conversa,
## pesca, mapa...) e quem tem a bolsa — a roda recebe a lista pronta e nao
## conhece autoload nenhum. Bloquear o movimento enquanto ela esta aberta
## tambem e da cena (Jogador.congelar), pelo mesmo motivo.

## Escolha confirmada. null = "Maos livres".
signal item_escolhido(item: ItemJogo)
## A roda fechou, por qualquer caminho. `trocou` = o item na mao mudou.
signal fechada(trocou: bool)

const CAMADA := 88

## Raio do anel de slots, do centro da roda ao centro de cada medalhao.
@export var raio: float = 110.0
## Raio de cada medalhao.
@export var raio_slot: float = 28.0
## Distancia do centro abaixo da qual nada e destacado.
@export var zona_morta: float = 36.0
## Opacidade do escurecimento do mundo atras da roda. Menor que o da roda de
## captura: aqui o jogo continua ali atras, e a roda e um atalho, nao uma tela.
@export var escurecimento: float = 0.55
## Abertura (os medalhoes saem do centro). Curta: e um atalho segurado, e uma
## animacao longa atrasaria o gesto de quem ja sabe onde o item esta.
@export var duracao_abertura: float = 0.12
## Deflexao minima do analogico do controle para apontar.
@export var limiar_analogico: float = 0.5
## Captura o mouse (MOUSE_MODE_CAPTURED) enquanto a roda esta aberta e devolve
## o modo anterior ao fechar. Desligavel para a cena de teste.
@export var capturar_mouse: bool = true

const TEXTO_TITULO := "EQUIPAR"
const TEXTO_MAOS_LIVRES := "Mãos livres"
const TEXTO_CONTROLES := "solte [Q] para equipar · [ESC] cancela"
const TEXTO_EQUIPADO := "EQUIPADO"
const TEXTO_SOLTE := "solte para equipar"
const TEXTO_NA_MAO := "na mão agora"

## Lado do ponto e passo do trilho, em pixels — os mesmos da roda de captura,
## para as duas rodas parecerem da mesma familia.
const PONTO := 3.0
const PASSO_TRILHO := 15.0

## Mao aberta do slot "Maos livres", em celulas (X = cheio). Desenhada por
## codigo porque nao e item: nao tem id na folha de icones, e inventar um id
## falso so para ela poria na folha um "item" que a bolsa nao conhece.
const MAO_ABERTA := [
	"..X.X.X..",
	"..X.X.X.X",
	"..X.X.X.X",
	"X.X.X.X.X",
	"XXXXXXXXX",
	".XXXXXXXX",
	".XXXXXXXX",
	"..XXXXXX.",
	"..XXXXXX.",
	"...XXXX..",
]

## Tons sobre o pergaminho (os de estado somem no bege — ver
## TemaEncontro.cor_da_chance_sobre_claro).
const VERDE_SOBRE_CLARO := Color("2e6a2e")
const OCRE_SOBRE_CLARO := Color("8a5a12")

var _itens: Array = []          # [null ("Maos livres"), ItemJogo, ...]
var _equipado_id: String = ""
var _indice: int = -1
var _aberta: bool = false
var _abertura: float = 1.0      # 0..1, anima a saida dos medalhoes
var _tween: Tween = null
var _tela: Control
## Ponteiro virtual, relativo ao centro (ver cabecalho). ZERO = zona morta.
var _ponteiro: Vector2 = Vector2.ZERO
var _modo_mouse_antes: Input.MouseMode = Input.MOUSE_MODE_VISIBLE
var _capturou: bool = false


func _ready() -> void:
	layer = CAMADA
	visible = false
	set_process(false)
	_tela = Control.new()
	_tela.name = "Desenho"
	# IGNORE: a entrada e lida em _input, antes da GUI; o Control so desenha.
	_tela.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tela.draw.connect(_desenhar)
	add_child(_tela)
	_ajustar_area()
	get_viewport().size_changed.connect(_ajustar_area)


## Abre a roda com `itens` (ItemJogo; outros valores sao ignorados) mais o slot
## "Maos livres" no TOPO. `equipado_id` marca o medalhao do item na mao ("" =
## maos livres). Comeca SEM destaque, com o ponteiro virtual no centro.
func abrir(itens: Array, equipado_id: String) -> void:
	_itens = [null]
	for i: Variant in itens:
		if i is ItemJogo:
			_itens.append(i)
	_equipado_id = equipado_id
	_indice = -1
	_ponteiro = Vector2.ZERO
	_aberta = true
	visible = true
	set_process(true)
	_ajustar_area()
	if capturar_mouse and not _capturou:
		_modo_mouse_antes = Input.mouse_mode
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		_capturou = true
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_abertura = 0.0 if duracao_abertura > 0.0 else 1.0
	if duracao_abertura > 0.0 and is_inside_tree():
		_tween = create_tween()
		_tween.tween_method(_definir_abertura, 0.0, 1.0, duracao_abertura) \
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	else:
		_abertura = 1.0
	_redesenhar()


## Fecha. Com `confirmar` e um slot destacado, emite item_escolhido (inclusive
## quando e o item que ja estava na mao — a cena decide o que fazer). Sempre
## emite `fechada`. A roda some ANTES dos sinais: quem os escuta e pergunta
## `aberta()` ja recebe falso.
func fechar(confirmar: bool) -> void:
	if not _aberta:
		return
	var valido: bool = confirmar and _indice >= 0 and _indice < _itens.size()
	var escolhido: ItemJogo = _itens[_indice] if valido else null
	var trocou: bool = valido and _id_do_slot(_indice) != _equipado_id
	_aberta = false
	visible = false
	set_process(false)
	_devolver_mouse()
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = null
	if valido:
		item_escolhido.emit(escolhido)
	fechada.emit(trocou)


func aberta() -> bool:
	return _aberta


## Slot destacado agora; -1 = zona morta (soltar nao troca nada).
func indice_destacado() -> int:
	return _indice


## Item do slot `i` (null = "Maos livres" ou fora da roda). Para teste e HUD.
func item_do_slot(i: int) -> ItemJogo:
	if i < 0 or i >= _itens.size():
		return null
	return _itens[i]


## Quantos slots, contando o "Maos livres".
func total_de_slots() -> int:
	return _itens.size()


## Aponta a roda: `vetor` e o ponteiro (ou o analogico) a partir do centro, em
## pixels. Publico para a cena de teste dirigir a roda sem mouse. Vira o novo
## ponteiro virtual: o mouse continua dali, e nao de onde parou antes.
func apontar(vetor: Vector2) -> void:
	if not _aberta:
		return
	_ponteiro = vetor.limit_length(raio)
	var novo: int = GeometriaRoda.indice_por_vetor(_ponteiro, _itens.size(), zona_morta)
	if novo != _indice:
		_indice = novo
		_redesenhar()


## Centro da roda em coordenadas do viewport: o centro da tela, que e onde a
## camera mantem o jogador fora das bordas do mapa.
func centro() -> Vector2:
	if not is_inside_tree():
		return Vector2.ZERO
	return (get_viewport().get_visible_rect().size * 0.5).floor()


# --- entrada ----------------------------------------------------------------

## Enquanto aberta a roda e MODAL: consome tecla, botao e clique, para que o F
## de usar, o E de falar ou o ESC da pausa nao disparem por baixo dela. O
## movimento do personagem nao passa por aqui (e lido por Input.get_vector) —
## quem o trava e a cena, congelando o jogador.
func _input(evento: InputEvent) -> void:
	if not _aberta:
		return
	if evento is InputEventMouseMotion:
		apontar(_ponteiro + (evento as InputEventMouseMotion).relative)
		get_viewport().set_input_as_handled()
		return
	if evento.is_action_released("roda_itens"):
		get_viewport().set_input_as_handled()
		fechar(true)
		return
	if evento.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		fechar(false)
		return
	if evento is InputEventMouseButton and (evento as InputEventMouseButton).pressed:
		var botao: int = (evento as InputEventMouseButton).button_index
		get_viewport().set_input_as_handled()
		# Clique esquerdo confirma o destacado (atalho para quem solta o Q
		# depois de clicar); direito cancela, como o ESC.
		if botao == MOUSE_BUTTON_LEFT and _indice >= 0:
			fechar(true)
		elif botao == MOUSE_BUTTON_RIGHT:
			fechar(false)
		return
	# Teclas de andar APONTAM, mas so ao serem pressionadas DEPOIS de abrir: a
	# tecla que ja estava segura (o jogador andava quando apertou Q) nao pode
	# sequestrar a selecao do mouse a cada quadro.
	for acao: String in ["mover_cima", "mover_baixo", "mover_esquerda", "mover_direita"]:
		if evento.is_action_pressed(acao):
			var v := Input.get_vector("mover_esquerda", "mover_direita",
					"mover_cima", "mover_baixo")
			if v != Vector2.ZERO:
				apontar(v.normalized() * raio)
			break
	if evento is InputEventKey or evento is InputEventJoypadButton:
		get_viewport().set_input_as_handled()


## Janela perdeu o foco com a roda aberta: o soltar do Q acontece fora do jogo e
## nunca chega como evento (o Godot so zera o estado da acao), e a roda ficaria
## aberta com o jogador congelado. Fecha sem trocar — o jogador nao confirmou
## nada. Sair de cena com ela aberta devolve o mouse pelo mesmo motivo.
func _notification(que: int) -> void:
	if que == NOTIFICATION_APPLICATION_FOCUS_OUT and _aberta:
		fechar(false)
	elif que == NOTIFICATION_EXIT_TREE:
		_devolver_mouse()


func _devolver_mouse() -> void:
	if _capturou:
		Input.mouse_mode = _modo_mouse_antes
		_capturou = false


## Analogico esquerdo do controle. Lido direto do eixo e nao por mover_*: no
## InputMap essas acoes so tem teclas. Abaixo do limiar nao mexe na selecao —
## soltar o analogico antes do botao mantem o ultimo apontado.
func _process(_delta: float) -> void:
	if not _aberta:
		return
	for dispositivo: int in Input.get_connected_joypads():
		var v := Vector2(Input.get_joy_axis(dispositivo, JOY_AXIS_LEFT_X),
				Input.get_joy_axis(dispositivo, JOY_AXIS_LEFT_Y))
		if v.length() >= limiar_analogico:
			apontar(v.normalized() * raio)
			return


# --- desenho ----------------------------------------------------------------

func _ajustar_area() -> void:
	if _tela == null or not is_inside_tree():
		return
	_tela.position = Vector2.ZERO
	_tela.size = get_viewport().get_visible_rect().size
	_redesenhar()


func _definir_abertura(valor: float) -> void:
	_abertura = valor
	_redesenhar()


func _redesenhar() -> void:
	if _tela != null:
		_tela.queue_redraw()


func _id_do_slot(i: int) -> String:
	var it := item_do_slot(i)
	return it.id if it != null else ""


func _nome_do_slot(i: int) -> String:
	var it := item_do_slot(i)
	return it.nome if it != null else TEXTO_MAOS_LIVRES


## Indice do slot do item na mao (0 = maos livres). -1 se o equipado nao esta
## na lista — nao deveria acontecer, mas a roda nao inventa marca.
func _indice_equipado() -> int:
	for i in _itens.size():
		if _id_do_slot(i) == _equipado_id:
			return i
	return -1


func _desenhar() -> void:
	if not _aberta:
		return
	var c := centro()
	var n: int = _itens.size()
	var a: float = clampf(_abertura, 0.0, 1.2)
	_tela.draw_rect(Rect2(Vector2.ZERO, _tela.size),
			Color(TemaEncontro.CONTORNO, escurecimento * clampf(_abertura, 0.0, 1.0)))
	_desenhar_trilho(c, raio * a)
	_desenhar_miolo(c)
	_desenhar_ponteiro(c, n)
	for i in n:
		_desenhar_slot(i, c + GeometriaRoda.posicao_do_slot(i, n, raio * a))
	_desenhar_textos(c)
	# O cursor do sistema esta escondido (capturado): este ponto e o que mostra
	# para onde o gesto aponta, inclusive dentro da zona morta.
	var mira := (c + _ponteiro).floor()
	_tela.draw_rect(Rect2(mira - Vector2(3, 3), Vector2(6, 6)), TemaEncontro.CONTORNO)
	_tela.draw_rect(Rect2(mira - Vector2(2, 2), Vector2(4, 4)), TemaEncontro.OURO_C)


## Trilho pontilhado no raio dos slots. Num circulo passo angular constante ja
## e passo constante de arco (na elipse da roda de captura nao era).
func _desenhar_trilho(c: Vector2, r: float) -> void:
	if r < 1.0:
		return
	var cor := Color(TemaEncontro.MADEIRA_C, 0.58)
	var pontos: int = maxi(8, int(TAU * r / PASSO_TRILHO))
	for k in pontos:
		var p := c + GeometriaRoda.direcao_do_angulo(TAU * float(k) / float(pontos)) * r
		_tela.draw_rect(Rect2((p - Vector2(PONTO, PONTO) * 0.5).floor(),
				Vector2(PONTO, PONTO)), cor)


## Miolo em pergaminho: o unico disco claro da tela, onde o olho procura a
## resposta ("o que vou equipar?"). Moldura de madeira com contorno, como os
## paineis 9-slice — em disco, porque a roda e redonda.
func _desenhar_miolo(c: Vector2) -> void:
	var r: float = _raio_miolo()
	_tela.draw_circle(c, r + 4.0, TemaEncontro.CONTORNO)
	_tela.draw_circle(c, r + 2.0, TemaEncontro.MADEIRA)
	_tela.draw_circle(c, r, TemaEncontro.PERG_E)
	_tela.draw_circle(c, r - 2.0, TemaEncontro.PERG)


func _raio_miolo() -> float:
	return maxf(zona_morta, raio - raio_slot - 14.0)


## Ponteiro dourado na borda do miolo, virado para o slot destacado.
##
## Faz o papel do raio pontilhado da roda de captura — amarrar o que o miolo
## mostra ao slot de onde aquilo veio —, mas cabe numa roda compacta: com os
## raios padrao o miolo quase encosta nos medalhoes, e um raio de pontos ali
## teria um ou dois pontos. A seta tambem le como o que a selecao e: uma
## DIRECAO a partir do centro.
func _desenhar_ponteiro(c: Vector2, n: int) -> void:
	if _indice < 0 or _indice >= n:
		return
	var dir := GeometriaRoda.direcao_do_angulo(GeometriaRoda.angulo_do_slot(_indice, n))
	var lado := Vector2(-dir.y, dir.x)
	var base: Vector2 = c + dir * (_raio_miolo() + 1.0)
	_tela.draw_colored_polygon(PackedVector2Array([base + dir * 10.0,
			base + lado * 7.0 - dir * 1.0, base - lado * 7.0 - dir * 1.0]),
			TemaEncontro.CONTORNO)
	_tela.draw_colored_polygon(PackedVector2Array([base + dir * 7.0,
			base + lado * 4.5, base - lado * 4.5]), TemaEncontro.OURO)


## Medalhao: contorno, aro (madeira; ouro quando destacado), fundo noturno e o
## icone. O destacado cresce 3px — a cor sozinha nao pode ser o unico canal.
func _desenhar_slot(i: int, p: Vector2) -> void:
	p = p.floor()
	var destacado: bool = i == _indice
	var r: float = raio_slot + (3.0 if destacado else 0.0)
	_tela.draw_circle(p, r + 2.0, TemaEncontro.CONTORNO)
	_tela.draw_circle(p, r, TemaEncontro.OURO if destacado else TemaEncontro.MADEIRA)
	# luz no alto a esquerda, como em toda a arte do projeto
	_tela.draw_arc(p, r - 1.0, PI, PI * 1.5, 10,
			TemaEncontro.OURO_C if destacado else TemaEncontro.MADEIRA_C, 1.0)
	_tela.draw_circle(p, r - 3.0, TemaEncontro.NOITE_C if destacado else TemaEncontro.NOITE)

	var escala: float = _escala_icone()
	if i == 0:
		_desenhar_mao_aberta(p, escala)
	else:
		var it := item_do_slot(i)
		var regiao := IconeCaptura.regiao(it.id)
		var folha := IconeCaptura.folha()
		if folha != null and regiao.has_area():
			var tam := regiao.size * escala
			_tela.draw_texture_rect_region(folha,
					Rect2((p - tam * 0.5).floor(), tam), regiao)

	if i == _indice_equipado():
		_desenhar_selo_equipado(p + Vector2(r * 0.68, r * 0.68).floor())


## Escala INTEIRA do icone que cabe no fundo do medalhao com folga. Inteira
## pelo motivo de IconeCaptura: meio pixel de escala em pixel art produz
## colunas de larguras desiguais.
func _escala_icone() -> float:
	var diametro_util: float = (raio_slot - 3.0) * 2.0 * 0.82
	return float(maxi(1, floori(diametro_util / 20.0)))


func _desenhar_mao_aberta(p: Vector2, escala: float) -> void:
	var colunas: int = String(MAO_ABERTA[0]).length()
	var linhas: int = MAO_ABERTA.size()
	var origem := (p - Vector2(colunas, linhas) * escala * 0.5).floor()
	# Duas passadas: o contorno de todas as celulas primeiro, o recheio depois —
	# senao o contorno de uma celula pintaria por cima da vizinha.
	for passada in 2:
		for y in linhas:
			var linha: String = MAO_ABERTA[y]
			for x in colunas:
				if linha[x] != "X":
					continue
				var canto := origem + Vector2(x, y) * escala
				if passada == 0:
					_tela.draw_rect(Rect2(canto - Vector2.ONE, Vector2(escala, escala)
							+ Vector2(2, 2)), TemaEncontro.CONTORNO)
				else:
					_tela.draw_rect(Rect2(canto, Vector2(escala, escala)),
							TemaEncontro.PERG_C if y < 4 else TemaEncontro.PERG)


## Losango verde no canto do medalhao do item na mao. Forma + cor: quem nao
## distingue o verde ainda ve que aquele medalhao tem um selo e os outros nao.
func _desenhar_selo_equipado(p: Vector2) -> void:
	var fora := PackedVector2Array([p + Vector2(0, -7), p + Vector2(7, 0),
			p + Vector2(0, 7), p + Vector2(-7, 0)])
	var dentro := PackedVector2Array([p + Vector2(0, -4), p + Vector2(4, 0),
			p + Vector2(0, 4), p + Vector2(-4, 0)])
	_tela.draw_colored_polygon(fora, TemaEncontro.CONTORNO)
	_tela.draw_colored_polygon(dentro, TemaEncontro.VERDE)


func _desenhar_textos(c: Vector2) -> void:
	var f := TemaEncontro.fonte()
	var ft := TemaEncontro.fonte_titulo()
	if f == null or ft == null:
		return
	# Miolo: nome em destaque e uma linha de estado abaixo.
	var nome: String
	var estado: String
	var cor_nome: Color = TemaEncontro.TINTA
	var cor_estado: Color
	if _indice < 0:
		nome = _nome_do_slot(maxi(_indice_equipado(), 0))
		estado = TEXTO_NA_MAO
		cor_nome = TemaEncontro.TINTA_C
		cor_estado = TemaEncontro.TINTA_C
	elif _indice == _indice_equipado():
		nome = _nome_do_slot(_indice)
		estado = TEXTO_EQUIPADO
		cor_estado = VERDE_SOBRE_CLARO
	else:
		nome = _nome_do_slot(_indice)
		estado = TEXTO_SOLTE
		cor_estado = OCRE_SOBRE_CLARO
	var alt: float = f.get_height(TemaEncontro.TAM_TEXTO)
	_texto_centrado(f, TemaEncontro.TAM_TEXTO, nome.to_upper(),
			Vector2(c.x, c.y - alt - 1.0), cor_nome, false)
	_texto_centrado(f, TemaEncontro.TAM_TEXTO, estado,
			Vector2(c.x, c.y + 3.0), cor_estado, false)

	# Titulo acima e controles abaixo da roda, sobre o mundo escurecido.
	var borda: float = raio + raio_slot + 8.0
	_texto_centrado(ft, TemaEncontro.TAM_TITULO, TEXTO_TITULO,
			Vector2(c.x, c.y - borda - ft.get_height(TemaEncontro.TAM_TITULO) - 6.0),
			TemaEncontro.PERG_C, true)
	_texto_centrado(f, TemaEncontro.TAM_TEXTO, TEXTO_CONTROLES,
			Vector2(c.x, c.y + borda + 8.0), TemaEncontro.PERG_E, true)


## Texto centrado em x, com o TOPO em `topo.y`. `sombra` desenha a copia escura
## deslocada 2px por tras — o rotulo_sombreado do TemaEncontro, em _draw: fonte
## de bitmap nao aceita contorno gerado pela engine.
func _texto_centrado(fonte: Font, tamanho: int, texto: String, topo: Vector2,
		cor: Color, sombra: bool) -> void:
	var largura: float = fonte.get_string_size(texto, HORIZONTAL_ALIGNMENT_LEFT, -1,
			tamanho).x
	var pos := Vector2(topo.x - largura * 0.5, topo.y + fonte.get_ascent(tamanho)).floor()
	if sombra:
		_tela.draw_string(fonte, pos + Vector2(2, 2), texto, HORIZONTAL_ALIGNMENT_LEFT,
				-1, tamanho, TemaEncontro.SOMBRA)
	_tela.draw_string(fonte, pos, texto, HORIZONTAL_ALIGNMENT_LEFT, -1, tamanho, cor)
