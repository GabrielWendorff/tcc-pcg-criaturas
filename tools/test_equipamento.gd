extends SceneTree

## Teste headless do equipamento na mao e da roda de itens — roda SEM janela:
##   godot --headless --path . -s res://tools/test_equipamento.gd
##
##   1. GEOMETRIA DA RODA (regra pura): slot 0 no topo, sentido horario, zona
##      morta e as FRONTEIRAS entre setores, para n = 1..8. Um setor deslocado
##      meio slot nao da erro nenhum — parece um mouse impreciso na tela.
##   2. POSES DA MAO (regra pura): as quatro direcoes, os padroes embutidos sem
##      arquivo, a sobreposicao da pose de pesca e o sentido do giro do lance.
##   3. ITENS: mao/uso lidos do catalogo, equipavel(), todo item com icone, os
##      indices antigos da folha intactos e a fonte cobrindo os textos novos.
##   4. SAVE: item_equipado vai e volta; save antigo sem o campo le "".
##   5. INPUT: as tres acoes novas, com os eventos certos e sem tecla repetida.
##   6. NOS: SlotDaMao/ItemNaMao num corpo de teste (troca sem recriar, ordem de
##      desenho ANTES/DEPOIS do Sprite, ponta global), o Jogador de verdade e a
##      RodaItens dirigida por vetor e por evento.
##
## Nada aqui cita Bolsa, Save ou Opcoes: sob -s os autoloads nao compilam no
## 4.7, e o que se testa e justamente a parte que nao depende deles.
##
## Sai com codigo != 0 se algo falhar.

## Ids e indices da folha de icones ANTES de lanterna e pa_de_jardim. Item novo
## entra no fim (ver tools/arte/gerar_itens.py); se algum destes mudar, alguem
## inseriu no meio.
const INDICES_ANTIGOS := {
	"esfera_simples": 0, "esfera_reforcada": 1, "rede_de_caca": 2,
	"armadilha_de_aco": 3, "redoma_aquatica": 4, "prisma_selante": 5,
	"osso": 6, "carne_seca": 7, "petisco_felino": 8, "peixe_seco": 9,
	"minhoca": 10, "sementes": 11, "queijo_curado": 12, "nectar_floral": 13,
	"fruta_madura": 14, "larva_viva": 15, "vara_de_pesca": 16,
	"pocao_simples": 17, "pocao_forte": 18, "elixir_de_folego": 19,
}

var _falhas: int = 0
var _verificacoes: int = 0


func _initialize() -> void:
	print("== Equipamento e roda de itens — teste headless ==")
	_testar_geometria()
	_testar_poses()
	var catalogo := _testar_itens()
	_testar_save()
	_testar_input()
	if catalogo != null:
		await _testar_nos(catalogo)
		_testar_jogador(catalogo)
		_testar_roda(catalogo)
	_testar_regras_puras()

	print("\n==")
	if _verificacoes < 120:
		print("RESULTADO: so %d verificacoes rodaram — o teste abortou no meio"
				% _verificacoes)
		quit(1)
	elif _falhas > 0:
		print("RESULTADO: %d VERIFICACAO(OES) FALHARAM" % _falhas)
		quit(1)
	else:
		print("RESULTADO: TODOS OS TESTES PASSARAM (%d verificacoes)" % _verificacoes)
		quit(0)


# ----------------------------------------------------------- 1. geometria

