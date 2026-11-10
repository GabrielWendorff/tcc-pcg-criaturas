class_name TabelasEconomia
extends RefCounted

## Le data/economia/economia.json: gold inicial, kit da Mirela, recompensa por
## derrotar um selvagem e o preco de cada item. Funcoes puras, sem engine.

const CAMINHO := "res://data/economia/economia.json"

var dados: Dictionary = {}
var erro: String = ""


static func carregar(caminho: String = CAMINHO) -> TabelasEconomia:
	var t := TabelasEconomia.new()
	var bruto: Variant = JSON.parse_string(FileAccess.get_file_as_string(caminho))
	if not bruto is Dictionary:
		t.erro = "economia.json ausente ou invalido"
		push_error("TabelasEconomia: " + t.erro)
		return t
	t.dados = bruto
	return t


func gold_inicial() -> int:
	return int(dados.get("gold_inicial", 0))


## Preco em gold; 0 = o item nao e vendido em lugar nenhum.
func preco(id: String) -> int:
	return int(dados.get("precos", {}).get(id, 0))


func kit_inicial() -> Dictionary:
	return dados.get("kit_inicial", {}).get("itens", {})


## Gold por derrotar uma criatura selvagem desta forca (FichaCombate.forca).
func recompensa_selvagem(forca: float) -> int:
	var r: Dictionary = dados.get("recompensa_selvagem", {})
	return maxi(1, roundi(float(r.get("base", 5)) + float(r.get("por_forca", 0.0)) * forca))
