class_name MenuPausa
extends CanvasLayer

## Menu de pausa (ESC no mundo): continuar, equipe, bolsa, opcoes, salvar, sair.
##
## PAUSA DE VERDADE — `get_tree().paused = true`. Nao e so congelar o jogador:
## com a arvore pausada o encontro nao sorteia, os tweens de animacao param e o
## cronometro de tempo jogado para junto (ver o process_mode de GerenciadorSave).
## Congelar so o personagem deixaria o mundo correndo atras de um menu, e o
## jogador voltaria de uma pausa de dois minutos para um encontro que comecou
## sem ele.
##
## Por isso este no e os dois paineis que ele abre sao PROCESS_MODE_ALWAYS: sao
## os unicos que continuam vivos com a arvore pausada.
##
## SALVAR E DAQUI. A tecla F5 da Etapa 1 era provisoria e esta documentada como
## tal; continua funcionando, mas o lugar do comando e este.
##
## Esta classe NAO sabe salvar, nao sabe o que e um item e nao conhece opcao
## nenhuma: ela abre paineis e emite sinais. Quem costura e a cena do mundo,
## como ja costurava encontro, dialogo e mapa.

signal retomar_pedido()
signal salvar_pedido()
signal sair_pedido()

const CAMADA := 96

enum Pagina { RAIZ, OPCOES }

const OPCOES_RAIZ := [
	{"id": "continuar", "texto": "CONTINUAR"},
	{"id": "equipe", "texto": "EQUIPE"},
	{"id": "bestiario", "texto": "BESTIÁRIO"},
	{"id": "bolsa", "texto": "BOLSA"},
	{"id": "opcoes", "texto": "OPÇÕES"},
	{"id": "salvar", "texto": "SALVAR"},
	{"id": "sair", "texto": "MENU PRINCIPAL"},
]

var bolsa: TelaBolsa
var tela_equipe: TelaEquipe
var tela_bestiario: TelaBestiario

## O que o bestiario mostra. A cena do mundo entrega: bestiario da seed, como saber se
## uma criatura foi capturada, tabelas de batalha e o rotulo da seed.
var bestiario: Array = []
var capturada: Callable
var tabelas_batalha: TabelasBatalha
var tabelas_probabilidade: TabelasProbabilidade
var rotulo_seed: String = ""

## Quem resolve um item usado na bolsa, porque esta classe nao sabe o que e curar:
## recebe o ItemJogo e devolve a frase do resultado. A cena do mundo liga aqui.
var usar_item: Callable

## Equipe mostrada pela tela de equipe. A cena do mundo entrega.
var equipe: EquipeJogador
var catalogo_corpos: CatalogoCorpos

## A bolsa foi aberta DIRETO do mundo (tecla B), e nao pelo item do menu. Quem
## entrou por atalho tem de sair por atalho: fechar a bolsa devolve o jogo, em
## vez de deixar o jogador num menu de pausa que ele nunca pediu.
var _bolsa_direta: bool = false
var _bestiario_direto: bool = false

var _raiz: Control
var _bloco: CenterContainer
var _menu: MenuEscolhas
var _painel_opcoes: PainelOpcoes
var _nota: Label
var _controles: Label

## Linha de controles mostrada sob o menu. A cena do mundo entrega: e ela que sabe se
## as teclas de desenvolvimento valem nesta build.
var texto_controles: String = ""
var _pagina: Pagina = Pagina.RAIZ
var _aberto: bool = false


