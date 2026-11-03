class_name SequenciaTutorial
extends RefCounted

## Um tutorial como SEQUENCIA DE PASSOS em dado (autoral/tutoriais/<id>.json) e
## o cursor que anda por ela.
##
## O pedido era "editar textos e ordem sem mexer no codigo". Por isso o passo e
## declarativo — o que dizer (conversa), o que mostrar (dica), o que esperar
## (evento) e o que muda no mundo (efeitos) — e esta classe so responde
## perguntas sobre ele: em que passo estou, este evento conclui o passo, para
## onde volto se falhar. Quem ABRE conversa, mostra dica e entrega item e o
## GerenciadorTutorial; aqui nao ha Node, entrada nem autoload. E o mesmo corte
## de SessaoDialogo/GerenciadorDialogo, e pelo mesmo motivo: o fluxo inteiro da
## licao e verificavel em teste headless (tools/test_tutorial.gd).
##
## O ARQUIVO (ver autoral/tutoriais/pesca.json):
##   {"id", "npc", "arvore", "bandeira_concluido",
##    "textos": {...},                       textos de interface (traduziveis)
##    "ao_pular": {"conversa", "efeitos"},
##    "passos": [{"id", "conversa", "ao_iniciar", "dica", "esperar",
##                "se_falhar", "ao_concluir"}, ...]}
##
## CICLO que o gerenciador segue:
##
##     s.iniciar()
##     enquanto s.ativa():
##         entrar no passo: efeitos ao_iniciar, conversa, dica
##         se o passo nao espera nada: concluir
##         senao, a cada evento: match s.reacao(evento, valor)
##             REACAO_CONCLUIR: efeitos ao_concluir; s.avancar()
##             REACAO_VOLTAR:   s.ir_para(s.destino_de_falha())

const DIRETORIO := "res://autoral/tutoriais/"

const EVENTOS := ["item_equipado", "pesca_iniciada", "arremessado", "silhueta_surgiu",
	"fisgado", "falhou"]
const EFEITOS := ["dar_itens", "definir", "desequipar", "concluir"]

## O evento que aciona `se_falhar`. Constante para o gerenciador e o teste nao
## repetirem a palavra solta.
const EVENTO_FALHA := "falhou"

## Conversa mostrada ao voltar por falha, NO LUGAR da conversa do passo de
## destino: quem cancelou o lance nao precisa ouvir a explicacao inteira do arco
## de novo, precisa de um "tente outra vez". Ausente na arvore, vale a conversa
## do proprio passo.
const CONVERSA_TENTAR_DE_NOVO := "tentar_de_novo"

## Respostas de reacao(). Vazio = o evento nao interessa a este passo.
const REACAO_CONCLUIR := "concluir"
const REACAO_VOLTAR := "voltar"

## Chaves aceitas num passo. Chave escrita errada ("esprar") faria o passo
## concluir na hora, em silencio — mesma razao de CondicaoDialogo.validar.
const CHAVES_PASSO := ["id", "conversa", "ao_iniciar", "dica", "esperar", "se_falhar",
	"ao_concluir"]
const CHAVES_ESPERAR := ["evento", "valor"]
const CHAVES_AO_PULAR := ["conversa", "efeitos"]

## Textos de interface que o gerenciador e a dica pedem por chave. Faltar um
## deles nao quebra nada (texto() devolve a propria chave), mas aparece na tela
## como "pular_sim" — e quem tem de pegar isso e o teste.
const TEXTOS_OBRIGATORIOS := ["titulo_dica", "aviso_pular", "pular_pergunta", "pular_sim",
	"pular_nao", "recebeu"]

var id: String = ""
var npc: String = ""
var arvore: String = ""
var bandeira_concluido: String = ""
var textos: Dictionary = {}
var ao_pular: Dictionary = {}
var passos: Array[Dictionary] = []

## Passo corrente. -1 = ainda nao comecou; passos.size() = concluida.
var indice: int = -1

## Problemas de FORMA achados na carga (bloco que nao e objeto, id que diverge
## do arquivo), num texto so; "" = carga limpa. Arquivo ausente ou JSON invalido
## nem chegam aqui: carregar() devolve null. Erros de conteudo vem de validar(),
## que repete estes e acrescenta o resto.
var erro: String = ""

var _erros_de_carga: PackedStringArray = []


