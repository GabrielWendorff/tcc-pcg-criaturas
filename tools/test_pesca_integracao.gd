extends Node

## Teste de INTEGRACAO da pesca no mundo de verdade — roda como CENA normal:
##   godot --headless --path . res://tools/test_pesca_integracao.tscn
##
## NAO sob -s, de proposito: o mundo cita os autoloads (Opcoes pela camera, Bolsa,
## Save), e sob -s eles nao existem no Godot 4.7 ("Identifier not found: Opcoes"
## — a falha pre-existente de test_encontro/test_interacao). Como cena, tudo
## compila e os autoloads estao no ar.
##
## O que tools/test_pesca.gd NAO cobre e este cobre: as LIGACOES de mundo.gd.
## A regra da pesca ja e testada sem janela; aqui o que se verifica e que a cena
## monta as pecas, que um dono da tela por vez vale (pesca x dialogo x pausa x
## roda), que a mao, a bolsa, o tutorial e o save conversam pelos sinais certos
## — e que nada disso mexeu no bestiario da seed (RF03).
##
## Roteiro, sobre presentation/exploracao/mundo.tscn (seed padrao, sem partida):
##   1. montagem: nos, mao, indicador, HUD, glifos, bestiario identico
##   2. beira d'agua perto do Anselmo; sem vara -> aviso (pela tecla F de verdade)
##   3. vara pela Bolsa -> item_equipado_mudou -> pode_pescar_aqui
##   4. roda (Q pressiona/solta de verdade): fechar sem troca, trocar, voltar
##   5. lance em modo tutorial com politica perfeita -> FISGADO -> OCIOSO
##   6. ESC no meio do recolhimento cancela SEM abrir a pausa; um clique no fade
##      de saida do minigame ja inicia o lance seguinte
##   7. licao completa do Anselmo, passo a passo, ate as minhocas
##   8. pular a licao: vara entregue, bandeira posta
##   9. save: bandeira e item na mao sobrevivem a ida e volta
##
## Engine.time_scale acelera o jogo; os tetos de espera sao em tempo de PAREDE,
## e um vigia (Timer que ignora a escala) derruba o teste se algo travar.

const CENA_MUNDO := "res://presentation/exploracao/mundo.tscn"
const BANDEIRA := "tutorial_pesca_concluido"
const VARA := "vara_de_pesca"
## Aceleracao do relogio do jogo. Alta o bastante para o roteiro inteiro levar
## segundos; baixa o bastante para os tweens e o recolhimento continuarem
## tendo varios quadros por fase.
const ACELERACAO := 4.0
## Teto de cada espera e do teste inteiro, em segundos de parede.
const TETO_ESPERA := 20.0
const TETO_TOTAL := 180.0
## Raio de busca da beira, em celulas, em volta do Anselmo ([60,20]).
const RAIO_BEIRA := 16
const MINIMO_VERIFICACOES := 140

var _falhas: int = 0
var _verificacoes: int = 0

var _m: Node2D
var _pesca: GerenciadorPesca
var _tutorial: GerenciadorTutorial
var _roda: RodaItens
var _dialogos: GerenciadorDialogo
var _jogador: Jogador
var _estado: EstadoMundo
var _mundo_iso: MundoIso

## Registro dos sinais, na ordem em que chegaram: ["peixe_fisgado", c]...
var _eventos: Array = []
var _avisos: PackedStringArray = []
var _notas: PackedStringArray = []
var _equipados: PackedStringArray = []
var _beira: Vector2i = Vector2i(-1, -1)
var _direcao_beira: String = ""


func _ready() -> void:
	var vigia := Timer.new()
	vigia.one_shot = true
	vigia.wait_time = TETO_TOTAL
	vigia.ignore_time_scale = true
	vigia.process_mode = Node.PROCESS_MODE_ALWAYS
	vigia.timeout.connect(_estourou)
	add_child(vigia)
	vigia.start()

	print("== Pesca integrada ao mundo — teste de cena ==")
	Engine.time_scale = ACELERACAO
	await _rodar()
	Engine.time_scale = 1.0
	print("\n==")
	# Sem esta guarda, um erro que abortasse _rodar() no meio sairia com codigo
	# 0 e passaria por sucesso.
	if _verificacoes < MINIMO_VERIFICACOES:
		print("RESULTADO: so %d verificacoes rodaram — o teste abortou no meio"
				% _verificacoes)
		get_tree().quit(1)
	elif _falhas > 0:
		print("RESULTADO: %d VERIFICACAO(OES) FALHARAM" % _falhas)
		get_tree().quit(1)
	else:
		print("RESULTADO: TODOS OS TESTES PASSARAM (%d verificacoes)" % _verificacoes)
		get_tree().quit(0)


func _estourou() -> void:
	Engine.time_scale = 1.0
	print("\nRESULTADO: TEMPO ESGOTADO (%.0f s) apos %d verificacoes, %d falha(s)"
			% [TETO_TOTAL, _verificacoes, _falhas])
	get_tree().quit(1)


func _ok(condicao: bool, rotulo: String, detalhe: String = "") -> bool:
	print("    %s %s%s" % ["OK  " if condicao else "FALHOU", rotulo,
			"" if detalhe == "" else "  — " + detalhe])
	_verificacoes += 1
	if not condicao:
		_falhas += 1
	return condicao


