class_name TabelasProbabilidade
extends RefCounted

## Carrega e expoe as tabelas de probabilidade condicionada de res://data/.
## Mantem a logica de geracao ignorante quanto ao formato de armazenamento
## (JSON hoje; poderia ser .tres amanha) e permite recarga a quente na calibragem.

const DATA_DIR := "res://data/"

var vocabulary: Dictionary = {}
var priors: Dictionary = {}
var palette: Dictionary = {}      # P(paleta | elemento)
var hue: Dictionary = {}          # P(matiz  | elemento)
var morphology: Dictionary = {}   # base_por_animal + modificador_por_elemento
var variants: Dictionary = {}     # modelos de cada feature + vies por elemento

var _ok: bool = false
var erro: String = ""


## Fabrica: retorna as tabelas carregadas, ou null em caso de erro (com push_error).
static func carregar() -> TabelasProbabilidade:
	var t := TabelasProbabilidade.new()
	t._carregar_tudo()
	if not t._ok:
		push_error("TabelasProbabilidade: falha ao carregar — " + t.erro)
		return null
	return t


func valido() -> bool:
	return _ok


func _carregar_tudo() -> void:
	var voc: Variant = _ler_json("vocabulary.json")
	var pri: Variant = _ler_json("primary_priors.json")
	var pal: Variant = _ler_json("conditional_palette.json")
	var hu: Variant = _ler_json("conditional_hue.json")
	var mor: Variant = _ler_json("conditional_morphology.json")
	var var_: Variant = _ler_json("feature_variants.json")
	if voc == null or pri == null or pal == null or hu == null or mor == null or var_ == null:
		return
	vocabulary = voc
	priors = pri
	palette = pal["tabela"]
	hue = hu["tabela"]
	morphology = mor
	variants = var_
	_ok = true


func _ler_json(nome_arquivo: String) -> Variant:
	var caminho := DATA_DIR + nome_arquivo
	if not FileAccess.file_exists(caminho):
		erro = "arquivo inexistente: " + caminho
		return null
	var texto := FileAccess.get_file_as_string(caminho)
	var dados: Variant = JSON.parse_string(texto)
	if dados == null:
		erro = "JSON invalido em: " + caminho
		return null
	return dados


# --- Acessores usados pelo gerador ---------------------------------------

func elementos() -> Array:
	return vocabulary["primarios"]["elemento"]


func animais() -> Array:
	return vocabulary["primarios"]["animal_base"]


func features_morfologia() -> Array:
	return vocabulary["derivados"]["morfologia"]


func prior_elemento() -> Dictionary:
	return priors["elemento"]


func prior_animal() -> Dictionary:
	return priors["animal_base"]


func dist_paleta(elemento: String) -> Dictionary:
	return palette[elemento]


func dist_matiz(elemento: String) -> Dictionary:
	return hue[elemento]


## P(feature presente | animal, elemento) = clamp(base + modificador, min, max).
func prob_feature(animal: String, elemento: String, feature: String) -> float:
	var base: float = morphology["base_por_animal"][animal][feature]
	var modif: float = morphology["modificador_por_elemento"][elemento][feature]
	var meta: Dictionary = morphology["_meta"]
	return clampf(base + modif, meta["clamp_min"], meta["clamp_max"])


# --- Variantes (modelos) das features -------------------------------------

## Pesos (nao normalizados) de escolha de modelo da feature, dado o elemento.
func vies_variante(feature: String, elemento: String) -> Array:
	return variants[feature]["vies_por_elemento"][elemento]


func num_modelos(feature: String) -> int:
	return variants[feature]["num_modelos"]


func nome_modelo(feature: String, indice: int) -> String:
	return variants[feature]["modelos"][indice]
