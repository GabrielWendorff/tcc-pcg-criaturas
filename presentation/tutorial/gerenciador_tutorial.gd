class_name GerenciadorTutorial
extends Node

## Executa um tutorial em dado (SequenciaTutorial) sobre os sistemas que ja
## existem: fala pelo GerenciadorDialogo, mostra dica pela DicaTutorial, espera
## eventos que a cena lhe repassa e aplica os efeitos dos passos.
##
## NAO CONHECE A PESCA. Os eventos chegam por notificar("arremessado"), e quem
## liga GerenciadorPesca.arremessado a esta chamada e a cena
## (presentation/exploracao/mundo.gd). Mesma politica de GerenciadorDialogo e
## GerenciadorEncontro: um no que conhece as partes, as partes nao se conhecem.
## Um segundo tutorial (captura, batalha) e outro JSON em autoral/tutoriais/ e
## outra meia duzia de connect() na cena — nenhuma linha aqui.
##
## UM PASSO, DE PONTA A PONTA:
##   1. entra: passo_iniciado, efeitos `ao_iniciar`;
##   2. conversa (se houver): pedida ao GerenciadorDialogo com a arvore do
##      tutorial, aberta assim que for possivel, e o passo segue quando ela fecha;
##   3. espera (se houver): mostra a `dica` e aguarda o evento; "falhou" com
##      `se_falhar` volta ao passo indicado, com a conversa "tentar_de_novo";
##   4. sai: efeitos `ao_concluir`, proximo passo.
##
## CONVERSA PENDENTE, e nao conversa imediata. Uma conversa so abre quando nada
## mais tem o controle: o tutorial comeca DENTRO da fala do Anselmo que o pediu
## (o servico e drenado ao entrar no no "licao"), a despedida e pedida no quadro
## em que o peixe e fisgado, com a pesca ainda na tela. Em vez de cada caso saber
## esperar o seu, o pedido fica guardado e _process tenta abri-lo a cada quadro
## ate conversar_com() aceitar — permissao falsa hoje, aberta no quadro seguinte.
## Abrir no quadro seguinte tambem evita abrir uma conversa DE DENTRO do sinal
## conversa_terminada da anterior, com a caixa ainda no meio do fechamento.
##
## PULAR: "pular_tutorial" (P) abre "Tem certeza?" e PAUSA A ARVORE, como o menu
## de pausa: com ela correndo, a linha continuaria sendo recolhida atras da
## pergunta. A DicaTutorial roda com PROCESS_MODE_ALWAYS e responde sozinha;
## este no herda a pausa, e por isso P nao faz nada com o jogo ja pausado.

signal tutorial_iniciado(id: String)
signal tutorial_concluido(id: String, pulado: bool)
signal passo_iniciado(id_passo: String)
## A cena desequipa o jogador (Jogador.equipar(null)). O tutorial nao conhece o
## jogador: so declara o que o passo pede.
signal desequipar_pedido()
## Recado curto para o HUD ("Recebeu: Vara de Pesca ×1").
signal nota(texto: String)

const ACAO_PULAR := "pular_tutorial"

enum Fase { PARADO, CONVERSANDO, ESPERANDO }

var dica: DicaTutorial
var erro: String = ""

## Pergunta feita antes de abrir o "Tem certeza?". A cena liga aqui o que mais
## tiver a tela (roda de itens aberta, mapa). Padrao: sempre pode.
var permissao_pulo: Callable = func() -> bool: return true

var _dialogos: GerenciadorDialogo
var _estado: EstadoMundo
var _seq: SequenciaTutorial
var _npc: Npc
var _ativo: bool = false
var _fase: Fase = Fase.PARADO

## Conversa esperando para abrir: {"arvore", "no", "depois": Callable}. Vazio =
## nenhuma. Independe de _ativo: a conversa "pulou" abre DEPOIS de o tutorial ja
## ter sido concluido.
var _pendente: Dictionary = {}
## A conversa aberta agora e uma que ESTE gerenciador pediu? Sem isto, o fim da
## conversa de outro NPC faria o passo andar.
var _conversa_propria: bool = false
var _depois_da_conversa: Callable = Callable()

## Token por passo — mesma ideia de GerenciadorEncontro._geracao. Uma conversa
## pedida por um passo que ja ficou para tras (pulo, falha) termina sem mexer no
## passo novo.
var _geracao: int = 0
var _pausou_arvore: bool = false
var _cache: Dictionary = {}


