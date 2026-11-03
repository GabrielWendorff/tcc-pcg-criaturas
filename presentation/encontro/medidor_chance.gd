class_name MedidorChance
extends Control

## Barra segmentada que mostra a chance de captura.
##
## Existe porque "45%" em corpo 11 e um dado que o jogador LE; uma barra e um
## dado que ele VE. Numa decisao que se toma em um segundo — qual dispositivo
## lancar — a diferenca entre ler e ver e a diferenca entre a interface ajudar
## ou atrapalhar.
##
## Tres canais redundantes para a mesma informacao: comprimento preenchido, cor e
## numero. Redundancia proposital — quem nao distingue vermelho de verde le a
## mesma coisa pelo comprimento, e a cor sozinha nunca decide nada aqui.
##
## Segmentos discretos, nao barra continua: em pixel art uma barra que avanca
## 0,7px por quadro produz uma coluna de meio pixel na ponta. Blocos inteiros
## avancam de bloco em bloco e cada estado e desenhavel exatamente.

## Largura de cada bloco e do vao entre eles, em pixels de tela.
const BLOCO := 5
const VAO := 1
const ALTURA_BARRA := 9

var segmentos: int = 10
var valor: float = 0.0:
	set(v):
		valor = clampf(v, 0.0, 1.0)
		queue_redraw()

## Mostra o numero a direita da barra.
var com_numero: bool = true

## Sobre fundo claro (pergaminho), troca os tons de estado pelos escuros. Sem
## isto o dourado do medidor desaparece no bege e a barra fica sem leitura.
var sobre_claro: bool = false:
	set(v):
		sobre_claro = v
		queue_redraw()


func _init(segmentos_: int = 10, com_numero_: bool = true,
		sobre_claro_: bool = false) -> void:
	segmentos = segmentos_
	com_numero = com_numero_
	sobre_claro = sobre_claro_
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(largura_da_barra() + (30 if com_numero else 0),
			ALTURA_BARRA + 2)


func largura_da_barra() -> float:
	return float(segmentos * BLOCO + (segmentos - 1) * VAO + 4)


func _draw() -> void:
	var cor: Color = TemaEncontro.cor_da_chance_sobre_claro(valor) if sobre_claro \
			else TemaEncontro.cor_da_chance(valor)
	var y := (size.y - ALTURA_BARRA) * 0.5
	# trilho
	draw_rect(Rect2(0, y, largura_da_barra(), ALTURA_BARRA), TemaEncontro.CONTORNO)
	draw_rect(Rect2(1, y + 1, largura_da_barra() - 2, ALTURA_BARRA - 2),
			TemaEncontro.PERG_E if sobre_claro else TemaEncontro.NOITE_E)
	# blocos. round e nao floor: com floor, 99% mostraria o mesmo que 90%.
	var cheios: int = roundi(valor * float(segmentos))
	for i in segmentos:
		if i >= cheios:
			break
		var x := 2.0 + float(i) * float(BLOCO + VAO)
		draw_rect(Rect2(x, y + 2, BLOCO, ALTURA_BARRA - 4), cor)
		# risco claro no topo do bloco: o mesmo chanfro das molduras
		draw_rect(Rect2(x, y + 2, BLOCO, 1), cor.lightened(0.35))
	if com_numero:
		var texto := "%d%%" % roundi(valor * 100.0)
		draw_string(TemaEncontro.fonte(),
				Vector2(largura_da_barra() + 6, y + ALTURA_BARRA - 1),
				texto, HORIZONTAL_ALIGNMENT_LEFT, -1, TemaEncontro.TAM_TEXTO, cor)
