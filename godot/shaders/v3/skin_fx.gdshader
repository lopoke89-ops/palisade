shader_type spatial;
// The moving part of an animated skin (16-characters.js: o.stars, o.holo, o.glitter), laid over its 3D model as a
// material overlay; the models themselves are still. kind 0: the Galaxy's twinkling stars; 1: the Holo's colour
// bands drifting up, strongest at the edges; 2: the gold skins' glitter. Points are fixed to the model, so they ride
// the animation. motion 0 holds everything still (Reduce motion).
render_mode unshaded, blend_add, depth_draw_never, cull_back, shadows_disabled, fog_disabled;

uniform int kind = 0;
uniform float motion = 1.0;

varying vec3 p;

void vertex() {
	p = VERTEX;
}

float hash(vec3 c) {
	return fract(sin(dot(c, vec3(12.9898, 78.233, 37.719))) * 43758.5453);
}

void fragment() {
	float t = TIME * motion + 1.3;
	vec3 col = vec3(0.0);
	if (kind == 1) {
		float edge = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 1.5);
		float hue = fract(p.y * 1.6 + t * 0.25 + edge * 0.5);
		vec3 rgb = clamp(abs(mod(hue * 6.0 + vec3(0.0, 4.0, 2.0), 6.0) - 3.0) - 1.0, 0.0, 1.0);
		col = rgb * (0.16 + 0.34 * edge);
	} else {
		float cells = kind == 0 ? 16.0 : 22.0;
		vec3 c = floor(p * cells);
		vec3 f = fract(p * cells) - 0.5;
		float r = hash(c);
		float twinkle = 0.35 + 0.65 * pow(0.5 + 0.5 * sin(t * (2.0 + r * 4.0) + r * 40.0), 2.0);
		float dot_ = smoothstep(0.3, 0.0, length(f)) * step(kind == 0 ? 0.55 : 0.38, r);
		col = (kind == 0 ? vec3(1.0, 0.97, 0.9) : vec3(1.0, 0.85, 0.42)) * dot_ * twinkle * 1.8;
	}
	ALBEDO = col;
}
