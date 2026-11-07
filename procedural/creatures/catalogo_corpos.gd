class_name CatalogoCorpos
extends RefCounted

## Indice da arte de criaturas: liga os atributos ja sorteados as mascaras de
## pixel art em res://arte/. E a ponte entre a Camada 2 (geracao) e a Camada 4
## (apresentacao) — nao sorteia nada, so resolve "quais atributos -> qual PNG e
## em que ponto ele encosta".
##
## As mascaras sao INDEXADAS: o canal R codifica o indice de paleta
## (1 contorno, 2 sombra, 3 base, 4 brilho) e a cor concreta so entra no shader
## paleta_indexada.gdshader, alimentado pela cor derivada de (matiz, paleta).
## Assim o mesmo PNG serve as 8 familias elementais sem 8 copias do asset — o
## custo de memoria fica em O(silhuetas), nao em O(silhuetas x paletas), que e o
## que sustenta a escala do bestiario dentro da meta de desempenho.
##
## Fonte: arte/corpos/corpos_ancoras.json, gerado por tools/arte/gerar_corpos.py.
## O JSON e o dado; o script Python e a calibracao. Nunca editar o JSON a mao.

const CAMINHO_ANCORAS := "res://arte/corpos/corpos_ancoras.json"
const DIR_CORPOS := "res://arte/corpos/"

## Asas, nadadeiras e escamas: arte e encaixe declarados por
## tools/arte/gerar_apendices.py. Cada peca tem um PIVO (o pixel dela que fica sobre
## a ancora do corpo) e uma ORDEM de desenho, de tras para frente.
const CAMINHO_APENDICES := "res://arte/apendices/apendices.json"
const DIR_APENDICES := "res://arte/apendices/"

## Ordem de desenho das garras entre os demais tracos: depois das escamas e das
## nadadeiras, antes das asas.
const ORDEM_GARRAS := 20

## Onde mora a arte das GARRAS e como seus arquivos se chamam:
## <dir>/<prefixo>_<indice+1>_<nome_do_modelo>.png. Os demais tracos vem de
## CAMINHO_APENDICES.
const ARTE_DE_FEATURE := {
	"garras": {"dir": "res://arte/garras/", "prefixo": "garra"},
}

## Ancoras em que cada feature se apoia, na ordem de desenho. As garras nascem nas
## duas extremidades das patas — e, nos corpos sem patas, na borda ventral.
##
## TODO corpo declara esses pontos, de proposito: nao ha veto anatomico aqui. Se o
## gerador concedeu garras a um peixe (P(garras|peixe) fica entre 2% e 12%), elas
## precisam aparecer, sob pena de a ficha da criatura contradizer o quadro. O lugar
## de suprimir um apendice improvavel e a tabela condicional, que e calibravel e
## entra nas metricas — nao um silencio na camada de apresentacao.
const SLOTS_DE_FEATURE := {
	"garras": ["pe_tras", "pe_frente"],
}

## Lado do quadro da mascara de corpo, em pixels de arte (nao de tela).
var canvas: Vector2 = Vector2(32, 32)

## Escala das mascaras de apendice em relacao ao pixel do corpo. A garra e
## autorada em 16x16 para ter detalhe, mas ocupa ~8px no corpo.
var escala_apendice: float = 0.5

var _sprites: Dictionary = {}          # body_id -> metadados do JSON
var _texturas_feature: Dictionary = {} # feature -> Array[String] de caminhos
var _apendices: Dictionary = {}        # o manifesto de arte/apendices/

var erro: String = ""


## Fabrica. Precisa das tabelas para saber o NOME de cada variante — e o nome que
## identifica o arquivo de arte (garra_04_adaga.png <- modelo 3 de "garras"),
## mantendo dado e asset com a mesma fonte de verdade.
static func carregar(tabelas: TabelasProbabilidade,
		caminho: String = CAMINHO_ANCORAS) -> CatalogoCorpos:
	var cat := CatalogoCorpos.new()
	if not cat._carregar(tabelas, caminho):
		push_error("CatalogoCorpos: " + cat.erro)
		return null
	return cat


func _carregar(tabelas: TabelasProbabilidade, caminho: String) -> bool:
	if not FileAccess.file_exists(caminho):
		erro = "arquivo de ancoras inexistente — " + caminho
		return false
	var dados: Variant = JSON.parse_string(FileAccess.get_file_as_string(caminho))
	if dados == null or not dados.has("sprites"):
		erro = "ancoras invalidas — " + caminho
		return false

	var c: Array = dados.get("canvas", [32, 32])
	canvas = Vector2(c[0], c[1])
	escala_apendice = float(dados.get("escala_garra_sugerida", 0.5))
	_sprites = dados["sprites"]

	if tabelas != null:
		for feature in ARTE_DE_FEATURE:
			var arte: Dictionary = ARTE_DE_FEATURE[feature]
			var caminhos: Array = []
			for i in tabelas.num_modelos(feature):
				caminhos.append(arte["dir"] + ("%s_%02d_%s.png" % [
					arte["prefixo"], i + 1, tabelas.nome_modelo(feature, i)
				]))
			_texturas_feature[feature] = caminhos
	if FileAccess.file_exists(CAMINHO_APENDICES):
		var ap: Variant = JSON.parse_string(FileAccess.get_file_as_string(CAMINHO_APENDICES))
		if ap is Dictionary:
			_apendices = ap
	return true


