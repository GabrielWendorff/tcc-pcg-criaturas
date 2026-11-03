extends Node2D

## Cena de TESTE da pesca — abra tools/cena_teste_pesca.tscn no editor e rode
## com F6 (executar a cena atual). Sem o mapa, sem NPC, sem save:
##
##   chao plano desenhado, uma faixa de agua (Polygon2D azul, com colisao),
##   o Jogador de verdade (com a SlotDaMao), a CameraExploracao seguindo-o, a
##   RodaItens e o GerenciadorPesca com um bestiario de DUAS criaturas montadas
##   a mao — uma de cada ponta da coerencia que a pesca le (RF04):
##     Agua-Peixe   esbelto, nadadeiras + escamas -> fundo, mais rapido e
##                  escorregadio (folga de velocidade menor)
##     Gelo-Anfibio compacto, sem tracos           -> mais raso e lento
##   Qual dos dois e o "mais facil" (o monstro do tutorial) sai da formula de
##   PerfilPesca.dificuldade, nao desta lista — o console diz qual e.
##
## Teclas: Q roda de itens · F pescar (e travar o arco) · ESC cancela ·
##         T liga/desliga o modo tutorial · R reinicia a cena.
##
## Serve para calibrar data/pesca/*.json e os @export visuais sem atravessar o
## mundo ate a ribeira: troque um numero, aperte R. Os perfis de pesca das duas
## criaturas sao impressos no console ao abrir.
##
## POR QUE ESTA CENA E NAO O MUNDO: o GerenciadorPesca recebe `e_agua` e
## `regiao_em` como Callable (nao conhece o MundoIso). Aqui eles leem o poligono
## da faixa d'agua — a mesma pesca, sem uma linha de codigo de excecao. E o
## teste de que a separacao vale.
##
## Roda como cena NORMAL (F6, ou `godot --path . res://tools/cena_teste_pesca.tscn`),
## nao sob -s: a camera e a bolsa precisam dos autoloads (Opcoes, Bolsa).

## Seed do sandbox: alimenta o RNG da pesca (surgimento, roleta, deriva). As
## duas criaturas nao vem do gerador, entao a seed nao muda QUEM existe aqui.
@export var seed_do_teste: int = 20261027
## Regiao devolvida para todo ponto da agua: escolhe o PontoDePesca de
## data/pesca/pontos.json ("vila" = Lago da Vila, "ribeira", "industrial" = Rio
## da Fabrica). Troque no inspetor para ver os pesos de outro habitat.
@export var regiao_da_agua: String = "ribeira"
## Chao desenhado, em pixels do mundo. Maior que a area visivel com zoom 3
## (1152x648 / 3), senao a camera centraliza em vez de seguir.
@export var area_do_chao: Rect2 = Rect2(-300, -240, 760, 480)
## Onde o jogador nasce: na beira, de frente para a agua (a direita).
@export var inicio_jogador: Vector2 = Vector2(112, 0)
@export var cor_grama: Color = Color("5f9e4a")
@export var cor_grade: Color = Color(0.0, 0.0, 0.0, 0.07)
@export var cor_areia: Color = Color("d9c38c")
@export var cor_agua: Color = Color("3f88a6")
## Folga da faixa de areia em volta da agua, em pixels.
@export var largura_areia: float = 10.0

## Contorno da agua, em pixels do mundo. Uma faixa vertical com a margem
## irregular: ~9 celulas de largura (o arremesso maximo e 7), e alcancavel a
## partir de `inicio_jogador` (a 1,3 celula da beira; o alcance e 1,6).
const CONTORNO_AGUA := [
	Vector2(140, -230), Vector2(330, -230), Vector2(352, -120), Vector2(338, 0),
	Vector2(360, 110), Vector2(344, 230), Vector2(150, 230), Vector2(136, 120),
	Vector2(144, 40), Vector2(138, -60), Vector2(146, -150),
]

## Tamanho da celula do mapa (o mesmo do MundoIso), para a grade desenhada e
## para a metrica de distancia da pesca.
const CELULA := Vector2i(32, 16)
const CAMADA_HUD := 86

