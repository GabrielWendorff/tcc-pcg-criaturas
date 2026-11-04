class_name ArvoreDialogo
extends RefCounted

## Uma arvore de dialogo carregada de autoral/dialogos/<id>.json.
##
## ARVORE, e nao lista encadeada: cada no nomeia seus destinos, e um destino pode
## ser qualquer no — inclusive um ja visitado, o que fecha o ciclo tipico de
## "menu de assuntos" sem nenhuma estrutura extra. E o que o item 6 do escopo
## pede e o que uma cadeia de if/else nao da.
##
## O ARQUIVO:
##   {"id": "anselmo", "inicio": "raiz", "nome": "Anselmo",
##    "nos": { "raiz": {...}, "rio": {...} }}
##
## `id` e o nome do arquivo sem extensao — quem manda e o arquivo, e o campo so
## precisa concordar (validar() cobra).
##
## O destino reservado "fim" encerra a conversa sem precisar de um no vazio.
##
## INICIOS CONDICIONAIS — por onde a conversa abre depende do mundo:
##   "inicios": [{"se": {"nao": {"bandeira": "tutorial_pesca_concluido"}}, "no": "licao"}]
## A PRIMEIRA regra cuja condicao passa substitui `inicio`; nenhuma passando,
## vale `inicio`. E o caso "na primeira vez ele te chama para a licao; depois,
## conversa normal" sem um no-desvio vazio na raiz e sem codigo no NPC. Uma
## variante nao serviria: ela troca as FALAS de um no, nao o caminho inteiro.
##
## ENTRADAS — nos abertos POR FORA da arvore:
##   "entradas": ["apresentacao", "ensina_roda", ...]
## O tutorial abre a conversa direto num no (GerenciadorDialogo.conversar_com
## com `no_inicial`), e nenhum outro no aponta para ele. Declarar a entrada e o
## que impede validar() de chamar esses nos de orfaos — e, no sentido inverso, o
## que faz um no orfao DE VERDADE continuar sendo apontado.

const DESTINO_FIM := "fim"

## Chaves aceitas numa regra de `inicios`. Chave escrita errada ("sse") faria a
## regra valer sempre, em silencio — mesma razao de CondicaoDialogo.validar.
const CHAVES_INICIO := ["se", "no"]

var id: String = ""
var nome: String = ""              ## nome exibido, quando o NPC nao traz o seu
var inicio: String = "raiz"
var nos: Dictionary = {}           ## id -> NoDialogo
var caminho: String = ""

## [{"se": condicao, "no": id}] — a primeira verdadeira substitui `inicio`.
var inicios: Array[Dictionary] = []

## Nos de entrada EXTERNA (tutorial). Contam como raiz no teste de alcance.
var entradas: PackedStringArray = []

## Problemas de FORMA achados na carga (regra que nao e objeto, entrada que nao
## e texto). Guardados para validar() reportar junto com o resto, em vez de a
## carga falhar e esconder todos os outros erros da arvore. Sem o id: quando a
## carga roda, o id ainda pode vir do nome do arquivo (ver carregar()).
var _erros_de_carga: PackedStringArray = []


static func carregar(caminho_json: String) -> ArvoreDialogo:
	if not FileAccess.file_exists(caminho_json):
		push_error("ArvoreDialogo: arquivo inexistente — " + caminho_json)
		return null
	var dados: Variant = JSON.parse_string(FileAccess.get_file_as_string(caminho_json))
	if not dados is Dictionary:
		push_error("ArvoreDialogo: JSON invalido — " + caminho_json)
		return null
	var arvore := de_dicionario(dados)
	arvore.caminho = caminho_json
	if arvore.id == "":
		arvore.id = caminho_json.get_file().get_basename()
	return arvore


