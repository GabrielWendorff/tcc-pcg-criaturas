extends SceneTree

## Teste headless do sistema de NPC e dialogo — roda SEM abrir janela:
##   godot --headless --path . -s res://tools/test_dialogo.gd
##
## Cobre o que NAO pode falhar na frente de quem joga:
##   - toda arvore de autoral/dialogos/ e estruturalmente valida (destino que nao
##     existe congelaria o jogador numa caixa sem saida);
##   - todo NPC tem arvore, arte e celula propria;
##   - a travessia da conversa faz o que o JSON diz — ramificacao, variante
##     condicional, efeito e servico;
##   - inicios condicionais escolhem o no de abertura pela condicao, e entradas
##     externas (as do tutorial) contam no teste de alcance;
##   - a fonte pixel cobre cada caractere escrito nos dialogos (glifo ausente nao
##     da erro na engine: sai como caixa vazia na tela).
##
## Sai com codigo != 0 se algo falhar.

var _falhas: int = 0
var _verificacoes: int = 0


func _initialize() -> void:
	print("== NPC e dialogo — teste headless ==")
	_rodar()
	print("\n==")
	if _verificacoes < 25:
		print("RESULTADO: so %d verificacoes rodaram — o teste abortou no meio"
				% _verificacoes)
		quit(1)
	elif _falhas > 0:
		print("RESULTADO: %d VERIFICACAO(OES) FALHARAM" % _falhas)
		quit(1)
	else:
		print("RESULTADO: TODOS OS TESTES PASSARAM")
		quit(0)


func _ok(condicao: bool, rotulo: String, detalhe: String = "") -> bool:
	print("    %s %s%s" % ["OK  " if condicao else "FALHOU", rotulo,
			"" if detalhe == "" else "  — " + detalhe])
	_verificacoes += 1
	if not condicao:
		_falhas += 1
	return condicao


