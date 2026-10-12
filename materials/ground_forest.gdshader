shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

uniform vec3 soil_dark : source_color = vec3(0.12, 0.16, 0.075);
uniform vec3 soil_mid : source_color = vec3(0.25, 0.29, 0.13);
uniform vec3 moss_color : source_color = vec3(0.30, 0.36, 0.16);
uniform float texture_scale = 3.2;
uniform float roughness_value : hint_range(0.5, 1.0) = 0.94;

float hash21(vec2 p) {
    p = fract(p * vec2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}

float noise2(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    float a = hash21(i);
    float b = hash21(i + vec2(1.0, 0.0));
    float c = hash21(i + vec2(0.0, 1.0));
    float d = hash21(i + vec2(1.0, 1.0));
    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void fragment() {
    vec2 p = UV * texture_scale * 18.0;
    float broad = noise2(p * 0.13);
    float mid = noise2(p * 0.75);
    float fine = noise2(p * 3.8);
    float flecks = step(0.79, noise2(p * 7.0));
    float moisture = smoothstep(0.40, 0.72, broad * 0.7 + mid * 0.3);
    vec3 soil = mix(soil_dark, soil_mid, broad * 0.75 + mid * 0.25);
    soil = mix(soil, moss_color, moisture * 0.34);
    soil *= 0.83 + fine * 0.24;
    soil = mix(soil, soil_mid * 0.72, flecks * 0.20);
    ALBEDO = soil;
    ROUGHNESS = roughness_value;
}
