extends Node3D

const PLAYER_SCRIPT = preload("res://scripts/player.gd")
const STATION_SCRIPT = preload("res://scripts/station.gd")

# Освещение кафе — меняй здесь для быстрой настройки cozy-атмосферы.
const SUN_ENERGY := 0.45
const WARM_LIGHT_ENERGY := 0.8
const WARM_LIGHT_RANGE := 8.0
const WARM_LIGHT_COLOR := Color("#ffd9bf")
const AMBIENT_ENERGY := 0.28
const AMBIENT_COLOR := Color("#fff0e1")
const ENV_BACKGROUND_COLOR := Color("#bde5cd")
const TONEMAP_EXPOSURE := 1.0
const GAME_VERSION := "0.0.03"

const FONT_REGULAR_LATIN := "res://assets/fonts/Nunito-Regular.ttf"
const FONT_SEMIBOLD_LATIN := "res://assets/fonts/Nunito-SemiBold.ttf"
const FONT_BOLD_LATIN := "res://assets/fonts/Nunito-Bold.ttf"
const FONT_REGULAR_CYRILLIC := "res://assets/fonts/Nunito-Regular-Cyrillic.ttf"
const FONT_SEMIBOLD_CYRILLIC := "res://assets/fonts/Nunito-SemiBold-Cyrillic.ttf"
const FONT_BOLD_CYRILLIC := "res://assets/fonts/Nunito-Bold-Cyrillic.ttf"

const UI_FONT_SMALL := 12
const UI_FONT_BODY := 14
const UI_FONT_MEDIUM := 16
const UI_FONT_TITLE := 20

const WORLD_FONT_SMALL := 14
const WORLD_FONT_BODY := 18
const WORLD_FONT_TITLE := 30
const WORLD_FONT_LOGO := 42

const COLOR_TEXT_PRIMARY := Color("#554653")
const COLOR_TEXT_SECONDARY := Color("#7a6874")
const COLOR_TEXT_LIGHT := Color("#fff8f2")
const COLOR_TEXT_ACCENT := Color("#c46f8d")
const COLOR_TEXT_MUTED := Color("#fff8f2", 0.72)

var ui_theme: Theme
var font_regular: Font
var font_semibold: Font
var font_bold: Font

var player

var grill_visual: Node3D
var grill_indicator: MeshInstance3D
var fryer_visual: Node3D
var soda_visual: Node3D
var assembly_visual: Node3D
var tray_visual: Node3D
var current_customer_root: Node3D
var current_order_label: Label3D
var current_name_label: Label3D
var register_screen: Label3D

var queue_roots: Array[Node3D] = []
var queue_data: Array = []
var seated_guests: Array[Node3D] = []
var table_positions = [
	Vector3(-3.15, 0, -3.45),
	Vector3(0.0, 0, -3.45),
	Vector3(3.15, 0, -3.45)
]

var order_label: Label
var order_items_label: Label
var tray_label: Label
var held_label: Label
var stack_label: Label
var money_label: Label
var status_label: Label
var day_label: Label
var queue_label: Label
var progress_bar: ProgressBar
var progress_label: Label
var debug_info_label: Label
var interaction_prompt_label: Label
var status_panel: PanelContainer
var status_hide_timer: Timer

var tray = []
var current_order = []
var burger_stack = []
var held_item = ""

var coins := 0
var hearts := 0
var order_number := 0
var day := 1
var served_today := 0
var target_today := 5

var busy := false
var transition_busy := false
var pending_action := ""
var pending_output := ""
var cook_timer: Timer

var current_customer = {}

var animal_profiles = [
	{
		"species": "bunny",
		"names": ["Мята", "Луна", "Соня"],
		"body": Color("#fff7ec"),
		"accent": Color("#f4b9cb")
	},
	{
		"species": "cat",
		"names": ["Ириска", "Персик", "Плюша"],
		"body": Color("#f2bd86"),
		"accent": Color("#d47f68")
	},
	{
		"species": "fox",
		"names": ["Фунтик", "Рыжик", "Искра"],
		"body": Color("#e99361"),
		"accent": Color("#fff0df")
	},
	{
		"species": "bear",
		"names": ["Плюш", "Кекс", "Мокко"],
		"body": Color("#bd9479"),
		"accent": Color("#9d705d")
	}
]

var pretty = {
	"burger": "Бургер",
	"fries": "Фри",
	"soda": "Напиток",
	"bun_bottom": "Нижняя булочка",
	"raw_patty": "Сырая котлета",
	"cooked_patty": "Готовая котлета",
	"cheese": "Сыр",
	"lettuce": "Салат",
	"tomato": "Помидор",
	"bun_top": "Верхняя булочка"
}

var colors = {
	"bun_bottom": Color("#e9ad5e"),
	"raw_patty": Color("#b65f5f"),
	"cooked_patty": Color("#744936"),
	"cheese": Color("#ffd85c"),
	"lettuce": Color("#8dcf72"),
	"tomato": Color("#e96161"),
	"bun_top": Color("#f1b768"),
	"fries": Color("#f5cf57"),
	"soda": Color("#ef9fb6")
}

var burger_recipe = [
	"bun_bottom",
	"cooked_patty",
	"cheese",
	"lettuce",
	"tomato",
	"bun_top"
]

var recipes = [
	["burger"],
	["fries"],
	["soda"],
	["burger", "fries"],
	["burger", "soda"],
	["fries", "soda"],
	["burger", "fries", "soda"]
]

func _ready() -> void:
	add_to_group("game")
	randomize()
	_load_fonts()
	_build_world()
	_spawn_player()
	_build_ui()
	_build_timer()
	_fill_initial_queue()
	_call_next_customer(true)
	_show_status("Кафе открылось. Теперь у входа есть очередь из зверят!")

func _process(_delta: float) -> void:
	if busy and cook_timer and not cook_timer.is_stopped():
		var total := 1.0
		match pending_action:
			"cook_patty":
				total = 2.6
			"make_fries":
				total = 2.5
			"make_soda":
				total = 1.2

		var elapsed := total - cook_timer.time_left
		progress_bar.value = clamp(elapsed / total * 100.0, 0.0, 100.0)

	_update_interaction_prompt()

	if debug_info_label:
		debug_info_label.text = "%d FPS  •  v%s" % [
			Engine.get_frames_per_second(),
			GAME_VERSION
		]

func _mat(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.82
	return m

func _box(parent: Node, name: String, pos: Vector3, size: Vector3, color: Color, collidable := true) -> Node3D:
	var holder: Node3D
	if collidable:
		holder = StaticBody3D.new()
	else:
		holder = Node3D.new()

	holder.name = name
	holder.position = pos
	parent.add_child(holder)

	var mesh := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	mesh.mesh = b
	mesh.material_override = _mat(color)
	holder.add_child(mesh)

	if collidable:
		var col := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		col.shape = shape
		holder.add_child(col)

	return holder

func _sphere(parent: Node, pos: Vector3, radius: float, color: Color) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = radius
	s.height = radius * 2.0
	mesh.mesh = s
	mesh.material_override = _mat(color)
	mesh.position = pos
	parent.add_child(mesh)
	return mesh

func _cylinder(parent: Node, pos: Vector3, radius: float, height: float, color: Color, rotate_x := 0.0) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = radius
	c.bottom_radius = radius
	c.height = height
	mesh.mesh = c
	mesh.material_override = _mat(color)
	mesh.position = pos
	mesh.rotation_degrees.x = rotate_x
	parent.add_child(mesh)
	return mesh

func _station(parent: Node, name: String, pos: Vector3, size: Vector3, color: Color, station_type: String, display_name: String, item_id := "", show_mesh := false) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = name
	body.position = pos
	body.set_script(STATION_SCRIPT)
	body.station_type = station_type
	body.display_name = display_name
	body.item_id = item_id
	parent.add_child(body)

	if show_mesh:
		var mesh := MeshInstance3D.new()
		var b := BoxMesh.new()
		b.size = size
		mesh.mesh = b
		mesh.material_override = _mat(color)
		body.add_child(mesh)

	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	body.add_child(col)

	return body

func _load_fonts() -> void:
	# Cyrillic subsets also cover basic Latin used in HUD/menu text.
	font_regular = load(FONT_REGULAR_CYRILLIC) as Font
	font_semibold = load(FONT_SEMIBOLD_CYRILLIC) as Font
	font_bold = load(FONT_BOLD_CYRILLIC) as Font
	if not font_regular:
		font_regular = load(FONT_REGULAR_LATIN) as Font
	if not font_semibold:
		font_semibold = load(FONT_SEMIBOLD_LATIN) as Font
	if not font_bold:
		font_bold = load(FONT_BOLD_LATIN) as Font

func _stylebox_panel(bg_alpha := 0.82, radius := 10) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.19, 0.14, 0.2, bg_alpha)
	box.corner_radius_top_left = radius
	box.corner_radius_top_right = radius
	box.corner_radius_bottom_left = radius
	box.corner_radius_bottom_right = radius
	box.content_margin_left = 12
	box.content_margin_top = 10
	box.content_margin_right = 12
	box.content_margin_bottom = 10
	return box

