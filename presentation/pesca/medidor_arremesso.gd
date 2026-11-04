class_name MedidorArremesso
extends Control

## O arco de forca do arremesso: meio circulo de 180 graus, tres zonas e um
## ponteiro que vai e volta ate o jogador travar.
##
## So DESENHA e MEDE O TEMPO. A conta do vai-e-volta, a zona de um valor e a
## geometria do arco moram em ArcoDeForca (regras/), que o teste headless confere
## sem abrir janela; aqui o valor do ponteiro e literalmente
## ArcoDeForca.pingpong(tempo, velocidade). Quem transforma a forca em distancia e
## o GerenciadorPesca — o medidor nao sabe o que e uma isca.
##
## _draw e nao TextureProgressBar: uma barra de textura enche num sentido so, e o
## arco precisa de tres cores fixas com o ponteiro POR CIMA delas (a zona e lida
## pela posicao, nao por quanto encheu). draw_arc sem antialias mantem a borda
## em degrau, coerente com o resto da pixel art.
##
## Os @export servem a cena de teste; no jogo, configurar(cfg) os sobrescreve com
## data/pesca/configuracao.json — o JSON e a fonte de verdade da calibragem.
##
## POSICAO: embaixo-centro da tela, ancorado por conta propria (_ancorar). O topo
## e da DicaTutorial e o meio e do mundo, onde o jogador ve para onde esta
## virado; a base da tela e o unico lugar que nao disputa com nenhum dos dois.

## O jogador travou o ponteiro. `zona` = "fraco" | "medio" | "maximo".
signal forca_escolhida(forca: float, zona: String)

## Fracao do arco percorrida por segundo (um vai-e-volta = 2/velocidade s).
@export var velocidade: float = 0.85
@export var raio: float = 72.0
@export var espessura: float = 14.0
## [0, limite_verde) = fraco; [limite_verde, limite_amarelo) = medio; resto = maximo.
@export var limite_verde: float = 0.45
@export var limite_amarelo: float = 0.80
## Segundos, depois de iniciar, em que o aperto e ignorado (ver pode_travar).
@export var atraso_trava: float = 0.15
@export var cor_verde: Color = TemaEncontro.VERDE
@export var cor_amarelo: Color = TemaEncontro.OURO
@export var cor_vermelho: Color = TemaEncontro.VERMELHO
## Tutorial: FRACO / MEDIO / MAXIMO escritos sobre as zonas.
@export var mostrar_legenda: bool = false:
	set(v):
		mostrar_legenda = v
		_ancorar()
		queue_redraw()
## Distancia da base do arco ate a borda de baixo da tela, em pixels. Deixa
## lugar para a legenda de teclas da InterfacePesca, que mora no rodape.
@export var folga_inferior: float = 44.0
## Quanto tempo o ponteiro pisca depois de travado. So retorno visual: o lance
## nao espera por ele.
@export var duracao_destaque: float = 0.35

## Posicao atual do ponteiro, 0 (esquerda) .. 1 (direita).
var valor: float = 0.0

var _ativo: bool = false
var _tempo: float = 0.0
## Tempo desde a trava; < 0 = sem destaque.
var _destaque: float = -1.0
## Nomes das zonas na tela. Padrao = os mesmos de ConfiguracaoPesca; configurar()
## os troca pelos do JSON.
var _rotulos: Dictionary = {"fraco": "FRACO", "medio": "MÉDIO", "maximo": "MÁXIMO"}

## Folga entre o arco e a moldura de madeira, e o espaco extra que a legenda
## pede acima do arco. Constantes de LAYOUT, nao de calibragem.
const _FOLGA_MOLDURA := 12.0
const _ALTURA_LEGENDA := 18.0
const _AFASTAMENTO_LEGENDA := 6.0
const _ALTURA_ZONA := 16.0
const _SEGMENTOS_ARCO := 48


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Respeita um iniciar() feito antes de entrar na arvore.
	visible = _ativo
	set_process(_ativo)
	_ancorar()


## Copia o arco, as zonas e os nomes das zonas da configuracao da pesca.
func configurar(cfg: ConfiguracaoPesca) -> void:
	if cfg == null:
		return
	velocidade = cfg.arco_velocidade
	raio = cfg.arco_raio
	espessura = cfg.arco_espessura
	limite_verde = cfg.limite_verde
	limite_amarelo = cfg.limite_amarelo
	atraso_trava = cfg.arco_atraso_trava
	for zona: String in _rotulos.keys():
		_rotulos[zona] = cfg.texto("zona_" + zona)
	_ancorar()
	queue_redraw()