## Liga o gerenciador. Devolve false com `erro` preenchido quando falta uma das
## partes — mesma politica de GerenciadorDialogo.preparar().
func preparar(dialogos: GerenciadorDialogo, estado: EstadoMundo) -> bool:
	if dialogos == null or estado == null:
		erro = "tutorial precisa do GerenciadorDialogo e do EstadoMundo"
		return false
	_dialogos = dialogos
	_estado = estado
	if not _dialogos.conversa_terminada.is_connected(_ao_terminar_conversa):
		_dialogos.conversa_terminada.connect(_ao_terminar_conversa)
	if dica == null:
		dica = DicaTutorial.new()
		dica.name = "DicaTutorial"
		add_child(dica)
		dica.resposta_pulo.connect(_ao_responder_pulo)
	return true


# ---------------------------------------------------------------- consultas
func ativo() -> bool:
	return _ativo


func perguntando() -> bool:
	return dica != null and dica.perguntando()


## O tutorial ja foi concluido (ou pulado) nesta partida? Le a bandeira que o
## proprio JSON declara — e e por ela que o save o lembra, sem secao propria.
func concluido(id_tutorial: String) -> bool:
	if _estado == null:
		return false
	var seq := _sequencia(id_tutorial)
	return seq != null and _estado.ativa(seq.bandeira_concluido)


## Id do passo corrente ("" fora do tutorial). Para teste e depuracao.
func passo_atual() -> String:
	return _seq.id_do_passo() if _ativo and _seq != null else ""


# ------------------------------------------------------------------ inicio
## Comeca o tutorial. `npc` e quem fala; null usa o `npc` declarado no JSON.
##
## Com uma conversa aberta (o caso normal: o pedido vem da fala do proprio
## Anselmo), a primeira conversa do tutorial fica pendente e abre quando aquela
## fechar.
##
## Pedido repetido com o MESMO tutorial ja em curso (o jogador volta a falar com
## o Anselmo no meio da licao) nao recomeca nada: reabre a conversa do passo
## corrente, que e o lembrete do que fazer agora, e devolve true. Outro tutorial
## em curso, sequencia ausente ou invalida: false.
func iniciar(id_tutorial: String, npc: Npc = null) -> bool:
	if _dialogos == null:
		push_error("GerenciadorTutorial: iniciar() antes de preparar()")
		return false
	if _ativo:
		if _seq != null and _seq.id == id_tutorial:
			_lembrar_passo()
			return true
		return false
	var seq := _sequencia(id_tutorial)
	if seq == null:
		return false
	var arvore := _dialogos.dialogos.arvore(seq.arvore)
	var problemas := seq.validar(arvore)
	if arvore == null:
		problemas.append("arvore '%s' nao carregou" % seq.arvore)
	if not problemas.is_empty():
		# Dado quebrado nao comeca: um passo esperando evento que nao existe
		# prenderia o jogador numa dica eterna. O teste pega isto antes.
		push_error("GerenciadorTutorial: '%s' invalido —\n  %s"
				% [id_tutorial, "\n  ".join(problemas)])
		return false

	_seq = seq
	_npc = npc if npc != null else _dialogos.npc_por_id(seq.npc)
	if _npc == null:
		push_warning("GerenciadorTutorial: NPC '%s' nao esta na cena — a licao segue sem falas"
				% seq.npc)
	_ativo = true
	_fase = Fase.PARADO
	_seq.iniciar()
	dica.mostrar_aviso_pulo(_seq.texto("aviso_pular"), true)
	tutorial_iniciado.emit(_seq.id)
	_comecar_passo(false)
	return true


# ---------------------------------------------------------------- eventos
## Evento do jogo ("item_equipado", "arremessado", "fisgado", "falhou"...). So
## conta enquanto o passo ESPERA: durante a conversa do passo, nada que o jogador
## faca pode pula-la — e ele esta congelado de qualquer forma.
func notificar(evento: String, valor: String = "") -> void:
	if not _ativo or _fase != Fase.ESPERANDO or _seq == null:
		return
	var reacao := _seq.reacao(evento, valor)
	if reacao == SequenciaTutorial.REACAO_CONCLUIR:
		_concluir_passo()
	elif reacao == SequenciaTutorial.REACAO_VOLTAR:
		_voltar_para(_seq.destino_de_falha())


# ------------------------------------------------------------------- pulo
## Abre a confirmacao. A pergunta vem ANTES da pausa: se ela nao abrir (no fora
## da arvore), nada fica pausado sem ninguem para despausar.
func pedir_pulo() -> void:
	if not _ativo or perguntando() or dica == null:
		return
	if permissao_pulo.is_valid() and not permissao_pulo.call():
		return
	dica.perguntar_pulo(_seq.texto("pular_pergunta"), _seq.texto("pular_sim"),
			_seq.texto("pular_nao"))
	if not dica.perguntando():
		return
	_pausou_arvore = not get_tree().paused
	get_tree().paused = true


