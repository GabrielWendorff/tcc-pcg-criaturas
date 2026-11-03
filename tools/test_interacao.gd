extends SceneTree

## Teste headless do FLUXO de interacao, com a cena de verdade e entrada de
## verdade — roda SEM abrir janela:
##   godot --headless --path . -s res://tools/test_interacao.gd
##
## Os outros testes cobrem as regras (tools/test_dialogo.gd) e o mapa
## (tools/test_mundo.gd) chamando as classes diretamente. Este cobre o que so
## falha MONTADO: a tecla chegar ao gerenciador certo, o jogador congelar, a
## caixa abrir, o menu de escolhas receber a navegacao, o controle voltar — e o
## mapa e o encontro nao brigarem pela mesma tecla.
##
## A entrada e injetada por InputEventAction, que percorre o mesmo caminho de
## _unhandled_input que uma tecla fisica percorre.

var _falhas: int = 0
var _verificacoes: int = 0


func _initialize() -> void:
	print("== Interacao (cena montada, entrada real) — teste headless ==")
	await _rodar()
	print("\n==")
	if _verificacoes < 12:
		print("RESULTADO: so %d verificacoes rodaram — o teste abortou no meio"
				% _verificacoes)
		quit(1)
	elif _falhas > 0:
		print("RESULTADO: %d VERIFICACAO(OES) FALHARAM" % _falhas)
		quit(1)
	else:
		print("RESULTADO: TODOS OS TESTES PASSARAM")
		quit(0)


func _ok(condicao: bool, rotulo: String, detalhe: String = "") -> void:
	print("    %s %s%s" % ["OK  " if condicao else "FALHOU", rotulo,
			"" if detalhe == "" else "  — " + detalhe])
	_verificacoes += 1
	if not condicao:
		_falhas += 1


func _acao(nome: String) -> void:
	var e := InputEventAction.new()
	e.action = nome
	e.pressed = true
	Input.parse_input_event(e)
	await process_frame
	var solta := InputEventAction.new()
	solta.action = nome
	solta.pressed = false
	Input.parse_input_event(solta)
	await process_frame


func _rodar() -> void:
	change_scene_to_file("res://presentation/exploracao/mundo.tscn")
	await process_frame
	await process_frame
	var cena := current_scene
	if cena == null or cena.get("dialogos") == null:
		_ok(false, "a cena montou com o gerenciador de dialogo")
		return

	var jogador: Jogador = cena.get("jogador")
	var mundo: MundoIso = cena.get("mundo")
	var gerente: GerenciadorDialogo = cena.get("dialogos")
	var mapa: MapaMundo = cena.get("mapa")
	var estado: EstadoMundo = cena.get("estado_mundo")

	print("\nMontagem")
	_ok(gerente.erro == "", "gerenciador de dialogo preparado", gerente.erro)
	_ok(get_nodes_in_group("npcs").size() == gerente.catalogo.npcs.size(),
			"todo NPC do catalogo entrou no mundo",
			"%d em cena" % get_nodes_in_group("npcs").size())
	_ok(estado.visitou("vila"), "a regiao do spawn ja nasce descoberta")

	# --------------------------------------------------- aproximacao e aviso
	print("\nAproximacao")
	var alvo: Npc = null
	for no in get_nodes_in_group("npcs"):
		if (no as Npc).dados.id == "mirela":
			alvo = no
	_ok(alvo != null, "o NPC de exemplo existe no mundo")
	if alvo == null:
		return

	jogador.position = mundo.celula_para_mundo(Vector2i(60, 60))   # longe
	await process_frame
	await process_frame
	_ok(gerente.npc_proximo() == null, "longe do NPC, nenhum aviso")

	jogador.position = alvo.position + Vector2(14, 4)
	await process_frame
	await process_frame
	_ok(gerente.npc_proximo() == alvo, "perto do NPC, o aviso aponta para ele",
			"distancia %.2f celulas"
					% alvo.distancia_em_celulas(jogador.global_position))

	# ------------------------------------------------------------- conversa
	print("\nConversa pela tecla de interagir")
	await _acao("interagir")
	_ok(gerente.em_conversa(), "a tecla abriu a conversa")
	_ok(jogador.congelado, "o jogador perdeu o controle durante a conversa")

	# A primeira confirmacao completa o texto; a segunda avanca para o menu.
	for i in 8:
		await _acao("interagir")
		if gerente._caixa.menu.ativo():
			break
	_ok(gerente._caixa.menu.ativo(), "avancar a fala chega ao menu de escolhas",
			"%d opcoes" % gerente._sessao.escolhas().size())

	var antes: int = gerente._caixa.menu._indice
	await _acao("mover_baixo")
	_ok(gerente._caixa.menu._indice != antes,
			"a navegacao do menu responde a mover_baixo",
			"%d -> %d" % [antes, gerente._caixa.menu._indice])

	await _acao("ui_accept")
	_ok(not gerente._caixa.menu.ativo() and gerente.em_conversa(),
			"confirmar a escolha segue a conversa no ramo novo")
	_ok(estado.bandeiras.size() > 0, "a escolha gravou efeito no EstadoMundo",
			str(estado.bandeiras.keys()))

	# --------------------------------------------------- mapa nao interfere
	print("\nO mapa nao disputa a tecla durante a conversa")
	await _acao("abrir_mapa")
	_ok(not mapa.aberto(), "M nao abre o mapa no meio de uma conversa")

	# ------------------------------------------------------------ encerrar
	print("\nFim da conversa")
	for i in 40:
		if not gerente.em_conversa():
			break
		await _acao("interagir")
	if gerente.em_conversa():
		await _acao("ui_cancel")
	_ok(not gerente.em_conversa(), "a conversa termina")
	_ok(not jogador.congelado, "o controle volta ao jogador")

	# ---------------------------------------------------------------- mapa
	print("\nMapa geral pela tecla M")
	await _acao("abrir_mapa")
	_ok(mapa.aberto(), "M abre o mapa")
	_ok(jogador.congelado, "com o mapa aberto o jogador nao anda")
	await _acao("interagir")
	_ok(not gerente.em_conversa(), "com o mapa aberto nao se inicia conversa")
	await _acao("ui_cancel")
	_ok(not mapa.aberto(), "ESC fecha o mapa")
	_ok(not jogador.congelado, "o controle volta ao fechar o mapa")
	await _acao("abrir_mapa")
	await _acao("abrir_mapa")
	_ok(not mapa.aberto(), "M abre e M fecha")
