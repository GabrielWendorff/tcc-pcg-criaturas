class_name MinigameRecolhimento
extends Control

## O recolhimento visto de lado: corte transversal da agua com o ceu em cima, a
## margem e o pescador a esquerda, as faixas de profundidade, a linha ate a isca
## e — quando surge — a silhueta do monstro atras dela.
##
## NAO TEM REGRA. Tudo o que acontece (para onde a isca vai, quando a silhueta
## surge, o interesse, o desfecho) e da SimulacaoRecolhimento, que o teste
## headless joga sem janela. Este no faz tres coisas por quadro: le a entrada,
## chama simulacao.passo() e desenha o estado. E por isso que o mesmo minigame
## roda a pesca normal e a do tutorial sem um `if tutorial` aqui dentro.
##
## ENTRADA SUBSTITUIVEL: `fonte_de_entrada` devolve Vector2(x_normalizado,
## alvo_profundidade). O padrao le o mouse; um teste de integracao troca por uma
## politica (a perfeita, a errada) e joga a cena real sem mexer no ponteiro.
##
## LEITURA DO MOUSE:
##   x  sobre o trilho de VELOCIDADE no rodape, que atravessa o quadro de ponta a
##      ponta: a esquerda e rapido, a direita e devagar. O marcador do trilho
##      fica exatamente onde o mouse tem de estar — a barra e o mapa do gesto.
##   y  sobre a agua: em cima raso, embaixo fundo. A isca segue com inercia (a
##      suavizacao e da simulacao).
##
## LAYOUT, de cima para baixo:
##   reserva_topo  livre: e onde a DicaTutorial fala durante a licao
##   quadro        ceu (fracao_ceu), agua em faixas, leito; margem a esquerda
##   painel        VELOCIDADE (trilho), INTERESSE, ALTURA OK / VELOCIDADE OK
##   margem        rodape: a legenda de teclas da InterfacePesca
##
## Escala horizontal: a posicao da isca e a FRACAO do trajeto (comeca sempre na
## direita, chega na margem com distancia 0) — qualquer arremesso usa a tela toda
## e "quanto falta" e lido de relance. Ja o afastamento da silhueta e uma
## DISTANCIA (celulas atras da isca) e usa uma escala fixa, a do arremesso
## maximo: um monstro "a uma celula" fica igualmente longe num arremesso curto e
## num longo, e a aproximacao le do mesmo jeito em qualquer lance.

## Desfecho da simulacao, repassado (a interface pode reagir sem conhecer a regra).
signal terminou(desfecho: String, perfil: PerfilPesca)
signal silhueta_surgiu(perfil: PerfilPesca)

## Folga do quadro em relacao as bordas da tela (e o rodape da legenda de teclas).
@export var margem: float = 48.0
## Fracao da altura da cena tomada pelo ceu.
@export var fracao_ceu: float = 0.22
## Faixa livre no topo para a DicaTutorial (nenhuma informacao essencial ali).
@export var reserva_topo: float = 90.0
## Altura do painel de instrumentos sob a agua.
@export var altura_painel: float = 58.0
## Fracao da largura da cena ocupada pela margem de terra a esquerda.
@export var fracao_margem_terra: float = 0.16
## Ampliacao do sprite do pescador (folha 1x). Inteira, como toda pixel art aqui.
@export var escala_pescador: float = 3.0
@export var comprimento_vara: float = 66.0
@export var faixas_de_profundidade: int = 6
@export var cor_ceu: Color = Color("8fbfd3")
@export var cor_horizonte: Color = Color("d6e4c8")
@export var cor_agua_rasa: Color = Color("3f88a6")
@export var cor_agua_funda: Color = Color("0f2236")
@export var cor_superficie: Color = Color("bfe3ee")
@export var cor_terra: Color = TemaEncontro.MADEIRA
@export var cor_grama: Color = Color("5f9e4a")
@export var cor_leito: Color = Color("3b3326")
@export var cor_linha: Color = TemaEncontro.PERG_C
@export var cor_isca: Color = TemaEncontro.VERMELHO
## Faixa-alvo (altura e velocidade do monstro +- tolerancia), quando mostrada.
@export var cor_alvo: Color = Color(TemaEncontro.VERDE, 0.22)
## Escurecimento do mundo em volta do quadro.
@export var cor_veu: Color = Color(TemaEncontro.NOITE_E, 0.82)
## Quanto tempo o aviso "Uma sombra segue a isca!" fica na tela.
@export var duracao_aviso_silhueta: float = 2.2

