class_name ColecaoSeed
extends RefCounted

## A colecao do jogador num mundo (uma seed): marcos do bestiario e o resumo da seed.
##
## O gancho de "jogar de novo" do jogo. Cada seed gera um bestiario novo, com as suas
## raras e as suas lendarias (RaridadeSorteio); registrar especies da itens nos marcos,
## e a vitoria mostra quanto do mundo foi visto e convida a outra seed. Sem estado
## proprio: tudo sai da colecao do inventario, que o save ja guarda — um marco nao se
## repete ao carregar porque so e dado quando a contagem CRUZA o numero.

## Meta no autoload Save: o menu principal abre direto em "novo jogo" (OUTRA SEED).
const META_OUTRA_SEED := "abrir_nova_partida"


## Marcos cujo numero de especies foi alcancado ao passar de `antes` para `depois`.
static func marcos_cruzados(raridade: RaridadeSorteio, antes: int, depois: int) -> Array:
	var saida: Array = []
	if raridade == null:
		return saida
	for m: Dictionary in raridade.marcos:
		var n: int = int(m.get("especies", 0))
		if antes < n and n <= depois:
			saida.append(m)
	return saida


## Entrega o marco na bolsa e devolve o que foi dado, por extenso ("2 Esfera
## Reforçada e 40 gold"). `bolsa` e o autoload Bolsa (ganhar_gold, adicionar, item).
static func entregar(marco: Dictionary, bolsa: Node) -> String:
	var partes := PackedStringArray()
	var itens: Dictionary = marco.get("itens", {})
	for id: String in itens:
		var dados: int = bolsa.adicionar(id, int(itens[id]))
		if dados > 0:
			var item: ItemJogo = bolsa.item(id)
			partes.append("%d %s" % [dados, item.nome if item != null else id])
	var gold: int = int(marco.get("gold", 0))
	if gold > 0:
		bolsa.ganhar_gold(gold)
		partes.append("%d gold" % gold)
	if partes.is_empty():
		return "a honra"
	if partes.size() == 1:
		return partes[0]
	return ", ".join(partes.slice(0, partes.size() - 1)) + " e " + partes[partes.size() - 1]


## Registradas de cada nivel contra o total do bestiario. `capturada`:
## Callable(Criatura) -> bool, a mesma pergunta que o bestiario (N) faz.
static func contagem(bestiario: Array, capturada: Callable,
		raridade: RaridadeSorteio) -> Dictionary:
	var c := {"registradas": 0, "total": bestiario.size(), "raras": 0, "raras_total": 0,
			"lendarias": 0, "lendarias_total": 0}
	for criatura: Criatura in bestiario:
		var niv: String = raridade.nivel(criatura) if raridade != null else RaridadeSorteio.COMUM
		var tem: bool = capturada.is_valid() and bool(capturada.call(criatura))
		if tem:
			c["registradas"] += 1
		if niv == RaridadeSorteio.RARA:
			c["raras_total"] += 1
			c["raras"] += 1 if tem else 0
		elif niv == RaridadeSorteio.LENDARIA:
			c["lendarias_total"] += 1
			c["lendarias"] += 1 if tem else 0
	return c


## Uma linha para o cabecalho do bestiario e para a vitoria.
static func linha_de_colecao(c: Dictionary) -> String:
	return "REGISTRADAS %d/%d  ·  RARAS %d/%d  ·  LENDÁRIAS %d/%d" % [c["registradas"],
			c["total"], c["raras"], c["raras_total"], c["lendarias"], c["lendarias_total"]]


## Texto da tela de vitoria: a seed, o que o jogador viu dela e quanto ela e coerente
## contra o sorteio independente da mesma seed (RF08). Coerencia por moda, a medida que
## vale em n=100: a informacao mutua exige n >= 5000 (procedural/creatures/README.md).
## `encontros` e o GerenciadorEncontro, sem o tipo: ele cita a camera, que cita o
## autoload Opcoes, e o teste headless (-s) desta classe nao teria como compilar.
static func texto_de_vitoria(encontros: Node, seed_do_mundo: int,
		nome_seed: String, tempo: String) -> String:
	var n: int = encontros.bestiario.size()
	var ger := GeradorCriaturas.new(encontros.tabelas, encontros.catalogo)
	var cond := MetricasCoerencia.avaliar(encontros.bestiario, encontros.tabelas)
	# O baseline e medido com a regua do modelo desta partida: as duas colunas comparam
	# a mesma coisa.
	var indep := MetricasCoerencia.avaliar(
			ger.gerar_bestiario(seed_do_mundo, n, GeradorCriaturas.Modo.INDEPENDENTE),
			encontros.tabelas, MetricasCoerencia.K_UNICIDADE_PADRAO,
			GeradorCriaturas.nome_do_modo(encontros.modo_gerador))
	var c := contagem(encontros.bestiario, encontros.inventario.ja_capturou, encontros.raridade)
	var faltam: int = int(c["lendarias_total"]) - int(c["lendarias"])
	var convite: String = ("Ainda há %d lendária%s escondida%s neste mundo. Cada seed sorteia "
			+ "outras.") % [faltam, "s" if faltam != 1 else "", "s" if faltam != 1 else ""] \
			if faltam > 0 else "Você achou todas as lendárias desta seed! Outra seed, outro bestiário."
	return ("SEED  %s\nTEMPO  %s\n%s\nCRIATURAS DISTINTAS  %d\n\nCOERÊNCIA DO BESTIÁRIO\n"
			+ "  esta seed: %.0f%%\n  sorteio independente: %.0f%%\n\n%s") % [
		nome_seed, tempo, linha_de_colecao(c), int(cond["unicidade"]["distintas"]),
		coerencia_media(cond) * 100.0, coerencia_media(indep) * 100.0, convite]


static func coerencia_media(metricas: Dictionary) -> float:
	var soma: float = 0.0
	for dim: String in MetricasCoerencia.DIMENSOES_MODA:
		soma += float(metricas["moda"][dim]["obs"])
	return soma / MetricasCoerencia.DIMENSOES_MODA.size()
