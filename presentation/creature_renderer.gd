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
var library: CreaturePartLibrary

## Fracao do quadro que a silhueta ocupa. A sobra acomoda os apendices, que se
## projetam para fora do corpo (asas acima, garras abaixo).
const OCUPACAO := 0.68

# Enquadramento resolvido a cada _draw e reaproveitado pelas ancoras, para que
# corpo e apendices compartilhem exatamente a mesma transformacao.
var _escala: float = 1.0
var _origem: Vector2 = Vector2.ZERO


func _ready() -> void:
	# Redesenha quando o container define/altera o tamanho (miniaturas em lista).
	resized.connect(queue_redraw)


func configurar(c: Criatura, lib: CreaturePartLibrary = null) -> void:
	criatura = c
	if lib != null:
		library = lib
	queue_redraw()


## Mantido como atalho historico; o modelo de cor vive em PaletaCriatura, que e
## compartilhado com o renderizador de sprites.
static func cor_de_matiz(matiz: String, paleta: String) -> Color:
	return PaletaCriatura.cor_base(matiz, paleta)


func _draw() -> void:
	if criatura == null:
		return
	if library == null:
		library = CreaturePartLibrary.carregar()
	var unit: float = minf(size.x, size.y)
	var centro := size * 0.5
	var corpo := cor_de_matiz(criatura.matiz, criatura.paleta)
	var escuro := corpo.darkened(0.45)
	var claro := corpo.lightened(0.35)
	var body: BodyDef = library.corpo_por_id(criatura.body_id) if library != null else null
	_enquadrar(body, centro, unit)

	# Ordem de pintura: partes de tras -> corpo -> partes da frente. Cada apendice
	# nasce na ancora do SEU corpo, nao numa fracao fixa do quadro.
	if _tem("asas"):
		_desenhar_asas(_ancora("asas", centro), unit, criatura.variantes["asas"],
			corpo, escuro, claro)
	if _tem("nadadeiras"):
		_desenhar_nadadeiras(_ancora("nadadeiras", centro), unit,
			criatura.variantes["nadadeiras"], corpo, escuro, claro)
	_desenhar_corpo(body, corpo, escuro, claro)
	if _tem("escamas"):
		_desenhar_escamas(_ancora("escamas", centro), unit,
			criatura.variantes["escamas"], escuro, claro)
	if _tem("garras"):
		_desenhar_garras(_ancora("garras", centro), unit,
			criatura.variantes["garras"], escuro)
	_desenhar_olhos(_ancora("olhos", centro), unit)


## Resolve escala e origem para que a silhueta caiba no quadro ocupando OCUPACAO
## dele, seja qual for a extensao do arquetipo, e fique centrada pela sua propria
## caixa envolvente — nao pelo ponto (0,0) do espaco normalizado, que em corpos
## assimetricos como a serpente nem fica no meio da forma.
func _enquadrar(body: BodyDef, centro: Vector2, unit: float) -> void:
	if body == null:
		_escala = unit
		_origem = centro
		return
	var caixa := body.limites()
	var extensao := maxf(caixa.size.x, caixa.size.y)
	_escala = (unit * OCUPACAO / extensao) if extensao > 0.0 else unit
	_origem = centro - (caixa.position + caixa.size * 0.5) * _escala


## Ponto do espaco normalizado do corpo -> pixels.
func _ponto(p: Vector2) -> Vector2:
	return _origem + p * _escala


func _tem(feature: String) -> bool:
	return criatura.morfologia.get(feature, false)


## Ancora do slot no corpo desta criatura, convertida para pixels.
## Sem biblioteca ou sem ancora declarada, cai no centro — degradacao visivel,
## nunca uma posicao plausivel por acidente.
func _ancora(slot: String, centro: Vector2) -> Vector2:
	if library == null or not library.tem_ancora(criatura.body_id, slot):
		return centro
	return _ponto(library.ancora(criatura.body_id, slot))


# --- Corpo (silhueta vinda do BodyDef) ------------------------------------

## Pinta a silhueta descrita pelo recurso, parte a parte, de tras para frente.
## Nenhuma geometria mora aqui: trocar a forma de um arquetipo e editar o .tres
## (via tools/gerar_part_library.gd), nunca este metodo.
func _desenhar_corpo(body: BodyDef, corpo: Color, escuro: Color, claro: Color) -> void:
	if body == null:
		# Sem corpo resolvido, desenha um marcador obviamente errado em vez de uma
		# silhueta plausivel — falha silenciosa aqui esconderia bug no gerador.
		_elipse(_origem, _escala * 0.2, _escala * 0.2, Color("ff00ff"), escuro)
		return
	for parte in body.partes_ordenadas():
		var cor := _tom(parte.get("tom", 0.0), corpo, escuro, claro)
		match parte.get("tipo", ""):
			"elipse":
				var r: Vector2 = Vector2(parte["r"]) * _escala
				_elipse(_ponto(parte["c"]), r.x, r.y, cor, escuro)
			"poligono":
				var pts := PackedVector2Array()
				for p in parte["pts"]:
					pts.append(_ponto(p))
				_poligono(pts, cor, escuro)


