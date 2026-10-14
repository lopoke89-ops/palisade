shader_type canvas_item;
// Night (drawLighting in 17-scenery.js): a shade over the frame with soft round holes punched out of it. Each hole
// takes away up to s of the darkness at its centre, falling off to nothing at radius r (destination-out with a
// radial gradient, so overlapping holes multiply).
uniform vec2 size = vec2(1280.0, 720.0);
uniform vec4 shade = vec4(0.0, 0.0, 0.0, 0.0);
uniform int count = 0;
uniform vec4 holes[96];   // x, y, r (screen pixels), s

void fragment() {
	vec2 p = UV * size;
	float a = shade.a;
	for (int i = 0; i < count; i++) {
		vec4 h = holes[i];
		float f = clamp(1.0 - distance(p, h.xy) / h.z, 0.0, 1.0);
		a *= 1.0 - h.w * f;
	}
	COLOR = vec4(shade.rgb, a);
}
