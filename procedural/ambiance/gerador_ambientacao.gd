class_name GeradorAmbientacao
extends RefCounted

## Camada 3: distribui vegetacao, sucata e um ponto de interesse por regiao sobre o mapa
## autoral. Mesma seed, mesmo bestiario e mesmo mapa => mesma ambientacao (RF03): usa um
## RNG proprio, e nao depende de nenhuma cena.
##
## O condicionamento e entre CRIATURA E LUGAR: o que nasce numa regiao depende do elemento
## que o bestiario desta seed mais trouxe para ela. Le a saida da Camada 2 e nao a altera.
##
## Custo linear no numero de celulas, sem busca e sem rejeicao. Celula que nao serve e
## ignorada, sem novo sorteio. Um obstaculo so entra com as 8 vizinhas livres, e um
## obstaculo isolado nao separa duas areas do mapa: nao ha caminho a reconferir.

const CAMINHO := "res://data/ambientacao.json"
const DESLOCAMENTO_SEED := 0xA3B1E
const SOLO_LIVRE := "."
const TERRENOS_DE_CAMINHO := ["c", "k", "p"]
const VIZINHAS := [
	Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1), Vector2i(-1, 0),
	Vector2i(1, 0), Vector2i(-1, 1), Vector2i(0, 1), Vector2i(1, 1),
]
const CATEGORIAS_DO_MAPA := ["arvores", "pedras", "penhascos", "decoracao", "casas"]

var dados: Dictionary = {}


static func carregar() -> GeradorAmbientacao:
	var bruto: Variant = JSON.parse_string(FileAccess.get_file_as_string(CAMINHO))
	if not bruto is Dictionary:
		push_error("GeradorAmbientacao: nao carregou " + CAMINHO)
		return null
	var g := GeradorAmbientacao.new()
	g.dados = bruto
	return g


## `reservadas`: celulas que ninguem pode ocupar, alem das que o proprio mapa declara
## (NPCs, por exemplo). `condicionado` falso e o baseline: a mesma regiao, sem o elemento.
## Retorno: {props: [{categoria, prop, celula}], achados: [{id, prop, celula, gold, regiao}],
## dominantes: {regiao: elemento}}.
func gerar(world_seed: int, mapa: Dictionary, catalogo_props: Dictionary, bestiario: Array,
		reservadas: Array = [], condicionado: bool = true) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = world_seed + DESLOCAMENTO_SEED
	var terreno: Array = mapa["terreno"]
	var bloqueia_terreno: Array = mapa["bloqueia"]
	var ocupadas: Dictionary = {}
	var bloqueadas: Dictionary = {}
	_ler_ocupacao(mapa, catalogo_props, ocupadas, bloqueadas)
	var proibidas: Dictionary = _celulas_proibidas(mapa, reservadas)
	var dominantes: Dictionary = elementos_dominantes(mapa, bestiario)
	var margem: int = int(dados["margem_do_caminho"])

	var saida: Array = []
	for regiao: Dictionary in mapa["regioes"]:
		var id: String = regiao["id"]
		var conf: Dictionary = dados["regioes"].get(id, {})
		if conf.is_empty():
			continue
		var elemento: String = dominantes.get(id, "")
		var pesos: Dictionary = _pesos_da_regiao(conf, elemento if condicionado else "")
		var densidade: float = float(conf["densidade"])
		if condicionado and elemento != "":
			densidade *= float(dados["fator_de_densidade_por_elemento"][elemento])
		var r: Array = regiao["retangulo"]
		for y in range(int(r[1]), int(r[3]) + 1):
			for x in range(int(r[0]), int(r[2]) + 1):
				var c := Vector2i(x, y)
				# Um sorteio por celula, sirva ela ou nao: a decisao de uma celula nao
				# desloca as seguintes.
				var sorteio: float = rng.randf()
				var indice_classe: float = rng.randf()
				var indice_prop: float = rng.randf()
				if sorteio >= densidade or not _celula_serve(terreno, c, ocupadas, bloqueadas,
						proibidas, margem):
					continue
				var classe: String = _escolher(pesos, indice_classe)
				var lista: Array = dados["classes"][classe]["props"]
				var prop: String = lista[mini(int(indice_prop * lista.size()), lista.size() - 1)]
				var bloqueante: bool = _prop_bloqueia(catalogo_props, prop)
				if bloqueante and _tem_vizinha_bloqueada(terreno, bloqueia_terreno, bloqueadas, c):
					continue
				ocupadas[c] = true
				if bloqueante:
					bloqueadas[c] = true
				saida.append({"categoria": dados["classes"][classe]["categoria"], "prop": prop,
						"celula": [c.x, c.y], "classe": classe, "regiao": id})

	return {
		"props": saida,
		"achados": _sortear_achados(rng, mapa, ocupadas, bloqueadas, proibidas, margem),
		"dominantes": dominantes,
	}


