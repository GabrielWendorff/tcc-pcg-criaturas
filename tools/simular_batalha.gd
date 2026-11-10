extends SceneTree

## Simulador de balanceamento: joga batalhas automaticas sobre o bestiario de varias
## seeds e confere os criterios de aceite do combate.
##   godot --headless --path . -s res://tools/simular_batalha.gd -- [--seeds 200]
##
## Criterios (sai com codigo != 0 se algum falhar):
##   - duelo contra a guardia dura de 3 a 8 turnos em media
##   - equipe mediana de 3 vence a guardia entre 55% e 80% das vezes
##   - nenhuma criatura e invencivel
##   - mesma seed e mesmas acoes dao a mesma batalha (RF03)
##
## A "equipe mediana" sao 3 criaturas da faixa central de forca do bestiario, com a IA
## da batalha escolhendo o melhor golpe. Um jogador humano troca, cura e usa vantagem
## de elemento melhor que isso: o numero e um piso de jogabilidade, nao uma previsao.
##
## Tambem imprime o encontro selvagem (1x1 com vida cheia), que nao tem criterio de
## aceite proprio, mas mostra o custo de andar no mato.

const N_CRIATURAS := 100
const TURNOS_MIN := 3.0
const TURNOS_MAX := 8.0
const VITORIAS_MIN := 0.55
const VITORIAS_MAX := 0.80
## Para ser invencivel, uma criatura venceria 100% destes duelos 1x1 contra oponentes
## sorteados no proprio bestiario.
const DUELOS_INVENCIVEL := 40
const SEEDS_INVENCIVEL := 30

var _prob: TabelasProbabilidade
var _tabelas: TabelasBatalha
var _guardioes: Array = []


func _initialize() -> void:
	_prob = TabelasProbabilidade.carregar()
	_tabelas = TabelasBatalha.carregar()
	_guardioes = CatalogoGuardioes.carregar().guardioes
	if _prob == null or _tabelas == null or _guardioes.is_empty():
		print("FALHOU: dados nao carregaram")
		quit(1)
		return

	var n_seeds := 200
	var args := OS.get_cmdline_user_args()
	var i_seeds := args.find("--seeds")
	if i_seeds >= 0 and i_seeds + 1 < args.size():
		n_seeds = int(args[i_seeds + 1])

	var t0 := Time.get_ticks_msec()
	var ok := true
	for g: Dictionary in _guardioes:
		ok = _medir_guardia(n_seeds, g) and ok
	_medir_selvagem(mini(n_seeds, 50))
	ok = _medir_invencivel() and ok
	ok = _medir_determinismo() and ok
	print("\ntempo: %.1f s" % ((Time.get_ticks_msec() - t0) / 1000.0))
	print("RESULTADO: %s" % ("CRITERIOS ATENDIDOS" if ok else "CRITERIOS NAO ATENDIDOS"))
	quit(0 if ok else 1)


func _medir_guardia(n_seeds: int, guardiao: Dictionary) -> bool:
	var ger := GeradorCriaturas.new(_prob)
	var vitorias: int = 0
	var turnos: int = 0
	var batalhas: int = 0
	var vitorias_solo: int = 0
	var repeticoes: int = 5
	for s in n_seeds:
		var semente: int = 1000 + s * 7919
		var bes := ger.gerar_bestiario(semente, N_CRIATURAS, GeradorCriaturas.MODO_DO_JOGO)
		var equipe := _equipe_mediana(bes, semente)
		var dulce := SelecaoBestiario.equipe_guardiao(bes, _tabelas,
				guardiao["elementos"], int(guardiao["tamanho_equipe"]),
				float(guardiao["percentil_forca"]))
		for r in repeticoes:
			var res := _duelar(equipe, dulce, "guardiao", semente + r)
			batalhas += 1
			turnos += int(res["turnos"])
			if res["desfecho"] == MotorBatalha.VITORIA:
				vitorias += 1
			if _duelar([equipe[0]], dulce, "guardiao", semente + r + 100)["desfecho"] \
					== MotorBatalha.VITORIA:
				vitorias_solo += 1
	var media: float = float(turnos) / batalhas
	var taxa: float = float(vitorias) / batalhas
	var meta: Array = guardiao.get("meta_vitorias", [VITORIAS_MIN, VITORIAS_MAX])
	print("%s (%d seeds, %d batalhas)" % [String(guardiao["nome"]), n_seeds, batalhas])
	var meta_turnos: Array = guardiao.get("meta_turnos", [TURNOS_MIN, TURNOS_MAX])
	print("  turnos por batalha: %.2f  (meta %.0f a %.0f)" % [media, float(meta_turnos[0]), float(meta_turnos[1])])
	print("  vitorias equipe de 3: %.1f%%  (meta %.0f%% a %.0f%%)"
			% [taxa * 100.0, float(meta[0]) * 100.0, float(meta[1]) * 100.0])
	print("  vitorias so com a inicial: %.1f%%  (informativo)"
			% (float(vitorias_solo) / batalhas * 100.0))
	return media >= float(meta_turnos[0]) and media <= float(meta_turnos[1]) \
			and taxa >= float(meta[0]) and taxa <= float(meta[1])


