@tool
extends MeshInstance3D
class_name ImageCanvasItem

@onready var label_dir:  Label3D = $LabelDir
@onready var label_name: Label3D = $LabelName
@onready var label_info: Label3D = $LabelInfo
@onready var label_idx: Label3D = $LabelIdx

var image_idx: int
var image_path: String
var kk: float= 1.0
var original_size: Vector2
var cache: Cache = Cache.new()

func set_ratio(k: float):
	if k < 1:
		mesh.size.x = mesh.size.y * k
		mesh.size.y = original_size.y
	else:
		mesh.size.x = original_size.x
		mesh.size.y = mesh.size.x / k

func get_size():
	return get_aabb().size * scale

func set_path(path: String):
	image_path = path
	label_dir.text  = path.get_base_dir().replace(get_parent().parent.root_path + '/', '')
	label_name.text = path.get_file()

func set_info(infostr: String):
	label_info.text = infostr

func set_idx(idx: int):
	image_idx = idx
	label_idx.text = str(idx)
	if idx < 0 or idx > len(cache.image_paths) - 1:
		set_path('---')
		return null
	set_path(cache.image_paths[idx])

func set_texture(tex: ImageTexture) -> void:
	if tex == null:
		assert(false)
		return
	get_active_material(0).emission_texture = tex
	var k = float(tex.get_width()) / tex.get_height()
	set_ratio(k)

func _ready() -> void:
	original_size = mesh.size
