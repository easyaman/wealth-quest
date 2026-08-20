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
	_check_icons(m)
	_check_deal_market(m)
	_check_statement(m)
	_check_debt_list(m)
	_check_shop(m)
	_check_health_bar(m)
	_check_standings(m)
	await _check_travel_panel(m)
	await _check_asset_list(m)
	_check_hud(m)
	_check_banner(m)
	_check_hint(m)
	await _check_goal_panel(m)
	await _check_dice()
	await _check_dream_roll()

	print("ui_check: %s" % ("ผ่านทั้งหมด ✅" if _fails == 0 else "ไม่ผ่าน %d ข้อ ❌" % _fails))
	quit(1 if _fails > 0 else 0)


## ข้อ 4 ของ Sprint B — UI ต้องใช้ไอคอนที่อบจากเมช ไม่ใช่อีโมจิ
## แต่ของที่ไม่มีเมช (อาหาร สถานะ) ต้องยังเห็นอีโมจิเดิม ห้ามกลายเป็นช่องว่าง
func _check_icons(m: WQMatch) -> void:
	_eq("มีไอคอนของพาหนะที่อบไว้แล้ว", WQIcon.exists("usedcar"), true)
	_eq("มีไอคอนของสถานที่ที่อบไว้แล้ว", WQIcon.exists("bank"), true)
	_eq("ไม่มีไอคอนของสิ่งที่ไม่มีเมช", WQIcon.exists("ค่าอาหาร"), false)

	var got := WQIcon.make("usedcar", "🚗", 16)
	_eq("id ที่มีไอคอน ต้องได้รูป ไม่ใช่ตัวอักษร", got is TextureRect, true)
	got.free()

	var fallback := WQIcon.make("ไม่มีจริง", "🚗", 16)
	_eq("id ที่ไม่มีไอคอน ต้องตกกลับไปเป็นอีโมจิเดิม", fallback is Label, true)
	_eq("อีโมจิสำรองต้องไม่ใช่ช่องว่าง", (fallback as Label).text, "🚗")
	fallback.free()

	# การ์ดดีลจริงต้องมีรูปติดอยู่ ไม่ใช่ตกกลับไปเป็นอีโมจิทุกใบ
	var p = m.players[0]
	var card := WQDealCard.new()
	card.bind(p, m.deals[0])
	_eq("การ์ดดีลใช้รูปไอคอนจริง", _textures_in(card) > 0, true)
	card.free()


func _textures_in(node: Node) -> int:
	var n := 1 if node is TextureRect else 0
	for c in node.get_children(): n += _textures_in(c)
	return n


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


## ร้านพาหนะ/อุปกรณ์ (Sprint B ข้อ 5)
func _check_shop(m: WQMatch) -> void:
	var p = m.players[0]
	p.place = "mall"
	p.vehicle = "public"
	p.devices = []
	p.liabilities = []
	p.cash = 400000.0
	p.changed.emit()

	var shop := WQShop.new()
	shop.bind(p)
	_eq("ร้านมีครบทั้งพาหนะและอุปกรณ์", shop._list.get_child_count(),
		WQData.vehicles.size() + WQData.devices.size())

	# --- ตัวเลขต้องคำนวณจาก commute จริงของผู้เล่นคนนี้ ไม่ใช่ค่ากลางๆ ---
	var t: Dictionary = p.vehicle_terms("usedcar")
	var want_commute: int = roundi(float(p.job.commute) * 0.42)
	_eq("ชั่วโมงเดินทางของรถมือสองคำนวณจาก commute ของอาชีพนี้", int(t.commute), want_commute)
	_eq("เวลาที่ได้คืนคือส่วนต่างจากพาหนะปัจจุบัน",
		int(t.hours_saved), p.get_commute_hours() - want_commute)
	_eq("ค่าใช้จ่ายที่เพิ่มขึ้นเทียบกับพาหนะปัจจุบัน",
		float(t.upkeep_delta), float(WQData.vehicle("usedcar").upkeep))

	# คนที่เดินทางไกลกว่าต้องได้เวลาคืนมากกว่า จากรถคันเดียวกัน — นี่คือเหตุผลที่ต้องเป็น pure function ใน core
	var far = WQPlayer.new()
	far.setup(m, {"name": "คนเดินทางไกล", "job_id": "nurse", "is_ai": true})
	var near = WQPlayer.new()
	near.setup(m, {"name": "คนเดินทางใกล้", "job_id": "programmer", "is_ai": true})
	if int(far.job.commute) != int(near.job.commute):
		var a := int(far.vehicle_terms("usedcar").hours_saved)
		var b := int(near.vehicle_terms("usedcar").hours_saved)
		_eq("รถคันเดียวกันให้ผลต่างกันตาม commute ของแต่ละอาชีพ", a != b, true)

	# --- แถบบนแท่นโชว์ต้องตรงกับ core ---
	var stats := WQShop.vehicle_stats(p, "usedcar")
	_eq("พาหนะมีแถบครบ 3 อย่างตามข้อ 5 ของ Sprint B", stats.size(), 3)
	_has("แถบเวลาที่ได้คืนตรงกับ core", String(stats[2].text), "%+d ชม." % int(t.hours_saved))
	_has("แถบค่าใช้จ่ายตรงกับ core", String(stats[1].text), WQFmt.n(float(t.upkeep)))

	# --- กด "ดู" ต้องบอกออกไปว่าเลือกอะไร ไม่ใช่เปลี่ยนสถานะเอง ---
	var picked: Array = []
	shop.picked.connect(func(k, i): picked.append([k, i]))
	var look := _button_named(shop, "ดู")
	look.pressed.emit()
	_eq("กดดูแล้วบอกออกไปว่าเลือกของชิ้นไหน", picked.size() > 0, true)

	# --- ซื้อจริง ---
	var before_vehicle: String = p.vehicle
	var buy := _button_named(shop, "ดาวน์ %s฿" % WQFmt.m(float(p.vehicle_terms("usedcar").down)))
	if buy == null:
		_fails += 1
		print("  ❌ หาปุ่มซื้อรถมือสองไม่เจอ")
	else:
		_eq("อยู่ที่ห้างและเงินพอ ปุ่มซื้อต้องกดได้", buy.disabled, false)
		buy.pressed.emit()
		_eq("กดซื้อแล้วเปลี่ยนพาหนะจริง", p.vehicle, "usedcar")
		_ne("พาหนะเปลี่ยนไปจากเดิม", p.vehicle, before_vehicle)

	# --- ไม่ได้อยู่ที่ห้าง = ซื้อไม่ได้ ---
	p.vehicle = "public"
	p.place = "home"
	p.changed.emit()
	shop._rebuild()
	var buy2 := _button_named(shop, "ดาวน์ %s฿" % WQFmt.m(float(p.vehicle_terms("usedcar").down)))
	if buy2 != null:
		_eq("ไม่ได้อยู่ที่ห้าง ปุ่มซื้อต้องกดไม่ได้", buy2.disabled, true)

	shop.free()   # WQPlayer เป็น RefCounted คืนหน่วยความจำเองเมื่อหมดการอ้างอิง ไม่ต้อง free()


