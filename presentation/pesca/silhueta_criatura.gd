class_name SilhuetaCriatura
extends Node2D

## A sombra do monstro que persegue a isca, no corte da agua.
##
## E a MESMA mascara de corpo do bestiario (CatalogoCorpos.textura_corpo), pintada
## de uma cor so. O pedido era "sprite escuro, sem detalhes" — e a mascara ja e o
## contorno exato da criatura gerada: um peixe alongado da uma sombra comprida, um
## anfibio compacto uma sombra redonda. O jogador le o PORTE e o ANIMAL pela
## forma antes de saber quem e, sem nenhuma arte nova (RF07: o visual continua
## sendo funcao pura dos atributos sorteados).
##
## COR CHAPADA POR SHADER. A mascara e indexada (canal R = indice da rampa, ver
## paleta_indexada.gdshader), entao tingir com `modulate` daria quatro tons de
## escuro — contorno, sombra, base e brilho ainda visiveis, que e justamente o
## "detalhe" que a silhueta nao pode ter. O shader troca toda cor pela `cor`
## e mantem so o alfa. Vai num Sprite2D proprio, e nao em draw_texture no
## _draw: num shader canvas_item, TEXTURE e a textura DO NO (a mesma licao de
## CreatureSpriteRenderer).
##
## Sem textura (catalogo ausente, body_id sem arte) cai num peixe generico de
## poligono: a pesca funciona mesmo numa cena de teste sem o catalogo.
##
## Virada para a ISCA: a isca vem da direita para a esquerda (para o jogador) e o
## monstro vem atras dela, logo olha para a esquerda. As mascaras sao autoradas
## com a cabeca de um lado — as ancoras `cabeca`/`cauda` dizem qual — e o sprite
## e espelhado (scale.x negativo, em torno do centro do corpo) quando a cabeca
## esta a direita.
##
## Quem POSICIONA e o MinigameRecolhimento (altura do monstro, afastamento atras
## da isca). Aqui so o que e da propria criatura: nadar, reagir ao interesse,
## aparecer e sumir. O nado e feito de deslocamentos INTEIROS, sem girar nem
## escalar a mascara: escala fracionaria ou rotacao em pixel art produzem colunas
## de larguras desiguais, e a sombra deixaria de ser da mesma familia do sprite.

@export var cor: Color = Color(0.03, 0.05, 0.09, 0.85):
	set(v):
		cor = v
		if _material != null:
			_material.set_shader_parameter("cor", cor)
		queue_redraw()
## Ampliacao da mascara (32 px de arte). INTEIRA, pelo motivo do topo do arquivo.
@export var escala_desenho: float = 3.0
## Duracao do aparecer/sumir, em segundos.
@export var duracao_fade: float = 0.45
## Amplitude do nado: subida/descida e avanco/recuo, em pixels de tela.
@export var amplitude_oscilacao: float = 3.0
@export var amplitude_avanco: float = 2.0
## Ondulacoes por segundo com interesse zero e com interesse cheio: o monstro
## interessado nada agitado; o desinteressado, preguicoso.
@export var frequencia_calma: float = 0.7
@export var frequencia_agitada: float = 2.4
## Opacidade relativa com interesse zero (1 = cheia). A sombra desinteressada e
## mais apagada — mais agua entre ela e o jogador.
@export var opacidade_longe: float = 0.55

const _CODIGO_SHADER := """
shader_type canvas_item;
render_mode unshaded;
uniform vec4 cor : source_color = vec4(0.03, 0.05, 0.09, 0.85);
void fragment() {
	if (texture(TEXTURE, UV).a < 0.5) {
		discard;
	}
	COLOR = vec4(cor.rgb, cor.a * COLOR.a);
}
"""

## Meia largura do peixe generico, em pixels de arte (antes da escala).
const _MEIA_LARGURA_POLIGONO := 12.0

## Um shader para todas as silhuetas: compilar um por instancia seria custo
## repetido para o mesmo codigo.
static var _shader: Shader