# ------------------------------------------------------------------- carga
## Le autoral/tutoriais/<id>.json. Devolve null (e push_error) quando o arquivo
## nao existe ou nao e um objeto JSON — nada para executar. Conteudo errado
## carrega assim mesmo e e apontado por validar().
static func carregar(id_tutorial: String) -> SequenciaTutorial:
	var caminho := DIRETORIO + id_tutorial + ".json"
	if not FileAccess.file_exists(caminho):
		push_error("SequenciaTutorial: arquivo inexistente — " + caminho)
		return null
	var dados: Variant = JSON.parse_string(FileAccess.get_file_as_string(caminho))
	if not dados is Dictionary:
		push_error("SequenciaTutorial: JSON invalido — " + caminho)
		return null
	var seq := de_dicionario(dados)
	# Mesmo contrato de ArvoreDialogo: quem manda e o nome do arquivo.
	if seq.id == "":
		seq.id = id_tutorial
	elif seq.id != id_tutorial:
		seq._erros_de_carga.append("campo id='%s' diverge do arquivo '%s'"
				% [seq.id, caminho.get_file()])
		seq.erro = "; ".join(seq._erros_de_carga)
	return seq


static func de_dicionario(d: Dictionary) -> SequenciaTutorial:
	var seq := SequenciaTutorial.new()
	seq.id = String(d.get("id", ""))
	seq.npc = String(d.get("npc", ""))
	seq.arvore = String(d.get("arvore", ""))
	seq.bandeira_concluido = String(d.get("bandeira_concluido", ""))

	var t: Variant = d.get("textos", {})
	if t is Dictionary:
		seq.textos = (t as Dictionary).duplicate(true)
	else:
		seq._erros_de_carga.append("textos deve ser objeto")

	var p: Variant = d.get("ao_pular", {})
	if p is Dictionary:
		seq.ao_pular = (p as Dictionary).duplicate(true)
	else:
		seq._erros_de_carga.append("ao_pular deve ser objeto")

	var lista: Variant = d.get("passos", [])
	if lista is Array:
		for i in (lista as Array).size():
			var passo: Variant = lista[i]
			if passo is Dictionary:
				seq.passos.append((passo as Dictionary).duplicate(true))
			else:
				seq._erros_de_carga.append("passos[%d] deve ser objeto" % i)
	else:
		seq._erros_de_carga.append("passos deve ser lista")
	seq.erro = "; ".join(seq._erros_de_carga)
	return seq


