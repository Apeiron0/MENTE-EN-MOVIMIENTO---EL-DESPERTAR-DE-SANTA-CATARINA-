extends Node3D

const PLAYER_SCENE: PackedScene = preload("res://scenes/Player.tscn")
const LANES: Array[float] = [-2.4, 0.0, 2.4]
const LEVEL_NAMES: Array[String] = ["Aulas de Clase", "Oficinas Administrativas", "Talleres Industriales", "Plaza Central UTSC", "Auditorio: Jefe Final"]
const LEVEL_COLORS: Array[Color] = [Color("#DCCBAA"), Color("#536B86"), Color("#737C82"), Color("#8AB66B"), Color("#333E54")]

var player: CharacterBody3D
var camera: Camera3D
var world_root: Node3D
var objects: Array[Dictionary] = []
var vitality: float = 100.0
var focus_points: int = 0
var correct_answers: int = 0
var questions_answered: int = 0
var distance_travelled: float = 0.0
var world_speed: float = 18.0
var spawn_clock: float = 0.0
var water_clock: float = 0.0
var quiz_clock: float = 0.0
var level_index: int = 0
var quiz_active: bool = false
var current_question: Dictionary = {}
var game_over: bool = false
var invincible_time: float = 0.0
var feedback_time: float = 0.0
var feedback_text: String = ""
var hud: CanvasLayer
var vitality_bar: ProgressBar
var score_label: Label
var level_label: Label
var feedback_label: Label
var quiz_panel: PanelContainer
var question_label: Label
var option_a: Button
var option_b: Button
var game_over_panel: PanelContainer
var game_over_label: Label
var distance_label: Label
var scenery_segments: Array[Node3D] = []
var segment_length: float = 35.0

var questions: Array[Dictionary] = [
	{"q":"¿Qué hábito ayuda a reducir la fatiga al estudiar?", "a":"Hacer pausas activas", "b":"No levantarse nunca", "correct":1, "tip":"Las pausas activas ayudan a cambiar de postura y recuperar la atención."},
	{"q":"¿Qué ayuda a cuidar la postura frente a la computadora?", "a":"Ajustar la postura y moverse", "b":"Encoger los hombros todo el día", "correct":1, "tip":"Ajusta tu postura y cambia de posición regularmente."},
	{"q":"¿Qué conviene hacer después de mucho tiempo sentado?", "a":"Levantarse y moverse", "b":"Seguir sentado sin descanso", "correct":1, "tip":"Interrumpe los periodos largos sentado con movimiento."},
	{"q":"¿Cómo conviene levantar una caja pesada?", "a":"Doblar las rodillas y acercar la carga", "b":"Girar la espalda mientras se levanta", "correct":1, "tip":"Mantén la carga cerca y evita girar el tronco bajo esfuerzo."},
	{"q":"¿Qué hábito favorece el descanso mental?", "a":"Dormir lo suficiente", "b":"Evitar dormir antes de un examen", "correct":1, "tip":"El descanso adecuado ayuda a la atención y al manejo del estrés."},
	{"q":"¿Qué puede ayudar a manejar el estrés?", "a":"Respirar con calma y hacer pausas", "b":"Ignorar siempre el cansancio", "correct":1, "tip":"La respiración pausada y las pausas pueden ayudar a regular el estrés."},
	{"q":"¿Qué beneficio puede aportar la actividad física regular?", "a":"Apoyar la salud física y mental", "b":"Eliminar la necesidad de dormir", "correct":1, "tip":"La actividad física contribuye al bienestar general, pero no sustituye el descanso."}
]

func _ready() -> void:
	_build_world()
	_build_player()
	_build_hud()
	_update_hud()

func _process(delta: float) -> void:
	if game_over:
		return
	if feedback_time > 0.0:
		feedback_time -= delta
		if feedback_time <= 0.0 and not quiz_active:
			feedback_label.visible = false
	if quiz_active:
		return
	distance_travelled += world_speed * delta
	world_speed = minf(29.0, world_speed + 0.025 * delta)
	spawn_clock += delta
	water_clock += delta
	quiz_clock += delta
	if invincible_time > 0.0:
		invincible_time -= delta
	if spawn_clock >= maxf(0.8, 1.55 - level_index * 0.12):
		spawn_clock = 0.0
		_spawn_object("obstacle")
	if water_clock >= 4.2:
		water_clock = 0.0
		_spawn_object("water")
	if quiz_clock >= maxf(6.0, 10.0 - level_index * 0.9):
		quiz_clock = 0.0
		_spawn_object("quiz")
	_update_objects(delta)
	_update_scenery(delta)
	_update_level()
	_update_camera(delta)
	_update_hud()