static func de_dicionario(dados: Dictionary) -> ArvoreDialogo:
	var arvore := ArvoreDialogo.new()
	arvore.id = String(dados.get("id", ""))
	arvore.nome = String(dados.get("nome", ""))
	arvore.inicio = String(dados.get("inicio", "raiz"))
	for id_do_no: String in (dados.get("nos", {}) as Dictionary).keys():
		arvore.nos[id_do_no] = NoDialogo.de_dicionario(
				id_do_no, dados["nos"][id_do_no])

	var lista_inicios: Variant = dados.get("inicios", [])
	if lista_inicios is Array:
		for i in (lista_inicios as Array).size():
			var regra: Variant = lista_inicios[i]
			if regra is Dictionary:
				arvore.inicios.append((regra as Dictionary).duplicate(true))
			else:
				arvore._erros_de_carga.append("inicios[%d] deve ser objeto {se, no}" % i)
	else:
		arvore._erros_de_carga.append("inicios deve ser lista")

	var lista_entradas: Variant = dados.get("entradas", [])
	if lista_entradas is Array:
		for item: Variant in lista_entradas:
			if item is String:
				arvore.entradas.append(String(item))
			else:
				arvore._erros_de_carga.append("entrada %s deve ser o id de um no" % str(item))
	else:
		arvore._erros_de_carga.append("entradas deve ser lista")
	return arvore


func no(id_do_no: String) -> NoDialogo:
	return nos.get(id_do_no)


func tem(id_do_no: String) -> bool:
	return id_do_no == DESTINO_FIM or nos.has(id_do_no)


## No por onde uma conversa comeca AGORA: a primeira regra de `inicios` cuja
## condicao passa, ou `inicio`.
##
## Sem estado, vale `inicio`. CondicaoDialogo trata estado nulo como "tudo
## verdadeiro" (e o que deixa a ferramenta ver todas as escolhas), mas aqui isso
## escolheria sempre a primeira regra — a conversa de primeira vez para quem nao
## tem historia nenhuma registrada. O inicio declarado e a leitura neutra.
func inicio_para(estado: EstadoMundo) -> String:
	if estado == null:
		return inicio
	for regra: Dictionary in inicios:
		if CondicaoDialogo.avaliar(regra.get("se"), estado):
			var destino := String(regra.get("no", ""))
			if destino != "":
				return destino
	return inicio


## Erros estruturais. Roda na ferramenta e no teste headless — nunca no meio de
## uma conversa: um destino escrito errado abriria a caixa e travaria o jogador
## num no que nao existe, com o controle congelado.
func validar() -> PackedStringArray:
	var erros := PackedStringArray()
	if nos.is_empty():
		erros.append("%s: arvore sem nos" % id)
		return erros
	if not nos.has(inicio):
		erros.append("%s: no inicial '%s' nao existe" % [id, inicio])
	for problema: String in _erros_de_carga:
		erros.append("%s: %s" % [id, problema])
	erros.append_array(_validar_inicios())
	for entrada: String in entradas:
		if not nos.has(entrada):
			erros.append("%s: entrada '%s' nao existe" % [id, entrada])

	for id_do_no: String in nos.keys():
		var n: NoDialogo = nos[id_do_no]
		var onde := "%s/%s" % [id, id_do_no]
		if n.falas.is_empty() and n.variantes.is_empty() and n.escolhas.is_empty():
			erros.append("%s: no sem fala e sem escolha" % onde)
		for f: Dictionary in n.falas:
			if String(f["texto"]).strip_edges() == "":
				erros.append("%s: fala vazia" % onde)
		if n.seguinte != "" and not tem(n.seguinte):
			erros.append("%s: seguinte '%s' nao existe" % [onde, n.seguinte])
		for i in n.escolhas.size():
			var e: Dictionary = n.escolhas[i]
			if String(e["texto"]).strip_edges() == "":
				erros.append("%s: escolha %d sem texto" % [onde, i])
			if String(e["destino"]) == "":
				erros.append("%s: escolha '%s' sem destino" % [onde, e["texto"]])
			elif not tem(String(e["destino"])):
				erros.append("%s: escolha '%s' aponta para '%s', que nao existe"
						% [onde, e["texto"], e["destino"]])
			erros.append_array(CondicaoDialogo.validar(e.get("se"),
					"%s/escolha[%d].se" % [onde, i]))
			erros.append_array(_validar_efeitos(e.get("efeitos", {}),
					"%s/escolha[%d].efeitos" % [onde, i]))
		for i in n.variantes.size():
			erros.append_array(CondicaoDialogo.validar(n.variantes[i].get("se"),
					"%s/variante[%d].se" % [onde, i]))
			if (n.variantes[i]["falas"] as Array).is_empty():
				erros.append("%s: variante %d sem falas" % [onde, i])
		erros.append_array(_validar_efeitos(n.efeitos, onde + "/efeitos"))

	# No inalcancavel e quase sempre um destino escrito errado em outro lugar —
	# o no ficou orfao e o texto nunca aparece. Nao e erro fatal, mas nao pode
	# passar em silencio.
	for id_do_no: String in nos.keys():
		if id_do_no != inicio and not _alcancado(id_do_no):
			erros.append("%s/%s: no inalcancavel a partir de '%s'"
					% [id, id_do_no, inicio])
	return erros


