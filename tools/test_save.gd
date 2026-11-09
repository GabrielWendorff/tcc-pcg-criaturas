extends Node

## Teste headless do menu principal e do sistema de save — roda SEM abrir janela:
##   godot --headless --path . -s res://tools/test_save.gd
##
## Cobre as camadas que podem falhar por motivos diferentes:
##
##   1. SEMENTE (regra pura): a conversao texto -> seed, que e a promessa de
##      RF01/RF03 virando funcao. Inclui um valor FIXADO: se a FNV mudar, o teste
##      quebra — e tem de quebrar, porque mudar o hash troca o mundo de todos os
##      saves existentes.
##   2. FORMATO (regra pura): ida e volta de DadosPartida, campos ausentes,
##      versao futura, save invalido.
##   3. CRIATURA SALVA contra um bestiario de verdade, gerado pelo
##      GeradorCriaturas: e o unico jeito de provar que guardar indice + seed no
##      lugar dos atributos de fato reconstroi a mesma criatura.
##   4. DISCO: gravar, reler, slot vazio, arquivo corrompido, queda do backup,
##      apagar. Grava em user://saves_teste/ para nao encostar nos saves reais.
##
## Sai com codigo != 0 se algo falhar.

const SEED := 123456789
const N := 40
const DIR_TESTE := "user://saves_teste/"

var _falhas: int = 0
var _verificacoes: int = 0


func _ready() -> void:
	print("== Menu e save — teste headless ==")
	ArquivoSave.diretorio = DIR_TESTE
	_limpar_diretorio()

	_testar_semente()
	_testar_formato()
	_testar_criatura_salva()
	_testar_disco()
	_testar_autoload()

	_limpar_diretorio()
	print("\n==")
	if _verificacoes < 40:
		print("RESULTADO: so %d verificacoes rodaram — o teste abortou no meio"
				% _verificacoes)
		get_tree().quit(1)
	elif _falhas > 0:
		print("RESULTADO: %d VERIFICACAO(OES) FALHARAM" % _falhas)
		get_tree().quit(1)
	else:
		print("RESULTADO: TODOS OS TESTES PASSARAM (%d verificacoes)" % _verificacoes)
		get_tree().quit(0)


# ----------------------------------------------------------------- 1. semente

func _testar_semente() -> void:
	print("\n-- 1. Semente (RF01/RF03)")
	_ok(Semente.de_texto("123456789") == 123456789,
			"texto numerico vale por si (abre o mundo do visualizador)")
	_ok(Semente.de_texto("  42  ") == 42, "espacos em volta sao ignorados")
	_ok(Semente.de_texto("") == 0, "texto vazio = 0, o sentinela de 'sem partida'")
	_ok(Semente.de_texto("ribeira") == Semente.de_texto("ribeira"),
			"a mesma palavra devolve sempre a mesma seed")
	_ok(Semente.de_texto("ribeira") != Semente.de_texto("Ribeira"),
			"a caixa importa — sao duas palavras diferentes")
	_ok(Semente.de_texto("ribeira") != Semente.de_texto("ribeiro"),
			"palavras parecidas dao mundos diferentes")
	_ok(Semente.de_texto("ribeira") > 0, "a seed e sempre positiva")

	# VALOR FIXADO. Nao e o numero que importa: e que ele nunca mude. Se esta
	# linha falhar, a conversao foi alterada e todo save existente passou a
	# apontar para outro mundo.
	_ok(Semente.de_texto("anselmo") == 4144908266,
			"a FNV nao mudou (ancora de compatibilidade dos saves)")
	_ok(Semente.de_texto("ribeira") == 4018126233, "ancora: 'ribeira'")

	var sorteios: Dictionary = {}
	for _i in 20:
		sorteios[Semente.aleatoria()] = true
	_ok(sorteios.size() >= 18, "o sorteio de seed nao se repete")


# ------------------------------------------------------------------ 2. formato

