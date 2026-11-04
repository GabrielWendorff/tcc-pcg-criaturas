class_name PainelSlots
extends Control

## Os tres slots de save, lado a lado, como cartoes.
##
## POR QUE TRES CARTOES E NAO UMA LISTA. Um slot nao e uma opcao de menu: e um
## mundo. O que distingue um do outro — a seed, a regiao, quantas criaturas, ha
## quanto tempo — e informacao de varias linhas, e uma lista vertical de rotulos
## de uma linha nao a comporta. Como o trabalho e sobre reprodutibilidade por
## seed (RF03), a SEED e o primeiro campo do cartao, em dourado: e ela que diz
## qual mundo esta ali, e dois slots com a mesma seed sao o mesmo mundo em dois
## momentos.
##
## O MESMO PAINEL SERVE AOS DOIS CAMINHOS. Em CONTINUAR so slot gravado e
## alcancavel; em NOVO todos sao, e o ocupado avisa que sera sobrescrito. Ter uma
## tela de "escolher onde carregar" e outra de "escolher onde gravar" seria o
## mesmo desenho duas vezes, divergindo na primeira correcao.
##
## SAVE DANIFICADO E CARTAO, NAO CAIXA DE ERRO. Um JSON truncado aparece como um
## cartao vermelho com o motivo escrito, ao lado dos outros. O jogador ve o que
## houve, ve que os demais estao intactos, e pode apagar aquele (Delete) ou
## comecar por cima dele. Uma caixa de erro modal na abertura do jogo diria menos
## e assustaria mais.
##
## Entrada: esquerda/direita (mover_* e ui_*), ui_accept/interagir confirma,
## ui_cancel volta, Delete apaga (com confirmacao no proprio cartao). Mouse
## seleciona ao passar e confirma no clique, como MenuEscolhas.

signal escolhido(slot: int)
signal cancelado()
signal apagado(slot: int)

enum Modo {
	CONTINUAR,  ## so slots carregaveis sao alcancaveis
	NOVO,       ## todos sao; o ocupado avisa que sera sobrescrito
}

const LARGURA_CARTAO := 300.0
const ALTURA_CARTAO := 212.0
const SEPARACAO := 20

var modo: Modo = Modo.CONTINUAR

var _linha: HBoxContainer
var _cartoes: Array[PanelContainer] = []
var _corpos: Array[VBoxContainer] = []
var _resumos: Array = []
var _indice: int = 0
var _ativo: bool = false
## Slot aguardando confirmacao de apagar. 0 = nenhum.
var _confirmando: int = 0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	var centro := CenterContainer.new()
	centro.name = "Centro"
	centro.set_anchors_preset(Control.PRESET_FULL_RECT)
	centro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(centro)

	_linha = HBoxContainer.new()
	_linha.name = "Linha"
	_linha.add_theme_constant_override("separation", SEPARACAO)
	_linha.mouse_filter = Control.MOUSE_FILTER_IGNORE
	centro.add_child(_linha)
	visible = false


## Mostra os slots. `resumos` sao os dicionarios de Save.resumos().
func abrir(resumos: Array, modo_: Modo) -> void:
	modo = modo_
	_resumos = resumos
	_confirmando = 0
	_reconstruir()
	_indice = maxi(0, _vizinho_alcancavel(-1, 1))
	_ativo = _vizinho_alcancavel(-1, 1) >= 0
	visible = true
	_pintar()


func fechar() -> void:
	_ativo = false
	visible = false
	_confirmando = 0


func ativo() -> bool:
	return _ativo


## Redesenha com resumos novos, preservando a selecao. Usado depois de apagar:
## reabrir do zero jogaria o cursor de volta ao primeiro cartao.
func atualizar(resumos: Array) -> void:
	var antes := _indice
	_resumos = resumos
	_reconstruir()
	_indice = antes if antes < _cartoes.size() else 0
	if not _alcancavel(_indice):
		_indice = maxi(0, _vizinho_alcancavel(_indice, 1))
	_ativo = _vizinho_alcancavel(-1, 1) >= 0
	_pintar()


# ---------------------------------------------------------------- construcao

## Refaz os tres cartoes. `remove_child` ANTES de `queue_free`, e nao so
## queue_free: a liberacao e diferida ate o fim do quadro, e um HBoxContainer com
## os cartoes velhos e os novos ao mesmo tempo distribui espaco para seis e
## encolhe todos pela metade por um quadro.
func _reconstruir() -> void:
	for c: PanelContainer in _cartoes:
		_linha.remove_child(c)
		c.queue_free()
	_cartoes.clear()
	_corpos.clear()
	for i in _resumos.size():
		var cartao := PanelContainer.new()
		cartao.name = "Slot%d" % (i + 1)
		cartao.custom_minimum_size = Vector2(LARGURA_CARTAO, ALTURA_CARTAO)
		cartao.mouse_filter = Control.MOUSE_FILTER_STOP
		cartao.mouse_entered.connect(_selecionar.bind(i))
		cartao.gui_input.connect(_ao_clicar.bind(i))

		var margem := MarginContainer.new()
		margem.name = "Margem"
		for lado in ["left", "right", "top", "bottom"]:
			margem.add_theme_constant_override("margin_" + lado, 14)
		margem.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cartao.add_child(margem)

		var corpo := VBoxContainer.new()
		corpo.name = "Corpo"
		corpo.add_theme_constant_override("separation", 5)
		corpo.mouse_filter = Control.MOUSE_FILTER_IGNORE
		margem.add_child(corpo)

		_linha.add_child(cartao)
		_cartoes.append(cartao)
		_corpos.append(corpo)
		_preencher(i)


