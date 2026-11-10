extends Node

## Teste do JOGO DE PONTA A PONTA, no mundo de verdade. Roda como cena:
##   godot --headless --path . res://tools/test_arco.tscn
##
## O que os outros testes nao cobrem: as LIGACOES de mundo.gd. A regra de batalha esta
## em test_batalha e o gerenciador em test_encontro; aqui se confere o caminho que o
## jogador faz, pelos servicos do dialogo e pelas telas:
##
##   1. partida nova: abre na chegada de onibus (pulada aqui); sem equipe nao ha
##      encontro, e o objetivo aponta a Mirela
##   2. a Mirela oferece 3 criaturas da seed; a escolhida entra na equipe; salva sozinho
##   3. cura gratuita da Mirela, poção pela bolsa e tela de equipe
##   4. o save guarda a equipe e a vida, e recarregar devolve as duas
##   5. a Dulce desafia, o duelo acontece com criaturas da seed e a vitoria da o selo,
##      a tela final e o dado de coerencia
##   6. perder a equipe em batalha mostra a derrota, e voltar ao save restaura a partida
##   7. a pesca: fisgar fora da licao vira batalha, e a pesca espera ela acabar
##   8. a fonte cobre o texto que so a batalha escreve
##   9. a batalha pelas teclas do jogador, e nao por chamadas internas
##  10. F2, F3 e F4 so existem no editor e na build de debug; F5 vale sempre
##  11. card do objetivo, controles so no comeco e na pausa, tela cheia
##  12. o bestiario da seed na pausa e na tecla N, com marca nas capturadas
##  13. gold, kit da Mirela, loja, recompensa por selvagem e premio da guardia
##  14. a fabrica: portao trancado sem o selo, interior com o Otavio, duelo, volta
##
## Grava em user://saves_teste_arco/, nunca nos saves reais. Um vigia derruba o teste se
## algo travar, e o resultado so e positivo se a ultima linha de cada etapa for alcancada.

const CENA_MUNDO := "res://presentation/exploracao/mundo.tscn"
const SEED_TESTE := 424242
const DIR_TESTE := "user://saves_teste_arco/"
const SLOT := 2
const TETO_TOTAL := 120.0

## Quantas funcoes _testar_* existem. Um erro de script dentro de uma delas devolve null
## ao chamador e a execucao segue: so a ultima linha de cada etapa prova que ela rodou.
const ETAPAS := 14

var _falhas: int = 0
var _verificacoes: int = 0
var _etapas: int = 0
var _dir_real: String = ""
var _m: Node2D


func _ready() -> void:
	await get_tree().process_frame
	# change_scene_to_file libera a cena corrente, e o jogo troca de cena ao voltar ao
	# save. O teste nao pode ser ela: uma cena vazia fica no lugar para ser liberada.
	var lugar := Node.new()
	get_tree().root.add_child(lugar)
	get_tree().current_scene = lugar
	var vigia := Timer.new()
	vigia.one_shot = true
	vigia.wait_time = TETO_TOTAL
	vigia.ignore_time_scale = true
	vigia.process_mode = Node.PROCESS_MODE_ALWAYS
	vigia.timeout.connect(_estourou)
	add_child(vigia)
	vigia.start()

	print("== Arco do jogo — teste de cena ==")
	_dir_real = ArquivoSave.diretorio
	ArquivoSave.diretorio = DIR_TESTE
	_limpar_saves()
	await _rodar()
	_limpar_saves()
	ArquivoSave.diretorio = _dir_real
	Save.encerrar_partida()
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


func _estourou() -> void:
	ArquivoSave.diretorio = _dir_real
	print("\nRESULTADO: TEMPO ESGOTADO apos %d verificacoes, %d falha(s)"
			% [_verificacoes, _falhas])
	get_tree().quit(1)


func _ok(condicao: bool, rotulo: String, detalhe: String = "") -> bool:
	print("    %s %s%s" % ["OK  " if condicao else "FALHOU", rotulo,
			"" if detalhe == "" else "  — " + detalhe])
	_verificacoes += 1
	if not condicao:
		_falhas += 1
	return condicao


func _rodar() -> void:
	Save.nova_partida(SEED_TESTE, "teste", SLOT)
	await _subir_mundo()
	await _testar_inicio()
	await _testar_primeira_criatura()
	_testar_cura_e_bolsa()
	await _testar_save()
	await _testar_vitoria()
	await _testar_derrota()
	await _testar_pesca()
	_testar_glifos()
	await _testar_teclado()
	await _testar_teclas_de_desenvolvimento()
	await _testar_hud_e_tela_cheia()
	await _testar_bestiario()
	await _testar_economia()
	await _testar_fabrica()


# ------------------------------------------------------------------- etapas

func _testar_inicio() -> void:
	print("\n1. Partida nova")
	var g: GerenciadorEncontro = _m.encontros
	# A chegada de onibus tem teste proprio (test_chegada). Aqui ela e pulada e a
	# escolha adiada, para o resto do arco seguir pela oferta da Mirela na praca.
	_ok(_m.chegada != null and _m.chegada.ativa(), "comeca pela chegada de onibus")
	_m.chegada.pular()
	await get_tree().process_frame
	_ok(_m.tela_inicial.aberta(), "pular a chegada leva a escolha")
	var adiar := InputEventAction.new()
	adiar.action = "ui_cancel"
	adiar.pressed = true
	_m.tela_inicial._unhandled_input(adiar)
	_ok(not _m.chegada.ativa() and not _m.jogador.congelado, "adiar a escolha encerra a chegada")
	_ok(g.equipe.vazia(), "comeca sem equipe")
	_ok(Bolsa.gold == Bolsa.economia.gold_inicial(), "comeca com o gold inicial", "%d" % Bolsa.gold)
	_ok(Bolsa.quantidade("esfera_simples") == 0 and Bolsa.quantidade("pocao_simples") == 0,
			"e sem dispositivos nem pocoes")
	_ok(not g.pode_comecar(), "sem equipe, nenhum encontro comeca")
	_ok(_m._objetivo_atual().contains("Mirela"), "o objetivo aponta a Mirela", _m._objetivo_atual())
	_ok(not _opcoes_de("dulce", "assuntos").has("Vim desafiar a guardiã do sítio."),
			"sem criatura, a Dulce nao oferece o desafio")
	_etapas += 1


