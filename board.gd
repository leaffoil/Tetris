extends Node2D

const COLS := 10
const ROWS := 20
const CELL := 32
const LINE_POINTS := [0, 40, 100, 300, 1200]

const DAS := 0.17             
const ARR := 0.05              
const SOFT_DROP_INTERVAL := 0.04

var grid: Array = []
var bag: Array = []

var piece_name := ""
var piece_cells: Array = []
var piece_size := 0
var piece_pos := Vector2i.ZERO

var fall_timer := 0.0
var fall_interval := 1.0
var is_game_over := false

var score := 0
var lines := 0
var level := 0
var start_level := 0
var speed_mult := 1.0

var hold_dir := 0
var das_timer := 0.0
var soft_timer := SOFT_DROP_INTERVAL


func _ready() -> void:
	randomize()
	var s: Dictionary = GameState.SETTINGS[GameState.difficulty]
	start_level = s.start_level
	speed_mult = s.speed_mult
	level = start_level
	update_speed()
	for y in ROWS:
		var row := []
		for x in COLS:
			row.append(null)
		grid.append(row)
	spawn_piece()


func update_speed() -> void:
	var l := mini(level, 29)
	var base := pow(0.8 - l * 0.007, l)
	fall_interval = maxf(base, 0.03) / speed_mult


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
		queue_redraw()


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
	for kick in [0, -1, 1, -2, 2]:
		var pos := piece_pos + Vector2i(kick, 0)
		if is_valid(rotated, pos):
			piece_cells = rotated
			piece_pos = pos
			return


func get_ghost_pos() -> Vector2i:
	var pos := piece_pos
	while is_valid(piece_cells, pos + Vector2i(0, 1)):
		pos += Vector2i(0, 1)
	return pos


func hard_drop() -> void:
	piece_pos = get_ghost_pos()
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
		score += LINE_POINTS[cleared] * (level + 1)
		lines += cleared
		level = start_level + floori(lines / 10.0)
		update_speed()
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
	# Esc = back to the difficulty menu at any time
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		get_tree().change_scene_to_file("res://menu.tscn")
		return
	if is_game_over:
		# Enter = back to the difficulty menu after dying
		if event is InputEventKey and event.pressed and (event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER):
			get_tree().change_scene_to_file("res://menu.tscn")
		return
	if event.is_action_pressed("move_left"):
		hold_dir = -1
		das_timer = 0.0
		try_move(Vector2i(-1, 0))
	elif event.is_action_pressed("move_right"):
		hold_dir = 1
		das_timer = 0.0
		try_move(Vector2i(1, 0))
	elif event.is_action_pressed("rotate_cw"):
		try_rotate()
	elif event.is_action_pressed("hard_drop"):
		hard_drop()
		fall_timer = 0.0


func _process(delta: float) -> void:
	if is_game_over:
		return
	handle_held_keys(delta)
	fall_timer += delta
	if fall_timer >= fall_interval:
		fall_timer = 0.0
		step_down()
	queue_redraw()


func handle_held_keys(delta: float) -> void:
	# Left / right sliding while the key is held
	if hold_dir != 0:
		var action := "move_left" if hold_dir < 0 else "move_right"
		if Input.is_action_pressed(action):
			das_timer += delta
			if das_timer >= DAS:
				das_timer -= ARR
				try_move(Vector2i(hold_dir, 0))
		else:
			hold_dir = 0
			if Input.is_action_pressed("move_left"):
				hold_dir = -1
				das_timer = 0.0
			elif Input.is_action_pressed("move_right"):
				hold_dir = 1
				das_timer = 0.0

	# Soft drop while holding Down
	if Input.is_action_pressed("soft_drop"):
		soft_timer += delta
		if soft_timer >= SOFT_DROP_INTERVAL:
			soft_timer = 0.0
			step_down()
			fall_timer = 0.0
	else:
		soft_timer = SOFT_DROP_INTERVAL


func _draw() -> void:
	draw_rect(Rect2(0, 0, COLS * CELL, ROWS * CELL), Color(0.08, 0.08, 0.12))
	for y in ROWS:
		for x in COLS:
			if grid[y][x] != null:
				draw_block(x, y, grid[y][x])
	if piece_name != "" and not is_game_over:
		var color: Color = Tetrominoes.SHAPES[piece_name].color
		# Ghost piece first, so the real piece draws on top of it
		var gp := get_ghost_pos()
		for c in piece_cells:
			draw_ghost_block(gp.x + c.x, gp.y + c.y, color)
		for c in piece_cells:
			draw_block(piece_pos.x + c.x, piece_pos.y + c.y, color)
	draw_hud()


func draw_hud() -> void:
	var font := ThemeDB.fallback_font
	var x := COLS * CELL + 24
	var diff_name: String = GameState.SETTINGS[GameState.difficulty].name
	draw_string(font, Vector2(x, 32), "SCORE", HORIZONTAL_ALIGNMENT_LEFT, -1, 22)
	draw_string(font, Vector2(x, 64), str(score), HORIZONTAL_ALIGNMENT_LEFT, -1, 30)
	draw_string(font, Vector2(x, 112), "LEVEL", HORIZONTAL_ALIGNMENT_LEFT, -1, 22)
	draw_string(font, Vector2(x, 144), str(level), HORIZONTAL_ALIGNMENT_LEFT, -1, 30)
	draw_string(font, Vector2(x, 192), "LINES", HORIZONTAL_ALIGNMENT_LEFT, -1, 22)
	draw_string(font, Vector2(x, 224), str(lines), HORIZONTAL_ALIGNMENT_LEFT, -1, 30)
	draw_string(font, Vector2(x, 272), diff_name.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 22)
	if is_game_over:
		var mid := ROWS * CELL * 0.5
		draw_string(font, Vector2(0, mid), "GAME OVER", HORIZONTAL_ALIGNMENT_CENTER, COLS * CELL, 40)
		draw_string(font, Vector2(0, mid + 40), "Press Enter", HORIZONTAL_ALIGNMENT_CENTER, COLS * CELL, 22)


func draw_block(x: int, y: int, color: Color) -> void:
	var r := Rect2(x * CELL, y * CELL, CELL, CELL)
	draw_rect(r, color)
	draw_rect(r, color.darkened(0.4), false, 2.0)


func draw_ghost_block(x: int, y: int, color: Color) -> void:
	var r := Rect2(x * CELL, y * CELL, CELL, CELL)
	draw_rect(r, Color(color, 0.2))
	draw_rect(r, Color(color, 0.7), false, 2.0)
