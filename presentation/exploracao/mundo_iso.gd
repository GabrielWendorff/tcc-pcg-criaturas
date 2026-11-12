class_name MundoIso
extends Node2D

## Camada 4 — monta a area jogavel isometrica a partir do mapa autoral.
##
## Le tres arquivos de dados e nao decide nada por conta propria:
##   autoral/mapas/mundo.json         o mapa (Camada 1, fixo, sem seed)
##   arte/mundo/atlas_terreno.json    onde cada terreno mora no atlas
##   arte/mundo/props.json            ancora e colisao de cada prop
##
## Nao ha geracao procedural aqui. O mundo e conteudo AUTORAL: nao depende da
## world_seed e nao muda entre partidas. O gerador por seed continua restrito a
## procedural/, onde as metricas de RF04/RF08 o medem. Quando a Camada 3
## (procedural/ambiance/) existir, ela vai ESPALHAR props sobre este mapa a
## partir da seed — por isso `adicionar_prop()` e publico e os containers de
## categoria sao acessiveis por grupo.
##
## ESTRUTURA DA ARVORE, e por que ela e assim:
##
##   MundoIso
##   ├── Chao          TileMapLayer, y_sort DESLIGADO
##   ├── Entidades     Node2D, y_sort LIGADO
##   │   ├── Penhascos/Arvores/Pedras/Decoracao/Casas   Node2D, y_sort LIGADO
##   │   └── (o Jogador entra aqui, posto pela cena)
##   ├── LimitesDoMapa StaticBody2D
##   ├── PontosDeEncontro
##   └── Regioes       (Area2D por regiao do mundo: vila, ribeira, ...)
##
## O chao NUNCA entra no y-sort. Ligar y_sort_enabled numa TileMapLayer joga os
## tiles na mesma lista de ordenacao dos irmaos: basta um tile com
## y_sort_origin != 0 para o chao passar A FRENTE do jogador, e a camada ainda
## precisa se quebrar em varios canvas items por faixa de Y (custo que cresce
## com o tamanho do mapa). Chao plano atras, entidades ordenadas na frente.
##
## Os containers de categoria TAMBEM tem y_sort_enabled — e isso e o que permite
## agrupar sem quebrar a profundidade. Em Godot 4, um filho y-sorted tem os seus
## filhos ACHATADOS na lista do pai: uma arvore dentro de `Arvores` disputa a
## ordenacao diretamente com uma casa dentro de `Casas` e com o jogador. Se um
## container ficasse SEM y-sort, ele viraria um bloco indivisivel ordenado pela
## propria position.y (zero), e todas as arvores passariam atras de tudo.

const CAMINHO_MAPA := "res://autoral/mapas/mundo.json"
const CAMINHO_ATLAS := "res://arte/mundo/atlas_terreno.json"
const CAMINHO_PROPS := "res://arte/mundo/props.json"
const DIR_PROPS := "res://arte/mundo/props/"

## Bits da mascara de transicao. Precisam bater com gerar_mundo_tiles.py: o bit
## acende na aresta em que o terreno da celula ACABA.
const BORDA_NO := 1     # vizinho (x-1, y)
const BORDA_NE := 2     # vizinho (x, y-1)
const BORDA_SE := 4     # vizinho (x+1, y)
const BORDA_SO := 8     # vizinho (x, y+1)
const VIZINHOS := [Vector2i(-1, 0), Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1)]

## Semente do hash que escolhe a variante de grama. Igual a de
## preview_mundo.variante_grama(), para que a previa em Python e o jogo desenhem
## exatamente o mesmo chao.
const SEMENTE_GRAMA := 907

## Espessura das paredes retas que fecham o mapa, em pixels.
const ESPESSURA_LIMITE := 96.0

## Categorias de prop, na ordem em que os containers sao criados. A ordem so
## importa para empate exato de Y — a profundidade real vem do y-sort.
const CATEGORIAS := ["Penhascos", "Arvores", "Pedras", "Decoracao", "Casas"]

## Nome do grupo em cada categoria: "penhascos", "arvores", ... Consultavel de
## qualquer lugar com get_tree().get_nodes_in_group("arvores").
const GRUPO_DE_CATEGORIA := {
	"Penhascos": "penhascos", "Arvores": "arvores", "Pedras": "pedras",
	"Decoracao": "decoracao", "Casas": "casas",
}

