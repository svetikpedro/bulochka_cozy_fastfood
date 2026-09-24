class_name FoodVisuals
extends RefCounted

enum MatKind { FOOD, METAL, PLASTIC, WOOD, CERAMIC, FABRIC, GLASS }

const BUN_TOP := Color("#f1b768")
const BUN_BOTTOM := Color("#e9ad5e")
const BUN_BOTTOM_DARK := Color("#c88842")
const BUN_TOP_DARK := Color("#c88842")
const RAW_PATTY := Color("#c45a4a")
const RAW_PATTY_DARK := Color("#8f3535")
const COOKED_PATTY := Color("#744936")
const COOKED_CRUST := Color("#4a2f22")
const CHEESE := Color("#f5d070")
const LETTUCE := Color("#8dcf72")
const LETTUCE_DARK := Color("#7fbe71")
const TOMATO := Color("#e96161")
const TOMATO_INNER := Color("#f4a0a0")
const SESAME := Color("#fff0da")
const FRIES := Color("#f5cf57")
const PINK_CARTON := Color("#e98fa9")
const SODA_CUP := Color("#ffe8ef")
const SODA_STRIPE := Color("#ef9fb6")
const BUNNY_WHITE := Color("#fff7f2")

static var _cache: Dictionary = {}

static var SESAME_POSITIONS := [
	Vector3(-0.05, 0.19, -0.04), Vector3(0.04, 0.20, 0.03), Vector3(-0.02, 0.21, 0.05),
	Vector3(0.06, 0.19, -0.02), Vector3(-0.06, 0.20, 0.01), Vector3(0.01, 0.22, -0.05),
	Vector3(0.05, 0.21, 0.05), Vector3(-0.03, 0.19, 0.04), Vector3(0.00, 0.20, 0.00),
]

static var FRIES_OFFSETS := [
	Vector3(-0.10, 0.18, -0.05), Vector3(-0.05, 0.22, -0.03), Vector3(0.00, 0.20, -0.06),
	Vector3(0.05, 0.24, -0.02), Vector3(0.10, 0.19, -0.04), Vector3(-0.08, 0.21, 0.02),
	Vector3(-0.02, 0.23, 0.04), Vector3(0.04, 0.20, 0.05), Vector3(0.08, 0.22, 0.01),
	Vector3(-0.06, 0.19, 0.06), Vector3(0.02, 0.25, -0.01), Vector3(0.07, 0.18, 0.03),
	Vector3(-0.03, 0.21, -0.04), Vector3(0.03, 0.23, 0.02), Vector3(-0.09, 0.20, 0.00),
]

static func food(color: Color, roughness := 0.68) -> StandardMaterial3D:
	return _cached(MatKind.FOOD, color, roughness, 0.0)

static func metal(color: Color, roughness := 0.38, metallic := 0.58) -> StandardMaterial3D:
	return _cached(MatKind.METAL, color, roughness, metallic)

static func plastic(color: Color, roughness := 0.52) -> StandardMaterial3D:
	return _cached(MatKind.PLASTIC, color, roughness, 0.0)

static func wood(color: Color, roughness := 0.74) -> StandardMaterial3D:
	return _cached(MatKind.WOOD, color, roughness, 0.0)

static func ceramic(color: Color, roughness := 0.42) -> StandardMaterial3D:
	return _cached(MatKind.CERAMIC, color, roughness, 0.0)

static func fabric(color: Color, roughness := 0.90) -> StandardMaterial3D:
	return _cached(MatKind.FABRIC, color, roughness, 0.0)

static func glass(color: Color, roughness := 0.18, alpha := 0.35) -> StandardMaterial3D:
	var key := "glass_%s_%.2f" % [color.to_html(false), alpha]
	if _cache.has(key):
		return _cache[key]
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(color.r, color.g, color.b, alpha)
	mat.roughness = roughness
	mat.metallic = 0.05
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_cache[key] = mat
	return mat

