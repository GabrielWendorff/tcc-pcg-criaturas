class_name SimulacaoRecolhimento
extends RefCounted

## O minigame de recolhimento INTEIRO, como regra pura: isca, silhueta, interesse
## e desfecho. Nao tem no, nao le Input, nao desenha. MinigameRecolhimento so le o
## mouse, chama passo() e desenha o estado daqui.
##
## Por que separado: o requisito de reprodutibilidade (RF03) vale tambem para a
## pesca — mesmo cfg + mesma seed + mesma sequencia de entradas => mesmo desfecho
## no mesmo tempo. Isso so e verificavel sem janela, e e o que tools/test_pesca.gd
## faz: joga o minigame com uma politica perfeita, uma errada e a do tutorial, a
## delta fixo, e confere a calibragem ("fisga em ~3 s", "foge em ~4.4 s").
##
## Entradas por quadro: alvo de profundidade (mouse Y) e x normalizado (mouse X:
## 0 = borda ESQUERDA = mais rapido, 1 = direita = mais devagar). A isca segue as
## duas por lerp exponencial — o jogador comanda a intencao, a linha tem inercia.
##
## Fisgar = manter a isca na MESMA ALTURA e na MESMA VELOCIDADE do monstro (cada uma
## dentro da sua tolerancia). O interesse sobe so com as DUAS certas e desce mais
## devagar do que sobe, para o jogador ter tempo de corrigir.
##
## RNG: todo sorteio (surgimento, roleta do monstro, fase/periodo da deriva) vem do
## `gerador` recebido, na ordem fixa documentada em passo(). Nunca o global.

signal silhueta_surgiu(perfil: PerfilPesca)
signal terminou(desfecho: String, perfil: PerfilPesca)

const FISGADO := "fisgado"
const FUGIU := "fugiu"
const RECOLHIDA := "recolhida"

## Piso do intervalo entre sorteios. So protege contra um JSON com intervalo 0, que
## travaria o laco de sorteios atrasados num unico quadro.
const _INTERVALO_MINIMO := 0.05
## Piso do periodo da deriva, contra divisao por zero com um JSON incoerente.
const _PERIODO_MINIMO := 0.1

var cfg: ConfiguracaoPesca
var modo_tutorial: bool = false
var distancia_total: float = 0.0
## Restante ate o jogador, em celulas do chao.
var distancia: float = 0.0
## Isca, 0 (superficie) .. 1 (fundo).
var profundidade: float = 0.0
## Normalizada, 0 = devagar .. 1 = rapido.
var velocidade: float = 0.0
## Celulas/s.
var velocidade_real: float = 0.0
var tempo: float = 0.0
## Silhueta ativa (null = nenhuma).
var perfil: PerfilPesca = null
## Posicao ATUAL do monstro (perfil + deriva), na mesma escala da isca.
var profundidade_monstro: float = 0.0
var velocidade_monstro: float = 0.0
var interesse: float = 0.0
var na_altura: bool = false
var na_velocidade: bool = false
## Celulas atras da isca, ja suavizado — e so visual.
var afastamento_silhueta: float = 0.0
## "" enquanto corre; FISGADO, FUGIU ou RECOLHIDA depois.
var desfecho: String = ""

## Multiplica `cfg.chance_surgimento` (o `multiplicador_surgimento` do PontoDePesca).
## Fora do construtor para nao mudar a assinatura do contrato: quem cria a
## simulacao atribui logo depois. 1.0 = chance da configuracao, sem ajuste.
var multiplicador_surgimento: float = 1.0
## Valor de `tempo` em que a silhueta surgiu; -1 enquanto nao surgiu. A interface
## usa para animar a entrada; o teste, para medir quanto a fisgada levou.
var tempo_surgimento: float = -1.0

var _candidatos: Array = []
var _rng: RandomNumberGenerator
var _perfil_tutorial: PerfilPesca = null
var _proximo_sorteio: float = 0.0
var _fase_profundidade: float = 0.0
var _periodo_profundidade: float = 1.0
var _fase_velocidade: float = 0.0
var _periodo_velocidade: float = 1.0