func _build_ui_theme() -> Theme:
	var theme := Theme.new()
	theme.default_font = font_regular
	theme.set_font("font", "Label", font_regular)
	theme.set_font_size("font_size", "Label", UI_FONT_BODY)
	theme.set_color("font_color", "Label", COLOR_TEXT_LIGHT)
	theme.set_stylebox("panel", "PanelContainer", _stylebox_panel())
	return theme

func _ui_label(parent: Node, font_size: int, color: Color, font: Font = null) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	var chosen := font
	if not chosen:
		if font_size >= UI_FONT_TITLE:
			chosen = font_bold
		elif font_size >= UI_FONT_BODY:
			chosen = font_semibold
		else:
			chosen = font_regular
	if chosen:
		label.add_theme_font_override("font", chosen)
	parent.add_child(label)
	return label

func _label3d(parent: Node, text: String, pos: Vector3, font_size: int, color: Color, outline_size := 4, centered := true, font: Font = null) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.position = pos
	label.font_size = font_size
	label.modulate = color
	label.outline_size = outline_size
	label.outline_modulate = Color("#fff7ee")
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER if centered else HORIZONTAL_ALIGNMENT_LEFT
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	if font:
		label.font = font
	elif font_size >= WORLD_FONT_LOGO - 6:
		label.font = font_bold
	elif font_size >= WORLD_FONT_TITLE:
		label.font = font_semibold
	else:
		label.font = font_regular
	parent.add_child(label)
	return label

func _menu_board_text(parent: Node, title: String, lines: Array, z_offset := -0.10) -> void:
	var title_y := 0.32
	var line_spacing := 0.22
	_label3d(parent, title, Vector3(0, title_y, z_offset), WORLD_FONT_TITLE, COLOR_TEXT_PRIMARY, 4, true, font_bold)
	for i in range(lines.size()):
		var line_y := title_y - 0.28 - i * line_spacing
		_label3d(parent, lines[i], Vector3(0, line_y, z_offset), WORLD_FONT_SMALL, COLOR_TEXT_SECONDARY, 3)

func _build_cafe_shell(world: Node3D) -> void:
	_box(world, "Floor", Vector3(0, -0.2, 0), Vector3(12, 0.4, 10), Color("#f6e7d9"))

	var tiles := Node3D.new()
	tiles.name = "FloorTiles"
	world.add_child(tiles)
	var tile_a := Color("#f6e7d9")
	var tile_b := Color("#efcad3")
	for ix in range(12):
		for iz in range(10):
			var tile_color := tile_a if (ix + iz) % 2 == 0 else tile_b
			_box(
				tiles,
				"Tile",
				Vector3(-5.5 + ix, 0.02, -4.5 + iz),
				Vector3(0.98, 0.03, 0.98),
				tile_color,
				false
			)

	_box(world, "BackWall", Vector3(0, 2.2, 4.9), Vector3(12, 4.8, 0.25), Color("#faf3ea"))
	_box(world, "LeftWall", Vector3(-5.9, 2.2, 0), Vector3(0.25, 4.8, 10), Color("#f5eef9"))
	_box(world, "RightWall", Vector3(5.9, 2.2, 0), Vector3(0.25, 4.8, 10), Color("#eef8f2"))

	var wainscot := Node3D.new()
	wainscot.name = "Wainscot"
	world.add_child(wainscot)
	_box(wainscot, "BackWainscot", Vector3(0, 0.55, 4.78), Vector3(12, 1.1, 0.12), Color("#f7cedd"), false)
	_box(wainscot, "LeftWainscot", Vector3(-5.78, 0.55, 0), Vector3(0.12, 1.1, 10), Color("#f0d4ea"), false)
	_box(wainscot, "RightWainscot", Vector3(5.78, 0.55, 0), Vector3(0.12, 1.1, 10), Color("#d9eee4"), false)
	_box(wainscot, "BackBorder", Vector3(0, 1.12, 4.76), Vector3(12, 0.06, 0.14), Color("#e8a8be"), false)
	_box(wainscot, "LeftBorder", Vector3(-5.76, 1.12, 0), Vector3(0.14, 0.06, 10), Color("#d8a0b8"), false)
	_box(wainscot, "RightBorder", Vector3(5.76, 1.12, 0), Vector3(0.14, 0.06, 10), Color("#a8cfc0"), false)

	_box(world, "Ceiling", Vector3(0, 4.55, 0), Vector3(12, 0.12, 10), Color("#fff4e8"), false)

func _build_front_facade(world: Node3D) -> void:
	var facade := Node3D.new()
	facade.name = "FrontFacade"
	world.add_child(facade)

	_box(facade, "DoorFrame", Vector3(5.72, 1.35, -1.2), Vector3(0.14, 2.7, 1.35), Color("#e8c4a8"), false)
	_box(facade, "DoorPanel", Vector3(5.68, 1.2, -1.2), Vector3(0.08, 2.35, 1.15), Color("#f4dcc8"), false)
	_box(facade, "DoorHandle", Vector3(5.64, 1.05, -0.75), Vector3(0.06, 0.12, 0.22), Color("#c8a888"), false)
	_box(facade, "DoorWindow", Vector3(5.66, 1.85, -1.2), Vector3(0.06, 0.55, 0.55), Color("#d8eef8"), false)

	_box(facade, "WindowFrameL", Vector3(5.72, 2.05, 1.8), Vector3(0.14, 1.5, 2.2), Color("#e8c4a8"), false)
	_box(facade, "WindowGlassL", Vector3(5.66, 2.05, 1.8), Vector3(0.06, 1.25, 1.85), Color("#cce8f4"), false)
	_box(facade, "WindowFrameR", Vector3(5.72, 2.05, -3.6), Vector3(0.14, 1.5, 2.2), Color("#e8c4a8"), false)
	_box(facade, "WindowGlassR", Vector3(5.66, 2.05, -3.6), Vector3(0.06, 1.25, 1.85), Color("#cce8f4"), false)

	_box(facade, "WindowSillL", Vector3(5.62, 1.25, 1.8), Vector3(0.18, 0.08, 2.3), Color("#fff0da"), false)
	_box(facade, "WindowSillR", Vector3(5.62, 1.25, -3.6), Vector3(0.18, 0.08, 2.3), Color("#fff0da"), false)

func _build_counter_decor(world: Node3D) -> void:
	_box(world, "FrontCounter", Vector3(0, 0.50, -1.8), Vector3(8.6, 1.0, 0.75), Color("#f19bb6"))
	_box(world, "CounterTop", Vector3(0, 1.01, -1.8), Vector3(8.8, 0.18, 0.95), Color("#fff0da"))

	for x in [-3.6, -1.8, 0.0, 1.8, 3.6]:
		_box(world, "CounterPanel", Vector3(x, 0.50, -2.18), Vector3(0.55, 0.85, 0.06), Color("#e888a4"), false)
		_box(world, "CounterPanelTrim", Vector3(x, 0.76, -2.19), Vector3(0.58, 0.05, 0.05), Color("#fff0da"), false)

	var serve = _station(
		world,
		"Serve",
		Vector3(0, 1.12, -1.8),
		Vector3(2.0, 0.22, 0.72),
		Color("#fff2ac"),
		"serve",
		"Выдать заказ",
		"",
		true
	)

	tray_visual = Node3D.new()
	tray_visual.name = "TrayVisual"
	tray_visual.position = Vector3(0, 0.08, 0)
	serve.add_child(tray_visual)
	_box(tray_visual, "TrayBase", Vector3(0, 0, 0), Vector3(1.45, 0.06, 0.58), Color("#de809e"), false)

	var register_root := Node3D.new()
	register_root.name = "Register"
	register_root.position = Vector3(-2.55, 1.08, -1.78)
	world.add_child(register_root)

	_box(register_root, "RegisterBody", Vector3(0, 0, 0), Vector3(1.05, 0.75, 0.60), Color("#f2a7bd"), false)
	_box(register_root, "RegisterScreen", Vector3(0, 0.13, -0.34), Vector3(0.78, 0.42, 0.08), Color("#fff0f5"), false)
	_box(register_root, "RegisterBase", Vector3(0, -0.42, 0.05), Vector3(1.15, 0.08, 0.68), Color("#e888a4"), false)

	register_screen = Label3D.new()
	register_screen.position = Vector3(0, 0.13, -0.40)
	register_screen.font_size = WORLD_FONT_BODY
	register_screen.font = font_semibold
	register_screen.modulate = COLOR_TEXT_PRIMARY
	register_root.add_child(register_screen)

	_box(register_root, "CardTerminal", Vector3(0.72, -0.12, -0.12), Vector3(0.34, 0.18, 0.42), Color("#c8dbea"), false)

	var shelf := Node3D.new()
	shelf.name = "CounterShelf"
	shelf.position = Vector3(2.35, 1.18, -1.78)
	world.add_child(shelf)
	_box(shelf, "ShelfBoard", Vector3(0, 0, 0), Vector3(0.85, 0.06, 0.35), Color("#fff0da"), false)
	for i in range(3):
		_cylinder(shelf, Vector3(-0.22 + i * 0.22, 0.12, 0), 0.05, 0.14, Color("#ffe9ef"))
	_box(shelf, "TakeawayBox", Vector3(0.28, 0.10, 0.05), Vector3(0.18, 0.12, 0.18), Color("#f4d6c8"), false)

	_label3d(world, "БУЛОЧКА", Vector3(0, 3.62, 4.56), WORLD_FONT_LOGO, COLOR_TEXT_PRIMARY, 5, true, font_bold)
	_label3d(world, "COZY FAST FOOD", Vector3(0, 3.18, 4.56), WORLD_FONT_SMALL, COLOR_TEXT_SECONDARY, 3)

	_box(world, "CounterSign", Vector3(-3.9, 1.85, -2.05), Vector3(0.55, 0.35, 0.06), Color("#fff0da"), false)
	_label3d(world, "OPEN", Vector3(-3.9, 1.85, -2.12), 14, Color("#6b5060"), 3)

