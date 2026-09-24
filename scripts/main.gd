extends Node3D

const PLAYER_SCRIPT = preload("res://scripts/player.gd")
const STATION_SCRIPT = preload("res://scripts/station.gd")
const FOOD_VISUALS = preload("res://scripts/food_visuals.gd")

# Освещение кафе — меняй здесь для быстрой настройки cozy-атмосферы.
const SUN_ENERGY := 0.45
const WARM_LIGHT_ENERGY := 0.8
const WARM_LIGHT_RANGE := 8.0
const WARM_LIGHT_COLOR := Color("#ffd9bf")
const AMBIENT_ENERGY := 0.28
const AMBIENT_COLOR := Color("#fff0e1")
const ENV_BACKGROUND_COLOR := Color("#bde5cd")
const TONEMAP_EXPOSURE := 1.0
const GAME_VERSION := "0.0.05"
const PROMPT_BG := Color("#fff7f2", 0.48)

const BURGER_COUNTER_SURFACE_Y := 1.12
const INGREDIENT_RISER_H := 0.10
const INGREDIENT_STATION_Y := 1.30
const GRILL_STATION_Y := 1.20
const ASSEMBLY_STATION_Y := 1.18
const HUD_FONT_SIZE := 14
const HUD_PANEL_BG := Color("#fff7f2", 0.58)
const HUD_PANEL_BG_SOFT := Color("#fff7f2", 0.42)
const HUD_TEXT_DARK := Color("#40363d")
const HUD_TEXT_MUTED := Color("#6b5d68", 0.88)
const FPS_TEXT_COLOR := Color("#171417", 0.68)

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
var interaction_prompt_panel: PanelContainer
var interaction_prompt_action_label: Label
var _prompt_fade := 0.0
var _prompt_target := 0.0
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
	"raw_patty": Color("#c45a4a"),
	"cooked_patty": Color("#744936"),
	"cheese": Color("#f5d070"),
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

func _process(delta: float) -> void:
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

	_prompt_fade = move_toward(_prompt_fade, _prompt_target, delta * 6.0)
	if interaction_prompt_panel:
		interaction_prompt_panel.modulate.a = _prompt_fade
		interaction_prompt_panel.visible = _prompt_fade > 0.02

	if debug_info_label:
		debug_info_label.text = "%d FPS  •  v%s" % [
			Engine.get_frames_per_second(),
			GAME_VERSION
		]

func _mat(color: Color, kind: String = "food") -> StandardMaterial3D:
	match kind:
		"metal":
			return FOOD_VISUALS.metal(color)
		"plastic":
			return FOOD_VISUALS.plastic(color)
		"wood":
			return FOOD_VISUALS.wood(color)
		"ceramic":
			return FOOD_VISUALS.ceramic(color)
		"fabric":
			return FOOD_VISUALS.fabric(color)
		_:
			return FOOD_VISUALS.food(color)

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

func _stylebox_panel(bg_alpha := 0.82, radius := 10, bg_color: Color = Color(0.19, 0.14, 0.2, bg_alpha)) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = bg_color if bg_color.a > 0.0 else Color(0.19, 0.14, 0.2, bg_alpha)
	box.corner_radius_top_left = radius
	box.corner_radius_top_right = radius
	box.corner_radius_bottom_left = radius
	box.corner_radius_bottom_right = radius
	box.content_margin_left = 12
	box.content_margin_top = 8
	box.content_margin_right = 12
	box.content_margin_bottom = 8
	return box

func _stylebox_hud_panel(alpha := 0.58, radius := 12) -> StyleBoxFlat:
	return _stylebox_panel(alpha, radius, HUD_PANEL_BG if alpha >= 0.5 else HUD_PANEL_BG_SOFT)

func _build_ui_theme() -> Theme:
	var theme := Theme.new()
	theme.default_font = font_regular
	theme.set_font("font", "Label", font_regular)
	theme.set_font_size("font_size", "Label", UI_FONT_BODY)
	theme.set_color("font_color", "Label", COLOR_TEXT_LIGHT)
	theme.set_stylebox("panel", "PanelContainer", _stylebox_panel())
	return theme

func _hud_label(parent: Node, color: Color, use_font: Font = null, semibold := false) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", HUD_FONT_SIZE)
	label.add_theme_color_override("font_color", color)
	var chosen := use_font if use_font else (font_semibold if semibold else font_regular)
	if chosen:
		label.add_theme_font_override("font", chosen)
	parent.add_child(label)
	return label

func _label3d_sign(parent: Node, text: String, pos: Vector3, font_size: int, color: Color, rot_y := 0.0) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.position = pos
	label.font_size = font_size
	label.modulate = color
	label.outline_size = 2
	label.outline_modulate = Color("#fff7ee")
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	label.rotation_degrees.y = rot_y
	label.font = font_bold if font_size >= WORLD_FONT_TITLE else font_semibold
	parent.add_child(label)
	return label

