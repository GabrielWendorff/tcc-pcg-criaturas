class_name SlotDaMao
extends Marker2D

## O ponto de ancoragem do item equipado — a "mao" do jogador.
##
## Filho do Jogador, irmao do Sprite. Tem UM filho fixo, o ItemNaMao, que e
## reconfigurado a cada troca: equipar outro item nao cria nem destroi no
## nenhum (nem o jogador, nem o slot, nem o desenho), so troca o que o desenho
## mostra. E o que torna a troca instantanea e o que deixa quem guardou uma
## referencia ao slot (a pesca, para tirar a ponta da vara) continuar valido.
##
## Marker2D e nao Node2D: no editor ele desenha a cruz de referencia, e numa cena
## de teste e o que mostra onde a mao esta antes de haver item nela.
##
## ORDEM DE DESENHO, NAO z_index
## -----------------------------
## O item tem de passar ATRAS do corpo quando o jogador olha para cima (a mao
## esta do outro lado) e NA FRENTE nas outras direcoes. O jeito obvio seria
## z_index = -1 / +1, e e o errado aqui: o Jogador vive no container y-sorted
## Entidades, junto com arvores, casas e NPCs, e z_index e GLOBAL ao canvas —
## com z = +1 a vara seria desenhada por cima da arvore que esta NA FRENTE do
## jogador; com z = -1 ela sumiria sob o chao. O y-sort so ordena irmaos de
## mesmo z.
##
## Ordem de filho resolve sem efeito colateral: dentro do Jogador os filhos sao
## desenhados na ordem da arvore, e o Jogador inteiro continua sendo UM item do
## y-sort. "atras" = mover o slot para ANTES do no "Sprite"; senao, DEPOIS.

## Emitido quando a vara chega a frente no lance — o instante em que a linha
## sai. Sempre emitido, mesmo sem item ou com a animacao interrompida, para que
## um `await` nele nunca fique pendurado.
signal arremesso_concluido()

const NOME := "SlotDaMao"

## Nome do irmao que define a ordem de desenho (ver Jogador._montar_sprite).
const NOME_DO_SPRITE := "Sprite"

## Item na mao (null = mao vazia).
var item: ItemJogo = null

## Direcao encarada aplicada por ultimo ("baixo", "esquerda", "direita", "cima").
var direcao: String = PosesDaMao.DIRECAO_PADRAO

## Pose de pesca ligada (vara erguida, ver pose_de_pesca()).
var pescando: bool = false

## As poses em uso. Publico para a cena de teste trocar a calibragem sem gravar
## arquivo (PosesDaMao.de_dicionario) e reaplicar com aplicar_direcao().
var poses: PosesDaMao

## O desenho. Sempre o mesmo no, do nascimento do slot ate o fim.
var visual: ItemNaMao

var _tween: Tween = null
## Ha um arremesso_concluido devido — ver _interromper_giro().
var _concluir_pendente: bool = false
## Ultimo (direcao, pescando) aplicado: o giro do arremesso so e interrompido
## quando a pose muda de verdade, nao a cada reaplicacao da mesma.
var _aplicada: String = ""


func _init(poses_: PosesDaMao = null) -> void:
	name = NOME
	poses = poses_ if poses_ != null else PosesDaMao.carregar()
	visual = ItemNaMao.new()
	visual.name = "ItemNaMao"
	visual.visible = false
	add_child(visual)


func _ready() -> void:
	# A ordem relativa ao Sprite so pode ser acertada com pai: e aqui, e nao no
	# _init, que a primeira pose vale por inteiro.
	aplicar_direcao(direcao)


## Troca o item na mao, na hora. null esvazia. O no do desenho e o mesmo; so o
## conteudo muda (ver o topo do arquivo).
func equipar(novo: ItemJogo) -> void:
	_interromper_giro()
	item = novo
	visual.configurar(novo)
	visual.visible = novo != null
	_aplicada = ""
	aplicar_direcao(direcao)


## Posicao, rotacao, espelho e ORDEM DE DESENHO da pose `nova`.
func aplicar_direcao(nova: String) -> void:
	var chave: String = "%s|%s" % [nova, pescando]
	var mudou: bool = chave != _aplicada
	direcao = nova
	_aplicada = chave
	var p: Dictionary = poses.pose(direcao, pescando)
	position = p["posicao"]
	scale = Vector2(-1.0 if bool(p["espelhar"]) else 1.0, 1.0)
	_ordenar(bool(p["atras"]))
	if _girando() and not mudou:
		# Mesma pose reaplicada no meio do lance (o Jogador reanima ao congelar,
		# por exemplo): a rotacao e do tween ate ele acabar.
		return
	_interromper_giro()
	rotation_degrees = float(p["rotacao"])