static func _cached(kind: MatKind, color: Color, roughness: float, metallic: float) -> StandardMaterial3D:
	var key := "%d_%s_%.2f_%.2f" % [kind, color.to_html(false), roughness, metallic]
	if _cache.has(key):
		return _cache[key]
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = roughness
	mat.metallic = metallic
	_cache[key] = mat
	return mat

static func _mesh(parent: Node, mesh: Mesh, mat: StandardMaterial3D, pos: Vector3, rot_deg := Vector3.ZERO, scl := Vector3.ONE) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = mat
	node.position = pos
	node.rotation_degrees = rot_deg
	node.scale = scl
	parent.add_child(node)
	return node

static func _box_mesh(size: Vector3) -> BoxMesh:
	var mesh := BoxMesh.new()
	mesh.size = size
	return mesh

static func _sphere_mesh(radius: float) -> SphereMesh:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	return mesh

static func _cyl_mesh(radius: float, height: float) -> CylinderMesh:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	return mesh

static func add_bunny_logo(parent: Node, pos: Vector3, scale_factor := 1.0) -> void:
	var root := Node3D.new()
	root.position = pos
	root.scale = Vector3.ONE * scale_factor
	parent.add_child(root)
	_mesh(root, _sphere_mesh(0.05), plastic(BUNNY_WHITE), Vector3(0, 0.03, 0), Vector3.ZERO, Vector3(1.0, 0.85, 0.9))
	_mesh(root, _sphere_mesh(0.018), plastic(BUNNY_WHITE), Vector3(-0.022, 0.07, 0))
	_mesh(root, _sphere_mesh(0.018), plastic(BUNNY_WHITE), Vector3(0.022, 0.07, 0))

static func create_bun_bottom(parent: Node, pos: Vector3, rot_y := 0.0, scale_factor := 1.0) -> Node3D:
	var root := Node3D.new()
	root.position = pos
	root.rotation_degrees.y = rot_y
	root.scale = Vector3.ONE * scale_factor
	parent.add_child(root)
	_mesh(root, _cyl_mesh(0.145, 0.028), food(BUN_BOTTOM_DARK), Vector3.ZERO, Vector3(90, 0, 0))
	var crown := _mesh(root, _sphere_mesh(0.13), food(BUN_BOTTOM), Vector3(0, 0.018, 0))
	crown.scale = Vector3(1.0, 0.42, 1.0)
	_mesh(root, _sphere_mesh(0.11), food(BUN_BOTTOM, 0.74), Vector3(0, 0.034, 0), Vector3.ZERO, Vector3(1.0, 0.28, 1.0))
	return root

static func create_bun_top(parent: Node, pos: Vector3, rot_y := 0.0, scale_factor := 1.0, with_sesame := true) -> Node3D:
	var root := Node3D.new()
	root.position = pos
	root.rotation_degrees.y = rot_y
	root.scale = Vector3.ONE * scale_factor
	parent.add_child(root)
	_mesh(root, _cyl_mesh(0.155, 0.018), food(BUN_TOP_DARK), Vector3(0, -0.008, 0), Vector3(90, 0, 0))
	var dome := _mesh(root, _sphere_mesh(0.125), food(BUN_TOP), Vector3(0, 0.03, 0))
	dome.scale = Vector3(1.0, 0.48, 1.0)
	if with_sesame:
		for seed_pos in SESAME_POSITIONS:
			var p: Vector3 = seed_pos * scale_factor
			_mesh(root, _sphere_mesh(0.009), food(SESAME, 0.55), p)
	return root