## หาปุ่มตัวแรกที่มีข้อความตามที่ระบุ
func _button_named(node: Node, text: String) -> Button:
	if node is Button and (node as Button).text == text: return node
	for c in node.get_children():
		var b := _button_named(c, text)
		if b != null: return b
	return null


## ❤️ สุขภาพ — ตัวเลขต้องเป็นชุดเดียวกับที่ settle() จะหักจริง ไม่ใช่คำนวณซ้ำในฝั่ง UI
func _check_health_bar(m: WQMatch) -> void:
	var p = m.players[0]
	p.health = 75.0
	p.set_sleep(2)                    # นอน 7 ชม. = ค่ามาตรฐาน
	var w := WQHealthBar.new()
	w.bind(p)

	_has("โชว์สุขภาพปัจจุบัน", w._bar.value_text, "%d / 100" % int(p.health))
	_has("โชว์ชื่อช่วงสุขภาพจาก core", w._bar.label_text, String(p.health_band().name))
	_has("โชว์ประสิทธิภาพเป็น %", w._cost.text, "%d%%" % roundi(p.get_efficiency() * 100.0))
	# หัวใจของวิดเจ็ต: แปลสุขภาพเป็นชั่วโมงที่หายไป ต้องเท่ากับ ดิบ − ใช้ได้จริง เป๊ะ
	_has("แปลงสุขภาพเป็นชั่วโมงที่หายไป", w._cost.text,
		"%d ชม." % (p.get_raw_free_hours() - p.get_hours_max()))
	_eq("แยกรายการที่มาของสุขภาพครบ", w._parts.get_child_count(), p.health_parts().size())

	# ผลรวมของรายการย่อยต้องเท่ากับยอดที่ core จะหักจริง ไม่งั้นวิดเจ็ตกำลังโกหก
	var sum := 0.0
	for part in p.health_parts(): sum += float(part.value)
	_eq("ผลรวมรายการย่อย = ยอดที่ core จะหักจริง",
		snappedf(sum, 0.0001), snappedf(p.health_delta(), 0.0001))

	# --- คำใบ้ต้องเปลี่ยนตามสถานการณ์ (กฎ 12.2.6) ไม่ใช่ข้อความคงที่ ---
	p.set_sleep(0)                    # นอน 5 ชม. → นอนขาดเกณฑ์อาชีพ
	_eq("นอนขาดจริงแล้ว", p.get_sleep_debt() > 0, true)
	_eq("เตือนเรื่องนอนขาดเฉพาะตอนนอนขาดจริง", _notes_in(w, "นอนน้อยกว่า") > 0, true)
	p.set_sleep(3)                    # นอน 8 ชม. → ไม่ขาดแล้ว
	_eq("นอนพอแล้วคำเตือนต้องหายไป", _notes_in(w, "นอนน้อยกว่า"), 0)

	p.health = 20.0
	p.changed.emit()
	_eq("สุขภาพต่ำกว่าเกณฑ์วิกฤตแล้วเตือนเรื่องล้มป่วย", _notes_in(w, "โซนวิกฤต") > 0, true)
	_eq("อยู่ในโซนวิกฤตแล้วไม่ต้องนับถอยหลังอีก", _notes_in(w, "จะเข้าโซนวิกฤต"), 0)

	# --- refresh ซ้ำต้องไม่ทำให้โหนดสะสม ---
	var n_parts := w._parts.get_child_count()
	var n_notes := w._notes.get_child_count()
	for _i in 3: w.refresh()
	_eq("รายการย่อยไม่สะสมเมื่อ refresh ซ้ำ", w._parts.get_child_count(), n_parts)
	_eq("คำใบ้ไม่สะสมเมื่อ refresh ซ้ำ", w._notes.get_child_count(), n_notes)

	p.health = 75.0
	p.set_sleep(2)
	w.free()


