extends Node

## Renderiza, a partir do jogo de verdade, as pecas que o banner e o poster montam:
## o mapa inteiro (com a ambientacao da seed) e criaturas do gerador. Nada aqui e
## desenhado a mao. O texto, na fonte pixel do jogo, entra depois, em Python
## (tools/divulgacao/fonte_pixel.py).
##
## Precisa de tela (o headless nao devolve textura):
##   godot --path . res://tools/divulgacao/renderizar.tscn
## Saida: docs/poster/recursos/ (PNGs e pecas.json), lida por tools/divulgacao/compor.py
## e tools/poster/gerar_poster.py.

const SAIDA := "res://docs/poster/recursos/"
const SEED := 123456789
const N := 100
## Pares exemplares: o primario e o traco que o modelo mais espera para ele.
const EXEMPLOS := [
	["fogo", "gato", "garras"], ["agua", "peixe", "nadadeiras"], ["ar", "ave", "asas"],
	["terra", "reptil", "escamas"], ["eletrico", "inseto", "asas"], ["gelo", "canino", "garras"],
]
const LADO_CRIATURA := 128
const SEEDS_DE_EXEMPLO := 40
## Folga acima do mapa: casas e arvores sobem alem da celula do topo.
const FOLGA_TOPO := 96.0

var _pecas: Dictionary = {"criaturas": [], "pares": [], "grade": []}
var _t: TabelasProbabilidade
var _cat: CatalogoCorpos


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SAIDA))
	_t = TabelasProbabilidade.carregar()
	_cat = CatalogoCorpos.carregar(_t)
	var ger := GeradorCriaturas.new(_t, _cat)
	var v2: Array = ger.gerar_bestiario(SEED, N, GeradorCriaturas.Modo.CONDICIONADO_V2)
	var v1: Array = ger.gerar_bestiario(SEED, N, GeradorCriaturas.Modo.CONDICIONADO)
	var ind: Array = ger.gerar_bestiario(SEED, N, GeradorCriaturas.Modo.INDEPENDENTE)

	await _renderizar_mapa(v2)
	# Exemplos: a criatura mais tipica de cada par em varias seeds, todas do gerador real.
	var varias: Array = []
	for s in SEEDS_DE_EXEMPLO:
		varias += ger.gerar_bestiario(SEED + s, N, GeradorCriaturas.Modo.CONDICIONADO_V2)
	for ex: Array in EXEMPLOS:
		var c := _exemplar(varias, ex[0], ex[1], ex[2])
		if c != null:
			await _salvar_criatura(c, "exemplo_%s_%s" % [ex[0], ex[1]], "criaturas")
	for par: Dictionary in _pares_contrastantes(v1, ind):
		await _salvar_criatura(par["v1"], "par_%03d_condicionado" % par["v1"].id, "pares")
		await _salvar_criatura(par["ind"], "par_%03d_independente" % par["ind"].id, "pares")
	for i in 24:
		await _salvar_criatura(v2[i], "grade_%03d" % i, "grade")

	var arq := FileAccess.open(SAIDA + "pecas.json", FileAccess.WRITE)
	arq.store_string(JSON.stringify(_pecas, "  "))
	arq.close()
	print("ok  pecas em ", ProjectSettings.globalize_path(SAIDA))
	get_tree().quit(0)


func _exemplar(bestiario: Array, elemento: String, animal: String, traco: String) -> Criatura:
	var melhor: Criatura = null
	var melhor_bits: float = INF
	for c: Criatura in bestiario:
		if c.elemento == elemento and c.animal_base == animal and c.morfologia.get(traco, false):
			var bits := NotaCoerencia.surpresa(c, _t, true)
			if bits < melhor_bits:
				melhor = c
				melhor_bits = bits
	return melhor


## Mesmos primarios nos dois bracos (v1 e independente partem dos mesmos sorteios):
## os pares em que a diferenca de surpresa e maior mostram o que o condicionamento faz.
func _pares_contrastantes(v1: Array, ind: Array) -> Array:
	var pares: Array = []
	for i in v1.size():
		var a: Criatura = v1[i]
		var b: Criatura = ind[i]
		pares.append({"v1": a, "ind": b, "ganho": NotaCoerencia.surpresa(b, _t, false)
				- NotaCoerencia.surpresa(a, _t, false)})
	pares.sort_custom(func(x: Dictionary, y: Dictionary) -> bool: return x["ganho"] > y["ganho"])
	var escolhidos: Array = []
	var animais: Dictionary = {}
	for p: Dictionary in pares:
		var animal: String = p["v1"].animal_base
		if animais.has(animal):
			continue
		animais[animal] = true
		escolhidos.append(p)
		if escolhidos.size() == 4:
			break
	return escolhidos


func _viewport(tamanho: Vector2i, transparente: bool) -> SubViewport:
	var sv := SubViewport.new()
	sv.size = tamanho
	sv.transparent_bg = transparente
	sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	sv.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	add_child(sv)
	return sv


func _capturar(sv: SubViewport, nome: String) -> void:
	for i in 3:
		await RenderingServer.frame_post_draw
	sv.get_texture().get_image().save_png(SAIDA + nome + ".png")
	sv.queue_free()


func _renderizar_mapa(bestiario: Array) -> void:
	var mundo := MundoIso.new()
	var sv := _viewport(Vector2i(64, 64), false)
	sv.add_child(mundo)
	mundo.carregar()
	var amb := GeradorAmbientacao.carregar()
	if amb != null:
		var geradas := amb.gerar(SEED, mundo.dados_do_mapa(), mundo.catalogo_de_props(), bestiario)
		for item: Dictionary in geradas["props"]:
			mundo.adicionar_prop(String(item["categoria"]), item)
	var r := mundo.limites_da_camera()
	r = r.grow_side(SIDE_TOP, FOLGA_TOPO)
	sv.size = Vector2i(ceili(r.size.x), ceili(r.size.y))
	var cam := Camera2D.new()
	cam.position = r.get_center()
	sv.add_child(cam)
	cam.make_current()
	_pecas["mapa"] = {"arquivo": "mapa.png", "tamanho": [sv.size.x, sv.size.y]}
	await _capturar(sv, "mapa")


func _salvar_criatura(c: Criatura, nome: String, lista: String) -> void:
	var sv := _viewport(Vector2i(LADO_CRIATURA, LADO_CRIATURA), true)
	var render := CreatureSpriteRenderer.new()
	render.size = Vector2(LADO_CRIATURA, LADO_CRIATURA)
	sv.add_child(render)
	render.configurar(c, _cat)
	await _capturar(sv, nome)
	var nota := NotaCoerencia.decompor(c, _t, NotaCoerencia.usa_v2(c))
	var linhas: Array = []
	for l: Dictionary in nota["linhas"]:
		linhas.append({"atributo": l["atributo"], "valor": l["valor"], "p": l["p"]})
	_pecas[lista].append({"arquivo": nome + ".png", "nome": c.nome(), "modo": c.modo,
			"elemento": c.elemento, "animal": c.animal_base, "porte": c.porte,
			"paleta": c.paleta, "matiz": c.matiz, "tracos": c.features_presentes(),
			"bits": nota["bits"], "atipica": NotaCoerencia.atipica(float(nota["bits"]), _t),
			"linhas": linhas})

