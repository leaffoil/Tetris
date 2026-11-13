extends Node2D

const COLS := 10
const ROWS := 20
const CELL := 32

var grid: Array = []          # grid[y][x] is a Color or null
var bag: Array = []

var piece_name := ""
var piece_cells: Array = []
var piece_size := 0
var piece_pos := Vector2i.ZERO

var fall_timer := 0.0
var fall_interval := 0.8
var is_game_over := false


func _ready() -> void:
	randomize()
	for y in ROWS:
		var row := []
		for x in COLS:
			row.append(null)
		grid.append(row)
	spawn_piece()


func next_from_bag() -> String:
	if bag.is_empty():
		bag = Tetrominoes.NAMES.duplicate()
		bag.shuffle()
	return bag.pop_back()


func spawn_piece() -> void:
	piece_name = next_from_bag()
	var data = Tetrominoes.SHAPES[piece_name]
	piece_cells = data.cells.duplicate()
	piece_size = data.size
	piece_pos = Vector2i(floori((COLS - piece_size) / 2.0), 0)
	if not is_valid(piece_cells, piece_pos):
		is_game_over = true
		print("Game over")


func is_valid(cells: Array, pos: Vector2i) -> bool:
	for c in cells:
		var x: int = pos.x + c.x
		var y: int = pos.y + c.y
		if x < 0 or x >= COLS or y >= ROWS:
			return false
		if y >= 0 and grid[y][x] != null:
			return false
	return true


func try_move(offset: Vector2i) -> bool:
	if is_valid(piece_cells, piece_pos + offset):
		piece_pos += offset
		return true
	return false


func try_rotate() -> void:
	var rotated := Tetrominoes.rotate_cw(piece_cells, piece_size)
	# Simple wall kicks: try in place, then shift left/right
	for kick in [0, -1, 1, -2, 2]:
		var pos := piece_pos + Vector2i(kick, 0)
		if is_valid(rotated, pos):
			piece_cells = rotated
			piece_pos = pos
			return


func hard_drop() -> void:
	while try_move(Vector2i(0, 1)):
		pass
	lock_piece()


func step_down() -> void:
	if not try_move(Vector2i(0, 1)):
		lock_piece()


func lock_piece() -> void:
	var color: Color = Tetrominoes.SHAPES[piece_name].color
	for c in piece_cells:
		var x: int = piece_pos.x + c.x
		var y: int = piece_pos.y + c.y
		if y >= 0:
			grid[y][x] = color
	var cleared := clear_lines()
	if cleared > 0:
		print("Cleared ", cleared)
	spawn_piece()


func clear_lines() -> int:
	var cleared := 0
	var y := ROWS - 1
	while y >= 0:
		if grid[y].all(func(cell): return cell != null):
			grid.remove_at(y)
			var row := []
			for x in COLS:
				row.append(null)
			grid.push_front(row)
			cleared += 1
		else:
			y -= 1
	return cleared


func _unhandled_input(event: InputEvent) -> void:
	if is_game_over:
		return
	if event.is_action_pressed("move_left"):
		try_move(Vector2i(-1, 0))
	elif event.is_action_pressed("move_right"):
		try_move(Vector2i(1, 0))
	elif event.is_action_pressed("soft_drop"):
		step_down()
		fall_timer = 0.0
	elif event.is_action_pressed("rotate_cw"):
		try_rotate()
	elif event.is_action_pressed("hard_drop"):
		hard_drop()
		fall_timer = 0.0


func _process(delta: float) -> void:
	if is_game_over:
		return
	fall_timer += delta
	if fall_timer >= fall_interval:
		fall_timer = 0.0
		step_down()
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(0, 0, COLS * CELL, ROWS * CELL), Color(0.08, 0.08, 0.12))
	for y in ROWS:
		for x in COLS:
			if grid[y][x] != null:
				draw_block(x, y, grid[y][x])
	if piece_name != "":
		var color: Color = Tetrominoes.SHAPES[piece_name].color
		for c in piece_cells:
			draw_block(piece_pos.x + c.x, piece_pos.y + c.y, color)


func draw_block(x: int, y: int, color: Color) -> void:
	var r := Rect2(x * CELL, y * CELL, CELL, CELL)
	draw_rect(r, color)
	draw_rect(r, color.darkened(0.4), false, 2.0)
