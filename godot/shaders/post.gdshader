shader_type canvas_item;
// Over the lit frame: the storm's tint (drawStorm), the vignette (drawVignette) and the red edge on low health
// (16h-nameplates.js), composited in that order.
uniform vec2 size = vec2(1280.0, 720.0);
uniform vec4 storm = vec4(0.0);
uniform vec2 vig_c = vec2(640.0, 374.0);
uniform vec2 vig_r = vec2(180.0, 1024.0);
uniform float low = 0.0;

vec4 over(vec4 acc, vec3 rgb, float a) {
	return vec4(rgb * a + acc.rgb * (1.0 - a), a + acc.a * (1.0 - a));
}

void fragment() {
	vec2 p = UV * size;
	vec4 acc = vec4(0.0);
	acc = over(acc, storm.rgb, storm.a);
	float t = clamp((distance(p, vig_c) - vig_r.x) / (vig_r.y - vig_r.x), 0.0, 1.0);
	acc = over(acc, vec3(12.0, 10.0, 8.0) / 255.0, 0.6 * t);
	if (low > 0.0) {
		float r0 = min(size.x, size.y) * 0.3, r1 = max(size.x, size.y) * 0.7;
		float q = clamp((distance(p, size * 0.5) - r0) / (r1 - r0), 0.0, 1.0);
		acc = over(acc, vec3(200.0, 20.0, 10.0) / 255.0, low * q);
	}
	COLOR = acc.a > 0.0 ? vec4(acc.rgb / acc.a, acc.a) : vec4(0.0);
}
