shader_type spatial;
render_mode blend_mix, diffuse_burley, specular_schlick_ggx;

uniform vec3 deep_water_color : source_color = vec3(0.025, 0.13, 0.105);
uniform vec3 shallow_water_color : source_color = vec3(0.14, 0.31, 0.235);
uniform float ripple_speed = 0.34;
uniform float ripple_scale = 28.0;

void fragment() {
	vec2 water_uv = UV * vec2(1.0, 2.2);
	float long_waves = sin((water_uv.x + water_uv.y * 0.18) * ripple_scale - TIME * ripple_speed);
	float crossing_waves = sin((water_uv.x - water_uv.y * 0.26) * 18.0 + TIME * 0.24)
		* cos((water_uv.x + water_uv.y * 0.22) * 13.0 - TIME * 0.19);
	float brightness = clamp(0.53 + long_waves * 0.045 + crossing_waves * 0.025, 0.0, 1.0);
	ALBEDO = mix(deep_water_color, shallow_water_color, brightness);
	ALPHA = 0.90;
	ROUGHNESS = 0.36;
	METALLIC = 0.0;
	SPECULAR = 0.28;
}