func _testar_formato() -> void:
	print("\n-- 2. Formato do save")
	var d := DadosPartida.nova(SEED, "ribeira", N)
	d.celula = Vector2i(60, 20)
	d.direcao = "cima"
	d.regiao = "ribeira"
	d.regiao_nome = "Ribeira do Anselmo"
	d.tempo_jogado = 3672.0
	d.estado_mundo = {"bandeiras": {"sabe_da_pesca": true}, "regioes": ["vila"],
			"vistos": {"anselmo:raiz": 2}}
	d.itens = {"esfera_simples": 7, "osso": 2}
	var salva := CriaturaSalva.new()
	salva.id = 3
	salva.world_seed = SEED
	salva.nivel = 5
	d.armazenadas.append(salva)

	var volta := DadosPartida.de_dicionario(d.para_dicionario())
	_ok(volta.valido(), "ida e volta produz um save valido")
	_ok(volta.seed_mundo == SEED and volta.seed_texto == "ribeira",
			"a seed e o texto sobrevivem")
	_ok(volta.celula == Vector2i(60, 20) and volta.direcao == "cima",
			"posicao e direcao sobrevivem")
	_ok(volta.regiao_nome == "Ribeira do Anselmo", "o nome da regiao sobrevive")
	_ok(volta.itens.get("esfera_simples") == 7, "as quantidades sobrevivem")
	_ok(volta.estado_mundo.get("bandeiras", {}).get("sabe_da_pesca") == true,
			"as bandeiras do EstadoMundo sobrevivem")
	_ok(volta.armazenadas.size() == 1 and volta.armazenadas[0].nivel == 5,
			"as criaturas guardadas sobrevivem")
	_ok(volta.tempo_legivel() == "1h 01m", "tempo jogado legivel: %s"
			% volta.tempo_legivel())
	_ok(volta.seed_legivel() == "ribeira", "o cartao mostra a palavra, nao o numero")
	_ok(DadosPartida.nova(SEED, "", N).seed_legivel() == str(SEED),
			"sem palavra, o cartao mostra o numero")

	# Campos ausentes nao sao erro: e o que faz um save da Etapa 1 abrir na 4.
	var minimo := DadosPartida.de_dicionario(
			{"versao": 1, "mundo": {"seed": SEED}})
	_ok(minimo.valido(), "save minimo (so a seed) e aceito")
	_ok(minimo.equipe.is_empty() and minimo.armazenadas.is_empty(),
			"secoes ausentes viram padrao, nao erro")
	_ok(minimo.lugar_legivel() == "Mundo", "sem regiao, o cartao nao fica vazio")
	_ok(not minimo.tem_posicao(),
			"save sem posicao nasce no spawn do mapa, nao na celula (0,0)")
	_ok(volta.tem_posicao(), "save com posicao gravada e reconhecido como tal")

	_ok(not DadosPartida.de_dicionario({"versao": 1, "mundo": {}}).valido(),
			"save sem seed e recusado")
	_ok(not DadosPartida.de_dicionario({"versao": 99}).valido(),
			"save de versao futura e recusado em vez de lido pela metade")

	var intruso := DadosPartida.de_dicionario({
		"versao": 1, "mundo": {"seed": SEED, "criaturas": N},
		"armazenadas": [{"id": 1, "seed": 999}]})
	_ok(not intruso.valido(), "criatura de outro mundo e recusada")

	var fora := DadosPartida.de_dicionario({
		"versao": 1, "mundo": {"seed": SEED, "criaturas": N},
		"armazenadas": [{"id": N + 5, "seed": SEED}]})
	_ok(not fora.valido(), "criatura fora do bestiario e recusada")


# ----------------------------------------------------------- 3. criatura salva

