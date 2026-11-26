shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;
uniform int style;
uniform vec3 path;
uniform float extent;
uniform float phase;
uniform float payoff_ink=.85;
uniform float payoff_edge=1.;
varying vec4 ink;
vec3 polar(float a,float r,float y){return vec3(cos(a)*r,y,sin(a)*r);}
void vertex(){
	float u=UV.x, lane=UV2.y, n=fract(lane*.618+.17), a=lane*TAU/9.;
	float leaf=sin(PI*u), gain=smoothstep(0.,.6,phase);
	vec3 p=vec3(0.), axis=vec3(0.,1.,0.), col=vec3(1.);
	float w=.08, alpha=1.;
	if(style==0 || style>=5){
		// A line connects two resolved positions. Nothing is aimed at a third body.
		float travel=mix(gain*.78,gain,u);
		vec3 lateral=normalize(vec3(-path.z,0.,path.x)+vec3(.00001,0.,0.));
		if(style==0){
			travel=clamp(phase*2.7-.28*n,0.,1.);
			p=path*travel+vec3(0.,.77,0.)+lateral*(n-.5)*.21;
			p+=normalize(path+vec3(.0,.17,.0))*(u-.5)*.32;
			w=.085*leaf;col=mix(vec3(.31,.57,.69),vec3(.90,.98,1.),u);
		}else if(style==5){
			p=path*(u*gain)+vec3(0.,.72+.13*leaf,0.)+lateral*(n-.5)*.17*leaf;
			w=.028*(.25+leaf);col=vec3(.67,.85,.54);alpha=lane<3.?1.:.28;
		}else if(style==6){
			p=path*travel+vec3(0.,.77+.15*sin(u*PI+n),0.)+lateral*(n-.5)*.26;
			w=.068*leaf;col=mix(vec3(.53,.42,.77),vec3(.88,.83,1.),n);
		}else{
			p=path*travel+vec3(0.,.73+.21*sin(u*PI),0.)+lateral*(n-.5)*.24*leaf;
			w=.042*(.15+leaf);col=mix(vec3(.49,.64,.36),vec3(.96,.83,.49),n);
		}
		axis=normalize(lateral+vec3(0.,.65,0.));
	}else if(style==1 || style==4){
		float theta=a+u*.64;
		float r=style==1?extent*(.12+.86*gain):extent*(.16+.80*gain*u);
		p=polar(theta,r,.09+leaf*(style==1?.15:.38));
		w=(style==1?.14:.16)*(.13+leaf);
		col=style==1?mix(vec3(.33,.59,.71),vec3(.94,.98,.99),u):mix(vec3(.31,.53,.30),vec3(.86,.85,.42),u);
	}else if(style==2){
		p=polar(a+.7*u,.48*(1.-gain*.80),.46+u*.71+n*.12);
		axis=polar(a+1.57,1.,0.);w=.12*(.1+leaf);
		col=mix(vec3(.41,.10,.21),vec3(.98,.65,.67),u);
	}else{
		p=polar(a+.8*u,.30+gain*.24,.98-.56*gain+.27*u);
		axis=polar(a+1.57,1.,0.);w=.10*leaf;
		col=mix(vec3(.33,.51,.22),vec3(.88,.78,.39),u);
	}
	VERTEX=p+axis*(UV.y-.5)*w*payoff_edge;
	ink=vec4(col,alpha*payoff_ink*(1.-smoothstep(.50,1.,phase)));
}
void fragment(){
	float edge=1.-abs(UV.y*2.-1.);
	ALBEDO=ink.rgb*(.71+.29*edge);
	ALPHA=ink.a*smoothstep(.0,.62,edge);
}
