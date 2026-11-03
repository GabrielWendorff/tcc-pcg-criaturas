class_name InterfaceEncontro
extends CanvasLayer

## Tela do encontro: a ficha da criatura de um lado, o menu de acoes do outro, a
## roda de selecao por cima e a animacao do lance no meio.
##
## PROFUNDIDADE — tres planos, e e o que organiza a leitura:
##   fundo      o mundo, escurecido pela transicao e fechado pela VINHETA
##   meio       a ficha da criatura e o menu
##   frente     a roda, quando aberta (e af o meio recua: ver _recuar_meio)
##
## A vinheta e o que transforma "uma janela por cima do jogo" em "o jogo entrou
## num estado especial". Ela e uma textura tramada de 192x108 ampliada 6x — nao um
## gradiente: um degrade liso no meio de uma tela de pixel art denuncia a
## interface como estranha ao jogo.
##
## Reaproveita o que ja existia em vez de recriar: CreatureSpriteRenderer desenha
## a criatura (a MESMA classe do bestiario) e PaletaCriatura da a cor de destaque,
## derivada de (matiz, paleta). A navegacao usa mover_cima/mover_baixo — as acoes
## do andar — mais ui_accept/ui_cancel, nativas da engine.
##
## Esta classe nao decide NADA de mecanica: nao sorteia, nao consome item, nao
## calcula chance. Toda a regra vive em presentation/encontro/regras/.

enum Acao { ABANDONAR, ISCA, ATACAR, CAPTURAR }

signal acao_escolhida(acao: Acao)
signal item_escolhido(item: ItemCaptura)
signal roda_cancelada()

## Opcoes do menu, na ordem em que aparecem. A ordem e deliberada: a saida fica no
## topo (e onde o olho procura por ela) e a acao mais provavel, embaixo, onde a
## selecao inicial ja esta. "Oferecer isca" e a quarta acao alem das tres do
## roteiro: a camada de isca precisa de um gesto proprio, e cobrar uma isca por
## arremesso a tornaria cara demais para ser usada.
const OPCOES := [
	{"acao": Acao.ABANDONAR, "rotulo": "ABANDONAR", "dica": "sair do encontro"},
	{"acao": Acao.ISCA, "rotulo": "OFERECER ISCA", "dica": "atrai pelo animal base"},
	{"acao": Acao.ATACAR, "rotulo": "ATACAR", "dica": "enfraquece, mas arrisca a fuga"},
	{"acao": Acao.CAPTURAR, "rotulo": "TENTAR CAPTURAR", "dica": "escolhe o dispositivo"},
]

const CAMINHO_VINHETA := "res://arte/ui/vinheta.png"

const LARGURA_FICHA := 306.0
const TAMANHO_RETRATO := 188.0
const LARGURA_MENU := 348.0

## Quanto o plano do meio recua quando a roda abre.
const RECUO_MEIO := 0.34

## Opacidade da vinheta. Ela SOMA com o escurecimento da transicao, e as duas
## juntas em forca cheia apagavam a vila por completo — o encontro tem de
## acontecer num lugar reconhecivel, nao numa tela preta.
const FORCA_VINHETA := 0.62

var _raiz: Control
var _vinheta: TextureRect
var _meio: Control
var _ficha: PanelContainer
var _moldura_retrato: PanelContainer
var _render: CreatureSpriteRenderer
var _titulo: Label
var _subtitulo: Label
var _atributos: RichTextLabel
var _perfil: RichTextLabel
var _medidor_vigor: MedidorChance
var _rotulo_vigor: Label
var _menu: VBoxContainer
var _mensagem: RichTextLabel
var _roda: RodaCaptura

## Dispositivo desenhado em voo/pousado no quadro. Vive entre animar_lancamento e
## o fim do encontro (ou o lance seguinte).
var _icone_em_voo: Control

var _opcoes: Array[Control] = []
var _indice: int = 0
var _menu_ativo: bool = false

var _criatura: Criatura


func _ready() -> void:
	_montar()
	visible = false


# --- construcao -------------------------------------------------------------

