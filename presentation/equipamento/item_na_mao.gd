class_name ItemNaMao
extends Node2D

## O desenho do item equipado, filho do SlotDaMao.
##
## Le `ItemJogo.mao` — {"forma", "comprimento", "cor", "textura"?, "cena"?} — e
## escolhe entre tres fontes de visual, nesta ordem:
##   1. "cena": uma PackedScene instanciada como filho (arte final animada);
##   2. "textura": um Sprite2D com o PNG (arte final parada);
##   3. a FORMA: placeholder desenhado em _draw() — vara, lanterna, pa, ou o
##      proprio icone da bolsa, pequeno.
##
## E por isso que trocar o placeholder pela arte de verdade e editar uma linha
## de data/itens/catalogo.json, sem abrir este arquivo: a forma continua
## declarada como reserva, e o que chegar de arte passa na frente dela.
##
## REFERENCIAL. O item e desenhado com o CABO na origem e o corpo para CIMA
## (-y). Quem gira, posiciona e espelha e o SlotDaMao (ver PosesDaMao); aqui
## so se desenha "em pe".
##
## O QUE PENDE NAO GIRA. A linha e a boia da vara e o corpo da lanterna caem
## na vertical do MUNDO, nao na do item: uma vara inclinada a 35 graus com a
## linha tambem inclinada a 35 graus le como um arame duro, nao como linha.
## Para isso o _draw desfaz a rotacao e o espelho herdados (`_alinhado`) antes
## de desenhar a parte que pende — e o no pede redesenho quando a sua
## transformacao global muda de orientacao (nao quando so anda: andar nao muda
## para onde a gravidade aponta).

## Formas que o placeholder sabe desenhar. Forma desconhecida cai em "icone":
## o item ainda aparece na mao, so que com a arte da bolsa.
const FORMAS := ["vara", "lanterna", "pa", "icone"]
const FORMA_PADRAO := "icone"

## Comprimento padrao de cada forma, em pixels do mundo, quando o JSON nao diz.
## O quadro do jogador tem 24px de altura: uma vara de 18 passa da cabeca,
## que e o que a faz ler como vara e nao como graveto.
const COMPRIMENTO_PADRAO := {"vara": 18.0, "lanterna": 7.0, "pa": 13.0, "icone": 0.0}

## Icone da bolsa (20px) reduzido. Pequeno de proposito: um icone em tamanho de
## bolsa e quase do tamanho do personagem e le como um balao, nao como objeto.
const ESCALA_ICONE_PADRAO := 0.5

## Linha solta da vara ate a boia, em pixels, quando ela nao esta lancada.
const LINHA_SOLTA := 6.0

# Cores de metal: espelham "aco" de tools/arte/ui_lib.py. TemaEncontro nao as
# tem porque a interface nao desenha metal; o placeholder do mundo desenha.
const ACO_E := Color("4e5462")
const ACO := Color("7e8698")
const ACO_C := Color("bcc4d6")
const COR_PADRAO := Color("8a5c3e")

## Item desenhado agora (null = mao vazia).
var item: ItemJogo = null

## Forma em uso ("" = nada desenhado).
var forma: String = ""

var comprimento: float = 0.0
var cor: Color = COR_PADRAO
var escala_icone: float = ESCALA_ICONE_PADRAO

## Falso depois do lance: a linha e a boia passam a ser desenhadas no mundo pela
## pesca (LancamentoMundo, a partir de `SlotDaMao.ponta_global()`), e desenha-las
## aqui tambem daria duas linhas saindo da mesma ponta.
var boia_na_ponta: bool = true:
	set(valor):
		if boia_na_ponta == valor:
			return
		boia_na_ponta = valor
		queue_redraw()

## A arte final, quando o item declara "textura" ou "cena". null = placeholder.
var _arte: Node2D = null
## Ponta da arte final no referencial deste no (quando ha arte).
var _ponta_arte: Vector2 = Vector2.ZERO
## Base que leva eixos do MUNDO para eixos locais (rotacao e espelho desfeitos).
var _alinhado: Transform2D = Transform2D.IDENTITY


