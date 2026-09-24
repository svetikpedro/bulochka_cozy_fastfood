extends CharacterBody3D

var camera: Camera3D
var ray: RayCast3D
var paw_left: MeshInstance3D
var paw_right: MeshInstance3D
var held_root: Node3D
var held_label: Label3D
var bob_time := 0.0

const SPEED := 4.0
const MOUSE_SENS := 0.0022
const GRAVITY := 18.0

func _ready() -> void:
	camera = Camera3D.new()
	camera.name = "Camera3D"
	camera.position = Vector3(0, 1.55, 0)
	camera.current = true
	add_child(camera)

	ray = RayCast3D.new()
	ray.name = "InteractRay"
	ray.target_position = Vector3(0, 0, -3.2)
	ray.enabled = true
	camera.add_child(ray)

	_create_paws()
	_create_held_root()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _make_mat(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.82
	return mat

func _create_paws() -> void:
	paw_left = _make_paw(Vector3(-0.42, -0.38, -0.72), -15.0)
	paw_right = _make_paw(Vector3(0.42, -0.38, -0.72), 15.0)

func _make_paw(pos: Vector3, roll: float) -> MeshInstance3D:
	var paw := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.14
	capsule.height = 0.52
	paw.mesh = capsule
	paw.material_override = _make_mat(Color("#fff7ec"))
	paw.position = pos
	paw.rotation_degrees = Vector3(68, 0, roll)
	camera.add_child(paw)
	return paw

func _create_held_root() -> void:
	held_root = Node3D.new()
	held_root.position = Vector3(0, -0.31, -0.86)
	camera.add_child(held_root)

	held_label = Label3D.new()
	held_label.position = Vector3(0, 0.22, -0.04)
	held_label.font_size = 26
	held_label.outline_size = 6
	held_label.outline_modulate = Color(1, 1, 1, 0.92)
	held_label.modulate = Color("#5a4654")
	held_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	held_label.visible = false
	held_root.add_child(held_label)

func _clear_held_visual() -> void:
	for child in held_root.get_children():
		if child != held_label:
			child.queue_free()

func _add_cylinder(parent: Node3D, radius: float, height: float, color: Color, pos: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = radius
	cylinder.bottom_radius = radius
	cylinder.height = height
	mesh.mesh = cylinder
	mesh.material_override = _make_mat(color)
	mesh.position = pos
	parent.add_child(mesh)
	return mesh

func _add_box(parent: Node3D, size: Vector3, color: Color, pos: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.material_override = _make_mat(color)
	mesh.position = pos
	parent.add_child(mesh)
	return mesh

func _add_sphere(parent: Node3D, radius: float, color: Color, pos: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = radius
	sphere.height = radius * 2.0
	mesh.mesh = sphere
	mesh.material_override = _make_mat(color)
	mesh.position = pos
	parent.add_child(mesh)
	return mesh

func set_held_item(item_id: String, display_name: String, _color: Color) -> void:
	_clear_held_visual()

	if item_id == "":
		held_label.visible = false
		return

	held_label.text = display_name
	held_label.visible = true

	match item_id:
		"bun_bottom":
			var bun = _add_cylinder(held_root, 0.20, 0.10, Color("#e9ad5e"))
			bun.rotation_degrees.x = 90
		"bun_top":
			var bun = _add_sphere(held_root, 0.22, Color("#f1b768"))
			bun.scale = Vector3(1.0, 0.55, 1.0)
		"raw_patty":
			var patty = _add_cylinder(held_root, 0.19, 0.07, Color("#b65f5f"))
			patty.rotation_degrees.x = 90
		"cooked_patty":
			var patty = _add_cylinder(held_root, 0.19, 0.07, Color("#744936"))
			patty.rotation_degrees.x = 90
		"cheese":
			var cheese = _add_box(held_root, Vector3(0.38, 0.035, 0.38), Color("#ffd85c"))
			cheese.rotation_degrees.y = 10
		"lettuce":
			var lettuce = _add_cylinder(held_root, 0.22, 0.045, Color("#8dcf72"))
			lettuce.rotation_degrees.x = 90
			lettuce.scale = Vector3(1.12, 1.0, 0.85)
		"tomato":
			var tomato = _add_cylinder(held_root, 0.18, 0.045, Color("#e96161"))
			tomato.rotation_degrees.x = 90
		_:
			_add_box(held_root, Vector3(0.30, 0.16, 0.30), Color("#f3d8dd"))

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * MOUSE_SENS)
		camera.rotation.x = clamp(
			camera.rotation.x - event.relative.y * MOUSE_SENS,
			deg_to_rad(-75.0),
			deg_to_rad(75.0)
		)

	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		elif event.keycode == KEY_E:
			_try_interact()

	if event is InputEventMouseButton and event.pressed:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _physics_process(delta: float) -> void:
	var input_vec := Vector2.ZERO
	if Input.is_key_pressed(KEY_A):
		input_vec.x -= 1.0
	if Input.is_key_pressed(KEY_D):
		input_vec.x += 1.0
	if Input.is_key_pressed(KEY_W):
		input_vec.y -= 1.0
	if Input.is_key_pressed(KEY_S):
		input_vec.y += 1.0

	input_vec = input_vec.normalized()

	var forward := -global_transform.basis.z
	var right := global_transform.basis.x
	forward.y = 0.0
	right.y = 0.0

	var move_dir := (right * input_vec.x + forward * -input_vec.y).normalized()
	velocity.x = move_dir.x * SPEED
	velocity.z = move_dir.z * SPEED

	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	else:
		velocity.y = -0.2

	if input_vec.length() > 0.1:
		bob_time += delta * 8.0
	else:
		bob_time = lerp(bob_time, 0.0, delta * 5.0)

	var bob := sin(bob_time) * 0.018
	camera.position.y = 1.55 + bob
	paw_left.position.y = -0.38 - bob * 0.7
	paw_right.position.y = -0.38 - bob * 0.7

	move_and_slide()

func get_interact_target():
	if not ray:
		return null

	ray.force_raycast_update()
	if ray.is_colliding():
		var target = ray.get_collider()
		if target and target.has_method("interact"):
			return target
	return null

func _try_interact() -> void:
	var target = get_interact_target()
	if target:
		_animate_paws()
		target.interact()

func _animate_paws() -> void:
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(paw_left, "position:z", -0.94, 0.10)
	tween.tween_property(paw_right, "position:z", -0.94, 0.10)
	tween.tween_property(held_root, "position:z", -1.00, 0.10)
	tween.chain().set_parallel(true)
	tween.tween_property(paw_left, "position:z", -0.72, 0.13)
	tween.tween_property(paw_right, "position:z", -0.72, 0.13)
	tween.tween_property(held_root, "position:z", -0.86, 0.13)
