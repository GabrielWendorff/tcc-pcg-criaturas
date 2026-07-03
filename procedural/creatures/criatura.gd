class_name Criatura
extends RefCounted

## Uma criatura gerada. Estrutura de dados desacoplada da apresentacao (RF07).
## Preenchida pelo GeradorCriaturas a partir da seed; nunca sorteia nada sozinha.

# Identidade / reprodutibilidade (RF03)
var id: int = 0
var world_seed: int = 0
var seed_individual: int = 0

# Atributos primarios (raizes)
var elemento: String = ""
var animal_base: String = ""

# Atributos derivados (condicionados aos primarios) — RF04
var paleta: String = ""
var matiz: String = ""
var morfologia: Dictionary = {}  # presenca: {"garras": true, "escamas": false, ...}
var variantes: Dictionary = {}   # modelo escolhido p/ features presentes: {"garras": 2, ...}


## Lista das features morfologicas presentes (para exibicao / metricas).
func features_presentes() -> Array:
	var presentes: Array = []
	for feature in morfologia:
		if morfologia[feature]:
			presentes.append(feature)
	return presentes


## Nome legivel derivado dos primarios (RF07). Determinístico.
func nome() -> String:
	return "%s-%s #%03d" % [elemento.capitalize(), animal_base.capitalize(), id]


func _to_string() -> String:
	var feats: String = ", ".join(features_presentes())
	if feats == "":
		feats = "(nenhuma)"
	return "%s | %s/%s | paleta=%s matiz=%s | %s" % [
		nome(), elemento, animal_base, paleta, matiz, feats
	]
