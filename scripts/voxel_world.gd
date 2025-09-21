extends Node3D
class_name VoxelWorld

@export var chunk_size: Vector3i = Vector3i(16, 16, 16)
@export var render_distance: Vector2i = Vector2i(2, 2)
@export var voxel_size: float = 1.0
@export var seed: int = 1337
@export var noise_scale: float = 64.0
@export var height_scale: float = 18.0
@export var ground_level: int = 4

const FACE_DIRECTIONS: Array = [
    Vector3i.RIGHT,
    Vector3i.LEFT,
    Vector3i.UP,
    Vector3i.DOWN,
    Vector3i.BACK,
    Vector3i.FORWARD,
]

const FACE_NORMALS: Array = [
    Vector3(1, 0, 0),
    Vector3(-1, 0, 0),
    Vector3(0, 1, 0),
    Vector3(0, -1, 0),
    Vector3(0, 0, 1),
    Vector3(0, 0, -1),
]

const FACE_VERTICES: Array = [
    [Vector3(1, 0, 0), Vector3(1, 1, 0), Vector3(1, 1, 1), Vector3(1, 0, 1)], # +X
    [Vector3(0, 0, 0), Vector3(0, 0, 1), Vector3(0, 1, 1), Vector3(0, 1, 0)], # -X
    [Vector3(0, 1, 0), Vector3(0, 1, 1), Vector3(1, 1, 1), Vector3(1, 1, 0)], # +Y
    [Vector3(0, 0, 0), Vector3(1, 0, 0), Vector3(1, 0, 1), Vector3(0, 0, 1)], # -Y
    [Vector3(0, 0, 1), Vector3(1, 0, 1), Vector3(1, 1, 1), Vector3(0, 1, 1)], # +Z
    [Vector3(0, 0, 0), Vector3(0, 1, 0), Vector3(1, 1, 0), Vector3(1, 0, 0)], # -Z
]

const FACE_UVS: Array = [
    [Vector2(0, 0), Vector2(0, 1), Vector2(1, 1), Vector2(1, 0)],
    [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)],
    [Vector2(0, 0), Vector2(0, 1), Vector2(1, 1), Vector2(1, 0)],
    [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)],
    [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)],
    [Vector2(0, 0), Vector2(0, 1), Vector2(1, 1), Vector2(1, 0)],
]

const FACE_TRIANGLES := [
    PackedInt32Array([0, 1, 2]),
    PackedInt32Array([0, 2, 3]),
]

var noise := FastNoiseLite.new()
var chunks: Dictionary = {}
var chunk_meshes: Dictionary = {}
var chunk_material := StandardMaterial3D.new()

func _ready() -> void:
    noise.seed = seed
    noise.noise_type = FastNoiseLite.TYPE_OPEN_SIMPLEX_2
    noise.frequency = 1.0 / max(0.001, noise_scale)
    chunk_material.roughness = 1.0
    chunk_material.metallic = 0.0
    chunk_material.albedo_color = Color(0.45, 0.7, 0.4)
    generate_initial_world()

func generate_initial_world() -> void:
    for x in range(-render_distance.x, render_distance.x + 1):
        for z in range(-render_distance.y, render_distance.y + 1):
            var coord := Vector3i(x, 0, z)
            generate_chunk(coord)

func generate_chunk(chunk_coord: Vector3i) -> void:
    if chunks.has(chunk_coord):
        return
    var block_map: Dictionary = {}
    var base := chunk_to_block_origin(chunk_coord)
    for lx in range(chunk_size.x):
        for lz in range(chunk_size.z):
            var world_x := base.x + lx
            var world_z := base.z + lz
            var surface_height := int(round((noise.get_noise_2d(float(world_x), float(world_z)) + 1.0) * 0.5 * height_scale)) + ground_level
            for ly in range(chunk_size.y):
                var world_y := base.y + ly
                if world_y <= surface_height:
                    block_map[Vector3i(lx, ly, lz)] = 1
    chunks[chunk_coord] = block_map
    update_chunk_mesh(chunk_coord)

func update_chunk_mesh(chunk_coord: Vector3i) -> void:
    var block_map: Dictionary = chunks.get(chunk_coord, null)
    if block_map == null:
        return
    if chunk_meshes.has(chunk_coord):
        var old := chunk_meshes[chunk_coord]
        if is_instance_valid(old):
            old.queue_free()
        chunk_meshes.erase(chunk_coord)
    var st := SurfaceTool.new()
    st.begin(Mesh.PRIMITIVE_TRIANGLES)
    for local_pos in block_map.keys():
        var block_type := block_map[local_pos]
        if block_type == 0:
            continue
        for face_index in range(FACE_DIRECTIONS.size()):
            var neighbor := local_pos + FACE_DIRECTIONS[face_index]
            if block_map.has(neighbor):
                if block_map[neighbor] != 0:
                    continue
            if neighbor.x < 0 or neighbor.x >= chunk_size.x or neighbor.y < 0 or neighbor.y >= chunk_size.y or neighbor.z < 0 or neighbor.z >= chunk_size.z:
                var neighbor_chunk := chunk_coord + FACE_DIRECTIONS[face_index]
                if chunks.has(neighbor_chunk):
                    var neighbor_map: Dictionary = chunks[neighbor_chunk]
                    if neighbor_map.has(local_wrapped_position(neighbor)) and neighbor_map[local_wrapped_position(neighbor)] != 0:
                        continue
            var vertices := FACE_VERTICES[face_index]
            var normal := FACE_NORMALS[face_index]
            var uvs := FACE_UVS[face_index]
            for tri in FACE_TRIANGLES:
                for index in tri:
                    var vertex := (Vector3(local_pos) + vertices[index]) * voxel_size
                    st.set_normal(normal)
                    st.set_uv(uvs[index])
                    st.add_vertex(vertex)
    if st.get_vertex_count() == 0:
        return
    var mesh := st.commit()
    var mesh_instance := MeshInstance3D.new()
    mesh_instance.mesh = mesh
    mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
    mesh_instance.name = "Chunk_%s_%s_%s" % [chunk_coord.x, chunk_coord.y, chunk_coord.z]
    mesh_instance.position = chunk_to_world(chunk_coord)
    mesh_instance.material_override = chunk_material
    add_child(mesh_instance)
    chunk_meshes[chunk_coord] = mesh_instance

