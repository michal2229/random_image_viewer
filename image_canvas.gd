@tool
extends Node3D
class_name ImageCanvas

const TEX_BLANK = preload("res://gfx/tex/tex_blank.dds")

@onready var image_canvas_item: ImageCanvasItem = $ImageCanvasItem
@onready var image_canvas_paper: MeshInstance3D = $ImageCanvasPaper
@onready var label_idx_offset: Label3D = $ImageCanvasItem/LabelIdxOffset
@onready var dirty_indicator: MeshInstance3D = $DirtyIndicator

@export var parent: Node
@export var idx_offset: int = 0
@export var placement_parent: Node3D

var margin: float = 0.1
var num_side_imgs = 4
var height_side = 2.0 * 1.0 / num_side_imgs - margin * (num_side_imgs - 1)/num_side_imgs
var scale_side = height_side / 2.0
var cache: Cache = Cache.new()
var dirty = false

signal sig_clicked(node: ImageCanvas)


func get_size():
	return image_canvas_paper.get_aabb().size * scale

func update_info_note(s: String):
	update_info()
	image_canvas_item.label_info.text += s

func update_info():
	var infostr = 'deleted\n' if cache.is_deleted(image_canvas_item.image_path) else ''
	infostr += 'saved\n' if cache.is_saved(image_canvas_item.image_path) else ''
	image_canvas_item.set_info(infostr)

func set_idx_offset(idxoff: int):
	idx_offset = idxoff
	label_idx_offset.text = str(idxoff)

func set_image(idxc):
	set_blank_tex()

	var idxx = idxc + idx_offset
	image_canvas_item.set_idx(idxx)
	if idxx < 0 or idxx > cache.image_paths.size() - 1:
		update_info_note('Error: bad index')
		return
	update_info()
	cache.request_image_load(idxx)
	dirty = true

func set_blank_tex():
	image_canvas_item.set_texture(TEX_BLANK)


func _ready() -> void:
	pass

func _process(_delta: float) -> void:
	if dirty_indicator:
		dirty_indicator.visible = dirty
	if not dirty:
		return

	var image_state = cache.get_image_state(image_canvas_item.image_idx)

	if image_state == cache.IMAGE_STATE.LOAD_FAIL:
		update_info_note('Error: load failed')
		set_blank_tex()
		dirty = false
		return

	if image_state == cache.IMAGE_STATE.BAD_ARG:
		update_info_note('Error: bad argument')
		set_blank_tex()
		dirty = false
		return

	#if image_state == cache.IMAGE_STATE.DELETED:
		#dirty = false
		#return

	if image_state == cache.IMAGE_STATE.LOADED:
		var tex = cache.get_texture_from_cache(image_canvas_item.image_idx)
		image_canvas_item.set_texture(tex)
		dirty = false
		return


func _on_area_3d_input_event(_camera: Node, event: InputEvent, _event_position: Vector3, _normal: Vector3, _shape_idx: int) -> void:
	if event is InputEventMouseButton:
		if Input.is_action_just_pressed("select"):
			sig_clicked.emit(self)
