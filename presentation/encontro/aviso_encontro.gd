class_name AvisoEncontro
extends Node2D

## O "!" que salta sobre a cabeca do jogador no instante do encontro.
##
## Anda junto com o jogador porque e filho DELE — o aviso pertence a quem foi
## surpreendido, nao a um ponto do mapa. Fica com z_index alto para nao ser
## coberto por prop nenhum: o y-sort de MundoIso ordena entidades pelo pe, e um
## aviso que aparece atras da arvore ao lado nao avisa nada.
##
## E um SPRITE de balao (arte/ui/balao_aviso.png), nao um rotulo com "!".
## Motivo: a fonte da interface e bitmap, e fonte de bitmap nao aceita o contorno
## gerado pela engine — pedi-lo nao da erro, simplesmente nao desenha. Um "!"
## chapado sobre grama clara sumiria. O balao traz o proprio contorno e o proprio
## fundo, e ainda e a linguagem do genero em vez de um caractere ampliado.

## Altura do aviso acima da origem do jogador (que e o PE dele — ver Jogador).
## Medida em pixels de MUNDO, nao de tela: a camera da exploracao roda em zoom 3,
## entao cada unidade aqui vale 3 pixels na tela. O sprite do personagem tem 24px
## de altura e a cabeca fica por volta de -22; a ponta do rabicho encosta logo
## acima dela.
const ALTURA := -27.0

## A pancada da entrada: sobe alem do tamanho final e volta. Sem o excesso a
## aparicao le como "apareceu", com ele le como "assustou".
const ESCALA_ESTOURO := 1.35

const CAMINHO_BALAO := "res://arte/ui/balao_aviso.png"

## Ampliacao do balao. INTEIRA: a camera da exploracao roda em zoom 3, e um
## sprite de interface em escala fracionaria dentro dela sai com colunas de
## larguras desiguais ao lado de uma arte que esta em escala inteira.
const ESCALA := 1

var _sprite: Sprite2D
var _tween: Tween


func _ready() -> void:
	z_index = 200
	visible = false
	_sprite = Sprite2D.new()
	_sprite.name = "Balao"
	_sprite.texture = load(CAMINHO_BALAO)
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.scale = Vector2(ESCALA, ESCALA)
	if _sprite.texture != null:
		# Origem na PONTA do rabicho, nao no centro: e o rabicho que aponta para a
		# cabeca, e e ele que precisa ficar parado quando o balao cresce.
		_sprite.offset = Vector2(0, -_sprite.texture.get_height() * 0.5)
	_sprite.position = Vector2(0, ALTURA)
	add_child(_sprite)


## Salta a vista e some sozinho depois de `duracao`. Nao bloqueia: quem chama
## controla o ritmo do roteiro pelo proprio relogio.
func mostrar(duracao: float) -> void:
	if _sprite == null:
		return
	if _tween != null and _tween.is_valid():
		_tween.kill()
	visible = true
	scale = Vector2(0.2, 0.2)
	modulate.a = 1.0
	var subida: float = minf(0.14, duracao * 0.25)
	_tween = create_tween()
	_tween.tween_property(self, "scale", Vector2.ONE * ESCALA_ESTOURO, subida) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "scale", Vector2.ONE, subida * 0.8) \
			.set_trans(Tween.TRANS_SINE)
	# Um respiro parado antes de sumir: o balao precisa ser LIDO, e um fade que
	# comeca junto com a escala transforma o susto em borrao.
	_tween.tween_interval(maxf(0.0, duracao - subida * 1.8 - 0.15))
	_tween.tween_property(self, "modulate:a", 0.0, 0.15)
	_tween.tween_callback(func(): visible = false)


func esconder() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	visible = false