func _montar() -> void:
	_raiz = Control.new()
	_raiz.name = "Raiz"
	_raiz.set_anchors_preset(Control.PRESET_FULL_RECT)
	_raiz.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_raiz)

	_vinheta = TextureRect.new()
	_vinheta.name = "Vinheta"
	_vinheta.texture = load(CAMINHO_VINHETA)
	_vinheta.set_anchors_preset(Control.PRESET_FULL_RECT)
	_vinheta.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_vinheta.stretch_mode = TextureRect.STRETCH_SCALE
	_vinheta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_raiz.add_child(_vinheta)

	_meio = Control.new()
	_meio.name = "Meio"
	_meio.set_anchors_preset(Control.PRESET_FULL_RECT)
	_meio.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_raiz.add_child(_meio)

	var centro := CenterContainer.new()
	centro.set_anchors_preset(Control.PRESET_FULL_RECT)
	centro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_meio.add_child(centro)

	var linha := HBoxContainer.new()
	linha.add_theme_constant_override("separation", 22)
	linha.mouse_filter = Control.MOUSE_FILTER_IGNORE
	centro.add_child(linha)

	linha.add_child(_montar_ficha())
	linha.add_child(_montar_coluna_acoes())

	_roda = RodaCaptura.new()
	_roda.name = "Roda"
	_roda.escolhido.connect(func(item): item_escolhido.emit(item))
	_roda.cancelado.connect(func(): roda_cancelada.emit())
	_raiz.add_child(_roda)


func _montar_ficha() -> Control:
	_ficha = PanelContainer.new()
	_ficha.name = "Ficha"
	_ficha.custom_minimum_size = Vector2(LARGURA_FICHA, 0)
	_ficha.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ficha.add_theme_stylebox_override("panel", TemaEncontro.moldura("painel"))

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 7)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ficha.add_child(v)

	_titulo = TemaEncontro.rotulo("", TemaEncontro.OURO_C, TemaEncontro.Corpo.TITULO)
	v.add_child(_titulo)

	_subtitulo = TemaEncontro.rotulo("", TemaEncontro.PERG_E)
	v.add_child(_subtitulo)

	# Moldura dourada do retrato: e o unico elemento da ficha com moldura propria,
	# porque a criatura e o assunto da tela.
	_moldura_retrato = PanelContainer.new()
	_moldura_retrato.add_theme_stylebox_override("panel",
			TemaEncontro.moldura("painel_ouro"))
	_moldura_retrato.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_moldura_retrato.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(_moldura_retrato)

	_render = CreatureSpriteRenderer.new()
	_render.custom_minimum_size = Vector2(TAMANHO_RETRATO, TAMANHO_RETRATO)
	_render.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_render.pivot_offset = Vector2(TAMANHO_RETRATO, TAMANHO_RETRATO) * 0.5
	_moldura_retrato.add_child(_render)

	v.add_child(_montar_vigor())

	_atributos = TemaEncontro.texto_rico()
	v.add_child(_atributos)

	_perfil = TemaEncontro.texto_rico()
	v.add_child(_perfil)

	return _ficha


func _montar_vigor() -> Control:
	var caixa := VBoxContainer.new()
	caixa.add_theme_constant_override("separation", 2)
	caixa.mouse_filter = Control.MOUSE_FILTER_IGNORE

	_rotulo_vigor = TemaEncontro.rotulo("VIGOR", TemaEncontro.PERG_E)
	caixa.add_child(_rotulo_vigor)

	_medidor_vigor = MedidorChance.new(12, true)
	_medidor_vigor.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	caixa.add_child(_medidor_vigor)
	return caixa


