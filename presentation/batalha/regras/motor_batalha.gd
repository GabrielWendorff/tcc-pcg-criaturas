class_name MotorBatalha
extends RefCounted

## Regra da batalha 1x1 por turnos. Nao anima nada e nao conhece no nenhum: recebe uma
## acao, muda o estado e devolve a lista de EVENTOS do turno, em ordem. Quem desenha
## percorre a lista; o simulador e o teste a ignoram. Por isso uma batalha inteira
## roda sem cena, e milhares delas calibram o balanceamento em segundos.
##
## Acoes do jogador (resolver_turno):
##   {"tipo": "golpe",  "golpe": Golpe}
##   {"tipo": "trocar", "indice": int}
##   {"tipo": "item",   "efeito": {...}, "alvo": int, "nome": String}
##   {"tipo": "passar"}    captura falha ou isca: o turno foi gasto fora do motor
##   {"tipo": "fugir"}
##
## Eventos: dicionarios com "tipo" e "texto". O texto vai pronto para a tela.
##
## DETERMINISMO (RF03): todo sorteio sai do RNG recebido. Mesma seed e mesmas acoes
## dao a mesma batalha, golpe a golpe.

const JOGADOR := "jogador"
const INIMIGO := "inimigo"

const SEM_DESFECHO := ""
const VITORIA := "vitoria"
const DERROTA := "derrota"
const FUGIU := "fugiu"

var tabelas: TabelasBatalha
var rng: RandomNumberGenerator
var lado_jogador: Array = []
var lado_inimigo: Array = []
var ativo_jogador: int = 0
var ativo_inimigo: int = 0
var tipo_inimigo: String = "selvagem"
var desfecho: String = SEM_DESFECHO
var turno: int = 0


func _init(tabelas_: TabelasBatalha, rng_: RandomNumberGenerator, jogador: Array,
		inimigo: Array, tipo_inimigo_: String = "selvagem") -> void:
	tabelas = tabelas_
	rng = rng_
	lado_jogador = jogador
	lado_inimigo = inimigo
	tipo_inimigo = tipo_inimigo_
	ativo_jogador = _primeiro_vivo(lado_jogador)
	ativo_inimigo = _primeiro_vivo(lado_inimigo)
	for c: Combatente in lado_jogador + lado_inimigo:
		c.limpar_reforcos()
	if ativo_jogador < 0:
		ativo_jogador = 0
		desfecho = DERROTA
	elif ativo_inimigo < 0:
		ativo_inimigo = 0
		desfecho = VITORIA


func jogador() -> Combatente:
	return lado_jogador[ativo_jogador]


func inimigo() -> Combatente:
	return lado_inimigo[ativo_inimigo]


func terminou() -> bool:
	return desfecho != SEM_DESFECHO


## A criatura do jogador caiu e ha outra viva: nada acontece ate ele escolher.
func precisa_trocar() -> bool:
	return not terminou() and not jogador().viva()


## Indices do lado do jogador para os quais da para trocar agora.
func trocas_possiveis() -> Array[int]:
	var saida: Array[int] = []
	for i in lado_jogador.size():
		if i != ativo_jogador and (lado_jogador[i] as Combatente).viva():
			saida.append(i)
	return saida


## Fim da batalha: reforcos nao atravessam para a exploracao.
func encerrar() -> void:
	for c: Combatente in lado_jogador + lado_inimigo:
		c.limpar_reforcos()


# ---------------------------------------------------------------------- turno

func resolver_turno(acao: Dictionary) -> Array:
	var eventos: Array = []
	if terminou() or precisa_trocar():
		return eventos
	turno += 1
	# Sorteado antes de agir: a escolha do adversario nao ve o que o jogador fez.
	var golpe_inimigo := IaBatalha.escolher(rng, inimigo(), jogador(), tabelas,
			tabelas.lado(tipo_inimigo))

	if String(acao.get("tipo", "")) == "golpe":
		_turno_de_golpes(acao.get("golpe") as Golpe, golpe_inimigo, eventos)
		return eventos

	if not _acao_sem_golpe(acao, eventos):
		return eventos
	_usar_golpe(INIMIGO, golpe_inimigo, eventos)
	return eventos


## Troca depois que a criatura caiu: nao gasta turno e o adversario nao age.
func trocar_forcada(indice: int) -> Array:
	var eventos: Array = []
	if not precisa_trocar() or not indice in trocas_possiveis():
		return eventos
	ativo_jogador = indice
	eventos.append({"tipo": "entrou", "lado": JOGADOR, "indice": indice,
			"texto": "%s entra em campo." % jogador().nome()})
	return eventos


func _turno_de_golpes(meu: Golpe, dele: Golpe, eventos: Array) -> void:
	var primeiro: String = _quem_age_primeiro(meu, dele)
	var segundo: String = INIMIGO if primeiro == JOGADOR else JOGADOR
	if not _usar_golpe(primeiro, meu if primeiro == JOGADOR else dele, eventos):
		return
	_usar_golpe(segundo, meu if segundo == JOGADOR else dele, eventos)


