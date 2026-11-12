extends SceneTree

## Camada 3: godot --headless --path . -s res://tools/test_ambientacao.gd

const SEED_A := 123456789
const N := 100
const SEMENTES := 300
const RAZAO_MINIMA_IM := 5.0

var _falhas: int = 0
var _total: int = 0
var _t: TabelasProbabilidade
var _ger: GeradorCriaturas
var _amb: GeradorAmbientacao
var _mapa: Dictionary
var _props: Dictionary
var _reservadas: Array = []


func _initialize() -> void:
	print("== Ambientacao (Camada 3) ==")
	_t = TabelasProbabilidade.carregar()
	_ger = GeradorCriaturas.new(_t, CatalogoCorpos.carregar(_t))
	_amb = GeradorAmbientacao.carregar()
	_mapa = JSON.parse_string(FileAccess.get_file_as_string("res://autoral/mapas/mundo.json"))
	_props = JSON.parse_string(FileAccess.get_file_as_string("res://arte/mundo/props.json"))["props"]
	var npcs: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://autoral/npcs/npcs.json"))
	for n: Dictionary in npcs["npcs"]:
		if String(n.get("mapa", "mundo")) == "mundo" or n.get("mapa") == null:
			_reservadas.append(Vector2i(int(n["celula"][0]), int(n["celula"][1])))
	_dados()
	_reproducao()
	_respeita_o_mapa()
	_condicionamento()
	print("\nRESULTADO: %s" % ("TODOS OS TESTES PASSARAM (%d)" % _total if _falhas == 0
			else "%d VERIFICACAO(OES) FALHARAM" % _falhas))
	quit(0 if _falhas == 0 else 1)


func _ok(cond: bool, nome: String, detalhe: String = "") -> void:
	_total += 1
	if not cond:
		_falhas += 1
	print("    %s %s  %s" % ["OK  " if cond else "FALHOU", nome, detalhe])


func _gerar(s: int, condicionado: bool = true) -> Dictionary:
	return _amb.gerar(s, _mapa, _props, _ger.gerar_bestiario(s, N, GeradorCriaturas.MODO_DO_JOGO),
			_reservadas, condicionado)


func _dados() -> void:
	print("\nDados")
	var tudo_existe: bool = true
	for classe: String in _amb.dados["classes"]:
		for p: String in _amb.dados["classes"][classe]["props"]:
			tudo_existe = tudo_existe and _props.has(p)
	_ok(tudo_existe, "todo prop das classes existe na arte")
	_ok(_props.has(_amb.dados["achados"]["prop"]), "a arte do achado existe")
	var elementos_ok: bool = true
	for e: String in _t.elementos():
		elementos_ok = elementos_ok and _amb.dados["vies_por_elemento"].has(e) \
				and _amb.dados["fator_de_densidade_por_elemento"].has(e)
	_ok(elementos_ok, "todo elemento tem vies e densidade")
	var regioes_ok: bool = true
	for r: Dictionary in _mapa["regioes"]:
		regioes_ok = regioes_ok and _amb.dados["regioes"].has(r["id"])
	_ok(regioes_ok, "toda regiao do mapa tem configuracao")


func _reproducao() -> void:
	print("\nReproducao (RF03)")
	var a := _gerar(SEED_A)
	seed(555)
	randi()
	_ok(JSON.stringify(a) == JSON.stringify(_gerar(SEED_A)), "mesma seed, mesma ambientacao")
	_ok(JSON.stringify(a["props"]) != JSON.stringify(_gerar(SEED_A + 1)["props"]),
			"seed diferente, ambientacao diferente")
	var bestiario := _ger.gerar_bestiario(SEED_A, N, GeradorCriaturas.MODO_DO_JOGO)
	var antes: String = JSON.stringify(bestiario.map(func(c: Criatura) -> Dictionary: return c.to_dict()))
	var t0 := Time.get_ticks_usec()
	_amb.gerar(SEED_A, _mapa, _props, bestiario, _reservadas)
	var ms: float = (Time.get_ticks_usec() - t0) / 1000.0
	_ok(antes == JSON.stringify(bestiario.map(func(c: Criatura) -> Dictionary: return c.to_dict())),
			"nao altera o bestiario")
	_ok(ms < 500.0, "custo aceitavel", "%.1f ms" % ms)
	_ok((a["props"] as Array).size() > 40, "ha o que ver", "%d props" % (a["props"] as Array).size())
	_ok((a["achados"] as Array).size() == 4, "um achado por regiao")