func _testar_primeira_criatura() -> void:
	print("\n2. Primeira criatura, pela Mirela")
	var g: GerenciadorEncontro = _m.encontros
	var mirela: Npc = _m.dialogos.npc_por_id("mirela")
	_ok(_m.dialogos.conversar_com(mirela, "", "oferta"), "a Mirela abre a oferta")
	_ok(_m._dono_da_tela() == "dialogo", "a conversa tem a tela")
	_m.dialogos.encerrar_conversa()
	await get_tree().process_frame
	_ok(_m.tela_inicial.aberta(), "a escolha abre DEPOIS de a conversa fechar")
	_ok(_m._dono_da_tela() == "escolha", "a escolha tem a tela")
	_ok(_m.jogador.congelado, "o jogador espera")
	_ok(_m.tela_inicial._opcoes.size() == 3, "3 opcoes", str(_m.tela_inicial._opcoes.size()))

	# ESC adia a escolha sem prender o jogador, e ela continua disponivel.
	var cancelar := InputEventAction.new()
	cancelar.action = "ui_cancel"
	cancelar.pressed = true
	_m.tela_inicial._unhandled_input(cancelar)
	_ok(not _m.tela_inicial.aberta() and not _m.jogador.congelado, "ESC adia a escolha")
	_ok(g.equipe.vazia(), "e nada entrou na equipe")
	_m._abrir_escolha_inicial()

	var escolhida: Criatura = _m.tela_inicial._opcoes[1]
	_m.tela_inicial._indice = 1
	_m.tela_inicial._confirmar()
	await get_tree().process_frame
	_ok(g.equipe.ativos.size() == 1 and g.equipe.ativos[0].criatura == escolhida,
			"a escolhida entrou na equipe", escolhida.nome())
	_ok(_m.estado_mundo.ativa("recebeu_inicial"), "bandeira posta")
	_ok(not _m.jogador.congelado, "o jogador anda de novo")
	_ok(g.pode_comecar(), "agora ha encontros")
	_ok(g.inventario.ja_capturou(escolhida), "e ela conta na colecao")
	var kit: Dictionary = Bolsa.economia.kit_inicial()
	_ok(Bolsa.quantidade("esfera_simples") == int(kit["esfera_simples"])
			and Bolsa.quantidade("pocao_simples") == int(kit["pocao_simples"]),
			"o kit da Mirela vem junto com a criatura", str(kit))
	_ok(ArquivoSave.ler(SLOT)["estado"] == ArquivoSave.Estado.OK,
			"salvou sozinho: a derrota sempre tem para onde voltar")
	_ok(_m._objetivo_atual().contains("Dulce"), "o objetivo passa para a Dulce", _m._objetivo_atual())
	_ok(_opcoes_de("dulce", "assuntos").has("Vim desafiar a guardiã do sítio."),
			"com criatura, a Dulce oferece o desafio")
	_ok(not _opcoes_de("mirela", "raiz").has("Preciso de uma criatura para andar por aí."),
			"a Mirela nao oferece de novo")
	_etapas += 1


func _testar_cura_e_bolsa() -> void:
	print("\n3. Cura, bolsa e equipe")
	var eq: EquipeJogador = _m.encontros.equipe
	var c: Combatente = eq.ativos[0]
	c.vida = 5
	_m._on_servico_pedido({"tipo": "curar_equipe"}, null)
	_ok(c.fracao() == 1.0, "a cura da Mirela e completa e de graca")

	c.vida = 5
	var pocao: ItemJogo = Bolsa.item("pocao_simples")
	var antes: int = Bolsa.quantidade(pocao.id)
	var frase: String = _m._usar_item_da_bolsa(pocao)
	_ok(c.vida == 35 and Bolsa.quantidade(pocao.id) == antes - 1,
			"poção pela bolsa cura e e gasta", frase)
	c.vida = c.ficha.vida
	antes = Bolsa.quantidade(pocao.id)
	frase = _m._usar_item_da_bolsa(pocao)
	_ok(Bolsa.quantidade(pocao.id) == antes, "sem ninguem ferido, nao gasta", frase)

	var bes: Array = _m.encontros.bestiario
	eq.adicionar(Combatente.de_criatura(bes[20], _m.encontros.tabelas_batalha))
	eq.adicionar(Combatente.de_criatura(bes[21], _m.encontros.tabelas_batalha))
	eq.adicionar(Combatente.de_criatura(bes[22], _m.encontros.tabelas_batalha))
	_ok(eq.ativos.size() == 3 and eq.deposito.size() == 1, "a quarta vai para o deposito")

	_m.pausa.abrir()
	_m.pausa._mostrar_equipe()
	var tela: TelaEquipe = _m.pausa.tela_equipe
	_ok(tela.aberta() and tela._linhas.size() == 4, "a tela de equipe lista equipe e deposito")
	tela._indice = 3
	tela._acionar()
	tela._indice = 1
	tela._acionar()
	_ok(eq.ativos[1].criatura == bes[22], "marcar e trocar sobe a do deposito",
			eq.ativos[1].nome())
	# Nao se deixa a equipe sem ninguem de pe.
	for x: Combatente in eq.ativos:
		x.vida = 0
	eq.ativos[0].vida = 1
	eq.deposito[0].vida = 0
	tela._indice = 3
	tela._acionar()
	tela._indice = 0
	tela._acionar()
	_ok(eq.ativos[0].viva(), "a troca que deixaria a equipe sem ninguem e recusada",
			tela._rodape.text)
	eq.curar_todos()
	tela.fechar()
	_m.pausa.fechar()
	_ok(not get_tree().paused, "fechar a pausa solta a arvore")
	_etapas += 1


