extends Node

## Autoload `Save` — dono da partida em curso e dos tres slots em disco.
##
## O PROJETO NAO TINHA AUTOLOAD NENHUM ate aqui, e isso era uma qualidade: cada
## cena monta o que precisa e nada e global por conveniencia. O save quebra a
## regra por um motivo que nenhum outro sistema tem — ele precisa existir ANTES
## da cena de jogo (o menu le os slots sem montar o mundo) e CONTINUAR existindo
## DEPOIS dela (a seed da partida atravessa menu -> mundo -> menu). Um dado com
## tempo de vida maior que o da cena nao cabe dentro de uma cena.
##
## SECOES: como o save colhe o que nao e dele
## -----------------------------------------
## Este no nao conhece MundoIso, InventarioJogador, EstadoMundo nem Equipe. Quem
## tem dado vivo registra como entrega-lo e como recebe-lo de volta:
##
##     Save.registrar_secao("jogador",
##             func(d: DadosPartida): d.celula = mundo.mundo_para_celula(jogador.position),
##             func(d: DadosPartida): jogador.position = mundo.celula_para_mundo(d.celula))
##
## E o mesmo padrao de EstadoMundo.registrar_provedor, e pela mesma razao: um
## sistema novo (deposito de criaturas, loja, missao) custa DUAS LINHAS NA CENA e
## nenhuma alteracao aqui. A alternativa — o save importando cada sistema do jogo
## — e o que transforma um formato de arquivo no no mais acoplado do projeto.
##
## As secoes sao reregistradas a cada montagem da cena de jogo e sobrescrevem a
## anterior pelo nome. Callable de no ja liberado e descartada na hora de colher:
## trocar de cena nao pode deixar o save tentando ler um jogador que nao existe.
##
## SECAO PERMANENTE. Um autoload (Bolsa, Equipe) nasce antes de qualquer cena e
## sobrevive a todas: a secao dele nao pode ser esquecida na troca de cena junto
## com as do mundo, ou o save gravaria uma bolsa vazia. Por isso
## `registrar_secao(..., permanente = true)`, e por isso `esquecer_secoes()` so
## derruba as de cena. A ordem continua sendo a de registro, e as permanentes
## registram primeiro (no _ready do autoload) — o que e exatamente a ordem certa:
## a bolsa tem de estar reposta antes de o encontro ler o estoque dela.
##
## DETERMINISMO (RF03). A conversao de texto em seed e uma FNV-1a propria
## (sistemas/regras/semente.gd), e nao String.hash(): o hash da engine pode mudar
## entre versoes do Godot, e a mesma palavra passaria a gerar outro mundo depois
## de uma atualizacao — exatamente a promessa que o trabalho faz e que nao pode
## ser quebrada por um upgrade.

signal partida_iniciada(dados: DadosPartida)
signal partida_encerrada()
signal partida_salva(slot: int)
signal slots_mudaram()

const SLOTS := ArquivoSave.SLOTS

## Partida em curso. null no menu principal e em qualquer cena aberta direto
## (teste, visualizador do bestiario): e o que permite a cena do mundo cair no
## comportamento antigo, com a seed constante, sem nenhum caminho especial.
var partida: DadosPartida = null

## Slot de onde a partida veio, e para onde F5/menu de pausa salvam. 0 = partida
## ainda nao vinculada a nenhum slot.
var slot_atual: int = 0

var _secoes: Dictionary = {}       ## nome -> {coletar, aplicar, permanente}
var _ordem: PackedStringArray = [] ## ordem de registro, respeitada ao aplicar
var _resumos: Array = []
var _resumos_validos: bool = false


func _ready() -> void:
	# PAUSABLE e nao ALWAYS: com o menu de pausa aberto (Etapa 2) o cronometro
	# da partida tem de parar junto com o jogo.
	process_mode = Node.PROCESS_MODE_PAUSABLE


func _process(delta: float) -> void:
	if partida != null:
		partida.tempo_jogado += delta


# ------------------------------------------------------------------- secoes

func registrar_secao(nome: String, coletar: Callable, aplicar: Callable,
		permanente: bool = false) -> void:
	if not _secoes.has(nome):
		_ordem.append(nome)
	_secoes[nome] = {"coletar": coletar, "aplicar": aplicar,
			"permanente": permanente}


## Derruba as secoes DE CENA. As permanentes (autoloads) ficam — ver nota no
## cabecalho.
func esquecer_secoes() -> void:
	var restantes := PackedStringArray()
	for nome: String in _ordem:
		if bool(_secoes[nome].get("permanente", false)):
			restantes.append(nome)
		else:
			_secoes.erase(nome)
	_ordem = restantes


