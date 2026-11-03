class_name GerenciadorEncontro
extends Node

## Orquestra o encontro inteiro: deteccao na exploracao, roteiro de aviso e
## transicao, menu, roda, lance e limpeza.
##
## E o UNICO no que conhece todas as partes; nenhuma delas conhece as outras. A
## interface nao sorteia, a roda nao consome item, o calculo nao anima. Isso e o
## que permite testar a regra sem abrir cena (tools/test_encontro.gd) e trocar a
## apresentacao sem tocar na mecanica.
##
## DETECCAO — reaproveita o que a etapa anterior deixou pronto: os PontoDeEncontro
## sao Area2D ja posicionadas pelo mapa, ja no grupo "pontos_de_encontro", com
## `elementos_provaveis` declarado e nenhum sinal conectado (docs/pendencias.md,
## item 7). Ligar o sistema foi conectar `body_entered` — nada no mapa, na arte ou
## no movimento mudou.
##
## QUAL CRIATURA APARECE — FILTRO COM MISTURA (chance_fora_da_regiao) SOBRE O
## BESTIARIO JA GERADO: a regiao filtra quem se encontra ali, e nao como a
## criatura foi feita. O modelo
## generativo (data/*.json, GeradorCriaturas) continua intacto e as metricas de
## RF04/RF08 medem exatamente o mesmo bestiario de antes. Ver
## docs/mudancas-estruturais.md.
##
## DETERMINISMO (RF03) — todo sorteio daqui (encontro, criatura, captura, dano,
## fuga) sai de UM RandomNumberGenerator semeado a partir da world_seed. Nenhuma
## chamada a randi()/randf() globais. Mesma seed e mesma sequencia de acoes
## reproduzem a partida lance a lance.

signal encontro_iniciado(criatura: Criatura)
signal encontro_terminado(desfecho: String, criatura: Criatura)
signal mensagem_registrada(texto: String)

## Camadas de CanvasLayer. A interface fica ACIMA do escurecimento porque o menu
## precisa ser lido sobre a tela ja escura.
const CAMADA_TRANSICAO := 80
const CAMADA_INTERFACE := 90

## Deslocamento aplicado a semente do RNG de jogo, para que a sequencia de
## encontros nao seja a mesma sequencia que gerou o bestiario a partir da mesma
## world_seed.
const DESLOCAMENTO_SEED := 0x5E7A

var world_seed: int = 0
var bestiario: Array = []

var tabelas: TabelasProbabilidade
var catalogo: CatalogoCorpos
var captura: TabelasCaptura
var cfg: ConfiguracaoEncontro
var inventario: InventarioJogador
var estado := EstadoEncontro.new()

var erro: String = ""

var _jogador: Jogador
var _camera: CameraExploracao
var _aviso: AvisoEncontro
var _transicao: TransicaoEncontro
var _interface: InterfaceEncontro

var _rng := RandomNumberGenerator.new()

# --- estado da deteccao ---
var _zonas: Array = []
var _distancia: float = 0.0
var _posicao_anterior: Vector2 = Vector2.ZERO
var _carencia: float = 0.0

# --- estado do encontro corrente ---
var _criatura: Criatura
var _vigor: float = 0.0
var _vigor_maximo: float = 1.0
var _isca_ativa: IscaCaptura
var _falhas: int = 0

## Contador de encontros, usado como TOKEN das rotinas assincronas.
##
## O roteiro de abertura e o lance sao corrotinas com varios `await` no meio. Se o
## encontro terminar enquanto uma delas espera — troca de cena, F4 durante o fade,
## uma limpeza externa — ela acordaria depois, tentaria transicoes invalidas e
## mexeria numa criatura que ja nao existe. Cada rotina guarda o token do encontro
## em que comecou e desiste em silencio quando ele muda.
var _geracao: int = 0


