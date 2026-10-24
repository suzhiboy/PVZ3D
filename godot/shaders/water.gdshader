shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, specular_schlick_ggx;

uniform vec4 shallow : source_color = vec4(0.30, 0.72, 0.80, 1.0);
uniform vec4 deep : source_color = vec4(0.03, 0.24, 0.42, 1.0);
uniform float wave_height = 0.022;
uniform float alpha : hint_range(0.0, 1.0) = 0.9;

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	VERTEX.y += sin(wpos.x * 1.9 + TIME * 1.5) * wave_height
		+ cos(wpos.z * 2.6 + TIME * 1.1) * wave_height;
}

void fragment() {
	vec3 n = normalize(NORMAL);
	float fres = pow(1.0 - clamp(dot(n, normalize(VIEW)), 0.0, 1.0), 2.4);

	float ripple = sin(UV.x * 34.0 + TIME * 1.7) * cos(UV.y * 27.0 - TIME * 1.3);
	ripple += sin(UV.x * 11.0 - TIME * 0.8) * 0.5;

	vec3 col = mix(deep.rgb, shallow.rgb, clamp(ripple * 0.16 + 0.46 + fres * 0.4, 0.0, 1.0));
	ALBEDO = col;
	ALPHA = alpha;
	ROUGHNESS = 0.08;
	METALLIC = 0.15;
	EMISSION = shallow.rgb * fres * 0.12;
}
