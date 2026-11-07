class_name CutsceneChegada
extends Node

## A chegada de onibus: a abertura de uma partida nova, dentro do proprio mundo.
##
##   onibus sai do tunel ──▶ para ──▶ jogador desce ──▶ onibus volta de re
##                                          │
##                         Mirela vem da praca ate ele
##                                          │
##        "chegada": o que sao as criaturas, todo mundo tem uma, "e a sua?"
##                                          │
##        "sem_criatura": o choque ──▶ escolha da primeira criatura
##                                          │
##        "apos_escolha": o kit, batalha e captura em poucas falas ──▶ fim
##
## NAO E UM SISTEMA DE CUTSCENES. E esta cena, escrita como codigo, porque e a unica: um
## interpretador de roteiro generico custaria mais que ela e nao teria segundo uso.
## O que e conteudo fica fora do codigo, como no resto do projeto: ONDE as coisas
## acontecem esta no mapa (MundoIso.chegada(), gravado e validado pelo gerador), o
## tempo e os textos de interface em autoral/cutscenes/chegada.json, e as falas na
## arvore da Mirela.
##
## Nao conhece a equipe nem a tela de escolha: pede a escolha (escolha_pedida) e a cena
## responde com escolha_feita() ou escolha_cancelada(). Pular (P, com confirmacao)
## leva direto a escolha: quem pula ainda recebe a primeira criatura.

signal terminada(pulada: bool)
## A Mirela terminou o "selecione um destes": a cena abre a escolha inicial.
signal escolha_pedida()

const CAMINHO := "res://autoral/cutscenes/chegada.json"
const ACAO_PULAR := "pular_tutorial"
const PROP_ONIBUS := "onibus"
## Da frente do onibus ao centro da pegada, em celulas no eixo x da grade. A frente e
## a chave do y-sort: e ela que precisa passar na frente do paredao ao sair da boca.
const FRENTE := 1.35
## Meia largura da carroceria, em celulas no eixo y da grade.
const MEIA_LARGURA := 0.55
## O onibus comeca inteiro dentro do tunel, sombra inclusive.
const RECUO_INICIAL := 2.4
const CAMADA_FAIXAS := 80
const CAMADA_VEU := 99
const ALTURA_FAIXA := 44.0

var erro: String = ""
var pulada: bool = false
## Fase corrente: "" (inativa), onibus, mirela, conversa, escolha, explicacao.
var fase: String = ""
var dados: Dictionary = {}
## Pergunta se P pode abrir a confirmacao agora. A cena liga aqui o dono da tela.
var permissao_pulo: Callable

var _mundo: MundoIso
var _jogador: Jogador
var _camera: CameraExploracao
var _dialogos: GerenciadorDialogo
var _mirela: Npc
var _geo: Dictionary = {}
var _origem_mirela: Vector2
var _direcao_mirela: String = "baixo"
var _onibus: Node2D
var _sprite_onibus: Sprite2D
var _ancora_onibus: Vector2
var _x_boca: float = 0.0
var _x_onibus: float = 0.0
var _movendo: bool = false
var _relogio: float = 0.0
var _dica: DicaTutorial
var _faixas: CanvasLayer
var _veu: CanvasLayer
var _tweens: Array[Tween] = []
var _geracao: int = 0
var _pausou_arvore: bool = false


static func carregar_dados() -> Dictionary:
	if not FileAccess.file_exists(CAMINHO):
		return {}
	var lido: Variant = JSON.parse_string(FileAccess.get_file_as_string(CAMINHO))
	return lido if lido is Dictionary else {}


## Liga a cena ao mundo. false com `erro` quando falta peca: mapa sem "chegada", prop
## do onibus ausente, NPC ou nos de dialogo inexistentes.
func preparar(mundo: MundoIso, jogador: Jogador, camera: CameraExploracao,
		dialogos: GerenciadorDialogo) -> bool:
	_mundo = mundo
	_jogador = jogador
	_camera = camera
	_dialogos = dialogos
	dados = carregar_dados()
	_geo = mundo.chegada()
	if dados.is_empty():
		erro = "nao leu " + CAMINHO
	elif _geo.is_empty():
		erro = "o mapa '%s' nao tem 'chegada'" % mundo.id_mapa
	elif mundo.sprite_de_prop(PROP_ONIBUS) == null:
		erro = "prop '%s' ausente de props.json" % PROP_ONIBUS
	else:
		_mirela = dialogos.npc_por_id(String(dados.get("npc", "")))
		var arvore := dialogos.dialogos.arvore(_mirela.dados.dialogo) if _mirela != null else null
		if _mirela == null:
			erro = "NPC '%s' nao esta neste mapa" % dados.get("npc", "")
		elif arvore == null or not arvore.nos.has(String(dados["no_chegada"])) \
				or not arvore.nos.has(String(dados["no_apos_escolha"])):
			erro = "a arvore da %s nao tem os nos da chegada" % _mirela.dados.nome
	if erro != "":
		return false
	_dica = DicaTutorial.new()
	_dica.name = "DicaChegada"
	add_child(_dica)
	_dica.resposta_pulo.connect(_ao_responder_pulo)
	_dialogos.conversa_terminada.connect(_ao_terminar_conversa)
	return true


