shader_type spatial;

uniform sampler2D cell_labels : filter_nearest, repeat_disable;
uniform ivec2 label_origin;
uniform float center_spacing = 1.75;
uniform vec2 seed_offset;
uniform sampler2D feature_distances : filter_linear, repeat_disable;
uniform vec2 feature_origin;
uniform vec2 feature_extent;
uniform vec2 feature_size;
uniform float feature_range;
uniform bool feature_mode = false;
uniform int art_mode = 0;
uniform bool botanical_mode = false;
uniform bool wilds_mode = false;
uniform float wilds_moisture = 0.0;
uniform vec3 wilds_floor : source_color;
uniform vec3 wilds_water : source_color;
uniform bool continuity_mode = false;
uniform vec3 botanical_ground : source_color;
uniform vec3 botanical_water : source_color;
uniform bool show_water = true;
uniform bool show_paths = true;
uniform bool show_ground = true;
uniform sampler2D leafy_ground : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D forest_ground : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
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

const float ROOT_3 = 1.732050808;
// A q or r index two steps from the rounded sample is at least sqrt(3)*1.5/2
// away. The kernel dies before that, so changing the 3×3 window adds zero weight.
const float RADIUS_SQUARED = 1.24 * 1.24;
varying vec2 world_xz;

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

vec2 noise_pair(vec2 p) {
	return vec2(noise2(p), noise2(p + vec2(23.37, 9.13))) * 2.0 - 1.0;
}

float sample_field(vec2 world, out vec4 land, out float water) {
	vec2 p = world / center_spacing;
	vec2 n = p + seed_offset;
	// A shared world-space warp bends the continuous field without moving mesh vertices.
	p += 0.36 * noise_pair(n * 0.49) + 0.15 * noise_pair(n * 1.25)
		+ 0.065 * noise_pair(n * 2.7);
	float r = 2.0 / ROOT_3 * p.y;
	vec2 axial = vec2(p.x - 0.5 * r, r);
	ivec2 center = ivec2(floor(axial + vec2(0.5)));
	ivec2 map_size = textureSize(cell_labels, 0);
	land = vec4(0.0);
	water = 0.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			ivec2 cell = center + ivec2(x, y);
			ivec2 texel = cell - label_origin;
			if (any(lessThan(texel, ivec2(0))) || any(greaterThanEqual(texel, map_size))) {
				continue;
			}
			int label = int(round(texelFetch(cell_labels, texel, 0).r * 255.0));
			vec2 delta = axial - vec2(cell);
			float squared = dot(delta, delta) + delta.x * delta.y;
			float support = max(0.0, 1.0 - squared / RADIUS_SQUARED);
			float weight = support * support * support * support;
			if (label >= 0 && label < 4) {
				land[label] += weight;
			} else if (label == 4) {
				water += weight;
			}
		}
	}
	float support = dot(land, vec4(1.0)) + water;
	float total = max(support, 0.0001);
	water /= total;
	land /= total;
	return support;
}

void vertex() {
	world_xz = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
}

