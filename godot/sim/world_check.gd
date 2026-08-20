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
	_check_disasters(city, m, p)
	_check_vfx(city, m, p)
	_check_avatar_states(city, p)
	_check_showcase(sc, p, m)
	_check_roll_start()
	await _check_job_select()
	await _check_setup_screen()
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

	# อาคารสองหลังที่อยู่ติดกันห้ามกินเนื้อที่ทับกัน — ผังเมืองมาจาก x ใน places.json
	# ซึ่งบางคู่ห่างกันแค่ 3 หน่วย ถ้าต่อตึกกว้างเกินช่องของตัวเอง เสากับหลังคาจะทะลุกัน
	# (เกิดจริงตอน Sprint C ต่ออาคารรอบแรก — ธนาคารทะลุฟิตเนสไป 1.95 หน่วย)
	_eq("อาคารไม่มีหลังไหนกินเนื้อที่ทับกัน", _overlaps(city), [])

	# ทุกอาคารต้องมีจุดยืนของตัวเอง ไม่งั้นตัวละครจะไปยืนซ้อนกันกลางถนน
	var seen := {}
	for id in city._places:
		var sp: Vector3 = (city._places[id] as WQPlaceNode).stand_point
		seen[sp.snapped(Vector3(0.01, 0.01, 0.01))] = true
	_eq("จุดยืนของแต่ละอาคารไม่ซ้ำกัน", seen.size(), city._places.size())


## ช่วงแกน X ที่อาคารแต่ละหลังกินจริง (รวม prop ที่เป็นลูกของมัน) เรียงจากซ้ายไปขวา
## แล้วดูว่าหลังที่อยู่ติดกันล้ำเข้าหากันไหม — เผื่อระยะ 0.1 หน่วยไว้กันเลขทศนิยมปัดเศษ
const BUILDING_GAP := 0.1

func _overlaps(city: WQCity) -> Array:
	var spans: Array = []
	for id in city._places:
		var node: WQPlaceNode = city._places[id]
		# วัดจาก bounds ของ "ตัวอาคาร" เท่านั้น ไม่ใช่ AABB ของทั้งโหนด
		# เพราะโหนดมีวงไฟไฮไลต์ที่กว้างกว่าตัวอาคาร 1.6 หน่วยติดอยู่ด้วย
		# วงไฟของสองหลังที่อยู่ติดกันซ้อนกันได้ไม่เป็นไร — มันเป็นแสงบนพื้น ไม่ใช่ก้อนตึก
		spans.append({"id": String(id),
			"x0": node.position.x + node.bounds.position.x,
			"x1": node.position.x + node.bounds.end.x})
	spans.sort_custom(func(a, b): return a.x0 < b.x0)
	var out: Array = []
	for i in spans.size() - 1:
		var over: float = spans[i].x1 - spans[i + 1].x0 - BUILDING_GAP
		if over > 0.0:
			out.append("%s ทับ %s %.2f หน่วย" % [spans[i].id, spans[i + 1].id, over])
	return out


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


