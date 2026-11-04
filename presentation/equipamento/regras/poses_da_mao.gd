class_name PosesDaMao
extends RefCounted

## Onde o item equipado fica, por direcao encarada — o dado por tras do SlotDaMao.
##
## Os numeros sao ajuste fino de pixel ("a mao do quadro de lado fica 1px mais
## alta"), do tipo que se calibra olhando a tela, varias vezes. Por isso moram em
## data/itens/mao.json e nao no codigo do no: trocar a pose e editar um JSON e
## reabrir a cena, sem tocar em GDScript.
##
## PADROES EMBUTIDOS. Os mesmos valores do JSON estao aqui; o arquivo os
## SOBRESCREVE campo a campo. Mesmo padrao de ConfiguracaoEncontro: um arquivo
## ausente ou incompleto degrada a calibragem, nunca o jogo — perder a pose da
## mao nao pode impedir o jogador de existir.
##
## Regra pura: RefCounted, sem Node, sem autoload. O teste le e confere sem
## montar cena.

const CAMINHO := "res://data/itens/mao.json"

## As quatro direcoes da folha do protagonista (ver Jogador.LINHA_DA_DIRECAO).
const DIRECOES := ["baixo", "esquerda", "direita", "cima"]

## Direcao usada quando pedem uma que nao existe. "baixo" porque e a pose de
## repouso do jogador (o personagem nasce olhando para a camera).
const DIRECAO_PADRAO := "baixo"

## Referencial: pixels do mundo relativos ao PE do jogador (a origem do no).
## O sprite e 24x24 com offset (-12, -22): a mao fica em y ~ -4..-7.
## rotacao em graus, horario; o item e desenhado com o cabo na origem e o
## corpo para cima, entao rotacao 0 = item em pe.
##
## Nas poses espelhadas a ponta continua indo para onde a rotacao manda
## (espelhar e scale.x = -1, que o Node2D aplica ANTES de girar): por isso a de
## "baixo" e negativa — a mao e a da esquerda da tela, e a vara se abre para
## fora, sem cruzar o rosto.
const POSES_PADRAO := {
	"baixo": {"posicao": Vector2(-7, -5), "rotacao": -30.0, "atras": false, "espelhar": true},
	"esquerda": {"posicao": Vector2(-6, -7), "rotacao": -35.0, "atras": false, "espelhar": true},
	"direita": {"posicao": Vector2(6, -7), "rotacao": 35.0, "atras": false, "espelhar": false},
	"cima": {"posicao": Vector2(5, -6), "rotacao": 20.0, "atras": true, "espelhar": false},
}

## Durante a pesca so a rotacao muda (vara erguida na direcao da agua). Qualquer
## campo de pose pode ser sobrescrito aqui; o que nao for, vem da pose comum.
const PESCA_PADRAO := {
	"baixo": {"rotacao": -55.0},
	"esquerda": {"rotacao": -60.0},
	"direita": {"rotacao": 60.0},
	"cima": {"rotacao": 10.0},
}

# --- arremesso (animacao do lance, graus somados a pose de pesca) -----------
## Para tras antes do lance. Negativo = anti-horario na pose NAO espelhada (a
## vara de quem olha para a direita sobe por cima do ombro); o SlotDaMao inverte
## o sinal nas espelhadas.
var recuo_graus: float = -70.0
## Para a frente, no instante em que a linha sai.
var avanco_graus: float = 25.0
var duracao_recuo: float = 0.18
var duracao_avanco: float = 0.12

## Mensagem do ultimo problema de leitura ("" = arquivo lido inteiro ou
## ausente). Nao impede nada: existe para o teste e para quem calibra saber
## que o JSON foi ignorado.
var erro: String = ""

var _poses: Dictionary = {}
var _pesca: Dictionary = {}


func _init() -> void:
	_poses = _copiar_poses(POSES_PADRAO)
	_pesca = PESCA_PADRAO.duplicate(true)


## Poses com os padroes acima, sobrescritas pelo JSON quando ele existe. Nunca
## devolve null.
static func carregar(caminho: String = CAMINHO) -> PosesDaMao:
	var p := PosesDaMao.new()
	if not FileAccess.file_exists(caminho):
		return p
	var dados: Variant = JSON.parse_string(FileAccess.get_file_as_string(caminho))
	if not (dados is Dictionary):
		p.erro = "JSON invalido: " + caminho
		push_warning("PosesDaMao: JSON invalido, usando padroes — " + caminho)
		return p
	p._aplicar(dados)
	return p