## 🏆 อันดับ — ลำดับต้องมาจาก core และแถบต้องเปลี่ยนความหมายตามด่านของแต่ละคน
func _check_standings(m: WQMatch) -> void:
	var mm := WQMatch.new()
	mm.setup({"mode": "solo", "seed": 20260815, "players": [
		{"name": "คุณ", "job_id": "teacher", "is_ai": false},
		{"name": "บอท A", "job_id": "programmer", "is_ai": true},
		{"name": "บอท B", "job_id": "pilot", "is_ai": true},
	]})
	var me = mm.players[0]
	var w := WQStandings.new()
	w.bind(me, mm)

	_eq("มีแถวครบทุกคนในแมตช์", w._rows.get_child_count(), mm.players.size())
	_has("หัวข้อบอกเดือนปัจจุบัน", w._title.text, str(mm.month))
	# ห้ามใช้ 🏁 เพราะเป็นอีโมจิขาวดำ จะเห็นเป็นกล่องเปล่าบนพื้นเข้มของเกม
	_eq("ไม่ใช้อีโมจิขาวดำในหัวข้อ", w._title.text.contains("🏁"), false)

	# เรียงตามลำดับที่ core จัดให้ ไม่ใช่ลำดับที่วิดเจ็ตคิดเอง
	var order: Array = mm.standings()
	_has("แถวแรกคือคนที่ core จัดไว้อันดับหนึ่ง",
		_row_text(w, 0), String(order[0].pname))

	# ด่าน 1 = โชว์อิสรภาพ · ด่าน 2 = โชว์ความคืบหน้าความฝัน
	_has("ด่าน 1 โชว์อิสรภาพ", _row_text(w, 0), "ด่าน 1")
	me.enter_phase2(WQData.dreams[0], false)
	me.changed.emit()
	var mine := _row_for(w, String(me.pname))
	_has("เข้าด่าน 2 แล้วแถวเปลี่ยนไปพูดเรื่องความฝัน", mine, "ด่าน 2")
	_has("บอกว่าข้อไหนคือตัวถ่วง", mine, String(me.dream_progress().worst_label))

	# --- refresh ซ้ำต้องไม่ทำให้แถวสะสม ---
	for _i in 3: w.refresh()
	_eq("แถวไม่สะสมเมื่อ refresh ซ้ำ", w._rows.get_child_count(), mm.players.size())
	w.free()