func _montar_coluna_acoes() -> Control:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	col.custom_minimum_size = Vector2(LARGURA_MENU, 0)
	col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE

	_menu = VBoxContainer.new()
	_menu.add_theme_constant_override("separation", 6)
	_menu.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(_menu)

	for i in OPCOES.size():
		var painel := PanelContainer.new()
		painel.add_theme_stylebox_override("panel", TemaEncontro.moldura("cartao"))
		painel.mouse_filter = Control.MOUSE_FILTER_STOP
		painel.gui_input.connect(_on_opcao_input.bind(i))
		painel.mouse_entered.connect(func(): _selecionar(i))

		var linha := VBoxContainer.new()
		# Nomeado: sem nome explicito o no recebe "@VBoxContainer@NNN" e o
		# get_node("Linhas/Nome") de _atualizar_menu nao acha nada.
		linha.name = "Linhas"
		linha.add_theme_constant_override("separation", 1)
		linha.mouse_filter = Control.MOUSE_FILTER_IGNORE
		painel.add_child(linha)

		var nome := TemaEncontro.rotulo("", TemaEncontro.PERG_C)
		nome.name = "Nome"
		linha.add_child(nome)

		var dica := TemaEncontro.rotulo(String(OPCOES[i]["dica"]), TemaEncontro.TEXTO_FRACO)
		dica.name = "Dica"
		linha.add_child(dica)

		_menu.add_child(painel)
		_opcoes.append(painel)

	# Caixa de mensagem em PERGAMINHO: e a voz do jogo, e precisa se distinguir
	# das acoes (madeira escura) sem competir com a criatura (moldura dourada).
	var caixa_msg := PanelContainer.new()
	caixa_msg.add_theme_stylebox_override("panel", TemaEncontro.moldura("pergaminho"))
	caixa_msg.custom_minimum_size = Vector2(0, 66)
	caixa_msg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(caixa_msg)

	_mensagem = TemaEncontro.texto_rico()
	_mensagem.add_theme_color_override("default_color", TemaEncontro.TINTA)
	caixa_msg.add_child(_mensagem)

	return col


# --- abertura / fechamento --------------------------------------------------

func abrir(criatura: Criatura, catalogo: CatalogoCorpos, tabelas: TabelasCaptura,
		duracao: float) -> void:
	_criatura = criatura
	# Reposiciona o retrato ANTES de configurar: uma captura bem-sucedida termina
	# com o renderizador encolhido e transparente (a criatura entrou no
	# dispositivo), e sem este reset o encontro seguinte abriria com o quadro vazio.
	_render.scale = Vector2.ONE
	_render.modulate.a = 1.0
	_limpar_icone()
	_render.configurar(criatura, catalogo)
	_preencher_ficha(criatura, tabelas)
	_indice = OPCOES.size() - 1     # "Tentar capturar": a acao esperada por padrao
	_atualizar_menu()
	mensagem("Uma criatura selvagem apareceu!", TemaEncontro.TINTA)
	visible = true
	_meio.modulate = Color.WHITE
	_raiz.modulate.a = 0.0
	_vinheta.modulate.a = 0.0
	_meio.scale = Vector2(0.97, 0.97)
	# Pivo pelo viewport e nao por _meio.size: na primeira abertura a CanvasLayer
	# acaba de sair de invisivel e o Control ainda nao foi dimensionado — o pivo
	# em (0,0) transformaria a entrada de escala num deslize a partir do canto.
	_meio.pivot_offset = get_viewport().get_visible_rect().size * 0.5
	var t := create_tween()
	t.set_parallel(true)
	t.tween_property(_raiz, "modulate:a", 1.0, duracao)
	t.tween_property(_vinheta, "modulate:a", FORCA_VINHETA, duracao * 1.6)
	t.tween_property(_meio, "scale", Vector2.ONE, duracao) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await t.finished


func fechar(duracao: float) -> void:
	_menu_ativo = false
	_limpar_icone()
	var t := create_tween()
	t.tween_property(_raiz, "modulate:a", 0.0, duracao)
	await t.finished
	visible = false


## Liga/desliga a leitura de entrada do menu. Desligado durante lancamento,
## ataque e roda — e o que garante que so um lance esteja em curso.
func menu_ativo(ligado: bool) -> void:
	_menu_ativo = ligado
	_atualizar_menu()


