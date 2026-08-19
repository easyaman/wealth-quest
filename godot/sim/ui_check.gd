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
	var before := w._left.value_text
	p.set_sleep(0)          # นอน 5 ชม. → เวลาว่างเพิ่ม ประสิทธิภาพตก
	_ne("แถบเวลาที่เหลืออัปเดตหลังเปลี่ยนการนอน", w._left.value_text, before)
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
	_check_deal_market(m)
	_check_statement(m)
	_check_debt_list(m)

	print("ui_check: %s" % ("ผ่านทั้งหมด ✅" if _fails == 0 else "ไม่ผ่าน %d ข้อ ❌" % _fails))
	quit(1 if _fails > 0 else 0)


func _check_deal_market(m: WQMatch) -> void:
	var p = m.players[0]
	p.place = "home"
	p.hours = p.get_hours_max()

	# เลือกดีลที่ถูกที่สุดแล้วเติมเงินให้พอ เพื่อให้เส้นทาง "กดปิดดีลแล้วซื้อจริง" ถูกทดสอบแน่ๆ
	# ไม่งั้นปุ่มอาจถูก disable แล้วเทสต์ผ่านแบบไม่ได้ตรวจอะไรเลย
	var d: Dictionary = m.deals[0]
	for x in m.deals:
		if float(x.down) < float(d.down): d = x
	p.cash = float(d.down) + p.get_total_expenses() * 3.0

	var mk := WQDealMarket.new()
	mk.bind(p, m)
	_eq("สร้างการ์ดครบทุกดีลในตลาด", mk._grid.get_child_count(), m.deals.size())

	var card: WQDealCard = _card_for_deal(mk, int(d.id))

	# กฎ 12.2.1 — การ์ดต้องบอกผลตอบแทนต่อทุน ไม่ใช่แค่ราคา
	_eq("การ์ดบอกผลตอบแทนต่อทุน %/เดือน", _labels_with(card, "%/ด. ต่อทุน"), 1)
	# กฎ 12.2.3 — ปุ่มติดป้ายราคาเป็นชั่วโมงเสมอ
	var btn := _button_of(card)
	_ne("ปุ่มมีข้อความ", btn.text, "")
	_has("ปุ่มติดป้ายชั่วโมง", btn.text, "ชม.")

	# อยู่บ้าน = ยังไม่ถึงหน้างาน ปุ่มต้องเป็น "เดินทางไป" ไม่ใช่ "ปิดดีล"
	var venue: String = p.place_for(p.act_for_kind(d.kind))
	_ne("ยังไม่ถึงหน้างาน ปุ่มต้องไม่ใช่ปิดดีล", btn.text.contains("ปิดดีล"), true)
	btn.pressed.emit()
	_eq("กดปุ่มแล้วเดินทางไปสถานที่ของดีลจริง", p.place, venue)
	_eq("กดปุ่มแล้วสั่งสร้างการ์ดใหม่", mk._rebuild_queued, true)

	# สร้างใหม่ซ้ำๆ ต้องไม่ทำให้การ์ดสะสม (ทั้งจากสัญญาณ changed และจากปุ่ม)
	mk._rebuild(); mk._rebuild()
	_eq("การ์ดไม่สะสมเมื่อสร้างใหม่ซ้ำ", mk._grid.get_child_count(), m.deals.size())

	# ถึงหน้างานแล้วปุ่มต้องเปลี่ยนเป็นปิดดีล และกดแล้วต้องได้ทรัพย์สินเพิ่มจริง
	var same := _card_for_deal(mk, int(d.id))
	if same == null:
		_fails += 1
		print("  ❌ หาการ์ดของดีลเดิมไม่เจอหลังเดินทาง")
		mk.free(); return
	var btn2 := _button_of(same)
	_has("ถึงหน้างานแล้วปุ่มเปลี่ยนเป็นปิดดีล", btn2.text, "ปิดดีล")
	var before_assets: int = p.assets.size()
	var before_deals: int = m.deals.size()
	_eq("เงินและเวลาพอแล้ว ปุ่มต้องกดได้", btn2.disabled, false)
	btn2.pressed.emit()
	_eq("กดปิดดีลแล้วได้ทรัพย์สินเพิ่ม", p.assets.size(), before_assets + 1)
	_eq("ดีลที่ซื้อไปแล้วต้องหลุดจากตลาด", m.deals.size(), before_deals - 1)

	mk.free()


