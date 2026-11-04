extends SceneTree

## Captura do mundo: as quatro regioes, as pontes, o NPC e o mapa geral.
##
## Precisa de display real — em --headless o driver e dummy e get_texture() nao
## devolve imagem (ver docs/pendencias.md item 6).
##
##   DISPLAY=:0 SHOT_DIR="user://" godot --display-driver x11 \
##     --rendering-driver opengl3 --path . -s res://tools/screenshot_mundo.gd
##
## Alem da conferencia visual, esta captura e a UNICA prova possivel da ordenacao
## por profundidade: nao existe API para consultar a ordem de desenho, e logar
## dentro de _draw() reflete a ordem de invalidacao, nao a de render. Quem
## responde e o pixel.

const ESPERA := 0.35

## (nome do arquivo, celula). Uma por lugar que precisa ser conferido.
const PONTOS := [
	["01_spawn_vila", Vector2i(21, 21)],
	["02_praca", Vector2i(21, 19)],
	["03_lago", Vector2i(30, 12)],
	["04_estrada_leste", Vector2i(46, 21)],
	["05_ponte_da_vila", Vector2i(54, 21)],
	["06_cabana_do_pescador", Vector2i(60, 19)],
	["07_ribeira", Vector2i(64, 28)],
	["08_distrito_fabrica", Vector2i(68, 58)],
	["09_padaria", Vector2i(62, 69)],
	["10_ponte_do_sitio", Vector2i(56, 63)],
	["11_fazenda", Vector2i(20, 58)],
	["12_celeiro_da_fazenda", Vector2i(18, 50)],
]


func _initialize() -> void:
	change_scene_to_file("res://presentation/exploracao/mundo.tscn")
	await process_frame
	await process_frame
	await create_timer(1.0).timeout

	var cena := current_scene
	if cena == null or cena.get("mundo") == null:
		print("FALHOU: a cena do mundo nao subiu")
		quit(1)
		return
	var mundo: MundoIso = cena.get("mundo")
	var jogador: Jogador = cena.get("jogador")
	var camera: CameraExploracao = cena.get("camera")
	var estado: EstadoMundo = cena.get("estado_mundo")
	var mapa: MapaMundo = cena.get("mapa")

	for item: Array in PONTOS:
		await _capturar(String(item[0]), jogador, camera,
				mundo.celula_para_mundo(item[1] as Vector2i))

	# Mapa com so a vila descoberta, e depois com o mundo inteiro: e a diferenca
	# que prova que a carta esconde o que nao foi andado.
	#
	# O estado precisa ser REPOSTO: as capturas acima teleportaram o jogador por
	# todas as regioes, e cada area marcou a sua como visitada. Sem esta linha a
	# primeira imagem sairia igual a segunda — e foi o que aconteceu antes de
	# alguem olhar as duas lado a lado.
	estado.regioes.clear()
	estado.visitar("vila")
	mapa.atualizar_posicao(Vector2i(21, 21), "vila")
	mapa.abrir()
	await create_timer(0.5).timeout
	await _capturar_tela("13_mapa_so_a_vila")
	for r: Dictionary in mundo.dados_das_regioes():
		estado.visitar(String(r.get("id", "")))
	mapa.fechar()
	mapa.atualizar_posicao(Vector2i(62, 69), "industrial")
	mapa.abrir()
	await create_timer(0.5).timeout
	await _capturar_tela("14_mapa_completo")
	quit(0)


func _capturar(nome: String, jogador: Jogador, camera: CameraExploracao,
		onde: Vector2) -> void:
	jogador.position = onde
	jogador.velocity = Vector2.ZERO
	await physics_frame
	camera.global_position = onde
	camera.reset_smoothing()
	await process_frame
	await create_timer(ESPERA).timeout
	await _capturar_tela(nome)


func _capturar_tela(nome: String) -> void:
	await process_frame
	var dir := OS.get_environment("SHOT_DIR")
	if dir == "":
		dir = "user://"
	var destino := dir.path_join("mundo_%s.png" % nome)
	var img := get_root().get_texture().get_image()
	if img == null:
		print("FALHOU: sem imagem (rodando headless?)")
		return
	img.save_png(destino)
	print("captura: ", destino)