static func create_patty(parent: Node, pos: Vector3, cooked := false, rot_y := 0.0, scale_factor := 1.0) -> Node3D:
	var root := Node3D.new()
	root.position = pos
	root.rotation_degrees.y = rot_y
	root.scale = Vector3.ONE * scale_factor
	parent.add_child(root)
	var body_color := COOKED_PATTY if cooked else RAW_PATTY
	var edge_color := COOKED_CRUST if cooked else RAW_PATTY_DARK
	_mesh(root, _cyl_mesh(0.185, 0.048), food(body_color, 0.72), Vector3.ZERO, Vector3(90, 0, 0))
	_mesh(root, _cyl_mesh(0.175, 0.012), food(edge_color, 0.78), Vector3(0, 0.012, 0), Vector3(90, 0, 0))
	if cooked:
		for i in range(4):
			_mesh(root, _box_mesh(Vector3(0.018, 0.006, 0.11)), food(COOKED_CRUST, 0.82), Vector3(-0.10 + i * 0.07, 0.028, 0))
	else:
		for i in range(3):
			var bump := _mesh(root, _sphere_mesh(0.025), food(RAW_PATTY_DARK, 0.76), Vector3(-0.06 + i * 0.06, 0.018, 0.04 - i * 0.03))
			bump.scale = Vector3(1.0, 0.35, 0.8)
	return root

static func create_cheese(parent: Node, pos: Vector3, rot_y := 0.0, rot_z := 0.0, scale_factor := 1.0) -> Node3D:
	var root := Node3D.new()
	root.position = pos
	root.rotation_degrees = Vector3(0, rot_y, rot_z)
	root.scale = Vector3.ONE * scale_factor
	parent.add_child(root)
	_mesh(root, _box_mesh(Vector3(0.20, 0.038, 0.20)), food(CHEESE, 0.62), Vector3.ZERO)
	_mesh(root, _box_mesh(Vector3(0.16, 0.012, 0.16)), food(CHEESE, 0.70), Vector3(0.02, -0.018, 0.02))
	var droop := _mesh(root, _box_mesh(Vector3(0.05, 0.012, 0.05)), food(CHEESE, 0.58), Vector3(0.08, -0.024, 0.08))
	droop.rotation_degrees.x = 18
	return root

static func create_lettuce(parent: Node, pos: Vector3, rot_y := 0.0, scale_factor := 1.0) -> Node3D:
	var root := Node3D.new()
	root.position = pos
	root.rotation_degrees.y = rot_y
	root.scale = Vector3.ONE * scale_factor
	parent.add_child(root)
	var leaf_a := _mesh(root, _cyl_mesh(0.14, 0.018), food(LETTUCE, 0.66), Vector3(-0.02, 0.004, 0.01), Vector3(90, 0, 0), Vector3(1.05, 0.8, 0.92))
	var leaf_b := _mesh(root, _cyl_mesh(0.12, 0.014), food(LETTUCE_DARK, 0.70), Vector3(0.03, 0.008, -0.02), Vector3(88, 14, 0), Vector3(0.95, 0.75, 1.08))
	_mesh(root, _cyl_mesh(0.10, 0.012), food(LETTUCE, 0.64), Vector3(0.0, 0.012, 0.03), Vector3(92, -10, 0), Vector3(1.1, 0.7, 0.9))
	leaf_a.rotation_degrees.z = 8
	leaf_b.rotation_degrees.z = -6
	return root

static func create_tomato(parent: Node, pos: Vector3, rot_y := 0.0, rot_x := 0.0, scale_factor := 1.0) -> Node3D:
	var root := Node3D.new()
	root.position = pos
	root.rotation_degrees = Vector3(rot_x, rot_y, 0)
	root.scale = Vector3.ONE * scale_factor
	parent.add_child(root)
	_mesh(root, _cyl_mesh(0.125, 0.032), food(TOMATO, 0.64), Vector3.ZERO, Vector3(90, 0, 0))
	_mesh(root, _cyl_mesh(0.095, 0.012), food(TOMATO_INNER, 0.58), Vector3(0, 0.012, 0), Vector3(90, 0, 0))
	for i in range(3):
		_mesh(root, _sphere_mesh(0.006), food(TOMATO_INNER, 0.50), Vector3(-0.03 + i * 0.03, 0.016, 0.02 - i * 0.02))
	return root