## Por regiao, o elemento mais frequente no bestiario entre os que as zonas dela aceitam.
## Empate: a ordem dos elementos em `pontos_encontro`, que e fixa.
func elementos_dominantes(mapa: Dictionary, bestiario: Array) -> Dictionary:
	var contagem: Dictionary = {}
	for c: Criatura in bestiario:
		contagem[c.elemento] = int(contagem.get(c.elemento, 0)) + 1
	var saida: Dictionary = {}
	for regiao: Dictionary in mapa["regioes"]:
		var r: Array = regiao["retangulo"]
		var melhor: String = ""
		for zona: Dictionary in mapa["pontos_encontro"]:
			var p: Array = zona["celula"]
			if int(p[0]) < int(r[0]) or int(p[0]) > int(r[2]) \
					or int(p[1]) < int(r[1]) or int(p[1]) > int(r[3]):
				continue
			for e: String in zona["elementos_provaveis"]:
				if melhor == "" or int(contagem.get(e, 0)) > int(contagem.get(melhor, 0)):
					melhor = e
		saida[regiao["id"]] = melhor
	return saida


func _pesos_da_regiao(conf: Dictionary, elemento: String) -> Dictionary:
	var pesos: Dictionary = {}
	for classe: String in conf["pesos"]:
		var fator: float = 1.0
		if elemento != "":
			fator = float(dados["vies_por_elemento"][elemento].get(classe, 1.0))
		pesos[classe] = float(conf["pesos"][classe]) * fator
	return pesos


func _escolher(pesos: Dictionary, u: float) -> String:
	var total: float = 0.0
	for k: String in pesos:
		total += float(pesos[k])
	var alvo: float = u * total
	var acumulado: float = 0.0
	var ultimo: String = ""
	for k: String in pesos:
		acumulado += float(pesos[k])
		ultimo = k
		if alvo <= acumulado:
			return k
	return ultimo


func _ler_ocupacao(mapa: Dictionary, catalogo: Dictionary, ocupadas: Dictionary,
		bloqueadas: Dictionary) -> void:
	for categoria: String in CATEGORIAS_DO_MAPA:
		for item: Dictionary in mapa.get(categoria, []):
			var nome: String = item["prop"]
			var meta: Dictionary = catalogo.get(nome, {})
			var cels: Array = meta.get("celulas", [1, 1])
			var c: Array = item["celula"]
			var bloqueia: bool = _prop_bloqueia(catalogo, nome)
			for dx in int(cels[0]):
				for dy in int(cels[1]):
					var celula := Vector2i(int(c[0]) + dx, int(c[1]) + dy)
					ocupadas[celula] = true
					if bloqueia:
						bloqueadas[celula] = true


func _prop_bloqueia(catalogo: Dictionary, nome: String) -> bool:
	return String(catalogo.get(nome, {}).get("colisao", {}).get("tipo", "nenhuma")) != "nenhuma"