func _build_ingredient_bin(parent: Node, name: String, pos: Vector3, item_id: String, display_name: String) -> StaticBody3D:
	var station := _station(
		parent,
		name,
		pos,
		Vector3(0.62, 0.22, 0.62),
		colors[item_id],
		"ingredient",
		display_name,
		item_id
	)
	_box(station, "BinRim", Vector3(0, -0.06, 0), Vector3(0.72, 0.10, 0.72), Color("#e8ddd0"), false)
	_box(station, "BinInner", Vector3(0, -0.02, 0), Vector3(0.58, 0.06, 0.58), Color("#d8cdbf"), false)
	return station

func _build_burger_prep_counter(world: Node3D) -> void:
	var center := Vector3(0.0, 0.45, 2.55)
	_box(world, "BurgerPrepCounter", center, Vector3(5.2, 1.1, 1.35), Color("#d9ead3"))
	_box(world, "BurgerPrepTop", Vector3(center.x, center.y + 0.63, center.z), Vector3(5.3, 0.08, 1.4), Color("#fff0da"), false)
	_box(world, "BurgerPrepBacksplash", Vector3(0, 1.35, 3.18), Vector3(5.4, 0.45, 0.08), Color("#efcad3"), false)

func _build_burger_workstation(world: Node3D) -> void:
	var station_y := 1.03
	var bin_z := 2.78

	var bun_bottom = _build_ingredient_bin(world, "BunBottom", Vector3(-1.65, station_y, bin_z), "bun_bottom", "Нижняя булочка")
	for i in range(3):
		_cylinder(bun_bottom, Vector3(-0.08 + i * 0.08, 0.12, 0.02), 0.17, 0.055, colors["bun_bottom"], 90)

	var cheese = _build_ingredient_bin(world, "Cheese", Vector3(-0.82, station_y, bin_z), "cheese", "Сыр")
	for i in range(3):
		var slice = _box(cheese, "CheeseSlice", Vector3(-0.06 + i * 0.06, 0.10, 0.0), Vector3(0.22, 0.025, 0.22), colors["cheese"], false)
		slice.rotation_degrees.y = -8 + i * 10

	var lettuce = _build_ingredient_bin(world, "Lettuce", Vector3(0.0, station_y, 2.95), "lettuce", "Салат")
	for i in range(3):
		var leaf = _cylinder(lettuce, Vector3(-0.08 + i * 0.08, 0.10, 0.0), 0.16, 0.025, colors["lettuce"], 90)
		leaf.rotation_degrees.y = -12 + i * 12

	var tomato = _build_ingredient_bin(world, "Tomato", Vector3(0.82, station_y, bin_z), "tomato", "Помидор")
	for i in range(3):
		_cylinder(tomato, Vector3(-0.07 + i * 0.07, 0.10, 0.0), 0.13, 0.025, colors["tomato"], 90)

	var bun_top = _build_ingredient_bin(world, "BunTop", Vector3(1.65, station_y, bin_z), "bun_top", "Верхняя булочка")
	for i in range(2):
		var top = _sphere(bun_top, Vector3(-0.05 + i * 0.10, 0.14 + i * 0.03, 0.0), 0.17, colors["bun_top"])
		top.scale = Vector3(1.0, 0.52, 1.0)
		for s in range(4):
			_sphere(bun_top, Vector3(-0.05 + i * 0.10 + randf_range(-0.06, 0.06), 0.20 + i * 0.03, randf_range(-0.06, 0.06)), 0.012, Color("#fff0da"))

	var raw_patty = _build_ingredient_bin(world, "RawPatty", Vector3(-2.45, station_y, 2.35), "raw_patty", "Сырая котлета")
	for i in range(3):
		_cylinder(raw_patty, Vector3(-0.08 + i * 0.08, 0.10, 0.0), 0.17, 0.045, colors["raw_patty"], 90)

	var grill_station = _station(world, "Grill", Vector3(-1.55, station_y, 2.35), Vector3(0.95, 0.25, 0.82), Color("#5f6066"), "grill", "Гриль", "", true)
	_build_grill_details(grill_station)

	var assembly_station = _station(world, "Assembly", Vector3(0.0, station_y, 2.35), Vector3(0.88, 0.22, 0.82), Color("#fff1d4"), "assemble", "Сборка бургера", "", true)
	_build_burger_assembly_board(assembly_station)

	_build_burger_counter_clutter(world)

func _build_grill_details(grill_station: StaticBody3D) -> void:
	_box(grill_station, "GrillBody", Vector3(0, -0.05, 0), Vector3(1.05, 0.35, 0.88), Color("#6a6b72"), false)
	_box(grill_station, "GrillBack", Vector3(0, 0.22, 0.38), Vector3(0.95, 0.28, 0.08), Color("#4a4b50"), false)
	grill_visual = Node3D.new()
	grill_visual.position = Vector3(0, 0.18, 0)
	grill_station.add_child(grill_visual)
	_box(grill_visual, "GrillSurface", Vector3(0, 0.02, 0), Vector3(0.82, 0.04, 0.62), Color("#2f3035"), false)
	for x in [-0.30, -0.10, 0.10, 0.30]:
		_box(grill_visual, "GrillLine", Vector3(x, 0, 0), Vector3(0.025, 0.035, 0.64), Color("#2f3035"), false)
	for i in range(2):
		_cylinder(grill_station, Vector3(-0.22 + i * 0.44, 0.18, -0.38), 0.05, 0.05, Color("#8a8088"))
	grill_indicator = _sphere(grill_station, Vector3(0.34, 0.22, -0.38), 0.035, Color("#5a5a5a"))

func _build_burger_assembly_board(assembly_station: StaticBody3D) -> void:
	_box(assembly_station, "BoardFrame", Vector3(0, 0.0, 0), Vector3(0.88, 0.05, 0.72), Color("#c8a888"), false)
	_box(assembly_station, "AssemblyBoard", Vector3(0, 0.03, 0), Vector3(0.82, 0.04, 0.66), Color("#fff0da"), false)
	assembly_visual = Node3D.new()
	assembly_visual.position = Vector3(0, 0.16, 0)
	assembly_station.add_child(assembly_visual)

func _build_burger_counter_clutter(world: Node3D) -> void:
	var clutter := Node3D.new()
	clutter.name = "BurgerClutter"
	clutter.position = Vector3(1.35, 1.01, 2.35)
	world.add_child(clutter)
	_box(clutter, "NapkinDispenser", Vector3(0, 0.08, 0.42), Vector3(0.18, 0.22, 0.14), Color("#fff0da"), false)
	_cylinder(clutter, Vector3(0.28, 0.10, 0.15), 0.04, 0.18, Color("#ffd2df"))
	_box(clutter, "TrayStack", Vector3(-0.30, 0.04, 0.38), Vector3(0.22, 0.06, 0.18), Color("#de809e"), false)
	_box(clutter, "SmallJar", Vector3(0.15, 0.06, -0.35), Vector3(0.10, 0.12, 0.10), Color("#cfe7ff"), false)
	_box(clutter, "SupplyTray", Vector3(-0.18, 0.04, -0.30), Vector3(0.16, 0.05, 0.16), Color("#f4d6c8"), false)

