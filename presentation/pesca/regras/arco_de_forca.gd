class_name ArcoDeForca
extends RefCounted

## Geometria e tempo do medidor de arremesso em meio circulo, separados do no que
## desenha (MedidorArremesso). Funcoes puras: o mesmo tempo da sempre o mesmo valor,
## e o teste headless confere o vai-e-volta e as zonas sem abrir janela.
##
## Convencao do arco: valor 0 = ponta ESQUERDA, 0.5 = topo, 1 = ponta DIREITA, com o
## eixo y da tela para baixo (por isso o topo e o angulo 3*PI/2). As zonas seguem a
## ordem pedida — verde (fraco) no comeco, amarelo (medio), vermelho (maximo) no
## fim — e, como o valor e o mesmo na ida e na volta, a ordem se repete ao voltar.


## Posicao no arco (0..1) depois de `tempo` segundos, indo e voltando:
## 0 em t=0, 1 em t=1/velocidade, 0 de novo em t=2/velocidade. `velocidade` e a
## fracao do arco percorrida por segundo. Velocidade <= 0 deixa o ponteiro parado
## na esquerda em vez de dividir por zero.
static func pingpong(tempo: float, velocidade: float) -> float:
	if velocidade <= 0.0:
		return 0.0
	# Calculado a mao: dentro desta classe o nome `pingpong` resolve para este
	# proprio metodo, nao para o global da engine — chama-lo seria recursao.
	var fase: float = fposmod(tempo * velocidade, 2.0)
	return fase if fase <= 1.0 else 2.0 - fase


## Zona de um valor do arco. Os limites pertencem a zona SEGUINTE:
## [0, verde) fraco, [verde, amarelo) medio, [amarelo, 1] maximo.
static func zona(valor: float, limite_verde: float, limite_amarelo: float) -> String:
	if valor < limite_verde:
		return "fraco"
	if valor < limite_amarelo:
		return "medio"
	return "maximo"


## Angulo (radianos) do ponto do arco: PI + PI*valor. Valor fora de 0..1 e preso
## ao arco — o ponteiro nunca desenha por baixo do meio circulo.
static func angulo(valor: float) -> float:
	return PI + PI * clampf(valor, 0.0, 1.0)


## Ponto do arco em coordenadas de tela, relativo a `centro`.
static func ponto(centro: Vector2, raio: float, valor: float) -> Vector2:
	var a := angulo(valor)
	return centro + Vector2(cos(a), sin(a)) * raio
