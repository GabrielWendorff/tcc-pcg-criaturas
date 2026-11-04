class_name TabelasPesca
extends RefCounted

## Carrega e expoe as tabelas da pesca: o perfil derivado (data/pesca/perfil.json)
## e os pontos de pesca (data/pesca/pontos.json).
##
## Espelha TabelasCaptura: fabrica estatica que devolve null com push_error, `erro`
## preenchido, validacao contra o vocabulario canonico. O motivo e o mesmo — os
## numeros que definem o comportamento sao DADO calibravel, nao codigo.
##
## O que NAO esta aqui: probabilidade de geracao. Estas tabelas nao participam do
## sorteio de nenhuma criatura; elas leem atributos ja sorteados. O modelo
## generativo do trabalho continua inteiro em data/*.json e procedural/creatures/.

const CAMINHO_PERFIL := "res://data/pesca/perfil.json"
const CAMINHO_PONTOS := "res://data/pesca/pontos.json"

## Campo de um eixo do perfil -> lista do vocabulario que nomeia suas chaves.
const _VOCAB_DO_CAMPO := {
	"por_animal": "animal", "por_elemento": "elemento",
	"por_porte": "porte", "por_traco": "traco",
}

var perfil: Dictionary = {}
var pontos: Array[PontoDePesca] = []
## Id do ponto usado por regiao que nenhum ponto declara (o sitio sem rio, a beira
## do mapa). Pescar sempre cai em ALGUM habitat, nunca em "nada".
var padrao: String = ""
var erro: String = ""

var _por_id: Dictionary = {}


## Fabrica: tabelas carregadas, ou null com push_error.
static func carregar(caminho_perfil: String = CAMINHO_PERFIL,
		caminho_pontos: String = CAMINHO_PONTOS) -> TabelasPesca:
	var t := TabelasPesca.new()
	if not t._carregar(caminho_perfil, caminho_pontos):
		push_error("TabelasPesca: falha ao carregar — " + t.erro)
		return null
	return t


func _carregar(caminho_perfil: String, caminho_pontos: String) -> bool:
	var p: Variant = _ler_json(caminho_perfil)
	if p == null:
		return false
	var q: Variant = _ler_json(caminho_pontos)
	if q == null:
		return false
	if not p is Dictionary or not p.has("elegibilidade"):
		erro = "perfil sem 'elegibilidade': " + caminho_perfil
		return false
	perfil = p
	if not q is Dictionary:
		erro = "pontos.json nao e um objeto: " + caminho_pontos
		return false
	for d: Variant in q.get("pontos", []):
		if not d is Dictionary:
			continue
		var ponto_ := PontoDePesca.de_dicionario(d)
		pontos.append(ponto_)
		_por_id[ponto_.id] = ponto_
	if pontos.is_empty():
		erro = "nenhum ponto declarado em " + caminho_pontos
		return false
	padrao = String(q.get("padrao", pontos[0].id))
	if not _por_id.has(padrao):
		erro = "ponto padrao '%s' nao existe" % padrao
		return false
	return true


func _ler_json(caminho: String) -> Variant:
	if not FileAccess.file_exists(caminho):
		erro = "arquivo inexistente: " + caminho
		return null
	var dados: Variant = JSON.parse_string(FileAccess.get_file_as_string(caminho))
	if dados == null:
		erro = "JSON invalido em: " + caminho
		return null
	return dados


## Perfis de pesca das criaturas ELEGIVEIS, na ordem do bestiario. E a lista que os
## pontos filtram — calculada uma vez por partida, depois da geracao.
func perfis_do_bestiario(bestiario: Array) -> Array:
	var lista: Array = []
	for item: Variant in bestiario:
		var c := item as Criatura
		if c != null and PerfilPesca.elegivel(c, perfil):
			lista.append(PerfilPesca.de_criatura(c, perfil))
	return lista


## Ponto que declara a regiao; se nenhum declara (ou a regiao e ""), o padrao.
func ponto_da_regiao(id_regiao: String) -> PontoDePesca:
	if id_regiao != "":
		for p in pontos:
			if id_regiao in p.regioes:
				return p
	return ponto(padrao)


func ponto(id: String) -> PontoDePesca:
	return _por_id.get(id) as PontoDePesca