func ativa() -> bool:
	return fase != ""


## A cena tem a tela so enquanto ninguem mais a tem: na conversa o dono e o dialogo, e
## na escolha, a tela de escolha.
func dona_da_tela() -> bool:
	return fase == "onibus" or fase == "mirela"


func iniciar() -> void:
	if erro != "" or ativa():
		return
	_geracao += 1
	pulada = false
	fase = "onibus"
	_origem_mirela = _mirela.position
	_direcao_mirela = _mirela.dados.direcao
	_jogador.congelar(true)
	_jogador.visible = false
	_jogador.position = _mundo.celula_para_mundo(_celula("desembarque"))
	_dialogos.suspender(true)
	# A linha de corte passa pela boca no lado FUNDO da carroceria (y menor): todo
	# ponto dentro da rocha (x < boca, y >= esse lado) cai a esquerda dela na tela,
	# qualquer que seja a altura. O preco e a frente sumir um instante a mais, ja
	# dentro da sombra da boca.
	_x_boca = _mundo.grade_para_mundo(_ponto("boca") - Vector2(0.0, MEIA_LARGURA)).x
	_criar_onibus(_ponto("boca").x - RECUO_INICIAL)
	_camera.seguir(_onibus)
	_montar_faixas()
	_montar_veu()
	_dica.mostrar_aviso_pulo(String(_texto_pulo("aviso")), true)
	_sequencia(_geracao)


# ----------------------------------------------------------------- roteiro
func _sequencia(token: int) -> void:
	var d: Dictionary = dados.get("duracoes", {})
	var parada: float = _ponto("parada").x
	var inicio: float = _x_onibus

	_movendo = true
	var chega := _tween()
	chega.tween_method(_por_onibus, inicio, parada, float(d.get("onibus_chegando", 4.0))) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await chega.finished
	_movendo = false
	if token != _geracao:
		return
	await _esperar(float(d.get("espera_porta", 0.5)))
	if token != _geracao:
		return

	# Desce: aparece ao lado da porta e a camera passa do onibus para ele.
	var pontos := _caminho_mirela()
	_jogador.visible = true
	_jogador.modulate.a = 0.0
	_jogador.olhar_para(pontos[-1])
	_camera.alvo = _jogador
	var desce := _tween()
	desce.tween_property(_jogador, "modulate:a", 1.0, float(d.get("descer", 0.3)))
	await desce.finished
	if token != _geracao:
		return

	# O onibus volta para o tunel enquanto a Mirela vem da praca.
	fase = "mirela"
	_movendo = true
	var parte := _tween()
	parte.tween_method(_por_onibus, parada, inicio, float(d.get("onibus_partindo", 3.0))) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	parte.tween_callback(_tirar_onibus)
	var anda := _mirela.andar_por(pontos, float(dados.get("velocidade_mirela", 52.0)))
	_tweens.append(anda)
	await anda.finished
	if token != _geracao:
		return
	_mirela.olhar_para(_jogador.position)
	_jogador.olhar_para(_mirela.position)
	_fechar_faixas()

	fase = "conversa"
	_dialogos.suspender(false)
	if not _dialogos.conversar_com(_mirela, "", String(dados["no_chegada"])):
		_pedir_escolha()


func _ao_terminar_conversa(_npc: Npc) -> void:
	match fase:
		"conversa":
			_pedir_escolha()
		"explicacao":
			_finalizar(false)


func _pedir_escolha() -> void:
	fase = "escolha"
	_dica.mostrar_aviso_pulo("", false)
	escolha_pedida.emit()


## A cena avisa que a primeira criatura foi escolhida (ou que ja havia uma).
func escolha_feita() -> void:
	if fase != "escolha":
		return
	if pulada:
		_finalizar(true)
		return
	fase = "explicacao"
	_dica.mostrar_aviso_pulo(String(_texto_pulo("aviso")), true)
	_dialogos.suspender(false)
	_mirela.olhar_para(_jogador.position)
	if not _dialogos.conversar_com(_mirela, "", String(dados["no_apos_escolha"])):
		_finalizar(false)


