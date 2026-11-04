class_name TabelasProbabilidade
extends RefCounted

## Carrega e expoe as tabelas de probabilidade condicionada de res://data/.
## Mantem a logica de geracao ignorante quanto ao formato de armazenamento
## (JSON hoje; poderia ser .tres amanha) e permite recarga a quente na calibragem.

const DATA_DIR := "res://data/"

var vocabulary: Dictionary = {}
var priors: Dictionary = {}
var porte: Dictionary = {}        # vies de P(porte  | elemento), pesos nao normalizados
var palette: Dictionary = {}      # P(paleta | elemento)
var hue: Dictionary = {}          # P(matiz  | elemento)
var morphology: Dictionary = {}   # base_por_animal + modificador_por_elemento
var variants: Dictionary = {}     # modelos de cada feature + vies por elemento

## Distribuicoes MARGINAIS, derivadas das condicionais pela lei da probabilidade
## total (ex.: P(paleta) = sum_e P(elemento=e) * P(paleta|e)). Nao sao dados de
## entrada: sao calculadas uma vez no carregamento e servem exclusivamente ao
## baseline independente (hipotese nula) usado nas metricas — ver GeradorCriaturas.
var marginais: Dictionary = {}

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
	var por: Variant = _ler_json("conditional_porte.json")
	var pal: Variant = _ler_json("conditional_palette.json")
	var hu: Variant = _ler_json("conditional_hue.json")
	var mor: Variant = _ler_json("conditional_morphology.json")
	var var_: Variant = _ler_json("feature_variants.json")
	if voc == null or pri == null or por == null or pal == null or hu == null \
			or mor == null or var_ == null:
		return
	vocabulary = voc
	priors = pri
	porte = por["vies_por_elemento"]
	palette = pal["tabela"]
	hue = hu["tabela"]
	morphology = mor
	variants = var_
	_calcular_marginais()
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


func portes() -> Array:
	return vocabulary["derivados"]["porte"]


func prior_elemento() -> Dictionary:
	return priors["elemento"]


func prior_animal() -> Dictionary:
	return priors["animal_base"]


## Pesos (nao normalizados) de escolha do porte, dado o elemento. Mesma ordem de
## portes(). O porte seleciona a mascara de corpo — ver CatalogoCorpos.
func vies_porte(elemento: String) -> Array:
	return porte[elemento]


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


# --- Marginais (baseline independente) ------------------------------------
#
# Estas distribuicoes descrevem o MESMO bestiario visto sem condicionamento:
# a frequencia com que cada valor derivado aparece no mundo, ignorando de qual
# elemento/animal ele veio. Amostrar delas produz criaturas com as mesmas
# proporcoes globais mas SEM correlacao entre primarios e derivados — que e
# exatamente a hipotese nula contra a qual a contribuicao do trabalho (RF04) e
# medida. Iteram o vocabulario canonico (arrays ordenados), nao os dicionarios,
# para que a ordem de insercao — e portanto a amostragem — seja deterministica.

func _calcular_marginais() -> void:
	var pe: Dictionary = prior_elemento()
	var pa: Dictionary = prior_animal()

	var m_paleta: Dictionary = {}
	for valor in vocabulary["derivados"]["paleta"]:
		var acc: float = 0.0
		for e in elementos():
			acc += float(pe[e]) * float(palette[e].get(valor, 0.0))
		m_paleta[valor] = acc

	var m_matiz: Dictionary = {}
	for valor in vocabulary["derivados"]["matiz"]:
		var acc: float = 0.0
		for e in elementos():
			acc += float(pe[e]) * float(hue[e].get(valor, 0.0))
		m_matiz[valor] = acc

	var m_feature: Dictionary = {}
	var m_variante: Dictionary = {}
	for f in features_morfologia():
		var acc: float = 0.0
		for a in animais():
			for e in elementos():
				acc += float(pa[a]) * float(pe[e]) * prob_feature(a, e, f)
		m_feature[f] = acc

		m_variante[f] = _media_vies(func(e): return vies_variante(f, e), num_modelos(f))

	marginais = {
		"porte": _media_vies(func(e): return vies_porte(e), portes().size()),
		"paleta": m_paleta,
		"matiz": m_matiz,
		"feature": m_feature,
		"variante": m_variante,
	}


## Media, ponderada pelo prior do elemento, de um vetor de vies indexado por elemento.
## Normaliza cada linha antes de somar: os pesos do JSON nao sao normalizados e linhas
## com totais diferentes pesariam desigualmente.
func _media_vies(linha_de: Callable, n: int) -> Array:
	var pe: Dictionary = prior_elemento()
	var pesos: Array = []
	pesos.resize(n)
	pesos.fill(0.0)
	for e in elementos():
		var linha: Array = linha_de.call(e)
		var total: float = 0.0
		for w in linha:
			total += float(w)
		for i in linha.size():
			pesos[i] += float(pe[e]) * float(linha[i]) / total
	return pesos


## Pesos de escolha do porte sem condicionar ao elemento.
func marginal_vies_porte() -> Array:
	return marginais["porte"]


func marginal_paleta() -> Dictionary:
	return marginais["paleta"]


func marginal_matiz() -> Dictionary:
	return marginais["matiz"]


## P(feature presente) sem condicionar a animal nem elemento.
func marginal_prob_feature(feature: String) -> float:
	return marginais["feature"][feature]


## Pesos de escolha de modelo sem condicionar ao elemento.
func marginal_vies_variante(feature: String) -> Array:
	return marginais["variante"][feature]