## Monta tudo. Devolve false com `erro` preenchido em vez de deixar meia
## montagem — mesma politica de MundoIso.carregar().
## `inventario_` entrega o estoque de fora (a partir da Etapa 3, o da Bolsa, que
## e unico e atravessa as cenas). Omitido, o encontro cria o seu a partir dos
## JSONs de captura — e o que mantem o teste headless independente da Bolsa.
func preparar(mundo: MundoIso, jogador: Jogador, camera: CameraExploracao,
		semente: int, quantidade: int = 100,
		inventario_: InventarioJogador = null) -> bool:
	world_seed = semente
	_jogador = jogador
	_camera = camera

	tabelas = TabelasProbabilidade.carregar()
	if tabelas == null:
		erro = "tabelas de probabilidade nao carregaram (res://data/)"
		return false
	catalogo = CatalogoCorpos.carregar(tabelas)
	if catalogo == null:
		erro = "catalogo de arte nao carregou (res://arte/)"
		return false
	captura = TabelasCaptura.carregar()
	if captura == null:
		erro = "tabelas de captura nao carregaram (res://data/captura/)"
		return false
	var faltando := captura.validar(tabelas)
	if not faltando.is_empty():
		erro = "tabelas de captura incoerentes com o vocabulario: " + ", ".join(faltando)
		return false

	cfg = ConfiguracaoEncontro.carregar()
	inventario = inventario_ if inventario_ != null else InventarioJogador.inicial(captura)
	_rng.seed = semente + DESLOCAMENTO_SEED

	# O bestiario da partida (RF01/RF02): mesma seed, mesmas ~100 criaturas.
	bestiario = GeradorCriaturas.new(tabelas, catalogo).gerar_bestiario(semente, quantidade)
	if bestiario.is_empty():
		erro = "bestiario vazio"
		return false

	_montar_nos()
	_conectar_zonas(mundo)
	_posicao_anterior = _jogador.global_position
	return true


func _montar_nos() -> void:
	_aviso = AvisoEncontro.new()
	_aviso.name = "AvisoEncontro"
	# Filho do JOGADOR: o "!" pertence a quem levou o susto e anda com ele.
	_jogador.add_child(_aviso)

	_transicao = TransicaoEncontro.new()
	_transicao.name = "TransicaoEncontro"
	_transicao.layer = CAMADA_TRANSICAO
	add_child(_transicao)

	_interface = InterfaceEncontro.new()
	_interface.name = "InterfaceEncontro"
	_interface.layer = CAMADA_INTERFACE
	_interface.acao_escolhida.connect(_on_acao)
	_interface.item_escolhido.connect(_on_item)
	_interface.roda_cancelada.connect(_on_roda_cancelada)
	add_child(_interface)


func _conectar_zonas(mundo: MundoIso) -> void:
	var pontos: Array = []
	if mundo != null and mundo.pontos_de_encontro != null:
		pontos = mundo.pontos_de_encontro.get_children()
	for no in pontos:
		var ponto := no as PontoDeEncontro
		if ponto == null:
			continue
		ponto.body_entered.connect(_on_zona_entrou.bind(ponto))
		ponto.body_exited.connect(_on_zona_saiu.bind(ponto))


# ------------------------------------------------------------------ deteccao

func _on_zona_entrou(corpo: Node2D, ponto: PontoDeEncontro) -> void:
	if corpo == _jogador and not ponto in _zonas:
		_zonas.append(ponto)


func _on_zona_saiu(corpo: Node2D, ponto: PontoDeEncontro) -> void:
	if corpo == _jogador:
		_zonas.erase(ponto)
		if _zonas.is_empty():
			# Sair da zona zera o passo em curso: a contagem e da caminhada
			# DENTRO do mato, nao um saldo que o jogador leva embora.
			_distancia = 0.0


