extends Node2D

## Camada 4 — cena da primeira area jogavel (RF05) e do encontro com criaturas.
##
## Monta mundo, jogador, camera, encontro, dialogo, roda de itens, pesca e o
## tutorial do Anselmo, e liga uns aos outros — nenhum deles conhece os demais.
##
## O ARCO DO JOGO e costurado aqui: a primeira criatura (Mirela), o duelo do guardiao,
## o selo, a vitoria e a derrota. A regra de batalha nao esta nesta cena; ela so reage
## a como o encontro terminou (_on_encontro_terminado).
##
## A SEED entra aqui, e desde a Etapa 1 do menu ela vem DE FORA: quem a escolhe e
## a tela de nova partida (RF01), e quem a guarda e o autoload `Save`. Esta cena
## apenas a le de `Save.partida` — e cai em SEED_DO_MUNDO quando nao ha partida
## nenhuma, que e o caso de abrir a cena direto pelo editor ou por um teste
## headless. Nenhum caminho especial: o comportamento antigo e o padrao.
##
## Mesma seed => mesmas ~100 criaturas e mesma sequencia de encontros (RF03). O
## visualizador do bestiario (F2) usa SEED_DO_MUNDO, de modo que uma partida
## iniciada com esse numero pode ser conferida criatura por criatura na lista.
##
## A cena e construida por codigo, como o resto do projeto (ver
## presentation/bestiario_viewer.gd). O motivo aqui e o mesmo de la: os dados
## mandam. O mapa e um JSON de 40x36 com ~350 props — descrever isso num .tscn
## produziria um arquivo gerado, gigante e ilegivel em diff, e ainda assim
## precisaria de um carregador para o JSON.
##
## UM DONO DA TELA POR VEZ. Encontro, conversa, mapa, pausa, pesca, roda de
## itens e a pergunta "pular a licao?" disputam o mesmo personagem e a mesma
## entrada. Nenhum deles conhece os outros: cada um PERGUNTA a esta cena (os
## Callable `permissao`, _pode_pausar, _alternar_mapa...) e todas as perguntas
## leem a mesma lista, _dono_da_tela(). Um sistema novo que tome a tela entra
## ali uma vez.
##
## Teclas de jogo que esta cena distribui (o resto e de cada sistema):
##   Q    abre a roda de itens ao PRESSIONAR; soltar e com a propria RodaItens
##   F    usar o item na mao — com a vara, pescar (lido pelo GerenciadorPesca)
##   P    pular a licao do Anselmo (lido pelo GerenciadorTutorial)
##
##   F5   grava a partida no slot de onde ela veio (atalho; o caminho normal e
##        ESC -> SALVAR)
##
## Teclas de desenvolvimento, so no editor e na build de debug (ver
## teclas_de_desenvolvimento). Na build de entrega nao existem: a F4 forcaria encontros
## e distorceria um playtest.
##   F3   liga/desliga a sobreposicao das zonas de encontro e da grade
##   F2   volta ao visualizador do bestiario (RF07/RF08)
##   F4   forca um encontro na zona mais proxima (nao espera o sorteio)

const CENA_BESTIARIO := "res://presentation/bestiario_viewer.tscn"
const CENA_MENU := "res://presentation/menu/menu_principal.tscn"
const CENA_MUNDO := "res://presentation/exploracao/mundo.tscn"
const DIR_MAPAS := "res://autoral/mapas/"
const META_CHEGADA_POR_PORTA := "chegada_por_porta"
const DURACAO_PORTA := 0.35

const BANDEIRA_INICIAL := "recebeu_inicial"
const BANDEIRA_VENCEU := "jogo_vencido"
const BANDEIRA_DICAS_BATALHA := "viu_dicas_batalha"

## Linha de teclas do HUD. Constante (e nao literal em _montar_hud) para o teste
## de integracao conferir os glifos contra a fonte pixel.
const TEXTO_TECLAS := "SETAS/WASD andar   E falar   Q itens  F usar   B bolsa   " \
		+ "N bestiário   M mapa   ESC pausa"
const TEXTO_TECLAS_DEV := "   F3 zonas   F2 bestiário   F4 encontro"
## Quanto tempo a linha de controles fica no rodape no comeco. Depois, so na pausa.
const SEGUNDOS_DE_CONTROLES := 12.0
const LARGURA_CARD_OBJETIVO := 300.0

## Respostas ao pedido {"servico": {"tipo": "pesca"}} do Anselmo ("Posso pescar
## agora?"). A fala dele nao cita tecla nenhuma — conta com esta nota —, e a
## nota muda conforme o que falta ao jogador.
const TEXTO_PESCA_COM_VARA := "Vara na mão: de frente para a água, aperte [F]."
const TEXTO_PESCA_EQUIPAR := "Equipe a vara na roda [Q] e, de frente para a água, aperte [F]."
const TEXTO_PESCA_SEM_VARA := "Sem vara não tem pesca. O Anselmo ensina."
const TEXTO_FISGOU := "Fisgou %s!"
const TEXTO_SEM_SALVAR_PESCA := "Não dá para salvar no meio da pesca."

## Seed usada quando a cena e aberta SEM partida (editor, teste headless,
## screenshot). Igual a do visualizador do bestiario, para que as duas telas
## mostrem o MESMO bestiario nesse caso.
const SEED_DO_MUNDO := 123456789

## Tamanho do bestiario — a meta declarada no trabalho. Tambem so o padrao: a
## partida carrega o seu proprio numero, para que um save antigo continue
## resolvendo os mesmos indices de criatura se a meta mudar.
const CRIATURAS_POR_MUNDO := 100

## Valores em vigor nesta sessao, resolvidos em _ready a partir de Save.partida.
var seed_do_mundo: int = SEED_DO_MUNDO
var criaturas_por_mundo: int = CRIATURAS_POR_MUNDO

var mundo: MundoIso
var jogador: Jogador
var camera: CameraExploracao
var encontros: GerenciadorEncontro
var dialogos: GerenciadorDialogo
var estado_mundo: EstadoMundo
var mapa: MapaMundo
var anuncio: AnuncioRegiao
var pausa: MenuPausa
var roda: RodaItens
var pesca: GerenciadorPesca
var tutorial: GerenciadorTutorial
var guardioes: CatalogoGuardioes
var tela_inicial: TelaEscolhaInicial
var tela_desfecho: TelaDesfecho
var tela_loja: TelaLoja
var lojas: CatalogoLojas
## Chegada de onibus. So existe numa partida nova; null nas demais.
var chegada: CutsceneChegada

## F2, F3 e F4 valem? Verdadeiro no editor e na build de debug, falso na de entrega.
var teclas_de_desenvolvimento: bool = OS.is_debug_build()

var _depuracao: bool = false
var _sobreposicao: SobreposicaoDepuracao
var _aviso: Label
var _hud_dica: Control
var _hud_nota: Control
var _hud_objetivo: Control
var _texto_objetivo: Label
var _texto_equipe: Label
var _tween_objetivo: Tween
## Ultimo objetivo nao vazio exibido. A comparacao e com ele, e nao com o texto da
## faixa, para a mudanca piscar mesmo passando por um estado intermediario vazio.
var _objetivo_mostrado: String = ""
## O que fazer quando a conversa fechar: a escolha inicial e o duelo nao abrem por cima
## da caixa de fala do NPC que os pediu.
var _apos_conversa: Callable
## Guardiao do duelo em curso, para saber de quem e o selo quando ele terminar.
var _duelo_atual: Dictionary = {}
## Celula -> {dados, no} das bolsas perdidas ainda no chao (Camada 3).
var _achados: Dictionary = {}
## A criatura fisgada foi para a batalha: a pesca espera ela terminar.
var _pesca_em_batalha: bool = false
var _atravessando: bool = false
## Ultima celula verificada para porta: a porta dispara ao PISAR nela, nao a cada
## quadro parado em cima (o aviso de trancado nao pode repetir sem parar).
var _ultima_celula_de_porta := Vector2i(-1, -1)
## Balao "ENTRAR"/"SAIR" sobre cada porta, visivel quando o jogador chega perto: sem
## ele, nada na fachada diz que a fabrica tem entrada.
var _avisos_de_porta: Array = []
const DISTANCIA_AVISO_PORTA := 2.5
var _tween_nota: Tween
var _tween_controles: Tween
var _regiao_corrente: String = ""
## O HUD foi pedido visivel? (_mostrar_hud). Guardado porque as duas linhas de
## cima tambem cedem a dica do tutorial, quadro a quadro (ver _process).
var _hud_visivel: bool = true


