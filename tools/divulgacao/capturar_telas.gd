extends Node

## Capturas de tela para o poster e a pagina do itch.io, do jogo rodando:
##   godot --path . res://tools/divulgacao/capturar_telas.tscn   (precisa de tela)
## Saida: docs/poster/recursos/tela_*.png

const SAIDA := "res://docs/poster/recursos/"


func _ready() -> void:
	await get_tree().process_frame
	# change_scene_to_file libera a cena corrente, e este no nao pode ser ela.
	var lugar := Node.new()
	get_tree().root.add_child(lugar)
	get_tree().current_scene = lugar
	get_tree().change_scene_to_file("res://presentation/exploracao/mundo.tscn")
	await get_tree().create_timer(1.5).timeout
	var m: Node = get_tree().current_scene
	var g: GerenciadorEncontro = m.encontros
	await _salvar("tela_exploracao")
	m._ao_escolher_inicial(SelecaoBestiario.iniciais(g.bestiario, g.tabelas_batalha)[1])
	g.dicas_de_estreia = {}
	await get_tree().create_timer(0.4).timeout
	g.iniciar_com_criatura(g.bestiario[6])
	await get_tree().create_timer(3.5).timeout
	await _salvar("tela_batalha")
	g._encerrar("fuga")
	await get_tree().create_timer(1.5).timeout

	var tela: TelaBestiario = m.pausa.tela_bestiario
	tela.abrir(g.bestiario, func(_c: Criatura) -> bool: return false, g.catalogo,
			g.tabelas_batalha, "123456789", g.tabelas)
	tela._selecionar(6, true)
	tela._vendo_sorteio = true
	tela._atualizar_ficha()
	await get_tree().create_timer(0.5).timeout
	await _salvar("tela_bestiario")
	get_tree().quit(0)


func _salvar(nome: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(SAIDA + nome + ".png")