func _unhandled_input(event: InputEvent) -> void:
	if game_over:
		if event is InputEventKey and event.pressed and event.keycode in [KEY_ENTER, KEY_SPACE]:
			get_tree().reload_current_scene()
		return
	if quiz_active:
		return
	player.handle_game_input(event)

func _build_world() -> void:
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color("#6EA8D1")
	sky_material.sky_horizon_color = Color("#E8D9B9")
	sky_material.ground_bottom_color = Color("#3F514B")
	sky_material.ground_horizon_color = Color("#B6B59A")
	sky.sky_material = sky_material
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#D9E6F1")
	env.ambient_light_energy = 0.65
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.environment = env
	add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, -28, 0)
	sun.light_energy = 1.35
	sun.shadow_enabled = true
	add_child(sun)
	world_root = Node3D.new()
	world_root.name = "World"
	add_child(world_root)
	# A fixed physical floor supports CharacterBody3D while visual segments recycle.
	var ground := StaticBody3D.new()
	ground.name = "GroundCollider"
	var ground_shape := CollisionShape3D.new()
	var ground_box := BoxShape3D.new()
	ground_box.size = Vector3(10.5, 0.4, 180.0)
	ground_shape.shape = ground_box
	ground_shape.position = Vector3(0, -0.2, -65.0)
	ground.add_child(ground_shape)
	world_root.add_child(ground)
	camera = Camera3D.new()
	camera.name = "Camera3D"
	camera.position = Vector3(0, 5.5, 8.5)
	camera.rotation_degrees = Vector3(-15, 0, 0)
	camera.current = true
	add_child(camera)
	for i in range(4):
		var segment := _create_segment(-float(i) * segment_length)
		scenery_segments.append(segment)

func _build_player() -> void:
	player = PLAYER_SCENE.instantiate() as CharacterBody3D
	player.position = Vector3(0, 0, 0)
	add_child(player)

func _create_segment(z_position: float) -> Node3D:
	var segment := Node3D.new()
	segment.position.z = z_position
	world_root.add_child(segment)
	var floor_color := LEVEL_COLORS[level_index]
	_add_box(segment, "Floor", Vector3(0, -0.18, 0), Vector3(10.5, 0.35, segment_length), _material(floor_color))
	var tile_mat := _material(Color("#F1E5CF") if level_index == 0 else Color("#687D92"))
	for z in range(-16, 18, 4):
		_add_box(segment, "FloorTile", Vector3(0, 0.005, float(z)), Vector3(10.2, 0.02, 0.035), tile_mat)
	for x in [-5.1, 5.1]:
		_add_box(segment, "SideWall", Vector3(x, 1.6, 0), Vector3(0.25, 3.2, segment_length), _material(Color("#B9C4C7")))
	for x in [-3.6, 3.6]:
		_add_box(segment, "LaneMarker", Vector3(x, 0.025, 0), Vector3(0.035, 0.025, segment_length), _material(Color("#F5C242")))
	# Classroom furniture and windows provide recognizable depth cues.
	if level_index == 0:
		for z in [-12.0, 0.0, 12.0]:
			for x in [-4.2, 4.2]:
				_add_box(segment, "Window", Vector3(x, 2.0, z), Vector3(0.08, 1.25, 2.2), _material(Color("#7DB8D5")))
				_add_box(segment, "WindowFrame", Vector3(x * 0.99, 2.0, z), Vector3(0.13, 1.4, 0.12), _material(Color("#F6E8CE")))
		for z in [-9.0, 5.0]:
			for x in [-4.1, 4.1]:
				_add_box(segment, "ClassBench", Vector3(x, 0.55, z), Vector3(1.15, 0.12, 0.7), _material(Color("#8A6547")))
				_add_box(segment, "BenchLeg", Vector3(x, 0.27, z), Vector3(0.08, 0.5, 0.08), _material(Color("#44505A")))
	elif level_index == 1:
		for z in [-12.0, 0.0, 12.0]:
			for x in [-4.15, 4.15]:
				_add_box(segment, "OfficeDesk", Vector3(x, 0.8, z), Vector3(1.25, 0.12, 0.8), _material(Color("#A77D54")))
				_add_box(segment, "Monitor", Vector3(x, 1.25, z - 0.15), Vector3(0.55, 0.55, 0.1), _material(Color("#263746")))
	elif level_index == 2:
		for z in [-12.0, 0.0, 12.0]:
			_add_box(segment, "IndustrialPipe", Vector3(-4.2, 2.7, z), Vector3(0.25, 0.25, 3.0), _material(Color("#D8A42B")))
			_add_box(segment, "Machine", Vector3(4.15, 0.9, z), Vector3(1.0, 1.8, 1.4), _material(Color("#59656D")))
	elif level_index == 3:
		for z in [-12.0, 0.0, 12.0]:
			for x in [-4.3, 4.3]:
				_add_box(segment, "CampusPlanter", Vector3(x, 0.25, z), Vector3(0.8, 0.5, 0.8), _material(Color("#8A6B4F")))
				_add_sphere(segment, "CampusShrub", Vector3(x, 0.9, z), Vector3(0.7, 0.85, 0.7), _material(Color("#5D9A60")))
	else:
		for z in [-12.0, 0.0, 12.0]:
			for x in [-4.2, 4.2]:
				_add_box(segment, "AuditoriumSeat", Vector3(x, 0.45, z), Vector3(1.0, 0.85, 0.8), _material(Color("#6C3345")))
	return segment

