shader_type canvas_item;

uniform vec4 tint : source_color = vec4(0.6, 0.05, 0.02, 0.55);
uniform float inner = 0.34;
uniform float outer = 0.82;

void fragment() {
	vec2 uv = UV - 0.5;
	float d = length(uv * vec2(1.16, 1.0));
	float v = smoothstep(inner, outer, d);
	COLOR = vec4(tint.rgb, tint.a * v);
}
