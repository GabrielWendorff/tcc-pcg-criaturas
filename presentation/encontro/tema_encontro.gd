class_name TemaEncontro
extends RefCounted

## Tema da interface de encontro: fonte, molduras e cores.
##
## Tudo aqui aponta para arte GERADA por tools/arte/gerar_ui.py, gerar_fonte.py e
## gerar_itens.py — a mesma politica das outras tres familias de arte do projeto.
## Nada de StyleBoxFlat com canto arredondado: um retangulo de cor chapada com
## raio de borda e a assinatura visual de interface web, e era exatamente o que
## esta tela parecia antes.
##
## FONTE
## Bitmap 5x7 em caixa 5x11, em duas folhas (1x e 2x). Pedir a folha 1x num
## tamanho maior faria a engine reamostrar e comer a borda do pixel; por isso as
## duas folhas existem e por isso TAM_TEXTO e TAM_TITULO sao os tamanhos NATIVOS
## de cada uma. Usar qualquer outro numero borra o texto.
##
## MOLDURAS
## StyleBoxTexture em 9 fatias: os 4 cantos ficam intactos, as bordas esticam num
## eixo e so o miolo liso estica nos dois. E o que mantem a espessura da moldura
## constante em qualquer tamanho de painel — sem isso, um painel largo teria
## borda esticada e o pixel deixaria de ser quadrado.
##
## As cores repetem a paleta de tools/arte/ui_lib.py. Elas vivem nos dois lugares
## porque o Python pinta os PNGs e o GDScript pinta o texto por cima deles; um
## valor diferente aqui aparece na hora, como texto que destoa da propria moldura.

const DIR_UI := "res://arte/ui/"

# --- fonte ------------------------------------------------------------------
const FONTE := DIR_UI + "fonte_pixel.fnt"
const FONTE_TITULO := DIR_UI + "fonte_pixel_2x.fnt"
const FONTE_CARTAZ := DIR_UI + "fonte_pixel_3x.fnt"

## Tamanhos NATIVOS das tres folhas. Nao inventar outros — ver nota acima.
const TAM_TEXTO := 11
const TAM_TITULO := 22
const TAM_CARTAZ := 33

# --- paleta (espelha tools/arte/ui_lib.py) ----------------------------------
const CONTORNO := Color("1f150f")
const MADEIRA_E := Color("4a3121")
const MADEIRA := Color("6b4630")
const MADEIRA_C := Color("8a5c3e")
const PERG_E := Color("b08a5e")
const PERG := Color("e8d5a8")
const PERG_C := Color("f7ebcd")
const TINTA := Color("3a2a1c")
const TINTA_C := Color("6e563e")
const NOITE_E := Color("181620")
const NOITE := Color("282436")
const NOITE_C := Color("3a344c")
const OURO_E := Color("a8761a")
const OURO := Color("f2c14e")
const OURO_C := Color("ffe9a8")
const VERDE := Color("5bbf5b")
const VERDE_C := Color("96e082")
const VERMELHO := Color("e14b4b")
const VERMELHO_C := Color("f58c78")

## Papeis, para o codigo da interface nao citar cor crua.
const TEXTO := PERG_C
const TEXTO_APOIO := PERG_E
const TEXTO_FRACO := Color("6e6480")
const TEXTO_TINTA := TINTA
const DESTAQUE := OURO
const SUCESSO := VERDE
const FALHA := VERMELHO
const ATENCAO := Color("e8a83a")

## Sombra de 1px sob o texto que fica sobre o MUNDO (sem painel atras). Substitui
## o contorno de fonte: fonte de bitmap nao aceita o contorno gerado pela engine
## — pedi-lo nao da erro, simplesmente nao desenha nada.
const SOMBRA := Color("11141b")