func _update_scenery(delta: float) -> void:
	for segment in scenery_segments:
		segment.position.z += world_speed * delta
		if segment.position.z > segment_length:
			segment.position.z -= segment_length * scenery_segments.size()

func _update_level() -> void:
	var new_level := mini(4, int(distance_travelled / 260.0))
	if new_level != level_index:
		level_index = new_level
		for segment in scenery_segments:
			segment.queue_free()
		scenery_segments.clear()
		for i in range(4):
			scenery_segments.append(_create_segment(-float(i) * segment_length))
		feedback_text = "Nivel %d: %s" % [level_index + 1, LEVEL_NAMES[level_index]]
		feedback_label.text = feedback_text
		feedback_label.visible = true
		feedback_time = 2.5
		if level_index == 4:
			_spawn_object("boss")

func _update_camera(delta: float) -> void:
	var target := Vector3(player.position.x * 0.25, 5.0, 8.5)
	camera.position = camera.position.lerp(target, minf(1.0, delta * 3.5))
	camera.look_at(Vector3(player.position.x * 0.2, 1.1, -7.0), Vector3.UP)

func _spawn_object(kind: String) -> void:
	var lane := randi_range(0, 2)
	var node := Node3D.new()
	node.name = kind.capitalize()
	node.position = Vector3(LANES[lane], 0.0, -48.0)
	world_root.add_child(node)
	var material: Material
	match kind:
		"obstacle":
			material = _material(Color("#204C73"))
			_add_box(node, "Backpack", Vector3(0, 0.48, 0), Vector3(0.85, 0.95, 0.65), material)
			_add_box(node, "Pocket", Vector3(0, 0.25, -0.34), Vector3(0.42, 0.32, 0.08), _material(Color("#F5C242")))
		"water":
			_add_cylinder(node, "WaterBottle", Vector3(0, 0.55, 0), 0.22, 0.95, _material(Color("#00A8FF")))
			_add_cylinder(node, "BottleCap", Vector3(0, 1.08, 0), 0.12, 0.15, _material(Color("#204C73")))
		"quiz":
			_add_box(node, "QuizBarrier", Vector3(0, 1.15, 0), Vector3(1.95, 2.3, 0.35), _material(Color("#F5C242")))
			_add_box(node, "BarrierStripe", Vector3(0, 1.15, -0.2), Vector3(1.65, 0.18, 0.06), _material(Color("#204C73")))
		"boss":
			_add_sphere(node, "Sedentarismo", Vector3(0, 2.3, 0), Vector3(1.5, 1.3, 0.9), _material(Color("#858A93")))
			_add_box(node, "MonitorEyeL", Vector3(-0.48, 2.45, -0.82), Vector3(0.4, 0.35, 0.12), _material(Color("#202C3B")))
			_add_box(node, "MonitorEyeR", Vector3(0.48, 2.45, -0.82), Vector3(0.4, 0.35, 0.12), _material(Color("#202C3B")))
	objects.append({"kind": kind, "node": node, "lane": lane, "question_index": randi_range(0, questions.size() - 1), "hit": false})

