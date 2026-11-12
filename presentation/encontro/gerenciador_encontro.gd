class_name GerenciadorEncontro
extends Node

## Orquestra o encontro inteiro: deteccao na exploracao, roteiro de aviso e
## transicao, batalha, roda, lance e limpeza. O duelo contra um guardiao passa pelo
## mesmo caminho, sem captura e sem fuga: ha um sistema de combate so.
##
## A REGRA DA BATALHA NAO ESTA AQUI. MotorBatalha resolve o turno e devolve os eventos;
## este no so os mostra, um a um.
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
## fuga) sai de um RandomNumberGenerator semeado a partir da world_seed, e a batalha
## tem o seu, com outro deslocamento. Nenhuma chamada a randi()/randf() globais. Mesma
## seed e mesma sequencia de acoes reproduzem a partida lance a lance.

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
const DESLOCAMENTO_BATALHA := 0xBA7A

var world_seed: int = 0
var bestiario: Array = []

var tabelas: TabelasProbabilidade
var catalogo: CatalogoCorpos
var captura: TabelasCaptura
var tabelas_batalha: TabelasBatalha
var equipe: EquipeJogador
## Batalha em curso; null fora de encontro.
var motor: MotorBatalha
var cfg: ConfiguracaoEncontro
var inventario: InventarioJogador
var estado := EstadoEncontro.new()

var erro: String = ""
## Dicas da primeira batalha contra selvagem: {titulo, menu, roda}. Quem preenche e a
## cena (autoral/cutscenes/chegada.json), uma vez por partida; cada chave aparece uma
## vez e sai daqui. Vazio, nenhuma dica.
var dicas_de_estreia: Dictionary = {}

var _jogador: Jogador
var _camera: CameraExploracao
var _aviso: AvisoEncontro
var _transicao: TransicaoEncontro
var _interface: InterfaceEncontro

var _rng := RandomNumberGenerator.new()
var _rng_batalha := RandomNumberGenerator.new()

# --- estado da deteccao ---
var _zonas: Array = []
var _distancia: float = 0.0
var _posicao_anterior: Vector2 = Vector2.ZERO
var _carencia: float = 0.0

# --- estado do encontro corrente ---
var _criatura: Criatura
## Guardiao do duelo corrente; vazio em encontro selvagem.
var _guardiao: Dictionary = {}
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


## Modelo do gerador deste mundo. Quem carrega um save antigo troca antes de preparar().
var modo_gerador: GeradorCriaturas.Modo = GeradorCriaturas.MODO_DO_JOGO

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

	tabelas_batalha = TabelasBatalha.carregar()
	if tabelas_batalha == null:
		erro = "tabelas de batalha nao carregaram (res://data/batalha/)"
		return false
	faltando = tabelas_batalha.validar(tabelas)
	if not faltando.is_empty():
		erro = "tabelas de batalha incoerentes com o vocabulario: " + ", ".join(faltando)
		return false
	equipe = EquipeJogador.new(tabelas_batalha.maximo_da_equipe())
	_rng_batalha.seed = semente + DESLOCAMENTO_BATALHA

	cfg = ConfiguracaoEncontro.carregar()
	inventario = inventario_ if inventario_ != null else InventarioJogador.inicial(captura)
	_rng.seed = semente + DESLOCAMENTO_SEED

	# O bestiario da partida (RF01/RF02): mesma seed, mesmas ~100 criaturas.
	bestiario = GeradorCriaturas.new(tabelas, catalogo).gerar_bestiario(semente, quantidade,
			modo_gerador)
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
	_interface.lista_escolhida.connect(_on_lista)
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
	# Sem criatura de pe nao ha encontro: o mato so vale depois da primeira escolha.
	if not equipe.tem_vivos():
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
	if not pode_comecar():
		return
	_comecar([_sortear_criatura(ponto)], "selvagem", {})


## Encontro com uma criatura ja definida: a que a pesca fisgou.
func iniciar_com_criatura(c: Criatura) -> void:
	if pode_comecar() and c != null:
		_comecar([c], "selvagem", {})


## Duelo contra um guardiao. As criaturas vem do bestiario (SelecaoBestiario).
func iniciar_duelo(guardiao: Dictionary, criaturas: Array) -> void:
	if pode_comecar() and not criaturas.is_empty():
		_comecar(criaturas, "guardiao", guardiao)


func pode_comecar() -> bool:
	return not estado.em_encontro() and equipe != null and equipe.tem_vivos()