## 📍 แผงสถานที่ — ต้อง "บอก" ว่าอยากไปไหน ไม่ใช่ย้ายผู้เล่นเอง (กฎเดียวกับฉากเมือง 3D)
func _check_travel_panel(m: WQMatch) -> void:
	var p = m.players[0]
	p.place = "home"
	p.hours = p.get_hours_max()
	var w := WQTravelPanel.new()
	w.bind(p)

	_eq("มีแถวครบทุกสถานที่", w._list.get_child_count(), WQData.places.size())

	# เรียงตามตำแหน่งบนถนน ไม่ใช่ตามระยะทางจากตัวเรา — ผู้เล่นต้องเห็นว่าอะไรอยู่ทางเดียวกัน
	var xs: Array = []
	for pl in WQData.places: xs.append(int(pl.x))
	xs.sort()
	var shown: Array = []
	for row in w._list.get_children():
		for pl in WQData.places:
			if _labels_with(row, String(pl.name)) > 0 or _button_text(row).contains(String(pl.name)):
				shown.append(int(pl.x))
				break
	_eq("เรียงตามตำแหน่งบนถนน (x)", shown, xs)

	# ปุ่มต้องติดราคาเป็นชั่วโมงเสมอ (กฎ 12.2.3) และตรงกับที่ core คิด
	var bank_btn := _place_button(w, "ธนาคาร")
	_eq("มีปุ่มของธนาคาร", bank_btn != null, true)
	_has("ปุ่มติดราคาเดินทางเป็นชั่วโมง", bank_btn.text, "%d ชม." % p.travel_cost("bank"))

	# กดแล้วต้องแค่ยิงสัญญาณ ห้ามย้ายผู้เล่นเอง
	var got: Array = []
	w.travel_requested.connect(func(id): got.append(id))
	var before_place: String = p.place
	var before_hours: int = p.hours
	bank_btn.pressed.emit()
	_eq("กดแล้วยิงสัญญาณบอกปลายทาง", got, ["bank"])
	_eq("แผงไม่ย้ายผู้เล่นเอง", p.place, before_place)
	_eq("แผงไม่หักเวลาผู้เล่นเอง", p.hours, before_hours)

	# ที่ที่ยืนอยู่ต้องกดไม่ได้ และบอกว่าอยู่ที่นี่
	var home_btn := _place_button(w, "บ้าน")
	_eq("ปุ่มของที่ที่ยืนอยู่กดไม่ได้", home_btn.disabled, true)
	_has("บอกว่าอยู่ที่นี่", home_btn.text, "อยู่ที่นี่")

	# เวลาไม่พอต้องกดไม่ได้ ไม่ใช่ปล่อยให้กดแล้วค่อยขึ้น error
	p.hours = 0
	p.changed.emit()
	await process_frame          # แผงสร้างปุ่มใหม่แบบ deferred (กันปุ่มถูก free ระหว่างส่งสัญญาณ)
	_eq("เวลาไม่พอแล้วปุ่มเดินทางกดไม่ได้", _place_button(w, "ธนาคาร").disabled, true)

	# อุปกรณ์ตัดความจำเป็นในการเดินทางทิ้ง — ต้องบอก ไม่งั้นผู้เล่นเสียเวลาไปฟรีๆ (GDD 3A.3)
	p.hours = p.get_hours_max()
	p.devices.append("smartphone")
	p.changed.emit()
	await process_frame
	_eq("มีสมาร์ตโฟนแล้วธุรกรรมทำที่ไหนก็ได้", p.can_do_here("loan"), true)
	_eq("แผงบอกว่าไม่ต้องเดินทางไปธนาคารแล้ว",
		_row_has(w, "ธนาคาร", "ไม่ต้องเดินทาง"), true)
	p.devices.erase("smartphone")

	# --- refresh ซ้ำต้องไม่ทำให้แถวสะสม ---
	for _i in 3: w.refresh()
	_eq("แถวไม่สะสมเมื่อ refresh ซ้ำ", w._list.get_child_count(), WQData.places.size())
	w.free()


## 🏘️ ทรัพย์สิน — ตัวเลขต้องตรงกับตอนขายจริง และข้อเสนอต้องไม่จมอยู่กลางรายการ
func _check_asset_list(m: WQMatch) -> void:
	var p = m.players[0]
	p.assets.clear()
	p.place = "estate"
	p.hours = p.get_hours_max()
	var w := WQAssetList.new()
	w.bind(p)
	_has("ไม่มีทรัพย์สินแล้วบอกให้ไปซื้อดีลใบแรก", _all_text(w._list), "ยังไม่มีทรัพย์สิน")

	# ซื้อดีลจริงจากตลาด ไม่ใช่ยัด dictionary ปลอมเข้าไป
	var deal: Dictionary = {}
	for d in m.deals:
		if String(d.kind) == "micro" and float(d.down) <= p.cash: deal = d
	if deal.is_empty(): deal = m.deals[0]
	p.cash = maxf(p.cash, float(deal.down) + 1000.0)
	p.place = WQData.place(p.place_for(p.act_for_kind(String(deal.kind)))).id
	var res: Dictionary = p.close_deal(int(deal.id))
	_eq("ซื้อดีลสำเร็จ", res.get("ok", false), true)
	await process_frame
	_eq("มีแถวทรัพย์สินหนึ่งชิ้น", w._list.get_child_count(), 1)

	var a: Dictionary = p.assets[0]
	var t: Dictionary = p.asset_terms(a)
	var text := _all_text(w._list)
	_has("โชว์ผลตอบแทนต่อทุนเป็น %/เดือน (กฎ 12.2.1)", text, "%.1f%%" % float(t.roi))
	_has("ปุ่มขายติดราคาเป็นชั่วโมง", text, "%d ชม." % int(t.hours))
	_has("ราคาขายบนปุ่มตรงกับที่ core คิด", text, WQFmt.m(float(t.sell_price)))

	# ไม่มีข้อเสนอต้องเตือนว่าขายเองโดนหักค่านายหน้า ก่อนกด ไม่ใช่หลังกด
	_eq("ยังไม่มีข้อเสนอ", bool(t.has_offer), false)
	_has("เตือนเรื่องค่านายหน้าตอนยังไม่มีข้อเสนอ", text, "ค่านายหน้า")

	# --- มีข้อเสนอแล้วต้องถูกดันขึ้นบนสุด (GDD 5.3 = วิธีเร่งที่เร็วที่สุดในเกม) ---
	var second: Dictionary = {}
	for d in m.deals:
		if float(d.down) <= p.cash: second = d
	if not second.is_empty():
		p.cash = maxf(p.cash, float(second.down) + 1000.0)
		p.hours = p.get_hours_max()
		p.place = WQData.place(p.place_for(p.act_for_kind(String(second.kind)))).id
		p.close_deal(int(second.id))
	await process_frame
	if p.assets.size() >= 2:
		# ใส่ข้อเสนอให้ "ชิ้นที่กระแสเงินสดน้อยกว่า" เพื่อพิสูจน์ว่าข้อเสนอชนะการเรียงตามรายได้
		var lo = p.assets[0] if p.asset_terms(p.assets[0]).net <= p.asset_terms(p.assets[1]).net 			else p.assets[1]
		lo.offer = {"price": p.asset_price(lo) * 1.25, "ttl": 2}
		p.changed.emit()
		await process_frame
		_has("ชิ้นที่มีข้อเสนออยู่แถวบนสุด", _all_text(w._list.get_child(0)), String(lo.name))
		_has("บอกส่วนต่างเหนือราคาตลาด", _all_text(w._list.get_child(0)), "สูงกว่าราคาตลาด")
		_has("บอกว่าข้อเสนอเหลือกี่เดือน", _all_text(w._list.get_child(0)), "เหลือ 2 เดือน")

	# --- กดขายแล้วต้องขายได้จริง และแถวหายไป ---
	var before: int = p.assets.size()
	p.hours = p.get_hours_max()
	var sell_btn := _sell_button(w, String(p.assets[0].name))
	if sell_btn != null and not sell_btn.disabled:
		sell_btn.pressed.emit()
		await process_frame
		_eq("กดขายแล้วทรัพย์สินหายไปจริง", p.assets.size(), before - 1)
		_eq("แถวหายตามไปด้วย", w._list.get_child_count(), maxi(1, p.assets.size()))

	# --- refresh ซ้ำต้องไม่ทำให้แถวสะสม ---
	var n := w._list.get_child_count()
	for _i in 3: w.refresh()
	_eq("แถวไม่สะสมเมื่อ refresh ซ้ำ", w._list.get_child_count(), n)
	w.free()
	p.assets.clear()
	p.place = "home"


