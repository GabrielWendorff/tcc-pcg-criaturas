extends SceneTree

## Teste headless do gerador — roda SEM abrir a janela:
##   godot --headless -s res://tools/test_gerador.gd
##
## Verifica: RF03 (reprodutibilidade), meta de desempenho (< 2s p/ 100 criaturas),
## variacao entre seeds e RF08 (coerencia). Sai com codigo != 0 se algo falhar.
##
## O relatorio de coerencia e sempre PAREADO: a mesma seed gera o bestiario da
## proposta (condicionado) e o da hipotese nula (independente), lado a lado. Sem o
## baseline, os numeros de coerencia nao significam nada — e a comparacao entre os
## dois que evidencia a contribuicao do trabalho (RF04).

const SEED_A := 123456789
const SEED_B := 987654321
const N := 100

## n usado para ESTIMAR informacao mutua. O estimador plug-in e fortemente
## enviesado para cima quando ha mais celulas que observacoes: com n=100 ate um
## bestiario independente exibe I>0, e a separacao contra o baseline fica ilegivel.
## O bestiario JOGAVEL continua sendo o de n=100; este n maior serve apenas a
## medicao. O artigo deve declarar qual n produziu cada numero.
const N_ESTIMATIVA := 5000

## Separacao minima exigida entre proposta e hipotese nula (RF04).
const RAZAO_MINIMA_IM := 10.0


func _initialize() -> void:
	var falhas: int = 0
	print("== Gerador de Criaturas — teste headless ==")

	var tabelas := TabelasProbabilidade.carregar()
	if tabelas == null:
		print("FALHOU: nao foi possivel carregar as tabelas.")
		quit(1)
		return

	# --- Arte: toda combinacao animal x porte precisa de mascara ---
	var catalogo := CatalogoCorpos.carregar(tabelas)
	if catalogo == null:
		print("FALHOU: nao foi possivel carregar o catalogo de arte de res://arte/.")
		quit(1)
		return
	var faltando := catalogo.validar(tabelas)
	if faltando.is_empty():
		print("Cobertura da arte: OK (%d corpos x %d portes)" % [
			tabelas.animais().size(), tabelas.portes().size()])
	else:
		print("Cobertura da arte: FALHOU — sem mascara para %s" % ", ".join(faltando))
		falhas += 1

	var gerador := GeradorCriaturas.new(tabelas, catalogo)

	# --- Desempenho (meta: bestiario completo < 2s) ---
	var t0 := Time.get_ticks_usec()
	var best_a := gerador.gerar_bestiario(SEED_A, N)
	var dt_ms := (Time.get_ticks_usec() - t0) / 1000.0
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

	# --- Baseline: mesma seed, sorteio independente (hipotese nula) ---
	var base_a := gerador.gerar_bestiario(SEED_A, N, GeradorCriaturas.Modo.INDEPENDENTE)
	if _primarios_iguais(best_a, base_a):
		print("Pareamento com baseline: OK (mesmos primarios, derivados descorrelacionados)")
	else:
		print("Pareamento com baseline: FALHOU (primarios divergiram)")
		falhas += 1

	# --- RF08: coerencia semantica ---
	var m := MetricasCoerencia.avaliar(best_a, tabelas)
	var mb := MetricasCoerencia.avaliar(base_a, tabelas)
	_relatorio(m, mb)

	# --- RF04: a hipotese como teste automatizado ---
	falhas += _testar_hipotese(gerador, tabelas)

	# --- Amostra visual (5 primeiras criaturas) ---
	print("\nAmostra (condicionado):")
	for i in min(5, best_a.size()):
		print("  " + str(best_a[i]))
	print("Amostra (baseline independente, mesmos primarios):")
	for i in min(5, base_a.size()):
		print("  " + str(base_a[i]))

	print("\n==")
	if falhas == 0:
		print("RESULTADO: TODOS OS TESTES PASSARAM")
		quit(0)
	else:
		print("RESULTADO: %d FALHA(S)" % falhas)
		quit(1)


