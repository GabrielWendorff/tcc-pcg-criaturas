class_name CreatureSpriteRenderer
extends Control

## Camada 4 — desenha a criatura com a PIXEL ART de arte/: mascara do corpo escolhido
## pelo par (animal_base, porte) mais a mascara de cada apendice que tem arte, posta na
## ancora declarada por aquele corpo.
##
## Nao ha aleatoriedade aqui: o desenho e funcao pura dos atributos ja sorteados, entao
## a mesma seed reproduz o mesmo visual (RF03/RF07).
##
## As mascaras sao indexadas (canal R = indice de paleta) e um unico ShaderMaterial,
## COMPARTILHADO pelas camadas desta criatura, resolve a rampa de cor. E por isso que
## 32 corpos x 4 garras cobrem as ~100 criaturas de um bestiario sem multiplicar assets
## por familia elemental.
##
## Cada mascara vive num TextureRect proprio, e nao num draw_texture_rect dentro de
## _draw(). Motivo: num shader canvas_item, TEXTURE e a textura DO NO, nao a do comando
## de desenho — com _draw() o shader amostrava a textura branca padrao, caia em
## round(1.0*4)=4 e pintava o quadro inteiro de cor_brilho, sem nunca descartar o
## transparente. O no com textura propria e o que faz TEXTURE apontar para a mascara.
##
## Features ainda sem arte (escamas, asas, nadadeiras) continuam sorteadas e medidas
## pelo gerador; aqui elas simplesmente nao sao desenhadas. Preferiu-se omitir a
## desenhar um placeholder vetorial por cima do pixel art: a mistura das duas
## linguagens visuais confunde a leitura da silhueta, que e justamente o que a arte
## veio corrigir. Ver CatalogoCorpos.ARTE_DE_FEATURE.

const SHADER_PALETA := preload("res://arte/shaders/paleta_indexada.gdshader")

## Folga, em pixels de arte, ao redor da caixa ocupada pela criatura. Impede que o
## contorno encoste na borda do quadro em miniaturas pequenas.
const MARGEM_ARTE := 2.0

var criatura: Criatura
var catalogo: CatalogoCorpos

## Um material por renderer, compartilhado pelas suas camadas: a rampa e a mesma para
## corpo e apendices, e trocar de criatura e trocar quatro uniformes, nao recriar
## material nenhum.
var _material := ShaderMaterial.new()

## Quadros a desenhar, em pixels de arte: [{tex: Texture2D, rect: Rect2}], de tras
## para frente. Recalculado so quando a criatura muda — nao a cada resize.
var _quadros: Array = []
var _camadas: Array[TextureRect] = []


func _init() -> void:
	_material.shader = SHADER_PALETA


## Reenquadra quando o container define/altera o tamanho. Precisa existir: em lista,
## configurar() e chamado logo apos add_child(), quando o Control ainda mede (0,0) e
## o container so distribui espaco no frame seguinte. Sem isto, as miniaturas ficam
## presas na escala 1 com origem negativa — a criatura sai cortada pelo canto.
func _notification(que: int) -> void:
	if que == NOTIFICATION_RESIZED:
		_reposicionar()


func configurar(c: Criatura, cat: CatalogoCorpos = null) -> void:
	criatura = c
	if cat != null:
		catalogo = cat
	if criatura == null or catalogo == null:
		_quadros = []
		_sincronizar_camadas()
		return

	var rampa := PaletaCriatura.rampa(criatura.matiz, criatura.paleta)
	_material.set_shader_parameter("cor_contorno", rampa[0])
	_material.set_shader_parameter("cor_sombra", rampa[1])
	_material.set_shader_parameter("cor_base", rampa[2])
	_material.set_shader_parameter("cor_brilho", rampa[3])

	_quadros = _montar_quadros()
	_sincronizar_camadas()
	_reposicionar()
	queue_redraw()


