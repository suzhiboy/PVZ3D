shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, unshaded;

// Stylised pool water with two crossing wave trains, a thin sun-glint and a
// soft mineral band at the coping. The surface keeps the toy-diorama clarity
// while reading as genuinely wet.
uniform vec4 shallow : source_color = vec4(0.30, 0.72, 0.8, 1.0);
uniform vec4 deep : source_color = vec4(0.03, 0.22, 0.38, 1.0);
uniform vec4 foam : source_color = vec4(0.76, 0.93, 0.95, 1.0);
uniform float wave_height = 0.025;
uniform float alpha : hint_range(0.0, 1.0) = 0.9;

varying vec3 wpos;
varying float crest;

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
	float h1 = sin(wpos.x * 1.9 + TIME * 1.35) * wave_height;
	float h2 = cos(wpos.z * 2.6 + TIME * 1.0) * wave_height;
	float h3 = sin((wpos.x + wpos.z) * 4.3 - TIME * 0.8) * wave_height * 0.28;
	VERTEX.y += h1 + h2 + h3;
	crest = h1 + h2 + h3;

	// Derive the surface normal from the same waves. The plane has a +Y normal,
	// so a small slope in X/Z is enough for the specular breakup.
	float dx = cos(wpos.x * 1.9 + TIME * 1.35) * 1.9 * wave_height
		+ cos((wpos.x + wpos.z) * 4.3 - TIME * 0.8) * 4.3 * wave_height * 0.28;
	float dz = -sin(wpos.z * 2.6 + TIME * 1.0) * 2.6 * wave_height
		+ cos((wpos.x + wpos.z) * 4.3 - TIME * 0.8) * 4.3 * wave_height * 0.28;
	NORMAL = normalize(vec3(-dx, 1.0, -dz));
}

void fragment() {
	vec3 n = normalize(NORMAL);
	float fres = pow(1.0 - clamp(dot(n, normalize(VIEW)), 0.0, 1.0), 2.2);

	// Fine capillary ripples, independent from the geometry waves. The sparkle
	// uses drifting noise, not a fixed sine grid, so it never reads as rain.
	float r1 = sin(UV.x * 42.0 + TIME * 1.6) * cos(UV.y * 31.0 - TIME * 1.25);
	float r2 = sin(UV.x * 13.0 - TIME * 0.55 + UV.y * 8.0);
	float ripple = r1 * 0.6 + r2 * 0.4;
	float shimmer = soft_noise(wpos.xz * 5.2 + vec2(TIME * 0.3, -TIME * 0.22));
	float micro = soft_noise(wpos.xz * 19.0 - vec2(TIME * 0.5, TIME * 0.37));
	float sparkle = smoothstep(0.72, 0.86, shimmer) * 0.1
		+ smoothstep(0.8, 0.94, micro) * 0.035;

	vec3 col = mix(deep.rgb, shallow.rgb, clamp(0.46 + ripple * 0.13 + fres * 0.32 + crest * 1.8, 0.0, 1.0));
	col = mix(col, deep.rgb * 1.15, fres * 0.06);

	// Thin pale mineral line where the water meets the coping.
	float edge = min(min(UV.x, 1.0 - UV.x), min(UV.y, 1.0 - UV.y));
	float rim = 1.0 - smoothstep(0.0, 0.045, edge);
	col = mix(col, foam.rgb, rim * 0.18);

	ALBEDO = clamp(col * (0.9 + fres * 0.15 + crest * 2.2), vec3(0.0), vec3(1.0));
	ALPHA = clamp(alpha + fres * 0.025, 0.0, 1.0);
	// Deliberately unshaded: the painterly highlights are authored here instead
	// of coming from PBR reflections, which produced broad plastic-looking spots.
	EMISSION = shallow.rgb * fres * 0.1 + foam.rgb * sparkle * 0.34;
}
