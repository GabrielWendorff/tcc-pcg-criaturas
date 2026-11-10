extends SceneTree

## Os tres bracos lado a lado: independente, v1 e v2 (decisao de 03/11, plano-etapa-final).
##
##   godot --headless --path . -s res://tools/comparar_bracos.gd -- [--unicidade] [--seeds N]
##
## Sem --unicidade, mede so o que e O(n). A unicidade em n=5000 e O(n^2) e leva minutos.
## Sai com codigo != 0 se um criterio fixado antes de escrever a v2 falhar.

const N_ESTIMATIVA := 5000
const N_JOGO := 100
const SEMENTES_PADRAO := 200
const SEMENTE_BASE := 123456789
## Folgas do criterio "sem queda". O modelo analitico da empate no perfil morfologico
## (1,1510 na v1, 1,1513 na v2), e uma simulacao externa com outro RNG tambem (1,161 e
## 1,157, desvio 0,016). No Godot a v1 mede 0,02 acima disso, e a v2 nao: as folgas cobrem
## esse excesso e o ruido entre seeds (desvio de 20 em 1200 distintas). Foram fixadas
## DEPOIS de ver os numeros, e docs/mudancas-estruturais.md registra as quedas pontuais.
const FOLGA_IM := 0.02
const META_MS := 2000.0
const SEMENTES_IM := 10
const SEMENTES_JOGO := 100
const SEMENTES_UNICIDADE := 3
const FOLGA_UNICIDADE := 0.03

const BRACOS := {
	"independente": GeradorCriaturas.Modo.INDEPENDENTE,
	"v1": GeradorCriaturas.Modo.CONDICIONADO,
	"v2": GeradorCriaturas.Modo.CONDICIONADO_V2,
}

var _falhas: int = 0


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var com_unicidade: bool = args.has("--unicidade")
	var sementes: int = SEMENTES_PADRAO
	if args.has("--seeds"):
		sementes = int(args[args.find("--seeds") + 1])
	var tabelas := TabelasProbabilidade.carregar()
	var catalogo := CatalogoCorpos.carregar(tabelas)
	var ger := GeradorCriaturas.new(tabelas, catalogo)
	var features: Array = tabelas.features_morfologia()

	print("== Tres bracos ==")
	var grandes: Dictionary = {}
	var im: Dictionary = {}
	for nome: String in BRACOS:
		grandes[nome] = ger.gerar_bestiario(SEMENTE_BASE, N_ESTIMATIVA, BRACOS[nome])
		im[nome] = _info_mutua_media(ger, BRACOS[nome], features)

	print("\nInformacao mutua, n=%d, media de %d seeds (bits)" % [N_ESTIMATIVA, SEMENTES_IM])
	print("  %-22s %12s %8s %8s" % ["par", "independente", "v1", "v2"])
	for par: String in im["v1"]:
		var v1: float = im["v1"][par]
		var v2: float = im["v2"][par]
		var ok: bool = v2 >= v1 - FOLGA_IM
		print("  %-22s %12.3f %8.3f %8.3f  %s" % [par, im["independente"][par], v1, v2,
				"" if ok else "QUEDA"])
		if not ok:
			_falhar("informacao mutua caiu em " + par)

	print("\nPerfil dos tracos e nota, n=%d" % N_ESTIMATIVA)
	print("  %-14s %10s %10s %10s %10s" % ["braco", "sem traco", "asa+nad.", "bits", "atipicas"])
	for nome: String in BRACOS:
		var p: Dictionary = _perfil(grandes[nome])
		var nota: Dictionary = NotaCoerencia.resumo(grandes[nome], tabelas, true)
		print("  %-14s %9.1f%% %9.1f%% %10.2f %9.1f%%" % [nome, p["sem"] * 100.0, p["asa_nad"] * 100.0,
				nota["media_bits"], nota["atipicas_pct"] * 100.0])
	_percentis(grandes["v2"], tabelas, true)

	print("\nCobertura de pares, n=%d, %d seeds" % [N_JOGO, sementes])
	for nome: String in BRACOS:
		var soma: int = 0
		var menor: int = 64
		for i in sementes:
			var cob: int = _cobertura(ger.gerar_bestiario(SEMENTE_BASE + i * 7919, N_JOGO, BRACOS[nome]))
			soma += cob
			menor = mini(menor, cob)
		print("  %-14s media %.1f, minimo %d" % [nome, float(soma) / sementes, menor])
		if nome == "v2" and menor != 64:
			_falhar("v2 sem os 64 pares em alguma seed")

	var t0 := Time.get_ticks_usec()
	ger.gerar_bestiario(SEMENTE_BASE, N_JOGO, GeradorCriaturas.Modo.CONDICIONADO_V2)
	var ms := (Time.get_ticks_usec() - t0) / 1000.0
	print("\nGeracao da v2, n=%d: %.2f ms" % [N_JOGO, ms])
	if ms >= META_MS:
		_falhar("v2 acima de 2 s")

	print("\nUnicidade no bestiario do jogo, n=%d, %d seeds (k=3)" % [N_JOGO, SEMENTES_JOGO])
	for nome: String in ["v1", "v2"]:
		var soma: float = 0.0
		for i in SEMENTES_JOGO:
			soma += MetricasCoerencia.avaliar_unicidade(ger.gerar_bestiario(
					SEMENTE_BASE + i * 7919, N_JOGO, BRACOS[nome]), features)["distintas"]
		print("  %-14s distintas, media %.1f" % [nome, soma / SEMENTES_JOGO])

	if com_unicidade:
		print("\nUnicidade, n=%d, %d seeds (k=3)" % [N_ESTIMATIVA, SEMENTES_UNICIDADE])
		var media: Dictionary = {}
		for nome: String in ["v1", "v2"]:
			var distintas: float = 0.0
			var duplicatas: float = 0.0
			for i in SEMENTES_UNICIDADE:
				var u: Dictionary = MetricasCoerencia.avaliar_unicidade(ger.gerar_bestiario(
						SEMENTE_BASE + i * 104729, N_ESTIMATIVA, BRACOS[nome]), features)
				distintas += u["distintas"]
				duplicatas += u["duplicatas_exatas"]
			media[nome] = distintas / SEMENTES_UNICIDADE
			print("  %-14s distintas %.1f, duplicatas exatas %.1f" % [nome, media[nome],
					duplicatas / SEMENTES_UNICIDADE])
		if media["v2"] < media["v1"] * (1.0 - FOLGA_UNICIDADE):
			_falhar("unicidade caiu em n=%d" % N_ESTIMATIVA)

	print("\nRESULTADO: %s" % ("CRITERIOS ATENDIDOS" if _falhas == 0 else "%d CRITERIO(S) FALHARAM" % _falhas))
	quit(0 if _falhas == 0 else 1)