func local_wrapped_position(local_pos: Vector3i) -> Vector3i:
    var x := (local_pos.x % chunk_size.x + chunk_size.x) % chunk_size.x
    var y := (local_pos.y % chunk_size.y + chunk_size.y) % chunk_size.y
    var z := (local_pos.z % chunk_size.z + chunk_size.z) % chunk_size.z
    return Vector3i(x, y, z)

func chunk_to_block_origin(chunk_coord: Vector3i) -> Vector3i:
    return Vector3i(
        chunk_coord.x * chunk_size.x,
        chunk_coord.y * chunk_size.y,
        chunk_coord.z * chunk_size.z
    )

func chunk_to_world(chunk_coord: Vector3i) -> Vector3:
    var origin := chunk_to_block_origin(chunk_coord)
    return Vector3(origin.x, origin.y, origin.z) * voxel_size

func world_to_block(world_position: Vector3) -> Vector3i:
    var scaled := world_position / voxel_size
    return Vector3i(floor(scaled.x), floor(scaled.y), floor(scaled.z))

func world_to_chunk(world_position: Vector3) -> Dictionary:
    var block := world_to_block(world_position)
    var chunk_coord := Vector3i(
        int(floor(float(block.x) / chunk_size.x)),
        int(floor(float(block.y) / chunk_size.y)),
        int(floor(float(block.z) / chunk_size.z))
    )
    var origin := chunk_to_block_origin(chunk_coord)
    var local := block - origin
    return {
        "chunk": chunk_coord,
        "local": local,
        "block": block,
    }

func ensure_chunk(chunk_coord: Vector3i) -> void:
    if chunks.has(chunk_coord):
        return
    generate_chunk(chunk_coord)

func set_block_global(world_position: Vector3, block_type: int) -> void:
    if block_type <= 0:
        remove_block_global(world_position)
        return
    var data := world_to_chunk(world_position)
    var chunk_coord: Vector3i = data["chunk"]
    ensure_chunk(chunk_coord)
    var local: Vector3i = data["local"]
    var block_map: Dictionary = chunks.get(chunk_coord)
    block_map[local] = block_type
    chunks[chunk_coord] = block_map
    update_chunk_mesh(chunk_coord)
    update_neighbor_meshes(chunk_coord, local)

func remove_block_global(world_position: Vector3) -> void:
    var data := world_to_chunk(world_position)
    var chunk_coord: Vector3i = data["chunk"]
    if not chunks.has(chunk_coord):
        return
    var local: Vector3i = data["local"]
    var block_map: Dictionary = chunks[chunk_coord]
    if not block_map.has(local):
        return
    block_map.erase(local)
    chunks[chunk_coord] = block_map
    update_chunk_mesh(chunk_coord)
    update_neighbor_meshes(chunk_coord, local)

func update_neighbor_meshes(chunk_coord: Vector3i, local: Vector3i) -> void:
    for direction_index in range(FACE_DIRECTIONS.size()):
        var axis_dir: Vector3i = FACE_DIRECTIONS[direction_index]
        if axis_dir.x != 0:
            if (axis_dir.x < 0 and local.x != 0) or (axis_dir.x > 0 and local.x != chunk_size.x - 1):
                continue
        if axis_dir.y != 0:
            if (axis_dir.y < 0 and local.y != 0) or (axis_dir.y > 0 and local.y != chunk_size.y - 1):
                continue
        if axis_dir.z != 0:
            if (axis_dir.z < 0 and local.z != 0) or (axis_dir.z > 0 and local.z != chunk_size.z - 1):
                continue
        var neighbor_chunk := chunk_coord + axis_dir
        if chunks.has(neighbor_chunk):
            update_chunk_mesh(neighbor_chunk)

func get_chunk_data(chunk_coord: Vector3i) -> Dictionary:
    return chunks.get(chunk_coord, {})

func get_block(chunk_coord: Vector3i, local_position: Vector3i) -> int:
    if not chunks.has(chunk_coord):
        return 0
    var block_map: Dictionary = chunks[chunk_coord]
    return block_map.get(local_position, 0)
