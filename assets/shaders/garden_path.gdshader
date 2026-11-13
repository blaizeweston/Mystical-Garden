shader_type spatial;
render_mode cull_disabled;

uniform sampler2D soil : source_color, filter_linear_mipmap, repeat_enable;
uniform float path_length = 6.0;
varying vec3 world;

void vertex() {
	world=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
}

void fragment() {
	float edge=sin(UV.y*11.0)*.035+sin(UV.y*27.0)*.018;
	ALBEDO=texture(soil,world.xz*.65).rgb*vec3(.77,.72,.63);
	ROUGHNESS=.98;
	float end_fade=1.0-smoothstep(path_length-.6,path_length,UV.y);
	ALPHA=(1.0-smoothstep(.36+edge,1.0,abs(UV.x)))*.94*end_fade;
}
