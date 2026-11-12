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

##
## CONDICIONADO_V2 e um terceiro braco, e nao uma correcao da v1, que continua
## reproduzivel criatura por criatura (tools/test_gerador_v2.gd confere). Muda tres
## coisas: o bestiario e ESTRATIFICADO (todo par elemento x animal aparece), os tracos
## sao sorteados em CADEIA (cada um conhece os anteriores) e o porte depende tambem do
## animal. Nao ha busca nem rejeicao: o custo continua linear no numero de criaturas.
## Como a estratificacao troca os primarios, a comparacao v1 x v2 e por distribuicao,
## e nao criatura a criatura.

## Valores gravados em nada: o save guarda o NOME do modo (nome_do_modo).
enum Modo { CONDICIONADO, INDEPENDENTE, CONDICIONADO_V2 }

## O modelo das partidas novas. Save antigo continua no modelo em que nasceu
## (DadosPartida.modelo_gerador): o save guarda indice e seed, e nao os atributos.
const MODO_DO_JOGO := Modo.CONDICIONADO_V2

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
	if modo == Modo.CONDICIONADO_V2:
		return _gerar_bestiario_v2(world_seed, quantidade)
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
func _gerar_uma(world_seed: int, seed_individual: int, id: int,
		modo: Modo = Modo.CONDICIONADO) -> Criatura:
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


# --- Modelo v2 -------------------------------------------------------------

func _gerar_bestiario_v2(world_seed: int, quantidade: int) -> Array:
	var master := RandomNumberGenerator.new()
	master.seed = world_seed
	var pares: Array = _primarios_estratificados(master, quantidade)
	var bestiario: Array = []
	for i in pares.size():
		bestiario.append(_gerar_uma_v2(world_seed, master.randi(), i, pares[i]))
	return bestiario


## Os pares (elemento, animal) do bestiario. Cada um dos 64 entra uma vez; o que sobrar
## de `quantidade` e sorteado dos priors, e a ordem final e embaralhada para o id nao
## revelar quem veio de onde. Com menos de 64 criaturas (so ferramentas e o menu) sai
## uma amostra sem repeticao, uniforme.
func _primarios_estratificados(master: RandomNumberGenerator, quantidade: int) -> Array:
	var pares: Array = []
	for e: String in tabelas.elementos():
		for a: String in tabelas.animais():
			pares.append([e, a])
	for _i in range(pares.size(), quantidade):
		pares.append([_amostrar_categorico(master, tabelas.prior_elemento()),
				_amostrar_categorico(master, tabelas.prior_animal())])
	# Fisher-Yates com o RNG da seed: Array.shuffle() usa o estado global (RF03).
	for i in range(pares.size() - 1, 0, -1):
		var j: int = master.randi_range(0, i)
		var troca: Array = pares[i]
		pares[i] = pares[j]
		pares[j] = troca
	pares.resize(mini(pares.size(), quantidade))
	return pares


func _gerar_uma_v2(world_seed: int, seed_individual: int, id: int, par: Array) -> Criatura:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_individual

	var c := Criatura.new()
	c.id = id
	c.world_seed = world_seed
	c.seed_individual = seed_individual
	c.modo = nome_do_modo(Modo.CONDICIONADO_V2)
	c.elemento = par[0]
	c.animal_base = par[1]

	var i_porte: int = _amostrar_indice_ponderado(rng,
			tabelas.pesos_porte_v2(c.animal_base, c.elemento))
	c.porte = tabelas.portes()[i_porte]
	c.body_id = CatalogoCorpos.montar_body_id(c.animal_base, i_porte, c.porte)
	if catalogo != null:
		c.arquetipo = catalogo.arquetipo(c.body_id)

	c.paleta = _amostrar_categorico(rng, tabelas.dist_paleta(c.elemento))
	c.matiz = _amostrar_categorico(rng, tabelas.dist_matiz(c.elemento))

	# Sorteio em cadeia. A morfologia final sai na ordem do vocabulario, a mesma da v1,
	# porque ha quem percorra o dicionario.
	var sorteados: Dictionary = {}
	var variantes: Dictionary = {}
	for feature: String in tabelas.ordem_cadeia():
		var p: float = tabelas.prob_feature_v2(c.animal_base, c.elemento, feature, sorteados)
		var presente: bool = _bernoulli(rng, p)
		sorteados[feature] = presente
		if presente:
			variantes[feature] = _amostrar_indice_ponderado(rng,
					tabelas.vies_variante(feature, c.elemento))
	c.morfologia = {}
	c.variantes = {}
	for feature: String in tabelas.features_morfologia():
		c.morfologia[feature] = sorteados[feature]
		if variantes.has(feature):
			c.variantes[feature] = variantes[feature]
	return c


static func nome_do_modo(modo: Modo) -> String:
	match modo:
		Modo.CONDICIONADO:
			return "condicionado"
		Modo.CONDICIONADO_V2:
			return "condicionado_v2"
	return "independente"


## Inverso de nome_do_modo. -1 para nome desconhecido (save editado ou de versao futura).
static func modo_do_nome(nome: String) -> int:
	for m: int in Modo.values():
		if nome_do_modo(m as Modo) == nome:
			return m
	return -1


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
