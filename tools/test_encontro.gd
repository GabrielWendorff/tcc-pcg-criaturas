extends Node

## Teste headless do sistema de encontro e captura. Roda como CENA:
##   godot --headless --path . res://tools/test_encontro.tscn
##
## Nao sob -s: o mundo cita os autoloads (Opcoes pela camera, Bolsa), e sob -s eles nao
## existem no Godot 4.7. A versao antiga, sob -s, abortava no fluxo completo e ainda
## assim imprimia que tinha passado: o resultado agora so e positivo se a ultima linha
## de cada etapa for alcancada (ver ETAPAS).
##
## Cobre as tres camadas separadamente, porque elas falham por motivos diferentes:
##
##   1. REGRA (sem cena): tabelas, afinidade, formula, iscas, inventario e a
##      maquina de estados. Sao classes puras — se algo aqui quebra, o problema e
##      de modelo, nao de interface.
##   2. FLUXO (com cena e fisica de verdade): o roteiro completo do encontro na
##      vila, com jogador, camera e zonas reais, percorrendo abandonar, atacar,
##      oferecer isca, capturar, falhar e encerrar.
##   3. BORDAS: sem dispositivo, sem isca, item zerado, cancelamento, encontros
##      repetidos e limpeza de estado entre eles.
##
## Sai com codigo != 0 se algo falhar.

const SEED := 123456789
const N := 100

## Tempos do roteiro reduzidos ao minimo no teste. Nao ha valor em esperar 3,5 s
## de fade por encontro — e reduzi-los aqui e, de quebra, a prova de que todo
## tempo do roteiro e configuravel.
const RITMO_DE_TESTE := 0.01

## Quantas funcoes _testar_* existem. Um erro de script dentro de uma delas devolve null
## ao chamador e a execucao segue: so a ultima linha de cada etapa prova que ela rodou.
const ETAPAS := 9

var _falhas: int = 0
var _verificacoes: int = 0
var _etapas: int = 0


func _ready() -> void:
	# A raiz ainda esta montando os filhos neste quadro, e o teste acrescenta nos a ela.
	await get_tree().process_frame
	print("== Encontro e captura — teste headless ==")
	await _rodar()
	print("\n==")
	if _etapas != ETAPAS:
		print("RESULTADO: O TESTE ABORTOU NO MEIO (%d de %d etapas, %d verificacoes)"
				% [_etapas, ETAPAS, _verificacoes])
		get_tree().quit(1)
	elif _falhas > 0:
		print("RESULTADO: %d VERIFICACAO(OES) FALHARAM" % _falhas)
		get_tree().quit(1)
	else:
		print("RESULTADO: TODOS OS TESTES PASSARAM (%d)" % _verificacoes)
		get_tree().quit(0)


func _ok(condicao: bool, rotulo: String, detalhe: String = "") -> bool:
	print("    %s %s%s" % ["OK  " if condicao else "FALHOU", rotulo,
			"" if detalhe == "" else "  — " + detalhe])
	_verificacoes += 1
	if not condicao:
		_falhas += 1
	return condicao


func _rodar() -> void:
	var tabelas := TabelasProbabilidade.carregar()
	var captura := TabelasCaptura.carregar()
	if tabelas == null or captura == null:
		print("FALHOU: tabelas nao carregaram.")
		return

	_testar_tabelas(tabelas, captura)
	_testar_afinidade(tabelas, captura)
	_testar_formula(captura)
	_testar_iscas(captura)
	_testar_inventario(captura)
	_testar_maquina_de_estados()
	_testar_determinismo(captura)
	await _testar_fluxo_completo()


# ------------------------------------------------------- 1. dados e coerencia

