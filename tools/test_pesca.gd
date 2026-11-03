extends SceneTree

## Teste headless das REGRAS da pesca — roda SEM abrir janela:
##   godot --headless --path . -s res://tools/test_pesca.gd
##
##   1. CONFIGURACAO: JSON aplicado chave a chave, padroes sem arquivo, JSON parcial,
##      extremos de velocidade/distancia e textos so com glifos da fonte pixel.
##   2. ESTADO: o ciclo pedido (OCIOSO -> ARREMESSO -> RECOLHENDO -> FISGADO|FALHOU
##      -> OCIOSO) e a recusa de toda transicao fora da tabela.
##   3. ARCO: vai-e-volta, zonas nos limites, angulo/ponto nas extremidades.
##   4. PERFIL E TABELAS sobre o bestiario da seed: determinismo, RF03 (calcular
##      perfis nao muda o bestiario), elegibilidade e a COERENCIA herdada do gerador
##      (RF04 virando mecanica) — com tabela de estatisticas para o artigo.
##   5. PONTO DE PESCA: pesos, candidatos, roleta (1 randf exato), mais facil e a
##      distribuicao empirica da roleta.
##   6. SIMULACAO: o minigame jogado por politicas (perfeita, errada, tutorial) a
##      delta fixo — e a verificacao da calibragem de data/pesca/configuracao.json.
##   7+. Reservado para a integracao (GerenciadorPesca, nos, tutorial).
##
## So usa classes de regras/ e do gerador. Nada de Bolsa/Save/Opcoes (autoloads
## nao existem sob -s) nem de nos de apresentacao.
##
## Sai com codigo != 0 se algo falhar.

const SEED := 123456789
const N := 100
const DT := 1.0 / 60.0
const ARQ_TEMP := "user://teste_pesca_configuracao.json"
const EPS := 1e-4

## Abaixo disto o teste abortou no meio (uma secao retornou cedo).
const MINIMO_VERIFICACOES := 115

## Chaves de texto que o contrato exige (GerenciadorPesca, InterfacePesca e o
## indicador "[F] PESCAR" leem estas).
const TEXTOS_OBRIGATORIOS := [
	"fisgou", "escapou", "recolhida", "cancelada", "sem_agua", "sem_vara",
	"zona_fraco", "zona_medio", "zona_maximo", "dica_arremesso", "dica_recolher",
	"rotulo_velocidade", "rotulo_interesse", "rotulo_altura_ok",
	"rotulo_velocidade_ok", "indicador_tecla", "indicador_texto",
]

var _falhas: int = 0
var _verificacoes: int = 0

# Compartilhado entre secoes: a 1 carrega a configuracao, a 4 o bestiario e as
# tabelas; a 5 e a 6 (e as secoes da integracao) reaproveitam.
var _cfg: ConfiguracaoPesca
var _tabelas_pesca: TabelasPesca
var _vocabulario: Dictionary = {}
var _bestiario: Array = []
## Perfis das criaturas ELEGIVEIS, na ordem do bestiario.
var _perfis: Array = []


func _initialize() -> void:
	print("== Pesca (regras) — teste headless ==")

	_testar_configuracao()
	_testar_estado()
	_testar_arco()
	_testar_perfis_e_tabelas()
	_testar_ponto()
	_testar_simulacao()
	# 7+. Secoes da integracao (GerenciadorPesca com geometria injetada, tutorial)
	# entram aqui, reaproveitando _cfg, _tabelas_pesca, _bestiario e _perfis.

	print("\n==")
	if _verificacoes < MINIMO_VERIFICACOES:
		print("RESULTADO: so %d verificacoes rodaram — o teste abortou no meio"
				% _verificacoes)
		quit(1)
	elif _falhas > 0:
		print("RESULTADO: %d VERIFICACAO(OES) FALHARAM" % _falhas)
		quit(1)
	else:
		print("RESULTADO: TODOS OS TESTES PASSARAM (%d verificacoes)" % _verificacoes)
		quit(0)


# ---------------------------------------------------------- 1. configuracao

func _testar_configuracao() -> void:
	print("\n-- 1. ConfiguracaoPesca")
	var padrao := ConfiguracaoPesca.new()

	var sem := ConfiguracaoPesca.carregar("res://data/pesca/nao_existe.json")
	_ok(sem != null, "sem arquivo, carregar() nao devolve null")
	_ok(sem != null and sem.velocidade_max == padrao.velocidade_max
			and sem.chance_surgimento == padrao.chance_surgimento
			and sem.texto("fisgou") == padrao.texto("fisgou"),
			"sem arquivo, valem os padroes embutidos")

	_cfg = ConfiguracaoPesca.carregar()
	var bruto: Variant = JSON.parse_string(
			FileAccess.get_file_as_string(ConfiguracaoPesca.CAMINHO))
	_ok(bruto is Dictionary, "data/pesca/configuracao.json existe e e JSON valido")
	if not bruto is Dictionary:
		return
	var faltando := PackedStringArray()
	var divergentes := PackedStringArray()
	for secao: String in ConfiguracaoPesca.SECOES:
		var sec: Dictionary = bruto.get(secao, {})
		for chave: String in ConfiguracaoPesca.SECOES[secao]:
			if not sec.has(chave):
				faltando.append("%s.%s" % [secao, chave])
			elif not _iguais(_cfg.get(chave), sec[chave]):
				divergentes.append("%s.%s" % [secao, chave])
	_ok(faltando.is_empty(), "o JSON declara toda variavel da configuracao",
			", ".join(faltando))
	_ok(divergentes.is_empty(), "cada chave do JSON chega a variavel de mesmo nome",
			", ".join(divergentes))
	_ok(_cfg.validar().is_empty(), "a calibragem do JSON e coerente",
			"; ".join(_cfg.validar()))
	_ok(padrao.validar().is_empty(), "os padroes embutidos sao coerentes",
			"; ".join(padrao.validar()))

	# Extremos: a normalizacao e presa a 0..1 dos dois lados.
	_ok(is_equal_approx(_cfg.velocidade_real(0.0), _cfg.velocidade_min)
			and is_equal_approx(_cfg.velocidade_real(1.0), _cfg.velocidade_max),
			"velocidade_real: 0 = minima, 1 = maxima")
	_ok(is_equal_approx(_cfg.velocidade_real(-3.0), _cfg.velocidade_min)
			and is_equal_approx(_cfg.velocidade_real(9.0), _cfg.velocidade_max),
			"velocidade_real: fora de 0..1 e presa aos extremos")
	_ok(is_equal_approx(_cfg.velocidade_real(0.5),
			(_cfg.velocidade_min + _cfg.velocidade_max) * 0.5),
			"velocidade_real: 0.5 = media (lerp linear)")
	_ok(is_equal_approx(_cfg.distancia_de_forca(0.0), _cfg.distancia_min_celulas)
			and is_equal_approx(_cfg.distancia_de_forca(1.0), _cfg.distancia_max_celulas),
			"distancia_de_forca: 0 = minima, 1 = maxima")
	_ok(is_equal_approx(_cfg.distancia_de_forca(-1.0), _cfg.distancia_min_celulas)
			and is_equal_approx(_cfg.distancia_de_forca(2.0), _cfg.distancia_max_celulas),
			"distancia_de_forca: fora de 0..1 e presa aos extremos")

	# JSON parcial: sobrescreve so o que declara, o resto fica no padrao.
	_escrever(ARQ_TEMP, JSON.stringify({
		"recolhimento": {"velocidade_max": 3.0},
		"deriva": {"deriva_ativa": false},
		"textos": {"fisgou": "PEGOU!"},
	}))
	var parcial := ConfiguracaoPesca.carregar(ARQ_TEMP)
	_ok(parcial.velocidade_max == 3.0 and parcial.velocidade_min == padrao.velocidade_min,
			"JSON parcial sobrescreve so o que declara")
	_ok(parcial.deriva_ativa == false, "booleano do JSON chega como bool")
	_ok(parcial.texto("fisgou") == "PEGOU!"
			and parcial.texto("escapou") == padrao.texto("escapou"),
			"textos sobrescritos chave a chave, os outros continuam")
	_escrever(ARQ_TEMP, "{ isto nao e json")
	var invalido := ConfiguracaoPesca.carregar(ARQ_TEMP)
	_ok(invalido != null and invalido.velocidade_max == padrao.velocidade_max,
			"JSON invalido cai nos padroes em vez de quebrar")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(ARQ_TEMP))

	_ok(_cfg.texto("chave_que_nao_existe") == "chave_que_nao_existe",
			"texto ausente aparece como a propria chave (visivel na tela)")
	var sem_texto := PackedStringArray()
	for chave: String in TEXTOS_OBRIGATORIOS:
		if not _cfg.textos.has(chave) or not padrao.textos.has(chave):
			sem_texto.append(chave)
	_ok(sem_texto.is_empty(), "toda chave de texto do contrato existe (JSON e padrao)",
			", ".join(sem_texto))
	_ok(_cfg.texto("indicador_tecla") == "[F]" and _cfg.texto("indicador_texto") == "PESCAR",
			"indicador de interacao: [F] PESCAR")

	var amostra: Array = []
	amostra.append_array(_cfg.textos.values())
	amostra.append_array(padrao.textos.values())
	var sem_glifo := _glifos_faltando(amostra)
	_ok(sem_glifo == "", "a fonte pixel cobre todo texto da pesca", sem_glifo)


