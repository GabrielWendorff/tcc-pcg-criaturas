extends SceneTree

## Teste headless do mundo jogavel — roda SEM abrir janela:
##   godot --headless --path . -s res://tools/test_mundo.gd
##
## Verifica o criterio de conclusao da etapa item por item: o mapa carrega, o
## chao e todos os props existem, a camera enquadra o mapa, os pontos de
## encontro estao la — e, com FISICA DE VERDADE, que o jogador anda, que nao
## atravessa agua/casa/arvore e que nao sai do mapa.
##
## A parte de fisica precisa de frames reais: os corpos de uma TileMapLayer so
## existem UM frame depois de set_cell, e move_and_slide nao faz nada fora de
## _physics_process. Por isso o script espera `physics_frame` em vez de medir
## tudo em _initialize e sair.
##
## Sai com codigo != 0 se algo falhar.

const N_PONTOS_MINIMO := 5      # a etapa pede de 5 a 8
const N_CASAS_MINIMO := 6
const N_REGIOES_MINIMO := 3    # a vila + pelo menos duas regioes novas
const PASSOS_DE_TESTE := 150    # 2,5 s de simulacao a 60 Hz

var _falhas: int = 0
var _verificacoes: int = 0


func _initialize() -> void:
	print("== Mundo jogavel — teste headless ==")
	await _rodar()
	print("\n==")
	# Sem esta guarda, um erro de compilacao que abortasse _rodar() antes da
	# primeira verificacao sairia com codigo 0 e passaria por sucesso.
	if _verificacoes < 25:
		print("RESULTADO: so %d verificacoes rodaram — o teste abortou no meio"
				% _verificacoes)
		quit(1)
	elif _falhas > 0:
		print("RESULTADO: %d VERIFICACAO(OES) FALHARAM" % _falhas)
		quit(1)
	else:
		print("RESULTADO: TODOS OS TESTES PASSARAM")
		quit(0)


func _ok(condicao: bool, rotulo: String, detalhe: String = "") -> bool:
	print("    %s %s%s" % ["OK  " if condicao else "FALHOU", rotulo,
			"" if detalhe == "" else "  — " + detalhe])
	_verificacoes += 1
	if not condicao:
		_falhas += 1
	return condicao


