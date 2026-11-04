class_name InterfacePesca
extends CanvasLayer

## A tela da pesca: o arco de forca, o minigame de recolhimento, o letreiro do
## resultado e a legenda de teclas no rodape.
##
## Camada 84: ACIMA da caixa de dialogo (70) — a pesca toma a tela inteira e
## uma fala atrasada nao pode cobri-la — e ABAIXO da roda de itens (88), da
## DicaTutorial (92) e de tudo que pausa o jogo (mapa, pausa, bolsa). A dica do
## Anselmo tem de ser lida POR CIMA do arco e do corte da agua.
##
## Como InterfaceEncontro, nao decide nada: nao sabe o que e um estado de pesca,
## nao sorteia, nao conta tempo de resultado. O GerenciadorPesca diz "mostre o
## arco", "abra o minigame", "escreva FISGOU" e "feche", e o resto e desenho.
##
## Os textos vem todos da ConfiguracaoPesca (data/pesca/configuracao.json) — a
## interface nao tem uma string ao jogador propria. A unica opcional e
## `dica_cancelar` (hoje nos padroes e no JSON): presente, entra na legenda;
## apagada dos textos, a legenda fica sem ela em vez de mostrar a chave crua.

const CAMADA := 84

## Distancia da legenda de teclas ate a borda de baixo, em pixels.
@export var folga_legenda: float = 16.0
## Quanto o letreiro do resultado sobe acima do centro da tela.
@export var subida_resultado: float = 40.0
## Sacudidas por segundo do tremor da fisgada. O mesmo valor de
## CameraExploracao.FREQUENCIA_DO_TREMOR, repetido e nao citado: citar a camera
## puxaria o autoload Opcoes para a compilacao deste script, e a interface deixaria
## de compilar isolada (godot -s) sem precisar de nada da camera.
@export var frequencia_tremor: float = 34.0

var medidor: MedidorArremesso
var minigame: MinigameRecolhimento

var _cfg: ConfiguracaoPesca
var _catalogo: CatalogoCorpos
var _raiz: Control
var _letreiro: PanelContainer
var _texto_letreiro: Label
var _legenda: Control
var _tween_minigame: Tween
var _tween_letreiro: Tween
var _aberta: bool = false

var _tremor_total: float = 0.0
var _tremor_restante: float = 0.0
var _tremor_intensidade: float = 0.0


func _init() -> void:
	layer = CAMADA


func _ready() -> void:
	if _raiz == null:
		_montar()


## Monta os nos (uma vez) e guarda a configuracao e o catalogo de corpos (para
## as silhuetas). Pode vir antes do _ready: quem cria a interface costuma
## prepara-la logo depois do add_child.
func preparar(cfg: ConfiguracaoPesca, catalogo_corpos: CatalogoCorpos) -> void:
	_cfg = cfg if cfg != null else ConfiguracaoPesca.new()
	_catalogo = catalogo_corpos
	if _raiz == null:
		_montar()
	medidor.configurar(_cfg)


## Arco de forca embaixo-centro, oscilando. `legenda`: FRACO/MEDIO/MAXIMO sobre
## as zonas (tutorial).
func mostrar_medidor(legenda: bool) -> void:
	_garantir_montada()
	_aberta = true
	visible = true
	medidor.mostrar_legenda = legenda
	medidor.iniciar()
	_escrever_legenda(_cfg.texto("dica_arremesso"))


## Some com o arco sem emitir nada (o lance ja foi decidido, ou foi cancelado).
func esconder_medidor() -> void:
	if medidor != null:
		medidor.desligar()


## Abre o corte da agua sobre o mundo com um fade de cfg.duracao_transicao.
## `alvos` liga as faixas-alvo do monstro.
func abrir_minigame(sim: SimulacaoRecolhimento, alvos: bool) -> void:
	_garantir_montada()
	_aberta = true
	visible = true
	esconder_medidor()
	_esconder_letreiro()
	_matar(_tween_minigame)
	minigame.iniciar(sim, _catalogo, alvos)
	minigame.modulate.a = 0.0
	_tween_minigame = create_tween()
	_tween_minigame.tween_property(minigame, "modulate:a", 1.0,
			maxf(_cfg.duracao_transicao, 0.01)).set_trans(Tween.TRANS_SINE)
	_escrever_legenda(_cfg.texto("dica_recolher"))


## Letreiro do resultado no centro ("FISGOU!", "ESCAPOU...", "Nada mordeu a
## isca."). Fica ate fechar(): quanto tempo ele dura e decisao do gerenciador.
## O FISGOU ganha a moldura dourada; o resto, a de madeira.
func mostrar_resultado(texto: String, cor: Color) -> void:
	_garantir_montada()
	_aberta = true
	visible = true
	_texto_letreiro.text = texto
	_texto_letreiro.add_theme_color_override("font_color", cor)
	var dourada: bool = cor == TemaEncontro.OURO or cor == TemaEncontro.OURO_C
	_letreiro.add_theme_stylebox_override("panel",
			TemaEncontro.moldura("painel_ouro" if dourada else "painel"))
	_letreiro.reset_size()
	var tam := _letreiro.get_combined_minimum_size()
	var tela := _raiz.get_viewport_rect().size
	_letreiro.size = tam
	_letreiro.position = ((tela - tam) * 0.5 - Vector2(0.0, subida_resultado)).floor()
	_letreiro.pivot_offset = (tam * 0.5).floor()
	_letreiro.visible = true
	_matar(_tween_letreiro)
	_letreiro.modulate.a = 0.0
	_letreiro.scale = Vector2.ONE * 0.6
	_tween_letreiro = create_tween().set_parallel(true)
	_tween_letreiro.tween_property(_letreiro, "modulate:a", 1.0, 0.12)
	_tween_letreiro.tween_property(_letreiro, "scale", Vector2.ONE, 0.22) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_escrever_legenda("")