static func populate_bin(parent: Node, item_id: String) -> Node3D:
	var visual_root := Node3D.new()
	visual_root.name = "VisualRoot"
	parent.add_child(visual_root)
	match item_id:
		"bun_bottom":
			for i in range(3):
				create_bun_bottom(visual_root, Vector3(-0.08 + i * 0.08, 0.12, 0.0), -8 + i * 8)
		"bun_top":
			for i in range(2):
				create_bun_top(visual_root, Vector3(-0.05 + i * 0.10, 0.14, 0.0), 6 + i * 10, 0.92)
		"cheese":
			for i in range(4):
				create_cheese(visual_root, Vector3(-0.08 + i * 0.055, 0.12 + i * 0.008, 0.0), -14 + i * 9, 3 + i * 2)
		"lettuce":
			for i in range(4):
				create_lettuce(visual_root, Vector3(-0.10 + i * 0.07, 0.11 + i * 0.012, 0.0), -16 + i * 11, 0.92 + i * 0.04)
		"tomato":
			for i in range(4):
				create_tomato(visual_root, Vector3(-0.09 + i * 0.06, 0.12, 0.0), -12 + i * 8, 6 + i * 2)
		"raw_patty":
			for i in range(3):
				create_patty(visual_root, Vector3(-0.08 + i * 0.08, 0.12, 0.0), false, -5 + i * 5)
	return visual_root

static func create_held_item(parent: Node, item_id: String) -> Node3D:
	var root := Node3D.new()
	parent.add_child(root)
	match item_id:
		"bun_bottom":
			create_bun_bottom(root, Vector3.ZERO, 12, 1.05)
		"bun_top":
			create_bun_top(root, Vector3.ZERO, -8, 1.05)
		"raw_patty":
			create_patty(root, Vector3.ZERO, false, 0, 1.05)
		"cooked_patty":
			create_patty(root, Vector3.ZERO, true, 0, 1.05)
		"cheese":
			create_cheese(root, Vector3.ZERO, 10, 4, 1.08)
		"lettuce":
			create_lettuce(root, Vector3.ZERO, 18, 1.08)
		"tomato":
			create_tomato(root, Vector3.ZERO, 8, 0, 1.08)
		_:
			_mesh(root, _box_mesh(Vector3(0.30, 0.16, 0.30)), plastic(Color("#f3d8dd")), Vector3.ZERO)
	return root

static func add_burger_layer(parent: Node, item_id: String, index: int) -> void:
	var y := index * 0.078
	var jitter_x: float = [-0.008, 0.006, -0.004, 0.005, -0.003, 0.007][index % 6]
	var jitter_z: float = [0.005, -0.004, 0.006, -0.003, 0.004, -0.005][index % 6]
	var pos := Vector3(jitter_x, y, jitter_z)
	match item_id:
		"bun_bottom":
			create_bun_bottom(parent, pos, 4, 1.0)
		"cooked_patty":
			create_patty(parent, pos, true, -3, 1.0)
		"cheese":
			var cheese := create_cheese(parent, pos, 12, 2, 1.02)
			cheese.scale = Vector3(1.08, 1.0, 1.08)
		"lettuce":
			create_lettuce(parent, pos, 18, 1.05)
		"tomato":
			create_tomato(parent, pos, 10, 0, 0.92)
		"bun_top":
			create_bun_top(parent, pos + Vector3(0, 0.04, 0), -6, 1.0)

