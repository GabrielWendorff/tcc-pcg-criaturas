extends Control

## Menu principal — a primeira tela do jogo e o unico lugar onde a SEED e
## escolhida (RF01).
##
## Tres paginas sobre o mesmo fundo, e nao tres cenas: a troca entre elas e
## instantanea e o fundo nunca pisca. Cena separada so se justifica quando ha
## estado proprio a montar e desmontar, e aqui nao ha — sao tres Controls que se
## revezam na visibilidade.
##
##   RAIZ    Novo jogo · Continuar · Opcoes · Sair
##   SLOTS   os tres cartoes (serve aos DOIS caminhos; ver PainelSlots)
##   SEED    o campo de semente (so no caminho de partida nova)
##
## QUEM LE A ENTRADA. Um no so, como no dialogo e no encontro: este
## `_unhandled_input` oferece o evento a pagina ativa e nao faz mais nada. Com
## tres paginas lendo `ui_accept` por conta propria, uma confirmacao atravessaria
## duas paginas no mesmo quadro — o mesmo defeito que GerenciadorDialogo
## documenta entre a caixa de fala e o menu de escolhas.
##
## O TITULO VEM DE project.godot (`application/config/name`). Nao ha nome de jogo
## inventado em codigo: trocar o nome e trocar uma linha nas configuracoes do
## projeto, e nenhuma tela fica para tras.

const CENA_JOGO := "res://presentation/exploracao/mundo.tscn"

enum Pagina { RAIZ, SLOTS, SEED, OPCOES }

## Para onde o painel de slots esta levando. O mesmo painel serve a carregar e a
## gravar, e e esta variavel que diz qual dos dois.
enum Intencao { CONTINUAR, NOVO }

const OPCOES_RAIZ := [
	{"id": "novo", "texto": "NOVO JOGO"},
	{"id": "continuar", "texto": "CONTINUAR"},
	{"id": "opcoes", "texto": "OPÇÕES"},
	{"id": "sair", "texto": "SAIR"},
]

const DICAS := {
	Pagina.RAIZ: "↑↓ escolher     E / ENTER confirmar",
	Pagina.SLOTS: "←→ escolher     E / ENTER confirmar     DEL apagar     ESC voltar",
	Pagina.SEED: "↑↓ escolher     E / ENTER confirmar     ESC voltar",
	Pagina.OPCOES: "↑↓ escolher     ←→ / E alternar     ESC voltar",
}

var _fundo: FundoMenu
var _raiz: Control
var _menu: MenuEscolhas
var _slots: PainelSlots
var _seed: PainelNovaPartida
var _opcoes: PainelOpcoes
var _dica: Control
var _nota: Control
var _veu: ColorRect
var _tween_nota: Tween

var _pagina: Pagina = Pagina.RAIZ
var _intencao: Intencao = Intencao.CONTINUAR
var _slot_escolhido: int = 0
var _saindo: bool = false


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	# Voltar ao menu encerra a partida em curso. Sem isto, sair do jogo e abrir
	# "Novo jogo" comecaria a partida nova por cima do estado da anterior, com o
	# cronometro da velha ainda correndo.
	Save.encerrar_partida()
	Save.recarregar_resumos()

	_fundo = FundoMenu.new()
	_fundo.name = "Fundo"
	add_child(_fundo)

	_montar_titulo()
	_montar_raiz()

	_slots = PainelSlots.new()
	_slots.name = "Slots"
	_slots.escolhido.connect(_ao_escolher_slot)
	_slots.cancelado.connect(_voltar_para_raiz)
	_slots.apagado.connect(_ao_apagar_slot)
	add_child(_slots)

	_seed = PainelNovaPartida.new()
	_seed.name = "NovaPartida"
	_seed.comecar.connect(_ao_comecar)
	_seed.cancelado.connect(_voltar_para_slots)
	add_child(_seed)

	# A MESMA tela de opcoes do menu de pausa: "opcoes" nao e uma tela do menu,
	# e uma tela do jogo, e duas copias divergiriam na primeira opcao nova.
	_opcoes = PainelOpcoes.new()
	_opcoes.name = "Opcoes"
	_opcoes.cancelado.connect(_voltar_para_raiz)
	add_child(_opcoes)

	_montar_rodape()

	# Veu de transicao. Ultimo filho: tem de cobrir tudo, inclusive o fundo.
	_veu = ColorRect.new()
	_veu.name = "Veu"
	_veu.color = Color(TemaEncontro.CONTORNO, 0.0)
	_veu.set_anchors_preset(Control.PRESET_FULL_RECT)
	_veu.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_veu)

	_ir_para(Pagina.RAIZ)