func _ready() -> void:
	Som.musica("vila")
	# Antes de qualquer montagem: o bestiario inteiro depende destes dois numeros.
	if Save.em_partida():
		seed_do_mundo = Save.partida.seed_mundo
		criaturas_por_mundo = Save.partida.criaturas_por_mundo

	mundo = MundoIso.new()
	mundo.name = "Mundo"
	mundo.caminho = _caminho_do_mapa()
	add_child(mundo)
	# Explicito, e nao pelo _ready do proprio MundoIso: e daqui que se conhece a
	# ordem — o jogador e a camera dependem de o mapa ja estar montado.
	mundo.carregar(_caminho_do_mapa())
	if mundo.erro != "":
		_mostrar_erro(mundo.erro)
		return

	jogador = Jogador.new()
	jogador.name = "Jogador"
	jogador.position = mundo.spawn_do_jogador()
	# Entra no MESMO container y-sorted dos props: e o que faz o jogador passar
	# atras da casa quando esta ao norte dela e na frente quando esta ao sul.
	mundo.entidades.add_child(jogador)

	camera = CameraExploracao.new()
	camera.name = "Camera"
	add_child(camera)
	camera.enquadrar(mundo.limites_da_camera())
	camera.seguir(jogador)

	_sobreposicao = SobreposicaoDepuracao.new()
	_sobreposicao.name = "Depuracao"
	_sobreposicao.mundo = mundo
	_sobreposicao.visible = false
	# Acima do chao e abaixo do resto nao importa: ela desenha linhas sobre tudo.
	add_child(_sobreposicao)
	_sobreposicao.z_index = 100

	_montar_hud()
	_montar_encontros()
	_montar_dialogos()
	# Equipamento, pesca e tutorial DEPOIS de encontro e dialogo, nesta ordem: a
	# pesca le o bestiario e o catalogo de corpos do encontro; o tutorial fala
	# pelo dialogo e escuta a pesca e a mao do jogador.
	_montar_equipamento()
	_montar_pesca()
	_montar_tutorial()
	_montar_regioes_e_mapa()
	_montar_pausa()
	_montar_arco()
	_ligar_save()
	_preparar_dicas_de_batalha()
	_montar_ambientacao()
	_talvez_chegar_de_onibus()
	_atualizar_objetivo()
	# Nasce sobre a celula de chegada, que nao e porta; a seguinte ja pode ser.
	_ultima_celula_de_porta = mundo.mundo_para_celula(jogador.position)
	_montar_avisos_de_porta()
	_clarear_chegada()


## Primeira criatura, guardioes, vitoria e derrota.
func _montar_arco() -> void:
	guardioes = CatalogoGuardioes.carregar()
	if guardioes.erro != "":
		_mostrar_erro("guardioes: " + guardioes.erro)
		return
	tela_inicial = TelaEscolhaInicial.new()
	tela_inicial.name = "TelaEscolhaInicial"
	add_child(tela_inicial)
	tela_inicial.escolhida.connect(_ao_escolher_inicial)
	tela_inicial.cancelada.connect(func() -> void:
			jogador.congelar(false)
			if dialogos != null:
				dialogos.suspender(false)
			if chegada != null:
				chegada.escolha_cancelada())

	lojas = CatalogoLojas.carregar()
	tela_loja = TelaLoja.new()
	tela_loja.name = "TelaLoja"
	add_child(tela_loja)
	tela_loja.fechada.connect(func() -> void:
			jogador.congelar(false)
			if dialogos != null:
				dialogos.suspender(false))
	Bolsa.gold_mudou.connect(_ao_mudar_gold)

	tela_desfecho = TelaDesfecho.new()
	tela_desfecho.name = "TelaDesfecho"
	add_child(tela_desfecho)
	# ADIADO: a escolha chega de dentro do evento de entrada, e trocar de cena ali
	# tira a cena antiga da arvore no meio dele. Na build de entrega isso derrubava o
	# jogo ao voltar ao save depois de perder (falha de segmentacao na fisica).
	tela_desfecho.opcao_escolhida.connect(_ao_escolher_no_desfecho, CONNECT_DEFERRED)

	if dialogos != null:
		dialogos.conversa_terminada.connect(_ao_terminar_conversa)
	if estado_mundo != null:
		estado_mundo.bandeira_mudou.connect(func(_n: String, _v: Variant) -> void:
				_atualizar_objetivo())
	if encontros != null and encontros.equipe != null:
		encontros.equipe.mudou.connect(_atualizar_objetivo)


## Liga o sistema de encontros. Depois do HUD de proposito: o gerenciador emite
## sinais que o HUD escuta, e conectar a um rotulo que ainda nao existe
## silenciaria a atualizacao da bolsa sem erro nenhum.
func _montar_encontros() -> void:
	encontros = GerenciadorEncontro.new()
	encontros.name = "Encontros"
	add_child(encontros)
	# O inventario vem DA BOLSA, e nao e criado pelo encontro: a partir da Etapa
	# 3 ha um estoque so, que a pesca, a loja e o dialogo tambem mexem. O
	# parametro e opcional e o encontro continua sabendo se virar sozinho — e o
	# que mantem tools/test_encontro.gd rodando sem conhecer a Bolsa.
	if Save.em_partida():
		encontros.modo_gerador = GeradorCriaturas.modo_do_nome(Save.partida.modelo_gerador) \
				as GeradorCriaturas.Modo
	RegistroSessao.evento("mundo", {"seed": seed_do_mundo,
			"modelo": GeradorCriaturas.nome_do_modo(encontros.modo_gerador)})
	if not encontros.preparar(mundo, jogador, camera, seed_do_mundo,
			criaturas_por_mundo, Bolsa.inventario):
		_mostrar_erro("encontros: " + encontros.erro)
		return
	# O HUD de exploracao sai de cena durante o encontro: sobreposto a interface
	# escurecida ele vira ruido ilegivel no topo da tela, e a informacao que ele
	# carrega (bolsa) ja aparece dentro da roda, item por item.
	encontros.encontro_iniciado.connect(func(_c): _mostrar_hud(false))
	encontros.encontro_terminado.connect(_on_encontro_terminado)


## Liga NPCs e dialogo. Depois dos encontros de proposito: o dialogo consulta o
## inventario (condicoes {"item": ...} e {"capturadas": ...}) por PROVEDOR, e um
## provedor registrado apontando para um inventario que ainda nao existe deixaria
## a condicao falsa em silencio.
func _montar_dialogos() -> void:
	estado_mundo = EstadoMundo.new()
	dialogos = GerenciadorDialogo.new()
	dialogos.name = "Dialogos"
	add_child(dialogos)
	if not dialogos.preparar(mundo, jogador, estado_mundo):
		_mostrar_erro("dialogo: " + dialogos.erro)
		return

	# O dialogo nao conhece o encontro: ele so PERGUNTA se pode comecar. A
	# resposta e a lista unica de _dono_da_tela — pesca ativa e roda aberta
	# inclusive. E por ela que a conversa "despedida" do tutorial, pedida no
	# quadro da fisgada, espera o minigame fechar em vez de abrir por cima dele.
	dialogos.permissao = func() -> bool: return _dono_da_tela() == ""
	# E o encontro nao conhece o dialogo: quem liga os dois e esta cena.
	if encontros != null:
		encontros.encontro_iniciado.connect(func(_c): dialogos.suspender(true))
		encontros.encontro_terminado.connect(func(_d, _c): dialogos.suspender(false))
		if encontros.inventario != null:
			estado_mundo.registrar_provedor("item",
					func(id: String) -> int: return encontros.inventario.quantidade(id))
			estado_mundo.registrar_provedor("capturadas",
					func(_c: String) -> int: return encontros.inventario.colecao.size())

	dialogos.servico_pedido.connect(_on_servico_pedido)


## Roda de itens (Q) e o vinculo entre a bolsa e a mao.
##
## A roda nao conhece o jogador nem a bolsa (ver roda_itens.gd): quem a abre,
## com a lista pronta, e esta cena, em _abrir_roda; quem congela o jogador
## enquanto ela esta aberta tambem. Congelar, e nao desacelerar o tempo: e o
## mesmo mecanismo do encontro e do dialogo, e o sorteio de encontro ja conta
## distancia andada — parado, ninguem sorteia nada atras da roda.
func _montar_equipamento() -> void:
	roda = RodaItens.new()
	roda.name = "RodaItens"
	add_child(roda)
	roda.item_escolhido.connect(jogador.equipar)
	# A roda so abre com a tela livre (_abrir_roda), entao descongelar ao fechar
	# nao devolve o controle a quem nao o tinha.
	roda.fechada.connect(func(_trocou: bool) -> void: jogador.congelar(false))
	# Metodo, e nao lambda: a Bolsa e autoload e sobrevive a esta cena; uma
	# conexao com metodo do no sai junto quando ele e liberado.
	Bolsa.item_mudou.connect(_ao_mudar_item_da_bolsa)


## Item que saiu da bolsa nao fica na mao. Hoje nenhum caminho do jogo tira um
## equipamento (sao permanentes), mas o save e editavel e a loja vira — e uma
## vara na mao sem vara na bolsa e um estado que a pesca nao espera.
func _ao_mudar_item_da_bolsa(id: String, quantidade: int) -> void:
	if quantidade <= 0 and jogador != null and id != "" and id == jogador.item_equipado:
		jogador.equipar(null)


func _abrir_roda() -> void:
	if roda == null or roda.aberta() or _dono_da_tela() != "":
		return
	roda.abrir(Bolsa.com_marcador("equipamento"), jogador.item_equipado)
	jogador.congelar(true)


