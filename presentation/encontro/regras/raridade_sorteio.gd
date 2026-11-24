class_name RaridadeSorteio
extends RefCounted

## Raridade de cada criatura do bestiario: o "shiny" deste jogo.
##
## A RARIDADE E A PROBABILIDADE CONDICIONADA. Uma criatura e rara quando o sorteio
## dos atributos dela era improvavel dado o elemento e o animal — a mesma surpresa
## -log2 P(derivados | primarios) da nota de coerencia (NotaCoerencia). Nao e um
## sorteio a mais nem uma tabela de raridade: e o gerador lido por outro lado. Uma
## atipica e rara justamente porque o modelo condicionado quase nunca a produz.
##
##   COMUM     surpresa abaixo do limiar de atipica (data/modelo_v2.json)
##   RARA      atipica: acima do limiar (~1 em 10 do modelo)
##   LENDARIA  as `lendarias_por_seed` maiores surpresas da seed, entre as atipicas
##
## Calculada uma vez por bestiario, sem RNG: nao muda o bestiario de nenhuma seed.

const COMUM := "comum"
const RARA := "rara"
const LENDARIA := "lendaria"
const CAMINHO := "res://data/captura/colecao.json"

var lendarias_por_seed: int = 3
var textos: Dictionary = {
	"comum": "", "rara": "RARA", "lendaria": "LENDÁRIA",
	"abertura_rara": "Uma criatura RARA apareceu! O sorteio dela era improvável.",
	"abertura_lendaria": "Uma criatura LENDÁRIA apareceu! Uma das 3 mais improváveis deste mundo.",
	"cartaz_rara": "CRIATURA RARA!",
	"cartaz_lendaria": "CRIATURA LENDÁRIA!",
	"nova_especie": "NOVA ESPÉCIE!",
	"registradas": "BESTIÁRIO %d/%d",
	"marco": "Marco do bestiário: %d espécies! Recebeu %s.",
}
## Marcos de especies registradas: [{especies, gold, itens}], em ordem crescente.
var marcos: Array = []

## id da criatura -> nivel; id -> surpresa em bits.
var _nivel: Dictionary = {}
var _bits: Dictionary = {}


## Le o JSON (padroes embutidos se faltar) e classifica o bestiario.
static func do_bestiario(bestiario: Array, tabelas: TabelasProbabilidade,
		caminho: String = CAMINHO) -> RaridadeSorteio:
	var r := RaridadeSorteio.new()
	r._carregar(caminho)
	r.classificar(bestiario, tabelas)
	return r


func classificar(bestiario: Array, tabelas: TabelasProbabilidade) -> void:
	_nivel.clear()
	_bits.clear()
	if tabelas == null:
		return
	var atipicas: Array = []
	for c: Criatura in bestiario:
		var bits: float = NotaCoerencia.surpresa(c, tabelas, NotaCoerencia.usa_v2(c))
		_bits[c.id] = bits
		if NotaCoerencia.atipica(bits, tabelas):
			_nivel[c.id] = RARA
			atipicas.append(c)
		else:
			_nivel[c.id] = COMUM
	# Empate de surpresa desempata pelo id: a mesma seed da sempre as mesmas lendarias.
	atipicas.sort_custom(func(a: Criatura, b: Criatura) -> bool:
		var ba: float = _bits[a.id]
		var bb: float = _bits[b.id]
		return ba > bb if not is_equal_approx(ba, bb) else a.id < b.id)
	for c: Criatura in atipicas.slice(0, maxi(lendarias_por_seed, 0)):
		_nivel[c.id] = LENDARIA


func nivel(c: Criatura) -> String:
	return String(_nivel.get(c.id, COMUM)) if c != null else COMUM


func e_especial(c: Criatura) -> bool:
	return nivel(c) != COMUM


## Surpresa em bits (0 se a criatura nao e deste bestiario).
func bits(c: Criatura) -> float:
	return float(_bits.get(c.id, 0.0)) if c != null else 0.0


## "1 em N": a chance deste sorteio exato dado o elemento e o animal, 2^bits.
func uma_em(c: Criatura) -> String:
	var n: float = pow(2.0, bits(c))
	if n >= 1000000.0:
		return "1 em %s mi" % String.num(n / 1000000.0, 1)
	return "1 em %s" % _milhar(roundi(n))


func rotulo(niv: String) -> String:
	return String(textos.get(niv, ""))


func cor(niv: String) -> Color:
	match niv:
		LENDARIA:
			return TemaEncontro.OURO
		RARA:
			return TemaEncontro.VERDE_C
	return TemaEncontro.PERG_C


## Quantas do bestiario em cada nivel: {comum, rara, lendaria}.
func contagem(bestiario: Array) -> Dictionary:
	var n := {COMUM: 0, RARA: 0, LENDARIA: 0}
	for c: Criatura in bestiario:
		n[nivel(c)] += 1
	return n


func texto(chave: String) -> String:
	return String(textos.get(chave, chave))


func _carregar(caminho: String) -> void:
	if not FileAccess.file_exists(caminho):
		return
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(caminho))
	if not d is Dictionary:
		push_warning("RaridadeSorteio: JSON invalido — " + caminho)
		return
	var r: Dictionary = d.get("raridade", {})
	lendarias_por_seed = int(r.get("lendarias_por_seed", lendarias_por_seed))
	var t: Dictionary = d.get("textos", {})
	for k: String in t:
		textos[k] = String(t[k])
	marcos = (d.get("marcos", {}) as Dictionary).get("lista", [])
	marcos.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a["especies"]) < int(b["especies"]))


static func _milhar(n: int) -> String:
	var s := str(n)
	var saida := ""
	while s.length() > 3:
		saida = "." + s.substr(s.length() - 3) + saida
		s = s.substr(0, s.length() - 3)
	return s + saida
