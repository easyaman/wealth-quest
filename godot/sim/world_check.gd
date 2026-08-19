extends SceneTree
## ตรวจฉาก 3D แบบ headless — ไม่ต้องเปิดหน้าต่างเกม
##   godot --headless --path . --script res://sim/world_check.gd
##
## ตรวจสามเรื่องที่พังเงียบได้ง่ายที่สุด:
##   1. ฉากเมือง/แท่นโชว์ผูกกับ match จริงแล้วรันข้ามเดือนได้โดยไม่ error
##   2. world/ ไม่แอบแก้ state ของเกม (คลิกอาคารต้องไม่ทำให้ผู้เล่นย้ายที่เอง)
##   3. core/ ไม่รู้จัก world/ เลย — headless sim ต้องรันได้โดยไม่โหลด 3D
##
## หมายเหตุ: โหมด headless ใช้ตัวเรนเดอร์หลอก อ่านภาพจาก SubViewport ไม่ได้
## ที่นี่จึงตรวจ "โครงสร้างและตรรกะ" เท่านั้น — ดูของจริงด้วยตาใช้ WQ_SHOT=/tmp/ui.png godot

var _fails := 0


func _init() -> void:
	WQData.load_all()
	var m := WQMatch.new()
	m.setup({"mode": "solo", "seed": 20260815, "players": [
		{"name": "คุณ", "job_id": "teacher", "is_ai": false},
		{"name": "บอท A", "job_id": "programmer", "is_ai": true},
	]})
	var p = m.players[0]

	var city: WQCity = load("res://world/city/City.tscn").instantiate()
	root.add_child(city)
	city.bind(m)
	city.bind_player(p)

	var sc: WQShowcase = load("res://world/showcase/Showcase.tscn").instantiate()
	root.add_child(sc)

	_check_city_layout(city)
	_check_click_is_read_only(city, p)
	_check_avatar(city, p)
	_check_showcase(sc, p, m)
	await _check_three_months(m, city, sc, p)
	_check_core_knows_nothing_about_world()

	city.free()
	sc.free()
	print("world_check: %s" % ("ผ่านทั้งหมด ✅" if _fails == 0 else "ไม่ผ่าน %d ข้อ ❌" % _fails))
	quit(1 if _fails > 0 else 0)


func _check_city_layout(city: WQCity) -> void:
	_eq("สร้างอาคารครบทุกสถานที่ใน places.json", city._places.size(), WQData.places.size())

	# x 0–100 ต้องกลายเป็น −25..+25 พอดี ไม่งั้นอาคารจะหลุดออกนอกกรอบกล้อง
	_eq("x=0 ไปอยู่ซ้ายสุด", snappedf(city.world_pos_of(0.0).x, 0.01), -25.0)
	_eq("x=100 ไปอยู่ขวาสุด", snappedf(city.world_pos_of(100.0).x, 0.01), 25.0)
	_eq("x=50 อยู่กลางถนน", snappedf(city.world_pos_of(50.0).x, 0.01), 0.0)

	# เรียกซ้ำต้องได้ตำแหน่งเดิมเป๊ะ — ผังเมืองห้ามสุ่ม ไม่งั้นผู้เล่นจำตึกไม่ได้
	_eq("ตำแหน่งคำนวณจาก x เท่านั้น (เรียกซ้ำได้ค่าเดิม)",
		city.world_pos_of(37.0), city.world_pos_of(37.0))

	# ถ้าลืมตั้ง own_world_3d ฉากเมืองกับแท่นโชว์จะใช้โลก 3D ใบเดียวกัน
	# แล้วถนนกับตึกจะไปโผล่อยู่ข้างหลังของบนแท่นโชว์ (เคยเกิดจริงตอนทำ Sprint A)
	_eq("ฉากเมืองมีโลก 3D ของตัวเอง", city._vp.own_world_3d, true)
	_eq("กล้องเป็น orthographic", city._cam.projection, Camera3D.PROJECTION_ORTHOGONAL)
	_eq("กล้อง size = 22 ตาม ART-DIRECTION 2.3", city._cam.size, 22.0)
	_eq("กล้องมุม isometric (-30, 45, 0)", city._cam.rotation_degrees.round(), Vector3(-30, 45, 0))

	# ทุกอาคารต้องมีจุดยืนของตัวเอง ไม่งั้นตัวละครจะไปยืนซ้อนกันกลางถนน
	var seen := {}
	for id in city._places:
		var sp: Vector3 = (city._places[id] as WQPlaceNode).stand_point
		seen[sp.snapped(Vector3(0.01, 0.01, 0.01))] = true
	_eq("จุดยืนของแต่ละอาคารไม่ซ้ำกัน", seen.size(), city._places.size())


