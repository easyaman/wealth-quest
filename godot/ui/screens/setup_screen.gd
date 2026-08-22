class_name WQSetupScreen
extends Control
## หน้าจอ setup — ทอยเต๋า → เลือกอาชีพ (GDD บทที่ 7)
##
## ก่อนหน้านี้เกมเปิดมาแล้วโผล่รายการอาชีพเลย โดยที่การทอยเต๋าเกิดขึ้นเงียบๆ ใน `WQSetup.roll_start()`
## ผู้เล่นจึงไม่มีทางรู้ว่า "ทำไมฉันได้เลือกแค่ 3 อาชีพ" หรือ "โบนัสเวลานี้มาจากไหน"
## ซึ่งทำให้สารหลักของบทที่ 7 หายไปทั้งบท — เต๋าลูกนี้คือ **ต้นทุนชีวิตที่เกิดมาพร้อม**
## ไม่ใช่ตัวตัดสินว่าเก่งหรือไม่เก่ง และคนที่ทอยได้น้อยจะได้ชั่วโมงว่างเพิ่มมาชดเชย
##
## หน้าจอนี้จึงบังคับให้เห็นสองอย่างก่อนจะไปต่อ:
##   1. **ตารางแต้มทั้งหก** (อ่านจาก `data/config.json` ตรงๆ) — เห็นว่าแลกกันยังไงก่อนทอย
##   2. **การทอยจริง** ที่มีจังหวะของมันเอง แล้วค่อยเฉลยว่าได้อะไร
##
## กฎเหล็ก: หน้าจอนี้ไม่ทอยเอง — `WQSetup.roll_start()` เป็นคนทอย (core เท่านั้นที่มีตัวสุ่ม)
## ที่นี่แค่เอาแต้มที่ได้ไปเล่นภาพลูกเต๋าให้ตรงกัน แล้วส่งชุดอาชีพเดิมนั้นต่อให้ `WQJobSelect`
##
## เลือกเสร็จแล้วยิง `chosen` ให้ `ui/main.gd` เป็นคนตั้งแมตช์ เหมือนเดิม

signal chosen(job_id: String, roll: int, bonus_hours: int)
signal load_requested

const DIM := Color("8fa6bd")
const GOLD := Color("f2b233")

var offer: Dictionary = {}       ## ผลทอยที่ได้ — ว่างอยู่แปลว่ายังไม่ได้ทอย

var _intro: Control
var _title: Label                ## หัวข้อ — เปลี่ยนตามที่นั่งที่กำลังตั้งในโต๊ะ hot-seat
var _table: VBoxContainer
var _dice: WQDice
var _roll_btn: Button
var _result: Label
var _next_btn: Button
var _load_btn: Button
var _job: WQJobSelect
var _seed := 0


func _init() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var bg := ColorRect.new()
	bg.color = WQPalette.BG_DEEP
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	_intro = _build_intro()
	add_child(_intro)

	# หน้าเลือกอาชีพถูกสร้างไว้ก่อนแต่ซ่อนอยู่ — สร้างตอนกดจะทำให้เฟรมนั้นกระตุก
	# เพราะมันต้องปั้นตัวละคร 3D ของอาชีพแรกขึ้นแท่นโชว์ทันทีที่โผล่
	_job = WQJobSelect.new()
	_job.visible = false
	_job.chosen.connect(func(id: String, roll: int, bonus: int): chosen.emit(id, roll, bonus))
	add_child(_job)


func _build_intro() -> Control:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)

	var center := CenterContainer.new()
	margin.add_child(center)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	col.custom_minimum_size = Vector2(680, 0)
	center.add_child(col)

	_title = Label.new()
	_title.text = "🎲 ทอยเต๋าเปิดโอกาสของคุณ"
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 26)
	col.add_child(_title)

	col.add_child(_para("เต๋าลูกนี้ทอยครั้งเดียวตอนเกิด — มันไม่ได้ตัดสินว่าคุณเก่งแค่ไหน "
		+ "แต่ตัดสินว่าคุณ [b]มีทางให้เลือกกี่ทาง[/b] แต้มยิ่งสูง อาชีพให้เลือกยิ่งเยอะ "
		+ "และเข้าถึงกลุ่มรายได้สูงได้", 14))
	col.add_child(_para("ทอยได้น้อยจะได้ [color=#4fc3f7]ชั่วโมงว่างเพิ่ม[/color] มาชดเชย "
		+ "เพราะคนที่มีทางเลือกน้อยกว่าต้องลงแรงมากกว่า — แต่ทางเลือกก็ยังน้อยกว่าอยู่ดี "
		+ "[color=#8fa6bd]แต้ม 6 ไม่ได้แปลว่าได้อาชีพที่ดีที่สุด[/color]", 13))

	_table = VBoxContainer.new()
	_table.add_theme_constant_override("separation", 2)
	col.add_child(_table)
	_build_table()

	_dice = WQDice.new(110.0)
	_dice.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_dice.rolled.connect(_on_rolled)
	col.add_child(_dice)

	_roll_btn = Button.new()
	_roll_btn.text = "🎲 ทอยเต๋า"
	_roll_btn.custom_minimum_size = Vector2(220, 44)
	_roll_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_roll_btn.pressed.connect(roll)
	col.add_child(_roll_btn)

	_result = Label.new()
	_result.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_result.add_theme_font_size_override("font_size", 16)
	_result.add_theme_color_override("font_color", GOLD)
	col.add_child(_result)

	# ปุ่มไปต่อโผล่หลังทอยเสร็จเท่านั้น — ผู้เล่นเป็นคนกำหนดจังหวะเองว่าดูผลนานแค่ไหน
	# (ตั้งเวลาให้เด้งไปเองจะพรากจังหวะเดียวของเกมที่โชคเป็นคนพูด)
	_next_btn = Button.new()
	_next_btn.text = "ดูอาชีพที่เลือกได้ ▸"
	_next_btn.custom_minimum_size = Vector2(220, 40)
	_next_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_next_btn.visible = false
	_next_btn.pressed.connect(show_jobs)
	col.add_child(_next_btn)

	# โผล่เฉพาะตอนที่มีไฟล์เซฟจริงเท่านั้น — ปุ่มที่กดแล้วเจอรายการว่างเปล่าคือปุ่มที่ไม่ควรมี
	_load_btn = Button.new()
	_load_btn.text = "📂 โหลดเกมที่บันทึกไว้"
	_load_btn.custom_minimum_size = Vector2(220, 36)
	_load_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_load_btn.pressed.connect(func(): load_requested.emit())
	col.add_child(_load_btn)
	return margin


