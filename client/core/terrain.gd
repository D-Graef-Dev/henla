extends RefCounted
## Terrain types of an island map and how cells are laid out in the array.

# These numbers are stored in savegames. Never renumber them.
const WATER := 0
const GRASS := 1
const FOREST := 2
const ROCK := 3
const PASTURE := 4
const CLIFF := 5
const POND := 6
const BEACH := 7

const TYPE_COUNT := 8
const SIZE := 256


## Position of cell (x, y) in the terrain array, row by row.
static func index(x: int, y: int) -> int:
	return y * SIZE + x
