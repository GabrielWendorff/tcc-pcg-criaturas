class_name InterfaceEncontro
extends CanvasLayer

## Tela da batalha: a ficha do adversario de um lado; do outro, o cartao da criatura
## do jogador, o menu de batalha e a mensagem do turno. A roda de selecao fica por
## cima e a animacao do lance no meio. Serve ao encontro selvagem e ao duelo.
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
## calcula chance nem dano. A regra vive em presentation/encontro/regras/ e em
## presentation/batalha/regras/.

enum Acao { GOLPES, CAPTURAR, ISCA, BOLSA, TROCAR, FUGIR }

signal acao_escolhida(acao: Acao)
## Escolha numa lista aberta por abrir_lista (golpes, itens, trocas). `valor` e o que
## o gerenciador pos no item; esta classe nao o interpreta.
signal lista_escolhida(valor: Variant)
signal lista_cancelada()
signal item_escolhido(item: ItemCaptura)
signal roda_cancelada()

## Opcoes do menu, na ordem em que aparecem. Golpes em cima, onde a selecao inicial ja
## esta: e a acao mais comum, e fugir fica por ultimo para nao ser apertado sem querer.
const OPCOES_SELVAGEM := [
	{"acao": Acao.GOLPES, "rotulo": "GOLPES", "dica": "enfraquece, mas se zerar ela foge"},
	{"acao": Acao.CAPTURAR, "rotulo": "CAPTURAR",
		"dica": "escolhe o dispositivo; falhar gasta o turno"},
	{"acao": Acao.ISCA, "rotulo": "OFERECER ISCA", "dica": "atrai pelo animal base; gasta o turno"},
	{"acao": Acao.BOLSA, "rotulo": "BOLSA", "dica": "poções; gasta o turno"},
	{"acao": Acao.TROCAR, "rotulo": "TROCAR", "dica": "outra criatura; gasta o turno"},
	{"acao": Acao.FUGIR, "rotulo": "FUGIR", "dica": "depende da velocidade"},
]
const OPCOES_DUELO := [
	{"acao": Acao.GOLPES, "rotulo": "GOLPES", "dica": "o que o corpo dela sabe fazer"},
	{"acao": Acao.BOLSA, "rotulo": "BOLSA", "dica": "poções; gasta o turno"},
	{"acao": Acao.TROCAR, "rotulo": "TROCAR", "dica": "outra criatura; gasta o turno"},
]

const CAMINHO_VINHETA := "res://arte/ui/vinheta.png"
## A dica fica na faixa livre a esquerda dos paineis: no topo ela cobria o nome da criatura.
const LARGURA_DICA_ESTREIA := 222.0
const MARGEM_DICA_ESTREIA := Vector2(8.0, 72.0)

const LARGURA_FICHA := 306.0
const TAMANHO_RETRATO := 188.0
const LARGURA_MENU := 348.0
const TAMANHO_RETRATO_JOGADOR := 96.0
## Altura reservada ao menu, para 6 opcoes. O menu muda de tamanho entre a raiz, os
## golpes e as trocas; sem reservar, a tela inteira se recentra e a ficha pula.
const ALTURA_MENU := 276.0

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
## Para a linha SORTEIO da ficha: a criatura mostra de onde veio. Opcional.
var tabelas_probabilidade: TabelasProbabilidade
var _titulo: Label
var _subtitulo: Label
var _atributos: RichTextLabel
var _perfil: RichTextLabel
var _medidor_vigor: MedidorChance
var _rotulo_vigor: Label
var _menu: VBoxContainer
var _mensagem: RichTextLabel
var _roda: RodaCaptura
var _cartao_jogador: PanelContainer
var _render_jogador: CreatureSpriteRenderer
var _nome_jogador: Label
var _medidor_jogador: MedidorChance
var _vida_jogador: Label
var _catalogo: CatalogoCorpos
var _tabelas_captura: TabelasCaptura

## Dispositivo desenhado em voo/pousado no quadro. Vive entre animar_lancamento e
## o fim do encontro (ou o lance seguinte).
var _icone_em_voo: Control

var _opcoes: Array[Control] = []
## O que o menu mostra agora: {rotulo, dica, acao} na raiz, {rotulo, dica, valor} numa lista.
var _itens_menu: Array = []
var _opcoes_raiz: Array = OPCOES_SELVAGEM
var _em_lista: bool = false
var _lista_cancelavel: bool = true
var _modo_captura: bool = true
var _indice: int = 0
var _menu_ativo: bool = false

var _criatura: Criatura
var _dica_estreia: PanelContainer
var _dica_estreia_titulo: Label
var _dica_estreia_texto: Label


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
	_montar_dica_estreia()