func _process(delta: float) -> void:
	if _jogador == null:
		return
	var agora: Vector2 = _jogador.global_position
	var andou: float = agora.distance_to(_posicao_anterior)
	_posicao_anterior = agora

	if estado.em_encontro():
		return
	if _carencia > 0.0:
		_carencia -= delta
		return
	if _zonas.is_empty():
		return
	# A opcao desliga o SORTEIO, nunca a geracao. O bestiario de uma world_seed
	# e o mesmo com a opcao ligada ou desligada (RF03); o que muda e se o jogo
	# o apresenta sozinho. `iniciar()` continua publico — F4 e a pesca entram
	# por ele e nao passam por aqui.
	if not Opcoes.ligada("encontros_aleatorios"):
		return

	_distancia += andou
	while _distancia >= cfg.distancia_por_passo:
		_distancia -= cfg.distancia_por_passo
		if _rng.randf() < cfg.chance_por_passo:
			_distancia = 0.0
			iniciar(_zonas[_rng.randi() % _zonas.size()])
			return


## Dispara um encontro imediatamente. Publica para o teste headless e para a
## tecla de depuracao da vila — o roteiro nao pode depender de o jogador ter
## sorte no momento certo.
func iniciar(ponto: PontoDeEncontro) -> void:
	if estado.em_encontro():
		return
	if not estado.mudar_para(EstadoEncontro.Estado.DETECTADO):
		return
	_geracao += 1
	_criatura = _sortear_criatura(ponto)
	_vigor_maximo = AfinidadeCriatura.vigor_maximo(_criatura, captura.config_vigor())
	_vigor = _vigor_maximo
	_isca_ativa = null
	_falhas = 0
	if _jogador != null:
		_jogador.congelar(true)
	encontro_iniciado.emit(_criatura)
	await _roteiro_de_abertura(_geracao)


## Filtro com mistura (chance_fora_da_regiao) sobre o bestiario ja gerado:
## prefere quem tem o elemento que a regiao declara em `elementos_provaveis` (o
## campo que o mapa ja trazia e nenhum codigo lia). A `chance_fora_da_regiao`
## mantem o bioma sem exclusividade — uma margem de lago puxa agua e gelo, mas
## nao proibe o resto. Nao e rejeicao: nao ha laco nem re-sorteio. Um randf()
## escolhe o conjunto e um randi() sorteia uniforme nele, ou seja
## P(c) = (1 - chance)·[c em F]/|F| + chance/N (F vazio: so o randi(), 1/N).
func _sortear_criatura(ponto: PontoDeEncontro) -> Criatura:
	var preferidos: Array = []
	if ponto != null:
		for c: Criatura in bestiario:
			if c.elemento in ponto.elementos_provaveis:
				preferidos.append(c)
	if preferidos.is_empty() or _rng.randf() < cfg.chance_fora_da_regiao:
		return bestiario[_rng.randi() % bestiario.size()]
	return preferidos[_rng.randi() % preferidos.size()]


# -------------------------------------------------------------------- roteiro

func _roteiro_de_abertura(token: int) -> void:
	estado.mudar_para(EstadoEncontro.Estado.AVISO)
	_aviso.mostrar(cfg.duracao_aviso)
	if _camera != null:
		_camera.tremer(cfg.duracao_tremor, cfg.intensidade_tremor)
	await get_tree().create_timer(cfg.duracao_aviso + cfg.atraso_apos_aviso).timeout
	if _abandonado(token):
		return

	estado.mudar_para(EstadoEncontro.Estado.TRANSICAO)
	await _transicao.escurecer(cfg.duracao_escurecimento)
	if _abandonado(token):
		return

	estado.mudar_para(EstadoEncontro.Estado.APRESENTACAO)
	await _transicao.apresentar(cfg.texto_criatura_encontrada, cfg.duracao_texto_encontro)
	if _abandonado(token):
		return

	# A troca para INTERACAO fica DEPOIS da animacao de abertura, junto com
	# _devolver_menu: o estado tem de significar "o menu esta no ar e aceita
	# entrada", nao "o menu comecou a aparecer". Trocar antes criaria uma janela em
	# que a maquina diz INTERACAO enquanto a interface ainda esta subindo.
	await _interface.abrir(_criatura, catalogo, captura, cfg.duracao_abertura_menu)
	if _abandonado(token):
		return
	_devolver_menu("")
	_interface.atualizar_vigor(1.0, _rotulo_do_estado())


