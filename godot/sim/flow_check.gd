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
	WQSave.dir = "user://saves_test"      # ห้ามแตะไฟล์เซฟจริงของผู้เล่น
	for slot in WQSave.MANUAL_SLOTS + WQSave.AUTO_SLOTS:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(WQSave.path_for(slot)))

	_main = load("res://ui/Main.tscn").instantiate()
	root.add_child(_main)
	await process_frame

	await _check_setup_to_match()
	await _check_tutorial()
	await _check_match_to_phase2()
	await _check_save_load()
	await _check_hotseat_setup()

	print("flow_check: %s" % ("ผ่านทั้งหมด ✅" if _fails == 0 else "ไม่ผ่าน %d ข้อ ❌" % _fails))
	quit(1 if _fails > 0 else 0)


## หน้า setup → เลือกอาชีพ → แมตช์เริ่มจริง
func _check_setup_to_match() -> void:
	_eq("เปิดเกมมาต้องอยู่ที่หน้าเมนูเลือกจำนวนคน", _main.mode_screen != null, true)
	_eq("ยังไม่เลือกอะไร ยังไม่มีแมตช์", _main.m == null, true)

	_main.mode_screen.buttons[0].pressed.emit()      # เล่นคนเดียว
	await process_frame
	_eq("เลือกคนเดียวแล้วต้องไปที่หน้าทอยเต๋า", _main.setup_screen != null, true)
	_eq("หน้าเมนูต้องถูกเก็บทิ้ง", _main.mode_screen == null, true)

	_main.setup_screen.skip_to_jobs(4)
	var job_id := String(_main.setup_screen.offer.jobs[0].id)
	_main.setup_screen._job.select(job_id)
	_eq("เกมคนเดียวไม่ต้องมีป้ายที่นั่ง",
		_main.setup_screen._job._head.text.contains("ผู้เล่น"), false)

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
	_eq("เล่นคนเดียวยังได้โต๊ะ 4 ที่นั่ง", _main.m.players.size(), WQSetup.SEATS)
	var bots := 0
	for pl in _main.m.players:
		if pl.is_ai: bots += 1
	_eq("เล่นคนเดียวมีบอท 3 ตัว", bots, 3)
	_eq("เล่นคนเดียวโหมดยังเป็น solo", String(_main.m.mode), "solo")


## การสอน 5 เดือนแรก — ต้องเปิดเองสำหรับเกมใหม่ ชี้ถูกวิดเจ็ต และสเต็ปที่ให้ลงมือทำต้องรอจริง
func _check_tutorial() -> void:
	var tut: WQTutorial = _main.tutorial
	_eq("เกมใหม่ต้องเปิดการสอนให้เอง", tut.running, true)
	_eq("เริ่มที่สเต็ปแรก", tut.step, 0)
	_eq("การ์ดสอนต้องเห็น", tut.visible, true)
	# ทั้งแผ่นต้องปล่อยคลิกผ่านไปที่เกม ไม่งั้นการสอนจะกลายเป็นกำแพงขวางการเล่น
	_eq("โอเวอร์เลย์ต้องไม่กินคลิก", tut.mouse_filter, Control.MOUSE_FILTER_IGNORE)
	await process_frame

	# วงแหวนต้องครอบวิดเจ็ตที่สเต็ปนั้นพูดถึงจริงๆ ไม่ใช่ลอยอยู่เฉยๆ
	_eq("สเต็ปแรกชี้ที่แผงงบเวลา", tut._ring.visible, true)
	var ring := Rect2(tut._ring.global_position, tut._ring.size)
	var target := Rect2(_main.time_budget.global_position, _main.time_budget.size)
	_eq("วงแหวนครอบแผงงบเวลาทั้งแผง", ring.encloses(target), true)

	tut._next.pressed.emit()
	_eq("กดถัดไปแล้วเดินไปสเต็ปหน้า", tut.step, 1)

	# สเต็ปที่ให้ลงมือทำ: ห้ามมีปุ่มถัดไป และต้องข้ามเองเมื่อทำสำเร็จจริง
	var wait_step := -1
	for i in tut._steps.size():
		if (tut._steps[i] as Dictionary).has("done"):
			wait_step = i
			break
	tut.step = wait_step
	tut.refresh()
	_eq("สเต็ปที่ให้ลงมือทำต้องไม่มีปุ่มถัดไป", tut._next.visible, false)
	_eq("และต้องบอกว่ากำลังรออะไรอยู่", tut._wait.visible, true)

	var p = _main.m.get_current()
	p.cash = 5_000_000.0
	p.place = "estate"
	p.hours = p.get_hours_max()
	p.close_deal(int(_main.m.deals[0].id))
	_main._refresh()
	_eq("ปิดดีลแล้วการสอนต้องเดินต่อเอง", tut.step > wait_step, true)

	# สถานะที่จะถูกเก็บลงไฟล์เซฟ
	_eq("สถานะการสอนที่จะเซฟ = สเต็ปปัจจุบัน", int(_main._ui_state().get("tut")), tut.step)


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


