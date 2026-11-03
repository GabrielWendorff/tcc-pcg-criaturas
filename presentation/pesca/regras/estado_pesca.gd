class_name EstadoPesca
extends RefCounted

## Maquina de estados da pesca. Espelha EstadoEncontro, pelo mesmo motivo: a pesca
## e uma sequencia com ordem obrigatoria (nao se recolhe sem ter arremessado, nao
## se fisga sem estar recolhendo), e guardar isso em bandeiras soltas
## (`arremessando`, `recolhendo`, ...) admitiria estados impossiveis — duas iscas
## na agua, um arremesso durante o resultado. Aqui eles simplesmente nao existem.
##
## TRANSICOES e a especificacao executavel do fluxo pedido:
##   OCIOSO -> ARREMESSO -> RECOLHENDO -> (FISGADO | FALHOU) -> OCIOSO
## mais a saida ARREMESSO -> FALHOU, que e o cancelamento antes de a isca cair.
##
## Diferente do encontro, uma transicao fora da tabela gera push_warning e nao
## push_error: a pesca e cancelavel a qualquer quadro (ui_cancel), e um cancelar que
## chega no mesmo quadro de um FISGADO e corrida de entrada, nao bug — o pedido e
## recusado e o estado fica coerente.

enum Estado {
	OCIOSO,       ## exploracao normal; o indicador "[F] PESCAR" pode aparecer
	ARREMESSO,    ## arco de forca oscilando; jogador congelado
	RECOLHENDO,   ## isca na agua; o minigame de recolhimento roda
	FISGADO,      ## o monstro mordeu — ponto de integracao com batalha/captura
	FALHOU,       ## cancelada, isca recolhida sem peixe, ou o monstro fugiu
}

const TRANSICOES := {
	Estado.OCIOSO:     [Estado.ARREMESSO],
	Estado.ARREMESSO:  [Estado.RECOLHENDO, Estado.FALHOU],
	Estado.RECOLHENDO: [Estado.FISGADO, Estado.FALHOU],
	Estado.FISGADO:    [Estado.OCIOSO],
	Estado.FALHOU:     [Estado.OCIOSO],
}

const NOMES := {
	Estado.OCIOSO: "OCIOSO", Estado.ARREMESSO: "ARREMESSO",
	Estado.RECOLHENDO: "RECOLHENDO", Estado.FISGADO: "FISGADO",
	Estado.FALHOU: "FALHOU",
}

signal mudou(anterior: Estado, atual: Estado)

var atual: Estado = Estado.OCIOSO


func e(estado: Estado) -> bool:
	return atual == estado


## Verdadeiro enquanto a pesca tem o controle: o jogador fica congelado e as
## outras interacoes (dialogo, roda, pausa) devem recusar.
func ativa() -> bool:
	return atual != Estado.OCIOSO


func pode_ir_para(novo: Estado) -> bool:
	return novo in TRANSICOES.get(atual, [])


## Aplica a transicao. Pedir o estado em que ja se esta e aceito sem emitir nada
## (idempotente, como no encontro). Fora da tabela devolve false sem mudar nada.
func mudar_para(novo: Estado) -> bool:
	if novo == atual:
		return true
	if not pode_ir_para(novo):
		push_warning("EstadoPesca: transicao invalida %s -> %s"
				% [NOMES[atual], NOMES[novo]])
		return false
	var anterior := atual
	atual = novo
	mudou.emit(anterior, atual)
	return true


## Volta ao repouso de qualquer estado. Existe para a limpeza: uma pesca
## interrompida (troca de cena, save carregado) precisa de saida que a tabela nao
## oferece.
func reiniciar() -> void:
	var anterior := atual
	atual = Estado.OCIOSO
	if anterior != Estado.OCIOSO:
		mudou.emit(anterior, atual)


static func nome(estado: Estado) -> String:
	return NOMES.get(estado, "?")