# ---------------------------------------------------------------- 2. estado

func _testar_estado() -> void:
	print("\n-- 2. EstadoPesca")
	var E := EstadoPesca.Estado
	var est := EstadoPesca.new()
	var mudancas: Array = []
	est.mudou.connect(func(a: EstadoPesca.Estado, b: EstadoPesca.Estado) -> void:
		mudancas.append([a, b]))

	_ok(est.e(E.OCIOSO) and not est.ativa(), "comeca OCIOSO e inativa")
	_ok(est.mudar_para(E.ARREMESSO) and est.ativa(), "OCIOSO -> ARREMESSO (ativa)")
	_ok(est.mudar_para(E.RECOLHENDO), "ARREMESSO -> RECOLHENDO")
	_ok(est.mudar_para(E.FISGADO), "RECOLHENDO -> FISGADO")
	_ok(est.mudar_para(E.OCIOSO) and not est.ativa(), "FISGADO -> OCIOSO (inativa)")
	_ok(mudancas.size() == 4 and mudancas[0] == [E.OCIOSO, E.ARREMESSO]
			and mudancas[3] == [E.FISGADO, E.OCIOSO],
			"mudou e emitido a cada transicao, com anterior e atual")

	_ok(est.mudar_para(E.ARREMESSO) and est.mudar_para(E.FALHOU)
			and est.mudar_para(E.OCIOSO), "cancelar no arco: ARREMESSO -> FALHOU -> OCIOSO")
	est.mudar_para(E.ARREMESSO)
	est.mudar_para(E.RECOLHENDO)
	_ok(est.mudar_para(E.FALHOU), "RECOLHENDO -> FALHOU (fugiu, recolhida, cancelada)")
	est.mudar_para(E.OCIOSO)

	mudancas.clear()
	_ok(not est.mudar_para(E.RECOLHENDO) and est.e(E.OCIOSO),
			"OCIOSO -> RECOLHENDO recusada (nao se recolhe sem arremessar)")
	_ok(not est.mudar_para(E.FISGADO) and est.e(E.OCIOSO),
			"OCIOSO -> FISGADO recusada")
	est.mudar_para(E.ARREMESSO)
	est.mudar_para(E.RECOLHENDO)
	est.mudar_para(E.FISGADO)
	_ok(not est.mudar_para(E.FALHOU) and est.e(E.FISGADO),
			"FISGADO -> FALHOU recusada (cancelar depois da fisgada nao desfaz)")
	_ok(mudancas.size() == 3, "transicao recusada nao emite mudou")

	# Varredura completa contra a tabela: 25 pares. A consulta (pode_ir_para) cobre
	# todos; mudar_para so e chamado nos validos — os invalidos ja foram exercitados
	# acima, e chama-los aqui so encheria o console de avisos.
	var erradas := PackedStringArray()
	for a: int in E.values():
		for b: int in E.values():
			var ea := a as EstadoPesca.Estado
			var eb := b as EstadoPesca.Estado
			est.atual = ea
			var na_tabela: bool = b in EstadoPesca.TRANSICOES[a]
			var ok_par: bool = est.pode_ir_para(eb) == na_tabela
			if na_tabela or a == b:
				ok_par = ok_par and est.mudar_para(eb) and est.atual == eb
			if not ok_par:
				erradas.append("%s->%s" % [EstadoPesca.nome(ea), EstadoPesca.nome(eb)])
	_ok(erradas.is_empty(), "as 25 transicoes batem exatamente com TRANSICOES",
			", ".join(erradas))

	est.atual = E.RECOLHENDO
	mudancas.clear()
	est.reiniciar()
	_ok(est.e(E.OCIOSO) and mudancas.size() == 1, "reiniciar de qualquer estado volta a OCIOSO")
	est.reiniciar()
	_ok(mudancas.size() == 1, "reiniciar em OCIOSO nao emite nada")
	_ok(EstadoPesca.nome(E.FISGADO) == "FISGADO", "nome() legivel para depuracao")


# ------------------------------------------------------------------ 3. arco

func _testar_arco() -> void:
	print("\n-- 3. ArcoDeForca")
	var v: float = _cfg.arco_velocidade
	_ok(is_equal_approx(ArcoDeForca.pingpong(0.0, v), 0.0), "t = 0: ponteiro na esquerda")
	_ok(is_equal_approx(ArcoDeForca.pingpong(0.5 / v, v), 0.5), "meio da ida: 0.5")
	_ok(is_equal_approx(ArcoDeForca.pingpong(1.0 / v, v), 1.0),
			"meio do ciclo (1/velocidade): ponta direita")
	_ok(is_equal_approx(ArcoDeForca.pingpong(1.5 / v, v), 0.5), "na volta passa de novo por 0.5")
	_ok(absf(ArcoDeForca.pingpong(2.0 / v, v)) < EPS, "fim do ciclo: de volta a esquerda")
	var subindo := true
	var descendo := true
	var dentro := true
	for i in 60:
		var t1: float = (float(i) / 60.0) / v
		var t2: float = (float(i + 1) / 60.0) / v
		subindo = subindo and ArcoDeForca.pingpong(t2, v) > ArcoDeForca.pingpong(t1, v)
		descendo = descendo and ArcoDeForca.pingpong(t2 + 1.0 / v, v) \
				< ArcoDeForca.pingpong(t1 + 1.0 / v, v)
	for i in 500:
		var valor := ArcoDeForca.pingpong(float(i) * 0.037, v)
		dentro = dentro and valor >= 0.0 and valor <= 1.0
	_ok(subindo and descendo, "sobe na ida e desce na volta, sem saltos")
	_ok(dentro, "o valor nunca sai de 0..1")
	_ok(ArcoDeForca.pingpong(3.0, 0.0) == 0.0, "velocidade 0 deixa o ponteiro parado")

	var lv: float = _cfg.limite_verde
	var la: float = _cfg.limite_amarelo
	_ok(ArcoDeForca.zona(0.0, lv, la) == "fraco"
			and ArcoDeForca.zona(lv - 0.001, lv, la) == "fraco", "abaixo do verde: fraco")
	_ok(ArcoDeForca.zona(lv, lv, la) == "medio"
			and ArcoDeForca.zona(la - 0.001, lv, la) == "medio",
			"o limite verde ja e medio (limite pertence a zona seguinte)")
	_ok(ArcoDeForca.zona(la, lv, la) == "maximo"
			and ArcoDeForca.zona(1.0, lv, la) == "maximo", "do amarelo em diante: maximo")

	_ok(is_equal_approx(ArcoDeForca.angulo(0.0), PI)
			and is_equal_approx(ArcoDeForca.angulo(0.5), PI * 1.5)
			and is_equal_approx(ArcoDeForca.angulo(1.0), TAU),
			"angulo: PI (esquerda), 3PI/2 (topo), 2PI (direita)")
	var c := Vector2(100.0, 80.0)
	var r: float = _cfg.arco_raio
	_ok(ArcoDeForca.ponto(c, r, 0.0).is_equal_approx(c + Vector2(-r, 0.0)),
			"ponto(0) na ponta esquerda")
	_ok(ArcoDeForca.ponto(c, r, 1.0).is_equal_approx(c + Vector2(r, 0.0)),
			"ponto(1) na ponta direita")
	_ok(ArcoDeForca.ponto(c, r, 0.5).is_equal_approx(c + Vector2(0.0, -r)),
			"ponto(0.5) no topo (y da tela para baixo)")
	_ok(ArcoDeForca.ponto(c, r, -2.0).is_equal_approx(ArcoDeForca.ponto(c, r, 0.0)),
			"valor fora do arco e preso a ele")