## Pesca na beira d'agua. Depois do encontro de proposito: o bestiario e o
## catalogo de corpos (a forma das silhuetas) sao os DELE — a pesca nao gera
## nada, le a mesma seed ja gerada, e por isso nao muda o bestiario (RF03).
##
## Filha DESTA cena, e nao do mundo: _unhandled_input chega aos filhos antes do
## pai. E isso que faz o ESC (ui_cancel e tambem "pausar") cancelar a pesca sem
## abrir a pausa — a pesca o consome antes de _unhandled_input daqui o ver.
func _montar_pesca() -> void:
	pesca = GerenciadorPesca.new()
	pesca.name = "Pesca"
	add_child(pesca)
	var bestiario: Array = encontros.bestiario if encontros != null else []
	var catalogo: CatalogoCorpos = encontros.catalogo if encontros != null else null
	if not pesca.preparar(jogador, camera, bestiario, seed_do_mundo, _e_agua,
			_regiao_em, mundo.celula, catalogo):
		_mostrar_erro("pesca: " + pesca.erro)
		return
	pesca.permissao = func() -> bool: return _dono_da_tela() == ""
	pesca.aviso.connect(_nota)
	# A conversa nao abre por cima da pesca: alem da permissao, o aviso "[E]
	# FALAR" some (suspender), como no mapa e no encontro.
	pesca.pesca_iniciada.connect(func() -> void: dialogos.suspender(true))
	# O HUD sai so quando o MINIGAME abre: no arco ele fica (o arco e embaixo, o
	# HUD em cima). Sobre o corte d'agua em tela cheia, texto de exploracao no
	# topo seria ruido — e ali o topo e da dica do tutorial.
	pesca.arremessado.connect(func(_f: float, _z: String, _d: float) -> void:
			_mostrar_hud(false))
	pesca.peixe_fisgado.connect(_ao_fisgar)
	pesca.pesca_encerrada.connect(_ao_encerrar_pesca)


func _ao_encerrar_pesca() -> void:
	if dialogos != null:
		dialogos.suspender(false)
	_mostrar_hud(true)


## A criatura fisgada vira batalha, com a pesca parada em FISGADO e o jogador
## congelado ate ela terminar (_on_encontro_terminado chama pesca.encerrar). Na licao do
## Anselmo, ou sem ninguem de pe para lutar, a fisgada so vira nota: quem aprende a
## pescar nao pode perder a partida por isso.
func _ao_fisgar(criatura: Criatura) -> void:
	if criatura == null:
		return
	print("Pesca: fisgou %s" % criatura)
	_nota(TEXTO_FISGOU % criatura.nome())
	if pesca.modo_tutorial or encontros == null or not encontros.pode_comecar():
		return
	# Sincrono, antes do primeiro await: _fisgar le este campo logo depois do sinal.
	pesca.encerrar_ao_fisgar = false
	_pesca_em_batalha = true
	# O letreiro "FISGOU!" fica um instante antes do encontro cobrir a tela.
	await get_tree().create_timer(pesca.cfg.duracao_resultado).timeout
	encontros.iniciar_com_criatura(criatura)


## Agua e regiao pela geometria do MAPA. Sao Callable para a pesca: ela nao
## conhece o MundoIso, e a cena de teste (tools/cena_teste_pesca.gd) entrega um
## poligono no lugar.
func _e_agua(p: Vector2) -> bool:
	# Interior nao tem pesca: as pocas da fabrica sao chao molhado, nao rio.
	return mundo.mundo_aberto and mundo.terreno_em(mundo.mundo_para_celula(p)) == "agua"


func _regiao_em(p: Vector2) -> String:
	var r := _regiao_da_celula(mundo.mundo_para_celula(p))
	return r.id_regiao if r != null else ""


## Licao de pesca do Anselmo. Por ultimo entre os tres: o tutorial fala pelo
## dialogo, escuta a pesca e a mao do jogador, e nenhum deles sabe que ele
## existe — os eventos chegam por notificar(), ligados aqui.
func _montar_tutorial() -> void:
	tutorial = GerenciadorTutorial.new()
	tutorial.name = "Tutorial"
	add_child(tutorial)
	if dialogos == null or not tutorial.preparar(dialogos, estado_mundo):
		_mostrar_erro("tutorial: " + tutorial.erro)
		return
	tutorial.nota.connect(_nota)
	tutorial.desequipar_pedido.connect(func() -> void: jogador.equipar(null))
	# P nao abre o "Tem certeza?" por cima do que e modal e nao e do tutorial.
	# Conversa e pesca podem: pular fecha a conversa da licao, e a pesca em
	# curso termina sozinha (ainda em modo tutorial) antes da fala "pulou".
	tutorial.permissao_pulo = func() -> bool:
		return not (_dono_da_tela() in ["roda", "mapa", "encontro", "pausa"])
	jogador.item_equipado_mudou.connect(func(id: String) -> void:
			tutorial.notificar("item_equipado", id))
	if pesca == null:
		return
	# Vale a partir do PROXIMO lance: a simulacao em curso ja nasceu com o modo
	# que tinha (ver GerenciadorPesca.modo_tutorial).
	tutorial.tutorial_iniciado.connect(func(_id: String) -> void:
			pesca.modo_tutorial = true)
	tutorial.tutorial_concluido.connect(func(_id: String, _pulado: bool) -> void:
			pesca.modo_tutorial = false)
	pesca.pesca_iniciada.connect(func() -> void: tutorial.notificar("pesca_iniciada"))
	pesca.arremessado.connect(func(_f: float, _z: String, _d: float) -> void:
			tutorial.notificar("arremessado"))
	pesca.silhueta_surgiu.connect(func(_c: Criatura) -> void:
			tutorial.notificar("silhueta_surgiu"))
	pesca.peixe_fisgado.connect(func(_c: Criatura) -> void: tutorial.notificar("fisgado"))
	pesca.pesca_falhou.connect(func(_motivo: String) -> void: tutorial.notificar("falhou"))


## Quem esta com a tela agora ("" = ninguem: o jogador anda livre). E a lista
## unica que todas as permissoes consultam (ver o topo do arquivo). A ordem so
## decide o NOME devolvido quando dois coincidem — o que nao deveria acontecer,
## e e justamente o que esta lista impede.
func _dono_da_tela() -> String:
	if tutorial != null and tutorial.perguntando():
		return "tutorial"
	if chegada != null and chegada.dona_da_tela():
		return "chegada"
	if pausa != null and pausa.aberto():
		return "pausa"
	if tela_desfecho != null and tela_desfecho.aberta():
		return "desfecho"
	if tela_inicial != null and tela_inicial.aberta():
		return "escolha"
	if tela_loja != null and tela_loja.aberta():
		return "loja"
	if encontros != null and encontros.estado.em_encontro():
		return "encontro"
	if dialogos != null and dialogos.em_conversa():
		return "dialogo"
	if pesca != null and pesca.ativa():
		return "pesca"
	if roda != null and roda.aberta():
		return "roda"
	if mapa != null and mapa.aberto():
		return "mapa"
	return ""


## O mapa da partida (Save.partida.mapa), ou o mundo quando nao ha partida ou o
## arquivo nao existe.
func _caminho_do_mapa() -> String:
	var id := Save.partida.mapa if Save.em_partida() else DadosPartida.MAPA_PADRAO
	var caminho := DIR_MAPAS + "%s.json" % id
	return caminho if FileAccess.file_exists(caminho) else DIR_MAPAS + "mundo.json"


## Portas: pisar na celula de uma porta leva ao outro mapa. A troca e a mesma de
## carregar um save, sem tocar no disco: o estado vivo vai para Save.partida, que
## muda de mapa, e a cena se remonta a partir dela.
func _verificar_porta() -> void:
	if _atravessando or jogador == null or mundo == null:
		return
	var c := mundo.mundo_para_celula(jogador.position)
	if c == _ultima_celula_de_porta:
		return
	_ultima_celula_de_porta = c
	var porta := mundo.porta_em(c)
	if porta.is_empty() or _dono_da_tela() != "":
		return
	var requer := String(porta.get("requer", ""))
	if requer != "" and not estado_mundo.ativa(requer):
		_nota(String(porta.get("aviso", "Trancado.")))
		return
	_atravessar(porta)


## Camada 3: o que a seed espalha sobre o mapa autoral. Roda depois do save, porque os
## achados ja recolhidos nao voltam. So no mundo aberto: interiores sao autorais.
func _montar_ambientacao() -> void:
	if encontros == null or mundo == null or not mundo.mundo_aberto:
		return
	var gerador := GeradorAmbientacao.carregar()
	if gerador == null:
		return
	var reservadas: Array = []
	if dialogos != null and dialogos.catalogo != null:
		for ficha: DadosNpc in dialogos.catalogo.npcs:
			reservadas.append(ficha.celula)
	var geradas := gerador.gerar(seed_do_mundo, mundo.dados_do_mapa(), mundo.catalogo_de_props(),
			encontros.bestiario, reservadas)
	for item: Dictionary in geradas["props"]:
		mundo.adicionar_prop(String(item["categoria"]), item)
	for achado: Dictionary in geradas["achados"]:
		if estado_mundo.ativa(String(achado["id"])):
			continue
		var c := Vector2i(int(achado["celula"][0]), int(achado["celula"][1]))
		_achados[c] = {"dados": achado, "no": mundo.adicionar_prop("Decoracao", achado)}
	RegistroSessao.evento("ambientacao", {"props": (geradas["props"] as Array).size(),
			"dominantes": geradas["dominantes"]})