## Um no e "alcancado" quando alguma coisa o abre: outro no (seguinte ou
## escolha), uma regra de `inicios` ou uma entrada externa. Nao e busca em grafo
## a partir da raiz — e de proposito: o que este teste caca e o no que NINGUEM
## nomeia, que e o sintoma de um destino escrito errado.
func _alcancado(alvo: String) -> bool:
	if alvo in entradas:
		return true
	for regra: Dictionary in inicios:
		if String(regra.get("no", "")) == alvo:
			return true
	for id_do_no: String in nos.keys():
		var n: NoDialogo = nos[id_do_no]
		if n.seguinte == alvo:
			return true
		for e: Dictionary in n.escolhas:
			if String(e["destino"]) == alvo:
				return true
	return false


func _validar_inicios() -> PackedStringArray:
	var erros := PackedStringArray()
	for i in inicios.size():
		var regra: Dictionary = inicios[i]
		var onde := "%s/inicios[%d]" % [id, i]
		for chave: String in regra.keys():
			if not chave in CHAVES_INICIO:
				erros.append("%s: chave desconhecida '%s' (esperado %s)"
						% [onde, chave, ", ".join(CHAVES_INICIO)])
		var destino := String(regra.get("no", ""))
		if destino == "":
			erros.append("%s: regra sem 'no'" % onde)
		elif not nos.has(destino):
			erros.append("%s: no '%s' nao existe" % [onde, destino])
		# Regra sem condicao vence sempre: `inicio` e as regras seguintes viram
		# texto morto. Quem quer um inicio fixo escreve `inicio`.
		if regra.get("se") == null:
			erros.append("%s: regra sem condicao 'se' — use 'inicio'" % onde)
		else:
			erros.append_array(CondicaoDialogo.validar(regra.get("se"), onde + ".se"))
	return erros


static func _validar_efeitos(efeitos: Variant, onde: String) -> PackedStringArray:
	var erros := PackedStringArray()
	if efeitos == null or (efeitos is Dictionary and (efeitos as Dictionary).is_empty()):
		return erros
	if not efeitos is Dictionary:
		erros.append("%s: efeitos deve ser objeto" % onde)
		return erros
	for chave: String in (efeitos as Dictionary).keys():
		if not chave in SessaoDialogo.EFEITOS:
			erros.append("%s: efeito desconhecido '%s' (esperado %s)"
					% [onde, chave, ", ".join(SessaoDialogo.EFEITOS)])
	for chave: String in ["definir", "somar"]:
		if efeitos.has(chave) and not efeitos[chave] is Dictionary:
			erros.append("%s.%s deve ser objeto {bandeira: valor}" % [onde, chave])
	return erros
