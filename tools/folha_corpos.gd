extends SceneTree

## Folha de contato dos corpos da biblioteca: um quadro por BodyDef, em grade.
## Ferramenta de calibracao visual — permite ver se um arquetipo esta deformado sem
## precisar sortear bestiarios ate ele aparecer.
##
##   godot res://tools/folha_corpos.gd -s res://tools/folha_corpos.gd
##   (precisa de display; caminho de saida via SHOT_PATH, senao user://corpos.png)

const CELULA := Vector2(150, 150)
const COLUNAS := 5


func _initialize() -> void:
	var lib := CreaturePartLibrary.carregar()
	var tabelas := TabelasProbabilidade.carregar()
	if lib == null or tabelas == null:
		printerr("Falha ao carregar dados de res://data/.")
		quit(1)
		return

	var corpos: Array = lib.todos_os_corpos()
	var linhas: int = ceili(float(corpos.size()) / COLUNAS)
	var tamanho := Vector2(COLUNAS * CELULA.x, linhas * (CELULA.y + 22))

	var raiz := Control.new()
	raiz.size = tamanho
	var fundo := ColorRect.new()
	fundo.color = Color("1b1e26")
	fundo.size = tamanho
	raiz.add_child(fundo)

	# Cada corpo aparece com uma criatura neutra: mesma cor e sem apendices, para
	# que a comparacao entre quadros isole a silhueta.
	for i in corpos.size():
		var corpo: BodyDef = corpos[i]
		var pos := Vector2((i % COLUNAS) * CELULA.x, (i / COLUNAS) * (CELULA.y + 22))

		var c := Criatura.new()
		c.body_id = corpo.id
		c.arquetipo = corpo.arquetipo
		c.matiz = "ciano"
		c.paleta = "fria"
		c.morfologia = {}
		c.variantes = {}

		var render := CreatureRenderer.new()
		render.position = pos
		render.size = CELULA
		raiz.add_child(render)
		render.configurar(c, lib)

		var rotulo := Label.new()
		rotulo.text = "%s\n%s" % [corpo.id, corpo.arquetipo]
		rotulo.position = pos + Vector2(4, CELULA.y - 10)
		rotulo.add_theme_font_size_override("font_size", 11)
		raiz.add_child(rotulo)

	get_root().add_child(raiz)
	get_root().size = tamanho
	await process_frame
	await process_frame
	await create_timer(0.5).timeout

	var img := get_root().get_texture().get_image()
	var destino := OS.get_environment("SHOT_PATH")
	if destino == "":
		destino = "user://corpos.png"
	img.save_png(destino)
	print("folha de corpos salva em: ", destino)
	quit(0)