## Preenche `partida` com o estado vivo de todos os sistemas registrados.
## Publico porque o cartao do slot precisa do estado ATUAL, e nao do estado do
## ultimo save, para mostrar onde o jogador esta.
func coletar() -> void:
	if partida == null:
		return
	for nome: String in _ordem:
		var coletar_: Callable = _secoes[nome]["coletar"]
		if coletar_.is_valid():
			coletar_.call(partida)


func _aplicar() -> void:
	if partida == null:
		return
	for nome: String in _ordem:
		var aplicar_: Callable = _secoes[nome]["aplicar"]
		if aplicar_.is_valid():
			aplicar_.call(partida)


## Entrega a `partida` aos sistemas da cena recem-montada. A cena do mundo chama
## isto depois de registrar as suas secoes.
func restaurar_na_cena() -> void:
	_aplicar()


# ------------------------------------------------------------------- partida

## Comeca uma partida nova em memoria. NAO grava: o primeiro save acontece quando
## o jogador salva, e uma partida nova que ja sobrescreve o slot tiraria dele a
## chance de desistir.
func nova_partida(semente: int, texto: String = "", slot: int = 0,
		criaturas: int = 100) -> DadosPartida:
	partida = DadosPartida.nova(semente, texto, criaturas)
	slot_atual = slot if ArquivoSave.slot_valido(slot) else 0
	esquecer_secoes()
	partida_iniciada.emit(partida)
	return partida


func carregar(slot: int) -> bool:
	var r := ArquivoSave.ler(slot)
	if r["estado"] != ArquivoSave.Estado.OK:
		push_warning("Save: slot %d nao carregou — %s" % [slot, r["erro"]])
		return false
	partida = r["dados"]
	slot_atual = slot
	esquecer_secoes()
	if r["do_backup"]:
		push_warning("Save: slot %d foi recuperado do backup" % slot)
	partida_iniciada.emit(partida)
	return true


## Grava a partida em curso. Devolve "" em caso de sucesso, ou o motivo da falha.
func salvar(slot: int = 0) -> String:
	if partida == null:
		return "nao ha partida em curso"
	var destino: int = slot if ArquivoSave.slot_valido(slot) else slot_atual
	if not ArquivoSave.slot_valido(destino):
		return "nenhum slot escolhido"
	coletar()
	var erro := ArquivoSave.escrever(destino, partida)
	if erro != "":
		return erro
	slot_atual = destino
	_resumos_validos = false
	partida_salva.emit(destino)
	slots_mudaram.emit()
	return ""


## Larga a partida (volta ao menu). Nao grava nada de proposito: sair sem salvar
## tem de ser possivel, e um autosave escondido aqui apagaria o save bom do
## jogador com o estado que ele estava tentando descartar.
func encerrar_partida() -> void:
	if partida == null:
		return
	partida = null
	slot_atual = 0
	esquecer_secoes()
	partida_encerrada.emit()


func em_partida() -> bool:
	return partida != null


# --------------------------------------------------------------------- slots

## Um dicionario por slot, na ordem 1..SLOTS:
##   {slot, estado, dados, erro, do_backup}
## Em cache porque o menu redesenha os cartoes a cada navegacao e reler tres
## arquivos por tecla pressionada e desperdicio visivel em disco lento.
func resumos() -> Array:
	if not _resumos_validos:
		recarregar_resumos()
	return _resumos


func recarregar_resumos() -> void:
	_resumos.clear()
	for slot in range(1, SLOTS + 1):
		var r := ArquivoSave.ler(slot)
		r["slot"] = slot
		_resumos.append(r)
	_resumos_validos = true


## Ha ao menos um slot carregavel? E o que habilita "Continuar" no menu.
func ha_save() -> bool:
	for r: Dictionary in resumos():
		if r["estado"] == ArquivoSave.Estado.OK:
			return true
	return false


## Slot do save mais recente, ou 0. Usado pelo "Continuar" direto.
func slot_mais_recente() -> int:
	var melhor: int = 0
	var marca: String = ""
	for r: Dictionary in resumos():
		if r["estado"] != ArquivoSave.Estado.OK:
			continue
		var d: DadosPartida = r["dados"]
		# Comparacao de texto: o carimbo e ISO 8601 ("2026-10-02 19:40:11"), e
		# nessa forma a ordem lexicografica E a ordem cronologica.
		if d.salvo_em > marca:
			marca = d.salvo_em
			melhor = int(r["slot"])
	return melhor


func apagar(slot: int) -> void:
	ArquivoSave.apagar(slot)
	_resumos_validos = false
	slots_mudaram.emit()


# A conversao de texto em seed NAO esta aqui: vive em sistemas/regras/semente.gd,
# como regra pura testavel fora de cena. Quem precisa dela (a tela de nova
# partida) chama `Semente.de_texto()` direto, sem passar por este no.
