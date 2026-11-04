class_name ItemJogo
extends RefCounted

## A ficha de um item na bolsa: o que a interface precisa saber para desenhar e
## descrever QUALQUER item, venha ele de onde vier.
##
## POR QUE NAO E UMA SEGUNDA HIERARQUIA DE ITENS
## ---------------------------------------------
## O projeto ja tinha ItemCaptura, DispositivoCaptura e IscaCaptura, carregados
## de data/captura/*.json e consumidos por CalculoCaptura. Aquelas classes
## carregam MECANICA — multiplicador, eficacia por traco, tipos preferidos — e
## nao tem motivo para mudar.
##
## Esta classe nao as substitui: ela as ENVELOPA. Um dispositivo vira um ItemJogo
## cujo campo `captura` aponta para o DispositivoCaptura original. A bolsa passa
## a ter uma lista so, com categoria, descricao e icone para todos; o encontro
## continua falando com as classes de sempre, sem saber que a bolsa existe.
##
## A alternativa — declarar dispositivos e iscas de novo num catalogo proprio —
## daria dois arquivos descrevendo o mesmo item, e a primeira divergencia entre
## eles seria um bug silencioso de balanceamento.
##
## MARCADORES em vez de subclasses. "esta vara serve para pescar" e um marcador,
## nao um tipo: quem pergunta e o sistema de pesca, com `tem_marcador("pesca")`.
## Uma subclasse ItemDePesca obrigaria o catalogo a conhecer a pesca, e a bolsa a
## conhecer as duas — para responder a uma pergunta de uma palavra.

var id: String = ""
var nome: String = ""
var descricao: String = ""

## Chave de Categorias (ver catalogo_itens.gd). Define a aba da bolsa.
var categoria: String = ""

## Falso = cada unidade ocupa uma linha propria e a bolsa nao mostra "×N".
## A vara de pesca e o caso: ter duas varas nao e ter o dobro de nada.
var empilhavel: bool = true
var max_pilha: int = 99

## Itens que o jogador nao pode descartar nem gastar por engano (vara, chaves).
var permanente: bool = false

## O que o item FAZ quando usado. Declarativo: {"tipo": "curar", "valor": 30}.
## Quem interpreta e CalculoBatalha, na batalha e na bolsa.
var efeito: Dictionary = {}

## Etiquetas livres consultadas por outros sistemas ("pesca", "chave").
var marcadores: PackedStringArray = PackedStringArray()

var quantidade_inicial: int = 0

## Como o item aparece NA MAO do jogador quando equipado. Declarativo, como
## `efeito`: {"forma": "vara", "comprimento": 18.0, "cor": "8a5a3c"}. Quem
## interpreta e ItemNaMao (presentation/equipamento/) — este arquivo e regra e
## nao pode conhecer Node nenhum. "textura"/"cena" opcionais apontam a arte
## final; sem elas, o placeholder da forma e desenhado por codigo.
##
## Vazio = o item nao tem desenho de mao proprio, e ItemNaMao cai no icone da
## bolsa em escala pequena. E o que permite marcar qualquer item como
## equipamento sem desenhar nada antes.
var mao: Dictionary = {}

## O que o botao de usar faz com o item NA MAO. "pescar" liga a vara ao
## GerenciadorPesca; "" = o item so troca o sprite (lanterna, pa — por ora).
##
## String e nao enum pelo mesmo motivo dos marcadores: o catalogo nao pode
## conhecer a pesca. Quem pergunta `uso == "pescar"` e a pesca; um uso novo e
## uma string nova no JSON e um consumidor novo, sem mexer aqui.
var uso: String = ""

## O objeto de MECANICA, quando o item tem uma. null para poções e ferramentas.
## Preenchido pelo CatalogoItens a partir de TabelasCaptura.
var captura: ItemCaptura = null


static func de_dicionario(d: Dictionary, categoria_: String) -> ItemJogo:
	var i := ItemJogo.new()
	i.id = String(d.get("id", ""))
	i.nome = String(d.get("nome", i.id))
	i.descricao = String(d.get("descricao", ""))
	i.categoria = categoria_
	i.empilhavel = bool(d.get("empilhavel", true))
	i.max_pilha = int(d.get("max_pilha", 99))
	i.permanente = bool(d.get("permanente", false))
	i.efeito = d.get("efeito", {})
	i.quantidade_inicial = int(d.get("quantidade_inicial", 0))
	for m: String in d.get("marcadores", []):
		i.marcadores.append(m)
	# Checagem de tipo e nao `as Dictionary`: um "mao": "vara" escrito a mao no
	# JSON viraria null no cast e quebraria o item inteiro, quando o certo e so
	# perder o desenho (ItemNaMao cai no icone).
	var mao_bruta: Variant = d.get("mao", {})
	if mao_bruta is Dictionary:
		i.mao = (mao_bruta as Dictionary).duplicate(true)
	# Mesmo cuidado: String(3) nao e um construtor valido no GDScript 4, e um
	# "uso" numerico derrubaria a leitura do catalogo inteiro. Uso que nao e
	# texto vale "" — o item so troca o sprite, que e o menos surpreendente.
	var uso_bruto: Variant = d.get("uso", "")
	i.uso = String(uso_bruto) if uso_bruto is String else ""
	return i


## Envelopa um item de captura ja carregado por TabelasCaptura. Nome, descricao e
## quantidade inicial vem DE LA — este catalogo nao os redeclara.
static func de_captura(item: ItemCaptura, categoria_: String) -> ItemJogo:
	var i := ItemJogo.new()
	i.id = item.id
	i.nome = item.nome
	i.descricao = item.descricao
	i.categoria = categoria_
	i.quantidade_inicial = item.quantidade_inicial
	i.captura = item
	if item is IscaCaptura:
		# Toda isca de captura serve de isca de pesca. A pescaria nao precisa de
		# um segundo conjunto de iscas: o que ela consulta e o animal_base
		# preferido, que a IscaCaptura ja declara.
		i.marcadores.append("pesca")
	return i


func tem_marcador(m: String) -> bool:
	return m in marcadores


## Pode ir para a mao (e para a roda de itens)? E um marcador, nao um campo
## proprio: "equipamento" ja era a etiqueta da vara no catalogo, e um booleano
## novo declarando a mesma coisa divergiria dela no primeiro item esquecido.
func equipavel() -> bool:
	return tem_marcador("equipamento")


## Linha curta sob o nome, na lista da bolsa. Delega ao objeto de mecanica quando
## ha um: e ele que sabe dizer "bom vs asas" ou "preferida por canino", e a
## pergunta so faz sentido diante de uma criatura concreta.
func detalhe(criatura: Criatura = null) -> String:
	if captura != null:
		return captura.detalhe(criatura)
	if efeito.has("tipo"):
		return _detalhe_do_efeito()
	return ""


func _detalhe_do_efeito() -> String:
	match String(efeito.get("tipo", "")):
		"curar":
			return "recupera %d de vida" % int(efeito.get("valor", 0))
		"reviver":
			return "revive com %d%% da vida" % int(efeito.get("percentual", 50))
		_:
			return ""
