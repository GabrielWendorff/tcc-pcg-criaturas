extends SceneTree

## Teste headless do tutorial em dado — roda SEM abrir janela e SEM autoload:
##   godot --headless --path . -s res://tools/test_tutorial.gd
##
## Cobre o que NAO pode falhar com o jogador no meio da licao:
##   - autoral/tutoriais/pesca.json carrega e e coerente com a arvore
##     anselmo_tutorial (cada conversa existe e esta em `entradas`), com o
##     catalogo de itens (o que se entrega existe) e com o NPC que fala;
##   - ids de passo unicos, eventos e efeitos conhecidos, destinos de falha reais
##     — um passo esperando um evento que ninguem emite prende o jogador numa
##     dica que nunca sai da tela;
##   - o fluxo inteiro por eventos: valor errado nao avanca, valor certo avanca,
##     falha no recolhimento volta ao arremesso, falha onde nao ha `se_falhar` e
##     ignorada, e a sequencia termina concluida;
##   - a fonte pixel cobre cada texto e cada dica (glifo ausente nao da erro na
##     engine: sai como caixa vazia na tela);
##   - o Anselmo abre na licao SEM a bandeira (pedindo o servico do tutorial) e na
##     conversa normal COM ela, oferecendo repetir a licao.
##
## O GerenciadorTutorial NAO entra aqui: ele fala com a Bolsa (autoload), e sob
## -s os autoloads nao existem. Tudo o que ele decide, porem, e perguntado a
## SequenciaTutorial (reacao, destino_de_falha) — e e isso que este teste exercita.
##
## Sai com codigo != 0 se algo falhar.

## Glifos que a fonte ate poderia ganhar um dia, mas que o projeto proibe por
## convencao (contrato da pesca, secao 1): reticencias, aspas curvas, visto,
## setas verticais.
const PROIBIDOS := ["…", "“", "”", "‘", "’", "✓", "↑", "↓"]

var _falhas: int = 0
var _verificacoes: int = 0


func _initialize() -> void:
	print("== Tutorial de pesca — teste headless ==")
	_rodar()
	print("\n==")
	if _verificacoes < 30:
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
	var seq := SequenciaTutorial.carregar("pesca")
	if not _ok(seq != null, "autoral/tutoriais/pesca.json carregou"):
		return
	_ok(seq.erro == "", "carga sem erro de forma", seq.erro)
	var dialogos := CatalogoDialogos.new()
	var arvore := dialogos.arvore(seq.arvore)
	_ok(arvore != null, "a arvore de dialogo do tutorial existe", seq.arvore)

	_testar_dados(seq, arvore)
	_testar_validacao_de_autoria(arvore)
	_testar_fluxo(seq)
	_testar_textos(seq)
	_testar_anselmo(seq, dialogos)


