class_name WQDebtList
extends PanelContainer
## หนี้สิน + การชำระบางส่วน (บทที่ 12 ของ GDD)
##
## ข้อ 12.2.4: **ปุ่มชำระหนี้ต้องบอกว่าประหยัดดอกเบี้ยได้เท่าไหร่/เดือน**
## เพราะจ่ายหนี้ให้ความรู้สึกเหมือนเงินหาย ทั้งที่มันคือทรัพย์สินที่ให้ผลตอบแทน
## แน่นอนที่สุดในเกม — ปิดหนี้ดอก 28%/ปี ก้อนละแสน = ลดรายจ่าย 2,300฿/เดือน ตลอดไป
##
## ข้อ 12.2.5: ติดป้าย "ดอกแพงสุด" ให้ก้อนที่ดอกสูงสุดอัตโนมัติ

const DIM := Color("8fa6bd")
const GOOD := Color("7ee08a")
const BAD := Color("ff8080")
const QUICK := [["25%", 0.25], ["50%", 0.5], ["ทั้งหมด", 1.0]]

var _p = null
var _list: VBoxContainer
var _rebuild_queued := false


func _init() -> void:
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 12)
	add_child(margin)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	margin.add_child(col)

	var title := Label.new()
	title.text = "หนี้สิน — ชำระบางส่วนก็ได้ ไม่เสียเวลา"
	title.add_theme_font_size_override("font_size", 15)
	col.add_child(title)

	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 8)
	col.add_child(_list)


func bind(player) -> void:
	if _p == player: return
	if _p != null and _p.changed.is_connected(_queue_rebuild):
		_p.changed.disconnect(_queue_rebuild)
	_p = player
	if _p != null:
		_p.changed.connect(_queue_rebuild)
	_rebuild()


## เหมือน WQDealMarket — ห้ามลบปุ่มทิ้งระหว่างที่ปุ่มนั้นกำลังส่งสัญญาณ pressed อยู่
func _queue_rebuild() -> void:
	if _rebuild_queued: return
	_rebuild_queued = true
	_rebuild.call_deferred()


func _rebuild() -> void:
	_rebuild_queued = false
	for c in _list.get_children():
		_list.remove_child(c); c.free()
	var p = _p
	if p == null: return

	if p.liabilities.is_empty():
		_list.add_child(_text("ปลอดหนี้ 🎉", GOOD))
		return

	var can_repay: bool = p.can_do_here("repay")
	if not can_repay:
		var bank: Dictionary = WQData.place(p.place_for("repay"))
		# ไม่ใส่ 📱 — อีโมจิโทรศัพท์เป็นสีเข้ม วางบนพื้นเข้มแล้วอ่านไม่ออก กลายเป็นกล่องดำ
		_list.add_child(_text("📍 ต้องไปที่ %s %s ก่อนถึงจะชำระหนี้ได้ (เดินทาง %d ชม.) — หรือซื้อสมาร์ตโฟนเพื่อทำผ่านแอป"
			% [bank.icon, bank.name, p.travel_cost(bank.id)], BAD))
	_list.add_child(_text("💡 ปิดหนี้ดอกแพงที่สุดก่อนเสมอ — ดอกเบี้ยที่ประหยัดได้คือรายได้ที่ไม่มีวันขาดทุน", DIM))

	var max_rate := 0.0
	for d in p.liabilities: max_rate = maxf(max_rate, float(d.rate))
	var rate_mod: float = p.match_ref.get_mods().rate

	for d in p.liabilities:
		var eff: float = float(d.rate) * rate_mod
		var is_worst: bool = float(d.rate) >= max_rate and p.liabilities.size() > 1
		_list.add_child(_debt_row(p, d, eff, is_worst, can_repay))


func _debt_row(p, d: Dictionary, eff: float, is_worst: bool, can_repay: bool) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)

	var head := HBoxContainer.new()
	var name_label := Label.new()
	name_label.text = str(d.name) + ("   ⚠ ดอกแพงสุด" if is_worst else "")
	name_label.add_theme_color_override("font_color", BAD if is_worst else Color.WHITE)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	head.add_child(name_label)
	var bal := Label.new()
	bal.text = WQFmt.m(d.balance) + "฿"
	bal.add_theme_color_override("font_color", BAD)
	bal.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	head.add_child(bal)
	box.add_child(head)

	box.add_child(_text("ดอกเบี้ย %d%%/ปี = −%s฿/เดือน" % [roundi(eff * 1200.0), WQFmt.n(float(d.balance) * eff)], DIM))

	var ctl := HBoxContainer.new()
	ctl.add_theme_constant_override("separation", 5)
	for q in QUICK:
		var amount := floorf(minf(float(d.balance) * float(q[1]), p.cash))
		var b := Button.new()
		b.text = str(q[0])
		b.disabled = amount <= 0 or not can_repay
		# ข้อ 12.2.4 — บอกผลของการกดก่อนกด ไม่ใช่หลังกด
		b.tooltip_text = "ชำระ %s฿ → ประหยัดดอกเบี้ย %s฿/เดือน ตลอดไป" % [
			WQFmt.n(amount), WQFmt.n(amount * eff)]
		b.pressed.connect(func(): _repay(p, d, amount))
		ctl.add_child(b)
	box.add_child(ctl)

	# ตัวเลขที่สำคัญที่สุดของแผงนี้ ต้องอ่านได้โดยไม่ต้องเอาเมาส์ไปจิ้ม
	var payable := floorf(minf(float(d.balance), p.cash))
	if payable > 0:
		box.add_child(_text("จ่ายได้ตอนนี้ %s฿ → ประหยัด %s฿/เดือน ตลอดไป%s" % [
			WQFmt.m(payable), WQFmt.n(payable * eff),
			"" if p.cash >= float(d.balance) else " (ปิดได้บางส่วน)"], GOOD))
	else:
		box.add_child(_text("ไม่มีเงินสดเหลือให้ชำระตอนนี้", DIM))
	return box


## หา index ตอนกดจริง ไม่ใช้ index ตอนสร้างปุ่ม เพราะก้อนก่อนหน้าอาจถูกปิดไปแล้ว
## แล้ว index จะเลื่อน ทำให้จ่ายผิดก้อน
func _repay(p, d: Dictionary, amount: float) -> void:
	for i in p.liabilities.size():
		if is_same(p.liabilities[i], d):
			p.repay_debt(i, amount)
			return


func _text(t: String, color: Color) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", 12)
	l.add_theme_color_override("font_color", color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l