# ---------------------------------------------------- 4. perfis e tabelas

func _testar_perfis_e_tabelas() -> void:
	print("\n-- 4. PerfilPesca e TabelasPesca (seed %d, %d criaturas)" % [SEED, N])
	var tabelas := TabelasProbabilidade.carregar()
	if tabelas == null:
		_ok(false, "tabelas de probabilidade carregaram")
		return
	var catalogo := CatalogoCorpos.carregar(tabelas)
	_bestiario = GeradorCriaturas.new(tabelas, catalogo).gerar_bestiario(SEED, N)
	_ok(_bestiario.size() == N, "bestiario de %d criaturas gerado" % N)
	var antes: Array = _dicts(_bestiario)

	_tabelas_pesca = TabelasPesca.carregar()
	_ok(_tabelas_pesca != null, "data/pesca/perfil.json e pontos.json carregaram")
	if _tabelas_pesca == null:
		return
	var voc: Variant = JSON.parse_string(
			FileAccess.get_file_as_string("res://data/vocabulary.json"))
	_vocabulario = voc if voc is Dictionary else {}
	var problemas := _tabelas_pesca.validar(_vocabulario)
	_ok(problemas.is_empty(), "tabelas de pesca coerentes com data/vocabulary.json",
			"; ".join(problemas))
	_ok(TabelasPesca.carregar("res://data/pesca/nao_existe.json") == null,
			"arquivo de perfil inexistente: carregar() devolve null (com erro no console)")

	var tab: Dictionary = _tabelas_pesca.perfil
	# Perfil de TODAS as criaturas (tambem as nao elegiveis): as comparacoes por
	# traco usam o bestiario inteiro, n maior.
	var todos: Array = []
	var deterministico := true
	for c: Criatura in _bestiario:
		var p1 := PerfilPesca.de_criatura(c, tab)
		var p2 := PerfilPesca.de_criatura(c, tab)
		deterministico = deterministico and p1.to_dict() == p2.to_dict()
		todos.append(p1)
	_ok(deterministico, "PerfilPesca e deterministico (mesma criatura, mesmo perfil)")
	_ok(PerfilPesca.de_criatura(null, tab) == null and not PerfilPesca.elegivel(null, tab),
			"criatura null: sem perfil e nao elegivel")

	# RF03: calcular perfis nao toca no bestiario nem no RNG do gerador.
	_ok(_dicts(_bestiario) == antes, "calcular perfis nao altera nenhuma criatura")
	var de_novo: Array = GeradorCriaturas.new(tabelas, catalogo).gerar_bestiario(SEED, N)
	_ok(_dicts(de_novo) == antes,
			"o bestiario regerado depois dos perfis e identico (RF03)")

	# Elegibilidade = regra exata do contrato.
	_perfis = _tabelas_pesca.perfis_do_bestiario(_bestiario)
	var ids_esperados: Array = []
	for c: Criatura in _bestiario:
		if c.elemento == "agua" or c.animal_base in ["peixe", "anfibio"]:
			ids_esperados.append(c.id)
	var ids_obtidos: Array = []
	for p: PerfilPesca in _perfis:
		ids_obtidos.append(p.criatura.id)
	_ok(ids_obtidos == ids_esperados,
			"elegiveis = elemento agua OU animal peixe/anfibio, na ordem do bestiario")
	_ok(_perfis.size() >= 10, "ha criaturas pescaveis suficientes (%d)" % _perfis.size())

	# Faixas declaradas respeitadas.
	var fora_da_faixa := PackedStringArray()
	var ids_raridade: Array = []
	for f: Dictionary in tab["peso"]["raridade"]:
		ids_raridade.append(String(f["id"]))
	for p: PerfilPesca in todos:
		if p.profundidade < float(tab["profundidade"]["minimo"]) - EPS \
				or p.profundidade > float(tab["profundidade"]["maximo"]) + EPS \
				or p.velocidade < float(tab["velocidade"]["minimo"]) - EPS \
				or p.velocidade > float(tab["velocidade"]["maximo"]) + EPS \
				or p.tolerancia_profundidade < float(tab["tolerancia"]["minimo"]) - EPS \
				or p.tolerancia_velocidade < float(tab["tolerancia"]["minimo"]) - EPS \
				or p.peso <= 0.0 or not p.raridade in ids_raridade:
			fora_da_faixa.append(str(p.criatura.id))
	_ok(fora_da_faixa.is_empty(), "todo perfil dentro das faixas da tabela",
			", ".join(fora_da_faixa))

	# --- Coerencia: RF04 virando mecanica ---
	var peixes: Array = _filtrar(_perfis, func(p: PerfilPesca) -> bool:
		return p.criatura.animal_base == "peixe")
	var anfibios: Array = _filtrar(_perfis, func(p: PerfilPesca) -> bool:
		return p.criatura.animal_base == "anfibio")
	_ok(not peixes.is_empty() and not anfibios.is_empty()
			and _media(peixes, "profundidade") > _media(anfibios, "profundidade"),
			"peixes elegiveis nadam mais fundo que anfibios (%.2f > %.2f)"
			% [_media(peixes, "profundidade"), _media(anfibios, "profundidade")])

	var com_nad: Array = _filtrar(todos, func(p: PerfilPesca) -> bool:
		return p.criatura.morfologia.get("nadadeiras", false))
	var sem_nad: Array = _filtrar(todos, func(p: PerfilPesca) -> bool:
		return not p.criatura.morfologia.get("nadadeiras", false))
	_ok(not com_nad.is_empty() and not sem_nad.is_empty()
			and _media(com_nad, "velocidade") > _media(sem_nad, "velocidade"),
			"com nadadeiras e mais rapido (%.2f > %.2f)"
			% [_media(com_nad, "velocidade"), _media(sem_nad, "velocidade")])
	_ok(_media(com_nad, "tolerancia_velocidade") < _media(sem_nad, "tolerancia_velocidade"),
			"com nadadeiras e mais escorregadio: menos folga de velocidade (%.3f < %.3f)"
			% [_media(com_nad, "tolerancia_velocidade"),
			_media(sem_nad, "tolerancia_velocidade")])
	# As escamas alargam a folga e compensam as nadadeiras: o mais escorregadio e
	# quem tem nadadeiras SEM escamas (tipicamente o anfibio), nao o peixe de agua.
	# E o que docs/mudancas-estruturais.md e o README da pesca afirmam.
	var nad_sem_esc: Array = _filtrar(com_nad, func(p: PerfilPesca) -> bool:
		return not p.criatura.morfologia.get("escamas", false))
	var nad_com_esc: Array = _filtrar(com_nad, func(p: PerfilPesca) -> bool:
		return p.criatura.morfologia.get("escamas", false))
	_ok(not nad_sem_esc.is_empty() and not nad_com_esc.is_empty()
			and _media(nad_sem_esc, "tolerancia_velocidade")
			< _media(nad_com_esc, "tolerancia_velocidade"),
			"nadadeiras sem escamas e o mais escorregadio (tol_v %.3f < %.3f com escamas)"
			% [_media(nad_sem_esc, "tolerancia_velocidade"),
			_media(nad_com_esc, "tolerancia_velocidade")])

	var densos: Array = _filtrar(todos, func(p: PerfilPesca) -> bool:
		return p.criatura.elemento in ["gelo", "sombra", "terra"])
	var leves: Array = _filtrar(todos, func(p: PerfilPesca) -> bool:
		return p.criatura.elemento in ["fogo", "ar", "eletrico"])
	_ok(_media(densos, "profundidade") > _media(leves, "profundidade"),
			"gelo/sombra/terra mais fundos que fogo/ar/eletrico (%.2f > %.2f)"
			% [_media(densos, "profundidade"), _media(leves, "profundidade")])
	var compactos: Array = _filtrar(todos, func(p: PerfilPesca) -> bool:
		return p.criatura.porte == "compacto")
	var esguios: Array = _filtrar(todos, func(p: PerfilPesca) -> bool:
		return p.criatura.porte in ["esbelto", "alongado"])
	_ok(_media(compactos, "velocidade") < _media(esguios, "velocidade"),
			"compacto mais lento que esbelto/alongado (%.2f < %.2f)"
			% [_media(compactos, "velocidade"), _media(esguios, "velocidade")])

	_imprimir_estatisticas(todos)

	# --- Pontos por regiao (ids de autoral/mapas/mundo.json) ---
	var tp := _tabelas_pesca
	_ok(tp.ponto_da_regiao("vila") != null and tp.ponto_da_regiao("vila").id == "lago_da_vila",
			"vila -> Lago da Vila")
	_ok(tp.ponto_da_regiao("ribeira").id == "ribeira", "ribeira -> Ribeira do Anselmo")
	_ok(tp.ponto_da_regiao("industrial").id == "rio_da_fabrica",
			"industrial -> Rio da Fabrica")
	_ok(tp.ponto_da_regiao("fazenda").id == tp.padrao,
			"fazenda (sem agua, sem ponto) -> ponto padrao")
	_ok(tp.ponto_da_regiao("").id == tp.padrao, "regiao vazia -> ponto padrao")
	_ok(tp.ponto("nao_existe") == null, "ponto() de id desconhecido devolve null")
	var nomes: Array = []
	for p in tp.pontos:
		nomes.append(p.nome)
	var sem_glifo := _glifos_faltando(nomes)
	_ok(sem_glifo == "", "a fonte pixel cobre os nomes dos pontos", sem_glifo)