## Pergaminho a esquerda com a dica da primeira batalha. Acima da roda de proposito: a
## dica da roda e lida com ela aberta.
func _montar_dica_estreia() -> void:
	_dica_estreia = PanelContainer.new()
	_dica_estreia.name = "DicaEstreia"
	_dica_estreia.add_theme_stylebox_override("panel", TemaEncontro.moldura("pergaminho"))
	_dica_estreia.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dica_estreia.offset_left = MARGEM_DICA_ESTREIA.x
	_dica_estreia.offset_right = MARGEM_DICA_ESTREIA.x + LARGURA_DICA_ESTREIA
	_dica_estreia.offset_top = MARGEM_DICA_ESTREIA.y
	_dica_estreia.visible = false
	_raiz.add_child(_dica_estreia)
	var coluna := VBoxContainer.new()
	coluna.add_theme_constant_override("separation", 2)
	coluna.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dica_estreia.add_child(coluna)
	_dica_estreia_titulo = TemaEncontro.rotulo("", TemaEncontro.TINTA, TemaEncontro.Corpo.TITULO)
	coluna.add_child(_dica_estreia_titulo)
	_dica_estreia_texto = TemaEncontro.rotulo("", TemaEncontro.TINTA)
	_dica_estreia_texto.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_dica_estreia_texto.custom_minimum_size = Vector2(LARGURA_DICA_ESTREIA - 32.0, 0)
	coluna.add_child(_dica_estreia_texto)


## Dica da primeira batalha (ver GerenciadorEncontro.dicas_de_estreia). Texto vazio
## esconde.
func mostrar_dica_estreia(titulo: String, texto: String) -> void:
	_dica_estreia_titulo.text = titulo.to_upper()
	_dica_estreia_titulo.visible = titulo != ""
	_dica_estreia_texto.text = texto
	# Sobra de altura do texto anterior: zerar deixa o painel voltar ao minimo.
	_dica_estreia.offset_bottom = _dica_estreia.offset_top
	_dica_estreia.visible = texto != ""


func dica_estreia_visivel() -> bool:
	return _dica_estreia != null and _dica_estreia.visible


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

	_rotulo_vigor = TemaEncontro.rotulo("VIDA", TemaEncontro.PERG_E)
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

	col.add_child(_montar_cartao_jogador())

	_menu = VBoxContainer.new()
	_menu.add_theme_constant_override("separation", 6)
	_menu.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_menu.custom_minimum_size = Vector2(0, ALTURA_MENU)
	col.add_child(_menu)

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


## Cartao da criatura do jogador: retrato, nome e vida. Fica em cima do menu para a
## vida estar a vista na hora de decidir.
func _montar_cartao_jogador() -> Control:
	_cartao_jogador = PanelContainer.new()
	_cartao_jogador.name = "CartaoJogador"
	_cartao_jogador.add_theme_stylebox_override("panel", TemaEncontro.moldura("painel"))
	_cartao_jogador.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cartao_jogador.add_child(h)

	_render_jogador = CreatureSpriteRenderer.new()
	_render_jogador.custom_minimum_size = Vector2(TAMANHO_RETRATO_JOGADOR, TAMANHO_RETRATO_JOGADOR)
	_render_jogador.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(_render_jogador)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 3)
	v.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(v)

	_nome_jogador = TemaEncontro.rotulo("", TemaEncontro.OURO_C)
	v.add_child(_nome_jogador)
	_medidor_jogador = MedidorChance.new(16, false)
	v.add_child(_medidor_jogador)
	_vida_jogador = TemaEncontro.rotulo("", TemaEncontro.PERG_E)
	v.add_child(_vida_jogador)
	return _cartao_jogador


# --- abertura / fechamento --------------------------------------------------

func abrir(criatura: Criatura, catalogo: CatalogoCorpos, tabelas: TabelasCaptura,
		duracao: float, modo_captura: bool = true,
		texto_abertura: String = "Uma criatura selvagem apareceu!") -> void:
	_criatura = criatura
	_catalogo = catalogo
	_tabelas_captura = tabelas
	_modo_captura = modo_captura
	_opcoes_raiz = OPCOES_SELVAGEM if modo_captura else OPCOES_DUELO
	# Reposiciona o retrato ANTES de configurar: uma captura bem-sucedida termina
	# com o renderizador encolhido e transparente (a criatura entrou no
	# dispositivo), e sem este reset o encontro seguinte abriria com o quadro vazio.
	_render.scale = Vector2.ONE
	_render.modulate.a = 1.0
	_limpar_icone()
	_render.configurar(criatura, catalogo)
	_preencher_ficha(criatura, tabelas)
	_mostrar_raiz()
	mensagem(texto_abertura, TemaEncontro.TINTA)
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
	mostrar_dica_estreia("", "")
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
	_atributos.text = ("[color=%s]COR[/color]  paleta %s · matiz "
			+ "%s\n[color=%s]APÊNDICES[/color]  %s") % [
		TemaEncontro.PERG_E.to_html(false), c.paleta, c.matiz,
		TemaEncontro.PERG_E.to_html(false), _lista_de_tracos(c)]
	_atributos.text += _linha_do_sorteio(c)
	if _modo_captura:
		_preencher_perfil(c, tabelas)
	else:
		_perfil.text = ""


