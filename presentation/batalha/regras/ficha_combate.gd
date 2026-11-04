class_name FichaCombate
extends RefCounted

## Traduz os atributos JA SORTEADOS de uma criatura em termos de batalha. E a mesma
## ideia de AfinidadeCriatura e PerfilPesca: nenhuma tabela por especie, nenhuma
## mudanca no GeradorCriaturas. Quem tem garras bate mais forte porque a garra veio
## de P(garras | animal, elemento), e nao porque alguem escreveu "gato e forte".
##
## O contrapeso e o que ja existia: cada traco que fortalece aqui tambem aumenta a
## evasao na captura. Criatura sem tracos e fraca, porem facil de pegar.
##
## Funcao pura dos atributos: mesma criatura, mesma ficha (RF03).

var vida: int = 1
var ataque: float = 1.0
var defesa: float = 1.0
var velocidade: float = 1.0
var esquiva: float = 0.0
var golpes: Array[Golpe] = []


static func de_criatura(c: Criatura, tabelas: TabelasBatalha) -> FichaCombate:
	var f := FichaCombate.new()
	var cfg: Dictionary = tabelas.stats()
	var valores: Dictionary = (cfg.get("base", {}) as Dictionary).duplicate()

	var por_traco: Dictionary = cfg.get("por_traco", {})
	for traco: String in por_traco:
		if not c.morfologia.get(traco, false):
			continue
		var regra: Dictionary = por_traco[traco]
		var stat := String(regra.get("stat", ""))
		var variante: int = int(c.variantes.get(traco, 0))
		valores[stat] = float(valores.get(stat, 0.0)) + float(regra.get("valor", 0.0)) \
				+ float(regra.get("por_variante", 0.0)) * variante

	var por_porte: Dictionary = cfg.get("por_porte", {}).get(c.porte, {})
	for stat: String in por_porte:
		valores[stat] = float(valores.get(stat, 0.0)) + float(por_porte[stat])

	f.vida = maxi(1, roundi(AfinidadeCriatura.vigor_maximo(c, tabelas.config_vigor())))
	f.ataque = maxf(1.0, float(valores.get("ataque", 1.0)))
	f.defesa = maxf(1.0, float(valores.get("defesa", 1.0)))
	f.velocidade = maxf(1.0, float(valores.get("velocidade", 1.0)))
	f.esquiva = clampf(float(valores.get("esquiva", 0.0)), 0.0, 0.9)
	f.golpes = golpes_de(c, tabelas)
	return f


## O golpe do elemento, um por traco presente, e a reserva so para quem ficaria com
## menos de dois. A ordem e a do vocabulario, para o menu nao mudar entre telas.
static func golpes_de(c: Criatura, tabelas: TabelasBatalha) -> Array[Golpe]:
	var lista: Array[Golpe] = []
	var do_elemento := tabelas.do_elemento(c.elemento)
	if do_elemento != null:
		lista.append(do_elemento)
	for traco: String in tabelas.stats().get("por_traco", {}):
		if c.morfologia.get(traco, false):
			var g := tabelas.do_traco(traco)
			if g != null:
				lista.append(g)
	if lista.size() < 2 and tabelas.de_reserva() != null:
		lista.append(tabelas.de_reserva())
	return lista


## Indice para comparar criaturas (iniciais e guardioes por percentil). Nao entra em
## nenhum calculo de dano.
func forca(tabelas: TabelasBatalha) -> float:
	var p: Dictionary = tabelas.pesos_de_forca()
	return float(vida) * float(p.get("vida", 0.25)) \
			+ ataque * float(p.get("ataque", 1.0)) \
			+ defesa * float(p.get("defesa", 1.0)) \
			+ velocidade * float(p.get("velocidade", 0.5)) \
			+ esquiva * float(p.get("esquiva", 100.0))
