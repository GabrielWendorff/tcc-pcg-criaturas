class_name BodyDef
extends Resource

## Definicao de um modelo de corpo (silhueta) — dado, nao codigo.
##
## O corpo deixou de ser um parametro do desenho para virar um ATRIBUTO da criatura,
## resolvido antes de todos os outros slots. Antes, 'animal_base' so alterava os raios
## de uma mesma elipse: todas as criaturas tinham a silhueta de um blob circular. Aqui
## a forma e descrita como uma lista de partes geometricas, o que permite que um
## quadrupede e um serpentiforme sejam estruturalmente diferentes, e nao a mesma bolha
## esticada.
##
## Coordenadas NORMALIZADAS: a criatura ocupa aproximadamente [-0.5, 0.5] nos dois
## eixos e olha para +x. A camada de apresentacao multiplica por sua propria escala,
## de modo que a silhueta e independente de resolucao (miniatura ou detalhe).

## Identificador estavel. Indexa slot_anchors e forbidden_slots em CreaturePartLibrary.
@export var id: String = ""

## Um dos 6 arquetipos: quadrupede, avial, serpentiforme, aquatico, insetoide, bipede.
## E o arquetipo — nao o animal — que governa quais slots fazem sentido anatomicamente.
@export var arquetipo: String = ""

## Nome legivel para UI e depuracao.
@export var nome: String = ""

## Peso relativo no sorteio entre os corpos do mesmo animal. Nao normalizado.
@export var peso: float = 1.0

## Partes que compoem a silhueta, cada uma um Dictionary:
##   {"tipo": "elipse",   "c": Vector2, "r": Vector2, "camada": int, "tom": float}
##   {"tipo": "poligono", "pts": PackedVector2Array,  "camada": int, "tom": float}
## camada: ordem de pintura (negativa = atras do tronco, positiva = na frente).
## tom: -1.0 escurece ate o contorno, 0.0 cor base, +1.0 clareia. Da volume sem
## exigir que a paleta seja conhecida aqui — a cor concreta entra so na apresentacao.
@export var partes: Array[Dictionary] = []


## Partes ordenadas por camada, prontas para pintura de tras para frente.
## Ordenacao estavel: partes de mesma camada mantem a ordem de declaracao, para que
## o desenho seja funcao pura do recurso (RF03 vale tambem para o visual).
func partes_ordenadas() -> Array[Dictionary]:
	# Ordena sobre (camada, indice_original) em vez de sobre os proprios dicionarios:
	# sort_custom nao garante estabilidade, e Dictionary nao serve como chave confiavel.
	var chaves: Array = []
	for i in partes.size():
		chaves.append([int(partes[i].get("camada", 0)), i])
	chaves.sort_custom(func(a, b):
		if a[0] == b[0]:
			return a[1] < b[1]
		return a[0] < b[0])
	var ordenadas: Array[Dictionary] = []
	for chave in chaves:
		ordenadas.append(partes[chave[1]])
	return ordenadas


## Caixa envolvente da silhueta, em coordenadas normalizadas. Os arquetipos tem
## extensoes bem diferentes (uma serpente e larga e baixa; um avial e alto e
## estreito), entao a apresentacao precisa disto para enquadrar cada corpo pelo seu
## proprio tamanho — do contrario os corpos longos vazam do quadro e os compactos
## ficam minusculos. Calculada sob demanda e memorizada; as partes nao mudam depois
## que o recurso e carregado.
func limites() -> Rect2:
	if _limites_cache != Rect2():
		return _limites_cache
	var minimo := Vector2.INF
	var maximo := -Vector2.INF
	for parte in partes:
		match parte.get("tipo", ""):
			"elipse":
				var c: Vector2 = parte["c"]
				var r: Vector2 = parte["r"]
				minimo = minimo.min(c - r)
				maximo = maximo.max(c + r)
			"poligono":
				for p in parte["pts"]:
					minimo = minimo.min(p)
					maximo = maximo.max(p)
	if minimo == Vector2.INF:
		return Rect2()
	_limites_cache = Rect2(minimo, maximo - minimo)
	return _limites_cache

var _limites_cache := Rect2()


func _to_string() -> String:
	return "BodyDef(%s / %s, %d partes)" % [id, arquetipo, partes.size()]