## Conteudo de um cartao. Reconstruido inteiro a cada mudanca de estado: sao
## cinco rotulos, e manter referencias para cada campo de cada cartao custaria
## mais codigo do que refaze-los.
func _preencher(i: int) -> void:
	var corpo := _corpos[i]
	for filho in corpo.get_children():
		corpo.remove_child(filho)
		filho.queue_free()
	var r: Dictionary = _resumos[i]
	var slot: int = int(r.get("slot", i + 1))

	var cabecalho := TemaEncontro.rotulo("SLOT %d" % slot, TemaEncontro.OURO,
			TemaEncontro.Corpo.TITULO)
	cabecalho.name = "Cabecalho"
	corpo.add_child(cabecalho)
	corpo.add_child(_regua())

	if _confirmando == slot:
		_preencher_confirmacao(corpo)
		return
	match int(r.get("estado", ArquivoSave.Estado.VAZIO)):
		ArquivoSave.Estado.OK:
			_preencher_gravado(corpo, r)
		ArquivoSave.Estado.DANIFICADO:
			_preencher_danificado(corpo, r)
		_:
			_preencher_vazio(corpo)


func _preencher_gravado(corpo: VBoxContainer, r: Dictionary) -> void:
	var d: DadosPartida = r["dados"]
	# A seed primeiro e em dourado: e o que identifica o MUNDO, e identidade de
	# mundo e o tema do trabalho. Data e tempo jogado vem por ultimo, apagados.
	corpo.add_child(_campo("SEED", d.seed_legivel(), TemaEncontro.OURO_C))
	corpo.add_child(TemaEncontro.rotulo(d.lugar_legivel(), TemaEncontro.PERG_C))
	corpo.add_child(_campo("CRIATURAS", "%d / %d"
			% [d.total_de_criaturas(), d.criaturas_por_mundo], TemaEncontro.PERG))
	corpo.add_child(_campo("TEMPO", d.tempo_legivel(), TemaEncontro.PERG))
	var data := d.data_legivel()
	if data != "":
		corpo.add_child(TemaEncontro.rotulo(data, TemaEncontro.TEXTO_FRACO))
	if bool(r.get("do_backup", false)):
		# Nao e enfeite: o jogador tem de saber que o save mais novo se perdeu e
		# que o que esta ali e o anterior.
		corpo.add_child(TemaEncontro.rotulo("recuperado do backup",
				TemaEncontro.ATENCAO))


func _preencher_vazio(corpo: VBoxContainer) -> void:
	var vazio := TemaEncontro.rotulo("— VAZIO —", TemaEncontro.TEXTO_FRACO)
	vazio.name = "Vazio"
	vazio.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vazio.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vazio.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vazio.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	corpo.add_child(vazio)


func _preencher_danificado(corpo: VBoxContainer, r: Dictionary) -> void:
	corpo.add_child(TemaEncontro.rotulo("— DANIFICADO —", TemaEncontro.VERMELHO))
	var motivo := TemaEncontro.rotulo(String(r.get("erro", "")), TemaEncontro.TEXTO_FRACO)
	motivo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	motivo.custom_minimum_size = Vector2(LARGURA_CARTAO - 34.0, 0)
	motivo.size_flags_vertical = Control.SIZE_EXPAND_FILL
	corpo.add_child(motivo)
	corpo.add_child(TemaEncontro.rotulo("DEL apaga", TemaEncontro.ATENCAO))


func _preencher_confirmacao(corpo: VBoxContainer) -> void:
	var pergunta := TemaEncontro.rotulo("APAGAR ESTE SLOT?", TemaEncontro.VERMELHO_C)
	pergunta.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pergunta.custom_minimum_size = Vector2(LARGURA_CARTAO - 34.0, 0)
	pergunta.size_flags_vertical = Control.SIZE_EXPAND_FILL
	corpo.add_child(pergunta)
	corpo.add_child(TemaEncontro.rotulo("E / ENTER  confirma", TemaEncontro.PERG_C))
	corpo.add_child(TemaEncontro.rotulo("ESC  cancela", TemaEncontro.TEXTO_FRACO))


## Linha "RÓTULO  valor". Rotulo apagado, valor em destaque: e o contraste que
## permite varrer tres cartoes procurando um numero sem ler as etiquetas.
func _campo(rotulo: String, valor: String, cor: Color) -> HBoxContainer:
	var linha := HBoxContainer.new()
	linha.add_theme_constant_override("separation", 6)
	linha.mouse_filter = Control.MOUSE_FILTER_IGNORE
	linha.add_child(TemaEncontro.rotulo(rotulo, TemaEncontro.TEXTO_FRACO))
	linha.add_child(TemaEncontro.rotulo(valor, cor))
	return linha