func _ready() -> void:
	# Avisa quando a transformacao GLOBAL muda — inclusive por giro do pai. E o
	# que mantem a linha da vara na vertical durante a animacao do arremesso.
	set_notify_transform(true)
	_atualizar_alinhamento(true)


func _notification(que: int) -> void:
	if que == NOTIFICATION_TRANSFORM_CHANGED:
		_atualizar_alinhamento(false)


## Troca o item desenhado. null limpa. Pode ser chamado a qualquer momento,
## dentro ou fora da arvore: o no e o mesmo, so o conteudo muda.
func configurar(novo: ItemJogo) -> void:
	item = novo
	_limpar_arte()
	boia_na_ponta = true
	forma = ""
	comprimento = 0.0
	cor = COR_PADRAO
	escala_icone = ESCALA_ICONE_PADRAO
	if item == null:
		queue_redraw()
		return

	var m: Dictionary = item.mao
	forma = String(m.get("forma", FORMA_PADRAO))
	if not forma in FORMAS:
		push_warning("ItemNaMao: forma '%s' desconhecida em '%s', usando o icone"
				% [forma, item.id])
		forma = FORMA_PADRAO
	comprimento = float(m.get("comprimento", COMPRIMENTO_PADRAO[forma]))
	cor = Color.from_string(String(m.get("cor", "")), COR_PADRAO)
	escala_icone = maxf(0.05, float(m.get("escala", ESCALA_ICONE_PADRAO)))

	# Arte final na frente do placeholder. A cena ganha da textura: quem se deu
	# ao trabalho de montar uma cena quer o que ela faz alem da imagem.
	if not _montar_cena(String(m.get("cena", "")), m):
		_montar_textura(String(m.get("textura", "")), m)
	queue_redraw()


## Ponta do item no referencial deste no — de onde sai a linha da vara, onde
## ficaria a luz da lanterna. Vector2.ZERO quando nao ha item.
func ponta_local() -> Vector2:
	if item == null or forma == "":
		return Vector2.ZERO
	if _arte != null:
		return _ponta_arte
	match forma:
		"vara", "pa":
			return Vector2(0.0, -comprimento)
		"lanterna":
			# A lanterna PENDE: a ponta util e o centro do vidro, que fica abaixo
			# da mao na vertical do mundo — e depende da pose corrente.
			return _base_alinhada().basis_xform(Vector2(0.0, 2.0 + comprimento * 0.5))
		_:
			return Vector2(0.0, -_tamanho_icone().y)


## Ha arte final (textura ou cena) no lugar do placeholder?
func tem_arte() -> bool:
	return _arte != null


# --- arte final -------------------------------------------------------------

func _montar_cena(caminho: String, m: Dictionary) -> bool:
	if caminho == "":
		return false
	if not ResourceLoader.exists(caminho):
		push_warning("ItemNaMao: cena inexistente em '%s' — %s" % [item.id, caminho])
		return false
	var pacote: PackedScene = load(caminho) as PackedScene
	if pacote == null:
		push_warning("ItemNaMao: '%s' nao e uma cena — %s" % [item.id, caminho])
		return false
	var raiz: Node = pacote.instantiate()
	if not (raiz is Node2D):
		push_warning("ItemNaMao: a cena de '%s' precisa ter raiz Node2D — %s"
				% [item.id, caminho])
		raiz.free()
		return false
	_arte = raiz as Node2D
	_arte.name = "Arte"
	add_child(_arte)
	# A ponta, em ordem de preferencia: o que a propria cena responde, um
	# Marker2D chamado "Ponta", o declarado no JSON, o comprimento.
	var resposta: Variant = _arte.call("ponta_local") if _arte.has_method("ponta_local") else null
	if resposta is Vector2:
		_ponta_arte = _arte.position + (resposta as Vector2)
	elif _arte.get_node_or_null("Ponta") is Node2D:
		_ponta_arte = _arte.position + (_arte.get_node("Ponta") as Node2D).position
	else:
		_ponta_arte = _vetor(m.get("ponta"), Vector2(0.0, -comprimento))
	return true


