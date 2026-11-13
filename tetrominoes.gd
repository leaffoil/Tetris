class_name Tetrominoes

const NAMES := ["I", "O", "T", "S", "Z", "J", "L"]

const SHAPES := {
	"I": {"size": 4, "color": Color("4dd0e1"),
		"cells": [Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1), Vector2i(3, 1)]},
	"O": {"size": 2, "color": Color("fdd835"),
		"cells": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]},
	"T": {"size": 3, "color": Color("ab47bc"),
		"cells": [Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1)]},
	"S": {"size": 3, "color": Color("66bb6a"),
		"cells": [Vector2i(1, 0), Vector2i(2, 0), Vector2i(0, 1), Vector2i(1, 1)]},
	"Z": {"size": 3, "color": Color("ef5350"),
		"cells": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1), Vector2i(2, 1)]},
	"J": {"size": 3, "color": Color("42a5f5"),
		"cells": [Vector2i(0, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1)]},
	"L": {"size": 3, "color": Color("ffa726"),
		"cells": [Vector2i(2, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1)]},
}

static func rotate_cw(cells: Array, size: int) -> Array:
	var out := []
	for c in cells:
		out.append(Vector2i(size - 1 - c.y, c.x))
	return out
