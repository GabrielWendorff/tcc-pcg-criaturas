class_name CatalogoDialogos
extends RefCounted

## Acesso as arvores de dialogo de autoral/dialogos/.
##
## Carga SOB DEMANDA e por NOME DE ARQUIVO: o NPC declara `"dialogo": "anselmo"`
## e o catalogo abre `autoral/dialogos/anselmo.json` na primeira vez que alguem
## fala com ele. Nao depende de listar diretorio em tempo de jogo (o que muda de
## comportamento entre projeto aberto e build exportado) e nao paga a carga de
## todas as arvores para abrir uma conversa.
##
## `carregar_todas()` existe para a FERRAMENTA: e o teste headless que quer ver
## todas as arvores de uma vez, e la listar diretorio e legitimo.

const DIRETORIO := "res://autoral/dialogos/"

var _arvores: Dictionary = {}


func arvore(id: String) -> ArvoreDialogo:
	if id == "":
		return null
	if _arvores.has(id):
		return _arvores[id]
	var a := ArvoreDialogo.carregar(DIRETORIO + id + ".json")
	_arvores[id] = a          # guarda ate o null: nao insiste num arquivo ausente
	return a


func tem(id: String) -> bool:
	return arvore(id) != null


## Todos os ids presentes no diretorio, em ordem estavel.
static func ids_no_diretorio(dir: String = DIRETORIO) -> PackedStringArray:
	var ids := PackedStringArray()
	var d := DirAccess.open(dir)
	if d == null:
		return ids
	for arquivo: String in d.get_files():
		# Fora do editor os .json continuam .json; dentro dele o FileSystem pode
		# reportar o par importado. Aceitar os dois evita lista vazia no editor.
		if arquivo.ends_with(".json"):
			ids.append(arquivo.get_basename())
		elif arquivo.ends_with(".json.import"):
			ids.append(arquivo.get_basename().get_basename())
	ids.sort()
	return ids


func carregar_todas(dir: String = DIRETORIO) -> Array[ArvoreDialogo]:
	var todas: Array[ArvoreDialogo] = []
	for id: String in ids_no_diretorio(dir):
		var a := arvore(id)
		if a != null:
			todas.append(a)
	return todas


## Erros estruturais de TODAS as arvores, prefixados pelo arquivo.
func validar(dir: String = DIRETORIO) -> PackedStringArray:
	var erros := PackedStringArray()
	for a: ArvoreDialogo in carregar_todas(dir):
		if a.id != a.caminho.get_file().get_basename():
			erros.append("%s: campo id='%s' diverge do nome do arquivo"
					% [a.caminho.get_file(), a.id])
		erros.append_array(a.validar())
	return erros