var simulacao: SimulacaoRecolhimento
var mostrar_alvos: bool = false
## func() -> Vector2(x_normalizado, alvo_profundidade). Ver o topo do arquivo.
var fonte_de_entrada: Callable

var _catalogo: CatalogoCorpos
var _rodando: bool = false
var _relogio: float = 0.0
## Ultima entrada lida (o marcador "fantasma" do trilho mostra a intencao).
var _entrada: Vector2 = Vector2(1.0, 0.0)

## Reacao visual ao desfecho: "" enquanto corre; FISGADO/FUGIU/RECOLHIDA depois.
var _reacao: String = ""
var _reacao_t: float = 0.0
var _afastamento_na_reacao: float = 0.0
var _aviso_t: float = -1.0

# --- geometria (recalculada em _calcular_layout) ----------------------------
var _quadro: Rect2 = Rect2()
var _cena: Rect2 = Rect2()
var _painel: Rect2 = Rect2()
var _agua: Rect2 = Rect2()
var _trilho: Rect2 = Rect2()
var _topo_margem: float = 0.0
var _pe_pescador: Vector2 = Vector2.ZERO

# --- nos ---------------------------------------------------------------------
## Janela recortada do tamanho da agua: a silhueta mora dentro dela e nunca
## aparece fora d'agua, nem perto da superficie.
var _janela: Control
var _silhueta: SilhuetaCriatura
## Camada da frente: linha, isca e painel de instrumentos, POR CIMA da silhueta.
var _frente: Control
var _medidor_interesse: MedidorChance
var _folha_pescador: Texture2D

## Altura do barranco acima da agua, e do leito, em pixels.
const _BARRANCO := 14.0
const _LEITO := 12.0
## Linha da folha do protagonista olhando para a direita (ver Jogador).
const _LINHA_DIREITA := 2
## Lado do quadro das mascaras de corpo, em pixels de arte (CatalogoCorpos.canvas).
const _LARGURA_MAXIMA_CORPO := 32.0


func _init() -> void:
	fonte_de_entrada = _entrada_do_mouse
	set_anchors_preset(Control.PRESET_FULL_RECT)
	# STOP: o minigame e a superficie inteira da tela enquanto roda. O clique do
	# mouse (que tambem e `usar_item`) nao vaza para o mundo atras dele.
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false

	_janela = Control.new()
	_janela.name = "Agua"
	_janela.clip_contents = true
	_janela.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_janela)

	_silhueta = SilhuetaCriatura.new()
	_silhueta.name = "Silhueta"
	_janela.add_child(_silhueta)

	_frente = Control.new()
	_frente.name = "Frente"
	_frente.set_anchors_preset(Control.PRESET_FULL_RECT)
	_frente.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frente.draw.connect(_desenhar_frente)
	add_child(_frente)

	_medidor_interesse = MedidorChance.new(20, true)
	_medidor_interesse.name = "Interesse"
	_medidor_interesse.visible = false
	_frente.add_child(_medidor_interesse)


func _ready() -> void:
	_folha_pescador = load(Jogador.FOLHA) as Texture2D
	# Respeita um iniciar() feito antes de entrar na arvore.
	set_process(_rodando)
	_calcular_layout()


func _notification(que: int) -> void:
	if que == NOTIFICATION_RESIZED:
		_calcular_layout()


## Comeca a desenhar e a jogar `sim`. `alvos` liga as faixas-alvo (tutorial ou
## cfg.mostrar_alvos). Pode ser chamado de novo para um lance novo.
func iniciar(sim: SimulacaoRecolhimento, catalogo_corpos: CatalogoCorpos, alvos: bool) -> void:
	_desligar()
	simulacao = sim
	_catalogo = catalogo_corpos
	mostrar_alvos = alvos
	_reacao = ""
	_reacao_t = 0.0
	_aviso_t = -1.0
	_relogio = 0.0
	_entrada = Vector2(1.0, 0.0)
	_silhueta.esconder()
	_medidor_interesse.visible = false
	if simulacao != null:
		simulacao.silhueta_surgiu.connect(_on_silhueta_surgiu)
		simulacao.terminou.connect(_on_terminou)
		# Silhueta forcada antes de abrir (roteiro de teste): ja entra visivel.
		if simulacao.perfil != null:
			_on_silhueta_surgiu(simulacao.perfil)
	_rodando = true
	visible = true
	# Volta a ser a superficie da tela (parar() o deixou transparente ao mouse).
	mouse_filter = Control.MOUSE_FILTER_STOP
	_calcular_layout()
	set_process(true)
	queue_redraw()


