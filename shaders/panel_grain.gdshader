shader_type canvas_item;

uniform float grain_amount : hint_range(0.0, 0.3) = 0.05;

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

void fragment() {
	// pure alpha-blended speckle, no SCREEN_TEXTURE read needed -- half the pixels
	// are faint light specks, half are faint dark specks, composited normally over
	// whatever the panel already drew beneath this (its own bg color/border)
	float n = hash(FRAGCOORD.xy) - 0.5;
	vec3 speck_color = n > 0.0 ? vec3(1.0) : vec3(0.0);
	float speck_alpha = abs(n) * grain_amount * 2.0;
	COLOR = vec4(speck_color, speck_alpha);
}
