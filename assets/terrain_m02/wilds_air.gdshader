shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled;
uniform vec3 climate;
uniform vec2 observer;
uniform float sight = 0.0;
uniform float motes = 0.6;
varying float strength;

void vertex() {
	vec3 anchor = MODEL_MATRIX[3].xyz;
	float seed = fract(sin(dot(anchor.xz,vec2(23.51,17.37)))*1435.86);
	float age = fract(TIME*(0.12+0.06*seed)+seed);
	float phase = seed*TAU + age*TAU;
	vec3 at = anchor + vec3(sin(phase)*.39+age*.45,.22+age*(.45+.45*seed),cos(phase)*.22);
	float lit = sight<0.0 ? 1.0 : 1.0-smoothstep(max(0.0,sight-1.7),max(0.01,sight),distance(at.xz,observer));
	strength = float(motes > 0.0)*sin(age*PI)*lit*smoothstep(seed-.06,seed+.06,motes)*(.76-.36*climate.y);
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0],INV_VIEW_MATRIX[1],INV_VIEW_MATRIX[2],vec4(at,1.0));
	VERTEX.xy *= .068 + .043*seed;
}
void fragment() {
	vec2 d=(UV-0.5)*2.0;
	float r=dot(d,d);
	float alpha=(1.0-smoothstep(.08, .95, r))*strength;
	ALBEDO=climate.x*vec3(.88,.78,.49)+climate.y*vec3(.55,.69,.63)+climate.z*vec3(.72,.72,.84);
	ALPHA=alpha*.71;
}