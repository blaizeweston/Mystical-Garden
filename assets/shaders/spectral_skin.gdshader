shader_type spatial;
render_mode unshaded, depth_draw_never, shadows_disabled;
uniform bool anchored;
uniform float ground_y;
uniform float opacity=.49;
uniform float veil=1.;
varying float height;
void vertex(){height=(MODEL_MATRIX*vec4(VERTEX,1.)).y-ground_y;}
void fragment(){
	float rim=pow(1.-abs(dot(normalize(NORMAL),normalize(VIEW))),1.7);
	float band=anchored?.16+.84*(1.-smoothstep(.72,1.68,height)):smoothstep(.05,.83,height);
	float threads=.84+.16*sin(height*43.+VERTEX.x*13.);
	ALBEDO=mix(anchored?vec3(.23,.19,.34):vec3(.27,.53,.60),anchored?vec3(.73,.64,.87):vec3(.77,.97,.93),rim);
	ALPHA=opacity*veil*band*(.42+.58*rim)*threads;
}