# --- molduras 9-slice: arquivo -> margem da fatia ---------------------------
const MOLDURAS := {
	"cartao": {"arquivo": "cartao_normal.png", "margem": 7, "conteudo": 9},
	"cartao_ativo": {"arquivo": "cartao_ativo.png", "margem": 7, "conteudo": 9},
	"cartao_selecionado": {"arquivo": "cartao_selecionado.png", "margem": 7, "conteudo": 9},
	"cartao_desativado": {"arquivo": "cartao_desativado.png", "margem": 7, "conteudo": 9},
	"painel": {"arquivo": "painel_escuro.png", "margem": 10, "conteudo": 13},
	"pergaminho": {"arquivo": "painel_pergaminho.png", "margem": 10, "conteudo": 13},
	"painel_ouro": {"arquivo": "painel_ouro.png", "margem": 10, "conteudo": 13},
	"medidor": {"arquivo": "medidor.png", "margem": 3, "conteudo": 3},
	"selo": {"arquivo": "selo.png", "margem": 4, "conteudo": 4},
}

static var _cache_molduras: Dictionary = {}
static var _fonte: FontFile
static var _fonte_titulo: FontFile
static var _fonte_cartaz: FontFile


static func fonte() -> FontFile:
	if _fonte == null:
		_fonte = load(FONTE)
	return _fonte


static func fonte_titulo() -> FontFile:
	if _fonte_titulo == null:
		_fonte_titulo = load(FONTE_TITULO)
	return _fonte_titulo


## Folha 3x. Existe para UM uso — o cartaz de tela cheia do encontro. Escalar a
## folha 2x ate esse tamanho custaria uma reamostragem no meio do momento mais
## visivel do roteiro.
static func fonte_cartaz() -> FontFile:
	if _fonte_cartaz == null:
		_fonte_cartaz = load(FONTE_CARTAZ)
	return _fonte_cartaz


## Moldura 9-slice por nome. Cacheada: a roda reconstroi seus slots a cada
## abertura, e um StyleBoxTexture novo por slot seria lixo por quadro.
static func moldura(nome: String) -> StyleBoxTexture:
	if _cache_molduras.has(nome):
		return _cache_molduras[nome]
	var d: Dictionary = MOLDURAS[nome]
	var sb := StyleBoxTexture.new()
	sb.texture = load(DIR_UI + String(d["arquivo"]))
	var m: int = int(d["margem"])
	sb.set_texture_margin_all(m)
	sb.set_content_margin_all(float(d["conteudo"]))
	# STRETCH e nao TILE: o miolo das molduras e cor chapada, e repetir uma cor
	# chapada custa mais desenho para produzir o mesmo pixel.
	sb.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	sb.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	_cache_molduras[nome] = sb
	return sb


## Corpos disponiveis. CORPO_* mapeia para a folha de mesma escala.
enum Corpo { TEXTO, TITULO, CARTAZ }


## Aplica a fonte pixel a um Label. Sempre no tamanho nativo da folha pedida.
static func aplicar_fonte(lbl: Label, corpo: Corpo = Corpo.TEXTO) -> void:
	var f: FontFile = fonte()
	var tam: int = TAM_TEXTO
	if corpo == Corpo.TITULO:
		f = fonte_titulo()
		tam = TAM_TITULO
	elif corpo == Corpo.CARTAZ:
		f = fonte_cartaz()
		tam = TAM_CARTAZ
	lbl.add_theme_font_override("font", f)
	lbl.add_theme_font_size_override("font_size", tam)


static func rotulo(texto: String, cor: Color = TEXTO,
		corpo: Corpo = Corpo.TEXTO) -> Label:
	var lbl := Label.new()
	lbl.text = texto
	lbl.add_theme_color_override("font_color", cor)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	aplicar_fonte(lbl, corpo)
	return lbl


