extends SceneTree

## Teste da REGRA de batalha, sem cena nem autoload:
##   godot --headless --path . -s res://tools/test_batalha.gd
##
## Stats e golpes derivados da morfologia, vantagem de elementos, dano, turno, troca,
## fuga, itens, derrota, selecao por percentil e RF03. Sai com codigo != 0 se falhar,
## inclusive quando uma etapa aborta no meio (ver ETAPAS).

const SEED := 123456789

## Quantas funcoes _testar_* existem. Um erro de script dentro de uma delas devolve null
## ao chamador e a execucao segue: so a ultima linha de cada etapa prova que ela rodou.
const ETAPAS := 10

var _falhas: int = 0
var _verificacoes: int = 0
var _etapas: int = 0
var _tabelas: TabelasBatalha
var _prob: TabelasProbabilidade


func _initialize() -> void:
	print("== Batalha — regra ==")
	_rodar()
	print("\n==")
	if _etapas != ETAPAS:
		print("RESULTADO: O TESTE ABORTOU NO MEIO (%d de %d etapas, %d verificacoes)"
				% [_etapas, ETAPAS, _verificacoes])
		quit(1)
	elif _falhas > 0:
		print("RESULTADO: %d VERIFICACAO(OES) FALHARAM" % _falhas)
		quit(1)
	else:
		print("RESULTADO: TODOS OS TESTES PASSARAM (%d)" % _verificacoes)
		quit(0)


func _ok(condicao: bool, rotulo: String, detalhe: String = "") -> bool:
	print("    %s %s%s" % ["OK  " if condicao else "FALHOU", rotulo,
			"" if detalhe == "" else "  — " + detalhe])
	_verificacoes += 1
	if not condicao:
		_falhas += 1
	return condicao


func _rodar() -> void:
	_prob = TabelasProbabilidade.carregar()
	_tabelas = TabelasBatalha.carregar()
	if not _ok(_prob != null and _tabelas != null, "tabelas carregaram"):
		return
	_testar_tabelas()
	_testar_ficha()
	_testar_elementos()
	_testar_dano()
	_testar_turno()
	_testar_troca_e_derrota()
	_testar_acoes()
	_testar_selecao()
	_testar_equipe()
	_testar_determinismo()


func _testar_tabelas() -> void:
	print("\nTabelas")
	var faltando := _tabelas.validar(_prob)
	_ok(faltando.is_empty(), "coerentes com o vocabulario do gerador", ", ".join(faltando))
	_ok(_tabelas.golpes.size() == 13, "13 golpes", "%d" % _tabelas.golpes.size())
	for e: String in _prob.elementos():
		var fortes := 0
		var fracos := 0
		for o: String in _prob.elementos():
			if _tabelas.forte_contra(e, o):
				fortes += 1
			if _tabelas.forte_contra(o, e):
				fracos += 1
		_ok(fortes == 2 and fracos == 2, "%s: forte contra 2, fraco contra 2" % e,
				"%d/%d" % [fortes, fracos])
	_etapas += 1


