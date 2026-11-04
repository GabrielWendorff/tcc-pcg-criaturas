class_name PerfilPesca
extends RefCounted

## Ficha de uma criatura do ponto de vista da PESCA: em que altura ela nada, em que
## velocidade persegue a isca, quanta folga da ao jogador e quao comum e.
##
## Mesmo espirito de AfinidadeCriatura na captura: o perfil NAO e uma tabela nova
## por especie. Ele e DERIVADO dos atributos que o gerador ja sorteou por
## probabilidade condicionada — animal_base, elemento, porte e os tracos de
## morfologia — por uma soma de contribuicoes declarada em data/pesca/perfil.json.
##
## A consequencia e a mesma de la: a coerencia semantica do trabalho (RF04) vira
## mecanica sem regra extra. O que EMERGE das tabelas condicionais e o efeito dos
## tracos: nadadeiras deixam a criatura rapida e com menos folga de velocidade;
## escamas a puxam para o fundo e alargam as duas folgas. O peixe fundo e rapido
## contra o anfibio raso e lento e sobretudo DECLARADO (por_animal no JSON).
## 'agua + peixe' recebe nadadeiras (0.92 + 0.20) E escamas (0.90 + 0.10) com
## alta probabilidade em conditional_morphology.json, e as escamas compensam as
## nadadeiras: o mais escorregadio e quem tem nadadeiras SEM escamas (tipicamente
## o anfibio), e por dificuldade() o peixe nao sai mais dificil que o anfibio.
##
## O ruido individual usa um RNG PROPRIO, semeado da seed_individual da criatura
## mais um deslocamento fixo. Nao consome nada do RNG do gerador: calcular perfis
## nunca altera o bestiario de uma seed (RF03), e as metricas de RF04/RF08 medem
## exatamente as mesmas criaturas de antes da pesca existir.

## Deslocamento da semente do ruido. Diferente do do encontro (0x5E7A) e do do
## gerenciador de pesca (0x9E5CA0), para as tres sequencias nunca coincidirem.
const DESLOCAMENTO_RUIDO := 0x9E5CA

var criatura: Criatura
## 0 = superficie, 1 = fundo.
var profundidade: float = 0.5
## Normalizada, na mesma escala do recolhimento: 0 = devagar, 1 = rapido.
var velocidade: float = 0.5
## Meia-largura da faixa em que a isca "esta na altura"/"na velocidade" do monstro.
var tolerancia_profundidade: float = 0.12
var tolerancia_velocidade: float = 0.14
## Peso-base de surgimento (antes do ponto de pesca multiplicar pelo habitat).
var peso: float = 1.0
## Id da faixa de raridade (data/pesca/perfil.json -> peso.raridade).
var raridade: String = ""


## Aparece na pesca? Elemento agua OU animal de agua (peixe, anfibio), conforme
## `elegibilidade` da tabela. Um peixe de fogo pesca-se; um gato de agua tambem.
static func elegivel(c: Criatura, tabela: Dictionary) -> bool:
	if c == null:
		return false
	var eleg: Dictionary = tabela.get("elegibilidade", {})
	var elementos: Array = eleg.get("elementos", [])
	var animais: Array = eleg.get("animais", [])
	return c.elemento in elementos or c.animal_base in animais


