extends SceneTree

## Teste da ECONOMIA e das LOJAS como dado, sem cena:
##   godot --headless --path . -s res://tools/test_economia.gd
##
## O jogo de ponta a ponta (comprar, ganhar gold, kit da Mirela) esta em test_arco.
## Aqui se confere que os arquivos dizem a mesma coisa entre si: toda loja vende
## item que existe e tem preco, todo vendedor existe e abre a sua loja no dialogo,
## a bolsa comeca so com ferramentas, e a recompensa cresce com a forca.

const ETAPAS := 4

var _falhas: int = 0
var _verificacoes: int = 0
var _etapas: int = 0


func _initialize() -> void:
	print("== Economia e lojas ==")
	var economia := TabelasEconomia.carregar()
	var captura := TabelasCaptura.carregar()
	var itens := CatalogoItens.carregar(captura)
	var lojas := CatalogoLojas.carregar()
	if _ok(economia.erro == "" and itens != null and lojas.erro == "", "dados carregaram"):
		_testar_lojas(economia, itens, lojas)
		_testar_carga_inicial(economia, itens)
		_testar_recompensa(economia)
		_testar_dialogos(lojas)
	print("\n==")
	if _etapas != ETAPAS:
		print("RESULTADO: O TESTE ABORTOU NO MEIO (%d de %d etapas)" % [_etapas, ETAPAS])
		quit(1)
	elif _falhas > 0:
		print("RESULTADO: %d VERIFICACAO(OES) FALHARAM" % _falhas)
		quit(1)
	else:
		print("RESULTADO: TODOS OS TESTES PASSARAM (%d)" % _verificacoes)
		quit(0)


func _ok(condicao: bool, rotulo: String, detalhe: String = "") -> bool:
	print("    %s %s%s" % ["OK  " if condicao else "FALHOU", rotulo,
			"" if detalhe == "" else "  — " + detalhe])
	_verificacoes += 1
	if not condicao:
		_falhas += 1
	return condicao


func _testar_lojas(economia: TabelasEconomia, itens: CatalogoItens, lojas: CatalogoLojas) -> void:
	print("\n1. Lojas")
	_ok(lojas.lojas.size() == 3, "3 lojas: vila, padaria e sitio")
	var problemas := PackedStringArray()
	var vendidos := {}
	for l: Dictionary in lojas.lojas:
		for id: String in l.get("itens", []):
			vendidos[id] = true
			if itens.item(id) == null:
				problemas.append("%s vende item inexistente %s" % [l["id"], id])
			elif economia.preco(id) <= 0:
				problemas.append("%s vende %s sem preco" % [l["id"], id])
	_ok(problemas.is_empty(), "toda loja vende item que existe e tem preco", ", ".join(problemas))
	var sem_loja := PackedStringArray()
	for d in captura_ids():
		if not vendidos.has(d):
			sem_loja.append(d)
	_ok(sem_loja.is_empty(), "todo dispositivo e toda isca sao vendidos em alguma loja",
			", ".join(sem_loja))
	_ok(vendidos.has("pocao_simples"), "pocao simples a venda")
	_etapas += 1


func captura_ids() -> Array:
	var c := TabelasCaptura.carregar()
	var ids: Array = []
	for i in (c.dispositivos as Array) + (c.iscas as Array):
		ids.append(i.id)
	return ids


func _testar_carga_inicial(economia: TabelasEconomia, itens: CatalogoItens) -> void:
	print("\n2. A bolsa comeca vazia de consumiveis")
	var carga := itens.quantidades_iniciais()
	var consumiveis := PackedStringArray()
	for id: String in carga:
		if not itens.item(id).permanente:
			consumiveis.append(id)
	_ok(consumiveis.is_empty(), "so ferramentas na carga inicial", ", ".join(consumiveis))
	_ok(economia.gold_inicial() > 0, "comeca com gold", "%d" % economia.gold_inicial())
	var kit := economia.kit_inicial()
	_ok(int(kit.get("esfera_simples", 0)) > 0 and int(kit.get("pocao_simples", 0)) > 0,
			"o kit da Mirela tem esfera e pocao", str(kit))
	var esfera := economia.preco("esfera_simples")
	_ok(economia.gold_inicial() >= esfera * 5, "o gold inicial compra ao menos 5 esferas simples",
			"%d de %d" % [economia.gold_inicial(), esfera * 5])
	_etapas += 1


func _testar_recompensa(economia: TabelasEconomia) -> void:
	print("\n3. Recompensa por derrotar selvagem")
	var fraca := economia.recompensa_selvagem(100.0)
	var forte := economia.recompensa_selvagem(220.0)
	_ok(forte > fraca, "criatura mais forte paga mais", "%d > %d" % [forte, fraca])
	_ok(fraca >= 1, "nunca paga zero")
	var guard: Dictionary = CatalogoGuardioes.carregar().por_id("dulce")
	_ok(int(guard.get("premio_gold", 0)) > forte * 3, "a guardia paga bem mais que um selvagem",
			"%d" % int(guard.get("premio_gold", 0)))
	_etapas += 1


func _testar_dialogos(lojas: CatalogoLojas) -> void:
	print("\n4. Cada vendedor abre a sua loja")
	var npcs: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://autoral/npcs/npcs.json"))
	var ids_npc := {}
	for n: Dictionary in npcs["npcs"]:
		ids_npc[n["id"]] = n["dialogo"]
	var problemas := PackedStringArray()
	for l: Dictionary in lojas.lojas:
		var npc := String(l.get("npc", ""))
		if not ids_npc.has(npc):
			problemas.append("loja %s: npc %s nao existe" % [l["id"], npc])
			continue
		var texto := FileAccess.get_file_as_string("res://autoral/dialogos/%s.json" % ids_npc[npc])
		if not texto.contains('"loja": "%s"' % l["id"]):
			problemas.append("dialogo de %s nao abre a loja %s" % [npc, l["id"]])
	_ok(problemas.is_empty(), "todo vendedor existe e o dialogo dele abre a loja dele",
			", ".join(problemas))
	_etapas += 1