## Mesma leitura, a partir de um dicionario ja carregado — util para a cena de
## teste calibrar uma pose sem gravar arquivo.
static func de_dicionario(d: Dictionary) -> PosesDaMao:
	var p := PosesDaMao.new()
	p._aplicar(d)
	return p


## Pose de uma direcao: {"posicao": Vector2, "rotacao": float (graus),
## "atras": bool, "espelhar": bool}. Sempre com as quatro chaves — quem consome
## nao precisa de get() com padrao. Direcao desconhecida cai em DIRECAO_PADRAO.
##
## `pescando` sobrepoe os campos declarados em "pesca" para a mesma direcao.
func pose(direcao: String, pescando: bool = false) -> Dictionary:
	var dir: String = direcao if _poses.has(direcao) else DIRECAO_PADRAO
	var base: Dictionary = (_poses[dir] as Dictionary).duplicate()
	if pescando and _pesca.has(dir):
		_sobrepor(base, _pesca[dir])
	return base


## +1 ou -1: o sentido de "para tras" e "para a frente" nesta direcao. Numa
## pose espelhada a vara aponta para o outro lado, e o mesmo giro de -70 graus
## que a ergue por cima do ombro de quem olha para a direita a jogaria para
## dentro do corpo de quem olha para a esquerda.
func sinal_do_giro(direcao: String, pescando: bool = false) -> float:
	return -1.0 if bool(pose(direcao, pescando)["espelhar"]) else 1.0


# --- leitura ----------------------------------------------------------------

func _aplicar(d: Dictionary) -> void:
	var poses: Variant = d.get("poses", {})
	if poses is Dictionary:
		for dir: String in (poses as Dictionary).keys():
			var bruto: Variant = poses[dir]
			if not (bruto is Dictionary):
				erro = "pose '%s' nao e um objeto" % dir
				continue
			if not _poses.has(dir):
				# Direcao nova (uma folha de 8 direcoes, um dia): parte da pose
				# padrao para nunca existir pose com chave faltando.
				_poses[dir] = (_poses[DIRECAO_PADRAO] as Dictionary).duplicate()
			_sobrepor(_poses[dir], bruto)

	var pesca: Variant = d.get("pesca", {})
	if pesca is Dictionary:
		for dir: String in (pesca as Dictionary).keys():
			var bruto_p: Variant = pesca[dir]
			if not (bruto_p is Dictionary):
				erro = "pose de pesca '%s' nao e um objeto" % dir
				continue
			if not _pesca.has(dir):
				_pesca[dir] = {}
			# Guarda ja convertido: o _sobrepor de pose() le Vector2/float.
			_sobrepor(_pesca[dir], bruto_p)

	var a: Variant = d.get("arremesso", {})
	if a is Dictionary:
		recuo_graus = float(a.get("recuo_graus", recuo_graus))
		avanco_graus = float(a.get("avanco_graus", avanco_graus))
		duracao_recuo = maxf(0.0, float(a.get("duracao_recuo", duracao_recuo)))
		duracao_avanco = maxf(0.0, float(a.get("duracao_avanco", duracao_avanco)))


## Copia para `alvo` so os campos conhecidos de `fonte`, convertendo o formato
## do JSON ([x, y], numeros) para o da pose (Vector2, float, bool). Campo
## estranho e ignorado: um erro de digitacao na calibragem nao pode virar uma
## chave a mais que alguem consome por engano.
static func _sobrepor(alvo: Dictionary, fonte: Dictionary) -> void:
	if fonte.has("posicao"):
		var p: Variant = fonte["posicao"]
		if p is Vector2:
			alvo["posicao"] = p
		elif p is Array and (p as Array).size() >= 2:
			alvo["posicao"] = Vector2(float(p[0]), float(p[1]))
	if fonte.has("rotacao"):
		alvo["rotacao"] = float(fonte["rotacao"])
	if fonte.has("atras"):
		alvo["atras"] = bool(fonte["atras"])
	if fonte.has("espelhar"):
		alvo["espelhar"] = bool(fonte["espelhar"])


static func _copiar_poses(origem: Dictionary) -> Dictionary:
	var saida: Dictionary = {}
	for dir: String in origem.keys():
		saida[dir] = (origem[dir] as Dictionary).duplicate()
	return saida
