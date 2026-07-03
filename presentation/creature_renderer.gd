class_name CreatureRenderer
extends Control

## Renderizador PLACEHOLDER da criatura: monta o visual a partir das partes
## (corpo por animal_base + cada feature presente no seu modelo escolhido),
## desenhando formas com _draw(). Tudo derivado dos atributos ja sorteados —
## nenhuma aleatoriedade aqui, o desenho e funcao pura da criatura (RF03/RF07).
##
## Trocar por pixel art depois = substituir os metodos _desenhar_* por Sprite2D,
## mantendo o mesmo modelo de dados (criatura.variantes -> qual PNG carregar).

var criatura: Criatura


func _ready() -> void:
	# Redesenha quando o container define/altera o tamanho (miniaturas em lista).
	resized.connect(queue_redraw)


func configurar(c: Criatura) -> void:
	criatura = c
	queue_redraw()


# matiz (categorico) -> cor concreta.
const CORES_MATIZ := {
	"vermelho": Color("e14b4b"), "laranja": Color("e8863a"), "amarelo": Color("e8cf4b"),
	"verde": Color("5bbf5b"), "ciano": Color("4bd6d6"), "azul": Color("4b6ee8"),
	"roxo": Color("9b5be8"), "marrom": Color("8a5a3c"), "cinza": Color("8a909c"),
	"branco": Color("e8ecf2"),
}


## Cor base do corpo: matiz ajustado pela familia de paleta. Estatico p/ reuso.
static func cor_de_matiz(matiz: String, paleta: String) -> Color:
	var c: Color = CORES_MATIZ.get(matiz, Color("8a909c"))
	match paleta:
		"vibrante": c.s = clampf(c.s * 1.35, 0.0, 1.0); c.v = clampf(c.v * 1.05, 0.0, 1.0)
		"neutra":   c.s = c.s * 0.5
		"terrosa":  c.s = c.s * 0.7; c.v = c.v * 0.82
		"quente":   c.s = clampf(c.s * 1.15, 0.0, 1.0); c.v = clampf(c.v * 1.03, 0.0, 1.0)
		"fria":     c.s = clampf(c.s * 1.1, 0.0, 1.0)
	return c


func _draw() -> void:
	if criatura == null:
		return
	var unit: float = minf(size.x, size.y)
	var centro := size * 0.5
	var corpo := cor_de_matiz(criatura.matiz, criatura.paleta)
	var escuro := corpo.darkened(0.45)
	var claro := corpo.lightened(0.35)

	# Ordem de pintura: partes de tras -> corpo -> partes da frente.
	if _tem("asas"):
		_desenhar_asas(centro, unit, criatura.variantes["asas"], corpo, escuro, claro)
	if _tem("nadadeiras"):
		_desenhar_nadadeiras(centro, unit, criatura.variantes["nadadeiras"], corpo, escuro, claro)
	_desenhar_corpo(centro, unit, corpo, escuro)
	if _tem("escamas"):
		_desenhar_escamas(centro, unit, criatura.variantes["escamas"], escuro, claro)
	if _tem("garras"):
		_desenhar_garras(centro, unit, criatura.variantes["garras"], escuro)
	_desenhar_olhos(centro, unit)


func _tem(feature: String) -> bool:
	return criatura.morfologia.get(feature, false)


# --- Corpo (silhueta por animal) -----------------------------------------