func _testar_save() -> void:
	print("\n4. Save da equipe")
	var eq: EquipeJogador = _m.encontros.equipe
	eq.ativos[0].vida = 7
	var primeira: Criatura = eq.ativos[0].criatura
	var deposito: Criatura = eq.deposito[0].criatura
	_ok(Save.salvar() == "", "gravou")
	_ok(Save.carregar(SLOT), "releu")
	await _subir_mundo()
	var nova: EquipeJogador = _m.encontros.equipe
	_ok(nova.ativos.size() == 3 and nova.deposito.size() == 1, "equipe e deposito voltaram")
	_ok(nova.ativos[0].criatura.id == primeira.id, "na mesma ordem")
	_ok(nova.ativos[0].vida == 7, "com a vida que tinham", "%d" % nova.ativos[0].vida)
	_ok(nova.deposito[0].criatura.id == deposito.id, "o deposito tambem")
	_ok(_m.estado_mundo.ativa("recebeu_inicial"), "a bandeira voltou")
	_ok(_m.encontros.inventario.colecao.size() == 4, "a colecao e refeita sem duplicar",
			"%d" % _m.encontros.inventario.colecao.size())
	nova.curar_todos()
	_etapas += 1


func _testar_vitoria() -> void:
	print("\n5. Duelo com a Dulce e vitoria")
	var g: GerenciadorEncontro = _m.encontros
	_acelerar(g)
	_m._on_servico_pedido({"tipo": "duelo", "guardiao": "dulce"}, null)
	_ok(not g.estado.em_encontro(), "o duelo espera a conversa fechar")
	_ok(_m._apos_conversa.is_valid(), "fica pendente")
	var salvo_antes: String = str(ArquivoSave.ler(SLOT)["dados"].salvo_em)
	_m._ao_terminar_conversa(null)
	_ok(g.em_duelo(), "ao fechar, o duelo comeca")
	_ok(ArquivoSave.ler(SLOT)["estado"] == ArquivoSave.Estado.OK,
			"salvou antes da luta", salvo_antes)
	_ok(g.motor.lado_inimigo.size() == 2, "a Dulce tem 2 criaturas")
	for c: Combatente in g.motor.lado_inimigo:
		_ok(c.criatura.elemento in ["terra", "planta"], "%s e da regiao" % c.nome())
		_ok(c.criatura in g.bestiario, "%s vem do bestiario da seed" % c.nome())
	await _ate_o_menu(g)

	# Vence pelo menu de verdade, com o adversario enfraquecido.
	for c: Combatente in g.motor.lado_inimigo:
		c.vida = 1
		c.ficha.esquiva = 0.0
	for i in 12:
		if not g.estado.em_encontro():
			break
		g.motor.jogador().vida = g.motor.jogador().ficha.vida
		g.motor.jogador().ficha.velocidade = 999.0
		g._on_lista({"tipo": "golpe", "golpe": g.tabelas_batalha.de_reserva()})
		await _ate_decisao(g)
	await _ate_inativo(g)
	await get_tree().process_frame
	_ok(_m.estado_mundo.ativa("selo_dulce"), "a vitoria da o selo")
	_ok(not _m.estado_mundo.ativa("jogo_vencido") and not _m.tela_desfecho.aberta(),
			"um selo so nao encerra o jogo")
	_ok(_m._objetivo_atual().contains("Anselmo"), "o objetivo passa para o Anselmo",
			_m._objetivo_atual())
	_ok(_opcoes_de("anselmo", "assuntos").has("Vim desafiar o guardião da ribeira."),
			"com o selo da Dulce, o Anselmo aceita o desafio")
	_ok(not _opcoes_de("mirela", "raiz").has("Tenho os três selos."),
			"sem os tres selos, a Mirela nao aceita o duelo final")
	_m.estado_mundo.definir("selo_anselmo", true)
	_ok(_m._objetivo_atual().contains("Otávio"), "depois vem o Otavio", _m._objetivo_atual())
	_m.estado_mundo.definir("selo_otavio", true)
	_ok(_m._objetivo_atual().contains("Mirela"), "com os tres selos, falta a Mirela",
			_m._objetivo_atual())
	_ok(_opcoes_de("mirela", "raiz").has("Tenho os três selos."),
			"com os tres selos, o duelo final abre")
	_ok(not _m.guardioes.venceu_o_jogo(_m.estado_mundo), "tres selos ainda nao vencem o jogo")
	# A tela final, com os dados da seed, aparece quando os selos pedidos estao todos.
	_m._ao_vencer_duelo(_m.guardioes.por_id("mirela"))
	await get_tree().process_frame
	_ok(_m.estado_mundo.ativa("jogo_vencido"), "com os selos pedidos, o jogo foi vencido")
	_ok(_m.tela_desfecho.aberta(), "a tela final abriu")
	_ok(_m.tela_desfecho._titulo.text == "VITÓRIA", "e diz vitoria")
	var corpo: String = _m.tela_desfecho._corpo.text
	_ok(corpo.contains("COERÊNCIA") and corpo.contains("independente"),
			"com a coerencia contra o baseline", corpo.replace("\n", " | "))
	_ok(_m._coerencia_media(MetricasCoerencia.avaliar(g.bestiario, g.tabelas))
			> _m._coerencia_media(MetricasCoerencia.avaliar(
			GeradorCriaturas.new(g.tabelas, g.catalogo).gerar_bestiario(
			SEED_TESTE, 100, GeradorCriaturas.Modo.INDEPENDENTE), g.tabelas,
			MetricasCoerencia.K_UNICIDADE_PADRAO, MetricasCoerencia.MODELO_V2)),
			"a seed condicionada e mais coerente que o sorteio independente")
	_ok(_m._dono_da_tela() == "desfecho", "a tela final tem a tela")
	_ok(_m.jogador.congelado, "o jogador espera")
	_m.tela_desfecho._ao_escolher(0)
	await get_tree().process_frame
	_ok(not _m.jogador.congelado and not _m.tela_desfecho.aberta(), "continuar explorando")
	_ok(_m._objetivo_atual().contains("concluído"), "objetivo concluido", _m._objetivo_atual())

	# Revanche nao repete a tela de vitoria.
	g.equipe.curar_todos()
	_m._ao_vencer_duelo(_m.guardioes.por_id("dulce"))
	_ok(not _m.tela_desfecho.aberta(), "revanche nao abre a tela final de novo")
	var dados: DadosPartida = ArquivoSave.ler(SLOT)["dados"]
	_ok(bool(dados.estado_mundo.get("bandeiras", {}).get("jogo_vencido", false)),
			"a vitoria foi gravada")
	_etapas += 1


