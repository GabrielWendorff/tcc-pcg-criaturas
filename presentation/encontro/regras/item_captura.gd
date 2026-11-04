class_name ItemCaptura
extends RefCounted

## Raiz comum de tudo que pode ocupar um slot da roda de selecao: dispositivos e
## iscas. Existe para que RodaCaptura seja UMA roda — ela recebe Array[ItemCaptura]
## e nao sabe (nem precisa saber) se esta mostrando o que prende ou o que atrai.
##
## Os campos aqui sao os que a roda desenha; o que cada especializacao acrescenta
## (multiplicador, tipos preferidos) so interessa ao CalculoCaptura.

var id: String = ""
var nome: String = ""
var descricao: String = ""

## Primitiva que IconeCaptura desenha. O projeto nao tem PNG de item, e desenhar a
## forma por codigo mantem a arte de interface na mesma politica do resto do
## trabalho: gerada, nao autorada arquivo a arquivo.
var forma: String = "esfera"

## Cor de destaque do slot, em hexadecimal sem '#'. Vem do dado, nao da roda.
var cor: Color = Color("8a909c")

## Quanto o jogador tem no inicio. O estoque corrente vive no InventarioJogador —
## este campo e so a carga inicial declarada no JSON.
var quantidade_inicial: int = 0


func _ler_comuns(d: Dictionary) -> void:
	id = String(d.get("id", ""))
	nome = String(d.get("nome", id))
	descricao = String(d.get("descricao", ""))
	forma = String(d.get("forma", "esfera"))
	cor = Color(String(d.get("cor", "8a909c")))
	quantidade_inicial = int(d.get("quantidade_inicial", 0))


## Linha curta que a roda mostra sob o nome. Cada especializacao responde com o
## que de fato distingue o item.
func detalhe(_criatura: Criatura) -> String:
	return descricao
