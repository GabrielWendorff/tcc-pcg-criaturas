extends Node

## Teste da CHEGADA DE ONIBUS, no mundo de verdade. Roda como cena:
##   godot --headless --path . res://tools/test_chegada.tscn
##
##   1. partida nova abre na chegada: onibus no tunel, jogador escondido, tela da cena
##   2. a cena inteira: onibus para, jogador desce, Mirela vem, conversa, escolha,
##      explicacao, fim com bandeira, HUD de volta e Mirela voltando ao lugar
##   3. dicas da primeira batalha contra selvagem, uma vez so
##   4. P pergunta antes de pular; "nao" continua, "sim" corta e ainda da a escolha
##   5. partida carregada (com posicao) nao repete a chegada
##
## Acelera o tempo (Engine.time_scale): a cena tem ~10 s de onibus e caminhada.

const CENA_MUNDO := "res://presentation/exploracao/mundo.tscn"
const SEED_TESTE := 515151
const DIR_TESTE := "user://saves_teste_chegada/"
const SLOT := 1
const SLOT_PULO := 2
const TETO_TOTAL := 90.0
const ETAPAS := 5

var _falhas: int = 0
var _verificacoes: int = 0
var _etapas: int = 0
var _dir_real: String = ""
var _m: Node2D


func _ready() -> void:
	await get_tree().process_frame
	var lugar := Node.new()
	get_tree().root.add_child(lugar)
	get_tree().current_scene = lugar
	var vigia := Timer.new()
	vigia.one_shot = true
	vigia.wait_time = TETO_TOTAL
	vigia.ignore_time_scale = true
	vigia.process_mode = Node.PROCESS_MODE_ALWAYS
	vigia.timeout.connect(_estourou)
	add_child(vigia)
	vigia.start()

	print("== Chegada de onibus — teste de cena ==")
	_dir_real = ArquivoSave.diretorio
	ArquivoSave.diretorio = DIR_TESTE
	_limpar_saves()
	await _rodar()
	Engine.time_scale = 1.0
	_limpar_saves()
	ArquivoSave.diretorio = _dir_real
	Save.encerrar_partida()
	print("\n==")
	if _etapas != ETAPAS:
		print("RESULTADO: O TESTE ABORTOU NO MEIO (%d de %d etapas, %d verificacoes)"
				% [_etapas, ETAPAS, _verificacoes])
		get_tree().quit(1)
	elif _falhas > 0:
		print("RESULTADO: %d VERIFICACAO(OES) FALHARAM" % _falhas)
		get_tree().quit(1)
	else:
		print("RESULTADO: TODOS OS TESTES PASSARAM (%d)" % _verificacoes)
		get_tree().quit(0)


func _estourou() -> void:
	Engine.time_scale = 1.0
	ArquivoSave.diretorio = _dir_real
	print("\nRESULTADO: TEMPO ESGOTADO apos %d verificacoes, %d falha(s)"
			% [_verificacoes, _falhas])
	get_tree().quit(1)


func _ok(condicao: bool, rotulo: String, detalhe: String = "") -> bool:
	print("    %s %s%s" % ["OK  " if condicao else "FALHOU", rotulo,
			"" if detalhe == "" else "  — " + detalhe])
	_verificacoes += 1
	if not condicao:
		_falhas += 1
	return condicao


func _rodar() -> void:
	Save.nova_partida(SEED_TESTE, "chegada", SLOT)
	await _subir_mundo()
	_testar_abertura()
	await _testar_cena_inteira()
	await _testar_dicas_de_batalha()
	await _testar_pulo()
	await _testar_partida_carregada()


# ------------------------------------------------------------------- etapas

func _testar_abertura() -> void:
	print("\n1. Partida nova abre na chegada")
	var c: CutsceneChegada = _m.chegada
	_ok(c != null and c.ativa(), "a chegada comecou", c.erro if c != null else "sem cena")
	_ok(c.fase == "onibus", "pelo onibus", c.fase)
	_ok(not _m.jogador.visible and _m.jogador.congelado, "jogador escondido e parado")
	_ok(c.onibus() != null and c.onibus().get_parent() == _m.mundo.entidades,
			"o onibus esta no mundo, no mesmo y-sort dos props")
	var sprite: Sprite2D = c.onibus().get_child(0)
	_ok(not sprite.visible or sprite.region_rect.position.x > 0.0,
			"o que ainda esta dentro do tunel e recortado na boca",
			str(sprite.region_rect))
	_ok(_m.camera.alvo == c.onibus(), "a camera acompanha o onibus")
	_ok(_m._dono_da_tela() == "chegada", "a cena tem a tela")
	_ok(not _m._pode_pausar(), "sem pausa no meio da cena")
	_ok(not _m._hud_objetivo.visible, "HUD escondido")
	_ok(_m.mundo.chegada().has("caminho_mirela"), "a coreografia vem do mapa")
	_etapas += 1