## Para de jogar e de ouvir a simulacao. O ultimo quadro continua desenhado (a
## interface pode estar no meio de um fade de saida).
func parar() -> void:
	_desligar()
	_rodando = false
	set_process(false)
	# IGNORE ja aqui, nao no fim do fade: quem chama parar() e o encerrar(), que
	# devolveu o controle ao jogador. Visivel e transparente com STOP, o quadro
	# engoliria por cfg.duracao_transicao o clique (= usar_item) do lance seguinte.
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Retangulo da agua no referencial deste Control (superficie ate o leito, da
## margem ate a borda direita do quadro).
func area_da_agua() -> Rect2:
	return _agua


func _desligar() -> void:
	if simulacao == null:
		return
	if simulacao.silhueta_surgiu.is_connected(_on_silhueta_surgiu):
		simulacao.silhueta_surgiu.disconnect(_on_silhueta_surgiu)
	if simulacao.terminou.is_connected(_on_terminou):
		simulacao.terminou.disconnect(_on_terminou)


# --- quadro a quadro --------------------------------------------------------

func _process(delta: float) -> void:
	_relogio += delta
	if _rodando and simulacao != null and simulacao.correndo():
		_entrada = _ler_entrada()
		simulacao.passo(delta, _entrada.y, _entrada.x)
	if _reacao != "":
		_reacao_t += delta
	if _aviso_t >= 0.0:
		_aviso_t += delta
		if _aviso_t > duracao_aviso_silhueta:
			_aviso_t = -1.0
	_atualizar_silhueta()
	_atualizar_interesse()
	queue_redraw()
	_frente.queue_redraw()


func _ler_entrada() -> Vector2:
	if fonte_de_entrada.is_valid():
		var v: Variant = fonte_de_entrada.call()
		if v is Vector2:
			var e: Vector2 = v
			return Vector2(clampf(e.x, 0.0, 1.0), clampf(e.y, 0.0, 1.0))
	return _entrada_do_mouse()


## Entrada padrao: x sobre o trilho de velocidade, y sobre a agua.
func _entrada_do_mouse() -> Vector2:
	var m := get_local_mouse_position()
	var x: float = 1.0
	if _trilho.size.x > 0.0:
		x = (m.x - _trilho.position.x) / _trilho.size.x
	var y: float = 0.0
	if _agua.size.y > 0.0:
		y = (m.y - _agua.position.y) / _agua.size.y
	return Vector2(clampf(x, 0.0, 1.0), clampf(y, 0.0, 1.0))


func _on_silhueta_surgiu(perfil: PerfilPesca) -> void:
	if perfil == null:
		return
	_silhueta.configurar(perfil.criatura, _catalogo)
	_silhueta.reagir(0.0)
	_silhueta.aparecer()
	_atualizar_silhueta()
	_aviso_t = 0.0
	silhueta_surgiu.emit(perfil)


func _on_terminou(desfecho: String, perfil: PerfilPesca) -> void:
	_reacao = desfecho
	_reacao_t = 0.0
	if simulacao != null:
		_afastamento_na_reacao = simulacao.afastamento_silhueta
	if desfecho == SimulacaoRecolhimento.FUGIU:
		_silhueta.sumir()
	terminou.emit(desfecho, perfil)


## Posicao da silhueta: na altura ATUAL do monstro (perfil + deriva) e com o
## focinho `afastamento` celulas atras da isca. Na reacao ao desfecho, o
## afastamento e substituido: fisgado = bote ate a isca; fugiu = disparada.
func _atualizar_silhueta() -> void:
	if simulacao == null or simulacao.perfil == null or not _silhueta.visible:
		return
	var cfg := simulacao.cfg
	var afastamento: float = simulacao.afastamento_silhueta
	match _reacao:
		SimulacaoRecolhimento.FISGADO:
			afastamento = lerpf(_afastamento_na_reacao, 0.0, clampf(_reacao_t / 0.18, 0.0, 1.0))
		SimulacaoRecolhimento.FUGIU:
			afastamento = _afastamento_na_reacao + _reacao_t * 6.0
	var isca := _posicao_isca()
	var x: float = isca.x + afastamento * _px_por_celula(cfg) + _silhueta.meia_largura()
	var y: float = _y_da_profundidade(simulacao.profundidade_monstro)
	_silhueta.position = (Vector2(x, y) - _janela.position).round()
	if cfg.interesse_alvo > 0.0:
		_silhueta.reagir(simulacao.interesse / cfg.interesse_alvo)


func _atualizar_interesse() -> void:
	var com_silhueta: bool = simulacao != null and simulacao.perfil != null \
			and _reacao != SimulacaoRecolhimento.FUGIU
	_medidor_interesse.visible = com_silhueta
	if com_silhueta and simulacao.cfg.interesse_alvo > 0.0:
		_medidor_interesse.valor = simulacao.interesse / simulacao.cfg.interesse_alvo


# --- geometria --------------------------------------------------------------

func _calcular_layout() -> void:
	var w: float = size.x
	var h: float = size.y
	_quadro = Rect2(margem, reserva_topo, maxf(w - margem * 2.0, 1.0),
			maxf(h - reserva_topo - margem, 1.0)).abs()
	_painel = Rect2(_quadro.position.x, _quadro.end.y - altura_painel,
			_quadro.size.x, altura_painel)
	_cena = Rect2(_quadro.position, Vector2(_quadro.size.x,
			maxf(_quadro.size.y - altura_painel - 4.0, 1.0)))
	var superficie: float = floorf(_cena.position.y + _cena.size.y * fracao_ceu)
	var terra: float = floorf(_cena.size.x * fracao_margem_terra)
	_agua = Rect2(_cena.position.x + terra, superficie,
			_cena.size.x - terra, maxf(_cena.end.y - _LEITO - superficie, 1.0))
	_topo_margem = superficie - _BARRANCO
	_pe_pescador = Vector2(floorf(_cena.position.x + terra * 0.45), _topo_margem)
	_trilho = Rect2(_painel.position.x + 16.0, _painel.position.y + 30.0,
			_painel.size.x - 32.0, 12.0)
	if _janela != null:
		_janela.position = _agua.position
		_janela.size = _agua.size
	if _medidor_interesse != null:
		var mlarg: float = _medidor_interesse.custom_minimum_size.x
		_medidor_interesse.position = Vector2(
				floorf(_painel.get_center().x - mlarg * 0.5 + 40.0), _painel.position.y + 9.0)
		_medidor_interesse.size = _medidor_interesse.custom_minimum_size


## Pixels de tela por celula para DISTANCIAS (afastamento da silhueta): a agua
## inteira cabe o arremesso maximo mais duas vezes o afastamento maximo.
func _px_por_celula(cfg: ConfiguracaoPesca) -> float:
	var celulas: float = cfg.distancia_max_celulas + 2.0 * maxf(cfg.silhueta_distancia_longe, 0.0)
	return _agua.size.x / maxf(celulas, 0.1)


## x da isca: fracao do trajeto entre a margem (distancia 0) e o ponto de
## partida, que deixa a direita espaco para a silhueta mais afastada.
func _posicao_isca() -> Vector2:
	if simulacao == null:
		return Vector2(_agua.end.x, _agua.position.y)
	var cfg := simulacao.cfg
	var x_fim: float = _agua.position.x + 10.0
	# A folga da direita usa o corpo MAIOR possivel (o quadro inteiro da mascara),
	# e nao o da silhueta corrente: a isca nao pode saltar de lugar quando uma
	# silhueta de outro tamanho surge.
	var x_inicio: float = _agua.end.x - (cfg.silhueta_distancia_longe * _px_por_celula(cfg)
			+ _LARGURA_MAXIMA_CORPO * _silhueta.escala_desenho + 8.0)
	x_inicio = maxf(x_inicio, x_fim + 1.0)
	var fracao: float = 0.0
	if simulacao.distancia_total > 0.0:
		fracao = clampf(simulacao.distancia / simulacao.distancia_total, 0.0, 1.0)
	return Vector2(lerpf(x_fim, x_inicio, fracao),
			_y_da_profundidade(simulacao.profundidade)).round()


func _y_da_profundidade(p: float) -> float:
	return _agua.position.y + clampf(p, 0.0, 1.0) * _agua.size.y


func _ponta_da_vara() -> Vector2:
	var mao := _pe_pescador + Vector2(4.0, -9.0) * escala_pescador
	return (mao + Vector2(0.62, -0.78) * comprimento_vara).round()


# --- desenho: fundo ---------------------------------------------------------

func _draw() -> void:
	# Veu sobre o mundo: o quadro e o assunto, mas o mundo continua la atras.
	draw_rect(Rect2(Vector2.ZERO, size), cor_veu)
	draw_style_box(TemaEncontro.moldura("painel"), _quadro.grow(8.0))
	_desenhar_ceu()
	_desenhar_agua()
	# A faixa-alvo antes da margem: o barranco a cobre, e ela fica so na agua.
	if mostrar_alvos and _com_silhueta_ativa():
		_desenhar_faixa_de_altura()
	_desenhar_margem()
	_desenhar_pescador()


func _desenhar_ceu() -> void:
	var ceu := Rect2(_cena.position, Vector2(_cena.size.x, _agua.position.y - _cena.position.y))
	# Tres faixas chapadas, e nao degrade: degrade liso denuncia a interface como
	# estranha a pixel art (mesma regra da vinheta do encontro).
	for i in 3:
		var u: float = float(i) / 3.0
		var faixa := Rect2(ceu.position.x, ceu.position.y + ceu.size.y * u,
				ceu.size.x, ceilf(ceu.size.y / 3.0))
		draw_rect(faixa, cor_ceu.lerp(cor_horizonte, u))
	# Nuvens: retangulos empilhados que andam devagar e dao a volta no quadro.
	for k in 3:
		var largura: float = 46.0 + 18.0 * float(k)
		var x: float = fposmod(float(k) * 263.0 + _relogio * (6.0 + 2.0 * float(k)),
				ceu.size.x + largura) - largura
		var y: float = ceu.position.y + 8.0 + float(k) * 11.0
		var base := Vector2(ceu.position.x + x, y).round()
		var nuvem := Color(TemaEncontro.PERG_C, 0.85)
		_retangulo_recortado(Rect2(base, Vector2(largura, 6.0)), ceu, nuvem)
		_retangulo_recortado(Rect2(base + Vector2(largura * 0.25, -4.0),
				Vector2(largura * 0.45, 4.0)), ceu, nuvem)


func _desenhar_agua() -> void:
	var n: int = maxi(faixas_de_profundidade, 1)
	var desde: float = _agua.position.y
	for i in n:
		var u: float = float(i) / float(maxi(n - 1, 1))
		var y0: float = floorf(_agua.position.y + _agua.size.y * float(i) / float(n))
		var y1: float = floorf(_agua.position.y + _agua.size.y * float(i + 1) / float(n))
		draw_rect(Rect2(_cena.position.x, y0, _cena.size.x, y1 - y0),
				cor_agua_rasa.lerp(cor_agua_funda, u))
		desde = y1
	# Leito: areia escura com pedrinhas em posicoes fixas (sem sorteio: o fundo e
	# cenario, e cenario nao consome RNG da pesca).
	var leito := Rect2(_cena.position.x, desde, _cena.size.x, _cena.end.y - desde)
	draw_rect(leito, cor_leito)
	for k in 9:
		var px: float = _agua.position.x + fposmod(float(k) * 137.0 + 31.0, maxf(_agua.size.x - 10.0, 1.0))
		var lado: float = 3.0 + float(k % 3) * 2.0
		draw_rect(Rect2(Vector2(px, leito.position.y - lado * 0.5).round(),
				Vector2(lado + 2.0, lado * 0.5 + 1.0)), cor_leito.lightened(0.18))
	# Superficie: linha clara ondulando, desenhada em degraus de 1 px.
	var pontos := PackedVector2Array()
	var passo: float = 6.0
	var x: float = _agua.position.x - _cena.size.x * fracao_margem_terra
	while x <= _agua.end.x + passo:
		var y: float = _agua.position.y + roundf(sin(x * 0.045 + _relogio * 2.2) * 1.5)
		pontos.append(Vector2(minf(x, _agua.end.x), y))
		x += passo
	draw_polyline(pontos, cor_superficie, 2.0)


func _desenhar_margem() -> void:
	var x0: float = _cena.position.x
	var borda: float = _agua.position.x
	# Barranco: topo plano, talude descendo ate o leito por dentro da agua.
	var terra := PackedVector2Array([
		Vector2(x0, _topo_margem), Vector2(borda + 4.0, _topo_margem),
		Vector2(borda + 10.0, _agua.position.y + 6.0),
		Vector2(borda + 26.0, _agua.end.y), Vector2(x0, _agua.end.y + _LEITO),
	])
	draw_colored_polygon(terra, cor_terra)
	draw_polyline(PackedVector2Array([terra[1], terra[2], terra[3]]), TemaEncontro.CONTORNO, 2.0)
	draw_rect(Rect2(x0, _topo_margem, borda + 4.0 - x0, 4.0), cor_grama)
	draw_rect(Rect2(x0, _topo_margem + 4.0, borda + 4.0 - x0, 1.0), cor_grama.darkened(0.35))


## O pescador de perfil, virado para a agua: o mesmo protagonista da exploracao
## (folha 1x, linha "direita"), ampliado em escala inteira. Sem a folha, um
## boneco de retangulos no mesmo lugar.
func _desenhar_pescador() -> void:
	var lado: float = float(Jogador.CELULA_FOLHA)
	var tam := Vector2(lado, lado) * escala_pescador
	var canto := _pe_pescador - Vector2(lado * 0.5, lado - 2.0) * escala_pescador
	if _folha_pescador != null:
		draw_texture_rect_region(_folha_pescador, Rect2(canto.round(), tam),
				Rect2(0.0, float(_LINHA_DIREITA) * lado, lado, lado))
	else:
		draw_rect(Rect2(_pe_pescador + Vector2(-6.0, -20.0) * escala_pescador,
				Vector2(12.0, 20.0) * escala_pescador), TemaEncontro.MADEIRA_C)
	# A vara: cabo grosso e escuro, ponta fina — a mesma leitura da vara na mao.
	var mao := _pe_pescador + Vector2(4.0, -9.0) * escala_pescador
	var ponta := _ponta_da_vara()
	draw_line(mao, ponta, TemaEncontro.CONTORNO, 5.0)
	draw_line(mao, mao.lerp(ponta, 0.35), TemaEncontro.MADEIRA, 3.0)
	draw_line(mao.lerp(ponta, 0.35), ponta, TemaEncontro.MADEIRA_C, 2.0)


func _desenhar_faixa_de_altura() -> void:
	var tol: float = simulacao.tolerancia_profundidade()
	var y0: float = _y_da_profundidade(simulacao.profundidade_monstro - tol)
	var y1: float = _y_da_profundidade(simulacao.profundidade_monstro + tol)
	var faixa := Rect2(_agua.position.x, floorf(y0), _agua.size.x, maxf(ceilf(y1 - y0), 1.0))
	draw_rect(faixa, cor_alvo)
	var borda := Color(cor_alvo, minf(cor_alvo.a * 3.0, 1.0))
	_tracejado(Vector2(faixa.position.x, faixa.position.y), faixa.size.x, borda)
	_tracejado(Vector2(faixa.position.x, faixa.end.y - 1.0), faixa.size.x, borda)


# --- desenho: frente (linha, isca, instrumentos) -----------------------------

func _desenhar_frente() -> void:
	if simulacao == null:
		return
	var isca := _posicao_isca()
	_desenhar_linha(_ponta_da_vara(), isca)
	_desenhar_isca(isca)
	_desenhar_painel()
	if _aviso_t >= 0.0:
		var alfa: float = clampf(minf(_aviso_t / 0.2,
				(duracao_aviso_silhueta - _aviso_t) / 0.4), 0.0, 1.0)
		var meio := Vector2(_agua.get_center().x, _cena.position.y + 22.0)
		_texto_no(_frente, simulacao.cfg.texto("silhueta_surgiu"), meio,
				Color(TemaEncontro.OURO_C, alfa), true, alfa)


## Linha da ponta da vara ate a isca: curva quadratica cuja barriga diminui com
## a velocidade — recolhendo rapido, a linha estica.
func _desenhar_linha(de: Vector2, ate: Vector2) -> void:
	var tensao: float = simulacao.velocidade if simulacao != null else 0.0
	var barriga: float = lerpf(0.18, 0.04, tensao) * de.distance_to(ate)
	var meio := (de + ate) * 0.5 + Vector2(0.0, barriga)
	var pontos := PackedVector2Array()
	for i in 17:
		var u: float = float(i) / 16.0
		pontos.append(de.lerp(meio, u).lerp(meio.lerp(ate, u), u))
	_frente.draw_polyline(pontos, cor_linha, 1.0)


func _desenhar_isca(p: Vector2) -> void:
	var cor := cor_isca
	if _reacao == SimulacaoRecolhimento.FISGADO and int(_reacao_t * 10.0) % 2 == 0:
		cor = TemaEncontro.OURO_C
	# Rastro de bolhas: tres pixels subindo atras da isca, mais vivos quanto mais
	# rapido o recolhimento. Posicoes fixas no tempo, sem sorteio.
	var vel: float = simulacao.velocidade if simulacao != null else 0.0
	for k in 3:
		var fase: float = fposmod(_relogio * (0.8 + vel) + float(k) * 0.33, 1.0)
		var b := p + Vector2(8.0 + float(k) * 7.0, -fase * 14.0)
		if b.y > _agua.position.y + 2.0:
			_frente.draw_rect(Rect2(b.round(), Vector2(2.0, 2.0)),
					Color(cor_superficie, (1.0 - fase) * (0.35 + vel * 0.5)))
	_frente.draw_circle(p, 5.0, TemaEncontro.CONTORNO)
	_frente.draw_circle(p, 3.5, cor)
	_frente.draw_rect(Rect2(p + Vector2(-1.0, -3.0), Vector2(2.0, 2.0)), TemaEncontro.PERG_C)
	# Anzol: gancho de 3 px sob a isca.
	_frente.draw_line(p + Vector2(0.0, 5.0), p + Vector2(0.0, 8.0), TemaEncontro.CONTORNO, 1.0)
	_frente.draw_line(p + Vector2(0.0, 8.0), p + Vector2(-2.0, 7.0), TemaEncontro.CONTORNO, 1.0)


## Painel de instrumentos: VELOCIDADE com o trilho (mapa do mouse x), INTERESSE
## (MedidorChance, filho da frente) e os dois selos ALTURA OK / VELOCIDADE OK.
func _desenhar_painel() -> void:
	var cfg := simulacao.cfg
	_frente.draw_style_box(TemaEncontro.moldura("painel"), _painel)
	var linha_texto: float = _painel.position.y + 19.0
	_texto_no(_frente, cfg.texto("rotulo_velocidade"),
			Vector2(_trilho.position.x, linha_texto), TemaEncontro.PERG_E, false, 1.0)

	var com_silhueta: bool = _com_silhueta_ativa()
	if _medidor_interesse.visible:
		var rotulo: String = cfg.texto("rotulo_interesse")
		var larg: float = _largura_texto(rotulo)
		_texto_no(_frente, rotulo, Vector2(_medidor_interesse.position.x - larg - 8.0,
				linha_texto), TemaEncontro.PERG_E, false, 1.0)
	if com_silhueta:
		# Selos acesos em verde, apagados em cinza — a palavra continua la quando
		# apaga, para o jogador saber QUAL das duas esta faltando.
		var ok_v: String = cfg.texto("rotulo_velocidade_ok")
		var ok_a: String = cfg.texto("rotulo_altura_ok")
		var x_v: float = _trilho.end.x - _largura_texto(ok_v)
		var x_a: float = x_v - 18.0 - _largura_texto(ok_a)
		_texto_no(_frente, ok_a, Vector2(x_a, linha_texto),
				TemaEncontro.VERDE_C if simulacao.na_altura else TemaEncontro.TEXTO_FRACO, false, 1.0)
		_texto_no(_frente, ok_v, Vector2(x_v, linha_texto),
				TemaEncontro.VERDE_C if simulacao.na_velocidade else TemaEncontro.TEXTO_FRACO, false, 1.0)
	_desenhar_trilho(com_silhueta)


## Trilho de velocidade. O marcador fica em x = 1 - velocidade: a esquerda e
## rapido, como o mouse. O preenchimento sai da DIREITA (devagar) ate o
## marcador — mais barra = mais rapido, e a ponta da barra e onde o mouse vai.
func _desenhar_trilho(com_silhueta: bool) -> void:
	var t := _trilho
	_frente.draw_rect(t.grow(2.0), TemaEncontro.CONTORNO)
	_frente.draw_rect(t, TemaEncontro.NOITE_E)
	var x_marcador: float = roundf(t.position.x + (1.0 - simulacao.velocidade) * t.size.x)
	var cheio := Rect2(x_marcador, t.position.y, t.end.x - x_marcador, t.size.y)
	_frente.draw_rect(cheio, TemaEncontro.OURO_E)
	_frente.draw_rect(Rect2(cheio.position, Vector2(cheio.size.x, 2.0)), TemaEncontro.OURO)
	if mostrar_alvos and com_silhueta:
		var tol: float = simulacao.tolerancia_velocidade()
		var xa: float = t.position.x + (1.0 - clampf(simulacao.velocidade_monstro + tol, 0.0, 1.0)) * t.size.x
		var xb: float = t.position.x + (1.0 - clampf(simulacao.velocidade_monstro - tol, 0.0, 1.0)) * t.size.x
		var faixa := Rect2(floorf(xa), t.position.y - 4.0, maxf(ceilf(xb - xa), 2.0), t.size.y + 8.0)
		_frente.draw_rect(faixa, cor_alvo)
		_frente.draw_rect(faixa, Color(cor_alvo, minf(cor_alvo.a * 3.0, 1.0)), false, 1.0)
	# Intencao (onde o mouse esta) como risco fino; o marcador cheio e a
	# velocidade de fato, que chega la com a inercia da linha.
	var x_intencao: float = roundf(t.position.x + _entrada.x * t.size.x)
	_frente.draw_rect(Rect2(x_intencao, t.position.y - 3.0, 1.0, t.size.y + 6.0),
			Color(TemaEncontro.PERG_C, 0.5))
	_frente.draw_rect(Rect2(x_marcador - 2.0, t.position.y - 4.0, 5.0, t.size.y + 8.0),
			TemaEncontro.CONTORNO)
	_frente.draw_rect(Rect2(x_marcador - 1.0, t.position.y - 3.0, 3.0, t.size.y + 6.0),
			TemaEncontro.PERG_C)


# --- apoio --------------------------------------------------------------------

func _com_silhueta_ativa() -> bool:
	return simulacao != null and simulacao.perfil != null \
			and _reacao != SimulacaoRecolhimento.FUGIU


func _largura_texto(texto: String) -> float:
	return TemaEncontro.fonte().get_string_size(texto, HORIZONTAL_ALIGNMENT_LEFT, -1,
			TemaEncontro.TAM_TEXTO).x


## Texto da fonte pixel com sombra de 1 px, desenhado no canvas `alvo`. `p` e a
## linha de base; `centrado` centraliza em x.
func _texto_no(alvo: CanvasItem, texto: String, p: Vector2, cor: Color,
		centrado: bool, alfa_sombra: float) -> void:
	var fonte := TemaEncontro.fonte()
	var x: float = p.x - (_largura_texto(texto) * 0.5 if centrado else 0.0)
	var base := Vector2(floorf(x), floorf(p.y))
	alvo.draw_string(fonte, base + Vector2(1.0, 1.0), texto, HORIZONTAL_ALIGNMENT_LEFT, -1,
			TemaEncontro.TAM_TEXTO, Color(TemaEncontro.SOMBRA, alfa_sombra))
	alvo.draw_string(fonte, base, texto, HORIZONTAL_ALIGNMENT_LEFT, -1,
			TemaEncontro.TAM_TEXTO, cor)


## Linha tracejada horizontal (borda das faixas-alvo).
func _tracejado(de: Vector2, largura: float, cor: Color) -> void:
	var x: float = 0.0
	while x < largura:
		draw_rect(Rect2(de.x + x, de.y, minf(4.0, largura - x), 1.0), cor)
		x += 7.0


## Retangulo recortado a `limite` (as nuvens nao saem do ceu).
func _retangulo_recortado(r: Rect2, limite: Rect2, cor: Color) -> void:
	var c := r.intersection(limite)
	if c.has_area():
		draw_rect(c, cor)
