class_name Npc
extends CharacterBody2D

## Personagem autoral com quem se conversa. UM script para TODOS os NPCs.
##
## Nao ha "script do pescador" nem "script do padeiro": o que muda de um NPC para
## outro e a ficha (DadosNpc, de autoral/npcs/npcs.json) e a arvore de dialogo
## (autoral/dialogos/<id>.json). Acrescentar um NPC e acrescentar dado — que e o
## criterio do item 4 do escopo e o motivo de este arquivo nao ter nenhum `match
## id`.
##
## CharacterBody2D e nao StaticBody2D: o NPC esta parado HOJE. Agenda, ronda e
## deslocamento por horario sao evolucoes previstas, e um corpo estatico teria de
## ser trocado de classe para recebe-las — com colisao, y-sort e cena mudando
## junto. Sem `_physics_process`, o custo de um corpo parado e o mesmo.
##
## Reaproveita a folha de caminhada do protagonista pelo recorte de
## `Jogador.montar_quadros()` — mesmo formato 4x4, mesma convencao de linhas. Um
## segundo recortador para a mesma folha seria duas verdades sobre o mesmo PNG.

## Raio do corpo, igual ao do jogador: dois corpos de raios diferentes na mesma
## grade produzem folgas de passagem diferentes em corredores iguais.
const RAIO := 5.0

var dados: DadosNpc
var celula_do_mapa: Vector2i = Vector2i(32, 16)

var _sprite: AnimatedSprite2D
var _indicador: IndicadorInteracao


## Fabrica a partir da ficha. A posicao em pixels vem de fora (MundoIso sabe
## converter celula -> mundo; o NPC nao precisa conhecer a projecao).
static func criar(ficha: DadosNpc, tamanho_da_celula: Vector2i) -> Npc:
	var npc := Npc.new()
	npc.dados = ficha
	npc.celula_do_mapa = tamanho_da_celula
	npc.name = "Npc_" + ficha.id
	return npc


func _ready() -> void:
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	add_to_group("npcs")
	if dados != null:
		set_meta("id", dados.id)
		set_meta("regiao", dados.regiao)
	if dados == null or dados.bloqueia:
		var forma := CircleShape2D.new()
		forma.radius = RAIO
		var col := CollisionShape2D.new()
		col.name = "Corpo"
		col.shape = forma
		add_child(col)
	else:
		# Sem forma nenhuma o corpo ainda entra nas consultas de fisica; desligar
		# a camada e o que torna o NPC atravessavel de verdade.
		collision_layer = 0
		collision_mask = 0
	_montar_sprite()
	_indicador = IndicadorInteracao.new()
	_indicador.name = "Indicador"
	add_child(_indicador)


func _montar_sprite() -> void:
	if dados == null or dados.folha == "":
		return
	var quadros := Jogador.montar_quadros(dados.folha)
	if quadros == null:
		push_error("Npc %s: folha de caminhada nao carregou — %s"
				% [dados.id, dados.folha])
		return
	_sprite = AnimatedSprite2D.new()
	_sprite.name = "Sprite"
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.centered = false
	_sprite.offset = Vector2(-Jogador.CELULA_FOLHA * 0.5,
			-(Jogador.CELULA_FOLHA - 2))
	_sprite.sprite_frames = quadros
	_sprite.animation = "parado_" + dados.direcao
	_sprite.frame = 0
	add_child(_sprite)


func mostrar_indicador(sim: bool) -> void:
	if _indicador != null:
		_indicador.mostrar(sim)


## Vira-se para um ponto do mundo. Chamado quando a conversa comeca: um NPC que
## fala de costas para quem o chamou desmente a propria caixa de dialogo.
func olhar_para(alvo: Vector2) -> void:
	var nova := direcao_na_tela(alvo - global_position,
			dados.direcao if dados != null else "baixo")
	if _sprite != null:
		_sprite.animation = "parado_" + nova
		_sprite.frame = 0
	if dados != null:
		dados.direcao = nova


## Uma das 4 direcoes da folha para um deslocamento `d` em pixels. Compara no
## CHAO, nao na tela: em projecao 2:1, 16px verticais valem 32px horizontais, e
## sem desfazer isso todo alvo parece estar ao norte ou ao sul. `atual` volta
## quando nao ha deslocamento.
static func direcao_na_tela(d: Vector2, atual: String) -> String:
	if d.length_squared() < 0.01:
		return atual
	var vertical := absf(d.y) * 2.0 > absf(d.x)
	return ("baixo" if d.y > 0.0 else "cima") if vertical \
			else ("direita" if d.x > 0.0 else "esquerda")


## Caminha pelos pontos (pixels do mundo) a `velocidade` pixels por segundo, com a
## animacao de andar. Para cutscene: o NPC nao tem fisica, e o tween so move a
## posicao. Devolve o tween; ao fim ele fica parado olhando na ultima direcao.
func andar_por(pontos: Array, velocidade: float) -> Tween:
	var t := create_tween()
	var de := position
	for p: Vector2 in pontos:
		var dir := direcao_na_tela(p - de, dados.direcao if dados != null else "baixo")
		t.tween_callback(animar_andando.bind(dir, true))
		t.tween_property(self, "position", p, de.distance_to(p) / maxf(velocidade, 1.0))
		de = p
	t.tween_callback(func() -> void:
			animar_andando(dados.direcao if dados != null else "baixo", false))
	return t


func animar_andando(dir: String, andando: bool) -> void:
	if dados != null:
		dados.direcao = dir
	if _sprite == null:
		return
	_sprite.animation = ("andar_" if andando else "parado_") + dir
	if andando:
		_sprite.play()
	else:
		_sprite.stop()
		_sprite.frame = 0


## Distancia ate um ponto do mundo medida em CELULAS DO CHAO.
##
## Desfaz a projecao isometrica antes de medir. Sem isso, o alcance de interacao
## seria um circulo NA TELA — o que na pratica e uma elipse deitada no chao, e o
## jogador conseguiria falar de mais longe pelo norte do que pelo leste.
func distancia_em_celulas(ponto: Vector2) -> float:
	var d := ponto - global_position
	var mx := celula_do_mapa.x * 0.5
	var my := celula_do_mapa.y * 0.5
	var gx := (d.x / mx + d.y / my) * 0.5
	var gy := (d.y / my - d.x / mx) * 0.5
	return sqrt(gx * gx + gy * gy)


func ao_alcance(ponto: Vector2) -> bool:
	return distancia_em_celulas(ponto) <= (dados.alcance if dados != null else 1.6)
