extends SceneTree

## Constroi res://data/part_library.tres — a biblioteca de corpos e ancoras.
##
##   godot --headless -s res://tools/gerar_part_library.gd
##
## O .tres gerado e o DADO versionado; este script e a fonte de calibracao, no mesmo
## papel que tools/validate_tables.py tem para as tabelas de probabilidade. Editar as
## silhuetas significa mexer aqui e regerar, nunca escrever geometria no renderer.
##
## Espaco de coordenadas: criatura inscrita em ~[-0.5, 0.5], olhando para +x.
## camada < 0 pinta atras do tronco, camada > 0 na frente.
## tom: -1 escuro, 0 cor base, +1 claro.

const DESTINO := "res://data/part_library.tres"


func _initialize() -> void:
	var lib := CreaturePartLibrary.new()
	var corpos: Array[BodyDef] = []
	corpos.append_array(_quadrupedes())
	corpos.append_array(_aviais())
	corpos.append_array(_serpentiformes())
	corpos.append_array(_aquaticos())
	corpos.append_array(_insetoides())
	corpos.append_array(_bipedes())

	# animal_base -> corpos possiveis. Um mesmo arquetipo serve animais diferentes
	# (gato e canino sao quadrupedes), e um mesmo animal pode ter mais de uma
	# silhueta — e o primeiro ponto onde o condicionamento atua: P(corpo | animal).
	var mapa := {
		"gato": ["quad_felino"],
		"canino": ["quad_canino"],
		"roedor": ["quad_roedor", "bipede_roedor"],
		"ave": ["avial_passeriforme", "avial_rapina"],
		"reptil": ["serp_lagarto", "serp_serpente"],
		"peixe": ["aqua_fusiforme", "aqua_anguiliforme"],
		"anfibio": ["bipede_anuro", "aqua_girino"],
		"inseto": ["inseto_alado", "inseto_terrestre"],
	}

	var por_id: Dictionary = {}
	for corpo in corpos:
		por_id[corpo.id] = corpo

	for animal in mapa:
		var lista: Array[BodyDef] = []
		for body_id in mapa[animal]:
			if not por_id.has(body_id):
				printerr("corpo inexistente no mapeamento: ", body_id)
				quit(1)
				return
			lista.append(por_id[body_id])
		lib.body_archetypes[animal] = lista

	lib.slot_anchors = _ancoras()
	lib.forbidden_slots = _proibicoes()

	var erro := _validar(lib, corpos)
	if erro != "":
		printerr("Biblioteca invalida: ", erro)
		quit(1)
		return

	var res := ResourceSaver.save(lib, DESTINO)
	if res != OK:
		printerr("Falha ao salvar ", DESTINO, " (erro ", res, ")")
		quit(1)
		return

	print("Biblioteca gerada: ", DESTINO)
	print("  corpos: %d | arquetipos: %d | animais mapeados: %d" % [
		corpos.size(), lib.arquetipos().size(), lib.body_archetypes.size()])
	for corpo in corpos:
		print("    %-22s %-14s %2d partes  proibidos: %s" % [
			corpo.id, corpo.arquetipo, corpo.partes.size(),
			", ".join(lib.slots_proibidos(corpo.id)) if not lib.slots_proibidos(corpo.id).is_empty() else "-",
		])
	quit(0)


# --- Primitivas de construcao --------------------------------------------

func _elipse(c: Vector2, r: Vector2, camada: int, tom: float = 0.0) -> Dictionary:
	return {"tipo": "elipse", "c": c, "r": r, "camada": camada, "tom": tom}


func _poli(pts: Array, camada: int, tom: float = 0.0) -> Dictionary:
	return {"tipo": "poligono", "pts": PackedVector2Array(pts), "camada": camada, "tom": tom}


func _corpo(id: String, arquetipo: String, nome: String, partes: Array,
		peso: float = 1.0) -> BodyDef:
	var b := BodyDef.new()
	b.id = id
	b.arquetipo = arquetipo
	b.nome = nome
	b.peso = peso
	var tipadas: Array[Dictionary] = []
	tipadas.assign(partes)
	b.partes = tipadas
	return b


