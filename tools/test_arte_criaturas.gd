extends SceneTree

## Teste da ARTE das criaturas: cada traco sorteado aparece, no lugar certo do corpo,
## e so ele. Roda sem cena:
##   godot --headless --path . -s res://tools/test_arte_criaturas.gd
##
##   1. os quatro tracos tem arte, em todos os modelos
##   2. as ancoras de encaixe (dorso, dorso_tras, flanco) caem DENTRO de cada um dos
##      32 corpos: asa no ombro, nadadeira no dorso e no flanco, nunca no ar
##   3. as escamas nunca saem da silhueta nem pintam o contorno
##   4. cada traco gera as pecas esperadas, e criatura sem traco nao ganha nenhuma
##   5. no bestiario de uma seed, o desenho bate com a ficha de toda criatura
##
## As imagens sao lidas do PNG fonte (Image.load_from_file): o teste roda sem
## renderizador, e nao depende de a textura importada devolver os pixels.

const SEED := 123456789
const ETAPAS := 5
const PECAS_POR_TRACO := {"garras": 2, "nadadeiras": 2, "asas": 1, "escamas": 1}
const ANCORAS := ["dorso", "dorso_tras", "flanco"]

var _falhas: int = 0
var _verificacoes: int = 0
var _etapas: int = 0
var _tabelas: TabelasProbabilidade
var _cat: CatalogoCorpos


func _initialize() -> void:
	print("== Arte das criaturas ==")
	_tabelas = TabelasProbabilidade.carregar()
	_cat = CatalogoCorpos.carregar(_tabelas)
	if _ok(_tabelas != null and _cat != null, "tabelas e catalogo carregaram"):
		_testar_cobertura()
		_testar_ancoras()
		_testar_escamas()
		_testar_pecas()
		_testar_bestiario()
	print("\n==")
	if _etapas != ETAPAS:
		print("RESULTADO: O TESTE ABORTOU NO MEIO (%d de %d etapas)" % [_etapas, ETAPAS])
		quit(1)
	elif _falhas > 0:
		print("RESULTADO: %d VERIFICACAO(OES) FALHARAM" % _falhas)
		quit(1)
	else:
		print("RESULTADO: TODOS OS TESTES PASSARAM (%d)" % _verificacoes)
		quit(0)


func _ok(condicao: bool, rotulo: String, detalhe: String = "") -> bool:
	print("    %s %s%s" % ["OK  " if condicao else "FALHOU", rotulo,
			"" if detalhe == "" else "  — " + detalhe])
	_verificacoes += 1
	if not condicao:
		_falhas += 1
	return condicao


func _testar_cobertura() -> void:
	print("\n1. Todo traco tem arte")
	for f: String in _tabelas.features_morfologia():
		_ok(_cat.tem_arte(f), "%s tem arte" % f)
		var faltando := PackedStringArray()
		for m in _tabelas.num_modelos(f):
			var c := _criatura("gato", 1, "medio", {f: m})
			if _cat.quadros_de_tracos(c).is_empty():
				faltando.append(_tabelas.nome_modelo(f, m))
		_ok(faltando.is_empty(), "%s: os %d modelos desenham" % [f, _tabelas.num_modelos(f)],
				", ".join(faltando))
	_etapas += 1


func _testar_ancoras() -> void:
	print("\n2. Encaixes dentro do corpo, nos 32 corpos")
	var fora := PackedStringArray()
	var corpos := 0
	for animal: String in _tabelas.animais():
		for i in _tabelas.portes().size():
			var id := CatalogoCorpos.montar_body_id(animal, i, _tabelas.portes()[i])
			var img := _imagem(_cat.caminho_corpo(id))
			corpos += 1
			for nome: String in ANCORAS:
				var a: Variant = _cat.meta(id).get(nome)
				if a == null or not _solido(img, int(a[0]), int(a[1])):
					fora.append("%s.%s" % [id, nome])
	_ok(fora.is_empty(), "dorso, dorso_tras e flanco caem sobre o corpo em %d corpos" % corpos,
			", ".join(fora))

	# A asa nasce ACIMA da linha media do corpo, e a nadadeira peitoral, abaixo do dorso.
	var trocados := PackedStringArray()
	for animal: String in _tabelas.animais():
		var m := _cat.meta(CatalogoCorpos.montar_body_id(animal, 1, "medio"))
		if int(m["dorso"][1]) >= int(m["flanco"][1]):
			trocados.append(animal)
	_ok(trocados.is_empty(), "o dorso fica acima do flanco em todo animal", ", ".join(trocados))
	_etapas += 1


