extends Node2D
## Shows a freshly generated island. Until M2 there is no backend yet,
## so this scene calls the generator directly.

const Terrain = preload("res://core/terrain.gd")
const IslandGenerator = preload("res://core/island_generator.gd")

@onready var _terrain: TileMapLayer = $Terrain
@onready var _fog: Polygon2D = $Fog
@onready var _camera: Camera2D = $Camera

# Placeholder: how many cells inside the map edge the fog begins.
# The camera centre stops where the fog begins.
const FOG_DEPTH := 8

func _ready() -> void:
	# a new island on every start, the seed is printed to rebuild it with print_island
	var island_seed := randi_range(0, 999_999_999)
	print("island seed: %d" % island_seed)

	var cells := IslandGenerator.generate(island_seed)
	_show_terrain(cells)
	
	var tile_size := _terrain.tile_set.tile_size
	_fog.cover_map(Terrain.SIZE, tile_size, FOG_DEPTH)
	_camera.limit_to_map(Terrain.SIZE, tile_size, FOG_DEPTH)
	var center := Vector2i(Terrain.SIZE, Terrain.SIZE) / 2
	_camera.center_on(_terrain.map_to_local(center))


func _show_terrain(cells: PackedByteArray) -> void:
	_terrain.clear()
	# the tile set has one atlas, its columns are in terrain value order
	var source_id := _terrain.tile_set.get_source_id(0)
	for y in Terrain.SIZE:
		for x in Terrain.SIZE:
			var type := cells[Terrain.index(x, y)]
			_terrain.set_cell(Vector2i(x, y), source_id, Vector2i(type, 0))
