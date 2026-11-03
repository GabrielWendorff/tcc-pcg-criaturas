class_name DefinicaoOpcao
extends RefCounted

## A DECLARACAO de uma opcao de configuracao: id, rotulo, tipo, padrao.
##
## O PADRAO QUE O PEDIDO PEDIA. Acrescentar uma opcao nova ao jogo e acrescentar
## UMA ENTRADA em Opcoes.DEFINICOES. Nada mais: a tela de opcoes se constroi
## varrendo a lista, a persistencia grava todas as chaves que encontrar, e quem
## consome a opcao pergunta por id. Nao ha campo novo em classe nenhuma, nao ha
## linha nova na interface e nao ha caso novo no arquivo de configuracao.
##
## E o mesmo principio que sustenta o resto do projeto — dispositivo de captura,
## NPC, arvore de dialogo, criatura: o comportamento vem do DADO, e o codigo so
## sabe interpretar a forma. A diferenca e que aqui o dado e uma constante em
## GDScript, e nao um JSON: uma opcao exige um consumidor escrito em codigo de
## qualquer forma, e declara-la num arquivo externo daria a falsa impressao de
## que acrescentar uma linha la basta para ela fazer alguma coisa.
##
## DOIS TIPOS, porque um so nao prova que a estrutura e extensivel:
##
##   BOOLEANA  liga/desliga. `padrao` e bool.
##   ESCOLHA   uma de varias. `valores` e a lista, cada uma com um `dado`
##             associado — o numero ou texto que o consumidor de fato usa.
##
## O `dado` e o que separa a opcao da sua apresentacao: "Rápido" e o que o
## jogador le, 80.0 e o que a caixa de dialogo poe em caracteres por segundo.
## Sem ele, cada consumidor teria um match por id de escolha espalhado pelo
## codigo.

enum Tipo { BOOLEANA, ESCOLHA }

var id: String = ""
var rotulo: String = ""
var descricao: String = ""
var tipo: Tipo = Tipo.BOOLEANA
var padrao: Variant = true

## So em ESCOLHA: [{id, rotulo, dado}, ...], na ordem em que a opcao cicla.
var valores: Array = []


static func de_dicionario(d: Dictionary) -> DefinicaoOpcao:
	var o := DefinicaoOpcao.new()
	o.id = String(d.get("id", ""))
	o.rotulo = String(d.get("rotulo", o.id))
	o.descricao = String(d.get("descricao", ""))
	o.valores = d.get("valores", [])
	o.tipo = Tipo.ESCOLHA if not o.valores.is_empty() else Tipo.BOOLEANA
	o.padrao = d.get("padrao", o.valores[0]["id"] if o.tipo == Tipo.ESCOLHA else true)
	return o


## O valor e aceitavel para esta opcao? Um arquivo de configuracao editado a mao
## (ou de uma versao antiga do jogo) nao pode injetar lixo no estado do jogo.
func aceita(valor: Variant) -> bool:
	if tipo == Tipo.BOOLEANA:
		return valor is bool
	if not (valor is String):
		return false
	return indice_de(valor) >= 0


func indice_de(valor_id: String) -> int:
	for i in valores.size():
		if String(valores[i].get("id", "")) == valor_id:
			return i
	return -1


## Proximo valor na roda. Em BOOLEANA, o inverso; em ESCOLHA, o seguinte da
## lista, dando a volta. Uma opcao que se percorre com a MESMA tecla dos dois
## tipos e o que permite a tela de opcoes ser uma lista so.
func proximo(atual: Variant) -> Variant:
	if tipo == Tipo.BOOLEANA:
		return not bool(atual)
	var i: int = indice_de(String(atual))
	return valores[posmod(i + 1, valores.size())]["id"]


## Como o valor corrente aparece na tela.
func rotulo_do_valor(valor: Variant) -> String:
	if tipo == Tipo.BOOLEANA:
		return "LIGADO" if bool(valor) else "DESLIGADO"
	var i: int = indice_de(String(valor))
	return String(valores[i].get("rotulo", valor)) if i >= 0 else "?"


## O dado associado ao valor corrente — o numero que o consumidor usa. Em
## BOOLEANA e o proprio booleano.
func dado_do_valor(valor: Variant) -> Variant:
	if tipo == Tipo.BOOLEANA:
		return bool(valor)
	var i: int = indice_de(String(valor))
	return valores[i].get("dado") if i >= 0 else null
