extends Control

## Visualizador do bestiario (RF07). Digite uma seed, gere e veja as ~100
## criaturas DESENHADAS (corpo + features no modelo escolhido) com miniaturas na
## lista e um painel de detalhe. No topo, as metricas de coerencia (RF08).

const N_PADRAO := 100

var _tabelas: TabelasProbabilidade
var _catalogo: CatalogoCorpos
var _gerador: GeradorCriaturas

var _seed_input: LineEdit
var _header: RichTextLabel
var _lista: VBoxContainer
var _detalhe_render: CreatureSpriteRenderer
var _detalhe_texto: RichTextLabel


func _ready() -> void:
	_tabelas = TabelasProbabilidade.carregar()
	# Carregado uma unica vez e repassado a cada renderer: sao ~100 miniaturas por
	# bestiario, e cada uma lendo o JSON de ancoras por conta propria seria desperdicio.
	_catalogo = CatalogoCorpos.carregar(_tabelas) if _tabelas != null else null
	_construir_ui()
	if _tabelas == null or _catalogo == null:
		_header.text = "[color=e14b4b]Erro: nao foi possivel carregar res://data/ ou res://arte/.[/color]"
		return
	var faltando := _catalogo.validar(_tabelas)
	if not faltando.is_empty():
		_header.text = "[color=e14b4b]Arte ausente para: %s[/color]" % ", ".join(faltando)
		return
	_gerador = GeradorCriaturas.new(_tabelas, _catalogo)
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

	# --- corpo: detalhe (esq) + lista (dir) ---
	var linha := HBoxContainer.new()
	linha.add_theme_constant_override("separation", 14)
	linha.size_flags_vertical = SIZE_EXPAND_FILL
	col.add_child(linha)

	linha.add_child(_construir_painel_detalhe())

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	linha.add_child(scroll)

	_lista = VBoxContainer.new()
	_lista.size_flags_horizontal = SIZE_EXPAND_FILL
	_lista.add_theme_constant_override("separation", 4)
	scroll.add_child(_lista)


func _construir_painel_detalhe() -> Control:
	var painel := PanelContainer.new()
	painel.custom_minimum_size = Vector2(300, 0)
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = Color("222633")
	estilo.set_corner_radius_all(8)
	estilo.set_content_margin_all(12)
	painel.add_theme_stylebox_override("panel", estilo)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	painel.add_child(v)

	var moldura := PanelContainer.new()
	var molst := StyleBoxFlat.new()
	molst.bg_color = Color("15171e")
	molst.set_corner_radius_all(6)
	moldura.add_theme_stylebox_override("panel", molst)
	moldura.size_flags_horizontal = SIZE_SHRINK_CENTER
	v.add_child(moldura)

	_detalhe_render = CreatureSpriteRenderer.new()
	_detalhe_render.custom_minimum_size = Vector2(260, 260)
	moldura.add_child(_detalhe_render)

	_detalhe_texto = RichTextLabel.new()
	_detalhe_texto.bbcode_enabled = true
	_detalhe_texto.fit_content = true
	_detalhe_texto.size_flags_horizontal = SIZE_EXPAND_FILL
	v.add_child(_detalhe_texto)

	return painel


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
	if not bestiario.is_empty():
		_selecionar(bestiario[0])


