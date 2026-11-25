shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, depth_draw_never;
uniform sampler2D mask_atlas : filter_linear, repeat_disable;
uniform int family = 0; // spray, pollen, shore inlet
uniform float sample_time = -1.0;
uniform float density;
uniform float size;
uniform float height;
uniform float spread;
uniform float speed;
uniform float lifetime;
uniform float opacity;
uniform float splash;
uniform vec4 tint : source_color = vec4(.66,.89,.90,1.);
varying float tile;
varying float fade;

void vertex() {
	float t = sample_time < 0.0 ? TIME : sample_time;
	vec3 origin = VERTEX;
	float seed = dot(origin.xz,vec2(.371,.129));
	float i = UV2.x;
	float random = fract(sin(i*13.13+seed+2.0)*4317.32);
	vec2 corner = UV-.5;
	vec3 offset = vec3(0.);
	vec2 extent = vec2(size);
	bool horizontal = false;
	bool strand = family==0 && i>=35.;
	fade = 1.;
	tile = 0.;
	if (family == 0) {
		bool landing = i >= 30.;
		float arm = mod(i,5.);
		float angle = arm*TAU/5.+UV2.y;
		float cycle = t*speed/max(.01,lifetime) + seed + arm*.236;
		float age = fract(cycle + (landing ? 0. : floor(i/5.)*.194));
		float throw_length = spread*(.9+.1*sin(floor(cycle)*1.6+arm));
		vec2 dir = vec2(cos(angle),sin(angle));
		float u = landing ? 1. : age;
		offset.xz = dir*(.28+u*throw_length);
		offset.y = mix(.83,.08,u)+4.*height*u*(1.-u);
		// Different spouts breathe in short, overlapping phrases.
		fade = smoothstep(-.7,.25,sin(t*1.7+arm+seed));
		if (strand) {
			u = UV.x*.76;
			offset.xz = dir*(.28+u*spread) + vec2(-dir.y,dir.x)*(UV.y-.5)*size*.64;
			offset.y = mix(.83,.08,u)+4.*height*u*(1.-u);
			extent = vec2(0.);
			fade *= (.28+.72*smoothstep(-.4,.7,cos(TAU*(u-t*speed/lifetime+arm*.19))))
				*(1.-smoothstep(.35,.76,u))*.90;
			tile = 4.;
		} else if (landing) {
			tile = 3.;
			extent = vec2(.09+age*.23);
			fade *= splash*(1.-smoothstep(.05,.5,age));
		} else {
			tile = 1.;
			extent *= vec2(.9,1.65);
			fade *= step(i+.5,density)*sin(PI*age);
		}
	} else if (family == 1) {
		float life = lifetime*mix(.74,1.,random);
		float age = fract(t/max(.01,life)+i*.618+seed);
		float angle = i*2.40 + sin(t*.8+seed)*.22;
		offset.xz = vec2(cos(angle),sin(angle))*spread*(.15+age*.85)
			+ vec2(.13*sin(age*5.+angle),.07*sin(age*4.+angle))*age;
		offset.y = 1.14+speed*age*life;
		extent *= mix(.62,1.15,random);
		fade = step(i+.5,density)*smoothstep(0.,.18,age)*(1.-smoothstep(.56,1.,age));
	} else {
		float age = fract(t*speed+i/3.+seed);
		tile = 2.;
		horizontal = true;
		float radius = mix(.88,.16,age);
		extent = vec2(radius,radius*.78);
		fade = sin(PI*age)*.78;
	}
	vec4 center = MODELVIEW_MATRIX*vec4(origin+offset,1.);
	if (horizontal) {
		center += MODELVIEW_MATRIX*vec4(corner.x*extent.x,0.,corner.y*extent.y,0.);
	} else {
		center.xy += vec2(corner.x,-corner.y)*extent;
	}
	POSITION = PROJECTION_MATRIX*center;
}
void fragment() {
	vec2 uv = vec2((tile+clamp(UV.x,.015,.985))*.25,UV.y);
	float mask = tile>3.5 ? (1.-smoothstep(.2,.50,abs(UV.y-.5))) : texture(mask_atlas,uv).a;
	float alpha = mask*opacity*fade;
	if (alpha < .012) { discard; }
	ALBEDO = tint.rgb;
	ALPHA = alpha;
}
