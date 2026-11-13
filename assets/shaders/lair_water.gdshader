shader_type spatial;
varying vec3 world;
varying vec2 pool_uv;
uniform float phase_strength : hint_range(0.0, 1.0) = 0.0;

void vertex() {
	pool_uv = VERTEX.xz;
	float angle = atan(VERTEX.z, VERTEX.x + 0.00001);
	VERTEX.xz *= 1.0 + 0.045 * sin(angle * 5.0) + 0.032 * cos(angle * 8.0 + 0.4);
	world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float wave = sin(world.x * 2.8 + TIME * (0.9 + phase_strength * 0.9))
		* sin(world.z * 3.7 - TIME * (0.7 + phase_strength * 0.7));
	float ripple = sin(world.x * 4.3 + world.z * 2.1 - TIME * (1.3 + phase_strength)) * 0.5 + 0.5;
	float edge = smoothstep(0.70, 0.99, length(pool_uv) + wave * 0.027);
	vec3 deep = mix(vec3(0.024, 0.078, 0.084), vec3(0.085, 0.21, 0.205),
		clamp(0.34 + wave * (0.18 + phase_strength * 0.16) + ripple * 0.17, 0.0, 1.0));
	ALBEDO = mix(deep, vec3(0.132, 0.117, 0.082), edge);
	EMISSION = deep * (0.10 + ripple * 0.11) * (1.0 - edge);
	ROUGHNESS = mix(0.26 + wave * 0.065, 0.90, edge);
	SPECULAR = mix(0.58, 0.20, edge);
	NORMAL_MAP = vec3(0.5 + wave * 0.045, 0.5 + sin(world.z * 4.0 + TIME) * 0.035, 1.0);
}