func _rodar() -> void:
	# ---------------------------------------------------- 1. mapa e chao
	print("\nMapa e terreno")
	var t0 := Time.get_ticks_usec()
	var mundo := MundoIso.new()
	root.add_child(mundo)
	mundo.carregar()
	var ms := (Time.get_ticks_usec() - t0) / 1000.0
	if not _ok(mundo.erro == "", "mapa carregou", mundo.erro):
		return
	_ok(mundo.largura > 0 and mundo.profundidade > 0, "dimensoes",
			"%dx%d celulas" % [mundo.largura, mundo.profundidade])
	_ok(ms < 2000.0, "tempo de montagem", "%.0f ms" % ms)

	# Um frame antes de qualquer consulta por grupo. Num script `extends
	# SceneTree`, os nos adicionados durante _initialize ainda nao receberam
	# NOTIFICATION_ENTER_TREE: eles existem na arvore mas nao no indice de
	# grupos, e get_nodes_in_group devolveria zero para tudo. Num jogo normal
	# isso nao acontece — e artefato de rodar com -s.
	await process_frame

	var celulas := mundo.chao.get_used_cells().size()
	_ok(celulas == mundo.largura * mundo.profundidade, "chao completo",
			"%d de %d celulas" % [celulas, mundo.largura * mundo.profundidade])

	var terrenos := {}
	for gy in mundo.profundidade:
		for gx in mundo.largura:
			var n := mundo.terreno_em(Vector2i(gx, gy))
			terrenos[n] = int(terrenos.get(n, 0)) + 1
	print("       terrenos: " + str(terrenos))
	_ok(terrenos.has("agua") and int(terrenos["agua"]) > 40, "lago presente",
			"%d celulas de agua" % int(terrenos.get("agua", 0)))
	_ok(terrenos.has("grama") and int(terrenos["grama"]) > 200, "areas de grama",
			"%d celulas" % int(terrenos.get("grama", 0)))
	_ok(int(terrenos.get("grama_alta", 0)) > 60, "grama alta (futuros arbustos)",
			"%d celulas" % int(terrenos.get("grama_alta", 0)))
	_ok(int(terrenos.get("caminho", 0)) > 60, "caminhos",
			"%d celulas" % int(terrenos.get("caminho", 0)))

	# ------------------------------------------------------------ 2. props
	print("\nProps e organizacao")
	var por_grupo := {}
	for grupo in ["casas", "arvores", "pedras", "penhascos", "decoracao"]:
		por_grupo[grupo] = get_nodes_in_group(grupo).size()
	print("       " + str(por_grupo))
	_ok(int(por_grupo["casas"]) >= N_CASAS_MINIMO, "pelo menos %d casas"
			% N_CASAS_MINIMO, "%d casas" % int(por_grupo["casas"]))
	_ok(int(por_grupo["arvores"]) > 20, "arvores")
	_ok(int(por_grupo["pedras"]) > 5, "pedras")
	_ok(int(por_grupo["penhascos"]) > 20, "penhascos na borda")

	var com_colisao := 0
	var casas_com_papel := 0
	for no in get_nodes_in_group("casas"):
		if no.get_node_or_null("Colisao") != null:
			com_colisao += 1
		if String(no.get_meta("papel", "")) != "":
			casas_com_papel += 1
	_ok(int(por_grupo["casas"]) > 0 and com_colisao == int(por_grupo["casas"]),
			"toda casa tem colisao", "%d de %d" % [com_colisao, int(por_grupo["casas"])])
	_ok(int(por_grupo["casas"]) > 0 and casas_com_papel == int(por_grupo["casas"]),
			"toda casa declara um papel futuro (NPC/loja/missao)")

	var arvores_com_colisao := 0
	for no in get_nodes_in_group("arvores"):
		if no.get_node_or_null("Colisao") != null:
			arvores_com_colisao += 1
	_ok(int(por_grupo["arvores"]) > 0
			and arvores_com_colisao == int(por_grupo["arvores"]),
			"toda arvore tem colisao",
			"%d de %d" % [arvores_com_colisao, int(por_grupo["arvores"])])

	# ------------------------------------------------- 3. pontos de encontro
	print("\nPontos de encontro (preparados, sem mecanica)")
	var pontos := get_nodes_in_group("pontos_de_encontro")
	_ok(pontos.size() >= N_PONTOS_MINIMO, "pelo menos %d pontos" % N_PONTOS_MINIMO,
			"%d pontos" % pontos.size())
	var ids := {}
	var todos_validos := not pontos.is_empty()
	for no in pontos:
		var p := no as PontoDeEncontro
		print("       " + str(p))
		if p.id_ponto == "" or ids.has(p.id_ponto) or p.raio_celulas <= 0.0 \
				or p.elementos_provaveis.is_empty() or p.celulas_de_grama_alta < 8:
			todos_validos = false
		ids[p.id_ponto] = true
		if mundo.terreno_em(mundo.mundo_para_celula(p.position)) != "grama_alta":
			todos_validos = false
	_ok(todos_validos, "todo ponto: id unico, raio, elementos e grama alta sob ele")
	var sem_sinal := true
	for no in pontos:
		if (no as Area2D).body_entered.get_connections().size() > 0:
			sem_sinal = false
	_ok(sem_sinal, "nenhum ponto tem mecanica ligada (fora do escopo da etapa)")

	# ----------------------------------------------------------- 4. camera
	print("\nCamera")
	var lim := mundo.limites_da_camera()
	var esperado := Vector2((mundo.largura + mundo.profundidade) * 16.0,
			(mundo.largura + mundo.profundidade) * 8.0)
	_ok(lim.size.is_equal_approx(esperado), "limites cobrem o mapa",
			"%s (esperado %s)" % [lim.size, esperado])
	var quinas := mundo.quinas_do_mapa()
	var dentro := true
	for q in quinas:
		if not lim.has_point(q) and lim.grow(1.0).has_point(q) == false:
			dentro = false
	_ok(dentro, "as 4 quinas do mapa caem dentro dos limites")

	# ---------------------------------------------------------- 5. jogador
	print("\nJogador")
	var quadros := Jogador.montar_quadros()
	_ok(quadros != null, "folha de caminhada carregou")
	if quadros != null:
		_ok(quadros.get_animation_names().size() == 8,
				"8 animacoes (4 andar + 4 parado)",
				str(quadros.get_animation_names()))
		_ok(quadros.get_frame_count("andar_baixo") == 4, "4 quadros por caminhada")

	var jogador := Jogador.new()
	jogador.position = mundo.spawn_do_jogador()
	mundo.entidades.add_child(jogador)
	var spawn := jogador.position
	_ok(not mundo.bloqueia(mundo.mundo_para_celula(spawn)), "spawn em chao pisavel",
			"celula %s = %s" % [mundo.mundo_para_celula(spawn),
					mundo.terreno_em(mundo.mundo_para_celula(spawn))])

	# ------------------------------------------------ 5b. regioes e NPCs
	print("\nRegioes do mundo")
	var regioes := mundo.dados_das_regioes()
	_ok(regioes.size() >= N_REGIOES_MINIMO, "pelo menos %d regioes"
			% N_REGIOES_MINIMO, "%d declaradas" % regioes.size())
	var nos_de_regiao := get_nodes_in_group("regioes")
	_ok(nos_de_regiao.size() == regioes.size(),
			"toda regiao declarada virou area em cena",
			"%d areas para %d regioes" % [nos_de_regiao.size(), regioes.size()])
	var ids_de_regiao := {}
	for r: Dictionary in regioes:
		var id_r := String(r.get("id", ""))
		var ret: Array = r.get("retangulo", [])
		var completo: bool = id_r != "" and String(r.get("nome", "")) != "" \
				and ret.size() == 4 and not ids_de_regiao.has(id_r)
		ids_de_regiao[id_r] = r
		print("       %-12s %-22s [%d,%d]-[%d,%d]" % [id_r, r.get("nome", ""),
				ret[0], ret[1], ret[2], ret[3]])
		if not completo:
			_ok(false, "regiao '%s' com dado incompleto ou id repetido" % id_r)
	_ok(ids_de_regiao.size() == regioes.size(),
			"toda regiao tem id unico, nome e retangulo")

	# O spawn precisa cair numa regiao: o mapa geral marca a regiao inicial como
	# descoberta a partir dele, e um spawn na terra de ninguem abriria o jogo com
	# tudo "???".
	var celula_spawn := mundo.mundo_para_celula(mundo.spawn_do_jogador())
	var regiao_do_spawn := ""
	for no in nos_de_regiao:
		if (no as RegiaoMundo).contem_celula(celula_spawn):
			regiao_do_spawn = (no as RegiaoMundo).id_regiao
	_ok(regiao_do_spawn != "", "o spawn cai dentro de uma regiao", regiao_do_spawn)

	print("\nNPCs no mundo")
	var catalogo := CatalogoNpcs.carregar()
	var dialogos := CatalogoDialogos.new()
	_ok(catalogo.validar(dialogos).is_empty(), "catalogo de NPCs valido",
			"\n       ".join(catalogo.validar(dialogos)))
	var regioes_com_npc := {}
	for n: DadosNpc in catalogo.npcs:
		# Quem mora num interior (o Otavio, na fabrica) e conferido pelo gerador
		# daquele mapa (tools/mapas/gerar_fabrica.py), nao contra o mundo.
		if n.mapa != mundo.id_mapa:
			continue
		var pisavel: bool = not mundo.bloqueia(n.celula)
		var regiao_do_npc := ""
		for no in nos_de_regiao:
			if (no as RegiaoMundo).contem_celula(n.celula):
				regiao_do_npc = (no as RegiaoMundo).id_regiao
		regioes_com_npc[regiao_do_npc] = true
		print("       %-9s %-14s celula %s  terreno=%s  regiao=%s"
				% [n.id, n.papel, n.celula, mundo.terreno_em(n.celula), regiao_do_npc])
		_ok(pisavel and regiao_do_npc == n.regiao,
				"%s: em chao pisavel e na regiao que declara" % n.id,
				"terreno=%s regiao_real=%s declarada=%s"
						% [mundo.terreno_em(n.celula), regiao_do_npc, n.regiao])
	_ok(regioes_com_npc.size() >= 3, "os NPCs estao espalhados pelo mundo",
			"%d regioes com NPC" % regioes_com_npc.size())

	print("\nMapa geral (M)")
	var estado := EstadoMundo.new()
	var tela := MapaMundo.new()
	root.add_child(tela)
	tela.preparar(mundo, estado)
	_ok(not tela.aberto(), "comeca fechado")
	tela.abrir()
	_ok(tela.aberto(), "abre")
	tela.fechar()
	_ok(not tela.aberto(), "fecha")
	_ok(not tela._descoberta("ribeira"), "regiao nao visitada aparece oculta")
	estado.visitar("ribeira")
	_ok(tela._descoberta("ribeira"), "visitar a regiao a revela no mapa")
	var carta: MapaMundo.Carta = tela._carta
	_ok(carta != null and carta.textura != null, "a carta rasteriza o terreno",
			"%s px" % (carta.textura.get_size() if carta != null and carta.textura != null else Vector2.ZERO))
	tela.queue_free()

	print("\nTravessia do rio")
	var celulas_de_ponte := 0
	for gy in mundo.profundidade:
		for gx in mundo.largura:
			if mundo.terreno_em(Vector2i(gx, gy)) == "ponte":
				celulas_de_ponte += 1
	_ok(celulas_de_ponte > 0, "existem celulas de ponte", "%d" % celulas_de_ponte)
	var ponte_sobre_agua := false
	for gy in mundo.profundidade:
		for gx in mundo.largura:
			if mundo.terreno_em(Vector2i(gx, gy)) != "ponte":
				continue
			if not mundo.bloqueia(Vector2i(gx, gy)) and (
					mundo.terreno_em(Vector2i(gx, gy - 1)) == "agua"
					or mundo.terreno_em(Vector2i(gx, gy + 1)) == "agua"):
				ponte_sobre_agua = true
	_ok(ponte_sobre_agua, "a ponte e pisavel e atravessa a agua")

	# ------------------------------------------------- 6. fisica de verdade
	print("\nFisica (simulacao de %d frames por direcao)" % PASSOS_DE_TESTE)
	await physics_frame
	await physics_frame          # os corpos da TileMapLayer nascem 1 frame depois

	var andou := await _empurrar(jogador, spawn, Vector2(1, 0))
	_ok(andou > 30.0, "o jogador anda", "%.0f px para leste" % andou)

	# Contra a borda: em qualquer direcao ele tem de continuar dentro do mapa.
	var quinas_mapa := mundo.quinas_do_mapa()
	var fugiu := false
	var vazou_terreno := false
	for dir in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1),
			Vector2(1, 1), Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1)]:
		jogador.position = spawn
		jogador.velocity = Vector2.ZERO
		await _empurrar(jogador, spawn, dir, PASSOS_DE_TESTE * 4)
		if not _dentro_do_losango(jogador.position, quinas_mapa):
			fugiu = true
			print("       fugiu na direcao %s -> %s" % [dir, jogador.position])
		var c := mundo.mundo_para_celula(jogador.position)
		if mundo.bloqueia(c):
			vazou_terreno = true
			print("       parou em terreno bloqueado %s (%s) indo %s"
					% [c, mundo.terreno_em(c), dir])
	_ok(not fugiu, "nao sai do mapa em nenhuma das 8 direcoes")
	_ok(not vazou_terreno, "nunca termina dentro de agua ou rocha")

	# Contra o lago, de perto: anda ate a agua e tem de parar na margem.
	var margem := _celula_pisavel_junto_a(mundo, "agua")
	if not margem.is_empty():
		var alvo := mundo.celula_para_mundo(margem[1])
		jogador.position = mundo.celula_para_mundo(margem[0])
		jogador.velocity = Vector2.ZERO
		var rumo := (alvo - jogador.position).normalized()
		await _empurrar(jogador, jogador.position, rumo, PASSOS_DE_TESTE)
		var final_c := mundo.mundo_para_celula(jogador.position)
		_ok(mundo.terreno_em(final_c) != "agua", "o lago barra o jogador",
				"parou em %s (%s)" % [final_c, mundo.terreno_em(final_c)])

	# Contra uma casa: empurra de baixo para cima contra a parede.
	var casas := get_nodes_in_group("casas")
	if not casas.is_empty():
		var casa := casas[0] as Node2D
		jogador.position = casa.position + Vector2(0, 90)
		jogador.velocity = Vector2.ZERO
		await _empurrar(jogador, jogador.position, Vector2(0, -1), PASSOS_DE_TESTE)
		var dist := jogador.position.distance_to(casa.position)
		_ok(dist > 20.0, "a casa barra o jogador",
				"parou a %.0f px do centro da casa '%s'"
				% [dist, String(casa.get_meta("id", casa.name))])


