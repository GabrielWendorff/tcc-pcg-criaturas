class_name GerenciadorPesca
extends Node

## Orquestra a pesca inteira: deteccao da agua na exploracao, arco de forca,
## arremesso no mundo, minigame de recolhimento, resultado e limpeza.
##
## E o UNICO no que conhece todas as partes — mesma politica de
## GerenciadorEncontro e GerenciadorDialogo. O medidor nao sabe o que e uma isca,
## o minigame nao sabe que existe um mundo, a linha no mundo nao sabe que existe
## um minigame, e a regra (presentation/pesca/regras/) nao sabe que existe Node.
## Isso e o que deixa tools/test_pesca.gd jogar a pesca sem janela e a cena de
## teste trocar a geometria do mapa por um retangulo de agua.
##
## ROTEIRO (EstadoPesca):
##   OCIOSO      o indicador "[F] PESCAR" aparece sobre o jogador quando ha vara
##               na mao e agua a frente; usar_item comeca
##   ARREMESSO   jogador congelado, vara erguida, arco de forca oscilando;
##               usar_item trava a forca -> vara gira -> linha voa -> pousa
##   RECOLHENDO  minigame no ar; a SimulacaoRecolhimento decide o desfecho
##   FISGADO     tremor, "FISGOU!", peixe_fisgado(criatura) — ponto de integracao
##   FALHOU      "ESCAPOU..." / "Nada mordeu a isca." / cancelada
##   -> OCIOSO   encerrar(): fecha a tela, recolhe a linha, devolve o controle
## ui_cancel cancela em qualquer fase ativa.
##
## DESACOPLADO DO MAPA: preparar() recebe `e_agua` e `regiao_em` como Callable,
## e nao o MundoIso. A cena do jogo liga ao terreno do mapa; uma cena de teste
## liga a um retangulo. Nenhuma linha aqui sabe o que e uma celula de terreno.
##
## DETERMINISMO (RF03) — um RandomNumberGenerator so, semeado com
## world_seed + DESLOCAMENTO_SEED (separado do encontro, 0x5E7A, e do ruido do
## perfil, 0x9E5CA), alimenta a simulacao de todos os lances da partida, que o
## consome sem re-semear. Mesma seed + mesmos lances + mesma entrada = mesmos
## monstros, no mesmo tempo. Os perfis sao derivados UMA vez, depois da geracao,
## e nao tocam o RNG do gerador: o bestiario e as metricas RF04/RF08 sao os
## mesmos de antes da pesca existir.
##
## ROTINAS COM AWAIT guardam o token `_geracao`, como GerenciadorEncontro: o
## lance espera a vara girar e a linha pousar, o resultado espera um timer. Se a
## pesca for cancelada ou encerrada no meio, a rotina acorda, ve que o token
## mudou e desiste em silencio — sem transicao invalida, sem mexer numa
## simulacao que ja nao existe.

signal pesca_iniciada()
signal estado_mudou(anterior: EstadoPesca.Estado, atual: EstadoPesca.Estado)
## A isca caiu na agua; comeca RECOLHENDO. `distancia` em celulas do chao.
signal arremessado(forca: float, zona: String, distancia: float)
signal silhueta_surgiu(criatura: Criatura)
## PONTO DE INTEGRACAO com a batalha/captura futuras. A pesca para aqui: com
## encerrar_ao_fisgar = false, fica em FISGADO (jogador congelado) ate quem
## recebeu o sinal chamar encerrar().
signal peixe_fisgado(criatura: Criatura)
## "cancelada" | "recolhida" | "fugiu".
signal pesca_falhou(motivo: String)
## Voltou a OCIOSO e o controle foi devolvido ao jogador.
signal pesca_encerrada()
## Recado curto para o HUD ("Equipe a vara...", "Nada de agua...").
signal aviso(texto: String)

const CAMADA_INTERFACE := 84
const DESLOCAMENTO_SEED := 0x9E5CA0
## Vocabulario canonico, para validar as tabelas da pesca ao montar (a mesma
## checagem que o encontro faz com as tabelas de captura).
const CAMINHO_VOCABULARIO := "res://data/vocabulary.json"

