class_name MenuEscolhas
extends Control

## Menu de escolhas do dialogo: a lista navegavel que aparece quando a conversa
## ramifica.
##
## MESMA LINGUAGEM DO MENU DE ENCONTRO, de proposito — cartoes 9-slice de madeira,
## cartao dourado no selecionado, fonte bitmap, navegacao por mover_cima/baixo +
## ui_accept. Um segundo estilo de menu no mesmo jogo seria a interface dizendo
## que estes dois momentos vem de sistemas diferentes, e eles nao vem.
##
## Entrada aceita: teclado (setas/WASD), mouse (passar o cursor seleciona, clique
## confirma) e controle (o mesmo ui_accept/ui_cancel, mais os botoes ligados a
## mover_* e a `interagir` em project.godot).
##
## Nao conhece dialogo: recebe uma lista de {texto, dica} e devolve um indice.
## A chave opcional `ativo: false` desenha a opcao apagada e a navegacao a pula —
## e o que o menu principal usa para "Continuar" sem nenhum save no disco.

signal escolhido(indice: int)
signal cancelado()

## Largura do bloco. Fixa para que o menu nao "respire" entre um no de opcoes
## curtas e outro de opcoes longas — a caixa muda de tamanho, o olho perde o
## lugar da lista.
const LARGURA := 360.0

## Encaixa o bloco PELA BASE (ver _encaixar_acima). Verdadeiro no dialogo, onde o
## menu tem de crescer para cima a partir da caixa de fala; falso quando o menu e
## o conteudo principal da tela e quem posiciona e o container do pai.
var ancorar_acima: bool = true

var _coluna: VBoxContainer
var _pergunta: PanelContainer
var _rotulo_pergunta: Label
var _lista: VBoxContainer
var _cartoes: Array[PanelContainer] = []
var _habilitados: Array[bool] = []
var _indice: int = 0
var _ativo: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(LARGURA, 0)
	_coluna = VBoxContainer.new()
	var col := _coluna
	col.name = "Coluna"
	col.add_theme_constant_override("separation", 8)
	col.set_anchors_preset(Control.PRESET_FULL_RECT)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(col)

	_pergunta = PanelContainer.new()
	_pergunta.name = "Pergunta"
	_pergunta.add_theme_stylebox_override("panel", TemaEncontro.moldura("pergaminho"))
	_pergunta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pergunta.visible = false
	_rotulo_pergunta = TemaEncontro.rotulo("", TemaEncontro.TINTA)
	_pergunta.add_child(_rotulo_pergunta)
	col.add_child(_pergunta)

	_lista = VBoxContainer.new()
	_lista.name = "Lista"
	_lista.add_theme_constant_override("separation", 5)
	_lista.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(_lista)
	visible = false


## Mostra as opcoes. `escolhas` sao os dicionarios de NoDialogo.escolhas_para().
func abrir(escolhas: Array, pergunta: String = "") -> void:
	_limpar()
	_rotulo_pergunta.text = pergunta
	_pergunta.visible = pergunta != ""
	for i in escolhas.size():
		var e: Dictionary = escolhas[i]
		var cartao := PanelContainer.new()
		cartao.name = "Escolha%d" % i
		cartao.add_theme_stylebox_override("panel", TemaEncontro.moldura("cartao"))
		cartao.mouse_filter = Control.MOUSE_FILTER_STOP
		cartao.mouse_entered.connect(_selecionar.bind(i))
		cartao.gui_input.connect(_ao_clicar.bind(i))

		var linha := HBoxContainer.new()
		linha.name = "Linha"
		linha.add_theme_constant_override("separation", 6)
		linha.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cartao.add_child(linha)

		# O cursor e um caractere, nao um deslocamento do texto: mover a opcao
		# para a direita quando ela e selecionada faz a lista inteira tremer a
		# cada tecla. O '▶' esta na fonte do projeto.
		var seta := TemaEncontro.rotulo("▶", TemaEncontro.OURO)
		seta.name = "Seta"
		linha.add_child(seta)

		_habilitados.append(bool(e.get("ativo", true)))

		var texto := TemaEncontro.rotulo(String(e.get("texto", "")), TemaEncontro.PERG)
		texto.name = "Texto"
		texto.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		texto.custom_minimum_size = Vector2(LARGURA - 46.0, 0)
		linha.add_child(texto)

		_lista.add_child(cartao)
		_cartoes.append(cartao)
	_indice = maxi(0, _vizinho_habilitado(-1, 1))
	_ativo = _indice >= 0 and _habilitados.has(true)
	visible = true
	_pintar()
	_encaixar_acima()


