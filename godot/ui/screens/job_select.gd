class_name WQJobSelect
extends Control
## หน้าเลือกอาชีพ — ทอยเต๋าตอนเริ่มเกม (GDD บทที่ 7 · Sprint C ข้อ 5)
##
## แต้มเต๋าไม่ได้แปลว่าได้อาชีพดีหรือแย่ แต่แปลว่าได้ "ทางเลือกกี่ทาง"
## หน้าจอนี้จึงต้องทำให้ผู้เล่นเปรียบเทียบทางเลือกที่มีได้จริง — ไม่ใช่แค่กดผ่าน
## แถบสามอันจึงวัดกันเองในชุดที่ทอยได้ (เต็มแถบ = ดีที่สุดในชุดนี้) ไม่ใช่เทียบกับค่าคงที่ลอยๆ
##
## กฎเหล็ก: **ตัวเลขทุกตัวมาจาก core** ผ่าน `WQSetup.job_preview()` ซึ่งสร้าง WQPlayer จริง
## มาถามคำตอบ ที่นี่ไม่คำนวณสูตรเกมเองแม้แต่ช่องเดียว
##
## หน้าจอนี้ไม่สร้างเกมเอง — เลือกเสร็จแล้วยิง `chosen` ให้ ui/main.gd เป็นคนตั้งแมตช์

signal chosen(job_id: String, roll: int, bonus_hours: int)

const CARD_MIN := Vector2(300, 0)

var offer: Dictionary = {}       ## ผลทอยจาก WQSetup.roll_start
var picked_id := ""              ## อาชีพที่กำลังเลือกอยู่
## ป้ายที่นั่ง — มาจาก setup_screen.start() ก่อน show_offer() เสมอ ว่างอยู่ = เล่นคนเดียว
## ต้องอยู่ให้ทันตอนกดข้ามหน้าเต๋าไปเลือกอาชีพเลย ไม่งั้นคนที่สองจะไม่รู้ว่าถึงตาตัวเอง
var seat_label := ""

var _head: Label
var _die: WQDice
var _list: VBoxContainer
var _showcase: WQShowcase
var _confirm: Button
var _buttons: Dictionary = {}    ## job_id -> Button


func _init() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var bg := ColorRect.new()
	bg.color = WQPalette.BG_DEEP
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	add_child(margin)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	margin.add_child(col)

	# เต๋าลูกเล็กค้างไว้ที่หัวข้อ — ผู้เล่นต้องเห็นตลอดว่า "ชุดอาชีพนี้มาจากแต้มนี้"
	# ไม่ใช่รายการที่เกมยื่นให้เฉยๆ (GDD บทที่ 7: แต้ม = จำนวนทางเลือก ไม่ใช่คุณภาพ)
	var head_row := HBoxContainer.new()
	head_row.add_theme_constant_override("separation", 10)
	col.add_child(head_row)

	_die = WQDice.new(40.0)
	head_row.add_child(_die)

	_head = Label.new()
	_head.add_theme_font_size_override("font_size", 20)
	_head.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head_row.add_child(_head)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(row)

	# รายการอาชีพอาจยาวถึง 7 ใบ ต้องมีสกรอลล์ ไม่งั้นใบล่างสุดจะกดไม่ได้บนจอเตี้ย
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = CARD_MIN
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_child(scroll)

	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 6)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_list)

	_showcase = WQShowcase.new()
	_showcase.custom_minimum_size = Vector2(360, 420)
	_showcase.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_showcase)

	_confirm = Button.new()
	_confirm.text = "เริ่มชีวิตด้วยอาชีพนี้"
	_confirm.disabled = true
	_confirm.pressed.connect(_on_confirm)
	col.add_child(_confirm)


## ทอยเต๋าแล้วสร้างรายการอาชีพ — forced_roll > 0 ใช้ตอนทดสอบ
func start(seed_value: int, forced_roll := 0) -> void:
	show_offer(WQSetup.roll_start(seed_value, forced_roll))


