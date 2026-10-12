shader_type spatial;
render_mode blend_mix, diffuse_burley, specular_schlick_ggx;

uniform vec3 deep_water_color : source_color = vec3(0.035, 0.21, 0.31);
uniform vec3 shallow_water_color : source_color = vec3(0.12, 0.43, 0.53);
uniform float ripple_speed = 0.75;
uniform float ripple_scale = 62.0;

void fragment() {
	vec2 centered_uv = UV - vec2(0.5);
	float radial_distance = length(centered_uv);
	float circular_ripples = sin(radial_distance * ripple_scale - TIME * ripple_speed);
	float crossing_waves = sin((UV.x + UV.y) * 44.0 + TIME * 0.55)
		* cos((UV.x - UV.y) * 31.0 - TIME * 0.42);
	float fine_variation = sin(UV.x * 91.0 + TIME * 1.1)
		* sin(UV.y * 79.0 - TIME * 0.8);
	float brightness = clamp(0.48 + circular_ripples * 0.10 + crossing_waves * 0.09 + fine_variation * 0.04, 0.0, 1.0);
	ALBEDO = mix(deep_water_color, shallow_water_color, brightness);
	ALPHA = 0.84;
	ROUGHNESS = 0.22;
	METALLIC = 0.06;
	SPECULAR = 0.62;
}