func _testar_tabelas(tabelas: TabelasProbabilidade, captura: TabelasCaptura) -> void:
	print("\nTabelas de captura")
	var faltando := captura.validar(tabelas)
	_ok(faltando.is_empty(), "coerentes com o vocabulario", ", ".join(faltando))
	_ok(captura.dispositivos.size() >= 3, "dispositivos carregados",
			"%d" % captura.dispositivos.size())
	_ok(captura.iscas.size() >= 5, "iscas carregadas", "%d" % captura.iscas.size())
	_ok(captura.teto() < 1.0 and captura.piso() > 0.0, "clamps sao estocasticos",
			"piso %.2f, teto %.2f" % [captura.piso(), captura.teto()])

	# Toda especie do vocabulario precisa de ao menos uma isca preferida, senao
	# um bestiario inteiro fica sem a camada de isca sem ninguem perceber.
	var sem_isca := PackedStringArray()
	for animal: String in tabelas.animais():
		var achou := false
		for isca in captura.iscas:
			if animal in isca.tipos_preferidos:
				achou = true
				break
		if not achou:
			sem_isca.append(animal)
	_ok(sem_isca.is_empty(), "todo animal base tem isca preferida", ", ".join(sem_isca))

	# Arte x dado: todo item declarado precisa de icone na folha. Sem esta
	# verificacao, um item novo em data/captura/*.json apareceria na roda como um
	# buraco — e so na tela, so quando alguem abrisse aquela roda.
	var sem_icone := PackedStringArray()
	var com_icone: Array = IconeCaptura.ids_conhecidos()
	for item: ItemCaptura in (captura.dispositivos as Array) + (captura.iscas as Array):
		if not item.id in com_icone:
			sem_icone.append(item.id)
	_ok(sem_icone.is_empty(), "todo item tem icone em arte/itens/", ", ".join(sem_icone))

	# A fonte precisa cobrir o que a interface escreve — inclusive acentos e os
	# sinais usados nos rotulos. Glifo ausente nao da erro: sai uma caixa vazia.
	var fonte := TemaEncontro.fonte()
	var faltando_glifo := PackedStringArray()
	var amostra := "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789"
	amostra += " ×·—+%()[].,:!?ÁÂÃÉÊÍÓÔÕÚÇáâãéêíóôõúüç▶"
	for item: ItemCaptura in (captura.dispositivos as Array) + (captura.iscas as Array):
		amostra += item.nome + item.descricao
	for i in amostra.length():
		var c: String = amostra[i]
		if not fonte.has_char(c.unicode_at(0)) and not c in faltando_glifo:
			faltando_glifo.append(c)
	_ok(faltando_glifo.is_empty(), "a fonte cobre o texto da interface",
			"".join(faltando_glifo))
	_etapas += 1


func _testar_afinidade(tabelas: TabelasProbabilidade, captura: TabelasCaptura) -> void:
	print("\nAfinidade (evasao derivada da morfologia sorteada)")
	var fatores := captura.fatores_de_evasao()

	var pelado := _criatura("agua", "peixe", "medio", {})
	_ok(is_equal_approx(AfinidadeCriatura.multiplicador_evasao(pelado, fatores), 1.0),
			"sem apendices, evasao neutra")

	var peixe := _criatura("agua", "peixe", "medio",
			{"escamas": true, "nadadeiras": true})
	var gato := _criatura("fogo", "gato", "medio", {"garras": true})
	var e_peixe := AfinidadeCriatura.multiplicador_evasao(peixe, fatores)
	var e_gato := AfinidadeCriatura.multiplicador_evasao(gato, fatores)
	_ok(e_peixe < e_gato, "peixe escamado/com nadadeiras evade mais que gato com garras",
			"%.3f < %.3f" % [e_peixe, e_gato])
	_ok(e_peixe < 1.0 and e_gato < 1.0, "todo apendice reduz a chance")

	# O vigor e funcao dos atributos: compacto aguenta mais que alongado.
	var cfgv := captura.config_vigor()
	var compacto := _criatura("terra", "reptil", "compacto", {"escamas": true})
	var alongado := _criatura("ar", "reptil", "alongado", {"escamas": true})
	_ok(AfinidadeCriatura.vigor_maximo(compacto, cfgv)
			> AfinidadeCriatura.vigor_maximo(alongado, cfgv),
			"porte compacto tem mais vigor que alongado")

	var faixas := captura.faixas_de_estado()
	_ok(String(AfinidadeCriatura.faixa_de_estado(1.0, faixas)["id"]) == "intacta",
			"vigor cheio = intacta")
	_ok(String(AfinidadeCriatura.faixa_de_estado(0.2, faixas)["id"]) == "exausta",
			"vigor baixo = exausta")
	_ok(float(AfinidadeCriatura.faixa_de_estado(0.2, faixas)["multiplicador"])
			> float(AfinidadeCriatura.faixa_de_estado(1.0, faixas)["multiplicador"]),
			"criatura exausta e mais facil de capturar")
	# Todo traco do vocabulario tem de pesar na evasao: um esquecido aqui nao daria
	# erro, daria uma criatura silenciosamente mais facil do que a tabela pretende.
	_ok(fatores.size() == tabelas.features_morfologia().size(),
			"todo traco do vocabulario tem fator de evasao",
			"%d de %d" % [fatores.size(), tabelas.features_morfologia().size()])
	_etapas += 1


# --------------------------------------------------------------- 2. a formula