## Espera `condicao` ficar verdadeira, quadro a quadro, ate `teto` segundos de
## parede. Nunca `await sinal` direto: um sinal que nao vem travaria o teste.
func _esperar(condicao: Callable, teto: float = TETO_ESPERA) -> bool:
	var limite: int = Time.get_ticks_msec() + int(teto * 1000.0)
	while not bool(condicao.call()):
		if Time.get_ticks_msec() > limite:
			return false
		await get_tree().process_frame
	return true


func _quadros(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _quadros_fisica(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _rodar() -> void:
	if not await _montagem():
		return
	if not await _beira_sem_vara():
		return
	await _com_vara()
	await _roda_de_itens()
	await _lance_perfeito()
	await _cancelar_com_esc()
	await _licao_completa()
	await _pular_licao()
	_save()


# ------------------------------------------------------------- 1. montagem

func _montagem() -> bool:
	print("\n1. Montagem do mundo")
	var cena: PackedScene = load(CENA_MUNDO)
	if not _ok(cena != null, "mundo.tscn carregou"):
		return false
	_m = cena.instantiate() as Node2D
	add_child(_m)
	await _quadros(3)
	if not _ok(_m.get("_aviso") == null, "nenhum erro de montagem na tela"):
		return false
	_pesca = _m.get("pesca") as GerenciadorPesca
	_tutorial = _m.get("tutorial") as GerenciadorTutorial
	_roda = _m.get("roda") as RodaItens
	_dialogos = _m.get("dialogos") as GerenciadorDialogo
	_jogador = _m.get("jogador") as Jogador
	_estado = _m.get("estado_mundo") as EstadoMundo
	_mundo_iso = _m.get("mundo") as MundoIso
	if not _ok(_pesca != null and _tutorial != null and _roda != null and _dialogos != null
			and _jogador != null and _estado != null, "pesca, tutorial, roda, dialogo e jogador"):
		return false
	_ok(_m.get_node_or_null("Pesca") == _pesca, "GerenciadorPesca filho da cena ('Pesca')",
			"a ordem de _unhandled_input depende disto")
	_ok(_m.get_node_or_null("Tutorial") == _tutorial, "GerenciadorTutorial filho da cena")
	_ok(_m.get_node_or_null("RodaItens") == _roda and _roda.layer == RodaItens.CAMADA,
			"RodaItens na camada %d" % RodaItens.CAMADA)
	_ok(_pesca.erro == "" and _pesca.interface != null, "pesca preparada", _pesca.erro)
	_ok(_pesca.interface != null and _pesca.interface.layer == GerenciadorPesca.CAMADA_INTERFACE,
			"InterfacePesca na camada %d" % GerenciadorPesca.CAMADA_INTERFACE)
	_ok(_tutorial.dica != null and _tutorial.dica.layer == DicaTutorial.CAMADA,
			"DicaTutorial na camada %d" % DicaTutorial.CAMADA)
	var mao := _jogador.mao
	_ok(mao is SlotDaMao and mao.get_parent() == _jogador, "jogador.mao e a SlotDaMao do jogador")
	_ok(_jogador.get_node_or_null("IndicadorPesca") is IndicadorInteracao,
			"indicador '[F] PESCAR' montado no jogador")
	_ok(_pesca.perfis().size() > 0, "perfis de pesca da seed",
			"%d elegiveis de %d" % [_pesca.perfis().size(), _encontros().bestiario.size()])

	# RF03: a pesca le o bestiario, nao gera nada — o da cena e o do gerador puro.
	var enc := _encontros()
	var puro: Array = GeradorCriaturas.new(enc.tabelas, enc.catalogo).gerar_bestiario(
			int(_m.get("seed_do_mundo")), int(_m.get("criaturas_por_mundo")))
	var iguais: bool = puro.size() == enc.bestiario.size()
	for i in mini(puro.size(), enc.bestiario.size()):
		if (puro[i] as Criatura).to_dict() != (enc.bestiario[i] as Criatura).to_dict():
			iguais = false
			break
	_ok(iguais, "bestiario da cena identico ao do gerador (RF03)",
			"%d criaturas" % puro.size())

	# HUD: a linha de teclas cita Q e F, cabe na tela e so usa glifos da fonte.
	var teclas := String(_constante("TEXTO_TECLAS"))
	_ok(teclas.contains("Q itens  F usar"), "HUD de teclas inclui 'Q itens  F usar'")
	var hud := _m.get("_hud_dica") as Control
	_ok(hud != null and _texto_do_hud(hud) == teclas, "HUD mostra a linha de teclas")
	var largura: float = TemaEncontro.fonte().get_string_size(teclas,
			HORIZONTAL_ALIGNMENT_LEFT, -1, TemaEncontro.TAM_TEXTO).x
	var tela: float = get_viewport().get_visible_rect().size.x
	_ok(14.0 + largura <= tela, "linha de teclas cabe na tela",
			"%.0f px de %.0f" % [14.0 + largura, tela])
	for nome: String in ["TEXTO_TECLAS", "TEXTO_PESCA_COM_VARA", "TEXTO_PESCA_EQUIPAR",
			"TEXTO_PESCA_SEM_VARA", "TEXTO_FISGOU", "TEXTO_SEM_SALVAR_PESCA"]:
		var faltando := _glifos_faltando(String(_constante(nome)))
		_ok(faltando == "", "glifos de %s na fonte pixel" % nome, faltando)

	# Ligacoes: cada sinal que o contrato manda ligar tem ao menos um ouvinte.
	for par: Array in [[_pesca.aviso, "pesca.aviso"], [_pesca.pesca_iniciada, "pesca_iniciada"],
			[_pesca.arremessado, "arremessado"], [_pesca.silhueta_surgiu, "silhueta_surgiu"],
			[_pesca.peixe_fisgado, "peixe_fisgado"], [_pesca.pesca_falhou, "pesca_falhou"],
			[_pesca.pesca_encerrada, "pesca_encerrada"],
			[_jogador.item_equipado_mudou, "item_equipado_mudou"],
			[_tutorial.tutorial_iniciado, "tutorial_iniciado"],
			[_tutorial.tutorial_concluido, "tutorial_concluido"],
			[_tutorial.desequipar_pedido, "desequipar_pedido"], [_tutorial.nota, "tutorial.nota"],
			[_roda.item_escolhido, "roda.item_escolhido"], [_roda.fechada, "roda.fechada"]]:
		var s: Signal = par[0]
		_ok(not s.get_connections().is_empty(), "%s ligado pela cena" % String(par[1]))

	_conectar_registros()
	return true


func _conectar_registros() -> void:
	_pesca.aviso.connect(func(t: String) -> void: _avisos.append(t))
	_pesca.pesca_iniciada.connect(func() -> void: _eventos.append(["pesca_iniciada"]))
	_pesca.arremessado.connect(func(f: float, z: String, d: float) -> void:
			_eventos.append(["arremessado", f, z, d]))
	_pesca.silhueta_surgiu.connect(func(c: Criatura) -> void:
			_eventos.append(["silhueta_surgiu", c]))
	_pesca.peixe_fisgado.connect(func(c: Criatura) -> void: _eventos.append(["peixe_fisgado", c]))
	_pesca.pesca_falhou.connect(func(m: String) -> void: _eventos.append(["pesca_falhou", m]))
	_pesca.pesca_encerrada.connect(func() -> void: _eventos.append(["pesca_encerrada"]))
	_jogador.item_equipado_mudou.connect(func(id: String) -> void: _equipados.append(id))
	_tutorial.tutorial_iniciado.connect(func(id: String) -> void:
			_eventos.append(["tutorial_iniciado", id]))
	_tutorial.tutorial_concluido.connect(func(id: String, pulado: bool) -> void:
			_eventos.append(["tutorial_concluido", id, pulado]))
	_tutorial.nota.connect(func(t: String) -> void: _notas.append(t))


# ------------------------------------------------- 2. beira, sem vara

func _beira_sem_vara() -> bool:
	print("\n2. Beira d'agua perto do Anselmo, sem vara")
	_jogador.equipar(null)
	if not _ok(await _ir_para_a_beira(), "achou beira pisavel de frente para a agua",
			"celula %s, olhando para %s" % [_beira, _direcao_beira]):
		return false
	var agua := _pesca.agua_a_frente()
	_ok(bool(agua["ok"]) and float(agua["distancia_fim"]) - float(agua["distancia_inicio"]) >= 3.0,
			"trecho de agua a frente com folga para o arremesso",
			"%.1f..%.1f celulas" % [float(agua["distancia_inicio"]), float(agua["distancia_fim"])])
	_ok(not _pesca.pode_pescar_aqui(), "sem vara: pode_pescar_aqui() falso")
	_ok(not _pesca.tentar_iniciar(), "sem vara: tentar_iniciar() recusa")
	var ultimo: String = _avisos[_avisos.size() - 1] if _avisos.size() > 0 else ""
	_ok(ultimo == _pesca.cfg.texto("sem_vara"), "sem vara: aviso com o texto 'sem_vara'", ultimo)
	# O mesmo pela TECLA, passando pelo InputMap e pelo _unhandled_input real.
	_avisos.clear()
	await _tecla(KEY_F)
	_ok(_avisos.size() == 1, "tecla F sem vara na beira: um aviso", "%d avisos" % _avisos.size())
	_ok(_texto_do_hud(_m.get("_hud_nota") as Control) == _pesca.cfg.texto("sem_vara"),
			"o aviso chega a nota do HUD")
	_ok(_pesca.estado.e(EstadoPesca.Estado.OCIOSO) and not _jogador.congelado,
			"sem vara: continua OCIOSO e livre")
	# As minhocas da carga inicial tambem tem o marcador "pesca": nem o HUD nem a
	# dica do Anselmo podem toma-las por uma vara.
	_ok(Bolsa.tem_marcador("pesca") and not Bolsa.tem(VARA),
			"(premissa) iscas com marcador 'pesca', vara fora da bolsa")
	_ok(String(_m.call("_dica_de_pesca")) == String(_constante("TEXTO_PESCA_SEM_VARA")),
			"servico 'pesca' sem vara nenhuma: manda falar com o Anselmo")
	_ok(not _texto_do_hud(_m.get("_hud_bolsa") as Control).contains("vara"),
			"HUD da bolsa nao anuncia vara que nao existe")
	return true


## Procura, em volta do Anselmo, uma celula pisavel fora das zonas de encontro
## com agua da ribeira a frente numa das quatro direcoes, e poe o jogador ali.
## A pergunta "ha agua a frente?" e feita a PROPRIA pesca (agua_a_frente), e nao
## recalculada aqui: o teste confere a geometria que o jogo usa.
func _ir_para_a_beira() -> bool:
	var anselmo := Vector2i(60, 20)
	var candidatas: Array[Vector2i] = []
	for dy in range(-RAIO_BEIRA, RAIO_BEIRA + 1):
		for dx in range(-RAIO_BEIRA, RAIO_BEIRA + 1):
			var c := anselmo + Vector2i(dx, dy)
			var t := _mundo_iso.terreno_em(c)
			if _mundo_iso.bloqueia(c) or t == "grama_alta" or t == "ponte":
				continue
			if absi(dx) <= 1 and absi(dy) <= 1:
				continue  # o proprio Anselmo
			candidatas.append(c)
	candidatas.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
			return (a - anselmo).length_squared() < (b - anselmo).length_squared())
	for c: Vector2i in candidatas:
		var pos := _mundo_iso.celula_para_mundo(c)
		if _em_zona_de_encontro(pos):
			continue
		for dir: String in ["direita", "esquerda", "baixo", "cima"]:
			_jogador.position = pos
			_jogador.velocity = Vector2.ZERO
			_jogador.direcao = dir
			var agua := _pesca.agua_a_frente()
			if not bool(agua["ok"]):
				continue
			if float(agua["distancia_fim"]) - float(agua["distancia_inicio"]) < 3.0:
				continue
			if String(_m.call("_regiao_em", agua["fim"])) != "ribeira":
				continue
			# A fisica pode empurrar o corpo para fora de um prop: a celula so
			# serve se o jogador fica onde foi posto.
			await _quadros_fisica(3)
			if _jogador.position.distance_to(pos) > 1.0:
				continue
			_jogador.direcao = dir
			if bool(_pesca.agua_a_frente()["ok"]):
				_beira = c
				_direcao_beira = dir
				return true
	return false


func _em_zona_de_encontro(pos: Vector2) -> bool:
	for no in get_tree().get_nodes_in_group("pontos_de_encontro"):
		var ponto := no as PontoDeEncontro
		if ponto != null and Geometry2D.is_point_in_polygon(pos - ponto.position,
				ponto.poligono()):
			return true
	return false


# ---------------------------------------------------------------- 3. vara

func _com_vara() -> void:
	print("\n3. Vara pela Bolsa e na mao")
	Bolsa.adicionar(VARA, 1)
	_ok(Bolsa.tem(VARA), "Bolsa tem a vara")
	_ok(String(_m.call("_dica_de_pesca")) == String(_constante("TEXTO_PESCA_EQUIPAR")),
			"servico 'pesca' com a vara so na bolsa: manda equipar")
	_ok(_texto_do_hud(_m.get("_hud_bolsa") as Control).contains("vara"),
			"HUD da bolsa mostra a vara")
	_equipados.clear()
	_jogador.equipar(Bolsa.item(VARA))
	_ok(_equipados.size() == 1 and _equipados[0] == VARA, "item_equipado_mudou('%s')" % VARA,
			str(_equipados))
	_ok(_jogador.mao.item != null and _jogador.mao.item.id == VARA, "a vara esta na SlotDaMao")
	_ok(_pesca.tem_vara(), "pesca.tem_vara()")
	await _quadros(2)
	_ok(_pesca.pode_pescar_aqui(), "na beira com a vara: pode_pescar_aqui()")
	var indicador := _jogador.get_node_or_null("IndicadorPesca") as IndicadorInteracao
	_ok(indicador != null and indicador.visible, "indicador '[F] PESCAR' visivel")
	_ok(String(_m.call("_dica_de_pesca")) == String(_constante("TEXTO_PESCA_COM_VARA")),
			"servico 'pesca' do Anselmo: dica com a vara na mao")


# ---------------------------------------------------------- 4. roda de itens

func _roda_de_itens() -> void:
	print("\n4. Roda de itens (Q)")
	await _tecla(KEY_Q, true, false)
	_ok(_roda.aberta(), "Q pressionado abre a roda")
	_ok(_jogador.congelado, "jogador congelado com a roda aberta")
	_ok(_roda.total_de_slots() == Bolsa.com_marcador("equipamento").size() + 1,
			"slots = equipamentos da bolsa + 'Mãos livres'", "%d" % _roda.total_de_slots())
	_ok(String(_m.call("_dono_da_tela")) == "roda", "dono da tela: roda")
	_ok(not _pesca.pode_pescar_aqui(), "roda aberta: a pesca nao comeca")
	_ok(not bool(_dialogos.permissao.call()), "roda aberta: o dialogo nao comeca")
	await _tecla(KEY_Q, false, true)
	_ok(not _roda.aberta() and _jogador.item_equipado == VARA,
			"soltar Q no centro (zona morta) fecha sem trocar")
	_ok(not _jogador.congelado, "jogador descongelado ao fechar")

	await _tecla(KEY_Q, true, false)
	_roda.fechar(false)
	_ok(not _roda.aberta() and _jogador.item_equipado == VARA, "fechar(false) nao troca")
	_ok(not _jogador.congelado, "fechar(false) tambem descongela")
	await _tecla(KEY_Q, false, true)   # o soltar com a roda ja fechada nao faz nada

	await _tecla(KEY_Q, true, false)
	var i_lanterna := _slot_do_item("lanterna")
	_ok(i_lanterna > 0, "a lanterna esta na roda", "slot %d" % i_lanterna)
	_roda.apontar(GeometriaRoda.posicao_do_slot(i_lanterna, _roda.total_de_slots(), _roda.raio))
	_ok(_roda.indice_destacado() == i_lanterna, "apontar destaca o slot da lanterna")
	_equipados.clear()
	await _tecla(KEY_Q, false, true)
	_ok(_jogador.item_equipado == "lanterna" and _equipados.has("lanterna"),
			"soltar Q com a lanterna destacada troca o item", str(_equipados))
	_ok(not _pesca.tem_vara() and not _pesca.pode_pescar_aqui(), "lanterna na mao: nao pesca")

	_roda.abrir(Bolsa.com_marcador("equipamento"), _jogador.item_equipado)
	var i_vara := _slot_do_item(VARA)
	_roda.apontar(GeometriaRoda.posicao_do_slot(i_vara, _roda.total_de_slots(), _roda.raio))
	_roda.fechar(true)
	_ok(_jogador.item_equipado == VARA, "fechar(true) com indice valido troca (de volta a vara)")
	_jogador.congelar(false)


func _slot_do_item(id: String) -> int:
	for i in _roda.total_de_slots():
		var it := _roda.item_do_slot(i)
		if it != null and it.id == id:
			return i
	return -1


# ---------------------------------------------- 5. lance com politica perfeita

func _lance_perfeito() -> void:
	print("\n5. Lance em modo tutorial, politica perfeita")
	_pesca.modo_tutorial = true
	_usar_politica_perfeita()
	_eventos.clear()
	_ok(_pesca.tentar_iniciar(), "tentar_iniciar() na beira com a vara")
	_ok(_pesca.estado.e(EstadoPesca.Estado.ARREMESSO), "estado ARREMESSO")
	_ok(_jogador.congelado, "jogador congelado no arremesso")
	_ok(_jogador.mao.pescando, "vara em pose de pesca")
	_ok(_contar("pesca_iniciada") == 1, "pesca_iniciada emitido")
	_ok(bool(_dialogos.get("_suspenso")), "dialogo suspenso durante a pesca")
	_ok(String(_m.call("_dono_da_tela")) == "pesca" and not bool(_m.call("_pode_pausar")),
			"dono da tela: pesca (a pausa nao abre)")

	_pesca.confirmar_arremesso(0.9)
	_ok(await _esperar(func() -> bool: return _pesca.estado.e(EstadoPesca.Estado.RECOLHENDO)),
			"a isca pousa: RECOLHENDO")
	_ok(_pesca.interface.minigame.mouse_filter == Control.MOUSE_FILTER_STOP,
			"no recolhimento o minigame segura o mouse (o clique nao vaza para o mundo)")
	var lance: Array = _primeiro("arremessado")
	_ok(lance.size() == 4 and is_equal_approx(float(lance[1]), 0.9) and String(lance[2]) == "maximo"
			and float(lance[3]) > 0.0, "arremessado(0.9, maximo, distancia)", str(lance))
	_ok(_pesca.ponto_atual() != null and _pesca.ponto_atual().id == "ribeira",
			"ponto de pesca pela regiao do pouso: ribeira",
			_pesca.ponto_atual().id if _pesca.ponto_atual() != null else "null")
	await _quadros(1)
	_ok(not (_m.get("_hud_dica") as Control).visible and not (_m.get("_hud_nota") as Control).visible,
			"HUD escondido no minigame")
	var anselmo := _dialogos.npc_por_id("anselmo")
	_ok(anselmo != null and not _dialogos.conversar_com(anselmo),
			"conversa com o Anselmo recusada durante a pesca")

	_ok(await _esperar(func() -> bool: return _contar("peixe_fisgado") > 0),
			"politica perfeita no tutorial: peixe_fisgado")
	var fisgado: Array = _primeiro("peixe_fisgado")
	var c: Criatura = fisgado[1] if fisgado.size() > 1 else null
	_ok(c != null and _encontros().bestiario.has(c), "a criatura fisgada e do bestiario da seed",
			c.nome() if c != null else "null")
	_ok(c != null and PerfilPesca.elegivel(c, _pesca.tabelas.perfil),
			"a criatura fisgada e elegivel a pesca (agua, peixe ou anfibio)",
			"%s/%s" % [c.elemento, c.animal_base] if c != null else "")
	var sombra: Array = _primeiro("silhueta_surgiu")
	_ok(sombra.size() > 1 and sombra[1] == c, "a silhueta que surgiu e a fisgada")
	_ok(_pesca.estado.e(EstadoPesca.Estado.FISGADO), "estado FISGADO")
	_ok(_texto_do_hud(_m.get("_hud_nota") as Control) == String(_constante("TEXTO_FISGOU")) % c.nome(),
			"_ao_fisgar: nota 'Fisgou ...' (ponto de integracao)")

	_ok(await _esperar(func() -> bool: return _contar("pesca_encerrada") > 0),
			"encerra sozinha depois do letreiro")
	_ok(_pesca.estado.e(EstadoPesca.Estado.OCIOSO), "volta a OCIOSO")
	_ok(not _jogador.congelado and not _jogador.mao.pescando, "jogador livre, vara abaixada")
	_ok(_contar("pesca_falhou") == 0, "nenhum pesca_falhou depois da fisgada")
	_ok(not bool(_dialogos.get("_suspenso")), "dialogo de volta")
	await _quadros(1)
	_ok((_m.get("_hud_dica") as Control).visible, "HUD de volta")
	_pesca.modo_tutorial = false


func _usar_politica_perfeita() -> void:
	_pesca.interface.minigame.fonte_de_entrada = func() -> Vector2:
		var s := _pesca.simulacao()
		if s == null or s.perfil == null:
			return Vector2(1.0, 0.5)   # devagar, meia-agua, ate a sombra surgir
		return Vector2(1.0 - s.velocidade_monstro, s.profundidade_monstro)


# --------------------------------------------------- 6. ESC no recolhimento

func _cancelar_com_esc() -> void:
	print("\n6. Cancelar: ESC no recolhimento, cancelar() no arco")
	_eventos.clear()
	_ok(_pesca.tentar_iniciar(), "novo lance")
	_pesca.confirmar_arremesso(0.5)
	_ok(await _esperar(func() -> bool: return _pesca.estado.e(EstadoPesca.Estado.RECOLHENDO)),
			"RECOLHENDO")
	await _tecla(KEY_ESCAPE)
	_ok(await _esperar(func() -> bool: return _contar("pesca_falhou") > 0, 5.0),
			"ESC: pesca_falhou emitido")
	var falhou: Array = _primeiro("pesca_falhou")
	_ok(falhou.size() > 1 and String(falhou[1]) == "cancelada", "motivo 'cancelada'", str(falhou))
	_ok(_pesca.estado.e(EstadoPesca.Estado.OCIOSO) and not _jogador.congelado,
			"OCIOSO e jogador livre na hora")
	var pausa := _m.get("pausa") as MenuPausa
	_ok(pausa != null and not pausa.aberto() and not get_tree().paused,
			"o mesmo ESC NAO abriu a pausa (a pesca o consumiu)")
	_ok(_pesca.interface.minigame.mouse_filter == Control.MOUSE_FILTER_IGNORE,
			"pesca encerrada: o minigame no fade de saida nao segura o mouse")
	await _clique_no_fade()

	_eventos.clear()
	_ok(_pesca.tentar_iniciar(), "lance de novo")
	_pesca.cancelar()
	_ok(_primeiro("pesca_falhou").size() > 1 and String(_primeiro("pesca_falhou")[1]) == "cancelada"
			and _pesca.estado.e(EstadoPesca.Estado.OCIOSO), "cancelar() no arco: cancelada -> OCIOSO")
	await _quadros(2)


## O clique logo depois de encerrar, com o corte da agua ainda esmaecendo
## (cfg.duracao_transicao), tem de chegar ao _unhandled_input da pesca: e o
## `usar_item` do lance seguinte. O relogio volta a 1x so neste trecho para o
## fade durar o bastante e o clique cair DENTRO dele.
func _clique_no_fade() -> void:
	_ok(_pesca.tentar_iniciar(), "lance para encerrar no recolhimento")
	_pesca.confirmar_arremesso(0.5)
	_ok(await _esperar(func() -> bool: return _pesca.estado.e(EstadoPesca.Estado.RECOLHENDO)),
			"RECOLHENDO de novo")
	await _quadros(2)
	var minigame := _pesca.interface.minigame
	Engine.time_scale = 1.0
	_eventos.clear()
	_pesca.cancelar()
	_clique(true)
	await get_tree().process_frame
	# O clique ja foi despachado; o fade so termina no fim deste quadro, no minimo.
	var no_fade: bool = minigame.visible
	_clique(false)
	await _quadros(2)
	Engine.time_scale = ACELERACAO
	_ok(_contar("pesca_iniciada") == 1 and _pesca.estado.e(EstadoPesca.Estado.ARREMESSO),
			"clique durante o fade de saida ja inicia o lance seguinte",
			"minigame ainda visivel no clique: %s" % no_fade)
	_pesca.cancelar()
	_ok(_pesca.estado.e(EstadoPesca.Estado.OCIOSO), "cancelado de volta a OCIOSO")
	await _quadros(2)


# --------------------------------------------------- 7. licao completa

func _licao_completa() -> void:
	print("\n7. Licao do Anselmo, de ponta a ponta")
	_estado.bandeiras.erase(BANDEIRA)
	# Tirar a vara da bolsa por fora (ela e permanente: Bolsa.remover recusa).
	Bolsa.inventario.consumir(VARA, Bolsa.quantidade(VARA))
	_ok(not Bolsa.tem(VARA) and _jogador.item_equipado == "",
			"vara saiu da bolsa -> a mao esvazia sozinha")
	var minhocas_antes: int = Bolsa.quantidade("minhoca")
	_eventos.clear()
	_notas.clear()
	_usar_politica_perfeita()

	var anselmo := _dialogos.npc_por_id("anselmo")
	_ok(_dialogos.conversar_com(anselmo), "conversar com o Anselmo sem a bandeira")
	_ok(_contar("tutorial_iniciado") == 1 and _tutorial.ativo(),
			"a fala 'licao' pede o servico e o tutorial comeca")
	_ok(_pesca.modo_tutorial, "pesca em modo tutorial")

	_dialogos.encerrar_conversa()   # fecha a "licao"; a "apresentacao" abre depois
	_ok(await _passar_conversa("apresentacao"), "conversa da apresentacao")
	_ok(await _esperar(func() -> bool: return _tutorial.passo_atual() == "equipar"),
			"passo 'equipar'")
	_ok(Bolsa.tem(VARA), "a apresentacao entrega a vara")
	_ok(_notas.has("Recebeu: Vara de Pesca ×1"), "nota 'Recebeu: Vara de Pesca ×1'", str(_notas))
	_ok(_jogador.item_equipado == "", "o passo desequipa (a licao ensina a roda)")
	_ok(await _passar_conversa("equipar"), "conversa da roda")
	_ok(await _esperar(func() -> bool: return _tutorial.dica.dica_visivel()), "dica no topo")
	await _quadros(1)
	_ok(not (_m.get("_hud_dica") as Control).visible,
			"as linhas de cima do HUD cedem a dica do tutorial")

	await _tecla(KEY_Q, true, false)
	_roda.apontar(GeometriaRoda.posicao_do_slot(_slot_do_item(VARA), _roda.total_de_slots(),
			_roda.raio))
	await _tecla(KEY_Q, false, true)
	_ok(_jogador.item_equipado == VARA, "vara equipada pela roda")
	_ok(await _esperar(func() -> bool: return _tutorial.passo_atual() == "arremesso"),
			"item_equipado leva ao passo 'arremesso'")
	_ok(await _passar_conversa("arremesso"), "conversa do arremesso")

	_ok(_pesca.tentar_iniciar(), "na beira: arremesso da licao")
	_ok(_pesca.interface.medidor.mostrar_legenda, "arco com a legenda FRACO/MÉDIO/MÁXIMO")
	_pesca.confirmar_arremesso(0.5)
	_ok(await _esperar(func() -> bool: return _tutorial.passo_atual() == "recolher"),
			"arremessado leva ao passo 'recolher'")
	_ok(await _esperar(func() -> bool: return _tutorial.passo_atual() == "silhueta"),
			"a silhueta de ensino surge: passo 'silhueta'")
	_ok(await _esperar(func() -> bool: return _contar("peixe_fisgado") > 0),
			"fisgada garantida no tutorial")
	_ok(await _esperar(func() -> bool: return _tutorial.passo_atual() == "despedida"),
			"passo 'despedida'")
	_ok(not _dialogos.em_conversa(), "a despedida espera: nada abre por cima do resultado")
	_ok(await _esperar(func() -> bool: return _dialogos.em_conversa()),
			"a despedida abre depois que a pesca encerra")
	_ok(_pesca.estado.e(EstadoPesca.Estado.OCIOSO), "...com a pesca ja em OCIOSO")
	_dialogos.encerrar_conversa()
	_ok(await _esperar(func() -> bool: return _contar("tutorial_concluido") > 0),
			"tutorial_concluido")
	var fim: Array = _primeiro("tutorial_concluido")
	_ok(fim.size() > 2 and String(fim[1]) == "pesca" and fim[2] == false, "concluido sem pular",
			str(fim))
	_ok(_estado.ativa(BANDEIRA), "bandeira '%s' posta" % BANDEIRA)
	_ok(Bolsa.quantidade("minhoca") == minhocas_antes + 5, "recompensa: 5 minhocas",
			"%d -> %d" % [minhocas_antes, Bolsa.quantidade("minhoca")])
	_ok(not _pesca.modo_tutorial and not _tutorial.ativo(), "modo tutorial desligado")


## A conversa pedida pelo passo `passo` abre (o tutorial a abre sozinho, no
## quadro seguinte) e e fechada como o ESC fecharia — o que faz o passo seguir.
func _passar_conversa(passo: String) -> bool:
	if not await _esperar(func() -> bool: return _dialogos.em_conversa()):
		print("      (a conversa do passo '%s' nao abriu)" % passo)
		return false
	if _tutorial.passo_atual() != passo:
		print("      (conversa aberta no passo '%s', esperado '%s')"
				% [_tutorial.passo_atual(), passo])
		return false
	_dialogos.encerrar_conversa()
	await _quadros(1)
	return true


# --------------------------------------------------------- 8. pular

func _pular_licao() -> void:
	print("\n8. Pular a licao")
	_estado.bandeiras.erase(BANDEIRA)
	Bolsa.inventario.consumir(VARA, Bolsa.quantidade(VARA))
	_eventos.clear()
	_notas.clear()
	var anselmo := _dialogos.npc_por_id("anselmo")
	_ok(_dialogos.conversar_com(anselmo) and _contar("tutorial_iniciado") == 1,
			"sem a bandeira, falar com o Anselmo comeca a licao (tutorial_iniciado)")
	_tutorial.pular()
	_ok(Bolsa.tem(VARA), "pular entrega a vara")
	_ok(_notas.has("Recebeu: Vara de Pesca ×1"), "nota da vara ao pular", str(_notas))
	_ok(_estado.ativa(BANDEIRA), "pular define '%s'" % BANDEIRA)
	var fim: Array = _primeiro("tutorial_concluido")
	_ok(fim.size() > 2 and fim[2] == true, "tutorial_concluido(pesca, pulado=true)", str(fim))
	_ok(not _pesca.modo_tutorial and not _tutorial.ativo(), "modo tutorial desligado")
	_dialogos.encerrar_conversa()   # a "licao" que pediu o tutorial
	_ok(await _esperar(func() -> bool: return _dialogos.em_conversa()), "a conversa 'pulou' abre")
	_dialogos.encerrar_conversa()
	await _quadros(2)
	_ok(_dialogos.conversar_com(anselmo) and not _tutorial.ativo(),
			"com a bandeira, o Anselmo abre na conversa normal (sem licao)")
	_dialogos.encerrar_conversa()
	await _quadros(2)


# ----------------------------------------------------------- 9. save

func _save() -> void:
	print("\n9. Save: bandeira e item na mao")
	var copia := EstadoMundo.new()
	copia.de_dicionario(_estado.para_dicionario())
	_ok(copia.ativa(BANDEIRA), "a bandeira sobrevive a para_dicionario/de_dicionario")

	_jogador.equipar(Bolsa.item(VARA))
	var d := DadosPartida.nova(int(_m.get("seed_do_mundo")))
	_m.call("_colher_jogador", d)
	_m.call("_colher_estado", d)
	_ok(d.item_equipado == VARA, "_colher_jogador grava o item na mao")
	# Ida e volta pelo TEXTO do save, como o arquivo em disco faria.
	var lido := DadosPartida.de_dicionario(JSON.parse_string(JSON.stringify(d.para_dicionario())))
	_ok(lido.valido() and lido.item_equipado == VARA, "item_equipado volta do JSON", lido.erro)
	var estado_lido := EstadoMundo.new()
	estado_lido.de_dicionario(lido.estado_mundo)
	_ok(estado_lido.ativa(BANDEIRA), "a bandeira volta do JSON do save")

	_jogador.equipar(null)
	_m.call("_repor_jogador", lido)
	_ok(_jogador.item_equipado == VARA, "_repor_jogador reequipa a vara (a bolsa a tem)")
	var sem_posicao := DadosPartida.nova(int(_m.get("seed_do_mundo")))
	sem_posicao.item_equipado = "lanterna"
	_m.call("_repor_jogador", sem_posicao)
	_ok(_jogador.item_equipado == "lanterna",
			"save sem posicao tambem reequipa (antes do retorno cedo)")
	var orfao := DadosPartida.nova(int(_m.get("seed_do_mundo")))
	orfao.item_equipado = "item_que_nao_existe"
	_m.call("_repor_jogador", orfao)
	_ok(_jogador.item_equipado == "", "item que a bolsa nao tem volta como mao vazia")


# ----------------------------------------------------------- apoio

func _encontros() -> GerenciadorEncontro:
	return _m.get("encontros") as GerenciadorEncontro


func _constante(nome: String) -> Variant:
	return (_m.get_script() as GDScript).get_script_constant_map().get(nome, "")


func _texto_do_hud(raiz: Control) -> String:
	var frente := raiz.get_node_or_null("Frente") as Label if raiz != null else null
	return frente.text if frente != null else ""


func _glifos_faltando(texto: String) -> String:
	var fonte := TemaEncontro.fonte()
	var faltando := ""
	for i in texto.length():
		var ch := texto.unicode_at(i)
		if ch != 10 and not fonte.has_char(ch) and not faltando.contains(texto[i]):
			faltando += texto[i]
	return faltando


func _contar(nome: String) -> int:
	var n: int = 0
	for e: Array in _eventos:
		if String(e[0]) == nome:
			n += 1
	return n


func _primeiro(nome: String) -> Array:
	for e: Array in _eventos:
		if String(e[0]) == nome:
			return e
	return []


## Botao esquerdo do mouse (= usar_item) no centro da tela, pelo Input de
## verdade: passa pela GUI — que pode engoli-lo — antes do _unhandled_input.
## A posicao do evento e em coordenadas da JANELA (a headless tem 64x64 e o
## stretch a leva ao viewport): o centro do viewport cairia fora dela e nenhum
## Control seria atingido.
func _clique(pressionado: bool) -> void:
	var centro := Vector2(get_window().size) * 0.5
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.button_mask = MOUSE_BUTTON_MASK_LEFT if pressionado else 0
	ev.pressed = pressionado
	ev.position = centro
	ev.global_position = centro
	Input.parse_input_event(ev)


## Aperta (e solta) uma tecla de verdade: o evento entra pelo Input e passa pelo
## InputMap e pela propagacao normal (_input, _unhandled_input).
func _tecla(tecla: Key, apertar: bool = true, soltar: bool = true) -> void:
	for pressionada: bool in [true, false]:
		if (pressionada and not apertar) or (not pressionada and not soltar):
			continue
		var ev := InputEventKey.new()
		ev.keycode = tecla
		ev.physical_keycode = tecla
		ev.pressed = pressionada
		Input.parse_input_event(ev)
		await _quadros(2)