func _testar_ficha() -> void:
	print("\nFicha derivada da morfologia")
	var pelado := _c("planta", "roedor", "medio", {})
	var f0 := FichaCombate.de_criatura(pelado, _tabelas)
	_ok(f0.golpes.size() == 2, "sem tracos: elemento + reserva",
			_nomes(f0.golpes))
	_ok(f0.golpes[1].reserva, "a reserva e a Investida")

	var garras0 := FichaCombate.de_criatura(
			_c("planta", "gato", "medio", {"garras": 0}), _tabelas)
	var garras3 := FichaCombate.de_criatura(
			_c("planta", "gato", "medio", {"garras": 3}), _tabelas)
	_ok(garras0.ataque > f0.ataque, "garras sobem o ataque",
			"%.0f > %.0f" % [garras0.ataque, f0.ataque])
	_ok(garras3.ataque > garras0.ataque, "a variante escala o traco",
			"%.0f > %.0f" % [garras3.ataque, garras0.ataque])
	_ok(garras0.vida > f0.vida, "cada traco soma vida (formula do vigor)")

	var f_esc := FichaCombate.de_criatura(_c("agua", "peixe", "medio", {"escamas": 0}), _tabelas)
	_ok(f_esc.defesa > f0.defesa, "escamas sobem a defesa")
	var f_asa := FichaCombate.de_criatura(_c("ar", "ave", "medio", {"asas": 0}), _tabelas)
	_ok(f_asa.velocidade > f0.velocidade, "asas sobem a velocidade")
	var f_nad := FichaCombate.de_criatura(_c("agua", "peixe", "medio", {"nadadeiras": 0}), _tabelas)
	_ok(f_nad.esquiva > f0.esquiva, "nadadeiras sobem a esquiva")

	var compacto := FichaCombate.de_criatura(_c("terra", "roedor", "compacto", {}), _tabelas)
	var alongado := FichaCombate.de_criatura(_c("terra", "roedor", "alongado", {}), _tabelas)
	_ok(compacto.defesa > alongado.defesa and compacto.vida > alongado.vida,
			"compacto: mais defesa e vida")
	_ok(alongado.velocidade > compacto.velocidade, "alongado: mais velocidade")

	var cheio := _c("fogo", "reptil", "medio",
			{"garras": 1, "escamas": 1, "asas": 1, "nadadeiras": 1})
	var f_cheio := FichaCombate.de_criatura(cheio, _tabelas)
	_ok(f_cheio.golpes.size() == 5, "todos os tracos: no maximo 5 golpes", _nomes(f_cheio.golpes))
	_ok(not _tem_reserva(f_cheio.golpes), "com tracos nao ha Investida")
	_etapas += 1


func _testar_elementos() -> void:
	print("\nVantagem de elementos")
	_ok(is_equal_approx(_tabelas.multiplicador_elemento("agua", "fogo"), 1.5), "agua > fogo")
	_ok(is_equal_approx(_tabelas.multiplicador_elemento("fogo", "agua"), 0.75), "fogo < agua")
	_ok(is_equal_approx(_tabelas.multiplicador_elemento("fogo", "ar"), 1.0), "neutro entre fogo e ar")
	_ok(is_equal_approx(_tabelas.multiplicador_elemento("", "fogo"), 1.0), "golpe sem elemento e neutro")
	_etapas += 1