func _testar_formula(captura: TabelasCaptura) -> void:
	print("\nFormula de captura")
	var peixe := _criatura("agua", "peixe", "medio", {"escamas": true, "nadadeiras": true})
	var ave := _criatura("ar", "ave", "esbelto", {"asas": true, "garras": true})

	var simples := captura.dispositivo("esfera_simples")
	var redoma := captura.dispositivo("redoma_aquatica")
	var rede := captura.dispositivo("rede_de_caca")

	var p_simples := CalculoCaptura.chance(peixe, simples, null, 1.0, captura)
	var p_redoma := CalculoCaptura.chance(peixe, redoma, null, 1.0, captura)
	var p_rede := CalculoCaptura.chance(peixe, rede, null, 1.0, captura)
	_ok(p_redoma > p_simples, "dispositivo certo bate o generico no peixe",
			"redoma %.2f > simples %.2f" % [p_redoma, p_simples])
	_ok(p_redoma > p_rede, "dispositivo errado nao vence o certo",
			"redoma %.2f > rede %.2f" % [p_redoma, p_rede])

	var p_ave_rede := CalculoCaptura.chance(ave, rede, null, 1.0, captura)
	var p_ave_simples := CalculoCaptura.chance(ave, simples, null, 1.0, captura)
	_ok(p_ave_rede > p_ave_simples, "a rede brilha contra asas",
			"rede %.2f > simples %.2f" % [p_ave_rede, p_ave_simples])
	_ok(p_ave_rede > p_rede, "o mesmo dispositivo muda de valor conforme a criatura",
			"ave %.2f > peixe %.2f" % [p_ave_rede, p_rede])

	# Clamps: nem garantido, nem impossivel.
	var prisma := captura.dispositivo("prisma_selante")
	var facil := _criatura("planta", "canino", "medio", {})
	var osso := captura.isca("osso")
	var p_max := CalculoCaptura.chance(facil, prisma, osso, 0.05, captura)
	_ok(p_max <= captura.teto() + 0.0001, "tudo certo nao garante captura",
			"%.2f <= %.2f" % [p_max, captura.teto()])
	var p_min := CalculoCaptura.chance(peixe, rede, null, 1.0, captura)
	_ok(p_min >= captura.piso(), "nenhuma criatura e impossivel",
			"%.2f >= %.2f" % [p_min, captura.piso()])

	# Estado: atacar antes de lancar tem de valer a pena.
	var p_intacta := CalculoCaptura.chance(peixe, redoma, null, 1.0, captura)
	var p_exausta := CalculoCaptura.chance(peixe, redoma, null, 0.1, captura)
	_ok(p_exausta > p_intacta, "criatura enfraquecida sobe a chance",
			"%.2f > %.2f" % [p_exausta, p_intacta])

	var detalhe := CalculoCaptura.avaliar(peixe, redoma, osso, 1.0, captura)
	_ok(detalhe["fatores"].size() == 4, "a avaliacao devolve os 4 fatores",
			"%d" % detalhe["fatores"].size())
	_etapas += 1


func _testar_iscas(captura: TabelasCaptura) -> void:
	print("\nIscas (preferencia pelo animal base)")
	var canino := _criatura("terra", "canino", "medio", {"garras": true})
	var osso := captura.isca("osso")
	var nectar := captura.isca("nectar_floral")
	var simples := captura.dispositivo("esfera_simples")

	_ok(osso.preferida_por(canino), "osso e preferido por canino")
	_ok(not nectar.preferida_por(canino), "nectar nao e preferido por canino")

	var sem := CalculoCaptura.chance(canino, simples, null, 1.0, captura)
	var certa := CalculoCaptura.chance(canino, simples, osso, 1.0, captura)
	var errada := CalculoCaptura.chance(canino, simples, nectar, 1.0, captura)
	_ok(certa > errada, "isca certa bate isca errada",
			"%.2f > %.2f" % [certa, errada])
	_ok(certa / sem > 1.30, "isca certa muda o jogo (>30%)",
			"x%.2f" % (certa / sem))
	_ok(errada / sem < 1.10, "isca errada quase nao ajuda",
			"x%.2f" % (errada / sem))

	# Uma isca com varios tipos preferidos precisa valer para todos eles.
	var larva := captura.isca("larva_viva")
	var acertos := 0
	for animal: String in larva.tipos_preferidos:
		if larva.preferida_por(_criatura("terra", animal, "medio", {})):
			acertos += 1
	_ok(acertos == larva.tipos_preferidos.size(),
			"isca multi-tipo vale para todos os tipos que declara")
	_etapas += 1


# ----------------------------------------------------------- 3. estado e bolsa

func _testar_inventario(captura: TabelasCaptura) -> void:
	print("\nInventario")
	var inv := InventarioJogador.inicial(captura)
	var simples := captura.dispositivo("esfera_simples")
	var antes := inv.quantidade(simples.id)
	_ok(antes > 0, "carga inicial veio do JSON", "%dx %s" % [antes, simples.nome])

	_ok(inv.consumir(simples.id), "consumir com estoque")
	_ok(inv.quantidade(simples.id) == antes - 1, "quantidade caiu em 1")

	var prisma := captura.dispositivo("prisma_selante")
	while inv.tem(prisma.id):
		inv.consumir(prisma.id)
	_ok(inv.quantidade(prisma.id) == 0, "estoque zera")
	_ok(not inv.consumir(prisma.id), "consumir sem estoque falha")
	_ok(inv.quantidade(prisma.id) == 0, "e nao deixa quantidade negativa")

	var avisado := [false]
	inv.mudou.connect(func(_id, _n): avisado[0] = true)
	inv.adicionar(prisma.id, 2)
	_ok(avisado[0], "sinal 'mudou' dispara para a interface atualizar")
	_ok(inv.quantidade(prisma.id) == 2, "adicionar repoe o estoque")

	var c := _criatura("fogo", "gato", "medio", {"garras": true})
	inv.guardar_criatura(c)
	_ok(inv.colecao.size() == 1 and inv.ja_capturou(c), "criatura entra na colecao")
	_ok(inv.total_de(captura.dispositivos) > 0, "total_de soma o estoque de uma lista")
	_etapas += 1