func _build_cafe_shell(world: Node3D) -> void:
	var cream := Color("#fff0da")
	var pink := Color("#f4b6c7")
	var pink_dark := Color("#e98fa9")
	var wood := Color("#b87958")

	_box(world, "Floor", Vector3(0, -0.2, 0), Vector3(12, 0.4, 10), cream)

	var tiles := Node3D.new()
	tiles.name = "FloorTiles"
	world.add_child(tiles)
	for ix in range(12):
		for iz in range(10):
			var tile_color := cream if (ix + iz) % 2 == 0 else pink
			_box(
				tiles,
				"Tile",
				Vector3(-5.5 + ix, 0.02, -4.5 + iz),
				Vector3(0.98, 0.03, 0.98),
				tile_color,
				false
			)

	_box(world, "BackWall", Vector3(0, 2.2, 4.9), Vector3(12, 4.8, 0.25), cream)
	_box(world, "LeftWall", Vector3(-5.9, 2.2, 0), Vector3(0.25, 4.8, 10), Color("#fff7f2"))
	_box(world, "RightWall", Vector3(5.9, 2.2, 0), Vector3(0.25, 4.8, 10), Color("#f4fbef"))

	var wainscot := Node3D.new()
	wainscot.name = "Wainscot"
	world.add_child(wainscot)
	_box(wainscot, "BackWainscot", Vector3(0, 0.55, 4.78), Vector3(12, 1.1, 0.12), pink, false)
	_box(wainscot, "LeftWainscot", Vector3(-5.78, 0.55, 0), Vector3(0.12, 1.1, 10), pink_dark, false)
	_box(wainscot, "RightWainscot", Vector3(5.78, 0.55, 0), Vector3(0.12, 1.1, 10), Color("#7fbe71", 0.35), false)
	_box(wainscot, "BackBorder", Vector3(0, 1.12, 4.76), Vector3(12, 0.06, 0.14), pink_dark, false)
	_box(wainscot, "LeftBorder", Vector3(-5.76, 1.12, 0), Vector3(0.14, 0.06, 10), pink_dark, false)
	_box(wainscot, "RightBorder", Vector3(5.76, 1.12, 0), Vector3(0.14, 0.06, 10), Color("#7fbe71"), false)

	_box(world, "Ceiling", Vector3(0, 4.55, 0), Vector3(12, 0.12, 10), cream, false)
	_box(world, "CeilingTrim", Vector3(0, 4.48, 0), Vector3(11.6, 0.04, 9.6), wood, false)

func _build_checkout_area(world: Node3D) -> void:
	var pink := Color("#e98fa9")
	var pink_light := Color("#f4b6c7")
	var cream := Color("#fff0da")
	var metal := Color("#8a8586")

	_box(world, "FrontCounter", Vector3(0, 0.50, -1.8), Vector3(8.6, 1.0, 0.75), pink)
	_box(world, "CounterTop", Vector3(0, 1.01, -1.8), Vector3(8.8, 0.18, 0.95), cream)

	for x in [-3.6, -1.8, 0.0, 1.8, 3.6]:
		_box(world, "CounterPanel", Vector3(x, 0.50, -2.18), Vector3(0.55, 0.85, 0.06), pink_light, false)
		_box(world, "CounterPanelTrim", Vector3(x, 0.76, -2.19), Vector3(0.58, 0.05, 0.05), cream, false)

	var register_root := Node3D.new()
	register_root.name = "Register"
	register_root.position = Vector3(-2.55, 1.08, -1.78)
	world.add_child(register_root)

	_box(register_root, "RegisterBody", Vector3(0, 0, 0), Vector3(1.05, 0.75, 0.60), pink_light, false)
	_box(register_root, "RegisterScreen", Vector3(0, 0.13, -0.34), Vector3(0.78, 0.42, 0.08), cream, false)
	_box(register_root, "RegisterBase", Vector3(0, -0.42, 0.05), Vector3(1.15, 0.08, 0.68), pink, false)

	register_screen = Label3D.new()
	register_screen.position = Vector3(0, 0.13, -0.40)
	register_screen.font_size = WORLD_FONT_BODY
	register_screen.font = font_semibold
	register_screen.modulate = COLOR_TEXT_PRIMARY
	register_screen.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	register_root.add_child(register_screen)

	var pos_screen := Node3D.new()
	pos_screen.name = "PosMenuScreen"
	pos_screen.position = Vector3(0.05, 0.28, -0.36)
	register_root.add_child(pos_screen)
	_box(pos_screen, "ScreenBezel", Vector3(0, 0, 0), Vector3(0.62, 0.34, 0.04), metal, false)
	FOOD_VISUALS.create_pos_icon_burger(pos_screen, Vector3(-0.16, 0.02, -0.03))
	FOOD_VISUALS.create_pos_icon_fries(pos_screen, Vector3(0.0, 0.0, -0.03))
	FOOD_VISUALS.create_pos_icon_drink(pos_screen, Vector3(0.16, 0.0, -0.03))

	_box(register_root, "CardTerminal", Vector3(0.72, -0.12, -0.12), Vector3(0.34, 0.18, 0.42), Color("#c8dbea"), false)
	_box(register_root, "CardSlot", Vector3(0.72, -0.04, -0.28), Vector3(0.22, 0.04, 0.06), metal, false)

	_box(register_root, "ReceiptPrinter", Vector3(-0.72, -0.08, -0.10), Vector3(0.38, 0.14, 0.32), cream, false)
	_box(register_root, "ReceiptPaper", Vector3(-0.72, 0.02, -0.24), Vector3(0.18, 0.02, 0.14), Color("#ffffff"), false)

	var bell := Node3D.new()
	bell.name = "ServiceBell"
	bell.position = Vector3(-1.55, 1.06, -1.72)
	world.add_child(bell)
	_cylinder(bell, Vector3(0, 0.04, 0), 0.10, 0.06, metal)
	_cylinder(bell, Vector3(0, 0.10, 0), 0.07, 0.05, Color("#f5d070"))
	_sphere(bell, Vector3(0, 0.16, 0), 0.035, Color("#f5d070"))

	_label3d_sign(world, "БУЛОЧКА", Vector3(0, 3.62, 4.54), WORLD_FONT_LOGO, COLOR_TEXT_PRIMARY, 180.0)
	_label3d_sign(world, "COZY FAST FOOD", Vector3(0, 3.18, 4.54), WORLD_FONT_SMALL, COLOR_TEXT_SECONDARY, 180.0)

	_box(world, "CounterSign", Vector3(-3.9, 1.85, -2.05), Vector3(0.55, 0.35, 0.06), cream, false)
	_label3d_sign(world, "OPEN", Vector3(-3.9, 1.85, -2.14), 14, Color("#6b5060"), 0.0)

