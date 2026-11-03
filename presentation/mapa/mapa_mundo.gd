class_name MapaMundo
extends CanvasLayer

## O mapa geral do mundo (tecla M).
##
## A CARTA E RASTERIZADA DO PROPRIO TERRENO, um pixel por celula, na mesma
## projecao isometrica em que o jogador anda. Nao e uma ilustracao desenhada a
## parte, e isso e uma decisao de arquitetura, nao de arte:
##
##   - uma regiao nova aparece no mapa sem ninguem desenhar nada — basta ela
##     existir no JSON do mundo, que e exatamente o criterio de "o sistema
##     escala para novas areas" do escopo;
##   - o mapa nao pode MENTIR. Uma ilustracao envelhece em silencio: muda-se o
##     curso do rio no compilador do mapa e a carta continua mostrando o rio
##     antigo. Aqui as duas coisas sao o mesmo dado.
##
## PROJECAO. `(gx - gy, (gx + gy) / 2)` e a mesma relacao 2:1 de MundoIso, so que
## em escala de miniatura. Isso importa mais do que parece: uma carta desenhada
## na grade (retangulo) estaria girada 45 graus em relacao ao que se ve andando,
## e o jogador teria de fazer a conversao de cabeca a cada consulta.
##
## DESCOBERTA. Regiao nao visitada aparece sob um veu, com o nome escondido. O
## que decide e EstadoMundo.visitou() — a mesma bandeira que o dialogo pode
## consultar com {"visitou": "ribeira"}.
##
## A tela NAO conhece o jogador nem o mundo: recebe os dados em `preparar()` e
## uma celula em `atualizar_posicao()`. E o que permite abri-la de um teste.

signal fechado()

const CAMADA := 95

## Ampliacao da carta. INTEIRA, pelo mesmo motivo do zoom da camera: em escala
## fracionaria um pixel da carta cobre 3,5 pixels de tela e as colunas saem com
## larguras desiguais.
const ESCALA := 4

## Cor de cada terreno na carta. Espelha a paleta de tools/arte/mundo_lib.py —
## sao os MESMOS materiais, um tom acima do tom base para a carta nao sair
## abafada sob o veu de pergaminho.
const CORES := {
	"grama": Color("6f9e57"),
	"grama_alta": Color("3d6b40"),
	"caminho": Color("b89a6e"),
	"terra": Color("9c968b"),
	"areia": Color("d8c795"),
	"agua": Color("3a84b0"),
	"rocha": Color("4c4e5e"),
	"calcada": Color("9a9896"),
	"lavoura": Color("7a5a3e"),
	"ponte": Color("a5805a"),
}
const COR_DESCONHECIDA := Color("55503f")

## Veu sobre regiao nao visitada. Nao e preto: sobre uma carta de pergaminho o
## que esconde e a TINTA ENVELHECIDA, nao a sombra.
const COR_VEU := Color(0.42, 0.36, 0.26, 0.86)

var estado: EstadoMundo

var _regioes: Array = []
var _celula_do_jogador: Vector2i = Vector2i.ZERO
var _regiao_atual: String = ""
var _carta: Carta
var _lista: VBoxContainer
var _aberto: bool = false


func _ready() -> void:
	layer = CAMADA
	visible = false


## Recebe os dados do mundo ja montado. Depois disto a tela e autossuficiente.
func preparar(mundo: MundoIso, estado_do_mundo: EstadoMundo) -> void:
	estado = estado_do_mundo
	_regioes = mundo.dados_das_regioes()
	_montar(mundo)