func _update_objects(delta: float) -> void:
	for i in range(objects.size() - 1, -1, -1):
		var obj: Dictionary = objects[i]
		var node: Node3D = obj.node
		node.position.z += world_speed * delta
		if not bool(obj.hit) and absf(node.position.z - player.position.z) < 1.0 and int(obj.lane) == player.lane:
			match str(obj.kind):
				"obstacle":
					if player.jump_time <= 0.0 and player.slide_time <= 0.0 and invincible_time <= 0.0:
						vitality -= 18.0
						_show_feedback("¡Cuidado con el obstáculo! -18 vitalidad", 1.5)
						if vitality <= 0.0:
							_end_game(false)
					obj.hit = true
				"water":
					vitality = minf(100.0, vitality + 20.0)
					focus_points += 5
					_show_feedback("¡Botella recogida! +20 vitalidad", 1.4)
					obj.hit = true
				"quiz":
					obj.hit = true
					objects[i] = obj
					_open_quiz(int(obj.question_index))
					return
				"boss":
					obj.hit = true
					_open_boss_challenge()
		if node.position.z > 12.0 or bool(obj.hit):
			node.queue_free()
			objects.remove_at(i)
		else:
			objects[i] = obj

func _open_quiz(index: int) -> void:
	quiz_active = true
	current_question = questions[index]
	question_label.text = str(current_question.q)
	option_a.text = "1  " + str(current_question.a)
	option_b.text = "2  " + str(current_question.b)
	quiz_panel.visible = true
	option_a.grab_focus()

func _answer_quiz(answer: int) -> void:
	if not quiz_active:
		return
	var answering_boss: bool = str(current_question.q).begins_with("JEFE FINAL:")
	questions_answered += 1
	if answer == int(current_question.correct):
		correct_answers += 1
		focus_points += 20
		vitality = minf(100.0, vitality + 8.0)
		world_speed = minf(41.0, world_speed + 1.5)
		_show_feedback("¡Correcto! +20 enfoque. " + str(current_question.tip), 3.2)
	else:
		vitality -= 15.0
		_show_feedback("Respuesta incorrecta. " + str(current_question.tip), 3.2)
	quiz_active = false
	quiz_panel.visible = false
	if answering_boss and answer == int(current_question.correct):
		_end_game(true)
	elif vitality <= 0.0:
		_end_game(false)
	_update_hud()

func _open_boss_challenge() -> void:
	quiz_active = true
	current_question = {"q":"JEFE FINAL: ¿Qué ayuda a recuperar la calma?", "a":"Respirar lenta y conscientemente", "b":"Aguantar la respiración todo el tiempo", "correct":1, "tip":"Respira con calma y a un ritmo cómodo."}
	question_label.text = str(current_question.q)
	option_a.text = "1  " + str(current_question.a)
	option_b.text = "2  " + str(current_question.b)
	quiz_panel.visible = true

func _end_game(won: bool) -> void:
	game_over = true
	quiz_active = false
	quiz_panel.visible = false
	game_over_panel.visible = true
	if won:
		game_over_label.text = "¡CAMPUS RECUPERADO!\nEnfoque: %d   Respuestas correctas: %d/%d\n¡Moverse alegra el corazón!" % [focus_points, correct_answers, questions_answered]
	else:
		game_over_label.text = "VITALIDAD AGOTADA\nEnfoque: %d   Respuestas correctas: %d/%d\nPulsa ENTER para intentarlo de nuevo." % [focus_points, correct_answers, questions_answered]

func _show_feedback(message: String, duration: float) -> void:
	feedback_text = message
	feedback_label.text = message
	feedback_label.visible = true
	feedback_time = duration

func _update_hud() -> void:
	if vitality_bar:
		vitality_bar.value = vitality
		score_label.text = "Enfoque: %d   Respuestas correctas: %d/%d" % [focus_points, correct_answers, questions_answered]
		level_label.text = "Nivel %d/5 · %s" % [level_index + 1, LEVEL_NAMES[level_index]]
		distance_label.text = "Distancia: %dm" % int(distance_travelled)