func _testar_geometria() -> void:
	print("\n-- 1. GeometriaRoda")
	var raio := 100.0
	var zona := 36.0
	for n in range(1, 9):
		var passo: float = TAU / float(n)
		var angulos_ok := true
		var centros_ok := true
		var fronteiras_ok := true
		var detalhe := ""
		for i in n:
			if not is_equal_approx(GeometriaRoda.angulo_do_slot(i, n), passo * i):
				angulos_ok = false
				detalhe = "slot %d de %d: %f" % [i, n, GeometriaRoda.angulo_do_slot(i, n)]
			# Apontar o CENTRO do desenho do slot cai no setor dele.
			var centro_slot := GeometriaRoda.posicao_do_slot(i, n, raio)
			if GeometriaRoda.indice_por_vetor(centro_slot, n, zona) != i:
				centros_ok = false
			# Fronteira entre i e i+1: um fio antes e um fio depois.
			if n > 1:
				var b: float = passo * (float(i) + 0.5)
				var antes := GeometriaRoda.direcao_do_angulo(b - 0.001) * raio
				var depois := GeometriaRoda.direcao_do_angulo(b + 0.001) * raio
				if GeometriaRoda.indice_por_vetor(antes, n, zona) != i \
						or GeometriaRoda.indice_por_vetor(depois, n, zona) != (i + 1) % n:
					fronteiras_ok = false
					detalhe = "fronteira %d|%d de %d" % [i, (i + 1) % n, n]
		_ok(angulos_ok and is_zero_approx(GeometriaRoda.angulo_do_slot(0, n)),
				"n=%d: slot 0 com angulo 0, passo TAU/n" % n, detalhe)
		_ok(GeometriaRoda.posicao_do_slot(0, n, raio).is_equal_approx(Vector2(0, -raio)),
				"n=%d: slot 0 no TOPO da tela" % n)
		_ok(centros_ok, "n=%d: apontar o centro de cada slot o seleciona" % n)
		_ok(fronteiras_ok, "n=%d: fronteiras exatas entre setores vizinhos" % n, detalhe)

	# Sentido horario na TELA (y para baixo).
	_ok(GeometriaRoda.posicao_do_slot(1, 4, raio).is_equal_approx(Vector2(raio, 0)),
			"n=4: slot 1 a direita (sentido horario)")
	_ok(GeometriaRoda.posicao_do_slot(2, 4, raio).is_equal_approx(Vector2(0, raio)),
			"n=4: slot 2 embaixo")
	_ok(GeometriaRoda.indice_por_vetor(Vector2(-50, 0), 4, 10.0) == 3,
			"n=4: apontar para a esquerda = slot 3")
	_ok(is_equal_approx(GeometriaRoda.angulo_de_vetor(Vector2(1, 0)), PI * 0.5),
			"angulo de bussola: direita = PI/2")

	# Zona morta.
	_ok(GeometriaRoda.indice_por_vetor(Vector2(0, -35.9), 4, zona) == -1,
			"dentro da zona morta: -1")
	_ok(GeometriaRoda.indice_por_vetor(Vector2(0, -36.0), 4, zona) == 0,
			"na borda da zona morta ja seleciona")
	_ok(GeometriaRoda.indice_por_vetor(Vector2.ZERO, 4, zona) == -1,
			"vetor nulo = zona morta")
	_ok(GeometriaRoda.indice_por_vetor(Vector2(80, 80), 0, zona) == -1,
			"roda vazia: -1")
	_ok(GeometriaRoda.indice_por_vetor(Vector2(0, 80), 1, zona) == 0,
			"n=1: qualquer direcao fora da zona morta e o unico slot")
	_ok(is_zero_approx(GeometriaRoda.angulo_do_slot(3, 0)), "n=0 nao gera NaN")


# --------------------------------------------------------------- 2. poses

func _testar_poses() -> void:
	print("\n-- 2. PosesDaMao")
	var sem := PosesDaMao.carregar("res://data/itens/nao_existe.json")
	_ok(sem != null, "sem arquivo, carregar() devolve os padroes (nunca null)")
	for dir: String in PosesDaMao.DIRECOES:
		var p := sem.pose(dir)
		var esperado: Dictionary = PosesDaMao.POSES_PADRAO[dir]
		_ok(p["posicao"] is Vector2 and p["rotacao"] is float and p["atras"] is bool
				and p["espelhar"] is bool,
				"padrao '%s' tem as quatro chaves com os tipos certos" % dir)
		_ok((p["posicao"] as Vector2).is_equal_approx(esperado["posicao"])
				and is_equal_approx(float(p["rotacao"]), float(esperado["rotacao"])),
				"padrao '%s' = POSES_PADRAO" % dir)

	var poses := PosesDaMao.carregar()
	_ok(poses.erro == "", "data/itens/mao.json lido sem erro", poses.erro)
	for dir: String in PosesDaMao.DIRECOES:
		var p := poses.pose(dir)
		var pos: Vector2 = p["posicao"]
		# A mao fica dentro do quadro do sprite (24x24, offset (-12, -22)).
		_ok(pos.x >= -12.0 and pos.x <= 12.0 and pos.y >= -22.0 and pos.y <= 0.0,
				"'%s': mao dentro do quadro do jogador" % dir, str(pos))
		_ok(bool(p["atras"]) == (dir == "cima"),
				"'%s': atras do corpo so olhando para cima" % dir)
		var pp := poses.pose(dir, true)
		_ok((pp["posicao"] as Vector2).is_equal_approx(pos)
				and not is_equal_approx(float(pp["rotacao"]), float(p["rotacao"])),
				"'%s': pose de pesca muda a rotacao e mantem a mao" % dir,
				"%s -> %s graus" % [p["rotacao"], pp["rotacao"]])
	_ok(poses.pose("diagonal").hash() == poses.pose("baixo").hash(),
			"direcao desconhecida cai em 'baixo'")
	_ok(poses.sinal_do_giro("esquerda") == -1.0 and poses.sinal_do_giro("direita") == 1.0,
			"o giro do lance se inverte na pose espelhada")
	_ok(poses.duracao_recuo > 0.0 and poses.duracao_avanco > 0.0
			and signf(poses.recuo_graus) != signf(poses.avanco_graus),
			"arremesso: recuo e avanco em sentidos opostos, duracoes positivas")
	# Espelhada ou nao, a ponta vai para FORA do corpo: o x da ponta tem o sinal
	# do x da mao (baixo/esquerda a esquerda, direita a direita).
	for dir: String in ["baixo", "esquerda", "direita"]:
		var p := poses.pose(dir)
		var ponta_x: float = (p["posicao"] as Vector2).x \
				+ sin(deg_to_rad(float(p["rotacao"]))) * 18.0
		_ok(signf(ponta_x) == signf((p["posicao"] as Vector2).x),
				"'%s': a vara se abre para fora, sem cruzar o rosto" % dir,
				"ponta em x=%.1f" % ponta_x)

	var parcial := PosesDaMao.de_dicionario({"poses": {"direita": {"rotacao": 10}},
			"pesca": {"direita": {"posicao": [1, -2]}}})
	_ok(is_equal_approx(float(parcial.pose("direita")["rotacao"]), 10.0)
			and (parcial.pose("direita")["posicao"] as Vector2).is_equal_approx(Vector2(6, -7)),
			"JSON parcial sobrescreve so o campo declarado")
	_ok((parcial.pose("direita", true)["posicao"] as Vector2).is_equal_approx(Vector2(1, -2)),
			"a pose de pesca pode sobrescrever qualquer campo, em [x, y]")
	var torta := PosesDaMao.de_dicionario({"poses": {"direita": "lixo"}})
	_ok(torta.erro != "" and torta.pose("direita")["posicao"] is Vector2,
			"pose malformada e ignorada com erro, sem quebrar as outras")


