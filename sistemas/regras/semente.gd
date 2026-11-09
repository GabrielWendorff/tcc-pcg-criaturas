class_name Semente
extends RefCounted

## Conversao de texto em seed de mundo (RF01) e sorteio de seed nova.
##
## Classe pura, sem engine e sem estado, em `regras/` pelo mesmo motivo que
## AfinidadeCriatura e CalculoCaptura estao la: e regra, nao apresentacao, e um
## teste headless tem de poder verifica-la sem abrir cena.
##
## POR QUE NAO String.hash()
## -------------------------
## Porque o hash da engine nao e contrato: pode mudar entre versoes do Godot, e a
## mesma palavra passaria a abrir OUTRO mundo depois de uma atualizacao. O
## trabalho inteiro promete que a seed reproduz o bestiario (RF03), e um save
## guarda a seed — uma promessa dessas nao pode depender do detalhe de
## implementacao de terceiros. Por isso a funcao esta escrita aqui, e por isso
## tools/test_save.gd fixa um valor esperado: mudar esta funcao e trocar o mundo
## de todos os saves ja gravados, e o teste tem de quebrar quando isso acontecer.
##
## POR QUE FNV-1a DE 32 BITS, E NAO DE 64
## --------------------------------------
## Para que a multiplicacao NAO POSSA estourar. Com o acumulador mascarado em 32
## bits e o primo abaixo de 2^25, o produto fica sempre abaixo de 2^57 e cabe
## folgado no int de 64 bits do GDScript. A versao de 64 bits dependeria de o
## estouro dar a volta em complemento de dois — comportamento que na pratica
## acontece, mas que ninguem garante por escrito. Num sistema cuja unica funcao e
## ser identico para sempre, "na pratica acontece" nao serve.
##
## 2^32 mundos distintos e muito mais do que o trabalho precisa: a seed padrao do
## projeto (123456789) tem 27 bits.

## Base e primo da FNV-1a de 32 bits.
const OFFSET_FNV := 2166136261
const PRIMO_FNV := 16777619
const MASCARA_32 := 0xFFFFFFFF


## Seed a partir do que o jogador digitou.
##
## Texto puramente numerico vale POR SI, sem passar pelo hash: digitar
## "123456789" tem de abrir o MESMO mundo da constante usada pelo visualizador do
## bestiario e pelos testes headless, senao a tela de nova partida nao serve para
## conferir nada do que o trabalho afirma.
##
## Devolve 0 para texto vazio — o sentinela de "nao ha partida" que
## DadosPartida._validar() recusa.
static func de_texto(texto: String) -> int:
	var limpo := texto.strip_edges()
	if limpo == "":
		return 0
	if limpo.is_valid_int():
		return absi(limpo.to_int())
	var h: int = OFFSET_FNV
	# Percorre os BYTES do UTF-8, nao os caracteres: assim "ribeira" e "ribeirã"
	# sao entradas de tamanhos diferentes e o acento participa do hash, em vez de
	# depender de como a engine indexa a String.
	for byte in limpo.to_utf8_buffer():
		h = (h ^ byte) & MASCARA_32
		h = (h * PRIMO_FNV) & MASCARA_32
	# Seed 0 e o sentinela de "sem partida": na chance remota de o hash cair nele,
	# desloca em 1 em vez de devolver um mundo que o validador recusaria.
	return h if h != 0 else 1


static var _sorteador: RandomNumberGenerator


## Seed nova, para o botao "sortear".
##
## E o UNICO sorteio do projeto que nao e reproduzivel, e tem de ser: o produto
## dele E a semente de que todo o resto depende. Ainda assim sai de um
## RandomNumberGenerator proprio, e nao de randi() global, para nao mexer no
## estado aleatorio que qualquer outro sistema possa estar usando.
static func aleatoria() -> int:
	# Um RNG so, semeado uma vez: randomize() usa o relogio, e dois RNGs criados no mesmo
	# instante sairiam iguais. O sorteio de seed e a unica entrada nao reprodutivel do jogo.
	if _sorteador == null:
		_sorteador = RandomNumberGenerator.new()
		_sorteador.randomize()
	return _sorteador.randi_range(1, 999_999_999)
