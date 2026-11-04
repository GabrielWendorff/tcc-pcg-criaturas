extends Node

## Captura as telas do combate e do arco. Precisa de display real, e roda como cena
## porque o mundo cita os autoloads:
##   DISPLAY=:0 SHOT_DIR="user://" godot --display-driver x11 \
##     --rendering-driver opengl3 --path . res://tools/screenshot_batalha.tscn
##
## Os testes provam a mecanica; quem responde se o texto coube na tela e o pixel.

func _ready() -> void:
	await get_tree().process_frame
	var m: Node = load("res://presentation/exploracao/mundo.tscn").instantiate()
	get_tree().root.add_child(m)
	await get_tree().create_timer(1.0).timeout
	var g: GerenciadorEncontro = m.get("encontros")

	await _capturar("hud_inicial", 0.2)
	m.call("_abrir_escolha_inicial")
	await _capturar("escolha_inicial", 0.3)
	var ini: TelaEscolhaInicial = m.get("tela_inicial")
	ini._confirmar()
	await get_tree().process_frame
	for i in [20, 21, 22]:
		g.equipe.adicionar(Combatente.de_criatura(g.bestiario[i], g.tabelas_batalha))
	g.equipe.ativos[0].vida = 60

	var pontos := get_tree().get_nodes_in_group("pontos_de_encontro")
	g.iniciar(pontos[0])
	await _ate_menu(g)
	await _capturar("batalha_menu", 0.3)
	g._interface._menu_ativo = true
	g._abrir_lista_de_golpes()
	await _capturar("batalha_golpes", 0.2)
	g._interface.voltar_ao_menu()
	g._abrir_lista_de_trocas()
	await _capturar("batalha_trocas", 0.2)
	g._interface.voltar_ao_menu()
	g._on_acao(InterfaceEncontro.Acao.CAPTURAR)
	await _capturar("batalha_roda", 0.5)
	g._on_roda_cancelada()
	await get_tree().create_timer(0.3).timeout
	g._encerrar("teste")
	await _ate_inativo(g)

	var dulce: Dictionary = (m.get("guardioes") as CatalogoGuardioes).por_id("dulce")
	g.iniciar_duelo(dulce, SelecaoBestiario.equipe_guardiao(g.bestiario, g.tabelas_batalha,
			dulce["elementos"], 2, float(dulce["percentil_forca"])))
	await _capturar("duelo_cartaz", 1.5)
	await _ate_menu(g)
	await _capturar("duelo_menu", 0.3)
	g._encerrar("teste")
	await _ate_inativo(g)

	m.call("_mostrar_vitoria")
	await _capturar("vitoria", 0.3)
	(m.get("tela_desfecho") as TelaDesfecho).fechar()
	m.call("_mostrar_derrota")
	await _capturar("derrota", 0.3)
	(m.get("tela_desfecho") as TelaDesfecho).fechar()
	(m.get("jogador") as Jogador).congelar(false)

	var pausa: MenuPausa = m.get("pausa")
	pausa.abrir()
	pausa._mostrar_equipe()
	await _capturar("equipe", 0.3)
	pausa.fechar()
	print("FIM")
	get_tree().quit(0)


func _ate_menu(g: GerenciadorEncontro) -> void:
	for i in 900:
		if g.estado.e(EstadoEncontro.Estado.INTERACAO):
			return
		await get_tree().process_frame


func _ate_inativo(g: GerenciadorEncontro) -> void:
	for i in 900:
		if g.estado.e(EstadoEncontro.Estado.INATIVO):
			return
		await get_tree().process_frame


func _capturar(nome: String, espera: float) -> void:
	await get_tree().create_timer(espera, true).timeout
	await get_tree().process_frame
	var dir := OS.get_environment("SHOT_DIR")
	if dir == "":
		dir = "user://"
	var img := get_tree().root.get_texture().get_image()
	var caminho := dir.path_join("batalha_%s.png" % nome)
	print(caminho, " ", img.save_png(caminho))