## Pisar numa bolsa perdida paga uma vez. A bandeira vai para o save.
func _verificar_achado() -> void:
	if _achados.is_empty() or jogador == null or _dono_da_tela() != "":
		return
	var c := mundo.mundo_para_celula(jogador.position)
	if not _achados.has(c):
		return
	var achado: Dictionary = _achados[c]
	var dados: Dictionary = achado["dados"]
	_achados.erase(c)
	(achado["no"] as Node).queue_free()
	estado_mundo.definir(String(dados["id"]))
	Bolsa.ganhar_gold(int(dados["gold"]))
	Som.tocar("achado")
	_nota("Você achou uma bolsa perdida: +%d gold" % int(dados["gold"]))
	_autosalvar()


func _atravessar(porta: Dictionary) -> void:
	if not Save.em_partida():
		_nota("Sem partida em curso: portas só funcionam numa partida do menu.")
		return
	_atravessando = true
	Som.tocar("porta")
	jogador.congelar(true)
	Save.coletar()
	var chegada: Array = porta.get("chegada", [0, 0])
	Save.partida.mapa = String(porta.get("destino", DadosPartida.MAPA_PADRAO))
	Save.partida.celula = Vector2i(int(chegada[0]), int(chegada[1]))
	Save.partida.direcao = String(porta.get("direcao", "baixo"))
	Save.set_meta(META_CHEGADA_POR_PORTA, true)
	var veu := ColorRect.new()
	veu.color = Color(TemaEncontro.CONTORNO, 0.0)
	veu.set_anchors_preset(Control.PRESET_FULL_RECT)
	veu.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var camada := CanvasLayer.new()
	camada.layer = 99
	camada.add_child(veu)
	add_child(camada)
	var t := create_tween()
	t.tween_property(veu, "color:a", 1.0, DURACAO_PORTA)
	await t.finished
	_trocar_de_cena(CENA_MUNDO)


func _montar_avisos_de_porta() -> void:
	for p: Dictionary in mundo.portas():
		var c: Array = p.get("celula", [0, 0])
		# Num no proprio, na porta: o balao anima a propria posicao (o balanco), e
		# solto no mundo ele balancaria em torno da origem do mapa.
		var lugar := Node2D.new()
		lugar.position = mundo.celula_para_mundo(Vector2i(int(c[0]), int(c[1])))
		mundo.entidades.add_child(lugar)
		var ind := IndicadorInteracao.new()
		lugar.add_child(ind)
		ind.configurar("", "ENTRAR" if String(p.get("destino", "")) != "mundo" else "SAIR")
		ind.mostrar(false)
		_avisos_de_porta.append(ind)


func _atualizar_avisos_de_porta() -> void:
	if jogador == null:
		return
	var c := Vector2(mundo.mundo_para_celula(jogador.position))
	var portas := mundo.portas()
	for i in _avisos_de_porta.size():
		var pc: Array = portas[i].get("celula", [0, 0])
		(_avisos_de_porta[i] as IndicadorInteracao).mostrar(
				c.distance_to(Vector2(int(pc[0]), int(pc[1]))) <= DISTANCIA_AVISO_PORTA
				and _dono_da_tela() == "")


## Chegou por uma porta: a tela clareia em vez de aparecer de uma vez.
func _clarear_chegada() -> void:
	if not Save.has_meta(META_CHEGADA_POR_PORTA):
		return
	Save.remove_meta(META_CHEGADA_POR_PORTA)
	var veu := ColorRect.new()
	veu.color = Color(TemaEncontro.CONTORNO, 1.0)
	veu.set_anchors_preset(Control.PRESET_FULL_RECT)
	veu.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var camada := CanvasLayer.new()
	camada.layer = 99
	camada.add_child(veu)
	add_child(camada)
	var t := create_tween()
	t.tween_property(veu, "color:a", 0.0, DURACAO_PORTA)
	t.tween_callback(camada.queue_free)


func _process(_delta: float) -> void:
	_verificar_porta()
	_verificar_achado()
	_atualizar_avisos_de_porta()
	# O marcador do jogador so precisa acompanhar enquanto a carta esta aberta —
	# e, com o jogador congelado, ele nem se move. Atualizar assim mesmo mantem a
	# tela correta se algo mais mover o personagem (uma teleportacao futura).
	if mapa != null and mapa.aberto() and jogador != null:
		mapa.atualizar_posicao(mundo.mundo_para_celula(jogador.position),
				_regiao_corrente)
	_ceder_topo_a_dica()


## O card do objetivo divide o topo da tela com a dica do tutorial, que e desenhada
## por cima (camada 92) e tem um aviso no canto direito. Com o pergaminho la, o card e
## a linha de controles cedem: a dica e a instrucao do momento. A nota fica — e por
## ela que chega o "Recebeu: ...".
func _ceder_topo_a_dica() -> void:
	var dica_na_tela: bool = tutorial != null and tutorial.dica != null \
			and tutorial.dica.dica_visivel()
	for no: Control in [_hud_dica, _hud_objetivo]:
		if no != null:
			no.visible = _hud_visivel and not dica_na_tela


## Liga a cena ao autoload `Save`. Ultima montagem de proposito: cada secao le e
## escreve num sistema que ja tem de existir.
##
## A CENA NAO CHAMA NENHUM "salvar_tudo". Ela declara, para cada pedaco de
## estado, como colher e como repor — e o Save executa as duas direcoes na ordem
## de registro. E o mesmo padrao dos provedores de EstadoMundo, e o motivo e o
## mesmo: um sistema novo custa um registro aqui, e nem o formato do save nem o
## autoload precisam conhece-lo.
func _ligar_save() -> void:
	if not Save.em_partida():
		return
	Save.esquecer_secoes()

	# A ORDEM IMPORTA. "jogador" primeiro porque repor a posicao e o que define
	# em que regiao o personagem esta; so depois faz sentido repor as bandeiras,
	# que incluem quais regioes ja foram descobertas.
	# "itens" NAO esta aqui: a Bolsa registra a propria secao, como permanente,
	# porque ela atravessa a troca de cena e esta tela nao.
	Save.registrar_secao("jogador", _colher_jogador, _repor_jogador)
	Save.registrar_secao("estado_mundo", _colher_estado, _repor_estado)
	Save.registrar_secao("criaturas", _colher_criaturas, _repor_criaturas)

	Save.restaurar_na_cena()


func _colher_estado(d: DadosPartida) -> void:
	d.estado_mundo = estado_mundo.para_dicionario()


## Secao vazia = partida nova. Repor um dicionario vazio apagaria a visita a
## regiao de spawn que _montar_regioes_e_mapa acabou de registrar.
func _repor_estado(d: DadosPartida) -> void:
	if not d.estado_mundo.is_empty():
		estado_mundo.de_dicionario(d.estado_mundo)


func _colher_jogador(d: DadosPartida) -> void:
	d.mapa = mundo.id_mapa if mundo.id_mapa != "" else DadosPartida.MAPA_PADRAO
	d.celula = mundo.mundo_para_celula(jogador.position)
	d.direcao = jogador.direcao
	d.regiao = _regiao_corrente
	d.regiao_nome = _nome_da_regiao(_regiao_corrente)
	d.item_equipado = jogador.item_equipado


func _repor_jogador(d: DadosPartida) -> void:
	# O item na mao ANTES do retorno cedo: um save sem posicao (gravado antes de
	# o jogador andar) pode ter a vara na mao do mesmo jeito.
	_reequipar(d.item_equipado)
	if not d.tem_posicao():
		return  # partida nova: o spawn declarado pelo mapa ja esta certo
	jogador.position = mundo.celula_para_mundo(d.celula)
	jogador.direcao = d.direcao
	# A camera salta junto. Sem isto ela comeca no spawn e desliza pelo mapa
	# inteiro ate o jogador no primeiro segundo da partida carregada.
	camera.seguir(jogador)
	# `body_entered` nao dispara num corpo teleportado para dentro da area, e o
	# mapa e o anuncio de regiao leem esta variavel — recalcular e mais barato e
	# mais confiavel que esperar a fisica.
	var r := _regiao_da_celula(d.celula)
	_regiao_corrente = r.id_regiao if r != null else d.regiao


## Poe de volta na mao o item gravado — so se a Bolsa o tem. A secao "itens" e
## permanente e foi registrada antes de qualquer secao de cena, entao ja foi
## reposta quando esta roda: um id que saiu do estoque (save editado, item
## renomeado) nao volta a mao, volta a mao vazia. O Jogador aceita equipar()
## antes do proprio _ready.
func _reequipar(id: String) -> void:
	if id == "":
		return
	if Bolsa.tem(id):
		jogador.equipar(Bolsa.item(id))
	else:
		push_warning("Save: item equipado '%s' nao esta na bolsa — mao vazia" % id)
		jogador.equipar(null)


## Criaturas do jogador: equipe e deposito, com a vida de cada uma. Os atributos nao
## vao para o save, sao recalculados pela seed (CriaturaSalva).
func _colher_criaturas(d: DadosPartida) -> void:
	d.equipe = encontros.equipe.para_salvas(encontros.equipe.ativos)
	d.armazenadas = encontros.equipe.para_salvas(encontros.equipe.deposito)


