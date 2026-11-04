class_name CondicaoDialogo
extends RefCounted

## Avaliador das condicoes declarativas do dialogo.
##
## O que este arquivo existe para evitar e a cadeia de if/else dentro do NPC. A
## condicao e DADO: mora no JSON da arvore, e o mesmo avaliador serve para
## esconder uma escolha, trocar a fala de um no ou barrar um servico.
##
## GRAMATICA (tudo opcional; ausencia de condicao e sempre verdadeiro):
##
##   {"bandeira": "conheceu_pescador"}          bandeira ativa
##   {"bandeira": "moedas", "pelo_menos": 10}   comparacao numerica
##   {"bandeira": "fase", "igual": "final"}     igualdade exata
##   {"visitou": "ribeira"}                     regiao ja pisada
##   {"falou_com": "anselmo"}                   qualquer no daquele NPC ja visto
##   {"viu": ["anselmo", "sobre_o_rio"]}        um no especifico ja visto
##   {"item": "isca_frutada", "pelo_menos": 1}  dominio externo (provedor)
##   {"nao": {...}}                             negacao
##   {"todos": [{...}, {...}]}                  conjuncao
##   {"algum": [{...}, {...}]}                  disjuncao
##
## `pelo_menos`/`no_maximo` combinam com qualquer fonte de valor (bandeira ou
## dominio externo). Sem nenhum dos dois, a fonte e lida como verdade/falsidade.
##
## O QUE AINDA NAO EXISTE e deliberado: hora do dia, missao ativa e progressao de
## historia entram como DOMINIOS novos (um provedor registrado no EstadoMundo),
## nao como chaves novas aqui. Ver README.

## Chaves que nomeiam uma fonte de valor.
const FONTES := ["bandeira", "visitou", "falou_com", "viu", "item", "capturadas"]

## Chaves que compoem condicoes.
const COMPOSTAS := ["nao", "todos", "algum"]

## Chaves de comparacao aceitas ao lado de uma fonte.
const COMPARACOES := ["igual", "diferente", "pelo_menos", "no_maximo"]


static func avaliar(condicao: Variant, estado: EstadoMundo) -> bool:
	if condicao == null or estado == null:
		return true
	if condicao is Array:
		# Lista solta e conjuncao — o caso mais comum escrito do jeito mais curto.
		for sub: Variant in condicao:
			if not avaliar(sub, estado):
				return false
		return true
	if not condicao is Dictionary:
		return true
	var d: Dictionary = condicao
	if d.is_empty():
		return true

	if d.has("nao"):
		return not avaliar(d["nao"], estado)
	if d.has("todos"):
		for sub: Variant in d["todos"]:
			if not avaliar(sub, estado):
				return false
		return true
	if d.has("algum"):
		for sub: Variant in d["algum"]:
			if avaliar(sub, estado):
				return true
		return false

	var valor: Variant = _valor_da_fonte(d, estado)
	if d.has("igual"):
		return _iguais(valor, d["igual"])
	if d.has("diferente"):
		return not _iguais(valor, d["diferente"])
	if d.has("pelo_menos"):
		return _numero(valor) >= float(d["pelo_menos"])
	if d.has("no_maximo"):
		return _numero(valor) <= float(d["no_maximo"])
	return _verdadeiro(valor)


## De onde a condicao tira o valor que sera comparado.
static func _valor_da_fonte(d: Dictionary, estado: EstadoMundo) -> Variant:
	if d.has("bandeira"):
		return estado.ler(String(d["bandeira"]))
	if d.has("visitou"):
		return estado.visitou(String(d["visitou"]))
	if d.has("falou_com"):
		return estado.ja_falou_com(String(d["falou_com"]))
	if d.has("viu"):
		var par: Array = d["viu"]
		if par.size() < 2:
			return false
		return estado.quantas_vezes(String(par[0]), String(par[1]))
	if d.has("item"):
		return estado.consultar("item", String(d["item"]))
	if d.has("capturadas"):
		return estado.consultar("capturadas", String(d["capturadas"]))
	return null


static func _iguais(a: Variant, b: Variant) -> bool:
	if a == null:
		# null nunca e igual a nada escrito no JSON, exceto a propria ausencia.
		return b == null
	if (a is int or a is float) and (b is int or b is float):
		return is_equal_approx(float(a), float(b))
	return String(a) == String(b) if a is String or b is String else a == b


static func _numero(v: Variant) -> float:
	if v is bool:
		return 1.0 if v else 0.0
	if v is int or v is float:
		return float(v)
	return 0.0


static func _verdadeiro(v: Variant) -> bool:
	if v == null:
		return false
	if v is bool:
		return v
	if v is int or v is float:
		return float(v) != 0.0
	if v is String:
		return v != ""
	return true


## Erros de FORMA da condicao — checagem de ferramenta, nao de execucao.
##
## Uma condicao com chave errada ("bandeirq") avalia como verdadeira em silencio,
## e a escolha que deveria estar escondida aparece. Quem pega isso e o teste, nao
## o jogador; por isso a validacao e separada da avaliacao.
static func validar(condicao: Variant, onde: String) -> PackedStringArray:
	var erros := PackedStringArray()
	if condicao == null:
		return erros
	if condicao is Array:
		for i in (condicao as Array).size():
			erros.append_array(validar(condicao[i], "%s[%d]" % [onde, i]))
		return erros
	if not condicao is Dictionary:
		erros.append("%s: condicao deve ser objeto ou lista, veio %s"
				% [onde, type_string(typeof(condicao))])
		return erros

	var d: Dictionary = condicao
	var compostas := 0
	for chave: String in COMPOSTAS:
		if d.has(chave):
			compostas += 1
			if chave == "nao":
				erros.append_array(validar(d[chave], onde + ".nao"))
			elif d[chave] is Array:
				for i in (d[chave] as Array).size():
					erros.append_array(validar(d[chave][i], "%s.%s[%d]" % [onde, chave, i]))
			else:
				erros.append("%s.%s deve ser lista de condicoes" % [onde, chave])
	if compostas > 0:
		if d.size() > compostas:
			erros.append("%s mistura composicao com fonte de valor" % onde)
		return erros

	var fontes := 0
	for chave: String in FONTES:
		if d.has(chave):
			fontes += 1
	if fontes == 0:
		erros.append("%s: nenhuma fonte reconhecida (esperado %s)"
				% [onde, ", ".join(FONTES)])
	elif fontes > 1:
		erros.append("%s declara mais de uma fonte de valor" % onde)
	if d.has("viu") and not d["viu"] is Array:
		erros.append("%s.viu deve ser [npc, no]" % onde)
	for chave: String in d.keys():
		if not chave in FONTES and not chave in COMPARACOES and not chave in COMPOSTAS:
			erros.append("%s: chave desconhecida '%s'" % [onde, chave])
	return erros
