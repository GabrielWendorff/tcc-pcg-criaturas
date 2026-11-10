class_name NotaCoerencia
extends RefCounted

## Nota de coerencia POR CRIATURA (RF08): a surpresa -log2 P(derivados | primarios), em
## bits. Quanto menor, mais a criatura se parece com o que o seu elemento e o seu animal
## fazem esperar. As metricas de MetricasCoerencia descrevem o bestiario inteiro; esta
## responde por uma criatura so, e e o que a vitrine do algoritmo mostra.
##
## E calculada das tabelas, sem sortear nada: nao consome RNG e nao altera o bestiario.
## Por isso vale medir com ela qualquer braco, inclusive o independente, contra o modelo
## da proposta. Atencao ao que ela NAO prova: mede a criatura com a mesma tabela que a
## gerou. Quem quebra essa circularidade e o teste cego do playtest.

## Piso de probabilidade: um valor impossivel sob o modelo (so ocorre ao medir o braco
## independente) custa log2(1/PISO) bits, em vez de surpresa infinita.
const PISO := 0.0001


## Para cada atributo derivado: o valor, a probabilidade sob o modelo e os bits.
## Retorno: {"linhas": [{atributo, valor, p, bits}], "bits": total}.
static func decompor(c: Criatura, tabelas: TabelasProbabilidade, v2: bool) -> Dictionary:
	var linhas: Array = []
	var pesos_porte: Array = tabelas.pesos_porte_v2(c.animal_base, c.elemento) if v2 \
			else tabelas.vies_porte(c.elemento)
	_anotar(linhas, "porte", c.porte,
			_fracao(pesos_porte, tabelas.portes().find(c.porte)))
	_anotar(linhas, "paleta", c.paleta, float(tabelas.dist_paleta(c.elemento).get(c.paleta, 0.0)))
	_anotar(linhas, "matiz", c.matiz, float(tabelas.dist_matiz(c.elemento).get(c.matiz, 0.0)))
	for f: String in tabelas.features_morfologia():
		var presente: bool = bool(c.morfologia.get(f, false))
		var p: float = tabelas.prob_feature_v2(c.animal_base, c.elemento, f, c.morfologia) if v2 \
				else tabelas.prob_feature(c.animal_base, c.elemento, f)
		_anotar(linhas, f, "sim" if presente else "não", p if presente else 1.0 - p)
		if presente:
			var i: int = int(c.variantes[f])
			_anotar(linhas, f + " (modelo)", tabelas.nome_modelo(f, i),
					_fracao(tabelas.vies_variante(f, c.elemento), i))
	var total: float = 0.0
	for linha: Dictionary in linhas:
		total += float(linha["bits"])
	return {"linhas": linhas, "bits": total}


static func surpresa(c: Criatura, tabelas: TabelasProbabilidade, v2: bool) -> float:
	return float(decompor(c, tabelas, v2)["bits"])


## O modelo em que a criatura deve ser lida na tela: a do proprio bestiario.
static func usa_v2(c: Criatura) -> bool:
	return c.modo == GeradorCriaturas.nome_do_modo(GeradorCriaturas.Modo.CONDICIONADO_V2)


static func atipica(bits: float, tabelas: TabelasProbabilidade) -> bool:
	return bits > tabelas.limiar_atipica_bits()


## {media_bits, atipicas_pct} de um bestiario.
static func resumo(bestiario: Array, tabelas: TabelasProbabilidade, v2: bool) -> Dictionary:
	var soma: float = 0.0
	var atipicas: int = 0
	for c: Criatura in bestiario:
		var bits: float = surpresa(c, tabelas, v2)
		soma += bits
		if atipica(bits, tabelas):
			atipicas += 1
	var n: int = maxi(bestiario.size(), 1)
	return {"media_bits": soma / n, "atipicas_pct": float(atipicas) / n}


static func _anotar(linhas: Array, atributo: String, valor: String, p: float) -> void:
	var efetiva: float = maxf(p, PISO)
	linhas.append({"atributo": atributo, "valor": valor, "p": efetiva,
			"bits": -log(efetiva) / MetricasCoerencia.LN2})


static func _fracao(pesos: Array, i: int) -> float:
	var total: float = 0.0
	for w: Variant in pesos:
		total += float(w)
	return float(pesos[i]) / total if total > 0.0 and i >= 0 else 0.0