## `candidatos`: saida de PontoDePesca.candidatos(). `gerador`: o RNG da pesca,
## ja semeado — a simulacao consome dele e nao o re-semeia, entao arremessos
## seguidos continuam a mesma sequencia da seed do mundo.
func _init(config: ConfiguracaoPesca, distancia_inicial: float, candidatos: Array,
		gerador: RandomNumberGenerator, tutorial: bool = false,
		perfil_tutorial: PerfilPesca = null) -> void:
	cfg = config if config != null else ConfiguracaoPesca.new()
	if gerador == null:
		# Sem RNG nao ha como sortear sem o estado global; uma seed fixa mantem a
		# reprodutibilidade e o aviso aponta o erro de quem chamou.
		push_warning("SimulacaoRecolhimento: gerador null, usando seed 0")
		gerador = RandomNumberGenerator.new()
		gerador.seed = 0
	_rng = gerador
	modo_tutorial = tutorial
	_perfil_tutorial = perfil_tutorial
	_candidatos = candidatos.duplicate()
	distancia_total = maxf(distancia_inicial, 0.0)
	distancia = distancia_total
	profundidade = clampf(cfg.profundidade_inicial, cfg.profundidade_min, cfg.profundidade_max)
	velocidade = 0.0
	velocidade_real = cfg.velocidade_real(velocidade)
	afastamento_silhueta = cfg.silhueta_distancia_longe
	_proximo_sorteio = cfg.atraso_minimo_surgimento


## Avanca a simulacao um quadro. Ordem FIXA (e parte da especificacao, RF03):
##   1. terminou? nada muda.
##   2. tempo += delta
##   3. profundidade da isca -> alvo (preso a [min, max]) por lerp exponencial
##   4. velocidade -> 1 - x por lerp exponencial; velocidade_real em celulas/s
##   5. distancia -= velocidade_real * delta
##   6. sem silhueta: tutorial => surge a de ensino no tempo fixo; normal => um
##      sorteio a cada intervalo (1 randf contra a chance, e a roleta se passar)
##   7. com silhueta: deriva, na_altura/na_velocidade, interesse; alvo => FISGADO,
##      zero => FUGIU; afastamento visual
##   8. fim do trajeto: tutorial prende a isca antes do fim; normal => RECOLHIDA
## Fisgar (7) vem antes de recolher (8): no quadro em que as duas coisas
## acontecem, o jogador que acertou nao perde o monstro por um quadro.
func passo(delta: float, alvo_profundidade: float, x_normalizado: float) -> void:
	if desfecho != "":
		return
	delta = maxf(delta, 0.0)
	tempo += delta

	var alvo_p: float = clampf(alvo_profundidade, cfg.profundidade_min, cfg.profundidade_max)
	profundidade = lerpf(profundidade, alvo_p, _fator(cfg.suavidade_profundidade, delta))
	var alvo_v: float = 1.0 - clampf(x_normalizado, 0.0, 1.0)
	velocidade = lerpf(velocidade, alvo_v, _fator(cfg.suavidade_velocidade, delta))
	velocidade_real = cfg.velocidade_real(velocidade)

	distancia -= velocidade_real * delta

	if perfil == null:
		_tentar_surgir()
	if perfil != null:
		_perseguir(delta)
		if desfecho != "":
			return

	if modo_tutorial:
		distancia = maxf(distancia, cfg.tutorial_distancia_minima)
	elif distancia <= 0.0:
		distancia = 0.0
		_terminar(RECOLHIDA)


func correndo() -> bool:
	return desfecho == ""


## Tolerancia de altura EFETIVA (a do perfil, alargada no tutorial). 0 sem silhueta.
func tolerancia_profundidade() -> float:
	if perfil == null:
		return 0.0
	return perfil.tolerancia_profundidade * _multiplicador_tolerancia()


func tolerancia_velocidade() -> float:
	if perfil == null:
		return 0.0
	return perfil.tolerancia_velocidade * _multiplicador_tolerancia()


## Faz a silhueta `p` surgir agora, sem sorteio (testes, roteiros). Consome do RNG
## so a deriva, como um surgimento normal. Ignorado depois do desfecho.
func forcar_silhueta(p: PerfilPesca) -> void:
	if desfecho != "" or p == null:
		return
	_surgir(p)


func _tentar_surgir() -> void:
	if modo_tutorial:
		# Tutorial nao sorteia: o monstro de ensino surge num tempo fixo, para a
		# dica da tela sempre corresponder ao que o jogador ve.
		if tempo >= cfg.tutorial_tempo_ate_silhueta:
			var p: PerfilPesca = _perfil_tutorial
			if p == null:
				p = PontoDePesca.mais_facil(_candidatos)
			if p != null:
				_surgir(p)
		return
	# `while`, e nao `if`: um quadro longo (engasgo) que cruza dois instantes de
	# sorteio faz os dois, e a taxa de surgimento nao depende da taxa de quadros.
	while tempo >= _proximo_sorteio:
		_proximo_sorteio += maxf(cfg.intervalo_surgimento, _INTERVALO_MINIMO)
		# Sem candidato o intervalo passa sem consumir o rng: um ponto vazio gasta
		# MENOS numeros que um com candidatos (docs/mudancas-estruturais.md).
		if distancia <= cfg.distancia_minima_para_surgir or _candidatos.is_empty():
			continue
		if _rng.randf() < cfg.chance_surgimento * multiplicador_surgimento:
			var sorteado := PontoDePesca.sortear(_candidatos, _rng)
			if sorteado != null:
				_surgir(sorteado)
				return


