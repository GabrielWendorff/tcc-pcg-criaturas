extends Control

## Visualizador do bestiario (primeira versao de RF07). Ferramenta de demo/depuracao:
## digite uma seed, gere e veja as ~100 criaturas com cor, atributos, morfologia
## e as metricas de coerencia (RF08) no topo. Sem sprites ainda — o "visual" e a
## cor derivada (matiz) + a familia de paleta.

const N_PADRAO := 100

var _tabelas: TabelasProbabilidade
var _gerador: GeradorCriaturas

var _seed_input: LineEdit
var _header: RichTextLabel
var _lista: VBoxContainer

# matiz (categorico) -> cor concreta para o swatch.
const CORES_MATIZ := {
	"vermelho": Color("e14b4b"),
	"laranja":  Color("e8863a"),
	"amarelo":  Color("e8cf4b"),
	"verde":    Color("5bbf5b"),
	"ciano":    Color("4bd6d6"),
	"azul":     Color("4b6ee8"),
	"roxo":     Color("9b5be8"),
	"marrom":   Color("8a5a3c"),
	"cinza":    Color("8a909c"),
	"branco":   Color("e8ecf2"),
}


func _ready() -> void:
	_tabelas = TabelasProbabilidade.carregar()
	_construir_ui()
	if _tabelas == null:
		_header.text = "[color=e14b4b]Erro: nao foi possivel carregar as tabelas de res://data/.[/color]"
		return
	_gerador = GeradorCriaturas.new(_tabelas)
	_gerar(123456789)


func _construir_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color("1b1e26")
	bg.set_anchors_preset(PRESET_FULL_RECT)
	add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(PRESET_FULL_RECT)
	for lado in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(lado, 16)
	add_child(margin)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	margin.add_child(col)

	# --- barra de controle ---
	var toolbar := HBoxContainer.new()
	toolbar.add_theme_constant_override("separation", 8)
	col.add_child(toolbar)

	var lbl := Label.new()
	lbl.text = "Seed:"
	toolbar.add_child(lbl)

	_seed_input = LineEdit.new()
	_seed_input.text = "123456789"
	_seed_input.custom_minimum_size.x = 200
	_seed_input.tooltip_text = "Numero ou texto qualquer (texto vira seed pela hash)."
	_seed_input.text_submitted.connect(func(_t): _on_gerar())
	toolbar.add_child(_seed_input)

	var btn := Button.new()
	btn.text = "Gerar bestiário"
	btn.pressed.connect(_on_gerar)
	toolbar.add_child(btn)

	var btn2 := Button.new()
	btn2.text = "Seed aleatória"
	btn2.pressed.connect(_on_aleatoria)
	toolbar.add_child(btn2)

	# --- cabecalho de metricas ---
	_header = RichTextLabel.new()
	_header.bbcode_enabled = true
	_header.fit_content = true
	_header.size_flags_horizontal = SIZE_EXPAND_FILL
	col.add_child(_header)

	# --- lista rolavel de criaturas ---
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)

	_lista = VBoxContainer.new()
	_lista.size_flags_horizontal = SIZE_EXPAND_FILL
	_lista.add_theme_constant_override("separation", 4)
	scroll.add_child(_lista)


func _on_gerar() -> void:
	_gerar(_seed_do_input())


func _on_aleatoria() -> void:
	var s := randi()
	_seed_input.text = str(s)
	_gerar(s)


## Aceita seed numerica ou texto (texto -> hash deterministica).
func _seed_do_input() -> int:
	var txt := _seed_input.text.strip_edges()
	if txt.is_valid_int():
		return int(txt)
	return hash(txt)


func _gerar(world_seed: int) -> void:
	var t0 := Time.get_ticks_usec()
	var bestiario := _gerador.gerar_bestiario(world_seed, N_PADRAO)
	var dt_ms := (Time.get_ticks_usec() - t0) / 1000.0
	var m := MetricasCoerencia.avaliar(bestiario, _tabelas)
	_atualizar_header(world_seed, dt_ms, m)
	_popular_lista(bestiario)


func _atualizar_header(world_seed: int, dt_ms: float, m: Dictionary) -> void:
	var meta_cor := "5bbf5b" if dt_ms < 2000.0 else "e14b4b"
	var linhas := PackedStringArray()
	linhas.append("[b]Seed:[/b] %d    [b]Criaturas:[/b] %d    [b]Tempo:[/b] [color=%s]%.2f ms[/color]" % [
		world_seed, m["total"], meta_cor, dt_ms
	])
	linhas.append("[b]Coerência (RF08):[/b]  paleta %.0f%%   matiz %.0f%%   morfologia %.0f%%   [b]geral %.0f%%[/b]" % [
		m["paleta_pct"] * 100.0, m["matiz_pct"] * 100.0,
		m["morfologia_pct"] * 100.0, m["geral_pct"] * 100.0
	])
	_header.text = "\n".join(linhas)


func _popular_lista(bestiario: Array) -> void:
	for filho in _lista.get_children():
		filho.queue_free()
	for c in bestiario:
		_lista.add_child(_card(c))


func _card(c: Criatura) -> Control:
	var panel := PanelContainer.new()
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = Color("242833")
	estilo.set_corner_radius_all(6)
	estilo.set_content_margin_all(8)
	# borda esquerda tingida pela cor da criatura
	estilo.border_color = _cor_matiz(c.matiz)
	estilo.border_width_left = 4
	panel.add_theme_stylebox_override("panel", estilo)

	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	panel.add_child(h)

	var swatch := ColorRect.new()
	swatch.color = _cor_matiz(c.matiz)
	swatch.custom_minimum_size = Vector2(44, 44)
	swatch.size_flags_vertical = SIZE_SHRINK_CENTER
	h.add_child(swatch)

	var texto := RichTextLabel.new()
	texto.bbcode_enabled = true
	texto.fit_content = true
	texto.size_flags_horizontal = SIZE_EXPAND_FILL
	texto.text = _descricao_bbcode(c)
	h.add_child(texto)

	return panel


func _descricao_bbcode(c: Criatura) -> String:
	var feats := c.features_presentes()
	var feats_txt := ", ".join(feats) if not feats.is_empty() else "[color=6a7080](nenhuma)[/color]"
	# marcador de coerencia por criatura (paleta e matiz na moda do elemento)
	var coerente := (c.paleta == _moda(_tabelas.dist_paleta(c.elemento))) \
		and (c.matiz == _moda(_tabelas.dist_matiz(c.elemento)))
	var tag := "[color=5bbf5b]● coerente[/color]" if coerente else "[color=8a909c]○ atípica[/color]"
	return "[b]%s[/b]   %s\n[color=b0b6c0]%s + %s[/color]   ·   paleta [b]%s[/b]   ·   matiz [b]%s[/b]\nmorfologia: %s" % [
		c.nome(), tag, c.elemento, c.animal_base, c.paleta, c.matiz, feats_txt
	]


func _cor_matiz(matiz: String) -> Color:
	return CORES_MATIZ.get(matiz, Color("8a909c"))


func _moda(dist: Dictionary) -> String:
	var melhor := ""
	var melhor_p := -1.0
	for valor in dist:
		if dist[valor] > melhor_p:
			melhor_p = dist[valor]
			melhor = valor
	return melhor
