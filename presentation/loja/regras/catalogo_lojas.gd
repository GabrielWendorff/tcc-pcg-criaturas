class_name CatalogoLojas
extends RefCounted

## Le autoral/lojas/lojas.json: quem vende e o que vende (Camada 1). O preco nao mora
## aqui, e sim em TabelasEconomia: um item custa o mesmo em qualquer loja.

const CAMINHO := "res://autoral/lojas/lojas.json"

var lojas: Array = []
var erro: String = ""


static func carregar(caminho: String = CAMINHO) -> CatalogoLojas:
	var c := CatalogoLojas.new()
	var bruto: Variant = JSON.parse_string(FileAccess.get_file_as_string(caminho))
	if not bruto is Dictionary:
		c.erro = "lojas.json ausente ou invalido"
		return c
	c.lojas = bruto.get("lojas", [])
	return c


func loja(id: String) -> Dictionary:
	for l: Dictionary in lojas:
		if String(l.get("id", "")) == id:
			return l
	return {}