## Liga/desliga a pose de pesca (vara erguida para a agua). Desligar tambem
## devolve a boia a ponta da vara: a pesca acabou e a linha foi recolhida.
func pose_de_pesca(sim: bool) -> void:
	pescando = sim
	if not sim:
		visual.boia_na_ponta = true
	aplicar_direcao(direcao)


## Recuo e avanco da vara. A rotacao sai da pose CORRENTE (normalmente a de
## pesca, que a pesca liga antes do lance) e volta para ela no fim.
## `arremesso_concluido` sai no fim do avanco — o instante em que a linha deixa
## a ponta — e nao no fim do retorno: quem espera para lancar a boia quer o
## gesto, nao o assentamento.
func animar_arremesso() -> void:
	_interromper_giro()
	_concluir_pendente = true
	if item == null or not is_inside_tree():
		# Deferido: quem chama costuma fazer `animar_arremesso()` e logo
		# `await arremesso_concluido`. Emitir aqui, sincrono, passaria antes do
		# await e o deixaria esperando para sempre.
		_concluir.call_deferred()
		return
	var base: float = float(poses.pose(direcao, pescando)["rotacao"])
	var sinal: float = poses.sinal_do_giro(direcao, pescando)
	rotation_degrees = base
	_tween = create_tween()
	_tween.tween_property(self, "rotation_degrees", base + sinal * poses.recuo_graus,
			poses.duracao_recuo).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "rotation_degrees", base + sinal * poses.avanco_graus,
			poses.duracao_avanco).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_tween.tween_callback(_soltar_linha)
	_tween.tween_property(self, "rotation_degrees", base,
			poses.duracao_avanco * 1.5).set_trans(Tween.TRANS_SINE)


## Ponta do item em coordenadas GLOBAIS — origem da linha de pesca. Sem item, a
## propria mao: a linha nunca sai do pe do jogador por falta de item.
func ponta_global() -> Vector2:
	if not is_inside_tree():
		return position
	if item == null or not visual.is_inside_tree():
		return global_position
	return visual.to_global(visual.ponta_local())


## Esta desenhado atras do corpo agora? (Ordem de filho, ver o topo.)
func atras_do_corpo() -> bool:
	var sprite := _sprite_irmao()
	return sprite != null and get_index() < sprite.get_index()


# --- interno ----------------------------------------------------------------

func _sprite_irmao() -> Node:
	var pai := get_parent()
	if pai == null:
		return null
	var s := pai.get_node_or_null(NOME_DO_SPRITE)
	return null if s == self else s


## Move o slot para logo antes (atras) ou logo depois (na frente) do Sprite.
## move_child poe o no EXATAMENTE no indice pedido; pedir o indice do sprite
## funciona nos dois sentidos — vindo de depois, o slot entra e empurra o sprite
## uma casa; vindo de antes, a saida do slot puxa o sprite uma casa e o slot
## entra logo depois dele.
func _ordenar(atras: bool) -> void:
	var sprite := _sprite_irmao()
	if sprite == null:
		return
	var i_sprite: int = sprite.get_index()
	var i_eu: int = get_index()
	if (atras and i_eu > i_sprite) or (not atras and i_eu < i_sprite):
		get_parent().move_child(self, i_sprite)


func _girando() -> bool:
	return _tween != null and _tween.is_valid() and _tween.is_running()


## Para o lance no meio. Se o sinal ainda era devido, sai AGORA — um lance
## interrompido continua tendo um fim, e quem esperava por ele segue.
##
## Sincrono aqui (e deferido no caso sem item, em animar_arremesso) pelo mesmo
## motivo: quem espera o lance INTERROMPIDO ja esta no `await`; deferir faria o
## sinal sair depois de um eventual lance novo comecar, e acordaria tambem quem
## espera o novo, antes da hora.
func _interromper_giro() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = null
	_concluir()


func _soltar_linha() -> void:
	visual.boia_na_ponta = false
	_concluir()


func _concluir() -> void:
	if not _concluir_pendente:
		return
	_concluir_pendente = false
	arremesso_concluido.emit()
