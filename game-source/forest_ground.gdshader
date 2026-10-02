shader_type spatial;
varying vec3 world_position;
float noise(vec2 p) {
	return fract(sin(dot(p, vec2(127.1,311.7))) * 43758.5453);
}
float smooth_noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f*f*(3.0-2.0*f);
	return mix(mix(noise(i),noise(i+vec2(1,0)),f.x),mix(noise(i+vec2(0,1)),noise(i+vec2(1,1)),f.x),f.y);
}
void vertex() { world_position = (MODEL_MATRIX * vec4(VERTEX,1.0)).xyz; }
void fragment() {
	float patches = smooth_noise(world_position.xz * 0.6);
	float detail = smooth_noise(world_position.xz * 10.0);
	ALBEDO = mix(vec3(0.085,0.16,0.09),vec3(0.19,0.27,0.13),patches) * (0.87 + detail*0.22);
	ROUGHNESS = 0.95;
}
