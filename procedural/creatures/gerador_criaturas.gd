class_name GeradorCriaturas
extends RefCounted

## Gerador procedural da Camada 2. Aplica as regras probabilisticas condicionadas
## (RF04) de forma DETERMINISTICA a partir da seed (RF03): toda amostragem usa um
## RandomNumberGenerator explicito — nunca o estado aleatorio global.
##
## Fluxo por criatura:
##   seed -> elemento, animal_base (priors)
##        -> paleta ~ P(paleta|elemento)
##        -> matiz  ~ P(matiz|elemento)
##        -> morfologia ~ P(feature|animal,elemento)  (Bernoulli)

var tabelas: TabelasProbabilidade


func _init(tabelas_: TabelasProbabilidade) -> void:
	tabelas = tabelas_


## Gera o bestiario completo de um mundo. Mesma world_seed + mesmo n => mesmo
## bestiario, criatura por criatura (RF03).
func gerar_bestiario(world_seed: int, quantidade: int) -> Array:
	var master := RandomNumberGenerator.new()
	master.seed = world_seed
	var bestiario: Array = []
	for i in quantidade:
		# Cada criatura recebe uma seed propria, derivada deterministicamente da
		# world_seed. Isola a amostragem de cada criatura das demais.
		var seed_individual: int = master.randi()
		bestiario.append(_gerar_uma(world_seed, seed_individual, i))
	return bestiario


## Gera uma criatura isolada e reproduzivel a partir da sua seed individual.
func _gerar_uma(world_seed: int, seed_individual: int, id: int) -> Criatura:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_individual

	var c := Criatura.new()
	c.id = id
	c.world_seed = world_seed
	c.seed_individual = seed_individual

	# Primarios (ordem fixa de amostragem = determinismo)
	c.elemento = _amostrar_categorico(rng, tabelas.prior_elemento())
	c.animal_base = _amostrar_categorico(rng, tabelas.prior_animal())

	# Derivados condicionados aos primarios (RF04)
	c.paleta = _amostrar_categorico(rng, tabelas.dist_paleta(c.elemento))
	c.matiz = _amostrar_categorico(rng, tabelas.dist_matiz(c.elemento))

	c.morfologia = {}
	c.variantes = {}
	for feature in tabelas.features_morfologia():
		var p: float = tabelas.prob_feature(c.animal_base, c.elemento, feature)
		var presente: bool = _bernoulli(rng, p)
		c.morfologia[feature] = presente
		if presente:
			# QUAL modelo tambem e condicionado ao elemento (RF04 na camada visual).
			var pesos: Array = tabelas.vies_variante(feature, c.elemento)
			c.variantes[feature] = _amostrar_indice_ponderado(rng, pesos)

	return c


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