## O encontro que iniciou esta rotina ainda e o encontro corrente?
func _abandonado(token: int) -> bool:
	return token != _geracao


## Devolve o controle ao menu. Passa por aqui SEMPRE que uma acao termina — e o
## unico ponto que volta a aceitar entrada, o que torna impossivel ter duas acoes
## em curso.
func _devolver_menu(texto: String, cor: Color = TemaEncontro.TEXTO_APOIO) -> void:
	if estado.atual != EstadoEncontro.Estado.INTERACAO:
		estado.mudar_para(EstadoEncontro.Estado.INTERACAO)
	if texto != "":
		_interface.mensagem(texto, cor)
		mensagem_registrada.emit(texto)
	_interface.menu_ativo(true)


# --------------------------------------------------------------------- acoes

func _on_acao(acao: InterfaceEncontro.Acao) -> void:
	match acao:
		InterfaceEncontro.Acao.ABANDONAR:
			_encerrar("abandonado")
		InterfaceEncontro.Acao.ISCA:
			_abrir_roda_de_isca()
		InterfaceEncontro.Acao.ATACAR:
			_atacar()
		InterfaceEncontro.Acao.CAPTURAR:
			_abrir_roda_de_dispositivo()


func _abrir_roda_de_dispositivo() -> void:
	if inventario.total_de(captura.dispositivos) <= 0:
		_devolver_menu("Sem dispositivos de captura.", TemaEncontro.FALHA)
		return
	if not estado.mudar_para(EstadoEncontro.Estado.RODA_DISPOSITIVO):
		return
	await _interface.abrir_roda("Escolha o dispositivo", captura.dispositivos,
			inventario, _ficha_de_dispositivo, cfg.duracao_abertura_roda)


func _abrir_roda_de_isca() -> void:
	if inventario.total_de(captura.iscas) <= 0:
		_devolver_menu("Sem iscas na bolsa.", TemaEncontro.FALHA)
		return
	if not estado.mudar_para(EstadoEncontro.Estado.RODA_ISCA):
		return
	await _interface.abrir_roda("Ofereça uma isca", captura.iscas,
			inventario, _ficha_de_isca, cfg.duracao_abertura_roda)


## Ficha do dispositivo para a roda: a chance REAL daquele lance, com a isca ativa
## e o estado atual da criatura ja embutidos. E o que transforma a roda numa
## leitura da criatura em vez de uma lista de precos.
##
## O `selo` traduz a eficacia do aparelho CONTRA ESTA CRIATURA em uma palavra. Ele
## nao acrescenta informacao — o medidor ja mostra a chance —, mas responde a
## pergunta que o numero sozinho nao responde: "esta alto porque o aparelho e bom,
## ou porque a criatura e facil?".
func _ficha_de_dispositivo(item: ItemCaptura) -> Dictionary:
	var d := item as DispositivoCaptura
	var p := CalculoCaptura.chance(_criatura, d, _isca_ativa, _fracao_vigor(), captura)
	return {
		"texto": "%d%%" % roundi(p * 100.0),
		"valor": p,
		"medidor": true,
		"detalhe": d.detalhe(_criatura),
		"selo": _selo_do_dispositivo(d),
	}


func _selo_do_dispositivo(d: DispositivoCaptura) -> String:
	var m: float = d.multiplicador_contra(_criatura) / maxf(d.multiplicador, 0.001)
	if m >= 1.5:
		return "MUITO EFICAZ"
	if m >= 1.15:
		return "EFICAZ"
	if m <= 0.85:
		return "POUCO EFEITO"
	return ""