func _surgir(p: PerfilPesca) -> void:
	perfil = p
	tempo_surgimento = tempo
	interesse = cfg.interesse_inicial
	afastamento_silhueta = cfg.silhueta_distancia_longe
	# Fase e periodo da deriva, nesta ordem, SEMPRE sorteados — mesmo no tutorial ou
	# com a deriva desligada. Assim ligar/desligar a deriva muda o movimento, mas
	# nao QUAIS monstros surgem nos arremessos seguintes da mesma seed.
	_fase_profundidade = _rng.randf() * TAU
	_periodo_profundidade = _rng.randf_range(cfg.deriva_periodo_min, cfg.deriva_periodo_max)
	_fase_velocidade = _rng.randf() * TAU
	_periodo_velocidade = _rng.randf_range(cfg.deriva_periodo_min, cfg.deriva_periodo_max)
	_atualizar_monstro()
	na_altura = false
	na_velocidade = false
	silhueta_surgiu.emit(p)


## Posicao atual do monstro: o perfil mais a deriva senoidal. Presa a faixa util
## da isca — um monstro numa altura que a isca nao alcanca seria impossivel de
## fisgar por construcao, nao por habilidade.
func _atualizar_monstro() -> void:
	var dp: float = 0.0
	var dv: float = 0.0
	if cfg.deriva_ativa and not modo_tutorial:
		var t: float = tempo - tempo_surgimento
		dp = cfg.deriva_amplitude_profundidade * sin(
				TAU * t / maxf(_periodo_profundidade, _PERIODO_MINIMO) + _fase_profundidade)
		dv = cfg.deriva_amplitude_velocidade * sin(
				TAU * t / maxf(_periodo_velocidade, _PERIODO_MINIMO) + _fase_velocidade)
	profundidade_monstro = clampf(perfil.profundidade + dp,
			cfg.profundidade_min, cfg.profundidade_max)
	velocidade_monstro = clampf(perfil.velocidade + dv, 0.0, 1.0)


func _perseguir(delta: float) -> void:
	_atualizar_monstro()
	na_altura = absf(profundidade - profundidade_monstro) <= tolerancia_profundidade()
	na_velocidade = absf(velocidade - velocidade_monstro) <= tolerancia_velocidade()

	if na_altura and na_velocidade:
		interesse += cfg.interesse_ganho * delta
	else:
		interesse -= (cfg.tutorial_perda if modo_tutorial else cfg.interesse_perda) * delta
	if modo_tutorial:
		# O tutorial PROMETE a fisgada (requisito). O piso e a garantia: nenhum
		# numero de calibragem faz o monstro de ensino desistir.
		interesse = maxf(interesse, maxf(cfg.tutorial_interesse_minimo, 0.0))
	interesse = clampf(interesse, 0.0, cfg.interesse_alvo)

	var fracao: float = interesse / cfg.interesse_alvo if cfg.interesse_alvo > 0.0 else 0.0
	var alvo_afastamento: float = lerpf(cfg.silhueta_distancia_longe,
			cfg.silhueta_distancia_perto, fracao)
	afastamento_silhueta = lerpf(afastamento_silhueta, alvo_afastamento,
			_fator(cfg.silhueta_suavidade, delta))

	if interesse >= cfg.interesse_alvo:
		_terminar(FISGADO)
	elif interesse <= 0.0 and not modo_tutorial:
		_terminar(FUGIU)


## Unico ponto que encerra: `desfecho` deixa de ser "" e o passo() seguinte
## retorna no item 1 — por isso `terminou` sai uma unica vez.
func _terminar(d: String) -> void:
	desfecho = d
	terminou.emit(d, perfil)


func _multiplicador_tolerancia() -> float:
	return cfg.tutorial_multiplicador_tolerancia if modo_tutorial else 1.0


## Fator do lerp exponencial: 1 - exp(-k*delta). Independe da taxa de quadros —
## dois quadros de 1/120 s chegam no mesmo lugar que um de 1/60 s.
static func _fator(k: float, delta: float) -> float:
	if k <= 0.0:
		return 1.0
	return 1.0 - exp(-k * delta)