func _desenhar_corpo(centro: Vector2, unit: float, corpo: Color, escuro: Color) -> void:
	var rx := unit * 0.24
	var ry := unit * 0.26
	match criatura.animal_base:
		"peixe":   rx = unit * 0.34; ry = unit * 0.20
		"reptil":  rx = unit * 0.33; ry = unit * 0.22
		"anfibio": rx = unit * 0.32; ry = unit * 0.24
		"ave":     rx = unit * 0.26; ry = unit * 0.28
		"roedor":  rx = unit * 0.24; ry = unit * 0.24
		"inseto":  rx = unit * 0.20; ry = unit * 0.24
		"gato":    rx = unit * 0.25; ry = unit * 0.29
		"canino":  rx = unit * 0.29; ry = unit * 0.26

	# Extras atras do corpo (cauda) para peixe/reptil.
	if criatura.animal_base == "peixe" or criatura.animal_base == "reptil":
		var cauda := PackedVector2Array([
			centro + Vector2(-rx * 0.9, 0),
			centro + Vector2(-rx * 1.7, -ry * 0.7),
			centro + Vector2(-rx * 1.7, ry * 0.7),
		])
		_poligono(cauda, escuro)

	# Segundo segmento (abdomen) para inseto.
	if criatura.animal_base == "inseto":
		_elipse(centro + Vector2(-rx * 1.1, 0), rx * 0.9, ry * 0.85, corpo, escuro)

	# Corpo principal.
	_elipse(centro, rx, ry, corpo, escuro)

	# Cabeca/focinho e orelhas por animal (na frente = +x).
	match criatura.animal_base:
		"gato":
			_orelhas_pontudas(centro, rx, ry, corpo, escuro)
		"canino":
			_elipse(centro + Vector2(rx * 0.85, ry * 0.25), rx * 0.4, ry * 0.32, corpo, escuro)
			_orelhas_caidas(centro, rx, ry, escuro)
		"roedor":
			_poligono(_circ(centro + Vector2(-rx * 0.2, -ry * 0.95), unit * 0.06), corpo, escuro)
			_poligono(_circ(centro + Vector2(rx * 0.35, -ry * 0.95), unit * 0.06), corpo, escuro)
		"ave":
			var bico := PackedVector2Array([
				centro + Vector2(rx * 0.95, -ry * 0.05),
				centro + Vector2(rx * 1.4, ry * 0.05),
				centro + Vector2(rx * 0.95, ry * 0.2),
			])
			_poligono(bico, Color("e8a83a"))
		"reptil":
			_poligono(_circ(centro + Vector2(rx * 0.8, -ry * 0.2), unit * 0.05), corpo, escuro)
		"anfibio":
			_poligono(_circ(centro + Vector2(rx * 0.45, -ry * 0.75), unit * 0.07), corpo, escuro)
			_poligono(_circ(centro + Vector2(-rx * 0.1, -ry * 0.85), unit * 0.07), corpo, escuro)
		"inseto":
			_desenhar_antenas(centro, rx, ry, escuro)


func _orelhas_pontudas(centro: Vector2, rx: float, ry: float, corpo: Color, escuro: Color) -> void:
	for lado in [-1.0, 1.0]:
		var b := centro + Vector2(lado * rx * 0.55, -ry * 0.75)
		_poligono(PackedVector2Array([
			b + Vector2(-rx * 0.22, 0),
			b + Vector2(lado * rx * 0.1, -ry * 0.6),
			b + Vector2(rx * 0.22, 0),
		]), corpo, escuro)


func _orelhas_caidas(centro: Vector2, rx: float, ry: float, escuro: Color) -> void:
	for lado in [-1.0, 1.0]:
		var b := centro + Vector2(lado * rx * 0.5, -ry * 0.7)
		_poligono(PackedVector2Array([
			b + Vector2(-rx * 0.18, 0),
			b + Vector2(lado * rx * 0.3, ry * 0.7),
			b + Vector2(rx * 0.18, 0),
		]), escuro)


func _desenhar_antenas(centro: Vector2, rx: float, ry: float, escuro: Color) -> void:
	for lado in [-1.0, 1.0]:
		var b := centro + Vector2(rx * 0.4 + lado * rx * 0.1, -ry * 0.8)
		draw_line(b, b + Vector2(lado * rx * 0.5, -ry * 0.7), escuro, maxf(1.0, rx * 0.06))


# --- Olhos ----------------------------------------------------------------