func _ficha_de_isca(item: ItemCaptura) -> Dictionary:
	var i := item as IscaCaptura
	var preferida: bool = i.preferida_por(_criatura)
	return {
		"texto": "+%.0f%%" % (i.bonus * 100.0) if preferida else "",
		"valor": -1.0,
		"medidor": false,
		"detalhe": i.detalhe(_criatura),
		"selo": "PREFERIDA" if preferida else "",
	}


func _on_roda_cancelada() -> void:
	await _interface.fechar_roda()
	_devolver_menu("")


func _on_item(item: ItemCaptura) -> void:
	# Espera a roda se recolher antes de resolver a acao: e o intervalo que liga
	# a escolha ao que vem depois. Sem ele, o arremesso comeca no mesmo quadro em
	# que a roda desaparece.
	await _interface.fechar_roda()
	match estado.atual:
		EstadoEncontro.Estado.RODA_DISPOSITIVO:
			_lancar(item as DispositivoCaptura)
		EstadoEncontro.Estado.RODA_ISCA:
			_oferecer(item as IscaCaptura)


## Oferece a isca: consome UMA e a deixa ativa pelo resto do encontro. A escolha
## de nao consumir a cada lance e deliberada — a isca posta no chao continua no
## chao, e cobrar uma por arremesso tornaria a camada de isca cara demais para
## ser usada, que e o oposto do que o sistema quer ensinar.
func _oferecer(isca: IscaCaptura) -> void:
	if isca == null:
		_devolver_menu("")
		return
	if not inventario.consumir(isca.id):
		_devolver_menu("Acabou: %s." % isca.nome, TemaEncontro.FALHA)
		return
	_isca_ativa = isca
	var preferida: bool = isca.preferida_por(_criatura)
	# A criatura responde ANTES da mensagem: a reacao e a resposta do mundo, o
	# texto e a explicacao. Nesta ordem uma confirma a outra.
	await _interface.animar_reacao(preferida)
	if preferida:
		_devolver_menu("%s! É exatamente o que um %s quer. (+%.0f%% na captura)"
				% [isca.nome, _criatura.animal_base, isca.bonus * 100.0], TemaEncontro.SUCESSO)
	else:
		_devolver_menu("%s. Um %s mal se interessa (+%.0f%%)."
				% [isca.nome, _criatura.animal_base,
				captura.bonus_de_isca_incorreta() * 100.0], TemaEncontro.ATENCAO)


func _lancar(dispositivo: DispositivoCaptura) -> void:
	if dispositivo == null:
		_devolver_menu("")
		return
	# Consome ANTES de sortear: o dispositivo se gasta ao ser lancado, e nao ao
	# dar certo. Se o estoque acabou entre abrir a roda e confirmar, nada e
	# sorteado e nada e gasto.
	if not inventario.consumir(dispositivo.id):
		_devolver_menu("Acabaram os %s." % dispositivo.nome, TemaEncontro.FALHA)
		return
	if not estado.mudar_para(EstadoEncontro.Estado.LANCANDO):
		return
	var token := _geracao

	var r := CalculoCaptura.tentar(_rng, _criatura, dispositivo, _isca_ativa,
			_fracao_vigor(), captura)
	await _interface.animar_lancamento(dispositivo, cfg)
	if _abandonado(token):
		return

	var sucesso: bool = bool(r["sucesso"])
	estado.mudar_para(EstadoEncontro.Estado.SUCESSO if sucesso else EstadoEncontro.Estado.FALHA)
	await _interface.animar_desfecho(sucesso, cfg)
	if _abandonado(token):
		return

	if sucesso:
		inventario.guardar_criatura(_criatura)
		_interface.mensagem("Capturada! %s entrou na coleção. [chance %d%%]"
				% [_criatura.nome(), roundi(float(r["p"]) * 100.0)], TemaEncontro.SUCESSO)
		mensagem_registrada.emit("capturada: " + _criatura.nome())
		await get_tree().create_timer(cfg.duracao_desfecho).timeout
		_encerrar("capturada")
		return

	_falhas += 1
	var fuga: float = captura.chance_de_fuga(_falhas)
	if _rng.randf() < fuga:
		_interface.mensagem("Escapou do %s — e sumiu no mato." % dispositivo.nome,
				TemaEncontro.FALHA)
		await get_tree().create_timer(cfg.duracao_desfecho).timeout
		_encerrar("fugiu")
		return
	_devolver_menu("Escapou do %s. [chance era %d%%]"
			% [dispositivo.nome, roundi(float(r["p"]) * 100.0)], TemaEncontro.ATENCAO)


