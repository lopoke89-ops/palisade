shader_type canvas_item;
// Night (drawLighting in 17-scenery.js): a shade over the frame with soft round holes punched out of it. Each hole
// takes away up to s of the darkness at its centre, falling off to nothing at radius r (destination-out with a
// radial gradient, so overlapping holes multiply).
uniform vec2 size = vec2(1280.0, 720.0);
uniform vec4 shade = vec4(0.0, 0.0, 0.0, 0.0);
uniform int count = 0;
uniform vec4 holes[96];   // x, y, r (screen pixels), s
uniform int cone_count = 0;
uniform vec4 cones[6]; // screen origin, world aim
uniform float cone_reach[6];
uniform vec2 iso_scale = vec2(48.0, 24.0);

void fragment() {
	vec2 p = UV * size;
	float a = shade.a;
	for (int i = 0; i < count; i++) {
		vec4 h = holes[i];
		float f = clamp(1.0 - distance(p, h.xy) / h.z, 0.0, 1.0);
		a *= 1.0 - h.w * f;
	}
	for (int i = 0; i < cone_count; i++) {
		vec2 d = p - cones[i].xy;
		vec2 world = vec2((d.x / iso_scale.x + d.y / iso_scale.y) * 0.5, (d.y / iso_scale.y - d.x / iso_scale.x) * 0.5);
		float dist = length(world);
		float facing = dot(world / max(dist, 0.001), cones[i].zw);
		float cone = smoothstep(0.72, 0.9, facing) * sqrt(clamp(1.0 - dist / cone_reach[i], 0.0, 1.0));
		a *= 1.0 - cone * 0.98;
	}
	COLOR = vec4(shade.rgb, a);
}