func _build_kitchen_decor(world: Node3D) -> void:
	_build_burger_prep_counter(world)
	_build_burger_workstation(world)

	_box(world, "Backsplash", Vector3(0, 1.35, 4.72), Vector3(10.5, 0.55, 0.08), Color("#fff0da"), false)
	_box(world, "BacksplashTile", Vector3(0, 1.35, 4.68), Vector3(10.5, 0.45, 0.04), Color("#efcad3"), false)

	for sx in [-4.8, 2.4]:
		_box(world, "KitchenShelf", Vector3(sx, 2.15, 4.65), Vector3(1.4, 0.08, 0.35), Color("#fff0da"), false)
		_box(world, "JarA", Vector3(sx - 0.25, 2.28, 4.65), Vector3(0.12, 0.18, 0.12), Color("#cfe7ff"), false)
		_box(world, "JarB", Vector3(sx + 0.25, 2.28, 4.65), Vector3(0.12, 0.18, 0.12), Color("#ffd2df"), false)

	_box(world, "SupplyBox", Vector3(-5.2, 0.35, 3.5), Vector3(0.45, 0.35, 0.45), Color("#f4d6c8"), false)

	var fryer_station = _station(world, "Fryer", Vector3(-4.6, 0.93, 0.65), Vector3(1.5, 0.4, 1.0), Color("#b7bcc4"), "fries", "Фритюрница", "", true)
	_box(fryer_station, "FryerBody", Vector3(0, -0.08, 0), Vector3(1.55, 0.55, 1.05), Color("#9aa0a8"), false)
	_box(fryer_station, "FryerPanel", Vector3(0, 0.05, -0.48), Vector3(0.55, 0.18, 0.08), Color("#7a8088"), false)
	for i in range(2):
		_box(fryer_station, "FryerBtn", Vector3(-0.12 + i * 0.24, 0.05, -0.53), Vector3(0.10, 0.08, 0.04), Color("#ffd2df") if i == 0 else Color("#cfe7ff"), false)
	fryer_visual = Node3D.new()
	fryer_visual.position = Vector3(0, 0.26, 0)
	fryer_station.add_child(fryer_visual)
	_box(fryer_visual, "Basket", Vector3(0, 0, 0), Vector3(0.72, 0.18, 0.62), Color("#72767c"), false)
	_box(fryer_visual, "BasketHandle", Vector3(0, 0.18, -0.22), Vector3(0.45, 0.05, 0.06), Color("#5a5e64"), false)
	for i in range(8):
		var fx = -0.28 + (i % 4) * 0.18
		var fz = -0.16 + int(i / 4) * 0.30
		var fry = _box(fryer_visual, "Fry", Vector3(fx, 0.15, fz), Vector3(0.08, 0.30, 0.08), Color("#f5cf57"), false)
		fry.rotation_degrees.z = 8 + i * 5

	var soda_station = _station(world, "Soda", Vector3(4.6, 1.38, 0.65), Vector3(1.4, 1.7, 0.8), Color("#94d7df"), "soda", "Автомат напитков", "", true)
	_box(soda_station, "SodaScreen", Vector3(0, 0.35, -0.35), Vector3(0.75, 0.45, 0.08), Color("#fff0f5"), false)
	_box(soda_station, "SodaDripTray", Vector3(0, -0.55, -0.35), Vector3(0.55, 0.08, 0.35), Color("#c8dbea"), false)
	for i in range(3):
		_box(soda_station, "SodaBtn", Vector3(-0.28 + i * 0.28, 0.05, -0.42), Vector3(0.16, 0.16, 0.06), [Color("#ffd2df"), Color("#cfe7ff"), Color("#ffe29d")][i], false)
	_box(soda_station, "SodaNozzle", Vector3(0, -0.15, -0.42), Vector3(0.10, 0.12, 0.10), Color("#7ab8c0"), false)
	soda_visual = Node3D.new()
	soda_visual.position = Vector3(0, -0.55, -0.47)
	soda_station.add_child(soda_visual)
	_cylinder(soda_visual, Vector3.ZERO, 0.16, 0.38, Color("#ffe9ef"))
	_box(soda_visual, "Straw", Vector3(0.05, 0.30, 0), Vector3(0.035, 0.42, 0.035), Color("#e4789c"), false)

	var trash_station = _station(world, "Trash", Vector3(5.0, 0.65, 3.95), Vector3(0.9, 1.2, 0.9), Color("#a9c7bb"), "trash", "Мусор", "", true)
	_box(trash_station, "TrashBody", Vector3(0, -0.05, 0), Vector3(0.75, 1.0, 0.75), Color("#8fb5a6"), false)
	_box(trash_station, "TrashLid", Vector3(0, 0.58, 0), Vector3(0.82, 0.08, 0.82), Color("#7aa898"), false)
	_box(trash_station, "TrashSlot", Vector3(0, 0.52, -0.28), Vector3(0.35, 0.06, 0.12), Color("#4a5a52"), false)

func _build_dining_decor(world: Node3D) -> void:
	for x in [-3.15, 0.0, 3.15]:
		_box(world, "DiningTable", Vector3(x, 0.72, -3.9), Vector3(1.65, 0.12, 1.15), Color("#fff0da"))
		_box(world, "DiningLegFL", Vector3(x - 0.62, 0.34, -3.45), Vector3(0.12, 0.70, 0.12), Color("#b58b78"), false)
		_box(world, "DiningLegFR", Vector3(x + 0.62, 0.34, -3.45), Vector3(0.12, 0.70, 0.12), Color("#b58b78"), false)
		_box(world, "DiningLegBL", Vector3(x - 0.62, 0.34, -4.35), Vector3(0.12, 0.70, 0.12), Color("#b58b78"), false)
		_box(world, "DiningLegBR", Vector3(x + 0.62, 0.34, -4.35), Vector3(0.12, 0.70, 0.12), Color("#b58b78"), false)
		_box(world, "ChairFront", Vector3(x, 0.42, -4.65), Vector3(0.75, 0.75, 0.75), Color("#e99ab2"), false)
		_box(world, "ChairSide", Vector3(x + 0.85, 0.42, -3.9), Vector3(0.65, 0.75, 0.65), Color("#f4b9cb"), false)
		_box(world, "NapkinHolder", Vector3(x - 0.45, 0.80, -3.65), Vector3(0.12, 0.08, 0.12), Color("#fff0da"), false)
		_cylinder(world, Vector3(x + 0.35, 0.82, -4.05), 0.06, 0.10, Color("#8fc79d"))

	var booth := Node3D.new()
	booth.name = "WallBooth"
	booth.position = Vector3(-5.35, 0, -1.5)
	world.add_child(booth)
	_box(booth, "BoothSeat", Vector3(0, 0.42, 0), Vector3(3.2, 0.45, 0.85), Color("#f4b9cb"), false)
	_box(booth, "BoothBack", Vector3(0, 0.95, -0.35), Vector3(3.2, 0.75, 0.18), Color("#fff0da"), false)
	_box(booth, "BoothTable", Vector3(0, 0.62, 0.55), Vector3(1.2, 0.08, 0.65), Color("#fff0da"), false)

func _build_wall_decor(world: Node3D) -> void:
	var menu_data = [
		{
			"title": "BURGER",
			"lines": ["Classic", "Cheese", "Fresh"],
			"color": Color("#fff1d7"),
			"icon_color": Color("#e9ad5e")
		},
		{
			"title": "FRIES",
			"lines": ["Classic", "Crispy", "Hot"],
			"color": Color("#ffe0e8"),
			"icon_color": Color("#f5cf57")
		},
		{
			"title": "DRINK",
			"lines": ["Cola", "Berry", "Soda"],
			"color": Color("#e0f0ff"),
			"icon_color": Color("#ef9fb6")
		}
	]

	for i in range(3):
		var x = -2.6 + i * 2.6
		var data = menu_data[i]
		var board = _box(
			world,
			"MenuBoard",
			Vector3(x, 3.25, 4.68),
			Vector3(2.1, 1.35, 0.12),
			data["color"],
			false
		)
		_box(board, "MenuFrame", Vector3(0, 0, -0.02), Vector3(2.0, 1.25, 0.04), Color("#fff0da"), false)
		_menu_board_text(board, data["title"], data["lines"])
		if i == 0:
			_cylinder(board, Vector3(0.55, -0.05, -0.10), 0.10, 0.06, data["icon_color"], 90)
			_sphere(board, Vector3(0.55, 0.02, -0.10), 0.10, data["icon_color"])
		elif i == 1:
			for fi in range(3):
				_box(board, "FryIcon", Vector3(0.45 + fi * 0.08, -0.05, -0.10), Vector3(0.05, 0.22, 0.05), data["icon_color"], false)
		else:
			_cylinder(board, Vector3(0.55, -0.05, -0.10), 0.08, 0.22, data["icon_color"])

	for x in [-4.5, -3.0, -1.5, 0.0, 1.5, 3.0, 4.5]:
		_sphere(world, Vector3(x, 4.35, 3.9), 0.10, [Color("#ffd2df"), Color("#ffe29d"), Color("#cfe7ff")][randi() % 3])

	var poster_positions = [Vector3(-5.55, 2.2, -2.5), Vector3(-5.55, 2.2, 0.5), Vector3(5.55, 2.2, 2.5)]
	var poster_colors = [Color("#ffe0e8"), Color("#e0f0ff"), Color("#fff1d7")]
	for i in range(3):
		_box(world, "Poster", poster_positions[i], Vector3(0.06, 0.75, 0.55), poster_colors[i], false)
		if i == 0:
			_cylinder(world, Vector3(poster_positions[i].x + 0.06, poster_positions[i].y, poster_positions[i].z), 0.08, 0.05, Color("#e9ad5e"), 90)
		elif i == 1:
			for fi in range(4):
				_box(world, "PosterFry", Vector3(poster_positions[i].x + 0.06, poster_positions[i].y - 0.08 + fi * 0.06, poster_positions[i].z), Vector3(0.04, 0.16, 0.04), Color("#f5cf57"), false)
		else:
			_cylinder(world, Vector3(poster_positions[i].x - 0.06, poster_positions[i].y, poster_positions[i].z), 0.07, 0.20, Color("#ef9fb6"))

	for x in [-4.7, 4.7]:
		_box(world, "PlantPot", Vector3(x, 0.38, -4.15), Vector3(0.65, 0.55, 0.65), Color("#e2ad7c"), false)
		_sphere(world, Vector3(x, 0.95, -4.15), 0.48, Color("#8fc79d"))

	_box(world, "WallShelf", Vector3(-5.55, 1.85, 3.2), Vector3(0.35, 0.08, 1.2), Color("#fff0da"), false)
	_box(world, "TakeawayStack", Vector3(-5.45, 1.98, 3.0), Vector3(0.22, 0.18, 0.22), Color("#f4d6c8"), false)
	_box(world, "TakeawayStack2", Vector3(-5.45, 2.12, 3.25), Vector3(0.18, 0.14, 0.18), Color("#ffe0e8"), false)
	for i in range(4):
		_cylinder(world, Vector3(5.45, 1.55 + i * 0.08, 0.0), 0.04, 0.10, Color("#ffe9ef"))