func _build_service_area(world: Node3D) -> void:
	var pink := Color("#e98fa9")
	var pink_light := Color("#f4b6c7")
	var cream := Color("#fff0da")

	var serve = _station(
		world,
		"Serve",
		Vector3(0, 1.12, -1.8),
		Vector3(2.0, 0.22, 0.72),
		cream,
		"serve",
		"Выдать заказ",
		"",
		true
	)

	tray_visual = Node3D.new()
	tray_visual.name = "TrayVisual"
	tray_visual.position = Vector3(0, 0.08, 0)
	serve.add_child(tray_visual)

	_box(tray_visual, "TrayRim", Vector3(0, 0.04, 0), Vector3(1.52, 0.05, 0.62), pink, false)
	_box(tray_visual, "TrayBase", Vector3(0, 0, 0), Vector3(1.38, 0.06, 0.52), pink_light, false)
	_box(tray_visual, "TrayInset", Vector3(0, 0.01, 0), Vector3(1.22, 0.03, 0.44), cream, false)

func _build_ingredient_bin(parent: Node, name: String, pos: Vector3, item_id: String, display_name: String, use_riser := false) -> StaticBody3D:
	if use_riser:
		_box(
			parent,
			name + "Riser",
			Vector3(pos.x, BURGER_COUNTER_SURFACE_Y + INGREDIENT_RISER_H * 0.5, pos.z),
			Vector3(0.66, INGREDIENT_RISER_H, 0.66),
			Color("#fff0da"),
			false
		)

	var station := _station(
		parent,
		name,
		pos,
		Vector3(0.58, 0.18, 0.58),
		colors[item_id],
		"ingredient",
		display_name,
		item_id
	)
	_box(station, "BinRim", Vector3(0, 0.0, 0), Vector3(0.68, 0.08, 0.68), Color("#e98fa9"), false)
	_box(station, "BinInner", Vector3(0, 0.03, 0), Vector3(0.54, 0.05, 0.54), Color("#fff0da"), false)
	FOOD_VISUALS.populate_bin(station, item_id)
	return station

func _build_grill_details(grill_station: StaticBody3D) -> void:
	var metal := Color("#8a8586")
	var metal_dark := Color("#5a5859")

	_box(grill_station, "GrillBody", Vector3(0, -0.05, 0), Vector3(1.05, 0.35, 0.88), metal, false)
	_box(grill_station, "GrillBack", Vector3(0, 0.22, 0.38), Vector3(0.95, 0.28, 0.08), metal_dark, false)
	_box(grill_station, "GrillKnobL", Vector3(-0.38, 0.08, -0.38), Vector3(0.08, 0.08, 0.08), Color("#f4b6c7"), false)
	_box(grill_station, "GrillKnobR", Vector3(0.38, 0.08, -0.38), Vector3(0.08, 0.08, 0.08), Color("#f4b6c7"), false)

	grill_visual = Node3D.new()
	grill_visual.position = Vector3(0, 0.18, 0)
	grill_station.add_child(grill_visual)

	_box(grill_visual, "GrillSurface", Vector3(0, 0.02, 0), Vector3(0.82, 0.04, 0.62), Color("#2f3035"), false)
	for x in [-0.30, -0.10, 0.10, 0.30]:
		_box(grill_visual, "GrillLine", Vector3(x, 0, 0), Vector3(0.025, 0.035, 0.64), Color("#1f2024"), false)
	for i in range(2):
		_cylinder(grill_station, Vector3(-0.22 + i * 0.44, 0.18, -0.38), 0.05, 0.05, metal)
	grill_indicator = _sphere(grill_station, Vector3(0.34, 0.22, -0.38), 0.035, Color("#5a5a5a"))

