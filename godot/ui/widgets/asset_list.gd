class_name WQAssetList
extends PanelContainer
## 🏘️ ทรัพย์สินของฉัน (บทที่ 12 ของ GDD)
##
## ข้อ 12.2.1: ทุกชิ้นต้องบอก **"ผลตอบแทนต่อทุน %/เดือน"** ไม่ใช่แค่มูลค่า
## และต้องคิดจาก "เงินที่ควักเองไปจริง" (เงินดาวน์) ไม่ใช่ราคาเต็ม — อสังหาฯ ที่ดาวน์ 20%
## ให้ผลตอบแทนต่อทุนสูงกว่าที่เห็นจากราคาเต็มมาก ถ้าโชว์จากราคาเต็มผู้เล่นจะประเมินผิดทั้งกระดาน
##
## **ชิ้นที่มีคนเสนอซื้อถูกดันขึ้นบนสุดเสมอ** เพราะ GDD 5.3 บอกว่า
## "ขายชิ้นที่มีข้อเสนอ → เอาเงินก้อนไปดาวน์หลายชิ้น" คือวิธีเร่งที่เร็วที่สุดในเกม
## ข้อเสนออยู่แค่ 2 เดือนแล้วหายไป ถ้าปล่อยให้มันจมอยู่กลางรายการ ผู้เล่นจะพลาดของที่สำคัญที่สุด
##
## ตัวเลขทุกช่องมาจาก `WQPlayer.asset_terms()` ซึ่งคิดราคาขายแบบเดียวกับ `sell_asset()` เป๊ะ
## ผู้เล่นจึงกดขายแล้วได้เงินตรงกับที่เห็นเสมอ

const DIM := Color("8fa6bd")
const WARN := Color("ff8080")
const GOOD := Color("7ee08a")
const GOLD := Color("f2b233")

var _player = null
var _title: Label
var _summary: Label
var _list: VBoxContainer
var _rebuilding := false


func _init() -> void:
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 12)
	add_child(margin)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	margin.add_child(col)

	var head := HBoxContainer.new()
	_title = Label.new()
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title.add_theme_font_size_override("font_size", 16)
	head.add_child(_title)
	_summary = Label.new()
	_summary.add_theme_color_override("font_color", DIM)
	_summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	head.add_child(_summary)
	col.add_child(head)

	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 8)
	col.add_child(_list)


func bind(player) -> void:
	if _player == player: return
	if _player != null and _player.changed.is_connected(_queue_rebuild):
		_player.changed.disconnect(_queue_rebuild)
	_player = player
	if _player != null:
		_player.changed.connect(_queue_rebuild)
	refresh()


## เหมือน WQDealMarket/WQDebtList — ห้าม free() ปุ่มทิ้งระหว่างที่ปุ่มนั้นกำลังส่งสัญญาณ pressed
## (กดปุ่ม "ขาย" → changed ยิง → ถ้า rebuild ทันทีจะลบปุ่มที่ยังส่งสัญญาณอยู่)
func _queue_rebuild() -> void:
	if _rebuilding: return
	_rebuilding = true
	_do_rebuild.call_deferred()


func _do_rebuild() -> void:
	_rebuilding = false
	refresh()


func refresh() -> void:
	var p = _player
	if p == null: return
	var n: int = p.assets.size()
	_title.text = "🏘️ ทรัพย์สินของฉัน (%d ชิ้น)" % n
	_summary.text = "มูลค่ารวม %s฿  ·  รายได้ %s฿/เดือน" % [
		WQFmt.m(p.get_asset_value()), WQFmt.n(p.get_passive_income())]

	for c in _list.get_children():
		_list.remove_child(c)
		c.free()

	if n == 0:
		var hint := Label.new()
		hint.text = "ยังไม่มีทรัพย์สินสักชิ้น — รายได้ยังมาจากเงินเดือนล้วนๆ\n" \
			+ "ซื้อดีลใบแรกจากตลาดดีล แล้วรายได้จากทรัพย์สินจะเริ่มไล่ตามรายจ่าย"
		hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		hint.add_theme_color_override("font_color", DIM)
		hint.add_theme_font_size_override("font_size", 13)
		_list.add_child(hint)
		return

	# ชิ้นที่มีข้อเสนอขึ้นก่อนเสมอ แล้วที่เหลือเรียงตามกระแสเงินสดสุทธิจากมากไปน้อย
	var rows: Array = []
	for a in p.assets: rows.append({"a": a, "t": p.asset_terms(a)})
	rows.sort_custom(func(x, y):
		if bool(x.t.has_offer) != bool(y.t.has_offer): return bool(x.t.has_offer)
		return float(x.t.net) > float(y.t.net))
	for r in rows:
		_list.add_child(_row(p, r.a, r.t))