func _repor_criaturas(d: DadosPartida) -> void:
	var equipe := encontros.equipe
	equipe.ativos.clear()
	equipe.deposito.clear()
	encontros.inventario.colecao.clear()
	_repor_lista(d.equipe, equipe.ativos)
	_repor_lista(d.armazenadas, equipe.deposito)
	# Save de antes da equipe existir: tudo estava em `armazenadas`.
	while equipe.ativos.size() < equipe.maximo and not equipe.deposito.is_empty():
		equipe.promover(0)
	if not equipe.vazia():
		estado_mundo.definir(BANDEIRA_INICIAL)
	equipe.mudou.emit()


func _repor_lista(salvas: Array[CriaturaSalva], destino: Array[Combatente]) -> void:
	for salva: CriaturaSalva in salvas:
		var c := salva.resolver(encontros.bestiario)
		if c == null:
			# Nao derruba a partida: uma criatura que nao resolve veio de um
			# bestiario menor, e perder uma criatura e melhor que recusar o
			# save inteiro. DadosPartida._validar ja barra o caso grave (a
			# seed trocada), que e o unico em que TUDO estaria errado.
			push_warning("Save: criatura #%d nao existe neste bestiario" % salva.id)
			continue
		destino.append(Combatente.de_criatura(c, encontros.tabelas_batalha, salva.hp_atual))
		encontros.inventario.colecao.append(c)


## Nome de exibicao da regiao, para o cartao do slot. Vem do mapa ja carregado —
## o menu nao tem como saber, e e por isso que o nome e gravado no save.
func _nome_da_regiao(id_regiao: String) -> String:
	for r: Dictionary in mundo.dados_das_regioes():
		if String(r.get("id", "")) == id_regiao:
			return String(r.get("nome", ""))
	return ""


## Grava no slot de onde a partida veio (F5). Atalho de teclado para o que o
## menu de pausa oferece em ESC -> SALVAR; os dois chamam o mesmo Save.salvar().
func _salvar_agora() -> void:
	if not Save.em_partida():
		_nota("Sem partida em curso — abra o jogo pelo menu principal.")
		return
	if encontros != null and encontros.estado.em_encontro():
		_nota("Não dá para salvar no meio de um encontro.")
		return
	# A pesca nao tem estado salvo (o lance e curto e a simulacao nao e
	# serializada): gravar no meio dela repoe um jogador livre, sem linha n'agua.
	if pesca != null and pesca.ativa():
		_nota(TEXTO_SEM_SALVAR_PESCA)
		return
	var erro := Save.salvar()
	if erro == "":
		_nota("Partida gravada no slot %d." % Save.slot_atual)
	else:
		_nota("Falha ao salvar: " + erro)


## Menu de pausa (ESC) e, por dentro dele, a bolsa e as opcoes.
##
## Ele PAUSA A ARVORE (get_tree().paused), e nao so congela o jogador como o
## mapa e o dialogo fazem. A diferenca importa: com a arvore correndo, o sorteio
## de encontro do GerenciadorEncontro continua rodando atras do menu, e o
## jogador voltaria de uma pausa de dois minutos para um encontro que comecou
## sem ele. Congelar o personagem resolve o movimento, nao o tempo.
func _montar_pausa() -> void:
	pausa = MenuPausa.new()
	pausa.name = "Pausa"
	add_child(pausa)
	pausa.retomar_pedido.connect(_fechar_pausa)
	pausa.salvar_pedido.connect(_salvar_pela_pausa)
	# Adiado pelo mesmo motivo da tela de desfecho (ver _montar_arco).
	pausa.sair_pedido.connect(_sair_para_o_menu, CONNECT_DEFERRED)
	pausa.usar_item = _usar_item_da_bolsa
	pausa.texto_controles = texto_das_teclas()
	if encontros != null:
		pausa.bestiario = encontros.bestiario
		pausa.capturada = func(c: Criatura) -> bool: return encontros.inventario.ja_capturou(c)
		pausa.tabelas_batalha = encontros.tabelas_batalha
		pausa.tabelas_probabilidade = encontros.tabelas
		pausa.rotulo_seed = Save.partida.seed_legivel() if Save.em_partida() else str(seed_do_mundo)
	if encontros != null:
		pausa.equipe = encontros.equipe
		pausa.catalogo_corpos = encontros.catalogo


## Item usado fora de batalha: vai para quem mais precisa na equipe. O item so e gasto
## se fez algo.
func _usar_item_da_bolsa(item: ItemJogo) -> String:
	if encontros == null or encontros.equipe == null:
		return "Nada para fazer com %s agora." % item.nome
	var alvo := encontros.equipe.alvo_de_efeito(item.efeito)
	if alvo == null:
		return "Ninguém na equipe precisa de %s." % item.nome
	if not Bolsa.remover(item.id):
		return "Acabou: %s." % item.nome
	var ganho := CalculoBatalha.aplicar_efeito(item.efeito, alvo)
	encontros.equipe.mudou.emit()
	return "%s: +%d de vida em %s." % [item.nome, ganho, alvo.nome()]


## ESC e `ui_cancel` ao mesmo tempo: quem ja tem a tela na frente responde
## primeiro, e so entao a pausa. Sem esta ordem, sair de uma conversa com ESC
## abriria o menu de pausa no mesmo quadro. A pesca e a roda consomem o proprio
## ESC; esta checagem e a rede de seguranca para o que nao consome (FISGADO com
## encerrar_ao_fisgar = false, por exemplo).
func _pode_pausar() -> bool:
	return _dono_da_tela() == ""


func _abrir_pausa() -> void:
	if _pode_pausar():
		pausa.abrir()


func _fechar_pausa() -> void:
	pausa.fechar()


func _salvar_pela_pausa() -> void:
	var erro := Save.salvar()
	if erro == "":
		pausa.nota("Partida gravada no slot %d." % Save.slot_atual)
	else:
		pausa.nota("Falha ao salvar: " + erro)


func _sair_para_o_menu() -> void:
	# fechar() antes de trocar de cena: `paused` e da ARVORE, nao da cena, e
	# deixa-lo ligado congelaria o menu principal recem-carregado.
	pausa.fechar()
	Save.encerrar_partida()
	_trocar_de_cena(CENA_MENU)


## Bolsa direto do mundo (B), sem passar pelo menu de pausa. A bolsa e
## consultada o tempo todo — exigir dois menus para ver quantas iscas restam
## faria o jogador parar de consultar.
func _abrir_bolsa() -> void:
	if _pode_pausar():
		pausa.abrir_na_bolsa()


## Pedidos {"servico": ...} do dialogo. O tutorial e a pesca ja existem e sao
## atendidos aqui; loja e missao ainda NAO, e o pedido vira uma nota no HUD.
## Quando existirem, entram NESTE ponto, e nenhuma arvore de dialogo precisa ser
## reescrita — foi exatamente assim que o tutorial entrou.
func _on_servico_pedido(pedido: Dictionary, npc: Npc) -> void:
	var tipo := String(pedido.get("tipo", ""))
	var quem := npc.dados.nome if npc != null else "?"
	match tipo:
		"tutorial":
			# Chega com a caixa do NPC ainda aberta (o servico e drenado ao
			# entrar no no "licao"); o tutorial guarda a primeira conversa e a
			# abre quando esta fechar.
			var id_tutorial := String(pedido.get("tutorial", ""))
			if tutorial == null or not tutorial.iniciar(id_tutorial, npc):
				push_warning("servico tutorial '%s' recusado (pedido por %s)"
						% [id_tutorial, quem])
			return
		"pesca":
			_nota(_dica_de_pesca())
			return
		"escolher_inicial":
			_apos_conversa = _abrir_escolha_inicial
			return
		"loja":
			var id_loja := String(pedido.get("loja", ""))
			_apos_conversa = _abrir_loja.bind(id_loja)
			return
		"curar_equipe":
			encontros.equipe.curar_todos()
			_nota("Equipe recuperada.")
			return
		"duelo":
			var id_guardiao := String(pedido.get("guardiao", ""))
			_apos_conversa = _comecar_duelo.bind(id_guardiao)
			return
	print("servico pedido por %s: %s %s" % [quem, tipo, pedido])
	_nota("(%s ainda nao implementado — pedido por %s)" % [tipo.to_upper(), quem])


func _ao_terminar_conversa(_npc: Npc) -> void:
	if not _apos_conversa.is_valid():
		return
	var pendente := _apos_conversa
	_apos_conversa = Callable()
	pendente.call()


func _abrir_escolha_inicial() -> void:
	if encontros == null or not encontros.equipe.vazia():
		return
	jogador.congelar(true)
	dialogos.suspender(true)
	tela_inicial.abrir(SelecaoBestiario.iniciais(encontros.bestiario, encontros.tabelas_batalha),
			encontros.catalogo, encontros.tabelas_batalha)


func _abrir_loja(id_loja: String) -> void:
	var loja := lojas.loja(id_loja) if lojas != null else {}
	if loja.is_empty():
		push_warning("loja desconhecida: " + id_loja)
		return
	jogador.congelar(true)
	dialogos.suspender(true)
	tela_loja.abrir(loja)