var jogador: Jogador
var camera: CameraExploracao
var roda: RodaItens
var pesca: GerenciadorPesca
var bestiario: Array = []

var _agua: Polygon2D
var _hud: Label
var _ultimo_resultado: String = "—"
var _ultimo_aviso: String = ""
var _erro: String = ""


func _ready() -> void:
	_montar_agua()

	jogador = Jogador.new()
	jogador.name = "Jogador"
	jogador.position = inicio_jogador
	# Antes do add_child: o _ready do jogador aplica a direcao ao sprite e a mao.
	jogador.direcao = "direita"
	add_child(jogador)

	camera = CameraExploracao.new()
	camera.name = "Camera"
	add_child(camera)
	camera.enquadrar(area_do_chao)
	camera.seguir(jogador)

	roda = RodaItens.new()
	roda.name = "RodaItens"
	add_child(roda)
	roda.item_escolhido.connect(jogador.equipar)
	roda.fechada.connect(func(_trocou: bool) -> void: jogador.congelar(false))

	_montar_hud()
	_montar_pesca()
	_dar_a_vara()
	queue_redraw()


# ------------------------------------------------------------------ montagem

## Poligono azul (o que se ve) + corpo estatico com o mesmo contorno (o que
## segura o jogador na beira). O mesmo poligono responde `e_agua`.
func _montar_agua() -> void:
	var contorno := PackedVector2Array(CONTORNO_AGUA)
	_agua = Polygon2D.new()
	_agua.name = "Agua"
	_agua.polygon = contorno
	_agua.color = cor_agua
	add_child(_agua)

	var corpo := StaticBody2D.new()
	corpo.name = "MargemDaAgua"
	var forma := CollisionPolygon2D.new()
	forma.polygon = contorno
	corpo.add_child(forma)
	add_child(corpo)


func _montar_pesca() -> void:
	var tabelas := TabelasProbabilidade.carregar()
	var catalogo: CatalogoCorpos = CatalogoCorpos.carregar(tabelas) if tabelas != null else null
	if catalogo == null:
		_erro = "catalogo de corpos nao carregou (res://arte/corpos/)"
		push_error("CenaTestePesca: " + _erro)
		return
	bestiario = _bestiario_de_exemplo(tabelas, catalogo)

	pesca = GerenciadorPesca.new()
	pesca.name = "Pesca"
	# Filha desta cena, e antes do preparar — como em mundo.gd: o indicador
	# "[F] PESCAR" entra no jogador e a interface na arvore no preparar.
	add_child(pesca)
	if not pesca.preparar(jogador, camera, bestiario, seed_do_teste, _e_agua,
			_regiao_em, CELULA, catalogo):
		_erro = pesca.erro
		push_error("CenaTestePesca: " + _erro)
		return
	# Um dono da tela por vez, na versao de duas pecas: a roda e a pesca.
	pesca.permissao = func() -> bool: return not roda.aberta()
	pesca.aviso.connect(func(texto: String) -> void: _ultimo_aviso = texto)
	pesca.peixe_fisgado.connect(func(c: Criatura) -> void:
			_ultimo_resultado = "FISGOU %s" % c.nome() if c != null else "FISGOU")
	pesca.pesca_falhou.connect(func(motivo: String) -> void:
			_ultimo_resultado = "FALHOU (%s)" % motivo)
	_imprimir_perfis()


## As duas criaturas de exemplo, montadas campo a campo como o GeradorCriaturas
## as montaria. seed_individual FIXO: e dele que sai o ruido do perfil
## (PerfilPesca.DESLOCAMENTO_RUIDO), entao o perfil impresso e sempre o mesmo.
func _bestiario_de_exemplo(tabelas: TabelasProbabilidade,
		catalogo: CatalogoCorpos) -> Array:
	var peixe := _criatura(tabelas, catalogo, 1, "agua", "peixe", "esbelto", "fria",
			"azul", {"escamas": 1, "nadadeiras": 2}, 7001)
	var anfibio := _criatura(tabelas, catalogo, 2, "gelo", "anfibio", "compacto", "fria",
			"ciano", {}, 7002)
	return [peixe, anfibio]