func _build_kitchen_line(world: Node3D) -> void:
	var cream := Color("#fff0da")
	var pink := Color("#e98fa9")
	var pink_light := Color("#f4b6c7")
	var wood := Color("#b87958")
	var green := Color("#7fbe71")
	var metal := Color("#8a8586")

	_box(world, "PrepCounterBody", Vector3(3.75, 0.55, 0.35), Vector3(3.8, 1.1, 1.55), wood)
	_box(world, "PrepCounterTop", Vector3(3.75, 1.12, 0.35), Vector3(3.9, 0.08, 1.62), cream, false)
	_box(world, "PrepBacksplash", Vector3(3.75, 1.35, 1.05), Vector3(3.8, 0.42, 0.08), pink_light, false)
	_box(world, "PrepBacksplashTile", Vector3(3.75, 1.35, 1.01), Vector3(3.7, 0.34, 0.04), cream, false)

	_build_ingredient_bin(
		world, "BunBottom", Vector3(2.4, INGREDIENT_STATION_Y, -0.15), "bun_bottom", "Нижняя булочка", true
	)
	_build_ingredient_bin(
		world, "BunTop", Vector3(2.4, INGREDIENT_STATION_Y, 0.45), "bun_top", "Верхняя булочка", true
	)
	_build_ingredient_bin(
		world, "Cheese", Vector3(4.0, INGREDIENT_STATION_Y, -0.25), "cheese", "Сыр", true
	)
	_build_ingredient_bin(
		world, "Lettuce", Vector3(4.0, INGREDIENT_STATION_Y, 0.15), "lettuce", "Салат", true
	)
	_build_ingredient_bin(
		world, "Tomato", Vector3(4.0, INGREDIENT_STATION_Y, 0.55), "tomato", "Помидор", true
	)
	_build_ingredient_bin(
		world, "RawPatty", Vector3(4.8, GRILL_STATION_Y, -0.05), "raw_patty", "Сырая котлета"
	)

	var assembly_station = _station(
		world, "Assembly", Vector3(3.2, ASSEMBLY_STATION_Y, 0.15),
		Vector3(0.95, 0.22, 0.82), cream, "assemble", "Сборка бургера", "", true
	)
	_box(assembly_station, "BoardFrame", Vector3(0, 0.0, 0), Vector3(0.98, 0.06, 0.78), wood, false)
	_box(assembly_station, "AssemblyBoard", Vector3(0, 0.04, 0), Vector3(0.92, 0.04, 0.72), cream, false)
	_box(assembly_station, "BoardHandle", Vector3(0.42, 0.04, 0.0), Vector3(0.08, 0.05, 0.22), wood, false)
	_box(assembly_station, "BoardGroove", Vector3(0, 0.06, 0), Vector3(0.78, 0.012, 0.58), Color("#f4b6c7", 0.55), false)
	assembly_visual = Node3D.new()
	assembly_visual.position = Vector3(0, 0.18, 0)
	assembly_station.add_child(assembly_visual)

	var grill_station = _station(
		world, "Grill", Vector3(4.8, GRILL_STATION_Y, 0.55),
		Vector3(0.95, 0.25, 0.82), metal, "grill", "Гриль", "", true
	)
	_build_grill_details(grill_station)

	var fryer_station = _station(
		world, "Fryer", Vector3(2.6, 0.93, 1.15),
		Vector3(1.5, 0.4, 1.0), metal, "fries", "Фритюрница", "", true
	)
	_box(fryer_station, "FryerBody", Vector3(0, -0.08, 0), Vector3(1.55, 0.55, 1.05), Color("#9aa0a8"), false)
	_box(fryer_station, "FryerPanel", Vector3(0, 0.05, -0.48), Vector3(0.55, 0.18, 0.08), Color("#7a8088"), false)
	_box(fryer_station, "FryerOilWindow", Vector3(0, -0.02, 0.18), Vector3(0.42, 0.22, 0.06), Color("#f5d070", 0.65), false)
	for i in range(2):
		_box(fryer_station, "FryerBtn", Vector3(-0.12 + i * 0.24, 0.05, -0.53), Vector3(0.10, 0.08, 0.04), pink_light if i == 0 else cream, false)
	fryer_visual = Node3D.new()
	fryer_visual.position = Vector3(0, 0.26, 0)
	fryer_station.add_child(fryer_visual)
	_box(fryer_visual, "Basket", Vector3(0, 0, 0), Vector3(0.72, 0.18, 0.62), metal, false)
	_box(fryer_visual, "BasketHandle", Vector3(0, 0.18, -0.22), Vector3(0.45, 0.05, 0.06), Color("#5a5e64"), false)
	for i in range(8):
		var fx = -0.28 + (i % 4) * 0.18
		var fz = -0.16 + int(i / 4) * 0.30
		var fry = _box(fryer_visual, "Fry", Vector3(fx, 0.15, fz), Vector3(0.08, 0.30, 0.08), Color("#f5cf57"), false)
		fry.rotation_degrees.z = 8 + i * 5

	var soda_station = _station(
		world, "Soda", Vector3(5.1, 1.38, 0.35),
		Vector3(1.4, 1.7, 0.8), Color("#94d7df"), "soda", "Автомат напитков", "", true
	)
	_box(soda_station, "SodaBody", Vector3(0, -0.05, 0), Vector3(1.25, 1.55, 0.72), pink_light, false)
	_box(soda_station, "SodaScreen", Vector3(0, 0.35, -0.35), Vector3(0.75, 0.45, 0.08), cream, false)
	_box(soda_station, "SodaDripTray", Vector3(0, -0.55, -0.35), Vector3(0.55, 0.08, 0.35), metal, false)
	for i in range(3):
		_box(soda_station, "SodaBtn", Vector3(-0.28 + i * 0.28, 0.05, -0.42), Vector3(0.16, 0.16, 0.06), [pink_light, cream, green][i], false)
	_box(soda_station, "SodaNozzle", Vector3(0, -0.15, -0.42), Vector3(0.10, 0.12, 0.10), Color("#7ab8c0"), false)
	soda_visual = Node3D.new()
	soda_visual.position = Vector3(0, -0.55, -0.47)
	soda_station.add_child(soda_visual)
	FOOD_VISUALS.create_drink(soda_visual, Vector3.ZERO, 0.55, false)

	var trash_station = _station(
		world, "Trash", Vector3(5.0, 0.65, 1.05),
		Vector3(0.9, 1.2, 0.9), green, "trash", "Мусор", "", true
	)
	_box(trash_station, "TrashBody", Vector3(0, -0.05, 0), Vector3(0.75, 1.0, 0.75), Color("#7fbe71"), false)
	_box(trash_station, "TrashLid", Vector3(0, 0.58, 0), Vector3(0.82, 0.08, 0.82), Color("#6aab5f"), false)
	_box(trash_station, "TrashSlot", Vector3(0, 0.52, -0.28), Vector3(0.35, 0.06, 0.12), Color("#4a5a52"), false)

	var sauces := Node3D.new()
	sauces.name = "SauceBottles"
	sauces.position = Vector3(2.15, 1.12, 0.85)
	world.add_child(sauces)
	var sauce_colors = [Color("#e96161"), Color("#f5d070"), Color("#8dcf72")]
	for i in range(3):
		_cylinder(sauces, Vector3(-0.18 + i * 0.18, 0.08, 0), 0.035, 0.16, sauce_colors[i])
		_box(sauces, "Cap", Vector3(-0.18 + i * 0.18, 0.18, 0), Vector3(0.05, 0.04, 0.05), cream, false)

	var display_case := Node3D.new()
	display_case.name = "DisplayCase"
	display_case.position = Vector3(3.0, 1.05, 1.05)
	world.add_child(display_case)
	_box(display_case, "CaseBase", Vector3(0, 0, 0), Vector3(1.35, 0.08, 0.55), wood, false)
	_box(display_case, "CaseGlass", Vector3(0, 0.22, 0), Vector3(1.25, 0.38, 0.48), Color("#cce8f4", 0.35), false)
	_box(display_case, "CaseFrameL", Vector3(-0.62, 0.22, 0), Vector3(0.04, 0.40, 0.52), metal, false)
	_box(display_case, "CaseFrameR", Vector3(0.62, 0.22, 0), Vector3(0.04, 0.40, 0.52), metal, false)
	for i in range(3):
		FOOD_VISUALS.create_display_burger(display_case, Vector3(-0.32 + i * 0.32, 0.18, 0), 0.62)