## Fechou a escolha sem escolher: a cena acaba e a Mirela continua oferecendo na praca
## (no "oferta"), que e o caminho de sempre.
func escolha_cancelada() -> void:
	if fase == "escolha":
		_finalizar(pulada)


# -------------------------------------------------------------------- pulo
func _input(evento: InputEvent) -> void:
	if not ativa() or pulada or _dica == null or _dica.perguntando() \
			or not InputMap.has_action(ACAO_PULAR) or fase == "escolha":
		return
	if evento.is_action_pressed(ACAO_PULAR) and not evento.is_echo():
		get_viewport().set_input_as_handled()
		if permissao_pulo.is_valid() and not permissao_pulo.call():
			return
		_dica.perguntar_pulo(String(_texto_pulo("pergunta")), String(_texto_pulo("sim")),
				String(_texto_pulo("nao")))
		if _dica.perguntando():
			_pausou_arvore = not get_tree().paused
			get_tree().paused = true


func _ao_responder_pulo(confirmou: bool) -> void:
	_despausar()
	if confirmou:
		pular()


## Corta a cena onde estiver: onibus some, o jogador fica no desembarque, a Mirela
## volta ao lugar dela. Se a criatura ainda nao foi escolhida, a escolha abre.
func pular() -> void:
	if not ativa() or pulada:
		return
	if _dica.perguntando():
		_dica.fechar_pergunta()
		_despausar()
	pulada = true
	_geracao += 1
	var fase_antes := fase
	fase = "pulando"
	_matar_tweens()
	_jogador.parar_roteiro()
	_tirar_onibus()
	_remover_camadas()
	_jogador.visible = true
	_jogador.modulate.a = 1.0
	if fase_antes == "onibus" or fase_antes == "mirela":
		_jogador.position = _mundo.celula_para_mundo(_celula("desembarque"))
	_camera.seguir(_jogador)
	_mirela.position = _origem_mirela
	_mirela.animar_andando(_direcao_mirela, false)
	_dialogos.suspender(false)
	_dialogos.encerrar_conversa()   # fase "pulando": o fim da conversa e ignorado
	if fase_antes == "explicacao":
		fase = "escolha"
		_finalizar(true)
	else:
		_pedir_escolha()


func _despausar() -> void:
	if _pausou_arvore and is_inside_tree():
		get_tree().paused = false
	_pausou_arvore = false


func _exit_tree() -> void:
	if _dica != null and _dica.perguntando():
		_dica.fechar_pergunta()
	_despausar()


# --------------------------------------------------------------------- fim
func _finalizar(pulou: bool) -> void:
	fase = ""
	_geracao += 1
	_dica.mostrar_aviso_pulo("", false)
	_tirar_onibus()
	_remover_camadas()
	_jogador.visible = true
	_jogador.modulate.a = 1.0
	_jogador.congelar(false)
	_camera.alvo = _jogador
	_dialogos.suspender(false)
	if _mirela.position.distance_to(_origem_mirela) > 1.0:
		var volta := _caminho_mirela()
		volta.reverse()
		volta.remove_at(0)
		volta.append(_origem_mirela)
		var t := _mirela.andar_por(volta, float(dados.get("velocidade_mirela", 52.0)))
		var dir := _direcao_mirela
		t.tween_callback(func() -> void: _mirela.animar_andando(dir, false))
	terminada.emit(pulou)


# ------------------------------------------------------------------ onibus
func _criar_onibus(x_centro: float) -> void:
	_onibus = Node2D.new()
	_onibus.name = "Onibus"
	_sprite_onibus = _mundo.sprite_de_prop(PROP_ONIBUS)
	_sprite_onibus.region_enabled = true
	_ancora_onibus = -_sprite_onibus.offset
	_sprite_onibus.position = -_frente_px()
	_onibus.add_child(_sprite_onibus)
	_mundo.entidades.add_child(_onibus)
	_por_onibus(x_centro)


## Centro do onibus no eixo x da grade (y e o da estrada). Recorta o sprite na boca do
## tunel: o que esta a oeste dela fica dentro da rocha e nao aparece.
func _por_onibus(x_centro: float) -> void:
	_x_onibus = x_centro
	if _onibus == null:
		return
	_onibus.position = _mundo.grade_para_mundo(Vector2(x_centro, _ponto("boca").y)) + _frente_px()
	var tam := _sprite_onibus.texture.get_size()
	var esquerda := _onibus.position.x + _sprite_onibus.position.x - _ancora_onibus.x
	var corte := clampf(roundf(_x_boca - esquerda), 0.0, tam.x)
	_sprite_onibus.visible = corte < tam.x
	_sprite_onibus.region_rect = Rect2(corte, 0.0, tam.x - corte, tam.y)
	_sprite_onibus.offset = Vector2(-_ancora_onibus.x + corte, -_ancora_onibus.y)


