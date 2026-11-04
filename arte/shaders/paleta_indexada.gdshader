// paleta_indexada.gdshader
// Aplica uma paleta de 4 cores sobre uma mascara indexada (canal R = indice).
// Uso: material.set_shader_parameter("cor_contorno", Color(...)) etc.
//
// Indices na mascara:  1 contorno | 2 sombra | 3 base | 4 brilho
shader_type canvas_item;
render_mode unshaded;

uniform vec4 cor_contorno : source_color = vec4(0.16, 0.06, 0.03, 1.0);
uniform vec4 cor_sombra   : source_color = vec4(0.60, 0.18, 0.07, 1.0);
uniform vec4 cor_base     : source_color = vec4(0.88, 0.38, 0.12, 1.0);
uniform vec4 cor_brilho   : source_color = vec4(1.00, 0.76, 0.29, 1.0);

void fragment() {
	vec4 src = texture(TEXTURE, UV);
	if (src.a < 0.5) {
		discard;
	}
	int idx = int(round(src.r * 4.0));
	vec4 c = cor_base;
	if (idx == 1) {
		c = cor_contorno;
	} else if (idx == 2) {
		c = cor_sombra;
	} else if (idx == 4) {
		c = cor_brilho;
	}
	COLOR = vec4(c.rgb, c.a * src.a);
}