## Spawn, portas, o trajeto da chegada de onibus e o que o chamador reservar.
func _celulas_proibidas(mapa: Dictionary, reservadas: Array) -> Dictionary:
	var proibidas: Dictionary = {}
	var pontos: Array = reservadas.duplicate()
	var spawn: Array = mapa["spawn_jogador"]
	pontos.append(Vector2i(int(spawn[0]), int(spawn[1])))
	for porta: Dictionary in mapa.get("portas", []):
		pontos.append(Vector2i(int(porta["celula"][0]), int(porta["celula"][1])))
	var chegada: Dictionary = mapa.get("chegada", {})
	if not chegada.is_empty():
		var boca: Array = chegada["boca"]
		var parada: Array = chegada["parada"]
		for x in range(int(boca[0]), int(parada[0]) + 2):
			pontos.append(Vector2i(x, int(boca[1])))
		for chave: String in ["desembarque", "encontro"]:
			pontos.append(Vector2i(int(chegada[chave][0]), int(chegada[chave][1])))
		var trajeto: Array = chegada["caminho_mirela"]
		for i in range(1, trajeto.size()):
			var a := Vector2i(int(trajeto[i - 1][0]), int(trajeto[i - 1][1]))
			var b := Vector2i(int(trajeto[i][0]), int(trajeto[i][1]))
			var passos: int = maxi(absi(b.x - a.x), absi(b.y - a.y))
			for t in passos + 1:
				pontos.append(a + (b - a) * t / maxi(passos, 1))
	for p: Vector2i in pontos:
		proibidas[p] = true
		for v: Vector2i in VIZINHAS:
			proibidas[p + v] = true
	return proibidas


func _celula_serve(terreno: Array, c: Vector2i, ocupadas: Dictionary, bloqueadas: Dictionary,
		proibidas: Dictionary, margem: int) -> bool:
	if _solo(terreno, c) != SOLO_LIVRE or ocupadas.has(c) or bloqueadas.has(c) or proibidas.has(c):
		return false
	for dy in range(-margem, margem + 1):
		for dx in range(-margem, margem + 1):
			if TERRENOS_DE_CAMINHO.has(_solo(terreno, c + Vector2i(dx, dy))):
				return false
	return true


func _tem_vizinha_bloqueada(terreno: Array, bloqueia_terreno: Array, bloqueadas: Dictionary,
		c: Vector2i) -> bool:
	for v: Vector2i in VIZINHAS:
		var n: Vector2i = c + v
		if bloqueadas.has(n) or bloqueia_terreno.has(_solo(terreno, n)):
			return true
	return false


func _solo(terreno: Array, c: Vector2i) -> String:
	if c.y < 0 or c.y >= terreno.size():
		return "r"
	var linha: String = terreno[c.y]
	return linha[c.x] if c.x >= 0 and c.x < linha.length() else "r"


func _sortear_achados(rng: RandomNumberGenerator, mapa: Dictionary, ocupadas: Dictionary,
		bloqueadas: Dictionary, proibidas: Dictionary, margem: int) -> Array:
	var conf: Dictionary = dados["achados"]
	var terreno: Array = mapa["terreno"]
	var alcancaveis: Dictionary = _alcancaveis(mapa, bloqueadas)
	var achados: Array = []
	for regiao: Dictionary in mapa["regioes"]:
		var id: String = regiao["id"]
		var r: Array = regiao["retangulo"]
		var candidatas: Array = []
		for y in range(int(r[1]), int(r[3]) + 1):
			for x in range(int(r[0]), int(r[2]) + 1):
				var c := Vector2i(x, y)
				if alcancaveis.has(c) and _celula_serve(terreno, c, ocupadas, bloqueadas,
						proibidas, margem):
					candidatas.append(c)
		if candidatas.is_empty():
			continue
		var escolhida: Vector2i = candidatas[rng.randi_range(0, candidatas.size() - 1)]
		ocupadas[escolhida] = true
		achados.append({"id": "achado_" + id, "prop": conf["prop"],
				"celula": [escolhida.x, escolhida.y], "regiao": id,
				"gold": rng.randi_range(int(conf["gold_minimo"]), int(conf["gold_maximo"]))})
	return achados


## Celulas que o jogador alcanca a partir do spawn, depois dos obstaculos sorteados.
func _alcancaveis(mapa: Dictionary, bloqueadas: Dictionary) -> Dictionary:
	var terreno: Array = mapa["terreno"]
	var bloqueia_terreno: Array = mapa["bloqueia"]
	var spawn := Vector2i(int(mapa["spawn_jogador"][0]), int(mapa["spawn_jogador"][1]))
	var vistos: Dictionary = {spawn: true}
	var fila: Array = [spawn]
	var i: int = 0
	while i < fila.size():
		var c: Vector2i = fila[i]
		i += 1
		for v: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var n: Vector2i = c + v
			if not vistos.has(n) and not bloqueadas.has(n) \
					and not bloqueia_terreno.has(_solo(terreno, n)):
				vistos[n] = true
				fila.append(n)
	return vistos
