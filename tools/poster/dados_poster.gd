extends SceneTree

## Mede os numeros do poster e grava docs/poster/dados.json. Tudo sai do gerador real:
##   godot --headless --path . -s res://tools/poster/dados_poster.gd
## Os graficos (tools/poster/gerar_poster.py) so desenham o que este arquivo mediu.

const SAIDA := "res://docs/poster/dados.json"
const SEED := 123456789
const N := 5000
const SEEDS_IM := 10
const BRACOS := {
	"independente": GeradorCriaturas.Modo.INDEPENDENTE,
	"v1": GeradorCriaturas.Modo.CONDICIONADO,
	"v2": GeradorCriaturas.Modo.CONDICIONADO_V2,
}


func _initialize() -> void:
	var t := TabelasProbabilidade.carregar()
	var ger := GeradorCriaturas.new(t, CatalogoCorpos.carregar(t))
	var features: Array = t.features_morfologia()
	var dados: Dictionary = {
		"seed": SEED, "n": N, "seeds_informacao_mutua": SEEDS_IM,
		"vocabulario": t.vocabulary,
		"informacao_mutua": {}, "matiz_por_elemento": {}, "traco_por_animal": {},
		"moda": {}, "surpresa": {}, "cobertura": {}, "tabela": {},
	}
	for nome: String in BRACOS:
		var modo: int = BRACOS[nome]
		var soma: Dictionary = {}
		for i in SEEDS_IM:
			var im := MetricasCoerencia.avaliar_info_mutua(
					ger.gerar_bestiario(SEED + i * 15485863, N, modo), features)
			for par: String in im:
				soma[par] = float(soma.get(par, 0.0)) + float(im[par]["i_bits"]) / SEEDS_IM
		dados["informacao_mutua"][nome] = soma

		var bes: Array = ger.gerar_bestiario(SEED, N, modo)
		dados["matiz_por_elemento"][nome] = _contar(bes, "elemento", "matiz")
		dados["traco_por_animal"][nome] = _tracos(bes, features)
		var moda := MetricasCoerencia._avaliar_moda(bes, t, features, true)
		dados["moda"][nome] = {}
		for dim: String in MetricasCoerencia.DIMENSOES_MODA:
			dados["moda"][nome][dim] = moda[dim]["obs"]
		var bits: Array = []
		var atipicas: int = 0
		for c: Criatura in bes:
			var b := NotaCoerencia.surpresa(c, t, true)
			bits.append(b)
			if NotaCoerencia.atipica(b, t):
				atipicas += 1
		dados["surpresa"][nome] = {"bits": bits, "atipicas": float(atipicas) / N}
		var pares: float = 0.0
		for i in 100:
			var vistos: Dictionary = {}
			for c: Criatura in ger.gerar_bestiario(SEED + i * 7919, 100, modo):
				vistos[c.elemento + "|" + c.animal_base] = true
			pares += vistos.size()
		dados["cobertura"][nome] = pares / 100.0

	for f: String in features:
		dados["tabela"][f] = {}
		for a: String in t.animais():
			dados["tabela"][f][a] = {}
			for e: String in t.elementos():
				dados["tabela"][f][a][e] = t.prob_feature(a, e, f)
	var t0 := Time.get_ticks_usec()
	for i in 20:
		ger.gerar_bestiario(SEED + i, 100, GeradorCriaturas.Modo.CONDICIONADO_V2)
	dados["ms_por_bestiario"] = (Time.get_ticks_usec() - t0) / 1000.0 / 20.0
	dados["limiar_atipica_bits"] = t.limiar_atipica_bits()

	var arq := FileAccess.open(SAIDA, FileAccess.WRITE)
	arq.store_string(JSON.stringify(dados))
	arq.close()
	print("ok  ", ProjectSettings.globalize_path(SAIDA),
			"  %.2f ms por bestiario" % dados["ms_por_bestiario"])
	quit(0)


func _contar(bes: Array, campo_x: String, campo_y: String) -> Dictionary:
	var saida: Dictionary = {}
	for c: Criatura in bes:
		var x := str(c.get(campo_x))
		var y := str(c.get(campo_y))
		if not saida.has(x):
			saida[x] = {}
		saida[x][y] = int(saida[x].get(y, 0)) + 1
	return saida


func _tracos(bes: Array, features: Array) -> Dictionary:
	var total: Dictionary = {}
	var com: Dictionary = {}
	for c: Criatura in bes:
		total[c.animal_base] = int(total.get(c.animal_base, 0)) + 1
		if not com.has(c.animal_base):
			com[c.animal_base] = {}
		for f: String in features:
			if c.morfologia.get(f, false):
				com[c.animal_base][f] = int(com[c.animal_base].get(f, 0)) + 1
	var saida: Dictionary = {}
	for a: String in total:
		saida[a] = {}
		for f: String in features:
			saida[a][f] = float(com.get(a, {}).get(f, 0)) / float(total[a])
	return saida