var _sprite: Sprite2D
var _material: ShaderMaterial
var _tem_textura: bool = false
var _espelhar: bool = true
## Caixa ocupada pelo corpo dentro da mascara, em pixels de arte.
var _conteudo: Rect2 = Rect2()
var _interesse: float = 0.0
var _tempo: float = 0.0
var _tween: Tween
## Deslocamento corrente do nado (aplicado ao sprite ou ao poligono).
var _nado: Vector2 = Vector2.ZERO
var _alfa: float = 0.6


func _init() -> void:
	if _shader == null:
		_shader = Shader.new()
		_shader.code = _CODIGO_SHADER
	_material = ShaderMaterial.new()
	_material.shader = _shader
	_material.set_shader_parameter("cor", cor)
	_sprite = Sprite2D.new()
	_sprite.name = "Mascara"
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.material = _material
	_sprite.centered = true
	_sprite.visible = false
	add_child(_sprite)
	visible = false
	modulate.a = 0.0
	set_process(false)


## Mascara do corpo da criatura. Sem catalogo ou sem textura, o poligono
## generico. Pode ser chamada de novo a cada silhueta: o no e o mesmo.
func configurar(criatura: Criatura, catalogo_corpos: CatalogoCorpos) -> void:
	var tex: Texture2D = null
	var olha_para_direita: bool = true
	if criatura != null and catalogo_corpos != null:
		tex = catalogo_corpos.textura_corpo(criatura.body_id)
		var m: Dictionary = catalogo_corpos.meta(criatura.body_id)
		var cabeca: Variant = m.get("cabeca")
		var cauda: Variant = m.get("cauda")
		if cabeca is Array and cauda is Array and not (cabeca as Array).is_empty() \
				and not (cauda as Array).is_empty():
			olha_para_direita = float(cabeca[0]) >= float(cauda[0])
	_tem_textura = tex != null
	_espelhar = olha_para_direita
	_sprite.texture = tex
	_sprite.visible = _tem_textura
	_conteudo = _caixa_do_corpo(tex)
	if _tem_textura:
		# Centro do CORPO na origem do no, e nao o centro do quadro de 32 px: o
		# minigame poe a origem na altura do monstro, e um corpo encostado no pe
		# do quadro ficaria visualmente abaixo da faixa que o jogador tem de seguir.
		_sprite.offset = (tex.get_size() * 0.5 - _conteudo.get_center()).round()
	_montar_tracos(criatura, catalogo_corpos, tex)
	_interesse = 0.0
	_aplicar_nado()
	queue_redraw()


## Asas e nadadeiras mudam o CONTORNO, e por isso entram na sombra: um peixe sem
## nadadeiras e um com elas nao fazem a mesma silhueta. Sao filhas do sprite do corpo,
## no mesmo pixel de arte e com o mesmo shader de cor chapada, e por isso espelham e
## nadam junto com ele. As escamas ficam dentro do corpo e nao mudam a sombra.
func _montar_tracos(criatura: Criatura, catalogo_corpos: CatalogoCorpos, tex: Texture2D) -> void:
	for filho in _sprite.get_children():
		filho.queue_free()
	if tex == null or criatura == null or catalogo_corpos == null:
		return
	var origem: Vector2 = _sprite.offset - tex.get_size() * 0.5
	for q: Dictionary in catalogo_corpos.quadros_de_tracos(criatura):
		var t: Texture2D = q["tex"]
		var r: Rect2 = q["rect"]
		if r.position == Vector2.ZERO and r.size == tex.get_size():
			continue  # sobreposicao (escamas): nao muda o contorno
		var s := Sprite2D.new()
		s.texture = t
		s.centered = false
		s.material = _material
		s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		s.position = origem + r.position
		s.scale = r.size / t.get_size()
		_sprite.add_child(s)


## Meia largura do corpo na tela, em pixels. O minigame a usa para encostar o
## FOCINHO, e nao o centro, a distancia certa da isca.
func meia_largura() -> float:
	if _tem_textura:
		return _conteudo.size.x * 0.5 * escala_desenho
	return _MEIA_LARGURA_POLIGONO * escala_desenho


