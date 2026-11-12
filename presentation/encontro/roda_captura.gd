class_name RodaCaptura
extends Control

## Roda radial de selecao de item.
##
## E UMA roda so, e ela nao sabe o que esta mostrando: recebe Array[ItemCaptura] e
## um Callable que traduz cada item numa ficha. Por isso a mesma classe serve a
## escolha do DISPOSITIVO e a da ISCA — e serviria a uma terceira lista amanha sem
## uma linha nova aqui. Acrescentar um dispositivo em data/captura/dispositivos.json
## ja o coloca na roda, com icone, quantidade e chance.
##
## COMPOSICAO
## Tres niveis de leitura, do centro para fora:
##   1. o MIOLO em pergaminho — a ficha do item escolhido, o unico elemento claro
##      da tela e portanto o primeiro que o olho encontra;
##   2. o ANEL pontilhado e os raios — dizem que aquilo e uma roda, e nao cartoes
##      espalhados em circulo;
##   3. os CARTOES — moldura de madeira, dourada quando selecionados.
##
## Sem o miolo o centro fica vazio e a composicao se desmancha: numa roda o olho
## procura o eixo, e ali tem de haver a resposta ("o que estou prestes a usar?").
##
## O que a ficha do Callable traz — {texto, valor, detalhe, medidor, selo} — e
## descrito em `abrir()`. A roda nao calcula nada.
##
## Entrada: setas/WASD (as MESMAS acoes do andar), mouse pelo angulo do cursor,
## ui_accept confirma, ui_cancel cancela. Nenhuma acao de entrada nova no projeto.

signal escolhido(item: ItemCaptura)
signal cancelado()
signal selecao_mudou(item: ItemCaptura)

## Cartao vertical: icone em cima, nome, quantidade, medidor. A leitura de cima
## para baixo e a de um item de inventario; a horizontal era a de uma linha de
## tabela, que e como a versao anterior lia.
const LARGURA_SLOT := 122.0
const ALTURA_SLOT := 106.0

## Raio da roda como fracao da menor dimensao disponivel. E so o PISO estetico —
## o raio real cresce com o numero de itens (ver _raio()).
const FRACAO_RAIO := 0.30
const RAIO_MINIMO := 150.0

## Folga minima entre dois cartoes vizinhos, em pixels de circunferencia.
const FOLGA_SLOT := 18.0

## Achatamento vertical da roda. A tela e mais larga que alta: uma roda
## circular joga os cartoes de cima e de baixo para fora dela.
const ACHATAMENTO := 0.80

## Margem entre o cartao mais alto e a borda da tela.
const MARGEM_DA_BORDA := 14.0

const ESCALA_SELECIONADO := 1.06

## Tempo do recolhimento dos cartoes ao fechar.
const DURACAO_FECHAMENTO := 0.16

## Amplitude e periodo da flutuacao do cartao selecionado.
const FLUTUACAO := 3.0
const PERIODO_FLUTUACAO := 1.1

const LARGURA_MIOLO := 244.0

## Lado do ponto e passo entre pontos, em pixels. Grandes de proposito: um
## pontilhado fino vira linha continua e perde o carater de pixel art.
const PONTO := 3.0

## Distancia PERCORRIDA entre dois pontos do trilho — ver _desenhar_anel.
const PASSO_ANEL := 15.0

## Passo dos pontos do raio que liga o miolo ao cartao selecionado.
const PASSO_RAIO := 7.0

## Onde o anel e desenhado, como fracao do raio. Menor que 1 de proposito: no
## proprio raio dos cartoes ele ficaria inteiro escondido atras deles. Entre o
## miolo e os cartoes, ele vira o TRILHO da roda — que e o que faz a composicao
## ler como um mecanismo, e nao como cartoes espalhados em circulo.
const FRACAO_ANEL := 0.62

## Folga entre o miolo e o cartao mais proximo.
const FOLGA_DO_MIOLO := 26.0

var itens: Array = []
var ativa: bool = false

var _inventario: InventarioJogador
var _ficha_de: Callable
var _indice: int = -1
var _slots: Array[Control] = []
var _fichas: Array = []

