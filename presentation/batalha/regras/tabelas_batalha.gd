class_name TabelasBatalha
extends RefCounted

## Carrega e expoe as tabelas de res://data/batalha/. Espelha TabelasCaptura: mesma
## fabrica estatica, mesmo `erro`, mesma politica de os numeros serem dado calibravel.
##
## Estas tabelas NAO participam do sorteio de nenhuma criatura. Elas leem atributos
## ja sorteados, e por isso o bestiario de uma seed e as metricas de RF08 nao mudam.

const DIR_BATALHA := "res://data/batalha/"
const ARQUIVO_VIGOR := "res://data/captura/balanceamento.json"

var balanceamento: Dictionary = {}
var elementos: Dictionary = {}
var golpes: Array[Golpe] = []
var erro: String = ""

var _vigor: Dictionary = {}
var _por_id: Dictionary = {}


static func carregar() -> TabelasBatalha:
	var t := TabelasBatalha.new()
	t._carregar_tudo()
	if t.erro != "":
		push_error("TabelasBatalha: falha ao carregar — " + t.erro)
		return null
	return t


func _carregar_tudo() -> void:
	var bal: Variant = _ler_json(DIR_BATALHA + "balanceamento.json")
	var ele: Variant = _ler_json(DIR_BATALHA + "elementos.json")
	var gol: Variant = _ler_json(DIR_BATALHA + "golpes.json")
	var cap: Variant = _ler_json(ARQUIVO_VIGOR)
	if bal == null or ele == null or gol == null or cap == null:
		return
	balanceamento = bal
	elementos = ele
	_vigor = cap.get("vigor", {})
	for d: Dictionary in gol.get("golpes", []):
		var g := Golpe.de_dicionario(d)
		golpes.append(g)
		_por_id[g.id] = g
	if golpes.is_empty():
		erro = "nenhum golpe declarado"


func _ler_json(caminho: String) -> Variant:
	var texto := FileAccess.get_file_as_string(caminho)
	if texto == "":
		erro = "arquivo vazio ou ausente: " + caminho
		return null
	var dados: Variant = JSON.parse_string(texto)
	if not dados is Dictionary:
		erro = "JSON invalido: " + caminho
		return null
	return dados


func golpe(id: String) -> Golpe:
	return _por_id.get(id, null)


func do_elemento(elemento: String) -> Golpe:
	for g: Golpe in golpes:
		if g.elemento == elemento:
			return g
	return null


func do_traco(traco: String) -> Golpe:
	for g: Golpe in golpes:
		if g.traco == traco:
			return g
	return null


func de_reserva() -> Golpe:
	for g: Golpe in golpes:
		if g.reserva:
			return g
	return null


func config_vigor() -> Dictionary:
	return _vigor


func stats() -> Dictionary:
	return balanceamento.get("stats", {})


func dano() -> Dictionary:
	return balanceamento.get("dano", {})


func fuga() -> Dictionary:
	return balanceamento.get("fuga", {})


func lado(tipo: String) -> Dictionary:
	return balanceamento.get("lados", {}).get(tipo, {})


func pesos_de_forca() -> Dictionary:
	return balanceamento.get("forca", {})


func iniciais() -> Dictionary:
	return balanceamento.get("iniciais", {})


func maximo_da_equipe() -> int:
	return int(balanceamento.get("equipe", {}).get("maximo", 3))


func forte_contra(atacante: String, defensor: String) -> bool:
	return defensor in elementos.get("forte_contra", {}).get(atacante, [])


## Multiplicador de elemento. A relacao e simetrica por construcao: so "forte_contra"
## e declarado, e o fraco e o inverso dele. Golpe neutro ("") vale 1.
func multiplicador_elemento(atacante: String, defensor: String) -> float:
	if atacante == "" or defensor == "":
		return 1.0
	if forte_contra(atacante, defensor):
		return float(elementos.get("multiplicador_forte", 1.5))
	if forte_contra(defensor, atacante):
		return float(elementos.get("multiplicador_fraco", 0.75))
	return 1.0


## Lista do que falta ou diverge do vocabulario do gerador. Vazia = coerente.
func validar(prob: TabelasProbabilidade) -> PackedStringArray:
	var faltando := PackedStringArray()
	var fortes: Dictionary = elementos.get("forte_contra", {})
	for e: String in prob.elementos():
		if do_elemento(e) == null:
			faltando.append("golpe do elemento " + e)
		if not fortes.has(e):
			faltando.append("vantagem do elemento " + e)
		for alvo: String in fortes.get(e, []):
			if not alvo in prob.elementos():
				faltando.append("elemento desconhecido " + alvo)
			if forte_contra(alvo, e):
				faltando.append("vantagem mutua %s/%s" % [e, alvo])
	var por_traco: Dictionary = stats().get("por_traco", {})
	for f: String in prob.features_morfologia():
		if do_traco(f) == null:
			faltando.append("golpe do traco " + f)
		if not por_traco.has(f):
			faltando.append("stat do traco " + f)
	var por_porte: Dictionary = stats().get("por_porte", {})
	for p: String in prob.portes():
		if not por_porte.has(p):
			faltando.append("stat do porte " + p)
	if de_reserva() == null:
		faltando.append("golpe de reserva")
	return faltando