func _ready() -> void:
	layer = CAMADA
	process_mode = Node.PROCESS_MODE_ALWAYS

	_raiz = Control.new()
	_raiz.name = "Raiz"
	_raiz.set_anchors_preset(Control.PRESET_FULL_RECT)
	_raiz.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_raiz)

	var veu := ColorRect.new()
	veu.color = Color(TemaEncontro.CONTORNO, 0.68)
	veu.set_anchors_preset(Control.PRESET_FULL_RECT)
	veu.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_raiz.add_child(veu)

	_bloco = CenterContainer.new()
	_bloco.name = "Bloco"
	_bloco.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bloco.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_raiz.add_child(_bloco)

	var coluna := VBoxContainer.new()
	coluna.add_theme_constant_override("separation", 12)
	coluna.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bloco.add_child(coluna)

	var titulo := TemaEncontro.rotulo("PAUSA", TemaEncontro.OURO,
			TemaEncontro.Corpo.TITULO)
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	coluna.add_child(titulo)

	_menu = MenuEscolhas.new()
	_menu.ancorar_acima = false
	_menu.escolhido.connect(_ao_escolher)
	coluna.add_child(_menu)

	_nota = TemaEncontro.rotulo("", TemaEncontro.ATENCAO)
	_nota.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_nota.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_nota.custom_minimum_size = Vector2(MenuEscolhas.LARGURA, 0)
	coluna.add_child(_nota)

	_controles = TemaEncontro.rotulo("", TemaEncontro.PERG_E)
	_controles.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	coluna.add_child(_controles)

	_painel_opcoes = PainelOpcoes.new()
	_painel_opcoes.cancelado.connect(_voltar_para_raiz)
	_raiz.add_child(_painel_opcoes)

	bolsa = TelaBolsa.new()
	bolsa.name = "Bolsa"
	bolsa.fechada.connect(_ao_fechar_bolsa)
	bolsa.item_usado.connect(_ao_usar_item)
	add_child(bolsa)

	tela_equipe = TelaEquipe.new()
	tela_equipe.name = "TelaEquipe"
	tela_equipe.fechada.connect(_voltar_da_equipe)
	add_child(tela_equipe)

	tela_bestiario = TelaBestiario.new()
	tela_bestiario.name = "TelaBestiario"
	tela_bestiario.fechada.connect(_ao_fechar_bestiario)
	add_child(tela_bestiario)

	visible = false


# -------------------------------------------------------------------- fluxo

func abrir() -> void:
	if _aberto:
		return
	_aberto = true
	visible = true
	_nota.text = ""
	_controles.text = texto_controles
	_bolsa_direta = false
	_ir_para(Pagina.RAIZ)
	get_tree().paused = true


func fechar() -> void:
	if not _aberto:
		return
	_aberto = false
	visible = false
	_menu.fechar()
	_painel_opcoes.fechar()
	if bolsa.aberta():
		bolsa.fechar()
	if tela_equipe.aberta():
		tela_equipe.fechar()
	if tela_bestiario.aberta():
		tela_bestiario.fechar()
	get_tree().paused = false


func aberto() -> bool:
	return _aberto


func _ir_para(pagina: Pagina) -> void:
	_pagina = pagina
	_raiz.visible = true
	# O titulo e o menu saem de cena na pagina de opcoes: os dois paineis sao
	# filhos do mesmo _raiz e o de opcoes desenharia POR CIMA do "PAUSA".
	_bloco.visible = pagina == Pagina.RAIZ
	if pagina == Pagina.RAIZ:
		var opcoes: Array = []
		for o: Dictionary in OPCOES_RAIZ:
			# "Salvar" sem partida vinculada a slot fica apagada em vez de
			# falhar no clique — o mesmo tratamento do "Continuar" do menu
			# principal.
			var ativo: bool = true
			if o["id"] == "salvar":
				ativo = Save.em_partida() and Save.slot_atual > 0
			opcoes.append({"texto": o["texto"], "ativo": ativo})
		_menu.abrir(opcoes)
		_painel_opcoes.fechar()
	else:
		_menu.fechar()
		_painel_opcoes.abrir()


func _voltar_para_raiz() -> void:
	_ir_para(Pagina.RAIZ)


func _ao_escolher(indice: int) -> void:
	match String(OPCOES_RAIZ[indice]["id"]):
		"continuar":
			retomar_pedido.emit()
		"equipe":
			_mostrar_equipe()
		"bestiario":
			_mostrar_bestiario(false)
		"bolsa":
			_mostrar_bolsa(false)
		"opcoes":
			_ir_para(Pagina.OPCOES)
		"salvar":
			salvar_pedido.emit()
		"sair":
			sair_pedido.emit()