var celula: Vector2i = Vector2i(32, 16)
var largura: int = 0            # em celulas, no eixo x da grade
var profundidade: int = 0       # em celulas, no eixo y da grade

var chao: TileMapLayer
var entidades: Node2D
var pontos_de_encontro: Node2D
var regioes: Node2D
var limites: StaticBody2D

var erro: String = ""
var carregado: bool = false

## Qual mapa e este ("mundo", "fabrica"...): o id do JSON, ou o nome do arquivo.
var id_mapa: String = ""
## Mundo aberto (mapa geral, pesca, encontros) ou interior.
var mundo_aberto: bool = true

var _mapa: Dictionary = {}
var _atlas: Dictionary = {}
var _props: Dictionary = {}
var _terreno: PackedStringArray = PackedStringArray()
var _legenda: Dictionary = {}
var _containers: Dictionary = {}
var _fonte_terreno: int = -1


## Losango de uma celula, em pixels relativos ao CENTRO dela — que e o
## referencial que TileData.set_collision_polygon_points espera.
##
## Nao pode ser `const`: em GDScript 4.7 um PackedVector2Array com chamadas a
## Vector2() nao e expressao constante.
static func losango_da_celula(tam: Vector2i) -> PackedVector2Array:
	var mx := tam.x * 0.5
	var my := tam.y * 0.5
	return PackedVector2Array([
		Vector2(0.0, -my), Vector2(mx, 0.0), Vector2(0.0, my), Vector2(-mx, 0.0)
	])


## Rede de seguranca para quem largar um MundoIso numa cena e esperar que ele se
## monte sozinho. Quem controla a ordem deve chamar carregar() explicitamente:
## _ready NAO e garantidamente sincrono com add_child em todo contexto — num
## script `extends SceneTree`, por exemplo, ele so roda no primeiro frame, e um
## chamador que conferisse `erro` logo apos o add_child leria um mundo vazio sem
## nenhum erro registrado.
## Mapa que o _ready carrega. Quem quer outro (um interior) define ANTES de por o
## no na arvore: o _ready carrega sozinho, e um carregar() depois seria ignorado
## (e idempotente) e deixaria o mundo no mapa padrao.
var caminho: String = CAMINHO_MAPA


func _ready() -> void:
	if not carregado and not carregar(caminho):
		push_error("MundoIso: " + erro)


## Monta o mundo inteiro. Idempotente. Devolve false e preenche `erro` em vez de
## deixar uma cena meio construida: um mapa que carrega pela metade e pior de
## diagnosticar que um que nao carrega.
func carregar(caminho_mapa: String = CAMINHO_MAPA) -> bool:
	if carregado:
		return true
	if not _ler_dados(caminho_mapa):
		return false
	_construir_arvore()
	if not _montar_chao():
		return false
	_montar_props()
	_montar_pontos_de_encontro()
	_montar_regioes()
	_montar_limites()
	carregado = true
	return true


# ------------------------------------------------------------------ dados
func _ler_json(caminho: String) -> Variant:
	if not FileAccess.file_exists(caminho):
		erro = "arquivo inexistente — " + caminho
		return null
	var dados: Variant = JSON.parse_string(FileAccess.get_file_as_string(caminho))
	if dados == null:
		erro = "JSON invalido — " + caminho
	return dados


func _ler_dados(caminho_mapa: String) -> bool:
	_mapa = _ler_json(caminho_mapa)
	if _mapa == null:
		return false
	_atlas = _ler_json(CAMINHO_ATLAS)
	if _atlas == null:
		return false
	_props = _ler_json(CAMINHO_PROPS)
	if _props == null:
		return false
	_props = _props.get("props", {})

	id_mapa = String(_mapa.get("id", caminho_mapa.get_file().get_basename()))
	mundo_aberto = bool(_mapa.get("mundo_aberto", true))
	var c: Array = _mapa.get("celula", [32, 16])
	celula = Vector2i(int(c[0]), int(c[1]))
	largura = int(_mapa["dimensoes"]["largura"])
	profundidade = int(_mapa["dimensoes"]["profundidade"])
	_legenda = _mapa["legenda"]
	_terreno = PackedStringArray(_mapa["terreno"])
	if _terreno.size() != profundidade:
		erro = "mapa declara %d linhas de profundidade mas tem %d" % [
			profundidade, _terreno.size()]
		return false
	for i in _terreno.size():
		if _terreno[i].length() != largura:
			erro = "linha %d do terreno tem %d colunas, esperado %d" % [
				i, _terreno[i].length(), largura]
			return false
	return true