func _montar_textura(caminho: String, m: Dictionary) -> bool:
	if caminho == "":
		return false
	if not ResourceLoader.exists(caminho):
		push_warning("ItemNaMao: textura inexistente em '%s' — %s" % [item.id, caminho])
		return false
	var tex: Texture2D = load(caminho) as Texture2D
	if tex == null:
		push_warning("ItemNaMao: '%s' nao e uma textura — %s" % [item.id, caminho])
		return false
	var spr := Sprite2D.new()
	spr.name = "Arte"
	spr.texture = tex
	spr.centered = false
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	# "pivo" = pixel da textura que fica na mao. Padrao: meio da borda de baixo,
	# que e o cabo de um item desenhado em pe (a convencao deste no).
	var tam: Vector2 = tex.get_size()
	var pivo: Vector2 = _vetor(m.get("pivo"), Vector2(floorf(tam.x * 0.5), tam.y))
	spr.offset = -pivo
	_arte = spr
	add_child(_arte)
	# "ponta" tambem em pixels da textura. Padrao: meio da borda de cima.
	_ponta_arte = _vetor(m.get("ponta"), Vector2(floorf(tam.x * 0.5), 0.0)) - pivo
	return true


func _limpar_arte() -> void:
	if _arte != null:
		remove_child(_arte)
		_arte.queue_free()
	_arte = null
	_ponta_arte = Vector2.ZERO


## [x, y] do JSON para Vector2, com padrao para ausente ou malformado.
static func _vetor(bruto: Variant, padrao: Vector2) -> Vector2:
	if bruto is Vector2:
		return bruto
	if bruto is Array and (bruto as Array).size() >= 2:
		return Vector2(float(bruto[0]), float(bruto[1]))
	return padrao


# --- placeholder ------------------------------------------------------------

func _atualizar_alinhamento(forcar: bool) -> void:
	var novo := _base_alinhada()
	if forcar or not novo.is_equal_approx(_alinhado):
		_alinhado = novo
		queue_redraw()


## Base (sem translacao) que leva vetores em eixos do MUNDO para eixos locais.
## Fora da arvore nao ha transformacao global; usa-se a local, que e o melhor
## palpite e nao gera erro.
func _base_alinhada() -> Transform2D:
	var t: Transform2D = get_global_transform() if is_inside_tree() else transform
	var inv := t.affine_inverse()
	return Transform2D(inv.x, inv.y, Vector2.ZERO)


func _tamanho_icone() -> Vector2:
	var r := IconeCaptura.regiao(item.id) if item != null else Rect2()
	if not r.has_area():
		return Vector2.ZERO
	return r.size * escala_icone


func _draw() -> void:
	if item == null or forma == "" or _arte != null:
		return
	match forma:
		"vara":
			_desenhar_vara()
		"lanterna":
			_desenhar_lanterna()
		"pa":
			_desenhar_pa()
		_:
			_desenhar_icone()


## Cabo grosso e escuro, vara fina e clara, carretel na junta, linha com boia.
## Contorno escuro de 1px por fora em tudo: o mesmo recurso que mantem o
## sprite do jogador legivel sobre grama, terra e agua.
func _desenhar_vara() -> void:
	var topo := Vector2(0.0, -comprimento)
	var junta := Vector2(0.0, -minf(5.0, comprimento * 0.35))
	draw_line(Vector2(0.0, 1.0), topo + Vector2(0.0, -1.0), TemaEncontro.CONTORNO, 3.0)
	draw_line(Vector2.ZERO, junta, cor.darkened(0.25), 2.0)
	draw_line(junta, topo, cor.lightened(0.25), 1.0)
	draw_circle(junta + Vector2(1.5, 0.5), 1.8, TemaEncontro.CONTORNO)
	draw_circle(junta + Vector2(1.5, 0.5), 1.0, ACO_C)
	if not boia_na_ponta:
		return
	# Linha e boia na vertical do mundo, a partir da ponta.
	draw_set_transform_matrix(Transform2D(_alinhado.x, _alinhado.y, topo))
	var boia := Vector2(0.0, LINHA_SOLTA)
	draw_line(Vector2.ZERO, boia, TemaEncontro.PERG_E, 1.0)
	draw_circle(boia + Vector2(0.0, 1.5), 2.2, TemaEncontro.CONTORNO)
	draw_circle(boia + Vector2(0.0, 1.5), 1.4, TemaEncontro.PERG_C)
	draw_rect(Rect2(boia + Vector2(-1.0, 0.0), Vector2(2.0, 1.0)), TemaEncontro.VERMELHO)
	draw_set_transform_matrix(Transform2D.IDENTITY)