# --------------------------------------------------------------- 3. itens

func _testar_itens() -> CatalogoItens:
	print("\n-- 3. Itens")
	var cat := CatalogoItens.carregar(null)
	_ok(cat != null, "CatalogoItens.carregar(null) le data/itens/catalogo.json")
	if cat == null:
		return null

	var vara := cat.item("vara_de_pesca")
	_ok(vara != null and vara.equipavel(), "a vara e equipavel")
	if vara != null:
		_ok(String(vara.mao.get("forma", "")) == "vara"
				and float(vara.mao.get("comprimento", 0.0)) > 0.0,
				"a vara declara forma e comprimento de mao", str(vara.mao))
		_ok(vara.uso == "pescar", "o uso da vara e 'pescar'")
	for id: String in ["lanterna", "pa_de_jardim"]:
		var it := cat.item(id)
		_ok(it != null, "item de exemplo '%s' existe" % id)
		if it == null:
			continue
		_ok(it.categoria == "ferramentas" and not it.empilhavel and it.permanente
				and it.quantidade_inicial == 1 and it.equipavel() and it.uso == "",
				"'%s': ferramenta, nao empilha, permanente, 1 inicial, equipavel, so sprite" % id)
		_ok(String(it.mao.get("forma", "")) in ["lanterna", "pa"],
				"'%s' tem forma propria de mao" % id, str(it.mao))
	var pocao := cat.item("pocao_simples")
	_ok(pocao != null and not pocao.equipavel() and pocao.mao.is_empty()
			and pocao.uso == "", "consumivel nao e equipavel e nao tem mao/uso")
	var torto := ItemJogo.de_dicionario({"id": "x", "mao": "vara", "uso": 3}, "ferramentas")
	_ok(torto.mao.is_empty() and torto.uso == "",
			"'mao' que nao e objeto vira {} e 'uso' que nao e texto vira ''")

	# Todo equipavel tem forma conhecida (ou arte final declarada).
	var equipaveis := cat.com_marcador("equipamento")
	_ok(equipaveis.size() >= 3, "pelo menos 3 equipaveis no catalogo",
			"%d" % equipaveis.size())
	for it: ItemJogo in equipaveis:
		var forma := String(it.mao.get("forma", ItemNaMao.FORMA_PADRAO))
		_ok(forma in ItemNaMao.FORMAS or it.mao.has("textura") or it.mao.has("cena"),
				"'%s': forma de mao conhecida ('%s')" % [it.id, forma])

	# Icones: todo item do catalogo — e os de captura, quando as tabelas sobem.
	var ids := IconeCaptura.ids_conhecidos()
	var completo := cat
	var captura := TabelasCaptura.carregar()
	if captura != null:
		var com_captura := CatalogoItens.carregar(captura)
		if com_captura != null:
			completo = com_captura
	var sem_icone := PackedStringArray()
	for it: ItemJogo in completo.itens:
		if not it.id in ids:
			sem_icone.append(it.id)
	_ok(sem_icone.is_empty(), "todo item do catalogo (%d) tem icone na folha"
			% completo.itens.size(), ", ".join(sem_icone))

	# A folha cresceu so no fim.
	var bruto: Variant = JSON.parse_string(
			FileAccess.get_file_as_string(IconeCaptura.CAMINHO_INDICE))
	var indice: Dictionary = (bruto as Dictionary).get("itens", {}) if bruto is Dictionary else {}
	var mudaram := PackedStringArray()
	for id: String in INDICES_ANTIGOS.keys():
		if int(indice.get(id, -1)) != int(INDICES_ANTIGOS[id]):
			mudaram.append(id)
	_ok(mudaram.is_empty(), "os 20 indices antigos da folha nao mudaram", ", ".join(mudaram))
	_ok(int(indice.get("lanterna", -1)) >= INDICES_ANTIGOS.size()
			and int(indice.get("pa_de_jardim", -1)) >= INDICES_ANTIGOS.size(),
			"lanterna e pa_de_jardim entraram no fim da folha")
	var folha := IconeCaptura.folha()
	_ok(folha != null, "IconeCaptura.folha() devolve a textura")
	var r := IconeCaptura.regiao("lanterna")
	var i_lanterna: int = int(indice.get("lanterna", 0))
	_ok(r.is_equal_approx(Rect2((i_lanterna % 8) * 20, floori(i_lanterna / 8.0) * 20, 20, 20)),
			"IconeCaptura.regiao('lanterna') recorta a celula certa", str(r))
	_ok(folha != null and Rect2(Vector2.ZERO, folha.get_size()).encloses(r),
			"o recorte cabe na folha")
	_ok(not IconeCaptura.regiao("nao_existe").has_area(), "id sem icone: Rect2() vazio")

	# Glifos: tudo que a roda e os itens novos escrevem na tela.
	var textos := PackedStringArray([RodaItens.TEXTO_TITULO, RodaItens.TEXTO_MAOS_LIVRES,
			RodaItens.TEXTO_CONTROLES, RodaItens.TEXTO_EQUIPADO, RodaItens.TEXTO_SOLTE,
			RodaItens.TEXTO_NA_MAO])
	for it: ItemJogo in equipaveis:
		textos.append(it.nome)
		textos.append(it.nome.to_upper())
		textos.append(it.descricao)
	var fonte := TemaEncontro.fonte()
	var faltando := PackedStringArray()
	for t: String in textos:
		for k in t.length():
			var ch: String = t[k]
			if not fonte.has_char(ch.unicode_at(0)) and not ch in faltando:
				faltando.append(ch)
	_ok(faltando.is_empty(), "a fonte pixel cobre os textos da roda e dos itens",
			"faltam: " + " ".join(faltando))
	return cat