func _check_statement(m: WQMatch) -> void:
	var p = m.players[0]
	# ส่วนก่อนหน้าเปลี่ยนพาหนะ/สถานที่ไว้ ต้องรีเซ็ตก่อน ไม่งั้นเทสต์อ่านสถานะของส่วนอื่น
	p.vehicle = "public"
	p.devices = []
	p.place = "home"
	var st := WQStatement.new()
	st.bind(p)

	# ทุกบรรทัดต้องตรงกับ core ไม่ใช่คำนวณซ้ำในฝั่ง UI แล้วเพี้ยน
	_eq("งบมีบรรทัดรวมรายรับตรงกับ core", _labels_with(st, WQFmt.n(p.get_total_income()) + "฿") > 0, true)
	_eq("งบมีบรรทัดรวมรายจ่ายตรงกับ core", _labels_with(st, WQFmt.n(p.get_total_expenses()) + "฿") > 0, true)
	_eq("งบมีเหลือเก็บต่อเดือนตรงกับ core",
		_labels_with(st, WQFmt.signed(p.get_monthly_cashflow()) + "฿") > 0, true)
	_eq("งบดุลมีความมั่งคั่งสุทธิตรงกับ core", _labels_with(st, WQFmt.m(p.get_net_worth()) + "฿") > 0, true)
	# เส้นชัยของด่าน 1 ต้องอยู่บนหน้าจอเสมอ
	_eq("บอกว่าครอบคลุมรายจ่ายไปแล้วกี่ %", _labels_with(st, "ครอบคลุมรายจ่ายแล้ว"), 1)

	# ค่าดูแลพาหนะ/อุปกรณ์ต้องโผล่เป็นบรรทัดของตัวเองเมื่อมีจริงเท่านั้น
	_eq("ยังไม่มีพาหนะ จึงไม่มีบรรทัดค่าพาหนะ", _labels_with(st, "ค่าพาหนะ/อุปกรณ์"), 0)
	p.vehicle = "usedcar"
	p.changed.emit()
	_eq("ซื้อพาหนะแล้วต้องมีบรรทัดค่าพาหนะ", _labels_with(st, "ค่าพาหนะ/อุปกรณ์"), 1)
	p.vehicle = "public"
	p.changed.emit()
	st.free()


func _check_debt_list(m: WQMatch) -> void:
	var p = m.players[0]
	p.place = "bank"          # ต้องอยู่ธนาคารถึงจะชำระหนี้ได้
	p.cash = 60000.0
	p.liabilities = [
		{"name": "หนี้ถูก", "balance": 100000.0, "rate": 0.005},
		{"name": "หนี้แพง", "balance": 80000.0, "rate": 0.023},
	]

	var dl := WQDebtList.new()
	dl.bind(p)

	# ข้อ 12.2.5 — ก้อนดอกแพงสุดต้องถูกติดป้ายให้เอง และต้องมีใบเดียว
	_eq("ติดป้ายดอกแพงสุดให้ก้อนที่ดอกสูงสุด", _labels_with(dl, "ดอกแพงสุด"), 1)
	_eq("ป้ายไปอยู่กับก้อนที่ถูกต้อง", _labels_with(dl, "หนี้แพง   ⚠ ดอกแพงสุด"), 1)

	# ข้อ 12.2.4 — ต้องบอกดอกเบี้ยที่ประหยัดได้/เดือน โดยไม่ต้องเอาเมาส์ไปจิ้ม
	_eq("บอกดอกเบี้ยที่ประหยัดได้ต่อเดือนของทั้งสองก้อน", _labels_with(dl, "→ ประหยัด"), 2)

	# กดชำระแล้วยอดต้องลดจริง และต้องลดก้อนที่ถูกต้อง
	var expensive: Dictionary = p.liabilities[1]
	var before: float = float(expensive.balance)
	var hours_before: int = p.hours
	var btn := _quick_button(dl, "หนี้แพง", "50%")
	if btn == null:
		_fails += 1; print("  ❌ หาปุ่มชำระ 50% ของหนี้แพงไม่เจอ"); dl.free(); return
	_eq("อยู่ธนาคารแล้วปุ่มชำระต้องกดได้", btn.disabled, false)
	btn.pressed.emit()
	_eq("ยอดหนี้ก้อนที่กดลดลงจริง", float(expensive.balance) < before, true)
	_eq("ชำระหนี้ไม่กินเวลา (เป็นแค่การโอนเงิน)", p.hours, hours_before)

	dl.free()


## หาปุ่มลัด (25% / 50% / ทั้งหมด) ของหนี้ก้อนที่ชื่อขึ้นต้นตามที่ระบุ
func _quick_button(dl: WQDebtList, debt_name: String, label: String) -> Button:
	for row in dl._list.get_children():
		if _labels_with(row, debt_name) == 0: continue
		for c in row.get_children():
			if not (c is HBoxContainer): continue
			for b in c.get_children():
				if b is Button and (b as Button).text == label: return b
	return null


func _labels_with(node: Node, needle: String) -> int:
	var n := 0
	if node is Label and (node as Label).text.contains(needle): n += 1
	for c in node.get_children(): n += _labels_with(c, needle)
	return n


func _button_of(node: Node) -> Button:
	if node is Button: return node
	for c in node.get_children():
		var b := _button_of(c)
		if b != null: return b
	return null


func _card_for_deal(mk: WQDealMarket, id: int) -> WQDealCard:
	for c in mk._grid.get_children():
		if c is WQDealCard and int((c as WQDealCard)._deal.id) == id: return c
	return null


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