## Pula o tutorial: efeitos de `ao_pular` (que entregam a vara e marcam a
## bandeira — quem pula nao pode sair sem poder pescar), conclui e deixa a
## conversa "pulou" pendente. Os efeitos vem ANTES da conversa: se o jogo for
## salvo enquanto ela espera a pesca acabar, a licao ja consta como feita.
func pular() -> void:
	if not _ativo or _seq == null:
		return
	if perguntando():
		dica.fechar_pergunta()
		_despausar()
	_geracao += 1
	_pendente = {}
	_depois_da_conversa = Callable()
	if _conversa_propria:
		# Antes de encerrar: o encerramento emite conversa_terminada, e o passo
		# que a pediu ja nao existe.
		_conversa_propria = false
		_dialogos.encerrar_conversa()
	_aplicar_efeitos(_seq.ao_pular.get("efeitos", {}))
	var conversa := String(_seq.ao_pular.get("conversa", ""))
	var arvore := _seq.arvore
	_finalizar(true)
	if conversa != "":
		_pedir_conversa(arvore, conversa, Callable())


func _ao_responder_pulo(confirmou: bool) -> void:
	_despausar()
	if confirmou:
		pular()


func _despausar() -> void:
	if _pausou_arvore and is_inside_tree():
		get_tree().paused = false
	_pausou_arvore = false


## A pausa e da ARVORE, nao da cena: sair de cena com ela ligada congelaria a
## proxima (mesmo cuidado de mundo._sair_para_o_menu).
func _exit_tree() -> void:
	if dica != null and dica.perguntando():
		dica.fechar_pergunta()
	_despausar()


func _input(evento: InputEvent) -> void:
	if not _ativo or perguntando() or not InputMap.has_action(ACAO_PULAR):
		return
	if evento.is_action_pressed(ACAO_PULAR) and not evento.is_echo():
		pedir_pulo()
		get_viewport().set_input_as_handled()


# ------------------------------------------------------------------ passos
## Entra no passo corrente. `retomada` = voltou por falha: a conversa do passo
## da lugar a "tentar_de_novo", quando a arvore a tem.
func _comecar_passo(retomada: bool) -> void:
	_geracao += 1
	var token := _geracao
	var passo := _seq.passo_atual()
	passo_iniciado.emit(_seq.id_do_passo())
	_aplicar_efeitos(passo.get("ao_iniciar", {}))
	if token != _geracao or not _ativo:
		return  # um efeito ou um ouvinte do sinal mudou o rumo (pulo por codigo)

	var conversa := String(passo.get("conversa", ""))
	if retomada and _arvore_tem(SequenciaTutorial.CONVERSA_TENTAR_DE_NOVO):
		conversa = SequenciaTutorial.CONVERSA_TENTAR_DE_NOVO
	if conversa == "":
		_apos_conversa(token)
		return
	_fase = Fase.CONVERSANDO
	# A dica do passo anterior sai antes da conversa: duas instrucoes ao mesmo
	# tempo, uma na caixa e outra no topo, e o jogador le a errada.
	dica.esconder_dica()
	_pedir_conversa(_seq.arvore, conversa, _apos_conversa.bind(token))


func _apos_conversa(token: int) -> void:
	if token != _geracao or not _ativo:
		return
	var passo := _seq.passo_atual()
	if passo.get("esperar") == null:
		_concluir_passo()
		return
	_fase = Fase.ESPERANDO
	var texto_dica := String(passo.get("dica", ""))
	if texto_dica != "":
		dica.mostrar_dica(_seq.texto("titulo_dica"), texto_dica)
	else:
		dica.esconder_dica()


func _concluir_passo() -> void:
	var token := _geracao
	_aplicar_efeitos(_seq.passo_atual().get("ao_concluir", {}))
	if token != _geracao or not _ativo:
		return
	_seq.avancar()
	if _seq.concluida():
		_finalizar(false)
	else:
		_comecar_passo(false)


func _voltar_para(id_passo: String) -> void:
	if not _seq.ir_para(id_passo):
		push_error("GerenciadorTutorial: passo '%s' nao existe em '%s'" % [id_passo, _seq.id])
		return
	_comecar_passo(true)


