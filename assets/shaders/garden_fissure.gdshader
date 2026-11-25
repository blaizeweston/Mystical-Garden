shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never;
uniform float sample_time = -1.;
uniform float intensity;
uniform float frequency;
uniform float duration;
uniform vec4 tint : source_color;
varying float level;
void vertex() { level = VERTEX.y; }
void fragment() {
	float t = sample_time < 0. ? TIME : sample_time;
	float period = 1./frequency;
	float age = mod(t+.11*sin(t*1.37)-level*.09,period);
	float breath = sin(PI*clamp(age/min(duration,period),0.,1.));
	ALBEDO = tint.rgb*intensity*breath*breath*(.82+.18*sin(level*6.+t));
	ALPHA = 1.;
}