func _testar_criatura_salva() -> void:
	print("\n-- 3. CriaturaSalva contra o bestiario de verdade")
	var tabelas := TabelasProbabilidade.carregar()
	if tabelas == null:
		_ok(false, "tabelas de probabilidade carregaram")
		return
	var gerador := GeradorCriaturas.new(tabelas)
	var bestiario := gerador.gerar_bestiario(SEED, N)
	_ok(bestiario.size() == N, "bestiario de %d criaturas gerado" % N)

	var original: Criatura = bestiario[7]
	var salva := CriaturaSalva.de_criatura(original, 4)
	var dict := salva.para_dicionario()
	var relida := CriaturaSalva.de_dicionario(dict)
	_ok(relida.id == 7 and relida.nivel == 4, "ida e volta da criatura salva")

	# O ponto do formato: os atributos NAO estao no arquivo e mesmo assim voltam.
	_ok(not dict.has("elemento") and not dict.has("morfologia"),
			"o save nao guarda nenhum atributo gerado")
	var resolvida := relida.resolver(bestiario)
	_ok(resolvida != null, "a criatura resolve contra o bestiario")
	if resolvida != null:
		_ok(resolvida.elemento == original.elemento
				and resolvida.animal_base == original.animal_base
				and resolvida.porte == original.porte
				and resolvida.matiz == original.matiz
				and resolvida.morfologia == original.morfologia,
				"os atributos foram RECALCULADOS iguais a partir da seed")

	# Gerar de novo a mesma seed tem de dar o mesmo bestiario (RF03), que e o
	# que torna o formato possivel.
	var outro := GeradorCriaturas.new(tabelas).gerar_bestiario(SEED, N)
	_ok((outro[7] as Criatura).nome() == original.nome(),
			"a mesma seed regenera a mesma criatura numa segunda rodada")

	var de_outro_mundo := CriaturaSalva.de_dicionario({"id": 7, "seed": SEED + 1})
	_ok(de_outro_mundo.resolver(bestiario) == null,
			"criatura de outra seed nao resolve (e nao devolve a vizinha)")
	_ok(CriaturaSalva.de_dicionario({"id": N + 1, "seed": SEED}).resolver(bestiario) == null,
			"indice fora do bestiario nao resolve")


# -------------------------------------------------------------------- 4. disco

func _testar_disco() -> void:
	print("\n-- 4. Disco: gravar, reler, corromper, recuperar")
	_ok(ArquivoSave.ler(1)["estado"] == ArquivoSave.Estado.VAZIO,
			"slot nunca gravado le como VAZIO")
	_ok(ArquivoSave.ler(0)["estado"] == ArquivoSave.Estado.DANIFICADO,
			"slot fora de 1..3 e recusado")

	var d := DadosPartida.nova(SEED, "ribeira", N)
	d.celula = Vector2i(60, 20)
	d.itens = {"osso": 3}
	_ok(ArquivoSave.escrever(1, d) == "", "gravou o slot 1")
	_ok(d.salvo_em != "", "o carimbo de data foi preenchido na gravacao")

	var r := ArquivoSave.ler(1)
	_ok(r["estado"] == ArquivoSave.Estado.OK, "releu o slot 1")
	_ok((r["dados"] as DadosPartida).celula == Vector2i(60, 20),
			"o que voltou do disco e o que foi gravado")
	_ok(not bool(r["do_backup"]), "a primeira leitura nao veio do backup")

	# Segunda gravacao: o arquivo anterior tem de virar backup.
	d.celula = Vector2i(23, 19)
	_ok(ArquivoSave.escrever(1, d) == "", "gravou por cima")
	_ok(FileAccess.file_exists(ArquivoSave.caminho_backup(1)),
			"a gravacao anterior virou backup")
	_ok((ArquivoSave.ler(1)["dados"] as DadosPartida).celula == Vector2i(23, 19),
			"a leitura traz a versao mais nova, nao o backup")

	# Corrompe o principal. O backup tem de salvar a partida.
	_escrever_cru(ArquivoSave.caminho(1), "{\"versao\": 1, \"mundo\": {\"se")
	var recuperado := ArquivoSave.ler(1)
	_ok(recuperado["estado"] == ArquivoSave.Estado.OK,
			"principal truncado: a leitura cai no backup")
	_ok(bool(recuperado["do_backup"]), "a leitura avisa que veio do backup")
	_ok((recuperado["dados"] as DadosPartida).celula == Vector2i(60, 20),
			"o backup e a gravacao ANTERIOR, como esperado")

	# Corrompe os dois. Agora e DANIFICADO, e tem de ter motivo escrito.
	_escrever_cru(ArquivoSave.caminho_backup(1), "lixo que nao e json")
	var ruim := ArquivoSave.ler(1)
	_ok(ruim["estado"] == ArquivoSave.Estado.DANIFICADO,
			"principal e backup ruins: DANIFICADO")
	_ok(String(ruim["erro"]) != "", "o cartao tem um motivo para mostrar: %s"
			% ruim["erro"])
	_ok(ruim["dados"] == null, "save danificado nao devolve dados pela metade")

	# Um save semanticamente invalido (seed 0) e tao danificado quanto um JSON
	# quebrado: o arquivo le, mas a partida nao existe.
	_escrever_cru(ArquivoSave.caminho(2), "{\"versao\": 1, \"mundo\": {\"seed\": 0}}")
	_ok(ArquivoSave.ler(2)["estado"] == ArquivoSave.Estado.DANIFICADO,
			"JSON valido com conteudo impossivel tambem e DANIFICADO")

	# Gravar por cima de um slot danificado tem de funcionar: e como o jogador
	# se livra dele sem sair do jogo.
	_ok(ArquivoSave.escrever(2, DadosPartida.nova(SEED, "", N)) == "",
			"da para gravar por cima de um slot danificado")
	_ok(ArquivoSave.ler(2)["estado"] == ArquivoSave.Estado.OK,
			"o slot danificado voltou a ser valido")

	ArquivoSave.apagar(1)
	_ok(ArquivoSave.ler(1)["estado"] == ArquivoSave.Estado.VAZIO,
			"apagar limpa principal E backup")
	_ok(not ArquivoSave.existe(1), "o slot apagado deixa de existir")


