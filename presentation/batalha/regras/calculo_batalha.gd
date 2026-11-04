class_name CalculoBatalha
extends RefCounted

## Unico lugar que decide dano, acerto, fuga e efeito de item. Funcoes estaticas e
## puras, com o RNG sempre recebido de fora (RF03). Mesma politica de CalculoCaptura.


## Poder do golpe depois da variante do traco que o concede.
static func poder_efetivo(g: Golpe, atacante: Combatente, tabelas: TabelasBatalha) -> float:
	if g.traco == "" or atacante.criatura == null:
		return g.poder
	var variante: int = int(atacante.criatura.variantes.get(g.traco, 0))
	return g.poder * (1.0 + float(tabelas.dano().get("poder_por_variante", 0.0)) * variante)


static func multiplicador(g: Golpe, defensor: Combatente, tabelas: TabelasBatalha) -> float:
	return tabelas.multiplicador_elemento(g.elemento, defensor.criatura.elemento)


## Dano sem o sorteio de variacao e sem considerar acerto.
static func dano_base(g: Golpe, atacante: Combatente, defensor: Combatente,
		tabelas: TabelasBatalha, mult_lado: float = 1.0) -> float:
	if not g.causa_dano():
		return 0.0
	return poder_efetivo(g, atacante, tabelas) \
			* (atacante.ficha.ataque / maxf(defensor.defesa_efetiva(), 1.0)) \
			* float(tabelas.dano().get("escala", 1.0)) \
			* multiplicador(g, defensor, tabelas) * mult_lado


static func chance_de_acerto(g: Golpe, defensor: Combatente) -> float:
	return clampf(g.precisao * (1.0 - defensor.esquiva_efetiva()), 0.0, 1.0)


## Dano medio do golpe, ponderado pelo acerto. E o que a IA compara e o que a tela
## mostra ao jogador antes de escolher.
static func dano_esperado(g: Golpe, atacante: Combatente, defensor: Combatente,
		tabelas: TabelasBatalha, mult_lado: float = 1.0) -> float:
	return dano_base(g, atacante, defensor, tabelas, mult_lado) \
			* chance_de_acerto(g, defensor)


## Resolve um golpe de dano. Consome sempre dois sorteios, acertando ou nao: a
## sequencia do RNG nao depende do resultado anterior.
static func resolver_golpe(rng: RandomNumberGenerator, g: Golpe, atacante: Combatente,
		defensor: Combatente, tabelas: TabelasBatalha, mult_lado: float = 1.0) -> Dictionary:
	var sorteio_acerto: float = rng.randf()
	var sorteio_variacao: float = rng.randf()
	var acertou: bool = sorteio_acerto < chance_de_acerto(g, defensor)
	var cfg: Dictionary = tabelas.dano()
	var variacao: float = float(cfg.get("variacao", 0.0))
	var fator: float = 1.0 + variacao * (sorteio_variacao * 2.0 - 1.0)
	var dano: int = 0
	if acertou:
		dano = maxi(int(cfg.get("minimo", 1)),
				roundi(dano_base(g, atacante, defensor, tabelas, mult_lado) * fator))
	return {"acertou": acertou, "dano": dano, "mult": multiplicador(g, defensor, tabelas)}


## Soma o reforco do golpe ao stat, ate o limite. Devolve quanto de fato subiu.
static func aplicar_reforco(g: Golpe, c: Combatente) -> float:
	var atual: float = float(c.reforcos.get(g.stat, 0.0))
	var escala: float = 1.0
	if g.traco != "" and c.criatura != null:
		escala += 0.1 * int(c.criatura.variantes.get(g.traco, 0))
	var novo: float = minf(g.limite, atual + g.valor * escala)
	c.reforcos[g.stat] = novo
	return novo - atual


static func chance_de_fuga(fugitivo: Combatente, perseguidor: Combatente,
		tabelas: TabelasBatalha) -> float:
	var cfg: Dictionary = tabelas.fuga()
	var dif: float = fugitivo.ficha.velocidade - perseguidor.ficha.velocidade
	return clampf(float(cfg.get("base", 0.5)) + float(cfg.get("por_velocidade", 0.0)) * dif,
			float(cfg.get("piso", 0.0)), float(cfg.get("teto", 1.0)))


## O efeito declarado em data/itens/catalogo.json faz algo por esta criatura agora?
static func efeito_aplicavel(efeito: Dictionary, c: Combatente) -> bool:
	match String(efeito.get("tipo", "")):
		"curar":
			return c.viva() and c.vida < c.ficha.vida
		"reviver":
			return not c.viva()
	return false


## Aplica o efeito e devolve a vida recuperada. 0 = nada aconteceu.
static func aplicar_efeito(efeito: Dictionary, c: Combatente) -> int:
	if not efeito_aplicavel(efeito, c):
		return 0
	match String(efeito.get("tipo", "")):
		"curar":
			return c.curar(int(efeito.get("valor", 0)))
		"reviver":
			var parte: float = float(efeito.get("percentual", 0)) / 100.0
			return c.curar(maxi(1, roundi(c.ficha.vida * parte)))
	return 0
