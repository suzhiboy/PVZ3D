shader_type canvas_item;

uniform vec4 left_color : source_color = vec4(0.025, 0.055, 0.041, 0.94);
uniform vec4 right_color : source_color = vec4(0.025, 0.055, 0.041, 0.03);
uniform float curve = 1.0;

void fragment() {
	float k = pow(clamp(UV.x, 0.0, 1.0), curve);
	COLOR = mix(left_color, right_color, k);
}
