@tool
class_name Cache extends Node

enum IMAGE_STATE { NOT_LOADED, LOAD_REQUESTED, LOADED, LOAD_FAIL, BAD_ARG, UNEXPECTED_ERROR }

static var cache_texturess: Dictionary[int, ImageTexture]

static var image_paths: Array[String]
static var imname_to_idx: Dictionary[String, int]

static var null_textures: Array[String]
static var null_images: Array[String]
static var deleted_images: Array[String]
static var saved_images: Array[String]
static var requested_images: Array[String]

const max_num_textures: int = 256
const max_cached_res = 1024
static var mutex := Mutex.new()
static var semaphore_core := Semaphore.new()

static var worker_handles_dict: Dictionary[String, int]
static var num_images_being_processed: int = 0
static var max_num_images_being_processed = OS.get_processor_count()

signal sig_loading_image_complete(idx: int)


func get_image_state_by_name(imname: String) -> IMAGE_STATE:
	mutex.lock()
	if imname_to_idx[imname] in cache_texturess.keys():
		mutex.unlock()
		return IMAGE_STATE.LOADED
	mutex.unlock()

	if imname in null_images:
		return IMAGE_STATE.LOAD_FAIL

	if imname in null_textures:
		return IMAGE_STATE.LOAD_FAIL

	if imname in requested_images:
		return IMAGE_STATE.LOAD_REQUESTED

	if imname not in image_paths:
		return IMAGE_STATE.BAD_ARG

	return IMAGE_STATE.NOT_LOADED

func get_image_state(idx: int) -> IMAGE_STATE:
	if idx < 0 or idx > len(image_paths) - 1:
		#assert(false)
		return IMAGE_STATE.BAD_ARG

	return get_image_state_by_name(image_paths[idx])

func request_image_load_by_name(imname: String) -> void:
	assert(imname in image_paths)

	var img_stat = get_image_state_by_name(imname)
	if img_stat == IMAGE_STATE.LOAD_REQUESTED:
		return
	if img_stat == IMAGE_STATE.LOADED:
		return
	if img_stat == IMAGE_STATE.BAD_ARG:
		return

	requested_images.push_back(imname)

func request_image_load(idx: int) -> void:
	if idx < 0 or idx > len(image_paths) - 1:
		#assert(false)
		return
	request_image_load_by_name(image_paths[idx])

func load_image_to_cache_by_name(imname: String) -> void:
	get_texture(imname)
	sig_loading_image_complete.emit.call_deferred(imname)

func load_image_to_cache(idx: int) -> void:
	if idx < 0 or idx > len(image_paths) - 1:
		assert(false)
		return
	load_image_to_cache_by_name(image_paths[idx])

func manage_space():  # TODO: add disk storage for serialized textures for faster access instead of just removing
	mutex.lock()
	while cache_texturess.size() > max_num_textures:
		var to_del = cache_texturess.keys()[0]
		#print('[INFO] removing old texture: ' + to_del)
		cache_texturess.erase(to_del)
		print('[INFO] removed from cache: ' + str(to_del) + ' ( ' + str(cache_texturess.size()) + ' / ' + str(max_num_textures) + ' )')
	mutex.unlock()

func delete(impath):
	if impath not in deleted_images:
		mutex.lock()
		deleted_images.append(impath)
		mutex.unlock()

func is_deleted(impath):
	return impath in deleted_images

func save(impath):
	if impath not in saved_images:
		mutex.lock()
		saved_images.append(impath)
		mutex.unlock()

func is_saved(impath):
	return impath in saved_images


func get_texture_from_cache_by_name(imname: String) -> ImageTexture:
	mutex.lock()
	if imname_to_idx[imname] not in cache_texturess.keys():
		mutex.unlock()
		return null
	var ret = cache_texturess[imname_to_idx[imname]]
	mutex.unlock()
	return ret

func get_texture_from_cache(idx: int) -> ImageTexture:
	if idx < 0 or idx > len(image_paths) - 1:
		assert(false)
		return null
	return get_texture_from_cache_by_name(image_paths[idx])

func get_texture(imname: String) -> void:
	#print('[INFO] get texture: ' + imname)
	mutex.lock()
	if imname_to_idx[imname] in cache_texturess.keys():
		mutex.unlock()
		#print('[INFO] returning texture from cache: ' + imname)
		return #tex
	mutex.unlock()

	if imname in null_images:
		print('[WARNING] image in null list: ' + imname)
		return

	if imname in null_textures:
		print('[WARNING] texture in null list: ' + imname)
		return

	#print('[INFO] image not in cache, loading: ' + imname)

	var img: Image = Image.load_from_file(imname)

	if img == null or img.is_empty():
		print('[WARNING] image null: ' + imname)
		mutex.lock()
		null_images.append(imname)
		mutex.unlock()
		return #null

	if img.get_width() > max_cached_res or img.get_height() > max_cached_res:
		var w = img.get_width()
		var h = img.get_height()

		var resratio = float(max_cached_res) / max(w, h)
		w *= resratio
		h *= resratio

		img.resize(w, h, Image.INTERPOLATE_LANCZOS)

	if not img.is_compressed():
		#img.compress(Image.COMPRESS_ETC2, Image.COMPRESS_SOURCE_SRGB)
		#var err = img.compress(Image.COMPRESS_ETC2, Image.COMPRESS_SOURCE_SRGB)
		#assert(err == Error.OK)
		pass

	#print('[INFO] creating texture from image: ' + imname)
	var texture: ImageTexture = ImageTexture.create_from_image(img)
	if texture == null:
		print('[WARNING] texture could not be created: ' + imname)
		mutex.lock()
		null_textures.append(imname)
		mutex.unlock()
		return #null

	manage_space()

	mutex.lock()
	cache_texturess[imname_to_idx[imname]] = texture
	mutex.unlock()

	return

func on_sig_loading_image_complete(imname: String) -> void:
	WorkerThreadPool.wait_for_task_completion(worker_handles_dict[imname])
	worker_handles_dict.erase(imname)
	num_images_being_processed -= 1

func _ready() -> void:
	sig_loading_image_complete.connect(on_sig_loading_image_complete)

func _process(_delta: float) -> void:
	if len(requested_images) > 0:
		if num_images_being_processed > max_num_images_being_processed:
			while requested_images.size() > (max_num_textures - max_num_images_being_processed):
				requested_images.remove_at(0)
		else:
			var imname = requested_images.pop_back()
			if imname in worker_handles_dict.keys():
				return

			worker_handles_dict[imname] = WorkerThreadPool.add_task(load_image_to_cache_by_name.bind(imname), false)  # TODO: do cleanup
			num_images_being_processed += 1

func _exit_tree() -> void:
	pass
