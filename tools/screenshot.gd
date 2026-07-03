extends SceneTree

## Utilitario de captura: abre o visualizador, espera renderizar e salva um PNG.
## Uso: godot res://presentation/bestiario_viewer.tscn -s res://tools/screenshot.gd
## (nao headless — precisa de um display). Caminho de saida via variavel de ambiente
## SHOT_PATH, senao user://bestiario.png.

func _initialize() -> void:
	change_scene_to_file("res://presentation/bestiario_viewer.tscn")
	await process_frame
	await process_frame
	await create_timer(0.6).timeout
	var img := get_root().get_texture().get_image()
	var destino := OS.get_environment("SHOT_PATH")
	if destino == "":
		destino = "user://bestiario.png"
	img.save_png(destino)
	print("screenshot salvo em: ", destino)
	quit(0)
