extends Node2D

const COLS := 10
const ROWS := 20
const CELL := 32
const LINE_POINTS := [0, 40, 100, 300, 1200]
const TSPIN_POINTS := [400, 800, 1200, 1600]
const TSPIN_NAMES := ["T-SPIN", "T-SPIN SINGLE", "T-SPIN DOUBLE", "T-SPIN TRIPLE"]

const DAS := 0.17               # delay before sliding starts
const ARR := 0.05               # time between slide steps
const SOFT_DROP_INTERVAL := 0.04

const LOCK_DELAY := 0.5         # seconds a piece can sit on the stack before locking
const MAX_LOCK_RESETS := 15     # how many times moving/rotating can restart that timer

const PREVIEW_COUNT := 5
const PREVIEW_CELL := 20

var grid: Array = []
var bag: Array = []
var queue: Array = []

var piece_name := ""
var piece_cells: Array = []
var piece_size := 0
var piece_pos := Vector2i.ZERO
var rot := 0

var held_piece := ""
var can_hold := true

var fall_timer := 0.0
var fall_interval := 1.0
var is_game_over := false

var lock_timer := 0.0
var lock_resets := 0
var lowest_y := 0
var last_was_rotation := false

var score := 0
var lines := 0
var level := 0
var start_level := 0
var speed_mult := 1.0

var message := ""
var message_timer := 0.0

var hold_dir := 0
var das_timer := 0.0
var soft_timer := SOFT_DROP_INTERVAL


func _ready() -> void:
	randomize()
	setup_inputs()
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


# Adds any missing key bindings automatically (rotate_ccw = Z, hold = C or Shift)
func setup_inputs() -> void:
	ensure_action("move_left", [KEY_LEFT])
	ensure_action("move_right", [KEY_RIGHT])
	ensure_action("soft_drop", [KEY_DOWN])
	ensure_action("rotate_cw", [KEY_UP, KEY_X])
	ensure_action("rotate_ccw", [KEY_Z])
	ensure_action("hard_drop", [KEY_SPACE])
	ensure_action("hold", [KEY_C, KEY_SHIFT])


func ensure_action(action: String, keys: Array) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action)
	for k in keys:
		var e := InputEventKey.new()
		e.physical_keycode = k as Key
		InputMap.action_add_event(action, e)


func update_speed() -> void:
	var l := mini(level, 29)
	var base := pow(0.8 - l * 0.007, l)
	fall_interval = maxf(base, 0.03) / speed_mult


# ---------- Piece queue ----------

func fill_queue() -> void:
	while queue.size() < PREVIEW_COUNT + 1:
		if bag.is_empty():
			bag = Tetrominoes.NAMES.duplicate()
			bag.shuffle()
		queue.append(bag.pop_back())


func take_next() -> String:
	fill_queue()
	return queue.pop_front()


func spawn_piece(pname: String = "") -> void:
	if pname == "":
		pname = take_next()
	fill_queue()
	piece_name = pname
	var data = Tetrominoes.SHAPES[piece_name]
	piece_cells = data.cells.duplicate()
	piece_size = data.size
	rot = 0
	piece_pos = Vector2i(floori((COLS - piece_size) / 2.0), 0)
	lowest_y = piece_pos.y
	lock_timer = 0.0
	lock_resets = 0
	last_was_rotation = false
	fall_timer = 0.0
	if not is_valid(piece_cells, piece_pos):
		is_game_over = true
		queue_redraw()


func hold_current() -> void:
	if not can_hold:
		return
	can_hold = false
	var current := piece_name
	if held_piece == "":
		held_piece = current
		spawn_piece()
	else:
		var incoming := held_piece
		held_piece = current
		spawn_piece(incoming)


# ---------- Movement ----------

func is_valid(cells: Array, pos: Vector2i) -> bool:
	for c in cells:
		var x: int = pos.x + c.x
		var y: int = pos.y + c.y
		if x < 0 or x >= COLS or y >= ROWS:
			return false
		if y >= 0 and grid[y][x] != null:
			return false
	return true


func is_grounded() -> bool:
	return not is_valid(piece_cells, piece_pos + Vector2i(0, 1))