func _regua() -> Control:
	var r := ColorRect.new()
	r.name = "Regua"
	r.color = TemaEncontro.MADEIRA_C
	r.custom_minimum_size = Vector2(0, 1)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


# ----------------------------------------------------------------- navegacao

## Um slot so e alcancavel em CONTINUAR quando ha o que carregar nele. Em NOVO
## todos sao: gravar por cima de um save ruim e justamente como o jogador se
## livra dele.
func _alcancavel(i: int) -> bool:
	if i < 0 or i >= _resumos.size():
		return false
	if modo == Modo.NOVO:
		return true
	return int(_resumos[i].get("estado", ArquivoSave.Estado.VAZIO)) == ArquivoSave.Estado.OK


func _vizinho_alcancavel(de: int, passo: int) -> int:
	var n: int = _resumos.size()
	if n == 0:
		return -1
	for salto in range(1, n + 1):
		var i: int = posmod(de + passo * salto, n)
		if _alcancavel(i):
			return i
	return -1


func _selecionar(i: int) -> void:
	if not _ativo or i == _indice or not _alcancavel(i):
		return
	# Mover o cursor cancela uma confirmacao pendente: confirmar o apagamento de
	# um cartao enquanto se olha para outro seria a pior forma de perder um save.
	var cancelou: bool = _confirmando != 0
	_confirmando = 0
	_indice = i
	# So reconstroi quando o CONTEUDO mudou. Mudanca de selecao e cor de moldura,
	# e refazer quinze rotulos a cada tecla de seta seria lixo por quadro.
	if cancelou:
		_reconstruir()
	_pintar()


func _pintar() -> void:
	for i in _cartoes.size():
		var alcancavel := _alcancavel(i)
		var selecionado: bool = i == _indice and alcancavel
		var moldura := "cartao"
		if not alcancavel:
			moldura = "cartao_desativado"
		elif selecionado:
			moldura = "cartao_selecionado"
		_cartoes[i].add_theme_stylebox_override("panel", TemaEncontro.moldura(moldura))
		_cartoes[i].modulate.a = 1.0 if alcancavel else 0.55


func _ao_clicar(evento: InputEvent, i: int) -> void:
	if not _ativo or not _alcancavel(i):
		return
	if evento is InputEventMouseButton and evento.pressed \
			and (evento as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		_indice = i
		_pintar()
		_confirmar()


## Entrada do painel. Como em MenuEscolhas, e chamada pelo dono da tela e nao por
## um _unhandled_input proprio: um so no le a entrada por vez.
func tratar_entrada(evento: InputEvent) -> bool:
	if not _ativo:
		return false
	if evento.is_action_pressed("ui_accept") or evento.is_action_pressed("interagir"):
		_confirmar()
		return true
	if evento.is_action_pressed("ui_cancel"):
		if _confirmando != 0:
			_confirmando = 0
			_reconstruir()
			_pintar()
		else:
			cancelado.emit()
		return true
	if evento.is_action_pressed("mover_direita") or evento.is_action_pressed("ui_right"):
		_selecionar(_vizinho_alcancavel(_indice, 1))
		return true
	if evento.is_action_pressed("mover_esquerda") or evento.is_action_pressed("ui_left"):
		_selecionar(_vizinho_alcancavel(_indice, -1))
		return true
	if evento is InputEventKey and evento.pressed and not evento.echo \
			and (evento as InputEventKey).keycode == KEY_DELETE:
		_pedir_apagar()
		return true
	return false


## Delete pede confirmacao NO PROPRIO CARTAO, em vez de abrir uma caixa modal.
## Apagar e irreversivel e merece o passo a mais; uma janela por cima do menu
## para duas palavras seria desenho novo para uma pergunta de sim ou nao.
func _pedir_apagar() -> void:
	var slot := _slot_do_indice()
	if slot == 0:
		return
	var estado := int(_resumos[_indice].get("estado", ArquivoSave.Estado.VAZIO))
	if estado == ArquivoSave.Estado.VAZIO:
		return  # nao ha o que apagar
	_confirmando = slot
	_reconstruir()
	_pintar()


func _confirmar() -> void:
	if not _ativo:
		return
	var slot := _slot_do_indice()
	if slot == 0:
		return
	if _confirmando == slot:
		_confirmando = 0
		apagado.emit(slot)
		return
	escolhido.emit(slot)


func _slot_do_indice() -> int:
	if _indice < 0 or _indice >= _resumos.size():
		return 0
	return int(_resumos[_indice].get("slot", _indice + 1))


## Estado do slot selecionado, para o rodape da tela avisar "vai sobrescrever".
func estado_selecionado() -> int:
	if _indice < 0 or _indice >= _resumos.size():
		return ArquivoSave.Estado.VAZIO
	return int(_resumos[_indice].get("estado", ArquivoSave.Estado.VAZIO))