# ---------------------------------------------------------------- 4. save

func _testar_save() -> void:
	print("\n-- 4. DadosPartida.item_equipado")
	var d := DadosPartida.nova(123456789)
	_ok(d.item_equipado == "", "partida nova comeca de maos livres")
	d.item_equipado = "vara_de_pesca"
	var bruto := d.para_dicionario()
	_ok(String((bruto["jogador"] as Dictionary).get("item_equipado", "")) == "vara_de_pesca",
			"o campo vai para a secao 'jogador'")
	var volta := DadosPartida.de_dicionario(JSON.parse_string(JSON.stringify(bruto)))
	_ok(volta.valido() and volta.item_equipado == "vara_de_pesca",
			"ida e volta pelo JSON preserva o item na mao")
	var antigo := d.para_dicionario()
	(antigo["jogador"] as Dictionary).erase("item_equipado")
	var lido := DadosPartida.de_dicionario(antigo)
	_ok(lido.valido() and lido.item_equipado == "",
			"save antigo sem o campo carrega de maos livres")
	_ok(DadosPartida.VERSAO_ATUAL == 1, "campo opcional: a versao do formato nao subiu")


# --------------------------------------------------------------- 5. input

func _testar_input() -> void:
	print("\n-- 5. InputMap")
	_ok(_tem_tecla("usar_item", KEY_F) and _tem_mouse("usar_item", MOUSE_BUTTON_LEFT)
			and _tem_joy("usar_item", JOY_BUTTON_X),
			"usar_item: F (fisica) + botao esquerdo + joypad 2")
	_ok(_tem_tecla("roda_itens", KEY_Q) and _tem_joy("roda_itens", JOY_BUTTON_LEFT_SHOULDER),
			"roda_itens: Q (fisica) + joypad 9")
	_ok(_tem_tecla("pular_tutorial", KEY_P), "pular_tutorial: P (fisica)")
	for acao: String in ["usar_item", "roda_itens", "pular_tutorial"]:
		var bruto: Variant = ProjectSettings.get_setting("input/" + acao)
		_ok(bruto is Dictionary and (bruto as Dictionary).has("events"),
				"'%s' esta serializada em project.godot" % acao)
	# Nenhuma tecla nova ja era de outra acao do jogo.
	for tecla: int in [KEY_F, KEY_Q, KEY_P]:
		var donos := PackedStringArray()
		for acao: StringName in InputMap.get_actions():
			if String(acao).begins_with("ui_"):
				continue
			for ev: InputEvent in InputMap.action_get_events(acao):
				if ev is InputEventKey and ((ev as InputEventKey).physical_keycode == tecla
						or (ev as InputEventKey).keycode == tecla):
					donos.append(String(acao))
		_ok(donos.size() == 1, "tecla %s pertence a uma acao so"
				% OS.get_keycode_string(tecla as Key),
				", ".join(donos))


func _tem_tecla(acao: String, tecla: Key) -> bool:
	if not InputMap.has_action(acao):
		return false
	for ev: InputEvent in InputMap.action_get_events(acao):
		if ev is InputEventKey and (ev as InputEventKey).physical_keycode == tecla:
			return true
	return false