## รับผลทอยที่ทอยมาแล้วจากที่อื่น — `ui/screens/setup_screen.gd` ทอยก่อนเพื่อเอาแต้มไปเล่นภาพเต๋า
## แล้วค่อยส่งชุดเดิมมาที่นี่ ห้ามทอยซ้ำตรงนี้ ไม่งั้นแต้มบนหน้าจอกับชุดอาชีพจะเป็นคนละครั้งกัน
func show_offer(o: Dictionary) -> void:
	offer = o
	_die.face = int(offer.roll)
	# ไม่ใส่อีโมจิ 🎲 ซ้ำในข้อความ — มีลูกเต๋าที่วาดจริงอยู่ข้างๆ แล้ว
	var head_text := "ทอยได้ %d — %s   ·   เลือกได้ %d อาชีพ   ·   โบนัสเวลา +%d ชม./เดือน" % [
		int(offer.roll), String(offer.label), (offer.jobs as Array).size(),
		int(offer.bonus_hours)]
	_head.text = head_text if seat_label == "" else "%s — %s" % [seat_label, head_text]
	_build_list()
	if not (offer.jobs as Array).is_empty(): select(String(offer.jobs[0].id))


func _build_list() -> void:
	# remove_child() + free() ไม่ใช่ queue_free() — ทอยใหม่สองครั้งในเฟรมเดียวแล้วรายการจะซ้อนกัน
	for c in _list.get_children():
		_list.remove_child(c)
		c.free()
	_buttons.clear()
	for j in offer.jobs:
		var b := Button.new()
		b.toggle_mode = true
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size = Vector2(0, 46)
		b.text = "%s  %s\n     Tier %d · เงินเดือน %s" % [
			j.get("icon", ""), j.name, int(j.tier), WQFmt.m(float(j.salary))]
		var id := String(j.id)
		b.pressed.connect(func(): select(id))
		_list.add_child(b)
		_buttons[id] = b


## เลือกอาชีพหนึ่งมาดู — ยังไม่ผูกมัด จนกว่าจะกดปุ่มยืนยัน
func select(job_id: String) -> void:
	if not _buttons.has(job_id): return
	picked_id = job_id
	for id in _buttons:
		(_buttons[id] as Button).button_pressed = id == job_id
	_confirm.disabled = false
	var pv := WQSetup.job_preview(job_id, int(offer.bonus_hours))
	_showcase.show_built("character", job_id, WQKitbashChar.build(job_id),
		_stats(pv), "%s %s" % [pv.job.get("icon", ""), pv.job.name])


## สามแถบตามที่ Sprint C กำหนด: ชม.ว่างใช้ได้ · เงินเดือน · เดินทาง
## เต็มแถบ = ดีที่สุดในชุดที่ทอยได้ครั้งนี้ ผู้เล่นจึงเทียบกันเองได้ในหน้าเดียว
func _stats(pv: Dictionary) -> Array:
	var max_free := 1.0
	var max_salary := 1.0
	var max_commute := 1.0
	for j in offer.jobs:
		var o := WQSetup.job_preview(String(j.id), int(offer.bonus_hours))
		max_free = maxf(max_free, float(o.free_hours))
		max_salary = maxf(max_salary, float(o.salary))
		max_commute = maxf(max_commute, float(o.commute))
	return [
		{"label": "เวลาว่างใช้ได้", "value": float(pv.free_hours), "max": max_free,
			"color": WQPalette.TIME, "text": "%d ชม./เดือน" % int(pv.free_hours)},
		{"label": "เงินเดือน", "value": float(pv.salary), "max": max_salary,
			"color": WQPalette.MONEY, "text": WQFmt.m(float(pv.salary))},
		# เดินทางเป็น "ต้นทุน" ไม่ใช่ผลตอบแทน จึงใช้สีเดียวกับหนี้/ดอกเบี้ย
		# แถบยาว = เสียเวลาไปกับการเดินทางมาก ไม่ใช่ดี
		{"label": "เดินทางไปงาน (ยิ่งยาวยิ่งเสียเวลา)", "value": float(pv.commute),
			"max": max_commute, "color": WQPalette.MONEY_DARK,
			"text": "%d ชม./เดือน" % int(pv.commute)},
	]


func _on_confirm() -> void:
	if picked_id == "": return
	chosen.emit(picked_id, int(offer.roll), int(offer.bonus_hours))
