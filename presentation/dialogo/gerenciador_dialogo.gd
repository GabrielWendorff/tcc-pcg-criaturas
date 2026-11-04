class_name GerenciadorDialogo
extends Node

## Orquestra NPCs e conversa: instancia os personagens no mundo, detecta quem
## esta ao alcance, abre a caixa, conduz a sessao e devolve o controle.
##
## E o UNICO no que conhece todas as partes — mesma politica de
## GerenciadorEncontro. A caixa nao sabe o que e um no de dialogo, a sessao nao
## sabe o que e um Control, o NPC nao sabe o que e uma arvore. Isso e o que
## permite testar a conversa inteira sem abrir cena (tools/test_dialogo.gd).
##
## DETECCAO POR DISTANCIA, nao por Area2D. PontoDeEncontro usa area porque a
## pergunta la e "o jogador esta DENTRO do mato?" — uma regiao larga, de forma
## autoral. Aqui a pergunta e "qual NPC esta MAIS PERTO e dentro do alcance?", e
## duas areas sobrepostas nao respondem isso: `body_entered` dispara em ordem de
## fisica, nao de distancia, e o aviso passaria a apontar para o NPC errado
## sempre que dois estiverem lado a lado no balcao. Um laco por quadro sobre meia
## duzia de NPCs custa menos que duas areas por NPC.
##
## CONVIVENCIA COM O ENCONTRO — sem acoplamento: a cena entrega um Callable em
## `permissao`, e o gerenciador so pergunta se PODE comecar. No outro sentido,
## nada precisa ser feito: a deteccao de encontro conta DISTANCIA ANDADA, e
## durante a conversa o jogador esta congelado, logo nao anda e nao sorteia.

signal conversa_iniciada(npc: Npc)
signal conversa_terminada(npc: Npc)
## Pedido declarado por um efeito {"servico": {...}} do dialogo. Loja, pesca,
## tutorial e missao entram por aqui. Pesca e tutorial ja sao atendidos pela cena
## (o Anselmo ensina a pescar pelo pedido {"tipo": "tutorial"}); o que ainda nao
## existe vira uma mensagem. O dialogo ja esta escrito do jeito definitivo.
signal servico_pedido(pedido: Dictionary, npc: Npc)

var estado: EstadoMundo
var dialogos := CatalogoDialogos.new()
var catalogo: CatalogoNpcs
var erro: String = ""

## Pergunta feita antes de iniciar uma conversa. A cena liga aqui o que mais
## tiver controle (hoje: o encontro e o mapa). Padrao: sempre pode.
var permissao: Callable = func() -> bool: return true

var _mundo: MundoIso
var _jogador: Jogador
var _caixa: CaixaDialogo
var _sessao: SessaoDialogo
var _npc_atual: Npc
var _perto: Npc
var _suspenso: bool = false
var _npcs: Array[Npc] = []


## Monta catalogos, instancia os NPCs no mundo e prepara a caixa. Devolve false
## com `erro` preenchido em vez de deixar meia montagem — mesma politica de
## MundoIso.carregar() e GerenciadorEncontro.preparar().
func preparar(mundo: MundoIso, jogador: Jogador, estado_do_mundo: EstadoMundo) -> bool:
	_mundo = mundo
	_jogador = jogador
	estado = estado_do_mundo

	catalogo = CatalogoNpcs.carregar()
	if catalogo.erro != "":
		erro = catalogo.erro
		return false
	var problemas := catalogo.validar(dialogos)
	if not problemas.is_empty():
		erro = "\n".join(problemas)
		return false

	_caixa = CaixaDialogo.new()
	_caixa.name = "CaixaDialogo"
	add_child(_caixa)
	_caixa.avancar_pedido.connect(_avancar)
	_caixa.menu.escolhido.connect(_ao_escolher)
	# Esc no menu de escolhas: cai na ultima opcao declarada, que por convencao
	# das arvores deste projeto e a saida. Fechar a conversa direto puliria os
	# efeitos que a saida carrega.
	_caixa.menu.cancelado.connect(func(): _ao_escolher(_indice_de_saida()))

	_instanciar_npcs()
	return true