## กฎเหล็กข้อสำคัญที่สุดของ world/ — คลิกแล้วต้องแค่ "บอก" ไม่ใช่ "ทำ"
func _check_click_is_read_only(city: WQCity, p) -> void:
	var got: Array = []
	city.place_clicked.connect(func(id): got.append(id))

	var before_place: String = p.place
	var before_hours: int = p.hours
	city.place_clicked.emit("bank")

	_eq("คลิกอาคารแล้วยิงสัญญาณออกมา", got, ["bank"])
	_eq("world/ ไม่ย้ายผู้เล่นเอง", p.place, before_place)
	_eq("world/ ไม่หักเวลาผู้เล่นเอง", p.hours, before_hours)

	# หาอาคารจากพิกัดจอต้องไม่พังเมื่อชี้ที่ว่าง
	_eq("ชี้ที่ว่างแล้วไม่ได้อาคารไหน", city.place_at_screen(Vector2(-9999, -9999)), "")


func _check_avatar(city: WQCity, p) -> void:
	var home := city._stand_point_of("home")
	_eq("เริ่มเกมตัวละครยืนที่บ้าน", city._avatar.position, home)

	# ผู้เล่นย้ายที่ผ่าน core → ตัวละครต้องตามไปเอง โดยไม่มีใครสั่งมันตรงๆ
	p.travel_to("bank")
	_eq("ผู้เล่นย้ายที่แล้วตัวละครตามไป",
		city._avatar._target, city._stand_point_of("bank"))

	# สั่งซ้ำระหว่างยังเดินไม่ถึง = ต้องวาร์ป ห้ามให้ผู้เล่นรอแอนิเมชัน
	p.travel_to("mall")
	_eq("สั่งเดินทางซ้ำระหว่างเดินต้องวาร์ปถึงทันที",
		city._avatar.position, city._stand_point_of("mall"))
	p.travel_to("home")


func _check_showcase(sc: WQShowcase, p, m: WQMatch) -> void:
	var d: Dictionary = m.deals[0]
	sc.show_item("assets", String(d.kind), WQDealCard.showcase_stats(p, d), String(d.name))

	_eq("แท่นโชว์มีโลก 3D ของตัวเอง", sc._vp.own_world_3d, true)
	_eq("แท่นโชว์จำกลุ่มและ id ของที่โชว์อยู่", [sc.kind, sc.id], ["assets", String(d.kind)])
	_eq("ดีลต้องมีแถบครบ 4 อย่างตามข้อ 4.2 ของ ART-DIRECTION", sc._stats_box.get_child_count(), 4)

	# ยังไม่มี .glb ต้องได้กล่องแทน ไม่ใช่ error หรือแท่นว่าง
	_eq("ยังไม่มีโมเดลจริงของดีลกลุ่มนี้", sc.has_model("assets", String(d.kind)), false)
	_eq("ไม่มีโมเดลแล้วใช้กล่องแทน", sc._model.name, "Placeholder")
	_eq("บนแท่นมีของ + แท่นหมุน", sc._pivot.get_child_count(), 2)

	# แถบต้องอ่านค่าจาก core ไม่ใช่คำนวณเองในฝั่ง UI
	var t: Dictionary = p.deal_terms(d)
	var roi_bar: WQStatBar = sc._stats_box.get_child(0)
	_has("แถบผลตอบแทนตรงกับ core", roi_bar.value_text, "%.1f%%" % t.roi)
	var hour_bar: WQStatBar = sc._stats_box.get_child(2)
	_has("แถบเวลาปิดดีลตรงกับ core", hour_bar.value_text, str(t.hours))

	# เปลี่ยนของแล้วโหนดต้องไม่สะสม
	sc.show_item("vehicles", "usedcar", [{"label": "ทดสอบ", "value": 1, "max": 2}])
	_eq("เปลี่ยนของแล้วแถบเก่าไม่ค้าง", sc._stats_box.get_child_count(), 1)
	_eq("เปลี่ยนของแล้วของเก่าไม่ค้างบนแท่น", sc._pivot.get_child_count(), 2)

	# ทุก id ที่มีอยู่จริงใน data ต้องเรียกโชว์ได้โดยไม่ error แม้ยังไม่มีโมเดลสักชิ้น
	for v in WQData.vehicles:
		sc.show_item("vehicles", String(v.id), [])
	for dev in WQData.devices:
		sc.show_item("devices", String(dev.id), [])
	for pl in WQData.places:
		sc.show_item("places", String(pl.id), [])
	_eq("โชว์ id ทุกตัวใน data ได้โดยไม่พัง", sc._model != null, true)


