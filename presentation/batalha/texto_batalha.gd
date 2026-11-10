class_name TextoBatalha
extends RefCounted

## Como os numeros da batalha viram texto. Num lugar so para a ficha dizer a mesma
## coisa na escolha inicial, na equipe e na batalha.


static func stats(f: FichaCombate) -> String:
	return "VIDA %d  ATQ %d  DEF %d\nVEL %d  ESQ %d%%" % [f.vida, roundi(f.ataque),
			roundi(f.defesa), roundi(f.velocidade), roundi(f.esquiva * 100.0)]


static func lista_de_golpes(f: FichaCombate) -> String:
	var nomes := PackedStringArray()
	for g: Golpe in f.golpes:
		nomes.append(g.nome)
	return ", ".join(nomes)


static func lista_de_tracos(c: Criatura) -> String:
	var presentes: Array = c.features_presentes()
	return "nenhum" if presentes.is_empty() else ", ".join(presentes)


static func ficha_em_bbcode(c: Criatura, f: FichaCombate) -> String:
	var apoio := TemaEncontro.PERG_E.to_html(false)
	return "[color=%s]%s + %s · %s[/color]\n[color=%s]TRAÇOS[/color]  %s\n%s\n[color=%s]GOLPES[/color]  %s" % [
		apoio, c.elemento, c.animal_base, c.porte,
		apoio, lista_de_tracos(c),
		stats(f),
		apoio, lista_de_golpes(f)]


## A vitrine do algoritmo (RF07, RF08): de onde esta criatura veio. Cada linha e a chance
## que o modelo dava ao que saiu, dados os primarios, e a nota final soma a surpresa de
## todas elas. Sem sorteio nenhum aqui: tudo e lido das tabelas.
static func sorteio_em_bbcode(c: Criatura, tabelas: TabelasProbabilidade) -> String:
	var apoio := TemaEncontro.PERG_E.to_html(false)
	var nota: Dictionary = NotaCoerencia.decompor(c, tabelas, NotaCoerencia.usa_v2(c))
	var bits: float = float(nota["bits"])
	var atipica: bool = NotaCoerencia.atipica(bits, tabelas)
	var cor_nota := (TemaEncontro.FALHA if atipica else TemaEncontro.VERDE_C).to_html(false)
	var texto := "[color=%s]%s[/color]\n" % [TemaEncontro.OURO_C.to_html(false), c.nome().to_upper()]
	texto += "[color=%s]%s  %s bits[/color]\n" % [cor_nota, "ATÍPICA" if atipica else "COERENTE",
			("%.1f" % bits).replace(".", ",")]
	texto += "[color=%s]SEED %d[/color]\n" % [apoio, c.world_seed]
	texto += "[color=%s]PRIMÁRIOS[/color]  %s + %s\n" % [apoio, c.elemento, c.animal_base]
	texto += "[color=%s]CHANCE DE CADA DERIVADO[/color]" % apoio
	var linhas: Array = nota["linhas"]
	for i in linhas.size():
		var l: Dictionary = linhas[i]
		if String(l["atributo"]).ends_with(" (modelo)"):
			continue
		texto += "\n%s  %s %s" % [_percentual(float(l["p"])), l["atributo"], l["valor"]]
		if i + 1 < linhas.size() and String(linhas[i + 1]["atributo"]).ends_with(" (modelo)"):
			var modelo: Dictionary = linhas[i + 1]
			texto += " · %s %s" % [modelo["valor"], _percentual(float(modelo["p"]))]
	return texto


static func _percentual(p: float) -> String:
	return "<1%" if p < 0.01 else "%d%%" % roundi(p * 100.0)


## Linha de apoio de um golpe no menu: o que ele faz CONTRA ESTE adversario. E aqui
## que a vantagem de elementos aparece na hora de escolher.
static func dica_do_golpe(g: Golpe, atacante: Combatente, defensor: Combatente,
		tabelas: TabelasBatalha) -> String:
	if not g.causa_dano():
		return g.descricao
	var dano: int = roundi(CalculoBatalha.dano_base(g, atacante, defensor, tabelas))
	var acerto: int = roundi(CalculoBatalha.chance_de_acerto(g, defensor) * 100.0)
	var mult: float = CalculoBatalha.multiplicador(g, defensor, tabelas)
	var nota := ""
	if mult > 1.0:
		nota = "  MUITO EFICAZ ×%.2f" % mult
	elif mult < 1.0:
		nota = "  POUCO EFICAZ ×%.2f" % mult
	return "%d de dano · %d%% de acerto%s" % [dano, acerto, nota]