## Tremor da fisgada. Visual, por isso @export (como os outros nos de UI) e nao
## na ConfiguracaoPesca; a camera respeita a opcao do jogador.
@export var duracao_tremor: float = 0.35
@export var intensidade_tremor: float = 3.0
## Altura da parabola do voo da boia, em pixels de mundo.
@export var altura_voo: float = 18.0
## Tempo para a linha voltar a ponta da vara no encerramento.
@export var duracao_recolher_linha: float = 0.2

var cfg: ConfiguracaoPesca
var tabelas: TabelasPesca
var estado := EstadoPesca.new()
## Ligado pelo tutorial: tolerancias largas, monstro facil garantido, legenda do
## arco. Vale a partir do PROXIMO lance (a simulacao do lance corrente ja nasceu).
var modo_tutorial: bool = false
var encerrar_ao_fisgar: bool = true
## Pergunta feita antes de comecar (e de mostrar o indicador). A cena liga aqui
## o que mais tiver o controle: conversa, encontro, roda, mapa. Padrao: pode.
var permissao: Callable = func() -> bool: return true
var erro: String = ""
var interface: InterfacePesca

var _jogador: Jogador
var _camera: CameraExploracao
var _catalogo: CatalogoCorpos
var _e_agua: Callable
var _regiao_em: Callable
var _celula: Vector2i = Vector2i(32, 16)
## Perfis das criaturas elegiveis, na ordem do bestiario. Calculados uma vez.
var _perfis: Array = []
var _rng := RandomNumberGenerator.new()

var _indicador: IndicadorInteracao
var _lancamento: LancamentoMundo

# --- lance corrente ---
var _agua: Dictionary = {}
var _sim: SimulacaoRecolhimento
var _ponto: PontoDePesca
var _criatura: Criatura
var _lancando: bool = false

## Token das rotinas assincronas (ver o topo do arquivo).
var _geracao: int = 0

# --- cache da sondagem do indicador (refeita so quando o jogador anda/vira) ---
var _sonda_posicao: Vector2 = Vector2.INF
var _sonda_direcao: String = ""
var _sonda_ok: bool = false


## Monta tudo. Devolve false com `erro` preenchido em vez de deixar meia
## montagem — mesma politica de GerenciadorEncontro.preparar().
##   e_agua:    func(pos_mundo: Vector2) -> bool
##   regiao_em: func(pos_mundo: Vector2) -> String  (id da regiao; "" = nenhuma)
## `catalogo_corpos` da a forma das silhuetas; null = peixe generico.
func preparar(jogador: Jogador, camera: CameraExploracao, bestiario: Array, world_seed: int,
		e_agua: Callable, regiao_em: Callable, tamanho_celula: Vector2i = Vector2i(32, 16),
		catalogo_corpos: CatalogoCorpos = null) -> bool:
	erro = ""
	if jogador == null:
		erro = "jogador ausente"
		return false
	if not e_agua.is_valid():
		erro = "e_agua invalido (esperado func(pos_mundo: Vector2) -> bool)"
		return false
	_jogador = jogador
	_camera = camera
	_catalogo = catalogo_corpos
	_e_agua = e_agua
	_regiao_em = regiao_em
	_celula = tamanho_celula if tamanho_celula.x > 0 and tamanho_celula.y > 0 \
			else Vector2i(32, 16)

	cfg = ConfiguracaoPesca.carregar()
	# Calibragem incoerente nao impede pescar — so avisa. O teste (test_pesca)
	# e quem a reprova; aqui o jogo segue com o que tem.
	for problema: String in cfg.validar():
		push_warning("GerenciadorPesca: configuracao — " + problema)

	tabelas = TabelasPesca.carregar()
	if tabelas == null:
		erro = "tabelas de pesca nao carregaram (res://data/pesca/)"
		return false
	var vocabulario := _ler_vocabulario()
	if not vocabulario.is_empty():
		var faltando := tabelas.validar(vocabulario)
		if not faltando.is_empty():
			erro = "tabelas de pesca incoerentes com o vocabulario: " + ", ".join(faltando)
			return false

	_perfis = tabelas.perfis_do_bestiario(bestiario)
	_rng.seed = world_seed + DESLOCAMENTO_SEED
	_montar_nos()
	return true


