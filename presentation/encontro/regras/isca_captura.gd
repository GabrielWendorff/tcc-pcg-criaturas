class_name IscaCaptura
extends ItemCaptura

## Uma isca, lida de data/captura/iscas.json.
##
## A preferencia e declarada por ANIMAL BASE — atributo PRIMARIO da criatura, a
## mesma raiz de que dependem os derivados (RF04). Nao ha if/else por especie em
## lugar nenhum do sistema: acertar a isca e uma consulta a lista do dado.

## Valores de data/vocabulary.json -> primarios.animal_base.
var tipos_preferidos: PackedStringArray = PackedStringArray()

## Ganho quando a isca casa com o animal base (multiplicador = 1 + bonus).
var bonus: float = 0.0


static func de_dicionario(d: Dictionary) -> IscaCaptura:
	var isca := IscaCaptura.new()
	isca._ler_comuns(d)
	isca.bonus = float(d.get("bonus", 0.0))
	var tipos := PackedStringArray()
	for t: String in d.get("tipos_preferidos", []):
		tipos.append(t)
	isca.tipos_preferidos = tipos
	return isca


func preferida_por(criatura: Criatura) -> bool:
	return criatura != null and criatura.animal_base in tipos_preferidos


## Multiplicador da isca. 'bonus_incorreto' vem do balanceamento e e pequeno de
## proposito: comida errada nao e punicao, e so nao e vantagem.
func multiplicador_contra(criatura: Criatura, bonus_incorreto: float) -> float:
	return 1.0 + (bonus if preferida_por(criatura) else bonus_incorreto)


func detalhe(criatura: Criatura) -> String:
	var alvos: String = ", ".join(tipos_preferidos)
	if preferida_por(criatura):
		return "preferida por %s  (+%.0f%%)" % [alvos, bonus * 100.0]
	return "atrai %s" % alvos
