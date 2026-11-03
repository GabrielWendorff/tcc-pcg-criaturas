class_name ConfiguracaoPesca
extends RefCounted

## Todos os numeros da pesca — deteccao de agua, arco de forca, recolhimento,
## surgimento da silhueta, interesse, deriva, tutorial e textos — em um lugar so.
##
## Espelha ConfiguracaoEncontro: cada valor tem PADRAO EMBUTIDO e e sobrescrito por
## res://data/pesca/configuracao.json quando ele existe. Um arquivo ausente ou
## incompleto degrada o ajuste fino, nunca o funcionamento — perder a amplitude da
## deriva nao pode impedir o jogador de pescar.
##
## Os padroes abaixo SAO a calibragem atual (iguais ao JSON). Assim o jogo sem o
## arquivo continua com a mesma sensacao, e o JSON e o lugar de mexer sem recompilar.
##
## Nenhum destes numeros deve reaparecer como literal em gerenciador_pesca.gd,
## medidor_arremesso.gd, minigame_recolhimento.gd ou simulacao_recolhimento.gd.
##
## O JSON usa como chave o PROPRIO NOME da variavel, agrupado por secao. Isso torna
## o mapeamento 1:1 verificavel por codigo (SECOES) em vez de por disciplina: uma
## chave digitada errado na calibragem vira aviso, nao um ajuste que some calado.

const CAMINHO := "res://data/pesca/configuracao.json"

## Secao do JSON -> variaveis que ela pode sobrescrever. E a especificacao
## executavel do formato do arquivo; `textos` e tratado a parte (e um dicionario).
const SECOES := {
	"deteccao": ["alcance_agua_celulas", "passo_sonda_px"],
	"arremesso": ["arco_velocidade", "arco_raio", "arco_espessura", "arco_atraso_trava",
			"limite_verde", "limite_amarelo", "distancia_min_celulas",
			"distancia_max_celulas", "duracao_voo"],
	"recolhimento": ["profundidade_min", "profundidade_max", "profundidade_inicial",
			"suavidade_profundidade", "suavidade_velocidade", "velocidade_min",
			"velocidade_max"],
	"surgimento": ["intervalo_surgimento", "chance_surgimento",
			"atraso_minimo_surgimento", "distancia_minima_para_surgir"],
	"interesse": ["interesse_inicial", "interesse_ganho", "interesse_perda",
			"interesse_alvo"],
	"deriva": ["deriva_ativa", "deriva_amplitude_profundidade",
			"deriva_amplitude_velocidade", "deriva_periodo_min", "deriva_periodo_max"],
	"silhueta": ["silhueta_distancia_longe", "silhueta_distancia_perto",
			"silhueta_suavidade"],
	"tutorial": ["tutorial_multiplicador_tolerancia", "tutorial_tempo_ate_silhueta",
			"tutorial_perda", "tutorial_interesse_minimo", "tutorial_distancia_minima"],
	"interface": ["mostrar_alvos", "duracao_resultado", "duracao_transicao"],
}

# --- deteccao ---------------------------------------------------------------
## A agua tem de comecar a esta distancia (celulas do chao), a frente do jogador.
## Mais que isso e "olhar o rio de longe", nao "estar na beira".
var alcance_agua_celulas: float = 1.6
## Passo da marcha que procura agua, em pixels. Menor que meia celula vertical
## (8 px) para nao pular uma faixa estreita de agua na diagonal.
var passo_sonda_px: float = 2.0

# --- arremesso --------------------------------------------------------------
## Fracao do arco percorrida por segundo: um vai-e-volta completo leva 2/0.85 s.
var arco_velocidade: float = 0.85
var arco_raio: float = 72.0
var arco_espessura: float = 14.0
## Ignora o segundo aperto logo apos abrir o arco: quem segura a tecla um quadro a
## mais nao pode arremessar com forca zero sem querer.
var arco_atraso_trava: float = 0.15
## [0, limite_verde) = fraco; [limite_verde, limite_amarelo) = medio; resto = maximo.
var limite_verde: float = 0.45
var limite_amarelo: float = 0.80
var distancia_min_celulas: float = 1.5
var distancia_max_celulas: float = 7.0
var duracao_voo: float = 0.55

# --- recolhimento -----------------------------------------------------------
## Faixa util da isca (0 = superficie, 1 = fundo). As bordas ficam de fora para
## a isca nunca encostar no ceu nem no leito no desenho.
var profundidade_min: float = 0.06
var profundidade_max: float = 0.94
var profundidade_inicial: float = 0.12
## Constantes do lerp exponencial (1 - exp(-k*delta)). Exponencial, e nao lerp com
## fator fixo, para a resposta nao depender da taxa de quadros.
var suavidade_profundidade: float = 6.0
var suavidade_velocidade: float = 8.0
## Celulas/s. Com o maximo, um arremesso de 7 celulas volta em ~3 s; com o
## minimo, a isca quase para — e o "esperar o peixe" do pescador.
var velocidade_min: float = 0.35
var velocidade_max: float = 2.4