func _process(delta: float) -> void:
	if _sprite_onibus == null:
		return
	# Motor ligado: um pixel de balanco, em degrau. Suave leria como barco.
	_relogio += delta
	var balanco := 1.0 if _movendo and int(_relogio * 9.0) % 2 == 0 else 0.0
	_sprite_onibus.position = -_frente_px() - Vector2(0.0, balanco)


func _tirar_onibus() -> void:
	_movendo = false
	if _onibus != null:
		_onibus.queue_free()
	_onibus = null
	_sprite_onibus = null


func onibus() -> Node2D:
	return _onibus


func _frente_px() -> Vector2:
	return Vector2(FRENTE * _mundo.celula.x * 0.5, FRENTE * _mundo.celula.y * 0.5)


# --------------------------------------------------------------- camadas
## Faixas pretas em cima e embaixo: a convencao de "agora e cena, nao controle".
func _montar_faixas() -> void:
	_faixas = CanvasLayer.new()
	_faixas.layer = CAMADA_FAIXAS
	add_child(_faixas)
	for em_cima: bool in [true, false]:
		var f := ColorRect.new()
		f.color = Color(TemaEncontro.CONTORNO, 1.0)
		f.mouse_filter = Control.MOUSE_FILTER_IGNORE
		f.set_anchors_preset(Control.PRESET_TOP_WIDE if em_cima else Control.PRESET_BOTTOM_WIDE)
		f.offset_top = 0.0 if em_cima else 0.0
		f.offset_bottom = 0.0
		_faixas.add_child(f)
		var t := _tween()
		if em_cima:
			t.tween_property(f, "offset_bottom", ALTURA_FAIXA, 0.5)
		else:
			t.tween_property(f, "offset_top", -ALTURA_FAIXA, 0.5)


func _fechar_faixas() -> void:
	if _faixas == null:
		return
	var camada := _faixas
	_faixas = null
	var t := create_tween()
	for f: ColorRect in camada.get_children():
		t.parallel().tween_property(f, "modulate:a", 0.0,
				float(dados.get("duracoes", {}).get("fechar", 0.5)))
	t.tween_callback(camada.queue_free)


func _montar_veu() -> void:
	_veu = CanvasLayer.new()
	_veu.layer = CAMADA_VEU
	add_child(_veu)
	var preto := ColorRect.new()
	preto.color = Color(TemaEncontro.CONTORNO, 1.0)
	preto.set_anchors_preset(Control.PRESET_FULL_RECT)
	preto.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_veu.add_child(preto)
	var t := _tween()
	t.tween_property(preto, "color:a", 0.0, float(dados.get("duracoes", {}).get("abrir", 0.9)))
	var camada := _veu
	t.tween_callback(func() -> void:
			camada.queue_free()
			if _veu == camada:
				_veu = null)


func _remover_camadas() -> void:
	for camada: CanvasLayer in [_faixas, _veu]:
		if camada != null:
			camada.queue_free()
	_faixas = null
	_veu = null


# -------------------------------------------------------------- utilitarios
func _tween() -> Tween:
	var t := create_tween()
	_tweens.append(t)
	return t


func _matar_tweens() -> void:
	for t: Tween in _tweens:
		if t != null and t.is_valid():
			t.kill()
	_tweens.clear()


func _esperar(segundos: float) -> void:
	# process_always = false: a pergunta "pular?" pausa a arvore, e a espera tambem.
	await get_tree().create_timer(segundos, false).timeout


func _ponto(chave: String) -> Vector2:
	var p: Array = _geo.get(chave, [0, 0])
	return Vector2(float(p[0]), float(p[1]))


func _celula(chave: String) -> Vector2i:
	var p: Array = _geo.get(chave, [0, 0])
	return Vector2i(int(p[0]), int(p[1]))


## Caminho da Mirela em pixels do mundo, da praca ate o jogador.
func _caminho_mirela() -> Array:
	var pontos: Array = []
	for p: Array in _geo.get("caminho_mirela", []):
		pontos.append(_mundo.celula_para_mundo(Vector2i(int(p[0]), int(p[1]))))
	return pontos


func _texto_pulo(chave: String) -> String:
	return String(dados.get("pular", {}).get(chave, ""))