## Quatro patas ao longo do tronco, alternando tom para sugerir profundidade
## (as duas de tras mais escuras).
func _patas(xs: Array, y: float, r: Vector2) -> Array:
	var partes: Array = []
	for i in xs.size():
		var atras: bool = i % 2 == 0
		partes.append(_elipse(Vector2(xs[i], y), r, -1 if atras else 1, -0.55 if atras else -0.2))
	return partes


# --- Arquetipo 1: quadrupede ---------------------------------------------

func _quadrupedes() -> Array[BodyDef]:
	var felino: Array = []
	felino.append_array(_patas([-0.16, -0.09, 0.10, 0.17], 0.20, Vector2(0.035, 0.10)))
	felino.append(_poli([Vector2(-0.24, 0.02), Vector2(-0.40, -0.16),
		Vector2(-0.44, -0.10), Vector2(-0.26, 0.10)], -1, -0.45))          # cauda longa
	felino.append(_elipse(Vector2(-0.02, 0.02), Vector2(0.24, 0.14), 0))    # tronco esguio
	felino.append(_elipse(Vector2(0.23, -0.08), Vector2(0.12, 0.11), 2))    # cabeca
	felino.append(_poli([Vector2(0.14, -0.16), Vector2(0.17, -0.30),
		Vector2(0.23, -0.17)], 2, -0.25))                                   # orelha esq
	felino.append(_poli([Vector2(0.26, -0.17), Vector2(0.32, -0.29),
		Vector2(0.33, -0.15)], 2, -0.25))                                   # orelha dir

	var canino: Array = []
	canino.append_array(_patas([-0.17, -0.10, 0.09, 0.16], 0.21, Vector2(0.042, 0.11)))
	canino.append(_poli([Vector2(-0.25, -0.02), Vector2(-0.38, -0.14),
		Vector2(-0.36, -0.02)], -1, -0.45))                                 # cauda curta
	canino.append(_elipse(Vector2(-0.02, 0.02), Vector2(0.26, 0.15), 0))    # tronco robusto
	canino.append(_elipse(Vector2(0.24, -0.07), Vector2(0.13, 0.12), 2))
	canino.append(_elipse(Vector2(0.36, 0.00), Vector2(0.07, 0.06), 2, -0.15))  # focinho
	# Camada 1: a orelha caida fica ATRAS da cabeca (camada 2). Na frente ela
	# encobria o rosto e o olho parecia nascer sobre uma protuberancia.
	canino.append(_poli([Vector2(0.15, -0.19), Vector2(0.11, -0.03),
		Vector2(0.22, -0.17)], 1, -0.5))                                    # orelha caida
	canino.append(_poli([Vector2(0.27, -0.19), Vector2(0.32, -0.04),
		Vector2(0.34, -0.16)], 1, -0.5))

	var roedor: Array = []
	roedor.append_array(_patas([-0.11, -0.05, 0.08, 0.13], 0.19, Vector2(0.032, 0.08)))
	roedor.append(_poli([Vector2(-0.18, 0.00), Vector2(-0.34, 0.06),
		Vector2(-0.19, 0.08)], -1, -0.45))
	roedor.append(_elipse(Vector2(-0.01, 0.04), Vector2(0.20, 0.15), 0))    # tronco atarracado
	roedor.append(_elipse(Vector2(0.20, -0.04), Vector2(0.12, 0.11), 2))
	roedor.append(_elipse(Vector2(0.14, -0.17), Vector2(0.065, 0.07), 1, -0.3))  # orelha redonda
	roedor.append(_elipse(Vector2(0.28, -0.16), Vector2(0.065, 0.07), 1, -0.3))

	var lista: Array[BodyDef] = []
	lista.append(_corpo("quad_felino", "quadrupede", "felino", felino))
	lista.append(_corpo("quad_canino", "quadrupede", "canino", canino))
	lista.append(_corpo("quad_roedor", "quadrupede", "roedor", roedor))
	return lista


