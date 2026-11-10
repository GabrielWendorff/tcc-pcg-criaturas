extends Node

## Log de sessao: godot --headless --path . res://tools/test_registro.tscn

const DIR_TESTE := "user://logs_teste/"

var _falhas: int = 0
var _total: int = 0


func _ready() -> void:
	print("== Registro de sessao ==")
	_limpar()
	var reg := get_tree().root.get_node_or_null("/root/RegistroSessao")
	_ok(reg != null, "o autoload esta registrado")
	if reg != null:
		var real_dir: String = reg.diretorio
		reg.diretorio = DIR_TESTE
		reg.abrir()
		_ok(reg.caminho.begins_with(DIR_TESTE), "grava no diretorio pedido")
		reg.evento("duelo", {"guardiao": "dulce", "resultado": "vitoria"})
		push_error("erro de teste para o log")
		await get_tree().process_frame
		var linhas: PackedStringArray = FileAccess.get_file_as_string(reg.caminho).strip_edges().split("\n")
		var primeira: Variant = JSON.parse_string(linhas[0])
		_ok(primeira is Dictionary and primeira["evento"] == "sessao", "a primeira linha abre a sessao")
		var texto: String = "\n".join(linhas)
		_ok(texto.contains("\"guardiao\":\"dulce\""), "o evento foi gravado")
		_ok(texto.contains("erro de teste para o log") and texto.contains("\"evento\":\"erro\""),
				"erro de script entra no log")
		var todas_validas: bool = true
		for l: String in linhas:
			if not JSON.parse_string(l) is Dictionary:
				todas_validas = false
		_ok(todas_validas, "toda linha e JSON valido")
		for i in 25:
			FileAccess.open("%ssessao_2020-01-%02d.jsonl" % [DIR_TESTE, i + 1], FileAccess.WRITE).close()
		reg.abrir()
		_ok(DirAccess.get_files_at(DIR_TESTE).size() <= reg.MAXIMO_DE_ARQUIVOS, "sessoes antigas saem",
				str(DirAccess.get_files_at(DIR_TESTE).size()))
		reg.diretorio = real_dir
		reg.abrir()
	_limpar()
	print("\nRESULTADO: %s" % ("TODOS OS TESTES PASSARAM (%d)" % _total if _falhas == 0
			else "%d VERIFICACAO(OES) FALHARAM" % _falhas))
	get_tree().quit(0 if _falhas == 0 else 1)


func _ok(cond: bool, nome: String, detalhe: String = "") -> void:
	_total += 1
	if not cond:
		_falhas += 1
	print("    %s %s  %s" % ["OK  " if cond else "FALHOU", nome, detalhe])


func _limpar() -> void:
	if DirAccess.dir_exists_absolute(DIR_TESTE):
		for nome in DirAccess.get_files_at(DIR_TESTE):
			DirAccess.remove_absolute(DIR_TESTE + nome)
