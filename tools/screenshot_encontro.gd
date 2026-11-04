extends SceneTree

## Captura o roteiro do encontro, quadro a quadro. Precisa de display real — em
## --headless o driver e dummy e get_image() nao devolve imagem.
##
##   DISPLAY=:0 SHOT_DIR="user://" godot --display-driver x11 \
##     --rendering-driver opengl3 --path . -s res://tools/screenshot_encontro.gd
##
## E a unica conferencia possivel da APARENCIA: o teste headless
## (tools/test_encontro.gd) prova a mecanica e a maquina de estados, mas nao ve
## se o "!" ficou atras de uma arvore, se o texto coube na tela ou se a roda
## saiu do enquadramento. Quem responde e o pixel.
##
## Momentos capturados: o "!" sobre a cabeca, a tela escurecendo, o cartao
## CRIATURA ENCONTRADA, o menu, a roda de dispositivos e a roda de iscas.

func _initialize() -> void:
	change_scene_to_file("res://presentation/exploracao/mundo.tscn")
	await process_frame
	await create_timer(1.0).timeout

	var vila := current_scene
	if vila == null or vila.get("encontros") == null:
		print("FALHOU: a cena da vila nao subiu")
		quit(1)
		return
	var g: GerenciadorEncontro = vila.get("encontros")
	var jogador: Jogador = vila.get("jogador")
	var camera: CameraExploracao = vila.get("camera")

	# Leva o jogador ate uma zona antes de disparar: o "!" precisa aparecer sobre
	# o mato, que e onde ele sera visto de verdade.
	var pontos := get_nodes_in_group("pontos_de_encontro")
	var zona: PontoDeEncontro = pontos[0] if not pontos.is_empty() else null
	if zona != null:
		jogador.position = zona.position
		camera.global_position = zona.position
		camera.reset_smoothing()
	await process_frame

	# Sem criatura de pe nao ha encontro.
	if g.equipe.vazia():
		g.equipe.adicionar(Combatente.de_criatura(g.bestiario[0], g.tabelas_batalha))
	g.iniciar(zona)
	await _capturar("01_exclamacao", 0.25)
	await _capturar("02_escurecendo", g.cfg.duracao_aviso)
	await _capturar("03_criatura_encontrada", g.cfg.duracao_escurecimento + 0.25)
	await _esperar_menu(g)
	await _capturar("04_menu", 0.2)

	g._on_acao(InterfaceEncontro.Acao.CAPTURAR)
	await _capturar("05_roda_dispositivos", 0.45)
	g._on_roda_cancelada()
	await create_timer(0.2).timeout
	g._on_acao(InterfaceEncontro.Acao.ISCA)
	await _capturar("06_roda_iscas", 0.45)
	# Gira ate uma isca preferida pela criatura, para a captura mostrar o selo.
	for i in 12:
		var atual := g._interface._roda.item_selecionado() as IscaCaptura
		if atual != null and atual.preferida_por(g.criatura_atual()):
			break
		g._interface._roda._girar(1)
		await process_frame
	await _capturar("06b_isca_preferida", 0.35)
	g._on_roda_cancelada()
	await create_timer(0.2).timeout

	# Um lance de verdade, para ver o dispositivo em voo e o desfecho.
	g._on_acao(InterfaceEncontro.Acao.CAPTURAR)
	await create_timer(0.3).timeout
	g._on_item(g.captura.dispositivos[0])
	await _capturar("07_lancamento", g.cfg.duracao_lancamento + 0.3)
	await _capturar("08_desfecho", g.cfg.duracao_balanco * g.cfg.balancos + 0.5)
	quit(0)


func _esperar_menu(g: GerenciadorEncontro) -> void:
	for i in 600:
		if g.estado.e(EstadoEncontro.Estado.INTERACAO):
			return
		await process_frame


func _capturar(nome: String, espera: float) -> void:
	await create_timer(espera).timeout
	await process_frame
	var dir := OS.get_environment("SHOT_DIR")
	if dir == "":
		dir = "user://"
	var destino := dir.path_join("encontro_%s.png" % nome)
	var img := get_root().get_texture().get_image()
	if img == null:
		print("FALHOU: sem imagem (rodando headless?)")
		return
	img.save_png(destino)
	print("captura: ", destino)