## Empurra o corpo por N frames de fisica numa direcao de tela e devolve quanto
## andou. A direcao entra como a entrada entraria — inclusive o achatamento
## isometrico do eixo vertical.
func _empurrar(corpo: CharacterBody2D, origem: Vector2, direcao: Vector2,
		passos: int = PASSOS_DE_TESTE) -> float:
	var d := direcao.normalized()
	for i in passos:
		corpo.velocity = Vector2(d.x, d.y * Jogador.RAZAO_ISO) * Jogador.VELOCIDADE
		corpo.move_and_slide()
		await physics_frame
	return corpo.position.distance_to(origem)


func _dentro_do_losango(p: Vector2, quinas: PackedVector2Array) -> bool:
	for i in quinas.size():
		var a: Vector2 = quinas[i]
		var b: Vector2 = quinas[(i + 1) % quinas.size()]
		# Quinas em sentido horario: o produto vetorial tem de ser >= 0 para
		# todos os lados se o ponto estiver dentro.
		if (b - a).cross(p - a) < -1.0:
			return false
	return true


## Par [celula pisavel, celula do terreno alvo] vizinhas. Serve para lancar o
## jogador contra um terreno especifico a partir do lado de fora.
func _celula_pisavel_junto_a(mundo: MundoIso, terreno: String) -> Array[Vector2i]:
	for gy in range(1, mundo.profundidade - 1):
		for gx in range(1, mundo.largura - 1):
			var c := Vector2i(gx, gy)
			if mundo.bloqueia(c) or mundo.terreno_em(c) == "grama_alta":
				continue
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				if mundo.terreno_em(c + d) == terreno:
					return [c, c + d] as Array[Vector2i]
	return [] as Array[Vector2i]
