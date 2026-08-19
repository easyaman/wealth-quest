extends SceneTree
## อบไอคอน UI จากเมช 3D — เลิกวาดไอคอนด้วยมือ (ART-DIRECTION ข้อ 2.5 และ 4.3)
##
##   godot --path . --script res://world/tools/icon_bake.gd
##
## **ห้ามใส่ --headless** โหมด headless ใช้ตัวเรนเดอร์หลอก อ่านภาพกลับมาไม่ได้
## (`get_image()` คืน null) จึงต้องเปิดหน้าต่างจริง — สคริปต์ปิดตัวเองให้อัตโนมัติ
##
## ทุกชิ้นถ่ายจากมุมเดียวกันเป๊ะ (yaw 45° · pitch 30° · 128×128 · พื้นโปร่ง)
## เพื่อให้ไอคอนทั้งแผงดูเป็นชุดเดียวกัน · ผลลัพธ์ commit เข้า repo ได้
## เพื่อให้ UI ใช้ไอคอนได้โดยไม่ต้องโหลด 3D ตอนรัน headless
##
## ตอนนี้ยังไม่มี .glb สักไฟล์ ทุกชิ้นจึงออกมาเป็นกล่องแทน — ตั้งใจให้เป็นแบบนั้น
## รันซ้ำอีกครั้งหลังใส่โมเดลจริงแล้วไอคอนจะอัปเดตตามเอง

const OUT_DIR := "res://ui/theme/icons"
const SIZE := 128
const YAW := 45.0
const PITCH := -30.0

var _fails := 0


func _init() -> void:
	WQData.load_all()

	if DisplayServer.get_name() == "headless":
		printerr("icon_bake: โหมด headless เรนเดอร์ไม่ได้ — รันใหม่โดยไม่ใส่ --headless")
		quit(1)
		return

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))

	var items := _items()
	print("icon_bake: จะอบ %d ชิ้น -> %s" % [items.size(), OUT_DIR])

	var vp := SubViewport.new()
	vp.size = Vector2i(SIZE, SIZE)
	vp.transparent_bg = true
	vp.own_world_3d = true
	vp.msaa_3d = Viewport.MSAA_4X
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)

	# แสงและมุมกล้องชุดเดียวกับแท่นโชว์ ไอคอนจะได้ดูเป็นของชิ้นเดียวกับที่เห็นบนแท่น
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-42, 30, 0)
	light.light_energy = 1.25
	vp.add_child(light)

	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_CLEAR_COLOR
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color("9fb0c9")
	e.ambient_light_energy = 0.72
	env.environment = e
	vp.add_child(env)

	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.rotation_degrees = Vector3(PITCH, YAW, 0)
	cam.far = 200.0
	vp.add_child(cam)

	var made := 0
	var placeholders := 0
	var kitbashed := 0
	for it in items:
		var node := WQShowcase.model_for(it.kind, it.id)
		if not WQShowcase.has_model(it.kind, it.id):
			if WQKitbash.has(it.kind, it.id): kitbashed += 1
			else: placeholders += 1
		vp.add_child(node)

		var box := WQShowcase.aabb_of(node)
		var center := box.get_center()
		# ยืดกรอบให้พอดี "เงาของกล่องหุ้มบนจอ" ไม่ใช่ความยาวเส้นทแยงมุมของกล่อง
		# เส้นทแยงมุมมักยาวกว่าที่ตาเห็นมาก ของเลยลอยอยู่กลางไอคอนตัวเล็กนิดเดียว
		# แล้วพอย่อลงเหลือ 22px ในแถวของ UI จะกลายเป็นจุดดำจุดเดียว ดูไม่ออกว่าอะไร
		cam.size = maxf(0.25, _fit_size(box, cam.transform.basis) * 1.06)
		cam.position = center + cam.transform.basis.z * 30.0

		await process_frame
		await process_frame

		var img := vp.get_texture().get_image()
		if img == null:
			printerr("icon_bake: เรนเดอร์ %s/%s ไม่ได้" % [it.kind, it.id])
			_fails += 1
		else:
			var path := "%s/%s.png" % [OUT_DIR, it.id]
			var err := img.save_png(ProjectSettings.globalize_path(path))
			if err != OK:
				printerr("icon_bake: เขียน %s ไม่ได้ (error %d)" % [path, err])
				_fails += 1
			else:
				made += 1

		vp.remove_child(node)
		node.free()

	var fixed := _fix_import_settings()
	if fixed > 0:
		print("icon_bake: แก้ค่านำเข้าให้ %d ไฟล์ (เปิด mipmap · ปิดการบีบอัดแบบ 3D)" % fixed)

	print("icon_bake: เขียนไอคอน %d ไฟล์ (.glb จริง %d · เมชต่อกล่อง %d · กล่องเปล่า %d)%s" % [
		made, made - kitbashed - placeholders, kitbashed, placeholders,
		"" if _fails == 0 else "  ❌ พลาด %d ชิ้น" % _fails])
	quit(1 if _fails > 0 else 0)