## Identificador do corpo a partir dos atributos. Casa com o nome do arquivo:
## body_id "gato_1_compacto" -> arte/corpos/corpo_gato_1_compacto.png.
static func montar_body_id(animal: String, indice_porte: int, porte: String) -> String:
	return "%s_%d_%s" % [animal, indice_porte + 1, porte]


func existe(body_id: String) -> bool:
	return _sprites.has(body_id)


func meta(body_id: String) -> Dictionary:
	return _sprites.get(body_id, {})


func arquetipo(body_id: String) -> String:
	return meta(body_id).get("arquetipo", "")


func caminho_corpo(body_id: String) -> String:
	return DIR_CORPOS + "corpo_%s.png" % body_id


func textura_corpo(body_id: String) -> Texture2D:
	if not existe(body_id):
		return null
	return load(caminho_corpo(body_id))


## Textura do modelo escolhido de uma feature, ou null se a feature ainda nao tem
## arte. Retornar null (e nao um placeholder) e proposital: a apresentacao pula o
## apendice em vez de desenhar algo que nao corresponde ao dado.
func textura_feature(feature: String, indice_modelo: int) -> Texture2D:
	var caminhos: Array = _texturas_feature.get(feature, [])
	if indice_modelo < 0 or indice_modelo >= caminhos.size():
		return null
	return load(caminhos[indice_modelo])


func tem_arte(feature: String) -> bool:
	return ARTE_DE_FEATURE.has(feature) or _apendices.has(feature)


## Tudo o que se desenha por cima do corpo desta criatura, em pixels de arte e na
## ordem de desenho (de tras para frente): escamas, nadadeiras, garras, asas.
## [{tex, rect}]. So entra o traco que o gerador sorteou: o quadro nunca mostra o
## que a ficha nao tem, nem esconde o que ela tem.
func quadros_de_tracos(c: Criatura) -> Array:
	var itens: Array = []
	for feature: String in c.morfologia:
		if not c.morfologia[feature]:
			continue
		var modelo: int = int(c.variantes.get(feature, 0))
		if feature == "garras":
			var tex := textura_feature(feature, modelo)
			if tex == null:
				continue
			var tam: Vector2 = tex.get_size() * escala_apendice
			for ancora in ancoras_de_feature(c.body_id, feature):
				# A ancora e a PONTA da garra: centro horizontal, base vertical. O 1px
				# de sobreposicao evita a fresta de quando ela apenas encosta.
				itens.append({"ordem": ORDEM_GARRAS, "tex": tex,
						"rect": Rect2(ancora - Vector2(tam.x * 0.5, tam.y - 1.0), tam)})
			continue
		var regra: Dictionary = _apendices.get(feature, {})
		if regra.is_empty():
			continue
		var ordem: int = int(regra.get("ordem", 10))
		if regra.has("sobreposicao"):
			var modelos: Array = regra.get("modelos", [])
			if modelo >= modelos.size():
				continue
			var caminho := DIR_APENDICES + String(regra["sobreposicao"]).format({
				"corpo": c.body_id, "n": "%02d" % (modelo + 1), "nome": modelos[modelo]})
			var sob: Texture2D = load(caminho) if ResourceLoader.exists(caminho) else null
			if sob != null:
				itens.append({"ordem": ordem, "tex": sob,
						"rect": Rect2(Vector2.ZERO, sob.get_size())})
			continue
		var escala: float = float(_apendices.get("escala", 1.0))
		for p: Dictionary in regra.get("pecas", []):
			var ancora: Variant = meta(c.body_id).get(String(p.get("slot", "")))
			var arquivos: Array = p.get("arquivos", [])
			if ancora == null or modelo >= arquivos.size():
				continue
			var tex: Texture2D = load(DIR_APENDICES + String(arquivos[modelo]))
			if tex == null:
				continue
			var pivo: Array = p["pivos"][modelo]
			var origem := Vector2(ancora[0], ancora[1]) - Vector2(pivo[0], pivo[1]) * escala
			itens.append({"ordem": ordem, "tex": tex,
					"rect": Rect2(origem, tex.get_size() * escala)})
	itens.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a["ordem"]) < int(b["ordem"]))
	return itens


## Pontos, em pixels de arte, onde a feature se apoia neste corpo. Vazio so quando o
## corpo nao declara nenhum dos slots daquela feature — ver SLOTS_DE_FEATURE.
func ancoras_de_feature(body_id: String, feature: String) -> Array:
	var m: Dictionary = meta(body_id)
	var pontos: Array = []
	for slot in SLOTS_DE_FEATURE.get(feature, []):
		var p: Variant = m.get(slot)
		if p != null:
			pontos.append(Vector2(p[0], p[1]))
	return pontos


## Confere que existe uma mascara para toda combinacao animal x porte do
## vocabulario. Falha aqui e falha de asset, nao de sorteio — e o gerador nao
## deve descobrir isso no meio de um bestiario.
func validar(tabelas: TabelasProbabilidade) -> PackedStringArray:
	var faltando := PackedStringArray()
	for animal in tabelas.animais():
		for i in tabelas.portes().size():
			var id := montar_body_id(animal, i, tabelas.portes()[i])
			if not existe(id):
				faltando.append(id)
			elif not ResourceLoader.exists(caminho_corpo(id)):
				faltando.append(id + " (mascara ausente)")
	return faltando