func _instanciar_npcs() -> void:
	for ficha: DadosNpc in catalogo.npcs:
		var npc := Npc.criar(ficha, _mundo.celula)
		npc.position = _mundo.celula_para_mundo(ficha.celula)
		# Entra no MESMO container y-sorted dos props e do jogador: e o que faz o
		# NPC passar atras da casa ao norte dela e na frente ao sul.
		_mundo.entidades.add_child(npc)
		_npcs.append(npc)


# -------------------------------------------------------------------- estado
func em_conversa() -> bool:
	return _sessao != null


func npc_proximo() -> Npc:
	return _perto


## O NPC instanciado com este id, ou null. E como o tutorial acha o Anselmo
## quando ninguem lhe entrega o no (repetir a licao a partir de outro lugar).
func npc_por_id(id: String) -> Npc:
	for npc: Npc in _npcs:
		if npc.dados != null and npc.dados.id == id:
			return npc
	return null


## Tira o gerenciador de cena sem desmonta-lo (mapa aberto, encontro em curso).
## Esconde o aviso e para a deteccao; nao interrompe conversa em andamento.
func suspender(sim: bool) -> void:
	_suspenso = sim
	if sim and _perto != null:
		_perto.mostrar_indicador(false)
		_perto = null


# ------------------------------------------------------------------ deteccao
func _process(_delta: float) -> void:
	if _suspenso or em_conversa() or _jogador == null:
		return
	var alvo: Npc = null
	var menor := INF
	for npc: Npc in _npcs:
		var d := npc.distancia_em_celulas(_jogador.global_position)
		if d <= npc.dados.alcance and d < menor:
			menor = d
			alvo = npc
	if alvo == _perto:
		return
	if _perto != null:
		_perto.mostrar_indicador(false)
	_perto = alvo
	if _perto != null:
		_perto.mostrar_indicador(true)


func _unhandled_input(evento: InputEvent) -> void:
	if _suspenso:
		return
	if em_conversa():
		if _caixa.menu.tratar_entrada(evento):
			get_viewport().set_input_as_handled()
			return
		if evento.is_action_pressed("ui_accept") or evento.is_action_pressed("interagir"):
			_avancar()
			get_viewport().set_input_as_handled()
		elif evento.is_action_pressed("ui_cancel"):
			# Esc durante a FALA encerra a conversa. Nao ha efeito pendente: os
			# efeitos de um no sao aplicados ao entrar nele, nunca ao sair.
			_encerrar()
			get_viewport().set_input_as_handled()
		return
	if evento.is_action_pressed("interagir") and _perto != null:
		conversar_com(_perto)
		get_viewport().set_input_as_handled()


# ------------------------------------------------------------------ conversa
## Abre a conversa com um NPC. Devolve false quando nao pode comecar — outra
## coisa tem o controle, ou o dialogo do NPC nao carregou.
##
## `id_arvore` e `no_inicial` existem para o TUTORIAL: ele fala pela boca do
## Anselmo, mas com uma arvore propria (anselmo_tutorial) e abrindo no passo em
## que esta. Vazios, vale o de sempre — a arvore da ficha do NPC, comecando onde
## ela decidir (ArvoreDialogo.inicio_para). A conversa continua sendo do NPC:
## nome, retrato, `npc_id` dos nos vistos e servicos saem dele, nao da arvore.
func conversar_com(npc: Npc, id_arvore: String = "", no_inicial: String = "") -> bool:
	if npc == null or em_conversa() or _suspenso:
		return false
	if permissao.is_valid() and not permissao.call():
		return false
	var nome_da_arvore := id_arvore if id_arvore != "" else npc.dados.dialogo
	var arvore := dialogos.arvore(nome_da_arvore)
	if arvore == null:
		push_error("GerenciadorDialogo: NPC '%s' sem arvore '%s'"
				% [npc.dados.id, nome_da_arvore])
		return false
	# Recusa ANTES de congelar o jogador: um no inexistente abriria a caixa e a
	# sessao terminaria na hora, com o controle devolvido num quadro que ninguem
	# viu — melhor um erro claro e o jogo intacto.
	if no_inicial != "" and not arvore.nos.has(no_inicial):
		push_error("GerenciadorDialogo: no '%s' nao existe em '%s'"
				% [no_inicial, nome_da_arvore])
		return false

	_npc_atual = npc
	npc.mostrar_indicador(false)
	npc.olhar_para(_jogador.global_position)
	_jogador.congelar(true)

	_sessao = SessaoDialogo.new(arvore, estado, npc.dados.id)
	_sessao.iniciar(no_inicial)
	_caixa.abrir()
	conversa_iniciada.emit(npc)
	_drenar_servicos()
	_apresentar()
	return true


