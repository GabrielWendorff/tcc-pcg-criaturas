class_name Jogador
extends CharacterBody2D

## Camada 4 — personagem controlavel na area isometrica (RF05).
##
## Movimento LIVRE, nao preso a grade. A escolha e deliberada: um passo travado
## celula a celula tem cadencia melhor para um RPG de turnos, mas obriga a
## resolver colisao no dado do mapa (quais celulas sao pisaveis) em vez de na
## fisica. Como esta area ja tem props com pegada propria — uma casa 3x3, uma
## arvore que ocupa meia celula — a fisica e a fonte de verdade mais barata de
## manter, e a mudanca para passo travado depois so mexe neste arquivo.
##
## O PERSONAGEM E TEMPORARIO. A folha de caminhada e a do protagonista autoral
## (autoral/protagonista_1x.png, 4 direcoes x 4 quadros). Trocar o visual e
## trocar FOLHA/CELULA_FOLHA aqui: nada em movimento, colisao ou camera depende
## do desenho.

## Folha de caminhada: 4 linhas (baixo, esquerda, direita, cima) x 4 colunas
## (parado, passo A, parado, passo B).
##
## Usa a folha 1x e nao a 2x: com camera de zoom inteiro, ampliar na camera
## mantem o pixel quadrado; ampliar no asset e depois escalar de novo produz
## pixels de tamanhos desiguais na mesma imagem.
const FOLHA := "res://autoral/protagonista_1x.png"
const CELULA_FOLHA := 24
const LINHA_DA_DIRECAO := {"baixo": 0, "esquerda": 1, "direita": 2, "cima": 3}
const QUADROS_DA_CAMINHADA := [0, 1, 2, 3]

## Velocidade no eixo HORIZONTAL da tela, em pixels por segundo.
const VELOCIDADE := 72.0

## Fator do eixo vertical. Numa projecao 2:1, 32 px na horizontal e 16 px na
## vertical cobrem a MESMA distancia no chao — sem este fator, andar para o
## norte atravessa o mapa no dobro da velocidade de andar para o leste, e o
## movimento deixa de parecer isometrico.
const RAZAO_ISO := 0.5

## Aceleracao e frenagem, em pixels/s^2 no eixo horizontal. Existem para tirar o
## liga-desliga do movimento sem introduzir deslize: sao altas o bastante para a
## resposta continuar imediata.
const ACELERACAO := 900.0
const FRENAGEM := 1300.0

## Raio do corpo, em pixels. Circulo e nao retangulo: contra a serra de 26,57
## graus de um bloco isometrico, um retangulo engancha nos degraus e o
## personagem trava; o circulo escorrega.
const RAIO := 5.0

## Trocou o item na mao. "" = maos livres. Quem escuta e o tutorial ("equipe a
## vara") e o HUD — o jogador nao sabe que nenhum dos dois existe.
signal item_equipado_mudou(id: String)

var direcao: String = "baixo"       ## ultima direcao encarada (RF07)
var andando: bool = false

## Congelado por um evento que tomou o controle (hoje, o encontro). Ver congelar().
var congelado: bool = false

## Id do item na mao ("" = maos livres). E o que vai para o save
## (DadosPartida.item_equipado); o ItemJogo inteiro fica em item_atual().
var item_equipado: String = ""

## A mao: ancora do item equipado, filha deste no e irma do Sprite. Ver
## presentation/equipamento/slot_da_mao.gd para o porque da ordem de filho.
var mao: SlotDaMao

var _sprite: AnimatedSprite2D

## O item, guardado aqui e nao so na mao: equipar() pode ser chamado antes do
## _ready (a cena repoe o save logo apos criar o jogador), quando a mao ainda
## nao existe. Ela o recebe ao ser montada.
var _item: ItemJogo = null
## Caminhada roteirizada em curso (andar_ate). Enquanto existe, a entrada nao move.
var _roteiro: Tween = null


