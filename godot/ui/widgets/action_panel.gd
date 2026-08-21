class_name WQActionPanel
extends PanelContainer
## 🎯 ลงมือทำ — ปุ่มของการกระทำทั้งหมดที่ core ทำได้ (บทที่ 12 ของ GDD)
##
## ก่อนมีแผงนี้ เกมมีปุ่มให้กดแค่ "ปิดดีล · เดินทาง · ซื้อของ · ชำระหนี้" ทั้งที่ core
## ทำได้อีกเจ็ดอย่าง — ผู้เล่นจึงเห็นแค่ครึ่งเกม แผงนี้เอาอีกครึ่งกลับมาไว้ที่เดียว
##
## **หัวใจของแผงนี้คือการเทียบ ไม่ใช่การกด**: ทุกแถวติดราคาเป็นชั่วโมงไว้บนปุ่ม (กฎ 12.2.3)
## แล้ววางเรียงกันในคอลัมน์เดียวกับตลาดดีล เพื่อให้คำถามที่เกมนี้ถามซ้ำทุกเดือน —
## "30 ชม. นี้เอาไปรับ OT ได้เงินก้อนเดียว หรือเอาไปปิดดีลที่จ่ายทุกเดือน" — อยู่ในสายตาพร้อมกัน
##
## กฎของแผง:
##   · **ไม่ย้ายผู้เล่นเอง** — การกระทำที่ต้องไปที่อื่นก่อน ปุ่มจะกลายเป็นปุ่มเดินทาง
##     แล้วยิงสัญญาณ `travel_requested` ให้ `ui/main.gd` เป็นคนเรียก `travel_to()`
##     (กฎเดียวกับ WQTravelPanel และฉากเมือง 3D — ตัวละครต้องเดินให้เห็น)
##   · **ไม่คำนวณสูตรเกมเอง** — ราคาชั่วโมงมาจาก `p.act_cost()` ค่าเรียน/ค่าแพ็กเกจอ่านจาก
##     ตัวเลขที่ core ใช้จริง ไม่งั้นเพิร์กอาชีพจะทำให้ป้ายราคาโกหก
##   · **บอกเหตุผลที่กดไม่ได้เสมอ** — ปุ่มเทาเฉยๆ ทำให้ผู้เล่นคิดว่าเกมพัง
##     ทุกแถวที่กดไม่ได้จึงมีบรรทัดบอกว่าติดอะไร (เวลา · เงิน · โควตา · สถานะงาน)

signal travel_requested(place_id: String)

const DIM := Color("8fa6bd")
const WARN := Color("ff8080")
const GOOD := Color("7ee08a")
const GOLD := Color("ffd76a")

## กว้างเท่าปุ่มของแผงเดินทาง — สองแผงนี้อยู่ในคอลัมน์เดียวกัน ขอบปุ่มต้องตรงกัน
const BTN_W := 275.0

## เรียงตามลำดับเดียวกับต้นแบบเว็บ: หาโอกาส → แลกเวลาเป็นเงิน → ลงทุนในตัวเอง → ดูแลตัวเอง → เงินทุน
const ACTS: Array[Dictionary] = [
	{"id": "scout", "icon": "🔍", "name": "ออกดูทำเล/หาข้อมูล"},
	{"id": "ot", "icon": "⏱️", "name": "รับ OT ที่ออฟฟิศ"},
	{"id": "freelance", "icon": "💻", "name": "รับงาน freelance"},
	{"id": "study", "icon": "📚", "name": "เรียนเพิ่มเติม"},
	{"id": "rest", "icon": "🛋️", "name": "พักผ่อนที่บ้าน"},
	{"id": "gym", "icon": "🏋️", "name": "ออกกำลังกาย"},
	{"id": "resort", "icon": "🏨", "name": "ไปพักผ่อน"},
	{"id": "loan", "icon": "🏦", "name": "ยื่นกู้"},
]

## ปุ่มกู้ด่วนคิดเป็น % ของวงเงินที่เหลือ — รูปแบบเดียวกับปุ่มชำระหนี้ใน WQDebtList
## (core ปัดยอดกู้ลงหลักหมื่นอยู่แล้ว ปุ่มจึงโชว์ยอดที่ปัดแล้วเพื่อไม่ให้ตัวเลขบนปุ่มกับในบันทึกต่างกัน)
const LOAN_QUICK := [["25%", 0.25], ["50%", 0.5], ["เต็มวงเงิน", 1.0]]
const LOAN_STEP := 10000.0

