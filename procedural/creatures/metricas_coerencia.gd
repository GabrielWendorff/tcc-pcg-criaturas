class_name MetricasCoerencia
extends RefCounted

## RF08 — instrumentacao da coerencia semantica do bestiario. Reporta tres familias
## de medida, com propositos distintos:
##
## 1. COERENCIA POR MODA (_avaliar_moda): fracao de criaturas cujo derivado caiu no
##    valor mais provavel da sua condicional. E uma medida DESCRITIVA e, sozinha,
##    enganosa: seu valor maximo nao e 100%, e sim o teto imposto pelas proprias
##    tabelas (E[max_v P(v|primario)]). Se P(matiz=vermelho|fogo)=0.40, nenhum
##    gerador correto ultrapassa ~44% nessa dimensao — buscar 100% exigiria tabelas
##    quase degeneradas, destruindo a variedade procedural. Por isso cada dimensao
##    e reportada como observado / TETO TEORICO, e a razao entre os dois (eficiencia)
##    e que responde "o gerador esta amostrando corretamente das condicionais?".
##
## 2. INFORMACAO MUTUA (_avaliar_info_mutua): I(primario; derivado) em bits. Esta e a
##    medida que testa a HIPOTESE do trabalho (RF04). Sob sorteio independente,
##    I -> 0; sob atributos correlacionados, I > 0. Diferente da coerencia por moda,
##    nao tem teto artificial nem premia tabelas concentradas: mede quanta incerteza
##    sobre o derivado e eliminada ao conhecer o primario. Deve ser sempre lida
##    contra o baseline independente (GeradorCriaturas.Modo.INDEPENDENTE).
##
## 3. UNICIDADE (avaliar_unicidade): definicao operacional de "criatura unica" por
##    distancia de Hamming sobre o vetor de atributos, com limiar k explicito.

const LN2 := 0.6931471805599453

## k padrao: duas criaturas sao consideradas a mesma se diferem em menos de 3
## posicoes do vetor de atributos. Parametro exposto — ver avaliar_unicidade.
const K_UNICIDADE_PADRAO := 3


## Avalia um bestiario. Retorno:
## {
##   total, modo,
##   moda: {paleta|matiz|morfologia|variante: {obs, teto, razao}, por_feature, eficiencia_pct},
##   info_mutua: {"<x>->>><y>": {i_bits, i_corrigido, u, h_x, h_y, ...}},
##   unicidade: {k, distintas, isoladas, dist_media, ...}
## }
static func avaliar(bestiario: Array, tabelas: TabelasProbabilidade,
		k_unicidade: int = K_UNICIDADE_PADRAO) -> Dictionary:
	var total: int = bestiario.size()
	if total == 0:
		return {"total": 0}
	var features: Array = tabelas.features_morfologia()
	return {
		"total": total,
		"modo": bestiario[0].modo,
		"moda": _avaliar_moda(bestiario, tabelas, features),
		"info_mutua": avaliar_info_mutua(bestiario, features),
		"unicidade": avaliar_unicidade(bestiario, features, k_unicidade),
	}


# --- 1. Coerencia por moda, contra o teto teorico -------------------------

