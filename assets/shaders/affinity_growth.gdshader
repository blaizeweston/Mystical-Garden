shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, depth_draw_never;
uniform sampler2D masks : filter_linear_mipmap, repeat_disable;
uniform int effect;
uniform vec2 extent;
uniform float elapsed;
uniform float remaining;
uniform float variation;
uniform int stacks;
uniform float fire_height;
uniform float fire_flicker;
uniform float fire_smoke;
uniform float fire_embers;
uniform float frost_petals;
uniform float frost_mist;
uniform float thorn_bark;
uniform float thorn_spines;
uniform float affinity_status;

varying flat int role;
varying float opacity;
varying vec3 pigment;
varying float atlas_tile;
varying float bend;
varying vec3 bark_position;

void vertex(){
	role=int(round(UV2.x));
	float seed=UV2.y;
	float time=elapsed;
	float phase=seed*6.283+variation;
	bool status=effect>=5 && effect<=7;
	float fade=smoothstep(0.0,0.19,remaining);
	opacity=fade*(status ? affinity_status : 1.0);
	pigment=COLOR.rgb;
	atlas_tile=-1.0;
	bend=0.0;
	vec3 point=VERTEX;
	bark_position=point;
	vec2 size=vec2(0.0);
	if (role==0 || role==6){
		bool charred=effect==0;
		float start=effect==2 ? length(point.xz) : point.x*0.5+0.5;
		float spread=smoothstep(start*0.22,start*0.22+0.21,time);
		if (!charred && role==0) {point.xz+=UV*(thorn_bark-1.0);}
		if (!charred && role==6) {point.y*=thorn_spines;}
		point.y*=spread;
		opacity*=spread*(charred ? .97 : .95);
	} else if (role==4){
		if (effect==6){
			point.y=point.y*.60+.24;
			if(seed>=float(stacks)) {opacity=0.0;}
		} else {
			// Closing begins from the opening pose; both events share the same petal arrangement.
			float bloom=effect==3 ? smoothstep(0.0,.31,time) : 1.0-smoothstep(0.0,.29,time);
			point.y=(point.y*bloom+length(point.xz)*(1.0-bloom)*.92)*frost_petals;
			point.xz*=mix(.25,1.0,bloom);
			opacity*= effect==3 ? .66 : .66*(1.0-smoothstep(.23,.42,time));
			if(effect==3){opacity=.66*smoothstep(0.0,.065,time);}
		}
	} else if(role==8){
		opacity=(effect==3 ? 1.0 : fade)*.44;
	} else if(role==1){
		float flutter=sin(time*6.4*fire_flicker+phase)+.36*sin(time*11.3*fire_flicker-phase);
		size=vec2(.33+seed*.19,(.57+seed*.40+flutter*.077)*fire_height);
		bend=.055*flutter;
		pigment=mix(vec3(1.,.32,.075),vec3(1.,.70,.24),seed);
		opacity*=.88;
		atlas_tile=0.;
		if(status){size*=.48+.23*(1.0-smoothstep(0.,.28,time));point.y+=.16;}
	} else if(role==2 || role==3){
		bool ember=role==3;
		float life=fract(time*(ember ? .76*fire_embers : .47)+seed+variation);
		point.y+=life*(ember ? .95 : 1.15);
		point.x+=sin(life*3.6+phase)*.057;
		point.z+=sin(life*3.0+phase)*.085;
		size=ember ? vec2(.085,.145)*(1.-.58*life) : vec2(.42,.30)*(1.+life);
		opacity*=sin(life*3.14159)*(ember ? .91 : fire_smoke);
		pigment=ember ? vec3(1.,.66,.25) : vec3(.56,.52,.49);
		atlas_tile=ember ? 2. : 1.;
		if(status){size*=.68;point.y*=.67;}
	} else if(role==5){
		float life=effect==8 ? clamp(time/max(.01,time+remaining),0.,1.) : fract(time*.83+seed);
		point.xz*=effect==8 ? .4+life : 1.;
		point.y+=effect==8 ? life*.33 : .26+sin(time*3.+phase)*.12;
		size=vec2(.62,.40)*(.55+seed*.5+life*.26);
		opacity*=frost_mist*sin(life*3.14159);
		pigment=vec3(.80,.91,.92);
		atlas_tile=1.;
	} else if(role==7){
		float life=fract(time*.65+seed);
		point.y+=.49-life*.37;
		point.z+=sin(life*2.4+phase)*.06;
		size=vec2(.12,.22)*(.85+.35*seed);
		opacity*=.65+.25*sin(life*3.14);
		pigment=mix(vec3(.42,.09,.16),vec3(.77,.28,.34),seed);
		atlas_tile=3.;
	}
	if(effect>=9){
		// Only the confirmed upgrade receipt owns this short accent at its source.
		float burst=clamp(time/max(.01,time+remaining),0.,1.);
		point.xz*=.24+1.65*burst;
		point.y+=sin(3.14159*burst)*(.26+.23*seed);
		size*=1.0-.55*burst;
		opacity*=1.0-smoothstep(.35,1.,burst);
	}
	point.xz*=extent;
	vec4 camera=MODELVIEW_MATRIX*vec4(point,1.0);
	if(atlas_tile>=0.0){
		camera.xy+=vec2((UV.x-.5)*size.x,(1.-UV.y)*size.y);
	}
	POSITION=PROJECTION_MATRIX*camera;
}

void fragment(){
	float alpha=opacity;
	vec3 tint=pigment;
	if(role==7 && effect==7){tint=mix(tint,vec3(.88,.52,.57),.35*smoothstep(.45,.80,UV.y));}
	if(role==0){
		float striation=sin(bark_position.x*35.+sin(bark_position.z*22.)*2.+bark_position.y*14.);
		tint*=.88+.12*striation;
		if(effect==0){tint+=vec3(.14,.035,.005)*smoothstep(.65,1.,striation);}
	}
	if(atlas_tile>=0.0){
		vec2 local=UV;
		if(role==1){
			local.x+=bend*(1.-local.y)*(1.-local.y);
			tint=mix(tint,vec3(1.,.86,.45),smoothstep(.60,.95,local.y)*.65);
		}
		local=clamp(local,vec2(.012),vec2(.988));
		alpha*=texture(masks,vec2((atlas_tile+local.x)*.25,local.y)).a;
	}
	if(alpha<.016){discard;}
	ALBEDO=tint;
	ALPHA=alpha;
}
