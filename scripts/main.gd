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

var player

var grill_visual: Node3D
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
var tray_label: Label
var held_label: Label
var stack_label: Label
var money_label: Label
var status_label: Label
var day_label: Label
var queue_label: Label
var progress_bar: ProgressBar
var progress_label: Label

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

func _station(parent: Node, name: String, pos: Vector3, size: Vector3, color: Color, station_type: String, display_name: String, item_id := "") -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = name
	body.position = pos
	body.set_script(STATION_SCRIPT)
	body.station_type = station_type
	body.display_name = display_name
	body.item_id = item_id
	parent.add_child(body)

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

	var label := Label3D.new()
	label.text = display_name + "\n[E]"
	label.position = Vector3(0, size.y * 0.5 + 0.38, 0)
	label.font_size = 24
	label.outline_size = 6
	label.outline_modulate = Color(1, 1, 1, 0.9)
	label.modulate = Color("#553f4d")
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	body.add_child(label)

	return body

func _build_world() -> void:
	var world := Node3D.new()
	world.name = "Cafe"
	add_child(world)

	_box(world, "Floor", Vector3(0, -0.2, 0), Vector3(12, 0.4, 10), Color("#f4d6c8"))
	_box(world, "BackWall", Vector3(0, 2.2, 4.9), Vector3(12, 4.8, 0.25), Color("#f7cedd"))
	_box(world, "LeftWall", Vector3(-5.9, 2.2, 0), Vector3(0.25, 4.8, 10), Color("#ead9f4"))
	_box(world, "RightWall", Vector3(5.9, 2.2, 0), Vector3(0.25, 4.8, 10), Color("#d7eee4"))

	# Стойка и выдача.
	_box(world, "FrontCounter", Vector3(0, 0.65, -1.8), Vector3(8.6, 1.3, 0.75), Color("#f19bb6"))
	_box(world, "CounterTop", Vector3(0, 1.38, -1.8), Vector3(8.8, 0.18, 0.95), Color("#fff0da"))

	var serve = _station(
		world,
		"Serve",
		Vector3(0, 1.57, -1.8),
		Vector3(2.0, 0.22, 0.72),
		Color("#fff2ac"),
		"serve",
		"Выдать заказ"
	)

	tray_visual = Node3D.new()
	tray_visual.name = "TrayVisual"
	tray_visual.position = Vector3(0, 0.18, 0)
	serve.add_child(tray_visual)
	_box(tray_visual, "TrayBase", Vector3(0, 0, 0), Vector3(1.45, 0.06, 0.58), Color("#de809e"), false)

	# Касса.
	var register_root := Node3D.new()
	register_root.name = "Register"
	register_root.position = Vector3(-2.55, 1.60, -1.78)
	world.add_child(register_root)

	_box(register_root, "RegisterBody", Vector3(0, 0, 0), Vector3(1.05, 0.75, 0.60), Color("#f2a7bd"), false)
	_box(register_root, "RegisterScreen", Vector3(0, 0.13, -0.34), Vector3(0.78, 0.42, 0.08), Color("#fff0f5"), false)

	register_screen = Label3D.new()
	register_screen.position = Vector3(0, 0.13, -0.40)
	register_screen.font_size = 22
	register_screen.modulate = Color("#6b4b5d")
	register_root.add_child(register_screen)

	_box(register_root, "CardTerminal", Vector3(0.72, -0.12, -0.12), Vector3(0.34, 0.18, 0.42), Color("#c8dbea"), false)

	# Кухонная линия.
	_box(world, "PrepA", Vector3(-4.4, 0.55, 2.8), Vector3(2.0, 1.1, 1.2), Color("#c5d9ef"))
	_box(world, "PrepB", Vector3(-1.7, 0.55, 2.8), Vector3(2.0, 1.1, 1.2), Color("#d7d7eb"))
	_box(world, "PrepC", Vector3(1.0, 0.55, 2.8), Vector3(2.0, 1.1, 1.2), Color("#d9ead3"))
	_box(world, "PrepD", Vector3(3.7, 0.55, 2.8), Vector3(2.0, 1.1, 1.2), Color("#e9d7ef"))

	var bun_bottom = _station(world, "BunBottom", Vector3(-4.75, 1.25, 2.7), Vector3(0.62, 0.25, 0.7), colors["bun_bottom"], "ingredient", "Нижняя булочка", "bun_bottom")
	_cylinder(bun_bottom, Vector3(0, 0.19, 0), 0.20, 0.08, colors["bun_bottom"], 90)

	var raw_patty = _station(world, "RawPatty", Vector3(-4.0, 1.25, 2.7), Vector3(0.62, 0.25, 0.7), colors["raw_patty"], "ingredient", "Сырая котлета", "raw_patty")
	_cylinder(raw_patty, Vector3(0, 0.18, 0), 0.19, 0.06, colors["raw_patty"], 90)

	var cheese = _station(world, "Cheese", Vector3(-2.05, 1.25, 2.7), Vector3(0.55, 0.18, 0.7), colors["cheese"], "ingredient", "Сыр", "cheese")
	_box(cheese, "CheeseVisual", Vector3(0, 0.15, 0), Vector3(0.34, 0.035, 0.34), colors["cheese"], false)

	var lettuce = _station(world, "Lettuce", Vector3(-1.35, 1.25, 2.7), Vector3(0.55, 0.18, 0.7), colors["lettuce"], "ingredient", "Салат", "lettuce")
	_cylinder(lettuce, Vector3(0, 0.15, 0), 0.20, 0.04, colors["lettuce"], 90)

	var tomato = _station(world, "Tomato", Vector3(0.65, 1.25, 2.7), Vector3(0.55, 0.18, 0.7), colors["tomato"], "ingredient", "Помидор", "tomato")
	_cylinder(tomato, Vector3(0, 0.15, 0), 0.16, 0.04, colors["tomato"], 90)

	var bun_top = _station(world, "BunTop", Vector3(1.35, 1.25, 2.7), Vector3(0.62, 0.25, 0.7), colors["bun_top"], "ingredient", "Верхняя булочка", "bun_top")
	var top = _sphere(bun_top, Vector3(0, 0.20, 0), 0.21, colors["bun_top"])
	top.scale = Vector3(1.0, 0.55, 1.0)

	var grill_station = _station(world, "Grill", Vector3(3.35, 1.25, 2.7), Vector3(0.95, 0.25, 0.8), Color("#5f6066"), "grill", "Гриль")
	grill_visual = Node3D.new()
	grill_visual.position = Vector3(0, 0.18, 0)
	grill_station.add_child(grill_visual)
	for x in [-0.30, -0.10, 0.10, 0.30]:
		_box(grill_visual, "GrillLine", Vector3(x, 0, 0), Vector3(0.025, 0.035, 0.64), Color("#2f3035"), false)

	var assembly_station = _station(world, "Assembly", Vector3(4.1, 1.25, 2.7), Vector3(0.85, 0.25, 0.8), Color("#fff1d4"), "assemble", "Сборка бургера")
	assembly_visual = Node3D.new()
	assembly_visual.position = Vector3(0, 0.16, 0)
	assembly_station.add_child(assembly_visual)

	var fryer_station = _station(world, "Fryer", Vector3(-4.6, 1.35, 0.65), Vector3(1.5, 0.4, 1.0), Color("#b7bcc4"), "fries", "Фритюрница")
	fryer_visual = Node3D.new()
	fryer_visual.position = Vector3(0, 0.26, 0)
	fryer_station.add_child(fryer_visual)

	_box(fryer_visual, "Basket", Vector3(0, 0, 0), Vector3(0.72, 0.18, 0.62), Color("#72767c"), false)
	for i in range(8):
		var fx = -0.28 + (i % 4) * 0.18
		var fz = -0.16 + int(i / 4) * 0.30
		var fry = _box(fryer_visual, "Fry", Vector3(fx, 0.15, fz), Vector3(0.08, 0.30, 0.08), Color("#f5cf57"), false)
		fry.rotation_degrees.z = 8 + i * 5

	var soda_station = _station(world, "Soda", Vector3(4.6, 1.75, 0.65), Vector3(1.4, 1.7, 0.8), Color("#94d7df"), "soda", "Автомат напитков")
	soda_visual = Node3D.new()
	soda_visual.position = Vector3(0, -0.55, -0.47)
	soda_station.add_child(soda_visual)
	_cylinder(soda_visual, Vector3.ZERO, 0.16, 0.38, Color("#ffe9ef"))
	_box(soda_visual, "Straw", Vector3(0.05, 0.30, 0), Vector3(0.035, 0.42, 0.035), Color("#e4789c"), false)

	_station(world, "Trash", Vector3(5.0, 0.65, 3.95), Vector3(0.9, 1.2, 0.9), Color("#a9c7bb"), "trash", "Мусор")

	# Столики для обслуженных гостей.
	for x in [-3.15, 0.0, 3.15]:
		_box(world, "DiningTable", Vector3(x, 0.72, -3.9), Vector3(1.65, 0.12, 1.15), Color("#fff0da"))
		_box(world, "DiningLeg", Vector3(x, 0.34, -3.9), Vector3(0.20, 0.70, 0.20), Color("#b58b78"))
		_box(world, "Chair", Vector3(x, 0.42, -4.65), Vector3(0.75, 0.75, 0.75), Color("#e99ab2"))

	# Область очереди у входа справа.
	_box(world, "QueueRug", Vector3(4.75, 0.01, -2.95), Vector3(1.35, 0.03, 2.8), Color("#d8eedf"), false)
	var qsign := Label3D.new()
	qsign.text = "ОЧЕРЕДЬ"
	qsign.position = Vector3(4.75, 1.0, -1.65)
	qsign.font_size = 22
	qsign.modulate = Color("#5f765f")
	qsign.rotation_degrees.y = 180
	world.add_child(qsign)

	# Меню и декор.
	for i in range(3):
		var x = -2.6 + i * 2.6
		var board = _box(
			world,
			"MenuBoard",
			Vector3(x, 3.25, 4.68),
			Vector3(2.1, 1.25, 0.12),
			[Color("#fff1d7"), Color("#ffe0e8"), Color("#e0f0ff")][i],
			false
		)
		var icon = Label3D.new()
		icon.text = ["BURGER", "FRIES", "DRINK"][i]
		icon.position = Vector3(0, 0, -0.08)
		icon.font_size = 32
		icon.modulate = Color("#6b5060")
		board.add_child(icon)

	for x in [-4.5, -3.0, -1.5, 0.0, 1.5, 3.0, 4.5]:
		_sphere(world, Vector3(x, 3.45, 3.9), 0.12, [Color("#ffd2df"), Color("#ffe29d"), Color("#cfe7ff")][randi() % 3])

	for x in [-4.7, 4.7]:
		_box(world, "PlantPot", Vector3(x, 0.38, -4.15), Vector3(0.65, 0.55, 0.65), Color("#e2ad7c"), false)
		_sphere(world, Vector3(x, 0.95, -4.15), 0.48, Color("#8fc79d"))

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
	current_name_label.font_size = 28
	current_name_label.outline_size = 7
	current_name_label.outline_modulate = Color(1, 1, 1, 0.92)
	current_name_label.modulate = Color("#6b4d5d")
	current_name_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	current_customer_root.add_child(current_name_label)

	current_order_label = Label3D.new()
	current_order_label.position = Vector3(0, 3.90, 0)
	current_order_label.font_size = 28
	current_order_label.outline_size = 10
	current_order_label.outline_modulate = Color("#fff7ee")
	current_order_label.modulate = Color("#6b4d5d")
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
	var layer := CanvasLayer.new()
	add_child(layer)

	var panel := ColorRect.new()
	panel.position = Vector2(18, 18)
	panel.size = Vector2(650, 195)
	panel.color = Color(0.19, 0.14, 0.2, 0.88)
	layer.add_child(panel)

	day_label = _label(panel, Vector2(18, 10), Vector2(610, 26), 16)
	order_label = _label(panel, Vector2(18, 38), Vector2(610, 30), 22)
	tray_label = _label(panel, Vector2(18, 73), Vector2(610, 26), 17)
	held_label = _label(panel, Vector2(18, 103), Vector2(610, 26), 17)
	stack_label = _label(panel, Vector2(18, 133), Vector2(610, 26), 16)
	money_label = _label(panel, Vector2(18, 163), Vector2(610, 24), 16)

	queue_label = Label.new()
	queue_label.anchor_left = 1.0
	queue_label.anchor_right = 1.0
	queue_label.offset_left = -260
	queue_label.offset_right = -18
	queue_label.offset_top = 18
	queue_label.offset_bottom = 48
	queue_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	queue_label.add_theme_font_size_override("font_size", 18)
	queue_label.add_theme_color_override("font_color", Color("#4d4050"))
	layer.add_child(queue_label)

	var help := Label.new()
	help.anchor_left = 1.0
	help.anchor_right = 1.0
	help.offset_left = -405
	help.offset_right = -18
	help.offset_top = 58
	help.offset_bottom = 176
	help.text = "WASD — ходить\nМышь — смотреть\nE — взаимодействовать\nEsc — отпустить мышь\n\nПосле выдачи гость идёт за столик,\nа очередь двигается вперёд."
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	help.add_theme_font_size_override("font_size", 15)
	help.add_theme_color_override("font_color", Color("#4d4050"))
	layer.add_child(help)

	status_label = Label.new()
	status_label.anchor_left = 0.5
	status_label.anchor_right = 0.5
	status_label.anchor_top = 1.0
	status_label.anchor_bottom = 1.0
	status_label.offset_left = -430
	status_label.offset_right = 430
	status_label.offset_top = -88
	status_label.offset_bottom = -44
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	status_label.add_theme_font_size_override("font_size", 19)
	status_label.add_theme_color_override("font_color", Color("#fff8ee"))
	layer.add_child(status_label)

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

	progress_label = Label.new()
	progress_label.anchor_left = 0.5
	progress_label.anchor_right = 0.5
	progress_label.anchor_top = 1.0
	progress_label.anchor_bottom = 1.0
	progress_label.offset_left = -260
	progress_label.offset_right = 260
	progress_label.offset_top = -166
	progress_label.offset_bottom = -138
	progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	progress_label.add_theme_font_size_override("font_size", 16)
	progress_label.visible = false
	layer.add_child(progress_label)

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
	cross.add_theme_font_size_override("font_size", 26)
	cross.add_theme_color_override("font_color", Color(1, 1, 1, 0.92))
	layer.add_child(cross)

	_update_ui()

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

	if action == "make_fries":
		_bounce_node(fryer_visual)
	elif action == "make_soda":
		_bounce_node(soda_visual)

