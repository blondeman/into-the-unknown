shader_type spatial;
render_mode blend_mix, depth_draw_always;

#define USE_ALPHA 0
#define USE_ALPHA_CUTOFF 1
#define USE_EMISSION 1
#define USE_REFLECTIONS 0
#define USE_NORMAL_MAP 0
#define USE_OCCLUSION 1
#define USE_HEIGHT_MAP 0
#define USE_ANISOTROPY 0
#define USE_BACKLIGHT 1
#define USE_REFRACTION 0

#include "includes/base-cel-shader.gdshaderinc"

#if USE_EMISSION
#include "includes/emission.gdshaderinc"
#endif

#if USE_REFLECTIONS
#include "includes/reflections.gdshaderinc"
#endif

#if USE_NORMAL_MAP
#include "includes/normal-map.gdshaderinc"
#endif

#if USE_OCCLUSION
#include "includes/occlusion.gdshaderinc"
#endif

#if USE_HEIGHT_MAP
#include "includes/height-map.gdshaderinc"
#endif

#if USE_ANISOTROPY
#include "includes/anisotropy.gdshaderinc"
#endif

#if USE_BACKLIGHT
#include "includes/backlight.gdshaderinc"
#endif

#if USE_REFRACTION
#include "includes/refraction.gdshaderinc"
#elif !USE_REFRACTION && USE_ALPHA
#include "includes/transparency.gdshaderinc"
#endif

group_uniforms BaseProperties;
#if USE_ALPHA_CUTOFF
uniform float alpha_cutoff: hint_range(0.0, 1.0) = 0.5;
#endif
uniform vec4 color: source_color = vec4(0.7, 0.12, 0.86, 1.0);
uniform sampler2D base_texture: source_color;
uniform vec4 specular: source_color = vec4(0.3, 0.3, 0.3, 0.5);
uniform sampler2D specular_texture: hint_default_white;
uniform vec4 fresnel: source_color = vec4(0.2, 0.2, 0.2, 0.3);
uniform sampler2D fresnel_texture: hint_default_white;
group_uniforms;

varying vec3 SPECULAR_COLOR;
varying float SPECULAR_STRENGTH;
varying vec3 FRESNEL_COLOR;
varying float FRESNEL_STRENGTH;

varying vec2 base_uv;

group_uniforms Tiling;
uniform vec2 uv_scale = vec2(1,1);
uniform vec2 uv_offset = vec2(0,0);
group_uniforms;

group_uniforms Cutout;
global uniform vec3 cutout_target_view;
uniform float StartRadius = 0.1;                   // world units - cone radius at the target end
uniform float EndRadius = 2.0;                     // world units - cone radius at the camera end
uniform float StartOffset = 0.0;                   // world units - shifts the cone's apex towards the camera by this much (e.g. 1.0 starts the cone 1 unit in front of the target)
uniform float EdgeWidth = 0.15;                    // world units - thickness of the solid-color ring at the hole's edge
uniform vec4 EdgeColor : source_color = vec4(0.0, 0.0, 0.0, 1.0);
group_uniforms;

void vertex() {
	UV = UV * uv_scale.xy + uv_offset.xy;
	#if !USE_HEIGHT_MAP
		base_uv = UV;
	#endif
}