func _build_ceiling_lights(world: Node3D) -> void:
	var lamp_colors = [Color("#ffd2df"), Color("#cfe7ff"), Color("#fff0da"), Color("#b8e8cc"), Color("#ffe29d")]
	var lamp_positions = [
		Vector3(-2.5, 4.35, 2.5),
		Vector3(1.5, 4.35, 2.5),
		Vector3(3.8, 4.35, 2.5),
		Vector3(-1.5, 4.35, -1.5),
		Vector3(2.0, 4.35, -1.5),
		Vector3(0.0, 4.35, -3.5)
	]
	for i in range(lamp_positions.size()):
		var root := Node3D.new()
		root.name = "PendantLamp%d" % i
		root.position = lamp_positions[i]
		world.add_child(root)
		_cylinder(root, Vector3(0, 0.08, 0), 0.015, 0.35, Color("#d4c4b0"))
		_cylinder(root, Vector3(0, -0.22, 0), 0.20, 0.18, lamp_colors[i % lamp_colors.size()])
		_sphere(root, Vector3(0, -0.28, 0), 0.05, Color("#fff8ee"))

func _build_world() -> void:
	var world := Node3D.new()
	world.name = "Cafe"
	add_child(world)

	_build_cafe_shell(world)
	_build_front_facade(world)
	_build_counter_decor(world)
	_build_kitchen_decor(world)
	_build_dining_decor(world)
	_build_wall_decor(world)
	_build_ceiling_lights(world)

	_box(world, "QueueRug", Vector3(4.75, 0.01, -2.95), Vector3(1.35, 0.03, 2.8), Color("#d8eedf"), false)
	var qsign := Label3D.new()
	qsign.text = "ОЧЕРЕДЬ"
	qsign.position = Vector3(4.75, 1.0, -1.65)
	qsign.font_size = 22
	qsign.modulate = Color("#5f765f")
	qsign.rotation_degrees.y = 180
	world.add_child(qsign)

	_make_current_customer_root(world)
	_make_queue_roots(world)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -25, 0)
	sun.light_energy = SUN_ENERGY
	sun.shadow_enabled = true
	world.add_child(sun)

	var warm := OmniLight3D.new()
	warm.position = Vector3(0, 3.6, -1.0)
	warm.light_color = WARM_LIGHT_COLOR
	warm.omni_range = WARM_LIGHT_RANGE
	warm.light_energy = WARM_LIGHT_ENERGY
	world.add_child(warm)

	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = ENV_BACKGROUND_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = AMBIENT_COLOR
	env.ambient_light_energy = AMBIENT_ENERGY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = TONEMAP_EXPOSURE
	env.glow_enabled = false
	environment.environment = env
	world.add_child(environment)

func _make_current_customer_root(parent: Node) -> void:
	current_customer_root = Node3D.new()
	current_customer_root.name = "CurrentCustomer"
	current_customer_root.position = Vector3(0, 0, -3.15)
	parent.add_child(current_customer_root)

	current_name_label = Label3D.new()
	current_name_label.position = Vector3(0, 3.28, 0)
	current_name_label.font = font_semibold
	current_name_label.font_size = WORLD_FONT_BODY
	current_name_label.outline_size = 5
	current_name_label.outline_modulate = Color("#fff7ee")
	current_name_label.modulate = COLOR_TEXT_PRIMARY
	current_name_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	current_customer_root.add_child(current_name_label)

	current_order_label = Label3D.new()
	current_order_label.position = Vector3(0, 3.90, 0)
	current_order_label.font = font_regular
	current_order_label.font_size = WORLD_FONT_BODY
	current_order_label.outline_size = 6
	current_order_label.outline_modulate = Color("#fff7ee")
	current_order_label.modulate = COLOR_TEXT_PRIMARY
	current_order_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	current_customer_root.add_child(current_order_label)

func _make_queue_roots(parent: Node) -> void:
	queue_roots.clear()
	var positions = [
		Vector3(4.65, 0, -2.25),
		Vector3(4.65, 0, -3.15),
		Vector3(4.65, 0, -4.05)
	]
	for i in range(3):
		var root := Node3D.new()
		root.name = "QueueCustomer%d" % i
		root.position = positions[i]
		root.rotation_degrees.y = 90
		parent.add_child(root)
		queue_roots.append(root)

func _random_customer_data() -> Dictionary:
	var profile = animal_profiles[randi() % animal_profiles.size()]
	return {
		"species": profile["species"],
		"name": profile["names"][randi() % profile["names"].size()],
		"body": profile["body"],
		"accent": profile["accent"]
	}

func _fill_initial_queue() -> void:
	queue_data.clear()
	for i in range(3):
		queue_data.append(_random_customer_data())
	_refresh_queue_visuals()