## `tracos`: feature -> modelo (indice da variante). Ausente = traco ausente.
func _criatura(tabelas: TabelasProbabilidade, catalogo: CatalogoCorpos, id: int,
		elemento: String, animal: String, porte: String, paleta: String, matiz: String,
		tracos: Dictionary, seed_individual: int) -> Criatura:
	var c := Criatura.new()
	c.id = id
	c.world_seed = seed_do_teste
	c.seed_individual = seed_individual
	c.elemento = elemento
	c.animal_base = animal
	c.porte = porte
	c.body_id = CatalogoCorpos.montar_body_id(animal, maxi(tabelas.portes().find(porte), 0),
			porte)
	if not catalogo.existe(c.body_id):
		push_warning("CenaTestePesca: corpo '%s' sem arte — silhueta generica" % c.body_id)
	c.arquetipo = catalogo.arquetipo(c.body_id)
	c.paleta = paleta
	c.matiz = matiz
	for f: String in ["garras", "escamas", "asas", "nadadeiras"]:
		var tem: bool = tracos.has(f)
		c.morfologia[f] = tem
		if tem:
			c.variantes[f] = clampi(int(tracos[f]), 0, maxi(tabelas.num_modelos(f) - 1, 0))
	return c


## A vara pela Bolsa (o estoque unico do jogo) e direto na mao. Nao empilha:
## reiniciar a cena nao da uma segunda vara.
func _dar_a_vara() -> void:
	if Bolsa.item("vara_de_pesca") == null:
		_erro = "a Bolsa nao conhece 'vara_de_pesca' (data/itens/catalogo.json)"
		push_error("CenaTestePesca: " + _erro)
		return
	Bolsa.adicionar("vara_de_pesca", 1)
	jogador.equipar(Bolsa.item("vara_de_pesca"))


func _imprimir_perfis() -> void:
	print("== Cena de teste da pesca — seed %d, regiao '%s' ==" % [seed_do_teste,
			regiao_da_agua])
	for p: Variant in pesca.perfis():
		var perfil := p as PerfilPesca
		print("  ", perfil)
		print("    ", perfil.to_dict())
	var ponto := pesca.tabelas.ponto_da_regiao(regiao_da_agua)
	if ponto == null:
		return
	print("  ponto '%s' (surgimento x%.2f):" % [ponto.nome, ponto.multiplicador_surgimento])
	for cand: Dictionary in ponto.candidatos(pesca.perfis()):
		var perfil := cand["perfil"] as PerfilPesca
		print("    peso %.3f  %s" % [float(cand["peso"]), perfil.criatura.nome()])
	var facil := PontoDePesca.mais_facil(ponto.candidatos(pesca.perfis()))
	if facil != null:
		print("  monstro do tutorial (mais facil): %s" % facil.criatura.nome())


# ------------------------------------------------------------------ geometria

func _e_agua(p: Vector2) -> bool:
	return Geometry2D.is_point_in_polygon(p - _agua.global_position, _agua.polygon)


func _regiao_em(p: Vector2) -> String:
	return regiao_da_agua if _e_agua(p) else ""


# ---------------------------------------------------------------------- entrada

## Q abre a roda (o soltar e da propria roda); T e R sao teclas de depuracao,
## como F2-F5 no mundo. F e ESC sao da pesca, que os le sozinha — e, sendo
## filha desta cena, os recebe antes daqui.
func _unhandled_input(evento: InputEvent) -> void:
	if evento.is_action_pressed("roda_itens"):
		if not roda.aberta() and (pesca == null or not pesca.ativa()):
			roda.abrir(Bolsa.com_marcador("equipamento"), jogador.item_equipado)
			jogador.congelar(true)
		get_viewport().set_input_as_handled()
		return
	if not (evento is InputEventKey) or not evento.pressed or evento.echo:
		return
	match (evento as InputEventKey).keycode:
		KEY_T:
			if pesca != null:
				pesca.modo_tutorial = not pesca.modo_tutorial
		KEY_R:
			get_tree().reload_current_scene()