# ---------------------------------------------------------------- construcao

func _montar_titulo() -> void:
	var caixa := VBoxContainer.new()
	caixa.name = "Titulo"
	caixa.add_theme_constant_override("separation", 10)
	caixa.set_anchors_preset(Control.PRESET_TOP_WIDE)
	caixa.offset_top = 56
	caixa.offset_bottom = 180
	caixa.alignment = BoxContainer.ALIGNMENT_CENTER
	caixa.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(caixa)

	var nome := String(ProjectSettings.get_setting("application/config/name", "RPG"))
	# Sombreado, e nao sobre painel: o titulo fica direto sobre o ceu desenhado,
	# e fonte de bitmap nao aceita o contorno da engine (ver TemaEncontro).
	var titulo := TemaEncontro.rotulo_sombreado(nome.to_upper(), TemaEncontro.OURO,
			TemaEncontro.Corpo.CARTAZ)
	titulo.name = "Nome"
	titulo.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	caixa.add_child(titulo)

	var linha := TemaEncontro.rotulo_sombreado("cada seed, um bestiário",
			TemaEncontro.PERG_E)
	linha.name = "Lema"
	linha.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	caixa.add_child(linha)


func _montar_raiz() -> void:
	_raiz = Control.new()
	_raiz.name = "Raiz"
	_raiz.set_anchors_preset(Control.PRESET_FULL_RECT)
	_raiz.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_raiz)

	var centro := CenterContainer.new()
	centro.set_anchors_preset(Control.PRESET_FULL_RECT)
	# Abaixo do centro geometrico: o titulo ocupa o terco de cima, e um menu
	# centrado na tela encostaria nele.
	centro.offset_top = 92
	centro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_raiz.add_child(centro)

	# A MESMA lista do dialogo e da roda de captura — ver a nota de
	# MenuEscolhas sobre haver um unico estilo de menu no jogo. `ancorar_acima`
	# fica falso porque aqui quem posiciona e o CenterContainer, e nao uma caixa
	# de fala no rodape.
	_menu = MenuEscolhas.new()
	_menu.name = "Opcoes"
	_menu.ancorar_acima = false
	_menu.escolhido.connect(_ao_escolher_raiz)
	centro.add_child(_menu)


func _montar_rodape() -> void:
	_dica = TemaEncontro.rotulo_sombreado("", TemaEncontro.PERG_E)
	_dica.name = "Dica"
	_dica.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_dica.offset_top = -34
	_dica.offset_bottom = -14
	add_child(_dica)

	_nota = TemaEncontro.rotulo_sombreado("", TemaEncontro.ATENCAO)
	_nota.name = "Nota"
	_nota.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_nota.offset_top = -58
	_nota.offset_bottom = -38
	_nota.modulate.a = 0.0
	add_child(_nota)


# -------------------------------------------------------------------- paginas

func _ir_para(pagina: Pagina) -> void:
	_pagina = pagina
	_raiz.visible = pagina == Pagina.RAIZ
	if pagina == Pagina.RAIZ:
		_abrir_raiz()
	else:
		_menu.fechar()
	if pagina == Pagina.SLOTS:
		var modo := PainelSlots.Modo.NOVO if _intencao == Intencao.NOVO \
				else PainelSlots.Modo.CONTINUAR
		_slots.abrir(Save.resumos(), modo)
	else:
		_slots.fechar()
	if pagina == Pagina.SEED:
		_seed.abrir(_slot_escolhido, _slot_ocupado(_slot_escolhido))
	else:
		_seed.fechar()
	if pagina == Pagina.OPCOES:
		_opcoes.abrir()
	else:
		_opcoes.fechar()
	TemaEncontro.escrever_sombreado(_dica, String(DICAS.get(pagina, "")))