# --------------------------------------------------------------- validacao
## Erros de conteudo. Roda no teste headless e antes de o gerenciador comecar —
## nunca no meio da licao: um passo que espera um evento que ninguem emite
## deixaria o jogador parado diante de uma dica que nunca sai da tela.
##
## Com `arvore_dialogo`, confere tambem as conversas: cada uma tem de existir e
## estar declarada em `entradas` (e assim que a arvore sabe que o no e aberto por
## fora, e nao um orfao).
func validar(arvore_dialogo: ArvoreDialogo = null) -> PackedStringArray:
	var erros := PackedStringArray()
	var onde := id if id != "" else "(tutorial sem id)"
	for problema: String in _erros_de_carga:
		erros.append("%s: %s" % [onde, problema])
	if id == "":
		erros.append("%s: sem id" % onde)
	if npc == "":
		erros.append("%s: sem npc" % onde)
	if arvore == "":
		erros.append("%s: sem arvore de dialogo" % onde)
	if bandeira_concluido == "":
		erros.append("%s: sem bandeira_concluido" % onde)
	if passos.is_empty():
		erros.append("%s: nenhum passo" % onde)

	for chave: String in TEXTOS_OBRIGATORIOS:
		if String(textos.get(chave, "")).strip_edges() == "":
			erros.append("%s: texto obrigatorio '%s' ausente" % [onde, chave])
	# "Recebeu: %s ×%d" e formatado com (nome, quantidade). Sem os dois marcadores
	# o operador % do GDScript erra em tempo de execucao — no meio da licao.
	var recebeu := String(textos.get("recebeu", ""))
	if recebeu != "" and (recebeu.count("%s") != 1 or recebeu.count("%d") != 1):
		erros.append("%s: texto 'recebeu' precisa de um %%s (nome) e um %%d (quantidade)"
				% onde)

	if arvore_dialogo != null and arvore != "" and arvore_dialogo.id != arvore:
		erros.append("%s: arvore entregue '%s' nao e a declarada '%s'"
				% [onde, arvore_dialogo.id, arvore])

	var ids := {}
	for i in passos.size():
		var passo: Dictionary = passos[i]
		var id_passo := String(passo.get("id", ""))
		var aqui: String = ("%s/passos[%d]" % [onde, i]) if id_passo == "" \
				else ("%s/%s" % [onde, id_passo])
		if id_passo == "":
			erros.append("%s: passo sem id" % aqui)
		elif ids.has(id_passo):
			erros.append("%s: id de passo repetido" % aqui)
		ids[id_passo] = true
		for chave: String in passo.keys():
			if not chave in CHAVES_PASSO:
				erros.append("%s: chave desconhecida '%s' (esperado %s)"
						% [aqui, chave, ", ".join(CHAVES_PASSO)])
		erros.append_array(_validar_conversa(passo.get("conversa", ""), arvore_dialogo,
				aqui + ".conversa"))
		erros.append_array(_validar_esperar(passo.get("esperar"), aqui + ".esperar"))
		erros.append_array(validar_efeitos(passo.get("ao_iniciar"), aqui + ".ao_iniciar"))
		erros.append_array(validar_efeitos(passo.get("ao_concluir"), aqui + ".ao_concluir"))

		var tem_espera := passo.get("esperar") != null
		if passo.has("dica") and not tem_espera:
			# A dica so aparece enquanto o passo espera; sem espera ela nunca sai.
			erros.append("%s: 'dica' sem 'esperar' nunca aparece" % aqui)
		if passo.has("dica") and String(passo["dica"]).strip_edges() == "":
			erros.append("%s: dica vazia" % aqui)
		if passo.has("se_falhar") and not tem_espera:
			erros.append("%s: 'se_falhar' sem 'esperar' nunca dispara" % aqui)
		if not tem_espera and String(passo.get("conversa", "")) == "" \
				and not passo.has("ao_iniciar") and not passo.has("ao_concluir"):
			erros.append("%s: passo vazio (sem conversa, espera nem efeito)" % aqui)

	# Destinos de falha depois de conhecer todos os ids: voltar para um passo
	# ADIANTE e legitimo, entao a checagem nao pode ser feita na mesma passada.
	for passo: Dictionary in passos:
		if passo.has("se_falhar"):
			var destino := String(passo["se_falhar"])
			if not ids.has(destino) or destino == "":
				erros.append("%s/%s: se_falhar aponta para '%s', que nao e um passo"
						% [onde, passo.get("id", "?"), destino])

	for chave: String in ao_pular.keys():
		if not chave in CHAVES_AO_PULAR:
			erros.append("%s/ao_pular: chave desconhecida '%s'" % [onde, chave])
	erros.append_array(_validar_conversa(ao_pular.get("conversa", ""), arvore_dialogo,
			onde + "/ao_pular.conversa"))
	erros.append_array(validar_efeitos(ao_pular.get("efeitos"), onde + "/ao_pular.efeitos"))
	if arvore_dialogo != null and not arvore_dialogo.nos.is_empty() \
			and arvore_dialogo.nos.has(CONVERSA_TENTAR_DE_NOVO) \
			and not CONVERSA_TENTAR_DE_NOVO in arvore_dialogo.entradas:
		erros.append("%s: '%s' existe na arvore mas nao esta em entradas"
				% [onde, CONVERSA_TENTAR_DE_NOVO])
	return erros


## Erros de forma de um bloco de efeitos. Estatico e publico porque o gerenciador
## e o teste conferem o mesmo formato em `ao_pular`, que nao e passo.
static func validar_efeitos(efeitos: Variant, onde: String) -> PackedStringArray:
	var erros := PackedStringArray()
	if efeitos == null:
		return erros
	if not efeitos is Dictionary:
		erros.append("%s: efeitos deve ser objeto" % onde)
		return erros
	var d: Dictionary = efeitos
	for chave: String in d.keys():
		if not chave in EFEITOS:
			erros.append("%s: efeito desconhecido '%s' (esperado %s)"
					% [onde, chave, ", ".join(EFEITOS)])
	if d.has("dar_itens"):
		if not d["dar_itens"] is Dictionary:
			erros.append("%s.dar_itens deve ser objeto {item: quantidade}" % onde)
		else:
			for item: String in (d["dar_itens"] as Dictionary).keys():
				var n: Variant = d["dar_itens"][item]
				if not (n is int or n is float) or int(n) < 1:
					erros.append("%s.dar_itens.%s: quantidade deve ser inteiro >= 1"
							% [onde, item])
	if d.has("definir") and not d["definir"] is Dictionary:
		erros.append("%s.definir deve ser objeto {bandeira: valor}" % onde)
	for chave: String in ["desequipar", "concluir"]:
		if d.has(chave) and not d[chave] is bool:
			erros.append("%s.%s deve ser true/false" % [onde, chave])
	return erros


