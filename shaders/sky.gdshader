// Sky with a drifting cloud layer (replaces ProceduralSkyMaterial; driven by scripts/sky_clouds.gd).
// Gradient sky and ground like the procedural sky, a sun disc with glow, stars at night, and
// clouds: fBm noise (domain-warped into cumulus shapes) projected onto a high flat layer, so they
// shrink and crowd together toward the horizon like real clouds. Each cloud is lit from the sun's
// side and darker in its thick core; near the horizon they fade into haze. The radiance cubemap
// (used for ambient light) gets a cheap average instead of the full clouds.
shader_type sky;

uniform vec3 sky_top_color : source_color = vec3(0.17, 0.42, 0.69);
uniform vec3 sky_horizon_color : source_color = vec3(0.66, 0.78, 0.86);
uniform vec3 ground_horizon_color : source_color = vec3(0.66, 0.78, 0.86);
uniform vec3 ground_bottom_color : source_color = vec3(0.04, 0.16, 0.25);
uniform float cover : hint_range(0.0, 1.0) = 0.42;     // 0 clear .. 1 overcast
uniform float storm : hint_range(0.0, 1.0) = 0.0;      // heavy, dark-bellied clouds
uniform vec3 cloud_lit : source_color = vec3(1.0);      // sunlit side (follows time of day)
uniform vec3 cloud_shade : source_color = vec3(0.62, 0.67, 0.75);
uniform float drift = 0.0;                              // seconds the wind has blown (set from script)
uniform vec2 wind_dir = vec2(1.0, 0.35);
uniform float night = 0.0;                              // 1 = full night: stars come out
uniform int octaves = 5;                                // fewer on phones

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm(vec2 p, int oct) {
	float s = 0.0;
	float a = 0.5;
	for (int i = 0; i < 6; i++) {
		if (i >= oct) {
			break;
		}
		s += a * vnoise(p);
		p = p * 2.03 + vec2(17.1, 9.2);
		a *= 0.5;
	}
	return s;
}

void sky() {
	vec3 d = EYEDIR;
	float y = d.y;
	vec3 col;
	if (y >= 0.0) {
		col = mix(sky_horizon_color, sky_top_color, pow(clamp(y, 0.0, 1.0), 0.45));
	} else {
		col = mix(ground_horizon_color, ground_bottom_color, clamp(sqrt(-y) * 1.5, 0.0, 1.0));
	}
	vec3 sun = LIGHT0_DIRECTION;
	float sd = dot(d, sun);
	vec3 sun_col = LIGHT0_COLOR * LIGHT0_ENERGY;
	if (LIGHT0_ENABLED) {
		float above = clamp(sun.y * 5.0 + 1.0, 0.0, 1.0);
		float disc = smoothstep(0.99925, 0.99965, sd);
		float glow = pow(max(sd, 0.0), 220.0) * 0.8 + pow(max(sd, 0.0), 10.0) * 0.1;
		col += sun_col * (disc * 5.0 + glow) * above;
	}
	if (night > 0.01) {
		// the moon rises opposite the sun
		vec3 moon = normalize(-sun + vec3(0.0, 0.25, 0.0));
		float md = dot(d, moon);
		float mdisc = smoothstep(0.99955, 0.9998, md);
		col += vec3(0.9, 0.93, 1.0) * (mdisc * 1.6 + pow(max(md, 0.0), 60.0) * 0.12) * night;
	}
	if (y > 0.0 && night > 0.01) {
		vec2 sp = d.xz / (y + 0.35) * 260.0;
		float st = step(0.9965, hash(floor(sp)));
		float tw = 0.6 + 0.4 * sin(drift * 2.0 + hash(floor(sp) + 3.1) * 40.0);
		col += vec3(st * tw * night * smoothstep(0.02, 0.3, y));
	}
	if (y > 0.0) {
		if (AT_CUBEMAP_PASS) {
			// ambient light only needs the average look of the sky
			vec3 avg = mix(cloud_shade, cloud_lit, 0.6);
			col = mix(col, avg, cover * 0.55 * smoothstep(0.0, 0.3, y));
		} else {
			// project the view ray onto a flat cloud layer high overhead
			vec2 p = d.xz / (y + 0.045) * 0.55 + wind_dir * drift * 0.0035;
			vec2 q = vec2(fbm(p * 0.55, 3), fbm(p * 0.55 + vec2(5.2, 1.3), 3));
			float n = fbm(p + q * 1.1, octaves);
			float th = mix(0.6, 0.33, cover);
			float dens = smoothstep(th, th + 0.2, n);
			// light from the sun's side: compare with the density a little toward the sun
			vec2 toward = normalize(sun.xz + vec2(0.0001)) * 0.09;
			float n2 = fbm(p + q * 1.1 + toward, octaves);
			float lit = clamp(0.6 + (n - n2) * 4.0, 0.0, 1.0);
			vec3 ccol = mix(cloud_shade, cloud_lit, lit);
			ccol *= mix(1.0, 0.62 - storm * 0.2, smoothstep(th + 0.12, th + 0.42, n) * (0.35 + storm * 0.65));
			// bright rims on clouds near the sun
			ccol += sun_col * pow(max(sd, 0.0), 30.0) * (1.0 - smoothstep(th, th + 0.3, n)) * 0.6;
			// far clouds sink into the horizon haze
			float haze = smoothstep(0.0, 0.25, y);
			ccol = mix(sky_horizon_color, ccol, 0.35 + 0.65 * haze);
			col = mix(col, ccol, dens * smoothstep(0.0, 0.06, y));
		}
	}
	COLOR = col;
}
