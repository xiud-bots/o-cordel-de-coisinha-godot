shader_type canvas_item;

// Overlay de escuridão para Fase 4 (Botija) com recorte radial suave
// centrado na posição do jogador na tela.
// Raio pequeno padrão (85px) e expansão para 320px quando o candeeiro está ativo.

uniform vec2 viewport_size = vec2(960.0, 580.0);
uniform vec2 light_center_px = vec2(480.0, 290.0);

uniform bool lantern_active = false;
uniform float lantern_blend : hint_range(0.0, 1.0) = 0.0;

uniform float base_radius_px : hint_range(20.0, 320.0) = 85.0;
uniform float lantern_radius_px : hint_range(85.0, 640.0) = 320.0;
uniform float inner_falloff : hint_range(0.05, 0.95) = 0.30;
uniform float flicker_strength : hint_range(0.0, 0.1) = 0.022;

uniform vec4 darkness_color : source_color = vec4(0.0118, 0.0157, 0.0314, 0.94); // rgba(3, 4, 8, 0.94)
uniform vec4 lantern_glow_color : source_color = vec4(0.996, 0.941, 0.541, 0.24); // aura dourada candeeiro

void fragment() {
	vec2 pixel_pos = UV * viewport_size;
	float dist = distance(pixel_pos, light_center_px);

	float active_mix = lantern_active ? 1.0 : lantern_blend;
	float flicker = 1.0 + (sin(TIME * 7.3) * cos(TIME * 11.7)) * flicker_strength * active_mix;
	float radius = mix(base_radius_px, lantern_radius_px, active_mix) * flicker;
	float inner_r = radius * inner_falloff;

	// Curva de recorte fiel ao Stage4BotijaScene: centro limpo, 0.7 suave, 1.0 escuro total
	float t_mid = smoothstep(inner_r, radius * 0.7, dist);
	float t_outer = smoothstep(radius * 0.7, radius, dist);
	float dark_factor = mix(t_mid * 0.15, 1.0, t_outer);
	float dark_alpha = darkness_color.a * dark_factor;

	// Brilho quente do candeeiro dentro do raio iluminado
	float glow_factor = (1.0 - smoothstep(40.0, radius, dist)) * active_mix;
	float glow_alpha = lantern_glow_color.a * glow_factor * (1.0 - t_outer);

	vec3 final_rgb = mix(lantern_glow_color.rgb, darkness_color.rgb, dark_factor);
	float final_alpha = clamp(dark_alpha + glow_alpha * (1.0 - dark_alpha), 0.0, 1.0);

	COLOR = vec4(final_rgb, final_alpha);
}
