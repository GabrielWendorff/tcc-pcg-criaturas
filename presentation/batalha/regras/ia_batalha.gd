class_name IaBatalha
extends RefCounted

## Como um combatente sem jogador escolhe o golpe. Separada do motor porque o
## simulador de balanceamento (tools/simular_batalha.gd) usa a mesma regra para jogar
## pelo lado do jogador.
##
## Consome sempre tres sorteios, para a sequencia do RNG nao depender da situacao.


static func escolher(rng: RandomNumberGenerator, atacante: Combatente, defensor: Combatente,
		tabelas: TabelasBatalha, cfg_lado: Dictionary) -> Golpe:
	var golpes: Array[Golpe] = atacante.ficha.golpes
	var sorteio_aleatorio: float = rng.randf()
	var sorteio_reforco: float = rng.randf()
	var indice: int = rng.randi()
	if golpes.is_empty():
		return null

	if sorteio_aleatorio < float(cfg_lado.get("chance_golpe_aleatorio", 0.0)):
		return golpes[indice % golpes.size()]

	if sorteio_reforco < float(cfg_lado.get("chance_reforco", 0.0)):
		for g: Golpe in golpes:
			if not g.causa_dano() and not atacante.reforco_no_limite(g):
				return g

	var melhor: Golpe = null
	var melhor_dano: float = -1.0
	var mult: float = float(cfg_lado.get("mult_dano", 1.0))
	for g: Golpe in golpes:
		if not g.causa_dano():
			continue
		var d: float = CalculoBatalha.dano_esperado(g, atacante, defensor, tabelas, mult)
		if d > melhor_dano:
			melhor_dano = d
			melhor = g
	return melhor if melhor != null else golpes[0]
