extends SceneTree

## Captura da conversa com NPC. Precisa de display real — em --headless o driver
## e dummy e get_texture() nao devolve imagem (mesma limitacao de
## tools/screenshot_mundo.gd; ver docs/pendencias.md item 6).
##
##   DISPLAY=:0 SHOT_DIR="user://" godot --display-driver x11 \
##     --rendering-driver opengl3 --path . -s res://tools/screenshot_dialogo.gd
##
## Momentos capturados: o aviso de interacao sobre a cabeca do NPC, a primeira
## fala, o menu de escolhas e um topico depois da ramificacao.

const ESPERA := 0.45


func _initialize() -> void:
	change_scene_to_file("res://presentation/exploracao/mundo.tscn")
	await process_frame
	await process_frame
	await create_timer(0.9).timeout

	var cena := current_scene
	if cena == null or cena.get("dialogos") == null:
		print("FALHOU: a cena nao subiu com o gerenciador de dialogo")
		quit(1)
		return
	var jogador: Jogador = cena.get("jogador")
	var camera: CameraExploracao = cena.get("camera")
	var gerente: GerenciadorDialogo = cena.get("dialogos")

	var npcs := get_nodes_in_group("npcs")
	if npcs.is_empty():
		print("FALHOU: nenhum NPC no mundo")
		quit(1)
		return
	var alvo: Npc = npcs[0]
	for no: Node in npcs:
		if String((no as Npc).dados.id) == "mirela":
			alvo = no

	# Ao lado do NPC, dentro do alcance: e o que faz o aviso aparecer.
	await _posicionar(jogador, camera, alvo.position + Vector2(18, 6))
	await _capturar("01_aviso_interacao")

	gerente.conversar_com(alvo)
	await create_timer(0.9).timeout
	await _capturar("02_primeira_fala")

	# Confirma ate o menu de escolhas abrir.
	for i in 6:
		gerente.call("_avancar")
		await create_timer(0.35).timeout
		if gerente.get("_caixa").menu.ativo():
			break
	await _capturar("03_escolhas")

	gerente.call("_ao_escolher", 0)
	await create_timer(0.9).timeout
	await _capturar("04_resposta")

	gerente.call("_avancar")
	await create_timer(0.5).timeout
	gerente.call("_avancar")
	await create_timer(0.6).timeout
	await _capturar("05_menu_de_assuntos")
	quit(0)


func _posicionar(jogador: Jogador, camera: CameraExploracao, onde: Vector2) -> void:
	jogador.position = onde
	jogador.velocity = Vector2.ZERO
	await physics_frame
	camera.global_position = onde
	camera.reset_smoothing()
	await process_frame
	await create_timer(ESPERA).timeout


func _capturar(nome: String) -> void:
	await process_frame
	var dir := OS.get_environment("SHOT_DIR")
	if dir == "":
		dir = "user://"
	var destino := dir.path_join("dialogo_%s.png" % nome)
	var img := get_root().get_texture().get_image()
	if img == null:
		print("FALHOU: sem imagem (rodando headless?)")
		return
	img.save_png(destino)
	print("captura: ", destino)