var _miolo: PanelContainer
var _miolo_nome: Label
var _miolo_icone: IconeCaptura
var _miolo_texto: RichTextLabel
var _miolo_medidor: MedidorChance
var _miolo_legenda: Label
var _miolo_controles: Label
var _miolo_selo: PanelContainer
var _miolo_selo_texto: Label
var _titulo: Control
var _tween_flutuacao: Tween


func _ready() -> void:
	# Ancorada no canto e dimensionada a mao, e nao PRESET_FULL_RECT: a roda vive
	# numa CanvasLayer que comeca invisivel, e um Control invisivel nao passa pelo
	# layout — com ancoras, no frame em que abrir() e chamado o tamanho ainda seria
	# (0,0) e todos os cartoes iriam para o canto superior esquerdo.
	set_anchors_preset(PRESET_TOP_LEFT)
	mouse_filter = MOUSE_FILTER_STOP
	visible = false
	_montar_fixos()
	_ajustar_area()
	get_viewport().size_changed.connect(_ajustar_area)


func _ajustar_area() -> void:
	position = Vector2.ZERO
	size = get_viewport_rect().size
	_posicionar()


func _montar_fixos() -> void:
	_titulo = TemaEncontro.rotulo_sombreado("", TemaEncontro.PERG_C, TemaEncontro.Corpo.TITULO)
	_titulo.set_anchors_preset(PRESET_TOP_WIDE)
	_titulo.offset_top = 22.0
	_titulo.offset_bottom = 58.0
	add_child(_titulo)

	# --- miolo: a ficha do item selecionado ---
	_miolo = PanelContainer.new()
	_miolo.name = "Miolo"
	_miolo.add_theme_stylebox_override("panel", TemaEncontro.moldura("pergaminho"))
	_miolo.custom_minimum_size = Vector2(LARGURA_MIOLO, 0)
	_miolo.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(_miolo)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	v.mouse_filter = MOUSE_FILTER_IGNORE
	_miolo.add_child(v)

	_miolo_nome = TemaEncontro.rotulo("", TemaEncontro.TINTA, TemaEncontro.Corpo.TITULO)
	_miolo_nome.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_miolo_nome)

	# Icone grande: no miolo o item precisa parecer um OBJETO na mao, nao uma
	# entrada de lista. Escala 4 sobre 20px de arte = 80px de leitura.
	_miolo_icone = IconeCaptura.new("", 4)
	_miolo_icone.custom_minimum_size = Vector2(84, 84)
	_miolo_icone.size_flags_horizontal = SIZE_SHRINK_CENTER
	v.add_child(_miolo_icone)

	_miolo_selo = PanelContainer.new()
	_miolo_selo.add_theme_stylebox_override("panel", TemaEncontro.moldura("selo"))
	_miolo_selo.size_flags_horizontal = SIZE_SHRINK_CENTER
	_miolo_selo.mouse_filter = MOUSE_FILTER_IGNORE
	_miolo_selo.visible = false
	v.add_child(_miolo_selo)
	_miolo_selo_texto = TemaEncontro.rotulo("", TemaEncontro.CONTORNO)
	_miolo_selo.add_child(_miolo_selo_texto)

	_miolo_texto = TemaEncontro.texto_rico()
	_miolo_texto.add_theme_color_override("default_color", TemaEncontro.TINTA)
	_miolo_texto.custom_minimum_size.x = LARGURA_MIOLO - 30.0
	v.add_child(_miolo_texto)

	_miolo_legenda = TemaEncontro.rotulo("CHANCE DE CAPTURA", TemaEncontro.MADEIRA)
	_miolo_legenda.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_miolo_legenda)

	_miolo_medidor = MedidorChance.new(10, true, true)
	_miolo_medidor.size_flags_horizontal = SIZE_SHRINK_CENTER
	v.add_child(_miolo_medidor)

	# Os controles ficam por ULTIMO, depois do medidor. Antes eles vinham no meio
	# do texto, entre a descricao e a chance — o que punha a instrucao de teclado
	# na frente do dado que decide a escolha.
	_miolo_controles = TemaEncontro.rotulo("[ENTER] USAR    [ESC] VOLTAR",
			TemaEncontro.MADEIRA)
	_miolo_controles.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_miolo_controles)