## บันทึก → เดินเกมต่อ → โหลดกลับ ต้องได้เกมเดิมเป๊ะ รวมถึงตัวสุ่ม
func _check_save_load() -> void:
	var month_at_save: int = _main.m.month
	var rng_at_save: int = _main.m.rng.s
	var tut_at_save: int = _main.tutorial.step

	_main.hud.save_pressed.emit()
	_eq("กด 💾 แล้วหน้าบันทึกต้องเปิด", _main.save_panel != null, true)
	_slot_button(0).pressed.emit()
	await process_frame
	_eq("บันทึกแล้วหน้าบันทึกต้องปิดเอง", _main.save_panel == null, true)
	_eq("ช่อง 1 ต้องมีไฟล์แล้ว", WQSave.slot_info("1").get("empty"), false)

	# เดินเกมต่อ — สิ้นเดือนต้อง autosave ให้เองด้วย (GDD 14.3)
	_main._end_turn()
	_eq("เดือนเดินหน้าแล้ว", _main.m.month, month_at_save + 1)
	_eq("สิ้นเดือนต้อง autosave ให้เอง", WQSave.slot_info("auto1").get("empty"), false)

	_main.hud.load_pressed.emit()
	_eq("กด 📂 แล้วหน้าโหลดต้องเปิด", _main.save_panel != null, true)
	_slot_button(0).pressed.emit()
	await process_frame
	_eq("โหลดแล้วหน้าโหลดต้องปิดเอง", _main.save_panel == null, true)
	_eq("ย้อนกลับไปเดือนที่บันทึกไว้", _main.m.month, month_at_save)
	# กฎเหล็กข้อ 4: state ตัวสุ่มต้องกลับมาด้วย ไม่งั้นผู้เล่นเซฟ-โหลดรีดผลที่ชอบได้
	_eq("state ของตัวสุ่มกลับมาเหมือนตอนบันทึก", _main.m.rng.s, rng_at_save)
	# การสอนต้องสอนต่อจากสเต็ปเดิม ไม่ใช่เริ่มสอนใหม่ทั้งหมดทุกครั้งที่โหลด
	_eq("โหลดแล้วการสอนต่อจากสเต็ปเดิม", _main.tutorial.step, tut_at_save)

	# หลังโหลด สัญญาณต้องไม่ต่อซ้ำ — กดเดินทางทีเดียวต้องเดินทางรอบเดียว
	var p = _main.m.get_current()
	p.place = "home"
	p.travel_used = 0
	var cost: int = p.travel_cost("bank")
	_main.travel_panel.travel_requested.emit("bank")
	_eq("กดเดินทางทีเดียว เสียเวลาเดินทางรอบเดียว", p.travel_used, cost)
	_eq("ไปถึงที่ที่กด", String(p.place), "bank")