func _testar_derrota() -> void:
	print("\n6. Derrota e volta ao save")
	var g: GerenciadorEncontro = _m.encontros
	g.equipe.curar_todos()
	var vida_salva: int = g.equipe.ativos[0].vida
	_ok(Save.salvar() == "", "ponto de retorno gravado")
	var primeira: int = g.equipe.ativos[0].criatura.id

	g.iniciar_com_criatura(g.bestiario[30])
	await _ate_o_menu(g)
	for i in 80:
		if not g.estado.em_encontro():
			break
		if g.estado.e(EstadoEncontro.Estado.TROCA_OBRIGATORIA):
			g._on_lista(g._itens_de_troca("trocar_forcada")[0]["valor"])
			await _ate_decisao(g)
			continue
		g.motor.jogador().vida = 1
		g.motor.jogador().ficha.esquiva = 0.0
		g._resolver_turno({"tipo": "passar"})
		await _ate_decisao(g)
	await _ate_inativo(g)
	await get_tree().process_frame
	_ok(_m.tela_desfecho.aberta() and _m.tela_desfecho._titulo.text == "DERROTA",
			"equipe inteira no chao, em encontro selvagem: tela de derrota")
	_ok(not g.equipe.tem_vivos(), "ninguem de pe")
	var opcoes: Array = _m.tela_desfecho._opcoes
	_ok(String(opcoes[0]["texto"]).contains("SAVE"), "oferece voltar ao save", str(opcoes[0]))

	# Regressao: trocar de cena DENTRO do evento de entrada derrubava a build de entrega
	# (falha de segmentacao ao voltar ao save). As saidas da cena tem de ser adiadas.
	_ok(_conexao_adiada(_m.tela_desfecho.opcao_escolhida), "a escolha do desfecho e tratada adiada")
	_ok(_conexao_adiada(_m.pausa.sair_pedido), "sair pela pausa e tratado adiado")
	var cena_velha := get_tree().current_scene
	_m.tela_desfecho._ao_escolher(0)
	_ok(get_tree().current_scene == cena_velha, "a cena nao sai da arvore no mesmo quadro da escolha")
	await _ate_trocar_de_cena(cena_velha)
	_m = get_tree().current_scene as Node2D
	_ok(_m != cena_velha, "a cena foi recarregada")
	await get_tree().process_frame
	var nova: EquipeJogador = _m.encontros.equipe
	_ok(nova.tem_vivos() and nova.ativos[0].vida == vida_salva, "a equipe voltou de pe, como no save")
	_ok(nova.ativos[0].criatura.id == primeira, "a mesma criatura")
	_ok(not _m.tela_desfecho.aberta() and not _m.jogador.congelado, "e o jogo segue")
	_etapas += 1


func _testar_pesca() -> void:
	print("\n7. Pesca vira batalha")
	var g: GerenciadorEncontro = _m.encontros
	_acelerar(g)
	var alvo: Criatura = g.bestiario[40]
	# Modo licao: fisgar so vira nota, e nao pode terminar em derrota.
	_m.pesca.modo_tutorial = true
	_m._ao_fisgar(alvo)
	_ok(not _m._pesca_em_batalha and _m.pesca.encerrar_ao_fisgar, "na licao, fisgar nao vira batalha")
	_m.pesca.modo_tutorial = false

	_m.pesca.cfg.duracao_resultado = 0.01
	_m._ao_fisgar(alvo)
	_ok(_m._pesca_em_batalha and not _m.pesca.encerrar_ao_fisgar,
			"fora da licao, a pesca espera a batalha")
	# Comeca depois do letreiro "FISGOU!", nao no mesmo quadro.
	await _ate(func() -> bool: return g.estado.em_encontro())
	await _ate_o_menu(g)
	_ok(g.criatura_atual() == alvo, "a batalha e com a criatura fisgada", alvo.nome())
	var fuga: Dictionary = g.tabelas_batalha.fuga()
	fuga["base"] = 1.0
	fuga["piso"] = 1.0
	fuga["teto"] = 1.0
	g._on_acao(InterfaceEncontro.Acao.FUGIR)
	await _ate_inativo(g)
	await get_tree().process_frame
	_ok(not _m._pesca_em_batalha and _m.pesca.encerrar_ao_fisgar, "ao acabar, a pesca volta ao normal")
	_ok(not _m.jogador.congelado, "e o jogador anda")
	_etapas += 1


## Glifo ausente nao da erro: sai uma caixa vazia na tela. Confere o texto que so a
## batalha escreve, inclusive o que depende de numero.
func _testar_glifos() -> void:
	print("\n8. A fonte cobre o texto da batalha")
	var tabelas: TabelasBatalha = _m.encontros.tabelas_batalha
	var amostra: String = TelaEquipe.TEXTO_RODAPE + TelaEscolhaInicial.TEXTO_RODAPE \
			+ TelaBolsa.TEXTO_RODAPE + "VITÓRIA DERROTA COERÊNCIA ÚLTIMO RECOMEÇAR GUARDIÃ SÍTIO"
	for g: Golpe in tabelas.golpes:
		amostra += g.nome + g.nome.to_upper() + g.descricao
	for o: Dictionary in InterfaceEncontro.OPCOES_SELVAGEM + InterfaceEncontro.OPCOES_DUELO:
		amostra += String(o["rotulo"]) + String(o["dica"])
	var bes: Array = _m.encontros.bestiario
	var a := Combatente.de_criatura(bes[0], tabelas)
	var b := Combatente.de_criatura(bes[1], tabelas)
	for g: Golpe in a.ficha.golpes:
		amostra += TextoBatalha.dica_do_golpe(g, a, b, tabelas)
	amostra += TextoBatalha.ficha_em_bbcode(a.criatura, a.ficha).replace("[color=", "").replace("[/color]", "")
	amostra += "MUITO EFICAZ ×1.50 POUCO EFICAZ ×0.75 %"
	amostra += _m._objetivo_atual()
	var faltando := PackedStringArray()
	for fonte: FontFile in [TemaEncontro.fonte(), TemaEncontro.fonte_titulo()]:
		for i in amostra.length():
			var c: String = amostra[i]
			if c != "\n" and not fonte.has_char(c.unicode_at(0)) and not c in faltando:
				faltando.append(c)
	_ok(faltando.is_empty(), "nenhum glifo faltando", " ".join(faltando))
	_etapas += 1