# ------------------------------------------------------------ 1. dados
func _testar_dados(seq: SequenciaTutorial, arvore: ArvoreDialogo) -> void:
	print("\nDados do tutorial")
	var erros := seq.validar(arvore)
	_ok(erros.is_empty(), "pesca.json valido contra a arvore anselmo_tutorial",
			"\n       ".join(erros))
	_ok(seq.id == "pesca" and seq.npc == "anselmo" and seq.arvore == "anselmo_tutorial",
			"id, npc e arvore declarados", "%s / %s / %s" % [seq.id, seq.npc, seq.arvore])
	_ok(seq.bandeira_concluido == "tutorial_pesca_concluido",
			"bandeira de concluido e a que o save e o Anselmo leem", seq.bandeira_concluido)

	var ids := {}
	var repetidos := PackedStringArray()
	for p: Dictionary in seq.passos:
		var id_passo := String(p.get("id", ""))
		if ids.has(id_passo):
			repetidos.append(id_passo)
		ids[id_passo] = true
	_ok(repetidos.is_empty() and ids.size() == seq.passos.size(), "ids de passo unicos",
			", ".join(repetidos))
	var ordem := PackedStringArray()
	for p: Dictionary in seq.passos:
		ordem.append(String(p.get("id", "")))
	_ok(ordem == PackedStringArray(["apresentacao", "equipar", "arremesso", "recolher",
			"silhueta", "despedida"]), "os seis passos da licao, na ordem pedida",
			" > ".join(ordem))

	var eventos_ruins := PackedStringArray()
	var efeitos_ruins := PackedStringArray()
	for p: Dictionary in seq.passos:
		var esperar: Variant = p.get("esperar")
		if esperar is Dictionary and not String(esperar.get("evento", "")) in SequenciaTutorial.EVENTOS:
			eventos_ruins.append("%s:%s" % [p.get("id"), esperar.get("evento")])
		for bloco: String in ["ao_iniciar", "ao_concluir"]:
			for chave: String in (p.get(bloco, {}) as Dictionary).keys():
				if not chave in SequenciaTutorial.EFEITOS:
					efeitos_ruins.append("%s.%s.%s" % [p.get("id"), bloco, chave])
	for chave: String in (seq.ao_pular.get("efeitos", {}) as Dictionary).keys():
		if not chave in SequenciaTutorial.EFEITOS:
			efeitos_ruins.append("ao_pular." + chave)
	_ok(eventos_ruins.is_empty(), "todo evento esperado e conhecido", ", ".join(eventos_ruins))
	_ok(efeitos_ruins.is_empty(), "todo efeito declarado e conhecido", ", ".join(efeitos_ruins))

	# Itens entregues existem no catalogo da bolsa — senao Bolsa.adicionar devolve
	# 0, a nota nao sai e o jogador termina a licao sem a vara.
	var catalogo := CatalogoItens.carregar(TabelasCaptura.carregar())
	if _ok(catalogo != null, "catalogo de itens carregou (sem autoload)"):
		var ausentes := PackedStringArray()
		var blocos: Array = [seq.ao_pular.get("efeitos", {})]
		for p: Dictionary in seq.passos:
			blocos.append(p.get("ao_iniciar", {}))
			blocos.append(p.get("ao_concluir", {}))
		for bloco: Dictionary in blocos:
			for id_item: String in (bloco.get("dar_itens", {}) as Dictionary).keys():
				if catalogo.item(id_item) == null:
					ausentes.append(id_item)
		_ok(ausentes.is_empty(), "todo item entregue existe no catalogo", ", ".join(ausentes))
		var vara := catalogo.item("vara_de_pesca")
		_ok(vara != null and vara.tem_marcador("equipamento"),
				"a vara entregue aparece na roda (marcador 'equipamento')")

	var pular_efeitos: Dictionary = seq.ao_pular.get("efeitos", {})
	_ok(int((pular_efeitos.get("dar_itens", {}) as Dictionary).get("vara_de_pesca", 0)) >= 1
			and bool(pular_efeitos.get("concluir", false)),
			"pular entrega a vara e conclui", str(pular_efeitos))
	_ok(String(seq.ao_pular.get("conversa", "")) == "pulou", "pular tem a conversa 'pulou'")
	var npcs := CatalogoNpcs.carregar()
	_ok(npcs.por_id(seq.npc) != null, "o NPC que fala a licao existe em npcs.json", seq.npc)


