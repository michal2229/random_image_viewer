@tool
class_name ImageManager extends Node3D

const IMAGE_CANVAS = preload("res://image_canvas.tscn")

@export var trash_dir: String = 'gdtrash'
@export var saved_dir: String = 'gdsaved'

@export var divider: int = 3
@export var margin: float = 0.025
@export var num_levels: int = 2

signal sig_image_scan_done

var initialized:= false
var root_path: String
var displayed_history_idx: Array[int] = []
var idx: int = -1
var cache: Cache = Cache.new()
var threads: Dictionary[int, Thread]
var mutex: Mutex = Mutex.new()
var work_thr_pool_handle = -1

func get_image_list(path, pvec):
	var dir = DirAccess.open(path)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if dir.current_is_dir():
				#print("Found directory: "  + (path + '/'+ file_name).trim_prefix(root_path + '/') )
				if trash_dir in file_name or saved_dir in file_name:
					print('[WARNING] ignoring path: ' + path + '/' + file_name)
					return
				get_image_list(path + '/' + file_name, pvec)
			else:
				var is_image = false

				is_image = is_image || file_name.to_lower().ends_with('.jpg')
				is_image = is_image || file_name.to_lower().ends_with('.jpeg')
				#is_image = is_image || file_name.to_lower().ends_with('.gif')
				is_image = is_image || file_name.to_lower().ends_with('.png')
				is_image = is_image || file_name.to_lower().ends_with('.tif')
				is_image = is_image || file_name.to_lower().ends_with('.tiff')
				is_image = is_image || file_name.to_lower().ends_with('.bmp')
				is_image = is_image || file_name.to_lower().ends_with('.tga')
				is_image = is_image || file_name.to_lower().ends_with('.dds')

				if is_image:
					#print("Found file: " + path + '/' + file_name)
					pvec.append(path + '/' + file_name)
					#var imntoidx = cache.imname_to_idx
					pass
			file_name = dir.get_next()
	else:
		print("An error occurred when trying to access the path.")

func set_image(idxx: int):
	idx = idxx
	if idx > 0 and idx < cache.image_paths.size() - 1:
		displayed_history_idx.append(idxx)
	#print('[INFO] set_image ' + str(idxx) + ': ' + cache.image_paths[idxx])

	for i in get_child_count():
		var c: ImageCanvas = get_child(get_child_count() - i - 1)
		c.set_image(idxx)

func set_random():
	if len(cache.image_paths) == 0:
		return

	idx = randi_range(0, len(cache.image_paths) - 1)
	set_image(idx)
	#print(idx, cache.image_paths[idx])

func update_info():
	for c: ImageCanvas in get_children():
		c.update_info()

func make_image_lvls(init_node: Node3D, lvl: int, dir: int):
	assert(dir == 1 or dir == -1)
	assert(lvl >= 0)

	if lvl == 0:
		return

	var init_node_size = init_node.get_size()
	for i in range(divider):
		var node: ImageCanvas = IMAGE_CANVAS.instantiate()
		add_child(node)
		node.sig_clicked.connect(on_sig_image_canvas_clicked)
		node.parent = self
		var idxoff = init_node.idx_offset*divider + (1 + (divider - 1 - i))*dir
		node.set_idx_offset(idxoff)
		node.name = 'ImageCanvas_' + ('+' if idxoff > 0 else '') + str(idxoff)
		node.scale = init_node.scale * (1.0/divider) * (1.0/(1.0+margin/(divider/1.5)))
		var node_size = node.get_size()
		node.global_position.x += init_node.global_position.x + (init_node_size.x/2 + node_size.x/2 + margin*node_size.x)*dir
		node.global_position.y += init_node.global_position.y + (node_size.y + margin*node_size.y)*( i - float(divider - 1.0)/2 )
		make_image_lvls(node, lvl - 1, dir)

func sort_children():
	var sorted_nodes := get_children()
	sorted_nodes.sort_custom( func(a: Node, b: Node): return abs(a.idx_offset - 0.01) < abs(b.idx_offset) )

	for node in get_children():
		remove_child(node)

	for node in sorted_nodes:
		add_child(node)