func _respeita_o_mapa() -> void:
	print("\nRespeita o mapa autoral (40 seeds)")
	var terreno: Array = _mapa["terreno"]
	var ocupadas := _ocupadas_do_mapa()
	var sobre_algo: int = 0
	var fora_do_solo: int = 0
	var alcance_quebrado: int = 0
	var achado_preso: int = 0
	var reservada: int = 0
	var chaves := _celulas_chave()
	for i in 40:
		var r := _gerar(1000 + i * 7919)
		var bloq: Dictionary = (ocupadas["bloqueadas"] as Dictionary).duplicate()
		var usadas: Dictionary = {}
		for item: Dictionary in (r["props"] as Array) + (r["achados"] as Array):
			var c := Vector2i(int(item["celula"][0]), int(item["celula"][1]))
			if (ocupadas["todas"] as Dictionary).has(c) or usadas.has(c):
				sobre_algo += 1
			if String(terreno[c.y])[c.x] != ".":
				fora_do_solo += 1
			if _reservadas.has(c):
				reservada += 1
			usadas[c] = true
			if String(_props[item["prop"]]["colisao"]["tipo"]) != "nenhuma":
				bloq[c] = true
		var alcance := _alcance(bloq)
		for k: Vector2i in chaves:
			if not alcance.has(k):
				alcance_quebrado += 1
		for a: Dictionary in r["achados"]:
			if not alcance.has(Vector2i(int(a["celula"][0]), int(a["celula"][1]))):
				achado_preso += 1
	_ok(sobre_algo == 0, "nada nasce sobre o que ja existe", str(sobre_algo))
	_ok(fora_do_solo == 0, "so em grama livre", str(fora_do_solo))
	_ok(reservada == 0, "nada na celula de um NPC", str(reservada))
	_ok(alcance_quebrado == 0, "NPCs, porta e zonas continuam alcancaveis", str(alcance_quebrado))
	_ok(achado_preso == 0, "todo achado e alcancavel", str(achado_preso))


func _condicionamento() -> void:
	print("\nCondicionamento criatura-lugar (%d seeds)" % SEMENTES)
	var cond: Array = []
	var base: Array = []
	for i in SEMENTES:
		var s: int = 5000 + i * 104729
		_coletar(_gerar(s), cond)
		_coletar(_gerar(s, false), base)
	var i_cond: float = MetricasCoerencia._info_mutua(cond)["i_bits"]
	var i_base: float = MetricasCoerencia._info_mutua(base)["i_bits"]
	_ok(i_cond > i_base * RAZAO_MINIMA_IM, "I(elemento dominante; classe) acima do baseline",
			"%.3f vs %.3f bits, n=%d" % [i_cond, i_base, cond.size()])


## Pares (regiao|elemento dominante, classe). A regiao entra na chave porque ela ja muda os
## pesos: o que se mede e o que o elemento acrescenta, dentro de uma regiao so.
func _coletar(r: Dictionary, pares: Array) -> void:
	for item: Dictionary in r["props"]:
		if item["regiao"] == "vila":
			pares.append([String(r["dominantes"]["vila"]), String(item["classe"])])


func _ocupadas_do_mapa() -> Dictionary:
	var todas: Dictionary = {}
	var bloqueadas: Dictionary = {}
	_amb._ler_ocupacao(_mapa, _props, todas, bloqueadas)
	return {"todas": todas, "bloqueadas": bloqueadas}


func _celulas_chave() -> Array:
	var chaves: Array = []
	var alcance := _alcance(_ocupadas_do_mapa()["bloqueadas"])
	for c: Vector2i in _reservadas:
		chaves.append(c)
	for p: Dictionary in _mapa["portas"]:
		chaves.append(Vector2i(int(p["celula"][0]), int(p["celula"][1])))
	for z: Dictionary in _mapa["pontos_encontro"]:
		chaves.append(Vector2i(int(z["celula"][0]), int(z["celula"][1])))
	# Conta so o que ja era alcancavel antes da Camada 3.
	return chaves.filter(func(c: Vector2i) -> bool: return alcance.has(c))


func _alcance(bloqueadas: Dictionary) -> Dictionary:
	return _amb._alcancaveis(_mapa, bloqueadas)