func _desenhar_olhos(centro: Vector2, unit: float) -> void:
	var r := unit * 0.045
	var base := centro + Vector2(unit * 0.06, -unit * 0.03)
	for dy in [-unit * 0.05, unit * 0.05]:
		var o := base + Vector2(0, dy)
		draw_circle(o, r, Color.WHITE)
		draw_circle(o + Vector2(r * 0.35, 0), r * 0.5, Color("14161c"))


# --- Garras ---------------------------------------------------------------

func _desenhar_garras(centro: Vector2, unit: float, modelo: int, escuro: Color) -> void:
	var cor := Color("f2ead2")  # osso
	var base_y := centro.y + unit * 0.16
	var esp := unit * 0.11
	if modelo == 2:  # serrilhadas: pente de dentes ao longo da base
		var pts := PackedVector2Array()
		var x0 := centro.x - unit * 0.18
		var n := 7
		for i in n + 1:
			var x := x0 + (unit * 0.36) * i / float(n)
			var y := base_y + (unit * 0.06 if i % 2 == 0 else 0.0)
			pts.append(Vector2(x, y))
		draw_polyline(pts, cor, maxf(1.5, unit * 0.02))
		return
	for i in 3:
		var cx := centro.x + (i - 1) * esp
		match modelo:
			0:  # curtas
				_poligono(PackedVector2Array([
					Vector2(cx - unit * 0.03, base_y), Vector2(cx, base_y + unit * 0.08),
					Vector2(cx + unit * 0.03, base_y)]), cor, escuro)
			1:  # curvas
				_poligono(PackedVector2Array([
					Vector2(cx - unit * 0.03, base_y), Vector2(cx - unit * 0.01, base_y + unit * 0.1),
					Vector2(cx + unit * 0.02, base_y + unit * 0.07), Vector2(cx + unit * 0.03, base_y)]),
					cor, escuro)
			3:  # adaga (longa)
				_poligono(PackedVector2Array([
					Vector2(cx - unit * 0.025, base_y), Vector2(cx, base_y + unit * 0.17),
					Vector2(cx + unit * 0.025, base_y)]), cor, escuro)


# --- Escamas (padrao sobre o corpo) --------------------------------------

func _desenhar_escamas(centro: Vector2, unit: float, modelo: int, escuro: Color, claro: Color) -> void:
	var r := unit * 0.14  # regiao no corpo
	match modelo:
		0:  # lisas: brilho suave (arco claro)
			draw_arc(centro + Vector2(0, -unit * 0.04), r, PI * 1.15, PI * 1.85,
				12, Color(claro, 0.6), maxf(1.5, unit * 0.02))
		1:  # granuladas: pontos
			for p in _grade(centro, r, unit * 0.055):
				draw_circle(p, unit * 0.012, Color(escuro, 0.7))
		2:  # placas: tiles retangulares
			for p in _grade(centro, r, unit * 0.06):
				var t := unit * 0.045
				draw_rect(Rect2(p - Vector2(t, t) * 0.5, Vector2(t, t)), Color(escuro, 0.55), true)
		3:  # cristalinas: losangos
			for p in _grade(centro, r, unit * 0.06):
				var d := unit * 0.028
				_poligono(PackedVector2Array([
					p + Vector2(0, -d), p + Vector2(d, 0), p + Vector2(0, d), p + Vector2(-d, 0)]),
					Color(claro, 0.7))


# --- Asas (atras do corpo, dois lados) -----------------------------------

