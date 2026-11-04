class_name CalculoCaptura
extends RefCounted

## Ponto UNICO onde a chance de captura e decidida. Interface, roda, gerenciador e
## testes chamam esta classe; nenhum deles recalcula nada por conta propria.
##
##   p = clamp(base * disp * afinidade * isca * estado, piso, teto)
##
## Produto, e nao soma, pelo mesmo motivo pelo qual as tabelas do gerador sao
## condicionais e nao aditivas: cada fator responde por uma pergunta independente
## e deve poder ANULAR o ganho dos outros. Uma rede contra garras (0.80) tem de
## estragar o lance mesmo com a isca certa; com soma, bastaria acumular bonus.
##
## Os quatro fatores, e de onde vem cada um:
##   disp       DispositivoCaptura     geral x eficacia contra os tracos presentes
##   afinidade  AfinidadeCriatura      evasao dos tracos que o gerador sorteou
##   isca       IscaCaptura            preferencia pelo animal_base (primario)
##   estado     faixa de vigor         consequencia mecanica de "Atacar"
##
## O teto (0.85) impede captura garantida mesmo com tudo certo; o piso (0.03)
## impede criatura impossivel. Sao os mesmos clamps que conditional_morphology.json
## aplica na geracao, pela mesma razao: manter o sistema estocastico nas pontas.

## Chance e decomposicao dos fatores. Devolve o detalhamento junto porque a
## interface EXIBE o porque — mostrar so o numero final esconderia exatamente a
## correlacao que o trabalho quer evidenciar.
##
## Retorno: {
##   p, base, piso, teto, sem_limite,
##   fatores: [{rotulo, valor, nota}]      (na ordem em que multiplicam)
## }
static func avaliar(criatura: Criatura, dispositivo: DispositivoCaptura,
		isca: IscaCaptura, fracao_vigor: float, tabelas: TabelasCaptura) -> Dictionary:
	var base: float = tabelas.chance_base()
	var fatores: Array = []

	var m_disp: float = 1.0
	if dispositivo != null:
		m_disp = dispositivo.multiplicador_contra(criatura)
		fatores.append({
			"rotulo": "dispositivo",
			"valor": m_disp,
			"nota": dispositivo.nome,
		})

	var m_afin: float = AfinidadeCriatura.multiplicador_evasao(
			criatura, tabelas.fatores_de_evasao())
	var presentes: Array = criatura.features_presentes() if criatura != null else []
	fatores.append({
		"rotulo": "afinidade",
		"valor": m_afin,
		"nota": ", ".join(presentes) if not presentes.is_empty() else "sem apêndices",
	})

	var m_isca: float = 1.0
	if isca != null:
		m_isca = isca.multiplicador_contra(criatura, tabelas.bonus_de_isca_incorreta())
		fatores.append({
			"rotulo": "isca",
			"valor": m_isca,
			"nota": isca.nome + ("" if isca.preferida_por(criatura) else " (não preferida)"),
		})

	var faixa := AfinidadeCriatura.faixa_de_estado(fracao_vigor, tabelas.faixas_de_estado())
	var m_estado: float = float(faixa.get("multiplicador", 1.0))
	fatores.append({
		"rotulo": "estado",
		"valor": m_estado,
		"nota": String(faixa.get("rotulo", "")),
	})

	var sem_limite: float = base * m_disp * m_afin * m_isca * m_estado
	return {
		"p": clampf(sem_limite, tabelas.piso(), tabelas.teto()),
		"base": base,
		"piso": tabelas.piso(),
		"teto": tabelas.teto(),
		"sem_limite": sem_limite,
		"estado": faixa,
		"fatores": fatores,
	}


## Atalho para quem so quer o numero (roda de selecao, ordenacao).
static func chance(criatura: Criatura, dispositivo: DispositivoCaptura,
		isca: IscaCaptura, fracao_vigor: float, tabelas: TabelasCaptura) -> float:
	return float(avaliar(criatura, dispositivo, isca, fracao_vigor, tabelas)["p"])


## Resolve uma tentativa. O RNG entra EXPLICITO, nunca o estado global: e a mesma
## exigencia que o gerador cumpre (RF03), estendida ao jogo — dada a mesma seed e a
## mesma sequencia de acoes, a partida se repete lance a lance.
static func tentar(rng: RandomNumberGenerator, criatura: Criatura,
		dispositivo: DispositivoCaptura, isca: IscaCaptura, fracao_vigor: float,
		tabelas: TabelasCaptura) -> Dictionary:
	var resultado := avaliar(criatura, dispositivo, isca, fracao_vigor, tabelas)
	var sorteio: float = rng.randf()
	resultado["sorteio"] = sorteio
	resultado["sucesso"] = sorteio < float(resultado["p"])
	return resultado