func _montar(mundo: MundoIso) -> void:
	var fundo := ColorRect.new()
	fundo.name = "Escurecimento"
	fundo.color = Color(0.05, 0.05, 0.07, 0.72)
	fundo.set_anchors_preset(Control.PRESET_FULL_RECT)
	fundo.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(fundo)

	var centro := CenterContainer.new()
	centro.set_anchors_preset(Control.PRESET_FULL_RECT)
	centro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(centro)

	var moldura := PanelContainer.new()
	moldura.name = "Moldura"
	moldura.add_theme_stylebox_override("panel", TemaEncontro.moldura("pergaminho"))
	moldura.mouse_filter = Control.MOUSE_FILTER_IGNORE
	centro.add_child(moldura)

	var coluna := VBoxContainer.new()
	coluna.add_theme_constant_override("separation", 8)
	coluna.mouse_filter = Control.MOUSE_FILTER_IGNORE
	moldura.add_child(coluna)

	var titulo := TemaEncontro.rotulo("MAPA DO VALE", TemaEncontro.TINTA,
			TemaEncontro.Corpo.TITULO)
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	coluna.add_child(titulo)

	var linha := HBoxContainer.new()
	linha.add_theme_constant_override("separation", 14)
	linha.mouse_filter = Control.MOUSE_FILTER_IGNORE
	coluna.add_child(linha)

	_carta = Carta.new()
	_carta.name = "Carta"
	_carta.dono = self
	_carta.montar(mundo)
	linha.add_child(_carta)

	_lista = VBoxContainer.new()
	_lista.name = "Legenda"
	_lista.add_theme_constant_override("separation", 6)
	_lista.custom_minimum_size = Vector2(230, 0)
	_lista.mouse_filter = Control.MOUSE_FILTER_IGNORE
	linha.add_child(_lista)

	var rodape := TemaEncontro.rotulo("M ou ESC  fecha o mapa", TemaEncontro.TINTA_C)
	rodape.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	coluna.add_child(rodape)


# ------------------------------------------------------------------- estado
func aberto() -> bool:
	return _aberto


func abrir() -> void:
	if _aberto:
		return
	_aberto = true
	visible = true
	_atualizar_legenda()
	_carta.queue_redraw()


func fechar() -> void:
	if not _aberto:
		return
	_aberto = false
	visible = false
	fechado.emit()


func alternar() -> void:
	if _aberto:
		fechar()
	else:
		abrir()


## Onde o marcador do jogador fica. Recebe a celula, e nao o no: a tela nao
## precisa (nem deve) conhecer o Jogador para desenhar um ponto.
func atualizar_posicao(celula: Vector2i, regiao: String = "") -> void:
	_celula_do_jogador = celula
	_regiao_atual = regiao
	if _aberto and _carta != null:
		_carta.queue_redraw()


func _unhandled_input(evento: InputEvent) -> void:
	if not _aberto:
		return
	if evento.is_action_pressed("abrir_mapa") or evento.is_action_pressed("ui_cancel"):
		fechar()
		get_viewport().set_input_as_handled()


func _descoberta(id_regiao: String) -> bool:
	return estado == null or estado.visitou(id_regiao)


## Legenda lateral: uma linha por regiao, na ordem do mapa. O que nao foi
## visitado aparece como "???" — o mapa nao entrega o mundo antes de o jogador
## andar nele.
func _atualizar_legenda() -> void:
	for filho in _lista.get_children():
		filho.queue_free()
	var cabecalho := TemaEncontro.rotulo("REGIÕES", TemaEncontro.MADEIRA_E)
	_lista.add_child(cabecalho)
	for r: Dictionary in _regioes:
		var id_regiao := String(r.get("id", ""))
		var conhecida := _descoberta(id_regiao)
		var aqui: bool = id_regiao == _regiao_atual
		var marca := "▶ " if aqui else "  "
		var nome: String = String(r.get("nome", id_regiao)) if conhecida else "???"
		var rotulo := TemaEncontro.rotulo(marca + nome,
				TemaEncontro.OURO_E if aqui else (
					TemaEncontro.TINTA if conhecida else TemaEncontro.TINTA_C))
		_lista.add_child(rotulo)
		if conhecida:
			var desc := TemaEncontro.rotulo("   " + String(r.get("descricao", "")),
					TemaEncontro.TINTA_C)
			desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			desc.custom_minimum_size = Vector2(220, 0)
			_lista.add_child(desc)