func _testar_dano() -> void:
	print("\nDano e acerto")
	var a := Combatente.de_criatura(_c("agua", "gato", "medio", {"garras": 0}), _tabelas)
	var d := Combatente.de_criatura(_c("fogo", "roedor", "medio", {}), _tabelas)
	var neutro := Combatente.de_criatura(_c("ar", "roedor", "medio", {}), _tabelas)
	var jato := _tabelas.do_elemento("agua")
	var forte := CalculoBatalha.dano_base(jato, a, d, _tabelas)
	var normal := CalculoBatalha.dano_base(jato, a, neutro, _tabelas)
	_ok(forte > normal, "vantagem aumenta o dano", "%.1f > %.1f" % [forte, normal])
	_ok(is_equal_approx(forte / normal, 1.5), "exatamente o multiplicador do dado")

	var r0 := CalculoBatalha.poder_efetivo(_tabelas.do_traco("garras"), a, _tabelas)
	var a3 := Combatente.de_criatura(_c("agua", "gato", "medio", {"garras": 3}), _tabelas)
	_ok(CalculoBatalha.poder_efetivo(_tabelas.do_traco("garras"), a3, _tabelas) > r0,
			"a variante escala o poder do golpe de traco")

	var antes := CalculoBatalha.dano_base(jato, a, d, _tabelas)
	CalculoBatalha.aplicar_reforco(_tabelas.do_traco("escamas"), d)
	_ok(CalculoBatalha.dano_base(jato, a, d, _tabelas) < antes, "Couraca reduz o dano recebido")
	for i in 10:
		CalculoBatalha.aplicar_reforco(_tabelas.do_traco("escamas"), d)
	_ok(d.reforco_no_limite(_tabelas.do_traco("escamas")), "o reforco para no limite",
			"%.2f" % float(d.reforcos["defesa"]))

	var d2 := Combatente.de_criatura(_c("ar", "peixe", "medio", {"nadadeiras": 3}), _tabelas)
	_ok(CalculoBatalha.chance_de_acerto(jato, d2) < CalculoBatalha.chance_de_acerto(jato, neutro),
			"esquiva reduz o acerto")

	var efeito_curar := {"tipo": "curar", "valor": 30}
	var ferido := Combatente.de_criatura(_c("ar", "peixe", "medio", {}), _tabelas, 10)
	_ok(CalculoBatalha.aplicar_efeito(efeito_curar, ferido) == 30, "poção cura o valor do dado")
	var caido := Combatente.de_criatura(_c("ar", "peixe", "medio", {}), _tabelas, 0)
	_ok(not CalculoBatalha.efeito_aplicavel(efeito_curar, caido), "poção não levanta quem caiu")
	var efeito_rev := {"tipo": "reviver", "percentual": 50}
	_ok(CalculoBatalha.aplicar_efeito(efeito_rev, caido) == roundi(caido.ficha.vida * 0.5),
			"elixir revive com o percentual do dado")
	_ok(not CalculoBatalha.efeito_aplicavel(efeito_rev, ferido), "elixir não serve em quem está de pé")
	var cheio := Combatente.de_criatura(_c("ar", "peixe", "medio", {}), _tabelas)
	_ok(not CalculoBatalha.efeito_aplicavel(efeito_curar, cheio), "poção não serve com vida cheia")
	_etapas += 1


func _testar_turno() -> void:
	print("\nTurno")
	var lento := _c("planta", "gato", "compacto", {})
	var rapido := _c("planta", "ave", "alongado", {"asas": 3})
	var motor := _motor([lento], [rapido])
	var g: Golpe = motor.jogador().ficha.golpes[0]
	var ev := motor.resolver_turno({"tipo": "golpe", "golpe": g})
	_ok(not ev.is_empty() and String(ev[0].get("lado", "")) == MotorBatalha.INIMIGO,
			"o mais rapido age primeiro")
	_ok(motor.turno == 1, "o turno foi contado")

	# Prioridade vence velocidade.
	var motor2 := _motor([_c("ar", "ave", "compacto", {"asas": 0})], [rapido])
	var rasante := motor2.jogador().ficha.golpes.filter(
			func(x: Golpe) -> bool: return x.traco == "asas")[0] as Golpe
	var dele := motor2.inimigo().ficha.golpes[0]
	_ok(motor2._quem_age_primeiro(rasante, dele) == MotorBatalha.JOGADOR,
			"Rasante age antes do mais rapido")

	# Quem cai nao revida.
	var motor3 := _motor([_c("fogo", "gato", "medio", {"garras": 3})],
			[_c("planta", "roedor", "alongado", {})])
	motor3.inimigo().vida = 1
	motor3.jogador().ficha.velocidade = 999.0
	var vida_antes: int = motor3.jogador().vida
	motor3.inimigo().ficha.esquiva = 0.0
	motor3.resolver_turno({"tipo": "golpe", "golpe": _tabelas.de_reserva()})
	_ok(motor3.desfecho == MotorBatalha.VITORIA, "derrubar o ultimo adversario vence")
	_ok(motor3.jogador().vida == vida_antes, "quem cai antes de agir nao revida")
	_ok(motor3.resolver_turno({"tipo": "passar"}).is_empty(), "batalha acabada nao tem mais turno")
	_etapas += 1