func _testar_maquina_de_estados() -> void:
	print("\nMaquina de estados")
	var e := EstadoEncontro.new()
	var E := EstadoEncontro.Estado
	_ok(e.e(E.INATIVO) and not e.em_encontro(), "comeca inativa")

	# Caminho feliz completo.
	var caminho := [E.DETECTADO, E.AVISO, E.TRANSICAO, E.APRESENTACAO, E.INTERACAO,
			E.RODA_DISPOSITIVO, E.LANCANDO, E.SUCESSO, E.ENCERRANDO, E.INATIVO]
	var todas_ok := true
	for passo in caminho:
		if not e.mudar_para(passo):
			todas_ok = false
	_ok(todas_ok and e.e(E.INATIVO), "caminho completo ate a captura")

	# Um segundo lance a partir do lancamento nao pode existir: e o que impede
	# duas tentativas simultaneas.
	e.reiniciar()
	for passo in [E.DETECTADO, E.AVISO, E.TRANSICAO, E.APRESENTACAO, E.INTERACAO,
			E.RODA_DISPOSITIVO, E.LANCANDO]:
		e.mudar_para(passo)
	_ok(not e.pode_ir_para(E.LANCANDO), "LANCANDO -> LANCANDO e proibido")
	_ok(not e.pode_ir_para(E.RODA_DISPOSITIVO), "nao se abre a roda com o lance no ar")
	_ok(not e.aceita_entrada(), "nenhuma entrada e aceita durante o lance")
	_ok(e.pode_ir_para(E.FALHA) and e.pode_ir_para(E.SUCESSO),
			"do lance so se sai por sucesso ou falha")

	e.mudar_para(E.FALHA)
	_ok(e.pode_ir_para(E.INTERACAO), "falha devolve ao menu")
	_ok(e.pode_ir_para(E.ENCERRANDO), "falha tambem pode encerrar (fuga)")
	e.reiniciar()
	_ok(e.e(E.INATIVO), "reiniciar limpa de qualquer estado")
	_etapas += 1


func _testar_determinismo(captura: TabelasCaptura) -> void:
	print("\nDeterminismo (RF03)")
	var c := _criatura("agua", "peixe", "medio", {"escamas": true, "nadadeiras": true})
	var d := captura.dispositivo("redoma_aquatica")
	var a := _sequencia_de_lances(SEED, c, d, captura)
	var b := _sequencia_de_lances(SEED, c, d, captura)
	var outra := _sequencia_de_lances(SEED + 1, c, d, captura)
	_ok(a == b, "mesma seed, mesma sequencia de resultados")
	_ok(a != outra, "seed diferente, sequencia diferente")
	_etapas += 1


func _sequencia_de_lances(semente: int, c: Criatura, d: DispositivoCaptura,
		captura: TabelasCaptura) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = semente
	var saida: Array = []
	for i in 20:
		saida.append(CalculoCaptura.tentar(rng, c, d, null, 1.0, captura)["sucesso"])
	return saida


# ------------------------------------------------ 4. fluxo completo, com cena

