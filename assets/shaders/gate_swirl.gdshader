shader_type spatial;
render_mode unshaded, cull_disabled, blend_add, depth_draw_never;
void fragment(){vec2 p=(UV-.5)*2.;float r=length(p);float a=atan(p.y,p.x);float edge=1.-smoothstep(.84,1.,r);float spiral=pow(.5+.5*sin(a*3.-r*17.+TIME*2.2),9.);float fine=pow(.5+.5*sin(a*7.+r*23.-TIME*1.5),16.);float rim=exp(-pow((r-.80)*20.,2.));float mist=(1.-r)*.10;float glow=(spiral*.48+fine*.14+rim*.75+mist)*edge*smoothstep(.03,.18,r);ALBEDO=mix(vec3(.06,.29,.65),vec3(.32,.78,1.),rim*.7+spiral*.3);EMISSION=ALBEDO*glow*.75;ALPHA=glow*.72;}
