class_name ConfiguracaoEncontro
extends RefCounted

## Ritmo do encontro e parametros de deteccao, em um lugar so.
##
## Todos os valores tem PADRAO EMBUTIDO e sao sobrescritos por
## res://data/captura/encontro.json quando ele existe. A ordem importa: um arquivo
## de calibragem ausente ou incompleto degrada o ajuste fino, nunca o
## funcionamento — perder um tempo de fade nao pode impedir o jogo de subir.
##
## Nenhum destes numeros deve reaparecer como literal em gerenciador_encontro.gd,
## transicao_encontro.gd ou roda_captura.gd.

const CAMINHO := "res://data/captura/encontro.json"

# --- deteccao ---------------------------------------------------------------
## Pixels ANDADOS dentro de uma zona por sorteio de encontro. Contar distancia, e
## nao tempo, e o que impede que parar na grama alta gere encontro.
var distancia_por_passo: float = 24.0
var chance_por_passo: float = 0.14
## Silencio apos um encontro terminar, para o jogador nao cair no seguinte no
## mesmo passo em que sai do primeiro.
var carencia_segundos: float = 1.5

## Chance de a criatura sorteada NAO respeitar os `elementos_provaveis` da zona.
## Sem ela o bioma viraria exclusividade, e uma margem de lago nunca mostraria
## nada alem de agua e gelo — o encontro deixaria de ser sorteio e viraria tabela.
var chance_fora_da_regiao: float = 0.15

# --- ritmo (segundos) -------------------------------------------------------
var duracao_aviso: float = 0.85
var duracao_tremor: float = 0.35
var intensidade_tremor: float = 5.0
var atraso_apos_aviso: float = 0.15
var duracao_escurecimento: float = 0.45
var duracao_texto_encontro: float = 1.10
var duracao_abertura_menu: float = 0.28
var duracao_abertura_roda: float = 0.22
var duracao_lancamento: float = 0.75
var duracao_balanco: float = 0.55
var balancos: int = 3
var duracao_desfecho: float = 1.20
var duracao_encerramento: float = 0.40
## Quanto cada evento do turno fica na tela antes do proximo.
var duracao_evento_batalha: float = 0.95

# --- texto ------------------------------------------------------------------
## Cartao da transicao. Em portugues como o resto da interface (ver
## bestiario_viewer e o HUD da vila); trocar aqui troca na tela.
var texto_criatura_encontrada: String = "CRIATURA ENCONTRADA"


## Configuracao com os padroes acima, sobrescritos pelo JSON quando disponivel.
## Nunca devolve null.
static func carregar(caminho: String = CAMINHO) -> ConfiguracaoEncontro:
	var cfg := ConfiguracaoEncontro.new()
	if not FileAccess.file_exists(caminho):
		return cfg
	var dados: Variant = JSON.parse_string(FileAccess.get_file_as_string(caminho))
	if dados == null:
		push_warning("ConfiguracaoEncontro: JSON invalido, usando padroes — " + caminho)
		return cfg
	cfg._aplicar(dados)
	return cfg


func _aplicar(d: Dictionary) -> void:
	var det: Dictionary = d.get("deteccao", {})
	distancia_por_passo = float(det.get("distancia_por_passo", distancia_por_passo))
	chance_por_passo = float(det.get("chance_por_passo", chance_por_passo))
	carencia_segundos = float(det.get("carencia_segundos", carencia_segundos))
	chance_fora_da_regiao = float(det.get("chance_fora_da_regiao", chance_fora_da_regiao))

	var r: Dictionary = d.get("ritmo", {})
	duracao_aviso = float(r.get("duracao_aviso", duracao_aviso))
	duracao_tremor = float(r.get("duracao_tremor", duracao_tremor))
	intensidade_tremor = float(r.get("intensidade_tremor", intensidade_tremor))
	atraso_apos_aviso = float(r.get("atraso_apos_aviso", atraso_apos_aviso))
	duracao_escurecimento = float(r.get("duracao_escurecimento", duracao_escurecimento))
	duracao_texto_encontro = float(r.get("duracao_texto_encontro", duracao_texto_encontro))
	duracao_abertura_menu = float(r.get("duracao_abertura_menu", duracao_abertura_menu))
	duracao_abertura_roda = float(r.get("duracao_abertura_roda", duracao_abertura_roda))
	duracao_lancamento = float(r.get("duracao_lancamento", duracao_lancamento))
	duracao_balanco = float(r.get("duracao_balanco", duracao_balanco))
	balancos = int(r.get("balancos", balancos))
	duracao_desfecho = float(r.get("duracao_desfecho", duracao_desfecho))
	duracao_encerramento = float(r.get("duracao_encerramento", duracao_encerramento))
	duracao_evento_batalha = float(r.get("duracao_evento_batalha", duracao_evento_batalha))

	var t: Dictionary = d.get("texto", {})
	texto_criatura_encontrada = String(t.get("criatura_encontrada", texto_criatura_encontrada))