## Metodo, e nao lambda: a Bolsa e autoload e sobrevive a esta cena.
func _ao_mudar_gold(_valor: int) -> void:
	_atualizar_objetivo()


func _ao_escolher_inicial(c: Criatura) -> void:
	encontros.equipe.adicionar(Combatente.de_criatura(c, encontros.tabelas_batalha))
	encontros.inventario.guardar_criatura(c)
	# O kit vem junto: a bolsa comeca vazia, e sem ele a primeira ida ao mato nao
	# teria captura possivel.
	for id: String in Bolsa.economia.kit_inicial():
		Bolsa.adicionar(id, int(Bolsa.economia.kit_inicial()[id]))
	estado_mundo.definir(BANDEIRA_INICIAL)
	jogador.congelar(false)
	dialogos.suspender(false)
	_autosalvar()
	_nota("%s agora anda com você." % c.nome())
	if chegada != null:
		chegada.escolha_feita()


func _comecar_duelo(id_guardiao: String) -> void:
	var guardiao := guardioes.por_id(id_guardiao)
	if guardiao.is_empty():
		push_warning("duelo pedido para guardiao desconhecido: " + id_guardiao)
		return
	if not encontros.pode_comecar():
		_nota("Ninguém de pé na equipe. A Mirela cuida disso, na praça.")
		return
	# Antes da luta: e o ponto para onde a derrota volta.
	_autosalvar()
	_duelo_atual = guardiao
	encontros.iniciar_duelo(guardiao, SelecaoBestiario.equipe_guardiao(encontros.bestiario,
			encontros.tabelas_batalha, guardiao.get("elementos", []),
			int(guardiao.get("tamanho_equipe", 2)), float(guardiao.get("percentil_forca", 0.5))))


## Partida nova (sem posicao gravada e sem a primeira criatura) comeca pela chegada de
## onibus. Precisa de partida: aberta direto pelo editor ou por teste sem Save, a cena
## comeca no spawn, como sempre comecou.
func _talvez_chegar_de_onibus() -> void:
	if not Save.em_partida() or Save.partida.tem_posicao() or mundo.chegada().is_empty():
		return
	if estado_mundo.ativa(BANDEIRA_INICIAL) or encontros == null or not encontros.equipe.vazia():
		return
	chegada = CutsceneChegada.new()
	chegada.name = "Chegada"
	add_child(chegada)
	if not chegada.preparar(mundo, jogador, camera, dialogos):
		push_warning("chegada de onibus desligada: " + chegada.erro)
		chegada.queue_free()
		chegada = null
		return
	if estado_mundo.ativa(String(chegada.dados.get("bandeira", ""))):
		chegada.queue_free()
		chegada = null
		return
	chegada.permissao_pulo = func() -> bool:
		return _dono_da_tela() in ["", "chegada", "dialogo"]
	chegada.escolha_pedida.connect(_ao_chegada_pedir_escolha)
	chegada.terminada.connect(_ao_terminar_chegada)
	_mostrar_hud(false)
	chegada.iniciar()


func _ao_chegada_pedir_escolha() -> void:
	if encontros.equipe.vazia():
		_abrir_escolha_inicial()
	else:
		chegada.escolha_feita()


func _ao_terminar_chegada(_pulada: bool) -> void:
	estado_mundo.definir(String(chegada.dados.get("bandeira", "chegou_de_onibus")))
	_mostrar_hud(true)
	_mostrar_controles_por_um_tempo()
	_atualizar_objetivo()
	_autosalvar()


## Dicas da primeira batalha contra selvagem: uma vez por partida, venha o jogador da
## chegada completa, da chegada pulada ou de um save antigo.
func _preparar_dicas_de_batalha() -> void:
	if encontros == null or estado_mundo == null or estado_mundo.ativa(BANDEIRA_DICAS_BATALHA):
		return
	var dicas: Dictionary = CutsceneChegada.carregar_dados().get("dicas_primeira_batalha", {})
	encontros.dicas_de_estreia = dicas.duplicate()


## Grava sem avisar quando da; sem slot (cena aberta direto) nao faz nada.
func _autosalvar() -> void:
	if Save.em_partida() and Save.slot_atual > 0:
		var erro := Save.salvar()
		if erro != "":
			push_warning("Salvamento automatico falhou: " + erro)


func _objetivo_atual() -> String:
	if encontros == null or encontros.equipe == null or guardioes == null:
		return ""
	if encontros.equipe.vazia():
		return "Fale com a Mirela, na praça da vila"
	if estado_mundo.ativa(BANDEIRA_VENCEU):
		return "Objetivo concluído. Explore à vontade"
	for g: Dictionary in guardioes.guardioes:
		if not estado_mundo.ativa(String(g.get("selo", ""))):
			return "Vença %s, %s" % [String(g.get("nome", "")), String(g.get("onde", ""))]
	return ""


func _texto_da_equipe() -> String:
	if encontros == null or encontros.equipe == null or encontros.equipe.vazia():
		return ""
	return "EQUIPE %d/%d DE PÉ     %d GOLD" % [encontros.equipe.vivos(),
			encontros.equipe.ativos.size(), Bolsa.gold]


## Atualiza o card. Quando o objetivo MUDA, ele pisca: e a unica forma de o jogador
## perceber que a meta andou sem precisar reler o topo da tela.
func _atualizar_objetivo() -> void:
	if _hud_objetivo == null:
		return
	var texto := _objetivo_atual()
	var anterior := _objetivo_mostrado
	_texto_objetivo.text = texto
	_texto_equipe.text = _texto_da_equipe()
	_texto_equipe.visible = _texto_equipe.text != ""
	_hud_objetivo.self_modulate.a = 1.0 if texto != "" else 0.0
	for filho: Node in _hud_objetivo.get_children():
		(filho as CanvasItem).visible = texto != ""
	if texto == "":
		return
	_objetivo_mostrado = texto
	if anterior != "" and texto != anterior:
		_piscar_objetivo()


func _piscar_objetivo() -> void:
	if _tween_objetivo != null and _tween_objetivo.is_valid():
		_tween_objetivo.kill()
	_hud_objetivo.modulate = Color(1.8, 1.6, 1.1)
	_tween_objetivo = create_tween()
	_tween_objetivo.tween_property(_hud_objetivo, "modulate", Color.WHITE, 1.2) \
			.set_trans(Tween.TRANS_SINE)
	_nota("Novo objetivo!")


func _mostrar_vitoria() -> void:
	Som.musica("")
	Som.tocar("vitoria")
	jogador.congelar(true)
	dialogos.suspender(true)
	tela_desfecho.abrir("VITÓRIA", TemaEncontro.OURO, _texto_de_vitoria(), [
		{"id": "continuar", "texto": "CONTINUAR EXPLORANDO"},
		{"id": "menu", "texto": "MENU PRINCIPAL"},
	])


## Os dados da seed: o que este mundo gerou e o quanto isso e coerente contra o sorteio
## independente da mesma seed (RF08). Coerencia por moda, a medida que vale em n=100: a
## informacao mutua exige n >= 5000 (procedural/creatures/README.md).
func _texto_de_vitoria() -> String:
	var n: int = encontros.bestiario.size()
	var ger := GeradorCriaturas.new(encontros.tabelas, encontros.catalogo)
	var cond := MetricasCoerencia.avaliar(encontros.bestiario, encontros.tabelas)
	# O baseline e medido com a regua do modelo desta partida: as duas colunas comparam
	# a mesma coisa.
	var indep := MetricasCoerencia.avaliar(
			ger.gerar_bestiario(seed_do_mundo, n, GeradorCriaturas.Modo.INDEPENDENTE),
			encontros.tabelas, MetricasCoerencia.K_UNICIDADE_PADRAO,
			GeradorCriaturas.nome_do_modo(encontros.modo_gerador))
	var tempo := Save.partida.tempo_legivel() if Save.em_partida() else "—"
	var nome_seed := Save.partida.seed_legivel() if Save.em_partida() else str(seed_do_mundo)
	return ("SEED  %s\nTEMPO  %s\nCAPTURAS  %d de %d criaturas deste mundo\nCRIATURAS DISTINTAS "
			+ " %d\n\nCOERÊNCIA DO BESTIÁRIO\n  esta seed: %.0f%%\n  sorteio independente: %.0f%%") % [
		nome_seed, tempo, encontros.inventario.colecao.size(), n,
		int(cond["unicidade"]["distintas"]),
		_coerencia_media(cond) * 100.0, _coerencia_media(indep) * 100.0]


static func _coerencia_media(metricas: Dictionary) -> float:
	var soma: float = 0.0
	for dim: String in MetricasCoerencia.DIMENSOES_MODA:
		soma += float(metricas["moda"][dim]["obs"])
	return soma / MetricasCoerencia.DIMENSOES_MODA.size()


