extends SceneTree

## Colecao: raridade do sorteio, marcos e contagem do bestiario.
##   godot --headless --path . -s res://tools/test_colecao.gd

const V2 := GeradorCriaturas.Modo.CONDICIONADO_V2

var _falhas: int = 0
var _total: int = 0


func _initialize() -> void:
	print("== Colecao: raridade e marcos ==")
	var t := TabelasProbabilidade.carregar()
	var g := GeradorCriaturas.new(t, CatalogoCorpos.carregar(t))
	var lendarias_vistas: Dictionary = {}
	for semente: int in [123456789, 987654321, 42]:
		var bes: Array = g.gerar_bestiario(semente, 100, V2)
		var r := RaridadeSorteio.do_bestiario(bes, t)
		var n: Dictionary = r.contagem(bes)
		var atipicas: int = 0
		var menor_lendaria: float = INF
		var maior_nao_lendaria: float = -INF
		for c: Criatura in bes:
			var bits: float = NotaCoerencia.surpresa(c, t, true)
			if NotaCoerencia.atipica(bits, t):
				atipicas += 1
			if r.nivel(c) == RaridadeSorteio.LENDARIA:
				menor_lendaria = minf(menor_lendaria, bits)
				lendarias_vistas[str(semente) + ":" + str(c.id)] = true
			else:
				maior_nao_lendaria = maxf(maior_nao_lendaria, bits)
		print("   seed %d: %d comuns, %d raras, %d lendarias (%d atipicas)"
				% [semente, n["comum"], n["rara"], n["lendaria"], atipicas])
		_ok(n["comum"] + n["rara"] + n["lendaria"] == bes.size(), "toda criatura tem um nivel")
		_ok(n["rara"] + n["lendaria"] == atipicas, "raras + lendarias = atipicas do modelo")
		_ok(n["lendaria"] == mini(r.lendarias_por_seed, atipicas),
				"lendarias = as %d maiores surpresas" % r.lendarias_por_seed)
		_ok(menor_lendaria >= maior_nao_lendaria, "nenhuma nao-lendaria mais improvavel que uma lendaria")
		_ok(n["rara"] >= 3 and n["rara"] <= 20, "raras sao poucas, mas existem (%d)" % n["rara"])
		var r2 := RaridadeSorteio.do_bestiario(g.gerar_bestiario(semente, 100, V2), t)
		var iguais: bool = true
		for c: Criatura in bes:
			iguais = iguais and r2.nivel(c) == r.nivel(c)
		_ok(iguais, "mesma seed, mesmas raras e lendarias (RF03)")

	# Classificar nao muda o bestiario nem consome RNG do gerador.
	var antes: Array = g.gerar_bestiario(42, 100, V2)
	RaridadeSorteio.do_bestiario(antes, t)
	var depois: Array = g.gerar_bestiario(42, 100, V2)
	var mesmo: bool = antes.size() == depois.size()
	for i in mini(antes.size(), depois.size()):
		mesmo = mesmo and antes[i].to_dict() == depois[i].to_dict()
	_ok(mesmo, "a raridade le o bestiario sem altera-lo")

	var r := RaridadeSorteio.do_bestiario([], t)
	_ok(not r.marcos.is_empty(), "marcos lidos de data/captura/colecao.json")
	_ok(ColecaoSeed.marcos_cruzados(r, 2, 3).size() == 1
			and int(ColecaoSeed.marcos_cruzados(r, 2, 3)[0]["especies"]) == 3,
			"cruzar 3 especies da o marco de 3")
	_ok(ColecaoSeed.marcos_cruzados(r, 3, 4).is_empty(), "marco nao se repete depois de cruzado")
	_ok(ColecaoSeed.marcos_cruzados(r, 0, 100).size() == r.marcos.size(), "pular tudo da todos")
	_ok(RaridadeSorteio._milhar(1234567) == "1.234.567" and RaridadeSorteio._milhar(42) == "42",
			"milhar com ponto")

	var bes: Array = g.gerar_bestiario(123456789, 100, V2)
	var inv := InventarioJogador.new()
	inv.guardar_criatura(bes[0])
	inv.guardar_criatura(bes[0])
	inv.guardar_criatura(bes[5])
	_ok(inv.especies_registradas() == 2, "capturar de novo nao conta especie nova")
	var c := ColecaoSeed.contagem(bes, inv.ja_capturou, RaridadeSorteio.do_bestiario(bes, t))
	_ok(c["registradas"] == 2 and c["total"] == 100, "contagem: 2 de 100 registradas")
	var linha := ColecaoSeed.linha_de_colecao(c)
	_ok(linha.begins_with("REGISTRADAS 2/100"), linha)
	var faltando := PackedStringArray()
	for fonte: FontFile in [TemaEncontro.fonte(), TemaEncontro.fonte_titulo(),
			TemaEncontro.fonte_cartaz()]:
		var amostra: String = linha + r.texto("nova_especie") + r.texto("cartaz_lendaria") \
				+ r.texto("cartaz_rara") + r.texto("abertura_lendaria") + r.texto("abertura_rara") \
				+ r.texto("marco") + r.texto("registradas") + "1 em 1.234 mi"
		for i in amostra.length():
			var ch: String = amostra[i]
			if not fonte.has_char(ch.unicode_at(0)) and not ch in faltando:
				faltando.append(ch)
	_ok(faltando.is_empty(), "a fonte cobre os textos da colecao", " ".join(faltando))

	print("\nRESULTADO: %s" % ("TODOS OS TESTES PASSARAM (%d)" % _total if _falhas == 0
			else "%d VERIFICACAO(OES) FALHARAM" % _falhas))
	quit(0 if _falhas == 0 else 1)


func _ok(cond: bool, nome: String, detalhe: String = "") -> void:
	_total += 1
	if not cond:
		_falhas += 1
	print("    %s %s  %s" % ["OK  " if cond else "FALHOU", nome, detalhe])