## O gerador a vista no meio da batalha: a nota da criatura e os dois derivados que o
## modelo mais esperava para o par (elemento, animal) dela. "E" no bestiario mostra o resto.
func _linha_do_sorteio(c: Criatura) -> String:
	if tabelas_probabilidade == null:
		return ""
	var nota := NotaCoerencia.decompor(c, tabelas_probabilidade, NotaCoerencia.usa_v2(c))
	var bits: float = float(nota["bits"])
	var atipica := NotaCoerencia.atipica(bits, tabelas_probabilidade)
	var destaques: Array = []
	for linha: Dictionary in nota["linhas"]:
		var atributo := String(linha["atributo"])
		if atributo.ends_with(" (modelo)") or String(linha["valor"]) == "não":
			continue
		destaques.append(linha)
	destaques.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a["p"]) > float(b["p"]))
	var partes := PackedStringArray()
	for linha: Dictionary in destaques.slice(0, 2):
		var atributo := String(linha["atributo"])
		var rotulo := String(linha["valor"]) if atributo in ["porte", "paleta", "matiz"] \
				else atributo
		partes.append("%s %d%%" % [rotulo, roundi(float(linha["p"]) * 100.0)])
	var cor := TemaEncontro.FALHA if atipica else TemaEncontro.VERDE
	return "\n[color=%s]SORTEIO[/color]  [color=%s]%s[/color] · %s" % [
		TemaEncontro.PERG_E.to_html(false), cor.to_html(false),
		"ATÍPICA" if atipica else "COERENTE", " · ".join(partes)]


## Troca quem esta na ficha: o proximo do guardiao entrou em campo.
func trocar_adversario(c: Combatente) -> void:
	_criatura = c.criatura
	_render.configurar(c.criatura, _catalogo)
	_preencher_ficha(c.criatura, _tabelas_captura)
	definir_stats(c.ficha)


## Acrescenta os stats derivados a ficha do adversario: o que o corpo dele faz em
## batalha, ao lado do que ele tem.
func definir_stats(f: FichaCombate) -> void:
	_atributos.text += "\n[color=%s]%s[/color]" % [TemaEncontro.PERG_E.to_html(false),
			TextoBatalha.stats(f).replace("\n", "  ")]


func mostrar_jogador(c: Combatente) -> void:
	_render_jogador.configurar(c.criatura, _catalogo)
	_nome_jogador.text = c.nome().to_upper()
	atualizar_jogador(c)


func atualizar_jogador(c: Combatente) -> void:
	_medidor_jogador.valor = c.fracao()
	_vida_jogador.text = "VIDA %d/%d" % [c.vida, c.ficha.vida]


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
	_rotulo_vigor.text = "VIDA  ·  %s" % rotulo.to_upper()


# --- menu -------------------------------------------------------------------

## Refaz os cartoes para a lista dada. O menu muda de tamanho entre a raiz e os golpes,
## entao os cartoes nao sao reaproveitados.
func _construir_menu(itens: Array) -> void:
	for painel: Control in _opcoes:
		_menu.remove_child(painel)
		painel.queue_free()
	_opcoes.clear()
	_itens_menu = itens
	for i in itens.size():
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

		var dica := TemaEncontro.rotulo(String(itens[i].get("dica", "")), TemaEncontro.TEXTO_FRACO)
		dica.name = "Dica"
		linha.add_child(dica)

		_menu.add_child(painel)
		_opcoes.append(painel)


func _mostrar_raiz() -> void:
	_em_lista = false
	_construir_menu(_opcoes_raiz)
	_indice = 0
	_atualizar_menu()


## Volta ao menu de batalha e devolve a entrada ao jogador.
func voltar_ao_menu() -> void:
	_mostrar_raiz()
	menu_ativo(true)