static func _avaliar_moda(bestiario: Array, tabelas: TabelasProbabilidade,
		features: Array) -> Dictionary:
	var total: int = bestiario.size()
	var paleta_ok: int = 0
	var matiz_ok: int = 0
	var feature_ok: Dictionary = {}
	for f in features:
		feature_ok[f] = 0
	var variante_ok: int = 0
	var variante_total: int = 0

	for c in bestiario:
		if c.paleta == _moda(tabelas.dist_paleta(c.elemento)):
			paleta_ok += 1
		if c.matiz == _moda(tabelas.dist_matiz(c.elemento)):
			matiz_ok += 1
		for f in features:
			var esperado: bool = tabelas.prob_feature(c.animal_base, c.elemento, f) >= 0.5
			if c.morfologia[f] == esperado:
				feature_ok[f] += 1
		for f in c.variantes:
			variante_total += 1
			if c.variantes[f] == _indice_moda(tabelas.vies_variante(f, c.elemento)):
				variante_ok += 1

	var tetos: Dictionary = _tetos_teoricos(tabelas, features)

	var por_feature: Dictionary = {}
	var soma_morf: float = 0.0
	for f in features:
		var pct: float = float(feature_ok[f]) / total
		por_feature[f] = _dimensao(pct, tetos["por_feature"][f])
		soma_morf += pct

	var r: Dictionary = {
		"paleta": _dimensao(float(paleta_ok) / total, tetos["paleta"]),
		"matiz": _dimensao(float(matiz_ok) / total, tetos["matiz"]),
		"morfologia": _dimensao(soma_morf / features.size(), tetos["morfologia"]),
		"variante": _dimensao(
			(float(variante_ok) / variante_total) if variante_total > 0 else 0.0,
			tetos["variante"]),
		"por_feature": por_feature,
	}
	# Eficiencia: quanto o gerador entrega do maximo que as tabelas permitem.
	# ~100% significa amostragem fiel as condicionais; NAO significa "tudo igual".
	var soma_razao: float = 0.0
	for dim in ["paleta", "matiz", "morfologia", "variante"]:
		soma_razao += r[dim]["razao"]
	r["eficiencia_pct"] = soma_razao / 4.0
	return r


static func _dimensao(obs: float, teto: float) -> Dictionary:
	return {"obs": obs, "teto": teto, "razao": (obs / teto) if teto > 0.0 else 0.0}


## Valor esperado da coerencia por moda sob as tabelas vigentes, calculado
## analiticamente (nao amostrado). E o limite superior de _avaliar_moda: um gerador
## perfeitamente fiel as condicionais converge para estes numeros quando n -> inf.
static func _tetos_teoricos(tabelas: TabelasProbabilidade, features: Array) -> Dictionary:
	var pe: Dictionary = tabelas.prior_elemento()
	var pa: Dictionary = tabelas.prior_animal()
	var elementos: Array = tabelas.elementos()
	var animais: Array = tabelas.animais()

	var t_paleta: float = 0.0
	var t_matiz: float = 0.0
	for e in elementos:
		t_paleta += float(pe[e]) * _maior_prob(tabelas.dist_paleta(e))
		t_matiz += float(pe[e]) * _maior_prob(tabelas.dist_matiz(e))

	# Morfologia: acerta-se a presenca esperada com prob. max(p, 1-p).
	# Variante: so conta quando a feature esta presente, entao pondera-se por p.
	var t_por_feature: Dictionary = {}
	var t_morf: float = 0.0
	var var_num: float = 0.0
	var var_den: float = 0.0
	for f in features:
		var acc: float = 0.0
		for e in elementos:
			for a in animais:
				var w: float = float(pe[e]) * float(pa[a])
				var p: float = tabelas.prob_feature(a, e, f)
				acc += w * maxf(p, 1.0 - p)
				var pesos: Array = tabelas.vies_variante(f, e)
				var soma: float = 0.0
				var maior: float = 0.0
				for x in pesos:
					soma += float(x)
					maior = maxf(maior, float(x))
				var_num += w * p * (maior / soma)
				var_den += w * p
		t_por_feature[f] = acc
		t_morf += acc

	return {
		"paleta": t_paleta,
		"matiz": t_matiz,
		"morfologia": t_morf / features.size(),
		"variante": (var_num / var_den) if var_den > 0.0 else 0.0,
		"por_feature": t_por_feature,
	}


# --- 2. Informacao mutua --------------------------------------------------