## Abre a roda.
##
## `ficha_de` recebe um ItemCaptura e devolve um Dictionary:
##     texto    String  etiqueta curta do cartao ("61%", "+45%", "")
##     valor    float   0..1 para o medidor; < 0 quando nao ha medida
##     medidor  bool    desenha barra (dispositivo) ou nao (isca)
##     detalhe  String  linha de leitura no miolo
##     selo     String  faixa de destaque no miolo ("PREFERIDA"), ou ""
func abrir(titulo: String, lista: Array, inventario: InventarioJogador,
		ficha_de: Callable, duracao: float) -> void:
	itens = lista
	_inventario = inventario
	_ficha_de = ficha_de
	TemaEncontro.escrever_sombreado(_titulo, titulo)
	_ajustar_area()
	_reconstruir_slots()
	visible = true
	ativa = true
	_indice = _primeiro_disponivel()
	_atualizar_selecao()
	# Um quadro antes de animar: os cartoes so conhecem o proprio tamanho depois
	# do layout, e a roda precisa dele para centralizar cada um no seu ponto.
	await get_tree().process_frame
	_posicionar()
	await _animar_abertura(duracao)
	_flutuar()


## Fecha a roda recolhendo os cartoes para o centro. Bloqueia ate terminar.
##
## O recolhimento nao e enfeite: e o que liga a escolha ao lance. Sem ele a roda
## simplesmente some entre um quadro e o outro, e o arremesso comeca sem que nada
## na tela tenha dito que a roda acabou.
func fechar(duracao: float = DURACAO_FECHAMENTO) -> void:
	ativa = false
	if _tween_flutuacao != null and _tween_flutuacao.is_valid():
		_tween_flutuacao.kill()
	if not visible or _slots.is_empty() or duracao <= 0.0:
		visible = false
		return
	var centro := _centro()
	var t := create_tween()
	t.set_parallel(true)
	for slot in _slots:
		t.tween_property(slot, "position", centro - slot.size * 0.5, duracao) \
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		t.tween_property(slot, "modulate:a", 0.0, duracao * 0.8)
	t.tween_property(_miolo, "modulate:a", 0.0, duracao * 0.7)
	t.tween_property(_titulo, "modulate:a", 0.0, duracao * 0.7)
	await t.finished
	visible = false
	# Devolve o que a animacao mexeu: a proxima abertura reconstroi os cartoes,
	# mas o miolo e o titulo sao os mesmos nos e voltariam invisiveis.
	_miolo.modulate.a = 1.0
	_titulo.modulate.a = 1.0


func item_selecionado() -> ItemCaptura:
	if _indice < 0 or _indice >= itens.size():
		return null
	return itens[_indice]


# --- construcao -------------------------------------------------------------

func _reconstruir_slots() -> void:
	for s in _slots:
		s.queue_free()
	_slots.clear()
	_fichas.clear()
	for i in itens.size():
		# A ficha e pedida UMA vez por abertura e guardada: ela custa um
		# CalculoCaptura.avaliar por item, e a roda a consulta de novo a cada
		# troca de selecao e a cada redesenho do anel.
		_fichas.append(_ficha_de.call(itens[i]) if _ficha_de.is_valid() else {})
		var slot := _montar_slot(itens[i], _fichas[i])
		add_child(slot)
		_slots.append(slot)
	_posicionar()


