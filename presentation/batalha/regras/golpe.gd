class_name Golpe
extends RefCounted

## Um golpe do catalogo (data/batalha/golpes.json). So dado: quem decide o dano e
## CalculoBatalha, e quem decide quem tem qual golpe e FichaCombate.

const TIPO_DANO := "dano"
const TIPO_REFORCO := "reforco"

var id: String = ""
var nome: String = ""
var descricao: String = ""
var tipo: String = TIPO_DANO
var poder: float = 0.0
var precisao: float = 1.0
var prioridade: int = 0
## Elemento do golpe; "" = neutro (golpes de traco e Investida).
var elemento: String = ""
## Traco que concede o golpe; "" = nao vem de traco. A variante dele escala o poder.
var traco: String = ""
var reserva: bool = false
var stat: String = ""
var valor: float = 0.0
var limite: float = 0.0


static func de_dicionario(d: Dictionary) -> Golpe:
	var g := Golpe.new()
	g.id = String(d.get("id", ""))
	g.nome = String(d.get("nome", g.id))
	g.descricao = String(d.get("descricao", ""))
	g.tipo = String(d.get("tipo", TIPO_DANO))
	g.poder = float(d.get("poder", 0.0))
	g.precisao = float(d.get("precisao", 1.0))
	g.prioridade = int(d.get("prioridade", 0))
	g.stat = String(d.get("stat", ""))
	g.valor = float(d.get("valor", 0.0))
	g.limite = float(d.get("limite", 0.0))
	var req: Dictionary = d.get("requisito", {})
	g.elemento = String(req.get("elemento", ""))
	g.traco = String(req.get("traco", ""))
	g.reserva = bool(req.get("reserva", false))
	return g


func causa_dano() -> bool:
	return tipo == TIPO_DANO
