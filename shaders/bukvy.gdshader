// Буквы заголовка: сверху жёлтые, снизу оранжевые.
// Красится только белая заливка буквы, тёмная обводка остаётся как была.
shader_type canvas_item;

uniform vec4 top_color : source_color = vec4(1.0, 0.95, 0.45, 1.0);
uniform vec4 bottom_color : source_color = vec4(1.0, 0.52, 0.1, 1.0);
uniform float y0 = 12.0;
uniform float y1 = 52.0;

varying float ly;

void vertex() {
	ly = VERTEX.y;
}

void fragment() {
	if (COLOR.r > 0.95 && COLOR.g > 0.95 && COLOR.b > 0.95) {
		COLOR.rgb = mix(top_color.rgb, bottom_color.rgb, clamp((ly - y0) / (y1 - y0), 0.0, 1.0));
	}
}
