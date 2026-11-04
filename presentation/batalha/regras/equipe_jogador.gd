class_name EquipeJogador
extends RefCounted

## Equipe ativa (ate o maximo de data/batalha/balanceamento.json) e deposito.
##
## NAO e autoload, embora sistemas/README.md previsse um: a regua daquele diretorio e
## o tempo de vida, e uma Criatura so resolve contra o bestiario, que nasce e morre
## com a cena do mundo. Esta classe vive no GerenciadorEncontro e o save a colhe por
## secao de cena, como os demais sistemas do mundo.

signal mudou()

var maximo: int = 3
var ativos: Array[Combatente] = []
var deposito: Array[Combatente] = []


func _init(maximo_: int = 3) -> void:
	maximo = maximo_


## Entra na equipe se couber, senao vai para o deposito. Devolve true se entrou na
## equipe.
func adicionar(c: Combatente) -> bool:
	var coube: bool = ativos.size() < maximo
	if coube:
		ativos.append(c)
	else:
		deposito.append(c)
	mudou.emit()
	return coube


func vazia() -> bool:
	return ativos.is_empty()


func tem_vivos() -> bool:
	for c: Combatente in ativos:
		if c.viva():
			return true
	return false


func vivos() -> int:
	var n: int = 0
	for c: Combatente in ativos:
		if c.viva():
			n += 1
	return n


## Cura a equipe e o deposito (servico gratuito da vila).
func curar_todos() -> void:
	for c: Combatente in ativos + deposito:
		c.curar_tudo()
	mudou.emit()


## Troca um membro por uma criatura do deposito.
func trocar_com_deposito(i_ativo: int, i_deposito: int) -> bool:
	if i_ativo < 0 or i_ativo >= ativos.size() \
			or i_deposito < 0 or i_deposito >= deposito.size():
		return false
	var saindo: Combatente = ativos[i_ativo]
	ativos[i_ativo] = deposito[i_deposito]
	deposito[i_deposito] = saindo
	mudou.emit()
	return true


## Sobe uma criatura do deposito para a equipe, se houver vaga.
func promover(i_deposito: int) -> bool:
	if ativos.size() >= maximo or i_deposito < 0 or i_deposito >= deposito.size():
		return false
	ativos.append(deposito[i_deposito])
	deposito.remove_at(i_deposito)
	mudou.emit()
	return true


## Reordena: a primeira da equipe e quem entra em campo.
func tornar_primeira(i_ativo: int) -> bool:
	if i_ativo <= 0 or i_ativo >= ativos.size():
		return false
	var c: Combatente = ativos[i_ativo]
	ativos.remove_at(i_ativo)
	ativos.push_front(c)
	mudou.emit()
	return true


## Troca duas criaturas de lugar dentro da equipe.
func trocar_posicoes(i: int, j: int) -> bool:
	if i < 0 or j < 0 or i >= ativos.size() or j >= ativos.size() or i == j:
		return false
	var c: Combatente = ativos[i]
	ativos[i] = ativos[j]
	ativos[j] = c
	mudou.emit()
	return true


## Primeira criatura em que o efeito do item faz algo: quem esta mais ferida entre as
## que ele alcanca. null = ninguem. Lista so a equipe: o deposito nao entra em campo.
func alvo_de_efeito(efeito: Dictionary) -> Combatente:
	var melhor: Combatente = null
	for c: Combatente in ativos:
		if CalculoBatalha.efeito_aplicavel(efeito, c) \
				and (melhor == null or c.fracao() < melhor.fracao()):
			melhor = c
	return melhor


# ----------------------------------------------------------------------- save

func para_salvas(lista: Array[Combatente]) -> Array[CriaturaSalva]:
	var saida: Array[CriaturaSalva] = []
	for c: Combatente in lista:
		var s := CriaturaSalva.de_criatura(c.criatura)
		s.hp_atual = c.vida
		saida.append(s)
	return saida
