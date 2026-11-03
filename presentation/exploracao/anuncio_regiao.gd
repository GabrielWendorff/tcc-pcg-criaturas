class_name AnuncioRegiao
extends CanvasLayer

## O nome da regiao que aparece ao entrar nela pela primeira vez.
##
## E a resposta mais barata para "onde eu estou?" num mundo continuo. Como nao
## ha carregamento entre regioes — de proposito: o requisito e atravessar
## andando —, nada mais avisa ao jogador que ele mudou de lugar. O rotulo faz
## esse trabalho e sai de cena.
##
## Aparece UMA vez por regiao (quem decide e EstadoMundo.visitar, que devolve
## true so na primeira visita). Reanunciar a cada reentrada transformaria a
## travessia de uma ponte num anuncio piscando.

const CAMADA := 60
const DURACAO := 2.4

var _caixa: Control
var _titulo: Control
var _linha: Control
var _tween: Tween


func _ready() -> void:
	layer = CAMADA
	_caixa = Control.new()
	_caixa.name = "Anuncio"
	_caixa.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_caixa.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_caixa.offset_top = 92.0
	_caixa.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_caixa.modulate.a = 0.0
	add_child(_caixa)

	# Sobre o mundo, sem painel atras: um cartao aqui roubaria a tela no momento
	# em que a coisa a ver e a paisagem nova. A legibilidade vem da sombra de
	# 3px do rotulo sombreado — e como pixel art resolve texto sobre fundo
	# arbitrario, ja que fonte de bitmap nao aceita contorno da engine.
	_titulo = TemaEncontro.rotulo_sombreado("", TemaEncontro.OURO_C,
			TemaEncontro.Corpo.TITULO)
	_titulo.position = Vector2(-300, 0)
	_titulo.custom_minimum_size = Vector2(600, 28)
	_titulo.size = Vector2(600, 28)
	_caixa.add_child(_titulo)

	_linha = TemaEncontro.rotulo_sombreado("", TemaEncontro.PERG)
	_linha.position = Vector2(-300, 32)
	_linha.custom_minimum_size = Vector2(600, 16)
	_linha.size = Vector2(600, 16)
	_caixa.add_child(_linha)


func anunciar(nome: String, descricao: String = "") -> void:
	TemaEncontro.escrever_sombreado(_titulo, nome)
	TemaEncontro.escrever_sombreado(_linha, descricao)
	# Os dois rotulos sao ancorados em FULL_RECT dentro do proprio container e
	# centralizados; escrever_sombreado recalcula o minimo, entao a largura fixa
	# precisa ser reposta para o texto continuar centrado na tela.
	for no: Control in [_titulo, _linha]:
		no.custom_minimum_size.x = 600
		no.size.x = 600
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_caixa.modulate.a = 0.0
	_caixa.position.y = 8.0
	_tween = create_tween()
	_tween.set_parallel(true)
	_tween.tween_property(_caixa, "modulate:a", 1.0, 0.35)
	_tween.tween_property(_caixa, "position:y", 0.0, 0.5) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_tween.set_parallel(false)
	_tween.tween_interval(DURACAO)
	_tween.tween_property(_caixa, "modulate:a", 0.0, 0.5)