## Lanterna de mao PENDURADA: alca curta, tampa, vidro aceso, base. Toda ela na
## vertical do mundo — uma lanterna inclinada junto com o braco le como se
## estivesse colada na mao.
func _desenhar_lanterna() -> void:
	draw_set_transform_matrix(_alinhado)
	var alt: float = maxf(4.0, comprimento)
	var topo_corpo: float = 2.0
	# brilho: um halo fraco em volta do vidro, para ler "acesa" de longe
	draw_circle(Vector2(0.0, topo_corpo + alt * 0.5), alt * 0.9, Color(TemaEncontro.OURO, 0.16))
	draw_line(Vector2.ZERO, Vector2(0.0, topo_corpo), ACO_E, 1.0)            # alca
	draw_rect(Rect2(-3.0, topo_corpo - 1.0, 6.0, alt + 2.0), TemaEncontro.CONTORNO)
	draw_rect(Rect2(-2.0, topo_corpo, 4.0, 1.0), cor)                        # tampa
	draw_rect(Rect2(-2.0, topo_corpo + 1.0, 4.0, alt - 2.0), TemaEncontro.OURO)   # vidro
	draw_rect(Rect2(-1.0, topo_corpo + 2.0, 2.0, maxf(1.0, alt - 4.0)), TemaEncontro.OURO_C)
	draw_rect(Rect2(-2.0, topo_corpo + alt - 1.0, 4.0, 1.0), cor.darkened(0.3))   # base
	draw_set_transform_matrix(Transform2D.IDENTITY)


## Pa de jardim em pe: cabo de madeira, virola, lamina em ponta.
func _desenhar_pa() -> void:
	var l: float = maxf(8.0, comprimento)
	var junta: float = -l * 0.45
	draw_line(Vector2(0.0, 1.0), Vector2(0.0, junta), TemaEncontro.CONTORNO, 3.0)
	draw_line(Vector2.ZERO, Vector2(0.0, junta), cor, 1.0)
	var lamina := PackedVector2Array([
		Vector2(-2.0, junta), Vector2(2.0, junta), Vector2(3.0, junta - 3.0),
		Vector2(0.0, -l), Vector2(-3.0, junta - 3.0),
	])
	draw_colored_polygon(lamina, ACO)
	# metade esquerda clara: luz no alto a esquerda, como na arte da folha
	draw_colored_polygon(PackedVector2Array([
		Vector2(-2.0, junta), Vector2(0.0, junta), Vector2(0.0, -l), Vector2(-3.0, junta - 3.0),
	]), ACO_C)
	var contorno := lamina.duplicate()
	contorno.append(lamina[0])
	draw_polyline(contorno, TemaEncontro.CONTORNO, 1.0)
	draw_rect(Rect2(-1.5, junta - 0.5, 3.0, 2.0), ACO_E)                     # virola


## O icone da bolsa, pequeno, com a base na mao.
func _desenhar_icone() -> void:
	var folha := IconeCaptura.folha()
	var r := IconeCaptura.regiao(item.id)
	if folha == null or not r.has_area():
		return
	var tam := _tamanho_icone()
	draw_texture_rect_region(folha, Rect2(Vector2(-tam.x * 0.5, -tam.y), tam), r)
