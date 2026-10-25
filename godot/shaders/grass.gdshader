shader_type spatial;
render_mode cull_back, depth_draw_opaque;

// Layered lawn: soft mowing bands, broad tonal patches and tiny dry clover
// flecks. The goal is a painted miniature lawn, not a repeating game texture.
uniform vec4 color_a : source_color = vec4(0.36, 0.5, 0.24, 1.0);
uniform vec4 color_b : source_color = vec4(0.28, 0.42, 0.2, 1.0);
uniform vec4 color_deep : source_color = vec4(0.2, 0.31, 0.16, 1.0);
uniform vec4 dry : source_color = vec4(0.57, 0.58, 0.32, 1.0);
uniform float stripe_width = 1.6;
uniform float speckle = 13.0;
uniform float dry_amount : hint_range(0.0, 1.0) = 0.12;
uniform float cell_size = 1.6;
uniform float cell_shade : hint_range(0.0, 0.2) = 0.028;

varying vec3 wpos;

float hash21(vec2 p) {
	p = fract(p * vec2(233.34, 451.21));
	p += dot(p, p + 34.32);
	return fract(p.x * p.y);
}

float soft_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash21(i), hash21(i + vec2(1.0, 0.0)), f.x),
		mix(hash21(i + vec2(0.0, 1.0)), hash21(i + vec2(1.0, 1.0)), f.x), f.y);
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	// Two scales of mown bands, softened at the edges.
	float band_a = sin(wpos.x / stripe_width * 3.14159);
	float band_b = sin((wpos.x + wpos.z * 0.12) / (stripe_width * 2.3) * 3.14159);
	float stripe = smoothstep(-0.65, 0.65, band_a * 0.72 + band_b * 0.28);

	// Broad mossy patches and darker roots under the grass.
	float broad = soft_noise(wpos.xz * 0.31 + 4.7);
	float mid = soft_noise(wpos.xz * 1.65 - 8.0);
	vec3 base = mix(color_b.rgb, color_a.rgb, stripe * 0.62 + 0.18);
	base = mix(base, color_deep.rgb, smoothstep(0.54, 0.9, broad * 0.7 + mid * 0.3) * 0.34);

	// Sparse dry clover and sun-bleached tips keep large lawns from reading flat.
	float d = soft_noise(wpos.xz * 0.84 + 19.0);
	base = mix(base, dry.rgb, smoothstep(0.73, 1.0, d) * dry_amount);
	float n = hash21(floor(wpos.xz * speckle));
	base *= 0.91 + n * 0.18;
	float tip = smoothstep(0.935, 0.995, hash21(floor(wpos.xz * 7.0) + 31.0));
	base = mix(base, dry.rgb * 1.08, tip * 0.12);

	// A whisper of the planting grid, enough for aiming without looking tiled.
	float cell = mod(floor(wpos.x / cell_size) + floor(wpos.z / cell_size), 2.0);
	base *= 1.0 - cell * cell_shade;

	ALBEDO = clamp(base, vec3(0.0), vec3(1.0));
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}

void light() {
	vec3 n = normalize(NORMAL);
	float ndl = dot(n, normalize(LIGHT));
	float w = clamp((ndl + 0.3) / 1.3, 0.0, 1.0);
	float stepped = floor(w * 4.0 + 0.5) / 4.0;
	float shaped = mix(stepped, smoothstep(0.0, 1.0, w), 0.38);
	vec3 tint = mix(vec3(0.86, 0.92, 1.0), vec3(1.04, 1.0, 0.93), smoothstep(0.05, 0.8, w));
	DIFFUSE_LIGHT += LIGHT_COLOR * ATTENUATION * shaped * tint / PI;
}
