extends Node

## Log local de sessao e de erros (requisito de monitoramento do Playbook).
##
## Um arquivo JSONL por sessao em user://logs/, e nada sai da maquina de quem joga: para o
## relatorio de playtest, o participante entrega o arquivo. Guarda o que o jogo fez (seed,
## duelos, desfecho) e os erros de script com a linha, para diagnosticar a build de
## entrega, em que nao ha console.
##
## Autoload pela regua de sistemas/: vive mais que qualquer cena. E nao decide nada do
## jogo: se nao conseguir abrir o arquivo, o jogo segue sem log.

const DIR_PADRAO := "user://logs/"
const PREFIXO := "sessao_"
## Sessoes guardadas. A mais antiga sai, para o log nao crescer sem limite.
const MAXIMO_DE_ARQUIVOS := 20

## O teste troca, para nao encostar nos logs reais.
var diretorio: String = DIR_PADRAO
var caminho: String = ""

var _arquivo: FileAccess
var _trava := Mutex.new()
var _capturador: CapturadorDeErros


func _ready() -> void:
	abrir()
	_capturador = CapturadorDeErros.new(self)
	OS.add_logger(_capturador)


func abrir() -> void:
	_trava.lock()
	if _arquivo != null:
		_arquivo.close()
		_arquivo = null
	DirAccess.make_dir_recursive_absolute(diretorio)
	var carimbo := Time.get_datetime_string_from_system().replace(":", "-")
	caminho = "%s%s%s.jsonl" % [diretorio, PREFIXO, carimbo]
	_arquivo = FileAccess.open(caminho, FileAccess.WRITE)
	_trava.unlock()
	_apagar_antigos()
	evento("sessao", {
		"godot": Engine.get_version_info()["string"],
		"so": OS.get_name(),
		"entrega": OS.has_feature("template_release"),
	})


## Grava uma linha. `dados` so aceita o que vira JSON.
func evento(nome: String, dados: Dictionary = {}) -> void:
	var linha := dados.duplicate()
	linha["t"] = Time.get_datetime_string_from_system()
	linha["evento"] = nome
	_escrever(JSON.stringify(linha))


func _escrever(texto: String) -> void:
	_trava.lock()
	if _arquivo != null:
		_arquivo.store_line(texto)
		# Sem flush, a ultima linha antes de um travamento, a que mais importa, se perderia.
		_arquivo.flush()
	_trava.unlock()


func _apagar_antigos() -> void:
	var nomes: Array = []
	for nome: String in DirAccess.get_files_at(diretorio):
		if nome.begins_with(PREFIXO):
			nomes.append(nome)
	nomes.sort()
	for i in maxi(0, nomes.size() - MAXIMO_DE_ARQUIVOS):
		DirAccess.remove_absolute(diretorio + nomes[i])


func _exit_tree() -> void:
	evento("fim")
	OS.remove_logger(_capturador)
	_trava.lock()
	if _arquivo != null:
		_arquivo.close()
		_arquivo = null
	_trava.unlock()


## Recebe erros do motor e de script. Pode ser chamado de qualquer thread, e nao pode
## usar nada que gere erro: voltaria para ca.
class CapturadorDeErros extends Logger:
	var _registro: Node

	func _init(registro: Node) -> void:
		_registro = registro

	func _log_error(function: String, file: String, line: int, code: String, rationale: String,
			_editor_notify: bool, error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		_registro._escrever(JSON.stringify({
			"evento": "erro",
			"tipo": error_type,
			"onde": "%s:%d %s" % [file, line, function],
			"mensagem": rationale if rationale != "" else code,
		}))