func _imprimir_estatisticas(todos: Array) -> void:
	print("\n   Perfis de pesca — seed %d (material para o artigo)" % SEED)
	print("   elegiveis: %d de %d" % [_perfis.size(), N])
	# `dific` = media de PerfilPesca.dificuldade() (menor = mais facil): e a
	# metrica que escolhe o monstro do tutorial, e por ela se le quem e "dificil".
	print("   %-10s %3s %6s %6s %7s %7s %6s %6s" % ["animal", "n", "prof", "vel",
			"tol_p", "tol_v", "peso", "dific"])
	for animal: String in ["peixe", "anfibio", "gato", "ave", "reptil", "roedor",
			"inseto", "canino"]:
		var g: Array = _filtrar(_perfis, func(p: PerfilPesca) -> bool:
			return p.criatura.animal_base == animal)
		if not g.is_empty():
			print("   %-10s %3d %6.2f %6.2f %7.3f %7.3f %6.2f %6.2f" % [animal, g.size(),
					_media(g, "profundidade"), _media(g, "velocidade"),
					_media(g, "tolerancia_profundidade"),
					_media(g, "tolerancia_velocidade"), _media(g, "peso"),
					_media_dificuldade(g)])
	print("   %-10s %3s %6s %6s" % ["elemento", "n", "prof", "vel"])
	for elemento: String in ["agua", "gelo", "sombra", "terra", "planta", "fogo", "ar",
			"eletrico"]:
		var g: Array = _filtrar(_perfis, func(p: PerfilPesca) -> bool:
			return p.criatura.elemento == elemento)
		if not g.is_empty():
			print("   %-10s %3d %6.2f %6.2f" % [elemento, g.size(),
					_media(g, "profundidade"), _media(g, "velocidade")])
	var contagem: Dictionary = {}
	for p: PerfilPesca in _perfis:
		contagem[p.raridade] = int(contagem.get(p.raridade, 0)) + 1
	print("   raridade (elegiveis): %s" % str(contagem))
	var com: Array = _filtrar(todos, func(p: PerfilPesca) -> bool:
		return p.criatura.morfologia.get("nadadeiras", false))
	var sem: Array = _filtrar(todos, func(p: PerfilPesca) -> bool:
		return not p.criatura.morfologia.get("nadadeiras", false))
	print("   nadadeiras (bestiario inteiro): com n=%d vel=%.2f tol_v=%.3f | sem n=%d vel=%.2f tol_v=%.3f"
			% [com.size(), _media(com, "velocidade"), _media(com, "tolerancia_velocidade"),
			sem.size(), _media(sem, "velocidade"), _media(sem, "tolerancia_velocidade")])
	var com_e: Array = _filtrar(_perfis, func(p: PerfilPesca) -> bool:
		return p.criatura.morfologia.get("nadadeiras", false))
	var sem_e: Array = _filtrar(_perfis, func(p: PerfilPesca) -> bool:
		return not p.criatura.morfologia.get("nadadeiras", false))
	print("   nadadeiras (so elegiveis):      com n=%d vel=%.2f tol_v=%.3f | sem n=%d vel=%.2f tol_v=%.3f"
			% [com_e.size(), _media(com_e, "velocidade"), _media(com_e, "tolerancia_velocidade"),
			sem_e.size(), _media(sem_e, "velocidade"), _media(sem_e, "tolerancia_velocidade")])
	# Os contrastes de elemento e de porte verificados acima usam o bestiario
	# inteiro. Entre os pescaveis o animal os mascara (os fogo/eletrico elegiveis
	# sao peixes, os gelo sao anfibios): as duas versoes, para citar a certa.
	for versao: Array in [["bestiario inteiro", todos], ["so elegiveis", _perfis]]:
		var lista: Array = versao[1]
		var densos: Array = _filtrar(lista, func(p: PerfilPesca) -> bool:
			return p.criatura.elemento in ["gelo", "sombra", "terra"])
		var leves: Array = _filtrar(lista, func(p: PerfilPesca) -> bool:
			return p.criatura.elemento in ["fogo", "ar", "eletrico"])
		var compactos: Array = _filtrar(lista, func(p: PerfilPesca) -> bool:
			return p.criatura.porte == "compacto")
		var esguios: Array = _filtrar(lista, func(p: PerfilPesca) -> bool:
			return p.criatura.porte in ["esbelto", "alongado"])
		print("   %-18s prof gelo/sombra/terra x fogo/ar/eletrico: n=%d %.2f x n=%d %.2f | vel compacto x esbelto/alongado: n=%d %.2f x n=%d %.2f"
				% [versao[0] + ":", densos.size(), _media(densos, "profundidade"),
				leves.size(), _media(leves, "profundidade"), compactos.size(),
				_media(compactos, "velocidade"), esguios.size(),
				_media(esguios, "velocidade")])
	var nad_sem_esc_e: Array = _filtrar(com_e, func(p: PerfilPesca) -> bool:
		return not p.criatura.morfologia.get("escamas", false))
	var nad_com_esc_e: Array = _filtrar(com_e, func(p: PerfilPesca) -> bool:
		return p.criatura.morfologia.get("escamas", false))
	print("   nadadeiras (so elegiveis):      sem escamas n=%d tol_v=%.3f | com escamas n=%d tol_v=%.3f"
			% [nad_sem_esc_e.size(), _media(nad_sem_esc_e, "tolerancia_velocidade"),
			nad_com_esc_e.size(), _media(nad_com_esc_e, "tolerancia_velocidade")])
	# O monstro de ensino de cada ponto (o README da pesca cita o da ribeira).
	for ponto: PontoDePesca in _tabelas_pesca.pontos:
		var facil := PontoDePesca.mais_facil(ponto.candidatos(_perfis))
		print("   monstro do tutorial em %-16s %s" % [ponto.id + ":",
				"%s (%s, dificuldade %.2f)" % [facil.criatura.nome(),
				",".join(PackedStringArray(facil.criatura.features_presentes())),
				facil.dificuldade()] if facil != null else "nenhum"])
	print("   %-24s %-9s %-24s %5s %5s %5s %5s %5s %s" % ["criatura", "porte", "tracos",
			"prof", "vel", "tol_p", "tol_v", "peso", "raridade"])
	for p: PerfilPesca in _perfis:
		var c := p.criatura
		print("   %-24s %-9s %-24s %5.2f %5.2f %5.2f %5.2f %5.2f %s" % [c.nome(), c.porte,
				",".join(PackedStringArray(c.features_presentes())), p.profundidade,
				p.velocidade, p.tolerancia_profundidade, p.tolerancia_velocidade,
				p.peso, p.raridade])


