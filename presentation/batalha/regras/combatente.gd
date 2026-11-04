class_name Combatente
extends RefCounted

## Uma criatura em condicao de lutar: a ficha derivada (imutavel) mais o que muda na
## partida. A vida atual persiste entre batalhas e vai para o save; os reforcos so
## duram enquanto ela esta em campo.

var criatura: Criatura
var ficha: FichaCombate
var vida: int = 1
## stat -> quanto foi somado por golpes de reforco.
var reforcos: Dictionary = {}


static func de_criatura(c: Criatura, tabelas: TabelasBatalha,
		vida_atual: int = CriaturaSalva.HP_CHEIO) -> Combatente:
	var r := Combatente.new()
	r.criatura = c
	r.ficha = FichaCombate.de_criatura(c, tabelas)
	r.vida = r.ficha.vida if vida_atual == CriaturaSalva.HP_CHEIO \
			else clampi(vida_atual, 0, r.ficha.vida)
	return r


func viva() -> bool:
	return vida > 0


func fracao() -> float:
	return clampf(float(vida) / float(maxi(ficha.vida, 1)), 0.0, 1.0)


func nome() -> String:
	return criatura.nome() if criatura != null else "?"


func receber(dano: int) -> void:
	vida = maxi(0, vida - maxi(dano, 0))


func curar(valor: int) -> int:
	var antes := vida
	vida = mini(ficha.vida, vida + maxi(valor, 0))
	return vida - antes


func curar_tudo() -> void:
	vida = ficha.vida
	limpar_reforcos()


func limpar_reforcos() -> void:
	reforcos.clear()


func defesa_efetiva() -> float:
	return ficha.defesa * (1.0 + float(reforcos.get("defesa", 0.0)))


func esquiva_efetiva() -> float:
	return clampf(ficha.esquiva + float(reforcos.get("esquiva", 0.0)), 0.0, 0.9)


## O reforco ja chegou ao limite do golpe?
func reforco_no_limite(g: Golpe) -> bool:
	return float(reforcos.get(g.stat, 0.0)) >= g.limite - 0.0001
