extends SceneTree
## ตรวจ "การต่อสาย" ของหน้าจอจริงใน `ui/main.gd` แบบ headless
##   godot --headless --path . --script res://sim/flow_check.gd
##
## `ui_check` ตรวจวิดเจ็ตทีละตัว แต่ไม่มีใครตรวจว่า **หน้าจอส่งไม้ต่อกันได้จริงไหม**
## ซึ่งเป็นจุดที่พังแล้วเกมเดินต่อไม่ได้เลย และพังแบบเงียบมาก — บั๊กสองตัวที่เจอตอนทำหน้านี้:
##
##   1. `free()` หน้าจอทิ้งระหว่างที่ปุ่มของมันกำลังส่งสัญญาณ `pressed` อยู่ → Godot ปฏิเสธ
##      แล้ว **ทั้งฟังก์ชันที่กำลังทำงานหลุดกลางคัน** ผลคือกดปุ่มแล้วไม่มีอะไรเกิดขึ้น
##   2. `enter_phase2()` ไม่ยิง `changed` → แผงเป้าหมายค้างที่ด่าน 1 ทั้งที่เข้าด่าน 2 ไปแล้ว
##
## ต้องรัน **โดยไม่ตั้ง `WQ_JOB`** เพราะเทสต์นี้เริ่มจากหน้า setup จริงๆ

var _fails := 0
var _main: Control


func _init() -> void:
	_main = load("res://ui/Main.tscn").instantiate()
	root.add_child(_main)
	await process_frame

	await _check_setup_to_match()
	await _check_match_to_phase2()

	print("flow_check: %s" % ("ผ่านทั้งหมด ✅" if _fails == 0 else "ไม่ผ่าน %d ข้อ ❌" % _fails))
	quit(1 if _fails > 0 else 0)


## หน้า setup → เลือกอาชีพ → แมตช์เริ่มจริง
func _check_setup_to_match() -> void:
	_eq("เปิดเกมมาต้องอยู่ที่หน้า setup", _main.setup_screen != null, true)
	_eq("ยังไม่เลือกอาชีพ ยังไม่มีแมตช์", _main.m == null, true)

	_main.setup_screen.skip_to_jobs(4)
	var job_id := String(_main.setup_screen.offer.jobs[0].id)
	_main.setup_screen._job.select(job_id)

	# กดปุ่มยืนยันจริง — นี่คือเส้นทางที่เคยขาดเพราะ free() ระหว่างปุ่มกำลังส่งสัญญาณ
	_main.setup_screen._job._confirm.pressed.emit()
	await process_frame

	_eq("กดยืนยันแล้วต้องมีแมตช์", _main.m != null, true)
	_eq("หน้า setup ต้องถูกเก็บทิ้ง", _main.setup_screen == null, true)
	var p = _main.m.get_current()
	_eq("ผู้เล่นได้อาชีพที่เลือกจริง", String(p.job.id), job_id)
	_eq("แต้มที่ทอยได้ถูกส่งเข้าแมตช์", p.roll, 4)
	_eq("โบนัสเวลาจากแต้มถูกส่งเข้าแมตช์", p.bonus_hours,
		int(WQData.cfg.roll_table["4"].bonusHours))


## ออกจากสนามแข่งหนู → หน้าทอยความฝัน → เข้าด่าน 2
func _check_match_to_phase2() -> void:
	var p = _main.m.get_current()
	p.finished = _main.m.month
	p.pending_dream = true
	_main._refresh()

	_eq("ผ่านด่าน 1 แล้วต้องเด้งหน้าทอยความฝันเอง", _main.dream_screen != null, true)

	# ระหว่างรอเลือกความฝัน ห้ามเดินเดือนต่อ ไม่งั้นผู้เล่นข้ามด่าน 2 ไปได้ทั้งด่าน
	var month_before: int = _main.m.month
	_main._end_turn()
	_eq("จบตาไม่ได้ระหว่างรอเลือกความฝัน", _main.m.month, month_before)

	_main.dream_screen.skip_to(3)
	var dream_name := String(_main.dream_screen.picked.name)
	_main.dream_screen._keep_btn.pressed.emit()
	await process_frame

	_eq("เลือกแล้วหน้าทอยความฝันต้องปิด", _main.dream_screen == null, true)
	_eq("เข้าด่าน 2 จริง", p.phase, 2)
	_eq("ได้ความฝันที่ทอยได้", String(p.dream.name), dream_name)
	_eq("เลือก \"ทำงานต่อ\" แล้วต้องไม่ลาออก", p.retired, false)
	# แผงเป้าหมายต้องเปลี่ยนตามเอง (ผ่านสัญญาณ `changed` ของ core ไม่ใช่ให้ UI ไปสั่งเอง)
	_has("แผงเป้าหมายเปลี่ยนไปเป็นด่าน 2", _main.goal_panel._title.text, dream_name)

	_main._end_turn()
	_eq("ตัดสินใจแล้วจบตาได้ตามปกติ", _main.m.month, month_before + 1)


func _eq(label: String, got, want) -> void:
	if got == want: return
	_fails += 1
	print("  ❌ %s: ได้ %s ต้องการ %s" % [label, str(got), str(want)])


func _has(label: String, haystack: String, needle: String) -> void:
	if haystack.contains(needle): return
	_fails += 1
	print("  ❌ %s: \"%s\" ไม่มี \"%s\"" % [label, haystack, needle])