# ----------------------------------------------------------- 5. ponto de pesca

func _testar_ponto() -> void:
	print("\n-- 5. PontoDePesca")
	var ponto := PontoDePesca.de_dicionario({
		"id": "teste", "nome": "Teste", "regioes": ["x"],
		"elementos": {"agua": 2.0, "fogo": 0.0},
		"animais": {"peixe": 3.0},
		"peso_fora": 0.5, "multiplicador_surgimento": 1.3,
	})
	_ok(ponto.id == "teste" and ponto.regioes == PackedStringArray(["x"])
			and is_equal_approx(ponto.multiplicador_surgimento, 1.3),
			"de_dicionario le id, regioes e multiplicador")

	var agua_peixe := _perfil_sintetico(1, "agua", "peixe", 1.0)
	var fogo_peixe := _perfil_sintetico(2, "fogo", "peixe", 1.0)
	var terra_peixe := _perfil_sintetico(3, "terra", "peixe", 1.0)
	var agua_gato := _perfil_sintetico(4, "agua", "gato", 1.0)
	var terra_gato := _perfil_sintetico(5, "terra", "gato", 1.0)
	var agua_peixe_raro := _perfil_sintetico(6, "agua", "peixe", 0.5)
	_ok(is_equal_approx(ponto.peso_de(agua_peixe), 6.0), "elemento e animal declarados: 2 x 3")
	_ok(is_equal_approx(ponto.peso_de(terra_peixe), 1.5),
			"elemento nao declarado usa peso_fora: 0.5 x 3")
	_ok(is_equal_approx(ponto.peso_de(agua_gato), 2.0), "animal nao declarado e neutro (x1)")
	_ok(is_equal_approx(ponto.peso_de(terra_gato), 0.5), "fora de tudo: so peso_fora")
	_ok(ponto.peso_de(fogo_peixe) == 0.0, "elemento declarado com 0 exclui")
	_ok(is_equal_approx(ponto.peso_de(agua_peixe_raro), 3.0),
			"o peso-base do perfil (raridade) multiplica o habitat")

	var cands: Array = ponto.candidatos([agua_peixe, fogo_peixe, terra_gato, agua_gato,
			null])
	var ids: Array = []
	for c: Dictionary in cands:
		ids.append((c["perfil"] as PerfilPesca).criatura.id)
	_ok(ids == [1, 5, 4], "candidatos: so peso > 0, na ordem dos perfis recebidos")
	_ok(ponto.candidatos([]).is_empty(), "sem perfis, sem candidatos")

	# Roleta consome EXATAMENTE 1 randf.
	var rng_a := RandomNumberGenerator.new()
	var rng_b := RandomNumberGenerator.new()
	rng_a.seed = 777
	rng_b.seed = 777
	PontoDePesca.sortear(cands, rng_a)
	rng_b.randf()
	_ok(rng_a.state == rng_b.state and rng_a.randf() == rng_b.randf(),
			"sortear consome exatamente 1 randf()")
	_ok(PontoDePesca.sortear([], rng_a) == null, "lista vazia: sortear devolve null")
	rng_b.randf()
	# So de sortear() isolado: a SimulacaoRecolhimento pula o ponto sem candidato
	# antes de sortear qualquer numero (ver _tentar_surgir).
	_ok(rng_a.state == rng_b.state,
			"sortear() isolado consome 1 randf tambem com lista vazia")

	# Mais facil: menor dificuldade, empate pelo menor id, independente da ordem.
	var facil := _perfil_sintetico(9, "agua", "peixe", 1.0, 0.5, 0.5, 0.20, 0.20)
	var gemeo := _perfil_sintetico(2, "agua", "peixe", 1.0, 0.5, 0.5, 0.20, 0.20)
	var dificil := _perfil_sintetico(1, "agua", "peixe", 1.0, 0.9, 0.9, 0.06, 0.06)
	var lista: Array = [{"perfil": dificil, "peso": 1.0}, {"perfil": facil, "peso": 1.0},
			{"perfil": gemeo, "peso": 1.0}]
	var invertida: Array = lista.duplicate()
	invertida.reverse()
	_ok(PontoDePesca.mais_facil(lista) == gemeo and PontoDePesca.mais_facil(invertida) == gemeo,
			"mais_facil: menor dificuldade, empate pelo menor criatura.id em qualquer ordem")
	_ok(PontoDePesca.mais_facil([]) == null, "mais_facil de lista vazia e null")
	_ok(dificil.dificuldade() > facil.dificuldade(),
			"dificuldade cresce com folga estreita e alvo nos extremos")

	# Distribuicao empirica da roleta.
	var pesos: Array = [1.0, 2.0, 7.0]
	var roleta: Array = []
	for i in pesos.size():
		roleta.append({"perfil": _perfil_sintetico(10 + i, "agua", "peixe", 1.0),
				"peso": pesos[i]})
	var contagem: Array = [0, 0, 0]
	var rng := RandomNumberGenerator.new()
	rng.seed = 2024
	for i in 2000:
		var p := PontoDePesca.sortear(roleta, rng)
		contagem[p.criatura.id - 10] += 1
	var desvio_max: float = 0.0
	for i in 3:
		desvio_max = maxf(desvio_max, absf(float(contagem[i]) / 2000.0 - pesos[i] / 10.0))
	print("   roleta 1:2:7 em 2000 sorteios -> %s (desvio maximo %.3f)" % [str(contagem), desvio_max])
	_ok(desvio_max < 0.04, "a roleta reproduz os pesos (desvio < 0.04 em 2000 sorteios)")

	var ruim := PontoDePesca.de_dicionario({"id": "ruim", "elementos": {"lava": 1.0},
			"animais": {"dragao": 1.0}, "peso_fora": -1.0})
	_ok(ruim.validar(_vocabulario).size() == 3,
			"validar acusa elemento, animal e peso_fora invalidos")

	# Os pontos reais sobre o bestiario da seed.
	for p in _tabelas_pesca.pontos:
		var cs: Array = p.candidatos(_perfis)
		var total: float = 0.0
		for c: Dictionary in cs:
			total += float(c["peso"])
		var top: Array = cs.duplicate()
		top.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return float(a["peso"]) > float(b["peso"]))
		var linha := PackedStringArray()
		for c: Dictionary in top.slice(0, 3):
			linha.append("%s %.0f%%" % [(c["perfil"] as PerfilPesca).criatura.nome(),
					100.0 * float(c["peso"]) / total])
		print("   %-16s %2d candidatos; mais provaveis: %s" % [p.id, cs.size(),
				", ".join(linha)])
	_ok(not _tabelas_pesca.ponto("ribeira").candidatos(_perfis).is_empty(),
			"a ribeira do Anselmo tem candidatos na seed de teste")