func _testar_troca_e_derrota() -> void:
	print("\nTroca e derrota")
	var a := _c("fogo", "gato", "medio", {"garras": 0})
	var b := _c("agua", "peixe", "medio", {})
	var forte := _c("sombra", "gato", "medio", {"garras": 3})
	var motor := _motor([a, b], [forte])
	motor.jogador().vida = 1
	motor.jogador().ficha.velocidade = 1.0
	# Forca o acerto pelo teto de esquiva zero e sorteios ate cair.
	for i in 20:
		if motor.precisa_trocar() or motor.terminou():
			break
		motor.jogador().vida = 1
		motor.resolver_turno({"tipo": "passar"})
	_ok(motor.precisa_trocar(), "caiu com reserva viva: troca obrigatoria")
	_ok(motor.resolver_turno({"tipo": "passar"}).is_empty(), "sem turno ate trocar")
	var vida_outra: int = (motor.lado_jogador[1] as Combatente).vida
	var ev := motor.trocar_forcada(1)
	_ok(ev.size() == 1 and motor.ativo_jogador == 1, "a troca obrigatoria funciona")
	_ok(motor.jogador().vida == vida_outra, "e o adversario nao age nela")

	var motor2 := _motor([a, b], [forte])
	var turno_antes: int = motor2.turno
	motor2.ativo_jogador = 0
	motor2.jogador().vida = motor2.jogador().ficha.vida
	motor2.resolver_turno({"tipo": "trocar", "indice": 1})
	_ok(motor2.ativo_jogador == 1 and motor2.turno == turno_antes + 1,
			"trocar voluntariamente gasta o turno")

	var motor3 := _motor([a], [forte])
	for i in 40:
		if motor3.terminou():
			break
		motor3.jogador().vida = 1
		motor3.resolver_turno({"tipo": "passar"})
	_ok(motor3.desfecho == MotorBatalha.DERROTA, "ultima criatura caiu: derrota")

	var segundo := _c("agua", "gato", "medio", {})
	var motor5 := _motor([_c("fogo", "gato", "medio", {"garras": 3})],
			[_c("planta", "roedor", "medio", {}), segundo], "guardiao")
	motor5.inimigo().vida = 1
	motor5.inimigo().ficha.esquiva = 0.0
	motor5.jogador().ficha.velocidade = 999.0
	# Investida tem precisao 1.0: com esquiva zero o acerto e certo, e o caso nao
	# depende do sorteio.
	var investida := _tabelas.de_reserva()
	var ev5 := motor5.resolver_turno({"tipo": "golpe", "golpe": investida})
	_ok(int(ev5[0].get("dano", 0)) > 0, "o golpe de precisao 1.0 acertou")
	_ok(motor5.inimigo().criatura == segundo and not motor5.terminou(),
			"guardiao manda a proxima criatura")
	_etapas += 1


func _testar_acoes() -> void:
	print("\nFuga e itens")
	var rapido := Combatente.de_criatura(_c("ar", "ave", "alongado", {"asas": 3}), _tabelas)
	var lento := Combatente.de_criatura(_c("terra", "roedor", "compacto", {}), _tabelas)
	var p_rapido := CalculoBatalha.chance_de_fuga(rapido, lento, _tabelas)
	var p_lento := CalculoBatalha.chance_de_fuga(lento, rapido, _tabelas)
	_ok(p_rapido > p_lento, "fugir depende da velocidade", "%.2f > %.2f" % [p_rapido, p_lento])

	var fugiu := false
	for s in 30:
		var m := _motor([_c("ar", "ave", "alongado", {"asas": 3})],
				[_c("terra", "roedor", "compacto", {})], "selvagem", s)
		m.resolver_turno({"tipo": "fugir"})
		if m.desfecho == MotorBatalha.FUGIU:
			fugiu = true
			break
	_ok(fugiu, "fugir pode dar certo")

	var m2 := _motor([_c("fogo", "gato", "medio", {})], [_c("fogo", "gato", "medio", {})])
	m2.jogador().vida = 5
	var ev := m2.resolver_turno({"tipo": "item", "efeito": {"tipo": "curar", "valor": 30},
			"alvo": 0, "nome": "Poção"})
	_ok(String(ev[0]["tipo"]) == "item" and int(ev[0]["ganho"]) == 30, "item cura na batalha")
	_ok(ev.size() >= 2, "e o adversario revida: item gasta o turno")
	_etapas += 1


