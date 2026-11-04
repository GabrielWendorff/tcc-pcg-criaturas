class_name CatalogoGuardioes
extends RefCounted

## Le autoral/guardioes/guardioes.json. O guardiao e Camada 1 (fixo); a equipe dele e
## lida do bestiario da seed por SelecaoBestiario.

const CAMINHO := "res://autoral/guardioes/guardioes.json"

var guardioes: Array = []
var selos_para_vencer: int = 1
var erro: String = ""


static func carregar() -> CatalogoGuardioes:
	var c := CatalogoGuardioes.new()
	var dados: Variant = JSON.parse_string(FileAccess.get_file_as_string(CAMINHO))
	if not dados is Dictionary:
		c.erro = "guardioes.json ausente ou invalido"
		return c
	c.guardioes = dados.get("guardioes", [])
	c.selos_para_vencer = int(dados.get("selos_para_vencer", 1))
	return c


func por_id(id: String) -> Dictionary:
	for g: Dictionary in guardioes:
		if String(g.get("id", "")) == id:
			return g
	return {}


## Quantos selos o estado do mundo ja guarda.
func selos_obtidos(estado: EstadoMundo) -> int:
	var n: int = 0
	for g: Dictionary in guardioes:
		if estado.ativa(String(g.get("selo", ""))):
			n += 1
	return n


func venceu_o_jogo(estado: EstadoMundo) -> bool:
	return selos_obtidos(estado) >= selos_para_vencer