# --- Arquetipo 2: avial ---------------------------------------------------

func _aviais() -> Array[BodyDef]:
	var passeriforme: Array = []
	passeriforme.append(_poli([Vector2(-0.14, 0.02), Vector2(-0.40, -0.10),
		Vector2(-0.38, 0.06), Vector2(-0.16, 0.12)], -1, -0.45))            # cauda em leque
	passeriforme.append(_elipse(Vector2(0.00, 0.04), Vector2(0.19, 0.21), 0))  # corpo vertical
	passeriforme.append(_elipse(Vector2(0.13, -0.19), Vector2(0.12, 0.11), 2))  # cabeca alta
	passeriforme.append(_poli([Vector2(0.24, -0.21), Vector2(0.38, -0.16),
		Vector2(0.24, -0.12)], 3, -0.1))                                    # bico curto
	passeriforme.append(_poli([Vector2(-0.03, 0.24), Vector2(-0.05, 0.36),
		Vector2(0.02, 0.36), Vector2(0.02, 0.24)], 1, -0.5))                # pernas finas
	passeriforme.append(_poli([Vector2(0.08, 0.24), Vector2(0.07, 0.36),
		Vector2(0.14, 0.36), Vector2(0.13, 0.24)], 1, -0.5))

	var rapina: Array = []
	rapina.append(_poli([Vector2(-0.16, -0.02), Vector2(-0.42, -0.14),
		Vector2(-0.44, 0.04), Vector2(-0.18, 0.10)], -1, -0.45))
	rapina.append(_elipse(Vector2(-0.01, 0.02), Vector2(0.22, 0.23), 0))    # peito largo
	rapina.append(_elipse(Vector2(0.16, -0.20), Vector2(0.13, 0.12), 2))
	rapina.append(_poli([Vector2(0.27, -0.24), Vector2(0.42, -0.19),
		Vector2(0.36, -0.08), Vector2(0.27, -0.13)], 3, -0.1))              # bico curvo
	rapina.append(_poli([Vector2(-0.04, 0.24), Vector2(-0.07, 0.36),
		Vector2(0.03, 0.36), Vector2(0.03, 0.24)], 1, -0.5))
	rapina.append(_poli([Vector2(0.10, 0.24), Vector2(0.09, 0.36),
		Vector2(0.18, 0.36), Vector2(0.16, 0.24)], 1, -0.5))

	var lista: Array[BodyDef] = []
	lista.append(_corpo("avial_passeriforme", "avial", "passeriforme", passeriforme, 1.2))
	lista.append(_corpo("avial_rapina", "avial", "rapina", rapina, 0.8))
	return lista


# --- Arquetipo 3: serpentiforme ------------------------------------------

func _serpentiformes() -> Array[BodyDef]:
	# Cadeia de segmentos decrescentes ao longo de uma senoide: a silhueta nasce da
	# repeticao, nao de uma elipse unica.
	var lagarto: Array = []
	for i in 7:
		var t: float = i / 6.0
		var x: float = lerpf(-0.40, 0.16, t)
		var y: float = sin(t * PI * 1.4) * 0.05 + 0.06
		var raio: float = lerpf(0.045, 0.13, t)
		lagarto.append(_elipse(Vector2(x, y), Vector2(raio * 1.15, raio), 0, -0.1 * (1.0 - t)))
	lagarto.append_array(_patas([-0.18, -0.12, 0.02, 0.08], 0.20, Vector2(0.03, 0.075)))
	lagarto.append(_elipse(Vector2(0.28, 0.00), Vector2(0.14, 0.10), 2))    # cabeca alongada
	lagarto.append(_poli([Vector2(0.36, 0.02), Vector2(0.44, 0.04),
		Vector2(0.36, 0.07)], 2, -0.2))                                     # focinho

	# 14 segmentos com raio minimo maior que o meio-passo: e a sobreposicao entre
	# eles que forma um corpo continuo. Com raios pequenos demais a silhueta virava
	# um colar de bolinhas soltas.
	var serpente: Array = []
	for i in 14:
		var t: float = i / 13.0
		var x: float = lerpf(-0.42, 0.20, t)
		var y: float = sin(t * PI * 2.2) * 0.12
		var raio: float = lerpf(0.055, 0.115, t)
		serpente.append(_elipse(Vector2(x, y), Vector2(raio, raio), 0, -0.12 * (1.0 - t)))
	serpente.append(_elipse(Vector2(0.28, sin(PI * 2.2) * 0.12), Vector2(0.13, 0.095), 2))
	serpente.append(_poli([Vector2(0.36, 0.01), Vector2(0.46, 0.03),
		Vector2(0.36, 0.05)], 1, -0.3))                                     # lingua

	var lista: Array[BodyDef] = []
	lista.append(_corpo("serp_lagarto", "serpentiforme", "lagarto", lagarto, 1.3))
	lista.append(_corpo("serp_serpente", "serpentiforme", "serpente", serpente, 0.7))
	return lista


