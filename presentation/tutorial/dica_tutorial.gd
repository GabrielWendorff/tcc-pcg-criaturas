class_name DicaTutorial
extends CanvasLayer

## O que o tutorial poe na tela FORA da caixa de dialogo: a dica do passo
## corrente, o aviso de que da para pular e a pergunta "Tem certeza?".
##
## TRES PECAS, TRES LUGARES:
##   dica      painel de pergaminho no TOPO-CENTRO. O pergaminho e a VOZ do jogo
##             (mesma convencao da caixa de dialogo e do encontro): a dica e o
##             Anselmo falando por escrito enquanto o jogador tem as maos ocupadas.
##             Fica no topo porque o rodape e da caixa de fala e o centro e do
##             que se esta aprendendo — o arco do arremesso e o corte da agua. O
##             minigame de pesca reserva os ~90 px de cima justamente para ela.
##   aviso     cartao de madeira pequeno no canto superior direito: "[P] pular
##             licao". Madeira porque e uma ACAO, nao uma fala.
##   pergunta  modal no centro, com o MESMO MenuEscolhas do dialogo — um segundo
##             estilo de menu diria que este momento vem de outro sistema.
##
## PAUSA. Quem pausa a arvore e o GerenciadorTutorial; este no roda com
## PROCESS_MODE_ALWAYS para continuar respondendo a teclado e mouse com tudo
## parado atras. E a mesma solucao do MenuPausa, e pelo mesmo motivo: com a
## arvore correndo, a pesca continuaria puxando a linha durante a pergunta.
##
## Nao sabe o que e um tutorial: recebe textos prontos e devolve um sinal.

signal resposta_pulo(confirmou: bool)

## Acima da roda de itens (88) e da interface de pesca (84) — a dica tem de ser
## lida DURANTE as duas —, abaixo do mapa (95), da pausa (96) e da bolsa (97),
## que tomam a tela inteira quando abertas.
const CAMADA := 92

## Largura do painel de dica. Fixa pelo mesmo motivo do MenuEscolhas: um painel
## que muda de largura a cada passo faz o olho perder o lugar do texto.
@export var largura_painel: float = 560.0
@export var margem_topo: float = 8.0
@export var margem_canto: float = 10.0
## Entrada e saida da dica, em segundos. Curta: a dica responde a uma acao do
## jogador e tem de estar la quando ele olhar.
@export var duracao_fade: float = 0.18
## Quanto a dica desce ao aparecer. O movimento e o que avisa "mudou o passo"
## quando o texto novo tem o mesmo tamanho do antigo.
@export var deslize: float = 6.0
## Escurecimento atras da pergunta (0 = nenhum). O jogo pausado continua visivel:
## o jogador decide sabendo onde parou.
@export var escurecer_fundo: float = 0.45

var _raiz: Control
var _painel: PanelContainer
var _titulo: Label
var _texto: Label
var _aviso: PanelContainer
var _rotulo_aviso: Label
var _modal: Control
var _menu: MenuEscolhas
var _tween_dica: Tween
var _perguntando: bool = false
var _dica_ativa: bool = false
var _modo_mouse_antes: Input.MouseMode = Input.MOUSE_MODE_VISIBLE
## Indice da opcao "sim" na lista da pergunta (ver perguntar_pulo).
var _indice_sim: int = 1


func _init() -> void:
	layer = CAMADA
	process_mode = Node.PROCESS_MODE_ALWAYS


func _ready() -> void:
	_montar()


