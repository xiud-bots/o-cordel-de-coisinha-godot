shader_type canvas_item;

// Efeito sutil de papel kraft de cordel + vinheta de xilogravura.
// Aplicar em um ColorRect fullscreen (mouse_filter = IGNORE) dentro de um CanvasLayer.

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear_mipmap;

uniform vec4 paper_tint : source_color = vec4(0.902, 0.812, 0.659, 1.0); // #e6cfa8 (PAPEL_CORDEL)
uniform vec4 vignette_color : source_color = vec4(0.078, 0.063, 0.047, 1.0); // #14100c (NANQUIM)

uniform float grain_strength : hint_range(0.0, 0.25) = 0.045;
uniform float grain_scale : hint_range(64.0, 1024.0) = 360.0;
uniform float fiber_strength : hint_range(0.0, 0.2) = 0.022;
uniform float paper_warmth : hint_range(0.0, 0.3) = 0.05;
uniform float vignette_strength : hint_range(0.0, 1.0) = 0.26;
uniform float vignette_softness : hint_range(0.05, 1.0) = 0.45;

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	float a = hash12(i);
	float b = hash12(i + vec2(1.0, 0.0));
	float c = hash12(i + vec2(0.0, 1.0));
	float d = hash12(i + vec2(1.0, 1.0));
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

void fragment() {
	vec4 base = texture(screen_texture, SCREEN_UV);

	// 1. Grão fino de papel artesanal
	float n_fine = hash12(floor(SCREEN_UV * grain_scale)) - 0.5;
	float n_soft = value_noise(SCREEN_UV * (grain_scale * 0.18)) - 0.5;
	float grain = (n_fine * 0.65 + n_soft * 0.35) * grain_strength;

	// 2. Fibras sutis de celulose (horizontais e verticais)
	float fiber_h = value_noise(vec2(SCREEN_UV.x * 28.0, SCREEN_UV.y * 220.0)) - 0.5;
	float fiber_v = value_noise(vec2(SCREEN_UV.x * 220.0, SCREEN_UV.y * 28.0)) - 0.5;
	float fibers = (fiber_h + fiber_v) * 0.5 * fiber_strength;

	// 3. Aquecimento sutil de papel envelhecido
	vec3 col = mix(base.rgb, base.rgb * paper_tint.rgb, paper_warmth);
	col += vec3(grain + fibers);

	// 4. Vinheta suave nas bordas (impressão de xilogravura)
	vec2 centered = SCREEN_UV - vec2(0.5);
	float radial_dist = length(centered * vec2(1.0, 0.85)) * 1.4142;
	float vig = smoothstep(1.0 - vignette_softness, 1.15, radial_dist);
	col = mix(col, vignette_color.rgb, clamp(vig * vignette_strength, 0.0, 1.0));

	COLOR = vec4(clamp(col, 0.0, 1.0), base.a);
}
