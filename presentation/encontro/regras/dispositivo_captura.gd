class_name DispositivoCaptura
extends ItemCaptura

## Um dispositivo de captura, lido de data/captura/dispositivos.json.
##
## O que o torna interessante nao e o multiplicador geral, e a EFICACIA POR TRACO:
## a rede fecha sobre asas mas se rasga em garras, a redoma vence escamas e
## nadadeiras. Como os tracos da criatura sao sorteados por probabilidade
## condicionada aos primarios (RF04), escolher o dispositivo certo e, na pratica,
## ler a coerencia semantica que o gerador produziu — 'agua + peixe' aparece
## escamado e com nadadeiras, e pede a redoma.

## Ganho geral, aplicado sempre.
var multiplicador: float = 1.0

## Ganho (>1) ou perda (<1) contra cada traco, aplicado SO se a criatura o possui.
## Traco ausente do dicionario vale 1.0 — dispositivo neutro naquele traco.
var eficacia_por_traco: Dictionary = {}


static func de_dicionario(d: Dictionary) -> DispositivoCaptura:
	var dispositivo := DispositivoCaptura.new()
	dispositivo._ler_comuns(d)
	dispositivo.multiplicador = float(d.get("multiplicador", 1.0))
	dispositivo.eficacia_por_traco = d.get("eficacia_por_traco", {})
	return dispositivo


## Multiplicador total deste dispositivo contra uma criatura concreta.
func multiplicador_contra(criatura: Criatura) -> float:
	var m: float = multiplicador
	for traco: String in eficacia_por_traco:
		if criatura != null and criatura.morfologia.get(traco, false):
			m *= float(eficacia_por_traco[traco])
	return m


## Tracos em que este dispositivo e bom ou ruim, para a ficha da roda.
func detalhe(criatura: Criatura) -> String:
	if eficacia_por_traco.is_empty():
		return "uso geral"
	var fortes := PackedStringArray()
	var fracos := PackedStringArray()
	for traco: String in eficacia_por_traco:
		var e: float = float(eficacia_por_traco[traco])
		# Marca com '*' o traco que ESTA criatura de fato tem: e a diferenca entre
		# a ficha do item e a leitura da criatura na frente do jogador.
		var marca: String = "*" if criatura != null and criatura.morfologia.get(traco, false) else ""
		if e > 1.0:
			fortes.append(traco + marca)
		elif e < 1.0:
			fracos.append(traco + marca)
	var partes := PackedStringArray()
	if not fortes.is_empty():
		partes.append("bom vs " + ", ".join(fortes))
	if not fracos.is_empty():
		partes.append("ruim vs " + ", ".join(fracos))
	return "  ·  ".join(partes)
