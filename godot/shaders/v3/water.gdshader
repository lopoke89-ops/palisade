shader_type spatial;
// Riverbend's water (drawTerrainLive): the tile colours, glints drifting downstream, a slow ripple. (flood.gdshader: the same over the
// flooded banks, with an alpha).
render_mode cull_disabled, specular_disabled;

uniform float t = 0.0;
uniform float sun_k = 0.5;
varying vec3 wpos;

// the Compatibility renderer lights in sRGB space: the 2D colours go in as they are
vec3 lin(vec3 c) {
	return c;
}

float h2(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 c = lin(COLOR.rgb);
	vec2 tile = floor(wpos.xz);
	vec2 f = wpos.xz - tile;
	float h = h2(tile + vec2(31.0, 7.0));
	float y = fract(t * 0.35 + h);
	float g = (1.0 - smoothstep(0.0, 0.03, abs(f.y - y))) * step(0.25 + h * 0.4, f.x) * step(f.x, 0.45 + h * 0.4);
	float h3 = h2(tile + vec2(5.0, 19.0));
	float y2 = fract(t * 0.35 + h3 + 0.5);
	g = max(g, (1.0 - smoothstep(0.0, 0.03, abs(f.y - y2))) * step(0.5 + h3 * 0.3, f.x) * step(f.x, 0.62 + h3 * 0.3) * 0.7);
	c = mix(c, lin(vec3(0.588, 0.784, 0.863)), g * 0.3);
	c *= 0.94 + 0.06 * sin(wpos.x * 3.1 + wpos.z * 1.7 + t * 1.3);
	ALBEDO = c;
}

void light() {
	DIFFUSE_LIGHT += ATTENUATION * LIGHT_COLOR * sun_k;
}