static func create_burger_visual(parent: Node, pos: Vector3, scale_factor := 1.0, in_box := false) -> Node3D:
	var root := Node3D.new()
	root.position = pos
	root.scale = Vector3.ONE * scale_factor
	parent.add_child(root)
	if in_box:
		_mesh(root, _box_mesh(Vector3(0.34, 0.08, 0.34)), plastic(Color("#fff0da")), Vector3(0, 0.04, 0))
		_mesh(root, _box_mesh(Vector3(0.30, 0.06, 0.30)), plastic(Color("#f4b6c7")), Vector3(0, 0.08, 0))
		add_bunny_logo(root, Vector3(0.12, 0.10, 0.14), 0.7)
	var layers := ["bun_bottom", "cooked_patty", "cheese", "lettuce", "tomato", "bun_top"]
	for i in range(layers.size()):
		add_burger_layer(root, layers[i], i)
	return root

static func create_fries(parent: Node, pos: Vector3, count := 14, scale_factor := 1.0, with_logo := true) -> Node3D:
	var root := Node3D.new()
	root.position = pos
	root.scale = Vector3.ONE * scale_factor
	parent.add_child(root)
	_mesh(root, _box_mesh(Vector3(0.30, 0.26, 0.24)), plastic(PINK_CARTON, 0.48), Vector3(0, 0.03, 0))
	if with_logo:
		add_bunny_logo(root, Vector3(0.0, 0.16, 0.13), 0.65)
	for i in range(mini(count, FRIES_OFFSETS.size())):
		var off: Vector3 = FRIES_OFFSETS[i]
		var fry := _mesh(root, _box_mesh(Vector3(0.038, 0.24 + (i % 3) * 0.02, 0.038)), food(FRIES, 0.66), off)
		fry.rotation_degrees = Vector3(-6 + (i % 4) * 3, (i % 5) * 7, -8 + i * 2)
	return root

static func create_drink(parent: Node, pos: Vector3, scale_factor := 1.0, with_logo := true) -> Node3D:
	var root := Node3D.new()
	root.position = pos
	root.scale = Vector3.ONE * scale_factor
	parent.add_child(root)
	_mesh(root, _cyl_mesh(0.115, 0.32), plastic(SODA_CUP, 0.48), Vector3(0, 0.05, 0))
	for i in range(4):
		_mesh(root, _box_mesh(Vector3(0.14, 0.05, 0.02)), plastic(SODA_STRIPE, 0.50), Vector3(0, -0.02 + i * 0.08, -0.116))
	_mesh(root, _cyl_mesh(0.118, 0.018), plastic(Color("#ffffff", 0.92), 0.40), Vector3(0, 0.22, 0))
	_mesh(root, _box_mesh(Vector3(0.025, 0.38, 0.025)), plastic(Color("#df6f93"), 0.46), Vector3(0.035, 0.34, 0))
	if with_logo:
		add_bunny_logo(root, Vector3(-0.04, 0.10, 0.12), 0.55)
	return root

static func create_tray_meal(parent: Node, item: String, pos: Vector3) -> void:
	match item:
		"burger":
			create_burger_visual(parent, pos, 0.82, true)
		"fries":
			create_fries(parent, pos, 12, 0.78)
		"soda":
			create_drink(parent, pos, 0.78)

static func create_pos_icon_burger(parent: Node, pos: Vector3) -> void:
	var root := Node3D.new()
	root.position = pos
	root.scale = Vector3(0.55, 0.55, 0.55)
	parent.add_child(root)
	create_bun_bottom(root, Vector3.ZERO, 0, 0.8)
	create_patty(root, Vector3(0, 0.05, 0), true, 0, 0.75)
	create_bun_top(root, Vector3(0, 0.10, 0), 0, 0.78, false)

static func create_pos_icon_fries(parent: Node, pos: Vector3) -> void:
	create_fries(parent, pos, 5, 0.45, false)

static func create_pos_icon_drink(parent: Node, pos: Vector3) -> void:
	create_drink(parent, pos, 0.45, false)

static func create_display_burger(parent: Node, pos: Vector3, scale_factor := 0.75) -> void:
	create_burger_visual(parent, pos, scale_factor, false)
