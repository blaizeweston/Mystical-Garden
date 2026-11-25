shader_type spatial;
render_mode cull_disabled;
uniform float sample_time = -1.;
void vertex() {
	float t = sample_time < 0. ? TIME : sample_time;
	float wind = t*1.18 + dot(MODEL_MATRIX[3].xz,vec2(.31,.19));
	VERTEX.xz += pow(max(VERTEX.y,0.),2.)*vec2(.032*sin(wind),.017*sin(wind*1.37));
}
void fragment() { ALBEDO = COLOR.rgb; ROUGHNESS = .83; }
