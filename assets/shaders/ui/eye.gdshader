shader_type canvas_item;
// Visibility indicator: an almond eye that opens as the player becomes
// visible, glowing warm in light and turning red when a guard is alarmed.

uniform float open_amount : hint_range(0.0, 1.0) = 0.0;
uniform float alert : hint_range(0.0, 1.0) = 0.0;
uniform vec4 lid_color : source_color = vec4(0.82, 0.66, 0.42, 0.9);

float almond(vec2 p, float h) {
	// Two arcs meeting at the corners; h = half-opening.
	float y = (1.0 - p.x * p.x) * h;
	return step(abs(p.y), y);
}

void fragment() {
	vec2 p = (UV - 0.5) * 2.0;
	float h = mix(0.06, 0.62, open_amount);
	float inner = almond(p, h);
	float outer = almond(p * vec2(0.94, 0.9), h + 0.12);
	float rim = clamp(outer - inner, 0.0, 1.0);
	vec3 calm = mix(vec3(0.25, 0.2, 0.15), vec3(1.0, 0.78, 0.42), open_amount);
	vec3 iris_col = mix(calm, vec3(1.0, 0.25, 0.15), alert);
	float iris = smoothstep(0.42, 0.3, length(p * vec2(1.0, 1.2))) * inner;
	float pupil = smoothstep(0.14, 0.1, length(p * vec2(1.0, 1.2))) * inner;
	vec3 col = lid_color.rgb * rim + iris_col * iris * (1.0 - pupil * 0.8);
	float a = max(rim * lid_color.a, iris * (0.4 + 0.6 * open_amount));
	COLOR = vec4(col, a);
}
