class_name ArquivoSave
extends RefCounted

## Leitura e escrita dos slots em user://. E a unica classe do projeto que toca
## em disco.
##
## ESCRITA EM TRES TEMPOS, e nenhum deles e paranoia gratuita: um save e o unico
## dado do jogo que o jogador nao pode refazer.
##
##   1. grava em `slot_N.tmp`;
##   2. LE O TMP DE VOLTA e o reconstroi como DadosPartida. Se o que voltou nao
##      bate, o save e abortado AQUI — com o arquivo bom ainda intacto no lugar;
##   3. so entao roda `slot_N.json` -> `slot_N.bak` e `slot_N.tmp` -> `slot_N.json`.
##
## Escrever por cima do arquivo bom e so depois descobrir que o disco encheu e
## exatamente o modo de falha que destroi a partida. Aqui o pior caso de uma
## queda no meio do passo 3 e perder o save MAIS NOVO: o .bak e de antes, e ler()
## cai nele sozinho.
##
## DANIFICADO E UM ESTADO, NAO UMA EXCECAO. ler() nunca falha e nunca derruba o
## jogo: devolve VAZIO, OK ou DANIFICADO com o motivo por escrito, e o menu
## desenha o cartao correspondente. Um JSON truncado por um desligamento no
## lugar errado e cenario esperado, nao bug.
##
## JSON e nao Resource: um .tres de save e codigo (`ResourceLoader` instancia o
## que o arquivo mandar), e um save editado a mao vira vetor de execucao. JSON e
## dado inerte, le-se com um editor de texto e dispensa migracao binaria.

const DIR_PADRAO := "user://saves/"
const SLOTS := 3

## Onde os slots moram. Variavel, e nao constante, por UM motivo: o teste
## headless precisa gravar sem encostar nos saves reais de quem roda o teste.
## Nenhum codigo de jogo a altera.
static var diretorio: String = DIR_PADRAO

enum Estado { VAZIO, OK, DANIFICADO }


static func caminho(slot: int) -> String:
	return "%sslot_%d.json" % [diretorio, slot]


static func caminho_backup(slot: int) -> String:
	return "%sslot_%d.bak" % [diretorio, slot]


static func caminho_temporario(slot: int) -> String:
	return "%sslot_%d.tmp" % [diretorio, slot]


static func slot_valido(slot: int) -> bool:
	return slot >= 1 and slot <= SLOTS


static func existe(slot: int) -> bool:
	return FileAccess.file_exists(caminho(slot)) \
			or FileAccess.file_exists(caminho_backup(slot))


## Le um slot. NUNCA devolve null e nunca empurra erro para o chamador:
##   {estado: Estado, dados: DadosPartida|null, erro: String, do_backup: bool}
static func ler(slot: int) -> Dictionary:
	if not slot_valido(slot):
		return _resultado(Estado.DANIFICADO, null, "slot %d fora de 1..%d" % [slot, SLOTS])
	var principal := _tentar_ler(caminho(slot))
	if principal["estado"] == Estado.OK:
		return principal
	# Um principal ausente com backup presente so acontece depois de uma queda
	# entre os dois renames do passo 3. Vale tentar.
	var backup := _tentar_ler(caminho_backup(slot))
	if backup["estado"] == Estado.OK:
		backup["do_backup"] = true
		return backup
	# Nada em lugar nenhum = slot vazio. Principal danificado com backup
	# tambem ruim = danificado, e o motivo relatado e o do PRINCIPAL, que e o
	# que o jogador tentou abrir.
	if principal["estado"] == Estado.VAZIO and backup["estado"] == Estado.VAZIO:
		return _resultado(Estado.VAZIO, null, "")
	return principal if principal["estado"] == Estado.DANIFICADO else backup


static func _tentar_ler(caminho_: String) -> Dictionary:
	if not FileAccess.file_exists(caminho_):
		return _resultado(Estado.VAZIO, null, "")
	var f := FileAccess.open(caminho_, FileAccess.READ)
	if f == null:
		return _resultado(Estado.DANIFICADO, null,
				"nao foi possivel abrir (erro %d)" % FileAccess.get_open_error())
	var texto := f.get_as_text()
	f.close()
	if texto.strip_edges() == "":
		return _resultado(Estado.DANIFICADO, null, "arquivo vazio")
	var bruto: Variant = JSON.parse_string(texto)
	if not (bruto is Dictionary):
		return _resultado(Estado.DANIFICADO, null, "JSON invalido ou truncado")
	var dados := DadosPartida.de_dicionario(bruto)
	if not dados.valido():
		return _resultado(Estado.DANIFICADO, null, dados.erro)
	return _resultado(Estado.OK, dados, "")


## Grava. Devolve "" em caso de sucesso, ou a mensagem de erro.
static func escrever(slot: int, dados: DadosPartida) -> String:
	if not slot_valido(slot):
		return "slot %d fora de 1..%d" % [slot, SLOTS]
	if dados == null:
		return "nada para salvar"
	var erro_dir := _garantir_diretorio()
	if erro_dir != "":
		return erro_dir

	dados.salvo_em = Time.get_datetime_string_from_system(false, true)
	if dados.criado_em == "":
		dados.criado_em = dados.salvo_em

	# 1. grava o temporario
	var tmp := caminho_temporario(slot)
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return "nao foi possivel escrever em %s (erro %d)" \
				% [tmp, FileAccess.get_open_error()]
	# Indentado: um save que se le num editor de texto e um save que se depura
	# sem ferramenta. O custo em bytes e irrelevante na escala deste formato.
	f.store_string(JSON.stringify(dados.para_dicionario(), "  "))
	f.close()

	# 2. confere o que foi realmente parar no disco ANTES de mexer no arquivo bom
	var conferencia := _tentar_ler(tmp)
	if conferencia["estado"] != Estado.OK:
		DirAccess.remove_absolute(tmp)
		return "save abortado: o arquivo gravado nao releu (%s)" % conferencia["erro"]

	# 3. rotaciona. A ordem importa: o backup e feito antes de o principal sair
	# do lugar, de modo que nunca existe um instante sem nenhuma copia valida.
	var atual := caminho(slot)
	var bak := caminho_backup(slot)
	if FileAccess.file_exists(atual):
		DirAccess.remove_absolute(bak)
		var e := DirAccess.rename_absolute(atual, bak)
		if e != OK:
			DirAccess.remove_absolute(tmp)
			return "nao foi possivel rotacionar o backup (erro %d)" % e
	var e2 := DirAccess.rename_absolute(tmp, atual)
	if e2 != OK:
		return "nao foi possivel publicar o save (erro %d)" % e2
	return ""


## Apaga o slot inteiro — principal, backup e qualquer temporario orfao.
static func apagar(slot: int) -> void:
	if not slot_valido(slot):
		return
	for c in [caminho(slot), caminho_backup(slot), caminho_temporario(slot)]:
		if FileAccess.file_exists(c):
			DirAccess.remove_absolute(c)


static func _garantir_diretorio() -> String:
	if DirAccess.dir_exists_absolute(diretorio):
		return ""
	var e := DirAccess.make_dir_recursive_absolute(diretorio)
	return "" if e == OK else "nao foi possivel criar %s (erro %d)" % [diretorio, e]


static func _resultado(estado: Estado, dados: DadosPartida, erro: String) -> Dictionary:
	return {"estado": estado, "dados": dados, "erro": erro, "do_backup": false}
