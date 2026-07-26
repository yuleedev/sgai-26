shader_type canvas_item;

uniform vec4 base_color : source_color = vec4(0.0784314, 0.0901961, 0.101961, 1.0);
uniform vec4 blob_color_a : source_color = vec4(0.105882, 0.129412, 0.121569, 1.0);
uniform vec4 blob_color_b : source_color = vec4(0.133333, 0.164706, 0.14902, 1.0);
uniform vec4 blob_color_c : source_color = vec4(0.168627, 0.196078, 0.188235, 1.0);
uniform float blob_scale : hint_range(0.1, 20.0) = 9.0;
uniform float fine_noise_strength : hint_range(0.0, 0.3) = 0.08;
uniform float grain_amount : hint_range(0.0, 0.3) = 0.15;
uniform float vignette_strength : hint_range(0.0, 1.0) = 0.6;
uniform float aspect_ratio : hint_range(0.1, 5.0) = 1.7778; // screen_width / screen_height; set at runtime in game_manager.gd
uniform bool show_grid = true;
uniform float grid_spacing : hint_range(20.0, 300.0) = 100.0;
uniform float grid_opacity : hint_range(0.0, 0.3) = 0.06;

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

// 3 octaves -- enough to break up the grid without reading as a repeating tile
float fbm(vec2 p) {
	float value = 0.0;
	float amplitude = 0.5;
	float total = 0.0;
	for (int i = 0; i < 3; i++) {
		value += value_noise(p) * amplitude;
		total += amplitude;
		p *= 2.0;
		amplitude *= 0.5;
	}
	return value / total;
}

void fragment() {
	float n = fbm(UV * blob_scale);
	int band = int(clamp(floor(n * 4.0), 0.0, 3.0));

	vec3 col;
	if (band == 0) {
		col = base_color.rgb;
	} else if (band == 1) {
		col = blob_color_a.rgb;
	} else if (band == 2) {
		col = blob_color_b.rgb;
	} else {
		col = blob_color_c.rgb;
	}

	// second, finer layer at 4x the scale and half amplitude -- breaks up the flat
	// interior of each posterized band so it reads as material, not a smooth gradient
	float fine = (value_noise(UV * blob_scale * 4.0) - 0.5) * 0.5;
	col += fine * fine_noise_strength;

	// static per-pixel grain -- no TIME input, so it reads as texture, not flicker
	float grain = hash(FRAGCOORD.xy) - 0.5;
	col += grain * grain_amount;

	if (show_grid) {
		vec2 grid_pos = mod(FRAGCOORD.xy, grid_spacing);
		float line_mask = clamp(step(grid_pos.x, 1.0) + step(grid_pos.y, 1.0), 0.0, 1.0);
		float tick_mask = step(grid_pos.x, 2.0) * step(grid_pos.y, 2.0);
		col += vec3(line_mask) * grid_opacity;
		col += vec3(tick_mask) * grid_opacity * 1.5;
	}

	// aspect-corrected radial distance: multiplying the x offset by aspect_ratio
	// (screen_width / screen_height) makes the falloff a true circle in physical
	// screen space instead of a circle in raw UV space (which would look stretched
	// on a non-square screen). length() is symmetric in both axes by construction,
	// so this is identical on the left and right, and identical on top and bottom.
	vec2 centered = UV - vec2(0.5);
	centered.x *= aspect_ratio;
	float dist = length(centered) * 2.0;
	float vignette = smoothstep(0.6, 1.0, dist);
	col *= (1.0 - vignette * vignette_strength);

	COLOR = vec4(col, 1.0);
}