## O caminho das teclas: as outras etapas chamam as acoes por dentro.
func _testar_teclado() -> void:
	print("\n9. Batalha pelo teclado")
	var g: GerenciadorEncontro = _m.encontros
	_acelerar(g)
	g.equipe.curar_todos()
	g.iniciar_com_criatura(g.bestiario[50])
	await _ate(func() -> bool: return g.estado.em_encontro())
	await _ate_o_menu(g)
	g.motor.inimigo().ficha.esquiva = 0.0
	g.motor.inimigo().vida = 100000
	var ui: InterfaceEncontro = g._interface

	_tecla(ui, "ui_cancel")
	await get_tree().process_frame
	_ok(g.estado.e(EstadoEncontro.Estado.INTERACAO) and g.motor.turno == 0,
			"ESC no menu nao foge nem gasta o turno")
	_tecla(ui, "mover_baixo")
	_ok(ui._indice == 1, "seta desce no menu")
	_tecla(ui, "mover_cima")
	_ok(ui._indice == 0, "seta sobe")

	_tecla(ui, "ui_accept")
	await get_tree().process_frame
	_ok(ui._em_lista and g.motor.turno == 0, "E em GOLPES abre a lista, sem gastar turno")
	_ok(ui._itens_menu.size() == g.motor.jogador().ficha.golpes.size(), "um cartao por golpe")
	_tecla(ui, "ui_cancel")
	await get_tree().process_frame
	_ok(not ui._em_lista and ui._menu_ativo, "ESC volta da lista ao menu")

	var vida: int = g.motor.inimigo().vida
	_tecla(ui, "ui_accept")
	await get_tree().process_frame
	_tecla(ui, "ui_accept")
	_ok(g.estado.e(EstadoEncontro.Estado.ATACANDO), "E no golpe resolve o turno")
	_tecla(ui, "ui_accept")
	_ok(g.motor.turno == 1, "tecla apressada nao resolve dois turnos")
	await _ate_decisao(g)
	_ok(g.motor.turno == 1 and ui._menu_ativo and not ui._em_lista,
			"terminado o turno, o menu volta a aceitar entrada")
	_ok(g.motor.inimigo().vida <= vida, "o golpe foi resolvido", "%d" % g.motor.inimigo().vida)

	var fuga: Dictionary = g.tabelas_batalha.fuga()
	fuga["base"] = 1.0
	fuga["piso"] = 1.0
	fuga["teto"] = 1.0
	_tecla(ui, "mover_cima")
	_ok(String(ui._itens_menu[ui._indice]["rotulo"]) == "FUGIR", "a navegacao da a volta ate FUGIR")
	_tecla(ui, "ui_accept")
	await _ate_inativo(g)
	_ok(not g.estado.em_encontro() and not _m.jogador.congelado, "E em FUGIR encerra e solta o jogador")
	_etapas += 1


func _testar_teclas_de_desenvolvimento() -> void:
	print("\n10. Teclas de desenvolvimento")
	var g: GerenciadorEncontro = _m.encontros
	_acelerar(g)
	g.equipe.curar_todos()
	var cena := get_tree().current_scene

	_m.teclas_de_desenvolvimento = false
	_ok(not _m.texto_das_teclas().contains("F4"), "entrega: o HUD nao cita F2, F3 nem F4",
			_m.texto_das_teclas())
	_ok(_m.texto_das_teclas().contains("F usar"), "entrega: o F de usar item continua")
	_tecla_f(KEY_F4)
	await get_tree().process_frame
	_ok(not g.estado.em_encontro(), "entrega: F4 nao forca encontro")
	_tecla_f(KEY_F3)
	_ok(not _m._sobreposicao.visible, "entrega: F3 nao mostra as zonas")
	_tecla_f(KEY_F2)
	await get_tree().process_frame
	await get_tree().process_frame
	_ok(get_tree().current_scene == cena, "entrega: F2 nao sai para o bestiario")
	# Um valor que so chega ao disco se a tecla gravar de verdade.
	Save.partida.tempo_jogado = 54321.0
	_tecla_f(KEY_F5)
	var dados: DadosPartida = ArquivoSave.ler(SLOT)["dados"]
	_ok(is_equal_approx(dados.tempo_jogado, 54321.0), "entrega: F5 continua salvando",
			"%.0f" % dados.tempo_jogado)

	_m.teclas_de_desenvolvimento = true
	_ok(_m.texto_das_teclas().contains("F4"), "debug: o HUD cita as teclas")
	_tecla_f(KEY_F3)
	_ok(_m._sobreposicao.visible, "debug: F3 mostra as zonas")
	_tecla_f(KEY_F3)
	_tecla_f(KEY_F4)
	await get_tree().process_frame
	_ok(g.estado.em_encontro(), "debug: F4 forca encontro")
	g._encerrar("teste")
	await _ate_inativo(g)
	_etapas += 1


