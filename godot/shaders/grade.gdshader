shader_type canvas_item;

// Restrained cinematic finish for the 3D view only. HUD and menus live on
// higher CanvasLayers, so their type keeps full contrast and crispness.
uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform float vignette_strength : hint_range(0.0, 0.5) = 0.18;
uniform float grain_strength : hint_range(0.0, 0.04) = 0.009;
uniform float grade_strength : hint_range(0.0, 1.0) = 0.32;

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

void fragment() {
	vec3 col = texture(screen_texture, SCREEN_UV).rgb;
	float luma = dot(col, vec3(0.299, 0.587, 0.114));

	// Split toning: cool, slightly blue-green shade and warm cream highlights.
	vec3 shade = col * vec3(0.93, 0.99, 1.05);
	vec3 light = col * vec3(1.035, 1.005, 0.955);
	col = mix(col, mix(shade, light, smoothstep(0.18, 0.82, luma)), grade_strength);

	// A soft oval vignette concentrates attention on the lane.
	vec2 p = (UV - 0.5) * vec2(1.08, 1.0);
	float vignette = smoothstep(0.34, 0.82, length(p));
	col *= 1.0 - vignette * vignette_strength;

	// Barely visible tooth, so gradients feel printed rather than synthetic.
	float grain = (hash12(UV * vec2(1920.0, 1080.0) + fract(TIME) * 91.7) - 0.5) * grain_strength;
	col += grain;

	COLOR = vec4(clamp(col, vec3(0.0), vec3(1.0)), 1.0);
}