func _build_dining_area(world: Node3D) -> void:
	var cream := Color("#fff0da")
	var wood := Color("#b87958")
	var pink := Color("#e98fa9")
	var pink_light := Color("#f4b6c7")
	var green := Color("#7fbe71")

	var table_xs = [-3.15, 0.0, 3.15, -5.2]
	for x in table_xs:
		var z := -3.9 if x != -5.2 else -2.2
		_box(world, "DiningTable", Vector3(x, 0.72, z), Vector3(1.65, 0.12, 1.15), cream)
		_box(world, "DiningLegFL", Vector3(x - 0.62, 0.34, z + 0.45), Vector3(0.12, 0.70, 0.12), wood, false)
		_box(world, "DiningLegFR", Vector3(x + 0.62, 0.34, z + 0.45), Vector3(0.12, 0.70, 0.12), wood, false)
		_box(world, "DiningLegBL", Vector3(x - 0.62, 0.34, z - 0.45), Vector3(0.12, 0.70, 0.12), wood, false)
		_box(world, "DiningLegBR", Vector3(x + 0.62, 0.34, z - 0.45), Vector3(0.12, 0.70, 0.12), wood, false)
		_box(world, "ChairFront", Vector3(x, 0.42, z - 0.75), Vector3(0.75, 0.75, 0.75), pink, false)
		_box(world, "ChairBack", Vector3(x, 0.55, z + 0.55), Vector3(0.75, 0.45, 0.12), pink_light, false)
		_box(world, "ChairSide", Vector3(x + 0.85, 0.42, z), Vector3(0.65, 0.75, 0.65), pink_light, false)
		_sphere(world, Vector3(x - 0.35, 0.84, z - 0.15), 0.08, green)
		_cylinder(world, Vector3(x - 0.35, 0.78, z - 0.15), 0.04, 0.06, wood)

func _build_windows_and_entrance(world: Node3D) -> void:
	var wood := Color("#b87958")
	var cream := Color("#fff0da")
	var pink := Color("#f4b6c7")
	var sky := Color("#87ceeb")
	var green := Color("#7fbe71")

	var facade := Node3D.new()
	facade.name = "FrontFacade"
	world.add_child(facade)

	_box(facade, "DoorFrame", Vector3(5.72, 1.35, -1.2), Vector3(0.14, 2.7, 1.35), wood, false)
	_box(facade, "DoorPanel", Vector3(5.68, 1.2, -1.2), Vector3(0.08, 2.35, 1.15), cream, false)
	_box(facade, "DoorHandle", Vector3(5.64, 1.05, -0.75), Vector3(0.06, 0.12, 0.22), wood, false)
	_box(facade, "DoorWindow", Vector3(5.66, 1.85, -1.2), Vector3(0.06, 0.55, 0.55), Color("#d8eef8"), false)
	FOOD_VISUALS.add_bunny_logo(facade, Vector3(5.64, 1.45, -1.05), 1.4)

	for z_pos in [1.8, -0.2, -2.2]:
		_box(facade, "WindowFrame", Vector3(5.72, 2.05, z_pos), Vector3(0.14, 1.5, 1.6), wood, false)
		_box(facade, "WindowGlass", Vector3(5.66, 2.05, z_pos), Vector3(0.06, 1.25, 1.35), Color("#cce8f4", 0.55), false)
		_box(facade, "WindowSill", Vector3(5.62, 1.25, z_pos), Vector3(0.18, 0.08, 1.45), cream, false)
		var awning := Node3D.new()
		awning.position = Vector3(5.58, 2.85, z_pos)
		facade.add_child(awning)
		_box(awning, "Awning", Vector3(0, 0, 0), Vector3(0.22, 0.08, 1.55), pink, false)
		for i in range(5):
			_box(awning, "AwningStripe", Vector3(0, -0.05, -0.62 + i * 0.31), Vector3(0.24, 0.04, 0.08), cream, false)

	var backdrop := Node3D.new()
	backdrop.name = "OutdoorBackdrop"
	backdrop.position = Vector3(6.35, 1.8, 0)
	facade.add_child(backdrop)
	_box(backdrop, "SkyPanel", Vector3(0, 1.2, 0), Vector3(0.08, 3.2, 8.5), sky, false)
	for i in range(6):
		var leaf := _sphere(backdrop, Vector3(0.06, -0.4 + (i % 3) * 0.9, -3.2 + i * 1.3), 0.35 + (i % 2) * 0.12, green)
		leaf.scale = Vector3(1.2, 0.85, 1.0)

