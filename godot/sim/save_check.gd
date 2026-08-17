extends SceneTree
## ตรวจว่าเซฟ/โหลดเก็บครบ โดยเฉพาะ state ของตัวสุ่มและระบบแผนที่
##   godot --headless --path . --script res://sim/save_check.gd
## ต้องรันทุกครั้งที่แก้ core/save.gd หรือเพิ่มฟิลด์ใน WQPlayer

var _fails := 0

func _init() -> void:
	WQData.load_all()
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

	print("save_check: %s" % ("ผ่านทั้งหมด ✅" if _fails == 0 else "ไม่ผ่าน %d ข้อ ❌" % _fails))
	quit(1 if _fails > 0 else 0)

func _eq(label: String, got, want) -> void:
	if typeof(got) == TYPE_FLOAT or typeof(want) == TYPE_FLOAT:
		if is_equal_approx(float(got), float(want)): return
	elif got == want:
		return
	_fails += 1
	print("  ❌ %s: ได้ %s ต้องการ %s" % [label, str(got), str(want)])
