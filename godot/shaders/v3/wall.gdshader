shader_type spatial;
// Walls and doors (drawWallShape, 15-render.js), one MultiMesh of unit boxes: INSTANCE_CUSTOM is
// (material + 8 if a door, damage state 0..2, char 0..1, hit flash). Materials are Pal.MAT (wood, brick, metal,
// concrete) and 4, the Foreman's rock slab. Wood
// planks, brick courses, metal ribs, the door panel and handle, dark holes as it's damaged, charring as it burns.
// A wall in front of the soldier on this screen goes see-through (screen-door), as in the 2D.
render_mode cull_disabled, specular_disabled;

uniform vec4 top_c[5];
uniform vec4 left_c[5];
uniform vec4 right_c[5];
uniform vec4 line_c[5];
uniform vec4 door_c[5];
uniform vec2 me = vec2(-99.0);
uniform vec3 fade = vec3(3.2, 1.7, 0.3);
uniform float sun_k = 0.5;

varying vec3 lp;
varying vec3 ln;
varying vec4 cd;
varying vec2 anchor;

// the Compatibility renderer lights in sRGB space: the 2D colours go in as they are
vec3 lin(vec3 c) {
	return c;
}

float bayer4(ivec2 q) {
	int i = (q.x & 3) + (q.y & 3) * 4;
	int m[16] = int[](0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5);
	return (float(m[i]) + 0.5) / 16.0;
}

float h2(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

float hline(float v, float at, float w) {
	return 1.0 - smoothstep(w * 0.5, w, abs(v - at));
}

void vertex() {
	lp = VERTEX;
	ln = NORMAL;
	cd = INSTANCE_CUSTOM;
	anchor = (MODEL_MATRIX * vec4(0.5, 0.0, 0.5, 1.0)).xz;
}

void fragment() {
	int code = int(cd.x + 0.5);
	int mat = code % 8;
	bool door = code >= 8;
	int st = int(cd.y + 0.5);
	vec3 col;
	float face = 0.0;   // 0 top, 1 south (the 2D left face), 2 east (right), 3 the hidden sides
	if (ln.y > 0.5) {
		col = top_c[mat].rgb;
	} else if (ln.z > 0.5) {
		col = left_c[mat].rgb;
		face = 1.0;
	} else if (ln.x > 0.5) {
		col = right_c[mat].rgb;
		face = 2.0;
	} else {
		col = left_c[mat].rgb * 0.7;
		face = 3.0;
	}
	float ch = cd.z * 0.85;
	col = mix(col, face < 0.5 ? vec3(0.141, 0.106, 0.082) : (face < 1.5 ? vec3(0.114, 0.086, 0.071) : vec3(0.094, 0.071, 0.059)), ch);
	if (face < 0.5) {
		col = mix(col, vec3(1.0), cd.w * 0.35);
	}
	if (face > 0.5 && face < 2.5 && mat < 4) {
		float u = face < 1.5 ? lp.x : 1.0 - lp.z;
		float v = lp.y;
		float w = 0.035;
		float l = 0.0;
		if (mat == 2) {
			l = max(max(hline(u, 0.2, w), hline(u, 0.4, w)), max(hline(u, 0.6, w), hline(u, 0.8, w)));
		} else {
			l = max(hline(v, 0.33, w), hline(v, 0.66, w));
			if (mat == 1) {
				float vv = 0.0;
				if (v < 0.33) {
					vv = max(hline(u, 0.3, w), hline(u, 0.7, w));
				} else if (v < 0.66) {
					vv = hline(u, 0.5, w);
				} else {
					vv = max(hline(u, 0.15, w), hline(u, 0.85, w));
				}
				l = max(l, vv);
			}
		}
		col = mix(col, line_c[mat].rgb, l * line_c[mat].a);
		if (door && u > 0.3 && u < 0.7 && v < 0.82) {
			col = door_c[mat].rgb;
			if (abs(u - 0.62) < 0.035 && abs(v - 0.42) < 0.04) {
				col = vec3(0.886, 0.706, 0.212);
			}
		}
		if (st > 0) {
			int n = st == 1 ? 2 : 3;
			for (int q = 0; q < 3; q++) {
				if (q >= n) {
					break;
				}
				float hu = 0.2 + h2(anchor * 7.0 + vec2(float(q), face * 13.0)) * 0.6;
				float hv = 0.25 + h2(anchor * 3.0 + vec2(face, float(q) * 11.0)) * 0.5;
				vec2 d = vec2((u - hu) / (0.075 + 0.025 * float(st)), (v - hv) / (0.11 + 0.04 * float(st)));
				if (dot(d, d) < 1.0) {
					col = (mat == 2 && st == 1) ? mix(col, vec3(0.157, 0.173, 0.176), 0.75) : vec3(0.055, 0.043, 0.035);
				}
			}
		}
	}
	ALBEDO = lin(col);
	float dd = anchor.x + anchor.y - (me.x + me.y);
	float lat = (anchor.x - anchor.y) - (me.x - me.y);
	if (dd > 0.0 && dd < fade.x && abs(lat) < fade.y && bayer4(ivec2(FRAGCOORD.xy)) >= fade.z) {
		discard;
	}
}

void light() {
	DIFFUSE_LIGHT += ATTENUATION * LIGHT_COLOR * sun_k;
}