func _rodar() -> void:
	var dialogos := CatalogoDialogos.new()
	var arvores := dialogos.carregar_todas()

	# ------------------------------------------------ 1. arvores e catalogo
	print("\nArvores de dialogo")
	_ok(arvores.size() >= 5, "arvores carregadas", "%d encontradas" % arvores.size())
	var erros := dialogos.validar()
	_ok(erros.is_empty(), "todas as arvores sao estruturalmente validas",
			"\n       ".join(erros))
	for a: ArvoreDialogo in arvores:
		_ok(a.nos.has(a.inicio) and not a.nos.is_empty(),
				"%s: no inicial '%s' existe" % [a.id, a.inicio],
				"%d nos" % a.nos.size())

	print("\nCatalogo de NPCs")
	var npcs := CatalogoNpcs.carregar()
	_ok(npcs.erro == "", "autoral/npcs/npcs.json carregou", npcs.erro)
	_ok(npcs.npcs.size() >= 5, "NPCs declarados", "%d" % npcs.npcs.size())
	var erros_npc := npcs.validar(dialogos)
	_ok(erros_npc.is_empty(), "NPCs coerentes com dialogos e arte",
			"\n       ".join(erros_npc))
	for n: DadosNpc in npcs.npcs:
		var quadros := Jogador.montar_quadros(n.folha)
		_ok(quadros != null and quadros.get_animation_names().size() == 8,
				"%s: folha de caminhada com 8 animacoes" % n.id, n.folha)

	# ------------------------------------------------ 2. travessia da conversa
	print("\nTravessia (mirela: raiz -> assuntos -> topico -> assuntos)")
	var estado := EstadoMundo.new()
	var arvore := dialogos.arvore("mirela")
	var s := SessaoDialogo.new(arvore, estado, "mirela")
	s.iniciar()
	_ok(s.tem_fala(), "a conversa abre com uma fala",
			String(s.fala_atual().get("texto", "")).substr(0, 40))
	_ok(not s.esperando_escolha(), "nao pede escolha antes de a fala acabar")
	s.avancar()
	_ok(s.esperando_escolha(), "terminada a fala, o no ramifica")
	_ok(s.escolhas().size() == 3, "tres escolhas no no inicial",
			"%d" % s.escolhas().size())

	s.escolher(0)                                  # "Sim, acabei de chegar."
	_ok(estado.ativa("se_apresentou"), "a escolha aplicou o efeito 'definir'")
	var falas := 0
	while s.tem_fala():
		falas += 1
		s.avancar()
	_ok(falas == 2, "o no 'chegou' tem duas falas", "%d lidas" % falas)
	_ok(s.esperando_escolha(), "'seguinte' levou ao menu de assuntos")
	var assuntos := s.escolhas().size()
	_ok(assuntos == 6, "seis assuntos disponiveis", "%d" % assuntos)

	s.escolher(1)                                  # "Sobre o rio"
	while s.tem_fala():
		s.avancar()
	_ok(estado.ativa("ouviu_sobre_rio"), "o topico marcou a bandeira do assunto")
	_ok(s.esperando_escolha() and s.escolhas().size() == assuntos,
			"o topico volta ao mesmo menu (ciclo da arvore)")

	# saida pela ultima opcao
	s.escolher(s.escolhas().size() - 1)
	while s.tem_fala():
		s.avancar()
	_ok(s.terminou(), "a despedida encerra a conversa")

	# ------------------------------------------------ 3. variantes condicionais
	print("\nVariantes condicionais")
	var s2 := SessaoDialogo.new(arvore, estado, "mirela")
	s2.iniciar()
	_ok(String(s2.fala_atual()["texto"]).begins_with("De volta"),
			"segunda conversa usa a variante de quem ja se apresentou",
			String(s2.fala_atual()["texto"]).substr(0, 30))

	var estado_novo := EstadoMundo.new()
	var s3 := SessaoDialogo.new(arvore, estado_novo, "mirela")
	s3.iniciar()
	_ok(String(s3.fala_atual()["texto"]).begins_with("Você é novo"),
			"estado limpo usa a fala base")

	# variante por provedor externo: "capturadas"
	# Dicionario e nao variavel local: em GDScript o lambda captura por VALOR, e
	# um contador solto nunca mudaria dentro do provedor ja registrado.
	var bolsa := {"n": 0}
	estado_novo.registrar_provedor("capturadas", func(_c: String) -> int: return bolsa["n"])
	_ok(not CondicaoDialogo.avaliar({"capturadas": "total", "pelo_menos": 1}, estado_novo),
			"condicao por provedor externo e falsa com zero capturadas")
	bolsa["n"] = 3
	_ok(CondicaoDialogo.avaliar({"capturadas": "total", "pelo_menos": 1}, estado_novo),
			"a mesma condicao passa quando o provedor muda")

	# ------------------------------------------------ 4. escolha condicionada
	print("\nEscolhas condicionadas e cruzamento entre NPCs")
	var e4 := EstadoMundo.new()
	# Licao ja feita: sem a bandeira, o Anselmo abre na licao de pesca (inicios
	# condicionais, secao 9) e nao no menu de assuntos que este trecho percorre.
	e4.definir("tutorial_pesca_concluido", true)
	var s4 := SessaoDialogo.new(dialogos.arvore("anselmo"), e4, "anselmo")
	s4.iniciar()
	while s4.tem_fala():
		s4.avancar()
	var antes := s4.escolhas().size()
	var tem_pescar := false
	for op: Dictionary in s4.escolhas():
		if String(op["destino"]) == "pescar_agora":
			tem_pescar = true
	_ok(not tem_pescar, "'Posso pescar agora?' escondida antes de falar de pesca",
			"%d opcoes" % antes)
	e4.definir("sabe_da_pesca", true)
	var depois := s4.escolhas().size()
	_ok(depois == antes + 1, "a opcao aparece quando a bandeira e posta",
			"%d -> %d" % [antes, depois])

	var e5 := EstadoMundo.new()
	e5.definir("ouviu_sobre_fabrica", true)
	var s5 := SessaoDialogo.new(dialogos.arvore("otavio"), e5, "otavio")
	s5.iniciar()
	_ok(String(s5.fala_atual()["texto"]).contains("perguntando da fábrica"),
			"Otavio reage a bandeira posta por OUTRO NPC (Mirela)")

	# ------------------------------------------------ 5. servicos (ganchos)
	print("\nServicos pedidos pelo dialogo (loja, pesca)")
	var e6 := EstadoMundo.new()
	var s6 := SessaoDialogo.new(dialogos.arvore("bento"), e6, "bento")
	s6.iniciar()
	while s6.tem_fala():
		s6.avancar()
	s6.servicos.clear()
	var indice_loja := -1
	for i in s6.escolhas().size():
		if String(s6.escolhas()[i]["destino"]) == "loja":
			indice_loja = i
	_ok(indice_loja >= 0, "a padaria oferece a opcao de loja")
	s6.escolher(indice_loja)
	_ok(s6.servicos.size() == 1, "o efeito 'servico' foi enfileirado",
			"%d" % s6.servicos.size())
	if s6.servicos.size() == 1:
		_ok(String(s6.servicos[0].get("tipo", "")) == "loja"
				and String(s6.servicos[0].get("npc", "")) == "bento",
				"o pedido carrega tipo e NPC de origem", str(s6.servicos[0]))

	# ------------------------------------------------ 6. condicoes invalidas
	print("\nValidacao de condicoes (erro de autoria)")
	_ok(not CondicaoDialogo.validar({"bandeirq": "x"}, "teste").is_empty(),
			"chave de condicao desconhecida e reportada")
	_ok(CondicaoDialogo.validar({"todos": [{"bandeira": "a"}, {"nao": {"visitou": "b"}}]},
			"teste").is_empty(), "composicao valida passa")
	_ok(CondicaoDialogo.avaliar(null, EstadoMundo.new()),
			"ausencia de condicao e verdadeiro")

	# ------------------------------------------------ 7. estado e save
	print("\nEstado de mundo (ganchos de save)")
	var e7 := EstadoMundo.new()
	e7.definir("moedas", 10)
	e7.somar("moedas", 5)
	_ok(int(e7.ler("moedas")) == 15, "somar acumula sobre definir",
			str(e7.ler("moedas")))
	_ok(e7.visitar("ribeira"), "primeira visita a uma regiao devolve true")
	_ok(not e7.visitar("ribeira"), "a segunda nao — e o que evita reanunciar")
	e7.marcar_visto("anselmo", "rio")
	var copia := EstadoMundo.new()
	copia.de_dicionario(e7.para_dicionario())
	_ok(int(copia.ler("moedas")) == 15 and copia.visitou("ribeira")
			and copia.quantas_vezes("anselmo", "rio") == 1,
			"para_dicionario/de_dicionario preservam bandeiras, regioes e vistos")

	# ------------------------------------------------ 8. cobertura da fonte
	print("\nTipografia")
	var fonte := TemaEncontro.fonte()
	var faltando := PackedStringArray()
	var amostra := "[E] FALAR▶·"
	for a: ArvoreDialogo in arvores:
		amostra += a.nome
		for id_do_no: String in a.nos.keys():
			var n: NoDialogo = a.nos[id_do_no]
			amostra += n.pergunta
			for f: Dictionary in n.falas:
				amostra += String(f["texto"])
			for v: Dictionary in n.variantes:
				for f: Dictionary in v["falas"]:
					amostra += String(f["texto"])
			for op: Dictionary in n.escolhas:
				amostra += String(op["texto"])
	for n: DadosNpc in npcs.npcs:
		amostra += n.nome + n.papel
	var ids_varridos := PackedStringArray()
	for a: ArvoreDialogo in arvores:
		ids_varridos.append(a.id)
	_ok("anselmo_tutorial" in ids_varridos,
			"a varredura de glifos inclui a arvore do tutorial (anselmo_tutorial)",
			", ".join(ids_varridos))
	for i in amostra.length():
		var c: String = amostra[i]
		if not fonte.has_char(c.unicode_at(0)) and not c in faltando:
			faltando.append(c)
	_ok(faltando.is_empty(), "a fonte pixel cobre todo o texto dos dialogos",
			"".join(faltando))

	# ------------------------------------------------ 9. inicios e entradas
	_testar_inicios_e_entradas(dialogos)