# ------------------------------------------------------------------ arvore
func _construir_arvore() -> void:
	chao = TileMapLayer.new()
	chao.name = "Chao"
	chao.y_sort_enabled = false          # ver nota de cabecalho: nunca ligar
	chao.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(chao)

	entidades = Node2D.new()
	entidades.name = "Entidades"
	entidades.y_sort_enabled = true
	add_child(entidades)

	for nome: String in CATEGORIAS:
		var c := Node2D.new()
		c.name = nome
		c.y_sort_enabled = true          # achata na lista de `entidades`
		entidades.add_child(c)
		_containers[nome] = c

	pontos_de_encontro = Node2D.new()
	pontos_de_encontro.name = "PontosDeEncontro"
	add_child(pontos_de_encontro)

	regioes = Node2D.new()
	regioes.name = "Regioes"
	add_child(regioes)

	limites = StaticBody2D.new()
	limites.name = "LimitesDoMapa"
	add_child(limites)


# -------------------------------------------------------------------- chao
func _montar_chao() -> bool:
	var textura: Texture2D = load("res://arte/mundo/" + String(_atlas["arquivo"]))
	if textura == null:
		# load() e nao preload(): os *.import estao no .gitignore, e um preload
		# de PNG ainda nao importado e erro de PARSE — o script inteiro deixaria
		# de carregar, sem chance de reportar nada.
		erro = ("atlas de terreno nao carregou. Num clone novo rode uma vez:\n"
				+ "  godot --headless --path . --import")
		return false

	var conjunto := TileSet.new()
	# As quatro propriedades andam juntas. So tile_shape deixa tile_layout em
	# STACKED, que nao e um mapa em losango — e o erro nao aparece como erro,
	# aparece como um mapa em fatias.
	conjunto.tile_shape = TileSet.TILE_SHAPE_ISOMETRIC
	conjunto.tile_layout = TileSet.TILE_LAYOUT_DIAMOND_DOWN
	conjunto.tile_offset_axis = TileSet.TILE_OFFSET_AXIS_HORIZONTAL
	conjunto.tile_size = celula
	conjunto.add_physics_layer(-1)
	conjunto.set_physics_layer_collision_layer(0, 1)

	var fonte := TileSetAtlasSource.new()
	fonte.texture = textura
	fonte.texture_region_size = celula
	# A fonte precisa estar DENTRO do TileSet antes de qualquer create_tile: um
	# TileData so enxerga as camadas de fisica do conjunto a que pertence, e
	# criar os tiles com a fonte solta faz add_collision_polygon(0) falhar com
	# "physics.size() = 0" — uma vez por tile, sem impedir a cena de subir.
	_fonte_terreno = conjunto.add_source(fonte, -1)
	chao.tile_set = conjunto

	var bloqueia: Array = _mapa.get("bloqueia", [])
	var terrenos_bloqueados := {}
	for ch: String in bloqueia:
		terrenos_bloqueados[_nome_do_terreno(ch)] = true

	var com_mascara: Array = _atlas["com_mascara"]
	var linhas: Dictionary = _atlas["linhas"]
	for nome: String in linhas.keys():
		var linha: int = int(linhas[nome])
		var colunas: int = 16 if nome in com_mascara else _atlas["pesos_grama"].size()
		for col in colunas:
			var coord := Vector2i(col, linha)
			fonte.create_tile(coord)
			if terrenos_bloqueados.has(nome):
				var td := fonte.get_tile_data(coord, 0)
				td.add_collision_polygon(0)
				td.set_collision_polygon_points(0, 0, losango_da_celula(celula))
	for gy in profundidade:
		for gx in largura:
			chao.set_cell(Vector2i(gx, gy), _fonte_terreno,
					_coord_no_atlas(gx, gy), 0)
	return true


## Coluna e linha do tile desta celula no atlas. Espelho exato de
## preview_mundo.tile_de() — as duas leem o mesmo atlas_terreno.json.
func _coord_no_atlas(gx: int, gy: int) -> Vector2i:
	var nome := _nome_do_terreno(_terreno[gy][gx])
	var linha: int = int(_atlas["linhas"].get(nome, 0))
	if not nome in _atlas["com_mascara"]:
		return Vector2i(_variante_de_grama(gx, gy), linha)
	return Vector2i(_mascara_de_bordas(gx, gy, nome), linha)