## Comeca a oscilar do zero (ponta esquerda). Sempre do zero: o jogador aprende o
## ritmo do arco, e um comeco em posicao variavel tiraria essa referencia.
func iniciar() -> void:
	_tempo = 0.0
	_destaque = -1.0
	valor = 0.0
	_ativo = true
	visible = true
	_ancorar()
	set_process(true)
	queue_redraw()


## Trava o ponteiro onde esta, emite forca_escolhida e devolve o valor. Chamado
## sem o arco ativo so devolve o valor atual (e nao emite: nao houve escolha).
func parar() -> float:
	if not _ativo:
		return valor
	_ativo = false
	_destaque = 0.0
	queue_redraw()
	forca_escolhida.emit(valor, ArcoDeForca.zona(valor, limite_verde, limite_amarelo))
	return valor


func ativo() -> bool:
	return _ativo


## Ja passou o atraso de trava? Quem segura a tecla um quadro alem do aperto que
## abriu o arco nao pode arremessar com forca zero sem querer.
func pode_travar() -> bool:
	return _ativo and _tempo >= atraso_trava


## Desliga sem emitir nada (cancelamento): o arco some e o valor fica.
func desligar() -> void:
	_ativo = false
	_destaque = -1.0
	visible = false
	set_process(false)


## Zona do valor atual — para quem quiser escrever "MEDIO" fora do medidor.
func zona_atual() -> String:
	return ArcoDeForca.zona(valor, limite_verde, limite_amarelo)


func _process(delta: float) -> void:
	if _ativo:
		_tempo += delta
		valor = ArcoDeForca.pingpong(_tempo, velocidade)
	elif _destaque >= 0.0:
		_destaque += delta
		if _destaque > duracao_destaque:
			_destaque = -1.0
			set_process(false)
	queue_redraw()


# --- layout ---------------------------------------------------------------

## Tamanho e ancoragem embaixo-centro. Recalculado quando o raio, a espessura ou
## a legenda mudam: o medidor ocupa so o retangulo do arco e da moldura, e nao a
## tela inteira — um Control de tela cheia esconderia o mundo do clique.
func _ancorar() -> void:
	var tam := _tamanho()
	anchor_left = 0.5
	anchor_right = 0.5
	anchor_top = 1.0
	anchor_bottom = 1.0
	offset_left = -tam.x * 0.5
	offset_right = tam.x * 0.5
	offset_bottom = -folga_inferior
	offset_top = -folga_inferior - tam.y
	custom_minimum_size = tam


func _tamanho() -> Vector2:
	var externo: float = raio + espessura * 0.5
	var meia_largura: float = externo + _FOLGA_MOLDURA
	var alto: float = externo + _FOLGA_MOLDURA + _ALTURA_ZONA + _FOLGA_MOLDURA * 0.5
	if mostrar_legenda:
		# A legenda fica POR FORA do arco; a moldura cresce ate a palavra mais
		# larga caber inteira de cada lado (MAXIMO quase na horizontal).
		var maior: float = 0.0
		for zona: String in _rotulos.keys():
			maior = maxf(maior, _largura(String(_rotulos[zona])))
		meia_largura = maxf(meia_largura, externo + _AFASTAMENTO_LEGENDA + maior + 6.0)
		alto += _ALTURA_LEGENDA
	return Vector2(ceilf(meia_largura * 2.0), ceilf(alto))


## Centro do arco no referencial deste Control: no meio, acima do nome da zona.
func _centro() -> Vector2:
	return Vector2(floorf(size.x * 0.5), floorf(size.y - _ALTURA_ZONA - _FOLGA_MOLDURA * 0.5))


# --- desenho --------------------------------------------------------------

func _draw() -> void:
	var c := _centro()
	var externo: float = raio + espessura * 0.5
	# Moldura de madeira atras de tudo: sobre grama, agua e telhado o arco tem de
	# ser lido com o mesmo contraste.
	draw_style_box(TemaEncontro.moldura("painel"), Rect2(Vector2.ZERO, size))

	# Trilho escuro um pouco mais largo que as zonas: e o contorno de 2px que
	# separa o arco do painel.
	draw_arc(c, raio, PI, TAU, _SEGMENTOS_ARCO, TemaEncontro.CONTORNO, espessura + 4.0, false)
	_desenhar_zona(c, 0.0, limite_verde, cor_verde)
	_desenhar_zona(c, limite_verde, limite_amarelo, cor_amarelo)
	_desenhar_zona(c, limite_amarelo, 1.0, cor_vermelho)
	# Marcas nos limites: com cor parecida (verde/amarelo para quem nao distingue)
	# a fronteira continua visivel pela forma.
	for limite: float in [limite_verde, limite_amarelo]:
		draw_line(ArcoDeForca.ponto(c, raio - espessura * 0.5 - 1.0, limite),
				ArcoDeForca.ponto(c, externo + 1.0, limite), TemaEncontro.CONTORNO, 2.0)

	if mostrar_legenda:
		_desenhar_legenda(c, externo)
	_desenhar_ponteiro(c, externo)

	# Nome da zona corrente sob o eixo, na cor da zona. Cor + palavra: a cor
	# sozinha nunca decide nada nesta interface (ver TemaEncontro.cor_da_chance).
	var zona := zona_atual()
	_texto_centrado(String(_rotulos.get(zona, zona)),
			Vector2(c.x, c.y + _ALTURA_ZONA - 3.0), _cor_da_zona(zona))