## Sobe o bloco para que a BASE dele fique na posicao pedida pela caixa.
##
## Um Control ancorado ao rodape tem altura ZERO ate alguem lhe dar uma: sem esta
## conta, o VBox cresce para BAIXO a partir da linha de base e as opcoes caem por
## cima da caixa de fala — que e exatamente onde elas nao podem estar, porque e
## onde esta o texto que a pergunta responde.
func _encaixar_acima() -> void:
	var altura: float = _coluna.get_combined_minimum_size().y
	custom_minimum_size = Vector2(LARGURA, altura)
	if ancorar_acima:
		offset_top = offset_bottom - altura


func fechar() -> void:
	_ativo = false
	visible = false
	_limpar()


func ativo() -> bool:
	return _ativo


func _limpar() -> void:
	for c: PanelContainer in _cartoes:
		c.queue_free()
	_cartoes.clear()
	_habilitados.clear()


func _selecionar(i: int) -> void:
	if not _ativo or i == _indice or i < 0 or i >= _cartoes.size():
		return
	if not _habilitados[i]:
		return
	_indice = i
	_pintar()


## Proximo indice habilitado a partir de `de`, andando em `passo`. Devolve -1 se
## nao houver nenhum. Da a volta na lista, mas no maximo uma: sem o limite, uma
## lista inteiramente apagada giraria para sempre.
func _vizinho_habilitado(de: int, passo: int) -> int:
	var n: int = _cartoes.size()
	if n == 0:
		return -1
	for salto in range(1, n + 1):
		var i: int = posmod(de + passo * salto, n)
		if _habilitados[i]:
			return i
	return -1


func _pintar() -> void:
	for i in _cartoes.size():
		var habilitado: bool = _habilitados[i]
		var selecionado: bool = i == _indice and habilitado
		var moldura := "cartao"
		if not habilitado:
			moldura = "cartao_desativado"
		elif selecionado:
			moldura = "cartao_selecionado"
		_cartoes[i].add_theme_stylebox_override("panel", TemaEncontro.moldura(moldura))
		var linha: HBoxContainer = _cartoes[i].get_node("Linha")
		(linha.get_node("Seta") as Label).modulate.a = 1.0 if selecionado else 0.0
		var texto := linha.get_node("Texto") as Label
		# Mesma leitura do cartao indisponivel da roda de captura: a opcao
		# continua visivel (saber que ela existe e informacao) e claramente fora
		# de alcance. Esconde-la faria a lista mudar de tamanho conforme o save.
		texto.add_theme_color_override("font_color",
				TemaEncontro.TEXTO_FRACO if not habilitado
				else (TemaEncontro.PERG_C if selecionado else TemaEncontro.PERG_E))


func _ao_clicar(evento: InputEvent, i: int) -> void:
	if not _ativo or not _habilitados[i]:
		return
	if evento is InputEventMouseButton and evento.pressed \
			and (evento as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		_indice = i
		_pintar()
		_confirmar()


## Entrada do menu. Chamada pelo gerenciador (e nao por _unhandled_input proprio)
## para que exista UM dono da entrada durante a conversa: com dois nos lendo o
## mesmo ui_accept, uma confirmacao avanca a fala E escolhe a opcao no mesmo
## quadro.
func tratar_entrada(evento: InputEvent) -> bool:
	if not _ativo:
		return false
	if evento.is_action_pressed("ui_accept") or evento.is_action_pressed("interagir"):
		_confirmar()
		return true
	if evento.is_action_pressed("ui_cancel"):
		cancelado.emit()
		return true
	if evento.is_action_pressed("mover_baixo") or evento.is_action_pressed("ui_down"):
		_selecionar(_vizinho_habilitado(_indice, 1))
		return true
	if evento.is_action_pressed("mover_cima") or evento.is_action_pressed("ui_up"):
		_selecionar(_vizinho_habilitado(_indice, -1))
		return true
	return false


func _confirmar() -> void:
	if not _ativo:
		return
	_ativo = false            # trava ate o gerenciador reabrir com o proximo no
	escolhido.emit(_indice)