func _mostrar_derrota() -> void:
	Som.musica("")
	Som.tocar("derrota")
	jogador.congelar(true)
	dialogos.suspender(true)
	var opcoes: Array = []
	if Save.em_partida() and ArquivoSave.slot_valido(Save.slot_atual) \
			and int(ArquivoSave.ler(Save.slot_atual)["estado"]) == ArquivoSave.Estado.OK:
		opcoes.append({"id": "recarregar", "texto": "VOLTAR AO ÚLTIMO SAVE"})
	else:
		opcoes.append({"id": "recarregar", "texto": "RECOMEÇAR"})
	opcoes.append({"id": "menu", "texto": "MENU PRINCIPAL"})
	tela_desfecho.abrir("DERROTA", TemaEncontro.FALHA,
			"Sua equipe inteira caiu.\nNinguém ficou de pé para continuar.", opcoes)


func _ao_escolher_no_desfecho(id: String) -> void:
	match id:
		"continuar":
			Som.musica("vila")
			jogador.congelar(false)
			dialogos.suspender(false)
		"menu":
			_sair_para_o_menu()
		"recarregar":
			if Save.em_partida() and ArquivoSave.slot_valido(Save.slot_atual) \
					and Save.carregar(Save.slot_atual):
				_trocar_de_cena(CENA_MUNDO)
			else:
				get_tree().reload_current_scene()


## Toda saida desta cena passa por aqui, e sempre por chamada adiada: trocar de cena
## dentro do evento de entrada tira a cena da arvore no meio dele, e na build de
## entrega isso derrubava o jogo (ver _montar_arco).
func _trocar_de_cena(caminho: String) -> void:
	get_tree().change_scene_to_file(caminho)


## O que falta para pescar, dito no HUD: vara na mao, vara so na bolsa, ou vara
## nenhuma.
func _dica_de_pesca() -> String:
	if pesca != null and pesca.tem_vara():
		return TEXTO_PESCA_COM_VARA
	if _vara_na_bolsa():
		return TEXTO_PESCA_EQUIPAR
	return TEXTO_PESCA_SEM_VARA


## Ha na bolsa um equipamento que PESCA (uso "pescar")? Nao e
## Bolsa.tem_marcador("pesca"): toda isca de captura tambem carrega esse
## marcador (serve de isca de pesca — ver ItemJogo.de_captura), e com as cinco
## minhocas da carga inicial ele e verdadeiro antes de o jogador ter vara.
func _vara_na_bolsa() -> bool:
	for item: ItemJogo in Bolsa.com_marcador("equipamento"):
		if item.uso == "pescar":
			return true
	return false


## Anuncio de regiao e mapa geral (M).
##
## As duas coisas vivem juntas porque leem o MESMO dado: as regioes declaradas
## pelo mapa. A area avisa a chegada; o EstadoMundo guarda que a regiao foi
## descoberta; o mapa mostra descoberto e nao-descoberto. Nenhuma das tres sabe
## das outras — quem as costura e esta cena.
func _montar_regioes_e_mapa() -> void:
	anuncio = AnuncioRegiao.new()
	anuncio.name = "AnuncioRegiao"
	add_child(anuncio)

	mapa = MapaMundo.new()
	mapa.name = "MapaMundo"
	add_child(mapa)
	mapa.preparar(mundo, estado_mundo)
	mapa.fechado.connect(_ao_fechar_mapa)

	for no in get_tree().get_nodes_in_group("regioes"):
		(no as RegiaoMundo).jogador_entrou.connect(_ao_entrar_na_regiao)

	# A regiao do spawn nao dispara `body_entered` (o jogador ja nasce dentro
	# dela), entao e marcada na mao. Sem isto a vila apareceria como "???" no
	# mapa ate o jogador sair e voltar.
	var inicial := _regiao_da_celula(mundo.mundo_para_celula(jogador.position))
	if inicial != null:
		estado_mundo.visitar(inicial.id_regiao)
		_regiao_corrente = inicial.id_regiao


func _ao_entrar_na_regiao(id_regiao: String) -> void:
	_regiao_corrente = id_regiao
	if not estado_mundo.visitar(id_regiao):
		return
	for r: Dictionary in mundo.dados_das_regioes():
		if String(r.get("id", "")) == id_regiao:
			anuncio.anunciar(String(r.get("nome", "")), String(r.get("descricao", "")))
			return


func _regiao_da_celula(c: Vector2i) -> RegiaoMundo:
	for no in get_tree().get_nodes_in_group("regioes"):
		var r := no as RegiaoMundo
		if r.contem_celula(c):
			return r
	return null


## Abre/fecha o mapa. Congela o jogador e suspende a deteccao de NPC pelo mesmo
## motivo do dialogo: o que esta na frente da tela tem o controle.
func _alternar_mapa() -> void:
	if mapa == null:
		return
	if not mundo.mundo_aberto:
		_nota("Aqui dentro não tem mapa.")
		return
	var dono := _dono_da_tela()
	if dono == "mapa":
		mapa.fechar()
		return
	if dono != "":
		return
	mapa.atualizar_posicao(mundo.mundo_para_celula(jogador.position),
			_regiao_corrente)
	mapa.abrir()
	jogador.congelar(true)
	if dialogos != null:
		dialogos.suspender(true)


func _ao_fechar_mapa() -> void:
	jogador.congelar(false)
	if dialogos != null:
		dialogos.suspender(false)


func _unhandled_input(evento: InputEvent) -> void:
	if evento.is_action_pressed("pausar"):
		_abrir_pausa()
		get_viewport().set_input_as_handled()
		return
	if evento.is_action_pressed("abrir_bestiario"):
		if _pode_pausar():
			pausa.abrir_no_bestiario()
		get_viewport().set_input_as_handled()
		return
	if evento.is_action_pressed("abrir_bolsa"):
		_abrir_bolsa()
		get_viewport().set_input_as_handled()
		return
	if evento.is_action_pressed("abrir_mapa"):
		_alternar_mapa()
		get_viewport().set_input_as_handled()
		return
	# So o PRESSIONAR e daqui; com a roda aberta, ela le o proprio soltar em
	# _input (antes de tudo) e consome as teclas — este ramo nem e alcancado.
	if evento.is_action_pressed("roda_itens"):
		_abrir_roda()
		get_viewport().set_input_as_handled()
		return
	if not (evento is InputEventKey) or not evento.pressed or evento.echo:
		return
	var tecla: Key = (evento as InputEventKey).keycode
	if tecla == KEY_F5:
		_salvar_agora()
		return
	if not teclas_de_desenvolvimento:
		return
	match tecla:
		KEY_F3:
			_depuracao = not _depuracao
			if _sobreposicao != null:
				_sobreposicao.visible = _depuracao
				_sobreposicao.queue_redraw()
		KEY_F2:
			# O visualizador do bestiario deixaria de ser alcancavel ao rodar o
			# projeto quando esta cena virou a principal. Uma tecla o traz de
			# volta sem duplicar nenhuma logica.
			# Adiado: estamos dentro do evento de entrada (ver _montar_arco).
			_trocar_de_cena.call_deferred(CENA_BESTIARIO)
		KEY_F4:
			# Conferir o roteiro do encontro nao pode depender de o sorteio cair no
			# momento em que alguem esta olhando.
			_forcar_encontro()


func _montar_hud() -> void:
	var camada := CanvasLayer.new()
	camada.name = "HUD"
	add_child(camada)
	# HUD na fonte pixel do encontro: o jogo tem UMA tipografia. O contorno da
	# engine nao funciona em fonte de bitmap, entao a legibilidade sobre a grama
	# vem de uma sombra de 2px desenhada por baixo (TemaEncontro.rotulo_sombreado).
	# Controles: no rodape, so nos primeiros segundos. Depois somem e ficam na pausa
	# (ESC): uma linha fixa de teclas no canto lia como sobreposicao de depuracao.
	_hud_dica = _rotulo_de_hud(texto_das_teclas(), Vector2.ZERO)
	_hud_dica.name = "Controles"
	_hud_dica.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_hud_dica.offset_left = 14.0
	_hud_dica.offset_top = -30.0
	camada.add_child(_hud_dica)
	# Quem acabou de passar por uma porta ja viu os controles: eles nao reaparecem.
	if Save.has_meta(META_CHEGADA_POR_PORTA):
		_hud_dica.modulate.a = 0.0
	else:
		_mostrar_controles_por_um_tempo()

	# Nota transitoria: avisos curtos que nao merecem uma caixa (servico ainda
	# nao implementado, regiao descoberta). Some sozinha.
	_hud_nota = _rotulo_de_hud("", Vector2(14, 14))
	camada.add_child(_hud_nota)
	_hud_nota.modulate.a = 0.0

	camada.add_child(_montar_card_objetivo())


## A linha de controles aparece e some depois de SEGUNDOS_DE_CONTROLES. De novo ao fim
## da chegada de onibus: durante a cena o HUD esta escondido, e o tempo teria passado.
func _mostrar_controles_por_um_tempo() -> void:
	if _tween_controles != null and _tween_controles.is_valid():
		_tween_controles.kill()
	_hud_dica.modulate.a = 1.0
	_tween_controles = create_tween()
	_tween_controles.tween_interval(SEGUNDOS_DE_CONTROLES)
	_tween_controles.tween_property(_hud_dica, "modulate:a", 0.0, 1.0)