func _testar_selecao() -> void:
	print("\nSelecao no bestiario")
	var ger := GeradorCriaturas.new(_prob)
	var bestiario := ger.gerar_bestiario(SEED, 100)
	var ini := SelecaoBestiario.iniciais(bestiario, _tabelas)
	_ok(ini.size() == 3, "3 opcoes iniciais")
	var elementos := {}
	for c: Criatura in ini:
		elementos[c.elemento] = true
	_ok(elementos.size() == 3, "com elementos diferentes", ", ".join(elementos.keys()))
	_ok(ini == SelecaoBestiario.iniciais(bestiario, _tabelas), "deterministicas para a seed")

	var cfg := ["terra", "planta"]
	var eq := SelecaoBestiario.equipe_guardiao(bestiario, _tabelas, cfg, 2, 0.5)
	_ok(eq.size() == 2 and eq[0] != eq[1], "guardiao com 2 criaturas distintas")
	for c: Criatura in eq:
		_ok(c.elemento in cfg, "%s e da regiao" % c.nome())
	var outra := SelecaoBestiario.equipe_guardiao(ger.gerar_bestiario(SEED + 1, 100),
			_tabelas, cfg, 2, 0.5)
	_ok(_ids(eq) != _ids(outra), "seed diferente, equipe diferente")
	var acima := SelecaoBestiario.equipe_guardiao(bestiario, _tabelas, cfg, 2, 0.9)
	_ok(_forca(acima[0]) >= _forca(eq[0]), "percentil maior, criatura mais forte")

	# Sem nenhuma criatura do elemento: nao pode ficar sem equipe.
	var vazia := SelecaoBestiario.equipe_guardiao(bestiario, _tabelas, ["inexistente"], 2, 0.5)
	_ok(vazia.size() == 2, "elemento ausente na seed cai no bestiario inteiro")

	var cat := CatalogoGuardioes.carregar()
	_ok(cat.erro == "" and not cat.por_id("dulce").is_empty(), "guardioes.json carregou")
	var e := EstadoMundo.new()
	_ok(not cat.venceu_o_jogo(e), "sem selo nao ha vitoria")
	e.definir("selo_dulce")
	_ok(cat.selos_para_vencer <= 1 or not cat.venceu_o_jogo(e),
			"com menos selos que os pedidos, ainda nao ha vitoria")
	for g: Dictionary in cat.guardioes:
		e.definir(String(g["selo"]))
	_ok(cat.venceu_o_jogo(e), "com os selos pedidos, vitoria")
	_etapas += 1


func _testar_equipe() -> void:
	print("\nEquipe e deposito")
	var eq := EquipeJogador.new(3)
	_ok(eq.vazia() and not eq.tem_vivos(), "comeca vazia")
	for i in 4:
		var entrou := eq.adicionar(Combatente.de_criatura(
				_c("fogo", "gato", "medio", {}), _tabelas))
		_ok(entrou == (i < 3), "criatura %d: %s" % [i, "equipe" if entrou else "deposito"])
	_ok(eq.ativos.size() == 3 and eq.deposito.size() == 1, "3 na equipe, 1 no deposito")
	var quarta: Combatente = eq.deposito[0]
	_ok(eq.trocar_com_deposito(0, 0) and eq.ativos[0] == quarta, "troca com o deposito")
	var segunda: Combatente = eq.ativos[1]
	_ok(eq.tornar_primeira(1) and eq.ativos[0] == segunda, "reordena quem entra em campo")
	for c: Combatente in eq.ativos:
		c.vida = 0
	_ok(not eq.tem_vivos(), "todas caidas: sem vivos")
	var salvas := eq.para_salvas(eq.ativos)
	_ok(salvas[0].hp_atual == 0, "0 de vida vai para o save (nao e o sentinela de cheio)")
	eq.curar_todos()
	_ok(eq.tem_vivos() and eq.ativos[0].fracao() == 1.0, "a cura da vila levanta todas")
	eq.ativos[1].vida = 3
	_ok(eq.alvo_de_efeito({"tipo": "curar", "valor": 30}) == eq.ativos[1],
			"poção vai para a mais ferida")
	_etapas += 1


