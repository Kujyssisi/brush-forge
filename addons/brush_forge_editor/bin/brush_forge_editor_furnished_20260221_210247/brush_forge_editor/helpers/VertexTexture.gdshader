shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

// ===== TEXTURE BLACK CHANNEL =====
group_uniforms TextureBlack;
uniform bool use_texture_black = false;
uniform sampler2D texture_black_albedo : source_color, filter_linear_mipmap, repeat_enable;
uniform vec3 texture_black_color : source_color = vec3(1.0, 1.0, 1.0);
uniform sampler2D texture_black_ao : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform float texture_black_ao_intensity : hint_range(0.0, 1.0) = 1.0;
uniform sampler2D texture_black_metallic : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform float texture_black_metallic_intensity : hint_range(0.0, 1.0) = 1.0;
uniform sampler2D texture_black_roughness : hint_roughness_gray, filter_linear_mipmap, repeat_enable;
uniform float texture_black_roughness_intensity : hint_range(0.0, 1.0) = 1.0;
uniform sampler2D texture_black_normal : hint_roughness_normal, filter_linear_mipmap, repeat_enable;
uniform float texture_black_normal_intensity : hint_range(0.0, 1.0) = 1.0;
uniform vec2 texture_black_scale = vec2(1.0, 1.0);

// ===== TEXTURE R CHANNEL =====
group_uniforms TextureR;
uniform bool use_texture_r = false;
uniform sampler2D texture_r_albedo : source_color, filter_linear_mipmap, repeat_enable;
uniform vec3 texture_r_color : source_color = vec3(1.0, 1.0, 1.0);
uniform sampler2D texture_r_ao : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform float texture_r_ao_intensity : hint_range(0.0, 1.0) = 1.0;
uniform sampler2D texture_r_metallic : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform float texture_r_metallic_intensity : hint_range(0.0, 1.0) = 1.0;
uniform sampler2D texture_r_roughness : hint_roughness_gray, filter_linear_mipmap, repeat_enable;
uniform float texture_r_roughness_intensity : hint_range(0.0, 1.0) = 1.0;
uniform sampler2D texture_r_normal : hint_roughness_normal, filter_linear_mipmap, repeat_enable;
uniform float texture_r_normal_intensity : hint_range(0.0, 1.0) = 1.0;
uniform vec2 texture_r_scale = vec2(1.0, 1.0);

// ===== TEXTURE G CHANNEL =====
group_uniforms TextureG;
uniform bool use_texture_g = false;
uniform sampler2D texture_g_albedo : source_color, filter_linear_mipmap, repeat_enable;
uniform vec3 texture_g_color : source_color = vec3(1.0, 1.0, 1.0);
uniform sampler2D texture_g_ao : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform float texture_g_ao_intensity : hint_range(0.0, 1.0) = 1.0;
uniform sampler2D texture_g_metallic : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform float texture_g_metallic_intensity : hint_range(0.0, 1.0) = 1.0;
uniform sampler2D texture_g_roughness : hint_roughness_gray, filter_linear_mipmap, repeat_enable;
uniform float texture_g_roughness_intensity : hint_range(0.0, 1.0) = 1.0;
uniform sampler2D texture_g_normal : hint_roughness_normal, filter_linear_mipmap, repeat_enable;
uniform float texture_g_normal_intensity : hint_range(0.0, 1.0) = 1.0;
uniform vec2 texture_g_scale = vec2(1.0, 1.0);

// ===== TEXTURE B CHANNEL =====
group_uniforms TextureB;
uniform bool use_texture_b = false;
uniform sampler2D texture_b_albedo : source_color, filter_linear_mipmap, repeat_enable;
uniform vec3 texture_b_color : source_color = vec3(1.0, 1.0, 1.0);
uniform sampler2D texture_b_ao : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform float texture_b_ao_intensity : hint_range(0.0, 1.0) = 1.0;
uniform sampler2D texture_b_metallic : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform float texture_b_metallic_intensity : hint_range(0.0, 1.0) = 1.0;
uniform sampler2D texture_b_roughness : hint_roughness_gray, filter_linear_mipmap, repeat_enable;
uniform float texture_b_roughness_intensity : hint_range(0.0, 1.0) = 1.0;
uniform sampler2D texture_b_normal : hint_roughness_normal, filter_linear_mipmap, repeat_enable;
uniform float texture_b_normal_intensity : hint_range(0.0, 1.0) = 1.0;
uniform vec2 texture_b_scale = vec2(1.0, 1.0);

