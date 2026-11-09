class_name DadosPartida
extends RefCounted

## Retrato serializavel de uma partida. E O FORMATO DO SAVE — tudo que sobrevive
## a fechar o jogo passa por aqui, e nada escreve em disco sem passar.
##
## A classe nao conhece nenhum sistema do jogo: nao importa ArquivoSave, nao sabe
## o que e um MundoIso nem um InventarioJogador. Quem tem dado vivo o entrega
## registrando uma SECAO no autoload Save (ver sistemas/gerenciador_save.gd), no
## mesmo padrao dos provedores de EstadoMundo. E o que mantem este arquivo com um
## motivo so para mudar: o formato mudou.
##
## VERSAO. Todo save carrega a sua. Um save de versao MENOR passa por _migrar()
## antes de ser lido; um de versao MAIOR e recusado, porque nenhuma migracao pode
## adivinhar um campo que ainda nao foi inventado — melhor dizer "este save e de
## uma versao mais nova do jogo" do que carregar meia partida.
##
## CAMPOS AUSENTES NAO SAO ERRO. Todo get() tem padrao. Um save da Etapa 1 (sem
## time, sem deposito) carrega na Etapa 4 com time vazio, e nao com uma tela de
## falha. O que E erro esta em _validar(): sem seed de mundo nao ha partida
## nenhuma para reconstruir.
##
## O QUE NAO ESTA AQUI, DE PROPOSITO:
##   - as configuracoes (tremor de camera, etc.) — vivem em user://opcoes.json,
##     separadas, porque valem para o jogador e nao para a partida: trocar de
##     slot nao pode religar um efeito que ele desligou;
##   - os atributos das criaturas — ver CriaturaSalva: saem da seed;
##   - o mapa, os NPCs e as arvores de dialogo — Camada 1, iguais em toda
##     partida. Salvar conteudo autoral e salvar uma copia do repositorio.

const VERSAO_ATUAL := 1

## Valor usado quando a partida nao declara mapa. Ha um mapa so hoje
## (autoral/mapas/mundo.json); o campo existe para o dia em que houver interior
## de casa, que e a unica coisa que exigiria uma segunda cena.
const MAPA_PADRAO := "mundo"
const MODELO_DOS_SAVES_ANTIGOS := "condicionado"

var versao: int = VERSAO_ATUAL

# --- mundo (RF01/RF03): e daqui que a partida inteira se reconstroi ---------
var seed_mundo: int = 0
## O que o jogador digitou, quando digitou texto. Guardado para o cartao do slot
## poder mostrar "ribeira" em vez de 1259231044 — a seed derivada continua sendo
## `seed_mundo`, e e ela que o gerador usa.
var seed_texto: String = ""
var criaturas_por_mundo: int = 100

## Com qual modelo do gerador este mundo nasceu. O save guarda indice e seed, e nao os
## atributos: sem este campo, uma partida antiga acordaria com outras criaturas.
##
## Campo OPCIONAL, sem subir VERSAO_ATUAL: ausente le como a v1, que e o modelo de todo
## save anterior a ele. Partida nova recebe GeradorCriaturas.MODO_DO_JOGO em nova().
var modelo_gerador: String = MODELO_DOS_SAVES_ANTIGOS

# --- posicao -----------------------------------------------------------------
var mapa: String = MAPA_PADRAO
## Em CELULAS da grade, nunca em pixels: a celula e estavel, o pixel depende do
## tamanho do tile e mudaria de significado se a arte do chao mudasse de escala.
##
## CELULA_NAO_GRAVADA e o sentinela de "partida nunca salva": quem restaura tem
## de poder distinguir "o jogador estava aqui" de "ainda nao ha posicao", e o
## spawn do mapa e a resposta certa no segundo caso. (0,0) nao serviria: e uma
## celula real — hoje borda de rocha, mas depender da geometria do mapa para a
## correcao de um formato de arquivo e o tipo de acoplamento que quebra calado
## quando o mapa muda.)
const CELULA_NAO_GRAVADA := Vector2i(-1, -1)

var celula: Vector2i = CELULA_NAO_GRAVADA
var direcao: String = "baixo"
var regiao: String = ""
## Nome de exibicao da regiao ("Ribeira do Anselmo"), guardado ao lado do id.
##
## E denormalizacao DELIBERADA, pelo mesmo motivo de `seed_texto`: o cartao do
## slot precisa ser legivel sem montar o mundo, e o nome so existe dentro de
## autoral/mapas/mundo.json — 133 KB de terreno cujo unico byte util para o
## cartao e esse. O id continua sendo a verdade; o nome e so o rotulo.
var regiao_nome: String = ""