func _build_hud() -> void:
	hud = CanvasLayer.new()
	hud.name = "HUD"
	add_child(hud)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.add_child(root)
	var top := PanelContainer.new()
	top.position = Vector2(20, 18)
	top.custom_minimum_size = Vector2(370, 115)
	root.add_child(top)
	var vbox := VBoxContainer.new()
	top.add_child(vbox)
	var title := Label.new()
	title.text = "MENTE EN MOVIMIENTO"
	title.add_theme_font_size_override("font_size", 21)
	vbox.add_child(title)
	level_label = Label.new()
	vbox.add_child(level_label)
	vitality_bar = ProgressBar.new()
	vitality_bar.max_value = 100
	vitality_bar.value = 100
	vitality_bar.custom_minimum_size.y = 20
	vbox.add_child(vitality_bar)
	score_label = Label.new()
	vbox.add_child(score_label)
	distance_label = Label.new()
	distance_label.position = Vector2(20, 145)
	root.add_child(distance_label)
	feedback_label = Label.new()
	feedback_label.position = Vector2(280, 24)
	feedback_label.size = Vector2(720, 70)
	feedback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	feedback_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	feedback_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	feedback_label.add_theme_font_size_override("font_size", 18)
	feedback_label.visible = false
	root.add_child(feedback_label)
	quiz_panel = PanelContainer.new()
	quiz_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	quiz_panel.position = Vector2(-300, -155)
	quiz_panel.custom_minimum_size = Vector2(600, 310)
	root.add_child(quiz_panel)
	var quiz_box := VBoxContainer.new()
	quiz_panel.add_child(quiz_box)
	var quiz_title := Label.new()
	quiz_title.text = "BARRICADA DE SALUD"
	quiz_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	quiz_title.add_theme_font_size_override("font_size", 24)
	quiz_box.add_child(quiz_title)
	question_label = Label.new()
	question_label.custom_minimum_size.y = 80
	question_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	question_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	question_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	quiz_box.add_child(question_label)
	option_a = Button.new()
	option_a.custom_minimum_size.y = 55
	option_a.pressed.connect(_answer_quiz.bind(1))
	quiz_box.add_child(option_a)
	option_b = Button.new()
	option_b.custom_minimum_size.y = 55
	option_b.pressed.connect(_answer_quiz.bind(2))
	quiz_box.add_child(option_b)
	var hint := Label.new()
	hint.text = "Elige la respuesta correcta para recuperar vitalidad y enfoque."
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	quiz_box.add_child(hint)
	quiz_panel.visible = false
	game_over_panel = PanelContainer.new()
	game_over_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	game_over_panel.position = Vector2(-300, -120)
	game_over_panel.custom_minimum_size = Vector2(600, 240)
	root.add_child(game_over_panel)
	var over_box := VBoxContainer.new()
	game_over_panel.add_child(over_box)
	game_over_label = Label.new()
	game_over_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	game_over_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	game_over_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	game_over_label.custom_minimum_size.y = 120
	over_box.add_child(game_over_label)
	var restart := Button.new()
	restart.text = "Reiniciar (Enter)"
	restart.pressed.connect(func(): get_tree().reload_current_scene())
	over_box.add_child(restart)
	game_over_panel.visible = false

func _add_box(parent: Node3D, node_name: String, pos: Vector3, size: Vector3, material: Material) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = node_name
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_instance.mesh = mesh
	mesh_instance.position = pos
	mesh_instance.material_override = material
	parent.add_child(mesh_instance)
	return mesh_instance

func _add_sphere(parent: Node3D, node_name: String, pos: Vector3, size: Vector3, material: Material) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = node_name
	var mesh := SphereMesh.new()
	mesh.radius = 0.5
	mesh.height = 1.0
	mesh_instance.mesh = mesh
	mesh_instance.position = pos
	mesh_instance.scale = size * 2.0
	mesh_instance.material_override = material
	parent.add_child(mesh_instance)
	return mesh_instance

func _add_cylinder(parent: Node3D, node_name: String, pos: Vector3, radius: float, height: float, material: Material) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = node_name
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh_instance.mesh = mesh
	mesh_instance.position = pos
	mesh_instance.material_override = material
	parent.add_child(mesh_instance)
	return mesh_instance

func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.78
	return material