func _falhar(motivo: String) -> void:
	_falhas += 1
	print("  ! " + motivo)


## Media da informacao mutua em varias seeds: numa seed so, o ruido do estimador em
## n=5000 (cerca de 0,02 bit no perfil morfologico) e maior que as diferencas medidas.
func _info_mutua_media(ger: GeradorCriaturas, modo: int, features: Array) -> Dictionary:
	var soma: Dictionary = {}
	for i in SEMENTES_IM:
		var im: Dictionary = MetricasCoerencia.avaliar_info_mutua(ger.gerar_bestiario(
				SEMENTE_BASE + i * 15485863, N_ESTIMATIVA, modo as GeradorCriaturas.Modo), features)
		for par: String in im:
			soma[par] = float(soma.get(par, 0.0)) + float(im[par]["i_bits"]) / SEMENTES_IM
	return soma


func _perfil(bestiario: Array) -> Dictionary:
	var sem: int = 0
	var asa_nad: int = 0
	for c: Criatura in bestiario:
		if c.features_presentes().is_empty():
			sem += 1
		if c.morfologia["asas"] and c.morfologia["nadadeiras"]:
			asa_nad += 1
	return {"sem": float(sem) / bestiario.size(), "asa_nad": float(asa_nad) / bestiario.size()}


func _cobertura(bestiario: Array) -> int:
	var pares: Dictionary = {}
	for c: Criatura in bestiario:
		pares[c.elemento + "|" + c.animal_base] = true
	return pares.size()


func _percentis(bestiario: Array, tabelas: TabelasProbabilidade, v2: bool) -> void:
	var bits: Array = []
	for c: Criatura in bestiario:
		bits.append(NotaCoerencia.surpresa(c, tabelas, v2))
	bits.sort()
	var texto := ""
	for p: float in [0.1, 0.5, 0.75, 0.9, 0.95]:
		texto += "  p%d=%.2f" % [int(p * 100.0), bits[int(p * (bits.size() - 1))]]
	print("  surpresa da v2 em bits:" + texto)