static func _validar_esperar(esperar: Variant, onde: String) -> PackedStringArray:
	var erros := PackedStringArray()
	if esperar == null:
		return erros
	if not esperar is Dictionary:
		erros.append("%s: deve ser objeto {evento, valor}" % onde)
		return erros
	var d: Dictionary = esperar
	for chave: String in d.keys():
		if not chave in CHAVES_ESPERAR:
			erros.append("%s: chave desconhecida '%s'" % [onde, chave])
	var evento := String(d.get("evento", ""))
	if not evento in EVENTOS:
		erros.append("%s: evento desconhecido '%s' (esperado %s)"
				% [onde, evento, ", ".join(EVENTOS)])
	return erros


static func _validar_conversa(conversa: Variant, arvore_dialogo: ArvoreDialogo,
		onde: String) -> PackedStringArray:
	var erros := PackedStringArray()
	if conversa == null or String(conversa) == "":
		return erros
	if not conversa is String:
		erros.append("%s: deve ser o id de um no" % onde)
		return erros
	if arvore_dialogo == null:
		return erros
	if not arvore_dialogo.nos.has(String(conversa)):
		erros.append("%s: no '%s' nao existe em '%s'"
				% [onde, conversa, arvore_dialogo.id])
	elif not String(conversa) in arvore_dialogo.entradas:
		erros.append("%s: no '%s' nao esta em 'entradas' de '%s'"
				% [onde, conversa, arvore_dialogo.id])
	return erros


# ------------------------------------------------------------------ cursor
func iniciar() -> void:
	indice = 0


func ativa() -> bool:
	return indice >= 0 and indice < passos.size()


func concluida() -> bool:
	return indice >= 0 and indice >= passos.size()


## O passo corrente, ou {} fora da sequencia. Devolve o PROPRIO dicionario: quem
## le nao deve escrever nele.
func passo_atual() -> Dictionary:
	return passos[indice] if ativa() else {}


func id_do_passo() -> String:
	return String(passo_atual().get("id", ""))


func avancar() -> void:
	if ativa():
		indice += 1


## Este evento e o que o passo corrente espera? `valor` so e comparado quando o
## passo declara um — "item_equipado" sem valor aceita qualquer item.
func atende(evento: String, valor: String = "") -> bool:
	var esperar: Variant = passo_atual().get("esperar")
	if not esperar is Dictionary:
		return false
	var d: Dictionary = esperar
	if String(d.get("evento", "")) != evento:
		return false
	return not d.has("valor") or String(d["valor"]) == valor


## Para onde o passo corrente volta quando chega "falhou". "" = nao trata falha.
func destino_de_falha() -> String:
	return String(passo_atual().get("se_falhar", ""))


## O que o evento faz com o passo corrente, SEM mudar nada: REACAO_CONCLUIR,
## REACAO_VOLTAR ou "" (ignorado). Pergunta e nao acao de proposito — antes de
## avancar, o gerenciador ainda precisa do passo corrente para aplicar os efeitos
## `ao_concluir` dele.
##
## "Atende" vem antes de "falhou": um passo que ESPERA a falha (para ensinar a
## cancelar, por exemplo) conclui com ela em vez de voltar.
func reacao(evento: String, valor: String = "") -> String:
	if not ativa():
		return ""
	if atende(evento, valor):
		return REACAO_CONCLUIR
	if evento == EVENTO_FALHA and destino_de_falha() != "":
		return REACAO_VOLTAR
	return ""


func ir_para(id_passo: String) -> bool:
	for i in passos.size():
		if String(passos[i].get("id", "")) == id_passo:
			indice = i
			return true
	return false


## Texto de interface por chave, ou a propria chave — visivel na tela e no teste,
## em vez de um rotulo vazio que ninguem nota.
func texto(chave: String) -> String:
	return String(textos.get(chave, chave))


## "Recebeu: Vara de Pesca ×1" pelo molde de `textos.recebeu`. Molde ausente ou
## sem os marcadores cai num formato fixo em vez de errar no meio da licao.
func texto_recebeu(nome: String, quantidade: int) -> String:
	var molde := String(textos.get("recebeu", ""))
	if molde.count("%s") == 1 and molde.count("%d") == 1 \
			and molde.find("%s") < molde.find("%d"):
		return molde % [nome, quantidade]
	return "%s ×%d" % [nome, quantidade]
