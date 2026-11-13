extends Control


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	center.add_child(box)

	var title := Label.new()
	title.text = "TETRIS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 56)
	box.add_child(title)

	for d in GameState.SETTINGS:
		var b := Button.new()
		b.text = GameState.SETTINGS[d].name
		b.custom_minimum_size = Vector2(260, 52)
		b.pressed.connect(_on_pick.bind(d))
		box.add_child(b)


func _on_pick(d: int) -> void:
	GameState.difficulty = d
	get_tree().change_scene_to_file("res://menu.tscn")