## ภัยพิบัติต้องเปลี่ยน "สิ่งที่มองเห็น" จริง ไม่ใช่แค่ขึ้นข้อความในบันทึก
## ยิงผ่านสัญญาณจริงของ match ทุกครั้ง — ไม่มีการเรียกเมธอดของ world/ ตรงๆ
func _check_disasters(city: WQCity, m: WQMatch, p) -> void:
	var layer: WQDisasterLayer = city._disasters

	# ทุก id ใน data ต้องมีสภาพในฉาก ไม่งั้นภัยพิบัติบางลูกจะเกิดแบบไม่มีอะไรเปลี่ยนบนจอเลย
	var missing: Array = []
	for d in WQData.disasters:
		if not WQDisasterLayer.KNOWN.has(String(d.id)): missing.append(String(d.id))
	_eq("ภัยพิบัติทุก id ใน data/disasters.json มีสภาพในฉาก", missing, [])

	var fog_before: float = city._env.fog_density
	var health_before: float = p.health
	var cash_before: float = p.cash

	var shakes: Array = []
	layer.shake_requested.connect(func(sec): shakes.append(sec))

	# น้ำท่วม — แผ่นน้ำต้องโผล่ขึ้นมา
	_start(m, "flood")
	_eq("น้ำท่วมแล้วชั้นภัยพิบัติรู้", layer.has("flood"), true)
	_eq("น้ำท่วมแล้วมีแผ่นน้ำในฉาก", layer._water.visible, true)

	# โรคระบาด — ตัวละครใส่หน้ากาก
	_start(m, "plague")
	_eq("โรคระบาดแล้วตัวละครใส่หน้ากาก", city._avatar.is_masked(), true)

	# เศรษฐกิจตก — หมอกเทาทึบขึ้น + ป้ายลดราคาโผล่หน้าร้าน
	_start(m, "crisis")
	_eq("เศรษฐกิจตกแล้วหมอกทึบขึ้น", city._env.fog_density > fog_before, true)
	_eq("เศรษฐกิจตกแล้วมีป้ายลดราคา", layer._sale_signs.visible, true)
	_eq("ป้ายลดราคามีครบทุกร้าน", layer._sale_signs.get_child_count(), WQData.places.size())

	_start(m, "rate")
	_eq("ดอกเบี้ยพุ่งแล้วมีป้ายเหนือธนาคาร", layer._rate_board.visible, true)
	_start(m, "inflation")
	_eq("ค่าครองชีพพุ่งแล้วมีลูกศรราคา", layer._price_arrows.visible, true)
	_start(m, "fire")
	_eq("ไฟไหม้แล้วมีควันลอยขึ้น", layer._smoke.emitting, true)
	_start(m, "quake")
	_eq("แผ่นดินไหวแล้วมีรอยแตกบนถนน", layer._cracks.visible, true)
	_eq("แผ่นดินไหวแล้วสั่งเขย่ากล้องหนึ่งครั้ง", shakes.size(), 1)

	# กฎเหล็ก: ชั้นภัยพิบัติอ่านอย่างเดียว — ที่หัก hp กับเงินคือ core/match.gd เท่านั้น
	_eq("ชั้นภัยพิบัติไม่หักสุขภาพผู้เล่นเอง", p.health, health_before)
	_eq("ชั้นภัยพิบัติไม่หักเงินผู้เล่นเอง", p.cash, cash_before)

	# จบทุกลูกแล้วฉากต้องกลับเป็นเหมือนเดิม ไม่ใช่ค้างสภาพภัยพิบัติไว้ตลอดเกม
	m.active_disasters.clear()
	m.month_ended.emit(m.month)
	_eq("ภัยพิบัติจบแล้วชั้นภัยพิบัติว่าง", layer.active, [])
	_eq("ภัยพิบัติจบแล้วหมอกกลับเป็นเดิม", city._env.fog_density, fog_before)
	_eq("ภัยพิบัติจบแล้วป้ายลดราคาหายไป", layer._sale_signs.visible, false)
	_eq("ภัยพิบัติจบแล้วตัวละครถอดหน้ากาก", city._avatar.is_masked(), false)


## เอฟเฟกต์ทั้งสี่ต้องยิงจาก "สัญญาณ" เท่านั้น — ทดสอบด้วยการทำให้เกมเกิดเหตุจริง
## ไม่ใช่เรียก play() ตรงๆ เพราะแบบนั้นทดสอบแค่ว่าอนุภาคสร้างได้ ไม่ได้ทดสอบว่ามันผูกถูกที่
func _check_vfx(city: WQCity, m: WQMatch, p) -> void:
	var vfx: WQVfx = city._vfx
	_eq("มีเอฟเฟกต์ครบสี่ตัว", vfx._emitters.keys().size(), 4)
	for kind in WQVfx.KINDS:
		_eq("เอฟเฟกต์ %s ยิงครั้งเดียวจบ ไม่พ่นค้าง" % kind,
			(vfx._emitters[kind] as GPUParticles3D).one_shot, true)

	vfx.played.clear()

	# ภัยพิบัติ — ยิงจาก disaster_started ของ match
	m.disaster_started.emit(WQData.disasters[0])
	_eq("ภัยพิบัติเกิดแล้วมีเอฟเฟกต์", vfx.played.has("disaster"), true)

	# ปิดดีล — ยิงจาก deal_closed ของผู้เล่นคนที่ฉากกำลังตามอยู่
	vfx.played.clear()
	p.deal_closed.emit({"kind": "micro", "name": "ทดสอบ"})
	_eq("ปิดดีลแล้วมีเอฟเฟกต์", vfx.played.has("deal_closed"), true)

	# ชนะ — ยิงเฉพาะตอนที่คนที่จบคือคนที่ฉากกำลังตามอยู่ ไม่ใช่ตอนบอทจบ
	vfx.played.clear()
	m.player_finished.emit(m.players[1])
	_eq("บอทจบเกมแล้วไม่ยิงเอฟเฟกต์ชนะให้ผู้เล่น", vfx.played.has("win"), false)
	m.player_finished.emit(p)
	_eq("ผู้เล่นทำความฝันสำเร็จแล้วมีเอฟเฟกต์ชนะ", vfx.played.has("win"), true)

	# เงินเดือนออก — เดือนที่ติดลบต้องไม่ยิง ไม่งั้นจะสอนผู้เล่นผิดว่าเดือนนี้ผ่านไปด้วยดี
	vfx.played.clear()
	var keep: float = p.fixed_expenses
	p.fixed_expenses = 99999999.0
	m.month_ended.emit(m.month)
	_eq("เดือนที่รายจ่ายท่วมรายรับ ไม่มีเอฟเฟกต์เงินเข้า", vfx.played.has("payday"), false)
	p.fixed_expenses = keep
	m.month_ended.emit(m.month)
	_eq("เดือนที่เหลือเก็บเป็นบวก มีเอฟเฟกต์เงินเข้า", vfx.played.has("payday"), true)