func _mostrar_equipe() -> void:
	if equipe == null:
		nota("Sem equipe nesta cena.")
		_ir_para(Pagina.RAIZ)
		return
	_raiz.visible = false
	_menu.fechar()
	tela_equipe.abrir(equipe, catalogo_corpos)


func _voltar_da_equipe() -> void:
	if _aberto:
		_ir_para(Pagina.RAIZ)


## O bestiario da seed. `direta`: aberto pela tecla N, e nao pelo menu — fechar devolve
## o jogo, como a bolsa aberta pelo B.
func _mostrar_bestiario(direta: bool) -> void:
	if bestiario.is_empty():
		nota("Sem bestiário nesta cena.")
		_ir_para(Pagina.RAIZ)
		return
	_bestiario_direto = direta
	_raiz.visible = false
	_menu.fechar()
	tela_bestiario.abrir(bestiario, capturada, catalogo_corpos, tabelas_batalha, rotulo_seed,
			tabelas_probabilidade)


func abrir_no_bestiario() -> void:
	abrir()
	_mostrar_bestiario(true)


func _ao_fechar_bestiario() -> void:
	if not _aberto:
		return
	if _bestiario_direto:
		_bestiario_direto = false
		retomar_pedido.emit()
	else:
		_ir_para(Pagina.RAIZ)


## Abre a bolsa por cima. O menu sai de cena enquanto ela esta aberta: duas
## telas empilhadas competiriam pela mesma tecla de cancelar.
func _mostrar_bolsa(direta: bool) -> void:
	_bolsa_direta = direta
	_raiz.visible = false
	_menu.fechar()
	bolsa.abrir()


## Atalho do mundo (B): pausa e vai direto para a bolsa, sem passar pelo menu.
func abrir_na_bolsa() -> void:
	abrir()
	_mostrar_bolsa(true)


func _ao_fechar_bolsa() -> void:
	if not _aberto:
		return
	if _bolsa_direta:
		_bolsa_direta = false
		retomar_pedido.emit()
	else:
		_ir_para(Pagina.RAIZ)


## Quem cura e a cena do mundo, por `usar_item`. Item sem efeito responde com uma
## recusa escrita, em vez de gastar em silencio.
func _ao_usar_item(item: ItemJogo) -> void:
	if item.permanente:
		bolsa.avisar("%s fica com você — é equipamento." % item.nome)
	elif not item.efeito.has("tipo") or not usar_item.is_valid():
		bolsa.avisar("Nada para fazer com %s agora." % item.nome)
	else:
		bolsa.avisar(String(usar_item.call(item)))


## Mensagem curta sob o menu. Fica ate a proxima — com o jogo pausado nao ha
## quadro passando para fazer um aviso sumir sozinho, e um texto que desaparece
## sob pausa pareceria um defeito.
func nota(texto: String) -> void:
	_nota.text = texto


## Bolsa, equipe ou bestiario abertos por cima do menu: eles tem a entrada.
func _tela_por_cima() -> bool:
	return bolsa.aberta() or tela_equipe.aberta() or tela_bestiario.aberta()


func _unhandled_input(evento: InputEvent) -> void:
	if not _aberto or _tela_por_cima():
		return
	var tratou := false
	if _pagina == Pagina.RAIZ:
		if evento.is_action_pressed("ui_cancel") or evento.is_action_pressed("pausar"):
			retomar_pedido.emit()
			tratou = true
		else:
			tratou = _menu.tratar_entrada(evento)
			# MenuEscolhas trava apos uma escolha; reabrir devolve o cursor a
			# lista quando a acao escolhida nao mudou de pagina (Salvar).
			if tratou and _pagina == Pagina.RAIZ and not _menu.ativo() \
					and _aberto and not _tela_por_cima():
				_ir_para(Pagina.RAIZ)
	else:
		tratou = _painel_opcoes.tratar_entrada(evento)
	if tratou:
		get_viewport().set_input_as_handled()