## O objetivo num card no canto superior direito, com letra maior: e o que diz ao
## jogador para onde este mundo vai, e precisa ser visto sem ser procurado, sem
## cobrir o centro da tela, onde o jogador anda.
func _montar_card_objetivo() -> Control:
	var card := PanelContainer.new()
	card.name = "CardObjetivo"
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_theme_stylebox_override("panel", TemaEncontro.moldura("painel"))
	card.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	card.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	card.offset_right = -10.0
	card.offset_top = 10.0
	card.custom_minimum_size = Vector2(LARGURA_CARD_OBJETIVO, 0)

	var coluna := VBoxContainer.new()
	coluna.add_theme_constant_override("separation", 4)
	coluna.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(coluna)

	coluna.add_child(TemaEncontro.rotulo("★ OBJETIVO", TemaEncontro.OURO, TemaEncontro.Corpo.TITULO))
	_texto_objetivo = TemaEncontro.rotulo("", TemaEncontro.PERG_C, TemaEncontro.Corpo.TITULO)
	_texto_objetivo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_texto_objetivo.custom_minimum_size = Vector2(LARGURA_CARD_OBJETIVO - 28.0, 0)
	coluna.add_child(_texto_objetivo)
	_texto_equipe = TemaEncontro.rotulo("", TemaEncontro.PERG_E)
	coluna.add_child(_texto_equipe)
	_hud_objetivo = card
	return card


func texto_das_teclas() -> String:
	return TEXTO_TECLAS + (TEXTO_TECLAS_DEV if teclas_de_desenvolvimento else "")


## Rotulo do HUD: texto claro sobre uma copia escura deslocada 2px. Devolve o
## container; quem atualiza escreve nos dois Labels por `escrever_hud`.
func _rotulo_de_hud(texto: String, onde: Vector2) -> Control:
	var raiz := Control.new()
	raiz.mouse_filter = Control.MOUSE_FILTER_IGNORE
	raiz.position = onde
	raiz.size = Vector2(720, 16)
	for i in 2:
		var lbl := TemaEncontro.rotulo(texto,
				TemaEncontro.SOMBRA if i == 0 else TemaEncontro.PERG_C)
		lbl.name = "Sombra" if i == 0 else "Frente"
		lbl.position = Vector2(2, 2) if i == 0 else Vector2.ZERO
		raiz.add_child(lbl)
	raiz.set_meta("deslocamento", 2.0)
	return raiz


func _escrever_hud(raiz: Control, texto: String) -> void:
	TemaEncontro.escrever_sombreado(raiz, texto)


## Mensagem curta no HUD, com sumico automatico.
func _nota(texto: String) -> void:
	if _hud_nota == null:
		return
	_escrever_hud(_hud_nota, texto)
	if _tween_nota != null and _tween_nota.is_valid():
		_tween_nota.kill()
	_hud_nota.modulate.a = 1.0
	_tween_nota = create_tween()
	_tween_nota.tween_interval(2.6)
	_tween_nota.tween_property(_hud_nota, "modulate:a", 0.0, 0.5)


func _mostrar_hud(visivel: bool) -> void:
	_hud_visivel = visivel
	for no in [_hud_dica, _hud_nota, _hud_objetivo]:
		if no != null:
			no.visible = visivel
	_ceder_topo_a_dica()


func _on_encontro_terminado(desfecho: String, criatura: Criatura) -> void:
	_mostrar_hud(true)
	_atualizar_objetivo()
	if criatura != null:
		print("Encontro encerrado (%s): %s" % [desfecho, criatura.nome()])
	if _pesca_em_batalha:
		_pesca_em_batalha = false
		pesca.encerrar_ao_fisgar = true
		pesca.encerrar()

	var duelo := _duelo_atual
	_duelo_atual = {}
	# A dica do menu sai do dicionario ao ser mostrada: se saiu, a primeira batalha
	# contra selvagem aconteceu e as dicas nao voltam.
	if encontros != null and not encontros.dicas_de_estreia.is_empty() \
			and not encontros.dicas_de_estreia.has("menu"):
		encontros.dicas_de_estreia = {}
		estado_mundo.definir(BANDEIRA_DICAS_BATALHA)
	RegistroSessao.evento("encontro", {"desfecho": desfecho,
			"criatura": criatura.nome() if criatura != null else "",
			"guardiao": String(duelo.get("id", ""))})
	match desfecho:
		"derrota":
			_mostrar_derrota()
		"derrotada":
			_recompensar_selvagem(criatura)
		"duelo_vencido":
			_ao_vencer_duelo(duelo)


## Gold por derrotar um selvagem, proporcional a forca dele: criatura mais forte que o
## gerador produziu vale mais. Capturar nao paga: e o outro caminho do encontro.
func _recompensar_selvagem(c: Criatura) -> void:
	if c == null or encontros == null:
		return
	var tabelas := encontros.tabelas_batalha
	var forca := FichaCombate.de_criatura(c, tabelas).forca(tabelas)
	var gold := Bolsa.economia.recompensa_selvagem(forca)
	Bolsa.ganhar_gold(gold)
	Som.tocar("moeda")
	_nota("+%d gold" % gold)


func _ao_vencer_duelo(guardiao: Dictionary) -> void:
	var selo := String(guardiao.get("selo", ""))
	# O premio so vem na primeira vitoria: a revanche nao pode virar fonte de gold.
	var premio: int = 0
	if not estado_mundo.ativa(selo):
		premio = int(guardiao.get("premio_gold", 0))
		Bolsa.ganhar_gold(premio)
	estado_mundo.definir(selo)
	Som.tocar("selo")
	if premio > 0:
		_nota("%s entregou o selo e %d gold." % [String(guardiao.get("nome", "")), premio])
	else:
		_nota("%s entregou o selo." % String(guardiao.get("nome", "")))
	if guardioes.venceu_o_jogo(estado_mundo) and not estado_mundo.ativa(BANDEIRA_VENCEU):
		estado_mundo.definir(BANDEIRA_VENCEU)
		RegistroSessao.evento("vitoria", {"seed": seed_do_mundo,
				"modelo": GeradorCriaturas.nome_do_modo(encontros.modo_gerador),
				"capturas": encontros.inventario.colecao.size(),
				"tempo": Save.partida.tempo_legivel() if Save.em_partida() else ""})
		_autosalvar()
		_mostrar_vitoria()
		return
	_autosalvar()


## Encontro imediato na zona mais proxima do jogador (F4).
func _forcar_encontro() -> void:
	if encontros == null or jogador == null:
		return
	# Atalho de depuracao, mas sob a mesma regra: um encontro por cima da pesca
	# ou da roda deixaria dois sistemas congelando e descongelando o jogador.
	if _dono_da_tela() != "":
		return
	if not encontros.pode_comecar():
		_nota("Sem ninguém de pé na equipe.")
		return
	var mais_perto: PontoDeEncontro = null
	var menor: float = INF
	for no in get_tree().get_nodes_in_group("pontos_de_encontro"):
		var ponto := no as PontoDeEncontro
		var d: float = ponto.global_position.distance_to(jogador.global_position)
		if d < menor:
			menor = d
			mais_perto = ponto
	encontros.iniciar(mais_perto)


func _mostrar_erro(mensagem: String) -> void:
	var camada := CanvasLayer.new()
	add_child(camada)
	_aviso = Label.new()
	_aviso.text = "Nao foi possivel montar a vila:\n\n" + mensagem
	_aviso.position = Vector2(24, 24)
	_aviso.add_theme_color_override("font_color", Color("e14b4b"))
	camada.add_child(_aviso)
	push_error("VilaInicial: " + mensagem)


## Sobreposicao de desenvolvimento (F3): mostra o que o mapa PREPAROU e que o
## jogador ainda nao ve — as zonas de encontro, o terreno bloqueado e a grade.
## E o que permite verificar a etapa sem abrir o JSON.
class SobreposicaoDepuracao extends Node2D:
	var mundo: MundoIso

	func _draw() -> void:
		if mundo == null:
			return
		var mx := mundo.celula.x * 0.5
		var my := mundo.celula.y * 0.5

		for gy in mundo.profundidade:
			for gx in mundo.largura:
				var c := Vector2i(gx, gy)
				if not mundo.bloqueia(c):
					continue
				var p := mundo.celula_para_mundo(c)
				draw_colored_polygon(PackedVector2Array([
					p + Vector2(0, -my), p + Vector2(mx, 0),
					p + Vector2(0, my), p + Vector2(-mx, 0)]),
					Color(0.9, 0.2, 0.2, 0.16))

		for no in get_tree().get_nodes_in_group("pontos_de_encontro"):
			var ponto := no as PontoDeEncontro
			var contorno := ponto.poligono()
			for i in contorno.size():
				draw_line(ponto.position + contorno[i],
						ponto.position + contorno[(i + 1) % contorno.size()],
						Color(1.0, 0.85, 0.25), 1.5)
			draw_string(ThemeDB.fallback_font,
					ponto.position + Vector2(-40, -4), ponto.id_ponto,
					HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(1.0, 0.9, 0.4))

		for no in get_tree().get_nodes_in_group("casas"):
			var casa := no as Node2D
			draw_string(ThemeDB.fallback_font, casa.position + Vector2(-30, 0),
					String(casa.get_meta("id", "")), HORIZONTAL_ALIGNMENT_LEFT,
					-1, 10, Color(0.55, 0.9, 1.0))