## Id do item na mao do jogador ("" = maos livres). Guardado o ID, nunca o
## ItemJogo: quem reequipa na carga confere se o item ainda esta na bolsa — um
## save editado a mao, ou um item que saiu da bolsa, cai em maos livres em vez
## de por na mao algo que o jogador nao tem.
##
## Campo OPCIONAL, sem subir VERSAO_ATUAL: ausente le como "", que e exatamente
## o estado de quem nunca equipou nada. Uma migracao so se justifica quando o
## padrao de um campo novo nao e o valor certo para os saves antigos.
var item_equipado: String = ""

# --- progresso ---------------------------------------------------------------
## EstadoMundo.para_dicionario(): bandeiras, regioes visitadas, nos de dialogo
## vistos. Guardado opaco de proposito — quem define o formato e o EstadoMundo.
var estado_mundo: Dictionary = {}

## id do item -> quantidade. Mesmo espaco de nomes de InventarioJogador.
var itens: Dictionary = {}

## Dinheiro do jogador. -1 = save de antes do gold existir: a Bolsa poe o gold inicial.
var gold: int = -1

var equipe: Array[CriaturaSalva] = []
var armazenadas: Array[CriaturaSalva] = []

# --- metadados do cartao de slot --------------------------------------------
var tempo_jogado: float = 0.0
var criado_em: String = ""
var salvo_em: String = ""

var erro: String = ""


func valido() -> bool:
	return erro == ""


## Partida nova. `texto` e o que o jogador digitou ("" quando a seed veio do
## sorteio ou foi digitada como numero).
static func nova(semente: int, texto: String = "", criaturas: int = 100) -> DadosPartida:
	var d := DadosPartida.new()
	d.seed_mundo = semente
	d.seed_texto = texto
	d.criaturas_por_mundo = maxi(1, criaturas)
	d.modelo_gerador = GeradorCriaturas.nome_do_modo(GeradorCriaturas.MODO_DO_JOGO)
	d.criado_em = Time.get_datetime_string_from_system(false, true)
	d.salvo_em = d.criado_em
	return d


static func de_dicionario(bruto: Dictionary) -> DadosPartida:
	var d := DadosPartida.new()
	d.versao = int(bruto.get("versao", 0))
	if d.versao > VERSAO_ATUAL:
		d.erro = "save da versao %d; este jogo le ate a %d" % [d.versao, VERSAO_ATUAL]
		return d
	var dados := _migrar(bruto, d.versao)

	var mundo: Dictionary = dados.get("mundo", {})
	d.seed_mundo = int(mundo.get("seed", 0))
	d.seed_texto = String(mundo.get("seed_texto", ""))
	d.criaturas_por_mundo = maxi(1, int(mundo.get("criaturas", 100)))
	d.modelo_gerador = String(mundo.get("modelo_gerador", MODELO_DOS_SAVES_ANTIGOS))

	var jog: Dictionary = dados.get("jogador", {})
	d.mapa = String(jog.get("mapa", MAPA_PADRAO))
	var c: Array = jog.get("celula", [])
	d.celula = Vector2i(int(c[0]), int(c[1])) if c.size() >= 2 else CELULA_NAO_GRAVADA
	d.direcao = String(jog.get("direcao", "baixo"))
	d.regiao = String(jog.get("regiao", ""))
	d.regiao_nome = String(jog.get("regiao_nome", ""))
	d.item_equipado = String(jog.get("item_equipado", ""))

	d.estado_mundo = (dados.get("estado_mundo", {}) as Dictionary).duplicate(true)
	d.itens = (dados.get("itens", {}) as Dictionary).duplicate(true)
	d.gold = int(dados.get("gold", -1))
	d.equipe = _ler_criaturas(dados.get("equipe", []))
	d.armazenadas = _ler_criaturas(dados.get("armazenadas", []))

	d.tempo_jogado = maxf(0.0, float(dados.get("tempo_jogado", 0.0)))
	d.criado_em = String(dados.get("criado_em", ""))
	d.salvo_em = String(dados.get("salvo_em", ""))

	d.versao = VERSAO_ATUAL
	d._validar()
	return d