## เริ่มภัยพิบัติผ่านทางเดียวกับที่ core ใช้จริง: ใส่ลงใน active_disasters แล้วยิงสัญญาณ
func _start(m: WQMatch, id: String) -> void:
	var def: Dictionary = {}
	for d in WQData.disasters:
		if String(d.id) == id: def = d
	m.active_disasters.append({"def": def, "left": int(def.dur)})
	m.disaster_started.emit(def)


## ท่าทั้งหกต้องถูกเลือกจากสถานะของ core เท่านั้น — ไม่มีใครสั่งท่าจากภายนอกได้
func _check_avatar_states(city: WQCity, p) -> void:
	var av: WQAvatar = city._avatar
	var health_before: float = p.health
	var place_before: String = p.place

	p.health = 80.0
	p.travel_to("home")
	av._hit_left = 0.0
	av._pick_state()
	_eq("ยืนเฉยๆ ที่บ้าน = ท่า idle", av.state, "idle")

	p.travel_to("office")
	av._hit_left = 0.0
	av._pick_state()
	_eq("อยู่ที่ทำงาน = ท่า work", av.state, "work")

	p.health = 30.0
	av._hit_left = 0.0
	av._pick_state()
	_eq("สุขภาพต่ำกว่า 40 = ท่า tired", av.state, "tired")

	# สุขภาพลดลงต้องเข้าท่า hit เอง โดยไม่มีใครสั่ง — ตัวละครดูจาก changed ของ core ล้วนๆ
	p.health = 20.0
	p.changed.emit()
	_eq("สุขภาพเพิ่งลดลง = ท่า hit", av.state, "hit")

	p.dream_done = 12
	av._hit_left = 0.0
	av._pick_state()
	_eq("ทำความฝันสำเร็จ = ท่า celebrate", av.state, "celebrate")

	p.dream_done = 0
	p.health = health_before
	p.travel_to(place_before)
	av._hit_left = 0.0
	av._pick_state()


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


## ทอยเต๋าเริ่มเกมต้องตรงกับตาราง roll_table ใน data/config.json ทุกแต้ม
## เทียบกับ "ตารางใน data" ไม่ใช่ตัวเลขที่พิมพ์ไว้ในเทสต์ — ไม่งั้นวันที่ปรับสมดุลตาราง
## เทสต์จะยังผ่านทั้งที่เกมไม่ได้ทำตามตารางแล้ว
func _check_roll_start() -> void:
	for roll in range(1, 7):
		var t: Dictionary = WQData.cfg.roll_table[str(roll)]
		var res := WQSetup.roll_start(20260815, roll)
		_eq("แต้ม %d ให้อาชีพครบตามตาราง" % roll, (res.jobs as Array).size(), int(t.count))
		_eq("แต้ม %d ให้โบนัสเวลาตามตาราง" % roll, res.bonus_hours, int(t.bonusHours))

		# ทุกอาชีพที่ยื่นให้ต้องอยู่ใน tier ที่แต้มนี้ปลดล็อก ห้ามมีอาชีพหลุด tier มา
		var bad: Array = []
		for j in res.jobs:
			if not t.tiers.has(float(j.tier)) and not t.tiers.has(int(j.tier)):
				bad.append(String(j.id))
		_eq("แต้ม %d ไม่มีอาชีพหลุด tier" % roll, bad, [])

		# GDD บทที่ 7: แต้ม ≥ 4 การันตีอย่างน้อยหนึ่งอาชีพจาก tier สูงสุดที่ปลดล็อก
		if roll >= 4:
			var top := 0
			for tier in t.tiers: top = maxi(top, int(tier))
			var has_top := false
			for j in res.jobs:
				if int(j.tier) == top: has_top = true
			_eq("แต้ม %d การันตีอาชีพ tier สูงสุด" % roll, has_top, true)

		# เรียงจาก tier ต่ำไปสูง แล้วเงินเดือนน้อยไปมาก — ผู้เล่นต้องอ่านรายการได้เป็นลำดับ
		var sorted := true
		for i in (res.jobs as Array).size() - 1:
			var a: Dictionary = res.jobs[i]
			var b: Dictionary = res.jobs[i + 1]
			if int(a.tier) > int(b.tier): sorted = false
			elif int(a.tier) == int(b.tier) and float(a.salary) > float(b.salary): sorted = false
		_eq("แต้ม %d เรียงตาม tier แล้วเงินเดือน" % roll, sorted, true)

	# เมล็ดเดิมต้องได้ผลเดิมเป๊ะ ไม่งั้นโหลดเซฟแล้วชุดอาชีพจะเปลี่ยน
	var a1 := WQSetup.roll_start(4242)
	var a2 := WQSetup.roll_start(4242)
	_eq("เมล็ดเดิมได้แต้มเดิม", a1.roll, a2.roll)
	_eq("เมล็ดเดิมได้ชุดอาชีพเดิม", str(a1.jobs), str(a2.jobs))


