shader_type spatial;
render_mode cull_back, depth_draw_opaque;

// "Hand-painted miniature" lighting for the whole game.
// Three ideas keep every prop in one visual language:
//   1. soft banding instead of hard cel steps,
//   2. warm highlights and cool bounced shadows,
//   3. a very light world-space pigment wash, like gouache on a model.
uniform vec4 albedo : source_color = vec4(1.0);
uniform float bands : hint_range(1.0, 8.0) = 3.0;
uniform float rim_amount : hint_range(0.0, 1.0) = 0.22;
uniform vec4 rim_color : source_color = vec4(1.0, 0.98, 0.9, 1.0);
uniform float glow : hint_range(0.0, 4.0) = 0.0;
uniform float wrap : hint_range(0.0, 1.0) = 0.28;
uniform float roughness : hint_range(0.0, 1.0) = 0.88;
uniform float gloss : hint_range(0.0, 1.0) = 0.05;
uniform float pigment : hint_range(0.0, 0.12) = 0.035;

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
	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 n = normalize(NORMAL);
	float rim = pow(1.0 - clamp(dot(n, normalize(VIEW)), 0.0, 1.0), 3.0);
	rim *= 1.0 - clamp(n.y, 0.0, 1.0) * 0.85;

	// Two very low-frequency noise layers suggest uneven pigment rather than
	// a plastic surface. Kept subtle so silhouettes and readability survive.
	float wash = soft_noise(wpos.xz * 1.35 + wpos.y * 1.1) - 0.5;
	float grain = soft_noise(wpos.xz * 7.0 + wpos.y * 3.0) - 0.5;
	vec3 painted = albedo.rgb * (1.0 + wash * pigment + grain * pigment * 0.35);

	ALBEDO = clamp(painted, vec3(0.0), vec3(1.0));
	ROUGHNESS = roughness;
	METALLIC = 0.0;
	SPECULAR = 0.2;
	// No ALPHA here: transparent materials use toon_alpha.gdshader so walls
	// keep writing depth and interiors stay hidden.
	EMISSION = rim_color.rgb * rim * rim_amount + albedo.rgb * glow;
}

void light() {
	vec3 n = normalize(NORMAL);
	float ndl = dot(n, normalize(LIGHT));
	float w = clamp((ndl + wrap) / (1.0 + wrap), 0.0, 1.0);

	// Blend the cel step with a smooth ramp. The result keeps the hand-drawn
	// banding but loses the harsh "stacked paper" transitions.
	float stepped = floor(w * bands + 0.5) / bands;
	float shaped = mix(stepped, smoothstep(0.0, 1.0, w), 0.32);

	// Cool sky bounce on the shadow side, warm sun on the lit side.
	vec3 light_tint = mix(vec3(0.82, 0.9, 1.0), vec3(1.05, 1.0, 0.91),
		smoothstep(0.05, 0.78, w));

	// A broad, soft sheen makes rounded fruit and painted wood feel solid
	// without turning the set into glossy plastic.
	vec3 h = normalize(normalize(LIGHT) + normalize(VIEW));
	float sheen = pow(max(dot(n, h), 0.0), 20.0) * gloss;

	DIFFUSE_LIGHT += LIGHT_COLOR * ATTENUATION * (shaped * light_tint + sheen) / PI;
}