func _comecar(criaturas: Array, tipo: String, guardiao: Dictionary) -> void:
	if not estado.mudar_para(EstadoEncontro.Estado.DETECTADO):
		return
	_geracao += 1
	_guardiao = guardiao
	var adversarios: Array = []
	for c: Criatura in criaturas:
		adversarios.append(Combatente.de_criatura(c, tabelas_batalha))
	motor = MotorBatalha.new(tabelas_batalha, _rng_batalha, equipe.ativos, adversarios, tipo)
	_criatura = motor.inimigo().criatura
	_isca_ativa = null
	_falhas = 0
	if _jogador != null:
		_jogador.congelar(true)
	encontro_iniciado.emit(_criatura)
	Som.tocar("encontro")
	Som.musica("batalha")
	await _roteiro_de_abertura(_geracao)


func em_duelo() -> bool:
	return not _guardiao.is_empty()


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
	var cartaz: String = String(_guardiao.get("titulo", "")) if em_duelo() \
			else cfg.texto_criatura_encontrada
	await _transicao.apresentar(cartaz, cfg.duracao_texto_encontro)
	if _abandonado(token):
		return

	# A troca para INTERACAO fica DEPOIS da animacao de abertura, junto com
	# _devolver_menu: o estado tem de significar "o menu esta no ar e aceita
	# entrada", nao "o menu comecou a aparecer". Trocar antes criaria uma janela em
	# que a maquina diz INTERACAO enquanto a interface ainda esta subindo.
	var abertura: String = "%s te desafia!" % String(_guardiao.get("nome", "")) if em_duelo() \
			else "Uma criatura selvagem apareceu!"
	await _interface.abrir(_criatura, catalogo, captura, cfg.duracao_abertura_menu,
			not em_duelo(), abertura)
	if _abandonado(token):
		return
	_interface.definir_stats(motor.inimigo().ficha)
	_interface.mostrar_jogador(motor.jogador())
	_atualizar_barras()
	if not em_duelo():
		_mostrar_dica_estreia("menu")
	_devolver_menu("")


## Mostra a dica `chave` de dicas_de_estreia, se houver. Cada uma aparece uma vez:
## mostrada, sai do dicionario.
func _mostrar_dica_estreia(chave: String) -> void:
	if not dicas_de_estreia.has(chave):
		return
	_interface.mostrar_dica_estreia(String(dicas_de_estreia.get("titulo", "")),
			String(dicas_de_estreia[chave]))
	dicas_de_estreia.erase(chave)


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
	_interface.voltar_ao_menu()


# --------------------------------------------------------------------- acoes

func _on_acao(acao: InterfaceEncontro.Acao) -> void:
	match acao:
		InterfaceEncontro.Acao.GOLPES:
			_abrir_lista_de_golpes()
		InterfaceEncontro.Acao.CAPTURAR:
			_abrir_roda_de_dispositivo()
		InterfaceEncontro.Acao.ISCA:
			_abrir_roda_de_isca()
		InterfaceEncontro.Acao.BOLSA:
			_abrir_lista_de_itens()
		InterfaceEncontro.Acao.TROCAR:
			_abrir_lista_de_trocas()
		InterfaceEncontro.Acao.FUGIR:
			_resolver_turno({"tipo": "fugir"})


func _abrir_lista_de_golpes() -> void:
	var itens: Array = []
	for g: Golpe in motor.jogador().ficha.golpes:
		itens.append({
			"rotulo": g.nome.to_upper(),
			"dica": TextoBatalha.dica_do_golpe(g, motor.jogador(), motor.inimigo(), tabelas_batalha),
			"valor": {"tipo": "golpe", "golpe": g},
		})
	_interface.abrir_lista(itens)


func _abrir_lista_de_trocas() -> void:
	var itens := _itens_de_troca("trocar")
	if itens.is_empty():
		_devolver_menu("Ninguém mais de pé para entrar.", TemaEncontro.FALHA)
		return
	_interface.abrir_lista(itens)


func _itens_de_troca(tipo: String) -> Array:
	var itens: Array = []
	for i: int in motor.trocas_possiveis():
		var c: Combatente = motor.lado_jogador[i]
		itens.append({
			"rotulo": c.nome().to_upper(),
			"dica": "VIDA %d/%d · %s" % [c.vida, c.ficha.vida, TextoBatalha.lista_de_golpes(c.ficha)],
			"valor": {"tipo": tipo, "indice": i},
		})
	return itens


