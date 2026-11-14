shader_type spatial;

uniform bool growing_root = false;
uniform float root_progress = 1.0;
uniform float reclaim_pulse = 0.0;

void fragment() {
	if (growing_root && COLOR.a > root_progress) {
		discard;
	}
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
	if (growing_root) {
		float seam = smoothstep(0.96, 0.997, sin(grain.x * TAU * 5.0 + grain.y * 0.82 + bend));
		float gaps = smoothstep(0.14, 0.65, sin(grain.y * 4.1 + grain.x * 10.0));
		float near_heart = exp(-grain.y * 0.62) * (1.0 - smoothstep(0.12, 0.38, COLOR.a));
		EMISSION = vec3(0.38, 0.012, 0.015) * seam * gaps * near_heart * (0.34 + reclaim_pulse);
	}
	ROUGHNESS = 0.91 - 0.09 * grooves;
}