## Poe na tela o que a sessao tem agora: uma fala, um menu de escolhas, ou o fim.
func _apresentar() -> void:
	if _sessao == null:
		return
	if _sessao.terminou():
		_encerrar()
		return
	if _sessao.esperando_escolha():
		_caixa.menu.abrir(_sessao.escolhas(), _sessao.no.pergunta)
		return
	_caixa.menu.fechar()
	var fala := _sessao.fala_atual()
	if fala.is_empty():
		_encerrar()
		return
	_caixa.mostrar_fala(String(fala["texto"]), _nome_de(fala), _papel_de(fala),
			_retrato_de(fala))


func _avancar() -> void:
	if _sessao == null or _caixa.menu.ativo():
		return
	# Primeira resposta de "avancar": completar a linha que ainda esta correndo.
	if not _caixa.texto_completo():
		_caixa.completar_texto()
		return
	_sessao.avancar()
	_drenar_servicos()
	_apresentar()


func _ao_escolher(indice: int) -> void:
	if _sessao == null:
		return
	_sessao.escolher(indice)
	_drenar_servicos()
	_apresentar()


func _indice_de_saida() -> int:
	if _sessao == null:
		return 0
	return maxi(0, _sessao.escolhas().size() - 1)


## Fecha a conversa em curso por fora — mesmo efeito de _encerrar (e do ESC
## durante uma fala): nenhum efeito pendente, porque os efeitos de um no sao
## aplicados ao entrar nele. Quem usa e o tutorial, ao pular a licao no meio de
## uma fala do Anselmo. Sem conversa aberta, nao faz nada.
func encerrar_conversa() -> void:
	if em_conversa():
		_encerrar()


func _encerrar() -> void:
	var npc := _npc_atual
	_sessao = null
	_npc_atual = null
	_caixa.fechar()
	if _jogador != null:
		_jogador.congelar(false)
	conversa_terminada.emit(npc)


func _drenar_servicos() -> void:
	if _sessao == null:
		return
	for pedido: Dictionary in _sessao.servicos:
		servico_pedido.emit(pedido, _npc_atual)
	_sessao.servicos.clear()


# ---------------------------------------------------------------- quem fala
func _nome_de(fala: Dictionary) -> String:
	var quem := String(fala.get("quem", NoDialogo.QUEM_NPC))
	if quem == NoDialogo.QUEM_JOGADOR:
		return "Você"
	if quem == NoDialogo.QUEM_NPC:
		return _npc_atual.dados.nome if _npc_atual != null else ""
	# Terceiro personagem: o proprio campo vale como nome, e se ele for o id de
	# um NPC do catalogo, o nome e o retrato saem da ficha dele.
	var outro := catalogo.por_id(quem)
	return outro.nome if outro != null else quem


func _papel_de(fala: Dictionary) -> String:
	var quem := String(fala.get("quem", NoDialogo.QUEM_NPC))
	if quem == NoDialogo.QUEM_JOGADOR:
		return ""
	if quem == NoDialogo.QUEM_NPC:
		return _npc_atual.dados.papel if _npc_atual != null else ""
	var outro := catalogo.por_id(quem)
	return outro.papel if outro != null else ""


func _retrato_de(fala: Dictionary) -> String:
	if String(fala.get("retrato", "")) != "":
		return String(fala["retrato"])
	var quem := String(fala.get("quem", NoDialogo.QUEM_NPC))
	if quem == NoDialogo.QUEM_JOGADOR:
		return CaixaDialogo.RETRATO_JOGADOR
	if quem == NoDialogo.QUEM_NPC:
		return _npc_atual.dados.retrato if _npc_atual != null else ""
	var outro := catalogo.por_id(quem)
	return outro.retrato if outro != null else ""
