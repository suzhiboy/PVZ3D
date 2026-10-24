shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled;

// Cell highlight under the crosshair: soft fill plus a bright rim.
uniform vec4 fill_color : source_color = vec4(0.55, 1.0, 0.42, 0.38);
uniform vec4 rim_color : source_color = vec4(0.72, 1.0, 0.55, 0.95);
uniform float pulse_speed = 3.5;

void fragment() {
	vec2 p = abs(UV - 0.5) * 2.0;
	float d = max(p.x, p.y);
	float rim = smoothstep(0.74, 0.80, d) * (1.0 - smoothstep(0.93, 0.99, d));
	float pulse = 0.72 + 0.28 * sin(TIME * pulse_speed);
	ALBEDO = mix(fill_color.rgb, rim_color.rgb, rim);
	ALPHA = mix(fill_color.a, rim_color.a, rim) * pulse;
}
