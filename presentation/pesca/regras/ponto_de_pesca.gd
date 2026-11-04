class_name PontoDePesca
extends RefCounted

## Um ponto de pesca (o "FishingSpot" do pedido): um trecho de agua com habitat
## proprio — o lago da vila, a ribeira do Anselmo, o rio da fabrica.
##
## O bestiario muda com a seed, entao o ponto NAO pode listar criaturas fixas: uma
## lista de ids valeria para uma seed so. Ele declara PESOS por elemento e por
## animal, e os candidatos sao calculados sobre o bestiario da seed DEPOIS da
## geracao — a mesma logica de PontoDeEncontro.elementos_provaveis, aplicada a
## agua. A regiao muda QUEM se pesca ali; nunca COMO a criatura e gerada (as
## tabelas condicionais e o bestiario continuam identicos, RF03).
##
## `peso_fora` e o peso de quem tem elemento nao declarado. Maior que zero de
## proposito: sem ele o habitat viraria exclusividade e o sorteio viraria tabela —
## o mesmo papel de chance_fora_da_regiao no encontro.

var id: String = ""
var nome: String = ""
var regioes: PackedStringArray = PackedStringArray()
var elementos: Dictionary = {}
var animais: Dictionary = {}
var peso_fora: float = 1.0
## Multiplica a chance de surgimento por sorteio (rio animado > rio poluido).
var multiplicador_surgimento: float = 1.0


static func de_dicionario(d: Dictionary) -> PontoDePesca:
	var p := PontoDePesca.new()
	p.id = String(d.get("id", ""))
	p.nome = String(d.get("nome", p.id))
	var regs := PackedStringArray()
	for r: Variant in d.get("regioes", []):
		regs.append(String(r))
	p.regioes = regs
	p.elementos = _pesos(d.get("elementos", {}))
	p.animais = _pesos(d.get("animais", {}))
	p.peso_fora = float(d.get("peso_fora", 1.0))
	p.multiplicador_surgimento = float(d.get("multiplicador_surgimento", 1.0))
	return p


## Peso de um perfil neste ponto: o peso-base da criatura (raridade) vezes o
## habitat (elemento, ou `peso_fora` se nao declarado) vezes o animal (1 se nao
## declarado — animal nao listado e neutro, nao excluido).
func peso_de(perfil: PerfilPesca) -> float:
	if perfil == null or perfil.criatura == null:
		return 0.0
	var c := perfil.criatura
	return perfil.peso * float(elementos.get(c.elemento, peso_fora)) \
			* float(animais.get(c.animal_base, 1.0))


## Candidatos deste ponto: [{"perfil": PerfilPesca, "peso": float}], so peso > 0,
## na ORDEM dos perfis recebidos (a do bestiario). Ordem estavel e o que faz a
## roleta de `sortear` reproduzivel pela seed.
func candidatos(perfis: Array) -> Array:
	var lista: Array = []
	for item: Variant in perfis:
		var perfil := item as PerfilPesca
		if perfil == null:
			continue
		var w := peso_de(perfil)
		if w > 0.0:
			lista.append({"perfil": perfil, "peso": w})
	return lista


## Roleta sobre os candidatos. Consome EXATAMENTE 1 randf() do rng, com qualquer
## lista (vazia devolve null): recalibrar os PESOS de um ponto que ainda tem
## candidatos muda qual criatura sai, nunca quantos numeros a pesca consumiu.
## A garantia e so desta funcao: SimulacaoRecolhimento._tentar_surgir pula o
## ponto sem candidato nenhum ANTES de sortear, e chance_surgimento e
## multiplicador_surgimento decidem quantas roletas (e derivas) um lance faz.
static func sortear(candidatos_: Array, rng: RandomNumberGenerator) -> PerfilPesca:
	var r: float = rng.randf()
	var total: float = 0.0
	for c: Dictionary in candidatos_:
		total += maxf(float(c.get("peso", 0.0)), 0.0)
	if total <= 0.0:
		return null
	var alvo: float = r * total
	var acumulado: float = 0.0
	var ultimo: PerfilPesca = null
	for c: Dictionary in candidatos_:
		var w: float = maxf(float(c.get("peso", 0.0)), 0.0)
		if w <= 0.0:
			continue
		acumulado += w
		ultimo = c.get("perfil") as PerfilPesca
		if alvo < acumulado:
			return ultimo
	# Arredondamento de float pode deixar `alvo` um epsilon acima do acumulado.
	return ultimo


## O candidato de menor dificuldade(). Empate decidido pelo menor criatura.id,
## nunca pela ordem da lista: o monstro do tutorial de uma seed e sempre o mesmo.
static func mais_facil(candidatos_: Array) -> PerfilPesca:
	var melhor: PerfilPesca = null
	var melhor_d: float = INF
	for c: Dictionary in candidatos_:
		var p := c.get("perfil") as PerfilPesca
		if p == null:
			continue
		var d: float = p.dificuldade()
		if melhor == null or d < melhor_d - 1e-9 \
				or (absf(d - melhor_d) <= 1e-9 and _id(p) < _id(melhor)):
			melhor = p
			melhor_d = d
	return melhor


## Problemas do ponto contra o vocabulario canonico (JSON de data/vocabulary.json).
## Um elemento escrito errado aqui nao daria erro — daria um habitat que nunca
## atrai o que pretende, e e isso que esta verificacao pega.
func validar(vocabulario: Dictionary) -> PackedStringArray:
	var problemas := PackedStringArray()
	var prim: Dictionary = vocabulario.get("primarios", {})
	var vocab_e: Array = prim.get("elemento", [])
	var vocab_a: Array = prim.get("animal_base", [])
	var rotulo: String = id if id != "" else "(sem id)"
	if id == "":
		problemas.append("ponto sem id")
	for e: String in elementos:
		if not e in vocab_e:
			problemas.append("ponto '%s': elemento '%s' fora do vocabulario" % [rotulo, e])
		if float(elementos[e]) < 0.0:
			problemas.append("ponto '%s': peso negativo para '%s'" % [rotulo, e])
	for a: String in animais:
		if not a in vocab_a:
			problemas.append("ponto '%s': animal '%s' fora do vocabulario" % [rotulo, a])
		if float(animais[a]) < 0.0:
			problemas.append("ponto '%s': peso negativo para '%s'" % [rotulo, a])
	if peso_fora < 0.0:
		problemas.append("ponto '%s': peso_fora negativo" % rotulo)
	if multiplicador_surgimento <= 0.0:
		problemas.append("ponto '%s': multiplicador_surgimento tem de ser > 0" % rotulo)
	return problemas


static func _pesos(d: Variant) -> Dictionary:
	var saida: Dictionary = {}
	if d is Dictionary:
		for chave: Variant in d:
			if not String(chave).begins_with("_"):
				saida[String(chave)] = float(d[chave])
	return saida


static func _id(p: PerfilPesca) -> int:
	return p.criatura.id if p.criatura != null else -1