func _testar_hud_e_tela_cheia() -> void:
	print("\n11. HUD, pausa e tela cheia")
	var faixa: Control = _m._hud_objetivo
	_ok(faixa != null and faixa.visible, "o card do objetivo esta na tela")
	_ok(_m._texto_objetivo.text == _m._objetivo_atual() and _m._texto_objetivo.text != "",
			"o card mostra o objetivo", _m._texto_objetivo.text)
	_ok(_m._texto_equipe.text.contains("DE PÉ"), "e quantas da equipe estao de pe",
			_m._texto_equipe.text)
	await get_tree().process_frame
	var tela: float = get_viewport().get_visible_rect().size.x
	var r: Rect2 = faixa.get_global_rect()
	_ok(r.end.x <= tela and tela - r.end.x < 20.0, "o card fica no canto direito",
			"%.0f..%.0f de %.0f px" % [r.position.x, r.end.x, tela])
	_ok(r.position.y < 20.0 and r.position.x > tela * 0.5, "no alto da tela, sem cobrir o centro")
	_ok(not _m._texto_objetivo.text.contains("Mirela"), "(premissa) objetivo apos a primeira criatura")
	var antes: String = _m._texto_objetivo.text
	_m.estado_mundo.definir("jogo_vencido", false)
	_m.estado_mundo.definir("selo_dulce", false)
	_m._atualizar_objetivo()
	_ok(_m._texto_objetivo.text != antes, "o objetivo muda com o estado do mundo", _m._texto_objetivo.text)
	_ok(_m._hud_objetivo.modulate != Color.WHITE, "e o card pisca quando muda")

	_ok(_m._hud_dica.get_parent() != null and _m._hud_dica.modulate.a < 1.0
			or _m.SEGUNDOS_DE_CONTROLES > 0.0, "a linha de controles existe e some depois do comeco")
	_ok(_m._hud_dica.get_global_rect().position.y > tela * 0.0
			and _m._hud_dica.get_global_rect().position.y > get_viewport().get_visible_rect().size.y * 0.5,
			"a linha de controles fica no rodape, nao no topo")
	_m.pausa.abrir()
	_ok(_m.pausa._controles.text == _m.texto_das_teclas(), "a pausa mostra os controles")
	_m.pausa.fechar()

	_ok(Opcoes.definicao("tela_cheia") != null, "a opcao de tela cheia existe")
	var original: Variant = Opcoes.ler("tela_cheia")
	var f11 := InputEventKey.new()
	f11.keycode = KEY_F11
	f11.pressed = true
	Opcoes._input(f11)
	_ok(Opcoes.ler("tela_cheia") != original, "F11 alterna a tela cheia")
	Opcoes._input(f11)
	_ok(Opcoes.ler("tela_cheia") == original, "e alterna de volta")
	_etapas += 1


func _testar_bestiario() -> void:
	print("\n12. Bestiario da seed")
	var g: GerenciadorEncontro = _m.encontros
	var tela: TelaBestiario = _m.pausa.tela_bestiario
	_ok(_m.texto_das_teclas().contains("N bestiário"), "os controles citam a tecla N")
	var n := InputEventAction.new()
	n.action = "abrir_bestiario"
	n.pressed = true
	_m._unhandled_input(n)
	await get_tree().process_frame
	_ok(tela.aberta() and get_tree().paused, "N abre o bestiario, com o jogo pausado")
	_ok(tela._celulas.size() == g.bestiario.size(), "todas as criaturas da seed",
			"%d" % tela._celulas.size())
	var com_marca: int = 0
	var certas: bool = true
	for i in tela._celulas.size():
		var marcada: bool = tela._celulas[i].find_child("Capturada", true, false) != null
		if marcada:
			com_marca += 1
		if marcada != g.inventario.ja_capturou(g.bestiario[i]):
			certas = false
	_ok(certas, "a marca aparece exatamente nas capturadas")
	_ok(com_marca == tela.total_capturadas() and com_marca > 0, "e o total confere",
			"%d marcadas" % com_marca)
	_ok(tela._subtitulo.text.contains("CAPTURADAS %d DE %d" % [com_marca, g.bestiario.size()]),
			"o topo mostra seed e capturadas", tela._subtitulo.text)
	var direita := InputEventAction.new()
	direita.action = "mover_direita"
	direita.pressed = true
	tela._unhandled_input(direita)
	_ok(tela._indice == 1 and tela._ficha_texto.text.contains(g.bestiario[1].nome().to_upper()),
			"a seta muda a ficha", g.bestiario[1].nome())
	var e_tecla := InputEventAction.new()
	e_tecla.action = "interagir"
	e_tecla.pressed = true
	tela._unhandled_input(e_tecla)
	var sorteio: String = tela._ficha_texto.text
	_ok(sorteio.contains("PRIMÁRIOS") and sorteio.contains("bits")
			and sorteio.contains(g.bestiario[1].elemento), "E mostra o sorteio da criatura",
			sorteio.replace("\n", " | "))
	_ok(sorteio.contains("COERENTE") or sorteio.contains("ATÍPICA"), "com a nota de coerencia")
	tela._selecionar(2)
	_ok(tela._ficha_texto.text.contains("bits"), "o sorteio continua ao trocar de criatura")
	tela._unhandled_input(e_tecla)
	_ok(not tela._ficha_texto.text.contains("bits"), "E de novo volta a ficha de batalha")
	tela._selecionar(1)
	tela._unhandled_input(n)
	await get_tree().process_frame
	_ok(not tela.aberta() and not get_tree().paused, "N de novo fecha e devolve o jogo")
	_m.pausa.abrir()
	var i_bes: int = -1
	for i in MenuPausa.OPCOES_RAIZ.size():
		if MenuPausa.OPCOES_RAIZ[i]["id"] == "bestiario":
			i_bes = i
	_m.pausa._ao_escolher(i_bes)
	_ok(tela.aberta(), "a pausa tambem abre o bestiario")
	tela.fechar()
	_ok(_m.pausa.aberto() and _m.pausa._bloco.visible, "e fechar volta ao menu da pausa")
	_m.pausa.fechar()
	_etapas += 1


