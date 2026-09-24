extends Control

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	var bg := ColorRect.new()
	bg.color = Color("#FFF0DA")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var center := VBoxContainer.new()
	center.set_anchors_preset(Control.PRESET_CENTER)
	center.offset_left = -180
	center.offset_top = -80
	center.offset_right = 180
	center.offset_bottom = 80
	center.add_theme_constant_override("separation", 16)
	add_child(center)

	var title := Label.new()
	title.text = "Булочка — Cozy Fast Food"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var font_bold: Font = load("res://assets/fonts/Nunito-Bold-Cyrillic.ttf")
	if font_bold:
		title.add_theme_font_override("font", font_bold)
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color("#5A454B"))
	center.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Выберите версию для теста"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var font: Font = load("res://assets/fonts/Nunito-Regular-Cyrillic.ttf")
	if font:
		subtitle.add_theme_font_override("font", font)
	subtitle.add_theme_font_size_override("font_size", 16)
	subtitle.add_theme_color_override("font_color", Color("#5A454B"))
	center.add_child(subtitle)

	var btn_2d := _make_button("Играть 2D", "res://scenes/2d/FastFood2D.tscn")
	center.add_child(btn_2d)

	var btn_3d := _make_button("Старая 3D версия", "res://Main.tscn")
	center.add_child(btn_3d)


func _make_button(text: String, scene_path: String) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(320, 48)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color("#F4B6C7")
	normal.corner_radius_top_left = 12
	normal.corner_radius_top_right = 12
	normal.corner_radius_bottom_left = 12
	normal.corner_radius_bottom_right = 12
	btn.add_theme_stylebox_override("normal", normal)
	var hover := normal.duplicate()
	hover.bg_color = Color("#E98FA9")
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", hover)
	var font_bold: Font = load("res://assets/fonts/Nunito-Bold-Cyrillic.ttf")
	if font_bold:
		btn.add_theme_font_override("font", font_bold)
	btn.add_theme_font_size_override("font_size", 18)
	btn.add_theme_color_override("font_color", Color("#5A454B"))
	btn.pressed.connect(func(): get_tree().change_scene_to_file(scene_path))
	return btn
