extends Node

## Som do jogo: efeitos curtos e uma musica de fundo por vez.
##
## Autoload pela regua de sistemas/: a musica atravessa trocas de cena. Ninguem chama
## este no direto: o caminho e a classe Som, que nao quebra quando o autoload nao
## existe (testes rodados com -s, por exemplo).
##
## Os arquivos e o catalogo saem de tools/audio/gerar_audio.py. O volume segue as
## opcoes "volume_musica" e "volume_efeitos".

const CATALOGO := "res://arte/audio/sons.json"
const DIR := "res://arte/audio/"
## Efeitos simultaneos. O nono para o mais antigo.
const VOZES := 8
const SILENCIO_DB := -80.0

var _efeitos: Dictionary = {}
var _musicas: Dictionary = {}
var _vozes: Array[AudioStreamPlayer] = []
var _proxima_voz: int = 0
var _musica: AudioStreamPlayer
var _musica_atual: String = ""
var _volume_musica_db: float = 0.0
var _volume_efeitos_db: float = 0.0
var _fade: Tween


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_carregar_catalogo()
	for i in VOZES:
		var voz := AudioStreamPlayer.new()
		add_child(voz)
		_vozes.append(voz)
	_musica = AudioStreamPlayer.new()
	add_child(_musica)
	var opcoes := get_node_or_null("/root/Opcoes")
	if opcoes != null:
		opcoes.mudou.connect(func(_id: String, _valor: Variant) -> void: _aplicar_volumes())
	_aplicar_volumes()


func _carregar_catalogo() -> void:
	var bruto: Variant = JSON.parse_string(FileAccess.get_file_as_string(CATALOGO))
	if not bruto is Dictionary:
		push_warning("Audio: catalogo ausente em " + CATALOGO)
		return
	for nome: String in bruto.get("efeitos", {}):
		_efeitos[nome] = load(DIR + String(bruto["efeitos"][nome]))
	for nome: String in bruto.get("musicas", {}):
		var faixa: AudioStream = load(DIR + String(bruto["musicas"][nome]))
		# O laco e definido aqui, e nao no .import, que fica fora do git.
		if faixa is AudioStreamWAV:
			var wav := faixa as AudioStreamWAV
			wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
			wav.loop_begin = 0
			wav.loop_end = int(wav.get_length() * wav.mix_rate)
		_musicas[nome] = faixa


func tem_efeito(nome: String) -> bool:
	return _efeitos.has(nome)


func tocar(nome: String, variacao_tom: float = 0.0) -> void:
	var som: AudioStream = _efeitos.get(nome)
	if som == null or _volume_efeitos_db <= SILENCIO_DB:
		return
	var voz: AudioStreamPlayer = _vozes[_proxima_voz]
	_proxima_voz = (_proxima_voz + 1) % VOZES
	voz.stream = som
	voz.volume_db = _volume_efeitos_db
	voz.pitch_scale = 1.0 + randf_range(-variacao_tom, variacao_tom) if variacao_tom > 0.0 else 1.0
	voz.play()


## Troca a musica de fundo com um fade curto. "" para o silencio. A mesma musica nao
## recomeca: voltar de uma batalha para a vila nao reinicia a faixa da vila.
func musica(nome: String, duracao_fade: float = 0.6) -> void:
	if nome == _musica_atual:
		return
	_musica_atual = nome
	if _fade != null:
		_fade.kill()
	_fade = create_tween()
	if _musica.playing:
		_fade.tween_property(_musica, "volume_db", SILENCIO_DB, duracao_fade * 0.5)
	_fade.tween_callback(func() -> void:
		_musica.stop()
		var faixa: AudioStream = _musicas.get(nome)
		if faixa == null:
			return
		_musica.stream = faixa
		_musica.volume_db = SILENCIO_DB
		_musica.play())
	_fade.tween_property(_musica, "volume_db", _volume_musica_db, duracao_fade * 0.5)


func musica_atual() -> String:
	return _musica_atual


func _aplicar_volumes() -> void:
	var opcoes := get_node_or_null("/root/Opcoes")
	_volume_musica_db = float(opcoes.dado("volume_musica", -12.0)) if opcoes != null else -12.0
	_volume_efeitos_db = float(opcoes.dado("volume_efeitos", -6.0)) if opcoes != null else -6.0
	if _musica != null and (_fade == null or not _fade.is_running()):
		_musica.volume_db = _volume_musica_db