func _build_plants_and_shelves(world: Node3D) -> void:
	var cream := Color("#fff0da")
	var wood := Color("#b87958")
	var pink := Color("#f4b6c7")
	var green := Color("#7fbe71")

	for sx in [-4.8, 2.4]:
		_box(world, "KitchenShelf", Vector3(sx, 2.15, 4.65), Vector3(1.4, 0.08, 0.35), wood, false)
		_cylinder(world, Vector3(sx - 0.25, 2.28, 4.65), 0.06, 0.10, cream)
		_cylinder(world, Vector3(sx + 0.25, 2.28, 4.65), 0.05, 0.14, pink)
		_sphere(world, Vector3(sx, 2.42, 4.65), 0.14, green)

	_box(world, "WallShelfL", Vector3(-5.55, 1.85, 3.2), Vector3(0.35, 0.08, 1.2), wood, false)
	_box(world, "WallShelfR", Vector3(5.55, 1.85, -1.5), Vector3(0.35, 0.08, 1.0), wood, false)
	for i in range(4):
		_cylinder(world, Vector3(5.45, 1.55 + i * 0.08, -1.2 + i * 0.15), 0.04, 0.10, pink)

	var hanging := Node3D.new()
	hanging.name = "HangingPlants"
	world.add_child(hanging)
	for x in [-2.5, 1.0, 3.5]:
		_cylinder(hanging, Vector3(x, 4.25, 2.0), 0.08, 0.12, wood)
		_sphere(hanging, Vector3(x, 4.05, 2.0), 0.18, green)
		_cylinder(hanging, Vector3(x + 0.08, 3.85, 2.05), 0.015, 0.35, green)

	for x in [-4.7, 4.7]:
		_box(world, "PlantPot", Vector3(x, 0.38, -4.15), Vector3(0.65, 0.55, 0.65), wood, false)
		_sphere(world, Vector3(x, 0.95, -4.15), 0.48, green)

	var vine_root := Node3D.new()
	vine_root.name = "TrailingVines"
	vine_root.position = Vector3(-5.78, 2.8, 1.5)
	world.add_child(vine_root)
	for i in range(5):
		_cylinder(vine_root, Vector3(0.04, -0.15 - i * 0.22, 0), 0.012, 0.20, green)

	var poster_data = [
		{"pos": Vector3(-5.55, 2.2, -2.5), "word": "BURGER", "color": Color("#fff1d7"), "icon": "burger"},
		{"pos": Vector3(-5.55, 2.2, 0.5), "word": "FRIES", "color": Color("#ffe0e8"), "icon": "fries"},
		{"pos": Vector3(5.55, 2.2, 2.5), "word": "BUNNY", "color": cream, "icon": "bunny"}
	]
	for data in poster_data:
		var poster = _box(world, "Poster", data["pos"], Vector3(0.06, 0.75, 0.55), data["color"], false)
		_label3d_sign(poster, data["word"], Vector3(0.06, 0.0, 0.0), WORLD_FONT_SMALL, COLOR_TEXT_PRIMARY, -90)
		match data["icon"]:
			"burger":
				FOOD_VISUALS.create_pos_icon_burger(poster, Vector3(0.06, -0.12, 0))
			"fries":
				FOOD_VISUALS.create_pos_icon_fries(poster, Vector3(0.06, -0.12, 0))
			"bunny":
				FOOD_VISUALS.add_bunny_logo(poster, Vector3(0.06, -0.10, 0), 1.2)

func _build_lighting_decor(world: Node3D) -> void:
	var pink := Color("#f4b6c7")
	var cream := Color("#fff0da")
	var cord := Color("#d4c4b0")

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
		_cylinder(root, Vector3(0, 0.08, 0), 0.015, 0.35, cord)
		_cylinder(root, Vector3(0, -0.22, 0), 0.20, 0.18, pink if i % 2 == 0 else cream)
		_sphere(root, Vector3(0, -0.28, 0), 0.05, cream)

	var string_lights := Node3D.new()
	string_lights.name = "StringLights"
	string_lights.position = Vector3(0, 4.15, -0.5)
	world.add_child(string_lights)
	for i in range(8):
		var t := float(i) / 7.0
		var lx := -4.0 + t * 8.0
		var ly := -0.08 + sin(t * PI) * 0.12
		_cylinder(string_lights, Vector3(lx, ly, 0), 0.012, 0.08, cord)
		_sphere(string_lights, Vector3(lx, ly - 0.06, 0), 0.045, [pink, cream, Color("#ffe29d")][i % 3])