## ตารางแต้มทั้งหก — อ่านจาก `data/config.json` ตรงๆ ห้ามพิมพ์ตัวเลขซ้ำที่นี่
## (วันที่ปรับสมดุลตาราง หน้าจอนี้ต้องเปลี่ยนตามเองโดยไม่ต้องแก้โค้ด)
func _build_table() -> void:
	WQData.load_all()
	for c in _table.get_children():
		_table.remove_child(c)
		c.free()
	for n in range(1, 7):
		var t: Dictionary = WQData.cfg.roll_table[str(n)]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		row.add_child(_cell("แต้ม %d" % n, 60, GOLD))
		row.add_child(_cell("เลือกได้ %d อาชีพ" % int(t.count), 130, Color.WHITE))
		row.add_child(_cell("+%d ชม./เดือน" % int(t.bonusHours), 120, WQPalette.TIME))
		row.add_child(_cell(String(t.label), 0, DIM))
		_table.add_child(row)


func _cell(text: String, width: float, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.custom_minimum_size = Vector2(width, 0)
	if width <= 0.0: l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.add_theme_font_size_override("font_size", 13)
	l.add_theme_color_override("font_color", color)
	return l


func _para(bb: String, size: int) -> RichTextLabel:
	var l := RichTextLabel.new()
	l.bbcode_enabled = true
	l.fit_content = true
	l.text = "[center]%s[/center]" % bb
	l.add_theme_font_size_override("normal_font_size", size)
	l.add_theme_font_size_override("bold_font_size", size)
	return l


## เตรียมหน้าจอด้วยเมล็ดของที่นั่งที่กำลังตั้ง — ยังไม่ทอยจนกว่าผู้เล่นจะกดปุ่มเอง
## `seat_label` ว่าง = เล่นคนเดียว หัวข้อเดิมไม่เปลี่ยน · ในโต๊ะ hot-seat ต้องบอกให้ชัด
## ว่ากำลังตั้งที่นั่งของใครอยู่ ไม่งั้นคนที่สองจะไม่รู้ว่าถึงตาตัวเองแล้ว
func start(seed_value: int, seat_label := "") -> void:
	_seed = seed_value
	_title.text = "🎲 ทอยเต๋าเปิดโอกาสของคุณ" if seat_label == "" \
		else "🎲 %s — ทอยเต๋าเปิดโอกาสของคุณ" % seat_label
	# ต้องตั้งก่อน show_jobs() ทุกทาง (ทั้งกดเองและ skip_to_jobs) ไม่งั้นหน้าเลือกอาชีพ
	# จะโผล่โดยไม่มีป้ายบอกว่าเป็นที่นั่งของใคร ซึ่งเป็นจังหวะที่คนผิดคนเผลอกดเลือกได้ง่ายที่สุด
	_job.seat_label = seat_label
	offer = {}
	_result.text = ""
	_next_btn.visible = false
	_roll_btn.disabled = false
	_dice.reset(1)
	_load_btn.visible = WQSave.has_any()
	_intro.visible = true
	_job.visible = false


## ทอยจริง — core ทอยก่อน แล้วภาพลูกเต๋าค่อยวิ่งไปหยุดที่แต้มนั้น
## `forced_roll > 0` ใช้ตอนเทสต์ ให้ได้แต้มที่ต้องการโดยไม่ต้องเดาเมล็ด
func roll(forced_roll := 0) -> void:
	if _dice.rolling or not offer.is_empty(): return
	offer = WQSetup.roll_start(_seed, forced_roll)
	_roll_btn.disabled = true
	_dice.roll_to(int(offer.roll))


func _on_rolled(_face: int) -> void:
	if offer.is_empty(): return
	var bonus := int(offer.bonus_hours)
	_result.text = "ได้แต้ม %d — “%s”\nเลือกอาชีพได้ %d แบบ%s" % [
		int(offer.roll), String(offer.label), (offer.jobs as Array).size(),
		"" if bonus == 0 else "  ·  ได้ชั่วโมงว่างเพิ่ม +%d ชม./เดือน" % bonus]
	_next_btn.visible = true


## ข้ามภาพลูกเต๋าไปหน้าเลือกอาชีพเลย — สำหรับเทสต์ headless และตอนถ่ายภาพหน้าจอ (WQ_ROLL)
## ผลลัพธ์ต้องเหมือนกดปุ่มเองทุกประการ ต่างแค่ไม่ต้องรอภาพกลิ้ง
func skip_to_jobs(forced_roll := 0) -> void:
	roll(forced_roll)
	_dice.finish_now()
	show_jobs()


## สลับไปหน้าเลือกอาชีพ — ส่งชุดที่ทอยได้ไปทั้งชุด ห้ามให้มันทอยใหม่
func show_jobs() -> void:
	if offer.is_empty(): return
	_intro.visible = false
	_job.visible = true
	_job.show_offer(offer)