# ----------------------------------------------------------------- 5. autoload

func _testar_autoload() -> void:
	print("\n-- 5. Autoload Save")
	var save := get_tree().root.get_node_or_null("/root/Save")
	if save == null:
		_ok(false, "o autoload Save esta registrado em project.godot")
		return
	_ok(true, "o autoload Save esta no ar")
	_ok(not save.em_partida(), "sem partida ao abrir")

	save.nova_partida(SEED, "ribeira", 3, N)
	_ok(save.em_partida() and save.partida.seed_mundo == SEED,
			"nova_partida poe a seed em vigor")
	_ok(save.slot_atual == 3, "a partida lembra de que slot veio")

	# Secoes: o Save colhe e repoe sem conhecer quem guarda o dado.
	var caixa := {"valor": 0}
	save.registrar_secao("teste",
			func(d: DadosPartida) -> void: d.itens = {"marca": caixa["valor"]},
			func(d: DadosPartida) -> void: caixa["valor"] = int(d.itens.get("marca", -1)))
	caixa["valor"] = 77
	_ok(save.salvar() == "", "salvou pelo autoload")
	caixa["valor"] = 0
	_ok(save.carregar(3), "carregou o slot 3")
	save.restaurar_na_cena()
	_ok(caixa["valor"] == 0,
			"carregar esquece as secoes da cena anterior (nao repoe em no morto)")

	save.registrar_secao("teste",
			func(d: DadosPartida) -> void: d.itens = {"marca": caixa["valor"]},
			func(d: DadosPartida) -> void: caixa["valor"] = int(d.itens.get("marca", -1)))
	save.restaurar_na_cena()
	_ok(caixa["valor"] == 77, "a secao reregistrada repoe o valor gravado")

	save.recarregar_resumos()
	_ok(save.ha_save(), "ha_save ve o slot gravado (habilita Continuar)")
	_ok(save.slot_mais_recente() == 3, "o slot mais recente e o 3")
	save.encerrar_partida()
	_ok(not save.em_partida(), "encerrar_partida limpa a sessao")
	save.apagar(3)
	save.apagar(2)
	_ok(not save.ha_save(), "sem save nenhum, Continuar fica apagado")


# ------------------------------------------------------------------ utilidades

func _escrever_cru(caminho: String, texto: String) -> void:
	var f := FileAccess.open(caminho, FileAccess.WRITE)
	if f != null:
		f.store_string(texto)
		f.close()


func _limpar_diretorio() -> void:
	if not DirAccess.dir_exists_absolute(DIR_TESTE):
		return
	for nome in DirAccess.get_files_at(DIR_TESTE):
		DirAccess.remove_absolute(DIR_TESTE + nome)


func _ok(condicao: bool, descricao: String) -> void:
	_verificacoes += 1
	if condicao:
		print("   ok   " + descricao)
	else:
		_falhas += 1
		print("  FALHA " + descricao)
