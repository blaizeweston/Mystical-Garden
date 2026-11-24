shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled;
void fragment() {
	float flow = fract(UV.x * 4.0 - TIME * 1.8 + UV.y);
	float pulse = sin(TIME * 2.1 + UV.y * 6.283);
	if (flow > 0.32 || pulse < -0.35) { discard; }
	ALBEDO = vec3(0.46, 0.77, 0.79);
	ALPHA = 0.65;
}