func _testar_escamas() -> void:
	print("\n3. Escamas recortadas pela silhueta")
	var vazou := PackedStringArray()
	var vazias := PackedStringArray()
	for animal: String in _tabelas.animais():
		for i in _tabelas.portes().size():
			var id := CatalogoCorpos.montar_body_id(animal, i, _tabelas.portes()[i])
			var corpo := _imagem(_cat.caminho_corpo(id))
			for m in _tabelas.num_modelos("escamas"):
				var q: Array = _cat.quadros_de_tracos(_criatura(animal, i, _tabelas.portes()[i],
						{"escamas": m}))
				var tex: Texture2D = q[0]["tex"]
				var img := _imagem(tex.resource_path)
				var pintados := 0
				for y in img.get_height():
					for x in img.get_width():
						if img.get_pixel(x, y).a < 0.5:
							continue
						pintados += 1
						if not _solido(corpo, x, y) or _indice(corpo, x, y) == 1:
							vazou.append("%s/%d (%d,%d)" % [id, m, x, y])
				if pintados == 0:
					vazias.append("%s/%d" % [id, m])
	_ok(vazou.is_empty(), "nenhum pixel de escama fora do corpo ou sobre o contorno",
			", ".join(vazou.slice(0, 5)))
	_ok(vazias.is_empty(), "toda sobreposicao de escama pinta alguma coisa", ", ".join(vazias))
	_etapas += 1


func _testar_pecas() -> void:
	print("\n4. Pecas por traco")
	var nua := _criatura("peixe", 1, "medio", {})
	_ok(_cat.quadros_de_tracos(nua).is_empty(), "peixe sem tracos nao ganha nadadeira nenhuma")
	var ave_nua := _criatura("ave", 1, "medio", {})
	_ok(_cat.quadros_de_tracos(ave_nua).is_empty(), "ave sem tracos nao ganha asa")
	for f: String in PECAS_POR_TRACO:
		var q := _cat.quadros_de_tracos(_criatura("canino", 1, "medio", {f: 0}))
		_ok(q.size() == int(PECAS_POR_TRACO[f]), "%s: %d peca(s)" % [f, PECAS_POR_TRACO[f]],
				"%d" % q.size())

	# Ordem de desenho: escamas por baixo de tudo, asas por cima de tudo.
	var todas := _criatura("reptil", 1, "medio",
			{"garras": 0, "escamas": 0, "asas": 0, "nadadeiras": 0})
	var q := _cat.quadros_de_tracos(todas)
	var primeira: Texture2D = q[0]["tex"]
	var ultima: Texture2D = q[q.size() - 1]["tex"]
	_ok(primeira.resource_path.contains("escamas"), "escamas sao desenhadas primeiro")
	_ok(ultima.resource_path.contains("asa_"), "asas sao desenhadas por ultimo")

	# Cada peca encosta pelo pivo na ancora do seu slot.
	var m := _cat.meta("gato_2_medio")
	var asa: Dictionary = _cat.quadros_de_tracos(_criatura("gato", 1, "medio", {"asas": 0}))[0]
	var r: Rect2 = asa["rect"]
	_ok(r.has_point(Vector2(m["dorso"][0], m["dorso"][1])), "a asa cobre o ombro do gato",
			"%s ~ %s" % [r, m["dorso"]])
	_ok(r.position.y < float(m["dorso"][1]), "e sobe a partir dele")
	var garras := _cat.quadros_de_tracos(_criatura("gato", 1, "medio", {"garras": 0}))
	var g0: Rect2 = garras[0]["rect"]
	_ok(absf(g0.end.y - float(m["pe_tras"][1])) <= 1.5, "as garras encostam no chao, nos pes",
			"%s ~ %s" % [g0, m["pe_tras"]])
	_etapas += 1


func _testar_bestiario() -> void:
	print("\n5. O desenho bate com a ficha, em todo o bestiario")
	var bestiario := GeradorCriaturas.new(_tabelas, _cat).gerar_bestiario(SEED, 100)
	var erradas := PackedStringArray()
	for c: Criatura in bestiario:
		var esperado := 0
		for f: String in PECAS_POR_TRACO:
			if c.morfologia.get(f, false):
				esperado += int(PECAS_POR_TRACO[f])
		var q := _cat.quadros_de_tracos(c)
		if q.size() != esperado:
			erradas.append("%s (%d de %d)" % [c.nome(), q.size(), esperado])
	_ok(erradas.is_empty(), "100 criaturas: uma peca por traco sorteado, nenhuma a mais",
			", ".join(erradas.slice(0, 5)))
	_etapas += 1


# ------------------------------------------------------------------ utilidades

func _imagem(caminho: String) -> Image:
	return Image.load_from_file(ProjectSettings.globalize_path(caminho))


func _solido(img: Image, x: int, y: int) -> bool:
	return x >= 0 and y >= 0 and x < img.get_width() and y < img.get_height() \
			and img.get_pixel(x, y).a > 0.5


func _indice(img: Image, x: int, y: int) -> int:
	return roundi(img.get_pixel(x, y).r * 4.0)


## `tracos`: traco -> modelo.
func _criatura(animal: String, indice_porte: int, porte: String, tracos: Dictionary) -> Criatura:
	var c := Criatura.new()
	c.elemento = "terra"
	c.animal_base = animal
	c.porte = porte
	c.body_id = CatalogoCorpos.montar_body_id(animal, indice_porte, porte)
	for f in ["garras", "escamas", "asas", "nadadeiras"]:
		c.morfologia[f] = tracos.has(f)
		if tracos.has(f):
			c.variantes[f] = int(tracos[f])
	return c