func _montar_nos() -> void:
	if not estado.mudou.is_connected(_ao_mudar_estado):
		estado.mudou.connect(_ao_mudar_estado)

	if interface == null:
		interface = InterfacePesca.new()
		interface.name = "InterfacePesca"
		interface.layer = CAMADA_INTERFACE
		add_child(interface)
	interface.preparar(cfg, _catalogo)

	if _lancamento == null:
		# Filho deste Node (que nao e CanvasItem): a linha e desenhada direto no
		# canvas do mundo, com a camera, em coordenadas globais — e fica fora do
		# y-sort das Entidades, que a esconderia atras da arvore da margem.
		_lancamento = LancamentoMundo.new()
		_lancamento.name = "LancamentoMundo"
		add_child(_lancamento)

	if _indicador != null and is_instance_valid(_indicador):
		_indicador.queue_free()
	# Filho do JOGADOR, como o "!" do encontro: o aviso e de quem vai pescar.
	_indicador = IndicadorInteracao.new()
	_indicador.name = "IndicadorPesca"
	_indicador.configurar(cfg.texto("indicador_tecla"), cfg.texto("indicador_texto"))
	_jogador.add_child(_indicador)


# ------------------------------------------------------------------ consultas

func ativa() -> bool:
	return estado.ativa()


## Vara na mao? (o item equipado declara uso "pescar").
func tem_vara() -> bool:
	if _jogador == null:
		return false
	var item := _jogador.item_atual()
	return item != null and item.uso == "pescar"


## Sonda a agua na direcao encarada, a partir do PE do jogador.
## {"ok", "inicio", "fim" (mundo), "comprimento" (celulas, inicio..fim),
##  "direcao" (unitario, tela), "distancia_inicio", "distancia_fim" (celulas do
##  jogador ate inicio/fim)}. O fim para no arremesso maximo: agua alem disso nao
## e alcancavel e nao precisa ser medida.
func agua_a_frente() -> Dictionary:
	return _sondar(true)


## Ociosa, permitida, com vara e com agua a frente.
func pode_pescar_aqui() -> bool:
	return estado.e(EstadoPesca.Estado.OCIOSO) and _permitido() and tem_vara() \
			and _ha_agua_a_frente()


## Comeca o ARREMESSO. Quando nao pode, devolve false — e, se o motivo for do
## jogador (sem vara, sem agua), emite aviso() com o texto para o HUD. Outra
## coisa com o controle (permissao falsa) recusa calada: nao e erro de quem
## apertou.
func tentar_iniciar() -> bool:
	if _jogador == null or interface == null or estado.ativa():
		return false
	if not _permitido():
		return false
	if not tem_vara():
		aviso.emit(cfg.texto("sem_vara"))
		return false
	var agua := agua_a_frente()
	if not bool(agua.get("ok", false)):
		aviso.emit(cfg.texto("sem_agua"))
		return false
	if not estado.mudar_para(EstadoPesca.Estado.ARREMESSO):
		return false
	_geracao += 1
	_agua = agua
	_lancando = false
	_criatura = null
	_jogador.congelar(true)
	var mao := _mao()
	if mao != null:
		mao.pose_de_pesca(true)
	_indicador.mostrar(false)
	interface.mostrar_medidor(modo_tutorial)
	pesca_iniciada.emit()
	return true


## Trava o arco e lanca. `forca` < 0 = o valor atual do medidor; um valor 0..1
## forca a posicao (teste, roteiro). Ignorado fora do ARREMESSO ou com o lance
## ja em curso.
func confirmar_arremesso(forca: float = -1.0) -> void:
	if not estado.e(EstadoPesca.Estado.ARREMESSO) or _lancando:
		return
	var travada: float = interface.medidor.parar()
	var f: float = clampf(forca if forca >= 0.0 else travada, 0.0, 1.0)
	_lancando = true
	_lancar(f, _geracao)


