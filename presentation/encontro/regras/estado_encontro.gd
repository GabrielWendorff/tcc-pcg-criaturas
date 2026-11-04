class_name EstadoEncontro
extends RefCounted

## Maquina de estados do encontro.
##
## O projeto nao tinha maquina de estados nenhuma — a exploracao e um
## CharacterBody2D lendo entrada todo frame. Um encontro, porem, e uma sequencia
## com ordem obrigatoria e caminhos que NAO podem se cruzar: enquanto o
## dispositivo esta no ar nao se abre menu, nao se ataca e, sobretudo, nao se
## lanca um segundo dispositivo. Guardar isso em bandeiras booleanas
## (`esta_capturando`, `esta_em_transicao`, ...) admite estados impossiveis; aqui
## os estados impossiveis simplesmente nao existem.
##
## TRANSICOES e a especificacao executavel do fluxo. Uma transicao fora da tabela
## e ERRO DE PROGRAMACAO, nao entrada invalida do jogador: por isso push_error e
## nao um retorno silencioso.

enum Estado {
	INATIVO,            ## exploracao normal; e o unico estado em que a deteccao roda
	DETECTADO,          ## sorteio deu encontro; o jogador ja esta congelado
	AVISO,              ## "!" sobre a cabeca + tremor de camera
	TRANSICAO,          ## escurecimento da tela
	APRESENTACAO,       ## cartao "CRIATURA ENCONTRADA"
	INTERACAO,          ## menu de batalha: golpes / capturar / isca / bolsa / trocar / fugir
	RODA_DISPOSITIVO,   ## roda radial escolhendo o dispositivo
	RODA_ISCA,          ## a MESMA roda, escolhendo isca
	LANCANDO,           ## dispositivo no ar; nenhuma entrada e aceita
	SUCESSO,            ## capturada
	FALHA,              ## escapou do dispositivo
	ATACANDO,           ## turno resolvendo: os eventos do motor estao sendo mostrados
	TROCA_OBRIGATORIA,  ## a criatura do jogador caiu: nada acontece ate ele escolher outra
	ENCERRANDO,         ## desmontando a interface e devolvendo o controle
}

const TRANSICOES := {
	Estado.INATIVO:          [Estado.DETECTADO],
	Estado.DETECTADO:        [Estado.AVISO, Estado.ENCERRANDO],
	Estado.AVISO:            [Estado.TRANSICAO, Estado.ENCERRANDO],
	Estado.TRANSICAO:        [Estado.APRESENTACAO, Estado.ENCERRANDO],
	Estado.APRESENTACAO:     [Estado.INTERACAO, Estado.ENCERRANDO],
	Estado.INTERACAO:        [Estado.RODA_DISPOSITIVO, Estado.RODA_ISCA,
			Estado.ATACANDO, Estado.ENCERRANDO],
	Estado.RODA_DISPOSITIVO: [Estado.LANCANDO, Estado.INTERACAO],
	Estado.RODA_ISCA:        [Estado.INTERACAO, Estado.ATACANDO],
	Estado.LANCANDO:         [Estado.SUCESSO, Estado.FALHA],
	Estado.SUCESSO:          [Estado.ENCERRANDO],
	Estado.FALHA:            [Estado.INTERACAO, Estado.ATACANDO, Estado.ENCERRANDO],
	Estado.ATACANDO:         [Estado.INTERACAO, Estado.TROCA_OBRIGATORIA, Estado.ENCERRANDO],
	Estado.TROCA_OBRIGATORIA: [Estado.ATACANDO, Estado.ENCERRANDO],
	Estado.ENCERRANDO:       [Estado.INATIVO],
}

const NOMES := {
	Estado.INATIVO: "INATIVO", Estado.DETECTADO: "DETECTADO",
	Estado.AVISO: "AVISO", Estado.TRANSICAO: "TRANSICAO",
	Estado.APRESENTACAO: "APRESENTACAO", Estado.INTERACAO: "INTERACAO",
	Estado.RODA_DISPOSITIVO: "RODA_DISPOSITIVO", Estado.RODA_ISCA: "RODA_ISCA",
	Estado.LANCANDO: "LANCANDO", Estado.SUCESSO: "SUCESSO",
	Estado.FALHA: "FALHA", Estado.ATACANDO: "ATACANDO",
	Estado.TROCA_OBRIGATORIA: "TROCA_OBRIGATORIA",
	Estado.ENCERRANDO: "ENCERRANDO",
}

signal mudou(anterior: Estado, atual: Estado)

var atual: Estado = Estado.INATIVO


func e(estado: Estado) -> bool:
	return atual == estado


## Verdadeiro enquanto o encontro tem o controle — o mundo fica congelado e a
## deteccao nao roda.
func em_encontro() -> bool:
	return atual != Estado.INATIVO


## Verdadeiro so nos estados que aceitam entrada do jogador. Tudo que anima
## (transicao, lancamento, desfecho) e intocavel de proposito: e o que impede
## dois lances simultaneos com um segundo confirmar apressado.
func aceita_entrada() -> bool:
	return atual in [Estado.INTERACAO, Estado.RODA_DISPOSITIVO, Estado.RODA_ISCA,
			Estado.TROCA_OBRIGATORIA]


func pode_ir_para(novo: Estado) -> bool:
	return novo in TRANSICOES.get(atual, [])


## Aplica a transicao. Devolve false (sem mudar nada) se ela nao existe na tabela.
func mudar_para(novo: Estado) -> bool:
	if novo == atual:
		return true
	if not pode_ir_para(novo):
		push_error("EstadoEncontro: transicao invalida %s -> %s"
				% [NOMES[atual], NOMES[novo]])
		return false
	var anterior := atual
	atual = novo
	mudou.emit(anterior, atual)
	return true


## Volta ao repouso de qualquer estado. Existe para a limpeza: um encontro
## interrompido (troca de cena, erro) precisa de saida que a tabela nao oferece.
func reiniciar() -> void:
	var anterior := atual
	atual = Estado.INATIVO
	if anterior != Estado.INATIVO:
		mudou.emit(anterior, atual)


static func nome(estado: Estado) -> String:
	return NOMES.get(estado, "?")