func _ready() -> void:
	# Sem gravidade nem chao: numa vista de cima o corpo desliza no plano.
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	add_to_group("jogador")
	_montar_colisao()
	_montar_sprite()
	# Depois do sprite: o slot se posiciona RELATIVO a ele na lista de filhos
	# (antes = atras do corpo, depois = na frente), entao o sprite tem de existir.
	_montar_mao()
	_aplicar_animacao()


## Poe `item` na mao. null = maos livres. A troca e imediata e nao recria nada:
## a mesma mao, o mesmo no de desenho, so o conteudo muda.
##
## Recusa item sem o marcador "equipamento": quem abre a roda so oferece
## equipaveis, mas o save e editavel a mao, e uma pocao na mao viraria um
## estado que nenhum outro sistema espera.
func equipar(item: ItemJogo) -> void:
	if item != null and not item.equipavel():
		push_warning("Jogador: '%s' nao e equipamento — mao mantida" % item.id)
		return
	_item = item
	if mao != null:
		mao.equipar(item)
	var id: String = item.id if item != null else ""
	if id == item_equipado:
		return
	item_equipado = id
	item_equipado_mudou.emit(id)


## O item na mao (null = maos livres).
func item_atual() -> ItemJogo:
	return _item


func _physics_process(delta: float) -> void:
	# get_vector ja normaliza a diagonal e ja cancela acoes opostas. Normalizar
	# de novo depois quebraria justamente essa diagonal.
	if _roteiro != null:
		return  # quem anda e o tween de andar_ate; a animacao ja foi posta la
	var entrada := Vector2.ZERO if congelado else Input.get_vector(
			"mover_esquerda", "mover_direita", "mover_cima", "mover_baixo")
	var alvo := Vector2(entrada.x, entrada.y * RAZAO_ISO) * VELOCIDADE
	var taxa := ACELERACAO if entrada != Vector2.ZERO else FRENAGEM
	velocity = velocity.move_toward(alvo, taxa * delta)
	move_and_slide()

	var estava := andando
	var antes := direcao
	andando = entrada != Vector2.ZERO
	if andando:
		direcao = _direcao_de(entrada)
	if andando != estava or direcao != antes:
		_aplicar_animacao()


## Tira (ou devolve) o controle do personagem.
##
## Nao usa set_physics_process(false): a velocidade guardada permaneceria e o
## personagem voltaria a andar sozinho ao ser descongelado. Aqui a entrada e lida
## como ZERO — a frenagem normal para o corpo, a animacao volta a parada, e a
## fisica continua rodando (o que mantem a colisao valida se algo o empurrar).
func congelar(sim: bool) -> void:
	if congelado == sim:
		return
	congelado = sim
	if congelado:
		velocity = Vector2.ZERO
		andando = false
		_aplicar_animacao()


## Caminha ate `destino` (pixels do mundo) em `duracao` segundos, sem entrada do
## jogador e sem fisica: e roteiro, para cutscene. Congela o jogador; quem chama
## descongela quando a cena acabar. Devolve o tween para quem quiser esperar.
func andar_ate(destino: Vector2, duracao: float) -> Tween:
	parar_roteiro()
	congelar(true)
	direcao = Npc.direcao_na_tela(destino - position, direcao)
	andando = true
	_aplicar_animacao()
	_roteiro = create_tween()
	_roteiro.tween_property(self, "position", destino, maxf(duracao, 0.01))
	_roteiro.tween_callback(func() -> void:
			_roteiro = null
			andando = false
			_aplicar_animacao())
	return _roteiro


## Interrompe a caminhada roteirizada onde estiver (pular a cutscene).
func parar_roteiro() -> void:
	if _roteiro != null and _roteiro.is_valid():
		_roteiro.kill()
	_roteiro = null
	if andando:
		andando = false
		_aplicar_animacao()


## Vira-se para um ponto do mundo, parado.
func olhar_para(alvo: Vector2) -> void:
	direcao = Npc.direcao_na_tela(alvo - position, direcao)
	_aplicar_animacao()