func _testar_fluxo_completo() -> void:
	print("\nFluxo completo na vila (cena e fisica reais)")
	var mundo := MundoIso.new()
	get_tree().root.add_child(mundo)
	mundo.carregar()
	if not _ok(mundo.erro == "", "vila carregou", mundo.erro):
		return

	var jogador := Jogador.new()
	jogador.position = mundo.spawn_do_jogador()
	mundo.entidades.add_child(jogador)
	var camera := CameraExploracao.new()
	get_tree().root.add_child(camera)
	camera.seguir(jogador)
	await get_tree().process_frame

	var t0 := Time.get_ticks_usec()
	var g := GerenciadorEncontro.new()
	get_tree().root.add_child(g)
	var pronto := g.preparar(mundo, jogador, camera, SEED, N)
	var ms := (Time.get_ticks_usec() - t0) / 1000.0
	if not _ok(pronto, "gerenciador montou", g.erro):
		return
	_ok(g.bestiario.size() == N, "bestiario da partida gerado", "%d criaturas" % N)
	_ok(ms < 2000.0, "montagem dentro da meta de desempenho", "%.0f ms" % ms)
	_acelerar(g)
	await get_tree().process_frame

	# Sem criatura de pe nao ha encontro.
	_ok(not g.pode_comecar(), "sem equipe, o encontro nao comeca")
	g.equipe.adicionar(Combatente.de_criatura(g.bestiario[0], g.tabelas_batalha))
	g.equipe.adicionar(Combatente.de_criatura(g.bestiario[1], g.tabelas_batalha))
	_ok(g.pode_comecar(), "com equipe, pode")

	var zona := _zona(mundo, "margem_do_lago")
	if not _ok(zona != null, "zona de teste encontrada"):
		return

	# --- roteiro de abertura ---
	g.iniciar(zona)
	_ok(jogador.congelado, "jogador congela no instante do encontro")
	_ok(g.estado.em_encontro(), "maquina saiu de INATIVO")
	# Ainda no primeiro await do roteiro: o tremor acabou de ser disparado.
	_ok(camera.tremendo(), "a camera treme no instante do encontro")
	await _ate_o_menu(g)
	var criatura := g.criatura_atual()
	_ok(criatura != null, "criatura sorteada", str(criatura))
	_ok(g.estado.e(EstadoEncontro.Estado.INTERACAO), "roteiro chegou ao menu",
			EstadoEncontro.nome(g.estado.atual))
	_ok(not camera.tremendo() and camera.offset == Vector2.ZERO,
			"o tremor termina zerado, sem deixar a camera torta")

	# A regiao filtra quem aparece, mas o bestiario nao muda.
	var na_regiao := 0
	for i in 40:
		var c: Criatura = g._sortear_criatura(zona)
		if c.elemento in zona.elementos_provaveis:
			na_regiao += 1
	_ok(na_regiao > 20, "a zona favorece os elementos que declara",
			"%d/40 em %s" % [na_regiao, ", ".join(zona.elementos_provaveis)])

	# --- fugir, com a chance forcada: o sorteio e testado em test_batalha ---
	var fuga: Dictionary = g.tabelas_batalha.fuga()
	fuga["base"] = 1.0
	fuga["piso"] = 1.0
	fuga["teto"] = 1.0
	g._on_acao(InterfaceEncontro.Acao.FUGIR)
	await _ate_inativo(g)
	_ok(g.estado.e(EstadoEncontro.Estado.INATIVO), "fugir encerra o encontro")
	_ok(not jogador.congelado, "jogador volta a andar")
	_ok(g.criatura_atual() == null, "estado do encontro foi limpo")

	# --- segundo encontro: isca, ataque e captura forcada ---
	g._carencia = 0.0
	g.iniciar(zona)
	await _ate_o_menu(g)
	criatura = g.criatura_atual()
	_ok(criatura != null, "segundo encontro abre normalmente")

	var isca := _isca_preferida(g, criatura)
	var antes_isca := g.inventario.quantidade(isca.id)
	g._on_acao(InterfaceEncontro.Acao.ISCA)
	await get_tree().process_frame
	_ok(g.estado.e(EstadoEncontro.Estado.RODA_ISCA), "menu abre a roda de iscas")
	g._on_item(isca)
	# Espera o estado assentar: desde que a roda se recolhe antes de resolver a
	# acao, _on_item leva alguns quadros ate devolver o controle ao menu.
	await _ate_o_menu(g)
	_ok(g.inventario.quantidade(isca.id) == antes_isca - 1, "a isca foi consumida")
	_ok(g.isca_ativa() == isca, "a isca fica ativa pelo resto do encontro")
	_ok(g.estado.e(EstadoEncontro.Estado.INTERACAO), "e o controle volta ao menu")
	_ok(g.motor.turno == 1, "a isca gastou o turno", "turno %d" % g.motor.turno)

	var chance_com_isca := CalculoCaptura.chance(criatura,
			g.captura.dispositivo("esfera_simples"), g.isca_ativa(), 1.0, g.captura)
	var chance_sem_isca := CalculoCaptura.chance(criatura,
			g.captura.dispositivo("esfera_simples"), null, 1.0, g.captura)
	_ok(chance_com_isca > chance_sem_isca, "a isca ativa entra no calculo do lance",
			"%.2f > %.2f" % [chance_com_isca, chance_sem_isca])

	# --- cancelar a roda ---
	g._on_acao(InterfaceEncontro.Acao.CAPTURAR)
	await get_tree().process_frame
	_ok(g.estado.e(EstadoEncontro.Estado.RODA_DISPOSITIVO), "roda de dispositivos abriu")
	g._on_roda_cancelada()
	await _ate_o_menu(g)
	_ok(g.estado.e(EstadoEncontro.Estado.INTERACAO), "cancelar a roda volta ao menu")

	# --- golpe: pelo menu de batalha, ate o motor ---
	_curar(g)
	var vida_antes: int = g.motor.inimigo().vida
	var jato := g.motor.jogador().ficha.golpes.filter(
			func(x: Golpe) -> bool: return x.causa_dano() and x.precisao >= 0.9)
	g.motor.inimigo().ficha.esquiva = 0.0
	g.motor.inimigo().vida = 100000
	vida_antes = 100000
	g._on_acao(InterfaceEncontro.Acao.GOLPES)
	await get_tree().process_frame
	_ok(g.estado.e(EstadoEncontro.Estado.INTERACAO), "abrir os golpes nao gasta o turno")
	var turno_antes: int = g.motor.turno
	for tentativa in 10:
		if g.motor.inimigo().vida < vida_antes:
			break
		_curar(g)
		g._on_lista({"tipo": "golpe", "golpe": jato[0]})
		await _ate_o_menu(g)
	_ok(g.motor.inimigo().vida < vida_antes, "o golpe derruba a vida do adversario",
			"%d -> %d" % [vida_antes, g.motor.inimigo().vida])
	_ok(g.motor.turno > turno_antes, "e gasta o turno")
	_ok(g._fracao_vigor() <= 1.0, "a captura le a fracao de vida do adversario")
	g.motor.inimigo().vida = g.motor.inimigo().ficha.vida
	_curar(g)

	# --- bolsa em batalha, com a poção do catalogo ---
	g.motor.jogador().vida = 1
	var pocao := "pocao_simples"
	g.inventario.adicionar(pocao, 1)
	var pocoes: int = g.inventario.quantidade(pocao)
	g._on_acao(InterfaceEncontro.Acao.BOLSA)
	await get_tree().process_frame
	g._on_lista({"tipo": "item", "id": pocao, "nome": "Poção", "alvo": g.motor.ativo_jogador,
			"efeito": {"tipo": "curar", "valor": 30}})
	await _ate_o_menu(g)
	_ok(g.inventario.quantidade(pocao) == pocoes - 1, "a poção foi consumida na batalha")
	_ok(g.estado.e(EstadoEncontro.Estado.INTERACAO) or g.motor.terminou(), "e o turno passou")
	_curar(g)

	# --- troca voluntaria ---
	var quem_saiu := g.motor.jogador()
	g._on_lista({"tipo": "trocar", "indice": 1 - g.motor.ativo_jogador})
	await _ate_o_menu(g)
	_ok(g.motor.jogador() != quem_saiu, "trocar poe outra criatura em campo")
	_curar(g)

	# --- lance com sucesso garantido (teto forcado) ---
	var colecao_antes := g.inventario.colecao.size()
	var dispositivo := g.captura.dispositivo("esfera_simples")
	var estoque_antes := g.inventario.quantidade(dispositivo.id)
	g.captura.balanceamento["base"] = 5.0        # forca sucesso dentro do teto
	g.captura.balanceamento["teto"] = 1.0
	var tamanho_equipe := g.equipe.ativos.size()
	g._on_acao(InterfaceEncontro.Acao.CAPTURAR)
	await get_tree().process_frame
	g._on_item(dispositivo)
	await _ate_inativo(g)
	_ok(g.equipe.ativos.size() == tamanho_equipe + 1, "a capturada entrou na equipe")
	_ok(g.inventario.quantidade(dispositivo.id) == estoque_antes - 1,
			"o dispositivo foi consumido no lance")
	_ok(g.inventario.colecao.size() == colecao_antes + 1,
			"criatura capturada entrou na colecao")
	_ok(g.estado.e(EstadoEncontro.Estado.INATIVO), "encontro encerra apos a captura")
	_ok(not jogador.congelado, "controle devolvido depois da captura")

	# --- lance com falha garantida ---
	g.captura.balanceamento["base"] = 0.0
	g.captura.balanceamento["piso"] = 0.0
	g.captura.balanceamento["fuga"]["chance_por_falha_extra"] = 0.0
	g._carencia = 0.0
	g.iniciar(zona)
	await _ate_o_menu(g)
	# Regressao: a captura anterior encolheu e apagou o retrato para "sugar" a
	# criatura. O encontro seguinte tem de reabrir com o quadro cheio.
	_ok(g._interface._render.modulate.a > 0.99
			and g._interface._render.scale.is_equal_approx(Vector2.ONE),
			"o retrato volta ao normal no encontro seguinte a uma captura")
	estoque_antes = g.inventario.quantidade(dispositivo.id)
	colecao_antes = g.inventario.colecao.size()
	g._on_acao(InterfaceEncontro.Acao.CAPTURAR)
	await get_tree().process_frame
	g._on_item(dispositivo)
	await _ate_o_menu(g)
	_ok(g.estado.e(EstadoEncontro.Estado.INTERACAO), "falha devolve ao menu")
	_ok(g.criatura_atual() != null, "a criatura continua no encontro")
	_ok(g.motor.turno >= 1, "a falha gastou o turno: a criatura revidou")
	_ok(g.inventario.colecao.size() == colecao_antes, "nada entrou na colecao")
	_ok(g.inventario.quantidade(dispositivo.id) == estoque_antes - 1,
			"o dispositivo se gasta mesmo na falha")
	_ok(g._falhas == 1, "a falha foi contabilizada para o risco de fuga")

	# --- bolsa vazia ---
	for d in g.captura.dispositivos:
		while g.inventario.tem(d.id):
			g.inventario.consumir(d.id)
	g._on_acao(InterfaceEncontro.Acao.CAPTURAR)
	await get_tree().process_frame
	_ok(g.estado.e(EstadoEncontro.Estado.INTERACAO),
			"sem dispositivos, a roda nao abre e o menu continua vivo")
	for i in g.captura.iscas:
		while g.inventario.tem(i.id):
			g.inventario.consumir(i.id)
	g._on_acao(InterfaceEncontro.Acao.ISCA)
	await get_tree().process_frame
	_ok(g.estado.e(EstadoEncontro.Estado.INTERACAO), "sem iscas, idem")

	# --- roda nao seleciona item zerado ---
	var roda := RodaCaptura.new()
	get_tree().root.add_child(roda)
	var inv := InventarioJogador.new()
	inv.adicionar(g.captura.dispositivos[1].id, 3)   # so o segundo tem estoque
	await roda.abrir("teste", g.captura.dispositivos, inv,
			func(_i): return {}, 0.0)
	_ok(roda.item_selecionado() != null
			and roda.item_selecionado().id == g.captura.dispositivos[1].id,
			"a roda comeca no primeiro item COM estoque")
	roda._girar(1)
	_ok(roda.item_selecionado().id == g.captura.dispositivos[1].id,
			"girar nao pousa em item zerado")
	await roda.fechar(0.0)
	roda.queue_free()

	# --- encerrar e recomecar ---
	g._encerrar("teste")
	await _ate_inativo(g)
	g._carencia = 0.0
	g.iniciar(zona)
	await _ate_o_menu(g)
	_ok(g.estado.e(EstadoEncontro.Estado.INTERACAO), "um novo encontro abre depois de tudo")
	_ok(g.isca_ativa() == null and g._falhas == 0,
			"isca e contagem de falhas nao vazam do encontro anterior")
	g._on_acao(InterfaceEncontro.Acao.FUGIR)
	await _ate_inativo(g)

	await _testar_duelo_e_derrota(g, zona)

	# --- deteccao pela caminhada ---
	_ok(g.zonas_ativas() >= 0, "contagem de zonas ativas acessivel")
	g._carencia = 0.0
	g._zonas = [zona]
	g.cfg.chance_por_passo = 1.0
	g._posicao_anterior = jogador.global_position
	jogador.global_position += Vector2(200, 0)
	await get_tree().process_frame
	await get_tree().process_frame
	_ok(g.estado.em_encontro(), "andar dentro da zona dispara o encontro")

	# Encerrar NO MEIO do roteiro de abertura: a corrotina que estava esperando
	# nao pode acordar depois e mexer num encontro que ja acabou.
	g._encerrar("interrompido")
	await _ate_inativo(g)
	for i in 30:
		await get_tree().process_frame
	_ok(g.estado.e(EstadoEncontro.Estado.INATIVO),
			"encerrar durante a abertura nao deixa o roteiro acordar depois")
	_ok(g.criatura_atual() == null, "e nao ressuscita a criatura do encontro morto")
	_ok(not jogador.congelado, "o jogador nao fica preso por um encontro interrompido")
	_etapas += 1