func _testar_economia() -> void:
	print("\n13. Gold, loja e recompensas")
	var g: GerenciadorEncontro = _m.encontros
	Bolsa.ganhar_gold(100)
	var gold: int = Bolsa.gold
	_ok(_m._texto_da_equipe().contains("%d GOLD" % gold), "o card mostra o gold", _m._texto_da_equipe())

	# Loja da vila, pelo servico do dialogo: abre DEPOIS de a conversa fechar.
	_m._on_servico_pedido({"tipo": "loja", "loja": "vila"}, null)
	_ok(not _m.tela_loja.aberta(), "a loja espera a conversa fechar")
	_m._ao_terminar_conversa(null)
	_ok(_m.tela_loja.aberta() and _m._dono_da_tela() == "loja", "e entao abre, com a tela")
	_ok(_m.jogador.congelado, "o jogador espera")
	_ok(_m.tela_loja._titulo.text == "ARMAZÉM DA VILA", "e a loja certa", _m.tela_loja._titulo.text)
	var esferas: int = Bolsa.quantidade("esfera_simples")
	var preco: int = Bolsa.economia.preco("esfera_simples")
	_m.tela_loja._indice = 0
	var erro: String = _m.tela_loja.comprar_selecionado()
	_ok(erro == "" and Bolsa.quantidade("esfera_simples") == esferas + 1, "comprar poe o item na bolsa", erro)
	_ok(Bolsa.gold == gold - preco, "e cobra o preco", "%d -> %d" % [gold, Bolsa.gold])
	Bolsa._definir_gold(preco - 1)
	erro = _m.tela_loja.comprar_selecionado()
	_ok(erro.contains("insuficiente") and Bolsa.quantidade("esfera_simples") == esferas + 1
			and Bolsa.gold == preco - 1, "sem gold, nao compra nem cobra", erro)
	var esc := InputEventAction.new()
	esc.action = "ui_cancel"
	esc.pressed = true
	_m.tela_loja._unhandled_input(esc)
	_ok(not _m.tela_loja.aberta() and not _m.jogador.congelado, "ESC fecha a loja e solta o jogador")

	# Selvagem derrotado paga pela forca dele.
	var c: Criatura = g.bestiario[60]
	var forca := FichaCombate.de_criatura(c, g.tabelas_batalha).forca(g.tabelas_batalha)
	var antes: int = Bolsa.gold
	_m._on_encontro_terminado("derrotada", c)
	_ok(Bolsa.gold == antes + Bolsa.economia.recompensa_selvagem(forca),
			"derrotar um selvagem paga pela forca dele", "+%d" % (Bolsa.gold - antes))
	antes = Bolsa.gold
	_m._on_encontro_terminado("capturada", c)
	_ok(Bolsa.gold == antes, "capturar nao paga")

	# A guardia paga so na primeira vitoria.
	var dulce: Dictionary = _m.guardioes.por_id("dulce")
	_m.estado_mundo.definir("selo_dulce", false)
	antes = Bolsa.gold
	_m._ao_vencer_duelo(dulce)
	_ok(Bolsa.gold == antes + int(dulce["premio_gold"]), "a primeira vitoria paga o premio",
			"+%d" % (Bolsa.gold - antes))
	antes = Bolsa.gold
	_m._ao_vencer_duelo(dulce)
	_ok(Bolsa.gold == antes, "a revanche nao paga de novo")
	if _m.tela_desfecho.aberta():
		_m.tela_desfecho.fechar()
		_m.jogador.congelar(false)

	# O gold vai para o save.
	_ok(Save.salvar() == "", "gravou")
	var dados: DadosPartida = ArquivoSave.ler(SLOT)["dados"]
	_ok(dados.gold == Bolsa.gold, "o gold esta no save", "%d" % dados.gold)

	var fonte := TemaEncontro.fonte()
	var amostra: String = TelaLoja.TEXTO_RODAPE
	for l: Dictionary in _m.lojas.lojas:
		amostra += String(l["nome"])
	var faltando := PackedStringArray()
	for i in amostra.length():
		if not fonte.has_char(amostra.unicode_at(i)) and not amostra[i] in faltando:
			faltando.append(amostra[i])
	_ok(faltando.is_empty(), "a fonte cobre o texto das lojas", " ".join(faltando))
	_etapas += 1


