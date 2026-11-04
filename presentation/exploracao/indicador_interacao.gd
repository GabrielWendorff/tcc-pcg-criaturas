class_name IndicadorInteracao
extends Node2D

## O aviso "[E] FALAR" que flutua sobre a cabeca de quem pode ser interagido.
##
## Fica no MUNDO (filho do NPC), e nao no HUD: com varios NPCs no mesmo quadro,
## um aviso no canto da tela nao diz de QUEM ele fala. Preso ao personagem, a
## resposta e a posicao.
##
## z_index alto pelo mesmo motivo de AvisoEncontro: o y-sort de MundoIso ordena
## pelo pe, e um aviso coberto pela arvore da frente nao avisa nada.
##
## ESCALA — o aviso vive no MUNDO mas e INTERFACE, e as duas coisas nao andam na
## mesma escala. A camera da exploracao roda em zoom 3: um painel de 70px com
## fonte de 11px, desenhado no mundo, chegaria a tela com 210px e 33px de texto —
## maior que o personagem sobre o qual ele aponta. Compensar o zoom
## (1/ZOOM) devolve o aviso ao tamanho do resto da interface, e o resultado
## continua nitido porque 3 x 1/3 = 1 exato: nenhum pixel e reamostrado.
##
## TEXTO CONFIGURAVEL — o mesmo aviso serve ao NPC ("[E] FALAR", o padrao, que
## nenhum NPC precisa declarar) e a pesca ("[F] PESCAR" sobre o proprio jogador).
## Um segundo no de aviso so para a pesca repetiria a escala, o balanco e a
## moldura, e os dois divergiriam no primeiro ajuste. configurar() pode vir antes
## do _ready (quem cria o no costuma configura-lo antes do add_child) ou depois.

## Altura acima da origem do NPC (que e o PE dele). O sprite tem 24px e a cabeca
## fica por volta de -22: o aviso encosta logo acima.
const ALTURA := -34.0 * CameraExploracao.ZOOM

## Balanco vertical, em pixels de mundo. Pequeno de proposito — o aviso precisa
## chamar atencao sem virar o elemento mais agitado da tela.
const BALANCO := 2.0

## Texto padrao: o do NPC. Mudar aqui muda todos os NPCs de uma vez.
const TECLA_PADRAO := "[E]"
const TEXTO_PADRAO := "FALAR"

var _painel: PanelContainer
var _rotulo_tecla: Label
var _rotulo_texto: Label
var _tween: Tween
var _tecla: String = TECLA_PADRAO
var _texto: String = TEXTO_PADRAO


func _ready() -> void:
	z_index = 200
	visible = false
	scale = Vector2.ONE / CameraExploracao.ZOOM

	_painel = PanelContainer.new()
	_painel.name = "Painel"
	_painel.add_theme_stylebox_override("panel", TemaEncontro.moldura("cartao"))
	_painel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var linha := HBoxContainer.new()
	linha.add_theme_constant_override("separation", 4)
	linha.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rotulo_tecla = TemaEncontro.rotulo(_tecla, TemaEncontro.OURO)
	_rotulo_texto = TemaEncontro.rotulo(_texto, TemaEncontro.PERG_C)
	linha.add_child(_rotulo_tecla)
	linha.add_child(_rotulo_texto)
	_painel.add_child(linha)
	add_child(_painel)
	# Centralizar exige o tamanho ja calculado — so existe depois do primeiro
	# layout do Control.
	_painel.resized.connect(_centralizar)
	_centralizar()


## Troca a tecla e o texto do aviso ("[F]", "PESCAR"). Antes do _ready so guarda
## (os rotulos nascem com estes valores); depois, reescreve e recentraliza — o
## painel muda de largura com o texto, e o centro tem de acompanhar.
func configurar(tecla: String, texto: String) -> void:
	_tecla = tecla
	_texto = texto
	if _rotulo_tecla == null or _rotulo_texto == null:
		return
	_rotulo_tecla.text = tecla
	_rotulo_texto.text = texto
	# O PanelContainer so encolhe se pedirem: sem isto um texto mais curto que o
	# anterior deixaria o painel com a largura antiga e o aviso descentrado.
	_painel.reset_size()
	_centralizar()


func _centralizar() -> void:
	if _painel == null:
		return
	var tam := _painel.get_combined_minimum_size()
	_painel.position = Vector2(-tam.x * 0.5, ALTURA)


func mostrar(sim: bool) -> void:
	if visible == sim:
		return
	visible = sim
	if _tween != null and _tween.is_valid():
		_tween.kill()
	if not sim:
		return
	_centralizar()
	var cheia := Vector2.ONE / CameraExploracao.ZOOM
	scale = cheia * 0.85
	_tween = create_tween()
	_tween.tween_property(self, "scale", cheia, 0.12) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.set_loops()
	_tween.tween_property(self, "position:y", -BALANCO, 0.7) \
			.set_trans(Tween.TRANS_SINE)
	_tween.tween_property(self, "position:y", 0.0, 0.7) \
			.set_trans(Tween.TRANS_SINE)