## Sacode a tela da pesca. O GerenciadorPesca so chama isto quando a CAMERA
## aceitou tremer (CameraExploracao.tremendo()), e e assim que a opcao
## "tremor de camera" do jogador vale aqui sem esta classe conhecer as opcoes.
func tremer(duracao: float, intensidade: float) -> void:
	if duracao <= 0.0 or intensidade <= 0.0:
		return
	_tremor_total = duracao
	_tremor_restante = duracao
	_tremor_intensidade = intensidade


## Fecha tudo: para o arco e o minigame, apaga letreiro e legenda e esmaece o
## corte da agua. Idempotente.
func fechar() -> void:
	_aberta = false
	if _raiz == null:
		return
	esconder_medidor()
	minigame.parar()
	_esconder_letreiro()
	_escrever_legenda("")
	_tremor_restante = 0.0
	offset = Vector2.ZERO
	_matar(_tween_minigame)
	if not minigame.visible:
		visible = false
		return
	_tween_minigame = create_tween()
	_tween_minigame.tween_property(minigame, "modulate:a", 0.0,
			maxf(_cfg.duracao_transicao, 0.01)).set_trans(Tween.TRANS_SINE)
	_tween_minigame.tween_callback(_ao_fechar_minigame)


func aberta() -> bool:
	return _aberta


func _process(delta: float) -> void:
	if _tremor_restante <= 0.0:
		return
	_tremor_restante -= delta
	if _tremor_restante <= 0.0:
		offset = Vector2.ZERO
		return
	# Mesma forma do tremor da CameraExploracao: amplitude decrescente,
	# frequencias diferentes nos dois eixos, e zero exato no fim.
	var fase: float = (_tremor_total - _tremor_restante) * frequencia_tremor
	var amp: float = _tremor_intensidade * (_tremor_restante / maxf(_tremor_total, 0.001))
	offset = Vector2(sin(fase) * amp, cos(fase * 1.7) * amp * 0.5).round()


# --- construcao -------------------------------------------------------------

func _garantir_montada() -> void:
	if _cfg == null:
		_cfg = ConfiguracaoPesca.new()
	if _raiz == null:
		_montar()
		medidor.configurar(_cfg)


func _montar() -> void:
	_raiz = Control.new()
	_raiz.name = "Raiz"
	_raiz.set_anchors_preset(Control.PRESET_FULL_RECT)
	_raiz.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_raiz)

	minigame = MinigameRecolhimento.new()
	minigame.name = "Minigame"
	_raiz.add_child(minigame)

	medidor = MedidorArremesso.new()
	medidor.name = "Medidor"
	_raiz.add_child(medidor)

	_letreiro = PanelContainer.new()
	_letreiro.name = "Resultado"
	_letreiro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_letreiro.add_theme_stylebox_override("panel", TemaEncontro.moldura("painel"))
	_letreiro.visible = false
	_texto_letreiro = TemaEncontro.rotulo("", TemaEncontro.OURO_C, TemaEncontro.Corpo.TITULO)
	_texto_letreiro.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_letreiro.add_child(_texto_letreiro)
	_raiz.add_child(_letreiro)

	# Legenda de teclas sobre o mundo ou o minigame: rotulo sombreado, legivel em
	# qualquer fundo sem painel (o rodape ja e do arco e do painel do minigame).
	_legenda = TemaEncontro.rotulo_sombreado("", TemaEncontro.PERG_C)
	_legenda.name = "Legenda"
	_legenda.visible = false
	_raiz.add_child(_legenda)
	visible = false


## Escreve a legenda do rodape (centrada). "" esconde. A dica de cancelar entra
## so se o JSON a declarar — ver o topo do arquivo.
func _escrever_legenda(texto: String) -> void:
	if _legenda == null:
		return
	if texto == "":
		_legenda.visible = false
		return
	var completo: String = texto
	if _cfg.textos.has("dica_cancelar"):
		completo += "   ·   " + _cfg.texto("dica_cancelar")
	TemaEncontro.escrever_sombreado(_legenda, completo)
	var tam: Vector2 = _legenda.custom_minimum_size
	_legenda.anchor_left = 0.5
	_legenda.anchor_right = 0.5
	_legenda.anchor_top = 1.0
	_legenda.anchor_bottom = 1.0
	_legenda.offset_left = -floorf(tam.x * 0.5)
	_legenda.offset_right = ceilf(tam.x * 0.5)
	_legenda.offset_bottom = -folga_legenda
	_legenda.offset_top = -folga_legenda - tam.y
	_legenda.visible = true


func _esconder_letreiro() -> void:
	if _letreiro == null:
		return
	_matar(_tween_letreiro)
	_letreiro.visible = false


func _ao_fechar_minigame() -> void:
	minigame.visible = false
	if not _aberta:
		visible = false


static func _matar(t: Tween) -> void:
	if t != null and t.is_valid():
		t.kill()
