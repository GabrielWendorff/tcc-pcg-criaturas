class_name FundoMenu
extends Control

## Fundo do menu principal: pixel art GERADA EM TEMPO DE CARGA, sem nenhum
## arquivo de imagem.
##
## POR QUE 192x108 AMPLIADO 6x, e nao 1152x648 direto
## --------------------------------------------------
## E a mesma tecnica da vinheta do encontro (interface_encontro.gd), pelas mesmas
## duas razoes:
##
##   1. O PIXEL FICA QUADRADO E GRANDE. Desenhar na resolucao da tela produziria
##      formas de 1px que, ao lado de uma fonte bitmap 5x7 ampliada, leem como
##      ruido fino — a tela teria duas escalas de pixel brigando. Ampliar com
##      filtro NEAREST (ja o padrao do projeto, ver project.godot) garante que o
##      menor detalhe do fundo tenha o mesmo tamanho do menor detalhe do texto.
##   2. CUSTA 20.736 PIXELS, nao 746.496. Um laco por pixel em GDScript na
##      resolucao cheia levaria quase um segundo na abertura do jogo; aqui e
##      imperceptivel, e a imagem e gerada UMA vez e virada textura.
##
## O DEGRADE E TRAMADO, nao liso
## -----------------------------
## O ceu nao e uma interpolacao continua: e dividido em BANDAS de cor chapada, e
## a fronteira entre duas bandas vizinhas e misturada por uma matriz de Bayer
## 2x2. E o que o README do encontro ja dizia de outra tela — "um degrade liso no
## meio de uma tela de pixel art denuncia a interface como estranha ao jogo".
## Banda chapada + trama e como um ceu de pixel art e feito a mao.
##
## DETERMINISTICO. Estrelas, colinas e vaga-lumes saem de um RandomNumberGenerator
## semeado por constante, nunca de randf() global — a mesma politica do gerador de
## criaturas (RF03). O menu abre identico toda vez, e um fundo que muda a cada
## abertura leria como instabilidade, nao como variedade.
##
## As cores sao todas de TemaEncontro: o menu principal e a primeira tela do jogo
## e precisa prometer a paleta que as outras cumprem.

## Resolucao nativa do desenho. 192x108 x6 = 1152x648, o tamanho de viewport em
## que as outras telas do projeto foram verificadas.
const LARGURA := 192
const ALTURA := 108

## Semente do desenho. Constante: ver nota de determinismo acima.
const SEMENTE := 20261002

## Linha do horizonte, em pixels do desenho. Acima dela, ceu; abaixo, terra.
const HORIZONTE := 64

## Bandas de cor chapada do ceu. Poucas de proposito — com muitas, a trama some e
## o degrade volta a parecer liso.
const BANDAS := 11

## Matriz de Bayer 2x2 normalizada, usada para tramar a fronteira entre bandas.
const BAYER := [[0.0, 0.5], [0.75, 0.25]]

## Desliga a animacao dos vaga-lumes. Segue a opcao "efeitos de tela"; existe
## como campo para que uma tela possa desligar por conta propria.
var animado: bool = true:
	set(valor):
		animado = valor
		if _motes != null:
			_motes.visible = valor

var _textura: TextureRect
var _motes: CamadaDeMotes


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	_textura = TextureRect.new()
	_textura.name = "Ceu"
	_textura.texture = ImageTexture.create_from_image(_desenhar())
	_textura.set_anchors_preset(Control.PRESET_FULL_RECT)
	# IGNORE_SIZE + SCALE: a imagem acompanha a janela em qualquer tamanho. Em
	# proporcao diferente de 16:9 ela estica, que e o comportamento ja aceito
	# pela vinheta do encontro — o alternativa (barras) deixaria canto de
	# viewport na cor de fundo crua.
	_textura.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_textura.stretch_mode = TextureRect.STRETCH_SCALE
	_textura.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_textura)

	_motes = CamadaDeMotes.new()
	_motes.name = "Motes"
	_motes.set_anchors_preset(Control.PRESET_FULL_RECT)
	_motes.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_motes)
	animado = Opcoes.ligada("efeitos_de_tela")
	Opcoes.mudou.connect(_ao_mudar_opcao)


## O fundo do menu e a unica tela que pode ter a opcao mexida DEBAIXO dela (a
## tela de opcoes abre por cima dele), entao aqui vale escutar o sinal em vez de
## so ler o valor na abertura.
func _ao_mudar_opcao(id: String, valor: Variant) -> void:
	if id == "efeitos_de_tela":
		animado = bool(valor)


# --------------------------------------------------------------- composicao