## Prioridade do golpe, depois velocidade. Empate e sorteado, sempre consumindo o
## sorteio para a sequencia do RNG nao depender dos stats.
func _quem_age_primeiro(meu: Golpe, dele: Golpe) -> String:
	var desempate: float = rng.randf()
	var pm: int = meu.prioridade if meu != null else 0
	var pd: int = dele.prioridade if dele != null else 0
	if pm != pd:
		return JOGADOR if pm > pd else INIMIGO
	var vm: float = jogador().ficha.velocidade
	var vd: float = inimigo().ficha.velocidade
	if not is_equal_approx(vm, vd):
		return JOGADOR if vm > vd else INIMIGO
	return JOGADOR if desempate < 0.5 else INIMIGO


## Devolve false quando o turno acaba aqui, sem revide do adversario.
func _acao_sem_golpe(acao: Dictionary, eventos: Array) -> bool:
	match String(acao.get("tipo", "")):
		"trocar":
			var i: int = int(acao.get("indice", -1))
			if not i in trocas_possiveis():
				turno -= 1
				return false
			jogador().limpar_reforcos()
			ativo_jogador = i
			eventos.append({"tipo": "entrou", "lado": JOGADOR, "indice": i,
					"texto": "%s entra em campo." % jogador().nome()})
		"item":
			var alvo: Combatente = lado_jogador[clampi(int(acao.get("alvo", ativo_jogador)),
					0, lado_jogador.size() - 1)]
			var ganho: int = CalculoBatalha.aplicar_efeito(acao.get("efeito", {}), alvo)
			eventos.append({"tipo": "item", "lado": JOGADOR, "ganho": ganho,
					"texto": "%s em %s: +%d de vida."
					% [String(acao.get("nome", "Item")), alvo.nome(), ganho]})
		"fugir":
			var p: float = CalculoBatalha.chance_de_fuga(jogador(), inimigo(), tabelas)
			if rng.randf() < p:
				desfecho = FUGIU
				eventos.append({"tipo": "fuga", "sucesso": true, "texto": "Conseguiu fugir."})
				return false
			eventos.append({"tipo": "fuga", "sucesso": false, "texto": "Não conseguiu fugir!"})
		"passar":
			pass
	return true


## Executa o golpe de um lado. Devolve false quando alguem caiu: o turno termina ali.
func _usar_golpe(lado: String, g: Golpe, eventos: Array) -> bool:
	if g == null:
		return true
	var atacante: Combatente = jogador() if lado == JOGADOR else inimigo()
	var defensor: Combatente = inimigo() if lado == JOGADOR else jogador()

	if not g.causa_dano():
		CalculoBatalha.aplicar_reforco(g, atacante)
		eventos.append({"tipo": "reforco", "lado": lado, "golpe": g.nome, "stat": g.stat,
				"texto": "%s usou %s." % [atacante.nome(), g.nome]})
		return true

	var mult_lado: float = float(tabelas.lado(
			JOGADOR if lado == JOGADOR else tipo_inimigo).get("mult_dano", 1.0))
	var r := CalculoBatalha.resolver_golpe(rng, g, atacante, defensor, tabelas, mult_lado)
	defensor.receber(int(r["dano"]))
	eventos.append({"tipo": "golpe", "lado": lado, "golpe": g.nome,
			"acertou": r["acertou"], "dano": r["dano"], "mult": r["mult"],
			"texto": _texto_do_golpe(atacante, g, r)})
	if defensor.viva():
		return true
	_ao_cair(INIMIGO if lado == JOGADOR else JOGADOR, eventos)
	return false


func _texto_do_golpe(atacante: Combatente, g: Golpe, r: Dictionary) -> String:
	if not r["acertou"]:
		return "%s usou %s e errou." % [atacante.nome(), g.nome]
	var nota := ""
	if float(r["mult"]) > 1.0:
		nota = " Muito eficaz!"
	elif float(r["mult"]) < 1.0:
		nota = " Pouco eficaz."
	return "%s usou %s: %d de dano.%s" % [atacante.nome(), g.nome, int(r["dano"]), nota]


func _ao_cair(lado: String, eventos: Array) -> void:
	var caida: Combatente = jogador() if lado == JOGADOR else inimigo()
	eventos.append({"tipo": "caiu", "lado": lado, "texto": "%s caiu." % caida.nome()})
	if lado == INIMIGO:
		var proximo := _primeiro_vivo(lado_inimigo)
		if proximo < 0:
			desfecho = VITORIA
			return
		ativo_inimigo = proximo
		eventos.append({"tipo": "entrou", "lado": INIMIGO, "indice": proximo,
				"texto": "%s entra em campo." % inimigo().nome()})
		return
	if _primeiro_vivo(lado_jogador) < 0:
		desfecho = DERROTA


static func _primeiro_vivo(lista: Array) -> int:
	for i in lista.size():
		if (lista[i] as Combatente).viva():
			return i
	return -1
