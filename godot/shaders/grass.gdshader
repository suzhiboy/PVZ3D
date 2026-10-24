shader_type spatial;
render_mode cull_back, depth_draw_opaque;

// Mown lawn: stripes, per-blade speckle, and a barely-there checkerboard so the
// player can read the planting grid without UI clutter.
uniform vec4 color_a : source_color = vec4(0.44, 0.63, 0.28, 1.0);
uniform vec4 color_b : source_color = vec4(0.37, 0.55, 0.24, 1.0);
uniform vec4 dry : source_color = vec4(0.62, 0.66, 0.34, 1.0);
uniform float stripe_width = 1.6;
uniform float speckle = 11.0;
uniform float dry_amount : hint_range(0.0, 1.0) = 0.12;
uniform float cell_size = 1.6;
uniform float cell_shade : hint_range(0.0, 0.2) = 0.028;

varying vec3 wpos;

float hash21(vec2 p) {
	p = fract(p * vec2(233.34, 451.21));
	p += dot(p, p + 34.32);
	return fract(p.x * p.y);
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float stripe = step(0.5, fract(wpos.x / stripe_width));
	vec3 base = mix(color_a.rgb, color_b.rgb, stripe * 0.45);

	float n = hash21(floor(wpos.xz * speckle));
	base *= 0.9 + n * 0.2;

	float d = hash21(floor(wpos.xz * 1.7) + 17.0);
	base = mix(base, dry.rgb, smoothstep(0.72, 1.0, d) * dry_amount);

	float cell = mod(floor(wpos.x / cell_size) + floor(wpos.z / cell_size), 2.0);
	base *= 1.0 - cell * cell_shade;

	ALBEDO = base;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}

void light() {
	float ndl = dot(normalize(NORMAL), normalize(LIGHT));
	float w = clamp((ndl + 0.3) / 1.3, 0.0, 1.0);
	float stepped = floor(w * 3.0 + 0.5) / 3.0;
	DIFFUSE_LIGHT += LIGHT_COLOR * ATTENUATION * stepped / PI;
}
