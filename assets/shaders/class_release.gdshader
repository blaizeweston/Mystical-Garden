shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, depth_draw_never;
uniform int style;
uniform vec3 path;
uniform float radius;
uniform float lane_width;
uniform float angle;
uniform float span;
uniform bool variation;
uniform bool braced;
uniform float phase;
uniform float class_ink=.84;
uniform float class_relief=1.;
varying vec4 pigment;
vec3 polar(float a,float r,float y){return vec3(cos(a)*r,y,sin(a)*r);}
vec3 sweep(float u,float lane,out float width,out vec3 tint){
	float a=lane*TAU/9.;
	float n=fract(lane*.618+.31);
	float f=smoothstep(0.,.46,phase);
	float leaf=sin(PI*clamp(u,0.,1.));
	width=.055;
	if(style==0){
		// Ground breaks into branching, jagged seams.
		float section=mod(lane,3.);
		float travel=(section==2.?(.42+.55*u):u)*f;
		a=floor(lane/3.)*TAU/3.+section*.29+sin(travel*10.+n)*.12;
		width=(.15-.105*travel)*(.24+.76*leaf);
		tint=mix(vec3(.38,.24,.13),vec3(.91,.77,.49),u);
		return polar(a,radius*travel,.06+leaf*(1.-phase)*.23);
	}
	if(style==1){
		float az=variation?angle+(lane/8.-.5)*1.75:a;
		width=(braced?.13:.10)*(.24+leaf);
		tint=mix(vec3(.32,.22,.14),vec3(.78,.75,.48),u);
		return polar(az+sin(u*3.1)*.14,(.29+.25*u)*(.7+.3*f),.10+u*f*(braced?.78:1.12));
	}
	if(style==2 || style==9){
		float grow=min(1.,phase*3.5);
		width=(style==9?.095:.15)*(.12+leaf);
		tint=style==9?mix(vec3(.31,.63,.44),vec3(.98,.87,.61),u):mix(vec3(.43,.65,.39),vec3(.96,.69,.85),u);
		float spread=variation?grow:(.38+.62*f);
		return polar(a+.30*sin(u*PI)+phase*.12,radius*spread*(.10+u*.88),.09+leaf*(.24+.4*n)*grow+phase*u*.23);
	}
	if(style==3){
		width=.10*(.13+leaf);
		tint=mix(vec3(.26,.38,.21),vec3(.73,.86,.50),u);
		return polar(a+.5*u,radius*(.99-u*.53*f),.07+u*u*.43*f);
	}
	if(style==4){
		float row=mod(lane,3.)-1.;
		float travel=clamp(phase*2.6,0.,1.);
		float ribbon=(.18+.82*u)*travel;
		vec3 side=normalize(vec3(-path.z,0.,path.x)+vec3(.00001,0.,0.));
		width=(.025+.045*leaf)*(lane<3.?1.:.55);
		tint=mix(vec3(.35,.60,.47),vec3(.95,.94,.69),u);
		return path*ribbon+side*(row*lane_width*.68+(floor(lane/3.)-1.)*.08*(1.-u)) + vec3(0.,.75+abs(row)*.10,0.);
	}
	if(style==5){
		float theta=angle-span*.5+span*(.12+.88*u)*f;
		width=(.065+.12*leaf)*(lane<3.?1.:.35);
		tint=mix(vec3(.36,.16,.28),vec3(.95,.65,.70),u);
		return polar(theta,radius*(.57+.42*lane/8.),.12+leaf*.33*(1.-phase)+n*.11);
	}
	if(style==6){
		// A target-local sickle cut. Actual healing is reported separately.
		width=.085*(.12+leaf);tint=mix(vec3(.44,.18,.30),vec3(.95,.69,.73),u);
		return polar(-1.2+u*2.65+phase*.23,.30+.16*n,.56+u*.65+n*.09);
	}
	if(style==8){
		width=.07*(.17+leaf);tint=mix(vec3(.55,.43,.68),vec3(.92,.80,.89),u);
		return polar(a,radius*(.59+.34*u),.10+u*(1.-f)*1.2);
	}
	float beat=floor(lane/3.)*.11;
	float pulse=smoothstep(beat,.66+beat,phase);
	width=.07*(.18+leaf);
	tint=mix(vec3(.56,.57,.38),vec3(.96,.86,.62),u);
	return polar(mod(lane,3.)*TAU/3.+u*1.92,radius*(variation?1.-.82*pulse:.20+.8*pulse),.13+beat+leaf*.07);
}
void vertex(){
	float w;vec3 ink;float u=UV.x;float lane=UV2.y;
	vec3 p=sweep(u,lane,w,ink);
	float dw;vec3 dc;
	float step_dir=u>.998?-.002:.002;
	vec3 tangent=(sweep(u+step_dir,lane,dw,dc)-p)*sign(step_dir);
	vec3 eye=normalize((inverse(MODELVIEW_MATRIX)*vec4(0.,0.,1.,0.)).xyz);
	vec3 normal=cross(tangent,eye);
	VERTEX=p+normal/max(length(normal),.00001)*(UV.y-.5)*w*class_relief;
	pigment=vec4(ink,class_ink*(1.-smoothstep(.48,1.,phase)));
}
void fragment(){
	float ridge=1.-abs(UV.y*2.-1.);
	ALBEDO=pigment.rgb*(.74+.26*ridge);
	ALPHA=pigment.a*smoothstep(.0,.55,ridge);
}
