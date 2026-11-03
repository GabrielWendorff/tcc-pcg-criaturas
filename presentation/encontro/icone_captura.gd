class_name IconeCaptura
extends Control

## Icone de um item, recortado da folha arte/itens/itens.png.
##
## Antes as formas eram desenhadas por primitivas em _draw(). Funcionava, mas
## cada icone era uma composicao de circulos e retangulos exatos — e o resultado
## lia como diagrama, nao como objeto: sem contorno consistente, sem volume, e
## com estilos que nao combinavam entre si. A arte agora vem de
## tools/arte/gerar_itens.py, que aplica a mesma direcao das outras familias:
## silhueta primeiro, contorno escuro de 1px por fora, tres tons e luz no alto a
## esquerda.
##
## O indice de cada icone vem de arte/itens/itens.json, chaveado pelos MESMOS ids
## de data/captura/*.json. Item declarado sem icone e erro de dado — apanhado por
## tools/test_encontro.gd, nao descoberto como um buraco na roda.

const CAMINHO_FOLHA := "res://arte/itens/itens.png"
const CAMINHO_INDICE := "res://arte/itens/itens.json"

## Escala de desenho. INTEIRA sempre: meio pixel de escala em pixel art produz
## colunas de larguras desiguais, que e o defeito que a arte veio corrigir.
var escala: int = 2

## Esmaece o icone sem trocar as cores — usado no slot sem estoque.
var esmaecido: bool = false:
	set(valor):
		esmaecido = valor
		queue_redraw()

var _id: String = ""

static var _folha: Texture2D
static var _indice: Dictionary = {}
static var _celula: Vector2i = Vector2i(20, 20)
static var _colunas: int = 8
static var _carregado: bool = false


func _init(id: String = "", escala_: int = 2) -> void:
	_id = id
	escala = escala_
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func configurar(id: String, escala_: int = -1) -> void:
	_id = id
	if escala_ > 0:
		escala = escala_
	queue_redraw()


## Tamanho que o icone ocupa nesta escala. Serve para o layout reservar o espaco
## exato, sem numero magico espalhado pelos paineis.
func tamanho() -> Vector2:
	_carregar()
	return Vector2(_celula) * float(escala)


func _draw() -> void:
	_carregar()
	if _folha == null or not _indice.has(_id):
		return
	var i: int = int(_indice[_id])
	var origem := Vector2i((i % _colunas) * _celula.x, (i / _colunas) * _celula.y)
	var destino := Rect2((size - tamanho()) * 0.5, tamanho())
	# floor no canto: em posicao fracionaria o recorte pega meia coluna de pixel
	# do icone vizinho na folha e aparece uma listra na borda.
	destino.position = destino.position.floor()
	draw_texture_rect_region(_folha, destino, Rect2(origem, _celula),
			Color(1, 1, 1, 0.35) if esmaecido else Color.WHITE)


## Folha e indice carregados UMA vez para todo o processo: a roda cria ate 10
## icones por abertura, e cada um relendo o JSON seria desperdicio puro.
static func _carregar() -> void:
	if _carregado:
		return
	_carregado = true
	_folha = load(CAMINHO_FOLHA)
	if not FileAccess.file_exists(CAMINHO_INDICE):
		push_error("IconeCaptura: indice ausente — " + CAMINHO_INDICE)
		return
	var dados: Variant = JSON.parse_string(
			FileAccess.get_file_as_string(CAMINHO_INDICE))
	if dados == null:
		push_error("IconeCaptura: indice invalido — " + CAMINHO_INDICE)
		return
	_indice = dados.get("itens", {})
	var c: Array = dados.get("celula", [20, 20])
	_celula = Vector2i(int(c[0]), int(c[1]))
	_colunas = int(dados.get("colunas", 8))


## Ids que a folha conhece. Usado pelo teste para confrontar arte e dado.
static func ids_conhecidos() -> Array:
	_carregar()
	return _indice.keys()


## A folha inteira, para quem desenha icone FORA de um Control — a roda de itens
## e o item na mao desenham em _draw() de Node2D/CanvasLayer, e instanciar um
## IconeCaptura (Control) so para ler a textura seria um no inteiro por icone.
## O carregamento e o mesmo cache estatico: nenhuma segunda leitura do disco.
static func folha() -> Texture2D:
	_carregar()
	return _folha


## Recorte do icone `id` na folha, em pixels. Rect2() (vazio) quando o id nao
## existe — quem desenha testa `has_area()` e pula, em vez de pintar a celula
## zero (a esfera) no lugar de um item que esqueceram de desenhar.
static func regiao(id: String) -> Rect2:
	_carregar()
	if not _indice.has(id):
		return Rect2()
	var i: int = int(_indice[id])
	var linha: int = floori(float(i) / float(_colunas))
	return Rect2(Vector2((i % _colunas) * _celula.x, linha * _celula.y),
			Vector2(_celula))
