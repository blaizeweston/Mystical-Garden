shader_type spatial;

void fragment() {
	// Mesh UVs follow the curved wood along the trunk, through branches and into the roots.
	vec2 grain = UV;
	float bend = 0.55 * sin(grain.y * 1.4 + grain.x * TAU);
	float narrow = sin(TAU * grain.x * 31.0 + bend + 0.45 * sin(grain.y * 4.0));
	float grain_break = 0.55 + 0.45 * sin(grain.y * 4.7 + cos(grain.x * TAU * 7.0));
	float grooves = smoothstep(0.73, 0.985, narrow) * grain_break;
	float ribbons = sin(TAU * grain.x * 13.0 - bend + 0.27 * grain.y);
	float small_marks = sin(TAU * grain.x * 67.0 + bend * 2.1 + grain.y * 2.2);
	float pigment = 1.07 + ribbons * 0.11 + small_marks * 0.055 - grooves * 0.29;
	ALBEDO = COLOR.rgb * pigment;
	ROUGHNESS = 0.91 - 0.09 * grooves;
}
