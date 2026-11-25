shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, depth_draw_never;
void fragment() {
	float edge = smoothstep(0., .76, UV.y) * (1. - smoothstep(.87, 1., UV.y));
	ALBEDO = mix(vec3(.38,.48,.32),vec3(.94,.92,.72),UV.y);
	ALPHA = COLOR.a * (.24 + .76 * edge) * smoothstep(0.,.3,UV.y);
}
