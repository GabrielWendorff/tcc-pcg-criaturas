class_name CreaturePartLibrary
extends Resource

## Biblioteca de partes: catalogo dos corpos disponiveis e de onde cada apendice
## nasce em cada um deles. E o recurso de dados que sustenta a Fase 1 — a silhueta
## como variavel de primeira classe.
##
## Antes, as posicoes de garras, asas e nadadeiras eram fracoes fixas do tamanho do
## quadro, iguais para os 8 animais: uma asa nascia no mesmo ponto num peixe e numa
## ave. Aqui cada corpo declara suas proprias ancoras, entao o apendice acompanha a
## anatomia do arquetipo.
##
## Carregado de res://data/part_library.tres (versionado). Regeravel por
## tools/gerar_part_library.gd, que e a fonte de calibracao — o .tres e o dado.

const CAMINHO_PADRAO := "res://data/part_library.tres"

## animal_base -> Array[BodyDef]. Um animal pode ter varios corpos possiveis
## (P(corpo | animal) — o condicionamento comeca ja na silhueta).
@export var body_archetypes: Dictionary = {}

## body_id -> {slot_name: Vector2}. Ponto de origem de cada apendice, em coordenadas
## normalizadas do corpo (mesmo espaco de BodyDef.partes).
@export var slot_anchors: Dictionary = {}

## body_id -> Array[String]. Slots anatomicamente impossiveis neste corpo.
## Declarado aqui na Fase 1; a aplicacao como veto pre-amostragem entra na Fase 2.
@export var forbidden_slots: Dictionary = {}


static func carregar(caminho: String = CAMINHO_PADRAO) -> CreaturePartLibrary:
	if not ResourceLoader.exists(caminho):
		push_error("CreaturePartLibrary: recurso inexistente — " + caminho)
		return null
	var lib: Resource = load(caminho)
	if lib == null or not (lib is CreaturePartLibrary):
		push_error("CreaturePartLibrary: recurso invalido — " + caminho)
		return null
	return lib


## Corpos possiveis para um animal. Array vazio se o animal nao esta mapeado.
func corpos_de(animal: String) -> Array:
	var corpos: Variant = body_archetypes.get(animal, [])
	return corpos if corpos is Array else []


## Pesos de sorteio dos corpos de um animal, na mesma ordem de corpos_de().
func pesos_de(animal: String) -> Array:
	var pesos: Array = []
	for corpo in corpos_de(animal):
		pesos.append(corpo.peso)
	return pesos


func corpo_por_id(body_id: String) -> BodyDef:
	for animal in body_archetypes:
		for corpo in corpos_de(animal):
			if corpo.id == body_id:
				return corpo
	return null


## Ancora de um slot neste corpo. Vector2.ZERO quando nao declarada — o chamador
## trata como "sem posicao propria", nunca como "centro do corpo por acaso".
func ancora(body_id: String, slot: String) -> Vector2:
	var mapa: Dictionary = slot_anchors.get(body_id, {})
	return mapa.get(slot, Vector2.ZERO)


func tem_ancora(body_id: String, slot: String) -> bool:
	return slot_anchors.get(body_id, {}).has(slot)


## Slots vetados neste corpo por impossibilidade anatomica (usado na Fase 2).
func slots_proibidos(body_id: String) -> Array:
	return forbidden_slots.get(body_id, [])


func slot_proibido(body_id: String, slot: String) -> bool:
	return slot in slots_proibidos(body_id)


## Lista plana de todos os corpos, para validacao e ferramentas.
func todos_os_corpos() -> Array:
	var todos: Array = []
	for animal in body_archetypes:
		for corpo in corpos_de(animal):
			todos.append(corpo)
	return todos


## Conjunto de arquetipos efetivamente usados.
func arquetipos() -> Array:
	var vistos: Dictionary = {}
	for corpo in todos_os_corpos():
		vistos[corpo.arquetipo] = true
	return vistos.keys()