# ---------------------------------------------- 2. validacao de autoria
func _testar_validacao_de_autoria(arvore: ArvoreDialogo) -> void:
	print("\nValidacao (erro de autoria)")
	var ruim := SequenciaTutorial.de_dicionario({
		"id": "ruim", "npc": "anselmo", "arvore": "anselmo_tutorial",
		"bandeira_concluido": "x",
		"textos": {"titulo_dica": "T", "aviso_pular": "A", "pular_pergunta": "P",
				"pular_sim": "S", "pular_nao": "N", "recebeu": "Recebeu %s"},
		"ao_pular": {"conversa": "nao_existe"},
		"passos": [
			{"id": "a", "esperar": {"evento": "piscou"}},
			{"id": "a", "conversa": "apresentacao", "ao_concluir": {"teletransportar": true}},
			{"id": "c", "esperar": {"evento": "fisgado"}, "se_falhar": "z"},
			{"id": "d", "dica": "sem espera", "esprar": {"evento": "fisgado"}},
		],
	})
	var erros := "\n".join(ruim.validar(arvore))
	var torta := SequenciaTutorial.de_dicionario({"id": "torta", "passos": "nao e lista"})
	_ok(torta.erro.contains("passos deve ser lista")
			and "\n".join(torta.validar()).contains("passos deve ser lista"),
			"bloco com tipo errado vira 'erro' e aparece na validacao", torta.erro)
	_ok(erros.contains("evento desconhecido 'piscou'"), "evento desconhecido e reportado")
	_ok(erros.contains("id de passo repetido"), "id de passo repetido e reportado")
	_ok(erros.contains("efeito desconhecido 'teletransportar'"),
			"efeito desconhecido e reportado")
	_ok(erros.contains("se_falhar aponta para 'z'"), "se_falhar para passo inexistente e reportado")
	_ok(erros.contains("chave desconhecida 'esprar'"), "chave de passo escrita errada e reportada")
	_ok(erros.contains("'dica' sem 'esperar'"), "dica que nunca apareceria e reportada")
	_ok(erros.contains("'nao_existe' nao existe"), "conversa inexistente na arvore e reportada")
	_ok(erros.contains("'recebeu' precisa"), "molde de 'recebeu' sem %d e reportado")


# ---------------------------------------------------- 3. fluxo por eventos
## Simula o que o GerenciadorTutorial faz com cada evento: pergunta reacao() e
## so entao avanca ou volta.
func _reagir(seq: SequenciaTutorial, evento: String, valor: String = "") -> String:
	var r := seq.reacao(evento, valor)
	if r == SequenciaTutorial.REACAO_CONCLUIR:
		seq.avancar()
	elif r == SequenciaTutorial.REACAO_VOLTAR:
		seq.ir_para(seq.destino_de_falha())
	return r


func _testar_fluxo(seq: SequenciaTutorial) -> void:
	print("\nFluxo da licao por eventos")
	_ok(not seq.ativa() and not seq.concluida(), "antes de iniciar: nem ativa nem concluida")
	seq.iniciar()
	_ok(seq.ativa() and seq.id_do_passo() == "apresentacao", "comeca na apresentacao",
			seq.id_do_passo())
	_ok(_reagir(seq, "falhou") == "" and seq.id_do_passo() == "apresentacao",
			"'falhou' na apresentacao (sem se_falhar) e ignorado")
	_ok(seq.passo_atual().get("esperar") == null, "a apresentacao nao espera evento",
			"conclui quando a conversa fecha")
	seq.avancar()

	_ok(seq.id_do_passo() == "equipar", "segue para equipar", seq.id_do_passo())
	_ok(bool((seq.passo_atual().get("ao_iniciar", {}) as Dictionary).get("desequipar", false)),
			"equipar comeca desequipando (repetir a licao exige equipar de novo)")
	_ok(_reagir(seq, "item_equipado", "lanterna") == "" and seq.id_do_passo() == "equipar",
			"item_equipado com OUTRO item nao avanca")
	_ok(_reagir(seq, "item_equipado", "") == "" and seq.id_do_passo() == "equipar",
			"mao vazia nao avanca")
	_ok(_reagir(seq, "arremessado") == "" and seq.id_do_passo() == "equipar",
			"evento de outro passo nao avanca")
	_ok(_reagir(seq, "item_equipado", "vara_de_pesca") == SequenciaTutorial.REACAO_CONCLUIR
			and seq.id_do_passo() == "arremesso", "equipar a VARA avanca para o arremesso",
			seq.id_do_passo())

	_ok(_reagir(seq, "pesca_iniciada") == "" and seq.id_do_passo() == "arremesso",
			"abrir o arco ainda nao conclui o arremesso")
	_ok(_reagir(seq, "falhou") == "" and seq.id_do_passo() == "arremesso",
			"cancelar no arco nao volta nada (arremesso nao trata falha)")
	_reagir(seq, "arremessado")
	_ok(seq.id_do_passo() == "recolher", "isca na agua: passo de recolher", seq.id_do_passo())

	_ok(seq.reacao("falhou") == SequenciaTutorial.REACAO_VOLTAR
			and seq.destino_de_falha() == "arremesso", "falhar no recolher pede volta ao arremesso")
	_reagir(seq, "falhou")
	_ok(seq.id_do_passo() == "arremesso", "falhou no recolher -> volta ao arremesso",
			seq.id_do_passo())
	_reagir(seq, "arremessado")
	_reagir(seq, "silhueta_surgiu")
	_ok(seq.id_do_passo() == "silhueta", "silhueta surgiu: passo de igualar", seq.id_do_passo())
	_reagir(seq, "falhou")
	_ok(seq.id_do_passo() == "arremesso", "falhou com a silhueta -> volta ao arremesso",
			seq.id_do_passo())
	_reagir(seq, "arremessado")
	_reagir(seq, "silhueta_surgiu")
	_reagir(seq, "fisgado")
	_ok(seq.id_do_passo() == "despedida", "fisgou: despedida", seq.id_do_passo())
	var final: Dictionary = seq.passo_atual().get("ao_concluir", {})
	_ok(int((final.get("dar_itens", {}) as Dictionary).get("minhoca", 0)) > 0
			and bool(final.get("concluir", false)),
			"a despedida entrega minhocas e marca concluido", str(final))
	seq.avancar()
	_ok(seq.concluida() and not seq.ativa(), "a sequencia termina concluida")
	_ok(seq.reacao("fisgado") == "" and seq.passo_atual().is_empty(),
			"concluida, nenhum evento reage")

	seq.iniciar()
	_ok(seq.id_do_passo() == "apresentacao", "iniciar() de novo recomeca do passo zero")
	_ok(not seq.ir_para("nao_existe") and seq.id_do_passo() == "apresentacao",
			"ir_para um passo inexistente nao mexe no cursor")


