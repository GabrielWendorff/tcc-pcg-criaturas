extends SceneTree

## Teste headless das opcoes e da bolsa — roda SEM abrir janela:
##   godot --headless --path . -s res://tools/test_bolsa.gd
##
##   1. OPCOES (regra pura): os dois tipos de DefinicaoOpcao, a validacao que
##      recusa valor estranho vindo de um arquivo editado a mao, e o ciclo.
##   2. CATALOGO: as duas fontes num namespace so, sem id repetido, todo item
##      com icone desenhado. Icone faltando nao da erro na engine — da um buraco
##      na bolsa, e e exatamente o que esta verificacao existe para pegar.
##   3. BOLSA: a API (adicionar/remover/tem/quantidade), o teto de pilha, o item
##      permanente que nao se gasta, os marcadores e os sinais.
##   4. INTEGRACAO: o encontro continua recebendo um InventarioJogador, a bolsa
##      sobrevive ao save, e a opcao de encontro nao mexe no bestiario (RF03).
##
## Sai com codigo != 0 se algo falhar.

const SEED := 123456789
const DIR_TESTE := "user://saves_teste_bolsa/"

var _falhas: int = 0
var _verificacoes: int = 0


func _initialize() -> void:
	print("== Opcoes e bolsa — teste headless ==")
	ArquivoSave.diretorio = DIR_TESTE
	_limpar()

	_testar_definicoes()
	_testar_catalogo()
	_testar_bolsa()
	_testar_integracao()

	_limpar()
	print("\n==")
	if _verificacoes < 40:
		print("RESULTADO: so %d verificacoes rodaram — o teste abortou no meio"
				% _verificacoes)
		quit(1)
	elif _falhas > 0:
		print("RESULTADO: %d VERIFICACAO(OES) FALHARAM" % _falhas)
		quit(1)
	else:
		print("RESULTADO: TODOS OS TESTES PASSARAM (%d verificacoes)" % _verificacoes)
		quit(0)


# ----------------------------------------------------------------- 1. opcoes

func _testar_definicoes() -> void:
	print("\n-- 1. DefinicaoOpcao")
	var b := DefinicaoOpcao.de_dicionario(
			{"id": "tremor", "rotulo": "Tremor", "padrao": true})
	_ok(b.tipo == DefinicaoOpcao.Tipo.BOOLEANA, "sem 'valores', a opcao e booleana")
	_ok(b.aceita(false) and not b.aceita("sim"),
			"booleana recusa valor que nao e bool")
	_ok(b.proximo(true) == false, "booleana inverte")
	_ok(b.rotulo_do_valor(true) == "LIGADO", "rotulo da booleana")
	_ok(b.dado_do_valor(false) == false, "o dado da booleana e ela mesma")

	var e := DefinicaoOpcao.de_dicionario({
		"id": "velocidade", "rotulo": "Velocidade", "padrao": "normal",
		"valores": [
			{"id": "lento", "rotulo": "LENTO", "dado": 26.0},
			{"id": "normal", "rotulo": "NORMAL", "dado": 46.0},
			{"id": "rapido", "rotulo": "RÁPIDO", "dado": 84.0},
		]})
	_ok(e.tipo == DefinicaoOpcao.Tipo.ESCOLHA, "com 'valores', a opcao e escolha")
	_ok(e.aceita("lento") and not e.aceita("turbo"),
			"escolha recusa um id que nao esta na lista")
	_ok(not e.aceita(true), "escolha recusa booleano")
	_ok(e.proximo("normal") == "rapido", "escolha avanca")
	_ok(e.proximo("rapido") == "lento", "escolha da a volta")
	_ok(e.dado_do_valor("rapido") == 84.0,
			"o dado e o numero que o consumidor usa, nao o rotulo")

	# O autoload de verdade.
	var opcoes := root.get_node_or_null("/root/Opcoes")
	if opcoes == null:
		_ok(false, "o autoload Opcoes esta registrado em project.godot")
		return
	_ok(opcoes.definicoes().size() >= 4, "as opcoes do jogo estao declaradas")
	_ok(opcoes.ligada("tremor_camera"), "tremor de camera vem ligado")
	opcoes.definir("tremor_camera", false)
	_ok(not opcoes.ligada("tremor_camera"), "definir desliga")
	_ok(opcoes.dado("velocidade_texto") == 46.0,
			"velocidade padrao = 46 caracteres por segundo")
	opcoes.alternar("velocidade_texto")
	_ok(opcoes.dado("velocidade_texto") == 84.0, "alternar avanca a escolha")
	opcoes.definir("velocidade_texto", "turbo")
	_ok(opcoes.dado("velocidade_texto") == 84.0,
			"valor invalido e recusado, o anterior fica de pe")
	_ok(opcoes.ligada("id_que_nao_existe"),
			"opcao inexistente devolve o padrao em vez de desligar o jogo")
	opcoes.restaurar_padroes()
	_ok(opcoes.ligada("tremor_camera") and opcoes.dado("velocidade_texto") == 46.0,
			"restaurar padroes volta tudo")