## แถบ HUD — ห้าตัวเลขที่ต้องเห็นตลอดเวลา ต้องตรงกับ core ทุกช่อง
func _check_hud(m: WQMatch) -> void:
	var p = m.players[0]
	var w := WQHud.new()
	w.bind(p, m)
	_has("บอกเดือนปัจจุบัน", w._month.text, str(m.month))
	_has("บอกชื่อและอาชีพ", w._who.text, String(p.job.name))
	_has("เงินสดตรงกับ core", w._cash.text, WQFmt.m(p.cash))
	_has("ความมั่งคั่งสุทธิตรงกับ core", w._net.text, WQFmt.m(p.get_net_worth()))
	_has("เวลาที่เหลือตรงกับ core", w._time.text, "%d / %d" % [p.hours, p.get_hours_max()])
	_has("สุขภาพบอกชื่อช่วงด้วย", w._health.text, String(p.health_band().name))

	# ปุ่มจบตาต้องแค่ยิงสัญญาณ ไม่ใช่จบตาเอง — คนตัดสินใจคือ ui/main.gd
	var fired: Array = []
	w.end_turn_pressed.connect(func(): fired.append(true))
	var before: int = m.month
	w._end.pressed.emit()
	_eq("กดจบตาแล้วยิงสัญญาณ", fired.size(), 1)
	_eq("HUD ไม่จบตาเอง", m.month, before)
	w.free()


## แบนเนอร์ — ต้องซ่อนตัวเองเมื่อไม่มีอะไรประกาศ และโชว์ทั้งชัยชนะและภัยพิบัติที่ยังมีผล
func _check_banner(m: WQMatch) -> void:
	var mm := WQMatch.new()
	mm.setup({"mode": "solo", "seed": 20260815,
		"players": [{"name": "คุณ", "job_id": "teacher", "is_ai": false}]})
	var w := WQBanner.new()
	w.bind(mm)
	_eq("ไม่มีอะไรประกาศแล้วซ่อนทั้งแถบ", w.visible, false)

	var def: Dictionary = WQData.disasters[0]
	mm.active_disasters.append({"def": def, "left": int(def.dur)})
	mm.disaster_started.emit(def)
	_eq("มีภัยพิบัติแล้วแบนเนอร์โผล่", w.visible, true)
	_has("บอกชื่อภัยพิบัติ", _all_text(w._rows), String(def.name))
	_has("บอกว่าเหลืออีกกี่เดือน", _all_text(w._rows), "เหลืออีก %d เดือน" % int(def.dur))

	# GDD 9.3: ต้องประกาศ "อันดับที่" ด้วย ไม่ใช่แค่บอกว่ามีคนชนะ
	var p = mm.players[0]
	p.dream = WQData.dreams[0].duplicate(true)
	p.dream_done = 42
	mm.add_champion(p)
	_has("ประกาศชัยชนะพร้อมอันดับ", _all_text(w._rows), "อันดับ 1")
	_has("บอกเดือนที่ทำสำเร็จ", _all_text(w._rows), "42")

	mm.active_disasters.clear()
	mm.champions.clear()
	w.refresh()
	_eq("ภัยพิบัติจบและไม่มีแชมป์แล้วซ่อนอีกครั้ง", w.visible, false)
	w.free()