## Sem corpo resolvido, marca o erro em vez de deixar o quadro vazio: uma criatura
## invisivel esconderia um body_id invalido vindo do gerador. Fica no _draw() do
## proprio Control, que nao tem material — logo nao passa pelo shader de paleta.
func _draw() -> void:
	if criatura != null and catalogo != null and _quadros.is_empty():
		draw_rect(Rect2(size * 0.4, size * 0.2), Color("ff00ff"))


## Cria, reaproveita e esconde TextureRects para bater com _quadros. Reaproveitar em
## vez de recriar importa: o painel de detalhe troca de criatura a cada clique.
func _sincronizar_camadas() -> void:
	while _camadas.size() < _quadros.size():
		var camada := TextureRect.new()
		camada.material = _material
		camada.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		camada.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		camada.stretch_mode = TextureRect.STRETCH_SCALE
		camada.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(camada)
		_camadas.append(camada)
	for i in _camadas.size():
		var ativa: bool = i < _quadros.size()
		_camadas[i].visible = ativa
		if ativa:
			_camadas[i].texture = _quadros[i]["tex"]
	queue_redraw()


## Enquadra a criatura e posiciona as camadas. Separado de _sincronizar_camadas para
## que um resize so mexa em position/size, sem tocar na arvore de nos.
func _reposicionar() -> void:
	if _quadros.is_empty():
		return
	var caixa := _caixa()
	# Escala inteira: em pixel art, meio pixel de escala produz colunas de largura
	# desigual e a silhueta perde a leitura. Cai para 1 quando o quadro e menor que
	# a arte, aceitando corte antes de aceitar borrao.
	var escala := maxf(1.0, floorf(minf(size.x / caixa.size.x, size.y / caixa.size.y)))
	var origem := (size - caixa.size * escala) * 0.5 - caixa.position * escala
	for i in _quadros.size():
		var r: Rect2 = _quadros[i]["rect"]
		_camadas[i].position = origem + r.position * escala
		_camadas[i].size = r.size * escala


## Quadros em pixels de arte, de tras para frente. O corpo vem primeiro; os apendices
## sobrepoem porque se projetam para fora dele (as garras descem abaixo da linha do
## chao da mascara).
func _montar_quadros() -> Array:
	var corpo := catalogo.textura_corpo(criatura.body_id)
	if corpo == null:
		push_error("CreatureSpriteRenderer: corpo sem mascara — " + criatura.body_id)
		return []

	var quadros: Array = [{"tex": corpo, "rect": Rect2(Vector2.ZERO, corpo.get_size())}]

	# Itera o mapa de arte (ordem de declaracao fixa) e nao criatura.morfologia: a
	# ordem de desenho e ordem de sobreposicao, e nao pode depender da ordem de
	# insercao de um Dictionary.
	for feature in CatalogoCorpos.ARTE_DE_FEATURE:
		if not criatura.morfologia.get(feature, false):
			continue
		var tex := catalogo.textura_feature(feature, criatura.variantes[feature])
		if tex == null:
			continue
		var tam: Vector2 = tex.get_size() * catalogo.escala_apendice
		for ancora in catalogo.ancoras_de_feature(criatura.body_id, feature):
			# A ancora e a PONTA do apendice: centro horizontal, base vertical. O 1px
			# de sobreposicao evita a fresta que aparece quando ele apenas encosta no
			# contorno do corpo.
			quadros.append({
				"tex": tex,
				"rect": Rect2(ancora - Vector2(tam.x * 0.5, tam.y - 1.0), tam),
			})
	return quadros


## Caixa envolvente de tudo que sera desenhado, com margem. Precisa incluir os
## apendices: as garras extrapolam a mascara de 32x32 do corpo, e enquadrar so pelo
## corpo as cortaria fora do quadro.
func _caixa() -> Rect2:
	var caixa: Rect2 = _quadros[0]["rect"]
	for i in range(1, _quadros.size()):
		caixa = caixa.merge(_quadros[i]["rect"])
	return caixa.grow(MARGEM_ARTE)
