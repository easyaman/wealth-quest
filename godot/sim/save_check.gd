extends SceneTree
## ตรวจว่าเซฟ/โหลดเก็บครบ โดยเฉพาะ state ของตัวสุ่มและระบบแผนที่
##   godot --headless --path . --script res://sim/save_check.gd
## ต้องรันทุกครั้งที่แก้ core/save.gd หรือเพิ่มฟิลด์ใน WQPlayer

var _fails := 0

func _init() -> void:
	WQData.load_all()
	WQSave.dir = "user://saves_test"      # ห้ามแตะไฟล์เซฟจริงของผู้เล่น
	var m := WQMatch.new()
	m.setup({"mode": "solo", "seed": 4242, "players": [
		{"name": "คุณ", "job_id": "teacher", "is_ai": false},
		{"name": "บอท", "job_id": "programmer", "is_ai": true}]})

	# ตั้งสถานะของระบบแผนที่ให้ไม่ใช่ค่าเริ่มต้น จะได้รู้ว่าถูกเก็บจริงไม่ใช่บังเอิญตรง
	var p = m.players[0]
	p.place = "mall"
	p.travel_used = 17
	p.vehicle = "usedcar"
	p.devices = ["smartphone", "laptop"]
	p.gym_pack = "trainer"
	p.shield = 0.35
	p.exercise_this_month = 2

	var data := WQSave.to_dict(m)
	var round_trip: Dictionary = JSON.parse_string(JSON.stringify(data))
	var m2 := WQSave.from_dict(round_trip)
	var q = m2.players[0]

	_eq("เวอร์ชันไฟล์เซฟ", int(round_trip.v), WQSave.VERSION)
	_eq("state ของตัวสุ่ม", m2.rng.s, m.rng.s)
	_eq("สถานที่ปัจจุบัน", q.place, "mall")
	_eq("ชั่วโมงเดินทางที่ใช้ไป", q.travel_used, 17)
	_eq("พาหนะ", q.vehicle, "usedcar")
	_eq("อุปกรณ์", "|".join(q.devices), "smartphone|laptop")
	_eq("แพ็กเกจฟิตเนส", q.gym_pack, "trainer")
	_eq("โล่จากการพักผ่อน", q.shield, 0.35)
	_eq("จำนวนครั้งที่ออกกำลังกาย", q.exercise_this_month, 2)
	# ฟิลด์พวกนี้ต้องมีผลกับตัวเลขจริง ไม่ใช่แค่เก็บไว้เฉยๆ
	_eq("ค่าดูแลพาหนะ+อุปกรณ์", q.get_upkeep_cost(), p.get_upkeep_cost())
	_eq("ชั่วโมงเดินทางประจำ (ลดตามพาหนะ)", q.get_commute_hours(), p.get_commute_hours())

	# ตัวสุ่มต้องเดินต่อจากจุดเดิม ไม่งั้นผู้เล่นเซฟ-โหลดซ้ำเพื่อรีดผลที่ชอบได้
	_eq("ค่าสุ่มถัดไปหลังโหลด", m2.rng.next(), m.rng.next())

	_check_slots(m)

	print("save_check: %s" % ("ผ่านทั้งหมด ✅" if _fails == 0 else "ไม่ผ่าน %d ข้อ ❌" % _fails))
	quit(1 if _fails > 0 else 0)

## ช่องเซฟจริงบนดิสก์ — หัวไฟล์ต้องอ่านได้โดยไม่ต้องประกอบแมตช์ และ autosave ต้องวนช่อง
func _check_slots(m: WQMatch) -> void:
	for slot in WQSave.MANUAL_SLOTS + WQSave.AUTO_SLOTS:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(WQSave.path_for(slot)))

	_eq("ยังไม่มีเซฟสักช่อง", WQSave.has_any(), false)
	_eq("ช่องว่างต้องบอกว่าว่าง", WQSave.slot_info("1").get("empty"), true)

	WQSave.write_slot(m, "1", {"tut": 4})
	var info := WQSave.slot_info("1")
	_eq("เขียนแล้วช่องต้องไม่ว่าง", info.get("empty"), false)
	_eq("หัวไฟล์บอกเดือนที่เซฟ", int(info.get("month")), m.month)
	_eq("หัวไฟล์บอกชื่อผู้เล่นคนจริง", String(info.get("name")), String(m.players[0].pname))
	_eq("หัวไฟล์บอกความมั่งคั่งสุทธิ", int(info.get("net_worth")),
		roundi(m.players[0].get_net_worth()))
	_eq("หัวไฟล์บอกว่าเวอร์ชันตรง", info.get("version_ok"), true)
	_eq("มีเซฟแล้ว has_any ต้องเป็นจริง", WQSave.has_any(), true)
	_eq("ของฝั่ง UI กลับมาครบ", int(WQSave.read_extra("1").get("tut", -1)), 4)

	var loaded := WQSave.read_slot("1")
	_eq("โหลดช่องที่เขียนไว้ได้", loaded != null and loaded.month == m.month, true)
	_eq("โหลดช่องที่ไม่มีไฟล์ต้องได้ null ไม่ใช่ crash", WQSave.read_slot("2"), null)

	# autosave ต้องไล่ลงช่องว่างให้ครบก่อน แล้วค่อยวนทับช่องที่เก่าที่สุด
	# เขียนรวดเดียวในวินาทีเดียวแบบนี้แหละที่เคยทำให้วงยุบเหลือช่องเดียว (ตอนเรียงด้วยนาฬิกา)
	for _i in WQSave.AUTO_SLOTS.size():
		WQSave.write_auto(m)
	var filled := 0
	for slot in WQSave.AUTO_SLOTS:
		if not WQSave.slot_info(slot).get("empty", true): filled += 1
	_eq("autosave กระจายครบทั้งสามช่อง", filled, WQSave.AUTO_SLOTS.size())

	WQSave.write_auto(m)          # ครั้งที่สี่ต้องวนกลับไปทับช่องแรกซึ่งเก่าที่สุด
	var seqs: Array = []
	for slot in WQSave.AUTO_SLOTS:
		seqs.append(int(WQSave.slot_info(slot).get("seq", -1)))
	_eq("autosave ครั้งที่สี่ทับช่องที่เก่าที่สุด", seqs, [3, 1, 2])


func _eq(label: String, got, want) -> void:
	if typeof(got) == TYPE_FLOAT or typeof(want) == TYPE_FLOAT:
		if is_equal_approx(float(got), float(want)): return
	elif got == want:
		return
	_fails += 1
	print("  ❌ %s: ได้ %s ต้องการ %s" % [label, str(got), str(want)])
