shader_type spatial;
varying vec3 rock_position;
varying vec3 rock_normal;
void vertex() { rock_position = VERTEX; rock_normal = NORMAL; }
void fragment() {
	float bands = 0.5 + 0.5 * sin(rock_position.y * 12.0 + sin(rock_position.x * 4.0));
	vec3 stone = mix(vec3(0.15,0.20,0.24),vec3(0.27,0.32,0.36),bands * 0.55);
	float moss = smoothstep(0.55,0.9,rock_normal.y) * (0.5+0.5*sin(rock_position.x*6.0));
	ALBEDO = mix(stone,vec3(0.13,0.20,0.10),moss*0.6);
	ROUGHNESS = 0.93;
	SPECULAR = 0.12;
}