var _p = null
var _title: Label
var _left: Label
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
	_left = Label.new()
	_left.add_theme_color_override("font_color", DIM)
	_left.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	head.add_child(_left)
	col.add_child(head)

	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 4)
	col.add_child(_list)


func bind(player) -> void:
	if _p == player: return
	if _p != null and _p.changed.is_connected(_queue_rebuild):
		_p.changed.disconnect(_queue_rebuild)
	_p = player
	if _p != null:
		_p.changed.connect(_queue_rebuild)
	refresh()


## เหมือนแผงเดินทาง — ห้าม free() ปุ่มทิ้งระหว่างที่ปุ่มนั้นกำลังส่งสัญญาณ pressed อยู่
## และการกระทำหนึ่งครั้งยิง changed ได้หลายรอบ จึงต้องมีธงกันคิวซ้อน
func _queue_rebuild() -> void:
	if _rebuilding: return
	_rebuilding = true
	call_deferred("_do_rebuild")


func _do_rebuild() -> void:
	_rebuilding = false
	refresh()


func refresh() -> void:
	var p = _p
	if p == null: return
	_title.text = "🎯 ลงมือทำ"
	_left.text = "เหลือ %d ชม." % p.hours

	for c in _list.get_children():
		_list.remove_child(c)
		c.free()

	for a in ACTS:
		var act := String(a.id)
		# ยืนอยู่ที่ฟิตเนส/รีสอร์ต/ธนาคารแล้ว = กางตัวเลือกจริงให้เลย ไม่ใช่ปุ่มเดียวรวมๆ
		# เพราะการเลือกแพ็กเกจ/ยอดกู้ *คือ* การตัดสินใจ ไม่ใช่รายละเอียดปลีกย่อย
		if act == "gym" and p.can_do_here("gym"):
			_add_packs(p, a, WQData.gym_packs, "gym")
		elif act == "resort" and p.can_do_here("resort"):
			_add_packs(p, a, WQData.resort_packs, "resort")
		elif act == "loan" and p.can_do_here("loan"):
			_list.add_child(_loan_row(p, a))
		else:
			_list.add_child(_act_row(p, a))


# ========== แถวการกระทำทั่วไป ==========
func _act_row(p, a: Dictionary) -> Control:
	var act := String(a.id)
	var dest := String(p.place_for(act))
	var here: bool = dest == String(p.place)
	var cost: int = _hours_of(p, act)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 1)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)

	# ไอคอนบนปุ่มคือ "ที่ที่ทำสิ่งนี้ได้" — บอกที่ทางของการกระทำโดยไม่กินบรรทัดเพิ่ม
	# (กฎ world/ ข้อ 8: ไอคอนต้องผ่าน WQIcon เสมอ ไม่งั้นอีโมจิขาวดำจะเป็นกล่องดำบนพื้นเข้ม)
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(BTN_W, 0)
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	var has_icon := WQIcon.decorate_button(btn, dest)
	var label: String = String(a.name) if has_icon else "%s %s" % [String(a.icon), String(a.name)]

	var note := ""
	var note_color := WARN
	if here:
		btn.text = "%s — %d ชม." % [label, cost]
		note = _blocked(p, act, cost)
		btn.disabled = note != ""
		if not btn.disabled:
			btn.pressed.connect(func(): _do(act))
	else:
		# อยู่ผิดที่ → ปุ่มนี้กลายเป็นปุ่มเดินทาง ราคาบนปุ่มจึงต้องเป็นค่าเดินทาง
		# ไม่ใช่ค่าของการกระทำ (กด = เดินทาง ไม่ใช่ทำ) ส่วนราคาจริงย้ายไปอยู่บรรทัดล่าง
		var th: int = p.travel_cost(dest)
		btn.text = "%s — เดินทาง %d ชม." % [label, th]
		btn.disabled = not p.can_spend(th)
		note = "📍 ต้องไปที่ %s ก่อน แล้วทำอีก %d ชม." % [p.place_name(act), cost]
		note_color = DIM
		if btn.disabled:
			note = "เวลาไม่พอจะเดินทางไป %s (ต้องใช้ %d ชม. เหลือ %d ชม.)" % [
				p.place_name(act), th, p.hours]
			note_color = WARN
		else:
			btn.pressed.connect(func(): travel_requested.emit(dest))
	head.add_child(btn)

	var desc := Label.new()
	desc.text = _desc(p, act)
	desc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.add_theme_font_size_override("font_size", 12)
	desc.add_theme_color_override("font_color", Color.WHITE if here else DIM)
	head.add_child(desc)
	box.add_child(head)

	if note != "": box.add_child(_note_label(note, note_color))
	return box