# --- Arquetipo 4: aquatico ------------------------------------------------

func _aquaticos() -> Array[BodyDef]:
	var fusiforme: Array = []
	fusiforme.append(_poli([Vector2(-0.22, 0.00), Vector2(-0.44, -0.16),
		Vector2(-0.38, 0.00), Vector2(-0.44, 0.16)], -1, -0.4))             # cauda bifurcada
	# Corpo em losango suavizado: nem circulo, nem elipse — perfil hidrodinamico.
	fusiforme.append(_poli([
		Vector2(0.38, 0.00), Vector2(0.26, -0.13), Vector2(0.06, -0.19),
		Vector2(-0.14, -0.15), Vector2(-0.26, -0.05), Vector2(-0.26, 0.05),
		Vector2(-0.14, 0.15), Vector2(0.06, 0.19), Vector2(0.26, 0.13),
	], 0))
	fusiforme.append(_poli([Vector2(0.20, -0.10), Vector2(0.22, 0.10),
		Vector2(0.26, 0.09), Vector2(0.24, -0.09)], 1, -0.45))              # linha da guelra

	var anguiliforme: Array = []
	for i in 9:
		var t: float = i / 8.0
		var x: float = lerpf(-0.44, 0.22, t)
		var y: float = sin(t * PI * 1.8) * 0.10
		var alt: float = lerpf(0.05, 0.13, t)
		anguiliforme.append(_elipse(Vector2(x, y), Vector2(alt * 0.9, alt), 0, -0.1 * (1.0 - t)))
	anguiliforme.append(_poli([Vector2(-0.40, -0.02), Vector2(-0.50, -0.12),
		Vector2(-0.50, 0.08), Vector2(-0.40, 0.04)], -1, -0.4))
	anguiliforme.append(_elipse(Vector2(0.28, sin(PI * 1.8) * 0.10), Vector2(0.12, 0.11), 2))

	var girino: Array = []
	girino.append(_poli([Vector2(-0.10, 0.00), Vector2(-0.40, -0.14),
		Vector2(-0.34, 0.00), Vector2(-0.40, 0.14)], -1, -0.4))
	girino.append(_elipse(Vector2(0.06, 0.00), Vector2(0.24, 0.20), 0))     # cabeca-corpo
	girino.append(_elipse(Vector2(0.16, -0.06), Vector2(0.07, 0.06), 1, 0.35))  # brilho

	var lista: Array[BodyDef] = []
	lista.append(_corpo("aqua_fusiforme", "aquatico", "fusiforme", fusiforme, 1.4))
	lista.append(_corpo("aqua_anguiliforme", "aquatico", "anguiliforme", anguiliforme, 0.6))
	lista.append(_corpo("aqua_girino", "aquatico", "girino", girino, 0.5))
	return lista


# --- Arquetipo 5: insetoide -----------------------------------------------