# --------------------------------------------------------------- 2. catalogo

func _testar_catalogo() -> void:
	print("\n-- 2. CatalogoItens")
	var captura := TabelasCaptura.carregar()
	if captura == null:
		_ok(false, "tabelas de captura carregaram")
		return
	var cat := CatalogoItens.carregar(captura)
	if cat == null:
		_ok(false, "catalogo carregou")
		return
	_ok(true, "catalogo carregou")

	var esperado: int = captura.dispositivos.size() + captura.iscas.size()
	_ok(cat.da_categoria("dispositivos").size() == captura.dispositivos.size(),
			"os dispositivos vieram de data/captura/, sem redeclaracao")
	_ok(cat.da_categoria("iscas").size() == captura.iscas.size(),
			"as iscas vieram de data/captura/, sem redeclaracao")
	_ok(cat.itens.size() > esperado,
			"o catalogo acrescenta itens proprios aos de captura")
	_ok(cat.item("esfera_simples") != null
			and cat.item("esfera_simples").captura is DispositivoCaptura,
			"o item envelopa o DispositivoCaptura original, nao uma copia")
	_ok(cat.item("osso").detalhe() == captura.isca("osso").detalhe(),
			"o detalhe do item E o detalhe da mecanica — um metodo so")

	var vara := cat.item("vara_de_pesca")
	_ok(vara != null, "a vara de pesca existe no catalogo")
	if vara != null:
		_ok(not vara.empilhavel and vara.permanente,
				"a vara nao empilha e nao se gasta")
		_ok(vara.tem_marcador("pesca"), "a vara esta marcada para pesca")
	_ok(cat.item("minhoca").tem_marcador("pesca"),
			"toda isca de captura serve de isca de pesca")
	_ok(cat.com_marcador("pesca").size() >= captura.iscas.size() + 1,
			"a pesca acha vara e iscas por marcador, sem conhecer categoria")

	var pocao := cat.item("pocao_simples")
	_ok(pocao != null and int(pocao.efeito.get("valor", 0)) == 30,
			"o efeito declarado chega intacto")
	_ok(pocao != null and pocao.detalhe().contains("30"),
			"o detalhe do consumivel descreve o efeito: %s"
			% (pocao.detalhe() if pocao != null else ""))

	# A verificacao que mais importa: icone faltando nao da erro na engine.
	var indice: Dictionary = {}
	var bruto: Variant = JSON.parse_string(
			FileAccess.get_file_as_string("res://arte/itens/itens.json"))
	if bruto is Dictionary:
		indice = bruto.get("itens", {})
	_ok(not indice.is_empty(), "o indice de icones foi lido")
	var problemas := cat.validar(indice)
	_ok(problemas.is_empty(), "nenhum problema de dado: %s" % ", ".join(problemas))


# ------------------------------------------------------------------ 3. bolsa

