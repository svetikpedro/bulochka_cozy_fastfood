extends CharacterBody3D

const INTERACT_DISTANCE := 1.8
const FOOD_VISUALS = preload("res://scripts/food_visuals.gd")

var camera: Camera3D
var ray: RayCast3D
var paw_left: MeshInstance3D
var paw_right: MeshInstance3D
var held_root: Node3D
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
	return FOOD_VISUALS.plastic(color)

func _create_paws() -> void:
	paw_left = _make_paw(Vector3(-0.38, -0.36, -0.70), -14.0)
	paw_right = _make_paw(Vector3(0.38, -0.36, -0.70), 14.0)

func _make_paw(pos: Vector3, roll: float) -> MeshInstance3D:
	var paw := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.15
	capsule.height = 0.48
	paw.mesh = capsule
	var mat := FOOD_VISUALS.plastic(Color("#fff7ec"))
	mat.roughness = 0.78
	paw.material_override = mat
	paw.position = pos
	paw.rotation_degrees = Vector3(72, 0, roll)
	camera.add_child(paw)
	return paw

func _create_held_root() -> void:
	held_root = Node3D.new()
	held_root.position = Vector3(0, -0.31, -0.86)
	camera.add_child(held_root)

func _clear_held_visual() -> void:
	for child in held_root.get_children():
		child.queue_free()

func set_held_item(item_id: String, _display_name: String, _color: Color) -> void:
	_clear_held_visual()
	if item_id == "":
		return
	FOOD_VISUALS.create_held_item(held_root, item_id)

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
	paw_left.position.y = -0.36 - bob * 0.7
	paw_right.position.y = -0.36 - bob * 0.7

	move_and_slide()

func get_interact_target():
	if not ray or not camera:
		return null

	ray.force_raycast_update()
	if not ray.is_colliding():
		return null

	var target = ray.get_collider()
	if not target or not target.has_method("interact"):
		return null

	if camera.global_position.distance_to(ray.get_collision_point()) > INTERACT_DISTANCE:
		return null

	return target

func _try_interact() -> void:
	var target = get_interact_target()
	if target:
		_animate_paws()
		target.interact()

func _animate_paws() -> void:
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(paw_left, "position:z", -0.92, 0.10)
	tween.tween_property(paw_right, "position:z", -0.92, 0.10)
	tween.tween_property(held_root, "position:z", -0.98, 0.10)
	tween.chain().set_parallel(true)
	tween.tween_property(paw_left, "position:z", -0.70, 0.13)
	tween.tween_property(paw_right, "position:z", -0.70, 0.13)
	tween.tween_property(held_root, "position:z", -0.86, 0.13)
