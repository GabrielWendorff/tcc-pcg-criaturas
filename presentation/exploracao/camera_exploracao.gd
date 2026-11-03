class_name CameraExploracao
extends Camera2D

## Camada 4 — camera da exploracao: segue o jogador e nao deixa ver fora do mapa.
##
## Sem zoom, rotacao ou troca de alvo: a etapa atual pede orientacao espacial
## estavel, e cada grau de liberdade a mais na camera e um jeito a mais de o
## jogador se perder num mapa que ele ainda nao conhece.

## Ampliacao. INTEIRA de proposito: em zoom fracionario um pixel de arte cobre
## 3,5 pixels de tela e as colunas saem com larguras desiguais — o serrilhado
## que aparece e o mesmo defeito que o filtro NEAREST veio evitar.
const ZOOM := 3.0

## Quanto a camera "persegue" a posicao do alvo. Alto o bastante para nao dar
## sensacao de atraso no controle, baixo o bastante para amortecer o passo.
const SUAVIDADE := 9.0

## Quantas sacudidas por segundo o tremor da. Alto o bastante para ler como
## impacto, nao como oscilacao.
const FREQUENCIA_DO_TREMOR := 34.0

var alvo: Node2D

var _tremor_restante: float = 0.0
var _tremor_total: float = 0.0
var _tremor_intensidade: float = 0.0
var _fase_do_tremor: float = 0.0


func _ready() -> void:
	zoom = Vector2(ZOOM, ZOOM)
	position_smoothing_enabled = true
	position_smoothing_speed = SUAVIDADE
	# Sem isto o clamp nos limites e instantaneo e a camera "bate" na borda
	# enquanto o resto do movimento esta suavizado.
	limit_smoothed = true
	# make_current() so vale com o no JA na arvore — em _ready ele esta.
	make_current()


## Confina a camera ao retangulo do mapa. Se a area visivel for MAIOR que o
## retangulo, a Camera2D centraliza em vez de clampar; com um mapa de 1216x608 e
## zoom 3 isso nao acontece, mas e o motivo de o zoom nao ser configuravel aqui.
func enquadrar(retangulo: Rect2) -> void:
	limit_left = int(retangulo.position.x)
	limit_top = int(retangulo.position.y)
	limit_right = int(retangulo.end.x)
	limit_bottom = int(retangulo.end.y)


func seguir(no: Node2D) -> void:
	alvo = no
	if alvo != null:
		# Sem o salto inicial a camera comeca na origem e desliza ate o jogador
		# no primeiro segundo de jogo.
		global_position = alvo.global_position
		reset_smoothing()


## Sacode a camera por `duracao` segundos, com `intensidade` pixels de amplitude
## inicial. Usado pelo encontro para pontuar o susto e pela pesca nos puxoes.
##
## Mexe em `offset`, e nao em `position`: a posicao e reescrita todo frame pelo
## seguimento do alvo, e a suavizacao da Camera2D amorteceria justamente o que o
## tremor precisa ter de seco. O offset entra depois de tudo isso.
##
## A OPCAO E CONSULTADA AQUI, no ponto de entrada, e nao em cada chamador. E o
## que faz "desligar tremor de camera" valer para o encontro, para a pesca e
## para qualquer sistema futuro sem que nenhum deles precise saber que a opcao
## existe — um `if` esquecido num chamador novo seria um defeito de
## acessibilidade descoberto por quem desligou a opcao justamente por precisar.
func tremer(duracao: float, intensidade: float) -> void:
	if duracao <= 0.0 or intensidade <= 0.0:
		return
	if not Opcoes.ligada("tremor_camera"):
		return
	_tremor_total = duracao
	_tremor_restante = duracao
	_tremor_intensidade = intensidade
	_fase_do_tremor = 0.0


func tremendo() -> bool:
	return _tremor_restante > 0.0


func _process(delta: float) -> void:
	if alvo != null:
		# Basta escrever a posicao: o amortecimento e a limitacao sao aplicados
		# pela propria Camera2D ao desenhar.
		global_position = alvo.global_position
	_avancar_tremor(delta)


## Amplitude decrescente ate zero, e offset ZERADO no fim: um tremor que termina
## fora do zero deixa a camera torta pelo resto da partida, e o desvio e pequeno
## demais para alguem desconfiar da camera.
func _avancar_tremor(delta: float) -> void:
	if _tremor_restante <= 0.0:
		return
	_tremor_restante -= delta
	if _tremor_restante <= 0.0:
		offset = Vector2.ZERO
		return
	_fase_do_tremor += delta * FREQUENCIA_DO_TREMOR
	var amplitude := _tremor_intensidade * (_tremor_restante / _tremor_total)
	# Frequencias diferentes nos dois eixos: em fase, a sacudida sai na diagonal e
	# le como deslize. O eixo vertical usa metade da amplitude pelo mesmo motivo do
	# RAZAO_ISO do jogador — numa projecao 2:1, o mesmo deslocamento em y parece o
	# dobro do deslocamento em x.
	offset = Vector2(sin(_fase_do_tremor) * amplitude,
			cos(_fase_do_tremor * 1.7) * amplitude * 0.5)