## Duelo contra guardiao, troca obrigatoria e derrota, passando pelo gerenciador.
func _testar_duelo_e_derrota(g: GerenciadorEncontro, zona: PontoDeEncontro) -> void:
	print("\nDuelo, troca obrigatoria e derrota")
	var desfechos: Array = []
	var ouvir := func(d: String, _c: Criatura) -> void: desfechos.append(d)
	g.encontro_terminado.connect(ouvir)
	_curar(g)

	var guardiao := {"id": "teste", "nome": "Teste", "titulo": "DUELO", "selo": "selo_teste"}
	g.iniciar_duelo(guardiao, [g.bestiario[10], g.bestiario[11]])
	await _ate_o_menu(g)
	_ok(g.em_duelo(), "o duelo passa pelo mesmo gerenciador")
	_ok(g.motor.tipo_inimigo == "guardiao", "com o motor no modo guardiao")
	var menu: Array = g._interface._itens_menu
	var acoes := menu.map(func(o: Dictionary) -> int: return int(o["acao"]))
	_ok(not InterfaceEncontro.Acao.CAPTURAR in acoes and not InterfaceEncontro.Acao.FUGIR in acoes,
			"no duelo nao se captura nem se foge")

	# Vencer: o adversario com 1 de vida e sem esquiva.
	for c: Combatente in g.motor.lado_inimigo:
		c.vida = 1
		c.ficha.esquiva = 0.0
	var investida := g.tabelas_batalha.de_reserva()
	for tentativa in 12:
		if not g.estado.em_encontro():
			break
		_curar(g)
		g.motor.jogador().ficha.velocidade = 999.0
		g._on_lista({"tipo": "golpe", "golpe": investida})
		await _ate_o_menu(g)
	await _ate_inativo(g)
	_ok(not desfechos.is_empty() and desfechos.back() == "duelo_vencido",
			"derrubar a equipe do guardiao vence o duelo", str(desfechos))

	# Troca obrigatoria e derrota: as duas primeiras caem no golpe do adversario.
	_curar(g)
	g.iniciar_duelo(guardiao, [g.bestiario[12]])
	await _ate_o_menu(g)
	var forcou := false
	for tentativa in 80:
		if not g.estado.em_encontro():
			break
		if g.estado.e(EstadoEncontro.Estado.TROCA_OBRIGATORIA):
			forcou = true
			_ok(not g._interface._lista_cancelavel, "a troca obrigatoria nao se cancela")
			g._on_lista(g._itens_de_troca("trocar_forcada")[0]["valor"])
			await _ate_decisao(g)
			continue
		g.motor.jogador().vida = 1
		g.motor.jogador().ficha.esquiva = 0.0
		g._resolver_turno({"tipo": "passar"})
		await _ate_decisao(g)
	await _ate_inativo(g)
	_ok(forcou, "cair com reserva viva obriga a trocar")
	_ok(desfechos.back() == "derrota", "a equipe inteira no chao e derrota", str(desfechos))
	_ok(not g.equipe.tem_vivos(), "ninguem de pe depois da derrota")
	_ok(not g.pode_comecar(), "e nenhum encontro comeca assim")
	g.iniciar(zona)
	_ok(not g.estado.em_encontro(), "iniciar() recusa")
	g.encontro_terminado.disconnect(ouvir)
	_curar(g)
	_etapas += 1