## Mostra uma lista no lugar do menu. `itens`: [{rotulo, dica, valor}]. Sem
## `cancelavel`, o ESC nao sai dela: e a troca obrigatoria.
func abrir_lista(itens: Array, cancelavel: bool = true) -> void:
	_em_lista = true
	_lista_cancelavel = cancelavel
	_construir_menu(itens)
	_indice = 0
	menu_ativo(true)


func _atualizar_menu() -> void:
	for i in _opcoes.size():
		var selecionada: bool = i == _indice and _menu_ativo
		_opcoes[i].add_theme_stylebox_override("panel",
				TemaEncontro.moldura("cartao_selecionado" if selecionada else "cartao"))
		var nome: Label = _opcoes[i].get_node("Linhas/Nome")
		var dica: Label = _opcoes[i].get_node("Linhas/Dica")
		var op: Dictionary = _itens_menu[i]
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
	Som.tocar("ui_mover")
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
		# ESC sai da lista. No menu de batalha nao faz nada: fugir custa o turno e
		# pode falhar, e nao e algo para acontecer por uma tecla de reflexo.
		if _em_lista and _lista_cancelavel:
			_mostrar_raiz()
			menu_ativo(true)
			lista_cancelada.emit()
	elif evento.is_action_pressed("mover_baixo") or evento.is_action_pressed("mover_direita"):
		get_viewport().set_input_as_handled()
		_selecionar(posmod(_indice + 1, _opcoes.size()))
	elif evento.is_action_pressed("mover_cima") or evento.is_action_pressed("mover_esquerda"):
		get_viewport().set_input_as_handled()
		_selecionar(posmod(_indice - 1, _opcoes.size()))


func _confirmar() -> void:
	if not _menu_ativo:
		return
	Som.tocar("ui_confirmar")
	_menu_ativo = false      # trava ate o gerenciador devolver o controle
	_atualizar_menu()
	if _em_lista:
		lista_escolhida.emit(_itens_menu[_indice]["valor"])
	else:
		acao_escolhida.emit(_itens_menu[_indice]["acao"])


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

	Som.tocar("captura_lancar")
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
		Som.tocar("captura_balanco")
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
	Som.tocar("captura_sucesso" if sucesso else "captura_falha")
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


## O golpe que acertou: quem bate da um pulo, quem apanha pisca em branco, sacode e
## mostra o dano subindo. Golpe eficaz pisca mais forte e o numero vem dourado.
func animar_golpe(dano: int, eficaz: bool, no_jogador: bool) -> void:
	var atacante: Control = _render if no_jogador else _render_jogador
	var alvo: Control = _render_jogador if no_jogador else _render
	if atacante != null:
		atacante.pivot_offset = atacante.size * 0.5
		var pulo := create_tween()
		pulo.tween_property(atacante, "scale", Vector2(1.15, 1.15), 0.06)
		pulo.tween_property(atacante, "scale", Vector2.ONE, 0.10)
	if alvo != null:
		var clarao := create_tween()
		clarao.tween_property(alvo, "modulate", Color(2.4, 2.4, 2.4) if eficaz
				else Color(1.8, 1.8, 1.8), 0.05)
		clarao.tween_property(alvo, "modulate", Color.WHITE, 0.12)
		if dano > 0:
			_numero_de_dano(alvo, dano, eficaz)
	await animar_ataque(9.0 if eficaz else 6.0, no_jogador)


func _numero_de_dano(alvo: Control, dano: int, eficaz: bool) -> void:
	var rotulo := TemaEncontro.rotulo("-%d" % dano,
			TemaEncontro.OURO if eficaz else TemaEncontro.PERG_C, TemaEncontro.Corpo.TITULO)
	rotulo.z_index = 10
	_raiz.add_child(rotulo)
	var centro: Vector2 = alvo.get_global_rect().get_center() - _raiz.global_position
	rotulo.position = centro - Vector2(18.0, 10.0)
	var sobe := create_tween()
	sobe.set_parallel(true)
	sobe.tween_property(rotulo, "position:y", rotulo.position.y - 34.0, 0.6) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	sobe.tween_property(rotulo, "modulate:a", 0.0, 0.6).set_delay(0.25)
	sobe.chain().tween_callback(rotulo.queue_free)


## Sacode quem levou o golpe: a ficha do adversario ou o cartao do jogador.
func animar_ataque(intensidade: float, no_jogador: bool = false) -> void:
	var alvo: Control = _cartao_jogador if no_jogador else _ficha
	var origem: Vector2 = alvo.position
	var t := create_tween()
	for i in 3:
		var lado: float = intensidade if i % 2 == 0 else -intensidade
		t.tween_property(alvo, "position", origem + Vector2(lado, 0.0), 0.05)
	t.tween_property(alvo, "position", origem, 0.05)
	await t.finished
