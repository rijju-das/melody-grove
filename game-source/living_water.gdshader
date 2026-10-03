shader_type spatial;
render_mode cull_disabled;

// Paused by the same clock as foliage. Sky reflections need no extra render pass.
uniform float breeze_time = 0.0;
varying vec2 pond_position;
varying vec3 local_normal;

void vertex() {
	pond_position = VERTEX.xz;
	float a = VERTEX.x * 22.0 + VERTEX.z * 8.0 + breeze_time * 1.5;
	float b = VERTEX.z * 30.0 - VERTEX.x * 11.0 - breeze_time;
	VERTEX.y += 0.018 * sin(a) + 0.012 * cos(b);
	NORMAL = normalize(vec3(-0.20 * cos(a), 1.0, 0.18 * sin(b)));
}
void fragment() {
	vec2 p = pond_position - vec2(0.12, -0.06);
	float d = length(p);
	float ripples = 0.0;
	for (int i = 0; i < 3; i++) {
		float age = fract(breeze_time / 4.0 + float(i) / 3.0);
		float radius = mix(0.04, 0.67, age);
		float ring = 1.0 - smoothstep(0.003, 0.009, abs(d - radius));
		ripples += ring * pow(sin(age * 3.14159265), 1.3);
	}
	float waves = sin(p.x * 80.0 + p.y * 33.0 + breeze_time * 1.4) * cos(p.y * 59.0 - breeze_time);
	float edge = smoothstep(0.55, 1.0, length(pond_position));
	vec3 deep = vec3(0.025, 0.135, 0.16);
	vec3 shallows = vec3(0.075, 0.33, 0.29);
	vec3 water = mix(deep, shallows, clamp(edge * 0.85 + waves * 0.07, 0.0, 1.0));
	ALBEDO = mix(water, vec3(0.54, 0.83, 0.76), clamp(ripples * 0.55, 0.0, 1.0));
	ROUGHNESS = 0.18;
	METALLIC = 0.22;
	SPECULAR = 0.8;
}