## 💡 คำใบ้ — ต้องเปลี่ยนตามสถานการณ์ และพูดข้อที่สำคัญที่สุดข้อเดียว (กฎ 12.2.6)
func _check_hint(m: WQMatch) -> void:
	var p = m.players[0]
	p.assets.clear()
	p.health = 75.0
	p.hours = p.get_hours_max()
	var w := WQHint.new()
	w.bind(p)
	_has("ยังไม่มีทรัพย์สิน = ชวนไปดูตลาดดีล", w._label.text, "ตลาดดีล")

	# สุขภาพวิกฤตต้องชนะคำใบ้เรื่องทรัพย์สิน เพราะเสียหายหนักกว่าถ้าไม่ทำตอนนี้
	p.health = 20.0
	p.changed.emit()
	_has("สุขภาพวิกฤตขึ้นก่อนเรื่องอื่น", w._label.text, "วิกฤต")

	# เวลาหมดต้องบอกให้จบตา ไม่ใช่ปล่อยให้ผู้เล่นนั่งงงว่าทำไมกดอะไรไม่ได้
	p.health = 75.0
	p.hours = 0
	p.changed.emit()
	_has("เวลาหมดแล้วบอกให้จบตา", w._label.text, "จบตา")

	p.hours = p.get_hours_max()
	p.changed.emit()
	w.free()


## 🎯 เป้าหมายด่าน — เกณฑ์ชนะต่างกันคนละด่าน ต้องบอกให้ตรงด่านที่อยู่จริง
func _check_goal_panel(m: WQMatch) -> void:
	var mm := WQMatch.new()
	mm.setup({"mode": "solo", "seed": 20260815,
		"players": [{"name": "คุณ", "job_id": "teacher", "is_ai": false}]})
	var p = mm.players[0]
	var w := WQGoalPanel.new()
	w.bind(p)
	_has("ด่าน 1 พูดเรื่องออกจากสนามแข่งหนู", w._title.text, "สนามแข่งหนู")
	_eq("ด่าน 1 ยังไม่มีปุ่มอ้างสิทธิ์ความฝัน", w._claim.visible, false)

	# ไม่ยิง `changed` เอง — `enter_phase2()` ต้องยิงให้เอง (เคยไม่ยิง แผงเลยค้างที่ด่าน 1)
	p.enter_phase2(WQData.dreams[0], false)
	await process_frame
	_has("เข้าด่าน 2 แล้วหัวข้อเปลี่ยนเป็นชื่อความฝัน", w._title.text,
		String(p.dream.name))
	# GDD 9.2: ต้องครบทั้งสองเงื่อนไข จึงต้องมีสองแถบ ไม่ใช่แถบเดียว
	var bars := 0
	for c in w._body.get_children():
		if c is WQStatBar: bars += 1
	_eq("ด่าน 2 มีสองเกณฑ์ = สองแถบ", bars, 2)
	_eq("ยังไม่ครบเกณฑ์ ปุ่มยังไม่โผล่", w._claim.visible, false)

	# ครบทั้งสองเกณฑ์แล้วปุ่มต้องโผล่ และกดแล้วต้องจบด่านจริง
	p.cash = float(p.dream.cost) * 2.0
	p.assets.append({"id": 999, "kind": "fund", "icon": "📈", "name": "ทดสอบ",
		"value": 1.0, "cost": 1.0, "debt": 0.0,
		"income": float(p.dream.passiveReq) * 2.0, "vol": 0.0, "drift": 1.0,
		"offer": null, "sick": 0, "burned": 0})
	p.changed.emit()
	await process_frame
	_eq("ครบทั้งสองเกณฑ์แล้วปุ่มโผล่", w._claim.visible, true)
	w._claim.pressed.emit()
	await process_frame
	_eq("กดแล้วทำความฝันสำเร็จจริง", p.phase, 3)
	_has("จบแล้วหัวข้อเปลี่ยนเป็นสำเร็จ", w._title.text, "สำเร็จ")
	w.free()


func _sell_button(w: WQAssetList, asset_name: String) -> Button:
	for row in w._list.get_children():
		if _labels_with(row, asset_name) == 0: continue
		return _button_of(row)
	return null


func _button_text(node: Node) -> String:
	var b := _button_of(node)
	return "" if b == null else b.text


func _place_button(w: WQTravelPanel, place_name: String) -> Button:
	for row in w._list.get_children():
		var b := _button_of(row)
		if b != null and b.text.contains(place_name): return b
	return null


func _row_has(w: WQTravelPanel, place_name: String, needle: String) -> bool:
	for row in w._list.get_children():
		var b := _button_of(row)
		if b == null or not b.text.contains(place_name): continue
		return _labels_with(row, needle) > 0
	return false


