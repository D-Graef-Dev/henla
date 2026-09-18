extends RefCounted
## Builds the terrain of a new island from a seed.
##
## Uses float noise, the one allowed exception in core (Kontrakt 6).
## That's fine because the result is saved and never generated again.

# preload instead of class_name: headless runs have no editor class cache
const Terrain = preload("res://core/terrain.gd")

# Island types, picked by the seed. They only change the shape - a different
# mix of resources is meant for later regions.
# radius: how much of the map is land. stretch: 1.0 is round, higher is longer.
# frequency and weight: size and strength of the bumps in the coastline.
const TYPES := [
	{"name": "round", "radius": 0.75, "stretch": 1.0, "frequency": 0.012, "weight": 0.5},
	{"name": "long", "radius": 0.85, "stretch": 2.0, "frequency": 0.012, "weight": 0.5},
	{"name": "ragged", "radius": 0.80, "stretch": 1.2, "frequency": 0.020, "weight": 1.2},
	{"name": "small", "radius": 0.45, "stretch": 1.0, "frequency": 0.020, "weight": 0.5},
]

# Platzhalter 18.09.2026
const WATER_BORDER := 0.95
const COVER_FREQUENCY := 0.03
const CLIFF_FREQUENCY := 0.02
const ROCK_FREQUENCY := 0.025
const ROCK_LEVEL := 0.4
const FOREST_LEVEL := 0.2
const PASTURE_LEVEL := -0.3
const POND_LEVEL := -0.45
const CLIFF_LEVEL := 0.0
const MIN_CLIFF_LENGTH := 6
const MIN_BEACH_LENGTH := 4
const MIN_POND_SIZE := 4
const MIN_ROCK_SIZE := 6

const MIN_FOREST := 1500
const MIN_ROCK := 300
const MIN_PASTURE := 600
const MIN_BEACH := 150

const MAX_TRIES := 50


## Returns an empty array if none of the tries gives a usable island.
static func generate(island_seed: int) -> PackedByteArray:
	# The seed decides the type and the rotation, the tries only reroll the noise.
	var island_type: Dictionary = TYPES[absi(island_seed) % TYPES.size()]
	var angle := deg_to_rad(absi(island_seed) % 360)
	for i in MAX_TRIES:
		var cells := _build(island_seed + i, island_type, angle)
		if _is_usable(cells):
			return cells
	push_error("no usable island for seed %d" % island_seed)
	return PackedByteArray()


## Number of cells per terrain type. The terrain value is the list index.
static func count(cells: PackedByteArray) -> Array[int]:
	var counts: Array[int] = []
	counts.resize(Terrain.TYPE_COUNT)
	counts.fill(0)
	for type in cells:
		counts[type] += 1
	return counts


static func _build(noise_seed: int, island_type: Dictionary, angle: float) -> PackedByteArray:
	var radius: float = island_type["radius"]
	var stretch: float = island_type["stretch"]
	var weight: float = island_type["weight"]
	var frequency: float = island_type["frequency"]
	var shape_noise := _make_noise(noise_seed, frequency)
	var cover_noise := _make_noise(noise_seed + 1, COVER_FREQUENCY)
	var pond_noise := _make_noise(noise_seed + 2, COVER_FREQUENCY)
	var rock_noise := _make_noise(noise_seed + 3, ROCK_FREQUENCY)
	var cliff_noise := _make_noise(noise_seed + 4, CLIFF_FREQUENCY)

	var cells := PackedByteArray()
	cells.resize(Terrain.SIZE * Terrain.SIZE)  # all zeros = all water

	var center := Terrain.SIZE / 2.0
	for y in Terrain.SIZE:
		for x in Terrain.SIZE:
			# 0 in the middle, 1 at the map edge
			var from_center := Vector2(x - center, y - center) / center
			if from_center.length() > WATER_BORDER:
				continue  # keep a water border around every island

			# Turning and stretching gives the island its type's outline.
			var shaped := from_center.rotated(angle)
			shaped.x *= stretch

			# Falls off towards the edge, the noise makes the coast uneven.
			var height := 1.0 - shaped.length() / radius + shape_noise.get_noise_2d(x, y) * weight
			if height <= 0.0:
				continue

			# Holes in the land. Those not connected to the sea become ponds later.
			if pond_noise.get_noise_2d(x, y) < POND_LEVEL:
				continue

			var cover := cover_noise.get_noise_2d(x, y)
			var type := Terrain.GRASS
			if rock_noise.get_noise_2d(x, y) > ROCK_LEVEL:
				type = Terrain.ROCK
			elif cover > FOREST_LEVEL:
				type = Terrain.FOREST
			elif cover < PASTURE_LEVEL:
				type = Terrain.PASTURE
			cells[Terrain.index(x, y)] = type

	_keep_biggest_island(cells)
	_mark_ponds(cells)
	# Cliffs and beach need the finished coastline, so they come late.
	_add_cliffs(cells, cliff_noise)
	_add_beach(cells)
	# last, because the coast can cut off bits of rock
	_remove_rock_specks(cells)
	return cells