func _row(p, a: Dictionary, t: Dictionary) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 6)
	head.add_child(WQIcon.make(String(a.kind), String(a.icon), 20))
	var name_label := Label.new()
	name_label.text = String(a.name)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.add_theme_font_size_override("font_size", 14)
	head.add_child(name_label)
	var value := Label.new()
	value.text = "มูลค่า %s฿" % WQFmt.m(float(t.price))
	value.add_theme_color_override("font_color", GOLD)
	value.add_theme_font_size_override("font_size", 13)
	head.add_child(value)
	box.add_child(head)

	# บรรทัดผลตอบแทน — หัวใจตามกฎ 12.2.1
	var flow := Label.new()
	flow.text = "   %s฿/เดือน  (%.1f%%/ด. ต่อทุน %s฿)" % [
		WQFmt.signed(float(t.net)), float(t.roi), WQFmt.m(float(t.cost))]
	flow.add_theme_color_override("font_color", GOOD if float(t.net) > 0.0 else WARN)
	flow.add_theme_font_size_override("font_size", 13)
	box.add_child(flow)

	if float(t.debt) > 0.0:
		box.add_child(_dim("   หนี้ที่ผูกอยู่ %s฿ · ค่าผ่อน %s฿/เดือน" % [
			WQFmt.m(float(t.debt)), WQFmt.n(float(t.payment))]))

	var status := _status_text(t)
	if status != "":
		var st := _dim("   " + status)
		st.add_theme_color_override("font_color", WARN)
		box.add_child(st)

	if bool(t.has_offer):
		# ข้อเสนอคือของที่หมดอายุใน 2 เดือน — ต้องเด่นที่สุดในแถว
		var offer := Label.new()
		offer.text = "   💰 มีคนเสนอซื้อ %s฿ (สูงกว่าราคาตลาด %.0f%%) — ได้เงินสด %s฿ · %s฿ เทียบราคาที่ซื้อมา · เหลือ %d เดือน" % [
			WQFmt.m(float(t.sell_price)), float(t.premium) * 100.0,
			WQFmt.m(float(t.proceeds)), WQFmt.signed(float(t.gain)), int(t.offer_ttl)]
		offer.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		offer.add_theme_color_override("font_color", GOLD)
		offer.add_theme_font_size_override("font_size", 13)
		box.add_child(offer)

	box.add_child(_sell_row(p, a, t))
	return box


## ปุ่มขาย — ติดราคาเป็นชั่วโมงเสมอ (กฎ 12.2.3) และบอกเหตุผลเมื่อกดไม่ได้
func _sell_row(p, a: Dictionary, t: Dictionary) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)

	var b := Button.new()
	b.text = "ขาย %s฿ — %d ชม." % [WQFmt.m(float(t.sell_price)), int(t.hours)]
	var id := int(a.id)
	b.pressed.connect(func(): p.sell_asset(id))
	row.add_child(b)

	var note := ""
	if not bool(t.can_sell_here):
		b.disabled = true
		note = "ต้องไปที่ %s ก่อนถึงจะขายได้" % String(t.sell_place)
	elif not p.can_spend(int(t.hours)):
		b.disabled = true
		note = "เวลาไม่พอ ต้องใช้ %d ชม. (เหลือ %d ชม.)" % [int(t.hours), p.hours]
	elif not bool(t.has_offer):
		# ขายเองโดยไม่มีข้อเสนอโดนหักค่านายหน้า/ภาษี — ต้องบอกก่อนกด ไม่ใช่หลังกด
		note = "ไม่มีข้อเสนอ — ขายเองโดนหัก %.0f%% เป็นค่านายหน้า/ภาษี" % [
			(1.0 - float(WQData.cfg.sell_fee)) * 100.0]
	if note != "":
		var l := _dim(note)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if b.disabled: l.add_theme_color_override("font_color", WARN)
		row.add_child(l)
	return row


## สถานะที่ทำให้ทรัพย์สินชิ้นนี้ไม่ทำงานตามปกติตอนนี้
func _status_text(t: Dictionary) -> String:
	if int(t.burned) > 0:
		return "🔥 ถูกไฟไหม้ ไม่มีรายได้อีก %d เดือน" % int(t.burned)
	if int(t.sick) > 0:
		return "📉 ธุรกิจซบเซา รายได้ลดลงอีก %d เดือน" % int(t.sick)
	return ""


func _dim(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_color_override("font_color", DIM)
	l.add_theme_font_size_override("font_size", 12)
	return l
