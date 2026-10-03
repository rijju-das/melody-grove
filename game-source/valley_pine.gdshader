shader_type spatial;
render_mode cull_disabled;
varying vec3 leaf_position;
void vertex() { leaf_position = VERTEX; }
void fragment() {
	float variation = 0.5 + 0.5 * sin(leaf_position.y * 2.4 + leaf_position.x * 1.2);
	ALBEDO = mix(vec3(0.027,0.085,0.047),vec3(0.065,0.18,0.095),variation);
	ROUGHNESS = 0.92;
	SPECULAR = 0.15;
}