// ===== TEXTURE WHITE CHANNEL =====
group_uniforms TextureWhite;
uniform bool use_texture_white = false;
uniform sampler2D texture_white_albedo : source_color, filter_linear_mipmap, repeat_enable;
uniform vec3 texture_white_color : source_color = vec3(1.0, 1.0, 1.0);
uniform sampler2D texture_white_ao : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform float texture_white_ao_intensity : hint_range(0.0, 1.0) = 1.0;
uniform sampler2D texture_white_metallic : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform float texture_white_metallic_intensity : hint_range(0.0, 1.0) = 1.0;
uniform sampler2D texture_white_roughness : hint_roughness_gray, filter_linear_mipmap, repeat_enable;
uniform float texture_white_roughness_intensity : hint_range(0.0, 1.0) = 1.0;
uniform sampler2D texture_white_normal : hint_roughness_normal, filter_linear_mipmap, repeat_enable;
uniform float texture_white_normal_intensity : hint_range(0.0, 1.0) = 1.0;
uniform vec2 texture_white_scale = vec2(1.0, 1.0);

// ===== BLENDING =====
group_uniforms Blending;
uniform bool use_noise_blending = false;
uniform sampler2D blend_noise_texture : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform sampler2D blend_height_texture : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform float blend_height_intensity = 1.0;
uniform float contrast0 = 10.0;
uniform vec2 blend_noise_scale = vec2(1.0, 1.0);
uniform vec2 blend_height_scale = vec2(1.0, 1.0);

varying vec3 vertex_color;


void vertex() {
	vertex_color = COLOR.rgb;
}

