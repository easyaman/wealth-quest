class_name WQStatement
extends PanelContainer
## งบกำไรขาดทุน + งบดุล (บทที่ 12 ของ GDD)
##
## นี่คือหน้าจอที่บอกว่าผู้เล่นชนะหรือแพ้: เกมจบเมื่อ "รายได้จากทรัพย์สิน ≥ รายจ่าย"
## ทั้งสองตัวเลขจึงต้องอยู่ในสายตาตลอด และต้องเห็นว่าแต่ละบรรทัดดันตัวเลขไปทางไหน

const DIM := Color("8fa6bd")
const GOOD := Color("7ee08a")
const BAD := Color("ff8080")
const GOLD := Color("ffd76a")
const ACCENT := Color("7fd8ff")

var _p = null
var _income: VBoxContainer
var _balance: VBoxContainer
var _free: Label


func _init() -> void:
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 12)
	add_child(margin)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	margin.add_child(col)

	col.add_child(_heading("งบกำไรขาดทุน — เข้าเท่าไหร่ ออกเท่าไหร่"))
	_income = VBoxContainer.new()
	_income.add_theme_constant_override("separation", 1)
	col.add_child(_income)

	_free = Label.new()
	_free.add_theme_font_size_override("font_size", 13)
	col.add_child(_free)

	col.add_child(_heading("งบดุล — มีอะไรอยู่ ติดหนี้เท่าไหร่"))
	_balance = VBoxContainer.new()
	_balance.add_theme_constant_override("separation", 1)
	col.add_child(_balance)


func bind(player) -> void:
	if _p == player: return
	if _p != null and _p.changed.is_connected(refresh):
		_p.changed.disconnect(refresh)
	_p = player
	if _p != null:
		_p.changed.connect(refresh)
	refresh()


func refresh() -> void:
	var p = _p
	if p == null: return
	_clear(_income)
	_clear(_balance)

	var salary_note := ""
	if p.retired: salary_note = " (เกษียณ)"
	elif p.downsize_left > 0: salary_note = " (ตกงาน!)"
	_row(_income, "เงินเดือน" + salary_note, WQFmt.n(p.get_current_salary()) + "฿", GOOD)
	_row(_income, "รายได้จากทรัพย์สิน (%d รายการ)" % p.assets.size(),
		WQFmt.n(p.get_passive_income()) + "฿", ACCENT)
	_row(_income, "รวมรายรับ", WQFmt.n(p.get_total_income()) + "฿", GOOD, true)

	_row(_income, "รายจ่ายประจำ", "−" + WQFmt.n(p.fixed_expenses) + "฿", BAD)
	_row(_income, "ค่าอาหาร (%s %s)" % [p.food_opt().icon, p.food_opt().label],
		"−" + WQFmt.n(p.get_food_cost()) + "฿", BAD)
	if p.child_cost > 0:
		_row(_income, "ค่าเลี้ยงลูก", "−" + WQFmt.n(p.child_cost) + "฿", BAD)
	if p.get_upkeep_cost() > 0:
		_row(_income, "ค่าพาหนะ/อุปกรณ์ %s" % p.get_veh().icon,
			"−" + WQFmt.n(p.get_upkeep_cost()) + "฿", BAD)
	_row(_income, "ดอกเบี้ย/ค่าผ่อน (%d ก้อน)" % p.liabilities.size(),
		"−" + WQFmt.n(p.get_debt_payments()) + "฿", BAD)
	_row(_income, "รวมรายจ่าย", "−" + WQFmt.n(p.get_total_expenses()) + "฿", BAD, true)

	var cf: float = p.get_monthly_cashflow()
	_row(_income, "เหลือเก็บต่อเดือน", WQFmt.signed(cf) + "฿", GOOD if cf >= 0 else BAD, true)

	# เส้นชัยของด่าน 1 อยู่ตรงนี้ — ต้องเห็นว่าอีกไกลแค่ไหนโดยไม่ต้องคำนวณเอง
	var pct: float = p.get_freedom_pct()
	# ไม่ใส่ 🏁 — ธงหมากรุกเป็นอีโมจิขาวดำ พอวางบนพื้นเข้มของเกมจะดูเหมือนกล่องเปล่า
	# (ฟอนต์มีตัวอักษรนี้อยู่ ปัญหาคือสีของตัวอีโมจิเอง ไม่ใช่ฟอนต์ขาด)
	_free.text = "รายได้จากทรัพย์สินครอบคลุมรายจ่ายแล้ว %d%% — ถึง 100%% เมื่อไหร่คือออกจากสนามแข่งหนู" % roundi(pct)
	_free.add_theme_color_override("font_color", GOOD if pct >= 100.0 else GOLD)
	_free.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	_row(_balance, "เงินสด", WQFmt.m(p.cash) + "฿", GOLD)
	_row(_balance, "มูลค่าทรัพย์สิน", WQFmt.m(p.get_asset_value()) + "฿", ACCENT)
	_row(_balance, "หนี้สินรวม", "−" + WQFmt.m(p.get_total_debt()) + "฿", BAD)
	_row(_balance, "ความมั่งคั่งสุทธิ", WQFmt.m(p.get_net_worth()) + "฿",
		GOOD if p.get_net_worth() >= 0 else BAD, true)
	_row(_balance, "วงเงินกู้ที่เหลือ (จาก %s)" % WQFmt.m(p.get_credit_limit()),
		WQFmt.m(p.get_credit_left()) + "฿", DIM)
	if p.study_level > 0 or p.study_progress > 0:
		_row(_balance, "ระดับการศึกษา (คืบหน้า %d/%d)" % [floori(p.study_progress), p.get_study_need()],
			"Lv.%d" % p.study_level, ACCENT)


func _heading(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 15)
	return l


func _row(box: VBoxContainer, left: String, right: String, color: Color, strong := false) -> void:
	var h := HBoxContainer.new()
	var a := Label.new()
	a.text = left
	a.add_theme_font_size_override("font_size", 13 if strong else 12)
	a.add_theme_color_override("font_color", Color.WHITE if strong else DIM)
	a.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(a)
	var b := Label.new()
	b.text = right
	b.add_theme_font_size_override("font_size", 13 if strong else 12)
	b.add_theme_color_override("font_color", color)
	b.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	h.add_child(b)
	box.add_child(h)


func _clear(box: Node) -> void:
	for c in box.get_children():
		box.remove_child(c); c.free()
