shader_type spatial;
render_mode cull_back, depth_draw_opaque;

// Banded, stylised lighting for the whole game. Every prop uses this so the
// world reads as one hand-drawn set.
uniform vec4 albedo : source_color = vec4(1.0);
uniform float bands : hint_range(1.0, 8.0) = 3.0;
uniform float rim_amount : hint_range(0.0, 1.0) = 0.22;
uniform vec4 rim_color : source_color = vec4(1.0, 0.98, 0.9, 1.0);
uniform float glow : hint_range(0.0, 4.0) = 0.0;
uniform float wrap : hint_range(0.0, 1.0) = 0.28;

void fragment() {
	vec3 n = normalize(NORMAL);
	float rim = pow(1.0 - clamp(dot(n, normalize(VIEW)), 0.0, 1.0), 3.0);
	// upward-facing surfaces (floors, ground) pick up far too much rim at
	// grazing angles, which reads as a white sheet — damp it hard
	rim *= 1.0 - clamp(n.y, 0.0, 1.0) * 0.85;
	ALBEDO = albedo.rgb;
	ROUGHNESS = 0.92;
	METALLIC = 0.0;
	SPECULAR = 0.0;
	// NOTE: no ALPHA here on purpose. Writing ALPHA puts the material in the
	// transparent pipeline, which loses depth writes — walls then stop hiding
	// the room behind them. Use toon_alpha.gdshader for see-through props.
	EMISSION = rim_color.rgb * rim * rim_amount + albedo.rgb * glow;
}

void light() {
	float ndl = dot(normalize(NORMAL), normalize(LIGHT));
	float w = clamp((ndl + wrap) / (1.0 + wrap), 0.0, 1.0);
	float stepped = floor(w * bands + 0.5) / bands;
	DIFFUSE_LIGHT += LIGHT_COLOR * ATTENUATION * stepped / PI;
}
