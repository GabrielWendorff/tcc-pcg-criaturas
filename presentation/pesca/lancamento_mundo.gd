class_name LancamentoMundo
extends Node2D

## A linha e a boia NO MUNDO isometrico: o voo do arremesso, o respingo e a
## boia parada na agua enquanto o minigame roda por cima.
##
## Vive no mundo e nao na interface porque o arremesso e um gesto do PERSONAGEM —
## a linha sai da ponta da vara que o jogador ve na mao, e o ponto onde a boia
## cai e o ponto do mapa que define o ponto de pesca (lago, ribeira, rio). Um
## arco desenhado no HUD nao diria onde a isca caiu.
##
## A ORIGEM E UM CALLABLE, e nao um ponto: a ponta da vara se mexe (o tween do
## arremesso, a pose de pesca), e a linha tem de sair dela a cada quadro. Quem
## responde e SlotDaMao.ponta_global(); este no nao conhece o jogador.
##
## z_index alto, como IndicadorInteracao e AvisoEncontro: o y-sort ordena pelo
## pe, e uma linha que passa por tras da arvore da margem some no meio do voo.
## As coordenadas sao GLOBAIS (o no fica na origem do mundo): destino e origem
## chegam em coordenadas de mundo e sao desenhados via to_local.
##
## Os tempos vem de quem chama (duracao_voo da ConfiguracaoPesca); o que resta
## aqui e visual, e por isso @export.

## A boia tocou a agua (fim do voo). Tambem e emitido quando o voo e
## interrompido por recolher(): um `await pousou` nunca fica pendurado, e quem
## espera confere o proprio token antes de seguir (ver GerenciadorPesca).
signal pousou()

## Pixels de mundo (a camera roda em zoom 3).
@export var raio_boia: float = 2.0
@export var cor_linha: Color = TemaEncontro.PERG_C
@export var cor_boia: Color = TemaEncontro.VERMELHO
@export var cor_respingo: Color = Color("cfe8f2")
## Duracao do respingo e raio maximo dos aneis.
@export var duracao_respingo: float = 0.6
@export var raio_respingo: float = 7.0
## Quanto a linha pendura no meio, por pixel de comprimento, com a boia parada.
## No voo ela vai esticada.
@export var barriga_linha: float = 0.12
## Balanco da boia parada na agua, em pixels e ciclos por segundo.
@export var balanco_boia: float = 0.8
@export var frequencia_balanco: float = 0.9

enum _Fase { PARADA, VOANDO, NA_AGUA, RECOLHENDO }

var _fase: _Fase = _Fase.PARADA
var _origem: Callable = Callable()
var _de: Vector2 = Vector2.ZERO
var _destino: Vector2 = Vector2.ZERO
var _boia: Vector2 = Vector2.ZERO
var _t: float = 0.0
var _duracao: float = 0.0
var _altura: float = 18.0
var _respingo: float = -1.0
var _relogio: float = 0.0
var _devido_pousou: bool = false

const _SEGMENTOS_LINHA := 14


func _ready() -> void:
	z_index = 200
	# Respeita um lancar() feito antes de entrar na arvore.
	visible = _fase != _Fase.PARADA
	set_process(visible)


## Lanca a boia da ponta da vara ate `destino` (mundo) numa parabola de `altura`
## pixels acima da reta, em `duracao` segundos. Emite `pousou` ao tocar a agua.
func lancar(origem: Callable, destino: Vector2, duracao: float, altura: float = 18.0) -> void:
	_concluir_voo_pendente()
	_origem = origem
	_de = _ponto_de_origem()
	_destino = destino
	_boia = _de
	_duracao = maxf(duracao, 0.01)
	_altura = altura
	_t = 0.0
	_respingo = -1.0
	_fase = _Fase.VOANDO
	_devido_pousou = true
	visible = true
	set_process(true)
	queue_redraw()


## Recolhe a boia de volta a ponta da vara e some. Interrompe um voo em curso
## (emitindo o `pousou` devido).
func recolher(duracao: float = 0.2) -> void:
	_concluir_voo_pendente()
	if _fase == _Fase.PARADA:
		return
	_de = _boia
	_duracao = maxf(duracao, 0.01)
	_t = 0.0
	_respingo = -1.0
	_fase = _Fase.RECOLHENDO
	set_process(true)


## A boia esta na agua (pousou e nao foi recolhida)?
func na_agua() -> bool:
	return _fase == _Fase.NA_AGUA


## Posicao atual da boia, em coordenadas de mundo.
func posicao_boia() -> Vector2:
	return _boia


