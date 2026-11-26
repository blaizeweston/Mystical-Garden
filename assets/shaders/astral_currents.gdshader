shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;
uniform vec3 path;
uniform float extent;
uniform float seed_offset;
uniform float seconds;
uniform float phase;
uniform float event_weight = 1.0;
uniform bool returning;
uniform bool collapse;
uniform bool outward;
uniform bool standing;
uniform bool burst;
uniform bool singularity;
uniform float storm_width = 1.0;
uniform float storm_kink = 1.0;
uniform float spirit_wisp = 0.72;
uniform float spirit_veil = 0.49;
uniform float void_flow = 1.0;
uniform float core_weight=1.;
uniform float void_shade = 0.48;
varying vec4 ink;

float hash(float n) {return fract(sin(n*125.7+seed_offset)*4375.47);}
vec3 polar(float a,float r,float y){return vec3(cos(a)*r,y,sin(a)*r);}

vec3 point_on_strip(int role,float lane,float t,out float width,out vec4 pigment){
	float n=hash(lane+1.0);
	float a=n*6.283185;
	vec3 sideways=normalize(vec3(-path.z,0.,path.x)+vec3(.00001,0.,0.));
	float taper=sin(t*3.14159);
	vec3 p=vec3(0.);
	if(role==0){
		// Secondary filaments split and rejoin the same confirmed segment.
		float u=lane<.5?t:mix(.16+lane*.13,.50+lane*.13,t);
		float kink=(hash(floor(t*16.+.5)+floor(phase*3.)*.41)-.5)*sin(u*3.14159);
		float gain=min(length(path),1.)*storm_kink;
		p=path*u+vec3(0.,.83,0.)+sideways*(kink*.42+sin(t*3.14159)*lane*.075)*gain;
		p.y+=((lane>.5?taper*.24:0.)+float(returning)*sin(u*3.14159)*.18+kink*.18)*gain;
		width=(lane<.5?.081:.032)*storm_width*event_weight*(.36+.64*taper)*smoothstep(0.,.12,length(path));
		pigment=vec4(mix(vec3(.61,.77,1.),vec3(1.,.94,.66),float(returning)),pow(1.-phase,1.35)*(lane<.5?1.:.65));
	}else if(role==1){
		float r=(burst?extent*(.50+n*.47):.14+n*.27)*(t+phase*(1.-t))*(.75+event_weight*.25);
		p=path+polar(a,r,.80+t*(.05+n*.25)-phase*.18);
		width=.032*storm_width*(1.-t*.85)*event_weight;
		pigment=vec4(.98,.94,.73,(1.-phase)*(1.-phase)*(.55+.42*n));
	}else if(role==2){
		float u=t+(1.-t)*phase*.40;
		if(standing){
			p=polar(a+u*2.1+seconds*.67,.23+u*.12,.14+u*1.32);
		}else{
			p=path*u+sideways*(sin(u*6.3+a+phase*2.)*.11+taper*.19*(n-.5));
			p.y+=.22+n*.48+taper*(.21+phase*.16);
		}
		width=(.026+n*.041)*(.12+taper)*(.8+.2*sin(u*6.+a));
		pigment=vec4(.56,.91,.91,spirit_wisp*(.45+.55*n)*(1.-smoothstep(.47,1.,phase)));
	}else if(role==3){
		p=polar(lane*1.256+t*.98+seconds*.24,.32+t*.08,.062+.085*taper);
		width=.032*(.22+taper);pigment=vec4(.64,.52,.84,(.35+spirit_veil*.4)*(1.-smoothstep(.88,1.,phase)));
	}else if(role==7){
		// Crossed, target-local pinches. Only the confirmed overlap receipt has three.
		float radius=extent*(1.-smoothstep(.0,.83,phase))*(.36+.5*taper);
		float theta=a+t*2.62+phase*1.45*void_flow;
		p=polar(theta,radius,.53+(t-.5)*.72*(1.-phase));
		width=.058*(.12+taper);
		pigment=vec4(.77,.66,.95,(.52+void_shade*.46)*(1.-phase));
	}else{
		float fade=1.-smoothstep(.82,1.,phase);
		float sink=collapse?pow(1.-phase,2.):1.;
		if(role==4){
			float travel=fract(seconds*void_flow*(.44+.19*n)+n);
			float u=clamp(travel*.81+t*.19,0.,1.);
			float r=(1.-u)*(.88+.095*n);
			if(outward){r=u*.95;}
			p=polar(a+u*(singularity?5.8:3.8),extent*r*sink,.075+sin(u*3.14)*(.11+.085*n)*sink);
			width=(.028+.032*n)*(.1+taper)*min(1.,extent+.22);
			pigment=vec4(mix(vec3(.51,.54,.83),vec3(.84,.77,.95),n),fade*sin(u*3.14159)*(.48+.4*n));
		}else if(role==5){
			p=polar(lane*1.256637+t*1.15,extent,.071);
			width=.018*(.25+taper);
			pigment=vec4(.57,.52,.72,.54*fade);
		}else{
			float r=(lane<.5?.12:.22)*extent*sink;
			p=polar(t*6.283185+seconds*.52,r,.09+.012*lane);
			width=lane<.5?r*1.9:.025*sink;
			pigment=lane<.5?vec4(.075,.05,.15,void_shade*fade*core_weight):vec4(.64,.51,.78,.58*fade);
		}
	}
	return p;
}

void vertex(){
	int role=int(UV2.x+.1);
	float width;
	vec4 color;
	vec3 p=point_on_strip(role,UV2.y,UV.x,width,color);
	ink=color;
	float ignored;
	vec4 other;
	float dt=UV.x>.997?-.003:.003;
	vec3 tangent=(point_on_strip(role,UV2.y,UV.x+dt,ignored,other)-p)*sign(dt);
	vec3 view_axis=role==6?vec3(0.,1.,0.):normalize((inverse(MODELVIEW_MATRIX)*vec4(0.,0.,1.,0.)).xyz);
	vec3 normal=cross(tangent,view_axis);
	VERTEX=p+(UV.y-.5)*width*normal/max(.000001,length(normal));
}
void fragment(){
	float edge=1.-smoothstep(.38,1.,abs(UV.y*2.-1.));
	ALBEDO=ink.rgb;
	ALPHA=clamp(ink.a*edge,0.,1.);
}