## ไอคอนถูกอบที่ 128px แล้ว UI ย่อลงเหลือ ~18px — ถ้าไม่มี mipmap การย่อ 7 เท่าจะแตกเป็นจุด
## และถ้าปล่อยให้ detect_3d บีบอัดเป็น texture แบบ VRAM สีที่อบไว้จะเพี้ยนทีละนิด
## Godot สร้างไฟล์ .import ให้เองตอน import ครั้งแรก ที่นี่จึงแค่ตามไปแก้ค่าให้ถูก
## (รันครั้งแรกอาจยังไม่มีไฟล์ .import — รัน --import แล้วอบซ้ำอีกรอบจะครบเอง)
func _fix_import_settings() -> int:
	var dir := DirAccess.open(OUT_DIR)
	if dir == null: return 0
	var n := 0
	for f in dir.get_files():
		if not f.ends_with(".png.import"): continue
		var path := "%s/%s" % [OUT_DIR, f]
		var text := FileAccess.get_file_as_string(path)
		var fixed := text.replace("mipmaps/generate=false", "mipmaps/generate=true") \
			.replace("detect_3d/compress_to=1", "detect_3d/compress_to=0")
		if fixed == text: continue
		var fh := FileAccess.open(path, FileAccess.WRITE)
		if fh == null: continue
		fh.store_string(fixed)
		fh.close()
		n += 1
	return n


## ครึ่งหนึ่งของด้านที่กว้างที่สุดของกล่องหุ้ม เมื่อฉายลงบนแกนขวา/แกนขึ้นของกล้อง ×2
static func _fit_size(box: AABB, basis: Basis) -> float:
	var right := basis.x
	var up := basis.y
	var center := box.get_center()
	var ex := 0.0
	var ey := 0.0
	for i in 8:
		var c := box.position + Vector3(
			box.size.x if (i & 1) else 0.0,
			box.size.y if (i & 2) else 0.0,
			box.size.z if (i & 4) else 0.0) - center
		ex = maxf(ex, absf(c.dot(right)))
		ey = maxf(ey, absf(c.dot(up)))
	return maxf(ex, ey) * 2.0


## รายการของที่ต้องมีไอคอน — มาจาก WQModelIds เพื่อให้ตรงกับตัวตรวจโมเดลและ README เสมอ
func _items() -> Array:
	var out := WQModelIds.all()
	# ชื่อไฟล์ไอคอนอยู่ในโฟลเดอร์เดียวกันหมด id ซ้ำกันข้ามกลุ่มจะทับกันเงียบๆ
	var seen := {}
	for it in out:
		if seen.has(it.id):
			printerr("icon_bake: id ซ้ำ \"%s\" (%s กับ %s) — ไอคอนจะทับกัน" % [
				it.id, seen[it.id], it.kind])
		seen[it.id] = it.kind
	return out
