shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled;

// Planting grid, locked to world space. Only drawn while a seed is selected.
uniform vec4 line_color : source_color = vec4(1.0, 1.0, 0.94, 0.30);
uniform vec2 grid_origin = vec2(-7.2, -4.0);
uniform float cell_size = 1.6;
uniform vec2 cell_count = vec2(9.0, 5.0);
uniform float thickness : hint_range(0.005, 0.12) = 0.035;

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = (wpos.xz - grid_origin) / cell_size;
	vec2 g = abs(fract(p) - 0.5);
	float lx = smoothstep(0.5 - thickness, 0.5, g.x);
	float ly = smoothstep(0.5 - thickness, 0.5, g.y);
	float inside = step(0.0, p.x) * step(p.x, cell_count.x) * step(0.0, p.y) * step(p.y, cell_count.y);
	float l = max(lx, ly) * inside;
	// fade the grid out at grazing angles so it never reads as a solid sheet
	float facing = clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0);
	ALBEDO = line_color.rgb;
	ALPHA = line_color.a * l * smoothstep(0.06, 0.24, facing);
}
