class_name SessaoDialogo
extends RefCounted

## Percurso de UMA conversa: onde estamos na arvore, qual fala esta na tela e o
## que acontece quando o jogador confirma ou escolhe.
##
## Nao conhece Control, Node nem entrada — e por isso que o fluxo inteiro de um
## dialogo (inclusive ramificacao e efeitos) pode ser verificado em teste
## headless, do mesmo jeito que CalculoCaptura verifica a captura sem abrir cena.
##
## CICLO que a apresentacao segue:
##
##     s.iniciar()                 # ou s.iniciar("no") para abrir num no especifico
##     while not s.terminou():
##         if s.esperando_escolha(): s.escolher(i)
##         else:                     mostrar(s.fala_atual()); s.avancar()
##
## EFEITOS aplicados ao ENTRAR num no (e ao escolher uma opcao, antes de saltar):
##   {"definir": {"bandeira": valor}}   grava no EstadoMundo
##   {"somar":   {"bandeira": 1}}       incrementa
##   {"visitar": "ribeira"}             marca regiao conhecida
##   {"servico": {"tipo": "loja", ...}} enfileira um pedido para a cena atender
##
## `servico` e o gancho de loja/missao/pesca/tutorial: a sessao NAO sabe o que e
## uma loja, so registra que o dialogo pediu uma. Quem atende e a cena, lendo
## `servicos`. O tutorial de pesca ({"tipo": "tutorial"}) entrou exatamente por
## aqui, sem mudar uma linha desta classe; o que ainda nao existe (loja) vira uma
## mensagem — e o dialogo ja esta escrito do jeito definitivo.

const EFEITOS := ["definir", "somar", "visitar", "servico"]

## Teto de saltos automaticos (`seguinte`) numa mesma confirmacao. Uma arvore com
## ciclo de nos sem fala travaria o jogo com o jogador congelado; aqui ela para e
## reclama.
const MAXIMO_DE_SALTOS := 64

var arvore: ArvoreDialogo
var estado: EstadoMundo
var npc_id: String = ""

var no: NoDialogo
var servicos: Array[Dictionary] = []

var _falas: Array[Dictionary] = []
var _i: int = 0
var _terminou: bool = false


func _init(arvore_da_conversa: ArvoreDialogo, estado_do_mundo: EstadoMundo,
		id_do_npc: String = "") -> void:
	arvore = arvore_da_conversa
	estado = estado_do_mundo
	npc_id = id_do_npc


## Abre a conversa. Sem `no_inicial`, quem decide e a arvore
## (ArvoreDialogo.inicio_para: inicios condicionais, depois `inicio`). Com ele, a
## conversa comeca exatamente ali — e o caminho do tutorial, que abre a arvore
## dele no passo em que esta. O no pedido passa pelo mesmo _entrar(): efeitos,
## variante e marcacao de visto valem igual a um no alcancado por escolha.
func iniciar(no_inicial: String = "") -> void:
	_terminou = false
	servicos.clear()
	if arvore == null:
		_terminou = true
		return
	_entrar(no_inicial if no_inicial != "" else arvore.inicio_para(estado))


func terminou() -> bool:
	return _terminou


func tem_fala() -> bool:
	return not _terminou and _i < _falas.size()


func fala_atual() -> Dictionary:
	return _falas[_i] if tem_fala() else {}


## Quantas falas ainda vem depois desta. A caixa usa para decidir entre o
## indicador de "continua" e o de "fim".
func falas_restantes() -> int:
	return maxi(0, _falas.size() - _i - 1)


func esperando_escolha() -> bool:
	return not _terminou and not tem_fala() and not escolhas().is_empty()


func escolhas() -> Array[Dictionary]:
	if no == null:
		return []
	return no.escolhas_para(estado)


## Consome a fala corrente. Quando a ultima acaba, resolve o fim do no.
func avancar() -> void:
	if _terminou:
		return
	if _i < _falas.size():
		_i += 1
	if _i < _falas.size():
		return
	if not escolhas().is_empty():
		return                      # espera a escolha do jogador
	if no != null and no.seguinte != "":
		_entrar(no.seguinte)
		return
	_terminou = true


func escolher(indice: int) -> void:
	var visiveis := escolhas()
	if _terminou or indice < 0 or indice >= visiveis.size():
		return
	var escolha: Dictionary = visiveis[indice]
	_aplicar(escolha.get("efeitos", {}))
	_entrar(String(escolha["destino"]))


# ----------------------------------------------------------------- internos
func _entrar(id_do_no: String) -> void:
	var saltos := 0
	while true:
		saltos += 1
		if saltos > MAXIMO_DE_SALTOS:
			push_error("SessaoDialogo: ciclo de nos sem fala em '%s' (a partir de '%s')"
					% [arvore.id, id_do_no])
			_terminou = true
			return
		if id_do_no == ArvoreDialogo.DESTINO_FIM or not arvore.nos.has(id_do_no):
			if id_do_no != ArvoreDialogo.DESTINO_FIM:
				push_error("SessaoDialogo: no '%s' nao existe em '%s'"
						% [id_do_no, arvore.id])
			no = null
			_falas = []
			_i = 0
			_terminou = true
			return

		no = arvore.nos[id_do_no]
		_aplicar(no.efeitos)
		# A VARIANTE E RESOLVIDA ANTES DE MARCAR O NO COMO VISTO — e nao depois.
		# A ordem inversa e silenciosa e destroi exatamente o caso que as
		# variantes existem para atender: {"falou_com": "anselmo"} ja seria
		# verdadeiro na PRIMEIRA fala do Anselmo, e a saudacao de reencontro
		# apareceria na apresentacao. Aqui, uma condicao dentro do no le o estado
		# como ele estava ANTES desta visita.
		_falas = no.falas_para(estado)
		if estado != null:
			estado.marcar_visto(npc_id, id_do_no)
		_i = 0
		if not _falas.is_empty() or not escolhas().is_empty():
			return
		# No sem fala e sem escolha: e um desvio puro.
		if no.seguinte == "":
			_terminou = true
			return
		id_do_no = no.seguinte


func _aplicar(efeitos: Variant) -> void:
	if not efeitos is Dictionary or estado == null:
		return
	var d: Dictionary = efeitos
	for nome: String in (d.get("definir", {}) as Dictionary).keys():
		estado.definir(nome, d["definir"][nome])
	for nome: String in (d.get("somar", {}) as Dictionary).keys():
		estado.somar(nome, float(d["somar"][nome]))
	if d.has("visitar"):
		estado.visitar(String(d["visitar"]))
	if d.has("servico"):
		var pedido: Dictionary = (d["servico"] as Dictionary).duplicate(true)
		pedido["npc"] = npc_id
		servicos.append(pedido)
