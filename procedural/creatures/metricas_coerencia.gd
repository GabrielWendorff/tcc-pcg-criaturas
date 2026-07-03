class_name MetricasCoerencia
extends RefCounted

## RF08 — mede o quanto os atributos derivados de cada criatura correspondem ao
## perfil ESPERADO dos seus primarios. "Esperado" = a moda da distribuicao
## condicional (paleta/matiz) ou P>=0.5 (morfologia). Quanto maior a coerencia,
## mais forte a marca da contribuicao (atributos correlacionados) frente a uma
## geracao independente/estocastica pura (No Man's Sky).

## Avalia um bestiario e retorna um relatorio agregado.
## Retorno: {
##   total, paleta_pct, matiz_pct, morfologia_pct, geral_pct,
##   por_feature: {garras: pct, ...}
## }  — todos os pct em [0.0, 1.0].
static func avaliar(bestiario: Array, tabelas: TabelasProbabilidade) -> Dictionary:
	var total: int = bestiario.size()
	if total == 0:
		return {"total": 0, "geral_pct": 0.0}

	var paleta_ok: int = 0
	var matiz_ok: int = 0
	var features: Array = tabelas.features_morfologia()
	var feature_ok: Dictionary = {}
	for f in features:
		feature_ok[f] = 0

	for c in bestiario:
		if c.paleta == _moda(tabelas.dist_paleta(c.elemento)):
			paleta_ok += 1
		if c.matiz == _moda(tabelas.dist_matiz(c.elemento)):
			matiz_ok += 1
		for f in features:
			var esperado: bool = tabelas.prob_feature(c.animal_base, c.elemento, f) >= 0.5
			if c.morfologia[f] == esperado:
				feature_ok[f] += 1

	var por_feature: Dictionary = {}
	var soma_morf: float = 0.0
	for f in features:
		var pct: float = float(feature_ok[f]) / total
		por_feature[f] = pct
		soma_morf += pct
	var morfologia_pct: float = soma_morf / features.size()

	var paleta_pct: float = float(paleta_ok) / total
	var matiz_pct: float = float(matiz_ok) / total
	# Coerencia geral: media das 3 dimensoes derivadas (paleta, matiz, morfologia).
	var geral_pct: float = (paleta_pct + matiz_pct + morfologia_pct) / 3.0

	return {
		"total": total,
		"paleta_pct": paleta_pct,
		"matiz_pct": matiz_pct,
		"morfologia_pct": morfologia_pct,
		"por_feature": por_feature,
		"geral_pct": geral_pct,
	}


## Valor mais provavel (moda) de uma distribuicao categorica.
static func _moda(dist: Dictionary) -> String:
	var melhor: String = ""
	var melhor_p: float = -1.0
	for valor in dist:
		if dist[valor] > melhor_p:
			melhor_p = dist[valor]
			melhor = valor
	return melhor
