shader_type spatial;
// The blocky world (ground, props, buildings, trees): the 2D game's colours as vertex colours (sRGB), lit flat (the
// faces carry the 2D shading already), darkened where a shadow falls. Pieces in front of someone go see-through
// (screen-door) by the 2D rules: anchor (UV2, a tile or a tree's foot) between 0 and fade.x tiles nearer the viewer
// than a watched person's x + y, and within fade.y of them across the screen. Vertex alpha below 1 marks a lit
// piece (a window, a kiln's mouth, a lamp): it glows by that much.
render_mode cull_disabled, specular_disabled;

uniform int who_n = 0;
uniform vec4 who[24];
uniform vec3 fade = vec3(0.0, 0.0, 0.32);
uniform float sun_k = 0.5;
uniform float grid = 0.0;   // the yard's tile lines (how dark)

varying vec2 anchor;
varying vec3 wpos;

// the Compatibility renderer lights in sRGB space: the 2D colours go in as they are
vec3 lin(vec3 c) {
	return c;
}

float bayer4(ivec2 q) {
	int i = (q.x & 3) + (q.y & 3) * 4;
	int m[16] = int[](0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5);
	return (float(m[i]) + 0.5) / 16.0;
}

void vertex() {
	anchor = UV2;
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 c = lin(COLOR.rgb);
	if (grid > 0.0) {
		vec2 g = abs(fract(wpos.xz + 0.5) - 0.5);
		vec2 w = fwidth(wpos.xz) * 0.9;
		float l = max(1.0 - smoothstep(0.0, w.x, g.x), 1.0 - smoothstep(0.0, w.y, g.y));
		c *= 1.0 - grid * l;
	}
	ALBEDO = c;
	if (COLOR.a < 0.99) {
		EMISSION = c * (1.0 - COLOR.a) * 1.6;
	}
	if (fade.x > 0.0 && anchor.x > -500.0) {
		bool f = false;
		for (int i = 0; i < who_n; i++) {
			float dd = anchor.x + anchor.y - (who[i].x + who[i].y);
			float lat = (anchor.x - anchor.y) - (who[i].x - who[i].y);
			if (dd > 0.0 && dd < fade.x && abs(lat) < fade.y) {
				f = true;
				break;
			}
		}
		if (f && bayer4(ivec2(FRAGCOORD.xy)) >= fade.z) {
			discard;
		}
	}
}

void light() {
	DIFFUSE_LIGHT += ATTENUATION * LIGHT_COLOR * sun_k;
}