## Rotulo legivel POR CIMA do mundo. Dois Labels: o de tras, deslocado 2px e
## escuro, e a sombra. E como pixel art resolve legibilidade sobre fundo
## arbitrario — e o unico jeito, com fonte de bitmap, de nao depender de contorno.
static func rotulo_sombreado(texto: String, cor: Color = TEXTO,
		corpo: Corpo = Corpo.TEXTO) -> Control:
	var raiz := Control.new()
	raiz.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var desloc: float = [2.0, 3.0, 4.0][int(corpo)]
	for i in 2:
		var lbl := rotulo(texto, SOMBRA if i == 0 else cor, corpo)
		lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.position = Vector2(desloc, desloc) if i == 0 else Vector2.ZERO
		lbl.name = "Sombra" if i == 0 else "Frente"
		raiz.add_child(lbl)
	raiz.set_meta("deslocamento", desloc)
	escrever_sombreado(raiz, texto)
	return raiz


## Troca o texto de um rotulo sombreado — nos DOIS Labels — e recalcula o tamanho
## minimo do container.
##
## O recalculo nao e detalhe: os dois Labels sao ancorados em FULL_RECT (e o que
## os mantem alinhados um sobre o outro), e um filho ancorado nao contribui para o
## tamanho minimo do pai. Sem esta conta, um rotulo sombreado dentro de um
## Container mede zero e o painel atras dele encolhe para um quadradinho enquanto
## o texto transborda por fora.
static func escrever_sombreado(raiz: Control, texto: String) -> void:
	var frente := raiz.get_node_or_null("Frente") as Label
	var sombra := raiz.get_node_or_null("Sombra") as Label
	if frente == null or sombra == null:
		return
	frente.text = texto
	sombra.text = texto
	var desloc: float = float(raiz.get_meta("deslocamento", 2.0))
	raiz.custom_minimum_size = frente.get_minimum_size() + Vector2(desloc, desloc)


## Texto rico com a fonte pixel em TODAS as variantes.
##
## Sem sobrescrever bold/italics, um trecho em [b] cai na fonte padrao da engine
## e a linha sai com dois tipos misturados — o defeito e discreto e destroi a
## unidade da tela. Como nao ha corte negrito desta fonte, [b] simplesmente nao
## engorda: a enfase se faz com COR e caixa alta.
static func texto_rico(bbcode: String = "") -> RichTextLabel:
	var rt := RichTextLabel.new()
	rt.bbcode_enabled = true
	rt.fit_content = true
	rt.scroll_active = false
	rt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for papel in ["normal_font", "bold_font", "italics_font", "bold_italics_font",
			"mono_font"]:
		rt.add_theme_font_override(papel, fonte())
	for papel in ["normal_font_size", "bold_font_size", "italics_font_size",
			"bold_italics_font_size", "mono_font_size"]:
		rt.add_theme_font_size_override(papel, TAM_TEXTO)
	rt.add_theme_color_override("default_color", TEXTO)
	rt.add_theme_constant_override("line_separation", 2)
	rt.text = bbcode
	return rt


## Cor que traduz uma probabilidade em leitura imediata. Os cortes sao os mesmos
## em toda a interface para que a mesma cor signifique sempre a mesma coisa.
##
## A cor NUNCA e o unico canal: onde este metodo e usado ha tambem numero e
## comprimento de barra (ver MedidorChance). Um jogador com dificuldade de
## distinguir vermelho de verde le a mesma informacao pelo tamanho da barra.
static func cor_da_chance(p: float) -> Color:
	if p >= 0.6:
		return VERDE
	if p >= 0.35:
		return OURO
	return VERMELHO


## A MESMA leitura, em tons que sobrevivem ao pergaminho.
##
## As cores de estado sao calibradas para fundo escuro; sobre bege, o dourado
## some e o verde claro fica ilegivel. Nao basta escurecer por formula — o
## dourado precisa virar ocre, nao amarelo sujo —, entao os tres tons sao
## escolhidos e ficam aqui, ao lado dos originais, para nunca divergirem.
static func cor_da_chance_sobre_claro(p: float) -> Color:
	if p >= 0.6:
		return Color("2e6a2e")
	if p >= 0.35:
		return Color("8a5a12")
	return Color("9c2f2b")
