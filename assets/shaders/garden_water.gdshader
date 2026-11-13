shader_type spatial;
render_mode unshaded, cull_disabled;
uniform float pond_size=1.5;
uniform float motion_enabled=1.0;
uniform float resonance=0.0;
varying vec3 local_point;
void vertex() {
	local_point = VERTEX;
	VERTEX.y += sin(VERTEX.x * 5.0 + (TIME*motion_enabled) * 0.7) * 0.005 + cos(VERTEX.z * 6.0 - (TIME*motion_enabled) * 0.5) * 0.004;
}
void fragment() {
	float r = length(local_point.xz);
	float ripple = sin(local_point.x * 7.0 + local_point.z * 4.0 - (TIME*motion_enabled) * 0.7) * 0.5 + 0.5;
	float shimmer = sin(local_point.x * 12.0 + local_point.z * 7.0 + (TIME*motion_enabled)) * 0.5 + 0.5;
	float sparkle = pow(sin(local_point.x * 30.0 + (TIME*motion_enabled) * 2.0) * sin(local_point.z * 26.0 - (TIME*motion_enabled) * 1.7) * 0.5 + 0.5, 6.0);
	float fres = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), 2.5);
	vec3 deep = vec3(0.10,0.19,0.18);
	vec3 shallow = vec3(0.20,0.32,0.26);
	ALBEDO = mix(deep, shallow, ripple * 0.08 + shimmer * 0.08 + smoothstep(0.55,1.0,r/pond_size)*0.65);
	EMISSION = vec3(0.5,0.8,0.85) * sparkle * 0.015;
	float answering_ring = pow(max(0.0, sin(r * 17.0 - TIME * motion_enabled * 1.1)), 16.0);
	EMISSION += vec3(0.32, 0.48, 0.26) * answering_ring * resonance * 0.075;
	ROUGHNESS = 0.23;
	SPECULAR = 0.85;
}