# ---------------------------------------------------------------------- desenho

func _draw() -> void:
	draw_rect(area_do_chao, cor_grama)
	# Grade de losangos da celula do mapa: so referencia de escala (quantas
	# celulas o arremesso alcanca), nao colisao.
	var mx: float = float(CELULA.x) * 0.5
	var my: float = float(CELULA.y) * 0.5
	var x0: float = area_do_chao.position.x
	var x1: float = area_do_chao.end.x
	var y0: float = area_do_chao.position.y
	var y1: float = area_do_chao.end.y
	var passo: float = float(CELULA.y)
	var k: float = y0 - (x1 - x0) * my / mx
	while k <= y1:
		draw_line(Vector2(x0, k), Vector2(x1, k + (x1 - x0) * my / mx), cor_grade)
		draw_line(Vector2(x0, k + (x1 - x0) * my / mx), Vector2(x1, k), cor_grade)
		k += passo
	# Areia: o contorno da agua engordado, desenhado por baixo do Polygon2D.
	for contorno: PackedVector2Array in Geometry2D.offset_polygon(
			PackedVector2Array(CONTORNO_AGUA), largura_areia):
		draw_colored_polygon(contorno, cor_areia)


func _montar_hud() -> void:
	var camada := CanvasLayer.new()
	camada.name = "HUD"
	# Acima da InterfacePesca (84) e abaixo da roda (88): o HUD continua legivel
	# com o minigame aberto, no topo que ele reserva para a dica do tutorial.
	camada.layer = CAMADA_HUD
	add_child(camada)
	var fundo := ColorRect.new()
	fundo.color = Color(TemaEncontro.NOITE_E, 0.72)
	fundo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fundo.position = Vector2(8, 6)
	fundo.size = Vector2(620, 80)
	camada.add_child(fundo)
	_hud = TemaEncontro.rotulo("", TemaEncontro.PERG_C)
	_hud.position = Vector2(14, 8)
	camada.add_child(_hud)


func _process(_delta: float) -> void:
	if _hud == null:
		return
	if _erro != "":
		_hud.text = "CENA DE TESTE — PESCA\nERRO: " + _erro
		return
	var linhas: PackedStringArray = []
	linhas.append("CENA DE TESTE — PESCA   seed %d · %d criaturas · água: %s"
			% [seed_do_teste, bestiario.size(), regiao_da_agua])
	linhas.append("Q roda de itens   F pescar / travar o arco   ESC cancela   T tutorial   R reinicia")
	var estado: String = EstadoPesca.nome(pesca.estado.atual) if pesca != null else "?"
	var tutorial: String = "LIGADO" if pesca != null and pesca.modo_tutorial else "desligado"
	var na_mao: String = jogador.item_atual().nome if jogador.item_atual() != null else "mãos livres"
	linhas.append("estado: %s   modo tutorial: %s   na mão: %s" % [estado, tutorial, na_mao])
	linhas.append(_linha_da_silhueta())
	linhas.append("último resultado: %s%s" % [_ultimo_resultado,
			"   ·   aviso: " + _ultimo_aviso if _ultimo_aviso != "" else ""])
	_hud.text = "\n".join(linhas)


func _linha_da_silhueta() -> String:
	var s: SimulacaoRecolhimento = pesca.simulacao() if pesca != null else null
	if s == null:
		if pesca != null and pesca.pode_pescar_aqui():
			return "na beira: aperte F para pescar"
		return "sem lance em curso"
	if s.perfil == null:
		return "recolhendo — %.1f de %.1f células, nenhuma sombra ainda" \
				% [s.distancia, s.distancia_total]
	return "sombra: %s   interesse %d/%d   altura %s · velocidade %s" % [
			s.perfil.criatura.nome(), int(s.interesse), int(pesca.cfg.interesse_alvo),
			"OK" if s.na_altura else "--", "OK" if s.na_velocidade else "--"]
