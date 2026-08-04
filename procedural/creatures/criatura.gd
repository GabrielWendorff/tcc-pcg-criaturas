class_name Criatura
extends RefCounted

## Uma criatura gerada. Estrutura de dados desacoplada da apresentacao (RF07).
## Preenchida pelo GeradorCriaturas a partir da seed; nunca sorteia nada sozinha.

# Identidade / reprodutibilidade (RF03)
var id: int = 0
var world_seed: int = 0
var seed_individual: int = 0
var modo: String = "condicionado"  # "condicionado" (proposta) ou "independente" (baseline)

# Atributos primarios (raizes)
var elemento: String = ""
var animal_base: String = ""

# Silhueta: primeiro derivado, condicionado ao animal. Governa onde os apendices
# nascem e quais deles sao anatomicamente possiveis.
var body_id: String = ""
var arquetipo: String = ""

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


## Vetor categorico canonico da criatura, base da distancia de Hamming que define
## operacionalmente "criatura unica". Tamanho FIXO: features ausentes ocupam suas
## posicoes com "0"/"-", para que duas criaturas sejam sempre comparaveis posicao a
## posicao. A ordem de 'features' deve vir do vocabulario, nunca de um Dictionary.
func vetor_atributos(features: Array) -> PackedStringArray:
	var v := PackedStringArray([elemento, animal_base, body_id, paleta, matiz])
	for f in features:
		var presente: bool = morfologia.get(f, false)
		v.append("1" if presente else "0")
		v.append(str(variantes[f]) if presente else "-")
	return v


## Representacao serializavel (exportacao JSON para analise externa — RF08).
func to_dict() -> Dictionary:
	return {
		"id": id,
		"world_seed": world_seed,
		"seed_individual": seed_individual,
		"modo": modo,
		"nome": nome(),
		"elemento": elemento,
		"animal_base": animal_base,
		"body_id": body_id,
		"arquetipo": arquetipo,
		"paleta": paleta,
		"matiz": matiz,
		"morfologia": morfologia,
		"variantes": variantes,
	}


func _to_string() -> String:
	var feats: String = ", ".join(features_presentes())
	if feats == "":
		feats = "(nenhuma)"
	return "%s | %s/%s [%s] | paleta=%s matiz=%s | %s" % [
		nome(), elemento, animal_base, body_id, paleta, matiz, feats
	]