## I(primario; derivado) para os pares que sustentam a tese do trabalho.
## "cor" = par (paleta, matiz) tratado como uma unica variavel conjunta;
## "morfologia" = assinatura binaria de presenca das features (perfil completo).
##
## Custo O(n) — publica de proposito: estimar informacao mutua exige n grande
## (>=5000), regime em que avaliar() inteira sairia cara por causa da unicidade,
## que e O(n^2). Quem so precisa testar a hipotese chama esta funcao direto.
static func avaliar_info_mutua(bestiario: Array, features: Array) -> Dictionary:
	var r: Dictionary = {}
	r["elemento->paleta"] = _info_mutua(_pares(bestiario, "elemento", "paleta"))
	r["elemento->matiz"] = _info_mutua(_pares(bestiario, "elemento", "matiz"))
	r["elemento->cor"] = _info_mutua(_pares_cor(bestiario))
	r["animal->morfologia"] = _info_mutua(_pares_morfologia(bestiario, features))
	for f in features:
		r["animal->" + f] = _info_mutua(_pares_feature(bestiario, f))
	return r


## Estimador plug-in de I(X;Y) = H(X) + H(Y) - H(X,Y), em bits.
## O plug-in e enviesado para CIMA em amostras pequenas (com n=100 e muitas celulas,
## I>0 aparece mesmo sob independencia real), por isso reporta-se tambem a correcao
## de Miller-Madow e o coeficiente de incerteza U = I/H(Y), que normaliza I em [0,1]
## e se le como "fracao da incerteza do derivado explicada pelo primario".
static func _info_mutua(pares: Array) -> Dictionary:
	var n: int = pares.size()
	if n == 0:
		return {"n": 0, "i_bits": 0.0, "i_corrigido": 0.0, "u": 0.0}

	var cx: Dictionary = {}
	var cy: Dictionary = {}
	var cxy: Dictionary = {}
	for p in pares:
		var x: String = p[0]
		var y: String = p[1]
		cx[x] = cx.get(x, 0) + 1
		cy[y] = cy.get(y, 0) + 1
		var chave: String = x + "|" + y
		cxy[chave] = cxy.get(chave, 0) + 1

	var h_x: float = _entropia(cx, n)
	var h_y: float = _entropia(cy, n)
	var h_xy: float = _entropia(cxy, n)
	var i: float = h_x + h_y - h_xy
	# Miller-Madow sobre cada entropia: H_corr = H + (suporte - 1) / (2n), em nats.
	var correcao: float = float(cx.size() + cy.size() - cxy.size() - 1) / (2.0 * n * LN2)

	return {
		"n": n,
		"h_x": h_x,
		"h_y": h_y,
		"h_xy": h_xy,
		"i_bits": i,
		"i_corrigido": maxf(0.0, i + correcao),
		"u": (i / h_y) if h_y > 0.0 else 0.0,
		"suporte_x": cx.size(),
		"suporte_y": cy.size(),
		"suporte_xy": cxy.size(),
	}


static func _entropia(contagens: Dictionary, n: int) -> float:
	var h: float = 0.0
	for chave in contagens:
		var p: float = float(contagens[chave]) / n
		if p > 0.0:
			h -= p * (log(p) / LN2)
	return h


static func _pares(bestiario: Array, campo_x: String, campo_y: String) -> Array:
	var pares: Array = []
	for c in bestiario:
		pares.append([str(c.get(campo_x)), str(c.get(campo_y))])
	return pares


static func _pares_cor(bestiario: Array) -> Array:
	var pares: Array = []
	for c in bestiario:
		pares.append([c.elemento, c.paleta + "+" + c.matiz])
	return pares


static func _pares_morfologia(bestiario: Array, features: Array) -> Array:
	var pares: Array = []
	for c in bestiario:
		pares.append([c.animal_base, assinatura_morfologica(c, features)])
	return pares


static func _pares_feature(bestiario: Array, feature: String) -> Array:
	var pares: Array = []
	for c in bestiario:
		pares.append([c.animal_base, "1" if c.morfologia.get(feature, false) else "0"])
	return pares


