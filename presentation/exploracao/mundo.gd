extends Node2D

## Camada 4 — cena da primeira area jogavel (RF05) e do encontro com criaturas.
##
## Monta mundo, jogador, camera, encontro, dialogo, roda de itens, pesca e o
## tutorial do Anselmo, e liga uns aos outros — nenhum deles conhece os demais.
## Continua sem missao; a batalha existe apenas como o golpe que enfraquece a
## criatura dentro do encontro (ver GerenciadorEncontro._atacar), e a pesca para
## na fisgada (ver _ao_fisgar).
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
## Teclas de desenvolvimento:
##   F3   liga/desliga a sobreposicao das zonas de encontro e da grade
##   F2   volta ao visualizador do bestiario (RF07/RF08)
##   F4   forca um encontro na zona mais proxima (nao espera o sorteio)
##   F5   grava a partida no slot de onde ela veio (atalho; o caminho normal e
##        ESC -> SALVAR)

const CENA_BESTIARIO := "res://presentation/bestiario_viewer.tscn"
const CENA_MENU := "res://presentation/menu/menu_principal.tscn"

## Linha de teclas do HUD. Constante (e nao literal em _montar_hud) para o teste
## de integracao conferir os glifos contra a fonte pixel.
const TEXTO_TECLAS := "SETAS/WASD andar   E falar   Q itens  F usar   B bolsa   M mapa   ESC pausa   F3 zonas   F2 bestiário   F4 encontro"

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

var _depuracao: bool = false
var _sobreposicao: SobreposicaoDepuracao
var _aviso: Label
var _hud_dica: Control
var _hud_bolsa: Control
var _hud_nota: Control
var _tween_nota: Tween
var _regiao_corrente: String = ""
## O HUD foi pedido visivel? (_mostrar_hud). Guardado porque as duas linhas de
## cima tambem cedem a dica do tutorial, quadro a quadro (ver _process).
var _hud_visivel: bool = true


func _ready() -> void:
	# Antes de qualquer montagem: o bestiario inteiro depende destes dois numeros.
	if Save.em_partida():
		seed_do_mundo = Save.partida.seed_mundo
		criaturas_por_mundo = Save.partida.criaturas_por_mundo

	mundo = MundoIso.new()
	mundo.name = "Mundo"
	add_child(mundo)
	# Explicito, e nao pelo _ready do proprio MundoIso: e daqui que se conhece a
	# ordem — o jogador e a camera dependem de o mapa ja estar montado.
	mundo.carregar()
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
	_ligar_save()


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
	if not encontros.preparar(mundo, jogador, camera, seed_do_mundo,
			criaturas_por_mundo, Bolsa.inventario):
		_mostrar_erro("encontros: " + encontros.erro)
		return
	# O HUD de exploracao sai de cena durante o encontro: sobreposto a interface
	# escurecida ele vira ruido ilegivel no topo da tela, e a informacao que ele
	# carrega (bolsa) ja aparece dentro da roda, item por item.
	encontros.encontro_iniciado.connect(func(_c): _mostrar_hud(false))
	encontros.encontro_terminado.connect(_on_encontro_terminado)
	encontros.inventario.mudou.connect(func(_id, _n): _atualizar_bolsa())
	encontros.inventario.criatura_guardada.connect(func(_c): _atualizar_bolsa())
	_atualizar_bolsa()


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
	_atualizar_bolsa()


## PONTO DE INTEGRACAO da pesca com a batalha/captura (RF06), que ainda nao
## existem. Hoje: nota no HUD e registro no console. Quando existirem, entram
## AQUI e em mais nenhum lugar: `pesca.encerrar_ao_fisgar = false` em
## _montar_pesca, abrir a batalha/captura com `criatura` e chamar
## `pesca.encerrar()` quando ela acabar — a pesca ja fica parada em FISGADO,
## com o jogador congelado, esperando exatamente por isso.
func _ao_fisgar(criatura: Criatura) -> void:
	if criatura == null:
		return
	print("Pesca: fisgou %s" % criatura)
	_nota(TEXTO_FISGOU % criatura.nome())


## Agua e regiao pela geometria do MAPA. Sao Callable para a pesca: ela nao
## conhece o MundoIso, e a cena de teste (tools/cena_teste_pesca.gd) entrega um
## poligono no lugar.
func _e_agua(p: Vector2) -> bool:
	return mundo.terreno_em(mundo.mundo_para_celula(p)) == "agua"


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
	if pausa != null and pausa.aberto():
		return "pausa"
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


func _process(_delta: float) -> void:
	# O marcador do jogador so precisa acompanhar enquanto a carta esta aberta —
	# e, com o jogador congelado, ele nem se move. Atualizar assim mesmo mantem a
	# tela correta se algo mais mover o personagem (uma teleportacao futura).
	if mapa != null and mapa.aberto() and jogador != null:
		mapa.atualizar_posicao(mundo.mundo_para_celula(jogador.position),
				_regiao_corrente)
	_ceder_topo_a_dica()


## As duas linhas de cima do HUD (teclas e bolsa) dividem o topo da tela com a
## dica do tutorial, que e desenhada por cima delas (camada 92). Com o
## pergaminho la, elas cedem: a dica e a instrucao do momento, e texto correndo
## por tras dela vira ruido. A nota fica — e por ela que chega o "Recebeu: ...",
## e ela e curta o bastante para nao alcancar o painel.
func _ceder_topo_a_dica() -> void:
	var dica_na_tela: bool = tutorial != null and tutorial.dica != null \
			and tutorial.dica.dica_visivel()
	for no: Control in [_hud_dica, _hud_bolsa]:
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
	_atualizar_bolsa()