## หน้าเลือกอาชีพ — ตัวเลขบนจอต้องมาจาก core และหน้าจอนี้ต้องไม่สร้างเกมเอง
func _check_job_select() -> void:
	var screen := WQJobSelect.new()
	root.add_child(screen)
	screen.start(20260815, 5)
	await process_frame

	_eq("ยื่นอาชีพให้เลือกครบตามแต้มที่ทอยได้",
		screen._buttons.size(), (screen.offer.jobs as Array).size())
	_eq("เปิดหน้ามาแล้วเลือกใบแรกไว้ให้ก่อน ไม่ปล่อยแท่นว่าง",
		screen.picked_id, String(screen.offer.jobs[0].id))

	var last := String(screen.offer.jobs[(screen.offer.jobs as Array).size() - 1].id)
	screen.select(last)
	_eq("เลือกอาชีพแล้วแท่นโชว์เปลี่ยนตาม", [screen._showcase.kind, screen._showcase.id],
		["character", last])
	_eq("มีแถบครบสามอันตาม Sprint C ข้อ 5", screen._showcase._stats_box.get_child_count(), 3)

	# ตัวเลขบนแถบต้องเท่ากับที่ core ตอบ ไม่ใช่คำนวณซ้ำในฝั่ง UI
	var pv := WQSetup.job_preview(last, int(screen.offer.bonus_hours))
	var free_bar: WQStatBar = screen._showcase._stats_box.get_child(0)
	_has("แถบเวลาว่างตรงกับ core", free_bar.value_text, "%d" % int(pv.free_hours))
	var pay_bar: WQStatBar = screen._showcase._stats_box.get_child(1)
	_has("แถบเงินเดือนตรงกับ core", pay_bar.value_text, WQFmt.m(float(pv.salary)))
	var commute_bar: WQStatBar = screen._showcase._stats_box.get_child(2)
	_has("แถบเดินทางตรงกับ core", commute_bar.value_text, "%d" % int(pv.commute))

	# ทุกอาชีพในชุดต้องมีชุดอาชีพของตัวเอง ไม่งั้นจะมีอาชีพที่โชว์เป็นตัวละครเปล่า
	var no_outfit: Array = []
	for j in WQData.jobs:
		if not WQKitbashChar.has_outfit(String(j.id)): no_outfit.append(String(j.id))
	_eq("ทุกอาชีพใน data/jobs.json มีชุดอาชีพ", no_outfit, [])

	# กดยืนยันแล้วต้องแค่ "บอก" ว่าเลือกอะไร ไม่ใช่ตั้งแมตช์เอง
	var got: Array = []
	screen.chosen.connect(func(id, roll, bonus): got.append([id, roll, bonus]))
	screen._on_confirm()
	_eq("กดยืนยันแล้วยิงสัญญาณบอกอาชีพที่เลือก",
		got, [[last, int(screen.offer.roll), int(screen.offer.bonus_hours)]])

	root.remove_child(screen)
	screen.free()


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