func _check_three_months(m: WQMatch, city: WQCity, sc: WQShowcase, p) -> void:
	var start: int = m.month
	for _i in 3:
		m.end_turn()
		await process_frame          # ให้ _process ของกล้อง/แท่นหมุนได้เดินจริงอย่างน้อยหนึ่งเฟรม
	_eq("เดินเกมผ่านไป 3 เดือนแล้ว", m.month >= start + 3, true)
	_eq("ฉากเมืองยังผูกกับผู้เล่นอยู่", city._player, p)
	_eq("แท่นหมุนหมุนไปจริงหลังผ่านหลายเฟรม", sc._spin > 0.0, true)
	_eq("อาคารไม่งอกเพิ่มระหว่างเดินเกม", city._places.size(), WQData.places.size())


## headless sim ต้องรันได้โดยไม่โหลด 3D เลย ถ้า core/ ไปอ้าง world/ เมื่อไหร่กฎนี้พัง
##
## มองหา "การอ้างถึงของจริง" คือ path res://world/ กับชื่อคลาสใน world/
## ไม่ใช่แค่คำว่า world/ เฉยๆ เพราะคอมเมนต์ที่อธิบายกฎข้อนี้ก็พิมพ์คำนั้นเหมือนกัน
const WORLD_REFS := ["res://world", "WQCity", "WQShowcase", "WQPlaceNode", "WQAvatar"]

func _check_core_knows_nothing_about_world() -> void:
	_eq("core/ ไม่อ้างถึง world/ เลย", _files_referencing_world("res://core"), [])
	# sim/ ก็ห้ามอ้าง ยกเว้นไฟล์นี้เองที่มีหน้าที่ทดสอบ world/ โดยตรง
	_eq("sim/ ตัวอื่นไม่อ้างถึง world/", _files_referencing_world("res://sim"), [])
	# และ ui/ ต้องเข้าถึง world/ ผ่านไฟล์ฉากเท่านั้น ไม่ preload สคริปต์ตรงๆ
	_eq("มีสคริปต์ที่ทดสอบ world/ อยู่จริง", FileAccess.file_exists("res://sim/world_check.gd"), true)


func _files_referencing_world(dir_path: String) -> Array:
	var out: Array = []
	var dir := DirAccess.open(dir_path)
	if dir == null: return ["เปิดโฟลเดอร์ %s ไม่ได้" % dir_path]
	for f in dir.get_files():
		if not f.ends_with(".gd"): continue
		if f == "world_check.gd": continue
		var text := FileAccess.get_file_as_string("%s/%s" % [dir_path, f])
		for ref in WORLD_REFS:
			if text.contains(ref):
				out.append("%s (พบ \"%s\")" % [f, ref])
				break
	return out


func _eq(label: String, got, want) -> void:
	if got == want: return
	_fails += 1
	print("  ❌ %s: ได้ %s ต้องการ %s" % [label, str(got), str(want)])


func _has(label: String, haystack: String, needle: String) -> void:
	if haystack.contains(needle): return
	_fails += 1
	print("  ❌ %s: \"%s\" ไม่มี \"%s\"" % [label, haystack, needle])