func _build_world() -> void:
	var world := Node3D.new()
	world.name = "Cafe"
	add_child(world)

	_build_cafe_shell(world)
	_build_checkout_area(world)
	_build_service_area(world)
	_build_kitchen_line(world)
	_build_dining_area(world)
	_build_windows_and_entrance(world)
	_build_plants_and_shelves(world)
	_build_lighting_decor(world)

	_box(world, "QueueRug", Vector3(4.75, 0.01, -2.95), Vector3(1.35, 0.03, 2.8), Color("#d8eedf"), false)

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
	var sf := scale_factor

	var torso := _sphere(root, Vector3(0, 1.18, 0) * sf, 0.62 * sf, body)
	torso.scale = Vector3(1.05, 0.92, 0.95)
	var head := _sphere(root, Vector3(0, 2.02, -0.02) * sf, 0.54 * sf, body)
	head.scale = Vector3(1.08, 0.96, 1.0)

	match species:
		"bunny":
			var ear_l := _sphere(root, Vector3(-0.18, 2.62, 0.02) * sf, 0.12 * sf, body)
			ear_l.scale = Vector3(0.55, 1.35, 0.45)
			var ear_r := _sphere(root, Vector3(0.18, 2.62, 0.02) * sf, 0.12 * sf, body)
			ear_r.scale = Vector3(0.55, 1.35, 0.45)
			_sphere(root, Vector3(-0.18, 2.58, -0.04) * sf, 0.07 * sf, accent)
			_sphere(root, Vector3(0.18, 2.58, -0.04) * sf, 0.07 * sf, accent)
			_sphere(root, Vector3(0, 1.55, 0.34) * sf, 0.10 * sf, accent)

		"cat":
			var ear_l = _sphere(root, Vector3(-0.24, 2.48, 0) * sf, 0.11 * sf, body)
			ear_l.scale = Vector3(0.75, 0.95, 0.55)
			ear_l.rotation_degrees.z = -18
			var ear_r = _sphere(root, Vector3(0.24, 2.48, 0) * sf, 0.11 * sf, body)
			ear_r.scale = Vector3(0.75, 0.95, 0.55)
			ear_r.rotation_degrees.z = 18
			var tail := _sphere(root, Vector3(0.52, 1.08, 0.12) * sf, 0.10 * sf, accent)
			tail.scale = Vector3(0.55, 1.6, 0.55)

		"fox":
			var ear_l = _sphere(root, Vector3(-0.24, 2.50, 0) * sf, 0.12 * sf, body)
			ear_l.scale = Vector3(0.7, 1.05, 0.5)
			ear_l.rotation_degrees.z = -20
			var ear_r = _sphere(root, Vector3(0.24, 2.50, 0) * sf, 0.12 * sf, body)
			ear_r.scale = Vector3(0.7, 1.05, 0.5)
			ear_r.rotation_degrees.z = 20
			_sphere(root, Vector3(0, 1.92, -0.40) * sf, 0.18 * sf, accent)
			var tail = _sphere(root, Vector3(0.58, 1.05, 0.14) * sf, 0.14 * sf, body)
			tail.scale = Vector3(0.65, 1.35, 0.65)

		"bear":
			_sphere(root, Vector3(-0.30, 2.38, 0) * sf, 0.16 * sf, accent)
			_sphere(root, Vector3(0.30, 2.38, 0) * sf, 0.16 * sf, accent)
			_sphere(root, Vector3(0, 1.92, -0.40) * sf, 0.16 * sf, Color("#d7b59a"))

	_sphere(root, Vector3(-0.15, 2.10, -0.42) * sf, 0.060 * sf, Color("#594b58"))
	_sphere(root, Vector3(0.15, 2.10, -0.42) * sf, 0.060 * sf, Color("#594b58"))
	_sphere(root, Vector3(-0.28, 1.96, -0.40) * sf, 0.070 * sf, Color("#f0a4b2"))
	_sphere(root, Vector3(0.28, 1.96, -0.40) * sf, 0.070 * sf, Color("#f0a4b2"))
	_sphere(root, Vector3(0, 1.98, -0.48) * sf, 0.040 * sf, Color("#6a5056"))

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
	left_panel.custom_minimum_size = Vector2(360, 0)
	left_panel.add_theme_stylebox_override("panel", _stylebox_hud_panel(0.58, 12))
	left_panel.theme = ui_theme
	layer.add_child(left_panel)

	var left_box := VBoxContainer.new()
	left_box.add_theme_constant_override("separation", 2)
	left_panel.add_child(left_box)

	day_label = _hud_label(left_box, HUD_TEXT_MUTED)
	order_label = _hud_label(left_box, HUD_TEXT_DARK, null, true)
	order_items_label = _hud_label(left_box, Color("#7a5160"), null, true)
	tray_label = _hud_label(left_box, HUD_TEXT_MUTED)
	held_label = _hud_label(left_box, HUD_TEXT_MUTED)
	stack_label = _hud_label(left_box, HUD_TEXT_MUTED)
	money_label = _hud_label(left_box, HUD_TEXT_DARK, null, true)

	var right_panel := PanelContainer.new()
	right_panel.anchor_left = 1.0
	right_panel.anchor_right = 1.0
	right_panel.anchor_top = 0.0
	right_panel.anchor_bottom = 0.0
	right_panel.offset_left = -236
	right_panel.offset_right = -14
	right_panel.offset_top = 14
	right_panel.offset_bottom = 108
	right_panel.add_theme_stylebox_override("panel", _stylebox_hud_panel(0.42, 10))
	right_panel.theme = ui_theme
	layer.add_child(right_panel)

	var right_box := VBoxContainer.new()
	right_box.add_theme_constant_override("separation", 3)
	right_panel.add_child(right_box)

	queue_label = _hud_label(right_box, HUD_TEXT_MUTED, null, true)
	queue_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	var help := _hud_label(right_box, HUD_TEXT_MUTED)
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	help.text = "WASD — ходить\nМышь — смотреть\nE — действие\nEsc — мышь"

	var hint := _hud_label(right_box, HUD_TEXT_MUTED)
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
	cross.offset_left = -4
	cross.offset_right = 4
	cross.offset_top = -6
	cross.offset_bottom = 6
	cross.text = "•"
	cross.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cross.add_theme_font_size_override("font_size", 8)
	cross.add_theme_color_override("font_color", Color(1, 1, 1, 0.92))
	layer.add_child(cross)

	interaction_prompt_panel = PanelContainer.new()
	interaction_prompt_panel.anchor_left = 0.5
	interaction_prompt_panel.anchor_right = 0.5
	interaction_prompt_panel.anchor_top = 0.5
	interaction_prompt_panel.anchor_bottom = 0.5
	interaction_prompt_panel.offset_left = -240
	interaction_prompt_panel.offset_right = 240
	interaction_prompt_panel.offset_top = 28
	interaction_prompt_panel.offset_bottom = 66
	interaction_prompt_panel.modulate.a = 0.0
	interaction_prompt_panel.visible = false
	interaction_prompt_panel.add_theme_stylebox_override("panel", _stylebox_hud_panel(PROMPT_BG.a, 8))
	layer.add_child(interaction_prompt_panel)

	var prompt_row := HBoxContainer.new()
	prompt_row.alignment = BoxContainer.ALIGNMENT_CENTER
	prompt_row.add_theme_constant_override("separation", 8)
	interaction_prompt_panel.add_child(prompt_row)

	var e_badge := PanelContainer.new()
	e_badge.add_theme_stylebox_override("panel", _stylebox_hud_panel(0.62, 6))
	var e_label := Label.new()
	e_label.text = "E"
	e_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	e_label.custom_minimum_size = Vector2(22, 22)
	e_label.add_theme_font_override("font", font_bold)
	e_label.add_theme_font_size_override("font_size", HUD_FONT_SIZE)
	e_label.add_theme_color_override("font_color", HUD_TEXT_DARK)
	e_badge.add_child(e_label)
	prompt_row.add_child(e_badge)

	interaction_prompt_action_label = Label.new()
	interaction_prompt_action_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	interaction_prompt_action_label.add_theme_font_override("font", font_semibold)
	interaction_prompt_action_label.add_theme_font_size_override("font_size", HUD_FONT_SIZE)
	interaction_prompt_action_label.add_theme_color_override("font_color", HUD_TEXT_DARK)
	prompt_row.add_child(interaction_prompt_action_label)

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
	debug_info_label.add_theme_font_size_override("font_size", 11)
	debug_info_label.add_theme_color_override("font_color", FPS_TEXT_COLOR)
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
				return "Положить котлету на гриль"
			if busy and pending_action == "cook_patty":
				return "Котлета жарится"
			if held_item == "cooked_patty":
				return "Забрать котлету"
			return "Гриль"
		"assemble":
			if burger_stack.size() >= burger_recipe.size():
				return "Бургер собран"
			var expected: String = burger_recipe[burger_stack.size()]
			var expected_name: String = pretty[expected]
			if held_item == "":
				return "Следующий слой: " + expected_name
			if held_item == expected:
				return "Добавить " + expected_name.to_lower()
			return "Нужен: " + expected_name
		"fries":
			if busy:
				return "Картошка жарится"
			return "Приготовить картошку"
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
	if not interaction_prompt_action_label or not interaction_prompt_panel:
		_prompt_target = 0.0
		return
	if not player or not player.has_method("get_interact_target"):
		_prompt_target = 0.0
		return

	var target = player.get_interact_target()
	if not target:
		_prompt_target = 0.0
		return

	var action_text := _resolve_interaction_text(target)
	if action_text == "":
		_prompt_target = 0.0
		return

	interaction_prompt_action_label.text = action_text
	_prompt_target = 1.0

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
	var cooked := color.is_equal_approx(colors["cooked_patty"]) or color == Color("#744936")
	var patty := FOOD_VISUALS.create_patty(grill_visual, Vector3(0, 0.09, 0), cooked, 0, 1.0)
	patty.name = "Patty"