## Problemas das tabelas contra o vocabulario canonico (JSON de
## data/vocabulary.json). Vazio = coerente. Como em TabelasCaptura.validar, uma
## chave fora do vocabulario nao da erro na engine: da uma contribuicao que nunca
## se aplica e um perfil silenciosamente diferente do que a tabela pretende.
func validar(vocabulario: Dictionary) -> PackedStringArray:
	var problemas := PackedStringArray()
	var prim: Dictionary = vocabulario.get("primarios", {})
	var der: Dictionary = vocabulario.get("derivados", {})
	var vocab := {
		"elemento": prim.get("elemento", []),
		"animal": prim.get("animal_base", []),
		"porte": der.get("porte", []),
		"traco": der.get("morfologia", []),
	}

	var eleg: Dictionary = perfil.get("elegibilidade", {})
	problemas.append_array(_conferir("elegibilidade.elementos",
			eleg.get("elementos", []), vocab["elemento"]))
	problemas.append_array(_conferir("elegibilidade.animais",
			eleg.get("animais", []), vocab["animal"]))

	for eixo: String in ["profundidade", "velocidade"]:
		var t: Dictionary = perfil.get(eixo, {})
		if t.is_empty():
			problemas.append("perfil sem o eixo '%s'" % eixo)
			continue
		for campo: String in ["por_animal", "por_elemento", "por_porte", "por_traco"]:
			problemas.append_array(_conferir("%s.%s" % [eixo, campo],
					t.get(campo, {}), vocab[_VOCAB_DO_CAMPO[campo]]))
		if float(t.get("minimo", 0.0)) >= float(t.get("maximo", 1.0)):
			problemas.append("%s: minimo >= maximo" % eixo)
		if float(t.get("variacao", 0.0)) < 0.0:
			problemas.append("%s: variacao negativa" % eixo)

	var tol: Dictionary = perfil.get("tolerancia", {})
	for campo: String in ["por_traco_profundidade", "por_traco_velocidade"]:
		problemas.append_array(_conferir("tolerancia." + campo,
				tol.get(campo, {}), vocab["traco"]))
	if float(tol.get("minimo", 0.0)) <= 0.0:
		problemas.append("tolerancia.minimo tem de ser > 0 (tolerancia zero = impossivel fisgar)")

	var pt: Dictionary = perfil.get("peso", {})
	problemas.append_array(_conferir("peso.por_porte", pt.get("por_porte", {}), vocab["porte"]))
	problemas.append_array(_conferir("peso.por_elemento",
			pt.get("por_elemento", {}), vocab["elemento"]))
	if float(pt.get("fator_por_traco", 1.0)) <= 0.0:
		problemas.append("peso.fator_por_traco tem de ser > 0")
	var faixas: Array = pt.get("raridade", [])
	if faixas.is_empty():
		problemas.append("peso.raridade vazia")
	var anterior: float = -INF
	for faixa: Dictionary in faixas:
		if String(faixa.get("id", "")) == "":
			problemas.append("peso.raridade: faixa sem id")
		var ate: float = float(faixa.get("peso_ate", 0.0))
		if ate <= anterior:
			problemas.append("peso.raridade: faixas fora de ordem crescente de peso_ate")
		anterior = ate

	var vistos: Dictionary = {}
	var dono_da_regiao: Dictionary = {}
	for p in pontos:
		if vistos.has(p.id):
			problemas.append("ponto '%s' declarado duas vezes" % p.id)
		vistos[p.id] = true
		for r: String in p.regioes:
			if dono_da_regiao.has(r):
				problemas.append("regiao '%s' declarada por '%s' e '%s' (ambigua)"
						% [r, dono_da_regiao[r], p.id])
			dono_da_regiao[r] = p.id
		problemas.append_array(p.validar(vocabulario))
	if ponto(padrao) == null:
		problemas.append("ponto padrao '%s' nao existe" % padrao)
	return problemas


## Chaves que nao estao no vocabulario. Devolve a lista em vez de receber uma por
## parametro: arrays empacotados sao copiados na passagem, e um append feito la
## dentro se perderia.
## `colecao` e uma lista de valores ou um dicionario (confere as chaves).
static func _conferir(onde: String, colecao: Variant, permitidas: Array) -> PackedStringArray:
	var fora := PackedStringArray()
	var chaves: Array = colecao.keys() if colecao is Dictionary else Array(colecao)
	for chave: Variant in chaves:
		if String(chave).begins_with("_"):
			continue
		if not chave in permitidas:
			fora.append("%s: '%s' fora do vocabulario" % [onde, chave])
	return fora
