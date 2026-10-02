shader_type spatial;
render_mode cull_disabled;

// The CPU advances this clock only while the game is playing.
uniform float breeze_time = 0.0;
varying vec2 pond_position;

void vertex() {
	pond_position = VERTEX.xz;
	VERTEX.y += 0.055 * sin(VERTEX.x * 15.0 + breeze_time * 1.57)
		+ 0.025 * cos(VERTEX.z * 19.0 - breeze_time * 1.57);
}

void fragment() {
	vec2 p = pond_position - vec2(0.12, -0.06);
	float d = length(p);
	float ripples = 0.0;
	for (int i = 0; i < 3; i++) {
		float age = fract(breeze_time / 4.0 + float(i) / 3.0);
		float radius = mix(0.04, 0.67, age);
		float ring = 1.0 - smoothstep(0.004, 0.012, abs(d - radius));
		ripples += ring * pow(sin(age * 3.14159265), 1.3);
	}
	float shimmer = sin(pond_position.x * 25.0 + breeze_time) *
		cos(pond_position.y * 21.0 - breeze_time * 0.8) * 0.035;
	vec3 jade = mix(vec3(0.035, 0.23, 0.21), vec3(0.075, 0.40, 0.34),
		clamp(0.6 + shimmer - d * 0.3, 0.0, 1.0));
	ALBEDO = mix(jade, vec3(0.48, 0.76, 0.62), clamp(ripples * 0.65, 0.0, 1.0));
	ROUGHNESS = 0.3;
	SPECULAR = 0.45;
}