# ------------------------------------------------------------ 4. textos
func _testar_textos(seq: SequenciaTutorial) -> void:
	print("\nTextos e tipografia")
	for chave: String in SequenciaTutorial.TEXTOS_OBRIGATORIOS:
		_ok(seq.texto(chave) != chave, "texto '%s' presente" % chave, seq.texto(chave))
	var recebeu := seq.texto_recebeu("Vara de Pesca", 1)
	_ok(recebeu == "Recebeu: Vara de Pesca ×1", "nota de item no formato pedido", recebeu)

	var amostra := ""
	for chave: String in seq.textos.keys():
		amostra += String(seq.textos[chave])
	amostra += recebeu + seq.texto_recebeu("Minhoca", 5)
	var sem_dica := PackedStringArray()
	for p: Dictionary in seq.passos:
		amostra += String(p.get("dica", ""))
		if p.get("esperar") != null and String(p.get("dica", "")).strip_edges() == "":
			sem_dica.append(String(p.get("id", "")))
	_ok(sem_dica.is_empty(), "todo passo que espera tem dica na tela", ", ".join(sem_dica))

	var fonte := TemaEncontro.fonte()
	var faltando := PackedStringArray()
	var proibidos := PackedStringArray()
	for i in amostra.length():
		var c: String = amostra[i]
		if not fonte.has_char(c.unicode_at(0)) and not c in faltando:
			faltando.append(c)
		if c in PROIBIDOS and not c in proibidos:
			proibidos.append(c)
	_ok(faltando.is_empty(), "a fonte pixel cobre textos e dicas do tutorial",
			"".join(faltando))
	_ok(proibidos.is_empty(), "nenhum glifo proibido pela convencao", "".join(proibidos))