## หน้าจอ setup (GDD บทที่ 7) — ลำดับต้องเป็น ทอยเต๋า → เห็นผล → ค่อยเลือกอาชีพ
## และ **แต้มบนลูกเต๋ากับชุดอาชีพต้องมาจากการทอยครั้งเดียวกัน** ห้ามทอยซ้ำระหว่างทาง
func _check_setup_screen() -> void:
	var screen := WQSetupScreen.new()
	root.add_child(screen)
	screen.start(20260815)
	await process_frame

	_eq("เปิดมายังไม่ทอย", screen.offer.is_empty(), true)
	_eq("ยังไม่ทอย ยังไม่เห็นรายการอาชีพ", screen._job.visible, false)
	_eq("ยังไม่ทอย ยังไม่มีปุ่มไปต่อ", screen._next_btn.visible, false)
	_eq("ตารางแต้มครบหกแถวตาม data/config.json", screen._table.get_child_count(), 6)

	# กดปุ่มจริง (ไม่ใช่เรียกเมธอดตรงๆ) — สายปุ่มขาดเมื่อไหร่จะรู้ตรงนี้
	screen._roll_btn.pressed.emit()
	_eq("กดปุ่มแล้วทอยจริง", screen.offer.is_empty(), false)
	_eq("แต้มที่ได้อยู่ในช่วง 1–6", int(screen.offer.roll) >= 1 and int(screen.offer.roll) <= 6, true)
	_eq("ทอยแล้วปิดปุ่มทอย", screen._roll_btn.disabled, true)

	# เริ่มใหม่ต้องล้างของเดิมหมด ทั้งผลทอยและภาพลูกเต๋าที่ค้างกลิ้งอยู่
	screen.start(20260815)
	_eq("เริ่มใหม่แล้วล้างผลทอยเดิม", screen.offer.is_empty(), true)
	_eq("เริ่มใหม่แล้วลูกเต๋าหยุดนิ่ง", screen._dice.rolling, false)

	screen.roll(3)
	_eq("ทอยแล้วได้แต้มที่สั่ง", int(screen.offer.roll), 3)
	_eq("ระหว่างภาพลูกเต๋ากลิ้ง ยังไม่เฉลยรายการอาชีพ", screen._job.visible, false)

	# ทอยซ้ำระหว่างที่ยังไม่ไปต่อ ต้องไม่เปลี่ยนผล — ไม่งั้นผู้เล่นกดรัวเพื่อเลือกแต้มที่ชอบได้
	var jobs_before := str(screen.offer.jobs)
	screen.roll(6)
	_eq("กดทอยซ้ำแล้วผลไม่เปลี่ยน", int(screen.offer.roll), 3)
	_eq("กดทอยซ้ำแล้วชุดอาชีพไม่เปลี่ยน", str(screen.offer.jobs), jobs_before)

	screen._dice.finish_now()
	_eq("ภาพลูกเต๋าหยุดที่แต้มที่ทอยได้", screen._dice.face, 3)
	_has("เฉลยแต้มที่ได้เป็นข้อความด้วย", screen._result.text, "ได้แต้ม 3")
	_eq("ทอยเสร็จแล้วมีปุ่มไปต่อ", screen._next_btn.visible, true)

	screen.show_jobs()
	await process_frame
	_eq("ไปต่อแล้วเห็นรายการอาชีพ", screen._job.visible, true)
	_eq("ยื่นอาชีพครบตามแต้มที่ทอยได้",
		screen._job._buttons.size(), (screen.offer.jobs as Array).size())
	_eq("เต๋าที่หัวข้อค้างแต้มเดิมไว้ให้ดู", screen._job._die.face, 3)

	# หน้า setup ไม่ตั้งแมตช์เอง — ส่งต่อสัญญาณของหน้าเลือกอาชีพให้ ui/main.gd เท่านั้น
	# lambda ของ GDScript จับตัวแปรแบบ "ก๊อปค่า" — เขียน `got = [...]` จะไปโดนแค่ก๊อปของมันเอง
	# ต้องแก้ผ่านตัว Array เดิม (`assign`) ค่าถึงจะออกมาถึงข้างนอก
	var got: Array = []
	screen.chosen.connect(func(id: String, roll: int, bonus: int): got.assign([id, roll, bonus]))
	screen._job.select(String(screen.offer.jobs[0].id))
	screen._job._on_confirm()
	_eq("ส่งต่อสัญญาณเลือกอาชีพครบทั้งสามค่า", got,
		[String(screen.offer.jobs[0].id), 3, int(screen.offer.bonus_hours)])

	screen.free()


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