func _testar_cena_inteira() -> void:
	print("\n2. A cena inteira")
	var c: CutsceneChegada = _m.chegada
	var mirela: Npc = _m.dialogos.npc_por_id("mirela")
	var origem: Vector2 = mirela.position
	Engine.time_scale = 8.0
	await _ate(func() -> bool: return c.fase == "mirela", 900)
	_ok(c.fase == "mirela", "o onibus parou e a Mirela vem", c.fase)
	_ok(_m.jogador.visible, "o jogador desceu")
	var desembarque: Vector2 = _m.mundo.celula_para_mundo(_celula_da_chegada("desembarque"))
	_ok(_m.jogador.position.distance_to(desembarque) < 1.0, "ao lado da porta")
	_ok(_m.camera.alvo == _m.jogador, "a camera passa para o jogador")
	await _ate(func() -> bool: return c.fase == "conversa", 900)
	Engine.time_scale = 1.0
	var encontro: Vector2 = _m.mundo.celula_para_mundo(_celula_da_chegada("encontro"))
	_ok(mirela.position.distance_to(encontro) < 1.0, "a Mirela parou na frente dele")
	_ok(_m.dialogos.em_conversa() and _m.dialogos._sessao.no.id == "chegada",
			"e a conversa abre no no da chegada")
	_ok(_m._dono_da_tela() == "dialogo", "na conversa, a tela e do dialogo")

	await _conversar_ate_o_fim()
	await get_tree().process_frame
	_ok(c.fase == "escolha" and _m.tela_inicial.aberta(),
			"\"selecione um destes\": a escolha abre", c.fase)
	_ok(_m.estado_mundo.ativa("se_apresentou"), "e ela ja se apresentou")
	_m.tela_inicial._indice = 0
	_m.tela_inicial._confirmar()
	await get_tree().process_frame
	_ok(_m.encontros.equipe.ativos.size() == 1, "a escolhida entrou na equipe")
	_ok(Bolsa.quantidade("esfera_simples") > 0, "o kit veio junto")
	_ok(c.fase == "explicacao" and _m.dialogos._sessao.no.id == "apos_escolha",
			"a Mirela explica batalha e captura", c.fase)

	await _conversar_ate_o_fim()
	await get_tree().process_frame
	_ok(not c.ativa(), "a chegada terminou")
	_ok(_m.estado_mundo.ativa("chegou_de_onibus"), "bandeira da chegada")
	_ok(not _m.jogador.congelado and _m.jogador.visible, "o jogador anda")
	_ok(_m._hud_objetivo.visible, "HUD de volta")
	_ok(_m._dono_da_tela() == "", "ninguem mais tem a tela")
	_ok(c.onibus() == null, "o onibus foi embora")
	Engine.time_scale = 8.0
	await _ate(func() -> bool: return mirela.position.distance_to(origem) < 1.0, 900)
	Engine.time_scale = 1.0
	_ok(mirela.position.distance_to(origem) < 1.0, "a Mirela voltou para a praca")
	_ok(ArquivoSave.ler(SLOT)["estado"] == ArquivoSave.Estado.OK, "salvou ao fim")
	_etapas += 1


func _testar_dicas_de_batalha() -> void:
	print("\n3. Dicas da primeira batalha")
	var g: GerenciadorEncontro = _m.encontros
	_ok(g.dicas_de_estreia.has("menu") and g.dicas_de_estreia.has("roda"),
			"as dicas estao armadas")
	await _batalha_selvagem(g)
	var ui: InterfaceEncontro = g._interface
	_ok(ui.dica_estreia_visivel(), "a dica do menu aparece")
	_ok(ui._dica_estreia_texto.text.contains("GOLPES"), "e fala de golpes",
			ui._dica_estreia_texto.text)
	g._abrir_roda_de_dispositivo()
	await get_tree().process_frame
	_ok(ui._dica_estreia_texto.text.contains("dispositivo"), "na roda, a dica da roda",
			ui._dica_estreia_texto.text)
	ui.roda_cancelada.emit()
	await _ate(func() -> bool: return g.estado.e(EstadoEncontro.Estado.INTERACAO))
	g._encerrar("fuga")
	await _ate(func() -> bool: return g.estado.e(EstadoEncontro.Estado.INATIVO))
	await get_tree().process_frame
	_ok(not ui.dica_estreia_visivel(), "some com a batalha")
	_ok(_m.estado_mundo.ativa("viu_dicas_batalha"), "bandeira das dicas")
	_ok(g.dicas_de_estreia.is_empty(), "e nao voltam")
	await _batalha_selvagem(g)
	_ok(not ui.dica_estreia_visivel(), "na segunda batalha, nenhuma dica")
	g._encerrar("fuga")
	await _ate(func() -> bool: return g.estado.e(EstadoEncontro.Estado.INATIVO))
	_etapas += 1