func _insetoides() -> Array[BodyDef]:
	# Tres segmentos + seis pernas: a assinatura visual do arquetipo.
	var pernas_aladas: Array = []
	for lado in [-1.0, 1.0]:
		for i in 3:
			var x: float = -0.10 + i * 0.11
			pernas_aladas.append(_poli([
				Vector2(x, 0.02), Vector2(x - 0.03 * lado, 0.20 + i * 0.02),
				Vector2(x + 0.02, 0.19 + i * 0.02),
			], -1, -0.55))

	var alado: Array = pernas_aladas.duplicate()
	alado.append(_elipse(Vector2(-0.26, 0.02), Vector2(0.16, 0.13), 0, -0.15))  # abdomen
	alado.append(_elipse(Vector2(-0.02, 0.02), Vector2(0.14, 0.12), 0))         # torax
	alado.append(_elipse(Vector2(0.20, -0.02), Vector2(0.12, 0.11), 1))         # cabeca
	alado.append(_poli([Vector2(0.24, -0.11), Vector2(0.34, -0.28),
		Vector2(0.28, -0.10)], 2, -0.4))                                        # antenas
	alado.append(_poli([Vector2(0.16, -0.11), Vector2(0.18, -0.29),
		Vector2(0.21, -0.10)], 2, -0.4))

	var terrestre: Array = []
	for lado in [-1.0, 1.0]:
		for i in 3:
			var x: float = -0.12 + i * 0.12
			terrestre.append(_poli([
				Vector2(x, 0.04), Vector2(x - 0.05 * lado, 0.22),
				Vector2(x + 0.02, 0.20),
			], -1, -0.55))
	terrestre.append(_elipse(Vector2(-0.16, 0.02), Vector2(0.22, 0.15), 0, -0.1))  # corpo unico
	terrestre.append(_elipse(Vector2(0.16, 0.00), Vector2(0.16, 0.13), 1))
	terrestre.append(_poli([Vector2(0.28, -0.06), Vector2(0.42, -0.14),
		Vector2(0.30, -0.01)], 2, -0.35))                                        # mandibula
	terrestre.append(_poli([Vector2(0.28, 0.06), Vector2(0.42, 0.14),
		Vector2(0.30, 0.01)], 2, -0.35))

	var lista: Array[BodyDef] = []
	lista.append(_corpo("inseto_alado", "insetoide", "alado", alado, 1.2))
	lista.append(_corpo("inseto_terrestre", "insetoide", "terrestre", terrestre, 0.8))
	return lista


# --- Arquetipo 6: bipede --------------------------------------------------

func _bipedes() -> Array[BodyDef]:
	var anuro: Array = []
	# Pernas dobradas em Z, caracteristicas do anuro agachado.
	for lado in [-1.0, 1.0]:
		var base: float = 0.16 * lado
		anuro.append(_poli([
			Vector2(base - 0.06, 0.04), Vector2(base + 0.10 * lado, 0.14),
			Vector2(base + 0.06 * lado, 0.28), Vector2(base - 0.08 * lado, 0.28),
			Vector2(base - 0.02, 0.14),
		], -1, -0.4))
	anuro.append(_elipse(Vector2(0.00, 0.06), Vector2(0.24, 0.20), 0))     # tronco largo
	anuro.append(_elipse(Vector2(0.10, -0.14), Vector2(0.21, 0.13), 1))    # cabeca achatada
	anuro.append(_elipse(Vector2(0.02, -0.24), Vector2(0.075, 0.07), 2, 0.2))  # olho saliente
	anuro.append(_elipse(Vector2(0.20, -0.24), Vector2(0.075, 0.07), 2, 0.2))

	var roedor_bipede: Array = []
	roedor_bipede.append(_poli([Vector2(-0.14, 0.10), Vector2(-0.40, 0.22),
		Vector2(-0.36, 0.30), Vector2(-0.10, 0.24)], -1, -0.45))            # cauda apoiada
	for lado in [-1.0, 1.0]:
		var base: float = 0.08 * lado
		roedor_bipede.append(_poli([
			Vector2(base - 0.05, 0.10), Vector2(base + 0.09 * lado, 0.18),
			Vector2(base + 0.05 * lado, 0.30), Vector2(base - 0.06 * lado, 0.29),
		], -1, -0.4))
	roedor_bipede.append(_elipse(Vector2(0.00, 0.04), Vector2(0.17, 0.21), 0))  # tronco ereto
	roedor_bipede.append(_elipse(Vector2(0.10, -0.19), Vector2(0.14, 0.12), 1))
	roedor_bipede.append(_elipse(Vector2(0.02, -0.31), Vector2(0.07, 0.075), 0, -0.3))  # orelhas
	roedor_bipede.append(_elipse(Vector2(0.18, -0.30), Vector2(0.07, 0.075), 0, -0.3))
	roedor_bipede.append(_poli([Vector2(0.12, 0.02), Vector2(0.22, 0.10),
		Vector2(0.14, 0.12)], 2, -0.3))                                     # bracinho

	var lista: Array[BodyDef] = []
	lista.append(_corpo("bipede_anuro", "bipede", "anuro", anuro))
	lista.append(_corpo("bipede_roedor", "bipede", "roedor bipede", roedor_bipede, 0.6))
	return lista