func _nome_do_terreno(ch: String) -> String:
	return String(_legenda.get(ch, "grama"))


## Bits das arestas em que o terreno desta celula acaba.
##
## Fora do mapa conta como "acaba": sem isso a fileira externa terminaria num
## corte reto no vazio, que e exatamente a aparencia de mosaico que a mascara
## existe para evitar.
func _mascara_de_bordas(gx: int, gy: int, nome: String) -> int:
	var grupo: Array = _atlas["grupos_de_transicao"].get(nome, [])
	if grupo.is_empty():
		return 0
	var mascara := 0
	for i in VIZINHOS.size():
		var v: Vector2i = VIZINHOS[i] + Vector2i(gx, gy)
		var fora := v.x < 0 or v.y < 0 or v.x >= largura or v.y >= profundidade
		if fora or not _nome_do_terreno(_terreno[v.y][v.x]) in grupo:
			mascara |= 1 << i
	return mascara


## Variante de grama escolhida por hash da celula. Deterministico e sem estado:
## a mesma celula devolve sempre a mesma variante, e a previa em Python calcula
## o mesmo indice com a mesma funcao.
func _variante_de_grama(gx: int, gy: int) -> int:
	var pesos: Array = _atlas["pesos_grama"]
	var r := _ruido(gx, gy, SEMENTE_GRAMA)
	var acumulado := 0.0
	for i in pesos.size():
		acumulado += float(pesos[i])
		if r < acumulado:
			return i
	return pesos.size() - 1


## Hash inteiro de (x, y) em [0,1). Reimplementacao exata de mundo_lib.ruido():
## as duas precisam devolver o mesmo numero, ou a previa deixa de valer como
## conferencia do que o jogo desenha.
static func _ruido(x: int, y: int, semente: int) -> float:
	var h: int = (x * 374761393 + y * 668265263 + semente * 2147483647) & 0xFFFFFFFF
	h = ((h ^ (h >> 13)) * 1274126177) & 0xFFFFFFFF
	return float((h ^ (h >> 16)) & 0xFFFF) / 65536.0


# ------------------------------------------------------------------- props
func _montar_props() -> void:
	for categoria: String in CATEGORIAS:
		for item: Dictionary in _mapa.get(categoria.to_lower(), []):
			adicionar_prop(categoria, item)


## O mapa como foi lido do JSON e o catalogo de props. So leitura: e o contexto que a
## Camada 3 recebe para decidir onde cabe cada coisa.
func dados_do_mapa() -> Dictionary:
	return _mapa


func catalogo_de_props() -> Dictionary:
	return _props


## Instancia um prop numa categoria. Publica de proposito: e por aqui que a
## Camada 3 (ambientacao procedural) vai pendurar a vegetacao sorteada pela
## seed, sem precisar tocar no mapa autoral nem no formato do JSON.
func adicionar_prop(categoria: String, item: Dictionary) -> Node2D:
	var nome_prop := String(item["prop"])
	var meta: Dictionary = _props.get(nome_prop, {})
	if meta.is_empty():
		push_error("MundoIso: prop desconhecido em props.json — " + nome_prop)
		return null
	var textura: Texture2D = load(DIR_PROPS + String(meta["arquivo"]))
	if textura == null:
		push_error("MundoIso: arte ausente — " + DIR_PROPS + String(meta["arquivo"]))
		return null

	var cels: Array = meta["celulas"]
	var c: Array = item["celula"]
	var no := Node2D.new()
	no.name = "%s_%d_%d" % [nome_prop, int(c[0]), int(c[1])]
	no.position = celula_para_mundo(Vector2i(int(c[0]), int(c[1])),
			int(cels[0]), int(cels[1]))
	no.add_child(_sprite_ancorado(textura, meta))

	var colisao: Dictionary = meta.get("colisao", {})
	if String(colisao.get("tipo", "nenhuma")) == "poligono":
		var corpo := StaticBody2D.new()
		corpo.name = "Colisao"
		var poli := CollisionPolygon2D.new()
		var pontos := PackedVector2Array()
		for ponto: Array in colisao["pontos"]:
			pontos.append(Vector2(float(ponto[0]), float(ponto[1])))
		poli.polygon = pontos
		corpo.add_child(poli)
		no.add_child(corpo)

	# Metadados do dado do mapa viajam com o no. Nada os le hoje; existem para
	# que a etapa de NPCs/lojas/missoes encontre a casa certa sem reabrir o JSON.
	for chave: String in item.keys():
		if chave != "prop" and chave != "celula":
			no.set_meta(chave, item[chave])
	no.set_meta("prop", nome_prop)
	no.set_meta("celula", Vector2i(int(c[0]), int(c[1])))

	var container: Node2D = _containers[categoria]
	container.add_child(no)
	no.add_to_group(GRUPO_DE_CATEGORIA[categoria])
	return no


