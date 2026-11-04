class_name PontoDeEncontro
extends Area2D

## Camada 4 — zona de encontro com criaturas.
##
## A GEOMETRIA E OS DADOS continuam sendo tudo o que este no faz: uma Area2D no
## lugar certo, do tamanho certo, com os campos que a mecanica consome. Quem
## reage a `body_entered` e o GerenciadorEncontro, que se conecta de fora — este
## no nao conhece encontro, criatura nem captura, e continua util sozinho para
## qualquer outra coisa que precise saber "o jogador esta no mato".
##
## O CAMPO QUE LIGA ESTA ZONA AO RESTO DO TRABALHO e `elementos_provaveis`. Ele
## nomeia elementos do vocabulario canonico (data/vocabulary.json) e, desde o
## sistema de encontros, e LIDO: a regiao filtra QUEM se encontra ali — uma
## margem de lago puxa agua e gelo, um pedregal puxa terra e eletrico.
##
## A distincao importa para o artigo: a regiao nao muda COMO a criatura e gerada
## (as tabelas condicionais e o bestiario continuam identicos), so quem aparece
## onde. Ver GerenciadorEncontro._sortear_criatura e docs/mudancas-estruturais.md.
##
## Cada ponto tambem esta no grupo "pontos_de_encontro":
##     for p in get_tree().get_nodes_in_group("pontos_de_encontro"):
##         p.body_entered.connect(...)

## Identificador estavel, vindo do mapa (ex.: "margem_do_lago").
@export var id_ponto: String = ""

## Nome do bioma. Rotulo de autoria, nao enum: quem consumir decide o que fazer.
@export var bioma: String = ""

## Raio da zona, em CELULAS da grade. E o raio no chao — na tela ele vira uma
## elipse 2:1, que e como um circulo no chao se projeta em vista isometrica.
@export var raio_celulas: float = 3.0

## Elementos que a regiao favorece no sorteio da criatura do encontro.
@export var elementos_provaveis: PackedStringArray = PackedStringArray()

## Quantos arbustos a area comporta. Dica de densidade para a proxima etapa.
@export var arbustos_sugeridos: int = 6

## Quantas celulas de grama alta a area de fato cobre no mapa. Vem medido do
## compilador do mapa: e o numero que diz se a zona coube no terreno ou foi
## comida pelo lago, por um caminho ou pela borda.
@export var celulas_de_grama_alta: int = 0

## Numero de lados do poligono da zona. 16 ja da uma elipse limpa em escala de
## jogo e mantem a forma barata para a fisica.
const LADOS := 16


## Fabrica a partir de uma entrada de `pontos_encontro` do mapa.
static func criar(dados: Dictionary, celula: Vector2i) -> PontoDeEncontro:
	var p := PontoDeEncontro.new()
	p.id_ponto = String(dados.get("id", ""))
	p.bioma = String(dados.get("bioma", ""))
	p.raio_celulas = float(dados.get("raio_celulas", 3.0))
	p.arbustos_sugeridos = int(dados.get("arbustos_sugeridos", 6))
	p.celulas_de_grama_alta = int(dados.get("celulas_de_grama_alta", 0))
	var elementos := PackedStringArray()
	for e: String in dados.get("elementos_provaveis", []):
		elementos.append(e)
	p.elementos_provaveis = elementos
	p.name = "PontoDeEncontro_" + p.id_ponto
	p.celula_do_mapa = celula
	return p


var celula_do_mapa: Vector2i = Vector2i(32, 16)


func _ready() -> void:
	add_to_group("pontos_de_encontro")
	# Monitorando sempre. Quem escuta e o GerenciadorEncontro, que se conecta apos
	# o mundo montar; sem ouvinte, o custo de 8 areas paradas e irrelevante.
	monitoring = true
	monitorable = false
	var poli := CollisionPolygon2D.new()
	poli.name = "Zona"
	poli.polygon = poligono()
	add_child(poli)


## Contorno da zona em pixels, a partir de um circulo de `raio_celulas` no CHAO.
##
## Projetar o circulo do chao — e nao desenhar uma elipse direto na tela — e o
## que faz a zona cobrir sempre as mesmas celulas, qualquer que seja o raio.
func poligono() -> PackedVector2Array:
	var pontos := PackedVector2Array()
	var mx := celula_do_mapa.x * 0.5
	var my := celula_do_mapa.y * 0.5
	for i in LADOS:
		var ang := TAU * float(i) / float(LADOS)
		var gx := raio_celulas * cos(ang)
		var gy := raio_celulas * sin(ang)
		pontos.append(Vector2((gx - gy) * mx, (gx + gy) * my))
	return pontos


func _to_string() -> String:
	return "%s [%s] raio=%.1f celulas, grama_alta=%d, elementos=%s" % [
		id_ponto, bioma, raio_celulas, celulas_de_grama_alta,
		", ".join(elementos_provaveis)]
