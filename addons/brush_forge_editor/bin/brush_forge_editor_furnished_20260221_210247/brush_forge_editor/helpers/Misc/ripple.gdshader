shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, unshaded, diffuse_lambert_wrap;

// Main ripple texture
uniform sampler2D ripple_texture : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D SCREEN_TEXTURE : hint_screen_texture;
// Controls
uniform float blend_amount : hint_range(0.0, 1.0) = 0.5;

void fragment() {
	// Sample the ripple texture
	vec4 ripple_sample = texture(ripple_texture, UV);
	
	// Get what's behind this particle
	vec3 screen_color = textureLod(SCREEN_TEXTURE, SCREEN_UV, 0.0).rgb;
	
	// Blend the ripple texture with what's behind it, using vertex color
	vec3 ripple_color = ripple_sample.rgb * COLOR.rgb;
	ALBEDO = mix(screen_color, ripple_color, ripple_sample.a * blend_amount);
	
	// Use vertex alpha and texture alpha for transparency
	ALPHA = ripple_sample.a * COLOR.a;
}