## Desiste: ARREMESSO/RECOLHENDO viram FALHOU("cancelada") e encerram na hora;
## durante o letreiro do resultado, pula o letreiro. Em FISGADO com
## encerrar_ao_fisgar = false nao faz nada: a fisgada ja pertence a quem recebeu
## peixe_fisgado, e so ele encerra.
func cancelar() -> void:
	match estado.atual:
		EstadoPesca.Estado.ARREMESSO, EstadoPesca.Estado.RECOLHENDO:
			_falhar("cancelada")
		EstadoPesca.Estado.FISGADO:
			if encerrar_ao_fisgar:
				encerrar()
		EstadoPesca.Estado.FALHOU:
			encerrar()


## Fecha a interface, recolhe a linha, abaixa a vara, descongela o jogador, volta
## a OCIOSO e emite pesca_encerrada. Sem pesca ativa, nao faz nada.
func encerrar() -> void:
	if not estado.ativa():
		return
	# Invalida qualquer rotina da pesca que ainda esteja num await.
	_geracao += 1
	_lancando = false
	_soltar_simulacao()
	_ponto = null
	interface.fechar()
	_lancamento.recolher(duracao_recolher_linha)
	var mao := _mao()
	if mao != null:
		mao.pose_de_pesca(false)
	_jogador.congelar(false)
	# FISGADO/FALHOU -> OCIOSO estao na tabela. De ARREMESSO/RECOLHENDO (um
	# encerrar externo, troca de cena) nao estao: reiniciar() e a saida de limpeza.
	if estado.pode_ir_para(EstadoPesca.Estado.OCIOSO):
		estado.mudar_para(EstadoPesca.Estado.OCIOSO)
	else:
		estado.reiniciar()
	_criatura = null
	_sonda_posicao = Vector2.INF
	pesca_encerrada.emit()


## A criatura fisgada (em FISGADO) ou a da silhueta que esta seguindo a isca
## (em RECOLHENDO). Null sem nenhuma das duas.
func criatura_atual() -> Criatura:
	if _criatura != null:
		return _criatura
	if _sim != null and _sim.perfil != null:
		return _sim.perfil.criatura
	return null


## A simulacao do lance corrente; null fora de RECOLHENDO.
func simulacao() -> SimulacaoRecolhimento:
	return _sim if estado.e(EstadoPesca.Estado.RECOLHENDO) else null


## O ponto de pesca do lance corrente (null antes de a isca pousar).
func ponto_atual() -> PontoDePesca:
	return _ponto


## Perfis de pesca das criaturas elegiveis desta seed (ordem do bestiario).
func perfis() -> Array:
	return _perfis


# --------------------------------------------------------------------- entrada

func _process(_delta: float) -> void:
	if _jogador == null or _indicador == null:
		return
	_indicador.mostrar(not estado.ativa() and pode_pescar_aqui())


func _unhandled_input(evento: InputEvent) -> void:
	if _jogador == null or interface == null:
		return
	if estado.ativa():
		if evento.is_action_pressed("ui_cancel"):
			if estado.e(EstadoPesca.Estado.FISGADO) and not encerrar_ao_fisgar:
				return
			cancelar()
			get_viewport().set_input_as_handled()
			return
		if evento.is_action_pressed("usar_item"):
			if estado.e(EstadoPesca.Estado.ARREMESSO) and interface.medidor.pode_travar():
				confirmar_arremesso()
			# Engolido em qualquer fase ativa: um segundo F (ou clique) no meio da
			# pesca nao pode chegar a outro sistema.
			get_viewport().set_input_as_handled()
		return
	if not evento.is_action_pressed("usar_item") or not _permitido():
		return
	# usar_item e generico (F, clique, botao do controle). Sem vara E sem agua a
	# frente, o aperto nao e uma tentativa de pescar: nao avisa nem consome. Com
	# um dos dois, e — e o aviso diz o que falta.
	if not tem_vara() and not _ha_agua_a_frente():
		return
	tentar_iniciar()
	get_viewport().set_input_as_handled()