## Direcao encarada a partir da entrada, em 4 valores.
##
## O criterio e o eixo dominante da entrada NA TELA, nao no chao: o jogador
## pensa em termos do que ve. A folha tem so 4 direcoes; nas diagonais, o eixo
## horizontal ganha o desempate porque a silhueta de perfil le melhor do que a
## de frente quando o personagem esta se deslocando de lado.
func _direcao_de(entrada: Vector2) -> String:
	if absf(entrada.x) >= absf(entrada.y):
		return "direita" if entrada.x > 0.0 else "esquerda"
	return "baixo" if entrada.y > 0.0 else "cima"


func _aplicar_animacao() -> void:
	# A mao antes do retorno: sem folha de caminhada (clone sem --import) o item
	# continua acompanhando a direcao — e o slot so reordena se achar o Sprite.
	if mao != null:
		mao.aplicar_direcao(direcao)
	if _sprite == null:
		return
	_sprite.animation = ("andar_" if andando else "parado_") + direcao
	if andando:
		_sprite.play()
	else:
		_sprite.stop()
		_sprite.frame = 0


func _montar_colisao() -> void:
	var forma := CircleShape2D.new()
	forma.radius = RAIO
	var col := CollisionShape2D.new()
	col.name = "Corpo"
	col.shape = forma
	# A origem do no e o PE do personagem, e e ela que o y-sort usa. O circulo
	# fica centrado nela: colisao e profundidade passam a concordar sobre onde o
	# personagem esta pisando.
	add_child(col)


func _montar_sprite() -> void:
	_sprite = AnimatedSprite2D.new()
	_sprite.name = "Sprite"
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.centered = false
	# Encosta o pe do desenho na origem do no. Os 2px de folga sao a sombra do
	# quadro da folha, que fica abaixo da linha do chao.
	_sprite.offset = Vector2(-CELULA_FOLHA * 0.5, -(CELULA_FOLHA - 2))
	_sprite.sprite_frames = montar_quadros()
	add_child(_sprite)
	if _sprite.sprite_frames == null:
		push_error("Jogador: folha de caminhada nao carregou — " + FOLHA
				+ "\nNum clone novo rode uma vez: godot --headless --path . --import")


func _montar_mao() -> void:
	mao = SlotDaMao.new()
	add_child(mao)
	mao.equipar(_item)


## Recorta a folha em SpriteFrames. Estatica e publica para poder ser conferida
## por teste headless sem instanciar o jogador.
static func montar_quadros(caminho: String = FOLHA,
		lado: int = CELULA_FOLHA) -> SpriteFrames:
	var folha: Texture2D = load(caminho)
	if folha == null:
		return null
	var tam := folha.get_size()
	if int(tam.x) < lado * 4 or int(tam.y) < lado * 4:
		# AtlasTexture com regiao fora dos limites NAO da erro e devolve tamanho
		# normal — o recorte invalido passaria despercebido ate alguem olhar a
		# tela. Por isso a conferencia e explicita.
		push_error("Jogador: folha %s tem %s, esperado ao menos %dx%d"
				% [caminho, tam, lado * 4, lado * 4])
		return null

	var quadros := SpriteFrames.new()
	quadros.remove_animation("default")     # SpriteFrames.new() ja vem com ela
	for nome: String in LINHA_DA_DIRECAO.keys():
		var linha: int = LINHA_DA_DIRECAO[nome]
		for animacao: String in ["andar_" + nome, "parado_" + nome]:
			quadros.add_animation(animacao)
			quadros.set_animation_loop(animacao, true)
			quadros.set_animation_speed(animacao, 7.0)
		for col: int in QUADROS_DA_CAMINHADA:
			var recorte := AtlasTexture.new()
			recorte.atlas = folha
			recorte.region = Rect2(col * lado, linha * lado, lado, lado)
			quadros.add_frame("andar_" + nome, recorte)
		var parado := AtlasTexture.new()
		parado.atlas = folha
		parado.region = Rect2(0, linha * lado, lado, lado)
		quadros.add_frame("parado_" + nome, parado)
	return quadros