# ---------------------------------------------------------------- 6. simulacao

func _testar_simulacao() -> void:
	print("\n-- 6. SimulacaoRecolhimento (delta fixo 1/60 s)")
	if _perfis.is_empty() or _tabelas_pesca == null:
		_ok(false, "secao 4 preparou os perfis")
		return
	var ribeira := _tabelas_pesca.ponto("ribeira")
	var cands: Array = ribeira.candidatos(_perfis)

	# a) Politica perfeita fisga TODO perfil elegivel, com o arremesso maximo e a
	#    silhueta no 1o sorteio (multiplicador que leva a chance acima de 1).
	var mult_certo: float = 2.0 / maxf(_cfg.chance_surgimento, 0.001)
	var tempos: Array = []
	var nao_fisgados := PackedStringArray()
	var no_primeiro_sorteio := true
	for i in _perfis.size():
		var p: PerfilPesca = _perfis[i]
		var sim := SimulacaoRecolhimento.new(_cfg, _cfg.distancia_max_celulas,
				[{"perfil": p, "peso": 1.0}], _rng(SEED + i))
		sim.multiplicador_surgimento = mult_certo
		_rodar(sim, _politica_perfeita, 60.0)
		no_primeiro_sorteio = no_primeiro_sorteio \
				and absf(sim.tempo_surgimento - _cfg.atraso_minimo_surgimento) <= DT + EPS
		if sim.desfecho == SimulacaoRecolhimento.FISGADO:
			tempos.append(sim.tempo - sim.tempo_surgimento)
		else:
			nao_fisgados.append("%s (%s, vel %.2f)" % [p.criatura.nome(), sim.desfecho,
					p.velocidade])
	_ok(no_primeiro_sorteio, "com chance >= 1 a silhueta surge no 1o sorteio (atraso minimo)")
	_ok(nao_fisgados.is_empty(),
			"(a) politica perfeita fisga todo perfil elegivel (arremesso maximo)",
			", ".join(nao_fisgados))
	var media_fisgar: float = _media_simples(tempos)
	print("   politica perfeita: silhueta -> fisgado em %.2f s (min %.2f, max %.2f)"
			% [media_fisgar, tempos.min(), tempos.max()])
	_ok(media_fisgar >= 3.0 and media_fisgar <= 6.0,
			"calibragem: fisgar com a politica perfeita leva 3-6 s (%.2f)" % media_fisgar)

	# a2) Fluxo natural na ribeira, 300 arremessos maximos: a politica perfeita nunca
	#     deixa o monstro fugir; o que nao fisga e trajeto que acabou.
	var desfechos: Dictionary = {}
	var surgiram: int = 0
	for i in 300:
		var sim := SimulacaoRecolhimento.new(_cfg, _cfg.distancia_max_celulas, cands,
				_rng(SEED * 3 + i))
		sim.multiplicador_surgimento = ribeira.multiplicador_surgimento
		_rodar(sim, _politica_perfeita, 120.0)
		desfechos[sim.desfecho] = int(desfechos.get(sim.desfecho, 0)) + 1
		if sim.tempo_surgimento >= 0.0:
			surgiram += 1
	print("   ribeira, 300 arremessos maximos, politica perfeita: silhueta em %d%%, desfechos %s"
			% [roundi(100.0 * surgiram / 300.0), str(desfechos)])
	# So informativo: no arremesso medio sobra menos trajeto, e os peixes rapidos
	# deixam de caber — e o que torna a zona MAXIMA do arco desejavel.
	var no_medio: Dictionary = {}
	for i in 300:
		var sim := SimulacaoRecolhimento.new(_cfg, _cfg.distancia_de_forca(0.5), cands,
				_rng(SEED * 7 + i))
		sim.multiplicador_surgimento = ribeira.multiplicador_surgimento
		_rodar(sim, _politica_perfeita, 120.0)
		no_medio[sim.desfecho] = int(no_medio.get(sim.desfecho, 0)) + 1
	print("   ribeira, 300 arremessos medios, politica perfeita: desfechos %s" % str(no_medio))
	_ok(int(desfechos.get(SimulacaoRecolhimento.FUGIU, 0)) == 0,
			"politica perfeita nunca deixa o monstro fugir")
	_ok(int(desfechos.get(SimulacaoRecolhimento.FISGADO, 0)) >= 150,
			"politica perfeita fisga na maioria dos arremessos maximos")

	# Calibragem: "a silhueta costuma surgir 1-2 vezes num arremesso medio".
	var medio: float = _cfg.distancia_de_forca(0.5)
	var janela: float = (medio - _cfg.distancia_minima_para_surgir) / _cfg.velocidade_min
	var sorteios: int = 0
	if janela >= _cfg.atraso_minimo_surgimento:
		sorteios = int(floor((janela - _cfg.atraso_minimo_surgimento)
				/ _cfg.intervalo_surgimento)) + 1
	var esperadas: float = float(sorteios) * _cfg.chance_surgimento
	var viram: int = 0
	for i in 400:
		var sim := SimulacaoRecolhimento.new(_cfg, medio, cands, _rng(SEED * 5 + i))
		_rodar(sim, _politica_parada, 120.0)
		if sim.tempo_surgimento >= 0.0:
			viram += 1
	print("   arremesso medio (%.2f celulas) recolhido devagar: %d sorteios, %.2f silhuetas esperadas, viu ao menos uma em %d%%"
			% [medio, sorteios, esperadas, roundi(100.0 * viram / 400.0)])
	_ok(esperadas >= 1.0 and esperadas <= 2.0,
			"calibragem: 1-2 silhuetas esperadas num arremesso medio (%.2f)" % esperadas)

	# b) Politica errada com silhueta forcada: o monstro foge em inicial/perda s.
	var alvo := _perfil_sintetico(500, "agua", "peixe", 1.0, 0.75, 0.5, 0.12, 0.14)
	var sim_b := SimulacaoRecolhimento.new(_cfg, _cfg.distancia_max_celulas, cands, _rng(SEED))
	var surgidas: Array = []
	sim_b.silhueta_surgiu.connect(func(p: PerfilPesca) -> void: surgidas.append(p))
	sim_b.forcar_silhueta(alvo)
	_ok(surgidas.size() == 1 and sim_b.perfil == alvo
			and sim_b.interesse == _cfg.interesse_inicial,
			"forcar_silhueta: surge na hora, emite o sinal e comeca no interesse inicial")
	_rodar(sim_b, _politica_errada, 60.0)
	var t_fuga: float = _cfg.interesse_inicial / _cfg.interesse_perda
	print("   politica errada: fugiu em %.2f s (esperado %.2f s)" % [sim_b.tempo, t_fuga])
	_ok(sim_b.desfecho == SimulacaoRecolhimento.FUGIU and sim_b.perfil == alvo,
			"(b) politica errada: o monstro FOGE")
	_ok(absf(sim_b.tempo - t_fuga) <= 2.0 * DT, "foge em interesse_inicial/interesse_perda s")
	var nao_fugiram := PackedStringArray()
	for i in _perfis.size():
		var sim := SimulacaoRecolhimento.new(_cfg, _cfg.distancia_max_celulas, cands, _rng(i))
		sim.forcar_silhueta(_perfis[i])
		_rodar(sim, _politica_errada, 60.0)
		if sim.desfecho != SimulacaoRecolhimento.FUGIU:
			nao_fugiram.append("%s (%s)" % [(_perfis[i] as PerfilPesca).criatura.nome(),
					sim.desfecho])
	_ok(nao_fugiram.is_empty(), "politica errada faz todo perfil elegivel fugir",
			", ".join(nao_fugiram))

	# c) Sem candidatos, recolhendo no maximo: a isca volta vazia.
	var sim_c := SimulacaoRecolhimento.new(_cfg, _cfg.distancia_max_celulas, [], _rng(SEED))
	var terminos: Array = []
	sim_c.terminou.connect(func(d: String, p: PerfilPesca) -> void: terminos.append([d, p]))
	_rodar(sim_c, _politica_rapida, 60.0)
	print("   sem candidatos, velocidade maxima: %.1f celulas voltaram em %.2f s"
			% [_cfg.distancia_max_celulas, sim_c.tempo])
	_ok(sim_c.desfecho == SimulacaoRecolhimento.RECOLHIDA and terminos.size() == 1
			and terminos[0][1] == null and sim_c.distancia == 0.0,
			"(c) sem candidatos: RECOLHIDA, sem perfil, distancia zerada")
	_ok(sim_c.tempo >= 2.5 and sim_c.tempo <= 3.5,
			"calibragem: com velocidade_max, 7 celulas voltam em ~3 s (%.2f)" % sim_c.tempo)
	var sim_c2 := SimulacaoRecolhimento.new(_cfg, _cfg.distancia_minima_para_surgir, cands,
			_rng(SEED))
	sim_c2.multiplicador_surgimento = mult_certo
	_rodar(sim_c2, _politica_parada, 60.0)
	_ok(sim_c2.desfecho == SimulacaoRecolhimento.RECOLHIDA and sim_c2.tempo_surgimento < 0.0,
			"silhueta nao nasce com a isca a menos de distancia_minima_para_surgir")

	# d) Tutorial: errando por 60 s nada termina; acertando, fisga.
	var esperado := PontoDePesca.mais_facil(cands)
	var sim_d := SimulacaoRecolhimento.new(_cfg, _cfg.distancia_min_celulas, cands,
			_rng(SEED), true)
	var menor_interesse: float = INF
	var menor_distancia: float = INF
	var deriva_tutorial: float = 0.0
	for i in int(60.0 / DT):
		var e: Vector2 = _politica_errada(sim_d)
		sim_d.passo(DT, e.y, e.x)
		menor_distancia = minf(menor_distancia, sim_d.distancia)
		if sim_d.perfil != null:
			menor_interesse = minf(menor_interesse, sim_d.interesse)
			deriva_tutorial = maxf(deriva_tutorial,
					absf(sim_d.profundidade_monstro - sim_d.perfil.profundidade))
	_ok(sim_d.correndo(), "(d) tutorial, 60 s de politica errada: nao FUGIU nem RECOLHIDA")
	_ok(sim_d.perfil == esperado, "o monstro de ensino e o mais facil do ponto (%s)"
			% (esperado.criatura.nome() if esperado != null else "?"))
	_ok(absf(sim_d.tempo_surgimento - _cfg.tutorial_tempo_ate_silhueta) <= DT + EPS,
			"no tutorial a silhueta surge no tempo fixo, sem sorteio")
	_ok(menor_interesse >= _cfg.tutorial_interesse_minimo - EPS,
			"interesse nunca abaixo do piso do tutorial (%.1f)" % menor_interesse)
	_ok(menor_distancia >= _cfg.tutorial_distancia_minima - EPS,
			"a isca nunca chega ao fim no tutorial (%.2f celulas)" % menor_distancia)
	_ok(is_equal_approx(sim_d.tolerancia_profundidade(),
			esperado.tolerancia_profundidade * _cfg.tutorial_multiplicador_tolerancia)
			and is_equal_approx(sim_d.tolerancia_velocidade(),
			esperado.tolerancia_velocidade * _cfg.tutorial_multiplicador_tolerancia),
			"tolerancias efetivas multiplicadas no tutorial")
	_ok(deriva_tutorial < EPS, "sem deriva no tutorial: o monstro fica parado no perfil")
	var sim_d2 := SimulacaoRecolhimento.new(_cfg, _cfg.distancia_min_celulas, cands,
			_rng(SEED), true)
	_rodar(sim_d2, _politica_perfeita, 60.0)
	_ok(sim_d2.desfecho == SimulacaoRecolhimento.FISGADO,
			"tutorial com a politica perfeita: FISGADO (%.2f s apos a silhueta)"
			% (sim_d2.tempo - sim_d2.tempo_surgimento))
	var sim_d3 := SimulacaoRecolhimento.new(_cfg, _cfg.distancia_min_celulas, [],
			_rng(SEED), true, alvo)
	_rodar(sim_d3, _politica_perfeita, 60.0)
	_ok(sim_d3.desfecho == SimulacaoRecolhimento.FISGADO and sim_d3.perfil == alvo,
			"perfil_tutorial explicito tem prioridade (e dispensa candidatos)")

	# e) Determinismo (RF03): mesma seed + mesmas entradas = mesmo desfecho no mesmo tempo.
	var r1 := _jogar(SEED + 11, cands, _politica_perfeita)
	var r2 := _jogar(SEED + 11, cands, _politica_perfeita)
	_ok(r1 == r2, "(e) mesma seed e politica: mesmo desfecho, perfil e tempo %s" % str(r1))
	var r3 := _jogar(SEED + 12, cands, _politica_errada)
	var r4 := _jogar(SEED + 12, cands, _politica_errada)
	_ok(r3 == r4, "determinismo tambem com a politica errada %s" % str(r3))
	var variados: Dictionary = {}
	for i in 20:
		variados[str(_jogar(SEED + 100 + i, cands, _politica_perfeita))] = true
	_ok(variados.size() > 1, "seeds diferentes dao pescarias diferentes")

	# Deriva: liga e desliga sem mudar a sequencia do RNG.
	var cfg_sem := ConfiguracaoPesca.carregar()
	cfg_sem.deriva_ativa = false
	var rng_com := _rng(SEED + 21)
	var rng_sem := _rng(SEED + 21)
	var com := SimulacaoRecolhimento.new(_cfg, _cfg.distancia_max_celulas, cands, rng_com)
	var sem := SimulacaoRecolhimento.new(cfg_sem, _cfg.distancia_max_celulas, cands, rng_sem)
	com.forcar_silhueta(alvo)
	sem.forcar_silhueta(alvo)
	var faixa_com: Vector2 = Vector2(INF, -INF)
	var faixa_sem: Vector2 = Vector2(INF, -INF)
	for i in int(6.0 / DT):
		com.passo(DT, 0.5, 0.5)
		sem.passo(DT, 0.5, 0.5)
		faixa_com = Vector2(minf(faixa_com.x, com.profundidade_monstro),
				maxf(faixa_com.y, com.profundidade_monstro))
		faixa_sem = Vector2(minf(faixa_sem.x, sem.profundidade_monstro),
				maxf(faixa_sem.y, sem.profundidade_monstro))
	_ok(faixa_com.y - faixa_com.x > 0.02 and faixa_sem.y - faixa_sem.x < EPS,
			"deriva ligada move o monstro; desligada, ele fica no perfil")
	_ok(faixa_com.y - faixa_com.x <= 2.0 * _cfg.deriva_amplitude_profundidade + EPS,
			"a deriva respeita a amplitude declarada")
	_ok(rng_com.state == rng_sem.state,
			"ligar/desligar a deriva nao muda a sequencia do RNG da pesca")

	# f) `terminou` uma unica vez; passo() depois do fim nao muda nada.
	var sim_f := SimulacaoRecolhimento.new(_cfg, _cfg.distancia_max_celulas, cands, _rng(SEED))
	var emitidos: Array = []
	sim_f.terminou.connect(func(d: String, p: PerfilPesca) -> void: emitidos.append(d))
	sim_f.forcar_silhueta(alvo)
	_rodar(sim_f, _politica_perfeita, 60.0)
	var foto: Array = _foto(sim_f)
	for i in 30:
		sim_f.passo(DT, 0.9, 0.0)
	sim_f.forcar_silhueta(esperado)
	_ok(sim_f.desfecho == SimulacaoRecolhimento.FISGADO and emitidos == [sim_f.desfecho],
			"(f) terminou e emitido uma unica vez")
	_ok(_foto(sim_f) == foto and sim_f.perfil == alvo and not sim_f.correndo(),
			"passo() e forcar_silhueta() depois do fim nao mudam nada")


