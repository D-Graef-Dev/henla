shader_type canvas_item;
// Dithered fog around the map edge. A pixel is either full fog colour or
// left alone, so no blended colours outside the palette end up on screen.

// set from fog.gd
uniform float map_size = 256.0;
uniform vec2 tile_size = vec2(32.0, 16.0);
uniform float fog_depth = 8.0;
// placeholder, a palette colour: #a5a8b2 "Stein Licht"
uniform vec4 fog_color : source_color = vec4(0.647, 0.659, 0.698, 1.0);

// 4x4 ordered dither: the order in which pixels fill up with fog
const float BAYER[16] = float[16](
	0.0, 8.0, 2.0, 10.0,
	12.0, 4.0, 14.0, 6.0,
	3.0, 11.0, 1.0, 9.0,
	15.0, 7.0, 13.0, 5.0);

varying vec2 world_pos;

void vertex() {
	// the node sits at the map origin, so its local position is the world position
	world_pos = VERTEX;
}

void fragment() {
	// same diamond maths as in camera.gd: world position to cell coordinates
	float along = (world_pos.x - tile_size.x / 2.0) / tile_size.x;
	float down = world_pos.y / tile_size.y;
	vec2 cell = vec2(down + along, down - along);

	// 0 while inside the clear area, 1 at the map edge and beyond
	vec2 outside = max(fog_depth - cell, cell - (map_size - fog_depth));
	float density = clamp(max(outside.x, outside.y) / fog_depth, 0.0, 1.0);

	// pattern per world pixel, so it sticks to the map when the camera moves
	vec2 p = mod(floor(world_pos), 4.0);
	float threshold = (BAYER[int(p.y) * 4 + int(p.x)] + 0.5) / 16.0;
	if (density < threshold) {
		discard;
	}
	COLOR = fog_color;
}