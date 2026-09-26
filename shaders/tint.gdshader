// Цвет неба при разной погоде: сверху, посередине и снизу, между ними плавный переход.
shader_type canvas_item;

uniform vec4 top : source_color = vec4(0.0);
uniform vec4 mid : source_color = vec4(0.0);
uniform vec4 bottom : source_color = vec4(0.0);

void fragment() {
	float y = UV.y;
	if (y < 0.5) {
		COLOR = mix(top, mid, y * 2.0);
	} else {
		COLOR = mix(mid, bottom, (y - 0.5) * 2.0);
	}
}