## Perfil de pesca de uma criatura. Calcula mesmo para quem nao e elegivel (as
## metricas comparam com e sem traco sobre o bestiario inteiro). Null so para
## criatura null.
static func de_criatura(c: Criatura, tabela: Dictionary) -> PerfilPesca:
	if c == null:
		return null
	var p := PerfilPesca.new()
	p.criatura = c

	# Ruido deterministico, ordem FIXA: j1 (profundidade) e depois j2 (velocidade).
	var rng := RandomNumberGenerator.new()
	rng.seed = c.seed_individual + DESLOCAMENTO_RUIDO
	var j1: float = rng.randf_range(-1.0, 1.0)
	var j2: float = rng.randf_range(-1.0, 1.0)

	p.profundidade = _eixo(c, tabela.get("profundidade", {}), j1)
	p.velocidade = _eixo(c, tabela.get("velocidade", {}), j2)

	var tol: Dictionary = tabela.get("tolerancia", {})
	var minimo: float = float(tol.get("minimo", 0.05))
	p.tolerancia_profundidade = maxf(minimo, float(tol.get("profundidade_base", 0.12))
			+ _soma_tracos(c, tol.get("por_traco_profundidade", {})))
	p.tolerancia_velocidade = maxf(minimo, float(tol.get("velocidade_base", 0.14))
			+ _soma_tracos(c, tol.get("por_traco_velocidade", {})))

	var pt: Dictionary = tabela.get("peso", {})
	p.peso = float(pt.get("base", 1.0)) \
			* float(pt.get("por_porte", {}).get(c.porte, 1.0)) \
			* float(pt.get("por_elemento", {}).get(c.elemento, 1.0)) \
			* pow(float(pt.get("fator_por_traco", 1.0)), float(c.features_presentes().size()))
	p.raridade = _raridade(p.peso, pt.get("raridade", []))
	return p


## Quao dificil e fisgar: folgas estreitas pesam mais (1/tol), e altura/velocidade
## longe do meio pesam um pouco (exigem o mouse num canto da tela). Menor = mais
## facil. E por este numero que o tutorial escolhe o monstro de ensino.
func dificuldade() -> float:
	return 1.0 / maxf(tolerancia_profundidade, 0.001) \
			+ 1.0 / maxf(tolerancia_velocidade, 0.001) \
			+ 2.0 * absf(velocidade - 0.5) + 2.0 * absf(profundidade - 0.5)


func to_dict() -> Dictionary:
	var c := criatura
	return {
		"criatura_id": c.id if c != null else -1,
		"nome": c.nome() if c != null else "",
		"elemento": c.elemento if c != null else "",
		"animal_base": c.animal_base if c != null else "",
		"porte": c.porte if c != null else "",
		"tracos": c.features_presentes() if c != null else [],
		"profundidade": profundidade,
		"velocidade": velocidade,
		"tolerancia_profundidade": tolerancia_profundidade,
		"tolerancia_velocidade": tolerancia_velocidade,
		"peso": peso,
		"raridade": raridade,
		"dificuldade": dificuldade(),
	}


func _to_string() -> String:
	var nome_c: String = criatura.nome() if criatura != null else "?"
	return "%s | prof=%.2f vel=%.2f tol=(%.2f, %.2f) peso=%.2f %s" % [
		nome_c, profundidade, velocidade, tolerancia_profundidade,
		tolerancia_velocidade, peso, raridade]


## Soma de contribuicoes de um eixo + ruido, presa a [minimo, maximo]. Chave
## ausente contribui 0: um animal novo no vocabulario cai no meio, nao quebra.
static func _eixo(c: Criatura, t: Dictionary, ruido: float) -> float:
	var v: float = float(t.get("base", 0.5))
	v += float(t.get("por_animal", {}).get(c.animal_base, 0.0))
	v += float(t.get("por_elemento", {}).get(c.elemento, 0.0))
	v += float(t.get("por_porte", {}).get(c.porte, 0.0))
	v += _soma_tracos(c, t.get("por_traco", {}))
	v += ruido * float(t.get("variacao", 0.0))
	return clampf(v, float(t.get("minimo", 0.0)), float(t.get("maximo", 1.0)))


## Soma das contribuicoes dos tracos de morfologia PRESENTES na criatura.
static func _soma_tracos(c: Criatura, por_traco: Dictionary) -> float:
	var s: float = 0.0
	for traco: String in por_traco:
		if c.morfologia.get(traco, false):
			s += float(por_traco[traco])
	return s


## Primeira faixa cujo `peso_ate` cobre o peso. As faixas vem em ordem crescente,
## da mais rara para a mais comum; sem faixa que cubra, vale a ultima.
static func _raridade(peso_: float, faixas: Array) -> String:
	for faixa: Dictionary in faixas:
		if peso_ <= float(faixa.get("peso_ate", 0.0)):
			return String(faixa.get("id", ""))
	if faixas.is_empty():
		return "comum"
	return String(faixas[faixas.size() - 1].get("id", "comum"))