# --- surgimento -------------------------------------------------------------
## Um sorteio a cada `intervalo_surgimento` s, depois de `atraso_minimo_surgimento`
## s de recolhimento. Com 0.22 por sorteio, um arremesso medio recolhido devagar
## tem ~7 sorteios: ~1.5 silhuetas esperadas, ~80% de chance de ver ao menos uma.
var intervalo_surgimento: float = 1.2
var chance_surgimento: float = 0.22
var atraso_minimo_surgimento: float = 1.0
## Silhueta nao nasce com a isca ja na beira: nao haveria trajeto para fisgar.
var distancia_minima_para_surgir: float = 1.0

# --- interesse --------------------------------------------------------------
## Com a politica perfeita, (100 - 40)/20 = 3.0 s mais ~0.2 s de inercia da linha:
## ~3.2 s do surgimento a fisgada. Errando tudo, 40/9 = 4.4 s ate o monstro fugir.
## A perda e mais lenta que o ganho de proposito: o jogador tem tempo de corrigir.
var interesse_inicial: float = 40.0
var interesse_ganho: float = 20.0
var interesse_perda: float = 9.0
var interesse_alvo: float = 100.0

# --- deriva -----------------------------------------------------------------
## O monstro oscila levemente de altura e velocidade (senoide de fase e periodo
## sorteados). Desligavel: sem ela o minigame vira "ache a faixa e solte o mouse".
var deriva_ativa: bool = true
var deriva_amplitude_profundidade: float = 0.08
var deriva_amplitude_velocidade: float = 0.06
var deriva_periodo_min: float = 3.0
var deriva_periodo_max: float = 6.0

# --- silhueta (visual) -------------------------------------------------------
## Celulas atras da isca: longe com interesse 0, perto com interesse no alvo.
var silhueta_distancia_longe: float = 1.0
var silhueta_distancia_perto: float = 0.2
var silhueta_suavidade: float = 4.0

# --- tutorial ---------------------------------------------------------------
## No tutorial a fisgada e garantida: tolerancias largas, o monstro surge num
## tempo fixo, nao perde interesse e a isca nunca chega ao fim do trajeto.
var tutorial_multiplicador_tolerancia: float = 2.2
var tutorial_tempo_ate_silhueta: float = 2.5
var tutorial_perda: float = 0.0
var tutorial_interesse_minimo: float = 5.0
var tutorial_distancia_minima: float = 0.6

# --- interface --------------------------------------------------------------
## Faixas-alvo de altura/velocidade do monstro desenhadas fora do tutorial. Liga
## e facil demais; desligado, o jogador le a silhueta.
var mostrar_alvos: bool = false
var duracao_resultado: float = 1.6
var duracao_transicao: float = 0.3

# --- textos -----------------------------------------------------------------
## Chave -> texto ao jogador. Portugues com acentos, SO com glifos da fonte pixel
## (nada de reticencias unicode, aspas curvas ou setas para cima/baixo) — e
## tools/test_pesca.gd quem confere. O JSON sobrescreve chave a chave.
var textos: Dictionary = {
	"fisgou": "FISGOU!",
	"escapou": "ESCAPOU...",
	"fugiu": "ESCAPOU...",
	"recolhida": "Nada mordeu a isca.",
	"cancelada": "Pesca cancelada.",
	"sem_agua": "Nada de água à frente.",
	"sem_vara": "Equipe a vara de pesca: segure [Q] para abrir a roda.",
	"zona_fraco": "FRACO",
	"zona_medio": "MÉDIO",
	"zona_maximo": "MÁXIMO",
	"dica_arremesso": "[F] trava a força do arremesso.",
	"dica_recolher": "Mouse à esquerda: rápido · à direita: devagar · cima/baixo: altura",
	"rotulo_velocidade": "VELOCIDADE",
	"rotulo_interesse": "INTERESSE",
	"rotulo_altura_ok": "ALTURA OK",
	"rotulo_velocidade_ok": "VELOCIDADE OK",
	"indicador_tecla": "[F]",
	"indicador_texto": "PESCAR",
	"silhueta_surgiu": "Uma sombra segue a isca!",
	"dica_cancelar": "[ESC] cancela",
}


## Configuracao com os padroes acima, sobrescritos pelo JSON quando disponivel.
## Nunca devolve null.
static func carregar(caminho: String = CAMINHO) -> ConfiguracaoPesca:
	var cfg := ConfiguracaoPesca.new()
	if not FileAccess.file_exists(caminho):
		return cfg
	var dados: Variant = JSON.parse_string(FileAccess.get_file_as_string(caminho))
	if not dados is Dictionary:
		push_warning("ConfiguracaoPesca: JSON invalido, usando padroes — " + caminho)
		return cfg
	cfg._aplicar(dados)
	return cfg