func _tem_mouse(acao: String, botao: MouseButton) -> bool:
	if not InputMap.has_action(acao):
		return false
	for ev: InputEvent in InputMap.action_get_events(acao):
		if ev is InputEventMouseButton and (ev as InputEventMouseButton).button_index == botao:
			return true
	return false


func _tem_joy(acao: String, botao: JoyButton) -> bool:
	if not InputMap.has_action(acao):
		return false
	for ev: InputEvent in InputMap.action_get_events(acao):
		if ev is InputEventJoypadButton and (ev as InputEventJoypadButton).button_index == botao:
			return true
	return false


# ---------------------------------------------------------------- 6. nos

func _testar_nos(cat: CatalogoItens) -> void:
	print("\n-- 6a. SlotDaMao e ItemNaMao num corpo de teste")
	# Durante _initialize a raiz ainda NAO esta na arvore (SceneTree.initialize
	# chama o script antes de _set_tree): no adicionado agora nao tem transform
	# global nem tween. Um quadro e ela entra.
	if not root.is_inside_tree():
		await process_frame
	var vara := cat.item("vara_de_pesca")
	var lanterna := cat.item("lanterna")
	var pa := cat.item("pa_de_jardim")

	# Corpo que imita o Jogador: colisao, Sprite, e o slot por ultimo.
	var corpo := Node2D.new()
	corpo.name = "CorpoDeTeste"
	var colisao := Node2D.new()
	colisao.name = "Corpo"
	corpo.add_child(colisao)
	var sprite := Node2D.new()
	sprite.name = "Sprite"
	corpo.add_child(sprite)
	var slot := SlotDaMao.new()
	corpo.add_child(slot)
	corpo.position = Vector2(100, 50)
	root.add_child(corpo)

	var visual := slot.visual
	_ok(slot.name == SlotDaMao.NOME and slot.get_child_count() == 1
			and slot.get_child(0) == visual, "o slot nasce com um ItemNaMao so")
	_ok(slot.item == null and not visual.visible, "nasce de mao vazia")
	_ok(not slot.atras_do_corpo() and slot.get_index() > sprite.get_index(),
			"pose inicial ('baixo') desenha DEPOIS do Sprite")

	slot.equipar(vara)
	_ok(slot.item == vara and visual.forma == "vara" and visual.visible,
			"equipar a vara mostra a vara")
	_ok(is_equal_approx(visual.comprimento, float(vara.mao["comprimento"])),
			"o comprimento vem do JSON")
	slot.equipar(lanterna)
	_ok(slot.visual == visual and slot.get_child_count() == 1 and visual.forma == "lanterna",
			"trocar de item reaproveita o MESMO no de desenho")
	slot.equipar(pa)
	_ok(visual.forma == "pa" and visual.ponta_local().is_equal_approx(
			Vector2(0, -float(pa.mao["comprimento"]))), "a pa tem ponta no topo da lamina")
	slot.equipar(null)
	_ok(slot.item == null and not visual.visible and visual.forma == ""
			and is_instance_valid(visual), "equipar(null) esvazia sem destruir o no")

	# Ordem de desenho, nao z_index.
	slot.equipar(vara)
	slot.aplicar_direcao("cima")
	_ok(slot.get_index() < sprite.get_index() and slot.atras_do_corpo(),
			"'cima': slot ANTES do Sprite (atras do corpo)")
	_ok(slot.z_index == 0 and visual.z_index == 0, "nenhum z_index mexido")
	slot.aplicar_direcao("baixo")
	_ok(slot.get_index() > sprite.get_index() and not slot.atras_do_corpo(),
			"'baixo': slot DEPOIS do Sprite (na frente)")
	slot.aplicar_direcao("cima")
	slot.aplicar_direcao("direita")
	_ok(slot.get_index() == sprite.get_index() + 1,
			"de 'cima' para 'direita': logo depois do Sprite")
	_ok(colisao.get_index() == 0, "os outros filhos do corpo nao sao reordenados")
	var poses := slot.poses
	for dir: String in PosesDaMao.DIRECOES:
		slot.aplicar_direcao(dir)
		var p := poses.pose(dir)
		_ok(slot.position.is_equal_approx(p["posicao"])
				and is_equal_approx(slot.rotation_degrees, float(p["rotacao"]))
				and is_equal_approx(slot.scale.x, -1.0 if bool(p["espelhar"]) else 1.0),
				"'%s': posicao, rotacao e espelho da pose" % dir)

	# Ponta global: a origem da linha de pesca.
	slot.aplicar_direcao("direita")
	var p_dir := poses.pose("direita")
	var esperado: Vector2 = corpo.position + (p_dir["posicao"] as Vector2) \
			+ Vector2(0, -float(vara.mao["comprimento"])).rotated(
					deg_to_rad(float(p_dir["rotacao"])))
	_ok(slot.ponta_global().is_equal_approx(esperado), "ponta_global coerente com a pose",
			"%s (esperado %s)" % [slot.ponta_global(), esperado])
	slot.aplicar_direcao("esquerda")
	_ok(slot.ponta_global().x < slot.global_position.x
			and slot.ponta_global().y < slot.global_position.y,
			"olhando para a esquerda a ponta fica a esquerda e acima da mao")
	slot.equipar(null)
	_ok(slot.ponta_global().is_equal_approx(slot.global_position),
			"sem item, a ponta e a propria mao")

	# Item sem desenho de mao: icone pequeno.
	var generico := ItemJogo.de_dicionario({"id": "minhoca", "nome": "Minhoca",
			"marcadores": ["equipamento"]}, "iscas")
	slot.equipar(generico)
	_ok(visual.forma == "icone" and visual.ponta_local().is_equal_approx(
			Vector2(0, -20.0 * ItemNaMao.ESCALA_ICONE_PADRAO)),
			"sem 'mao', o item aparece como o icone pequeno")
	var estranho := ItemJogo.de_dicionario({"id": "x", "marcadores": ["equipamento"],
			"mao": {"forma": "espada"}}, "ferramentas")
	slot.equipar(estranho)
	_ok(visual.forma == ItemNaMao.FORMA_PADRAO, "forma desconhecida cai no icone")

	# Arte final por cima do placeholder.
	var com_arte := ItemJogo.de_dicionario({"id": "vara_de_pesca", "marcadores": ["equipamento"],
			"mao": {"forma": "vara", "textura": IconeCaptura.CAMINHO_FOLHA}}, "ferramentas")
	slot.equipar(com_arte)
	var tam := IconeCaptura.folha().get_size()
	_ok(visual.tem_arte() and visual.get_node_or_null("Arte") is Sprite2D,
			"'textura' substitui o placeholder por um Sprite2D")
	_ok(visual.ponta_local().is_equal_approx(Vector2(0, -tam.y)),
			"ponta padrao da textura: meio da borda de cima", str(visual.ponta_local()))
	slot.equipar(vara)
	_ok(not visual.tem_arte() and visual.get_node_or_null("Arte") == null,
			"voltar ao placeholder remove a arte na hora")
	var sem_arquivo := ItemJogo.de_dicionario({"id": "y", "marcadores": ["equipamento"],
			"mao": {"forma": "pa", "textura": "res://nao/existe.png"}}, "ferramentas")
	slot.equipar(sem_arquivo)
	_ok(not visual.tem_arte() and visual.forma == "pa",
			"textura inexistente: fica o placeholder da forma")

	# Pose de pesca e arremesso.
	slot.equipar(vara)
	slot.aplicar_direcao("direita")
	slot.pose_de_pesca(true)
	_ok(is_equal_approx(slot.rotation_degrees, float(poses.pose("direita", true)["rotacao"])),
			"pose_de_pesca(true) ergue a vara")
	var ouvido := {"n": 0}
	var ouvinte := func() -> void: ouvido["n"] = int(ouvido["n"]) + 1
	slot.arremesso_concluido.connect(ouvinte)
	var recuo_esperado: float = float(poses.pose("direita", true)["rotacao"]) + poses.recuo_graus
	var menor_rotacao: float = slot.rotation_degrees
	slot.animar_arremesso()
	var quadros := 0
	while int(ouvido["n"]) == 0 and quadros < 240:
		await process_frame
		menor_rotacao = minf(menor_rotacao, slot.rotation_degrees)
		quadros += 1
	_ok(int(ouvido["n"]) == 1, "animar_arremesso emite arremesso_concluido uma vez",
			"%d quadros" % quadros)
	_ok(menor_rotacao < float(poses.pose("direita", true)["rotacao"]) - 10.0,
			"a vara recua antes do lance",
			"chegou a %.1f graus (recuo pedido: %.1f)" % [menor_rotacao, recuo_esperado])
	_ok(not visual.boia_na_ponta, "depois do lance a boia sai da ponta (a linha e da pesca)")
	slot.pose_de_pesca(false)
	_ok(visual.boia_na_ponta and is_equal_approx(slot.rotation_degrees,
			float(poses.pose("direita")["rotacao"])),
			"pose_de_pesca(false) devolve a pose comum e a boia")
	# Lance interrompido ainda termina.
	slot.animar_arremesso()
	slot.aplicar_direcao("esquerda")
	_ok(int(ouvido["n"]) == 2, "trocar de direcao no meio do lance ainda emite o sinal")
	# Sem item: o sinal sai DEFERIDO (a tempo de quem faz await logo depois).
	slot.equipar(null)
	slot.animar_arremesso()
	_ok(int(ouvido["n"]) == 2, "sem item o sinal nao sai sincrono")
	await process_frame
	await process_frame
	_ok(int(ouvido["n"]) == 3, "sem item o sinal sai no quadro seguinte")
	slot.arremesso_concluido.disconnect(ouvinte)
	corpo.queue_free()
	await process_frame