# ------------------------------------------------------------------- utilidades

## Espera o jogador ter de decidir algo, ou o encontro acabar.
func _ate_decisao(g: GerenciadorEncontro) -> void:
	var parou := func() -> bool:
		return g.estado.aceita_entrada() or not g.estado.em_encontro()
	await _ate(g, parou)


func _curar(g: GerenciadorEncontro) -> void:
	for c: Combatente in g.equipe.ativos + g.equipe.deposito:
		c.vida = c.ficha.vida


## Reduz o roteiro ao minimo para o teste nao gastar segundos em fades.
func _acelerar(g: GerenciadorEncontro) -> void:
	g.cfg.duracao_aviso = RITMO_DE_TESTE
	g.cfg.duracao_tremor = RITMO_DE_TESTE
	g.cfg.atraso_apos_aviso = RITMO_DE_TESTE
	g.cfg.duracao_escurecimento = RITMO_DE_TESTE
	g.cfg.duracao_texto_encontro = RITMO_DE_TESTE
	g.cfg.duracao_abertura_menu = RITMO_DE_TESTE
	g.cfg.duracao_abertura_roda = 0.0
	g.cfg.duracao_lancamento = RITMO_DE_TESTE
	g.cfg.duracao_balanco = RITMO_DE_TESTE
	g.cfg.balancos = 1
	g.cfg.duracao_desfecho = RITMO_DE_TESTE
	g.cfg.duracao_encerramento = RITMO_DE_TESTE
	g.cfg.carencia_segundos = 0.0
	g.cfg.duracao_evento_batalha = RITMO_DE_TESTE