# ---------------------------------------------------------------------- lance

func _lancar(forca: float, token: int) -> void:
	var zona := ArcoDeForca.zona(forca, cfg.limite_verde, cfg.limite_amarelo)
	var pouso := _ponto_de_pouso(cfg.distancia_de_forca(forca))
	var mao := _mao()
	if mao != null:
		# O arco fica na tela, travado, durante o giro da vara: o jogador ve onde
		# parou enquanto o braco lanca.
		mao.animar_arremesso()
		await mao.arremesso_concluido
		if _abandonado(token):
			return
	interface.esconder_medidor()
	var destino: Vector2 = pouso["posicao"]
	_lancamento.lancar(_ponta_da_vara, destino, cfg.duracao_voo, altura_voo)
	await _lancamento.pousou
	if _abandonado(token):
		return
	_comecar_recolhimento(forca, zona, float(pouso["distancia"]), destino)


## Ponto de pouso ao longo do trecho de agua sondado: a `desejada` celulas do
## jogador, presa entre o comeco da agua (isca nao cai na terra) e o fim do
## trecho (nem do outro lado da margem).
func _ponto_de_pouso(desejada: float) -> Dictionary:
	var dir: Vector2 = _agua.get("direcao", Vector2.RIGHT)
	var de: float = float(_agua.get("distancia_inicio", 0.0))
	var ate: float = maxf(float(_agua.get("distancia_fim", de)), de)
	var d: float = clampf(desejada, de, ate)
	var por_px: float = _celulas(dir)
	var px: float = d / por_px if por_px > 0.0 else 0.0
	return {"posicao": _jogador.global_position + dir * px, "distancia": d}


func _comecar_recolhimento(forca: float, zona: String, distancia: float, pouso: Vector2) -> void:
	var regiao: String = ""
	if _regiao_em.is_valid():
		var r: Variant = _regiao_em.call(pouso)
		if r is String or r is StringName:
			regiao = String(r)
	_ponto = tabelas.ponto_da_regiao(regiao)
	var candidatos: Array = _ponto.candidatos(_perfis) if _ponto != null else []
	var perfil_tutorial: PerfilPesca = null
	if modo_tutorial and candidatos.is_empty():
		# O tutorial PROMETE a fisgada. Um ponto sem candidato nenhum deixaria a
		# simulacao rodando para sempre; o monstro mais facil da seed inteira
		# cumpre a promessa em qualquer agua.
		perfil_tutorial = _mais_facil_da_seed()
		if perfil_tutorial == null:
			push_warning("GerenciadorPesca: tutorial sem nenhuma criatura pescavel nesta seed")
	_sim = SimulacaoRecolhimento.new(cfg, distancia, candidatos, _rng, modo_tutorial,
			perfil_tutorial)
	if _ponto != null:
		_sim.multiplicador_surgimento = _ponto.multiplicador_surgimento
	_sim.silhueta_surgiu.connect(_on_silhueta_surgiu)
	_sim.terminou.connect(_on_sim_terminou)
	_lancando = false
	estado.mudar_para(EstadoPesca.Estado.RECOLHENDO)
	interface.abrir_minigame(_sim, modo_tutorial or cfg.mostrar_alvos)
	arremessado.emit(forca, zona, distancia)


func _on_silhueta_surgiu(perfil: PerfilPesca) -> void:
	if perfil != null and perfil.criatura != null:
		silhueta_surgiu.emit(perfil.criatura)


func _on_sim_terminou(desfecho: String, perfil: PerfilPesca) -> void:
	match desfecho:
		SimulacaoRecolhimento.FISGADO:
			_fisgar(perfil)
		SimulacaoRecolhimento.FUGIU:
			_falhar("fugiu")
		_:
			_falhar("recolhida")


# ------------------------------------------------------------------ desfechos

