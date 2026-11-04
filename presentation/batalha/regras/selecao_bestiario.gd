class_name SelecaoBestiario
extends RefCounted

## Escolhe criaturas JA GERADAS: as iniciais e as equipes de guardiao. Nao sorteia:
## o resultado e funcao do bestiario, e portanto da seed (RF03). Seed diferente da
## guardiao diferente, e o percentil mantem a dificuldade parecida em qualquer seed.


## Bestiario em ordem crescente de forca; empate pelo id. Com `elementos`, so os dali.
static func por_forca(bestiario: Array, tabelas: TabelasBatalha,
		elementos: Array = []) -> Array:
	var linhas: Array = []
	for c: Criatura in bestiario:
		if elementos.is_empty() or c.elemento in elementos:
			linhas.append({"c": c, "f": FichaCombate.de_criatura(c, tabelas).forca(tabelas)})
	linhas.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if not is_equal_approx(float(a["f"]), float(b["f"])):
			return float(a["f"]) < float(b["f"])
		return (a["c"] as Criatura).id < (b["c"] as Criatura).id)
	var saida: Array = []
	for l: Dictionary in linhas:
		saida.append(l["c"])
	return saida


## As opcoes da escolha inicial: na faixa central de forca, com ao menos um traco
## (e o primeiro contato do jogador com o gerador) e com elementos diferentes.
static func iniciais(bestiario: Array, tabelas: TabelasBatalha) -> Array:
	var cfg: Dictionary = tabelas.iniciais()
	var n: int = int(cfg.get("quantidade", 3))
	var ordenados := por_forca(bestiario, tabelas)
	if ordenados.is_empty():
		return []
	var de: int = floori(float(cfg.get("percentil_min", 0.35)) * (ordenados.size() - 1))
	var ate: int = ceili(float(cfg.get("percentil_max", 0.65)) * (ordenados.size() - 1))
	var faixa: Array = ordenados.slice(de, ate + 1)
	faixa.sort_custom(func(a: Criatura, b: Criatura) -> bool: return a.id < b.id)

	var saida: Array = []
	# Do criterio mais exigente para o mais frouxo: uma seed estranha nao pode deixar o
	# jogador sem opcoes.
	for exige_traco: bool in [true, false]:
		for c: Criatura in faixa:
			if saida.size() >= n:
				return saida
			if c in saida or (exige_traco and c.features_presentes().is_empty()):
				continue
			if not _tem_elemento(saida, c.elemento):
				saida.append(c)
	for c: Criatura in ordenados:
		if saida.size() >= n:
			break
		if not c in saida:
			saida.append(c)
	return saida


## A equipe de um guardiao: a criatura no percentil pedido dentro dos elementos da
## regiao e as vizinhas logo abaixo dela. Elementos insuficientes nesta seed: usa o
## bestiario inteiro, para o guardiao nunca ficar sem equipe.
static func equipe_guardiao(bestiario: Array, tabelas: TabelasBatalha, elementos: Array,
		tamanho: int, percentil: float) -> Array:
	var ordenados := por_forca(bestiario, tabelas, elementos)
	if ordenados.size() < tamanho:
		ordenados = por_forca(bestiario, tabelas)
	if ordenados.is_empty():
		return []
	var i: int = clampi(roundi(percentil * (ordenados.size() - 1)), 0, ordenados.size() - 1)
	var saida: Array = []
	var passo: int = 0
	while saida.size() < mini(tamanho, ordenados.size()):
		var abaixo: int = i - passo
		var acima: int = i + passo
		if abaixo >= 0 and not ordenados[abaixo] in saida:
			saida.append(ordenados[abaixo])
		elif acima < ordenados.size() and not ordenados[acima] in saida:
			saida.append(ordenados[acima])
		passo += 1
	return saida


static func _tem_elemento(lista: Array, elemento: String) -> bool:
	for c: Criatura in lista:
		if c.elemento == elemento:
			return true
	return false