# Called after every successful move or rotation: handles lock delay resets
func on_piece_moved() -> void:
	if piece_pos.y > lowest_y:
		lowest_y = piece_pos.y
		lock_resets = 0
	if is_grounded() and lock_resets < MAX_LOCK_RESETS:
		lock_timer = 0.0
		lock_resets += 1


func try_move(offset: Vector2i) -> bool:
	if is_valid(piece_cells, piece_pos + offset):
		piece_pos += offset
		last_was_rotation = false
		on_piece_moved()
		return true
	return false


func try_rotate(dir: int) -> void:
	if piece_name == "O":
		return
	var new_cells: Array
	if dir > 0:
		new_cells = Tetrominoes.rotate_cw(piece_cells, piece_size)
	else:
		new_cells = Tetrominoes.rotate_ccw(piece_cells, piece_size)
	var new_rot := (rot + dir + 4) % 4
	var kicks := Tetrominoes.get_kicks(piece_name, rot, new_rot)
	for k in kicks:
		var pos := piece_pos + Vector2i(k.x, -k.y)   # table is y-up, Godot is y-down
		if is_valid(new_cells, pos):
			piece_cells = new_cells
			piece_pos = pos
			rot = new_rot
			last_was_rotation = true
			on_piece_moved()
			return


func get_ghost_pos() -> Vector2i:
	var pos := piece_pos
	while is_valid(piece_cells, pos + Vector2i(0, 1)):
		pos += Vector2i(0, 1)
	return pos


func hard_drop() -> void:
	var gp := get_ghost_pos()
	if gp != piece_pos:
		last_was_rotation = false
	piece_pos = gp
	lock_piece()


# ---------- Locking and scoring ----------

# 3-corner rule: a T piece that was rotated into place with 3+ corners blocked
func is_tspin() -> bool:
	if piece_name != "T" or not last_was_rotation:
		return false
	var filled := 0
	for corner in [Vector2i(0, 0), Vector2i(2, 0), Vector2i(0, 2), Vector2i(2, 2)]:
		var x: int = piece_pos.x + corner.x
		var y: int = piece_pos.y + corner.y
		if x < 0 or x >= COLS or y >= ROWS:
			filled += 1
		elif y >= 0 and grid[y][x] != null:
			filled += 1
	return filled >= 3


func show_message(text: String) -> void:
	message = text
	message_timer = 1.6


func lock_piece() -> void:
	var tspin := is_tspin()
	var color: Color = Tetrominoes.SHAPES[piece_name].color
	for c in piece_cells:
		var x: int = piece_pos.x + c.x
		var y: int = piece_pos.y + c.y
		if y >= 0:
			grid[y][x] = color
	var cleared := clear_lines()
	var points := 0
	if tspin:
		points = TSPIN_POINTS[mini(cleared, 3)]
		show_message(TSPIN_NAMES[mini(cleared, 3)])
	elif cleared > 0:
		points = LINE_POINTS[cleared]
		if cleared == 4:
			show_message("TETRIS!")
	score += points * (level + 1)
	if cleared > 0:
		lines += cleared
		level = start_level + floori(lines / 10.0)
		update_speed()
	can_hold = true
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


# ---------- Input and game loop ----------

func _unhandled_input(event: InputEvent) -> void:
	# Esc = back to the difficulty menu at any time
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		get_tree().change_scene_to_file("res://menu.tscn")
		return
	if is_game_over:
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
		try_rotate(1)
	elif event.is_action_pressed("rotate_ccw"):
		try_rotate(-1)
	elif event.is_action_pressed("hold"):
		hold_current()
	elif event.is_action_pressed("hard_drop"):
		hard_drop()


func _process(delta: float) -> void:
	if is_game_over:
		return
	handle_held_keys(delta)

	# Gravity only moves the piece down; it never locks it by itself
	fall_timer += delta
	if fall_timer >= fall_interval:
		fall_timer = 0.0
		try_move(Vector2i(0, 1))

	# Lock delay: only starts counting while the piece is resting on something
	if is_grounded():
		lock_timer += delta
		if lock_timer >= LOCK_DELAY:
			lock_piece()
	else:
		lock_timer = 0.0

	if message_timer > 0.0:
		message_timer -= delta
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

	# Soft drop: moves down fast, but never places the piece
	if Input.is_action_pressed("soft_drop"):
		soft_timer += delta
		if soft_timer >= SOFT_DROP_INTERVAL:
			soft_timer = 0.0
			if try_move(Vector2i(0, 1)):
				fall_timer = 0.0
	else:
		soft_timer = SOFT_DROP_INTERVAL


