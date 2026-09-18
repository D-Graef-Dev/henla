extends Polygon2D
## Dithered fog that hides the map edge. Drawn above the terrain.

# Enough to fill the widest possible view when the camera sits at the map edge.
const MARGIN := 1024.0


# depth: how many cells inside the map edge the fog begins
func cover_map(map_size: int, tile_size: Vector2i, depth: int) -> void:
	var tile := Vector2(tile_size)
	# the map diamond's corners, with cell (0, 0) at the top
	var top := Vector2(tile.x / 2.0, 0.0)
	var left := top + Vector2(-tile.x / 2.0, tile.y / 2.0) * map_size
	var right := top + Vector2(tile.x / 2.0, tile.y / 2.0) * map_size
	var bottom := top + Vector2(0.0, tile.y) * map_size

	polygon = PackedVector2Array([
		Vector2(left.x - MARGIN, top.y - MARGIN),
		Vector2(right.x + MARGIN, top.y - MARGIN),
		Vector2(right.x + MARGIN, bottom.y + MARGIN),
		Vector2(left.x - MARGIN, bottom.y + MARGIN),
	])

	var fog_material := material as ShaderMaterial
	fog_material.set_shader_parameter("map_size", float(map_size))
	fog_material.set_shader_parameter("tile_size", tile)
	fog_material.set_shader_parameter("fog_depth", float(depth))