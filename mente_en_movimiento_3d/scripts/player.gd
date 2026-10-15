extends CharacterBody3D

signal lane_changed(new_lane: int)

const LANES: Array[float] = [-2.4, 0.0, 2.4]
@export var lane_change_speed: float = 11.0
@export var jump_velocity: float = 8.0
@export var gravity: float = 22.0

var lane: int = 1
var jump_time: float = 0.0
var slide_time: float = 0.0
var is_sliding: bool = false
var visual_root: Node3D
var body_mesh: MeshInstance3D
var head_mesh: MeshInstance3D
var left_leg: MeshInstance3D
var right_leg: MeshInstance3D
var left_arm: MeshInstance3D
var right_arm: MeshInstance3D
var run_clock: float = 0.0

func _ready() -> void:
	name = "Player"
	position = Vector3(0, 0.0, 0)
	_build_character()
	_build_collision()

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		if velocity.y < 0.0:
			velocity.y = 0.0
			jump_time = 0.0
	if jump_time > 0.0:
		jump_time = maxf(0.0, jump_time - delta)
	if slide_time > 0.0:
		slide_time = maxf(0.0, slide_time - delta)
		if slide_time == 0.0:
			is_sliding = false
			_set_slide_visual(false)
	var target_x := LANES[lane]
	position.x = move_toward(position.x, target_x, lane_change_speed * delta)
	velocity.z = 0.0
	move_and_slide()
	_animate_run(delta)

func handle_game_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	match event.keycode:
		KEY_LEFT, KEY_A:
			lane = maxi(0, lane - 1)
			lane_changed.emit(lane)
		KEY_RIGHT, KEY_D:
			lane = mini(2, lane + 1)
			lane_changed.emit(lane)
		KEY_SPACE, KEY_UP, KEY_W:
			if is_on_floor() and not is_sliding:
				velocity.y = jump_velocity
				jump_time = 0.5
		KEY_DOWN, KEY_S:
			if is_on_floor() and slide_time <= 0.0:
				slide_time = 0.7
				is_sliding = true
				_set_slide_visual(true)

func _build_character() -> void:
	visual_root = Node3D.new()
	visual_root.name = "Visuals"
	add_child(visual_root)
	var blue := _mat(Color("#204C73"))
	var gold := _mat(Color("#F5C242"))
	var skin := _mat(Color("#E8B28C"))
	var white := _mat(Color("#F4F4F0"))
	var green := _mat(Color("#A4C366"))
	body_mesh = _box("Torso", Vector3(0, 1.12, 0), Vector3(0.62, 0.8, 0.34), blue, visual_root)
	var shirt_mark := _box("UniformStripe", Vector3(0, 1.12, -0.18), Vector3(0.44, 0.09, 0.025), green, visual_root)
	var logo := _box("UTSCMark", Vector3(0, 1.36, -0.185), Vector3(0.32, 0.12, 0.025), white, visual_root)
	head_mesh = _sphere("Head", Vector3(0, 1.78, 0), Vector3(0.29, 0.32, 0.29), skin, visual_root)
	var hair := _sphere("Hair", Vector3(0, 1.98, 0.025), Vector3(0.3, 0.17, 0.3), _mat(Color("#493326")), visual_root)
	left_arm = _box("LeftArm", Vector3(-0.4, 1.18, 0), Vector3(0.17, 0.52, 0.19), blue, visual_root)
	right_arm = _box("RightArm", Vector3(0.4, 1.18, 0), Vector3(0.17, 0.52, 0.19), blue, visual_root)
	left_leg = _box("LeftLeg", Vector3(-0.18, 0.48, 0), Vector3(0.2, 0.55, 0.23), blue, visual_root)
	right_leg = _box("RightLeg", Vector3(0.18, 0.48, 0), Vector3(0.2, 0.55, 0.23), blue, visual_root)
	_box("LeftShoe", Vector3(-0.18, 0.17, -0.08), Vector3(0.24, 0.12, 0.36), white, visual_root)
	_box("RightShoe", Vector3(0.18, 0.17, -0.08), Vector3(0.24, 0.12, 0.36), white, visual_root)
	# Small green companion floats beside the runner.
	_sphere("MoustricoVerde", Vector3(0.85, 1.2, 0.1), Vector3(0.2, 0.22, 0.2), green, visual_root)
	_sphere("GuideEyeL", Vector3(0.79, 1.24, -0.08), Vector3(0.045, 0.055, 0.035), _mat(Color.WHITE), visual_root)
	_sphere("GuideEyeR", Vector3(0.9, 1.24, -0.08), Vector3(0.045, 0.055, 0.035), _mat(Color.WHITE), visual_root)

func _build_collision() -> void:
	var collision := CollisionShape3D.new()
	collision.name = "CollisionShape3D"
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.32
	capsule.height = 1.8
	collision.shape = capsule
	collision.position.y = 0.9
	add_child(collision)

func _animate_run(delta: float) -> void:
	run_clock += delta * (12.0 if is_on_floor() else 3.0)
	if not is_sliding:
		left_leg.rotation.x = sin(run_clock) * 0.45 if is_on_floor() else 0.0
		right_leg.rotation.x = -sin(run_clock) * 0.45 if is_on_floor() else 0.0
		left_arm.rotation.x = -sin(run_clock) * 0.3
		right_arm.rotation.x = sin(run_clock) * 0.3
	if visual_root:
		visual_root.position.y = 0.04 * absf(sin(run_clock)) if is_on_floor() and not is_sliding else 0.0

func _set_slide_visual(sliding: bool) -> void:
	if not visual_root:
		return
	visual_root.scale = Vector3(1.0, 0.58, 1.0) if sliding else Vector3.ONE

func _mat(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.75
	return material

func _box(node_name: String, pos: Vector3, size: Vector3, material: Material, parent: Node3D) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	var mesh := BoxMesh.new()
	mesh.size = size
	instance.mesh = mesh
	instance.position = pos
	instance.material_override = material
	parent.add_child(instance)
	return instance

func _sphere(node_name: String, pos: Vector3, scale_value: Vector3, material: Material, parent: Node3D) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	var mesh := SphereMesh.new()
	mesh.radius = 0.5
	mesh.height = 1.0
	instance.mesh = mesh
	instance.position = pos
	instance.scale = scale_value * 2.0
	instance.material_override = material
	parent.add_child(instance)
	return instance
