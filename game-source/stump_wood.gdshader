shader_type spatial;
uniform float radius = 1.0;
uniform float note_inset = 0.0;
uniform vec4 note_color : source_color = vec4(0.8,0.65,0.4,1.0);
varying vec3 wood_position;
varying vec3 wood_normal;
void vertex() { wood_position = VERTEX; wood_normal = NORMAL; }
void fragment() {
	vec2 p = wood_position.xz / max(radius,0.01);
	float a = atan(p.y,p.x);
	float r = length(p);
	float warped = r + sin(a*3.0+r*5.0)*0.018 + sin(a*7.0)*0.009;
	float rings = smoothstep(0.65,0.95,sin(warped*68.0));
	float fine = sin(warped*210.0)*0.022;
	vec3 cut_wood = mix(vec3(0.58,0.36,0.16),vec3(0.76,0.53,0.29),0.62 + sin(warped*14.0)*0.13);
	cut_wood *= 1.0 - rings*0.17 + fine;
	float grooves = pow(0.5+0.5*sin(a*27.0 + sin(wood_position.y*5.0+a*3.0)*0.65),7.0);
	float bark_fine = sin(a*95.0+wood_position.y*13.0)*0.025;
	vec3 bark = mix(vec3(0.12,0.055,0.025),vec3(0.27,0.14,0.065),0.60-grooves*0.5+bark_fine);
	float top = smoothstep(0.3,0.8,abs(wood_normal.y));
	vec3 wood = mix(bark,cut_wood,top);
	float inset = (1.0 - smoothstep(note_inset-0.018,note_inset+0.018,r)) * step(0.01,note_inset) * top;
	ALBEDO = mix(wood,note_color.rgb * (0.97-rings*0.04),inset);
	ROUGHNESS = 0.86;
}