func _montar_slot(item: ItemCaptura, ficha: Dictionary) -> Control:
	var disponivel: bool = _inventario == null or _inventario.tem(item.id)

	var painel := PanelContainer.new()
	painel.custom_minimum_size = Vector2(LARGURA_SLOT, ALTURA_SLOT)
	painel.pivot_offset = Vector2(LARGURA_SLOT, ALTURA_SLOT) * 0.5
	painel.mouse_filter = MOUSE_FILTER_IGNORE
	painel.add_theme_stylebox_override("panel",
			TemaEncontro.moldura(_nome_da_moldura(false, disponivel)))

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 3)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.mouse_filter = MOUSE_FILTER_IGNORE
	painel.add_child(col)

	var icone := IconeCaptura.new(item.id, 2)
	icone.custom_minimum_size = Vector2(0, 40)
	icone.esmaecido = not disponivel
	col.add_child(icone)

	var nome := TemaEncontro.rotulo(item.nome,
			TemaEncontro.PERG_C if disponivel else TemaEncontro.TEXTO_FRACO)
	nome.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nome.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# Duas linhas SEMPRE reservadas: sem isso, "Punhado de Sementes" quebra em
	# duas e aquele cartao fica mais alto que os vizinhos — numa roda, onde os
	# cartoes ficam lado a lado num circulo, alturas desiguais saltam a vista.
	nome.custom_minimum_size = Vector2(LARGURA_SLOT - 26.0, 26.0)
	nome.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	col.add_child(nome)

	var rodape := HBoxContainer.new()
	rodape.add_theme_constant_override("separation", 8)
	rodape.alignment = BoxContainer.ALIGNMENT_CENTER
	rodape.mouse_filter = MOUSE_FILTER_IGNORE
	col.add_child(rodape)

	# Quantidade sempre visivel, inclusive zerada: "×0" apagado le como
	# indisponivel; a ausencia do numero le como esquecimento.
	var n: int = _inventario.quantidade(item.id) if _inventario != null else 0
	var cor_qtd: Color = TemaEncontro.PERG_E
	if not disponivel:
		cor_qtd = TemaEncontro.TEXTO_FRACO
	elif n <= 2:
		cor_qtd = TemaEncontro.ATENCAO      # estoque curto merece ser notado
	rodape.add_child(TemaEncontro.rotulo("×%d" % n, cor_qtd))

	var texto: String = String(ficha.get("texto", ""))
	if bool(ficha.get("medidor", false)):
		var medidor := MedidorChance.new(5, true)
		medidor.valor = float(ficha.get("valor", 0.0))
		if not disponivel:
			medidor.modulate.a = 0.4
		rodape.add_child(medidor)
	elif texto != "":
		var cor: Color = TemaEncontro.VERDE if disponivel else TemaEncontro.TEXTO_FRACO
		rodape.add_child(TemaEncontro.rotulo(texto, cor))

	painel.set_meta("disponivel", disponivel)
	return painel


func _nome_da_moldura(selecionado: bool, disponivel: bool) -> String:
	if not disponivel:
		return "cartao_desativado"
	return "cartao_selecionado" if selecionado else "cartao"


# --- geometria --------------------------------------------------------------

func _notification(que: int) -> void:
	if que == NOTIFICATION_RESIZED:
		_posicionar()


func _area() -> Vector2:
	return size


func _centro() -> Vector2:
	return (_area() * 0.5).floor()


## Raio da roda.
##
## Sai de quatro restricoes, e o maior vence. As duas primeiras sao o motivo de a
## versao anterior encavalar os cartoes com 10 iscas:
##
## 1. VIZINHOS NA HORIZONTAL. Dois cartoes vizinhos ao redor do topo se separam
##    por R*sin(2π/n) no eixo x — nao por R. Com n=10, sin(36°)=0,59: um raio que
##    "parece folgado" entrega so 59% da distancia em x, e eles se tocam.
## 2. VIZINHOS NA VERTICAL. Nas laterais a separacao e R*sin(2π/n)*ACHATAMENTO —
##    ainda menor, porque a elipse comprime justamente o eixo em que os cartoes
##    sao mais altos.
## 3. O MIOLO. O pergaminho central ocupa LARGURA_MIOLO; o cartao mais proximo
##    tem de comecar depois dele.
## 4. A TELA. Teto: o cartao mais alto nao pode sair pela borda.
func _raio() -> float:
	var a := _area()
	var n: int = maxi(itens.size(), 1)
	var sep: float = sin(TAU / float(n)) if n > 2 else 1.0
	sep = maxf(sep, 0.15)      # com n<=2 nao ha vizinho para separar

	var por_tela: float = minf(a.x, a.y) * FRACAO_RAIO
	var por_vizinho_x: float = (LARGURA_SLOT + FOLGA_SLOT) / sep
	var por_vizinho_y: float = (ALTURA_SLOT + FOLGA_SLOT) / (sep * ACHATAMENTO)
	var por_miolo_x: float = (LARGURA_MIOLO + LARGURA_SLOT) * 0.5 + FOLGA_DO_MIOLO
	var por_miolo_y: float = ((_altura_do_miolo() + ALTURA_SLOT) * 0.5
			+ FOLGA_DO_MIOLO) / ACHATAMENTO

	var pedido: float = maxf(maxf(por_tela, maxf(por_vizinho_x, por_vizinho_y)),
			maxf(por_miolo_x, por_miolo_y))
	var teto: float = (a.y * 0.5 - ALTURA_SLOT * 0.5 - MARGEM_DA_BORDA) / ACHATAMENTO
	return clampf(pedido, RAIO_MINIMO, maxf(RAIO_MINIMO, teto))