## Ataque. O projeto nao tem sistema de batalha (docs/pendencias.md, item 7) e
## este NAO e um: e o minimo para que "Atacar" tenha consequencia mecanica —
## derruba o vigor, que e um dos fatores do CalculoCaptura. Quando a Camada de
## batalha existir, ela substitui este metodo e o resto do encontro nao muda.
func _atacar() -> void:
	if not estado.mudar_para(EstadoEncontro.Estado.ATACANDO):
		return
	var token := _geracao
	var vcfg := captura.config_vigor()
	var base: float = float(vcfg.get("dano_por_ataque", 25.0))
	var variacao: float = float(vcfg.get("variacao_do_dano", 0.0))
	var dano: float = base * (1.0 + variacao * (_rng.randf() * 2.0 - 1.0))
	_vigor = maxf(0.0, _vigor - dano)

	await _interface.animar_ataque(6.0)
	if _abandonado(token):
		return
	_interface.atualizar_vigor(_fracao_vigor(), _rotulo_do_estado())

	if _vigor <= 0.0:
		_interface.mensagem("A criatura cedeu e fugiu antes de ser capturada.",
				TemaEncontro.FALHA)
		await get_tree().create_timer(cfg.duracao_desfecho).timeout
		_encerrar("derrotada")
		return
	_devolver_menu("Golpe certeiro (-%d de vigor). Agora está %s."
			% [roundi(dano), _rotulo_do_estado()], TemaEncontro.SUCESSO)


# ------------------------------------------------------------------- limpeza

func _encerrar(desfecho: String) -> void:
	var criatura := _criatura
	# Invalida qualquer rotina do encontro que ainda esteja num await.
	_geracao += 1
	if not estado.mudar_para(EstadoEncontro.Estado.ENCERRANDO):
		estado.reiniciar()
	_interface.menu_ativo(false)
	_interface.fechar_roda()
	await _interface.fechar(cfg.duracao_encerramento)
	await _transicao.clarear(cfg.duracao_encerramento)
	_aviso.esconder()

	# A limpeza e completa de proposito: nada do encontro anterior pode vazar
	# para o proximo (isca ativa, contagem de falhas, vigor, distancia andada).
	_criatura = null
	_isca_ativa = null
	_falhas = 0
	_vigor = 0.0
	_distancia = 0.0
	_carencia = cfg.carencia_segundos
	if _jogador != null:
		_jogador.congelar(false)
		_posicao_anterior = _jogador.global_position
	estado.mudar_para(EstadoEncontro.Estado.INATIVO)
	encontro_terminado.emit(desfecho, criatura)


# -------------------------------------------------------------------- apoio

func _fracao_vigor() -> float:
	return clampf(_vigor / maxf(_vigor_maximo, 1.0), 0.0, 1.0)


func _rotulo_do_estado() -> String:
	var faixa := AfinidadeCriatura.faixa_de_estado(_fracao_vigor(), captura.faixas_de_estado())
	return String(faixa.get("rotulo", ""))


## Criatura do encontro corrente (null fora de encontro). Para HUD e teste.
func criatura_atual() -> Criatura:
	return _criatura


func isca_ativa() -> IscaCaptura:
	return _isca_ativa


## Quantas zonas o jogador esta pisando agora. Para a sobreposicao de depuracao.
func zonas_ativas() -> int:
	return _zonas.size()