## RF04 — converte a tese do trabalho num criterio de aprovacao/reprovacao:
## num regime de amostra em que o vies do estimador e desprezivel, a informacao
## mutua entre primarios e derivados deve superar a da hipotese nula por uma
## margem larga. Se um dia alguem quebrar o condicionamento, este teste acusa.
func _testar_hipotese(gerador: GeradorCriaturas, tabelas: TabelasProbabilidade) -> int:
	var t0 := Time.get_ticks_usec()
	var cond := gerador.gerar_bestiario(SEED_A, N_ESTIMATIVA, GeradorCriaturas.Modo.CONDICIONADO)
	var base := gerador.gerar_bestiario(SEED_A, N_ESTIMATIVA, GeradorCriaturas.Modo.INDEPENDENTE)
	# So a informacao mutua (O(n)); avaliar() inteira traria a unicidade, que e
	# O(n^2) e desnecessaria aqui.
	var features: Array = tabelas.features_morfologia()
	var mi_c := MetricasCoerencia.avaliar_info_mutua(cond, features)
	var mi_b := MetricasCoerencia.avaliar_info_mutua(base, features)
	var dt_ms := (Time.get_ticks_usec() - t0) / 1000.0

	print("\nRF04 hipotese: atributos correlacionados vs. sorteio independente")
	print("    estimativa com n=%d (%.0f ms); exige I_cond >= %.0fx I_base" % [
		N_ESTIMATIVA, dt_ms, RAZAO_MINIMA_IM])
	var falhas: int = 0
	for par in ["elemento->porte", "elemento->paleta", "elemento->matiz",
			"elemento->cor", "animal->morfologia"]:
		var ic: float = mi_c[par]["i_bits"]
		var ib: float = mi_b[par]["i_bits"]
		var razao: float = ic / ib if ib > 1e-9 else INF
		var ok: bool = razao >= RAZAO_MINIMA_IM
		if not ok:
			falhas += 1
		print("    %-22s %7.3f vs %6.3f bits  = %8s  %s" % [
			par, ic, ib, ("%.0fx" % razao) if is_finite(razao) else "inf",
			"OK" if ok else "FALHOU"])
	return falhas


func _relatorio(m: Dictionary, mb: Dictionary) -> void:
	print("\nRF08 coerencia semantica (seed %d, n=%d)" % [SEED_A, N])
	print("-".repeat(74))

	print("\n[1] COERENCIA POR MODA — observado / teto teorico das tabelas")
	print("    O teto NAO e 100%: e o maximo que as condicionais vigentes permitem.")
	print("    %-12s %8s %8s %8s   %8s" % ["dimensao", "obs", "teto", "efic.", "baseline"])
	for dim in MetricasCoerencia.DIMENSOES_MODA:
		var d: Dictionary = m["moda"][dim]
		print("    %-12s %7.1f%% %7.1f%% %7.1f%%   %6.1f%%" % [
			dim, d["obs"] * 100.0, d["teto"] * 100.0, d["razao"] * 100.0,
			mb["moda"][dim]["obs"] * 100.0,
		])
	for f in m["moda"]["por_feature"]:
		var d: Dictionary = m["moda"]["por_feature"][f]
		print("      %-10s %7.1f%% %7.1f%% %7.1f%%" % [
			f, d["obs"] * 100.0, d["teto"] * 100.0, d["razao"] * 100.0,
		])
	print("    EFICIENCIA GERAL: %.1f%%  (fidelidade as condicionais)" % (
		m["moda"]["eficiencia_pct"] * 100.0))

	print("\n[2] INFORMACAO MUTUA I(primario; derivado) — a metrica que testa a hipotese")
	print("    Sob sorteio independente I -> 0. U = fracao da incerteza explicada.")
	print("    %-22s %9s %9s %7s   %10s" % ["par", "I (bits)", "I corrig.", "U", "I baseline"])
	for par in m["info_mutua"]:
		var a: Dictionary = m["info_mutua"][par]
		var b: Dictionary = mb["info_mutua"][par]
		print("    %-22s %8.3f  %8.3f  %6.1f%%   %8.3f" % [
			par, a["i_bits"], a["i_corrigido"], a["u"] * 100.0, b["i_bits"],
		])

	print("\n[3] UNICIDADE — distancia de Hamming sobre o vetor de atributos")
	var u: Dictionary = m["unicidade"]
	print("    k=%d (de %d posicoes) | distintas: %d/%d (%.0f%%) | isoladas: %d" % [
		u["k"], u["dimensao"], u["distintas"], m["total"],
		u["distintas_pct"] * 100.0, u["isoladas"],
	])
	print("    distancia media entre pares: %.2f | minima: %d | duplicatas exatas: %d" % [
		u["dist_media"], u["dist_min"], u["duplicatas_exatas"],
	])
	print("-".repeat(74))


func _bestiarios_iguais(a: Array, b: Array) -> bool:
	if a.size() != b.size():
		return false
	for i in a.size():
		var x: Criatura = a[i]
		var y: Criatura = b[i]
		if x.elemento != y.elemento or x.animal_base != y.animal_base:
			return false
		if x.porte != y.porte or x.body_id != y.body_id:
			return false
		if x.paleta != y.paleta or x.matiz != y.matiz:
			return false
		if x.morfologia != y.morfologia:
			return false
		if x.variantes != y.variantes:
			return false
	return true


## Os primarios sao raizes: devem ser identicos entre os dois modos para a mesma
## seed, garantindo que a comparacao com o baseline seja pareada.
func _primarios_iguais(a: Array, b: Array) -> bool:
	if a.size() != b.size():
		return false
	for i in a.size():
		if a[i].elemento != b[i].elemento or a[i].animal_base != b[i].animal_base:
			return false
	return true