func _colher_estado(d: DadosPartida) -> void:
	d.estado_mundo = estado_mundo.para_dicionario()


## Secao vazia = partida nova. Repor um dicionario vazio apagaria a visita a
## regiao de spawn que _montar_regioes_e_mapa acabou de registrar.
func _repor_estado(d: DadosPartida) -> void:
	if not d.estado_mundo.is_empty():
		estado_mundo.de_dicionario(d.estado_mundo)


func _colher_jogador(d: DadosPartida) -> void:
	d.mapa = DadosPartida.MAPA_PADRAO
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


## Criaturas capturadas. PROVISORIO ATE A ETAPA 4: hoje existe uma colecao unica
## (InventarioJogador.colecao) e nenhum conceito de time, entao tudo e gravado em
## `armazenadas`. Quando o time ativo existir, esta secao e substituida pela do
## gerenciador de equipe e os saves antigos continuam validos — o deposito e
## exatamente onde uma criatura sem time deve estar.
func _colher_criaturas(d: DadosPartida) -> void:
	d.armazenadas.clear()
	for c: Criatura in encontros.inventario.colecao:
		d.armazenadas.append(CriaturaSalva.de_criatura(c))


func _repor_criaturas(d: DadosPartida) -> void:
	encontros.inventario.colecao.clear()
	for lista: Array in [d.equipe, d.armazenadas]:
		for salva: CriaturaSalva in lista:
			var c := salva.resolver(encontros.bestiario)
			if c == null:
				# Nao derruba a partida: uma criatura que nao resolve veio de um
				# bestiario menor, e perder uma criatura e melhor que recusar o
				# save inteiro. DadosPartida._validar ja barra o caso grave (a
				# seed trocada), que e o unico em que TUDO estaria errado.
				push_warning("Save: criatura #%d nao existe neste bestiario" % salva.id)
				continue
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
	pausa.sair_pedido.connect(_sair_para_o_menu)


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
	get_tree().change_scene_to_file(CENA_MENU)


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
	print("servico pedido por %s: %s %s" % [quem, tipo, pedido])
	_nota("(%s ainda nao implementado — pedido por %s)" % [tipo.to_upper(), quem])


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
	match (evento as InputEventKey).keycode:
		KEY_F3:
			_depuracao = not _depuracao
			if _sobreposicao != null:
				_sobreposicao.visible = _depuracao
				_sobreposicao.queue_redraw()
		KEY_F2:
			# O visualizador do bestiario deixaria de ser alcancavel ao rodar o
			# projeto quando esta cena virou a principal. Uma tecla o traz de
			# volta sem duplicar nenhuma logica.
			get_tree().change_scene_to_file(CENA_BESTIARIO)
		KEY_F4:
			# Conferir o roteiro do encontro nao pode depender de o sorteio cair no
			# momento em que alguem esta olhando.
			_forcar_encontro()
		KEY_F5:
			_salvar_agora()


func _montar_hud() -> void:
	var camada := CanvasLayer.new()
	camada.name = "HUD"
	add_child(camada)
	# HUD na fonte pixel do encontro: o jogo tem UMA tipografia. O contorno da
	# engine nao funciona em fonte de bitmap, entao a legibilidade sobre a grama
	# vem de uma sombra de 2px desenhada por baixo (TemaEncontro.rotulo_sombreado).
	_hud_dica = _rotulo_de_hud(TEXTO_TECLAS, Vector2(14, 10))
	camada.add_child(_hud_dica)

	# Nota transitoria: avisos curtos que nao merecem uma caixa (servico ainda
	# nao implementado, regiao descoberta). Some sozinha.
	_hud_nota = _rotulo_de_hud("", Vector2(14, 46))
	camada.add_child(_hud_nota)
	_hud_nota.modulate.a = 0.0

	# Bolsa: dispositivos, iscas e capturadas. Fica no HUD do mundo, e nao dentro
	# da interface de encontro, porque o estoque e o que decide se vale a pena
	# entrar no mato — informacao de exploracao, nao de menu.
	_hud_bolsa = _rotulo_de_hud("", Vector2(14, 28))
	camada.add_child(_hud_bolsa)


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


## Resumo da bolsa. Le o inventario do gerenciador — nao guarda contagem propria,
## que sairia do ar no primeiro item consumido por outro caminho.
func _atualizar_bolsa() -> void:
	if _hud_bolsa == null or encontros == null or encontros.inventario == null:
		return
	var inv := encontros.inventario
	var dispositivos: int = inv.total_de(encontros.captura.dispositivos)
	var iscas: int = inv.total_de(encontros.captura.iscas)
	var vara: String = "  ·  vara" if _vara_na_bolsa() else ""
	_escrever_hud(_hud_bolsa, "BOLSA  ×%d dispositivos  ·  ×%d iscas%s     CAPTURADAS %d/%d"
			% [dispositivos, iscas, vara, inv.colecao.size(), criaturas_por_mundo])


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
	for no in [_hud_dica, _hud_bolsa, _hud_nota]:
		if no != null:
			no.visible = visivel
	_ceder_topo_a_dica()


func _on_encontro_terminado(desfecho: String, criatura: Criatura) -> void:
	_mostrar_hud(true)
	_atualizar_bolsa()
	if criatura != null:
		print("Encontro encerrado (%s): %s" % [desfecho, criatura.nome()])


## Encontro imediato na zona mais proxima do jogador (F4).
func _forcar_encontro() -> void:
	if encontros == null or jogador == null:
		return
	# Atalho de depuracao, mas sob a mesma regra: um encontro por cima da pesca
	# ou da roda deixaria dois sistemas congelando e descongelando o jogador.
	if _dono_da_tela() != "":
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
