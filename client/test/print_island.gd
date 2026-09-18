extends SceneTree
## Prints an island as text, seen straight from above (not the iso view).
## Dev tool, not a test: the generator uses floats and is kept out of tests.
##
## godot --headless --path client --script res://test/print_island.gd -- 42

const Terrain = preload("res://core/terrain.gd")
const IslandGenerator = preload("res://core/island_generator.gd")

# one symbol per terrain type, in terrain value order
const SYMBOLS := ["~", ".", "T", "^", ",", "#", "o", ":"]
const NAMES := ["water", "grass", "forest", "rock", "pasture", "cliff", "pond", "beach"]
const STEP := 4  # 256 cells don't fit on a screen, show every 4th


func _initialize() -> void:
	var island_seed := 1
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		island_seed = int(args[0])

	var start := Time.get_ticks_msec()
	var cells := IslandGenerator.generate(island_seed)
	var took := Time.get_ticks_msec() - start
	if cells.is_empty():
		quit(1)
		return

	for y in range(0, Terrain.SIZE, STEP):
		var line := ""
		for x in range(0, Terrain.SIZE, STEP):
			line += SYMBOLS[cells[Terrain.index(x, y)]]
		print(line)

	print("seed %d, %d ms" % [island_seed, took])
	var counts := IslandGenerator.count(cells)
	var parts: PackedStringArray = []
	for type in Terrain.TYPE_COUNT:
		parts.append("%s %d" % [NAMES[type], counts[type]])
	print(", ".join(parts))
	quit(0)