## Surge da agua turva: fade e um leve crescimento. Nao bloqueia.
func aparecer() -> void:
	_matar_tween()
	visible = true
	modulate.a = 0.0
	scale = Vector2.ONE * 0.85
	set_process(true)
	_tween = create_tween().set_parallel(true)
	_tween.tween_property(self, "modulate:a", 1.0, duracao_fade).set_trans(Tween.TRANS_SINE)
	_tween.tween_property(self, "scale", Vector2.ONE, duracao_fade) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Some de volta no escuro e para de processar. Nao bloqueia.
func sumir() -> void:
	_matar_tween()
	if not visible:
		return
	_tween = create_tween()
	_tween.tween_property(self, "modulate:a", 0.0, duracao_fade).set_trans(Tween.TRANS_SINE)
	_tween.tween_callback(_ao_sumir)


## Esconde na hora, sem animacao (fechar a interface no meio de um fade).
func esconder() -> void:
	_matar_tween()
	visible = false
	modulate.a = 0.0
	scale = Vector2.ONE
	set_process(false)


## Interesse de 0 (vai embora) a 1 (vai morder). A DISTANCIA ate a isca e da
## simulacao (afastamento_silhueta) e o minigame a aplica; aqui o interesse muda
## so o jeito de nadar — mais nitida e mais agitada quando quer a isca.
func reagir(interesse_normalizado: float) -> void:
	_interesse = clampf(interesse_normalizado, 0.0, 1.0)


func _process(delta: float) -> void:
	_tempo += delta * lerpf(frequencia_calma, frequencia_agitada, _interesse)
	_aplicar_nado()


## Nado em pixels inteiros: sobe e desce numa onda, e avanca/recua em quadratura
## (um quarto de ciclo depois) — o par le como impulso de nadadeira.
func _aplicar_nado() -> void:
	var onda: float = sin(_tempo * TAU)
	var impulso: float = cos(_tempo * TAU)
	_nado = Vector2(roundf(impulso * amplitude_avanco), roundf(onda * amplitude_oscilacao))
	# A opacidade relativa entra no canal do material, e nao no modulate: o
	# modulate e do fade de aparecer/sumir e os dois nao podem brigar.
	_alfa = cor.a * lerpf(opacidade_longe, 1.0, _interesse)
	if _tem_textura:
		_sprite.position = _nado
		_sprite.scale = Vector2(-escala_desenho if _espelhar else escala_desenho, escala_desenho)
		_material.set_shader_parameter("cor", Color(cor, _alfa))
	else:
		queue_redraw()


## Peixe generico olhando para a esquerda: corpo oval, cauda em leque e
## barbatana. Do tamanho de uma mascara de porte medio na mesma escala.
func _draw() -> void:
	if _tem_textura:
		return
	draw_set_transform(_nado, 0.0, Vector2(escala_desenho, escala_desenho))
	var c := Color(cor, _alfa)
	var corpo := PackedVector2Array()
	for i in 20:
		var a: float = TAU * float(i) / 20.0
		corpo.append(Vector2(cos(a) * 9.0, sin(a) * 4.5))
	draw_colored_polygon(corpo, c)
	draw_colored_polygon(PackedVector2Array([
		Vector2(7.0, 0.0), Vector2(_MEIA_LARGURA_POLIGONO + 2.0, -5.0),
		Vector2(_MEIA_LARGURA_POLIGONO, 0.0), Vector2(_MEIA_LARGURA_POLIGONO + 2.0, 5.0),
	]), c)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-2.0, -4.0), Vector2(2.0, -7.5), Vector2(4.0, -3.5),
	]), c)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Caixa dos pixels opacos da mascara. 32x32 lidos uma vez por silhueta — barato,
## e evita depender de uma ancora de "centro" que o JSON de corpos nao declara.
static func _caixa_do_corpo(tex: Texture2D) -> Rect2:
	if tex == null:
		return Rect2()
	var img := tex.get_image()
	if img == null or img.is_empty():
		return Rect2(Vector2.ZERO, tex.get_size())
	var usado := img.get_used_rect()
	if not usado.has_area():
		return Rect2(Vector2.ZERO, tex.get_size())
	return Rect2(usado)


func _ao_sumir() -> void:
	visible = false
	set_process(false)


func _matar_tween() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = null