func _desenhar() -> Image:
	var img := Image.create_empty(LARGURA, ALTURA, false, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	rng.seed = SEMENTE

	_pintar_ceu(img)
	_pintar_lua(img)
	_pintar_estrelas(img, rng)
	# Da mais distante para a mais proxima: cada camada cobre a anterior, e e
	# essa sobreposicao que produz profundidade sem nenhum calculo de recuo.
	_pintar_colina(img, rng, HORIZONTE - 6, 5.0, Color("322c46"))
	_pintar_colina(img, rng, HORIZONTE + 2, 4.0, Color("231f33"))
	_pintar_colina(img, rng, HORIZONTE + 11, 3.0, Color("16131f"))
	_pintar_chao(img)
	_pintar_vinheta(img)
	return img


## Ceu em bandas chapadas, com a fronteira entre bandas vizinhas tramada.
func _pintar_ceu(img: Image) -> void:
	for y in HORIZONTE:
		var escalado: float = (float(y) / float(HORIZONTE)) * float(BANDAS)
		var banda: int = mini(int(escalado), BANDAS - 1)
		var sobra: float = escalado - float(banda)
		var cor := _cor_do_ceu(banda)
		var proxima := _cor_do_ceu(mini(banda + 1, BANDAS - 1))
		for x in LARGURA:
			# A trama so age na metade de baixo de cada banda: na metade de cima
			# a cor e chapada, e e isso que mantem a BANDA legivel como banda.
			var c := cor
			if sobra > 0.5:
				var limiar: float = BAYER[y % 2][x % 2]
				if (sobra - 0.5) * 2.0 > limiar:
					c = proxima
			img.set_pixel(x, y, c)


## Rampa do ceu, do topo ao horizonte. Noite fria em cima, brasa de crepusculo
## embaixo: e o contraste que faz a silhueta das colinas aparecer sem contorno.
func _cor_do_ceu(banda: int) -> Color:
	var paradas: Array[Color] = [
		TemaEncontro.NOITE_E.darkened(0.55),
		TemaEncontro.NOITE_E,
		TemaEncontro.NOITE,
		TemaEncontro.NOITE_C,
		Color("4d3f52"),
		TemaEncontro.MADEIRA_E,
		TemaEncontro.MADEIRA,
		TemaEncontro.OURO_E,
	]
	var t: float = float(banda) / float(maxi(BANDAS - 1, 1))
	var pos: float = t * float(paradas.size() - 1)
	var i: int = mini(int(pos), paradas.size() - 2)
	return paradas[i].lerp(paradas[i + 1], pos - float(i))


## Lua crescente: um disco claro com um segundo disco do ceu recortado por cima.
## Dois circulos resolvem a forma; desenhar o crescente diretamente exigiria uma
## equacao que ninguem releria depois.
func _pintar_lua(img: Image) -> void:
	var centro := Vector2(150, 19)
	var raio: float = 9.0
	for y in range(int(centro.y - raio) - 1, int(centro.y + raio) + 2):
		for x in range(int(centro.x - raio) - 1, int(centro.x + raio) + 2):
			if x < 0 or y < 0 or x >= LARGURA or y >= ALTURA:
				continue
			var p := Vector2(x, y)
			var d: float = p.distance_to(centro)
			if d > raio:
				# Halo de um pixel, para a lua nao recortar seca contra o ceu.
				if d <= raio + 1.6:
					img.set_pixel(x, y, img.get_pixel(x, y).lerp(TemaEncontro.PERG_E, 0.22))
				continue
			if p.distance_to(centro + Vector2(4.5, -2.5)) < raio - 0.5:
				continue  # a sombra do crescente: fica o ceu que ja estava ali
			img.set_pixel(x, y, TemaEncontro.PERG_C if d < raio - 2.0
					else TemaEncontro.PERG)


## Estrelas em tres brilhos. Densidade cai perto do horizonte, onde o ceu ja esta
## claro — uma estrela sobre a faixa alaranjada nao teria contraste e leria como
## sujeira no desenho.
func _pintar_estrelas(img: Image, rng: RandomNumberGenerator) -> void:
	for _i in 90:
		var x: int = rng.randi_range(0, LARGURA - 1)
		var y: int = rng.randi_range(1, HORIZONTE - 10)
		if rng.randf() > 1.0 - float(y) / float(HORIZONTE):
			continue
		var brilho: float = rng.randf()
		var cor := TemaEncontro.PERG_C if brilho > 0.88 \
				else (TemaEncontro.PERG if brilho > 0.55 else TemaEncontro.PERG_E)
		var fundo := img.get_pixel(x, y)
		img.set_pixel(x, y, fundo.lerp(cor, 0.35 + brilho * 0.65))


## Uma camada de colina: perfil por soma de senos (duas frequencias, fase
## sorteada), preenchido de cor chapada ate a base da imagem.
##
## Soma de SENOS e nao ruido: o perfil precisa ser suave e fechado, e duas
## frequencias ja dao uma linha que nao parece periodica a olho nu nesta largura.
func _pintar_colina(img: Image, rng: RandomNumberGenerator, base: int,
		amplitude: float, cor: Color) -> void:
	var fase_a: float = rng.randf() * TAU
	var fase_b: float = rng.randf() * TAU
	for x in LARGURA:
		var u: float = float(x) / float(LARGURA)
		var altura: float = sin(u * TAU * 1.6 + fase_a) * amplitude \
				+ sin(u * TAU * 3.7 + fase_b) * amplitude * 0.45
		var topo: int = clampi(base - int(round(altura)), 0, ALTURA - 1)
		for y in range(topo, ALTURA):
			img.set_pixel(x, y, cor)


## Chao: base escura com uma grade de losangos isometricos esmaecendo ao se
## afastar da base da tela.
##
## A grade e a assinatura da projecao 2:1 que o jogo inteiro usa — e o que liga
## o menu a tela que vem depois dele, sem precisar de nenhuma captura do mundo.
func _pintar_chao(img: Image) -> void:
	var inicio: int = HORIZONTE + 14
	for y in range(inicio, ALTURA):
		# Quanto mais perto da base, mais visivel a grade: no fundo ela se funde
		# ao sopé da colina, como linhas de perspectiva de fato se fundem.
		var forca: float = clampf(float(y - inicio) / float(ALTURA - inicio), 0.0, 1.0)
		for x in LARGURA:
			# Losango de 16x8: as duas familias de retas de uma grade 2:1.
			var na_grade: bool = posmod(x + 2 * y, 16) == 0 or posmod(x - 2 * y, 16) == 0
			if not na_grade:
				continue
			var fundo := img.get_pixel(x, y)
			img.set_pixel(x, y, fundo.lerp(TemaEncontro.MADEIRA_E, 0.10 + forca * 0.26))


## Escurecimento das bordas. Fecha a composicao para dentro, de modo que o olho
## caia no centro — que e onde o menu esta.
func _pintar_vinheta(img: Image) -> void:
	var centro := Vector2(LARGURA, ALTURA) * 0.5
	var maximo: float = centro.length()
	for y in ALTURA:
		for x in LARGURA:
			var d: float = (Vector2(x, y) - centro).length() / maximo
			if d < 0.55:
				continue
			var forca: float = clampf((d - 0.55) / 0.45, 0.0, 1.0) * 0.55
			img.set_pixel(x, y, img.get_pixel(x, y).darkened(forca))


## Vaga-lumes: a unica coisa que se move na tela.
##
## Camada separada, e nao pixels na imagem, porque sao o unico elemento animado —
## redesenhar a textura inteira por quadro para mover dezoito pontos custaria o
## fundo todo a cada frame.
class CamadaDeMotes extends Control:
	const SEMENTE := 991

	## Poucos e lentos: o fundo tem de ter vida sem disputar atencao com o menu,
	## que e o que o jogador veio ler.
	const QUANTIDADE := 18

	var _motes: Array[Dictionary] = []
	var _tempo: float = 0.0

	func _ready() -> void:
		var rng := RandomNumberGenerator.new()
		rng.seed = SEMENTE
		for _i in QUANTIDADE:
			_motes.append({
				"base": Vector2(rng.randf(), 0.45 + rng.randf() * 0.5),
				"amplitude": Vector2(rng.randf_range(0.01, 0.035),
						rng.randf_range(0.015, 0.05)),
				"velocidade": rng.randf_range(0.18, 0.52),
				"fase": rng.randf() * TAU,
				"raio": rng.randf_range(1.5, 3.0),
			})

	func _process(delta: float) -> void:
		_tempo += delta
		queue_redraw()

	func _draw() -> void:
		var tam := size
		for m: Dictionary in _motes:
			var fase: float = _tempo * float(m["velocidade"]) + float(m["fase"])
			var base: Vector2 = m["base"]
			var amp: Vector2 = m["amplitude"]
			var p := Vector2(
				(base.x + sin(fase) * amp.x) * tam.x,
				(base.y + cos(fase * 1.37) * amp.y) * tam.y)
			# Pulsacao lenta da opacidade: um ponto de brilho constante le como
			# pixel morto na tela, nao como bicho.
			var alfa: float = 0.25 + 0.45 * (0.5 + 0.5 * sin(fase * 2.1))
			draw_circle(p, float(m["raio"]) * 2.4,
					Color(TemaEncontro.OURO, alfa * 0.18))
			draw_circle(p, float(m["raio"]), Color(TemaEncontro.OURO_C, alfa))