# ------------------------------------------------- 5. Anselmo e a bandeira
func _testar_anselmo(seq: SequenciaTutorial, dialogos: CatalogoDialogos) -> void:
	print("\nAnselmo: licao na primeira vez, conversa depois")
	var anselmo := dialogos.arvore("anselmo")
	if not _ok(anselmo != null, "anselmo.json carregou"):
		return

	var novo := EstadoMundo.new()
	var s := SessaoDialogo.new(anselmo, novo, "anselmo")
	s.iniciar()
	_ok(s.no != null and s.no.id == "licao", "sem a bandeira, a conversa abre em 'licao'",
			s.no.id if s.no != null else "null")
	var pedido := _servico_de_tutorial(s.servicos)
	_ok(not pedido.is_empty() and String(pedido.get("tutorial", "")) == seq.id
			and String(pedido.get("npc", "")) == "anselmo",
			"a licao pede o servico do tutorial de pesca", str(s.servicos))
	var falas := 0
	while s.tem_fala():
		falas += 1
		s.avancar()
	_ok(falas == 1 and s.terminou(), "a licao e uma fala de chamada e encerra",
			"%d fala(s)" % falas)

	var s_volta := SessaoDialogo.new(anselmo, novo, "anselmo")
	s_volta.iniciar()
	_ok(s_volta.no != null and s_volta.no.id == "licao"
			and String(s_volta.fala_atual().get("texto", "")).contains("onde a gente parou"),
			"licao interrompida: volta a chamar, com a fala de retomada",
			String(s_volta.fala_atual().get("texto", "")).substr(0, 50))

	# A bandeira que o tutorial marca e a que o Anselmo le — dois arquivos, um nome.
	var feito := EstadoMundo.new()
	feito.definir(seq.bandeira_concluido, true)
	var s2 := SessaoDialogo.new(anselmo, feito, "anselmo")
	s2.iniciar()
	_ok(s2.no != null and s2.no.id == "raiz", "com a bandeira, a conversa abre em 'raiz'",
			s2.no.id if s2.no != null else "null")
	_ok(_servico_de_tutorial(s2.servicos).is_empty(), "e nao pede tutorial sozinha")
	while s2.tem_fala():
		s2.avancar()
	var indice_repetir := -1
	for i in s2.escolhas().size():
		if String(s2.escolhas()[i]["destino"]) == "repetir_licao":
			indice_repetir = i
	_ok(indice_repetir == 0, "'assuntos' oferece repetir a licao, como primeira opcao",
			"indice %d" % indice_repetir)
	if indice_repetir >= 0:
		s2.escolher(indice_repetir)
		_ok(not _servico_de_tutorial(s2.servicos).is_empty(),
				"repetir a licao pede o mesmo servico do tutorial", str(s2.servicos))

	var s3 := SessaoDialogo.new(anselmo, EstadoMundo.new(), "anselmo")
	s3.iniciar("raiz")
	while s3.tem_fala():
		s3.avancar()
	var oferece := false
	for op: Dictionary in s3.escolhas():
		if String(op["destino"]) == "repetir_licao":
			oferece = true
	_ok(not oferece, "sem a licao feita, nao ha 'repetir' no menu")

	# Cada conversa que o tutorial abre termina sozinha, sem menu: a ordem da
	# licao e dos passos, e uma escolha no meio deixaria o passo esperando.
	var tutorial := dialogos.arvore(seq.arvore)
	var problemas := PackedStringArray()
	var conversas := PackedStringArray([String(seq.ao_pular.get("conversa", "")),
			SequenciaTutorial.CONVERSA_TENTAR_DE_NOVO])
	for p: Dictionary in seq.passos:
		if String(p.get("conversa", "")) != "":
			conversas.append(String(p["conversa"]))
	for no: String in conversas:
		var st := SessaoDialogo.new(tutorial, EstadoMundo.new(), "anselmo")
		st.iniciar(no)
		var n := 0
		while st.tem_fala() and n < 20:
			n += 1
			st.avancar()
		if n == 0 or not st.terminou() or st.esperando_escolha():
			problemas.append(no)
	_ok(problemas.is_empty(), "toda conversa do tutorial tem falas e fecha sem menu",
			", ".join(problemas))


func _servico_de_tutorial(servicos: Array[Dictionary]) -> Dictionary:
	for pedido: Dictionary in servicos:
		if String(pedido.get("tipo", "")) == "tutorial":
			return pedido
	return {}
