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
	light.rotation_degrees = Vector3(-40, -35, 0)
	light.light_energy = 1.15
	vp.add_child(light)

	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_CLEAR_COLOR
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color("6f86b5")
	e.ambient_light_energy = 0.6
	env.environment = e
	vp.add_child(env)

	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.rotation_degrees = Vector3(PITCH, YAW, 0)
	cam.far = 200.0
	vp.add_child(cam)

	var made := 0
	var placeholders := 0
	for it in items:
		var node := _load_or_placeholder(it.kind, it.id)
		if not WQShowcase.has_model(it.kind, it.id): placeholders += 1
		vp.add_child(node)

		var box := WQShowcase.aabb_of(node)
		var center := box.get_center()
		# ยืดกรอบให้พอดีของแต่ละชิ้น ของเล็กของใหญ่จะได้เต็มไอคอนเท่ากัน
		cam.size = maxf(0.4, box.size.length() * 1.05)   # เผื่อขอบไว้ ไม่ให้ของชนกรอบไอคอน
		cam.position = center + Vector3(0, 0, 0) + cam.transform.basis.z * 30.0

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

	print("icon_bake: เขียนไอคอน %d ไฟล์ (เป็นกล่องแทน %d ชิ้นเพราะยังไม่มี .glb)%s" % [
		made, placeholders, "" if _fails == 0 else "  ❌ พลาด %d ชิ้น" % _fails])
	quit(1 if _fails > 0 else 0)


func _load_or_placeholder(kind: String, id: String) -> Node3D:
	var path := WQShowcase.model_path(kind, id)
	if ResourceLoader.exists(path):
		var packed := load(path)
		if packed is PackedScene:
			return (packed as PackedScene).instantiate()
	return WQShowcase.placeholder_for(kind)


## รายการของที่ต้องมีไอคอน — อ่านจาก data/*.json ทั้งหมด ไม่พิมพ์รายชื่อด้วยมือ
## ดีลไม่มี id คงที่ (id เป็นเลขรันไทม์) จึงอบตาม "ประเภทของดีล" แทน
func _items() -> Array:
	var out: Array = []
	for p in WQData.places: out.append({"kind": "places", "id": String(p.id)})
	for v in WQData.vehicles: out.append({"kind": "vehicles", "id": String(v.id)})
	for d in WQData.devices: out.append({"kind": "devices", "id": String(d.id)})
	for g in WQData.gym_packs: out.append({"kind": "packs", "id": "gym_" + String(g.id)})
	for r in WQData.resort_packs: out.append({"kind": "packs", "id": "resort_" + String(r.id)})
	for dr in WQData.dreams: out.append({"kind": "dreams", "id": "dream_%d" % int(dr.roll)})

	var kinds := {}
	for pool in [WQData.deal_pool, WQData.big_deals, WQData.mega_deals]:
		for t in pool: kinds[String(t.kind)] = true
	for k in kinds: out.append({"kind": "assets", "id": String(k)})

	# ชื่อไฟล์ไอคอนอยู่ในโฟลเดอร์เดียวกันหมด id ซ้ำกันข้ามกลุ่มจะทับกันเงียบๆ
	var seen := {}
	for it in out:
		if seen.has(it.id):
			printerr("icon_bake: id ซ้ำ \"%s\" (%s กับ %s) — ไอคอนจะทับกัน" % [
				it.id, seen[it.id], it.kind])
		seen[it.id] = it.kind
	return out
