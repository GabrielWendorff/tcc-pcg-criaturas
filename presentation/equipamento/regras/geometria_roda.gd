class_name GeometriaRoda
extends RefCounted

## A matematica da roda de itens, separada do desenho.
##
## Separada porque e a parte que da para errar sem ver: um slot que "pega" o
## mouse meio setor ao lado do lugar em que esta desenhado parece, na tela, um
## mouse impreciso — e ninguem desconfia da conta. Fora de Node ela e testada
## com numeros (tools/test_equipamento.gd), fronteira por fronteira, para
## n = 1..8.
##
## ANGULO DE BUSSOLA, NAO O DE Vector2.angle()
## ---------------------------------------------
## Os angulos daqui comecam em 0 no TOPO e crescem no sentido HORARIO, em
## [0, TAU). E como a roda e lida ("o primeiro item fica em cima, os outros vem
## no sentido do relogio") e e o que faz o slot 0 — "Maos livres" — ter angulo
## 0, sem um -PI/2 espalhado por quem consome. A conversao para a tela (x para a
## direita, y para BAIXO) acontece em um lugar so, `direcao_do_angulo()`.
##
## SETOR = METADE PARA CADA LADO DO SLOT
## O slot i ocupa [a_i - passo/2, a_i + passo/2). E o que faz apontar
## exatamente para o desenho do slot cair no MEIO do setor dele, e nao na
## borda — a selecao por angulo nao pode depender de o jogador mirar no
## centro do icone.


## Angulo de bussola do slot i (0 = topo, horario), em radianos, num anel de n.
## n <= 0 devolve 0: nao ha anel, e um NaN aqui viraria posicao NaN no desenho.
static func angulo_do_slot(i: int, n: int) -> float:
	if n <= 0:
		return 0.0
	return fposmod(TAU * float(i) / float(n), TAU)


## Centro do slot i relativo ao centro da roda, em pixels de tela.
static func posicao_do_slot(i: int, n: int, raio: float) -> Vector2:
	return direcao_do_angulo(angulo_do_slot(i, n)) * raio


## Slot apontado pelo vetor `v` (cursor menos centro). -1 na zona morta — e a
## zona morta que deixa o jogador abrir e fechar a roda sem trocar nada — ou
## quando nao ha slot.
static func indice_por_vetor(v: Vector2, n: int, zona_morta: float) -> int:
	if n <= 0 or v.length() < zona_morta:
		return -1
	# Vetor nulo com zona morta 0: nao ha direcao. O slot do topo e a resposta
	# menos surpreendente (e o "Maos livres").
	if v.is_zero_approx():
		return 0
	var passo: float = TAU / float(n)
	# Desloca meio setor: o setor do slot 0 vai de -passo/2 a +passo/2, e com o
	# deslocamento ele vira [0, passo), que o floor divide sem caso especial.
	var a: float = fposmod(angulo_de_vetor(v) + passo * 0.5, TAU)
	return clampi(floori(a / passo), 0, n - 1)


## Angulo de bussola de um vetor de tela (y para baixo). Topo = 0, direita =
## PI/2, baixo = PI, esquerda = 3PI/2.
static func angulo_de_vetor(v: Vector2) -> float:
	return fposmod(atan2(v.x, -v.y), TAU)


## Vetor unitario de tela para um angulo de bussola.
static func direcao_do_angulo(a: float) -> Vector2:
	return Vector2(sin(a), -cos(a))
