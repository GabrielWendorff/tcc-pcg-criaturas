class_name CatalogoItens
extends RefCounted

## Todos os itens do jogo numa lista so, organizados por categoria.
##
## DUAS FONTES, UM NAMESPACE
## -------------------------
##   data/captura/dispositivos.json  ──TabelasCaptura──┐
##   data/captura/iscas.json         ──TabelasCaptura──┼──▶ ItemJogo ──▶ Bolsa
##   data/itens/catalogo.json        ──────────────────┘
##
## Os itens de captura NAO sao redeclarados aqui: sao envelopados a partir das
## classes que o encontro ja usa (ver ItemJogo.de_captura). Dois arquivos
## descrevendo o mesmo dispositivo divergiriam na primeira calibragem, e o bug
## seria silencioso — a roda de captura usaria um numero e a bolsa mostraria
## outro.
##
## UM ESPACO DE NOMES SO. InventarioJogador ja guardava dispositivos e iscas na
## mesma tabela de quantidades (o comentario no topo daquele arquivo previa
## exatamente isto: "quando houver loja, chave, cura e material, o formato ja e
## o mesmo"). O catalogo e o que faltava para que os outros itens pudessem
## entrar nela — e `validar()` recusa id repetido, que e a unica coisa que esse
## arranjo nao perdoa.

const CAMINHO := "res://data/itens/catalogo.json"

## Prefixo que liga uma categoria do catalogo a uma lista de TabelasCaptura, em
## vez de a uma lista de itens declarada no proprio JSON.
const FONTE_CAPTURA := "captura:"

## Categorias na ordem em que aparecem nas abas da bolsa.
var categorias: Array = []

var itens: Array[ItemJogo] = []

var _por_id: Dictionary = {}
var _por_categoria: Dictionary = {}
var _ok: bool = false
var erro: String = ""


## Fabrica: catalogo pronto, ou null com push_error. `captura` pode ser null —
## nesse caso so os itens de data/itens/ entram, o que e util para um teste de
## formato que nao queira carregar as tabelas de balanceamento.
static func carregar(captura: TabelasCaptura = null) -> CatalogoItens:
	var c := CatalogoItens.new()
	c._carregar_tudo(captura)
	if not c._ok:
		push_error("CatalogoItens: falha ao carregar — " + c.erro)
		return null
	return c


func valido() -> bool:
	return _ok


func _carregar_tudo(captura: TabelasCaptura) -> void:
	if not FileAccess.file_exists(CAMINHO):
		erro = "arquivo inexistente: " + CAMINHO
		return
	var dados: Variant = JSON.parse_string(FileAccess.get_file_as_string(CAMINHO))
	if not (dados is Dictionary):
		erro = "JSON invalido em: " + CAMINHO
		return

	categorias = dados.get("categorias", [])
	if categorias.is_empty():
		erro = "nenhuma categoria declarada"
		return
	var declarados: Dictionary = dados.get("itens", {})

	for cat: Dictionary in categorias:
		var id_cat := String(cat.get("id", ""))
		_por_categoria[id_cat] = []
		var fonte := String(cat.get("fonte", ""))
		if fonte.begins_with(FONTE_CAPTURA):
			_absorver_captura(captura, fonte.substr(FONTE_CAPTURA.length()), id_cat)
		else:
			for d: Dictionary in declarados.get(id_cat, []):
				_registrar(ItemJogo.de_dicionario(d, id_cat))

	if itens.is_empty():
		erro = "nenhum item carregado"
		return
	_ok = true


func _absorver_captura(captura: TabelasCaptura, lista: String, id_cat: String) -> void:
	if captura == null:
		return  # categoria fica vazia; a aba some sozinha
	# if/else e nao ternario: os dois ramos sao Array[DispositivoCaptura] e
	# Array[IscaCaptura], tipos diferentes, e um ternario entre eles depende de
	# o parser achar o ancestral comum.
	var fonte: Array = []
	if lista == "dispositivos":
		fonte = captura.dispositivos
	else:
		fonte = captura.iscas
	for item: ItemCaptura in fonte:
		_registrar(ItemJogo.de_captura(item, id_cat))


func _registrar(item: ItemJogo) -> void:
	if _por_id.has(item.id):
		# Nao aborta: o item duplicado e ignorado e validar() reporta. Um id
		# repetido e erro de dado que o teste tem de nomear, nao um jogo que
		# nao abre.
		push_warning("CatalogoItens: id repetido, ignorado — " + item.id)
		return
	itens.append(item)
	_por_id[item.id] = item
	(_por_categoria[item.categoria] as Array).append(item)


# -------------------------------------------------------------------- acesso

func item(id: String) -> ItemJogo:
	return _por_id.get(id)


func tem(id: String) -> bool:
	return _por_id.has(id)


func da_categoria(id_cat: String) -> Array:
	return _por_categoria.get(id_cat, [])


func rotulo_da_categoria(id_cat: String) -> String:
	for cat: Dictionary in categorias:
		if String(cat.get("id", "")) == id_cat:
			return String(cat.get("rotulo", id_cat.to_upper()))
	return id_cat.to_upper()


## Itens que carregam um marcador — "quais varas o jogador pode usar para
## pescar?" sem a pesca precisar conhecer categoria nenhuma.
func com_marcador(m: String) -> Array:
	var saida: Array = []
	for i: ItemJogo in itens:
		if i.tem_marcador(m):
			saida.append(i)
	return saida


## Carga inicial declarada pelos dois arquivos de origem: id -> quantidade.
func quantidades_iniciais() -> Dictionary:
	var d: Dictionary = {}
	for i: ItemJogo in itens:
		if i.quantidade_inicial > 0:
			d[i.id] = i.quantidade_inicial
	return d


## Problemas de DADO, para o teste nomear. Icone faltando e o caso mais provavel:
## acrescentar um item ao JSON sem desenha-lo em tools/arte/gerar_itens.py nao da
## erro na engine — da um buraco na bolsa, descoberto na tela.
func validar(indice_de_icones: Dictionary) -> PackedStringArray:
	var problemas := PackedStringArray()
	var vistos: Dictionary = {}
	for i: ItemJogo in itens:
		if i.id == "":
			problemas.append("item sem id na categoria '%s'" % i.categoria)
		if vistos.has(i.id):
			problemas.append("id repetido: " + i.id)
		vistos[i.id] = true
		if not indice_de_icones.is_empty() and not indice_de_icones.has(i.id):
			problemas.append("sem icone em arte/itens/itens.json: " + i.id)
		if not i.empilhavel and i.max_pilha != 99 and i.max_pilha > 1:
			problemas.append("'%s' nao e empilhavel mas declara max_pilha %d"
					% [i.id, i.max_pilha])
	for cat: Dictionary in categorias:
		if not _por_categoria.has(String(cat.get("id", ""))):
			problemas.append("categoria sem lista: " + String(cat.get("id", "")))
	return problemas