## So o que faz algo agora e o jogador tem. Uma pocao vai para a criatura em campo; se
## ela nao precisa, para a mais ferida da equipe.
func _abrir_lista_de_itens() -> void:
	var itens: Array = []
	for item: ItemJogo in Bolsa.catalogo.da_categoria("consumiveis"):
		if inventario.quantidade(item.id) <= 0:
			continue
		var alvo := motor.jogador()
		if not CalculoBatalha.efeito_aplicavel(item.efeito, alvo):
			alvo = equipe.alvo_de_efeito(item.efeito)
		if alvo == null:
			continue
		itens.append({
			"rotulo": "%s ×%d" % [item.nome.to_upper(), inventario.quantidade(item.id)],
			"dica": "em %s" % alvo.nome(),
			"valor": {"tipo": "item", "id": item.id, "nome": item.nome, "efeito": item.efeito,
					"alvo": motor.lado_jogador.find(alvo)},
		})
	if itens.is_empty():
		_devolver_menu("Nada na bolsa ajuda agora.", TemaEncontro.ATENCAO)
		return
	_interface.abrir_lista(itens)


func _on_lista(valor: Variant) -> void:
	var acao: Dictionary = valor
	match String(acao.get("tipo", "")):
		"trocar_forcada":
			_resolver_troca_forcada(int(acao["indice"]))
		"item":
			if not inventario.consumir(String(acao["id"])):
				_devolver_menu("Acabou: %s." % String(acao["nome"]), TemaEncontro.FALHA)
				return
			_resolver_turno(acao)
		_:
			_resolver_turno(acao)


func _abrir_roda_de_dispositivo() -> void:
	if inventario.total_de(captura.dispositivos) <= 0:
		_devolver_menu("Sem dispositivos de captura.", TemaEncontro.FALHA)
		return
	if not estado.mudar_para(EstadoEncontro.Estado.RODA_DISPOSITIVO):
		return
	_mostrar_dica_estreia("roda")
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
		_interface.mensagem("%s! É exatamente o que um %s quer. (+%.0f%% na captura)"
				% [isca.nome, _criatura.animal_base, isca.bonus * 100.0], TemaEncontro.SUCESSO)
	else:
		_interface.mensagem("%s. Um %s mal se interessa (+%.0f%%)."
				% [isca.nome, _criatura.animal_base,
				captura.bonus_de_isca_incorreta() * 100.0], TemaEncontro.ATENCAO)
	# Isca gasta o turno: a criatura come e revida.
	var token := _geracao
	await get_tree().create_timer(cfg.duracao_evento_batalha).timeout
	if _abandonado(token):
		return
	_resolver_turno({"tipo": "passar"})


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
		# Com a vida que tinha: o que apanhou na captura continua machucado.
		var capturada: Combatente = motor.inimigo()
		capturada.limpar_reforcos()
		var na_equipe: bool = equipe.adicionar(capturada)
		_interface.mensagem("Capturada! %s foi para %s. [chance %d%%]"
				% [_criatura.nome(), "a equipe" if na_equipe else "o depósito",
				roundi(float(r["p"]) * 100.0)], TemaEncontro.SUCESSO)
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
	# Falhar gasta o turno: a criatura solta e revida.
	_interface.mensagem("Escapou do %s. [chance era %d%%]"
			% [dispositivo.nome, roundi(float(r["p"]) * 100.0)], TemaEncontro.ATENCAO)
	await get_tree().create_timer(cfg.duracao_evento_batalha).timeout
	if _abandonado(token):
		return
	_resolver_turno({"tipo": "passar"})


# -------------------------------------------------------------------- batalha

func _resolver_turno(acao: Dictionary) -> void:
	if not estado.mudar_para(EstadoEncontro.Estado.ATACANDO):
		return
	var token := _geracao
	await _mostrar_eventos(motor.resolver_turno(acao), token)
	if _abandonado(token):
		return
	await _apos_o_turno(token)


func _resolver_troca_forcada(indice: int) -> void:
	if not estado.mudar_para(EstadoEncontro.Estado.ATACANDO):
		return
	var token := _geracao
	await _mostrar_eventos(motor.trocar_forcada(indice), token)
	if _abandonado(token):
		return
	await _apos_o_turno(token)