func _fisgar(perfil: PerfilPesca) -> void:
	if not estado.mudar_para(EstadoPesca.Estado.FISGADO):
		return
	var token := _geracao
	_criatura = perfil.criatura if perfil != null else null
	if _camera != null:
		_camera.tremer(duracao_tremor, intensidade_tremor)
		# O minigame cobre o mundo, entao o tremor da camera mal aparece. A tela
		# da pesca treme junto — mas so se a camera aceitou tremer, que e onde a
		# opcao do jogador e consultada.
		if _camera.tremendo():
			interface.tremer(duracao_tremor, intensidade_tremor)
	interface.mostrar_resultado(cfg.texto("fisgou"), TemaEncontro.OURO)
	peixe_fisgado.emit(_criatura)
	if not encerrar_ao_fisgar or _abandonado(token):
		return
	await _segurar_resultado()
	if _abandonado(token):
		return
	encerrar()


## FALHOU com `motivo`. Cancelada encerra na hora (quem cancelou quer o controle
## de volta, e o recado vai pelo aviso); fugiu/recolhida seguram o letreiro por
## cfg.duracao_resultado antes de encerrar.
func _falhar(motivo: String) -> void:
	if not estado.mudar_para(EstadoPesca.Estado.FALHOU):
		return
	# Invalida o lance em voo (await da vara ou da linha).
	_geracao += 1
	var token := _geracao
	_lancando = false
	interface.esconder_medidor()
	pesca_falhou.emit(motivo)
	if _abandonado(token):
		return
	if motivo == "cancelada":
		aviso.emit(cfg.texto("cancelada"))
		encerrar()
		return
	# Os textos nao tem especificador de formato: nada de % aqui.
	var chave: String = "escapou" if motivo == "fugiu" else motivo
	var cor: Color = TemaEncontro.FALHA if motivo == "fugiu" else TemaEncontro.ATENCAO
	interface.mostrar_resultado(cfg.texto(chave), cor)
	await _segurar_resultado()
	if _abandonado(token):
		return
	encerrar()


# ---------------------------------------------------------------------- apoio

## Espera o letreiro do resultado ficar na tela. Timer que PARA com a arvore
## pausada (process_always = false): com a pergunta "pular a licao?" aberta por
## cima, o letreiro espera junto, em vez de a pesca se encerrar escondida atras
## dela.
func _segurar_resultado() -> void:
	await get_tree().create_timer(maxf(cfg.duracao_resultado, 0.0), false).timeout


## A pesca que iniciou esta rotina ainda e a pesca corrente?
func _abandonado(token: int) -> bool:
	return token != _geracao


func _ao_mudar_estado(anterior: EstadoPesca.Estado, atual: EstadoPesca.Estado) -> void:
	estado_mudou.emit(anterior, atual)


func _permitido() -> bool:
	if not permissao.is_valid():
		return true
	return bool(permissao.call())


func _mao() -> SlotDaMao:
	return _jogador.mao if _jogador != null else null


## Origem da linha: a ponta da vara. Sem mao (jogador de teste), a altura da mao
## sobre o pe.
func _ponta_da_vara() -> Vector2:
	var mao := _mao()
	if mao != null and mao.is_inside_tree():
		return mao.ponta_global()
	return _jogador.global_position + Vector2(0.0, -12.0)


func _soltar_simulacao() -> void:
	if _sim == null:
		return
	if _sim.silhueta_surgiu.is_connected(_on_silhueta_surgiu):
		_sim.silhueta_surgiu.disconnect(_on_silhueta_surgiu)
	if _sim.terminou.is_connected(_on_sim_terminou):
		_sim.terminou.disconnect(_on_sim_terminou)
	_sim = null


## O mais facil de TODOS os perfis da seed (reserva do tutorial).
func _mais_facil_da_seed() -> PerfilPesca:
	var todos: Array = []
	for p: Variant in _perfis:
		todos.append({"perfil": p, "peso": 1.0})
	return PontoDePesca.mais_facil(todos)