## ปุ่มของแถวที่ i ในหน้าบันทึก/โหลด (แถว 0–2 = ช่องที่ผู้เล่นกดเอง)
## โต๊ะ hot-seat: ทอยเต๋าและเลือกอาชีพทีละคนจนครบ แล้วเข้าเกมที่มีคนจริงสองคน
func _check_hotseat_setup() -> void:
	var main2: Control = load("res://ui/Main.tscn").instantiate()
	root.add_child(main2)
	await process_frame

	main2.mode_screen.buttons[1].pressed.emit()      # เล่น 2 คน
	await process_frame
	_eq("เลือก 2 คนแล้วไปที่หน้าทอยเต๋าของผู้เล่น 1", main2.setup_screen != null, true)
	_has("หัวข้อบอกว่ากำลังตั้งที่นั่งของใคร", main2.setup_screen._title.text, "ผู้เล่น 1")

	var first_offer_seed: int = main2.setup_screen._seed
	main2.setup_screen.skip_to_jobs(4)
	var job1 := String(main2.setup_screen.offer.jobs[0].id)
	main2.setup_screen._job.select(job1)
	main2.setup_screen._job._confirm.pressed.emit()
	await process_frame

	_eq("ตั้งที่นั่งแรกเสร็จแล้วยังไม่เริ่มเกม", main2.m == null, true)
	_eq("ต้องเด้งหน้าทอยเต๋าของผู้เล่น 2 ต่อทันที", main2.setup_screen != null, true)
	_has("หัวข้อเปลี่ยนเป็นผู้เล่น 2", main2.setup_screen._title.text, "ผู้เล่น 2")
	# เมล็ดเดียวกันทุกคน = ทุกคนทอยได้แต้มเดียวกันและได้ชุดอาชีพเดียวกันเป๊ะ
	_ne_int("ผู้เล่นคนที่สองใช้เมล็ดคนละตัว", main2.setup_screen._seed, first_offer_seed)

	main2.setup_screen.skip_to_jobs(2)
	_has("หน้าเลือกอาชีพยังบอกว่าเป็นที่นั่งของใคร",
		main2.setup_screen._job._head.text, "ผู้เล่น 2")
	var job2 := String(main2.setup_screen.offer.jobs[0].id)
	main2.setup_screen._job.select(job2)
	main2.setup_screen._job._confirm.pressed.emit()
	await process_frame

	_eq("ตั้งครบสองที่นั่งแล้วเกมต้องเริ่ม", main2.m != null, true)
	_eq("หน้าทอยเต๋าต้องถูกเก็บทิ้ง", main2.setup_screen == null, true)
	_eq("โต๊ะมี 4 ที่นั่ง", main2.m.players.size(), WQSetup.SEATS)
	var humans := 0
	for pl in main2.m.players:
		if not pl.is_ai: humans += 1
	_eq("คนจริงสองคน", humans, 2)
	_eq("โหมดเป็น multi", String(main2.m.mode), "multi")
	_eq("ผู้เล่น 1 ได้อาชีพที่เลือก", String(main2.m.players[0].job.id), job1)
	_eq("ผู้เล่น 2 ได้อาชีพที่เลือก", String(main2.m.players[1].job.id), job2)
	# การสอนชี้วิดเจ็ตของคนเดียว ในโต๊ะหลายคนมันจะชี้ผิดคนทันทีที่เปลี่ยนตา
	_eq("โต๊ะหลายคนต้องไม่เปิดการสอน", main2.tutorial.running, false)

	# --- ม่านส่งเครื่อง ---
	# ตั้งที่นั่งสุดท้ายเสร็จ เครื่องยังอยู่ในมือผู้เล่นคนสุดท้าย ถ้าไม่มีม่านคั่น
	# จอของผู้เล่น 1 (เงินสด หนี้ ดีลที่ถืออยู่) จะโผล่ใส่หน้าเขาทันที
	_eq("ตั้งโต๊ะเสร็จต้องมีม่านก่อนตาแรก", main2.pass_screen != null, true)
	main2.pass_screen._btn.pressed.emit()
	await process_frame
	_eq("กดพร้อมแล้วม่านแรกต้องเปิด", main2.pass_screen == null, true)

	var p1 = main2.m.get_current()
	main2._end_turn()
	await process_frame
	_eq("จบตาคนแรกแล้วต้องมีม่านกั้น", main2.pass_screen != null, true)
	var p2 = main2.m.get_current()
	_ne_obj("ม่านกั้นให้คนละคนกับคนที่เพิ่งเล่นจบ", p2, p1)
	_has("ม่านบอกว่าเป็นตาของใคร", main2.pass_screen._name.text, String(p2.pname))

	# ม่านต้องกันคีย์ SPACE ด้วย ไม่งั้นเคาะทะลุไปจบตาของคนที่ยังไม่ได้เริ่มเล่น
	var turn_before: int = main2.m.turn
	var key := InputEventKey.new()
	key.keycode = KEY_SPACE
	key.pressed = true
	main2._unhandled_input(key)
	_eq("เคาะ SPACE ทะลุม่านไม่ได้", main2.m.turn, turn_before)

	main2.pass_screen._btn.pressed.emit()
	await process_frame
	_eq("กดพร้อมแล้วม่านต้องเปิด", main2.pass_screen == null, true)
	_eq("เปิดม่านแล้วยังเป็นตาคนเดิม", main2.m.get_current(), p2)

	main2.queue_free()
	await process_frame


func _slot_button(i: int) -> Button:
	var row: Control = _main.save_panel._rows.get_child(i)
	return row.get_child(row.get_child_count() - 1)


func _eq(label: String, got, want) -> void:
	if got == want: return
	_fails += 1
	print("  ❌ %s: ได้ %s ต้องการ %s" % [label, str(got), str(want)])


func _has(label: String, haystack: String, needle: String) -> void:
	if haystack.contains(needle): return
	_fails += 1
	print("  ❌ %s: \"%s\" ไม่มี \"%s\"" % [label, haystack, needle])


func _ne_int(label: String, got: int, unwanted: int) -> void:
	if got != unwanted: return
	_fails += 1
	print("  ❌ %s: ค่าซ้ำกัน (%d)" % [label, got])


func _ne_obj(label: String, got, unwanted) -> void:
	if got != unwanted: return
	_fails += 1
	print("  ❌ %s: ได้คนเดิม (%s)" % [label, str(got)])