# ----------------------------------------------------------------- politicas

## Antes da silhueta: recolhe devagar (x = 1) a meia agua. Depois: copia o monstro.
func _politica_perfeita(sim: SimulacaoRecolhimento) -> Vector2:
	if sim.perfil == null:
		return Vector2(1.0, 0.5)
	return Vector2(1.0 - sim.velocidade_monstro, sim.profundidade_monstro)


## Recolhe devagar na altura OPOSTA a do monstro: nunca as duas tolerancias juntas.
func _politica_errada(sim: SimulacaoRecolhimento) -> Vector2:
	if sim.perfil == null:
		return Vector2(1.0, 0.5)
	var alvo: float = sim.cfg.profundidade_min if sim.profundidade_monstro >= 0.5 \
			else sim.cfg.profundidade_max
	return Vector2(1.0, alvo)


## Recolhe o mais rapido possivel (mouse na borda esquerda).
func _politica_rapida(_sim: SimulacaoRecolhimento) -> Vector2:
	return Vector2(0.0, 0.5)


## Recolhe o mais devagar possivel e ignora a silhueta: mede so o surgimento.
func _politica_parada(_sim: SimulacaoRecolhimento) -> Vector2:
	return Vector2(1.0, 0.5)


func _rodar(sim: SimulacaoRecolhimento, politica: Callable, limite_s: float) -> void:
	for i in int(ceil(limite_s / DT)):
		if not sim.correndo():
			return
		var e: Vector2 = politica.call(sim)
		sim.passo(DT, e.y, e.x)