## Altura corrente do miolo. Antes do primeiro layout ele mede 0 — a estimativa
## evita um quadro com os cartoes calculados por cima do pergaminho.
func _altura_do_miolo() -> float:
	if _miolo != null and _miolo.size.y > 1.0:
		return _miolo.size.y
	return 220.0


## Angulo do slot i: comeca no TOPO e anda no sentido horario, que e como a roda
## e lida (e como o exemplo da especificacao a desenha).
func _angulo(i: int) -> float:
	if itens.is_empty():
		return 0.0
	return -PI * 0.5 + TAU * float(i) / float(itens.size())


func _posicao_do_slot(i: int) -> Vector2:
	var a := _angulo(i)
	return _centro() + Vector2(cos(a) * _raio(), sin(a) * _raio() * ACHATAMENTO)


func _posicionar() -> void:
	if _miolo != null:
		_miolo.size = Vector2(_miolo.custom_minimum_size.x, 0)
		# O miolo so conhece a propria altura depois do layout; recentraliza no
		# quadro seguinte, senao ele fica preso pelo topo.
		_miolo.call_deferred("set_position",
				(_centro() - _miolo.size * 0.5).floor())
	for i in _slots.size():
		var tam: Vector2 = _slots[i].size
		if tam.x < 1.0:
			tam = Vector2(LARGURA_SLOT, ALTURA_SLOT)
		# floor: posicao fracionaria borra a moldura de pixel na borda.
		_slots[i].position = (_posicao_do_slot(i) - tam * 0.5).floor()
		_slots[i].set_meta("base_y", _slots[i].position.y)
	queue_redraw()


func _draw() -> void:
	if not visible or _slots.is_empty():
		return
	# Escurece o mundo e o menu atras da roda. A vinheta de InterfaceEncontro ja
	# cuida da atmosfera; aqui e so contraste para os cartoes.
	draw_rect(Rect2(Vector2.ZERO, _area()), Color(TemaEncontro.CONTORNO, 0.74))
	_desenhar_anel()
	_desenhar_raios()


## Trilho pontilhado da roda.
##
## Os pontos sao distribuidos por COMPRIMENTO DE ARCO, nao por angulo igual. Numa
## elipse as duas coisas nao coincidem: com passo angular constante os pontos se
## amontoam em cima e embaixo e se afastam nas laterais, e o resultado le como
## sujeira espalhada na tela em vez de um trilho. Foi exatamente o que apareceu na
## primeira versao desta roda.
##
## Nao ha formula fechada para o perimetro de uma elipse, entao o caminho e
## andado em passos finos, somando distancia, e um ponto e marcado a cada
## PASSO_ANEL pixels percorridos.
func _desenhar_anel() -> void:
	var c := _centro()
	var rx := _raio() * FRACAO_ANEL
	var ry := rx * ACHATAMENTO
	var cor := Color(TemaEncontro.MADEIRA_C, 0.58)
	var amostras: int = 720
	var percorrido: float = PASSO_ANEL      # marca o primeiro ponto de saida
	var anterior := c + Vector2(rx, 0.0)
	for i in range(1, amostras + 1):
		var a := TAU * float(i) / float(amostras)
		var p := c + Vector2(cos(a) * rx, sin(a) * ry)
		percorrido += p.distance_to(anterior)
		anterior = p
		if percorrido < PASSO_ANEL:
			continue
		percorrido = 0.0
		draw_rect(Rect2((p - Vector2(PONTO, PONTO) * 0.5).floor(),
				Vector2(PONTO, PONTO)), cor)