static func _make_noise(noise_seed: int, frequency: float) -> FastNoiseLite:
	var noise := FastNoiseLite.new()
	noise.seed = noise_seed
	noise.frequency = frequency
	return noise


# A few cells of rock look like noise and would make an easy quarry spot.
static func _remove_rock_specks(cells: PackedByteArray) -> void:
	var marked := PackedByteArray()
	marked.resize(cells.size())
	for i in cells.size():
		if cells[i] == Terrain.ROCK:
			marked[i] = 1

	var seen := PackedByteArray()
	seen.resize(cells.size())
	for y in Terrain.SIZE:
		for x in Terrain.SIZE:
			var i := Terrain.index(x, y)
			if marked[i] == 0 or seen[i] == 1:
				continue
			var piece := _collect_marked(marked, Vector2i(x, y), seen)
			if piece.size() >= MIN_ROCK_SIZE:
				continue
			for cell in piece:
				cells[Terrain.index(cell.x, cell.y)] = Terrain.GRASS


# Small islands cant be reached without ships, so they sink.
static func _keep_biggest_island(cells: PackedByteArray) -> void:
	var seen := PackedByteArray()
	seen.resize(cells.size())
	var biggest: Array[Vector2i] = []

	for y in Terrain.SIZE:
		for x in Terrain.SIZE:
			var i := Terrain.index(x, y)
			if cells[i] == Terrain.WATER or seen[i] == 1:
				continue
			var island := _flood(cells, Vector2i(x, y), seen)
			if island.size() > biggest.size():
				biggest = island

	var keep := PackedByteArray()
	keep.resize(cells.size())
	for cell in biggest:
		keep[Terrain.index(cell.x, cell.y)] = 1
	for i in cells.size():
		if keep[i] == 0:
			cells[i] = Terrain.WATER


# Water the sea can't reach is a pond. Ponds don't count as coast.
# Tiny ones look like holes, so they are filled with grass.
static func _mark_ponds(cells: PackedByteArray) -> void:
	var seen := PackedByteArray()
	seen.resize(cells.size())
	_flood(cells, Vector2i(0, 0), seen)  # the corner is always open sea

	for y in Terrain.SIZE:
		for x in Terrain.SIZE:
			var i := Terrain.index(x, y)
			if cells[i] != Terrain.WATER or seen[i] == 1:
				continue
			var pond := _flood(cells, Vector2i(x, y), seen)
			var type := Terrain.POND
			if pond.size() < MIN_POND_SIZE:
				type = Terrain.GRASS
			for cell in pond:
				cells[Terrain.index(cell.x, cell.y)] = type


static func _add_cliffs(cells: PackedByteArray, noise: FastNoiseLite) -> void:
	# Mark first and write later, so short pieces can be left out.
	var marked := PackedByteArray()
	marked.resize(cells.size())
	for y in Terrain.SIZE:
		for x in Terrain.SIZE:
			if _is_coast(cells, x, y) and noise.get_noise_2d(x, y) > CLIFF_LEVEL:
				marked[Terrain.index(x, y)] = 1

	# a few cells of cliff look like specks, not like a steep coast
	var seen := PackedByteArray()
	seen.resize(cells.size())
	for y in Terrain.SIZE:
		for x in Terrain.SIZE:
			var i := Terrain.index(x, y)
			if marked[i] == 0 or seen[i] == 1:
				continue
			var piece := _collect_marked(marked, Vector2i(x, y), seen)
			if piece.size() < MIN_CLIFF_LENGTH:
				continue
			for cell in piece:
				cells[Terrain.index(cell.x, cell.y)] = Terrain.CLIFF


