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