## Sprite de um prop do catalogo, com a ancora na origem, sem no, colisao nem lugar
## no mapa. E como a cutscene da chegada poe o onibus no mundo: mesma arte e mesma
## convencao de ancora dos props fixos. null se o prop nao existe.
func sprite_de_prop(nome_prop: String) -> Sprite2D:
	var meta: Dictionary = _props.get(nome_prop, {})
	if meta.is_empty():
		return null
	var textura: Texture2D = load(DIR_PROPS + String(meta["arquivo"]))
	return _sprite_ancorado(textura, meta) if textura != null else null


func _sprite_ancorado(textura: Texture2D, meta: Dictionary) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = textura
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	# centered = false + offset: a chave do y-sort e a position do NO, nunca o
	# desenho. Com centered = true a chave viraria a cintura do sprite, e uma
	# arvore alta passaria atras de uma pedra baixa que esta mais ao fundo.
	sprite.centered = false
	var ancora: Array = meta["ancora"]
	sprite.offset = Vector2(-int(ancora[0]), -int(ancora[1]))
	return sprite


# ------------------------------------------------------- pontos de encontro
func _montar_pontos_de_encontro() -> void:
	for dados: Dictionary in _mapa.get("pontos_encontro", []):
		var ponto := PontoDeEncontro.criar(dados, celula)
		ponto.position = celula_para_mundo(Vector2i(
				int(dados["celula"][0]), int(dados["celula"][1])))
		pontos_de_encontro.add_child(ponto)


# ----------------------------------------------------------------- regioes
## Uma Area2D por regiao declarada no mapa. Sao elas que dizem "voce chegou na
## Ribeira" e que marcam a regiao como descoberta no mapa geral (M).
##
## O mapa e UM SO — as regioes nao sao cenas separadas. Isso e o requisito de
## mundo continuo: atravessar de uma a outra e andar, sem carregamento. A regiao
## existe como DADO (um retangulo com nome), nao como fronteira de carregamento.
func _montar_regioes() -> void:
	for dados: Dictionary in _mapa.get("regioes", []):
		var r := RegiaoMundo.criar(dados)
		r.montar(self)
		regioes.add_child(r)


## Dados crus das regioes, na ordem do mapa. Quem consome e a tela de mapa geral,
## que precisa do retangulo e do rotulo sem instanciar nada.
func dados_das_regioes() -> Array:
	return _mapa.get("regioes", [])


## A grade de terreno, uma String por linha. E a fonte do mapa geral: ele
## rasteriza uma imagem de 1 pixel por celula a partir daqui, em vez de carregar
## uma ilustracao — assim uma regiao nova aparece no mapa sem arte nova.
func linhas_de_terreno() -> PackedStringArray:
	return _terreno


## Caractere -> nome do terreno (o mesmo dicionario do JSON).
func legenda_do_terreno() -> Dictionary:
	return _legenda


# ------------------------------------------------------------------ limites
func _montar_limites() -> void:
	# Paredes RETAS ao longo das quatro arestas do losango do mapa.
	#
	# A colisao dos tiles ja para o jogador na rocha da borda, mas a fronteira de
	# um bloco de losangos e uma serra de faces a 26,57 graus: empurrado contra
	# ela, o corpo escorrega ao longo da serra em vez de parar. Isso e o desejado
	# no lago (contornar a margem), mas nao serve como limite do mundo. Estas
	# quatro paredes sao o limite duro — se o jogador chegar nelas, para.
	var quinas := quinas_do_mapa()
	for i in quinas.size():
		var a: Vector2 = quinas[i]
		var b: Vector2 = quinas[(i + 1) % quinas.size()]
		var fora := (b - a).orthogonal().normalized() * ESPESSURA_LIMITE
		# orthogonal() gira 90 graus; com as quinas em sentido horario, o
		# resultado aponta para FORA do mapa.
		var poli := CollisionPolygon2D.new()
		poli.polygon = PackedVector2Array([a, b, b + fora, a + fora])
		limites.add_child(poli)