func _process(delta: float) -> void:
	_relogio += delta
	match _fase:
		_Fase.VOANDO:
			_t += delta / _duracao
			var u: float = minf(_t, 1.0)
			# Parabola sobre a reta origem -> destino: o pico no meio do voo.
			# 4u(1-u) vale 1 em u=0.5 e 0 nas pontas.
			_boia = _de.lerp(_destino, u) + Vector2(0.0, -_altura * 4.0 * u * (1.0 - u))
			if _t >= 1.0:
				_boia = _destino
				_fase = _Fase.NA_AGUA
				_respingo = 0.0
				_devido_pousou = false
				pousou.emit()
		_Fase.RECOLHENDO:
			_t += delta / _duracao
			var alvo := _ponto_de_origem()
			_boia = _de.lerp(alvo, minf(_t, 1.0))
			if _t >= 1.0:
				_fase = _Fase.PARADA
				visible = false
				set_process(false)
				return
	if _respingo >= 0.0:
		_respingo += delta
		if _respingo > duracao_respingo:
			_respingo = -1.0
	queue_redraw()


func _draw() -> void:
	if _fase == _Fase.PARADA:
		return
	var ponta := to_local(_ponto_de_origem())
	var boia := to_local(_boia)
	if _fase == _Fase.NA_AGUA:
		boia.y += roundf(sin(_relogio * TAU * frequencia_balanco) * balanco_boia)
	_desenhar_linha(ponta, boia, _fase == _Fase.NA_AGUA)
	if _respingo >= 0.0:
		_desenhar_respingo(to_local(_destino))
	# Boia: contorno, corpo claro, topo vermelho — a mesma da vara na mao, para
	# o jogador reconhecer que e a MESMA boia que saiu dali.
	draw_circle(boia, raio_boia + 1.0, TemaEncontro.CONTORNO)
	draw_circle(boia, raio_boia, TemaEncontro.PERG_C)
	draw_rect(Rect2(boia + Vector2(-1.0, -raio_boia), Vector2(2.0, 1.0)), cor_boia)


## Linha com barriga (curva quadratica). No voo ela vai quase reta — a boia puxa;
## parada, pendura proporcional ao comprimento, o que a faz ler como linha e nao
## como arame.
func _desenhar_linha(de: Vector2, ate: Vector2, solta: bool) -> void:
	var comprimento: float = de.distance_to(ate)
	var barriga: float = comprimento * barriga_linha if solta else comprimento * 0.02
	var meio := (de + ate) * 0.5 + Vector2(0.0, barriga)
	var pontos := PackedVector2Array()
	for i in _SEGMENTOS_LINHA + 1:
		var u: float = float(i) / float(_SEGMENTOS_LINHA)
		var a := de.lerp(meio, u)
		var b := meio.lerp(ate, u)
		pontos.append(a.lerp(b, u))
	draw_polyline(pontos, cor_linha, 1.0)


## Dois aneis achatados (2:1, o chao isometrico) que crescem e somem, e quatro
## gotas que sobem e caem.
func _desenhar_respingo(centro: Vector2) -> void:
	var u: float = clampf(_respingo / maxf(duracao_respingo, 0.01), 0.0, 1.0)
	var alfa: float = 1.0 - u
	for k in 2:
		var r: float = raio_respingo * clampf(u * 1.4 - float(k) * 0.3, 0.0, 1.0)
		if r <= 0.5:
			continue
		var anel := PackedVector2Array()
		for i in 17:
			var a: float = TAU * float(i) / 16.0
			anel.append(centro + Vector2(cos(a) * r, sin(a) * r * 0.5))
		draw_polyline(anel, Color(cor_respingo, alfa), 1.0)
	for i in 4:
		var lado: float = -1.0 if i % 2 == 0 else 1.0
		var abertura: float = (1.0 + floorf(float(i) * 0.5)) * 1.5
		var altura: float = 8.0 * 4.0 * u * (1.0 - u)
		var gota := centro + Vector2(lado * abertura * (0.5 + u * 2.0), -altura)
		draw_rect(Rect2(gota.round(), Vector2.ONE), Color(cor_respingo, alfa))


func _ponto_de_origem() -> Vector2:
	if _origem.is_valid():
		var p: Variant = _origem.call()
		if p is Vector2:
			return p
	return global_position


## Se ha um `pousou` devido (voo interrompido), emite agora. Sincrono: quem
## espera o voo interrompido ja esta no await.
func _concluir_voo_pendente() -> void:
	if not _devido_pousou:
		return
	_devido_pousou = false
	pousou.emit()