## Mostra os eventos do turno, um por vez. A regra ja aconteceu: o desenho so conta.
## As barras sao lidas do estado final de cada evento, e nao recalculadas aqui.
func _mostrar_eventos(eventos: Array, token: int) -> void:
	for ev: Dictionary in eventos:
		_interface.mensagem(String(ev.get("texto", "")), _cor_do_evento(ev))
		mensagem_registrada.emit(String(ev.get("texto", "")))
		var lado := String(ev.get("lado", ""))
		match String(ev.get("tipo", "")):
			"golpe":
				_atualizar_barras()
				if ev.get("acertou", false):
					await _interface.animar_ataque(6.0, lado == MotorBatalha.INIMIGO)
					if _abandonado(token):
						return
			"entrou":
				if lado == MotorBatalha.INIMIGO:
					_criatura = motor.inimigo().criatura
					_interface.trocar_adversario(motor.inimigo())
				else:
					_interface.mostrar_jogador(motor.jogador())
				_atualizar_barras()
			_:
				_atualizar_barras()
		await get_tree().create_timer(cfg.duracao_evento_batalha).timeout
		if _abandonado(token):
			return


func _cor_do_evento(ev: Dictionary) -> Color:
	match String(ev.get("tipo", "")):
		"golpe":
			if not ev.get("acertou", false):
				return TemaEncontro.ATENCAO
			return TemaEncontro.FALHA if String(ev.get("lado", "")) == MotorBatalha.INIMIGO \
					else TemaEncontro.SUCESSO
		"caiu":
			return TemaEncontro.FALHA if String(ev.get("lado", "")) == MotorBatalha.JOGADOR \
					else TemaEncontro.SUCESSO
		"item":
			return TemaEncontro.SUCESSO
		"fuga":
			return TemaEncontro.ATENCAO
	return TemaEncontro.TINTA


func _atualizar_barras() -> void:
	if motor == null:
		return
	_interface.atualizar_jogador(motor.jogador())
	var rotulo := "%d/%d" % [motor.inimigo().vida, motor.inimigo().ficha.vida]
	if not em_duelo():
		rotulo += " · " + _rotulo_do_estado()
	_interface.atualizar_vigor(motor.inimigo().fracao(), rotulo)


## O que vem depois dos eventos: fim, troca obrigatoria ou o menu de novo.
func _apos_o_turno(_token: int) -> void:
	if motor.terminou():
		match motor.desfecho:
			MotorBatalha.VITORIA:
				if em_duelo():
					_encerrar("duelo_vencido")
				else:
					# Zerar a vida perde a criatura: e o risco de bater demais antes
					# de tentar capturar.
					_interface.mensagem("A criatura cedeu e fugiu antes de ser capturada.",
							TemaEncontro.ATENCAO)
					await get_tree().create_timer(cfg.duracao_desfecho).timeout
					_encerrar("derrotada")
			MotorBatalha.DERROTA:
				_encerrar("derrota")
			MotorBatalha.FUGIU:
				_encerrar("abandonado")
		return
	if motor.precisa_trocar():
		estado.mudar_para(EstadoEncontro.Estado.TROCA_OBRIGATORIA)
		_interface.mensagem("%s caiu. Quem entra agora?" % motor.jogador().nome(),
				TemaEncontro.FALHA)
		_interface.abrir_lista(_itens_de_troca("trocar_forcada"), false)
		return
	_devolver_menu("")


# ------------------------------------------------------------------- limpeza

func _encerrar(desfecho: String) -> void:
	var criatura := _criatura
	# Invalida qualquer rotina do encontro que ainda esteja num await.
	_geracao += 1
	if motor != null:
		motor.encerrar()
	if not estado.mudar_para(EstadoEncontro.Estado.ENCERRANDO):
		estado.reiniciar()
	_interface.menu_ativo(false)
	_interface.fechar_roda()
	await _interface.fechar(cfg.duracao_encerramento)
	await _transicao.clarear(cfg.duracao_encerramento)
	_aviso.esconder()

	# A limpeza e completa de proposito: nada do encontro anterior pode vazar
	# para o proximo (isca ativa, contagem de falhas, batalha, distancia andada).
	_criatura = null
	_isca_ativa = null
	_falhas = 0
	motor = null
	_guardiao = {}
	_distancia = 0.0
	_carencia = cfg.carencia_segundos
	if _jogador != null:
		_jogador.congelar(false)
		_posicao_anterior = _jogador.global_position
	estado.mudar_para(EstadoEncontro.Estado.INATIVO)
	Som.musica("vila")
	encontro_terminado.emit(desfecho, criatura)


# -------------------------------------------------------------------- apoio

func _fracao_vigor() -> float:
	return motor.inimigo().fracao() if motor != null else 1.0


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