func _finish_action() -> void:
	busy = false
	progress_bar.visible = false
	progress_label.visible = false

	if pending_action == "cook_patty":
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
	var y = index * 0.075

	match item_id:
		"bun_bottom":
			_cylinder(assembly_visual, Vector3(0, y, 0), 0.21, 0.08, colors[item_id], 90)
		"cooked_patty":
			_cylinder(assembly_visual, Vector3(0, y, 0), 0.20, 0.06, colors[item_id], 90)
		"cheese":
			_box(assembly_visual, "Layer", Vector3(0, y, 0), Vector3(0.38, 0.035, 0.38), colors[item_id], false)
		"lettuce":
			var m = _cylinder(assembly_visual, Vector3(0, y, 0), 0.22, 0.04, colors[item_id], 90)
			m.scale = Vector3(1.08, 1.0, 0.86)
		"tomato":
			_cylinder(assembly_visual, Vector3(0, y, 0), 0.18, 0.04, colors[item_id], 90)
		"bun_top":
			var m = _sphere(assembly_visual, Vector3(0, y + 0.05, 0), 0.22, colors[item_id])
			m.scale = Vector3(1.0, 0.55, 1.0)

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
	_box(root, "Cheese", Vector3(0, 0.090, 0), Vector3(0.30, 0.025, 0.30), colors["cheese"], false)
	_cylinder(root, Vector3(0, 0.120, 0), 0.18, 0.030, colors["lettuce"], 90)
	_cylinder(root, Vector3(0, 0.150, 0), 0.145, 0.028, colors["tomato"], 90)

	var top = _sphere(root, Vector3(0, 0.205, 0), 0.17, colors["bun_top"])
	top.scale = Vector3(1.0, 0.52, 1.0)

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
	if not order_label:
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

	day_label.text = "День %d  •  обслужено %d/%d" % [day, served_today, target_today]
	order_label.text = "%s заказал: %s" % [customer_name, " + ".join(order_names)]
	tray_label.text = "Поднос: " + ("пусто" if tray_names.is_empty() else " + ".join(tray_names))
	held_label.text = "В лапках: " + ("ничего" if held_item == "" else pretty[held_item])
	stack_label.text = "Бургер: " + ("ещё не начат" if stack_names.is_empty() else " → ".join(stack_names))
	money_label.text = "Монеты: %d    Сердечки: %d" % [coins, hearts]

	if queue_label:
		queue_label.text = "В очереди: %d" % queue_data.size()

func _show_status(text: String) -> void:
	if status_label:
		status_label.text = text