## Cabecalho de metricas (RF08). Cada dimensao aparece como observado / teto: o
## teto e o maximo que as tabelas condicionais permitem, e nao 100% — exibir so o
## observado sugeriria que o gerador esta errando quando ele esta correto.
func _atualizar_header(world_seed: int, dt_ms: float, m: Dictionary) -> void:
	var meta_cor := "5bbf5b" if dt_ms < 2000.0 else "e14b4b"
	var moda: Dictionary = m["moda"]
	var linhas := PackedStringArray()
	linhas.append("[b]Seed:[/b] %d    [b]Criaturas:[/b] %d    [b]Tempo:[/b] [color=%s]%.2f ms[/color]" % [
		world_seed, m["total"], meta_cor, dt_ms
	])

	var partes := PackedStringArray()
	for dim in MetricasCoerencia.DIMENSOES_MODA:
		var d: Dictionary = moda[dim]
		partes.append("%s %.0f%%[color=6a7080]/%.0f%%[/color]" % [
			dim, d["obs"] * 100.0, d["teto"] * 100.0
		])
	linhas.append("[b]Coerência (RF08):[/b]  " + "   ".join(partes)
		+ "   [b]fidelidade %.0f%%[/b] [color=6a7080](obs/teto)[/color]" % (
			moda["eficiencia_pct"] * 100.0))

	# I(elemento;cor) e a medida que testa a hipotese (RF04). Com n=100 o estimador
	# e enviesado — o numero aqui e indicativo; use tools/analise.py com n>=5000.
	var im: Dictionary = m["info_mutua"]["elemento->cor"]
	var ip: Dictionary = m["info_mutua"]["elemento->porte"]
	var un: Dictionary = m["unicidade"]
	linhas.append("[color=b0b6c0]I(elemento;cor) = %.2f bits (explica %.0f%%)  ·  I(elemento;porte) = %.2f bits  ·  distintas (k=%d): %d/%d[/color]" % [
		im["i_bits"], im["u"] * 100.0, ip["i_bits"], un["k"], un["distintas"], m["total"]
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
	estilo.border_color = PaletaCriatura.cor_base(c.matiz, c.paleta)
	estilo.border_width_left = 4
	panel.add_theme_stylebox_override("panel", estilo)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.gui_input.connect(func(ev): _on_card_input(ev, c))

	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	panel.add_child(h)

	var thumb := CreatureSpriteRenderer.new()
	thumb.custom_minimum_size = Vector2(72, 72)
	thumb.size_flags_vertical = SIZE_SHRINK_CENTER
	thumb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(thumb)
	thumb.configurar(c, _catalogo)

	var texto := RichTextLabel.new()
	texto.bbcode_enabled = true
	texto.fit_content = true
	texto.size_flags_horizontal = SIZE_EXPAND_FILL
	texto.mouse_filter = Control.MOUSE_FILTER_IGNORE
	texto.text = _descricao_card(c)
	h.add_child(texto)

	return panel


func _on_card_input(ev: InputEvent, c: Criatura) -> void:
	if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		_selecionar(c)


func _selecionar(c: Criatura) -> void:
	_detalhe_render.configurar(c, _catalogo)
	_detalhe_texto.text = _descricao_detalhe(c)


func _descricao_card(c: Criatura) -> String:
	var coerente := _coerente(c)
	var tag := "[color=5bbf5b]● coerente[/color]" if coerente else "[color=8a909c]○ atípica[/color]"
	return "[b]%s[/b]   %s\n[color=b0b6c0]%s + %s · %s[/color]  ·  paleta [b]%s[/b]  ·  matiz [b]%s[/b]\n%s" % [
		c.nome(), tag, c.elemento, c.animal_base, c.porte, c.paleta, c.matiz, _lista_partes(c)
	]


func _descricao_detalhe(c: Criatura) -> String:
	var linhas := PackedStringArray()
	linhas.append("[b][font_size=18]%s[/font_size][/b]" % c.nome())
	linhas.append("[color=b0b6c0]Primários:[/color]  elemento [b]%s[/b]  ·  animal [b]%s[/b]" % [c.elemento, c.animal_base])
	linhas.append("[color=b0b6c0]Silhueta:[/color]  porte [b]%s[/b]  ·  arquétipo [b]%s[/b]  [color=6a7080](%s)[/color]" % [
		c.porte, c.arquetipo, c.body_id])
	linhas.append("[color=b0b6c0]Cor:[/color]  paleta [b]%s[/b]  ·  matiz [b]%s[/b]" % [c.paleta, c.matiz])
	linhas.append("[color=b0b6c0]Morfologia (modelo):[/color]")
	var achou := false
	for f in _tabelas.features_morfologia():
		if c.morfologia.get(f, false):
			achou = true
			var idx: int = c.variantes[f]
			# Marca o que o gerador decidiu mas a arte ainda nao cobre, para que o
			# quadro nunca contradiga a ficha sem explicacao.
			var nota := "" if _catalogo.tem_arte(f) else "  [color=e8a83a](sem arte)[/color]"
			linhas.append("   • %s: [b]%s[/b] [color=6a7080](modelo %d/%d)[/color]%s" % [
				f, _tabelas.nome_modelo(f, idx), idx + 1, _tabelas.num_modelos(f), nota
			])
	if not achou:
		linhas.append("   [color=6a7080](nenhuma)[/color]")
	var tag := "[color=5bbf5b]● coerente[/color]" if _coerente(c) else "[color=e8a83a]○ atípica[/color]"
	linhas.append("[color=b0b6c0]Coerência:[/color] %s   [color=6a7080](seed ind. %d)[/color]" % [tag, c.seed_individual])
	return "\n".join(linhas)


## Lista textual das features presentes com seus modelos (para o card).
func _lista_partes(c: Criatura) -> String:
	var partes := PackedStringArray()
	for f in _tabelas.features_morfologia():
		if c.morfologia.get(f, false):
			partes.append("%s:%s" % [f, _tabelas.nome_modelo(f, c.variantes[f])])
	if partes.is_empty():
		return "[color=6a7080](sem apêndices)[/color]"
	return "[color=9aa0aa]" + "  ·  ".join(partes) + "[/color]"


## Criatura "coerente" = paleta e matiz na moda do elemento.
func _coerente(c: Criatura) -> bool:
	return (c.paleta == _moda(_tabelas.dist_paleta(c.elemento))) \
		and (c.matiz == _moda(_tabelas.dist_matiz(c.elemento)))


func _moda(dist: Dictionary) -> String:
	var melhor := ""
	var melhor_p := -1.0
	for valor in dist:
		if dist[valor] > melhor_p:
			melhor_p = dist[valor]
			melhor = valor
	return melhor
