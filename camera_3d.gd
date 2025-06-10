@tool
extends Camera3D

@export var sensitivity_zoom = 0.05
var sensitivity_pan = 0.0625
var state_panning = false
var inhibit_panning = false
var pos_to: Vector3
var speed := 1.0
var fps_speed_mod := 1.0
var pointer_normal: Vector3
var init_pos: Vector3

func _ready() -> void:
	pos_to = global_position
	init_pos = global_position

func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return

	fps_speed_mod = delta * 60.0

	if pos_to.z < 0.00125:
		pos_to.z = 0.00125

	state_panning = false

	speed = global_position.z / 16.0
	if Input.is_action_just_pressed("zoom_in"):
		pos_to += speed * fps_speed_mod * pointer_normal

	if Input.is_action_pressed("zoom_in_cont"):
		pos_to += speed * fps_speed_mod * pointer_normal / 2

	if Input.is_action_just_pressed("zoom_out"):
		pos_to -= speed * fps_speed_mod  * pointer_normal

	if Input.is_action_pressed("zoom_out_cont"):
		pos_to -= speed * fps_speed_mod  * pointer_normal / 2

	if Input.is_action_just_pressed("reset_view"):
		pos_to = init_pos

	if Input.is_action_pressed("pan") and not inhibit_panning:
		state_panning = true

	var pan_v = Input.get_vector('pan_left', 'pan_right', 'pan_down', 'pan_up') * (0.0 if inhibit_panning else 1.0)

	pos_to.x += speed * fps_speed_mod * pan_v.x * sensitivity_pan * 8
	pos_to.y += speed * fps_speed_mod * pan_v.y * sensitivity_pan * 8

	global_position = lerp(global_position, pos_to, 0.4 * fps_speed_mod)

func _input(event):
	inhibit_panning = Input.is_key_pressed(KEY_CTRL)
	inhibit_panning = Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) || inhibit_panning

	if state_panning and not inhibit_panning:
		if event is InputEventMouseMotion:
			#print("Mouse Motion at: ", event.relative)
			pos_to.y += event.relative.y * sensitivity_pan * speed
			pos_to.x -= event.relative.x * sensitivity_pan * speed

	if event is InputEventMouseMotion:
		#var from = project_ray_origin(event.position)
		pointer_normal = project_ray_normal(event.position) * 1
		pass

	if event is InputEventKey:
		pointer_normal = Vector3(0,0,-1)
