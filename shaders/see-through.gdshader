shader_type spatial;
render_mode blend_mix, depth_draw_always;

// Declared as a global shader uniform in Project Settings > Shader Globals first
// (name: cutout_position, type: Vector2). Set from script with
// RenderingServer.global_shader_parameter_set("cutout_position", screen_pos) —
// no need to fetch/loop over individual materials, every shader referencing it updates at once.
global uniform vec2 cutout_position;
uniform float CircleRadius = 100.0;                // pixels, like the original 2D version
uniform float CircleBlur : hint_range(0.0, 1.0) = 0.05;

void fragment()
{
	float circle_blur = clamp(CircleBlur, 0.0, 1.0); // fixed arg order from the 2D version

	// distance between this fragment's screen pixel and the target's projected screen pixel
	float circle_dist = distance(cutout_position, FRAGCOORD.xy);

	// same falloff logic as the 2D version (edge0 < edge1, fixed from the original)
	float inner_radius = CircleRadius * (1.0 - circle_blur);
	float circle_signal = 1.0 - smoothstep(inner_radius, CircleRadius, circle_dist);

	ALBEDO = vec3(0.8); // wall's base color / hook up your toon texture here
	ALPHA = 1.0 - circle_signal; // fades to 0 (invisible) near CircleCentre
}
