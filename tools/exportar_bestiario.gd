extends SceneTree

## Exporta o bestiario completo + metricas em JSON, para analise estatistica
## externa (tools/analise.py). A estatistica e os graficos do artigo NAO rodam
## dentro da engine — o Godot so produz os dados.
##
##   godot --headless -s res://tools/exportar_bestiario.gd -- [opcoes]
##
## Opcoes (todas com padrao):
##   --seed <int>    seed do mundo                      (padrao 123456789)
##   --n <int>       tamanho do bestiario               (padrao 100)
##   --k <int>       limiar de Hamming para unicidade   (padrao 3)
##   --out <path>    arquivo de saida                   (padrao user://bestiario.json)
##   --independent   exporta APENAS o baseline (hipotese nula), sem o condicionado
##
## Por padrao exporta os DOIS modos na mesma seed (pareados), que e o formato que
## a analise espera. --independent existe para inspecionar o baseline isolado.

const PADROES := {
	"seed": 123456789,
	"n": 100,
	"k": MetricasCoerencia.K_UNICIDADE_PADRAO,
	"out": "user://bestiario.json",
}


func _initialize() -> void:
	var opts := _parse_args(OS.get_cmdline_user_args())
	if opts.get("_erro", "") != "":
		printerr("Argumento invalido: ", opts["_erro"])
		quit(2)
		return

	var tabelas := TabelasProbabilidade.carregar()
	if tabelas == null:
		printerr("Falha ao carregar as tabelas de res://data/.")
		quit(1)
		return

	var gerador := GeradorCriaturas.new(tabelas)
	var world_seed: int = opts["seed"]
	var n: int = opts["n"]
	var k: int = opts["k"]
	var so_baseline: bool = opts.get("independent", false)

	var saida: Dictionary = {
		"_meta": {
			"gerado_por": "tools/exportar_bestiario.gd",
			"engine": Engine.get_version_info()["string"],
			"world_seed": world_seed,
			"n": n,
			"k_unicidade": k,
			"apenas_baseline": so_baseline,
			"vocabulario": tabelas.vocabulary,
		},
	}

	if not so_baseline:
		var t0 := Time.get_ticks_usec()
		var cond := gerador.gerar_bestiario(world_seed, n, GeradorCriaturas.Modo.CONDICIONADO)
		saida["_meta"]["tempo_geracao_ms"] = (Time.get_ticks_usec() - t0) / 1000.0
		saida["condicionado"] = {
			"criaturas": _serializar(cond),
			"metricas": MetricasCoerencia.avaliar(cond, tabelas, k),
		}

	if not so_baseline:
		var v2 := gerador.gerar_bestiario(world_seed, n, GeradorCriaturas.Modo.CONDICIONADO_V2)
		saida["condicionado_v2"] = {
			"criaturas": _serializar(v2),
			"metricas": MetricasCoerencia.avaliar(v2, tabelas, k),
		}

	var base := gerador.gerar_bestiario(world_seed, n, GeradorCriaturas.Modo.INDEPENDENTE)
	saida["independente"] = {
		"criaturas": _serializar(base),
		"metricas": MetricasCoerencia.avaliar(base, tabelas, k),
	}

	var caminho: String = opts["out"]
	var arquivo := FileAccess.open(caminho, FileAccess.WRITE)
	if arquivo == null:
		printerr("Nao foi possivel escrever em: ", caminho,
			" (erro ", FileAccess.get_open_error(), ")")
		quit(1)
		return
	arquivo.store_string(JSON.stringify(saida, "  "))
	arquivo.close()

	print("Exportado: %s" % ProjectSettings.globalize_path(caminho))
	print("  seed=%d  n=%d  k=%d  modos=%s" % [
		world_seed, n, k, "independente" if so_baseline else "condicionado+independente",
	])
	quit(0)


func _serializar(bestiario: Array) -> Array:
	var lista: Array = []
	for c in bestiario:
		lista.append(c.to_dict())
	return lista


func _parse_args(args: PackedStringArray) -> Dictionary:
	var opts: Dictionary = PADROES.duplicate()
	var i: int = 0
	while i < args.size():
		var a: String = args[i]
		match a:
			"--independent":
				opts["independent"] = true
			"--seed", "--n", "--k":
				if i + 1 >= args.size():
					return {"_erro": a + " exige um valor"}
				var v: String = args[i + 1]
				if not v.is_valid_int():
					return {"_erro": a + " exige um inteiro, recebeu '" + v + "'"}
				opts[a.substr(2)] = int(v)
				i += 1
			"--out":
				if i + 1 >= args.size():
					return {"_erro": "--out exige um caminho"}
				opts["out"] = args[i + 1]
				i += 1
			_:
				return {"_erro": a}
		i += 1
	return opts
