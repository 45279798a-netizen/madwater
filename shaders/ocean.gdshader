// 瘋狂水世界 — open-ocean surface.
// Spectrum-sampled Gerstner swells (FFT-like look), Jacobian whitecaps, raft-edge foam,
// dynamic ripple rings, subsurface glow on thin crests. Godot's PBR lighting supplies the
// Fresnel sky reflection and the GGX sun glint from ROUGHNESS / SPECULAR.
shader_type spatial;
render_mode cull_disabled, specular_schlick_ggx, depth_draw_opaque;

const int NW = 20;
uniform vec4 wave_a[NW];          // dir.x, dir.z, k, amplitude
uniform vec4 wave_b[NW];          // omega, phase, Gerstner Q, unused
uniform float time_s = 0.0;
uniform float amp_mul = 1.0;     // storms make every wave taller
uniform vec3 calm = vec3(1.0, 1.0, 3.0);   // calm zone around the raft: x, z, radius
uniform vec3 sun_dir = vec3(0.5, 0.6, 0.3); // world direction toward the sun
uniform float light_k = 1.0;
uniform vec3 deep_color : source_color = vec3(0.012, 0.11, 0.2);
uniform vec3 scatter_color : source_color = vec3(0.05, 0.42, 0.47);
uniform sampler2D raft_mask : filter_linear, repeat_disable;
uniform vec2 raft_off = vec2(0.0);
uniform vec4 rip[8];              // x, z, start time, strength

varying vec3 w_pos;
varying vec3 w_nrm;
varying float v_h;
varying float v_j;

float hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}
float noise(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void vertex() {
	vec3 base = VERTEX + MODEL_MATRIX[3].xyz;
	vec2 p = base.xz;
	float h = 0.0;
	vec2 disp = vec2(0.0);
	vec3 nrm = vec3(0.0);
	vec3 jac = vec3(0.0);
	for (int i = 0; i < NW; i++) {
		vec2 d = wave_a[i].xy;
		float k = wave_a[i].z, a = wave_a[i].w * amp_mul;
		float w = wave_b[i].x, ph = wave_b[i].y, q = wave_b[i].z / amp_mul;
		float f = k * dot(d, p) + time_s * w + ph;
		float s = sin(f), c = cos(f), wa = k * a;
		h += a * s;
		disp += q * a * d * c;
		nrm.x += d.x * wa * c;
		nrm.z += d.y * wa * c;
		nrm.y += q * wa * s;
		jac += q * wa * s * vec3(d.x * d.x, d.y * d.y, d.x * d.y);
	}
	float dd = length(p - calm.xy);
	float kk = clamp((dd - calm.z) / 8.0, 0.0, 1.0);
	float dm = 0.32 + 0.68 * kk * kk * (3.0 - 2.0 * kk);
	VERTEX.xz += disp * dm;
	VERTEX.y = h * dm - 0.25;
	v_h = h * dm;
	vec3 jj = jac * dm;
	v_j = (1.0 - jj.x) * (1.0 - jj.y) - jj.z * jj.z;   // < 1 where the surface folds into a crest
	w_nrm = normalize(vec3(-nrm.x * dm, 1.0 - nrm.y * dm, -nrm.z * dm));
	NORMAL = w_nrm;
	w_pos = VERTEX + MODEL_MATRIX[3].xyz;
}

void fragment() {
	vec2 p = w_pos.xz;
	float t = time_s;
	vec3 to_cam = CAMERA_POSITION_WORLD - w_pos;
	float dist = length(to_cam);
	vec3 V = to_cam / dist;
	vec3 n = normalize(w_nrm);

	// micro ripples: smooth wind wave trains, faded with distance
	float fade = 1.0 - smoothstep(10.0, 45.0, dist);
	vec2 g = vec2(0.0);
	g += 0.040 * vec2(0.86, 0.50) * cos(dot(p, vec2(0.86, 0.50)) * 1.9 + t * 2.2);
	g += 0.030 * vec2(-0.30, 0.95) * cos(dot(p, vec2(-0.30, 0.95)) * 2.7 + t * 2.6);
	g += 0.020 * vec2(0.98, -0.20) * cos(dot(p, vec2(0.98, -0.20)) * 3.8 + t * 3.1);
	n.xz -= g * fade;

	// dynamic ripples from splashes and the shark's wake
	float rip_foam = 0.0;
	for (int i = 0; i < 8; i++) {
		vec4 r = rip[i];
		float age = t - r.z;
		if (r.w <= 0.0 || age < 0.0 || age > 3.5) { continue; }
		vec2 dv = p - r.xy;
		float rr = length(dv) + 0.0001;
		float env = exp(-pow((rr - age * 2.6) / 0.9, 2.0)) * exp(-age * 1.1) * r.w;
		float ph = rr * 5.0 - age * 16.0;
		n.xz += (dv / rr) * env * cos(ph) * 0.35;
		rip_foam += env * smoothstep(0.5, 1.0, sin(ph)) * exp(-age * 1.8);
	}
	n = normalize(n);
	n = normalize(mix(n, vec3(0.0, 1.0, 0.0), smoothstep(35.0, 160.0, dist) * 0.5));

	// subsurface: thin crests lit from behind glow blue-green
	float thick = clamp(v_h * 0.8 + 0.35, 0.0, 1.0);
	float sss = pow(clamp(dot(V, -normalize(sun_dir + n * 0.6)), 0.0, 1.0), 4.0) * thick;

	// foam: Jacobian folding, raft contact, ripple rings
	float fn = noise(p * 1.3 + vec2(t * 0.25, t * 0.08)) * 0.65 + noise(p * 4.2 - t * 0.3) * 0.35;
	float jf = smoothstep(0.8, 0.35, v_j);
	float crest_foam = jf * smoothstep(0.3, 0.7, fn + jf * 0.25);
	float m = texture(raft_mask, ((p - raft_off) * 0.5 + 16.5) / 32.0).r;
	float edge = smoothstep(0.24, 0.4, m) * (1.0 - smoothstep(0.46, 0.52, m));
	float raft_foam = edge * smoothstep(0.45, 0.8, fn + 0.15 * sin(t * 2.0 + p.x * 1.3 + p.y));
	float foam = max(max(crest_foam * 0.8, raft_foam * 0.6), min(rip_foam, 1.0) * 0.6);
	foam *= 1.0 - smoothstep(40.0, 110.0, dist);

	NORMAL = normalize((VIEW_MATRIX * vec4(n, 0.0)).xyz);
	ALBEDO = mix(deep_color, vec3(0.88, 0.93, 0.95), foam);
	EMISSION = scatter_color * (thick * 0.1 + sss * 0.9) * light_k * (1.0 - foam);
	METALLIC = 0.0;
	SPECULAR = 0.5;
	ROUGHNESS = mix(mix(0.035, 0.22, smoothstep(12.0, 160.0, dist)), 0.85, foam);
	if (!FRONT_FACING) {
		// seen from below: a bright window straight up, dimming to the deep blue-green at an angle
		float window = smoothstep(0.55, 0.95, -V.y);
		ALBEDO = vec3(0.01, 0.06, 0.07);
		EMISSION = mix(vec3(0.03, 0.2, 0.24), vec3(0.5, 0.8, 0.85), window) * (0.2 + 0.8 * light_k)
			* (0.85 + 0.3 * n.x);
		ROUGHNESS = 0.6;
		SPECULAR = 0.0;
	}
}