## ราคาชั่วโมงของการกระทำ — ฟิตเนส/รีสอร์ตราคาขึ้นกับแพ็กเกจ core จึงคืน -1
## ตอนยังอยู่ไกลให้โชว์แพ็กเกจที่ถูกที่สุดไว้ก่อน ("อย่างน้อยเท่านี้")
func _hours_of(p, act: String) -> int:
	var c: int = p.act_cost(act)
	if c >= 0: return c
	var packs: Array = WQData.gym_packs if act == "gym" else WQData.resort_packs
	var lo := 99999
	for pk in packs: lo = mini(lo, int(pk.hours))
	return 0 if lo == 99999 else lo


## "" = กดได้ · ข้อความ = เหตุผลที่กดไม่ได้ ต้องบอกเสมอ ไม่ปล่อยให้ปุ่มเทาเฉยๆ
## เงื่อนไขทุกข้อตรงกับที่ core ปฏิเสธจริง — ที่นี่แค่ถามก่อนกด แทนที่จะให้ผู้เล่นกดแล้วเจอ error
func _blocked(p, act: String, cost: int) -> String:
	var quota := int(WQData.cfg.side_job_max_count)
	match act:
		"ot":
			if p.retired: return "ลาออกจากงานประจำแล้ว รับ OT ไม่ได้"
			if p.downsize_left > 0: return "ตอนนี้ไม่มีงานประจำอยู่ (ถูกลดขนาดองค์กร)"
			if p.side_used >= quota: return "รับงานเสริมครบ %d ครั้งแล้วเดือนนี้" % quota
		"freelance":
			if p.side_used >= quota: return "รับงานเสริมครบ %d ครั้งแล้วเดือนนี้" % quota
		"study":
			if p.retired: return "ลาออกแล้ว เรียนเพิ่มไม่ได้ทำให้เงินเดือนขึ้นอีก"
			var fee: float = _study_fee(p)
			if p.cash < fee: return "ค่าเรียน %s฿ — เงินสดไม่พอ" % WQFmt.n(fee)
	if not p.can_spend(cost):
		return "เวลาไม่พอ ต้องใช้ %d ชม. (เหลือ %d ชม.)" % [cost, p.hours]
	return ""


## ค่าเรียนคิดจากเงินเดือนจริงและคิดคนละอัตราระหว่างเรียนที่สถาบันกับเรียนออนไลน์
## (สูตรเดียวกับใน `WQPlayer.study()` — ถ้าที่นี่คิดต่าง ป้ายราคาจะโกหกตอนมีโน้ตบุ๊ก)
func _study_fee(p) -> float:
	var online: bool = String(p.place_for("study")) != "school"
	var ratio: float = float(WQData.cfg.study_fee_ratio_online if online \
		else WQData.cfg.study_fee_ratio)
	return roundf(p.salary * ratio)