## tom em [-1, 1] -> cor concreta. A silhueta descreve profundidade relativa; a
## cor concreta so e resolvida aqui, mantendo o recurso independente da paleta.
func _tom(t: float, corpo: Color, escuro: Color, claro: Color) -> Color:
	if t < 0.0:
		return corpo.lerp(escuro, minf(-t, 1.0))
	if t > 0.0:
		return corpo.lerp(claro, minf(t, 1.0))
	return corpo


# --- Olhos ----------------------------------------------------------------

## Os olhos vao na ancora "olhos" do corpo. Foi tentado inferi-los da geometria
## (a parte mais a frente seria a cabeca), mas orelhas, bicos e mandibulas ocupam
## camadas altas e a heuristica errava; a posicao do olho e decisao de autoria do
## arquetipo, entao vive na biblioteca como qualquer outra ancora.
## Um olho so: a criatura e vista de perfil (olhando para +x), entao o segundo
## olho estaria do lado oculto. O par empilhado que existia antes so nao destoava
## porque o corpo era um blob sem orientacao definida.
func _desenhar_olhos(base: Vector2, unit: float) -> void:
	var r := unit * 0.055
	draw_circle(base, r, Color.WHITE)
	draw_circle(base, r, Color("14161c"), false, maxf(1.0, unit * 0.01))
	draw_circle(base + Vector2(r * 0.3, 0), r * 0.45, Color("14161c"))


# --- Garras ---------------------------------------------------------------

## 'base' e a ancora de garras do corpo — a extremidade das patas, que varia de
## arquetipo para arquetipo (baixo do tronco num quadrupede, ponta das pernas num
## avial). Todos os offsets aqui sao relativos a ela.
func _desenhar_garras(base: Vector2, unit: float, modelo: int, escuro: Color) -> void:
	var cor := Color("f2ead2")  # osso
	var base_y := base.y
	var esp := unit * 0.09
	if modelo == 2:  # serrilhadas: pente de dentes ao longo da base
		var pts := PackedVector2Array()
		var x0 := base.x - unit * 0.15
		var n := 7
		for i in n + 1:
			var x := x0 + (unit * 0.30) * i / float(n)
			var y := base_y + (unit * 0.05 if i % 2 == 0 else 0.0)
			pts.append(Vector2(x, y))
		draw_polyline(pts, cor, maxf(1.5, unit * 0.02))
		return
	for i in 3:
		var cx := base.x + (i - 1) * esp
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

## 'centro_padrao' e a ancora de escamas: o meio do tronco daquele corpo, que num
## insetoide fica bem atras do centro geometrico do quadro.
func _desenhar_escamas(centro_padrao: Vector2, unit: float, modelo: int,
		escuro: Color, claro: Color) -> void:
	var r := unit * 0.13  # regiao no corpo
	match modelo:
		0:  # lisas: brilho suave (arco claro)
			draw_arc(centro_padrao + Vector2(0, -unit * 0.04), r, PI * 1.15, PI * 1.85,
				12, Color(claro, 0.6), maxf(1.5, unit * 0.02))
		1:  # granuladas: pontos
			for p in _grade(centro_padrao, r, unit * 0.055):
				draw_circle(p, unit * 0.012, Color(escuro, 0.7))
		2:  # placas: tiles retangulares
			for p in _grade(centro_padrao, r, unit * 0.06):
				var t := unit * 0.045
				draw_rect(Rect2(p - Vector2(t, t) * 0.5, Vector2(t, t)), Color(escuro, 0.55), true)
		3:  # cristalinas: losangos
			for p in _grade(centro_padrao, r, unit * 0.06):
				var d := unit * 0.028
				_poligono(PackedVector2Array([
					p + Vector2(0, -d), p + Vector2(d, 0), p + Vector2(0, d), p + Vector2(-d, 0)]),
					Color(claro, 0.7))


# --- Asas (atras do corpo, dois lados) -----------------------------------

## 'insercao' e a ancora dorsal do corpo; as duas asas abrem simetricamente dela.
func _desenhar_asas(insercao: Vector2, unit: float, modelo: int, corpo: Color,
		escuro: Color, claro: Color) -> void:
	for lado in [-1.0, 1.0]:
		var base := insercao + Vector2(lado * unit * 0.07, 0.0)
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

## 'topo' e a ancora da dorsal — no dorso de um aquatico, no lombo de um quadrupede.
func _desenhar_nadadeiras(topo: Vector2, unit: float, modelo: int, corpo: Color,
		escuro: Color, claro: Color) -> void:
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
