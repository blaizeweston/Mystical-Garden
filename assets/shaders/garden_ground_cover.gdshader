shader_type spatial;
render_mode cull_disabled;

uniform sampler2D tex : source_color, filter_linear_mipmap;
uniform sampler2D coverage : filter_linear_mipmap;
uniform float blade_height = .35;
uniform float motion_enabled = 1.0;

void vertex() {
	vec3 world=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
	float sway=pow(clamp(VERTEX.y/blade_height,0.,1.),1.7);
	VERTEX.xz+=vec2(.9,.36)*sin(world.x*.66+world.z*.54+TIME*1.15)*.028*sway*motion_enabled;
	NORMAL=normalize(mix(NORMAL,vec3(0.,1.,0.),.4));
}

void fragment() {
	vec3 green=texture(tex,UV).rgb;
	float luma=dot(green,vec3(.22,.71,.07));
	ALBEDO=mix(green,vec3(luma)*vec3(.70,.83,.57),.38)*COLOR.rgb;
	ALPHA=texture(coverage,UV).r;
	ALPHA_SCISSOR_THRESHOLD=.25;
	EMISSION=ALBEDO*.12;
	ROUGHNESS=.98;
	SPECULAR=.03;
}