## Raio dourado do miolo ate o cartao SELECIONADO — e so ele.
##
## A versao anterior desenhava um raio para cada cartao. Somados ao trilho, eram
## dezesseis fileiras de pontos disputando a mesma area: o desenho que existia
## para dizer "isto e uma roda" acabava dizendo "isto esta poluido". Com um raio
## so, ele deixa de ser enfeite e passa a carregar informacao — amarra o que o
## miolo mostra ao cartao de onde aquilo veio.
func _desenhar_raios() -> void:
	if _indice < 0 or _indice >= _slots.size():
		return
	var c := _centro()
	var d := _posicao_do_slot(_indice) - c
	var comprimento := d.length()
	var direcao := d.normalized()
	# Comeca fora do miolo e para antes do cartao, para nao encostar em moldura
	# nenhuma nas duas pontas.
	var t: float = LARGURA_MIOLO * 0.45 + 12.0
	while t < comprimento - ALTURA_SLOT * 0.5:
		var p := c + direcao * t
		draw_rect(Rect2((p - Vector2(PONTO, PONTO) * 0.5).floor(),
				Vector2(PONTO, PONTO)), TemaEncontro.OURO)
		t += PASSO_RAIO


# --- selecao ----------------------------------------------------------------

func _disponivel(i: int) -> bool:
	if i < 0 or i >= _slots.size():
		return false
	return bool(_slots[i].get_meta("disponivel", false))


func _primeiro_disponivel() -> int:
	for i in itens.size():
		if _disponivel(i):
			return i
	return -1


## Gira para o proximo slot COM ESTOQUE. Se nenhum tiver, fica onde esta — a
## navegacao nunca pousa num item que o jogador nao pode usar.
func _girar(passo: int) -> void:
	if itens.is_empty():
		return
	var n: int = itens.size()
	var i: int = _indice if _indice >= 0 else 0
	for _tentativa in n:
		i = (i + passo + n) % n
		if _disponivel(i):
			if i != _indice:
				_indice = i
				_atualizar_selecao()
			return


func _selecionar(i: int) -> void:
	if i == _indice or not _disponivel(i):
		return
	Som.tocar("ui_mover")
	_indice = i
	_atualizar_selecao()


func _atualizar_selecao() -> void:
	for i in _slots.size():
		var selecionado: bool = i == _indice
		_slots[i].add_theme_stylebox_override("panel",
				TemaEncontro.moldura(_nome_da_moldura(selecionado, _disponivel(i))))
		var escala: float = ESCALA_SELECIONADO if selecionado else 1.0
		var t := create_tween()
		t.tween_property(_slots[i], "scale", Vector2(escala, escala), 0.10) \
				.set_trans(Tween.TRANS_SINE)
	_atualizar_miolo()
	_flutuar()
	queue_redraw()
	selecao_mudou.emit(item_selecionado())


## Faz o cartao selecionado subir e descer devagar. E o que da a impressao de que
## o item foi TIRADO da bolsa — parado, ele e so um cartao com borda diferente.
func _flutuar() -> void:
	if _tween_flutuacao != null and _tween_flutuacao.is_valid():
		_tween_flutuacao.kill()
	for i in _slots.size():
		if _slots[i].has_meta("base_y"):
			_slots[i].position.y = float(_slots[i].get_meta("base_y"))
	if _indice < 0 or _indice >= _slots.size() or not visible:
		return
	var slot: Control = _slots[_indice]
	var base: float = float(slot.get_meta("base_y", slot.position.y))
	_tween_flutuacao = create_tween().set_loops()
	_tween_flutuacao.tween_property(slot, "position:y", base - FLUTUACAO,
			PERIODO_FLUTUACAO * 0.5).set_trans(Tween.TRANS_SINE)
	_tween_flutuacao.tween_property(slot, "position:y", base,
			PERIODO_FLUTUACAO * 0.5).set_trans(Tween.TRANS_SINE)