## O jogador voltou a falar com o NPC no meio da licao. Repete a conversa do
## passo e devolve a dica; sem conversa (passo de pesca), so a dica. Durante uma
## conversa do proprio tutorial, nao ha o que lembrar.
func _lembrar_passo() -> void:
	if _fase != Fase.ESPERANDO:
		return
	var conversa := String(_seq.passo_atual().get("conversa", ""))
	if conversa == "":
		_apos_conversa(_geracao)
		return
	_fase = Fase.CONVERSANDO
	dica.esconder_dica()
	_pedir_conversa(_seq.arvore, conversa, _apos_conversa.bind(_geracao))


func _finalizar(pulado: bool) -> void:
	_geracao += 1
	# A bandeira e marcada aqui tambem, e nao so pelo efeito "concluir": um JSON
	# que esqueca o efeito faria a licao recomecar em toda conversa com o Anselmo.
	if _seq.bandeira_concluido != "" and not _estado.ativa(_seq.bandeira_concluido):
		_estado.definir(_seq.bandeira_concluido, true)
	_ativo = false
	_fase = Fase.PARADO
	dica.esconder_dica()
	dica.mostrar_aviso_pulo("", false)
	tutorial_concluido.emit(_seq.id, pulado)


# ----------------------------------------------------------------- efeitos
## Efeitos declarados no passo. Itens pela Bolsa (autoload): e o estoque unico
## que a roda, a pesca e o save ja leem. A nota so sai quando algo ENTROU — a
## vara nao empilha, e quem repete a licao nao "recebe" uma segunda.
func _aplicar_efeitos(efeitos: Variant) -> void:
	if not efeitos is Dictionary:
		return
	var d: Dictionary = efeitos
	var itens: Variant = d.get("dar_itens", {})
	if itens is Dictionary:
		for id_item: String in (itens as Dictionary).keys():
			var entrou: int = Bolsa.adicionar(id_item, int(itens[id_item]))
			if entrou > 0:
				var item: ItemJogo = Bolsa.item(id_item)
				var nome: String = item.nome if item != null else id_item
				nota.emit(_seq.texto_recebeu(nome, entrou))
	var definir: Variant = d.get("definir", {})
	if definir is Dictionary:
		for bandeira: String in (definir as Dictionary).keys():
			_estado.definir(bandeira, definir[bandeira])
	if bool(d.get("desequipar", false)):
		desequipar_pedido.emit()
	if bool(d.get("concluir", false)) and _seq.bandeira_concluido != "":
		_estado.definir(_seq.bandeira_concluido, true)


# --------------------------------------------------------------- conversas
func _pedir_conversa(arvore: String, no: String, depois: Callable) -> void:
	_pendente = {"arvore": arvore, "no": no, "depois": depois}


func _process(_delta: float) -> void:
	if not _pendente.is_empty():
		_tentar_abrir()


func _tentar_abrir() -> void:
	if _dialogos == null or _dialogos.em_conversa():
		return
	var pedido := _pendente
	var depois: Callable = pedido.get("depois", Callable())
	if _npc == null:
		# Sem quem fale (cena de teste sem o NPC): a licao nao pode travar
		# esperando uma boca. Segue como se a conversa tivesse acontecido.
		_pendente = {}
		if depois.is_valid():
			depois.call()
		return
	if not _dialogos.conversar_com(_npc, String(pedido["arvore"]), String(pedido["no"])):
		return  # outra coisa tem o controle; o proximo quadro tenta de novo
	_pendente = {}
	_conversa_propria = true
	_depois_da_conversa = depois


func _ao_terminar_conversa(_npc_que_falou: Npc) -> void:
	if not _conversa_propria:
		return
	_conversa_propria = false
	var depois := _depois_da_conversa
	_depois_da_conversa = Callable()
	if depois.is_valid():
		depois.call()


func _arvore_tem(no: String) -> bool:
	var arvore := _dialogos.dialogos.arvore(_seq.arvore)
	return arvore != null and arvore.nos.has(no)


## Sequencias carregadas, por id. Guarda ate o null: nao insiste num arquivo
## ausente a cada conversa com o Anselmo (mesma politica de CatalogoDialogos).
## Reaproveitar o objeto entre execucoes e seguro: o unico estado dele e o
## cursor, e SequenciaTutorial.iniciar() o devolve ao passo zero.
func _sequencia(id_tutorial: String) -> SequenciaTutorial:
	if not _cache.has(id_tutorial):
		_cache[id_tutorial] = SequenciaTutorial.carregar(id_tutorial)
	return _cache[id_tutorial]