## Inicios condicionais (o no de abertura depende do mundo) e entradas externas
## (nos abertos pelo tutorial, que nenhum outro no aponta).
func _testar_inicios_e_entradas(dialogos: CatalogoDialogos) -> void:
	print("\nInicios condicionais e entradas externas")
	var dados := {
		"id": "teste", "inicio": "raiz",
		"inicios": [
			{"se": {"bandeira": "a"}, "no": "via_a"},
			{"se": {"bandeira": "b"}, "no": "via_b"},
		],
		"nos": {
			"raiz": {"falas": ["raiz"], "fim": true},
			"via_a": {"falas": ["a"], "fim": true},
			"via_b": {"falas": ["b"], "fim": true},
		},
	}
	var a := ArvoreDialogo.de_dicionario(dados)
	_ok(a.validar().is_empty(), "nos alcancados so por inicios nao sao orfaos",
			"\n       ".join(a.validar()))
	var e := EstadoMundo.new()
	_ok(a.inicio_para(e) == "raiz", "nenhuma condicao verdadeira: vale 'inicio'",
			a.inicio_para(e))
	e.definir("b", true)
	_ok(a.inicio_para(e) == "via_b", "a regra cuja condicao passa escolhe o inicio",
			a.inicio_para(e))
	e.definir("a", true)
	_ok(a.inicio_para(e) == "via_a", "com duas verdadeiras, vence a PRIMEIRA da lista",
			a.inicio_para(e))
	_ok(a.inicio_para(null) == "raiz", "sem estado, vale 'inicio' (leitura neutra)")
	var s := SessaoDialogo.new(a, e, "teste")
	s.iniciar()
	_ok(s.no != null and s.no.id == "via_a", "SessaoDialogo.iniciar() segue inicio_para",
			s.no.id if s.no != null else "null")
	s.iniciar("via_b")
	_ok(s.no != null and s.no.id == "via_b", "iniciar(no) abre exatamente no no pedido",
			s.no.id if s.no != null else "null")

	# entradas
	var orfa := ArvoreDialogo.de_dicionario({
		"id": "orfa", "inicio": "raiz",
		"nos": {"raiz": {"falas": ["r"], "fim": true}, "solto": {"falas": ["s"], "fim": true}},
	})
	var erros_orfa := orfa.validar()
	_ok(erros_orfa.size() == 1 and erros_orfa[0].contains("inalcancavel"),
			"no que ninguem abre continua sendo reportado", "\n       ".join(erros_orfa))
	var com_entrada := ArvoreDialogo.de_dicionario({
		"id": "com_entrada", "inicio": "raiz", "entradas": ["solto"],
		"nos": {"raiz": {"falas": ["r"], "fim": true}, "solto": {"falas": ["s"], "fim": true}},
	})
	_ok(com_entrada.validar().is_empty(), "entrada externa conta como raiz no alcance",
			"\n       ".join(com_entrada.validar()))

	# erros de autoria
	var ruim := ArvoreDialogo.de_dicionario({
		"id": "ruim", "inicio": "raiz", "entradas": ["fantasma"],
		"inicios": [{"se": {"bandeirq": "x"}, "no": "raiz"}, {"no": "raiz"},
				{"se": {"bandeira": "x"}, "no": "nao_existe"}],
		"nos": {"raiz": {"falas": ["r"], "fim": true}},
	})
	var erros_ruim := "\n".join(ruim.validar())
	_ok(erros_ruim.contains("entrada 'fantasma' nao existe"),
			"entrada que nao existe e reportada")
	_ok(erros_ruim.contains("bandeirq"), "condicao invalida num inicio e reportada")
	_ok(erros_ruim.contains("sem condicao"), "regra de inicio sem 'se' e reportada")
	_ok(erros_ruim.contains("'nao_existe' nao existe"),
			"regra de inicio apontando para no inexistente e reportada")

	# as arvores reais do Anselmo
	var anselmo := dialogos.arvore("anselmo")
	var tutorial := dialogos.arvore("anselmo_tutorial")
	_ok(anselmo != null and anselmo.validar().is_empty(), "anselmo.json valido",
			"" if anselmo == null else "\n       ".join(anselmo.validar()))
	_ok(anselmo != null and not anselmo.inicios.is_empty(),
			"anselmo.json declara inicio condicional (licao na primeira vez)")
	_ok(tutorial != null and tutorial.validar().is_empty(), "anselmo_tutorial.json valido",
			"" if tutorial == null else "\n       ".join(tutorial.validar()))
	if tutorial != null:
		var faltam := PackedStringArray()
		for no: String in ["apresentacao", "ensina_roda", "ensina_arremesso",
				"tentar_de_novo", "despedida", "pulou"]:
			if not no in tutorial.entradas or not tutorial.nos.has(no):
				faltam.append(no)
		_ok(faltam.is_empty(), "anselmo_tutorial declara os seis nos como entradas",
				", ".join(faltam))
		var sem_fim := PackedStringArray()
		for no: String in tutorial.entradas:
			var n: NoDialogo = tutorial.nos.get(no)
			if n == null or not n.termina_conversa() or n.falas.is_empty():
				sem_fim.append(no)
		_ok(sem_fim.is_empty(), "cada entrada do tutorial tem falas e termina sozinha",
				", ".join(sem_fim))