func _testar_jogador(cat: CatalogoItens) -> void:
	print("\n-- 6b. Jogador")
	var vara := cat.item("vara_de_pesca")
	var lanterna := cat.item("lanterna")
	var pocao := cat.item("pocao_simples")

	var j := Jogador.new()
	root.add_child(j)
	_ok(j.mao != null and j.mao.get_parent() == j and j.mao.name == SlotDaMao.NOME,
			"o jogador monta a mao (SlotDaMao) como filho")
	var sprite := j.get_node_or_null("Sprite")
	_ok(sprite != null and j.mao.get_index() > sprite.get_index(),
			"a mao nasce depois do Sprite (olhando para baixo)")
	var ouvidos: Array[String] = []
	j.item_equipado_mudou.connect(func(id: String) -> void: ouvidos.append(id))
	j.equipar(vara)
	_ok(j.item_equipado == "vara_de_pesca" and j.item_atual() == vara
			and j.mao.item == vara, "equipar poe a vara na mao")
	j.equipar(vara)
	_ok(ouvidos.size() == 1 and ouvidos[0] == "vara_de_pesca",
			"re-equipar o mesmo item nao reemite o sinal",
			str(ouvidos))
	j.equipar(pocao)
	_ok(j.item_equipado == "vara_de_pesca", "item sem marcador 'equipamento' e recusado")
	j.direcao = "cima"
	j._aplicar_animacao()
	_ok(j.mao.get_index() < sprite.get_index() and j.mao.direcao == "cima",
			"_aplicar_animacao leva a direcao para a mao (cima = atras)")
	j.equipar(null)
	_ok(j.item_equipado == "" and j.item_atual() == null and ouvidos.size() == 2
			and ouvidos[1] == "",
			"equipar(null) volta a maos livres e avisa com ''", str(ouvidos))
	j.queue_free()

	# Equipar antes de entrar na arvore (a cena repoe o save logo apos criar).
	var j2 := Jogador.new()
	j2.equipar(lanterna)
	_ok(j2.mao == null and j2.item_equipado == "lanterna",
			"equipar antes do _ready guarda o item")
	root.add_child(j2)
	_ok(j2.mao != null and j2.mao.item == lanterna and j2.mao.visual.forma == "lanterna",
			"a mao montada no _ready recebe o item guardado")
	j2.queue_free()