# ---------- Drawing ----------

func _draw() -> void:
	draw_rect(Rect2(0, 0, COLS * CELL, ROWS * CELL), Color(0.08, 0.08, 0.12))
	for y in ROWS:
		for x in COLS:
			if grid[y][x] != null:
				draw_block(x, y, grid[y][x])
	if piece_name != "" and not is_game_over:
		var color: Color = Tetrominoes.SHAPES[piece_name].color
		var gp := get_ghost_pos()
		for c in piece_cells:
			draw_ghost_block(gp.x + c.x, gp.y + c.y, color)
		for c in piece_cells:
			draw_block(piece_pos.x + c.x, piece_pos.y + c.y, color)
	draw_hud()
	draw_side_panels()


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

	if message_timer > 0.0:
		var alpha := clampf(message_timer / 0.5, 0.0, 1.0)
		draw_string(font, Vector2(0, ROWS * CELL * 0.3), message, HORIZONTAL_ALIGNMENT_CENTER, COLS * CELL, 30, Color(1, 1, 1, alpha))

	if is_game_over:
		var mid := ROWS * CELL * 0.5
		draw_string(font, Vector2(0, mid), "GAME OVER", HORIZONTAL_ALIGNMENT_CENTER, COLS * CELL, 40)
		draw_string(font, Vector2(0, mid + 40), "Press Enter", HORIZONTAL_ALIGNMENT_CENTER, COLS * CELL, 22)


func draw_side_panels() -> void:
	var font := ThemeDB.fallback_font

	# HOLD on the left of the board
	var hold_x := -170.0
	draw_string(font, Vector2(hold_x, 32), "HOLD", HORIZONTAL_ALIGNMENT_LEFT, -1, 22)
	if held_piece != "":
		draw_preview(held_piece, Vector2(hold_x, 48), not can_hold)

	# NEXT queue on the right
	var next_x := COLS * CELL + 190.0
	draw_string(font, Vector2(next_x, 32), "NEXT", HORIZONTAL_ALIGNMENT_LEFT, -1, 22)
	for i in PREVIEW_COUNT:
		if i < queue.size():
			draw_preview(queue[i], Vector2(next_x, 48 + i * 56), false)


func draw_preview(pname: String, origin: Vector2, dim: bool) -> void:
	var data = Tetrominoes.SHAPES[pname]
	var cells: Array = data.cells
	var min_x := 99
	var max_x := -99
	var min_y := 99
	var max_y := -99
	for c in cells:
		min_x = mini(min_x, c.x)
		max_x = maxi(max_x, c.x)
		min_y = mini(min_y, c.y)
		max_y = maxi(max_y, c.y)
	var w := (max_x - min_x + 1) * PREVIEW_CELL
	var h := (max_y - min_y + 1) * PREVIEW_CELL
	# Center the piece inside a 4 x 2 cell box
	var offset := origin + Vector2((4 * PREVIEW_CELL - w) * 0.5, (2 * PREVIEW_CELL - h) * 0.5)
	var color: Color = data.color
	if dim:
		color = color.darkened(0.6)
	for c in cells:
		var pos := offset + Vector2(c.x - min_x, c.y - min_y) * PREVIEW_CELL
		var r := Rect2(pos, Vector2(PREVIEW_CELL, PREVIEW_CELL))
		draw_rect(r, color)
		draw_rect(r, color.darkened(0.4), false, 2.0)


func draw_block(x: int, y: int, color: Color) -> void:
	var r := Rect2(x * CELL, y * CELL, CELL, CELL)
	draw_rect(r, color)
	draw_rect(r, color.darkened(0.4), false, 2.0)


func draw_ghost_block(x: int, y: int, color: Color) -> void:
	var r := Rect2(x * CELL, y * CELL, CELL, CELL)
	draw_rect(r, Color(color, 0.2))
	draw_rect(r, Color(color, 0.7), false, 2.0)
