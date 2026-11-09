extends SceneTree

## Gerador v2 (Modo.CONDICIONADO_V2) e nota de coerencia por criatura:
##   godot --headless --path . -s res://tools/test_gerador_v2.gd
##
## O que importa primeiro: a v1 e o baseline continuam identicos, criatura por criatura.
## Os criterios estatisticos completos ficam em tools/comparar_bracos.gd, que e mais lento.

const SEED_A := 123456789
const N := 100
const V2 := GeradorCriaturas.Modo.CONDICIONADO_V2

## sha256 das 100 criaturas de to_dict(), medidos ANTES de a v2 existir.
const IMPRESSOES := [
	[123456789, GeradorCriaturas.Modo.CONDICIONADO, "dae9e4934694abe7dbadb3ee489d6ab20f523db30ac203136357f4e938fd6c81"],
	[123456789, GeradorCriaturas.Modo.INDEPENDENTE, "2af3378b8e2b5a55e052d2e304206cde49a65efb3f5df1bcd796cd0254665e0e"],
	[987654321, GeradorCriaturas.Modo.CONDICIONADO, "22a6c62bf50bf76493cb00c6597395920462a4dd80f0edffc4388781661cd44e"],
	[987654321, GeradorCriaturas.Modo.INDEPENDENTE, "516395537fe8077c67e10297fde42df5b25129bbbcf30c9b596a766101db0baa"],
	[42, GeradorCriaturas.Modo.CONDICIONADO, "1d2579d22456877ec6c240e39bb41193f6a3055a56bd61a0d420ab2250ec48b1"],
	[42, GeradorCriaturas.Modo.INDEPENDENTE, "64131939ab144248e2b8f0384969b59bb8b956c120959b4fb9bfd8f0cfd8c564"],
]

var _falhas: int = 0
var _total: int = 0
var _t: TabelasProbabilidade
var _g: GeradorCriaturas


func _initialize() -> void:
	print("== Gerador v2 ==")
	_t = TabelasProbabilidade.carregar()
	_g = GeradorCriaturas.new(_t, CatalogoCorpos.carregar(_t))
	_v1_intocada()
	_estratificacao()
	_reprodutibilidade()
	_cadeia()
	_nota()
	_metricas()
	print("\nRESULTADO: %s" % ("TODOS OS TESTES PASSARAM (%d)" % _total if _falhas == 0
			else "%d VERIFICACAO(OES) FALHARAM" % _falhas))
	quit(0 if _falhas == 0 else 1)


func _ok(cond: bool, nome: String, detalhe: String = "") -> void:
	_total += 1
	if not cond:
		_falhas += 1
	print("    %s %s%s" % ["OK  " if cond else "FALHOU", nome, ("  - " + detalhe) if detalhe != "" else ""])


func _impressao(bestiario: Array) -> String:
	var linhas := PackedStringArray()
	for c: Criatura in bestiario:
		linhas.append(JSON.stringify(c.to_dict(), "", true))
	return "\n".join(linhas).sha256_text()


func _v1_intocada() -> void:
	print("\nv1 e baseline identicos aos de antes da v2 (RF03)")
	for caso: Array in IMPRESSOES:
		_ok(_impressao(_g.gerar_bestiario(caso[0], N, caso[1])) == caso[2],
				"seed %d, %s" % [caso[0], GeradorCriaturas.nome_do_modo(caso[1])])


func _pares(bestiario: Array) -> Dictionary:
	var pares: Dictionary = {}
	for c: Criatura in bestiario:
		var chave: String = c.elemento + "|" + c.animal_base
		pares[chave] = int(pares.get(chave, 0)) + 1
	return pares


func _estratificacao() -> void:
	print("\nBestiario estratificado")
	var todas: bool = true
	for i in 200:
		if _pares(_g.gerar_bestiario(1000 + i * 7919, N, V2)).size() != 64:
			todas = false
	_ok(todas, "os 64 pares em 200 seeds")
	var cem := _g.gerar_bestiario(SEED_A, N, V2)
	_ok(cem.size() == N, "tamanho pedido")
	var ids_ok: bool = true
	for i in N:
		if cem[i].id != i:
			ids_ok = false
	_ok(ids_ok, "ids em sequencia")
	var pequena := _pares(_g.gerar_bestiario(SEED_A, 30, V2))
	_ok(pequena.size() == 30, "com menos de 64, sem par repetido", str(pequena.size()))
	var pares_ordem: Array = []
	for c: Criatura in cem.slice(0, 8):
		pares_ordem.append(c.elemento)
	_ok(pares_ordem.count(pares_ordem[0]) < 8, "a ordem e embaralhada")


func _reprodutibilidade() -> void:
	print("\nReprodutibilidade")
	var a := _impressao(_g.gerar_bestiario(SEED_A, N, V2))
	seed(987)  # o estado global nao pode influir
	randi()
	_ok(a == _impressao(_g.gerar_bestiario(SEED_A, N, V2)), "mesma seed, mesmo bestiario")
	_ok(a != _impressao(_g.gerar_bestiario(SEED_A + 1, N, V2)), "seed diferente, bestiario diferente")
	var t0 := Time.get_ticks_usec()
	_g.gerar_bestiario(SEED_A, N, V2)
	var ms := (Time.get_ticks_usec() - t0) / 1000.0
	_ok(ms < 2000.0, "menos de 2 s", "%.2f ms" % ms)
	_ok(GeradorCriaturas.modo_do_nome("condicionado_v2") == V2, "nome e modo se correspondem")
	_ok(GeradorCriaturas.modo_do_nome("outra_coisa") == -1, "nome desconhecido e recusado")