func _testar_fabrica() -> void:
	print("\n14. A fabrica e o segundo guardiao")
	var porta := Vector2i(65, 58)
	_ok(_m.mundo.porta_em(porta).get("destino", "") == "fabrica", "a porta da fabrica existe")
	_ok(_m.dialogos.npc_por_id("otavio") == null, "o Otavio nao esta mais no patio")

	# Sem o selo, o portao nao abre. (A etapa 5 ja deu os dois selos: zera.)
	_m.estado_mundo.definir("selo_otavio", false)
	_m.estado_mundo.definir("jogo_vencido", false)
	_m.estado_mundo.definir("selo_dulce", false)
	_m.jogador.position = _m.mundo.celula_para_mundo(Vector2i(65, 60))
	_m._ultima_celula_de_porta = Vector2i(65, 60)
	await get_tree().process_frame
	_m.jogador.position = _m.mundo.celula_para_mundo(porta)
	_m._verificar_porta()
	_ok(not _m._atravessando, "sem o selo da Dulce, o portao fica trancado")

	# Com o selo, entra.
	_m.estado_mundo.definir("selo_dulce", true)
	# Os outros selos ja vencidos: aqui o Otavio e o ultimo que falta.
	_m.estado_mundo.definir("selo_anselmo", true)
	_m.estado_mundo.definir("selo_mirela", true)
	_m._ultima_celula_de_porta = Vector2i(-1, -1)
	var velha := get_tree().current_scene
	_m._verificar_porta()
	_ok(_m._atravessando, "com o selo, atravessa")
	await _ate_trocar_de_cena(velha)
	_m = get_tree().current_scene as Node2D
	await get_tree().process_frame
	_ok(_m.mundo.id_mapa == "fabrica" and not _m.mundo.mundo_aberto, "esta dentro da fabrica")
	_ok(_m.mundo.mundo_para_celula(_m.jogador.position) == Vector2i(7, 11), "na celula de chegada")
	var otavio: Npc = _m.dialogos.npc_por_id("otavio")
	_ok(otavio != null and _m.dialogos.npc_por_id("mirela") == null,
			"la dentro esta o Otavio, e so ele")
	_ok(_m.encontros.equipe.ativos.size() == 3, "a equipe veio junto",
			"%d" % _m.encontros.equipe.ativos.size())
	_ok(not _m._e_agua(_m.mundo.celula_para_mundo(Vector2i(3, 3))), "as pocas nao viram pesca")
	_m._alternar_mapa()
	_ok(not _m.mapa.aberto(), "nao ha mapa geral aqui dentro")
	_ok(_m._objetivo_atual().contains("Otávio"), "o objetivo aponta o Otavio", _m._objetivo_atual())

	# O duelo com o Otavio e a vitoria final, com os dois selos.
	_m.estado_mundo.definir("jogo_vencido", false)
	var g: GerenciadorEncontro = _m.encontros
	_acelerar(g)
	g.equipe.curar_todos()
	_m._on_servico_pedido({"tipo": "duelo", "guardiao": "otavio"}, null)
	_m._ao_terminar_conversa(null)
	_ok(g.em_duelo() and g.motor.lado_inimigo.size() == 2, "o Otavio duela com 2 criaturas")
	for c: Combatente in g.motor.lado_inimigo:
		_ok(c.criatura.elemento in ["eletrico", "agua"], "%s e eletrico ou agua" % c.nome())
	await _ate_o_menu(g)
	for c: Combatente in g.motor.lado_inimigo:
		c.vida = 1
		c.ficha.esquiva = 0.0
	for i in 12:
		if not g.estado.em_encontro():
			break
		g.motor.jogador().vida = g.motor.jogador().ficha.vida
		g.motor.jogador().ficha.velocidade = 999.0
		g._on_lista({"tipo": "golpe", "golpe": g.tabelas_batalha.de_reserva()})
		await _ate_decisao(g)
	await _ate_inativo(g)
	await get_tree().process_frame
	_ok(_m.estado_mundo.ativa("selo_otavio"), "a vitoria da o selo do Otavio")
	_ok(_m.tela_desfecho.aberta() and _m.tela_desfecho._titulo.text == "VITÓRIA",
			"com todos os selos, a vitoria do jogo")
	_m.tela_desfecho._ao_escolher(0)
	await get_tree().process_frame

	# A saida devolve o jogador a frente da fabrica.
	velha = get_tree().current_scene
	_m._ultima_celula_de_porta = Vector2i(-1, -1)
	_m.jogador.position = _m.mundo.celula_para_mundo(Vector2i(7, 12))
	_m._verificar_porta()
	await _ate_trocar_de_cena(velha)
	_m = get_tree().current_scene as Node2D
	await get_tree().process_frame
	_ok(_m.mundo.id_mapa == "mundo" and _m.mundo.mundo_para_celula(_m.jogador.position) == Vector2i(65, 59),
			"a saida volta para a frente da fabrica")

	# Salvar la dentro e recarregar volta la para dentro.
	Save.partida.mapa = "fabrica"
	Save.partida.celula = Vector2i(7, 9)
	velha = get_tree().current_scene
	_m._trocar_de_cena.call_deferred(_m.CENA_MUNDO)
	await _ate_trocar_de_cena(velha)
	_m = get_tree().current_scene as Node2D
	await get_tree().process_frame
	_ok(_m.mundo.id_mapa == "fabrica", "um save feito la dentro carrega la dentro")
	_etapas += 1


func _conexao_adiada(sinal: Signal) -> bool:
	for c: Dictionary in sinal.get_connections():
		if int(c["flags"]) & CONNECT_DEFERRED:
			return true
	return false


func _tecla_f(tecla: Key) -> void:
	var ev := InputEventKey.new()
	ev.keycode = tecla
	ev.pressed = true
	_m._unhandled_input(ev)


func _tecla(ui: InterfaceEncontro, acao: String) -> void:
	var ev := InputEventAction.new()
	ev.action = acao
	ev.pressed = true
	ui._unhandled_input(ev)


# ---------------------------------------------------------------- utilidades

func _subir_mundo() -> void:
	var velha := get_tree().current_scene
	get_tree().change_scene_to_file(CENA_MUNDO)
	await _ate_trocar_de_cena(velha)
	_m = get_tree().current_scene as Node2D
	await get_tree().process_frame
	_ok(_m != null and _m.get("encontros") != null, "o mundo subiu")
	_acelerar(_m.encontros)


func _ate_trocar_de_cena(velha: Node) -> void:
	for i in 600:
		var atual := get_tree().current_scene
		if atual != null and atual != velha and atual.is_node_ready():
			return
		await get_tree().process_frame


func _acelerar(g: GerenciadorEncontro) -> void:
	g.cfg.duracao_aviso = 0.01
	g.cfg.duracao_tremor = 0.01
	g.cfg.atraso_apos_aviso = 0.01
	g.cfg.duracao_escurecimento = 0.01
	g.cfg.duracao_texto_encontro = 0.01
	g.cfg.duracao_abertura_menu = 0.01
	g.cfg.duracao_desfecho = 0.01
	g.cfg.duracao_encerramento = 0.01
	g.cfg.carencia_segundos = 0.0
	g.cfg.duracao_evento_batalha = 0.01


func _ate_o_menu(g: GerenciadorEncontro) -> void:
	var parou := func() -> bool:
		return g.estado.e(EstadoEncontro.Estado.INTERACAO) \
				or g.estado.e(EstadoEncontro.Estado.INATIVO)
	await _ate(parou)


func _ate_decisao(g: GerenciadorEncontro) -> void:
	await _ate(func() -> bool: return g.estado.aceita_entrada() or not g.estado.em_encontro())


func _ate_inativo(g: GerenciadorEncontro) -> void:
	await _ate(func() -> bool: return g.estado.e(EstadoEncontro.Estado.INATIVO))


func _ate(condicao: Callable, limite: int = 900) -> void:
	for i in limite:
		if condicao.call():
			return
		await get_tree().process_frame
	push_error("teste: tempo esgotado esperando")


## Textos das escolhas que o jogador VE naquele no da arvore, com o estado atual.
func _opcoes_de(id_arvore: String, id_no: String) -> Array:
	var arvore: ArvoreDialogo = _m.dialogos.dialogos.arvore(id_arvore)
	var saida: Array = []
	for e: Dictionary in arvore.nos[id_no].escolhas:
		if CondicaoDialogo.avaliar(e.get("se"), _m.estado_mundo):
			saida.append(String(e["texto"]))
	return saida


func _limpar_saves() -> void:
	for slot in range(1, ArquivoSave.SLOTS + 1):
		ArquivoSave.apagar(slot)
