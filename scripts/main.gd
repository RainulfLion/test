extends Node3D

@export var move_speed: float = 12.0
@export var mouse_sensitivity: float = 0.0025
@export var vertical_speed: float = 8.0

@onready var camera: Camera3D = $Camera3D
@onready var ray_cast: RayCast3D = $Camera3D/RayCast3D
@onready var voxel_world: VoxelWorld = $VoxelWorld

var yaw := 0.0
var pitch := 0.0
var mouse_captured := true

func _ready() -> void:
    if ray_cast:
        ray_cast.target_position = Vector3(0, 0, -10)
        ray_cast.enabled = true
    Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
    yaw = rotation.y
    pitch = camera.rotation.x

func _physics_process(delta: float) -> void:
    var input_vector := Vector2.ZERO
    if Input.is_action_pressed("move_forward"):
        input_vector.y -= 1.0
    if Input.is_action_pressed("move_backward"):
        input_vector.y += 1.0
    if Input.is_action_pressed("move_left"):
        input_vector.x -= 1.0
    if Input.is_action_pressed("move_right"):
        input_vector.x += 1.0
    if input_vector.length_squared() > 0.0:
        input_vector = input_vector.normalized()
    var basis := Basis(Vector3.UP, yaw)
    var forward := -basis.z
    var right := basis.x
    var direction := (forward * input_vector.y) + (right * input_vector.x)
    global_position += direction * move_speed * delta
    if Input.is_action_pressed("jump"):
        global_position.y += vertical_speed * delta

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventMouseMotion and mouse_captured:
        yaw -= event.relative.x * mouse_sensitivity
        pitch -= event.relative.y * mouse_sensitivity
        pitch = clamp(pitch, -1.2, 1.2)
        rotation.y = yaw
        camera.rotation.x = pitch
    elif event.is_action_pressed("action_toggle_mouse") and event.is_pressed() and not event.is_echo():
        mouse_captured = !mouse_captured
        Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED if mouse_captured else Input.MOUSE_MODE_VISIBLE)
    elif event.is_action_pressed("action_interact") and event.is_pressed() and not event.is_echo():
        _handle_interaction(false)
    elif event.is_action_pressed("action_alt_interact") and event.is_pressed() and not event.is_echo():
        _handle_interaction(true)

func _handle_interaction(place_block: bool) -> void:
    if not ray_cast or not ray_cast.is_colliding():
        return
    if not is_instance_valid(voxel_world):
        return
    var collision_point := ray_cast.get_collision_point()
    var normal := ray_cast.get_collision_normal()
    if place_block:
        var target := collision_point + normal * (voxel_world.voxel_size * 0.5)
        voxel_world.set_block_global(target, 1)
    else:
        var target := collision_point - normal * (voxel_world.voxel_size * 0.5)
        voxel_world.remove_block_global(target)