func _call_next_customer(first := false) -> void:
	if queue_data.is_empty():
		queue_data.append(_random_customer_data())

	current_customer = queue_data.pop_front()
	queue_data.append(_random_customer_data())

	_clear_character_visual(current_customer_root)
	_build_animal(current_customer_root, current_customer, 1.0)
	current_name_label.text = current_customer["name"]

	_refresh_queue_visuals()
	_new_order()

	if not first:
		var base = current_customer_root.position
		current_customer_root.position = Vector3(4.1, 0, -2.2)
		var tween := create_tween()
		tween.tween_property(current_customer_root, "position", base, 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _refresh_queue_visuals() -> void:
	for i in range(queue_roots.size()):
		_clear_character_visual(queue_roots[i], false)
		if i < queue_data.size():
			_build_animal(queue_roots[i], queue_data[i], 0.72)

	if queue_label:
		queue_label.text = "В очереди: %d" % queue_data.size()

func _clear_character_visual(root: Node3D, keep_labels := true) -> void:
	for child in root.get_children():
		if keep_labels and (child == current_name_label or child == current_order_label):
			continue
		child.queue_free()

func _build_animal(root: Node3D, data: Dictionary, scale_factor: float) -> void:
	var species: String = data["species"]
	var body: Color = data["body"]
	var accent: Color = data["accent"]

	_sphere(root, Vector3(0, 1.25, 0) * scale_factor, 0.57 * scale_factor, body)
	_sphere(root, Vector3(0, 2.08, 0) * scale_factor, 0.50 * scale_factor, body)

	match species:
		"bunny":
			_box(root, "EarL", Vector3(-0.23, 2.70, 0) * scale_factor, Vector3(0.22, 0.78, 0.22) * scale_factor, body, false)
			_box(root, "EarR", Vector3(0.23, 2.70, 0) * scale_factor, Vector3(0.22, 0.78, 0.22) * scale_factor, body, false)
			_box(root, "EarInnerL", Vector3(-0.23, 2.70, -0.12) * scale_factor, Vector3(0.09, 0.58, 0.05) * scale_factor, accent, false)
			_box(root, "EarInnerR", Vector3(0.23, 2.70, -0.12) * scale_factor, Vector3(0.09, 0.58, 0.05) * scale_factor, accent, false)

		"cat":
			var ear_l = _box(root, "CatEarL", Vector3(-0.30, 2.54, 0) * scale_factor, Vector3(0.32, 0.34, 0.24) * scale_factor, body, false)
			ear_l.rotation_degrees.z = -25
			var ear_r = _box(root, "CatEarR", Vector3(0.30, 2.54, 0) * scale_factor, Vector3(0.32, 0.34, 0.24) * scale_factor, body, false)
			ear_r.rotation_degrees.z = 25
			_box(root, "Tail", Vector3(0.55, 1.15, 0.10) * scale_factor, Vector3(0.14, 0.75, 0.14) * scale_factor, accent, false)

		"fox":
			var ear_l = _box(root, "FoxEarL", Vector3(-0.31, 2.56, 0) * scale_factor, Vector3(0.34, 0.42, 0.26) * scale_factor, body, false)
			ear_l.rotation_degrees.z = -25
			var ear_r = _box(root, "FoxEarR", Vector3(0.31, 2.56, 0) * scale_factor, Vector3(0.34, 0.42, 0.26) * scale_factor, body, false)
			ear_r.rotation_degrees.z = 25
			_sphere(root, Vector3(0, 1.98, -0.43) * scale_factor, 0.20 * scale_factor, accent)
			var tail = _box(root, "FoxTail", Vector3(0.62, 1.15, 0.12) * scale_factor, Vector3(0.22, 0.90, 0.22) * scale_factor, body, false)
			tail.rotation_degrees.z = -20

		"bear":
			_sphere(root, Vector3(-0.38, 2.44, 0) * scale_factor, 0.19 * scale_factor, accent)
			_sphere(root, Vector3(0.38, 2.44, 0) * scale_factor, 0.19 * scale_factor, accent)
			_sphere(root, Vector3(0, 1.98, -0.44) * scale_factor, 0.18 * scale_factor, Color("#d7b59a"))

	# Глазки, щёки и нос.
	_sphere(root, Vector3(-0.17, 2.16, -0.45) * scale_factor, 0.055 * scale_factor, Color("#594b58"))
	_sphere(root, Vector3(0.17, 2.16, -0.45) * scale_factor, 0.055 * scale_factor, Color("#594b58"))
	_sphere(root, Vector3(-0.32, 2.00, -0.43) * scale_factor, 0.065 * scale_factor, Color("#f0a4b2"))
	_sphere(root, Vector3(0.32, 2.00, -0.43) * scale_factor, 0.065 * scale_factor, Color("#f0a4b2"))
	_sphere(root, Vector3(0, 2.03, -0.50) * scale_factor, 0.045 * scale_factor, Color("#6a5056"))

func _spawn_player() -> void:
	player = CharacterBody3D.new()
	player.name = "Player"
	player.set_script(PLAYER_SCRIPT)
	player.position = Vector3(0, 0.25, 0.55)

	var col := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.35
	capsule.height = 1.65
	col.shape = capsule
	col.position.y = 0.85
	player.add_child(col)

	add_child(player)

func _build_timer() -> void:
	cook_timer = Timer.new()
	cook_timer.one_shot = true
	cook_timer.timeout.connect(_finish_action)
	add_child(cook_timer)

func _build_ui() -> void:
	ui_theme = _build_ui_theme()
	var layer := CanvasLayer.new()
	add_child(layer)

	var left_panel := PanelContainer.new()
	left_panel.position = Vector2(14, 14)
	left_panel.custom_minimum_size = Vector2(430, 128)
	left_panel.add_theme_stylebox_override("panel", _stylebox_panel(0.84, 12))
	left_panel.theme = ui_theme
	layer.add_child(left_panel)

	var left_box := VBoxContainer.new()
	left_box.add_theme_constant_override("separation", 4)
	left_panel.add_child(left_box)

	day_label = _ui_label(left_box, UI_FONT_SMALL, COLOR_TEXT_MUTED)
	order_label = _ui_label(left_box, UI_FONT_TITLE, COLOR_TEXT_LIGHT, font_bold)
	order_items_label = _ui_label(left_box, UI_FONT_MEDIUM, COLOR_TEXT_ACCENT, font_semibold)
	tray_label = _ui_label(left_box, UI_FONT_BODY, COLOR_TEXT_MUTED)
	held_label = _ui_label(left_box, UI_FONT_SMALL, COLOR_TEXT_MUTED)
	stack_label = _ui_label(left_box, UI_FONT_SMALL, COLOR_TEXT_MUTED)
	money_label = _ui_label(left_box, UI_FONT_SMALL, COLOR_TEXT_LIGHT, font_semibold)

	var right_panel := PanelContainer.new()
	right_panel.anchor_left = 1.0
	right_panel.anchor_right = 1.0
	right_panel.anchor_top = 0.0
	right_panel.anchor_bottom = 0.0
	right_panel.offset_left = -236
	right_panel.offset_right = -14
	right_panel.offset_top = 14
	right_panel.offset_bottom = 112
	right_panel.add_theme_stylebox_override("panel", _stylebox_panel(0.72, 10))
	right_panel.theme = ui_theme
	layer.add_child(right_panel)

	var right_box := VBoxContainer.new()
	right_box.add_theme_constant_override("separation", 3)
	right_panel.add_child(right_box)

	queue_label = _ui_label(right_box, UI_FONT_BODY, COLOR_TEXT_SECONDARY, font_semibold)
	queue_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	var help := _ui_label(right_box, UI_FONT_SMALL, COLOR_TEXT_SECONDARY)
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	help.text = "WASD — ходить\nМышь — смотреть\nE — действие\nEsc — мышь"

	var hint := _ui_label(right_box, UI_FONT_SMALL - 1, COLOR_TEXT_MUTED)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hint.text = "После выдачи гость идёт за столик."

	status_panel = PanelContainer.new()
	status_panel.anchor_left = 0.5
	status_panel.anchor_right = 0.5
	status_panel.anchor_top = 1.0
	status_panel.anchor_bottom = 1.0
	status_panel.offset_left = -280
	status_panel.offset_right = 280
	status_panel.offset_top = -96
	status_panel.offset_bottom = -52
	status_panel.modulate.a = 0.0
	status_panel.visible = false
	status_panel.add_theme_stylebox_override("panel", _stylebox_panel(0.78, 14))
	status_panel.theme = ui_theme
	layer.add_child(status_panel)

	status_label = _ui_label(status_panel, UI_FONT_MEDIUM, COLOR_TEXT_LIGHT, font_semibold)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	status_hide_timer = Timer.new()
	status_hide_timer.one_shot = true
	status_hide_timer.wait_time = 3.5
	status_hide_timer.timeout.connect(_hide_status_panel)
	add_child(status_hide_timer)

	progress_bar = ProgressBar.new()
	progress_bar.anchor_left = 0.5
	progress_bar.anchor_right = 0.5
	progress_bar.anchor_top = 1.0
	progress_bar.anchor_bottom = 1.0
	progress_bar.offset_left = -190
	progress_bar.offset_right = 190
	progress_bar.offset_top = -135
	progress_bar.offset_bottom = -110
	progress_bar.show_percentage = false
	progress_bar.visible = false
	layer.add_child(progress_bar)

	progress_label = _ui_label(layer, UI_FONT_BODY, COLOR_TEXT_LIGHT, font_semibold)
	progress_label.anchor_left = 0.5
	progress_label.anchor_right = 0.5
	progress_label.anchor_top = 1.0
	progress_label.anchor_bottom = 1.0
	progress_label.offset_left = -260
	progress_label.offset_right = 260
	progress_label.offset_top = -166
	progress_label.offset_bottom = -138
	progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	progress_label.visible = false

	var cross := Label.new()
	cross.anchor_left = 0.5
	cross.anchor_right = 0.5
	cross.anchor_top = 0.5
	cross.anchor_bottom = 0.5
	cross.offset_left = -10
	cross.offset_right = 10
	cross.offset_top = -15
	cross.offset_bottom = 15
	cross.text = "•"
	cross.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cross.add_theme_font_size_override("font_size", 24)
	cross.add_theme_color_override("font_color", Color(1, 1, 1, 0.92))
	layer.add_child(cross)

	interaction_prompt_label = Label.new()
	interaction_prompt_label.anchor_left = 0.5
	interaction_prompt_label.anchor_right = 0.5
	interaction_prompt_label.anchor_top = 0.5
	interaction_prompt_label.anchor_bottom = 0.5
	interaction_prompt_label.offset_left = -220
	interaction_prompt_label.offset_right = 220
	interaction_prompt_label.offset_top = 34
	interaction_prompt_label.offset_bottom = 62
	interaction_prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	interaction_prompt_label.add_theme_font_override("font", font_semibold)
	interaction_prompt_label.add_theme_font_size_override("font_size", UI_FONT_MEDIUM)
	interaction_prompt_label.add_theme_color_override("font_color", COLOR_TEXT_LIGHT)
	interaction_prompt_label.visible = false
	layer.add_child(interaction_prompt_label)

	debug_info_label = Label.new()
	debug_info_label.anchor_left = 1.0
	debug_info_label.anchor_right = 1.0
	debug_info_label.anchor_top = 0.0
	debug_info_label.anchor_bottom = 0.0
	debug_info_label.offset_left = -150
	debug_info_label.offset_right = -10
	debug_info_label.offset_top = 8
	debug_info_label.offset_bottom = 28
	debug_info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	debug_info_label.add_theme_font_override("font", font_regular)
	debug_info_label.add_theme_font_size_override("font_size", UI_FONT_SMALL)
	debug_info_label.add_theme_color_override("font_color", Color(0.72, 0.72, 0.76, 0.72))
	layer.add_child(debug_info_label)

	_update_ui()

func _resolve_interaction_text(station: Node) -> String:
	if not station or not station.has_method("get_interaction_text"):
		return ""

	match station.station_type:
		"ingredient":
			if held_item != "":
				return "В лапках уже что-то есть"
			if station.item_id in pretty:
				return "Взять " + pretty[station.item_id].to_lower()
			return station.get_interaction_text()
		"grill":
			if held_item == "raw_patty":
				return "Положить на гриль"
			if busy and pending_action == "cook_patty":
				return "Котлета жарится"
			if held_item == "cooked_patty":
				return "Забрать котлету с гриля"
			return "Гриль"
		"assemble":
			if held_item != "":
				return "Положить на доску"
			if burger_stack.size() >= burger_recipe.size():
				return "Бургер собран"
			return "Сборка бургера"
		"fries":
			if busy:
				return "Картошка жарится"
			return "Сделать картошку"
		"soda":
			if busy:
				return "Напиток наливается"
			return "Налить напиток"
		"serve":
			return "Выдать заказ"
		"trash":
			return "Выбросить"
		_:
			return station.get_interaction_text()

func _update_interaction_prompt() -> void:
	if not interaction_prompt_label:
		return
	if not player or not player.has_method("get_interact_target"):
		interaction_prompt_label.visible = false
		return

	var target = player.get_interact_target()
	if not target:
		interaction_prompt_label.visible = false
		return

	var action_text := _resolve_interaction_text(target)
	if action_text == "":
		interaction_prompt_label.visible = false
		return

	interaction_prompt_label.text = "E  " + action_text
	interaction_prompt_label.visible = true

func _hide_status_panel() -> void:
	if not status_panel:
		return
	var tween := create_tween()
	tween.tween_property(status_panel, "modulate:a", 0.0, 0.35)
	tween.tween_callback(func(): status_panel.visible = false)

func _label(parent: Node, pos: Vector2, size: Vector2, font_size: int) -> Label:
	var l := Label.new()
	l.position = pos
	l.size = size
	l.add_theme_font_size_override("font_size", font_size)
	parent.add_child(l)
	return l

func use_station(station_type: String, _display_name: String, item_id: String) -> void:
	if transition_busy:
		_show_status("Секундочку — посетители меняются местами.")
		return

	if busy:
		_show_status("Подожди немного — сейчас идёт приготовление.")
		return

	match station_type:
		"ingredient":
			_pick_ingredient(item_id)
		"grill":
			_use_grill()
		"assemble":
			_use_assembly()
		"fries":
			_start_action("make_fries", "Картошка жарится во фритюрнице…", 2.5, "fries")
		"soda":
			_start_action("make_soda", "Стакан наполняется напитком…", 1.2, "soda")
		"serve":
			_serve_order()
		"trash":
			held_item = ""
			burger_stack.clear()
			_clear_assembly_visual()
			_show_status("Текущая готовка очищена.")
			_sync_held_visual()
			_update_ui()

func _pick_ingredient(item_id: String) -> void:
	if held_item != "":
		_show_status("В лапках уже что-то есть.")
		return

	held_item = item_id
	_sync_held_visual()
	_show_status("Взято: " + pretty[item_id])
	_update_ui()

func _use_grill() -> void:
	if held_item != "raw_patty":
		_show_status("На гриль нужно положить сырую котлету.")
		return

	held_item = ""
	_sync_held_visual()
	_show_grill_patty(Color("#b65f5f"))
	_start_action("cook_patty", "Котлета жарится на гриле…", 2.6, "cooked_patty")

func _use_assembly() -> void:
	if held_item == "":
		_show_status("Возьми ингредиент и положи его на сборочный стол.")
		return

	var expected_index := burger_stack.size()
	if expected_index >= burger_recipe.size():
		_show_status("Бургер уже собран.")
		return

	var expected = burger_recipe[expected_index]

	if held_item != expected:
		_show_status("Следующий слой: " + pretty[expected])
		return

	burger_stack.append(held_item)
	_add_assembly_layer(held_item, burger_stack.size() - 1)
	held_item = ""
	_sync_held_visual()

	if burger_stack.size() == burger_recipe.size():
		if tray.size() >= 3:
			_show_status("Бургер готов, но поднос заполнен.")
			return

		tray.append("burger")
		burger_stack.clear()
		_show_status("Бургер собран и поставлен на поднос!")
		_refresh_tray_visual()

		var tween := create_tween()
		tween.tween_property(assembly_visual, "scale", Vector3(1.12, 1.12, 1.12), 0.10)
		tween.tween_property(assembly_visual, "scale", Vector3.ONE, 0.10)
		tween.tween_interval(0.25)
		tween.tween_callback(_clear_assembly_visual)
	else:
		_show_status("Слой добавлен. Следующий: " + pretty[burger_recipe[burger_stack.size()]])

	_update_ui()

func _start_action(action: String, text: String, duration: float, output: String) -> void:
	if output in ["fries", "soda"] and tray.size() >= 3:
		_show_status("На подносе нет места.")
		return

	busy = true
	pending_action = action
	pending_output = output

	progress_bar.value = 0
	progress_bar.visible = true
	progress_label.text = text
	progress_label.visible = true

	cook_timer.start(duration)
	_show_status(text)

	if action == "cook_patty":
		_set_grill_indicator(true)
	elif action == "make_fries":
		_bounce_node(fryer_visual)
	elif action == "make_soda":
		_bounce_node(soda_visual)

func _finish_action() -> void:
	busy = false
	progress_bar.visible = false
	progress_label.visible = false

	if pending_action == "cook_patty":
		_set_grill_indicator(false)
		_show_grill_patty(Color("#744936"))
		held_item = "cooked_patty"
		_sync_held_visual()
		_show_status("Котлета готова и снова в лапках.")

		var tween := create_tween()
		tween.tween_interval(0.25)
		tween.tween_callback(_clear_grill_visual)

	elif pending_output in ["fries", "soda"]:
		tray.append(pending_output)
		_refresh_tray_visual()
		_show_status(pretty[pending_output] + " готово и поставлено на поднос.")

	pending_action = ""
	pending_output = ""
	_update_ui()

func _serve_order() -> void:
	if held_item != "" or not burger_stack.is_empty():
		_show_status("Сначала закончи текущую готовку.")
		return

	if tray.is_empty():
		_show_status("Поднос пуст.")
		return

	var a = tray.duplicate()
	var b = current_order.duplicate()
	a.sort()
	b.sort()

	if a != b:
		_show_status("На подносе не тот заказ. Можно исправить без штрафа.")
		return

	transition_busy = true

	var reward := 4 + current_order.size() * 3
	coins += reward
	hearts += 1
	served_today += 1

	var served_customer = current_customer.duplicate()
	var served_order = current_order.duplicate()
	_show_status("%s доволен! +%d монет, +1 сердечко." % [served_customer["name"], reward])

	tray.clear()
	_refresh_tray_visual()
	current_order_label.text = "Спасибо! ♥"

	_happy_customer()

	var timer := get_tree().create_timer(0.55)
	await timer.timeout

	_send_customer_to_table(served_customer, served_order)

	if served_today >= target_today:
		_finish_day()
	else:
		_call_next_customer()

	transition_busy = false
	_update_ui()

func _send_customer_to_table(data: Dictionary, order: Array) -> void:
	var table_index := (served_today - 1) % table_positions.size()

	if seated_guests.size() >= table_positions.size():
		var old = seated_guests.pop_front()
		if is_instance_valid(old):
			old.queue_free()

	var diner := Node3D.new()
	diner.name = "SeatedGuest"
	diner.position = current_customer_root.global_position
	add_child(diner)
	_build_animal(diner, data, 0.70)

	var target = table_positions[table_index]
	var tween := create_tween()
	tween.tween_property(diner, "position", target, 0.75).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	var timer := get_tree().create_timer(0.78)
	await timer.timeout

	_add_table_food(diner, order)
	seated_guests.append(diner)

func _add_table_food(diner: Node3D, order: Array) -> void:
	var base := Node3D.new()
	base.position = Vector3(0, 0.95, -0.45)
	diner.add_child(base)

	var offset := -0.28
	for item in order:
		match item:
			"burger":
				_make_small_burger(base, Vector3(offset, 0, 0))
			"fries":
				_make_small_fries(base, Vector3(offset, 0, 0))
			"soda":
				_make_small_soda(base, Vector3(offset, 0, 0))
		offset += 0.28

func _finish_day() -> void:
	var bonus := 7 + hearts
	coins += bonus
	day += 1
	served_today = 0
	target_today = min(target_today + 1, 9)

	_show_status("День завершён! Бонус +%d монет. Начинается день %d." % [bonus, day])

	var timer := get_tree().create_timer(0.75)
	await timer.timeout

	for guest in seated_guests:
		if is_instance_valid(guest):
			guest.queue_free()
	seated_guests.clear()

	_call_next_customer()

func _new_order() -> void:
	order_number += 1
	current_order = recipes[randi() % recipes.size()].duplicate()
	_refresh_order_bubble()
	_update_register_screen()
	_update_ui()

func _refresh_order_bubble() -> void:
	if not current_order_label:
		return

	var parts = []
	for item in current_order:
		parts.append(pretty[item])

	current_order_label.text = "Хочу:\n" + " + ".join(parts)

func _update_register_screen() -> void:
	if not register_screen:
		return

	var parts = []
	for item in current_order:
		parts.append(pretty[item])

	register_screen.text = "ЗАКАЗ\n" + " + ".join(parts)

func _happy_customer() -> void:
	if not current_customer_root:
		return

	var base = current_customer_root.position
	var tween := create_tween()
	tween.tween_property(current_customer_root, "position:y", base.y + 0.22, 0.12)
	tween.tween_property(current_customer_root, "position:y", base.y, 0.12)
	tween.tween_property(current_customer_root, "position:y", base.y + 0.12, 0.10)
	tween.tween_property(current_customer_root, "position:y", base.y, 0.10)

func _sync_held_visual() -> void:
	if not player or not player.has_method("set_held_item"):
		return

	if held_item == "":
		player.set_held_item("", "", Color.WHITE)
	else:
		player.set_held_item(
			held_item,
			pretty[held_item],
			colors.get(held_item, Color.WHITE)
		)

func _show_grill_patty(color: Color) -> void:
	_clear_grill_visual()
	var patty := _cylinder(grill_visual, Vector3(0, 0.09, 0), 0.20, 0.07, color, 90)
	patty.name = "Patty"

func _clear_grill_visual() -> void:
	for child in grill_visual.get_children():
		if child.name == "Patty":
			child.queue_free()

func _add_assembly_layer(item_id: String, index: int) -> void:
	var y = index * 0.078

	match item_id:
		"bun_bottom":
			_cylinder(assembly_visual, Vector3(0, y, 0), 0.22, 0.075, colors[item_id], 90)
		"cooked_patty":
			_cylinder(assembly_visual, Vector3(0, y, 0), 0.19, 0.055, colors[item_id], 90)
		"cheese":
			var cheese = _box(assembly_visual, "Layer", Vector3(0, y, 0), Vector3(0.40, 0.028, 0.40), colors[item_id], false)
			cheese.rotation_degrees.y = 12
		"lettuce":
			var leaf = _cylinder(assembly_visual, Vector3(0, y, 0), 0.21, 0.035, colors[item_id], 90)
			leaf.scale = Vector3(1.12, 1.0, 0.82)
			leaf.rotation_degrees.y = 18
		"tomato":
			_cylinder(assembly_visual, Vector3(0, y, 0), 0.17, 0.032, colors[item_id], 90)
		"bun_top":
			var m = _sphere(assembly_visual, Vector3(0, y + 0.05, 0), 0.21, colors[item_id])
			m.scale = Vector3(1.02, 0.52, 1.02)
			for i in range(6):
				_sphere(assembly_visual, Vector3(randf_range(-0.08, 0.08), y + 0.11, randf_range(-0.08, 0.08)), 0.012, Color("#fff0da"))

func _clear_assembly_visual() -> void:
	for child in assembly_visual.get_children():
		child.queue_free()

func _clear_tray_food() -> void:
	for child in tray_visual.get_children():
		if child.name != "TrayBase":
			child.queue_free()

func _refresh_tray_visual() -> void:
	_clear_tray_food()

	var slot_positions = [
		Vector3(-0.45, 0.17, 0),
		Vector3(0.00, 0.17, 0),
		Vector3(0.45, 0.17, 0)
	]

	for i in range(tray.size()):
		if i >= slot_positions.size():
			break

		var item = tray[i]
		var pos = slot_positions[i]

		match item:
			"burger":
				_make_tray_burger(pos)
			"fries":
				_make_tray_fries(pos)
			"soda":
				_make_tray_soda(pos)

func _make_tray_burger(pos: Vector3) -> void:
	var root := Node3D.new()
	root.name = "FoodBurger"
	root.position = pos
	tray_visual.add_child(root)
	_make_small_burger(root, Vector3.ZERO)

func _make_tray_fries(pos: Vector3) -> void:
	var root := Node3D.new()
	root.name = "FoodFries"
	root.position = pos
	tray_visual.add_child(root)
	_make_small_fries(root, Vector3.ZERO)

func _make_tray_soda(pos: Vector3) -> void:
	var root := Node3D.new()
	root.name = "FoodSoda"
	root.position = pos
	tray_visual.add_child(root)
	_make_small_soda(root, Vector3.ZERO)

func _make_small_burger(parent: Node3D, pos: Vector3) -> void:
	var root := Node3D.new()
	root.position = pos
	parent.add_child(root)

	_cylinder(root, Vector3(0, 0.00, 0), 0.17, 0.055, colors["bun_bottom"], 90)
	_cylinder(root, Vector3(0, 0.055, 0), 0.16, 0.045, colors["cooked_patty"], 90)
	var cheese = _box(root, "Cheese", Vector3(0, 0.090, 0), Vector3(0.32, 0.022, 0.32), colors["cheese"], false)
	cheese.rotation_degrees.y = 14
	var leaf = _cylinder(root, Vector3(0, 0.118, 0), 0.18, 0.028, colors["lettuce"], 90)
	leaf.scale = Vector3(1.08, 1.0, 0.84)
	_cylinder(root, Vector3(0, 0.148, 0), 0.145, 0.026, colors["tomato"], 90)

	var top = _sphere(root, Vector3(0, 0.205, 0), 0.17, colors["bun_top"])
	top.scale = Vector3(1.0, 0.52, 1.0)
	for i in range(5):
		_sphere(root, Vector3(randf_range(-0.07, 0.07), 0.24, randf_range(-0.07, 0.07)), 0.010, Color("#fff0da"))

func _make_small_fries(parent: Node3D, pos: Vector3) -> void:
	var root := Node3D.new()
	root.position = pos
	parent.add_child(root)

	_box(root, "Carton", Vector3(0, 0.03, 0), Vector3(0.28, 0.28, 0.22), Color("#df6f83"), false)

	for i in range(7):
		var x = -0.105 + (i % 4) * 0.07
		var z = -0.045 + int(i / 4) * 0.09
		var fry = _box(root, "Fry", Vector3(x, 0.23, z), Vector3(0.04, 0.28, 0.04), colors["fries"], false)
		fry.rotation_degrees.z = -8 + i * 4

func _make_small_soda(parent: Node3D, pos: Vector3) -> void:
	var root := Node3D.new()
	root.position = pos
	parent.add_child(root)

	_cylinder(root, Vector3(0, 0.05, 0), 0.115, 0.32, Color("#ffe8ef"))
	_box(root, "Stripe", Vector3(0, 0.05, -0.116), Vector3(0.14, 0.25, 0.02), Color("#ef9fb6"), false)
	_box(root, "Straw", Vector3(0.035, 0.34, 0), Vector3(0.025, 0.38, 0.025), Color("#df6f93"), false)

func _bounce_node(node: Node3D) -> void:
	var base = node.position
	var tween := create_tween()
	tween.tween_property(node, "position:y", base.y + 0.08, 0.12)
	tween.tween_property(node, "position:y", base.y, 0.12)
	tween.set_loops(4)

func _update_ui() -> void:
	if not order_label or not order_items_label:
		return

	var order_names = []
	for item in current_order:
		order_names.append(pretty[item])

	var tray_names = []
	for item in tray:
		tray_names.append(pretty[item])

	var stack_names = []
	for item in burger_stack:
		stack_names.append(pretty[item])

	var customer_name = current_customer.get("name", "Гость")

	day_label.text = "ДЕНЬ %d    %d / %d" % [day, served_today, target_today]
	order_label.text = customer_name
	order_items_label.text = " + ".join(order_names) if not order_names.is_empty() else "—"
	tray_label.text = "Поднос: " + ("пусто" if tray_names.is_empty() else " + ".join(tray_names))
	held_label.text = "В лапках: " + ("—" if held_item == "" else pretty[held_item])
	stack_label.text = "Бургер: " + ("не начат" if stack_names.is_empty() else " → ".join(stack_names))
	money_label.text = "● %d монет   ♥ %d" % [coins, hearts]

	if queue_label:
		queue_label.text = "В очереди: %d" % queue_data.size()

func _show_status(text: String) -> void:
	if not status_label or not status_panel:
		return

	status_label.text = text
	status_panel.visible = true
	status_panel.modulate.a = 1.0

	if status_hide_timer:
		status_hide_timer.start()

func _set_grill_indicator(active: bool) -> void:
	if grill_indicator and grill_indicator.material_override:
		grill_indicator.material_override.albedo_color = Color("#ff8a3d") if active else Color("#5a5a5a")
	elif grill_indicator:
		grill_indicator.material_override = _mat(Color("#ff8a3d") if active else Color("#5a5a5a"))