func _clear_grill_visual() -> void:
	for child in grill_visual.get_children():
		if child.name == "Patty":
			child.queue_free()

func _add_assembly_layer(item_id: String, index: int) -> void:
	FOOD_VISUALS.add_burger_layer(assembly_visual, item_id, index)

func _clear_assembly_visual() -> void:
	for child in assembly_visual.get_children():
		child.queue_free()

func _clear_tray_food() -> void:
	for child in tray_visual.get_children():
		if child.name in ["TrayBase", "TrayRim", "TrayInset"]:
			continue
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
		FOOD_VISUALS.create_tray_meal(tray_visual, tray[i], slot_positions[i])

func _make_tray_burger(pos: Vector3) -> void:
	FOOD_VISUALS.create_tray_meal(tray_visual, "burger", pos)

func _make_tray_fries(pos: Vector3) -> void:
	FOOD_VISUALS.create_tray_meal(tray_visual, "fries", pos)

func _make_tray_soda(pos: Vector3) -> void:
	FOOD_VISUALS.create_tray_meal(tray_visual, "soda", pos)

func _make_small_burger(parent: Node3D, pos: Vector3) -> void:
	FOOD_VISUALS.create_burger_visual(parent, pos, 0.72, true)

func _make_small_fries(parent: Node3D, pos: Vector3) -> void:
	FOOD_VISUALS.create_fries(parent, pos, 8, 0.68, false)

func _make_small_soda(parent: Node3D, pos: Vector3) -> void:
	FOOD_VISUALS.create_drink(parent, pos, 0.68, false)

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