func _notes_in(w: WQHealthBar, needle: String) -> int:
	var n := 0
	for c in w._notes.get_children(): n += _labels_with(c, needle)
	return n


func _row_text(w: WQStandings, i: int) -> String:
	return _all_text(w._rows.get_child(i))


func _row_for(w: WQStandings, pname: String) -> String:
	for row in w._rows.get_children():
		var t := _all_text(row)
		if t.contains(pname): return t
	return ""


func _all_text(node: Node) -> String:
	var out := ""
	if node is Label: out += (node as Label).text + " "
	# ต้องเก็บข้อความบนปุ่มด้วย — ราคาชั่วโมงตามกฎ 12.2.3 อยู่บนปุ่ม ไม่ใช่บน Label
	if node is Button: out += (node as Button).text + " "
	if node is WQStatBar:
		out += (node as WQStatBar).label_text + " " + (node as WQStatBar).value_text + " "
	for c in node.get_children(): out += _all_text(c)
	return out


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


## หน้าทอยความฝันเข้าด่าน 2 (GDD บทที่ 9) — ตรวจสามเรื่องที่พังแล้วเสียเกม:
## ลำดับ (ทอย → เห็นเกณฑ์ → ค่อยเลือก) · สิทธิ์ทอยใหม่มีครั้งเดียว · เกณฑ์ที่โชว์ = เกณฑ์ที่ใช้จริง
func _check_dream_roll() -> void:
	var mm := WQMatch.new()
	mm.setup({"mode": "solo", "seed": 20260815,
		"players": [{"name": "คุณ", "job_id": "teacher", "is_ai": false}]})
	var p = mm.players[0]
	p.finished = 21
	p.pending_dream = true

	# แต้มต้องกินตัวสุ่มของแมตช์ ไม่งั้นเซฟก่อนทอยแล้วโหลดใหม่จนได้ความฝันที่ชอบได้
	var before: int = mm.rng.s
	var n: int = p.roll_dream()
	_eq("แต้มความฝันอยู่ในช่วง 1–%d" % WQData.dreams.size(),
		n >= 1 and n <= WQData.dreams.size(), true)
	_ne("ทอยความฝันแล้วตัวสุ่มของแมตช์ต้องเดินหน้า", mm.rng.s, before)

	var w := WQDreamRoll.new()
	root.add_child(w)
	w.start(p)
	_has("บอกว่าใช้เวลากี่เดือนถึงออกจากสนามแข่งหนู", w._sub.text, "21 เดือน")
	_eq("ยังไม่ทอย ยังไม่มีความฝัน", w.picked.is_empty(), true)
	_eq("ยังไม่ทอย ยังเลือกลาออก/ทำงานต่อไม่ได้", w._choice.visible, false)

	w.roll(4)
	_eq("ระหว่างกลิ้ง ยังไม่ให้ตัดสินใจ", w._choice.visible, false)
	w._dice.finish_now()
	_eq("ได้ความฝันตรงกับแต้มที่ทอยได้", int(w.picked.roll), 4)
	_eq("ลูกเต๋าหยุดที่แต้มเดียวกับความฝันที่ได้", w._dice.face, 4)
	_eq("ทอยเสร็จแล้วเลือกได้", w._choice.visible, true)
	_eq("ยังไม่ได้ใช้สิทธิ์ทอยใหม่ ปุ่มต้องอยู่", w._reroll_btn.visible, true)
	_has("การ์ดความฝันบอกชื่อความฝัน", _text_of(w._result), String(w.picked.name))

	# GDD 9.2 ต้องครบทั้งสองเกณฑ์ จึงต้องมีสองแถบ และตัวเลขต้องมาจาก core
	var bars := 0
	var terms: Dictionary = p.dream_terms(w.picked)
	for c in w._result.get_children():
		if c is WQStatBar: bars += 1
	_eq("โชว์เกณฑ์ครบสองข้อ", bars, 2)
	_has("เกณฑ์ความมั่งคั่งตรงกับที่ core คำนวณ", _text_of(w._result),
		WQFmt.m(float(terms.cost)))
	_has("เกณฑ์รายได้ต่อเดือนตรงกับที่ core คำนวณ", _text_of(w._result),
		WQFmt.n(float(terms.passive_req)))
	_has("ปุ่มลาออกบอกเวลาที่ได้คืนเป็นตัวเลขจริง", w._retire_btn.text,
		"+%d ชม." % (p.get_work_hours() + p.get_commute_hours()))

	# ทอยใหม่ได้ครั้งเดียว แล้วต้องรับผลครั้งที่สอง
	w.reroll(2)
	w._dice.finish_now()
	_eq("ทอยใหม่แล้วได้ความฝันใหม่", int(w.picked.roll), 2)
	_eq("ใช้สิทธิ์ทอยใหม่ไปแล้ว ปุ่มต้องหาย", w._reroll_btn.visible, false)
	w.reroll(6)
	_eq("ทอยใหม่ครั้งที่สองต้องไม่มีผล", int(w.picked.roll), 2)

	# หน้าจอไม่เปลี่ยนสถานะเอง — ส่งต่อให้ ui/main.gd เป็นคนเรียก enter_phase2()
	var got: Array = []
	w.chosen.connect(func(d: Dictionary, retire: bool): got.assign([String(d.name), retire]))
	w._retire_btn.pressed.emit()
	_eq("กดลาออกแล้วส่งความฝันกับการตัดสินใจออกไป",
		got, [String(w.picked.name), true])
	_eq("หน้าจอต้องไม่ดันผู้เล่นเข้าด่าน 2 เอง", p.phase, 1)

	# เกณฑ์ที่โชว์ตอนเลือก ต้องเป็นเกณฑ์เดียวกับที่ใช้วัดผลจริงทั้งเกม
	var picked_terms: Dictionary = p.dream_terms(w.picked)
	p.enter_phase2(w.picked, true)
	_eq("เกณฑ์ความมั่งคั่งที่ใช้จริงตรงกับที่โชว์", float(p.dream.cost), float(picked_terms.cost))
	_eq("เกณฑ์รายได้ที่ใช้จริงตรงกับที่โชว์",
		float(p.dream.passiveReq), float(picked_terms.passive_req))
	_eq("เข้าด่าน 2 แล้วธง pending_dream ต้องถูกล้าง", p.pending_dream, false)

	w.free()