## Perfil morfologico como string binaria ("1011"), na ordem do vocabulario.
static func assinatura_morfologica(c: Criatura, features: Array) -> String:
	var s: String = ""
	for f in features:
		s += "1" if c.morfologia.get(f, false) else "0"
	return s


# --- 3. Unicidade por distancia de Hamming --------------------------------

## Definicao operacional de "~100 criaturas unicas" (meta do trabalho).
## Duas criaturas sao consideradas DISTINTAS quando seus vetores de atributos
## diferem em pelo menos k posicoes. Reporta duas leituras:
##   - distintas: tamanho de um conjunto-cobertura guloso (representantes mutuamente
##     a distancia >= k). E a contagem conservadora de criaturas distinguiveis.
##   - isoladas: criaturas sem nenhum vizinho a distancia < k.
##
## Custo O(n^2): cada par e visitado uma unica vez. Adequado ao bestiario de jogo
## (n~100); com n na casa dos milhares leva dezenas de segundos, entao quem so
## precisa da informacao mutua deve chamar avaliar_info_mutua diretamente.
static func avaliar_unicidade(bestiario: Array, features: Array,
		k: int = K_UNICIDADE_PADRAO) -> Dictionary:
	var n: int = bestiario.size()
	if n == 0:
		return {"k": k, "distintas": 0, "isoladas": 0}

	var vetores: Array = []
	for c in bestiario:
		vetores.append(c.vetor_atributos(features))
	var dimensao: int = vetores[0].size()

	var representantes: Array = []
	var soma_dist: float = 0.0
	var num_pares: int = 0
	var dist_min: int = dimensao
	var exatos: Dictionary = {}
	# Distancia ao vizinho mais proximo, preenchida simetricamente: o par (i,j) e
	# medido uma vez e atualiza os dois lados.
	var vizinho: PackedInt32Array = PackedInt32Array()
	vizinho.resize(n)
	vizinho.fill(dimensao)

	for i in n:
		exatos["|".join(vetores[i])] = true
		for j in range(i + 1, n):
			var d: int = _hamming(vetores[i], vetores[j])
			vizinho[i] = mini(vizinho[i], d)
			vizinho[j] = mini(vizinho[j], d)
			soma_dist += d
			num_pares += 1
			dist_min = mini(dist_min, d)

		var distinta: bool = true
		for r in representantes:
			if _hamming(vetores[i], vetores[r]) < k:
				distinta = false
				break
		if distinta:
			representantes.append(i)

	var isoladas: int = 0
	for i in n:
		if vizinho[i] >= k:
			isoladas += 1

	return {
		"k": k,
		"dimensao": dimensao,
		"distintas": representantes.size(),
		"distintas_pct": float(representantes.size()) / n,
		"isoladas": isoladas,
		"isoladas_pct": float(isoladas) / n,
		"vetores_exatos": exatos.size(),
		"duplicatas_exatas": n - exatos.size(),
		"dist_media": (soma_dist / num_pares) if num_pares > 0 else 0.0,
		"dist_min": dist_min,
	}


static func _hamming(a: PackedStringArray, b: PackedStringArray) -> int:
	var d: int = 0
	for i in a.size():
		if a[i] != b[i]:
			d += 1
	return d


# --- Auxiliares -----------------------------------------------------------

## Valor mais provavel (moda) de uma distribuicao categorica.
static func _moda(dist: Dictionary) -> String:
	var melhor: String = ""
	var melhor_p: float = -1.0
	for valor in dist:
		if dist[valor] > melhor_p:
			melhor_p = dist[valor]
			melhor = valor
	return melhor


static func _maior_prob(dist: Dictionary) -> float:
	var melhor: float = 0.0
	for valor in dist:
		melhor = maxf(melhor, float(dist[valor]))
	return melhor


## Indice de maior peso num vetor de pesos (moda de variante).
static func _indice_moda(pesos: Array) -> int:
	var melhor: int = 0
	for i in pesos.size():
		if pesos[i] > pesos[melhor]:
			melhor = i
	return melhor