func _testar_determinismo() -> void:
	print("\nDeterminismo (RF03)")
	var a := _jogar(SEED)
	var b := _jogar(SEED)
	var c := _jogar(SEED + 1)
	_ok(a == b, "mesma seed e mesmas acoes: mesma batalha", "%d eventos" % a.size())
	_ok(a != c, "seed diferente: batalha diferente")
	_etapas += 1


func _jogar(semente: int) -> Array:
	var ger := GeradorCriaturas.new(_prob)
	var bes := ger.gerar_bestiario(SEED, 100)
	var rng := RandomNumberGenerator.new()
	rng.seed = semente
	var jog: Array = [Combatente.de_criatura(bes[0], _tabelas), Combatente.de_criatura(bes[1], _tabelas)]
	var ini: Array = [Combatente.de_criatura(bes[2], _tabelas), Combatente.de_criatura(bes[3], _tabelas)]
	var motor := MotorBatalha.new(_tabelas, rng, jog, ini, "guardiao")
	var saida: Array = []
	while not motor.terminou() and motor.turno < 200:
		if motor.precisa_trocar():
			saida.append_array(motor.trocar_forcada(motor.trocas_possiveis()[0]))
			continue
		var g := IaBatalha.escolher(rng, motor.jogador(), motor.inimigo(), _tabelas,
				_tabelas.lado("jogador"))
		saida.append_array(motor.resolver_turno({"tipo": "golpe", "golpe": g}))
	return saida


# ------------------------------------------------------------------- utilidades

func _motor(jogador: Array, inimigo: Array, tipo: String = "selvagem", semente: int = SEED) -> MotorBatalha:
	var rng := RandomNumberGenerator.new()
	rng.seed = semente
	var j: Array = []
	for c: Criatura in jogador:
		j.append(Combatente.de_criatura(c, _tabelas))
	var i: Array = []
	for c: Criatura in inimigo:
		i.append(Combatente.de_criatura(c, _tabelas))
	return MotorBatalha.new(_tabelas, rng, j, i, tipo)


## `tracos`: traco -> indice da variante.
func _c(elemento: String, animal: String, porte: String, tracos: Dictionary) -> Criatura:
	var c := Criatura.new()
	c.elemento = elemento
	c.animal_base = animal
	c.porte = porte
	c.paleta = "neutra"
	c.matiz = "cinza"
	for f in ["garras", "escamas", "asas", "nadadeiras"]:
		c.morfologia[f] = tracos.has(f)
		if tracos.has(f):
			c.variantes[f] = int(tracos[f])
	return c


func _nomes(golpes: Array[Golpe]) -> String:
	var n := PackedStringArray()
	for g: Golpe in golpes:
		n.append(g.nome)
	return ", ".join(n)


func _tem_reserva(golpes: Array[Golpe]) -> bool:
	for g: Golpe in golpes:
		if g.reserva:
			return true
	return false


func _ids(lista: Array) -> Array:
	var s: Array = []
	for c: Criatura in lista:
		s.append(c.id)
	return s


func _forca(c: Criatura) -> float:
	return FichaCombate.de_criatura(c, _tabelas).forca(_tabelas)
