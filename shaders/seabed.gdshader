// Sandy sea floor with animated caustics (light focused by the waves above), fading with depth.
shader_type spatial;
render_mode cull_disabled;

uniform float time_s = 0.0;
uniform float light_k = 1.0;

varying vec3 w_pos;

void vertex() {
	w_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float caustic(vec2 uv, float t) {
	vec2 p = mod(uv * 6.28318, 6.28318) - 250.0;
	vec2 i = p;
	float c = 1.0;
	float inten = 0.005;
	for (int n = 0; n < 4; n++) {
		float tt = t * (1.0 - (3.5 / float(n + 1)));
		i = p + vec2(cos(tt - i.x) + sin(tt + i.y), sin(tt - i.y) + cos(tt + i.x));
		c += 1.0 / length(vec2(p.x / (sin(i.x + tt) / inten), p.y / (cos(i.y + tt) / inten)));
	}
	c /= 4.0;
	c = 1.17 - pow(c, 1.4);
	return pow(abs(c), 8.0);
}

void fragment() {
	float depth = max(0.0, -w_pos.y);
	float fade = exp(-depth * 0.09);
	float c = caustic(w_pos.xz / 9.0, time_s * 0.5);
	// water absorbs red first: deeper sand turns blue-green and darker
	vec3 absorb = mix(vec3(0.62, 0.78, 0.8), vec3(0.18, 0.36, 0.42), clamp(depth / 14.0, 0.0, 1.0));
	ALBEDO = COLOR.rgb * absorb;
	ROUGHNESS = 0.95;
	SPECULAR = 0.1;
	EMISSION = vec3(0.45, 0.8, 0.85) * c * fade * light_k * 0.35;
}
