shader_type spatial;
render_mode blend_mix, cull_back, depth_draw_never;

// Variant of the toon shader for things that genuinely need to be see-through:
// the planting ghost, dust puffs, explosion flash. Kept separate because a
// shader that writes ALPHA gets pushed into the transparent pipeline, and
// transparent surfaces do not write depth — which makes interiors visible
// through their own walls.

uniform vec4 albedo : source_color = vec4(1.0);
uniform float bands : hint_range(1.0, 8.0) = 3.0;
uniform float rim_amount : hint_range(0.0, 1.0) = 0.22;
uniform vec4 rim_color : source_color = vec4(1.0, 0.98, 0.9, 1.0);
uniform float glow : hint_range(0.0, 4.0) = 0.0;
uniform float alpha : hint_range(0.0, 1.0) = 0.6;
uniform float wrap : hint_range(0.0, 1.0) = 0.28;

void fragment() {
	vec3 n = normalize(NORMAL);
	float rim = pow(1.0 - clamp(dot(n, normalize(VIEW)), 0.0, 1.0), 3.0);
	rim *= 1.0 - clamp(n.y, 0.0, 1.0) * 0.85;
	ALBEDO = albedo.rgb;
	ROUGHNESS = 0.92;
	METALLIC = 0.0;
	SPECULAR = 0.0;
	ALPHA = alpha;
	EMISSION = rim_color.rgb * rim * rim_amount + albedo.rgb * glow;
}

void light() {
	float ndl = dot(normalize(NORMAL), normalize(LIGHT));
	float w = clamp((ndl + wrap) / (1.0 + wrap), 0.0, 1.0);
	float stepped = floor(w * bands + 0.5) / bands;
	DIFFUSE_LIGHT += LIGHT_COLOR * ATTENUATION * stepped / PI;
}