func mensagem(texto: String, cor: Color = TemaEncontro.TINTA) -> void:
	# Mensagem sobre pergaminho: as cores de estado da paleta clara sao escuras o
	# bastante para ler sobre bege; as claras (PERG_C) sumiriam.
	var pintada: Color = cor
	if cor == TemaEncontro.TEXTO or cor == TemaEncontro.PERG_C:
		pintada = TemaEncontro.TINTA
	elif cor == TemaEncontro.TEXTO_APOIO:
		pintada = TemaEncontro.TINTA_C
	elif cor == TemaEncontro.SUCESSO:
		pintada = Color("2e6a2e")
	elif cor == TemaEncontro.FALHA:
		pintada = Color("9c2f2b")
	elif cor == TemaEncontro.ATENCAO:
		pintada = Color("8a5a12")
	_mensagem.text = "[color=%s]%s[/color]" % [pintada.to_html(false), texto]


# --- ficha ------------------------------------------------------------------

func _preencher_ficha(c: Criatura, tabelas: TabelasCaptura) -> void:
	_titulo.text = c.nome().to_upper()
	_subtitulo.text = "%s + %s  ·  %s" % [c.elemento, c.animal_base, c.porte]
	_atributos.text = "[color=%s]COR[/color]  paleta %s · matiz %s\n[color=%s]APÊNDICES[/color]  %s" % [
		TemaEncontro.PERG_E.to_html(false), c.paleta, c.matiz,
		TemaEncontro.PERG_E.to_html(false), _lista_de_tracos(c)]
	_preencher_perfil(c, tabelas)


func _lista_de_tracos(c: Criatura) -> String:
	var presentes: Array = c.features_presentes()
	if presentes.is_empty():
		return "[color=%s]nenhum[/color]" % TemaEncontro.TEXTO_FRACO.to_html(false)
	return ", ".join(presentes)


## Leitura de CAPTURA da criatura: quais tracos a defendem e quanto. E a ponte
## visivel entre o modelo generativo e a mecanica — o jogador ve que a criatura e
## dificil PELO QUE ELA TEM, e o que ela tem veio da tabela condicionada ao par
## (animal, elemento).
func _preencher_perfil(c: Criatura, tabelas: TabelasCaptura) -> void:
	var perfil := AfinidadeCriatura.perfil(c, tabelas)
	var apoio := TemaEncontro.PERG_E.to_html(false)
	var fraco := TemaEncontro.TEXTO_FRACO.to_html(false)
	var linhas := PackedStringArray(["[color=%s]DEFESAS[/color]" % apoio])
	var tracos: Array = perfil["tracos"]
	if tracos.is_empty():
		linhas.append("  [color=%s]nenhuma — presa fácil[/color]" % fraco)
	else:
		for t: Dictionary in tracos:
			linhas.append("  %s [color=%s]×%.2f  %s[/color]"
					% [t["traco"], fraco, t["fator"], t["motivo"]])
	linhas.append("[color=%s]evasão total ×%.2f[/color]"
			% [fraco, float(perfil["evasao"])])
	_perfil.text = "\n".join(linhas)


func atualizar_vigor(fracao: float, rotulo: String) -> void:
	var f: float = clampf(fracao, 0.0, 1.0)
	_medidor_vigor.valor = f
	_rotulo_vigor.text = "VIGOR  ·  %s" % rotulo.to_upper()


# --- menu -------------------------------------------------------------------

func _atualizar_menu() -> void:
	for i in _opcoes.size():
		var selecionada: bool = i == _indice and _menu_ativo
		_opcoes[i].add_theme_stylebox_override("panel",
				TemaEncontro.moldura("cartao_selecionado" if selecionada else "cartao"))
		var nome: Label = _opcoes[i].get_node("Linhas/Nome")
		var dica: Label = _opcoes[i].get_node("Linhas/Dica")
		var op: Dictionary = OPCOES[i]
		nome.text = ("▶ " if selecionada else "   ") + String(op["rotulo"])
		var cor: Color = TemaEncontro.TEXTO_FRACO
		if _menu_ativo:
			cor = TemaEncontro.OURO_C if selecionada else TemaEncontro.PERG_C
		nome.add_theme_color_override("font_color", cor)
		dica.add_theme_color_override("font_color",
				TemaEncontro.PERG_E if selecionada and _menu_ativo
				else TemaEncontro.TEXTO_FRACO)


