extends Node

## Som: godot --headless --path . res://tools/test_audio.tscn

var _falhas: int = 0
var _total: int = 0


func _ready() -> void:
	print("== Audio ==")
	var audio := get_tree().root.get_node_or_null("/root/Audio")
	_ok(audio != null, "o autoload esta registrado")
	if audio != null:
		var catalogo: Dictionary = JSON.parse_string(
				FileAccess.get_file_as_string("res://arte/audio/sons.json"))
		var todos: bool = true
		for nome: String in catalogo["efeitos"]:
			todos = todos and audio.tem_efeito(nome)
		_ok(todos, "todo efeito do catalogo carregou", str(catalogo["efeitos"].size()))
		var usados := _efeitos_usados_no_codigo()
		var faltando: Array = usados.filter(func(n: String) -> bool: return not audio.tem_efeito(n))
		_ok(faltando.is_empty(), "todo Som.tocar do codigo tem arquivo", str(faltando))
		for nome: String in catalogo["musicas"]:
			var faixa: AudioStream = audio._musicas.get(nome)
			_ok(faixa is AudioStreamWAV and (faixa as AudioStreamWAV).loop_mode
					== AudioStreamWAV.LOOP_FORWARD, "a musica '%s' toca em laco" % nome)
		Som.tocar("golpe")
		Som.musica("batalha")
		_ok(audio.musica_atual() == "batalha", "Som.musica troca a faixa")
		Som.musica("")
		_ok(audio.musica_atual() == "", "e silencia")
		var opcoes := get_tree().root.get_node_or_null("/root/Opcoes")
		var real: String = FileAccess.get_file_as_string("user://opcoes.json")
		opcoes.definir("volume_efeitos", "desligados")
		_ok(audio._volume_efeitos_db <= audio.SILENCIO_DB, "a opcao desliga os efeitos")
		opcoes.definir("volume_efeitos", "medio")
		if real != "":
			FileAccess.open("user://opcoes.json", FileAccess.WRITE).store_string(real)
	print("\nRESULTADO: %s" % ("TODOS OS TESTES PASSARAM (%d)" % _total if _falhas == 0
			else "%d VERIFICACAO(OES) FALHARAM" % _falhas))
	get_tree().quit(0 if _falhas == 0 else 1)


func _ok(cond: bool, nome: String, detalhe: String = "") -> void:
	_total += 1
	if not cond:
		_falhas += 1
	print("    %s %s  %s" % ["OK  " if cond else "FALHOU", nome, detalhe])


## Varre presentation/ e sistemas/ atras de Som.tocar("nome"), inclusive nos ternarios.
func _efeitos_usados_no_codigo() -> Array:
	var nomes: Dictionary = {}
	var re := RegEx.create_from_string("Som\\.tocar\\(([^)]*)\\)")
	var aspas := RegEx.create_from_string("\"([a-z_]+)\"")
	for raiz: String in ["res://presentation/", "res://sistemas/"]:
		for caminho: String in _arquivos(raiz):
			var texto := FileAccess.get_file_as_string(caminho)
			for m: RegExMatch in re.search_all(texto):
				for a: RegExMatch in aspas.search_all(m.get_string(1)):
					nomes[a.get_string(1)] = true
	return nomes.keys()


func _arquivos(dir: String) -> Array:
	var saida: Array = []
	for nome: String in DirAccess.get_files_at(dir):
		if nome.ends_with(".gd"):
			saida.append(dir + nome)
	for sub: String in DirAccess.get_directories_at(dir):
		saida += _arquivos(dir + sub + "/")
	return saida