## As quatro quinas do losango do mapa, em pixels locais, em sentido horario a
## partir do norte. Derivadas da geometria de TileMapLayer.map_to_local com
## layout DIAMOND_DOWN: centro(gx,gy) = ((gx-gy+1)*mx, (gx+gy+1)*my).
func quinas_do_mapa() -> PackedVector2Array:
	var mx := celula.x * 0.5
	var my := celula.y * 0.5
	return PackedVector2Array([
		Vector2(mx, 0.0),                                        # norte
		Vector2((largura + 1) * mx, largura * my),               # leste
		Vector2((largura - profundidade) * mx, (largura + profundidade) * my),  # sul
		Vector2((1 - profundidade) * mx, profundidade * my),     # oeste
	])


# ----------------------------------------------------------------- consulta
## Centro, em pixels do mundo, da pegada de largura x fundo celulas ancorada nesta celula.
## Para um prop de uma celula (o padrao) e o centro do losango dela.
func celula_para_mundo(c: Vector2i, largura: int = 1, fundo: int = 1) -> Vector2:
	var base := chao.map_to_local(c) if chao != null else Vector2(
			(c.x - c.y + 1) * celula.x * 0.5, (c.x + c.y + 1) * celula.y * 0.5)
	return base + Vector2((largura - fundo) * celula.x * 0.25,
			(largura + fundo) * celula.y * 0.25 - celula.y * 0.5)


## Ponto da grade em coordenadas FRACIONARIAS -> pixels do mundo. (gx + 0.5, gy +
## 0.5) e o centro da celula (gx, gy), o mesmo de celula_para_mundo. Para o que se
## move entre celulas: o onibus anda no eixo da estrada, nao de centro em centro.
func grade_para_mundo(p: Vector2) -> Vector2:
	var origem := celula_para_mundo(Vector2i.ZERO)
	var d := p - Vector2(0.5, 0.5)
	return origem + Vector2((d.x - d.y) * celula.x * 0.5, (d.x + d.y) * celula.y * 0.5)


## Coreografia da chegada de onibus, gravada pelo gerador do mapa ({} se este mapa
## nao tem): boca do tunel, parada, desembarque e caminho da Mirela.
func chegada() -> Dictionary:
	return _mapa.get("chegada", {})


func mundo_para_celula(pos: Vector2) -> Vector2i:
	return chao.local_to_map(pos)


## A porta nesta celula, ou {} — {celula, destino, chegada, direcao, requer?, aviso?}.
## Portas ligam este mapa a outro (um interior e o mundo); quem atravessa e a cena.
func porta_em(c: Vector2i) -> Dictionary:
	for p: Dictionary in _mapa.get("portas", []):
		var pc: Array = p.get("celula", [])
		if pc.size() >= 2 and Vector2i(int(pc[0]), int(pc[1])) == c:
			return p
	return {}


func portas() -> Array:
	return _mapa.get("portas", [])


func spawn_do_jogador() -> Vector2:
	var s: Array = _mapa.get("spawn_jogador", [0, 0])
	return celula_para_mundo(Vector2i(int(s[0]), int(s[1])))


## Retangulo que a Camera2D deve usar como limite. O mapa isometrico e um
## losango deitado que invade x NEGATIVO — nao e (0, 0, L*tw, A*th).
func limites_da_camera() -> Rect2:
	var mx := celula.x * 0.5
	var my := celula.y * 0.5
	var esquerda := (1 - profundidade) * mx
	var direita := (largura + 1) * mx
	return Rect2(esquerda, 0.0, direita - esquerda, (largura + profundidade) * my)


func terreno_em(c: Vector2i) -> String:
	if c.x < 0 or c.y < 0 or c.x >= largura or c.y >= profundidade:
		return ""
	return _nome_do_terreno(_terreno[c.y][c.x])


## Se a celula bloqueia a passagem pelo TERRENO. Nao considera props — quem
## responde por eles e a fisica. Util para ferramentas e testes.
func bloqueia(c: Vector2i) -> bool:
	return _nome_do_terreno_bloqueado(terreno_em(c))


func _nome_do_terreno_bloqueado(nome: String) -> bool:
	for ch: String in _mapa.get("bloqueia", []):
		if _nome_do_terreno(ch) == nome:
			return true
	return nome == ""
