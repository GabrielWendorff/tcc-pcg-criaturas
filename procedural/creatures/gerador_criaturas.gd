class_name GeradorCriaturas
extends RefCounted

## Gerador procedural da Camada 2. Aplica as regras probabilisticas condicionadas
## (RF04) de forma DETERMINISTICA a partir da seed (RF03): toda amostragem usa um
## RandomNumberGenerator explicito — nunca o estado aleatorio global.
##
## Fluxo por criatura:
##   seed -> elemento, animal_base (priors)
##        -> porte  ~ P(porte|elemento)               <- resolvido PRIMEIRO
##        -> paleta ~ P(paleta|elemento)
##        -> matiz  ~ P(matiz|elemento)
##        -> morfologia ~ P(feature|animal,elemento)  (Bernoulli)
##
## A silhueta e o par (animal_base, porte): o animal da a estrutura — quantas patas,
## onde fica a cabeca, se ha cauda — e o porte a estica no eixo compacto -> alongado.
## Juntos indexam uma das 32 mascaras de arte/corpos/ pelo body_id.
##
## O porte vem antes dos demais derivados porque e da silhueta que dependem as posicoes
## e a viabilidade dos apendices: uma garra encosta na ponta da pata, e um corpo sem
## patas nao a comporta de forma alguma. Resolver a silhueta depois dos apendices
## obrigaria a encaixa-los numa forma ja escolhida.
##
## O porte tambem e o unico atributo derivado que muda a SILHUETA, e nao a superficie:
## e por ele que o condicionamento (RF04) aparece na leitura mais imediata da criatura
## — um monstro de terra e atarracado, um de ar e esguio, antes de qualquer cor.
##
## O gerador opera em dois modos. CONDICIONADO e a proposta do trabalho. INDEPENDENTE
## e a hipotese nula usada como baseline nas metricas (RF08): amostra os derivados das
## distribuicoes MARGINAIS, produzindo um bestiario com as mesmas proporcoes globais
## de cada valor, porem sem nenhuma correlacao com os primarios. Os dois modos
## consomem o RNG na mesma ordem e na mesma quantidade, e partem dos MESMOS primarios
## para uma dada seed — logo a comparacao entre eles e pareada e a unica diferenca
## observavel e o condicionamento em si.

enum Modo { CONDICIONADO, INDEPENDENTE }

var tabelas: TabelasProbabilidade

## Usado apenas para anotar o arquetipo estrutural do corpo escolhido (dado de
## analise). O sorteio em si nao depende da arte: body_id e composto a partir dos
## atributos, entao um bestiario continua reproduzivel sem nenhum PNG carregado.
var catalogo: CatalogoCorpos


func _init(tabelas_: TabelasProbabilidade, catalogo_: CatalogoCorpos = null) -> void:
	tabelas = tabelas_
	catalogo = catalogo_ if catalogo_ != null else CatalogoCorpos.carregar(tabelas_)


## Gera o bestiario completo de um mundo. Mesma world_seed + mesmo n + mesmo modo
## => mesmo bestiario, criatura por criatura (RF03).
func gerar_bestiario(world_seed: int, quantidade: int, modo: Modo = Modo.CONDICIONADO) -> Array:
	var master := RandomNumberGenerator.new()
	master.seed = world_seed
	var bestiario: Array = []
	for i in quantidade:
		# Cada criatura recebe uma seed propria, derivada deterministicamente da
		# world_seed. Isola a amostragem de cada criatura das demais.
		var seed_individual: int = master.randi()
		bestiario.append(_gerar_uma(world_seed, seed_individual, i, modo))
	return bestiario


## Gera uma criatura isolada e reproduzivel a partir da sua seed individual.
func _gerar_uma(world_seed: int, seed_individual: int, id: int, modo: Modo = Modo.CONDICIONADO) -> Criatura:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_individual
	var condicionado: bool = modo == Modo.CONDICIONADO

	var c := Criatura.new()
	c.id = id
	c.world_seed = world_seed
	c.seed_individual = seed_individual
	c.modo = nome_do_modo(modo)

	# Primarios (ordem fixa de amostragem = determinismo). Identicos nos dois
	# modos: sao as raizes, nunca condicionadas a nada.
	c.elemento = _amostrar_categorico(rng, tabelas.prior_elemento())
	c.animal_base = _amostrar_categorico(rng, tabelas.prior_animal())

	# Porte: primeiro derivado a ser resolvido. A ESTRUTURA da silhueta segue o animal
	# nos dois modos (um "peixe" sem corpo de peixe descaracterizaria o proprio
	# primario em vez de descorrelacionar um derivado); o que o baseline descorrelaciona
	# e o porte, que e o grau de liberdade legitimamente condicionado ao elemento.
	var i_porte: int = _amostrar_indice_ponderado(rng,
		tabelas.vies_porte(c.elemento) if condicionado else tabelas.marginal_vies_porte())
	c.porte = tabelas.portes()[i_porte]
	c.body_id = CatalogoCorpos.montar_body_id(c.animal_base, i_porte, c.porte)
	if catalogo != null:
		c.arquetipo = catalogo.arquetipo(c.body_id)

	# Derivados condicionados aos primarios (RF04) — ou marginais, no baseline.
	c.paleta = _amostrar_categorico(rng,
		tabelas.dist_paleta(c.elemento) if condicionado else tabelas.marginal_paleta())
	c.matiz = _amostrar_categorico(rng,
		tabelas.dist_matiz(c.elemento) if condicionado else tabelas.marginal_matiz())

	c.morfologia = {}
	c.variantes = {}
	for feature in tabelas.features_morfologia():
		var p: float = tabelas.prob_feature(c.animal_base, c.elemento, feature) if condicionado \
			else tabelas.marginal_prob_feature(feature)
		var presente: bool = _bernoulli(rng, p)
		c.morfologia[feature] = presente
		if presente:
			# QUAL modelo tambem e condicionado ao elemento (RF04 na camada visual).
			var pesos: Array = tabelas.vies_variante(feature, c.elemento) if condicionado \
				else tabelas.marginal_vies_variante(feature)
			c.variantes[feature] = _amostrar_indice_ponderado(rng, pesos)

	return c


static func nome_do_modo(modo: Modo) -> String:
	return "condicionado" if modo == Modo.CONDICIONADO else "independente"


## Amostra um valor de uma distribuicao categorica {valor: prob} via CDF.
## Robusto a somas levemente != 1.0 (normaliza pelo total).
func _amostrar_categorico(rng: RandomNumberGenerator, dist: Dictionary) -> String:
	var total: float = 0.0
	for valor in dist:
		total += dist[valor]
	var alvo: float = rng.randf() * total
	var acumulado: float = 0.0
	var ultimo: String = ""
	for valor in dist:
		acumulado += dist[valor]
		ultimo = valor
		if alvo <= acumulado:
			return valor
	return ultimo  # fallback por erro de ponto flutuante


## Evento de Bernoulli: true com probabilidade p.
func _bernoulli(rng: RandomNumberGenerator, p: float) -> bool:
	return rng.randf() < p


## Amostra um indice em [0, pesos.size()) proporcional a pesos (nao normalizados).
func _amostrar_indice_ponderado(rng: RandomNumberGenerator, pesos: Array) -> int:
	var total: float = 0.0
	for w in pesos:
		total += w
	var alvo: float = rng.randf() * total
	var acumulado: float = 0.0
	for i in pesos.size():
		acumulado += pesos[i]
		if alvo <= acumulado:
			return i
	return pesos.size() - 1
