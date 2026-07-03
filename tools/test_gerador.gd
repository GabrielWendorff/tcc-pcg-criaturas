extends SceneTree

## Teste headless do gerador — roda SEM abrir a janela:
##   godot --headless -s res://tools/test_gerador.gd
##
## Verifica: RF03 (reprodutibilidade), meta de desempenho (< 2s p/ 100 criaturas),
## variacao entre seeds e RF08 (coerencia). Sai com codigo != 0 se algo falhar.

const SEED_A := 123456789
const SEED_B := 987654321
const N := 100


func _initialize() -> void:
	var falhas: int = 0

	var tabelas := TabelasProbabilidade.carregar()
	if tabelas == null:
		print("FALHOU: nao foi possivel carregar as tabelas.")
		quit(1)
		return

	var gerador := GeradorCriaturas.new(tabelas)

	# --- Desempenho (meta: bestiario completo < 2s) ---
	var t0 := Time.get_ticks_usec()
	var best_a := gerador.gerar_bestiario(SEED_A, N)
	var dt_ms := (Time.get_ticks_usec() - t0) / 1000.0
	print("== Gerador de Criaturas — teste headless ==")
	print("Geracao de %d criaturas: %.2f ms" % [N, dt_ms])
	if dt_ms >= 2000.0:
		print("  ! ACIMA da meta de 2000 ms")
		falhas += 1
	else:
		print("  OK dentro da meta (< 2000 ms)")

	# --- RF03: mesma seed => bestiario identico ---
	var best_a2 := gerador.gerar_bestiario(SEED_A, N)
	if _bestiarios_iguais(best_a, best_a2):
		print("RF03 reprodutibilidade: OK (mesma seed => mesmo bestiario)")
	else:
		print("RF03 reprodutibilidade: FALHOU")
		falhas += 1

	# --- Seeds diferentes => bestiarios diferentes ---
	var best_b := gerador.gerar_bestiario(SEED_B, N)
	if _bestiarios_iguais(best_a, best_b):
		print("Variacao entre seeds: FALHOU (seeds diferentes deram o mesmo)")
		falhas += 1
	else:
		print("Variacao entre seeds: OK (seeds diferentes => bestiarios diferentes)")

	# --- RF08: coerencia semantica ---
	var m := MetricasCoerencia.avaliar(best_a, tabelas)
	print("RF08 coerencia (seed %d, n=%d):" % [SEED_A, N])
	print("  paleta     : %5.1f%%" % (m["paleta_pct"] * 100.0))
	print("  matiz      : %5.1f%%" % (m["matiz_pct"] * 100.0))
	print("  morfologia : %5.1f%%" % (m["morfologia_pct"] * 100.0))
	for f in m["por_feature"]:
		print("      %-11s: %5.1f%%" % [f, m["por_feature"][f] * 100.0])
	print("  variante   : %5.1f%%  (qual modelo, entre features presentes)" % (m["variante_pct"] * 100.0))
	print("  GERAL      : %5.1f%%" % (m["geral_pct"] * 100.0))

	# --- Amostra visual (5 primeiras criaturas) ---
	print("Amostra:")
	for i in min(5, best_a.size()):
		print("  " + str(best_a[i]))

	print("==")
	if falhas == 0:
		print("RESULTADO: TODOS OS TESTES PASSARAM")
		quit(0)
	else:
		print("RESULTADO: %d FALHA(S)" % falhas)
		quit(1)


func _bestiarios_iguais(a: Array, b: Array) -> bool:
	if a.size() != b.size():
		return false
	for i in a.size():
		var x: Criatura = a[i]
		var y: Criatura = b[i]
		if x.elemento != y.elemento or x.animal_base != y.animal_base:
			return false
		if x.paleta != y.paleta or x.matiz != y.matiz:
			return false
		if x.morfologia != y.morfologia:
			return false
		if x.variantes != y.variantes:
			return false
	return true