func para_dicionario() -> Dictionary:
	return {
		"versao": VERSAO_ATUAL,
		"mundo": {
			"seed": seed_mundo,
			"seed_texto": seed_texto,
			"criaturas": criaturas_por_mundo,
			"modelo_gerador": modelo_gerador,
		},
		"jogador": {
			"mapa": mapa,
			"celula": [celula.x, celula.y],
			"direcao": direcao,
			"regiao": regiao,
			"regiao_nome": regiao_nome,
			"item_equipado": item_equipado,
		},
		"estado_mundo": estado_mundo.duplicate(true),
		"itens": itens.duplicate(true),
		"gold": gold,
		"equipe": _escrever_criaturas(equipe),
		"armazenadas": _escrever_criaturas(armazenadas),
		"tempo_jogado": tempo_jogado,
		"criado_em": criado_em,
		"salvo_em": salvo_em,
	}


## O minimo sem o qual nao da para reconstruir nada. Deliberadamente curto: um
## save e recusado so quando carrega-lo produziria um jogo quebrado, nunca por
## um campo cosmetico ausente.
func _validar() -> void:
	if seed_mundo == 0:
		erro = "save sem seed de mundo"
		return
	if GeradorCriaturas.modo_do_nome(modelo_gerador) == -1:
		erro = "save de um modelo do gerador que este jogo nao conhece: " + modelo_gerador
		return
	for lista: Array in [equipe, armazenadas]:
		for c: CriaturaSalva in lista:
			if c.world_seed != seed_mundo:
				erro = "criatura #%d e do mundo %d, nao do %d" \
						% [c.id, c.world_seed, seed_mundo]
				return
			if c.id < 0 or c.id >= criaturas_por_mundo:
				erro = "criatura #%d fora do bestiario (0..%d)" \
						% [c.id, criaturas_por_mundo - 1]
				return


## Traz um save antigo ate o formato corrente. Cada degrau e uma funcao propria,
## e eles se aplicam em cadeia — migrar 1->3 e rodar 1->2 e depois 2->3, nunca um
## salto que precise conhecer os dois extremos.
##
## Vazio hoje: so existe a versao 1. O lugar e que importa — a alternativa, que e
## espalhar `if versao < 2` pelos leitores de campo, e o que torna um formato
## impossivel de evoluir depois de alguns saves na rua.
static func _migrar(dados: Dictionary, de_versao: int) -> Dictionary:
	var d := dados.duplicate(true)
	if de_versao < 1:
		# Save sem campo "versao": so pode ter saido de um teste manual, mas
		# tratar como v1 e mais util que recusar.
		d["versao"] = 1
	return d


static func _ler_criaturas(lista: Variant) -> Array[CriaturaSalva]:
	var saida: Array[CriaturaSalva] = []
	if not (lista is Array):
		return saida
	for item: Variant in lista:
		if item is Dictionary:
			saida.append(CriaturaSalva.de_dicionario(item))
	return saida


static func _escrever_criaturas(lista: Array[CriaturaSalva]) -> Array:
	var saida: Array = []
	for c: CriaturaSalva in lista:
		saida.append(c.para_dicionario())
	return saida


## "1h 12m" / "4m". Sem segundos: o numero existe para o jogador reconhecer o
## slot, e segundo nenhum ajuda nisso.
func tempo_legivel() -> String:
	var minutos: int = int(tempo_jogado) / 60
	if minutos < 60:
		return "%dm" % minutos
	return "%dh %02dm" % [minutos / 60, minutos % 60]


## Como a seed aparece no cartao do slot: o texto digitado quando houve um,
## senao o numero.
func seed_legivel() -> String:
	return seed_texto if seed_texto != "" else str(seed_mundo)


## Houve uma posicao gravada? Falso numa partida recem-criada, que deve nascer
## no spawn declarado pelo mapa.
func tem_posicao() -> bool:
	return celula != CELULA_NAO_GRAVADA


func total_de_criaturas() -> int:
	return equipe.size() + armazenadas.size()


## Onde a partida parou, para o cartao do slot. Cai no id quando o nome nao foi
## gravado (save antigo) e em "Mundo" quando nem o id existe.
func lugar_legivel() -> String:
	if regiao_nome != "":
		return regiao_nome
	if regiao != "":
		return regiao.capitalize()
	return "Mundo"


## "02/10 19:40" a partir do carimbo ISO. Devolve "" se o carimbo nao tiver a
## forma esperada — um cartao sem data e melhor que um cartao com lixo.
func data_legivel() -> String:
	var partes := salvo_em.split(" ")
	if partes.size() < 2:
		return ""
	var ymd := partes[0].split("-")
	var hms := partes[1].split(":")
	if ymd.size() < 3 or hms.size() < 2:
		return ""
	return "%s/%s %s:%s" % [ymd[2], ymd[1], hms[0], hms[1]]