# --- Ancoras por corpo ----------------------------------------------------

## Onde cada apendice nasce em cada corpo. Substitui as fracoes fixas do renderer,
## que davam a mesma posicao para animais de anatomia incompativel.
##   garras     : ponto medio das extremidades (patas/pes)
##   asas       : insercao dorsal, atras do ombro
##   nadadeiras : base da dorsal
##   escamas    : centro da regiao de padrao sobre o tronco
func _ancoras() -> Dictionary:
	return {
		"quad_felino": {
			"olhos": Vector2(0.27, -0.09),
			"garras": Vector2(0.04, 0.28), "escamas": Vector2(-0.02, 0.02),
			"asas": Vector2(-0.04, -0.10), "nadadeiras": Vector2(-0.06, -0.13),
		},
		"quad_canino": {
			"olhos": Vector2(0.28, -0.08),
			"garras": Vector2(0.03, 0.30), "escamas": Vector2(-0.02, 0.02),
			"asas": Vector2(-0.04, -0.11), "nadadeiras": Vector2(-0.06, -0.14),
		},
		"quad_roedor": {
			"olhos": Vector2(0.24, -0.05),
			"garras": Vector2(0.02, 0.26), "escamas": Vector2(-0.01, 0.04),
			"asas": Vector2(-0.03, -0.09), "nadadeiras": Vector2(-0.05, -0.12),
		},
		"avial_passeriforme": {
			"olhos": Vector2(0.17, -0.21),
			"garras": Vector2(0.05, 0.36), "escamas": Vector2(0.00, 0.06),
			"asas": Vector2(-0.02, -0.04), "nadadeiras": Vector2(-0.10, 0.04),
		},
		"avial_rapina": {
			"olhos": Vector2(0.20, -0.22),
			"garras": Vector2(0.06, 0.36), "escamas": Vector2(-0.01, 0.04),
			"asas": Vector2(-0.03, -0.06), "nadadeiras": Vector2(-0.12, 0.02),
		},
		"serp_lagarto": {
			"olhos": Vector2(0.31, -0.02),
			"garras": Vector2(-0.05, 0.27), "escamas": Vector2(0.02, 0.05),
			"asas": Vector2(-0.06, -0.05), "nadadeiras": Vector2(-0.10, -0.04),
		},
		"serp_serpente": {
			"olhos": Vector2(0.30, -0.01),
			"garras": Vector2(0.00, 0.10), "escamas": Vector2(0.00, 0.02),
			"asas": Vector2(-0.06, -0.06), "nadadeiras": Vector2(-0.12, -0.06),
		},
		"aqua_fusiforme": {
			"olhos": Vector2(0.24, -0.03),
			"garras": Vector2(0.02, 0.18), "escamas": Vector2(0.02, 0.00),
			"asas": Vector2(-0.04, -0.10), "nadadeiras": Vector2(0.00, -0.19),
		},
		"aqua_anguiliforme": {
			"olhos": Vector2(0.31, 0.00),
			"garras": Vector2(0.00, 0.12), "escamas": Vector2(0.00, 0.00),
			"asas": Vector2(-0.06, -0.08), "nadadeiras": Vector2(-0.04, -0.14),
		},
		"aqua_girino": {
			"olhos": Vector2(0.16, -0.04),
			"garras": Vector2(0.04, 0.20), "escamas": Vector2(0.06, 0.00),
			"asas": Vector2(-0.02, -0.12), "nadadeiras": Vector2(0.02, -0.20),
		},
		"inseto_alado": {
			"olhos": Vector2(0.23, -0.03),
			"garras": Vector2(0.00, 0.24), "escamas": Vector2(-0.02, 0.02),
			"asas": Vector2(-0.06, -0.08), "nadadeiras": Vector2(-0.20, -0.06),
		},
		"inseto_terrestre": {
			"olhos": Vector2(0.19, -0.01),
			"garras": Vector2(-0.02, 0.24), "escamas": Vector2(-0.14, 0.02),
			"asas": Vector2(-0.10, -0.10), "nadadeiras": Vector2(-0.24, -0.06),
		},
		"bipede_anuro": {
			"olhos": Vector2(0.11, -0.24),
			"garras": Vector2(0.00, 0.30), "escamas": Vector2(0.00, 0.06),
			"asas": Vector2(-0.06, -0.06), "nadadeiras": Vector2(-0.10, -0.06),
		},
		"bipede_roedor": {
			"olhos": Vector2(0.13, -0.20),
			"garras": Vector2(0.00, 0.31), "escamas": Vector2(0.00, 0.04),
			"asas": Vector2(-0.04, -0.08), "nadadeiras": Vector2(-0.10, -0.08),
		},
	}