void fragment() {
	vec2 base_uv = UV;
	
	// Extract blend weights from vertex colors
	float weight_black = 1.0 - max(max(vertex_color.r, vertex_color.g), vertex_color.b);
	float weight_r = vertex_color.r;
	float weight_g = vertex_color.g;
	float weight_b = vertex_color.b;
	float weight_white = min(min(vertex_color.r, vertex_color.g), vertex_color.b);

	
	// Apply noise to blend transitions if enabled
	if (use_noise_blending) {
		vec3 n_out3p0 = vertex_color;
		vec3 n_out12p0 = n_out3p0;
		vec3 n_out4p0 = texture(blend_noise_texture, UV * blend_noise_scale).rgb;
		vec3 n_out13p0 = texture(blend_height_texture, UV * blend_height_scale).rgb * blend_height_intensity;
		vec3 n_out14p0 = vec3(n_out4p0.xyz) * vec3(n_out13p0.xyz);
		vec3 n_out5p0 = vec3(n_out12p0.xyz) + n_out14p0;
		vec3 n_out6p0 = n_out5p0 * vec3(n_out12p0.xyz);
		float n_out11p0 = contrast0;
		vec3 n_out10p0 = vec3(0.0, 0.0, 0.0);
		{
			n_out10p0 = clamp((n_out6p0 - 0.5) * n_out11p0 + 0.5, 0.0, 1.0);
		}
		vec3 vertex_color_a = n_out10p0;
		weight_black = 1.0 - max(max(vertex_color_a.r, vertex_color_a.g), vertex_color_a.b);
		weight_r = vertex_color_a.r;
		weight_g = vertex_color_a.g;
		weight_b = vertex_color_a.b;
		weight_white = min(min(vertex_color_a.r, vertex_color_a.g), vertex_color_a.b);
	}
	
	// Normalize weights
	float total = weight_black + weight_r + weight_g + weight_b + weight_white;
	total = max(total, 0.0001); // Prevent division by zero
	weight_black /= total;
	weight_r /= total;
	weight_g /= total;
	weight_b /= total;
	weight_white /= total;
	
	// Clamp normalized weights just to be safe
	weight_black = clamp(weight_black, 0.0, 1.0);
	weight_r = clamp(weight_r, 0.0, 1.0);
	weight_g = clamp(weight_g, 0.0, 1.0);
	weight_b = clamp(weight_b, 0.0, 1.0);
	weight_white = clamp(weight_white, 0.0, 1.0);
	
	// Initialize outputs
	vec3 final_albedo = vec3(0.0);
	float final_ao = 1.0;
	float final_metallic = 0.0;
	float final_roughness = 1.0;
	vec3 final_normal = vec3(0.5, 0.5, 1.0);
	
	// BLACK CHANNEL
	if (use_texture_black && weight_black > 0.0) {
		vec2 scaled_uv = base_uv * texture_black_scale;
		vec3 albedo = texture(texture_black_albedo, scaled_uv).rgb * texture_black_color;
		float ao = texture(texture_black_ao, scaled_uv).r;
		ao = mix(1.0, ao, texture_black_ao_intensity);
		float metallic = texture(texture_black_metallic, scaled_uv).r * texture_black_metallic_intensity;
		float roughness = texture(texture_black_roughness, scaled_uv).r * texture_black_roughness_intensity;
		vec3 normal = texture(texture_black_normal, scaled_uv).rgb;
		
		final_albedo += albedo * weight_black;
		final_ao *= mix(1.0, ao, weight_black);
		final_metallic += metallic * weight_black;
		final_roughness = mix(final_roughness, roughness, weight_black);
		final_normal = mix(final_normal, normal, weight_black * texture_black_normal_intensity);
	}
	
	// R CHANNEL
	if (use_texture_r && weight_r > 0.0) {
		vec2 scaled_uv = base_uv * texture_r_scale;
		vec3 albedo = texture(texture_r_albedo, scaled_uv).rgb * texture_r_color;
		float ao = texture(texture_r_ao, scaled_uv).r;
		ao = mix(1.0, ao, texture_r_ao_intensity);
		float metallic = texture(texture_r_metallic, scaled_uv).r * texture_r_metallic_intensity;
		float roughness = texture(texture_r_roughness, scaled_uv).r * texture_r_roughness_intensity;
		vec3 normal = texture(texture_r_normal, scaled_uv).rgb;
		
		final_albedo += albedo * weight_r;
		final_ao *= mix(1.0, ao, weight_r);
		final_metallic += metallic * weight_r;
		final_roughness = mix(final_roughness, roughness, weight_r);
		final_normal = mix(final_normal, normal, weight_r * texture_r_normal_intensity);
	}
	
	// G CHANNEL
	if (use_texture_g && weight_g > 0.0) {
		vec2 scaled_uv = base_uv * texture_g_scale;
		vec3 albedo = texture(texture_g_albedo, scaled_uv).rgb * texture_g_color;
		float ao = texture(texture_g_ao, scaled_uv).r;
		ao = mix(1.0, ao, texture_g_ao_intensity);
		float metallic = texture(texture_g_metallic, scaled_uv).r * texture_g_metallic_intensity;
		float roughness = texture(texture_g_roughness, scaled_uv).r * texture_g_roughness_intensity;
		vec3 normal = texture(texture_g_normal, scaled_uv).rgb;
		
		final_albedo += albedo * weight_g;
		final_ao *= mix(1.0, ao, weight_g);
		final_metallic += metallic * weight_g;
		final_roughness = mix(final_roughness, roughness, weight_g);
		final_normal = mix(final_normal, normal, weight_g * texture_g_normal_intensity);
	}
	
	// B CHANNEL
	if (use_texture_b && weight_b > 0.0) {
		vec2 scaled_uv = base_uv * texture_b_scale;
		vec3 albedo = texture(texture_b_albedo, scaled_uv).rgb * texture_b_color;
		float ao = texture(texture_b_ao, scaled_uv).r;
		ao = mix(1.0, ao, texture_b_ao_intensity);
		float metallic = texture(texture_b_metallic, scaled_uv).r * texture_b_metallic_intensity;
		float roughness = texture(texture_b_roughness, scaled_uv).r * texture_b_roughness_intensity;
		vec3 normal = texture(texture_b_normal, scaled_uv).rgb;
		
		final_albedo += albedo * weight_b;
		final_ao *= mix(1.0, ao, weight_b);
		final_metallic += metallic * weight_b;
		final_roughness = mix(final_roughness, roughness, weight_b);
		final_normal = mix(final_normal, normal, weight_b * texture_b_normal_intensity);
	}
	
	// WHITE CHANNEL
	if (use_texture_white && weight_white > 0.0) {
		vec2 scaled_uv = base_uv * texture_white_scale;
		vec3 albedo = texture(texture_white_albedo, scaled_uv).rgb * texture_white_color;
		float ao = texture(texture_white_ao, scaled_uv).r;
		ao = mix(1.0, ao, texture_white_ao_intensity);
		float metallic = texture(texture_white_metallic, scaled_uv).r * texture_white_metallic_intensity;
		float roughness = texture(texture_white_roughness, scaled_uv).r * texture_white_roughness_intensity;
		vec3 normal = texture(texture_white_normal, scaled_uv).rgb;
		
		final_albedo += albedo * weight_white;
		final_ao *= mix(1.0, ao, weight_white);
		final_metallic += metallic * weight_white;
		final_roughness = mix(final_roughness, roughness, weight_white);
		final_normal = mix(final_normal, normal, weight_white * texture_white_normal_intensity);
	}
	
	// Apply final values with clamping to prevent glitches
	ALBEDO = clamp(final_albedo, vec3(0.0), vec3(1.0));
	AO = clamp(final_ao, 0.0, 1.0);
	METALLIC = clamp(final_metallic, 0.0, 1.0);
	ROUGHNESS = clamp(final_roughness, 0.0, 1.0);
	NORMAL_MAP = final_normal;
}