func _testar_pulo() -> void:
	print("\n4. Pular com P")
	Save.nova_partida(SEED_TESTE + 1, "pulo", SLOT_PULO)
	await _subir_mundo()
	var c: CutsceneChegada = _m.chegada
	_ok(c != null and c.ativa(), "outra partida nova, outra chegada")
	_apertar_p(c)
	_ok(c._dica.perguntando() and get_tree().paused, "P pergunta antes, com o jogo parado")
	c._dica._ao_escolher(0)
	_ok(not c._dica.perguntando() and not get_tree().paused and c.ativa() and not c.pulada,
			"\"continuar\" segue a cena")
	_apertar_p(c)
	c._dica._ao_escolher(1)
	await get_tree().process_frame
	_ok(c.pulada and c.fase == "escolha", "\"pular\" corta a cena", c.fase)
	_ok(c.onibus() == null and _m.jogador.visible, "sem onibus, jogador a vista")
	_ok(_m.tela_inicial.aberta(), "e a escolha abre mesmo assim")
	_m.tela_inicial._confirmar()
	await get_tree().process_frame
	_ok(not c.ativa() and not _m.dialogos.em_conversa(),
			"quem pulou nao ouve a explicacao: as dicas da batalha cobrem")
	_ok(_m.encontros.equipe.ativos.size() == 1 and _m.estado_mundo.ativa("chegou_de_onibus"),
			"com criatura e bandeira")
	_ok(not _m.jogador.congelado, "e anda")
	_etapas += 1


func _testar_partida_carregada() -> void:
	print("\n5. Partida carregada")
	_ok(Save.carregar(SLOT), "releu a primeira partida")
	await _subir_mundo()
	_ok(_m.chegada == null, "nao repete a chegada")
	_ok(_m.jogador.visible and not _m.jogador.congelado, "jogador no mundo, livre")
	_etapas += 1


# ---------------------------------------------------------------- utilidades

func _celula_da_chegada(chave: String) -> Vector2i:
	var p: Array = _m.mundo.chegada()[chave]
	return Vector2i(int(p[0]), int(p[1]))


func _apertar_p(c: CutsceneChegada) -> void:
	var ev := InputEventAction.new()
	ev.action = CutsceneChegada.ACAO_PULAR
	ev.pressed = true
	c._input(ev)


func _conversar_ate_o_fim() -> void:
	for i in 80:
		if not _m.dialogos.em_conversa():
			return
		if _m.dialogos._caixa.menu.ativo():
			_m.dialogos._ao_escolher(0)
		else:
			_m.dialogos._caixa.completar_texto()
			_m.dialogos._avancar()
		await get_tree().process_frame


func _batalha_selvagem(g: GerenciadorEncontro) -> void:
	g.iniciar_com_criatura(g.bestiario[3])
	await _ate(func() -> bool:
			return g.estado.e(EstadoEncontro.Estado.INTERACAO))


func _subir_mundo() -> void:
	var velha := get_tree().current_scene
	get_tree().change_scene_to_file(CENA_MUNDO)
	for i in 600:
		var atual := get_tree().current_scene
		if atual != null and atual != velha and atual.is_node_ready():
			break
		await get_tree().process_frame
	_m = get_tree().current_scene as Node2D
	await get_tree().process_frame
	var g: GerenciadorEncontro = _m.encontros
	g.cfg.duracao_aviso = 0.01
	g.cfg.duracao_tremor = 0.01
	g.cfg.atraso_apos_aviso = 0.01
	g.cfg.duracao_escurecimento = 0.01
	g.cfg.duracao_texto_encontro = 0.01
	g.cfg.duracao_abertura_menu = 0.01
	g.cfg.duracao_desfecho = 0.01
	g.cfg.duracao_encerramento = 0.01
	g.cfg.duracao_abertura_roda = 0.01
	g.cfg.duracao_evento_batalha = 0.01


func _ate(condicao: Callable, limite: int = 900) -> void:
	for i in limite:
		if condicao.call():
			return
		await get_tree().process_frame
	push_error("teste: tempo esgotado esperando")


func _limpar_saves() -> void:
	for slot in range(1, ArquivoSave.SLOTS + 1):
		ArquivoSave.apagar(slot)