## Espera a maquina chegar a INTERACAO (ou desistir). Espera por ESTADO e nao por
## tempo fixo: um teste que dorme "o bastante" passa a falhar sozinho no dia em
## que alguem ajustar uma duracao no JSON.
func _ate_o_menu(g: GerenciadorEncontro) -> void:
	var parou := func() -> bool:
		return g.estado.e(EstadoEncontro.Estado.INTERACAO) \
				or g.estado.e(EstadoEncontro.Estado.INATIVO)
	await _ate(g, parou)


func _ate_inativo(g: GerenciadorEncontro) -> void:
	await _ate(g, func(): return g.estado.e(EstadoEncontro.Estado.INATIVO))


func _ate(g: GerenciadorEncontro, condicao: Callable, limite: int = 900) -> void:
	for i in limite:
		if condicao.call():
			return
		await get_tree().process_frame
	push_error("teste: tempo esgotado esperando; estado = "
			+ EstadoEncontro.nome(g.estado.atual))


func _zona(mundo: MundoIso, id: String) -> PontoDeEncontro:
	for no in mundo.pontos_de_encontro.get_children():
		var p := no as PontoDeEncontro
		if p != null and p.id_ponto == id:
			return p
	var filhos := mundo.pontos_de_encontro.get_children()
	return filhos[0] if not filhos.is_empty() else null


func _isca_preferida(g: GerenciadorEncontro, c: Criatura) -> IscaCaptura:
	for isca in g.captura.iscas:
		if isca.preferida_por(c) and g.inventario.tem(isca.id):
			return isca
	return g.captura.iscas[0]


## Criatura montada a mao, com atributos escolhidos — o gerador continua sendo
## testado em test_gerador.gd; aqui interessa a REACAO da captura a atributos
## conhecidos.
func _criatura(elemento: String, animal: String, porte: String,
		morfologia: Dictionary) -> Criatura:
	var c := Criatura.new()
	c.elemento = elemento
	c.animal_base = animal
	c.porte = porte
	c.paleta = "neutra"
	c.matiz = "cinza"
	c.body_id = CatalogoCorpos.montar_body_id(animal, 1, porte)
	for f in ["garras", "escamas", "asas", "nadadeiras"]:
		c.morfologia[f] = bool(morfologia.get(f, false))
		if c.morfologia[f]:
			c.variantes[f] = 0
	return c