## ลูกเต๋า — วิดเจ็ตนี้ต้องไม่มีตัวสุ่มของตัวเอง และต้องหยุดที่แต้มที่สั่งเสมอ
func _check_dice() -> void:
	var d := WQDice.new(64.0)
	root.add_child(d)

	# จำนวนจุดต้องเท่ากับแต้ม ไม่งั้นผู้เล่นอ่านหน้าเต๋าผิดตั้งแต่หน้าแรกของเกม
	for n in range(1, 7):
		_eq("หน้า %d มีจุดครบ %d จุด" % [n, n], (WQDice.PIPS[n] as Array).size(), n)

	d.face = 4
	_eq("ตั้งแต้มตรงๆ ได้", d.face, 4)
	await process_frame
	await process_frame
	# บั๊กที่เคยเกิดจริง: Godot เปิด `_process` ให้เองตอนเข้าฉาก แล้ว `_settle()` ลากหน้ากลับไป 1
	_eq("อยู่เฉยๆ หลายเฟรมแล้วแต้มต้องไม่เปลี่ยนเอง", d.face, 4)

	var landed: Array = []
	d.rolled.connect(func(n: int): landed.append(n))
	d.roll_to(6)
	_eq("ระหว่างกลิ้งต้องรู้ตัวว่ากำลังกลิ้ง", d.rolling, true)
	d.roll_to(2)          # กดซ้ำระหว่างกลิ้งต้องไม่เปลี่ยนปลายทาง
	d.finish_now()
	_eq("หยุดที่แต้มที่สั่งครั้งแรก", d.face, 6)
	_eq("ยิงสัญญาณครั้งเดียวต่อการทอยหนึ่งครั้ง", landed, [6])
	await process_frame
	_eq("หยุดแล้วต้องหยุดจริง ไม่กลิ้งต่อ", d.face, 6)

	# เดินเวลาให้ภาพกลิ้งจบเอง (14 หน้า × 0.07 วิ ≈ 1 วิ) — ต้องหยุดที่แต้มที่สั่งเหมือนกัน
	var d2 := WQDice.new(64.0)
	root.add_child(d2)
	d2.roll_to(5)
	d2._process(0.05)
	_eq("เวลายังไม่ถึง ยังกลิ้งอยู่", d2.rolling, true)
	d2._process(1.2)
	_eq("เวลาถึงแล้วหยุดเองที่แต้มที่สั่ง", [d2.rolling, d2.face], [false, 5])
	d2.free()

	d.free()


## รวมข้อความของ Label/RichTextLabel ทุกตัวใต้โหนดหนึ่งมาเป็นก้อนเดียว
func _text_of(node: Node) -> String:
	var out := ""
	if node is Label: out += (node as Label).text + "\n"
	elif node is RichTextLabel: out += (node as RichTextLabel).text + "\n"
	elif node is WQStatBar:
		out += (node as WQStatBar).label_text + " " + (node as WQStatBar).value_text + "\n"
	for c in node.get_children(): out += _text_of(c)
	return out


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


## หมายเหตุบางบรรทัดมีไอคอนนำหน้าแล้ว จึงเป็น HBox[ไอคอน, Label] ไม่ใช่ Label เปล่าๆ
## ต้องไล่ลงไปในลูกด้วย ไม่งั้นจะนับไม่เจอทั้งที่ข้อความอยู่บนจอจริงๆ
func _notes_with(w: WQTimeBudget, needle: String) -> int:
	var n := 0
	for c in w._notes.get_children():
		n += _labels_with(c, needle)
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