# --- Proibicoes anatomicas por corpo --------------------------------------

## Slots impossiveis em cada corpo. Declarado aqui na Fase 1; o veto pre-amostragem
## que consome estes dados entra na Fase 2. Estas sao as impossibilidades ligadas a
## FORMA do corpo — regras que dependem de elemento ou animal ficam na Fase 2.
func _proibicoes() -> Dictionary:
	return {
		# Serpente nao tem membros: nada de garras.
		"serp_serpente": ["garras"],
		# Corpos aquaticos nao sustentam asas.
		"aqua_fusiforme": ["asas"],
		"aqua_anguiliforme": ["asas", "garras"],
		"aqua_girino": ["asas", "garras"],
		# Aves ja tem asas proprias na silhueta; um segundo par seria incoerente.
		"avial_passeriforme": ["nadadeiras"],
		"avial_rapina": ["nadadeiras"],
	}


# --- Validacao ------------------------------------------------------------

func _validar(lib: CreaturePartLibrary, corpos: Array[BodyDef]) -> String:
	var ids: Dictionary = {}
	for corpo in corpos:
		if ids.has(corpo.id):
			return "id duplicado: " + corpo.id
		ids[corpo.id] = true
		if corpo.partes.is_empty():
			return "corpo sem partes: " + corpo.id
		if corpo.peso <= 0.0:
			return "peso invalido em: " + corpo.id
		if not lib.slot_anchors.has(corpo.id):
			return "corpo sem ancoras: " + corpo.id
		for slot in ["olhos", "garras", "escamas", "asas", "nadadeiras"]:
			if not lib.slot_anchors[corpo.id].has(slot):
				return "ancora ausente: %s/%s" % [corpo.id, slot]

	for body_id in lib.slot_anchors:
		if not ids.has(body_id):
			return "ancoras para corpo inexistente: " + body_id
	for body_id in lib.forbidden_slots:
		if not ids.has(body_id):
			return "proibicoes para corpo inexistente: " + body_id

	# Todo animal do vocabulario precisa de ao menos um corpo, senao o gerador
	# produziria criaturas sem silhueta.
	var tabelas := TabelasProbabilidade.carregar()
	if tabelas == null:
		return "nao foi possivel carregar o vocabulario para validar"
	for animal in tabelas.animais():
		if lib.corpos_de(animal).is_empty():
			return "animal sem corpo mapeado: " + animal
	return ""