void fragment() {
	vec2 p = world_xz;
	vec2 grain = p + seed_offset;
	vec4 land;
	float water;
	float support = sample_field(p, land, water);
	// At the outer rim a warped sample can leave the finite map. Ease back
	// to the welded M02 weights only when the continuous field loses support.
	vec4 rim = vec4(UV, UV2);
	float rim_weight = 1.0 - smoothstep(0.004, 0.024, support);
	land = mix(land, rim, rim_weight);
	water = mix(water, clamp(1.0 - dot(rim, vec4(1.0)), 0.0, 1.0), rim_weight);

	float macro = noise2(grain * 0.21);
	float patches = noise2(grain * 0.91 + vec2(3.8, 0.7));
	float damp = smoothstep(0.35, 0.82, 0.72 * macro + 0.28 * patches);
	float bank = smoothstep(0.08, 0.50, water);
	float edge_width = clamp(fwidth(water) * 0.75, 0.035, 0.16);
	float cover = smoothstep(0.50 - edge_width, 0.50 + edge_width, water);
	// The bed stays visible through the colored shallows. Depth comes from the same mask.
	float depth = smoothstep(0.53, 0.96, water);
	float path_weight = 0.0;
	if (feature_mode) {
		vec2 unit = clamp((p - feature_origin) / feature_extent, vec2(0.0), vec2(1.0));
		vec2 texel = (unit * (feature_size - vec2(1.0)) + 0.5) / feature_size;
		vec3 field = (texture(feature_distances, texel).rgb * 2.0 - 1.0) * feature_range;
		// Old water cells are substrate in the feature view. Actual water comes from the polygon only.
		land.y += water;
		float clearing = 1.0 - smoothstep(-0.22, 0.30, field.b);
		if (continuity_mode) {
			// Keep mottled substrate through clearings rather than painting a solid meadow stamp.
			float fringe = field.b + (patches - 0.5) * 0.76 + (macro - 0.5) * 0.72;
			clearing = (1.0 - smoothstep(-0.70, 0.96, fringe)) * (0.35 + 0.24 * patches);
		}
		land = mix(land, vec4(1.0, 0.0, 0.0, 0.0), clearing * 0.97);
		float edge = clamp(fwidth(field.r) * 0.70, 0.04, 0.18);
		cover = show_water ? 1.0 - smoothstep(-edge, edge, field.r) : 0.0;
		bank = show_water ? 1.0 - smoothstep(-0.21, 0.54, field.r) : 0.0;
		depth = 1.0 - smoothstep(-1.40, -0.05, field.r);
		water = mix(0.51, 1.0, depth);
		float trail = 1.0 - smoothstep(-0.32 + (patches - 0.5) * 0.3, 0.10, field.g);
		if (continuity_mode) {
			float lip = (patches - 0.5) * 0.21;
			trail = 1.0 - smoothstep(-0.23 + lip, 0.12 + lip, field.g);
		}
		path_weight = show_paths ? trail : 0.0;
	}

	vec2 uv_a = p * 0.37;
	vec2 uv_b = vec2(0.78 * p.x - 0.62 * p.y, 0.62 * p.x + 0.78 * p.y) * 0.55 + vec2(0.32, 0.57);
	vec3 leaf_detail = texture(leafy_ground, uv_a).rgb;
	vec3 soil_detail = texture(forest_ground, uv_b).rgb;
	float leaf_grain = dot(leaf_detail, vec3(0.32, 0.52, 0.16));
	float soil_grain = dot(soil_detail, vec3(0.31, 0.55, 0.14));
	float flecks = noise2(grain * 6.5);
	float small_tufts = smoothstep(0.48, 0.84, noise2(grain * vec2(3.4, 5.2)));
	vec3 meadow = mix(meadow_shade, meadow_color, 0.32 + 0.42 * macro);
	meadow *= (0.51 + 0.75 * leaf_grain + 0.16 * small_tufts) * vec3(1.05, 0.91, 0.92);
	meadow = mix(meadow, leaf_detail * vec3(0.55, 0.65, 0.45), 0.27);
	vec3 soil = mix(soil_shade, soil_color, 0.33 + 0.34 * macro);
	soil *= 0.65 + 0.48 * soil_grain + 0.26 * flecks;
	soil = mix(soil, soil_detail * vec3(0.57, 0.49, 0.41), 0.19);
	vec3 forest = mix(forest_floor_shade * vec3(1.08, 0.83, 0.77), forest_floor_color, patches * 0.51);
	forest *= 0.58 + 0.51 * soil_grain + 0.13 * small_tufts;
	forest = mix(forest, leaf_detail * vec3(0.53, 0.45, 0.31), 0.33);
	forest *= 0.82 + 0.32 * noise2(grain * 0.53);
	// Rotated, warped bands give stone seams at two scales without model-atlas UVs.
	vec2 rock_space = vec2(grain.x + 0.64 * grain.y, grain.y - 0.31 * grain.x);
	rock_space += noise_pair(rock_space * 0.85) * 0.34;
	float rock_face = noise2(rock_space * vec2(1.9, 3.7));
	float grain_rock = noise2(rock_space * vec2(8.0, 13.5));
	float fissure = smoothstep(0.015, 0.105, abs(rock_face + 0.10 * grain_rock - 0.49));
	vec3 stone = mix(stone_shade, stone_color, 0.25 + 0.11 * fissure + 0.30 * patches + 0.29 * grain_rock);
	stone *= vec3(0.93, 0.96, 0.96);

	float dry_total = dot(land, vec4(1.0));
	vec3 material_color = meadow * land.x + soil * land.y + forest * land.z + stone * land.w;
	// Fade in a continuous sand/gravel bed as the dry confidence vanishes.
	vec3 bed = soil * (0.76 + 0.22 * flecks) + vec3(0.018, 0.023, 0.019) * patches;
	vec3 dry = mix(bed, material_color / max(dry_total, 0.001), smoothstep(0.02, 0.20, dry_total));
	dry = show_ground ? dry : vec3(0.105, 0.115, 0.106);
	vec3 worn_trail = mix(soil * 1.25, vec3(0.41, 0.33, 0.21), 0.29 + 0.20 * flecks);
	dry = mix(dry, worn_trail, path_weight * (0.69 + 0.21 * patches));
	dry *= mix(vec3(1.0), vec3(0.69, 0.77, 0.73), max(bank, damp * 0.46));

	vec2 flow = vec2(p.x + p.y * 0.29, p.y - p.x * 0.36);
	float eddy = noise2(flow * vec2(1.27, 0.59) + vec2(0.0, -TIME * 0.12));
	float curl = noise2(flow * 1.9 + vec2(-TIME * 0.10, TIME * 0.06));
	float wave_a = sin(2.3 * flow.x + 12.8 * flow.y + 6.0 * eddy - TIME * 1.3);
	float wave_b = sin(-4.4 * flow.x + 5.7 * flow.y + 5.2 * curl - TIME * 0.82);
	float ripple = smoothstep(0.62, 1.0, 0.71 * wave_a + 0.29 * wave_b);
	float shimmer = ripple * smoothstep(0.25, 0.85, curl);
	vec3 shallow = mix(bed, water_color * vec3(0.67, 1.05, 1.01), 0.58);
	vec3 deep = water_shade * (0.81 + 0.27 * macro) + vec3(0.013, 0.028, 0.027);
	vec3 water_surface = mix(shallow, deep * (0.89 + 0.18 * damp), depth);
	water_surface += vec3(0.023, 0.034, 0.033) * shimmer * (0.84 - 0.43 * depth);
	water_surface += vec3(0.025, 0.042, 0.030) * (1.0 - smoothstep(0.0, 0.11, abs(water - 0.55))) * (0.55 + 0.45 * patches);
	float bed_detail = (soil_grain - 0.46) * 0.082 * (1.0 - depth);
	water_surface += vec3(bed_detail * 0.58, bed_detail * 0.92, bed_detail);
	if (art_mode == 1) {
		float center = 1.0 - smoothstep(4.6, 10.1, length(p * vec2(1.0, 1.04)) + (patches - 0.5) * 1.25);
		if (continuity_mode) {
			vec2 cast = p - vec2(-0.8, -0.45);
			float dapple = length(vec2(cast.x + 0.23 * cast.y, 0.87 * cast.y))
				+ (macro - 0.5) * 3.1 + (patches - 0.5) * 1.4;
			center = 1.0 - smoothstep(2.0, 11.1, dapple);
			center = max(center, 0.36 * path_weight);
		}
		vec3 sheltered = dry * vec3(0.57, 0.64, 0.52);
		vec3 warmed = dry * vec3(1.00, 0.92, 0.68);
		dry = mix(sheltered, warmed, center);
		water_surface *= vec3(0.66, 0.76, 0.64);
	} else if (art_mode == 2) {
		float waylight = max(0.70 * path_weight, 0.47 * bank);
		float canopies = smoothstep(0.33, 0.72, 0.72 * macro + 0.28 * patches);
		dry *= mix(vec3(0.45, 0.54, 0.47), vec3(0.84, 0.83, 0.66),
			clamp(waylight + 0.54 * canopies + 0.20 * land.w, 0.0, 1.0));
		water_surface *= vec3(0.56, 0.68, 0.59);
	}
	if (botanical_mode) {
		dry *= mix(vec3(1.0), botanical_ground, 0.40 - 0.16 * path_weight);
		water_surface *= mix(vec3(1.0), botanical_water, 0.40);
	}
	if (wilds_mode) {
		dry *= mix(vec3(1.0), wilds_floor, 0.42 + 0.24 * damp);
		dry *= 1.0 - wilds_moisture * (0.10 + 0.21 * max(bank, damp));
		water_surface = mix(water_surface, wilds_water * (0.53 + 0.19 * eddy), 0.58);
	}
	ALBEDO = mix(dry, water_surface, cover);

	ROUGHNESS = mix(0.90 - (wilds_mode ? wilds_moisture * 0.12 : 0.0) - 0.15 * damp - 0.14 * bank - 0.13 * land.w + 0.05 * flecks, 0.39 + 0.09 * eddy, cover);
	SPECULAR = mix(0.19 + 0.11 * bank, 0.34, cover);
}
