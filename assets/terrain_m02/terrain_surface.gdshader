shader_type spatial;

uniform vec3 meadow_color : source_color;
uniform vec3 meadow_shade : source_color;
uniform vec3 soil_color : source_color;
uniform vec3 soil_shade : source_color;
uniform vec3 forest_floor_color : source_color;
uniform vec3 forest_floor_shade : source_color;
uniform vec3 stone_color : source_color;
uniform vec3 stone_shade : source_color;
uniform vec3 water_color : source_color;
uniform vec3 water_shade : source_color;

varying vec2 ground;

float hash(vec2 p) {
	p = fract(p * vec2(0.1031, 0.11369));
	p += dot(p, p.yx + 19.19);
	return fract((p.x + p.y) * p.x);
}

float noise2(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1,0)), f.x),
		mix(hash(i + vec2(0,1)), hash(i + vec2(1,1)), f.x), f.y);
}

void vertex() {
	ground = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
}

void fragment() {
	vec4 land = vec4(UV, UV2);
	float water = clamp(1.0 - dot(land, vec4(1.0)), 0.0, 1.0);
	vec2 p = ground;
	float broad = noise2(p * 0.43);
	float fine = noise2(p * 9.5);
	float grain = noise2(p * 31.0);
	float patches = noise2(p * 1.8);
	// Detail is sampled in world space, so texture direction and scale continue across cells.
	vec3 meadow = mix(meadow_shade, meadow_color, 0.16 + 0.55*broad + 0.22*fine + 0.07*grain);
	meadow += vec3(0.035, 0.038, 0.005) * smoothstep(0.79, 0.95, fine);
	vec3 soil = mix(soil_shade, soil_color, 0.22 + 0.52*broad + 0.20*fine + 0.06*grain);
	vec3 forest = mix(forest_floor_shade, forest_floor_color, 0.25 + 0.4*patches + 0.35*fine);
	forest += vec3(0.045, 0.025, 0.006) * smoothstep(0.75, 0.96, grain);
	float strata = noise2(vec2(p.x * 0.85 + p.y * 0.37, p.y * 3.7));
	vec3 stone = mix(stone_shade, stone_color, 0.24 + 0.33*broad + 0.3*strata + 0.13*fine);
	vec3 ground_color = (meadow * land.x + soil * land.y + forest * land.z + stone * land.w)
		/ max(1.0 - water, 0.001);
	float bank_noise = 0.55*noise2(p * 2.25) + 0.3*patches + 0.15*fine;
	float shoreline = clamp(water + (bank_noise - 0.5) * 0.56 * (4.0 * water * (1.0 - water)), 0.0, 1.0);
	float wet = smoothstep(0.10, 0.48, shoreline);
	float coverage = smoothstep(0.25, 0.64, shoreline);
	float depth = smoothstep(0.45, 0.98, shoreline);
	vec2 current = vec2(p.x + p.y * 0.23, p.y - p.x * 0.11);
	float turbulence = noise2(current * vec2(2.0, 0.53) + vec2(0, -TIME * 0.10));
	float ripple = sin(current.y * 15.0 + 7.0*turbulence + current.x*2.5 - TIME*1.9);
	float glints = smoothstep(0.46, 0.98, ripple)
		* smoothstep(0.29, 0.82, noise2(current * vec2(1.4, 3.5) + vec2(0, -TIME * 0.20)));
	vec3 water_surface = mix(water_color, water_shade, 0.8 * depth + 0.09 * broad);
	water_surface += vec3(0.085, 0.12, 0.105) * glints * (0.8 - 0.4 * depth);
	ALBEDO = mix(ground_color * (1.0 - 0.31 * wet), water_surface, coverage);
	ROUGHNESS = mix(0.97, 0.28, coverage);
	SPECULAR = mix(0.12, 0.45, coverage);
}
