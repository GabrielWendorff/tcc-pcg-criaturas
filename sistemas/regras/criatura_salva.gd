class_name CriaturaSalva
extends RefCounted

## Uma criatura do jogador, como ela vai para o disco.
##
## O SAVE NAO GUARDA A CRIATURA. Guarda o indice dela no bestiario e a seed do
## mundo que a produziu — e nada mais. Elemento, animal base, porte, body_id,
## paleta, matiz, morfologia e variantes sao RECALCULADOS na carga, rodando o
## mesmo GeradorCriaturas com a mesma world_seed.
##
## Isso e RF03 (reprodutibilidade total pela seed) virando formato de arquivo. Tem
## tres consequencias praticas, e as tres sao o motivo de a classe existir:
##
##   1. TAMANHO. Um time e um deposito com dezenas de criaturas caberiam em
##      dezenas de KB de JSON com todos os atributos repetidos; aqui cada uma
##      custa seis numeros curtos.
##   2. COERENCIA IMPOSSIVEL DE QUEBRAR. Nenhum campo do save pode entrar em
##      contradicao com o gerador, porque nenhum atributo gerado esta no save. Se
##      uma tabela condicional for recalibrada, a criatura guardada muda junto —
##      ela nunca vira um fossil de uma versao antiga das tabelas.
##   3. VALIDACAO DE GRACA. Um save cuja `world_seed` nao bate com a do mundo
##      carregado e detectado na hora, e nao tres telas depois.
##
## O que ESTA aqui e so o que a seed NAO pode reproduzir: o que aconteceu com
## aquela criatura depois de capturada.
##
## O HP e a vida atual da batalha. NIVEL e EXPERIENCIA nao tem sistema, por decisao
## (presentation/batalha/README.md): a forca vem de qual criatura se tem. Os campos
## ficam para nao mudar o significado de um save ja gravado.

## HP ainda nao atribuido: a criatura entra em campo com a vida cheia. Um
## sentinela e melhor que 0 porque 0 e um valor legitimo (criatura desmaiada).
const HP_CHEIO := -1

var id: int = 0                 ## indice no bestiario da world_seed
var world_seed: int = 0
var nivel: int = 1
var experiencia: int = 0
var hp_atual: int = HP_CHEIO
var apelido: String = ""        ## "" = usa Criatura.nome()


static func de_criatura(c: Criatura, nivel_: int = 1) -> CriaturaSalva:
	var s := CriaturaSalva.new()
	s.id = c.id
	s.world_seed = c.world_seed
	s.nivel = nivel_
	return s


static func de_dicionario(d: Dictionary) -> CriaturaSalva:
	var s := CriaturaSalva.new()
	s.id = int(d.get("id", 0))
	s.world_seed = int(d.get("seed", 0))
	s.nivel = maxi(1, int(d.get("nivel", 1)))
	s.experiencia = maxi(0, int(d.get("xp", 0)))
	s.hp_atual = int(d.get("hp", HP_CHEIO))
	s.apelido = String(d.get("apelido", ""))
	return s


## Chaves curtas de proposito: um deposito cheio multiplica cada nome de campo
## por dezenas de linhas, e o arquivo deixa de caber numa tela de inspecao.
func para_dicionario() -> Dictionary:
	return {
		"id": id,
		"seed": world_seed,
		"nivel": nivel,
		"xp": experiencia,
		"hp": hp_atual,
		"apelido": apelido,
	}


## Devolve a Criatura correspondente dentro de um bestiario ja gerado, ou null.
##
## Confere a seed antes do indice: um bestiario de outro mundo tem um indice 42
## valido tambem, e devolve-lo silenciosamente trocaria a criatura do jogador por
## outra sem nenhum sintoma visivel ate a ficha ser aberta.
func resolver(bestiario: Array) -> Criatura:
	if id < 0 or id >= bestiario.size():
		return null
	var c: Criatura = bestiario[id]
	if c.world_seed != world_seed:
		return null
	return c


func nome_exibido(bestiario: Array) -> String:
	if apelido != "":
		return apelido
	var c := resolver(bestiario)
	return c.nome() if c != null else "???"