func _selecionar(i: int) -> void:
	if not _menu_ativo or i == _indice or i < 0 or i >= _opcoes.size():
		return
	_indice = i
	_atualizar_menu()


func _on_opcao_input(evento: InputEvent, i: int) -> void:
	if not _menu_ativo:
		return
	if evento is InputEventMouseButton and evento.pressed \
			and evento.button_index == MOUSE_BUTTON_LEFT:
		_indice = i
		_atualizar_menu()
		_confirmar()


func _unhandled_input(evento: InputEvent) -> void:
	if not _menu_ativo:
		return
	if evento.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		_confirmar()
	elif evento.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		# Esc no menu e abandonar: e a saida que o jogador procura primeiro.
		_menu_ativo = false
		acao_escolhida.emit(Acao.ABANDONAR)
	elif evento.is_action_pressed("mover_baixo") or evento.is_action_pressed("mover_direita"):
		get_viewport().set_input_as_handled()
		_selecionar(posmod(_indice + 1, _opcoes.size()))
	elif evento.is_action_pressed("mover_cima") or evento.is_action_pressed("mover_esquerda"):
		get_viewport().set_input_as_handled()
		_selecionar(posmod(_indice - 1, _opcoes.size()))


func _confirmar() -> void:
	if not _menu_ativo:
		return
	_menu_ativo = false      # trava ate o gerenciador devolver o controle
	_atualizar_menu()
	acao_escolhida.emit(OPCOES[_indice]["acao"])


# --- roda -------------------------------------------------------------------

func abrir_roda(titulo: String, itens: Array, inventario: InventarioJogador,
		ficha_de: Callable, duracao: float) -> void:
	_recuar_meio(true, duracao)
	await _roda.abrir(titulo, itens, inventario, ficha_de, duracao)


func fechar_roda(duracao: float = -1.0) -> void:
	_recuar_meio(false, 0.16)
	if duracao < 0.0:
		await _roda.fechar()
	else:
		await _roda.fechar(duracao)


## Empurra ficha e menu para o plano do meio enquanto a roda esta aberta. Sem
## isto, tres blocos de informacao disputam o mesmo primeiro plano e a tela vira
## ruido — que era o problema da versao anterior.
func _recuar_meio(recuado: bool, duracao: float) -> void:
	var t := create_tween()
	t.tween_property(_meio, "modulate",
			Color(RECUO_MEIO, RECUO_MEIO, RECUO_MEIO, 1.0) if recuado else Color.WHITE,
			maxf(duracao, 0.08))


# --- animacoes do lance -----------------------------------------------------

## Voo do dispositivo ate a criatura e os balancos. Bloqueia ate terminar; o
## resultado JA foi sorteado antes de chamar (o desenho nunca decide a mecanica).
func animar_lancamento(dispositivo: DispositivoCaptura, cfg: ConfiguracaoEncontro) -> void:
	var alvo: Vector2 = _render.get_global_rect().get_center()
	var icone := IconeCaptura.new(dispositivo.id, 2)
	icone.size = Vector2(40, 40)
	icone.pivot_offset = icone.size * 0.5
	icone.position = Vector2(alvo.x - 20.0, _raiz.size.y - 70.0)
	_raiz.add_child(icone)

	var voo := create_tween()
	voo.set_parallel(true)
	voo.tween_property(icone, "position", alvo - icone.size * 0.5, cfg.duracao_lancamento) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	voo.tween_property(icone, "rotation", TAU, cfg.duracao_lancamento)
	await voo.finished

	# A criatura entra no dispositivo: encolhe no ponto do impacto.
	var sugada := create_tween()
	sugada.set_parallel(true)
	sugada.tween_property(_render, "scale", Vector2(0.05, 0.05), 0.18) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	sugada.tween_property(_render, "modulate:a", 0.0, 0.18)
	await sugada.finished

	for i in cfg.balancos:
		var b := create_tween()
		var amplitude: float = 0.35
		b.tween_property(icone, "rotation", amplitude, cfg.duracao_balanco * 0.34) \
				.set_trans(Tween.TRANS_SINE)
		b.tween_property(icone, "rotation", -amplitude, cfg.duracao_balanco * 0.34) \
				.set_trans(Tween.TRANS_SINE)
		b.tween_property(icone, "rotation", 0.0, cfg.duracao_balanco * 0.32) \
				.set_trans(Tween.TRANS_SINE)
		await b.finished
	_icone_em_voo = icone