## คำอธิบายสั้นๆ ของแต่ละการกระทำ — พูดเรื่อง "ได้อะไรกลับมา" ไม่ใช่ทวนว่าปุ่มชื่ออะไร
func _desc(p, act: String) -> String:
	var quota := int(WQData.cfg.side_job_max_count)
	var mid := (float(WQData.cfg.side_job_min) + float(WQData.cfg.side_job_max)) * 0.5
	var perk: float = 1.5 if String(p.job.perkId) == "hustle" else 1.0
	match act:
		"scout":
			return "ดีลใหม่เข้าตลาด 2 รายการ"
		"ot":
			return "ได้เงินก้อน ~%s฿ (ใช้ไปแล้ว %d/%d ครั้ง)" % [
				WQFmt.n(p.salary * mid * perk), p.side_used, quota]
		"freelance":
			if p.has_device("laptop") and String(p.place) != "cowork":
				return "ทำที่บ้านได้ แต่ได้เงินน้อยกว่าที่ co-working %d%%" % \
					roundi((1.0 - 1.0 / float(WQData.cfg.freelance_cowork_mul)) * 100.0)
			return "ได้เงินมากกว่า OT %d%% (ใช้ไปแล้ว %d/%d ครั้ง)" % [
				roundi((float(WQData.cfg.freelance_cowork_mul) - 1.0) * 100.0),
				p.side_used, quota]
		"study":
			var online: bool = String(p.place_for("study")) != "school"
			var head := "ค่าเรียน %s฿" % WQFmt.n(_study_fee(p))
			if online:
				head += " (ออนไลน์ ถูกกว่าแต่คืบหน้าช้ากว่า %d%%)" % \
					roundi((1.0 - float(WQData.cfg.study_progress_online)) * 100.0)
			return "%s • คืบหน้า %d/%d ครั้ง → เงินเดือน +%d%% โดยรายจ่ายไม่โต" % [
				head, floori(p.study_progress), p.get_study_need(),
				roundi(float(WQData.cfg.study_raise) * 100.0)]
		"rest":
			return "สุขภาพ +2.5 และลดโอกาสเกิดเรื่องร้ายเดือนนี้"
		"gym":
			return "สุขภาพ +%s ขึ้นไป — มีแพ็กเกจให้เลือกที่ฟิตเนส" % str(WQData.gym_packs[0].hp)
		"resort":
			return "ฟื้นสุขภาพเยอะกว่าพักที่บ้านมาก และได้โล่กันเหตุการณ์ร้าย"
		"loan":
			if p.has_device("smartphone"): return "ทำผ่านแอปได้ ไม่ต้องเดินทาง"
			return "เพิ่มเงินสดแลกกับดอกเบี้ยที่กลายเป็นรายจ่ายทุกเดือน"
	return ""


## เดิมทิ้งค่าที่ core คืนมาทั้งหมด ผู้เล่นกดปุ่มแล้วทำไม่ได้จึงไม่มีอะไรตอบเลยสักอย่าง
## ตอนสำเร็จเสียงมาจากสัญญาณ `acted` ของ core เอง ที่นี่รับผิดชอบแค่ "ทำไม่ได้"
func _do(act: String) -> void:
	var res := {}
	match act:
		"scout": res = _p.scout()
		"ot": res = _p.side_job("ot")
		"freelance": res = _p.side_job("freelance")
		"study": res = _p.study()
		"rest": res = _p.rest()
		"gym": res = _p.exercise()
		"resort": res = _p.vacation()
	if not bool(res.get("ok", true)): WQAudio.ui("denied")


# ========== แพ็กเกจฟิตเนส / รีสอร์ต ==========
## ยืนอยู่ที่นั่นแล้วต้องเห็นทุกแพ็กเกจพร้อมกัน เพราะมันคือกับดัก "จ่ายเงินซื้อเวลา" ที่ชัดที่สุด
## ในเกม — เทรนเนอร์แพงกว่าจ่ายรายครั้ง 18 เท่า แต่ได้สุขภาพต่อชั่วโมงเกือบสองเท่า
func _add_packs(p, a: Dictionary, packs: Array, kind: String) -> void:
	_list.add_child(_note_label("%s %s — เลือกแพ็กเกจ" % [String(a.icon), String(a.name)], GOLD))
	for pk in packs:
		_list.add_child(_pack_row(p, pk, kind))


