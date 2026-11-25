shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, depth_draw_never;

// Local X follows the recorded delivery. UV.x is the fragment index and UV.y
// selects splinter, fracture facet, contact glint or frost dust.
uniform float elapsed;
uniform float lifetime;
uniform float fragment_count;
uniform float speed;
uniform float size_scale;
uniform vec2 splinter_shape = vec2(1.0);
uniform float spread;
uniform float sequence;
uniform float energy;
uniform float flash_strength;
uniform vec4 tint : source_color;
varying float brightness;
varying float opacity;

float noise1(float key) {
	return fract(sin(key * 78.233 + sequence * 1.79) * 437.585);
}

void vertex() {
	float i = UV.x;
	float role = UV.y;
	float r = noise1(i + 2.0);
	float t = clamp(elapsed / lifetime, 0.0, 1.0);
	float angle = i * 2.39996 + sequence * 0.31;
	vec3 travel;
	if (role < 0.5) {
		// Scatter back off the entry surface, leaving the body visible even
		// when the attack travels directly away from the camera.
		float yaw = ((i + 0.25 + 0.5*r) / fragment_count - 0.5) * spread;
		travel = normalize(vec3(-cos(yaw), 0.32 + 1.05 * noise1(i+7.0), sin(yaw)));
	} else {
		travel = normalize(vec3(cos(angle), -0.32 + 1.17 * noise1(i+11.0), sin(angle)));
	}
	vec3 cross_axis = normalize(cross(travel, vec3(0.0, 1.0, 0.0)));
	vec3 upright = cross(cross_axis, travel);
	float flight = elapsed * speed * (1.0 - 0.43 * t) * (0.65 + 0.55*r);
	vec3 offset = travel * (0.07 + flight);
	offset.y -= 1.4 * elapsed * elapsed;
	float shrink = (1.0 - smoothstep(0.40, 1.0, t)) * size_scale;
	float length_scale = role < 0.5 ? 0.25 * splinter_shape.x : 0.24;
	float width_scale = role < 0.5 ? 0.058 * splinter_shape.y : 0.095;
	opacity = 1.0 - smoothstep(0.47 + 0.18*r, 1.0, t);
	if (role > 1.5 && role < 2.5) {
		offset = travel * (0.035 + t*0.13);
		shrink *= sqrt(flash_strength) * (1.0 - smoothstep(0.0,0.32,t));
		length_scale = 0.22;
		width_scale = 0.070;
	} else if (role > 2.5) {
		offset *= 0.63;
		offset.y += elapsed * 0.36;
		length_scale = 0.060;
		width_scale = 0.043;
		opacity *= 0.52;
	}
	vec3 local = VERTEX;
	float spin = r * 3.14 + elapsed * (2.0 + 5.0*r);
	local.yz = mat2(vec2(cos(spin),sin(spin)),vec2(-sin(spin),cos(spin))) * local.yz;
	VERTEX = offset + shrink * (travel*local.x*length_scale + upright*local.y*width_scale + cross_axis*local.z*width_scale);
	brightness = COLOR.r * (role > 1.5 && role < 2.5 ? 1.38 : 1.0);
}

void fragment() {
	ALBEDO = mix(tint.rgb, vec3(1.0), 0.16) * brightness * (0.62 + energy*0.58);
	ALPHA = opacity;
}
