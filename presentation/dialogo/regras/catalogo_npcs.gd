class_name CatalogoNpcs
extends RefCounted

## Todos os NPCs autorais, de autoral/npcs/npcs.json.
##
## Um arquivo so, e nao um por NPC: a lista inteira cabe numa tela, e ver os
## personagens lado a lado e o que deixa evidente uma celula repetida ou um
## dialogo que ficou sem dono. As ARVORES de dialogo, essas sim, vao uma por
## arquivo — elas crescem.

const CAMINHO := "res://autoral/npcs/npcs.json"

var npcs: Array[DadosNpc] = []
var erro: String = ""


static func carregar(caminho: String = CAMINHO) -> CatalogoNpcs:
	var cat := CatalogoNpcs.new()
	if not FileAccess.file_exists(caminho):
		cat.erro = "arquivo inexistente — " + caminho
		return cat
	var dados: Variant = JSON.parse_string(FileAccess.get_file_as_string(caminho))
	if not dados is Dictionary:
		cat.erro = "JSON invalido — " + caminho
		return cat
	for d: Dictionary in (dados as Dictionary).get("npcs", []):
		cat.npcs.append(DadosNpc.de_dicionario(d))
	return cat


func por_id(id: String) -> DadosNpc:
	for n: DadosNpc in npcs:
		if n.id == id:
			return n
	return null


func na_regiao(regiao: String) -> Array[DadosNpc]:
	var saida: Array[DadosNpc] = []
	for n: DadosNpc in npcs:
		if n.regiao == regiao:
			saida.append(n)
	return saida


## Coerencia do catalogo com os dialogos e com a arte. Ferramenta e teste — o
## jogo nao valida em tempo de execucao; um NPC mudo por falta de arquivo tem de
## falhar no teste, nao na frente de quem joga.
func validar(dialogos: CatalogoDialogos) -> PackedStringArray:
	var erros := PackedStringArray()
	if erro != "":
		erros.append("catalogo de NPCs: " + erro)
		return erros
	if npcs.is_empty():
		erros.append("catalogo de NPCs vazio")
	var ids := {}
	var celulas := {}
	for n: DadosNpc in npcs:
		if n.id == "":
			erros.append("NPC sem id")
			continue
		if ids.has(n.id):
			erros.append("id repetido — " + n.id)
		ids[n.id] = true
		if celulas.has(n.celula):
			erros.append("%s e %s ocupam a mesma celula %s"
					% [celulas[n.celula], n.id, n.celula])
		celulas[n.celula] = n.id
		if not n.direcao in DadosNpc.DIRECOES:
			erros.append("%s: direcao '%s' desconhecida" % [n.id, n.direcao])
		if n.folha != "" and not ResourceLoader.exists(n.folha) \
				and not FileAccess.file_exists(n.folha):
			erros.append("%s: folha de caminhada ausente — %s" % [n.id, n.folha])
		if n.retrato != "" and not ResourceLoader.exists(n.retrato) \
				and not FileAccess.file_exists(n.retrato):
			erros.append("%s: retrato ausente — %s" % [n.id, n.retrato])
		if dialogos != null and not dialogos.tem(n.dialogo):
			erros.append("%s: dialogo '%s' nao existe em autoral/dialogos/"
					% [n.id, n.dialogo])
	return erros
