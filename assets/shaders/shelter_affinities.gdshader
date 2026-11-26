shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;

uniform sampler2D atlas : filter_linear, repeat_disable;
uniform float elapsed;
uniform float phase;
uniform float extent;
uniform float seed_offset;
uniform float strength=1.0;
uniform bool persistent;
uniform bool gentle;
uniform bool local_drops;
uniform bool worn;
uniform bool burst;
uniform bool expend;
uniform bool still_chip;
uniform bool bloom;
uniform float water_opacity=.78;
uniform float water_crest=1.0;
uniform float wood_grain=.7;
uniform float wood_thickness=1.0;
uniform float vital_petals=1.0;
uniform float vital_pollen=.72;
varying flat float part;
varying float variation;
varying float coverage;

void vertex(){
	part=round(UV2.x);
	variation=UV2.y;
	float h=fract(variation*12.61+seed_offset);
	float cycle=fract(elapsed*(.83+h*.34)+h);
	float grow=smoothstep(0.,.30,phase);
	coverage=persistent ? 1. : (.25+.75*smoothstep(0.,.09,phase))*(1.-smoothstep(.71,1.,phase));
	vec3 p=VERTEX;
	float sprite=0.;
	if(part<1.5 && !local_drops){
		p.x*=extent;
		p.y*=water_crest*(gentle ? .60 : 1.);
		p.y+=.055*sin(6.*elapsed+12.*VERTEX.x+3.*variation);
	}
	if(part==1.){
		if(local_drops){
			p.y+=(gentle ? cycle : 1.-cycle)*.65;
			coverage*=smoothstep(.0,.13,cycle)*(1.-smoothstep(.72,1.,cycle))*(.38+.62*strength);
		}else{
			p.y+=sin(cycle*3.14159)*.29*water_crest;
			p.z+=cycle*.23;
		}
		sprite=.055+.030*h;
	}
	if(part==2.){
		p.xz*=.9+.1*wood_thickness;
		p.y=(p.y-.45)*wood_thickness+.45;
		if(!worn){p.y-=.45*(1.-grow);p.xz*=1.+.6*(1.-grow);}
		else{p.y-=.24*(1.-smoothstep(0.,.20,elapsed));}
		coverage*=worn ? (.47+.43*strength) : .94;
	}
	if(part==3.){
		p.y=(p.y-.43)*wood_thickness+.43;
		if(still_chip){p.x*=wood_thickness;}
		if(!still_chip){
			vec2 axis=normalize(p.xz+vec2(.0001));
			float radius=burst ? max(0.,extent-.5) : .39;
			float travel=1.-pow(1.-phase,2.);
			if(expend){travel=smoothstep(.18,.76,phase);p.xz*=1.-.7*sin(min(phase/.18,1.)*3.1416);}
			p.xz+=axis*radius*travel;
			p.y+=sin(phase*3.14)*(.15+h*.16)-phase*.12;
		}
	}
	if(part==4.){
		float opening=bloom ? .35+.65*grow : .94+.06*sin(2.*elapsed+h*5.);
		p.xz*=opening*(bloom ? max(.7,extent)*.93 : 1.);
		p.y*=vital_petals*(bloom ? 1.35-.45*grow : 1.);
	}
	if(part==5.){
		p.xz*=bloom ? extent*(.4+.55*grow) : 1.;
		p.y+=cycle*(bloom ? .85 : .46);
		p.x+=sin(cycle*4.+h*8.)*.09;
		sprite=.065+.042*h;
		coverage*=vital_pollen*sin(3.1416*cycle);
	}
	if(part==7.){p.z*=extent*(1.-smoothstep(.02,.67,phase));p.x*=wood_thickness;coverage*=1.-phase;}
	if(part==6.){
		p.xz*=extent*(gentle ? 1.-phase : phase);
		p.y+=.08;
	}
	// Expand textured motes in camera space. Plates, petals and crests stay world-oriented.
	vec4 view=MODELVIEW_MATRIX*vec4(p,1.);
	view.xy+=(UV-.5)*vec2(sprite,sprite*(part==1. ? 1.65 : 1.));
	POSITION=PROJECTION_MATRIX*view;
}

void fragment(){
	vec3 col;
	float alpha=coverage;
	if(part==0.){
		float filament=.5+.5*sin(19.*UV.x-9.*elapsed+2.5*sin(UV.x*9.+elapsed)+UV.y*6.);
		col=mix(gentle ? vec3(.17,.56,.53) : vec3(.06,.38,.48),vec3(.75,.94,.90),smoothstep(.58,.96,filament)*.65+.3*UV.y);
		alpha*=water_opacity*(.39+.53*UV.y)*smoothstep(0.,.10,UV.x)*(1.-smoothstep(.90,1.,UV.x));
	}else if(part==1. || part==5.){
		float tile=part==1. ? 1. : 0.;
		alpha*=texture(atlas,vec2((tile+UV.x)*.25,UV.y)).a;
		col=part==1. ? vec3(.65,.89,.95) : mix(vec3(.73,.85,.29),vec3(1.,.83,.43),variation);
		if(part==1.){alpha*=water_opacity;}
	}else if(part==2. || part==3. || part==7.){
		float grain=sin(32.*UV.x+2.8*sin(UV.y*5.+variation*9.));
		float ridge=1.-smoothstep(.015,.27,abs(UV.x-.5));
		col=mix(vec3(.19,.086,.040),vec3(.70,.47,.22),clamp(.20+ridge*.42+wood_grain*.20*grain+variation*.18,0.,1.));
		if(part==2.){col=mix(col,vec3(.77,.68,.49),.29*ridge);}
	}else if(part==4.){
		float vein=1.-smoothstep(.012,.11,abs(UV.x-.5+.035*sin(UV.y*8.)));
		col=mix(vec3(.25,.53,.23),vec3(.91,.84,.48),UV.y*.78+vein*.19);
		alpha*=.72+.13*vein;
	}else{
		col=gentle ? vec3(.53,.85,.74) : vec3(.38,.74,.88);
		alpha*=water_opacity*.78;
	}
	ALBEDO=col;
	ALPHA=clamp(alpha,0.,1.);
}