void fragment() {
#if USE_HEIGHT_MAP
	base_uv = height_map_fragment(UV, VERTEX, TANGENT, BINORMAL, NORMAL);
#endif

#if USE_REFRACTION && USE_ALPHA
	EMISSION += refraction_fragment(alpha, NORMAL, SCREEN_UV, FRAGCOORD.z);
#elif !USE_REFRACTION && USE_ALPHA
	EMISSION += transparency_fragment(alpha, SCREEN_UV);
#endif

	SPECULAR_COLOR = specular.rgb * texture(specular_texture, base_uv).rgb;
	SPECULAR_STRENGTH = specular.a * texture(specular_texture, base_uv).a;
	FRESNEL_COLOR = fresnel.rgb * texture(fresnel_texture, base_uv).rgb;
	FRESNEL_STRENGTH = fresnel.a * texture(fresnel_texture, base_uv).a;

#if USE_EMISSION
	EMISSION += emission_fragment(base_uv);
#endif

#if USE_REFLECTIONS
	Surface surf = reflections_fragment(UV);
	METALLIC = surf.metallic;
	ROUGHNESS = surf.roughness;
#endif

#if USE_NORMAL_MAP
	NormalData normal = normal_map_fragment(base_uv, NORMAL, TANGENT, BINORMAL);
	NORMAL = normal.vector;
	NORMAL_MAP = normal.map;
	NORMAL_MAP_DEPTH = normal.depth;
#endif

#if USE_OCCLUSION
	OcclusionData occlusion = occlusion_fragment(base_uv);
	AO = occlusion.ao;
	AO_LIGHT_AFFECT = occlusion.ao_light_affect;
#endif

#if USE_ANISOTROPY
	AnisotropyData aniso = anisotropy_fragment(UV);
	ANISOTROPY_DIR = aniso.direction;
	ANISOTROPY_RATIO = aniso.ratio;
#endif

#if USE_BACKLIGHT
	BACKLIGHT = backlight_fragment(base_uv);
#endif

	float target_dist = length(cutout_target_view);
	vec3 axis_dir = -cutout_target_view / target_dist; // points from target towards camera

	// apex shifted towards the camera by StartOffset; segment_length is what's left to the camera
	vec3 apex = cutout_target_view + axis_dir * StartOffset;
	float segment_length = max(target_dist - StartOffset, 0.0001);

	vec3 to_frag = VERTEX - apex;
	float along_axis = dot(to_frag, axis_dir);          // 0.0 at apex, segment_length at camera

	// only the segment strictly between the (offset) apex and the camera counts
	float in_segment = step(0.0, along_axis) * step(along_axis, segment_length);

	vec3 closest_point = axis_dir * along_axis;
	float perp_dist = length(to_frag - closest_point);

	// radius at this point along the cone, linearly interpolated between the two ends
	float cone_radius = mix(StartRadius, EndRadius, clamp(along_axis / segment_length, 0.0, 1.0));
	float inner_radius = max(cone_radius - EdgeWidth, 0.0);

	// hole_mask: 1.0 fully inside the cutout (transparent), 0.0 elsewhere
	float hole_mask = step(perp_dist, inner_radius) * in_segment;
	// ring_mask: 1.0 in the band between inner_radius and cone_radius (solid colored edge), 0.0 elsewhere
	float ring_mask = (step(perp_dist, cone_radius) - step(perp_dist, inner_radius)) * in_segment;

	ALBEDO = mix(color.rgb * texture(base_texture, base_uv).rgb, EdgeColor.rgb, ring_mask);
	ALPHA = 1.0 - hole_mask;
}

void light() {
#if USE_BACKLIGHT
	DIFFUSE_LIGHT += backlight_diffuse(
			ALBEDO,
			LIGHT_COLOR,
			LIGHT,
			NORMAL,
			ATTENUATION,
			BACKLIGHT
	);
#else
	DIFFUSE_LIGHT += diffuse_light(
			ALBEDO,
			LIGHT_COLOR,
			LIGHT,
			NORMAL,
			ATTENUATION
	);
#endif

#if USE_ANISOTROPY
	SPECULAR_LIGHT += anisotropy_specular(
			LIGHT_COLOR,
			SPECULAR_COLOR,
			SPECULAR_STRENGTH,
			NORMAL,
			VIEW,
			LIGHT,
			ATTENUATION,
			UV,
			ANISOTROPY_DIR,
			ANISOTROPY_RATIO
	);
#else
	SPECULAR_LIGHT += specular_light(
			LIGHT_COLOR,
			SPECULAR_COLOR,
			SPECULAR_STRENGTH,
			NORMAL,
			VIEW,
			LIGHT,
			ATTENUATION
	);
#endif

	SPECULAR_LIGHT += fresnel_light(
			LIGHT_COLOR,
			FRESNEL_COLOR,
			FRESNEL_STRENGTH,
			NORMAL,
			VIEW,
			LIGHT,
			ATTENUATION
	);
}
