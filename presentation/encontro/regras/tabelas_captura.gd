class_name TabelasCaptura
extends RefCounted

## Carrega e expoe as tabelas de captura de res://data/captura/.
##
## Espelha deliberadamente TabelasProbabilidade: mesma fabrica estatica, mesmo
## `valido()`/`erro`, mesma politica de manter a regra ignorante quanto ao formato
## de armazenamento. O motivo e o mesmo la e aqui — os numeros que definem o
## comportamento sao DADO calibravel, nao codigo.
##
## O que NAO esta aqui: probabilidade de geracao. Estas tabelas nao participam do
## sorteio de nenhuma criatura; elas leem atributos ja sorteados. O modelo
## generativo do trabalho continua inteiro em data/*.json e procedural/creatures/.

const DIR_CAPTURA := "res://data/captura/"

var balanceamento: Dictionary = {}
var dispositivos: Array[DispositivoCaptura] = []
var iscas: Array[IscaCaptura] = []

var _por_id: Dictionary = {}
var _ok: bool = false
var erro: String = ""


## Fabrica: tabelas carregadas, ou null com push_error.
static func carregar() -> TabelasCaptura:
	var t := TabelasCaptura.new()
	t._carregar_tudo()
	if not t._ok:
		push_error("TabelasCaptura: falha ao carregar — " + t.erro)
		return null
	return t


func valido() -> bool:
	return _ok


func _carregar_tudo() -> void:
	var bal: Variant = _ler_json("balanceamento.json")
	var disp: Variant = _ler_json("dispositivos.json")
	var isc: Variant = _ler_json("iscas.json")
	if bal == null or disp == null or isc == null:
		return
	balanceamento = bal
	for d: Dictionary in disp.get("dispositivos", []):
		var dispositivo := DispositivoCaptura.de_dicionario(d)
		dispositivos.append(dispositivo)
		_por_id[dispositivo.id] = dispositivo
	for d: Dictionary in isc.get("iscas", []):
		var isca := IscaCaptura.de_dicionario(d)
		iscas.append(isca)
		_por_id[isca.id] = isca
	if dispositivos.is_empty():
		erro = "nenhum dispositivo declarado em dispositivos.json"
		return
	_ok = true


func _ler_json(nome_arquivo: String) -> Variant:
	var caminho := DIR_CAPTURA + nome_arquivo
	if not FileAccess.file_exists(caminho):
		erro = "arquivo inexistente: " + caminho
		return null
	var dados: Variant = JSON.parse_string(FileAccess.get_file_as_string(caminho))
	if dados == null:
		erro = "JSON invalido em: " + caminho
		return null
	return dados


## Item (dispositivo ou isca) por id. Um id so, um espaco de nomes so: e o que
## permite ao inventario guardar os dois tipos na mesma tabela de quantidades.
func item(id: String) -> ItemCaptura:
	return _por_id.get(id)


func dispositivo(id: String) -> DispositivoCaptura:
	return _por_id.get(id) as DispositivoCaptura


func isca(id: String) -> IscaCaptura:
	return _por_id.get(id) as IscaCaptura


# --- Acessores do balanceamento (nenhum numero destes vive em codigo) -------

func chance_base() -> float:
	return float(balanceamento.get("base", 0.45))


func piso() -> float:
	return float(balanceamento.get("piso", 0.03))


func teto() -> float:
	return float(balanceamento.get("teto", 0.85))


## Fator de evasao por traco morfologico. Chaves = data/vocabulary.json.
func fatores_de_evasao() -> Dictionary:
	return balanceamento.get("afinidade", {}).get("fator_evasao", {})


func motivo_do_traco(traco: String) -> String:
	return String(balanceamento.get("afinidade", {}).get("motivo", {}).get(traco, ""))


func faixas_de_estado() -> Array:
	return balanceamento.get("estado", {}).get("faixas", [])


func config_vigor() -> Dictionary:
	return balanceamento.get("vigor", {})


func bonus_de_isca_incorreta() -> float:
	return float(balanceamento.get("isca", {}).get("bonus_incorreto", 0.05))


func chance_de_fuga(falhas: int) -> float:
	var f: Dictionary = balanceamento.get("fuga", {})
	var por_falha: float = float(f.get("chance_por_falha_extra", 0.0))
	var maxima: float = float(f.get("chance_maxima", 1.0))
	# A primeira falha nunca faz a criatura fugir: um unico lance frustrado que
	# encerra o encontro le como bug, nao como risco.
	return clampf(por_falha * float(maxi(falhas - 1, 0)), 0.0, maxima)


## Confere que todo traco do vocabulario canonico tem fator de evasao declarado.
## Um traco esquecido aqui nao daria erro — daria uma criatura silenciosamente
## mais facil de capturar do que a tabela pretende.
func validar(tabelas: TabelasProbabilidade) -> PackedStringArray:
	var faltando := PackedStringArray()
	if tabelas == null:
		return faltando
	var fatores := fatores_de_evasao()
	for traco: String in tabelas.features_morfologia():
		if not fatores.has(traco):
			faltando.append("fator_evasao[%s]" % traco)
	var animais: Array = tabelas.animais()
	for isca_ in iscas:
		for tipo in isca_.tipos_preferidos:
			if not tipo in animais:
				faltando.append("isca '%s' prefere '%s', fora do vocabulario" % [isca_.id, tipo])
	for d in dispositivos:
		for traco: String in d.eficacia_por_traco:
			if not traco in tabelas.features_morfologia():
				faltando.append("dispositivo '%s' cita traco '%s', fora do vocabulario" % [d.id, traco])
	return faltando