# Every coast cell that didn't become a cliff is beach,
# so grass, forest and pasture never touch the sea.
static func _add_beach(cells: PackedByteArray) -> void:
	var marked := PackedByteArray()
	marked.resize(cells.size())
	for y in Terrain.SIZE:
		for x in Terrain.SIZE:
			if cells[Terrain.index(x, y)] != Terrain.CLIFF and _is_coast(cells, x, y):
				marked[Terrain.index(x, y)] = 1

	# ashort beach between two cliffs looks like a hole in the wall
	var seen := PackedByteArray()
	seen.resize(cells.size())
	for y in Terrain.SIZE:
		for x in Terrain.SIZE:
			var i := Terrain.index(x, y)
			if marked[i] == 0 or seen[i] == 1:
				continue
			var piece := _collect_marked(marked, Vector2i(x, y), seen)
			var type := Terrain.BEACH
			if piece.size() < MIN_BEACH_LENGTH:
				type = Terrain.CLIFF
			for cell in piece:
				cells[Terrain.index(cell.x, cell.y)] = type


# Like _flood, but for marked cells and in eight directions,
# because a diagonal coastline only touches at the corners.
# The water border keeps marked cells off the map edge.
static func _collect_marked(
		marked: PackedByteArray, start: Vector2i, seen: PackedByteArray) -> Array[Vector2i]:
	var piece: Array[Vector2i] = []
	var todo: Array[Vector2i] = [start]
	seen[Terrain.index(start.x, start.y)] = 1

	while not todo.is_empty():
		var cell: Vector2i = todo.pop_back()
		piece.append(cell)
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				var i := Terrain.index(cell.x + dx, cell.y + dy)
				if marked[i] == 1 and seen[i] == 0:
					seen[i] = 1
					todo.append(cell + Vector2i(dx, dy))

	return piece


# Collects all cel ls reachable from start in four directions without
# crossing between land and water, and marks them in seen.
static func _flood(
		cells: PackedByteArray, start: Vector2i, seen: PackedByteArray) -> Array[Vector2i]:
	const DIRECTIONS: Array[Vector2i] = [
		Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN,
	]
	var start_is_water := cells[Terrain.index(start.x, start.y)] == Terrain.WATER
	var area: Array[Vector2i] = []
	var todo: Array[Vector2i] = [start]
	seen[Terrain.index(start.x, start.y)] = 1

	while not todo.is_empty():
		var cell: Vector2i = todo.pop_back()
		area.append(cell)
		for dir in DIRECTIONS:
			var next := cell + dir
			if next.x < 0 or next.y < 0 or next.x >= Terrain.SIZE or next.y >= Terrain.SIZE:
				continue
			var i := Terrain.index(next.x, next.y)
			if seen[i] == 1:
				continue
			if (cells[i] == Terrain.WATER) != start_is_water:
				continue
			seen[i] = 1
			todo.append(next)

	return area


# Land next to the sea, corners included: in the iso view a diagonal
# neighbour still touches with its tip. Ponds are neither sea nor coast,
# or a pond touching the sea at a corner would get a beach in its middle.
static func _is_coast(cells: PackedByteArray, x: int, y: int) -> bool:
	var here := cells[Terrain.index(x, y)]
	if here == Terrain.WATER or here == Terrain.POND:
		return false
	# no bounds check needed: the water border keeps land off the map edge
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			if cells[Terrain.index(x + dx, y + dy)] == Terrain.WATER:
				return true
	return false


static func _is_usable(cells: PackedByteArray) -> bool:
	var counts := count(cells)
	return (
		counts[Terrain.FOREST] >= MIN_FOREST
		and counts[Terrain.ROCK] >= MIN_ROCK
		and counts[Terrain.PASTURE] >= MIN_PASTURE
		and counts[Terrain.BEACH] >= MIN_BEACH
	)