func _abrir_raiz() -> void:
	var tem_save := Save.ha_save()
	var opcoes: Array = []
	for o: Dictionary in OPCOES_RAIZ:
		# "Continuar" sem nenhum save fica VISIVEL e apagada, nunca escondida:
		# uma lista que muda de tamanho conforme o disco faz o jogador procurar
		# a opcao que ele lembra de ter visto.
		opcoes.append({"texto": o["texto"],
				"ativo": tem_save if o["id"] == "continuar" else true})
	_menu.abrir(opcoes)


func _voltar_para_raiz() -> void:
	_ir_para(Pagina.RAIZ)


func _voltar_para_slots() -> void:
	_ir_para(Pagina.SLOTS)


func _slot_ocupado(slot: int) -> bool:
	for r: Dictionary in Save.resumos():
		if int(r.get("slot", 0)) == slot:
			return int(r.get("estado", ArquivoSave.Estado.VAZIO)) != ArquivoSave.Estado.VAZIO
	return false


# --------------------------------------------------------------------- acoes

func _ao_escolher_raiz(indice: int) -> void:
	match String(OPCOES_RAIZ[indice]["id"]):
		"novo":
			_intencao = Intencao.NOVO
			_ir_para(Pagina.SLOTS)
		"continuar":
			_intencao = Intencao.CONTINUAR
			_ir_para(Pagina.SLOTS)
		"opcoes":
			_ir_para(Pagina.OPCOES)
		"sair":
			get_tree().quit()


func _ao_escolher_slot(slot: int) -> void:
	if _intencao == Intencao.NOVO:
		_slot_escolhido = slot
		_ir_para(Pagina.SEED)
		return
	if not Save.carregar(slot):
		# O painel so deixa escolher slot carregavel, entao chegar aqui significa
		# que o arquivo mudou entre a listagem e a confirmacao. Releitura e aviso.
		Save.recarregar_resumos()
		_slots.atualizar(Save.resumos())
		_nota_curta("Não foi possível carregar o slot %d." % slot)
		return
	_entrar_no_jogo()


func _ao_apagar_slot(slot: int) -> void:
	Save.apagar(slot)
	_slots.atualizar(Save.resumos())
	_nota_curta("Slot %d apagado." % slot)


func _ao_comecar(semente: int, texto: String) -> void:
	Save.nova_partida(semente, texto, _slot_escolhido)
	_entrar_no_jogo()


## Troca de cena com escurecimento. O veu existe pelo mesmo motivo do
## escurecimento do encontro: um corte seco entre o menu e o mundo le como falha
## de carregamento.
func _entrar_no_jogo() -> void:
	if _saindo:
		return
	_saindo = true
	_slots.fechar()
	_seed.fechar()
	_menu.fechar()
	var t := create_tween()
	t.tween_property(_veu, "color:a", 1.0, 0.35)
	t.tween_callback(func() -> void:
			get_tree().change_scene_to_file(CENA_JOGO))


func _nota_curta(texto: String) -> void:
	TemaEncontro.escrever_sombreado(_nota, texto)
	if _tween_nota != null and _tween_nota.is_valid():
		_tween_nota.kill()
	_nota.modulate.a = 1.0
	_tween_nota = create_tween()
	_tween_nota.tween_interval(2.4)
	_tween_nota.tween_property(_nota, "modulate:a", 0.0, 0.5)


# -------------------------------------------------------------------- entrada

func _unhandled_input(evento: InputEvent) -> void:
	if _saindo:
		return
	var tratou := false
	match _pagina:
		Pagina.RAIZ:
			tratou = _menu.tratar_entrada(evento)
		Pagina.SLOTS:
			tratou = _slots.tratar_entrada(evento)
		Pagina.SEED:
			tratou = _seed.tratar_entrada(evento)
		Pagina.OPCOES:
			tratou = _opcoes.tratar_entrada(evento)
	if tratou:
		get_viewport().set_input_as_handled()