func _testar_roda(cat: CatalogoItens) -> void:
	print("\n-- 6c. RodaItens")
	var vara := cat.item("vara_de_pesca")
	var lanterna := cat.item("lanterna")
	var pa := cat.item("pa_de_jardim")
	var roda := RodaItens.new()
	roda.capturar_mouse = false
	roda.duracao_abertura = 0.0
	root.add_child(roda)
	_ok(roda.layer == RodaItens.CAMADA and RodaItens.CAMADA == 88, "CanvasLayer na camada 88")
	_ok(not roda.aberta() and not roda.visible, "nasce fechada")

	var escolhas: Array = []
	var fechamentos: Array[bool] = []
	roda.item_escolhido.connect(func(it: ItemJogo) -> void: escolhas.append(it))
	roda.fechada.connect(func(trocou: bool) -> void: fechamentos.append(trocou))

	roda.abrir([vara, lanterna, pa, "lixo", null], "lanterna")
	_ok(roda.aberta() and roda.visible, "abrir mostra a roda")
	_ok(roda.total_de_slots() == 4 and roda.item_do_slot(0) == null
			and roda.item_do_slot(1) == vara,
			"'Maos livres' no topo + so os ItemJogo da lista")
	_ok(roda.indice_destacado() == -1, "abre na zona morta")
	roda.apontar(Vector2(0, -roda.raio))
	_ok(roda.indice_destacado() == 0, "apontar para cima destaca 'Maos livres'")
	roda.apontar(GeometriaRoda.posicao_do_slot(2, 4, roda.raio))
	_ok(roda.indice_destacado() == 2, "apontar o slot 2 o destaca")
	roda.apontar(Vector2(roda.zona_morta * 0.5, 0))
	_ok(roda.indice_destacado() == -1, "voltar ao centro tira o destaque")
	roda.fechar(true)
	_ok(not roda.aberta() and escolhas.is_empty() and fechamentos.size() == 1
			and fechamentos[0] == false,
			"soltar na zona morta nao escolhe nada")

	roda.abrir([vara, lanterna, pa], "lanterna")
	roda.apontar(GeometriaRoda.posicao_do_slot(1, 4, roda.raio))
	roda.fechar(true)
	_ok(escolhas.size() == 1 and escolhas[0] == vara and fechamentos.back() == true,
			"confirmar a vara emite item_escolhido(vara) e fechada(true)")

	roda.abrir([vara, lanterna, pa], "lanterna")
	roda.apontar(GeometriaRoda.posicao_do_slot(2, 4, roda.raio))
	roda.fechar(true)
	_ok(escolhas.size() == 2 and escolhas[1] == lanterna and fechamentos.back() == false,
			"confirmar o item que ja esta na mao: escolhido, mas trocou = false")

	roda.abrir([vara, lanterna, pa], "lanterna")
	roda.apontar(Vector2(0, -roda.raio))
	roda.fechar(true)
	_ok(escolhas.size() == 3 and escolhas[2] == null and fechamentos.back() == true,
			"'Maos livres' emite item_escolhido(null)")

	roda.abrir([vara, lanterna, pa], "")
	roda.apontar(GeometriaRoda.posicao_do_slot(1, 4, roda.raio))
	roda.fechar(false)
	_ok(escolhas.size() == 3 and fechamentos.back() == false, "cancelar nao escolhe nada")
	roda.fechar(true)
	_ok(fechamentos.size() == 5, "fechar de novo uma roda fechada nao reemite")

	# Pelos eventos de entrada, como o jogo entrega.
	roda.abrir([vara, lanterna, pa], "")
	# O cursor do sistema pode estar em QUALQUER lugar (no Wayland a roda nao
	# consegue move-lo): so o movimento RELATIVO conta, e a roda abre na zona morta.
	var longe := InputEventMouseMotion.new()
	longe.position = roda.centro() + Vector2(400, 300)
	longe.relative = Vector2(4, 3)
	roda._input(longe)
	_ok(roda.indice_destacado() == -1,
			"cursor longe do centro + gesto pequeno continua na zona morta (Wayland)")
	var mov := InputEventMouseMotion.new()
	mov.position = roda.centro() + Vector2(400, 300)
	mov.relative = GeometriaRoda.posicao_do_slot(3, 4, roda.raio)
	roda._input(mov)
	_ok(roda.indice_destacado() == 3, "movimento relativo do mouse aponta pelo angulo")
	var muito := InputEventMouseMotion.new()
	muito.relative = GeometriaRoda.posicao_do_slot(3, 4, roda.raio) * 20.0
	roda._input(muito)
	var volta := InputEventMouseMotion.new()
	volta.relative = -GeometriaRoda.posicao_do_slot(3, 4, roda.raio) * 2.0
	roda._input(volta)
	_ok(roda.indice_destacado() == 1,
			"o ponteiro e limitado ao raio: voltar o mesmo tanto cruza para o lado oposto")
	roda.apontar(GeometriaRoda.posicao_do_slot(3, 4, roda.raio))
	var tecla_d := InputEventKey.new()
	tecla_d.physical_keycode = KEY_D
	tecla_d.pressed = true
	roda._input(tecla_d)
	_ok(roda.indice_destacado() == 3,
			"tecla de andar sem estar segura no Input nao sequestra a selecao")
	var soltar_q := InputEventKey.new()
	soltar_q.physical_keycode = KEY_Q
	soltar_q.pressed = false
	roda._input(soltar_q)
	_ok(not roda.aberta() and escolhas.back() == pa, "SOLTAR Q confirma o destacado")

	roda.abrir([vara, lanterna, pa], "")
	mov.position = roda.centro() + GeometriaRoda.posicao_do_slot(1, 4, roda.raio)
	roda._input(mov)
	var esc := InputEventKey.new()
	esc.keycode = KEY_ESCAPE
	esc.pressed = true
	var n_escolhas := escolhas.size()
	roda._input(esc)
	_ok(not roda.aberta() and escolhas.size() == n_escolhas, "ESC fecha sem trocar")

	# Q solto FORA da janela nunca chega como evento: perder o foco fecha sem trocar.
	roda.abrir([vara, lanterna, pa], "")
	roda.apontar(GeometriaRoda.posicao_do_slot(1, 4, roda.raio))
	n_escolhas = escolhas.size()
	roda._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	_ok(not roda.aberta() and escolhas.size() == n_escolhas and fechamentos.back() == false,
			"perder o foco da janela fecha a roda sem trocar o item")

	roda.abrir([], "")
	_ok(roda.total_de_slots() == 1, "bolsa sem equipamento: so 'Maos livres'")
	roda.fechar(false)
	roda.queue_free()


