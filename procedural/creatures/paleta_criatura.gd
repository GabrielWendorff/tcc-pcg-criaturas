class_name PaletaCriatura
extends RefCounted

## Traducao dos atributos categoricos de cor (matiz, paleta) para cores concretas.
##
## Vive na camada procedural, e nao na de apresentacao, porque a cor da criatura E um
## atributo derivado (RF04): quem decide 'vermelho + quente' e a tabela condicionada ao
## elemento. Aqui so se resolve como esse par vira pixels, e o resultado e uma funcao
## pura dos atributos — mesma criatura, mesma cor, em qualquer tela (RF03).
##
## A rampa de 4 tons alimenta paleta_indexada.gdshader, que pinta as mascaras de
## arte/. Derivar a rampa de (matiz, paleta) — e nao de uma tabela fixa por elemento —
## e proposital: uma cor por elemento tornaria I(elemento; cor) trivialmente igual a
## H(elemento), inflando a metrica de RF08 com um resultado que nao vem do modelo
## probabilistico. Mantendo a cor como derivado sorteado, a informacao mutua medida
## continua sendo a que as tabelas condicionais de fato produzem.

const CORES_MATIZ := {
	"vermelho": Color("e14b4b"), "laranja": Color("e8863a"), "amarelo": Color("e8cf4b"),
	"verde": Color("5bbf5b"), "ciano": Color("4bd6d6"), "azul": Color("4b6ee8"),
	"roxo": Color("9b5be8"), "marrom": Color("8a5a3c"), "cinza": Color("8a909c"),
	"branco": Color("e8ecf2"),
}

const COR_PADRAO := Color("8a909c")


## Cor base do corpo: matiz ajustado pela familia de paleta.
static func cor_base(matiz: String, paleta: String) -> Color:
	var c: Color = CORES_MATIZ.get(matiz, COR_PADRAO)
	match paleta:
		"vibrante": c.s = clampf(c.s * 1.35, 0.0, 1.0); c.v = clampf(c.v * 1.05, 0.0, 1.0)
		"neutra":   c.s = c.s * 0.5
		"terrosa":  c.s = c.s * 0.7; c.v = c.v * 0.82
		"quente":   c.s = clampf(c.s * 1.15, 0.0, 1.0); c.v = clampf(c.v * 1.03, 0.0, 1.0)
		"fria":     c.s = clampf(c.s * 1.1, 0.0, 1.0)
	return c


## Rampa de 4 tons na ordem dos indices da mascara: 1 contorno, 2 sombra, 3 base,
## 4 brilho. O contorno nao e preto puro nem o brilho branco puro: ambos carregam o
## matiz, que e o que faz 100 criaturas com a mesma silhueta ainda se distinguirem.
static func rampa(matiz: String, paleta: String) -> Array[Color]:
	var base := cor_base(matiz, paleta)
	var tons: Array[Color] = [
		base.darkened(0.74), base.darkened(0.34), base, base.lightened(0.42)
	]
	return tons