func _cadeia() -> void:
	print("\nCadeia de tracos e porte por animal")
	var sem_nada: float = _t.prob_feature_v2("roedor", "planta", "garras", {})
	_ok(is_equal_approx(sem_nada, 0.45 - 0.05 + 0.15), "sem traco anterior, soma o efeito", str(sem_nada))
	var com_asas: float = _t.prob_feature_v2("roedor", "planta", "garras", {"asas": true})
	_ok(is_equal_approx(com_asas, 0.40), "com traco anterior, nao soma", str(com_asas))
	var cheia: Dictionary = {"garras": true, "escamas": true, "asas": false, "nadadeiras": false}
	_ok(is_equal_approx(_t.prob_feature_v2("gato", "fogo", "asas", cheia),
			_t.prob_feature_v2("gato", "fogo", "asas", {})),
			"so contam os tracos ANTES na cadeia")
	var roedor := _t.pesos_porte_v2("roedor", "terra")
	var reptil := _t.pesos_porte_v2("reptil", "terra")
	_ok(float(roedor[0]) / float(roedor[3]) > float(reptil[0]) / float(reptil[3]),
			"o porte agora depende do animal")
	var ordem_ok: bool = true
	for c: Criatura in _g.gerar_bestiario(SEED_A, N, V2):
		if c.morfologia.keys() != _t.features_morfologia():
			ordem_ok = false
	_ok(ordem_ok, "morfologia na ordem do vocabulario")


func _nota() -> void:
	print("\nNota de coerencia")
	# A soma das probabilidades de todos os perfis de presenca tem de dar 1.
	var soma: float = 0.0
	var fs: Array = _t.features_morfologia()
	for m in 16:
		var c := Criatura.new()
		c.animal_base = "peixe"
		c.elemento = "agua"
		c.porte = "medio"
		c.paleta = "fria"
		c.matiz = "azul"
		c.morfologia = {}
		for i in fs.size():
			var presente: bool = (m >> i) & 1 == 1
			c.morfologia[fs[i]] = presente
			if presente:
				c.variantes[fs[i]] = 0
		var p: float = 1.0
		for l: Dictionary in NotaCoerencia.decompor(c, _t, true)["linhas"]:
			if fs.has(l["atributo"]):
				p *= float(l["p"])
		soma += p
	_ok(absf(soma - 1.0) < 1e-6, "a cadeia e uma distribuicao: os 16 perfis somam 1", str(soma))
	var v2 := NotaCoerencia.resumo(_g.gerar_bestiario(SEED_A, 2000, V2), _t, true)
	var ind := NotaCoerencia.resumo(_g.gerar_bestiario(SEED_A, 2000,
			GeradorCriaturas.Modo.INDEPENDENTE), _t, true)
	_ok(float(ind["media_bits"]) > float(v2["media_bits"]) * 1.5, "o sorteio independente surpreende bem mais",
			"%.2f vs %.2f bits" % [ind["media_bits"], v2["media_bits"]])
	_ok(float(v2["atipicas_pct"]) < 0.2 and float(ind["atipicas_pct"]) > 0.8, "atipicas: poucas na v2, quase todas no sorteio",
			"%.1f%% vs %.1f%%" % [float(v2["atipicas_pct"]) * 100.0, float(ind["atipicas_pct"]) * 100.0])
	var antes := _impressao(_g.gerar_bestiario(SEED_A, N, V2))
	var cem := _g.gerar_bestiario(SEED_A, N, V2)
	for c: Criatura in cem:
		NotaCoerencia.surpresa(c, _t, true)
	_ok(antes == _impressao(cem), "calcular a nota nao muda o bestiario")
	_ok(NotaCoerencia.usa_v2(cem[0]), "a criatura sabe de que modelo veio")


func _metricas() -> void:
	print("\nMetricas com a regua do modelo")
	var v2 := MetricasCoerencia.avaliar(_g.gerar_bestiario(SEED_A, 400, V2), _t)
	_ok(float(v2["moda"]["eficiencia_pct"]) > 0.9, "a v2 entrega o que as proprias tabelas prometem",
			"%.1f%%" % (float(v2["moda"]["eficiencia_pct"]) * 100.0))
	_ok(v2["modo"] == "condicionado_v2", "o modo sai no relatorio")
	_ok(v2.has("nota"), "o relatorio traz a nota")
	var ind := MetricasCoerencia.avaliar(_g.gerar_bestiario(SEED_A, 400,
			GeradorCriaturas.Modo.INDEPENDENTE), _t, 3, MetricasCoerencia.MODELO_V2)
	_ok(float(v2["moda"]["porte"]["obs"]) > float(ind["moda"]["porte"]["obs"]),
			"baseline medido pela mesma regua fica abaixo")
	# Saves: novo nasce v2; antigo le como v1; desconhecido e recusado.
	var nova := DadosPartida.nova(SEED_A, "")
	_ok(nova.modelo_gerador == "condicionado_v2", "partida nova nasce no modelo do jogo")
	var bruto := nova.para_dicionario()
	_ok(DadosPartida.de_dicionario(bruto).modelo_gerador == "condicionado_v2", "o modelo volta do save")
	bruto["mundo"].erase("modelo_gerador")
	_ok(DadosPartida.de_dicionario(bruto).modelo_gerador == "condicionado", "save antigo continua na v1")
	bruto["mundo"]["modelo_gerador"] = "v9"
	_ok(not DadosPartida.de_dicionario(bruto).valido(), "modelo desconhecido e recusado")