# -------------------------------------------------------- 7. regras puras

## As regras deste modulo nao podem depender de autoload nem de sorteio global
## (ver contrato: regras/ compila e testa sob -s). Conferido no texto do fonte,
## que e onde a dependencia apareceria.
func _testar_regras_puras() -> void:
	print("\n-- 7. regras/ sem autoload e sem sorteio global")
	for caminho: String in ["res://presentation/equipamento/regras/geometria_roda.gd",
			"res://presentation/equipamento/regras/poses_da_mao.gd",
			"res://sistemas/regras/item_jogo.gd", "res://sistemas/regras/dados_partida.gd"]:
		var fonte := FileAccess.get_file_as_string(caminho)
		var proibidos := PackedStringArray()
		for termo: String in ["Bolsa.", "Save.", "Opcoes.", "randi(", "randf(",
				"extends Node"]:
			if fonte.contains(termo):
				proibidos.append(termo)
		_ok(fonte != "" and proibidos.is_empty(), caminho.get_file() + " e regra pura",
				", ".join(proibidos))


# ------------------------------------------------------------------ utilidades

func _ok(condicao: bool, descricao: String, detalhe: String = "") -> void:
	_verificacoes += 1
	if condicao:
		print("   ok   " + descricao)
	else:
		_falhas += 1
		print("  FALHA " + descricao + ("" if detalhe == "" else "  — " + detalhe))