func _montar() -> void:
	if _raiz != null:
		return
	_raiz = Control.new()
	_raiz.name = "Raiz"
	_raiz.set_anchors_preset(Control.PRESET_FULL_RECT)
	_raiz.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_raiz)

	# --- dica: pergaminho no topo-centro ---
	_painel = PanelContainer.new()
	_painel.name = "Dica"
	_painel.add_theme_stylebox_override("panel", TemaEncontro.moldura("pergaminho"))
	_painel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_painel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_painel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_painel.offset_left = -largura_painel * 0.5
	_painel.offset_right = largura_painel * 0.5
	_painel.offset_top = margem_topo
	_painel.offset_bottom = margem_topo
	_painel.visible = false
	_raiz.add_child(_painel)

	var coluna := VBoxContainer.new()
	coluna.add_theme_constant_override("separation", 3)
	coluna.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_painel.add_child(coluna)

	# Titulo em tinta clara e caixa alta, e nao na folha 2x: a fonte de titulo
	# tem 22 px e comeria um quarto da faixa reservada no topo.
	_titulo = TemaEncontro.rotulo("", TemaEncontro.TINTA_C)
	_titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	coluna.add_child(_titulo)

	# Label e nao RichTextLabel: a dica fala de teclas entre colchetes ("[Q]"),
	# e o BBCode leria isso como marcacao.
	_texto = TemaEncontro.rotulo("", TemaEncontro.TINTA)
	_texto.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_texto.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# Largura util = painel menos as margens de conteudo da moldura (13 + 13).
	_texto.custom_minimum_size = Vector2(largura_painel - 26.0, 0)
	coluna.add_child(_texto)

	# --- aviso: cartao no canto superior direito ---
	_aviso = PanelContainer.new()
	_aviso.name = "AvisoPulo"
	_aviso.add_theme_stylebox_override("panel", TemaEncontro.moldura("cartao"))
	_aviso.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_aviso.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_aviso.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_aviso.offset_right = -margem_canto
	_aviso.offset_left = -margem_canto
	_aviso.offset_top = margem_topo
	_aviso.offset_bottom = margem_topo
	_aviso.visible = false
	_rotulo_aviso = TemaEncontro.rotulo("", TemaEncontro.TEXTO_APOIO)
	_aviso.add_child(_rotulo_aviso)
	_raiz.add_child(_aviso)

	# --- pergunta: modal no centro ---
	_modal = Control.new()
	_modal.name = "Pergunta"
	_modal.set_anchors_preset(Control.PRESET_FULL_RECT)
	# STOP: um clique fora das opcoes nao pode atravessar para a interface de
	# pesca ou para a caixa de dialogo que estao embaixo.
	_modal.mouse_filter = Control.MOUSE_FILTER_STOP
	_modal.visible = false
	_raiz.add_child(_modal)

	var fundo := ColorRect.new()
	fundo.name = "Fundo"
	fundo.color = Color(TemaEncontro.NOITE_E, escurecer_fundo)
	fundo.set_anchors_preset(Control.PRESET_FULL_RECT)
	fundo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_modal.add_child(fundo)

	var centro := CenterContainer.new()
	centro.set_anchors_preset(Control.PRESET_FULL_RECT)
	centro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_modal.add_child(centro)

	_menu = MenuEscolhas.new()
	_menu.name = "Escolhas"
	# Aqui o menu E o conteudo da tela: quem o posiciona e o CenterContainer, e
	# nao a conta de "crescer para cima a partir da caixa de fala".
	_menu.ancorar_acima = false
	centro.add_child(_menu)
	_menu.escolhido.connect(_ao_escolher)
	_menu.cancelado.connect(_ao_cancelar)


# -------------------------------------------------------------------- dica
func mostrar_dica(titulo: String, texto: String) -> void:
	_montar()
	_titulo.text = titulo
	_titulo.visible = titulo != ""
	_texto.text = texto
	# Sobra de altura de um texto mais longo anterior: sem zerar, o painel nao
	# encolhe quando a dica nova tem uma linha so. Altura zero e o container volta
	# a crescer ate o minimo do conteudo, para baixo (grow_vertical padrao).
	_painel.offset_bottom = _painel.offset_top
	_painel.visible = true
	_dica_ativa = true
	_parar_tween()
	_painel.modulate.a = 0.0
	_painel.position.y = margem_topo - deslize
	_tween_dica = create_tween()
	_tween_dica.set_parallel(true)
	_tween_dica.tween_property(_painel, "modulate:a", 1.0, duracao_fade)
	_tween_dica.tween_property(_painel, "position:y", margem_topo, duracao_fade * 1.6) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func esconder_dica() -> void:
	_montar()
	_dica_ativa = false
	if not _painel.visible:
		return
	_parar_tween()
	_tween_dica = create_tween()
	_tween_dica.tween_property(_painel, "modulate:a", 0.0, duracao_fade)
	_tween_dica.tween_callback(func() -> void: _painel.visible = false)


