extends SceneTree
## ตรวจตรรกะของวิดเจ็ต UI แบบ headless — ไม่ต้องเปิดหน้าต่างเกม
##   godot --headless --path . --script res://sim/ui_check.gd
## ตรวจว่าวิดเจ็ตอ่านค่าจาก core ถูก · subscribe สัญญาณ changed จริง · และไม่สะสมโหนดซ้ำ
##
## ดูหน้าตาจริงด้วย:  WQ_SHOT=/tmp/ui.png godot --path .

var _fails := 0

func _init() -> void:
	WQData.load_all()
	var m := WQMatch.new()
	m.setup({"mode": "solo", "seed": 20260815,
		"players": [{"name": "คุณ", "job_id": "teacher", "is_ai": false}]})
	var p = m.players[0]

	var w := WQTimeBudget.new()
	w.bind(p)

	# --- อ่านค่าจาก core ถูกไหม ---
	_has("ชั่วโมงที่ผูกมัดไปแล้ว", w._committed.text, str(p.get_committed_hours()))
	_has("ชั่วโมงที่ใช้ได้จริง", w._usable.text, str(p.get_hours_max()))
	_has("ประสิทธิภาพ", w._eff.text, "%d%%" % roundi(p.get_efficiency() * 100.0))

	# ทุกช่วงเวลารวมกันต้องได้ 720 พอดี ไม่งั้นแถบจะโกหกว่าชีวิตหายไปไหน
	var frac := 0.0
	for s in w._bar.segments: frac += float(s.frac)
	_eq("สัดส่วนของแถบรวมกัน", snappedf(frac, 0.0001), 1.0)
	_eq("จำนวนป้ายสีเท่าจำนวนช่วง", w._legend.get_child_count(), w._bar.segments.size())

	# --- สัญญาณ changed ต้องพาวิดเจ็ตอัปเดตเอง ---
	var before := w._left.text
	p.set_sleep(0)          # นอน 5 ชม. → เวลาว่างเพิ่ม ประสิทธิภาพตก
	_ne("แถบเวลาที่เหลืออัปเดตหลังเปลี่ยนการนอน", w._left.text, before)
	_has("ชั่วโมงที่ใช้ได้จริงอัปเดตตาม", w._usable.text, str(p.get_hours_max()))

	# --- refresh ซ้ำในเฟรมเดียวต้องไม่ทำให้โหนดสะสม ---
	var n_legend := w._legend.get_child_count()
	var n_notes := w._notes.get_child_count()
	for _i in 3: w.refresh()
	_eq("ป้ายสีไม่สะสมเมื่อ refresh ซ้ำ", w._legend.get_child_count(), n_legend)
	_eq("หมายเหตุไม่สะสมเมื่อ refresh ซ้ำ", w._notes.get_child_count(), n_notes)

	# --- หมายเหตุตามสถานการณ์ต้องโผล่เมื่อเงื่อนไขเป็นจริงเท่านั้น ---
	_eq("ยังไม่ได้เดินทาง จึงไม่มีหมายเหตุเรื่องเดินทาง", _notes_with(w, "เดินทางแล้ว"), 0)
	p.travel_to("bank")
	_eq("เดินทางแล้วต้องมีหมายเหตุ", _notes_with(w, "เดินทางแล้ว"), 1)
	_eq("อยู่นอกบ้านต้องเตือนเรื่องตั้งค่าที่บ้าน", _notes_with(w, "บ้าน เท่านั้น"), 1)

	p.vehicle = "usedcar"
	p.changed.emit()
	_eq("มีพาหนะแล้วต้องบอกว่าเวลาไปงานลดเหลือเท่าไหร่", _notes_with(w, "เวลาไปทำงานเหลือ"), 1)
	_has("แถบสะท้อนเวลาเดินทางที่ลดลง", w._committed.text, str(p.get_committed_hours()))

	# --- ผูกกับผู้เล่นคนใหม่ต้องถอดสัญญาณเดิม ไม่งั้นวิดเจ็ตจะวาดข้อมูลของคนก่อน ---
	var q := WQPlayer.new()
	q.setup(m, {"name": "อีกคน", "job_id": "programmer", "is_ai": true})
	w.bind(q)
	_eq("ถอดสัญญาณของผู้เล่นคนเดิมแล้ว", p.changed.is_connected(w.refresh), false)
	_eq("ต่อสัญญาณของผู้เล่นคนใหม่แล้ว", q.changed.is_connected(w.refresh), true)
	_has("แสดงค่าของผู้เล่นคนใหม่", w._usable.text, str(q.get_hours_max()))

	w.free()
	print("ui_check: %s" % ("ผ่านทั้งหมด ✅" if _fails == 0 else "ไม่ผ่าน %d ข้อ ❌" % _fails))
	quit(1 if _fails > 0 else 0)


func _notes_with(w: WQTimeBudget, needle: String) -> int:
	var n := 0
	for c in w._notes.get_children():
		if c is Label and (c as Label).text.contains(needle): n += 1
	return n


func _eq(label: String, got, want) -> void:
	if got == want: return
	_fails += 1
	print("  ❌ %s: ได้ %s ต้องการ %s" % [label, str(got), str(want)])


func _ne(label: String, got, unwanted) -> void:
	if got != unwanted: return
	_fails += 1
	print("  ❌ %s: ค่าไม่เปลี่ยนเลย (%s)" % [label, str(got)])


func _has(label: String, haystack: String, needle: String) -> void:
	if haystack.contains(needle): return
	_fails += 1
	print("  ❌ %s: \"%s\" ไม่มี \"%s\"" % [label, haystack, needle])
