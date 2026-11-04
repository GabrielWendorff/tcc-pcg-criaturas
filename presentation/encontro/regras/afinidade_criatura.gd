class_name AfinidadeCriatura
extends RefCounted

## Traduz os atributos JA SORTEADOS de uma criatura em termos de captura: quao
## evasiva ela e, quanto vigor tem, em que estado esta.
##
## A ideia central do modulo — e a razao de ele existir separado do calculo — e que
## a afinidade NAO e uma tabela nova por especie. Ela le a MORFOLOGIA que o gerador
## produziu por probabilidade condicionada (data/conditional_morphology.json:
## P(traco | animal, elemento)) e atribui a cada traco presente um fator de evasao.
##
## A consequencia e que a coerencia semantica do trabalho (RF04) atravessa para a
## mecanica sem nenhuma regra extra: 'agua + peixe' recebe escamas (0.90) e
## nadadeiras (0.92) com alta probabilidade e, por isso, tende a ser blindado e
## escorregadio; 'fogo + gato' recebe garras (0.85 + 0.10) e reage. Ninguem
## escreveu 'peixe e dificil de pegar' em lugar nenhum — isso emerge da tabela
## condicional que ja existia.
##
## Funcoes estaticas e puras: mesma criatura, mesmos numeros, sem estado e sem
## engine (RF03). Testaveis sem abrir cena.


## Multiplicador de evasao: produto dos fatores dos tracos PRESENTES.
## Sem tracos, 1.0 — nao ha o que atrapalhar a captura.
static func multiplicador_evasao(criatura: Criatura, fatores: Dictionary) -> float:
	if criatura == null:
		return 1.0
	var m: float = 1.0
	for traco: String in fatores:
		if criatura.morfologia.get(traco, false):
			m *= float(fatores[traco])
	return m


## Vigor maximo — funcao deterministica dos atributos (RF03). E a VIDA da batalha
## (FichaCombate), e a fracao restante dela volta ao calculo de captura.
static func vigor_maximo(criatura: Criatura, cfg: Dictionary) -> float:
	if criatura == null:
		return float(cfg.get("base", 100.0))
	var v: float = float(cfg.get("base", 100.0))
	v += float(cfg.get("por_traco", 0.0)) * float(criatura.features_presentes().size())
	v += float(cfg.get("por_porte", {}).get(criatura.porte, 0.0))
	return maxf(v, 1.0)


## Faixa de estado correspondente a fracao de vigor restante (1.0 = intacta).
## As faixas vem do dado, em ordem da mais ferida para a mais intacta.
static func faixa_de_estado(fracao_vigor: float, faixas: Array) -> Dictionary:
	for faixa: Dictionary in faixas:
		if fracao_vigor <= float(faixa.get("vigor_ate", 1.0)):
			return faixa
	if faixas.is_empty():
		return {"id": "intacta", "multiplicador": 1.0, "rotulo": "intacta"}
	return faixas[faixas.size() - 1]


## Ficha da criatura do ponto de vista da captura, para a interface e para as
## metricas. Puro dado — quem desenha decide como mostrar.
static func perfil(criatura: Criatura, tabelas: TabelasCaptura) -> Dictionary:
	var fatores := tabelas.fatores_de_evasao()
	var tracos: Array = []
	for traco: String in fatores:
		if criatura != null and criatura.morfologia.get(traco, false):
			tracos.append({
				"traco": traco,
				"fator": float(fatores[traco]),
				"motivo": tabelas.motivo_do_traco(traco),
			})
	return {
		"evasao": multiplicador_evasao(criatura, fatores),
		"tracos": tracos,
		"vigor_maximo": vigor_maximo(criatura, tabelas.config_vigor()),
	}