## Desfecho: ou o dispositivo se fecha em luz, ou a criatura volta para a arena.
func animar_desfecho(sucesso: bool, cfg: ConfiguracaoEncontro) -> void:
	var icone := _icone_em_voo
	_icone_em_voo = null
	var t := create_tween()
	if sucesso:
		t.set_parallel(true)
		if icone != null:
			# Repousa GRANDE dentro da moldura: e o troféu do encontro, e ele
			# ocupa o lugar que a criatura ocupava.
			t.tween_property(icone, "scale", Vector2(2.2, 2.2),
					cfg.duracao_desfecho * 0.4) \
					.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		# A moldura do retrato pisca em dourado: e o brilho da captura, feito com
		# a propria moldura em vez de um halo desfocado.
		t.tween_property(_moldura_retrato, "modulate",
				Color(1.7, 1.6, 1.1), cfg.duracao_desfecho * 0.3)
		await t.finished
		var volta_cor := create_tween()
		volta_cor.tween_property(_moldura_retrato, "modulate", Color.WHITE,
				cfg.duracao_desfecho * 0.3)
	else:
		if icone != null:
			t.set_parallel(true)
			t.tween_property(icone, "scale", Vector2(1.9, 1.9), cfg.duracao_desfecho * 0.3)
			t.tween_property(icone, "modulate:a", 0.0, cfg.duracao_desfecho * 0.3)
			await t.finished
		var volta := create_tween()
		volta.set_parallel(true)
		volta.tween_property(_render, "scale", Vector2.ONE, cfg.duracao_desfecho * 0.35) \
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		volta.tween_property(_render, "modulate:a", 1.0, cfg.duracao_desfecho * 0.35)
		await volta.finished
	if sucesso:
		# Na captura o dispositivo FICA no quadro ate o encontro fechar: some-lo
		# deixaria a moldura vazia justamente no instante em que ela precisa
		# mostrar onde a criatura foi parar.
		_icone_em_voo = icone
	elif icone != null:
		icone.queue_free()


## Remove o dispositivo que tenha sobrado na tela de um lance anterior.
func _limpar_icone() -> void:
	if _icone_em_voo != null:
		_icone_em_voo.queue_free()
		_icone_em_voo = null


## Reacao da criatura ao que acabou de acontecer com ela.
##
## Um pulinho quando a isca e a preferida, um encolhimento quando nao e. Custa
## quatro linhas e responde, sem texto, a pergunta que o jogador acabou de fazer
## ao mundo: "ela gostou?". A mensagem no pergaminho diz a mesma coisa por
## escrito; ver as duas juntas e o que faz a escolha da isca parecer uma
## conversa com a criatura em vez de uma soma de bonus.
func animar_reacao(positiva: bool) -> void:
	var t := create_tween()
	if positiva:
		t.tween_property(_render, "position:y", _render.position.y - 10.0, 0.12) \
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		t.tween_property(_render, "position:y", _render.position.y, 0.16) \
				.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	else:
		t.tween_property(_render, "scale", Vector2(0.92, 0.92), 0.10)
		t.tween_property(_render, "scale", Vector2.ONE, 0.14) \
				.set_trans(Tween.TRANS_SINE)
	await t.finished


## Sacode a ficha da criatura — resposta visivel do golpe, sem sistema de batalha.
func animar_ataque(intensidade: float) -> void:
	var origem: Vector2 = _ficha.position
	var t := create_tween()
	for i in 3:
		var lado: float = intensidade if i % 2 == 0 else -intensidade
		t.tween_property(_ficha, "position", origem + Vector2(lado, 0.0), 0.05)
	t.tween_property(_ficha, "position", origem, 0.05)
	await t.finished