## textos[chave], ou a propria chave. Devolver a chave em vez de "" deixa um texto
## faltando VISIVEL na tela, que e onde ele e notado.
func texto(chave: String) -> String:
	return String(textos.get(chave, chave))


## Celulas/s de uma velocidade normalizada (0 = mais devagar, 1 = mais rapido).
func velocidade_real(normalizada: float) -> float:
	return lerpf(velocidade_min, velocidade_max, clampf(normalizada, 0.0, 1.0))


## Celulas do chao percorridas pela isca para uma forca do arco (0..1).
func distancia_de_forca(forca: float) -> float:
	return lerpf(distancia_min_celulas, distancia_max_celulas, clampf(forca, 0.0, 1.0))


## Incoerencias entre os numeros (faixa invertida, intervalo nulo, tutorial que
## nao garante a fisgada...). Vazio = ok. Nao corrige nada: calibragem errada tem
## de aparecer no teste, nao ser remendada em silencio.
func validar() -> PackedStringArray:
	var p := PackedStringArray()
	if not (0.0 < limite_verde and limite_verde < limite_amarelo and limite_amarelo < 1.0):
		p.append("arremesso: exige 0 < limite_verde < limite_amarelo < 1")
	if not (0.0 < distancia_min_celulas and distancia_min_celulas <= distancia_max_celulas):
		p.append("arremesso: exige 0 < distancia_min_celulas <= distancia_max_celulas")
	if arco_velocidade <= 0.0:
		p.append("arremesso: arco_velocidade tem de ser > 0")
	if not (0.0 <= profundidade_min and profundidade_min < profundidade_max
			and profundidade_max <= 1.0):
		p.append("recolhimento: exige 0 <= profundidade_min < profundidade_max <= 1")
	if not (0.0 < velocidade_min and velocidade_min < velocidade_max):
		p.append("recolhimento: exige 0 < velocidade_min < velocidade_max")
	if intervalo_surgimento <= 0.0:
		p.append("surgimento: intervalo_surgimento tem de ser > 0")
	if not (0.0 <= chance_surgimento and chance_surgimento <= 1.0):
		p.append("surgimento: chance_surgimento fora de [0, 1]")
	if not (0.0 < interesse_inicial and interesse_inicial < interesse_alvo):
		p.append("interesse: exige 0 < interesse_inicial < interesse_alvo")
	if interesse_ganho <= 0.0 or interesse_perda < 0.0:
		p.append("interesse: ganho tem de ser > 0 e perda >= 0")
	if not (0.0 < deriva_periodo_min and deriva_periodo_min <= deriva_periodo_max):
		p.append("deriva: exige 0 < deriva_periodo_min <= deriva_periodo_max")
	if tutorial_multiplicador_tolerancia < 1.0:
		p.append("tutorial: multiplicador de tolerancia < 1 deixaria o tutorial MAIS dificil")
	if tutorial_interesse_minimo <= 0.0:
		p.append("tutorial: tutorial_interesse_minimo tem de ser > 0 (o monstro nao desiste)")
	if tutorial_distancia_minima <= 0.0:
		p.append("tutorial: tutorial_distancia_minima tem de ser > 0 (a isca nao chega ao fim)")
	return p


func _aplicar(d: Dictionary) -> void:
	for secao: String in d:
		if secao.begins_with("_"):
			continue
		var valores: Variant = d[secao]
		if not valores is Dictionary:
			push_warning("ConfiguracaoPesca: secao '%s' nao e um objeto" % secao)
			continue
		if secao == "textos":
			for chave: String in valores:
				if not chave.begins_with("_"):
					textos[chave] = String(valores[chave])
			continue
		if not SECOES.has(secao):
			push_warning("ConfiguracaoPesca: secao desconhecida '%s'" % secao)
			continue
		var permitidas: Array = SECOES[secao]
		for chave: String in valores:
			if chave.begins_with("_"):
				continue
			if not chave in permitidas:
				push_warning("ConfiguracaoPesca: chave desconhecida '%s.%s'" % [secao, chave])
				continue
			set(chave, _converter(valores[chave], get(chave)))


## Converte o valor do JSON para o tipo da variavel. O parser de JSON entrega todo
## numero como float; sem isto um bool escrito como 0/1 quebraria a atribuicao.
static func _converter(valor: Variant, atual: Variant) -> Variant:
	match typeof(atual):
		TYPE_BOOL:
			return bool(valor)
		TYPE_INT:
			return int(valor)
		TYPE_FLOAT:
			return float(valor)
	return valor
