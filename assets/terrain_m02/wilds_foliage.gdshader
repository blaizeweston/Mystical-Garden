shader_type spatial;
render_mode cull_disabled;

uniform sampler2D surface_tile : filter_linear_mipmap, repeat_enable;
uniform float sway = 1.0;
uniform float wound = 0.75;
uniform float veil = 0.75;
uniform bool crown = false;
uniform bool woody = false;
uniform bool fungus = false;
uniform vec3 climate;
uniform vec2 observer;
uniform float sight = 0.0;

varying vec3 site;
varying vec3 root;
varying float upper;

void vertex() {
	root = MODEL_MATRIX[3].xyz;
	site = (MODEL_MATRIX * vec4(VERTEX,1.0)).xyz;
	upper = smoothstep(0.12,0.86,VERTEX.y);
	float phase = dot(root.xz,vec2(1.39,2.17));
	float breeze = sin(TIME*(0.94 - climate.y*0.28) + phase + VERTEX.y*1.3)
		+ 0.31*sin(TIME*1.76 + phase*1.71 + VERTEX.z*1.8);
	if (!woody && !fungus) {
		VERTEX.xz += vec2(0.025,0.013)*sway*breeze*upper*upper;
	}
}

void fragment() {
	// Thin only the upper boughs between the observer and camera. The fog and
	// opaque lower trunk keep their ordinary depth and visibility rules.
	if (crown && sight>0.0 && veil>0.0) {
		vec2 offset = site.xz-observer;
		vec2 toward_camera = normalize(INV_VIEW_MATRIX[2].xz);
		float along = dot(offset,toward_camera);
		float across = abs(dot(offset,vec2(-toward_camera.y,toward_camera.x)));
		float cut = (1.0-smoothstep(1.4,3.1,across)) * smoothstep(-0.25,0.9,along)
			* (1.0-smoothstep(2.8,6.5,along)) * smoothstep(0.68,1.72,site.y) * upper * veil;
		// Ordered opaque cutout keeps foliage out of the transparent sorting pass.
		ivec2 px = ivec2(FRAGCOORD.xy) % 4;
		int order[16] = int[16](0,8,2,10,12,4,14,6,3,11,1,9,15,7,13,5);
		if (cut > (float(order[px.x+4*px.y])+0.5)/16.0) discard;
	}
	vec2 trunk_uv = vec2(site.x*.43+site.z*.65,site.y*.67+site.z*.13);
	vec3 detail = texture(surface_tile, trunk_uv).rgb;
	vec3 leaf = COLOR.rgb;
	vec3 palette = climate.x*vec3(0.94,0.85,0.61) + climate.y*vec3(0.70,0.92,0.83) + climate.z*vec3(0.82,0.84,1.04);
	float green = smoothstep(-0.012,0.048,leaf.g-leaf.r);
	leaf *= mix(vec3(0.92,0.86,0.79), palette, green);
	leaf *= 0.78 + 0.38*detail.r;
	if (woody || (crown && green<0.25)) {
		// Moss-dark cambium follows the existing dead wood and raised roots.
		float pocket = smoothstep(0.42,0.70,detail.r) * smoothstep(-0.4,0.5,sin(root.x*.8+root.z*.51));
		float cord = 0.5+0.5*sin(32.0*trunk_uv.x+5.4*detail.b+3.2*detail.g);
		float seam = smoothstep(0.72,0.99,cord)*pocket*wound;
		float breath = 0.5+0.5*sin(TIME*0.84 + dot(site,vec3(.8,.6,.44)));
		leaf = mix(leaf,vec3(.101,.048,.038)*(0.82+0.32*breath),seam*.72);
		leaf = mix(leaf, vec3(.53,.49,.48)*(0.68+detail.b*.44), climate.z*.36*(1.0-seam));
		EMISSION=vec3(.046,.016,.007)*seam*breath;
	}
	if (fungus) EMISSION = vec3(.085,.105,.125) * upper * (0.6+0.4*detail.g);
	ALBEDO = leaf;
	ROUGHNESS = mix(0.91,0.68,climate.y*detail.g);
	SPECULAR = 0.17;
}