func _pack_row(p, pk: Dictionary, kind: String) -> Control:
	var owned: bool = kind == "gym" and pk.get("monthly", false) \
		and String(p.gym_pack) == String(pk.id)
	var fee: float = 0.0 if owned else float(pk.cost)
	var h := int(pk.hours)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 1)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)

	var btn := Button.new()
	btn.custom_minimum_size = Vector2(BTN_W, 0)
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	var icon_id := "%s_%s" % [kind, String(pk.id)]
	var has_icon := WQIcon.decorate_button(btn, icon_id)
	var label: String = String(pk.name) if has_icon else "%s %s" % [String(pk.icon), String(pk.name)]
	btn.text = "%s — %d ชม." % [label + (" ✓ ซื้อแล้ว" if owned else ""), h]

	var note := ""
	if not p.can_spend(h):
		note = "เวลาไม่พอ ต้องใช้ %d ชม. (เหลือ %d ชม.)" % [h, p.hours]
	elif p.cash < fee:
		note = "เงินสดไม่พอ ต้องจ่าย %s฿ (มี %s฿)" % [WQFmt.n(fee), WQFmt.n(p.cash)]
	btn.disabled = note != ""
	if not btn.disabled:
		var pack_id := String(pk.id)
		if kind == "gym":
			btn.pressed.connect(func(): _p.exercise(pack_id))
		else:
			btn.pressed.connect(func(): _p.vacation(pack_id))
	head.add_child(btn)

	var desc := Label.new()
	desc.text = _pack_desc(pk, fee, owned)
	desc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.add_theme_font_size_override("font_size", 12)
	desc.add_theme_color_override("font_color", GOOD if owned else Color.WHITE)
	head.add_child(desc)
	box.add_child(head)

	if note != "": box.add_child(_note_label(note, WARN))
	return box


func _pack_desc(pk: Dictionary, fee: float, owned: bool) -> String:
	var parts: Array = ["ฟรี (จ่ายไปแล้วเดือนนี้)" if owned else "%s฿" % WQFmt.n(fee),
		"สุขภาพ +%s" % str(pk.hp)]
	if float(pk.get("shield", 0.0)) > 0.0:
		parts.append("ลดโอกาสเกิดเรื่องร้าย %d%%" % roundi(float(pk.shield) * 100.0))
	if String(pk.get("note", "")) != "": parts.append(String(pk.note))
	return " • ".join(parts)


# ========== กู้เงิน ==========
## ยอดกู้เป็น % ของวงเงินที่เหลือ ไม่ใช่ช่องให้พิมพ์ตัวเลข — เพราะสิ่งที่ผู้เล่นต้องตัดสินใจจริง
## คือ "กินวงเงินไปเท่าไหร่" ไม่ใช่ตัวเลขกลมๆ และทุกปุ่มยังติดราคาชั่วโมงได้ครบตามกฎ 12.2.3
func _loan_row(p, a: Dictionary) -> Control:
	var cost: int = p.act_cost("loan")
	var left: float = p.get_credit_left()

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)

	# หัวแถวต่อเข้ากับ VBox ตรงๆ — WQIcon.row() เป็น HBox ที่ให้ Label ขยายเต็มความกว้างอยู่แล้ว
	# ถ้าเอาไปซ้อนใน HBox อีกชั้น มันจะหดจนเหลือความกว้างขั้นต่ำแล้วตัดคำทีละตัวอักษร
	var title := WQIcon.row("bank", String(a.icon),
		"%s — วงเงินเหลือ %s฿" % [String(a.name), WQFmt.m(left)], 18)
	(title.get_child(1) as Label).add_theme_color_override("font_color", GOLD)
	box.add_child(title)

	var desc := Label.new()
	desc.text = _desc(p, "loan")
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.add_theme_font_size_override("font_size", 12)
	desc.add_theme_color_override("font_color", DIM)
	box.add_child(desc)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	var any := false
	for q in LOAN_QUICK:
		var amount: float = roundf(left * float(q[1]) / LOAN_STEP) * LOAN_STEP
		var btn := Button.new()
		btn.text = "%s · %s฿ — %d ชม." % [String(q[0]), WQFmt.m(amount), cost]
		btn.disabled = amount < LOAN_STEP or not p.can_spend(cost)
		if not btn.disabled:
			any = true
			btn.pressed.connect(func(): _p.take_loan(amount))
		row.add_child(btn)
	box.add_child(row)

	if not any:
		var why := "เวลาไม่พอ ต้องใช้ %d ชม. (เหลือ %d ชม.)" % [cost, p.hours] \
			if not p.can_spend(cost) else "วงเงินที่เหลือไม่ถึง %s฿ แล้ว" % WQFmt.n(LOAN_STEP)
		box.add_child(_note_label(why, WARN))
	return box


func _note_label(text: String, color: Color) -> Label:
	var l := Label.new()
	l.text = "   " + text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", 12)
	l.add_theme_color_override("font_color", color)
	return l