## A carta em si: textura do terreno + veus, rotulos e marcador do jogador.
##
## Tudo num _draw() so, e nao em nos separados, porque os tres desenhos precisam
## da MESMA projecao: um rotulo posicionado por um calculo e um veu por outro
## divergem no primeiro ajuste de escala.
class Carta extends Control:
	var dono: MapaMundo
	var textura: ImageTexture
	var largura_celulas: int = 0
	var profundidade_celulas: int = 0
	var deslocamento_x: int = 0

	var _tempo: float = 0.0

	func montar(mundo: MundoIso) -> void:
		largura_celulas = mundo.largura
		profundidade_celulas = mundo.profundidade
		# A projecao (gx - gy) leva metade das celulas para x negativo; o
		# deslocamento traz o losango inteiro para dentro da imagem.
		deslocamento_x = profundidade_celulas
		var larg := largura_celulas + profundidade_celulas + 2
		var alt := (largura_celulas + profundidade_celulas) / 2 + 2
		var img := Image.create(larg, alt, false, Image.FORMAT_RGBA8)
		img.fill(Color(0, 0, 0, 0))

		var linhas := mundo.linhas_de_terreno()
		var legenda := mundo.legenda_do_terreno()
		for gy in profundidade_celulas:
			for gx in largura_celulas:
				var nome := String(legenda.get(linhas[gy][gx], "grama"))
				var cor: Color = CORES.get(nome, COR_DESCONHECIDA)
				var p := _projetar(Vector2i(gx, gy))
				# DOIS pixels de largura: na projecao isometrica em miniatura,
				# celulas vizinhas caem em colunas alternadas e um pixel so
				# deixaria a carta furada como um xadrez.
				img.set_pixel(int(p.x), int(p.y), cor)
				img.set_pixel(int(p.x) + 1, int(p.y), cor)
		textura = ImageTexture.create_from_image(img)
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		custom_minimum_size = Vector2(larg, alt) * ESCALA
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_process(true)

	func _projetar(c: Vector2i) -> Vector2:
		return Vector2(float(c.x - c.y + deslocamento_x),
				float(c.x + c.y) * 0.5)

	func _na_carta(c: Vector2i) -> Vector2:
		return (_projetar(c) + Vector2(1.0, 0.5)) * ESCALA

	func _process(delta: float) -> void:
		if not visible or dono == null or not dono.aberto():
			return
		_tempo += delta
		queue_redraw()

	func _draw() -> void:
		if textura == null:
			return
		draw_texture_rect(textura,
				Rect2(Vector2.ZERO, Vector2(textura.get_size()) * ESCALA), false)

		var fonte := TemaEncontro.fonte()
		for r: Dictionary in dono._regioes:
			var ret: Array = r.get("retangulo", [0, 0, 0, 0])
			var x0: int = int(ret[0])
			var y0: int = int(ret[1])
			var x1: int = int(ret[2])
			var y1: int = int(ret[3])
			var quinas := PackedVector2Array([
				_na_carta(Vector2i(x0, y0)), _na_carta(Vector2i(x1, y0)),
				_na_carta(Vector2i(x1, y1)), _na_carta(Vector2i(x0, y1))])
			var conhecida: bool = dono._descoberta(String(r.get("id", "")))
			var centro: Vector2 = _na_carta(Vector2i((x0 + x1) / 2, (y0 + y1) / 2))
			if not conhecida:
				draw_colored_polygon(quinas, COR_VEU)
				draw_string(fonte, centro + Vector2(-6, 4), "?",
						HORIZONTAL_ALIGNMENT_LEFT, -1, TemaEncontro.TAM_TEXTO,
						TemaEncontro.PERG_E)
				continue
			for i in quinas.size():
				draw_line(quinas[i], quinas[(i + 1) % quinas.size()],
						Color(TemaEncontro.MADEIRA_E, 0.55), 1.0)
			var nome := String(r.get("nome", ""))
			var largura_texto := fonte.get_string_size(nome, HORIZONTAL_ALIGNMENT_LEFT,
					-1, TemaEncontro.TAM_TEXTO).x
			# Sombra clara sob o nome: e o mesmo recurso do HUD (fonte de bitmap
			# nao aceita contorno da engine), invertido para carta clara.
			for passo in 2:
				draw_string(fonte,
						centro + Vector2(-largura_texto * 0.5, 4) + Vector2(1, 1) * (1 - passo),
						nome, HORIZONTAL_ALIGNMENT_LEFT, -1, TemaEncontro.TAM_TEXTO,
						TemaEncontro.PERG_C if passo == 0 else TemaEncontro.TINTA)

		# --- marcador do jogador ---
		var p := _na_carta(dono._celula_do_jogador)
		var pulso := 1.0 + 0.25 * sin(_tempo * 4.0)
		draw_circle(p, 6.0 * pulso, Color(TemaEncontro.OURO, 0.35))
		draw_circle(p, 3.0, TemaEncontro.OURO_C)
		draw_arc(p, 6.0 * pulso, 0.0, TAU, 20, TemaEncontro.CONTORNO, 1.0)
