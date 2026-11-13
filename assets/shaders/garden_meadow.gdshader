shader_type spatial;

uniform sampler2D leaf_color : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D leaf_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D soil : source_color, filter_linear_mipmap, repeat_enable;
uniform vec3 tint : source_color = vec3(1.0);
varying vec3 world;

float hash(vec2 p) {
	return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);
}

float noise2(vec2 p) {
	vec2 i=floor(p), f=smoothstep(vec2(0),vec2(1),fract(p));
	return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);
}

void vertex() {
	world=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
}

void fragment() {
	vec2 p=world.xz;
	vec2 fine=p*.42;
	float broad=noise2(p*.27)*.7+noise2(p*.8)*.3;
	vec3 grass=texture(leaf_color,fine).rgb*vec3(.35,.52,.31);
	vec3 leaf_litter=texture(soil,p*.49+vec2(.37,.19)).rgb*vec3(.36,.43,.32);
	ALBEDO=mix(leaf_litter,grass,.32+.67*smoothstep(.19,.78,broad))*tint;
	NORMAL_MAP=texture(leaf_normal,fine).rgb;
	NORMAL_MAP_DEPTH=.62;
	ROUGHNESS=.99;
	SPECULAR=.08;
}