func _atualizar_miolo() -> void:
	var item := item_selecionado()
	if item == null:
		_miolo_nome.text = "SEM ITENS"
		_miolo_icone.configurar("")
		_miolo_texto.text = "[center]Nada disponível.\nEsc para voltar.[/center]"
		_miolo_medidor.visible = false
		_miolo_legenda.visible = false
		_miolo_selo.visible = false
		return
	var ficha: Dictionary = _fichas[_indice] if _indice < _fichas.size() else {}
	_miolo_nome.text = item.nome.to_upper()
	_miolo_icone.configurar(item.id)

	var selo: String = String(ficha.get("selo", ""))
	_miolo_selo.visible = selo != ""
	_miolo_selo_texto.text = selo

	var linhas := PackedStringArray(["[center]%s[/center]" % item.descricao])
	var detalhe: String = String(ficha.get("detalhe", ""))
	if detalhe != "":
		linhas.append("[center][color=%s]%s[/color][/center]"
				% [TemaEncontro.TINTA_C.to_html(false), detalhe])
	_miolo_texto.text = "\n".join(linhas)

	_miolo_medidor.visible = bool(ficha.get("medidor", false))
	_miolo_legenda.visible = _miolo_medidor.visible
	if _miolo_medidor.visible:
		_miolo_medidor.valor = float(ficha.get("valor", 0.0))


func _animar_abertura(duracao: float) -> void:
	if _slots.is_empty() or duracao <= 0.0:
		return
	var centro := _centro()
	var t := create_tween()
	t.set_parallel(true)
	for i in _slots.size():
		var slot: Control = _slots[i]
		# Destino recalculado, e nao lido de slot.position: um _posicionar()
		# concorrente durante a animacao deixaria a posicao atual desatualizada.
		var destino: Vector2 = (_posicao_do_slot(i) - slot.size * 0.5).floor()
		slot.position = centro - slot.size * 0.5
		slot.modulate.a = 0.0
		t.tween_property(slot, "position", destino, duracao) \
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		t.tween_property(slot, "modulate:a", 1.0, duracao * 0.7)
	_miolo.modulate.a = 0.0
	t.tween_property(_miolo, "modulate:a", 1.0, duracao)
	await t.finished
	_posicionar()


# --- entrada ----------------------------------------------------------------

func _gui_input(evento: InputEvent) -> void:
	if not ativa:
		return
	if evento is InputEventMouseMotion:
		_selecionar(_slot_sob(evento.position))
	elif evento is InputEventMouseButton and evento.pressed \
			and evento.button_index == MOUSE_BUTTON_LEFT:
		var i := _slot_sob(evento.position)
		if i >= 0 and i == _indice:
			_confirmar()
		else:
			_selecionar(i)
		accept_event()


func _unhandled_input(evento: InputEvent) -> void:
	if not ativa:
		return
	if evento.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		cancelado.emit()
	elif evento.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		_confirmar()
	elif evento.is_action_pressed("mover_direita") or evento.is_action_pressed("mover_baixo"):
		get_viewport().set_input_as_handled()
		_girar(1)
	elif evento.is_action_pressed("mover_esquerda") or evento.is_action_pressed("mover_cima"):
		get_viewport().set_input_as_handled()
		_girar(-1)


## Slot mais proximo do ANGULO do cursor, e nao o que esta sob o ponteiro: numa
## roda, o gesto e apontar a direcao, e exigir acerto dentro do retangulo do
## cartao torna a selecao com mouse mais dificil que com o teclado. Perto do
## centro nao seleciona nada — e a zona neutra do miolo.
func _slot_sob(pos: Vector2) -> int:
	if itens.is_empty():
		return -1
	var d := pos - _centro()
	if d.length() < _raio() * 0.38:
		return -1
	var melhor: int = -1
	var melhor_dist: float = INF
	for i in itens.size():
		var dist: float = pos.distance_to(_posicao_do_slot(i))
		if dist < melhor_dist:
			melhor_dist = dist
			melhor = i
	return melhor


func _confirmar() -> void:
	Som.tocar("ui_confirmar")
	var item := item_selecionado()
	if item == null or not _disponivel(_indice):
		return
	ativa = false      # trava imediata: um segundo Enter nao gera segundo lance
	if _indice >= 0 and _indice < _slots.size():
		# Pulso de confirmacao: o cartao "aperta" antes de a roda fechar.
		var t := create_tween()
		t.tween_property(_slots[_indice], "scale", Vector2(1.18, 1.18), 0.06)
		t.tween_property(_slots[_indice], "scale", Vector2(0.9, 0.9), 0.07)
	escolhido.emit(item)