func prep_img_list() -> void:
	get_image_list(root_path, cache.image_paths)
	if len(cache.image_paths) == 0:
		return
	cache.image_paths.sort_custom(func(a: String, b: String): return a.filenocasecmp_to(b) < 0)
	cache.image_paths.make_read_only()

	for i in range(cache.image_paths.size()):
		cache.imname_to_idx[cache.image_paths[i]] = i
	cache.imname_to_idx.make_read_only()

	print('... image list preparing done (' + str(len(cache.image_paths)) + ' elements)')
	sig_image_scan_done.emit.call_deferred()

func on_sig_image_scan_done() -> void:
	initialized = true
	set_image((get_child_count() - 1) / 2)

func on_sig_image_canvas_clicked(node: ImageCanvas):
	var idxx = node.image_canvas_item.image_idx
	set_image(idxx)

func _ready() -> void:
	sig_image_scan_done.connect(on_sig_image_scan_done)
	get_tree().root.add_child.call_deferred(cache)

	var node_zero: Node3D = IMAGE_CANVAS.instantiate()
	add_child(node_zero)
	node_zero.parent = self
	node_zero.set_idx_offset(0)
	node_zero.name = 'ImageCanvas_0'
	make_image_lvls(node_zero, num_levels,  1)
	make_image_lvls(node_zero, num_levels, -1)
	print('[INFO] num images visible: ' + str(get_child_count()))
	sort_children()

	root_path =  DirAccess.open(".").get_current_dir()
	if 'projects_godot/random_image_viewer' in root_path:
		root_path = OS.get_environment("HOME") + '/data/data-bcache-a/_Obrazy'
	print("[INFO] pwd: " + root_path)

	WorkerThreadPool.add_task(prep_img_list)

func _process(_delta):
	if Engine.is_editor_hint():
		return

	if not initialized or len(cache.image_paths) == 0:
		return

	if Input.is_action_just_pressed("random"):
		set_random()

	if Input.is_action_just_pressed("previous_history"):
		if len(displayed_history_idx) > 1:
			displayed_history_idx.resize(displayed_history_idx.size() - 1)
			idx = displayed_history_idx[-1]
			set_image(idx)

	if Input.is_action_just_pressed("previous"):
		idx -= 1
		idx = max(idx, 0)
		set_image(idx)
		if idx > 0:
			displayed_history_idx[-1] = idx

	if Input.is_action_pressed("previous_cont"):
		idx -= 1
		idx = max(idx, 0)
		set_image(idx)
		if idx > 0:
			displayed_history_idx[-1] = idx

	if Input.is_action_just_pressed("previous_n"):
		idx -= get_child_count() - 1
		idx = max(idx, 0)
		set_image(idx)
		if idx > 0:
			displayed_history_idx[-1] = idx

	if Input.is_action_just_pressed("next"):
		idx += 1
		idx = min(idx, cache.image_paths.size() - 1)
		set_image(idx)
		if idx < cache.image_paths.size() - 1:
			displayed_history_idx[-1] = idx

	if Input.is_action_pressed("next_cont"):
		idx += 1
		idx = min(idx, cache.image_paths.size() - 1)
		set_image(idx)
		if idx < cache.image_paths.size() - 1:
			displayed_history_idx[-1] = idx

	if Input.is_action_just_pressed("next_n"):
		idx += get_child_count() - 1
		idx = min(idx, cache.image_paths.size() - 1)
		set_image(idx)
		if idx < cache.image_paths.size() - 1:
			displayed_history_idx[-1] = idx

	#if idx < 0 or idx > len(cache.image_paths) - 1:
	#	return

	if Input.is_action_just_pressed("delete"):
		var impath = cache.image_paths[idx]
		var dir = DirAccess.open(root_path)
		if not dir.file_exists(trash_dir):dir.make_dir(trash_dir)
		DirAccess.rename_absolute(impath, root_path + '/' + trash_dir + '/' + impath.get_file() )
		cache.delete(impath)
		update_info()

		set_image(idx)
		displayed_history_idx[-1] = idx

	if Input.is_action_just_pressed("save"):
		var impath = cache.image_paths[idx]
		var dir = DirAccess.open(root_path)
		if not dir.file_exists(saved_dir):
			dir.make_dir(saved_dir)
		DirAccess.copy_absolute(impath, root_path + '/' + saved_dir + '/' + impath.get_file() )
		cache.save(impath)
		update_info()


	if Input.is_action_just_pressed("show_in_filemanager"):
		OS.shell_show_in_file_manager(cache.image_paths[idx])  # TODO: test it when selecting will be implemented in godot