func _testar_bolsa() -> void:
	print("\n-- 3. Bolsa")
	var bolsa := root.get_node_or_null("/root/Bolsa")
	if bolsa == null:
		_ok(false, "o autoload Bolsa esta registrado em project.godot")
		return
	_ok(bolsa.pronta(), "a bolsa carregou catalogo e tabelas")
	bolsa.reiniciar()

	_ok(bolsa.quantidade("esfera_simples") == 12,
			"a carga inicial veio de data/captura/dispositivos.json")
	_ok(bolsa.quantidade("pocao_simples") == 3,
			"a carga inicial veio tambem de data/itens/catalogo.json")
	_ok(bolsa.quantidade("vara_de_pesca") == 0,
			"a vara comeca fora da bolsa — quem a da e o pescador")

	_ok(bolsa.tem("pocao_simples", 3) and not bolsa.tem("pocao_simples", 4),
			"tem() respeita a quantidade pedida")
	_ok(bolsa.adicionar("pocao_simples", 2) == 2, "adicionar devolve quanto coube")
	_ok(bolsa.quantidade("pocao_simples") == 5, "a quantidade subiu")
	_ok(bolsa.remover("pocao_simples", 5), "remover tira o que ha")
	_ok(bolsa.quantidade("pocao_simples") == 0, "a quantidade zerou")
	_ok(not bolsa.remover("pocao_simples"), "remover sem estoque falha e nao zera abaixo")
	_ok(bolsa.adicionar("item_que_nao_existe") == 0,
			"id desconhecido nao entra na bolsa")

	# Nao empilhavel: o teto e 1, por mais vezes que o pescador ofereca.
	_ok(bolsa.adicionar("vara_de_pesca", 3) == 1,
			"item nao empilhavel aceita no maximo uma unidade")
	_ok(bolsa.adicionar("vara_de_pesca") == 0, "a segunda vara nao entra")
	_ok(not bolsa.remover("vara_de_pesca"),
			"item permanente nao pode ser descartado")

	_ok(bolsa.tem_marcador("pesca"), "com a vara na bolsa, ha equipamento de pesca")
	# Vara + lanterna + pa de jardim: as duas ferramentas de exemplo da roda de
	# itens entram na carga inicial (quantidade_inicial 1, data/itens/catalogo.json).
	_ok(bolsa.com_marcador("equipamento").size() == 3,
			"com_marcador lista so o que esta EM ESTOQUE")

	# Aba vazia nao aparece.
	var antes: int = bolsa.categorias_com_itens().size()
	for i: ItemJogo in bolsa.catalogo.da_categoria("consumiveis"):
		while bolsa.quantidade(i.id) > 0:
			bolsa.remover(i.id)
	_ok(bolsa.categorias_com_itens().size() == antes - 1,
			"categoria sem estoque some das abas")
	_ok(bolsa.da_categoria("consumiveis").is_empty()
			and not bolsa.da_categoria("consumiveis", true).is_empty(),
			"da_categoria esconde os zerados, salvo quando pedido")

	# Sinal.
	var ouvido := {"id": "", "n": -1}
	var ouvinte := func(id: String, n: int) -> void:
		ouvido["id"] = id
		ouvido["n"] = n
	bolsa.item_mudou.connect(ouvinte)
	bolsa.adicionar("pocao_forte", 2)
	_ok(ouvido["id"] == "pocao_forte" and ouvido["n"] == 2,
			"item_mudou repassa a mudanca do inventario")
	bolsa.item_mudou.disconnect(ouvinte)

	bolsa.reiniciar()
	_ok(bolsa.quantidade("pocao_simples") == 3 and bolsa.quantidade("vara_de_pesca") == 0,
			"reiniciar devolve a carga inicial")


# ------------------------------------------------------------- 4. integracao

func _testar_integracao() -> void:
	print("\n-- 4. Integracao")
	var bolsa := root.get_node_or_null("/root/Bolsa")
	var save := root.get_node_or_null("/root/Save")
	var opcoes := root.get_node_or_null("/root/Opcoes")
	if bolsa == null or save == null or opcoes == null:
		_ok(false, "os tres autoloads estao no ar")
		return

	# O encontro continua recebendo um InventarioJogador — e agora o da bolsa.
	_ok(bolsa.inventario is InventarioJogador,
			"a bolsa possui o InventarioJogador que o encontro ja usava")
	bolsa.reiniciar()
	bolsa.inventario.consumir("esfera_simples", 1)
	_ok(bolsa.quantidade("esfera_simples") == 11,
			"consumir pelo inventario (como o encontro faz) muda a bolsa")

	# Save: a secao da bolsa e PERMANENTE e sobrevive a troca de cena.
	save.nova_partida(SEED, "", 1, 20)
	bolsa.adicionar("pocao_forte", 4)
	_ok(save.salvar(1) == "", "salvou com a bolsa dentro")
	bolsa.reiniciar()
	_ok(bolsa.quantidade("pocao_forte") == 1, "a bolsa voltou a carga inicial")
	_ok(save.carregar(1), "carregou o slot")
	# `carregar` esquece as secoes DE CENA; a da bolsa tem de continuar la.
	save.restaurar_na_cena()
	_ok(bolsa.quantidade("pocao_forte") == 5,
			"a secao permanente da bolsa sobreviveu ao esquecer_secoes")
	save.esquecer_secoes()
	save.restaurar_na_cena()
	_ok(bolsa.quantidade("pocao_forte") == 5,
			"esquecer_secoes nao derruba as permanentes")

	# A opcao de encontro nao pode tocar o bestiario (RF03).
	var tabelas := TabelasProbabilidade.carregar()
	if tabelas != null:
		opcoes.definir("encontros_aleatorios", true)
		var a := GeradorCriaturas.new(tabelas).gerar_bestiario(SEED, 30)
		opcoes.definir("encontros_aleatorios", false)
		var b := GeradorCriaturas.new(tabelas).gerar_bestiario(SEED, 30)
		var iguais := true
		for i in a.size():
			if (a[i] as Criatura).nome() != (b[i] as Criatura).nome():
				iguais = false
		_ok(iguais, "o bestiario da seed e o mesmo com a opcao ligada ou desligada")
		opcoes.restaurar_padroes()

	save.encerrar_partida()
	save.apagar(1)
	bolsa.reiniciar()


# ------------------------------------------------------------------ utilidades

func _limpar() -> void:
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
