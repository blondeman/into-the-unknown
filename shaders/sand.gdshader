shader_type canvas_item;

uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform vec2 rect_size = vec2(300.0, 100.0);   // set from script
uniform vec4 sand_light : source_color = vec4(0.87, 0.74, 0.47, 1.0);
uniform vec4 sand_dark  : source_color = vec4(0.66, 0.52, 0.30, 1.0);
uniform vec2 wind = vec2(1.0, -0.2);           // blow direction
uniform float grain_size = 3.0;                // in pixels
uniform float travel = 0.7;                    // how far grains fly (uv units)
uniform float lifetime = 0.35;                 // flight time in progress units
uniform float flying_density : hint_range(0.0, 1.0) = 0.6;
uniform float seed = 0.0;
const int STEPS = 20;

float hash(vec2 p) {
	p = fract((p + seed) * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x),
	           mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

// When (0..1+) a grain in this cell leaves the surface
float leave_time(vec2 cell, vec2 grid, vec2 w) {
	vec2 uv = (cell + 0.5) / grid;
	float sweep = dot(uv - 0.5, w) + 0.5;               // windward side goes first
	float n = vnoise(cell * 0.08 + vec2(seed * 1.7, seed * 3.1));
	return clamp(0.6 * sweep + 0.25 * n + 0.15 * hash(cell), 0.0, 1.0);
}

void fragment() {
	vec2 grid = rect_size / grain_size;
	vec2 w = normalize(wind);
	float t = progress * (1.0 + lifetime);

	vec2 cell = floor(UV * grid);
	float L = leave_time(cell, grid, w);

	vec4 col = vec4(0.0);

	if (t < L) {
		// still-attached sand
		float shade = hash(cell + 7.0);
		col = mix(sand_dark, sand_light, shade);
		col.a = 1.0;
	} else {
		// look backwards along the wind for a grain that is in flight here
		for (int i = 1; i <= STEPS; i++) {
			float a = float(i) / float(STEPS);           // normalized age
			vec2 origin = UV - w * a * travel;
			origin.y += sin(a * 7.0 + UV.x * 12.0) * 0.03 * a;   // turbulence
			if (origin.x < 0.0 || origin.y < 0.0 || origin.y > 1.0) continue;

			vec2 oc = floor(origin * grid);
			float oL = leave_time(oc, grid, w);
			float age = (t - oL) / lifetime;

			if (age > 0.0 && age < 1.0 && abs(age - a) < 0.5 / float(STEPS)) {
				if (hash(oc + 3.1) < flying_density) {
					col = mix(sand_dark, sand_light, hash(oc + 7.0));
					col.a = 1.0 - age;                   // fade as it flies off
					break;
				}
			}
		}
	}
	COLOR = col;
}