## Ha uma dica em vigor (mostrada e nao escondida). Para teste e para a cena
## decidir o que mais cabe no topo da tela.
func dica_visivel() -> bool:
	return _dica_ativa


func _parar_tween() -> void:
	if _tween_dica != null and _tween_dica.is_valid():
		_tween_dica.kill()


# ------------------------------------------------------------------- aviso
func mostrar_aviso_pulo(texto: String, visivel: bool) -> void:
	_montar()
	_rotulo_aviso.text = texto
	_aviso.visible = visivel and texto != ""
	# Largura zero e o cartao cresce para a ESQUERDA (grow BEGIN) ate o minimo do
	# texto novo. reset_size() faria o contrario: manteria a borda esquerda e
	# empurraria o cartao para fora da tela.
	_aviso.offset_left = _aviso.offset_right
	_aviso.offset_bottom = _aviso.offset_top


# ---------------------------------------------------------------- pergunta
## Abre a confirmacao. "Nao" vem PRIMEIRO, e e onde o cursor nasce: um ENTER
## dado sem ler (o mesmo dedo que acabou de apertar P) nao pode jogar a licao
## fora. E ESC, como em todo menu do projeto, e a saida — aqui, "nao".
func perguntar_pulo(pergunta: String, sim: String, nao: String) -> void:
	_montar()
	if _perguntando:
		return
	if not _menu.is_inside_tree():
		# MenuEscolhas monta os proprios nos no _ready; fora da arvore nao ha
		# o que abrir. Sem a pergunta, ninguem pausa nada (ver o gerenciador).
		push_warning("DicaTutorial: pergunta pedida fora da arvore de cena")
		return
	_indice_sim = 1
	_menu.abrir([{"texto": nao}, {"texto": sim}], pergunta)
	_modal.visible = true
	_perguntando = true
	# A pergunta responde ao mouse, e quem estava no meio do recolhimento pode
	# estar com o cursor escondido pela interface de pesca.
	_modo_mouse_antes = Input.mouse_mode
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func perguntando() -> bool:
	return _perguntando


## Fecha a pergunta SEM responder. Para quando a decisao vem por outro caminho
## (GerenciadorTutorial.pular() chamado por codigo com a pergunta aberta).
func fechar_pergunta() -> void:
	if not _perguntando:
		return
	_perguntando = false
	_menu.fechar()
	_modal.visible = false
	Input.mouse_mode = _modo_mouse_antes


func _ao_escolher(indice: int) -> void:
	if not _perguntando:
		return
	var confirmou := indice == _indice_sim
	fechar_pergunta()
	resposta_pulo.emit(confirmou)


func _ao_cancelar() -> void:
	if not _perguntando:
		return
	fechar_pergunta()
	resposta_pulo.emit(false)


## _input e nao _unhandled_input: com a pergunta aberta, esta camada e a dona
## da entrada, antes de qualquer outra. O menu recebe a navegacao; o resto do
## teclado e do controle e engolido — o jogo esta pausado e nenhuma tecla deve
## chegar a quem acordar depois. O MOUSE passa: os cliques nas opcoes chegam
## pelo gui_input dos cartoes, que vem depois desta fase.
func _input(evento: InputEvent) -> void:
	if not _perguntando:
		return
	if _menu.tratar_entrada(evento):
		get_viewport().set_input_as_handled()
		return
	if evento is InputEventKey or evento is InputEventJoypadButton \
			or evento is InputEventJoypadMotion:
		get_viewport().set_input_as_handled()