func _desenhar_asas(centro: Vector2, unit: float, modelo: int, corpo: Color, escuro: Color, claro: Color) -> void:
	for lado in [-1.0, 1.0]:
		var base := centro + Vector2(lado * unit * 0.1, -unit * 0.05)
		var ponta := base + Vector2(lado * unit * 0.26, -unit * 0.24)
		match modelo:
			0:  # emplumadas: arcos em camadas
				for k in 3:
					var rr := unit * (0.1 + 0.05 * k)
					draw_arc(base, rr, deg_to_rad(200.0) if lado < 0 else deg_to_rad(-20.0),
						deg_to_rad(290.0) if lado < 0 else deg_to_rad(70.0), 10,
						escuro if k % 2 == 0 else claro, maxf(1.5, unit * 0.018))
			1:  # membranosas: triangulo com nervuras
				var tri := PackedVector2Array([base, ponta, base + Vector2(lado * unit * 0.05, -unit * 0.02)])
				_poligono(tri, Color(escuro, 0.85))
				draw_line(base, ponta, corpo, maxf(1.0, unit * 0.015))
			2:  # insetoides: oval translucido
				_elipse((base + ponta) * 0.5, unit * 0.13, unit * 0.07, Color(claro, 0.35), Color(escuro, 0.5))
			3:  # energia: poligono brilhante
				var e := PackedVector2Array([base, ponta, base + Vector2(lado * unit * 0.18, unit * 0.04)])
				_poligono(e, Color(claro, 0.85))
				_poligono(e, Color(1, 1, 1, 0.25))


# --- Nadadeiras (dorsal + cauda) -----------------------------------------

func _desenhar_nadadeiras(centro: Vector2, unit: float, modelo: int, corpo: Color, escuro: Color, claro: Color) -> void:
	var topo := centro + Vector2(-unit * 0.02, -unit * 0.22)
	match modelo:
		0:  # curtas: dorsal pequena
			_poligono(PackedVector2Array([
				topo + Vector2(-unit * 0.08, unit * 0.06), topo + Vector2(0, -unit * 0.04),
				topo + Vector2(unit * 0.08, unit * 0.06)]), Color(escuro, 0.9))
		1:  # largas: dorsal grande
			_poligono(PackedVector2Array([
				topo + Vector2(-unit * 0.14, unit * 0.1), topo + Vector2(0, -unit * 0.12),
				topo + Vector2(unit * 0.14, unit * 0.1)]), Color(corpo, 0.9))
		2:  # espinhosas: pente de espinhos
			for i in 5:
				var x := topo.x + (i - 2) * unit * 0.05
				_poligono(PackedVector2Array([
					Vector2(x - unit * 0.015, topo.y + unit * 0.08), Vector2(x, topo.y - unit * 0.06),
					Vector2(x + unit * 0.015, topo.y + unit * 0.08)]), Color(escuro, 0.95))
		3:  # translucidas: leque translucido
			_poligono(PackedVector2Array([
				topo + Vector2(-unit * 0.15, unit * 0.12), topo + Vector2(-unit * 0.05, -unit * 0.13),
				topo + Vector2(unit * 0.05, -unit * 0.13), topo + Vector2(unit * 0.15, unit * 0.12)]),
				Color(claro, 0.4))


# --- Primitivas -----------------------------------------------------------

func _elipse(centro: Vector2, rx: float, ry: float, cor: Color, contorno := Color(0, 0, 0, 0)) -> void:
	_poligono(_elipse_pts(centro, rx, ry), cor, contorno)


func _elipse_pts(centro: Vector2, rx: float, ry: float, n := 28) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		var a := TAU * i / n
		pts.append(centro + Vector2(cos(a) * rx, sin(a) * ry))
	return pts


func _circ(centro: Vector2, r: float) -> PackedVector2Array:
	return _elipse_pts(centro, r, r, 16)


func _poligono(pts: PackedVector2Array, cor: Color, contorno := Color(0, 0, 0, 0)) -> void:
	draw_colored_polygon(pts, cor)
	if contorno.a > 0.0:
		var fechado := pts.duplicate()
		fechado.append(pts[0])
		draw_polyline(fechado, contorno, maxf(1.0, size.x * 0.006))


## Pontos de uma grade dentro do raio r (para padroes de escama).
func _grade(centro: Vector2, r: float, passo: float) -> Array:
	var pontos: Array = []
	var y := -r
	while y <= r:
		var x := -r
		while x <= r:
			var p := Vector2(x, y)
			if p.length() <= r:
				pontos.append(centro + p)
			x += passo
		y += passo
	return pontos
