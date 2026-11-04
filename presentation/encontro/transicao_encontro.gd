class_name TransicaoEncontro
extends CanvasLayer

## Escurecimento da tela e o cartao "CRIATURA ENCONTRADA".
##
## Camada propria, acima do mundo e ABAIXO da interface de encontro (ver as
## constantes CAMADA_* em GerenciadorEncontro): a interface precisa aparecer sobre
## a tela ja escura, e o escuro precisa continuar ali enquanto o menu estiver
## aberto. Por isso escurecer() e clarear() sao chamadas independentes, e nao um
## unico efeito com duracao fixa.
##
## Todos os tempos vem de ConfiguracaoEncontro; nenhum literal de duracao aqui.

## Opacidade do escuro. Baixa de proposito, e mais baixa desde que a vinheta de
## InterfaceEncontro passou a somar por cima: as duas em forca cheia apagavam a
## vila, e o encontro precisa acontecer num lugar reconhecivel.
const OPACIDADE := 0.78

## Deslocamento vertical da entrada do texto, em pixels.
const DESLOCAMENTO_TEXTO := 26.0

## Folga horizontal entre o texto e a moldura da faixa.
const FOLGA_DA_FAIXA := 72.0

var _veu: ColorRect
var _faixa: PanelContainer
var _texto: Control
var _texto_frente: Label
var _texto_sombra: Label


func _ready() -> void:
	_veu = ColorRect.new()
	_veu.name = "Veu"
	_veu.color = Color(TemaEncontro.CONTORNO, 0.0)
	_veu.set_anchors_preset(Control.PRESET_FULL_RECT)
	_veu.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_veu)

	# O cartaz e o momento mais visivel do roteiro e precisa de peso: folha 3x da
	# fonte, dentro de uma FAIXA de madeira que atravessa a tela. Texto solto no
	# meio do escuro — como estava — le como legenda de video, nao como um evento
	# do jogo. A sombra propria continua ali porque fonte de bitmap nao aceita o
	# contorno gerado pela engine.
	_faixa = PanelContainer.new()
	_faixa.name = "Faixa"
	_faixa.add_theme_stylebox_override("panel", TemaEncontro.moldura("painel"))
	_faixa.set_anchors_preset(Control.PRESET_CENTER)
	_faixa.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_faixa.modulate.a = 0.0
	add_child(_faixa)

	_texto = TemaEncontro.rotulo_sombreado("", TemaEncontro.OURO_C,
			TemaEncontro.Corpo.CARTAZ)
	_texto.name = "Cartao"
	_faixa.add_child(_texto)
	_texto_sombra = _texto.get_node("Sombra")
	_texto_frente = _texto.get_node("Frente")


## Escurece a tela. Bloqueia ate terminar.
func escurecer(duracao: float) -> void:
	var t := create_tween()
	t.tween_property(_veu, "color:a", OPACIDADE, duracao).set_trans(Tween.TRANS_SINE)
	await t.finished


## Mostra o cartao, segura e o retira. Bloqueia pela duracao inteira.
func apresentar(texto: String, duracao: float) -> void:
	TemaEncontro.escrever_sombreado(_texto, texto)
	# A faixa mede o texto so depois do layout; sem esperar um quadro ela entra na
	# tela com a largura do quadro anterior e "cresce" durante a animacao.
	await get_tree().process_frame
	_centralizar_faixa()
	var entrada: float = minf(0.22, duracao * 0.3)
	var t := create_tween()
	t.set_parallel(true)
	t.tween_property(_faixa, "modulate:a", 1.0, entrada)
	t.tween_property(_faixa, "position:y", _faixa.position.y, entrada) \
			.from(_faixa.position.y + DESLOCAMENTO_TEXTO) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await t.finished
	await get_tree().create_timer(maxf(0.0, duracao - entrada * 2.0)).timeout
	var saida := create_tween()
	saida.tween_property(_faixa, "modulate:a", 0.0, entrada)
	await saida.finished


## Devolve a tela ao mundo. Bloqueia ate terminar.
func clarear(duracao: float) -> void:
	var t := create_tween()
	t.tween_property(_veu, "color:a", 0.0, duracao).set_trans(Tween.TRANS_SINE)
	await t.finished
	TemaEncontro.escrever_sombreado(_texto, "")


## Centraliza a faixa no viewport a partir do tamanho que ela ganhou no layout.
## FOLGA_DA_FAIXA alarga a moldura para alem do texto: colada nas letras, a faixa
## le como caixa de rotulo; folgada, le como placa.
func _centralizar_faixa() -> void:
	var tela := get_viewport().get_visible_rect().size
	var minimo := _faixa.get_combined_minimum_size()
	_faixa.size = minimo + Vector2(FOLGA_DA_FAIXA, FOLGA_DA_FAIXA * 0.4)
	_faixa.position = ((tela - _faixa.size) * 0.5).floor()