## Joga um arremesso maximo na ribeira e resume o resultado em dado comparavel.
func _jogar(semente: int, cands: Array, politica: Callable) -> Array:
	var sim := SimulacaoRecolhimento.new(_cfg, _cfg.distancia_max_celulas, cands,
			_rng(semente))
	_rodar(sim, politica, 120.0)
	var id: int = sim.perfil.criatura.id if sim.perfil != null else -1
	return [sim.desfecho, id, sim.tempo, sim.tempo_surgimento]


func _foto(sim: SimulacaoRecolhimento) -> Array:
	return [sim.tempo, sim.distancia, sim.profundidade, sim.velocidade,
			sim.velocidade_real, sim.interesse, sim.afastamento_silhueta,
			sim.profundidade_monstro, sim.velocidade_monstro, sim.desfecho]


# --------------------------------------------------------------- utilitarios

func _rng(semente: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = semente
	return r


func _perfil_sintetico(id: int, elemento: String, animal: String, peso: float,
		profundidade: float = 0.5, velocidade: float = 0.5,
		tol_p: float = 0.12, tol_v: float = 0.14) -> PerfilPesca:
	var c := Criatura.new()
	c.id = id
	c.elemento = elemento
	c.animal_base = animal
	c.porte = "medio"
	c.morfologia = {"garras": false, "escamas": false, "asas": false, "nadadeiras": false}
	var p := PerfilPesca.new()
	p.criatura = c
	p.peso = peso
	p.profundidade = profundidade
	p.velocidade = velocidade
	p.tolerancia_profundidade = tol_p
	p.tolerancia_velocidade = tol_v
	return p


func _dicts(bestiario: Array) -> Array:
	var saida: Array = []
	for c: Criatura in bestiario:
		saida.append(c.to_dict())
	return saida


func _filtrar(lista: Array, criterio: Callable) -> Array:
	var saida: Array = []
	for item: Variant in lista:
		if criterio.call(item):
			saida.append(item)
	return saida


func _media(perfis: Array, campo: String) -> float:
	if perfis.is_empty():
		return 0.0
	var s: float = 0.0
	for p: PerfilPesca in perfis:
		s += float(p.get(campo))
	return s / float(perfis.size())


## dificuldade() e metodo, nao campo: _media (que usa get) nao a alcanca.
func _media_dificuldade(perfis: Array) -> float:
	if perfis.is_empty():
		return 0.0
	var s: float = 0.0
	for p: PerfilPesca in perfis:
		s += p.dificuldade()
	return s / float(perfis.size())


func _media_simples(valores: Array) -> float:
	if valores.is_empty():
		return 0.0
	var s: float = 0.0
	for v: Variant in valores:
		s += float(v)
	return s / float(valores.size())


## Compara o valor de uma variavel com o do JSON (que traz todo numero como float).
func _iguais(atual: Variant, do_json: Variant) -> bool:
	match typeof(atual):
		TYPE_BOOL:
			return atual == bool(do_json)
		TYPE_FLOAT, TYPE_INT:
			return is_equal_approx(float(atual), float(do_json))
	return atual == do_json


func _glifos_faltando(textos: Array) -> String:
	var fonte := TemaEncontro.fonte()
	if fonte == null:
		return "(fonte pixel nao carregou)"
	var faltando := PackedStringArray()
	for t: Variant in textos:
		var s := String(t)
		for i in s.length():
			var ch: String = s[i]
			if ch == "\n":
				continue
			if not fonte.has_char(ch.unicode_at(0)) and not ch in faltando:
				faltando.append(ch)
	return "".join(faltando)


func _escrever(caminho: String, conteudo: String) -> void:
	var f := FileAccess.open(caminho, FileAccess.WRITE)
	if f != null:
		f.store_string(conteudo)
		f.close()


func _ok(condicao: bool, descricao: String, detalhe: String = "") -> void:
	_verificacoes += 1
	if condicao:
		print("   ok   " + descricao)
	else:
		_falhas += 1
		print("  FALHA " + descricao + ("  [" + detalhe + "]" if detalhe != "" else ""))