## Agua comeca a frente? Versao barata para o indicador (para no inicio da agua)
## e com cache: so refaz a marcha quando o jogador anda ou vira.
func _ha_agua_a_frente() -> bool:
	if _jogador == null:
		return false
	var pos := _jogador.global_position
	if pos == _sonda_posicao and _jogador.direcao == _sonda_direcao:
		return _sonda_ok
	_sonda_posicao = pos
	_sonda_direcao = _jogador.direcao
	_sonda_ok = bool(_sondar(false).get("ok", false))
	return _sonda_ok


## Marcha em pixels a partir do pe, na direcao encarada, de passo_sonda_px em
## passo_sonda_px. Procura o primeiro ponto de agua ate alcance_agua_celulas; com
## `ate_o_fim`, segue pelo trecho continuo ate a agua acabar ou o arremesso
## maximo. Distancias em celulas do chao (a metrica de Npc.distancia_em_celulas).
func _sondar(ate_o_fim: bool) -> Dictionary:
	var r := {"ok": false, "inicio": Vector2.ZERO, "fim": Vector2.ZERO, "comprimento": 0.0,
			"direcao": Vector2.ZERO, "distancia_inicio": 0.0, "distancia_fim": 0.0}
	if _jogador == null or not _e_agua.is_valid() or cfg == null:
		return r
	var dir := _direcao_encarada()
	r["direcao"] = dir
	var pe := _jogador.global_position
	var passo: float = maxf(cfg.passo_sonda_px, 0.5)
	var celulas_por_passo: float = _celulas(dir) * passo
	if celulas_por_passo <= 0.0:
		return r
	var passos_ate_agua: int = int(floorf(cfg.alcance_agua_celulas / celulas_por_passo))
	var achou: int = -1
	for i in range(1, passos_ate_agua + 1):
		if _agua_em(pe + dir * passo * float(i)):
			achou = i
			break
	if achou < 0:
		return r
	var inicio := pe + dir * passo * float(achou)
	var ultimo: int = achou
	if ate_o_fim:
		var passos_max: int = int(ceilf(cfg.distancia_max_celulas / celulas_por_passo))
		var j: int = achou + 1
		while j <= passos_max and _agua_em(pe + dir * passo * float(j)):
			ultimo = j
			j += 1
	var fim := pe + dir * passo * float(ultimo)
	r["ok"] = true
	r["inicio"] = inicio
	r["fim"] = fim
	r["comprimento"] = _celulas(fim - inicio)
	r["distancia_inicio"] = _celulas(inicio - pe)
	r["distancia_fim"] = _celulas(fim - pe)
	return r


func _agua_em(p: Vector2) -> bool:
	return bool(_e_agua.call(p))


## Direcao encarada como vetor unitario de TELA. Cima/baixo sao (0, +-0.5)
## normalizados — o contrato registra o 0.5 da projecao 2:1, e a normalizacao
## deixa a marcha com o mesmo passo em pixels nos quatro sentidos.
func _direcao_encarada() -> Vector2:
	match _jogador.direcao:
		"esquerda":
			return Vector2(-1.0, 0.0)
		"baixo":
			return Vector2(0.0, 0.5).normalized()
		"cima":
			return Vector2(0.0, -0.5).normalized()
	return Vector2(1.0, 0.0)


## Comprimento de um deslocamento de tela em CELULAS DO CHAO: desfaz a projecao
## isometrica (mesma conta de Npc.distancia_em_celulas). 32 px horizontais = 16 px
## verticais = raiz(2) celula.
func _celulas(d: Vector2) -> float:
	var mx: float = float(_celula.x) * 0.5
	var my: float = float(_celula.y) * 0.5
	var gx: float = (d.x / mx + d.y / my) * 0.5
	var gy: float = (d.y / my - d.x / mx) * 0.5
	return sqrt(gx * gx + gy * gy)


func _ler_vocabulario() -> Dictionary:
	if not FileAccess.file_exists(CAMINHO_VOCABULARIO):
		return {}
	var dados: Variant = JSON.parse_string(FileAccess.get_file_as_string(CAMINHO_VOCABULARIO))
	return dados if dados is Dictionary else {}