func _desenhar_zona(c: Vector2, de: float, ate: float, cor: Color) -> void:
	if ate <= de:
		return
	var a0 := ArcoDeForca.angulo(de)
	var a1 := ArcoDeForca.angulo(ate)
	var segs: int = maxi(4, int(_SEGMENTOS_ARCO * (ate - de)))
	draw_arc(c, raio, a0, a1, segs, cor.darkened(0.15), espessura, false)
	# Chanfro claro na borda de fora, o mesmo recurso das molduras: le como peca,
	# nao como traco de vetor.
	draw_arc(c, raio + espessura * 0.5 - 1.5, a0, a1, segs, cor.lightened(0.35), 2.0, false)


func _desenhar_ponteiro(c: Vector2, externo: float) -> void:
	var ponta := ArcoDeForca.ponto(c, externo + 3.0, valor)
	var cor_ponta: Color = TemaEncontro.OURO_C
	# Piscar depois da trava: confirma o aperto sem texto, no proprio ponteiro.
	if _destaque >= 0.0 and int(_destaque * 12.0) % 2 == 0:
		cor_ponta = TemaEncontro.PERG_C
	draw_line(c, ponta, TemaEncontro.CONTORNO, 4.0)
	draw_line(c, ponta, cor_ponta, 2.0)
	draw_circle(c, 6.0, TemaEncontro.CONTORNO)
	draw_circle(c, 4.0, TemaEncontro.MADEIRA_C)
	draw_circle(c + Vector2(-1.0, -1.0), 1.5, TemaEncontro.OURO)


## FRACO / MEDIO / MAXIMO por fora do arco, no meio angular de cada zona. So no
## tutorial: depois da primeira licao as cores bastam, e tres palavras em volta
## do arco disputariam o olho com o ponteiro.
func _desenhar_legenda(c: Vector2, externo: float) -> void:
	var faixas := [
		["fraco", 0.0, limite_verde], ["medio", limite_verde, limite_amarelo],
		["maximo", limite_amarelo, 1.0],
	]
	for f: Array in faixas:
		var meio: float = (float(f[1]) + float(f[2])) * 0.5
		var zona: String = f[0]
		var texto: String = String(_rotulos.get(zona, zona))
		# Empurra o centro da palavra para fora do arco ate a caixa do texto nao
		# encostar nele: perto da horizontal pesa a largura; perto do topo, a
		# altura da linha.
		var a := ArcoDeForca.angulo(meio)
		var dir := Vector2(cos(a), sin(a))
		var folga: float = _largura(texto) * 0.5 * absf(dir.x) + 5.0 * absf(dir.y)
		var p := c + dir * (externo + _AFASTAMENTO_LEGENDA + folga)
		_texto_centrado(texto, p + Vector2(0.0, 4.0), _cor_da_zona(zona))


func _cor_da_zona(zona: String) -> Color:
	match zona:
		"fraco":
			return cor_verde
		"medio":
			return cor_amarelo
	return cor_vermelho


## Texto da fonte pixel centrado em x na linha de base `p`, com a sombra de 1px
## que o resto da interface usa sobre fundo variado.
func _texto_centrado(texto: String, p: Vector2, cor: Color) -> void:
	var fonte := TemaEncontro.fonte()
	var largura: float = _largura(texto)
	var base := Vector2(floorf(p.x - largura * 0.5), floorf(p.y))
	draw_string(fonte, base + Vector2(1.0, 1.0), texto, HORIZONTAL_ALIGNMENT_LEFT, -1,
			TemaEncontro.TAM_TEXTO, TemaEncontro.SOMBRA)
	draw_string(fonte, base, texto, HORIZONTAL_ALIGNMENT_LEFT, -1,
			TemaEncontro.TAM_TEXTO, cor)


static func _largura(texto: String) -> float:
	return TemaEncontro.fonte().get_string_size(texto, HORIZONTAL_ALIGNMENT_LEFT, -1,
			TemaEncontro.TAM_TEXTO).x