func _medir_selvagem(n_seeds: int) -> void:
	var ger := GeradorCriaturas.new(_prob)
	var vitorias: int = 0
	var turnos: int = 0
	var batalhas: int = 0
	var vida_perdida: float = 0.0
	for s in n_seeds:
		var semente: int = 5000 + s * 104729
		var bes := ger.gerar_bestiario(semente, N_CRIATURAS, GeradorCriaturas.MODO_DO_JOGO)
		var eu: Criatura = _equipe_mediana(bes, semente)[0]
		var rng := RandomNumberGenerator.new()
		rng.seed = semente
		for r in 10:
			var res := _duelar([eu], [bes[rng.randi() % bes.size()]], "selvagem", semente + r)
			batalhas += 1
			turnos += int(res["turnos"])
			vida_perdida += 1.0 - float(res["fracao_jogador"])
			if res["desfecho"] == MotorBatalha.VITORIA:
				vitorias += 1
	print("Selvagem (%d batalhas, informativo)" % batalhas)
	print("  turnos: %.2f   vitorias: %.1f%%   vida perdida: %.0f%%"
			% [float(turnos) / batalhas, float(vitorias) / batalhas * 100.0,
			vida_perdida / batalhas * 100.0])


func _medir_invencivel() -> bool:
	var ger := GeradorCriaturas.new(_prob)
	var pior: float = 0.0
	var quem: String = ""
	var invenciveis: int = 0
	for s in SEEDS_INVENCIVEL:
		var semente: int = 9000 + s * 15485863
		var bes := ger.gerar_bestiario(semente, N_CRIATURAS, GeradorCriaturas.MODO_DO_JOGO)
		var ordenados := SelecaoBestiario.por_forca(bes, _tabelas)
		var rng := RandomNumberGenerator.new()
		rng.seed = semente
		# As 5 mais fortes da seed: se ha invencivel, esta entre elas.
		for i in range(ordenados.size() - 5, ordenados.size()):
			var c: Criatura = ordenados[i]
			var v: int = 0
			for d in DUELOS_INVENCIVEL:
				var oponente: Criatura = ordenados[ordenados.size() - 1 - (rng.randi() % 20)]
				if _duelar([c], [oponente], "guardiao", semente + d)["desfecho"] \
						== MotorBatalha.VITORIA:
					v += 1
			var taxa: float = float(v) / DUELOS_INVENCIVEL
			if taxa > pior:
				pior = taxa
				quem = c.nome()
			if v == DUELOS_INVENCIVEL:
				invenciveis += 1
	print("Invencivel: maior taxa %.1f%% (%s) contra as 20 mais fortes; %d invenciveis"
			% [pior * 100.0, quem, invenciveis])
	return invenciveis == 0


func _medir_determinismo() -> bool:
	var ger := GeradorCriaturas.new(_prob)
	var bes := ger.gerar_bestiario(123456789, N_CRIATURAS, GeradorCriaturas.MODO_DO_JOGO)
	var a := _duelar(_equipe_mediana(bes, 1), [bes[0], bes[1]], "guardiao", 42)
	var b := _duelar(_equipe_mediana(bes, 1), [bes[0], bes[1]], "guardiao", 42)
	var igual: bool = a["eventos"] == b["eventos"]
	print("RF03: %s" % ("mesma batalha" if igual else "BATALHAS DIFERENTES"))
	return igual


## Tres criaturas da faixa central de forca, escolhidas pela semente. Sem filtro de
## elemento: o jogador nao sabe de antemao qual guardia vai enfrentar.
func _equipe_mediana(bes: Array, semente: int) -> Array:
	var ordenados := SelecaoBestiario.por_forca(bes, _tabelas)
	var de: int = int(ordenados.size() * 0.35)
	var ate: int = int(ordenados.size() * 0.65)
	var rng := RandomNumberGenerator.new()
	rng.seed = semente + 77
	var saida: Array = []
	while saida.size() < 3:
		var c: Criatura = ordenados[de + rng.randi() % (ate - de)]
		if not c in saida:
			saida.append(c)
	return saida


func _duelar(minha: Array, dele: Array, tipo: String, semente: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = semente
	var j: Array = []
	for c: Criatura in minha:
		j.append(Combatente.de_criatura(c, _tabelas))
	var i: Array = []
	for c: Criatura in dele:
		i.append(Combatente.de_criatura(c, _tabelas))
	var motor := MotorBatalha.new(_tabelas, rng, j, i, tipo)
	var eventos: Array = []
	while not motor.terminou() and motor.turno < 300:
		if motor.precisa_trocar():
			eventos.append_array(motor.trocar_forcada(motor.trocas_possiveis()[0]))
			continue
		var g := IaBatalha.escolher(rng, motor.jogador(), motor.inimigo(), _tabelas,
				_tabelas.lado("jogador"))
		eventos.append_array(motor.resolver_turno({"tipo": "golpe", "golpe": g}))
	return {
		"desfecho": motor.desfecho,
		"turnos": motor.turno,
		"eventos": eventos,
		"fracao_jogador": (j[0] as Combatente).fracao(),
	}
