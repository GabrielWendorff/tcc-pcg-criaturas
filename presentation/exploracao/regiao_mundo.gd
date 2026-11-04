class_name RegiaoMundo
extends Area2D

## Area de uma regiao do mundo (vila, ribeira, distrito, sitio).
##
## Duas funcoes, e as duas saem do MESMO retangulo declarado no mapa:
##   - em jogo, avisa quando o jogador ENTRA na regiao (nome na tela, bandeira
##     de "visitou_<id>" no EstadoMundo);
##   - no mapa geral (M), e a moldura do rotulo e o criterio de "descoberta".
##
## Um retangulo na GRADE vira um LOSANGO na tela — e por isso a colisao e um
## poligono de quatro pontos projetados, e nao um RectangleShape2D. Com um
## retangulo de tela, a regiao pegaria pedaco da vizinha em duas quinas e
## deixaria de pegar a propria em outras duas.
##
## Nao conhece EstadoMundo nem HUD: emite `jogador_entrou` e quem escuta decide.
## Mesma politica de PontoDeEncontro, que tambem so declara geometria e dados.

signal jogador_entrou(id_regiao: String)

@export var id_regiao: String = ""
@export var nome: String = ""
@export var descricao: String = ""
@export var icone: String = ""
## Retangulo na grade: [x0, y0, x1, y1], inclusivo nas duas pontas.
@export var retangulo: Rect2i = Rect2i()


static func criar(dados: Dictionary) -> RegiaoMundo:
	var r := RegiaoMundo.new()
	r.id_regiao = String(dados.get("id", ""))
	r.nome = String(dados.get("nome", r.id_regiao))
	r.descricao = String(dados.get("descricao", ""))
	r.icone = String(dados.get("icone", ""))
	var ret: Array = dados.get("retangulo", [0, 0, 0, 0])
	if ret.size() >= 4:
		r.retangulo = Rect2i(int(ret[0]), int(ret[1]),
				int(ret[2]) - int(ret[0]) + 1, int(ret[3]) - int(ret[1]) + 1)
	r.name = "Regiao_" + r.id_regiao
	return r


func _ready() -> void:
	add_to_group("regioes")
	monitoring = true
	monitorable = false
	body_entered.connect(_ao_entrar)


## Monta a colisao a partir das quatro quinas ja projetadas pelo mundo. Recebe o
## MundoIso em vez de reimplementar a projecao: uma segunda copia da conversao
## celula->pixel e a receita para a area e o desenho discordarem.
func montar(mundo: MundoIso) -> void:
	var x0 := retangulo.position.x
	var y0 := retangulo.position.y
	var x1 := retangulo.end.x
	var y1 := retangulo.end.y
	var meia := Vector2(mundo.celula) * 0.5
	var quinas := PackedVector2Array([
		mundo.celula_para_mundo(Vector2i(x0, y0)) + Vector2(0.0, -meia.y),
		mundo.celula_para_mundo(Vector2i(x1, y0)) + Vector2(meia.x, 0.0),
		mundo.celula_para_mundo(Vector2i(x1, y1)) + Vector2(0.0, meia.y),
		mundo.celula_para_mundo(Vector2i(x0, y1)) + Vector2(-meia.x, 0.0),
	])
	var poli := CollisionPolygon2D.new()
	poli.name = "Area"
	poli.polygon = quinas
	add_child(poli)


func contem_celula(c: Vector2i) -> bool:
	return retangulo.has_point(c)


func _ao_entrar(corpo: Node2D) -> void:
	if corpo is Jogador:
		jogador_entrou.emit(id_regiao)
