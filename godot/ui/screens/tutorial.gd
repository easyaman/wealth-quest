class_name WQTutorial
extends Control
## 💡 การสอน 5 เดือนแรก — พอร์ตสเต็ปจากตัวแปร `TUT` ใน `../ui.html`
##
## เกมนี้สอนตัวเองไม่ได้ด้วยหน้าจอเดียว เพราะสิ่งที่ต้องเข้าใจไม่ใช่ "ปุ่มไหนทำอะไร"
## แต่เป็น **ความสัมพันธ์** สามอย่างที่มองไม่เห็นถ้าไม่มีใครชี้: เวลาเป็นคอขวดจริงไม่ใช่เงิน ·
## สุขภาพเป็นตัวคูณเวลา · และตัวเลขที่กำหนดชะตาคือสัดส่วน ไม่ใช่เงินเดือน
## สเต็ปจึงผูกกับ **เดือน** ไม่ใช่กับการกดปุ่ม — แต่ละเดือนเปิดประเด็นใหม่ตอนที่ผู้เล่นเพิ่งเจอมันจริง
##
## กติกาของหน้าจอนี้:
##   · **ห้ามบังการเล่น** — โอเวอร์เลย์ทั้งแผ่นปล่อยเมาส์ผ่าน (`MOUSE_FILTER_IGNORE`)
##     มีแต่การ์ดคำอธิบายที่รับคลิก ผู้เล่นเล่นเกมต่อได้ตลอดเวลาโดยไม่ต้องปิดการสอน
##   · **สเต็ปที่ให้ลงมือทำต้องรอจริง** (`done`) ไม่ใช่แค่กด "ถัดไป" ผ่าน — เช่นสเต็ป
##     "ลองปิดดีลแรก" จะข้ามเองเมื่อผู้เล่นมีทรัพย์สินชิ้นแรกจริงๆ
##   · **ข้ามได้ตลอดเวลา** และสถานะการสอนถูกเก็บลงไฟล์เซฟ (ช่อง `ui.tut`)
##     โหลดเกมกลับมาแล้วจะสอนต่อจากสเต็ปเดิม ไม่ใช่เริ่มใหม่ทั้งหมด
##
## วงแหวนไฮไลต์วาดรอบวิดเจ็ตจริงในหน้าจอ ตำแหน่งจึงมาจาก `global_position` ของวิดเจ็ตนั้น
## และอัปเดตตามเมื่อคอลัมน์ถูกเลื่อน (ต่อกับ `value_changed` ของสกรอลล์ ไม่ใช่ไล่ทุกเฟรม)

signal finished                  ## ปิดการสอนแล้ว (จบครบหรือกดข้าม)

const CARD_W := 460.0
const RING_PAD := 6.0
const DIM := Color("8fa6bd")
const GOLD := Color("f2b233")

var step := 0
var running := false

var _targets: Dictionary = {}    ## คีย์ในสเต็ป → วิดเจ็ตจริงบนหน้าจอ
var _player = null
var _match: WQMatch
var _steps: Array = []
var _ring: _Ring
var _card: PanelContainer
var _title: Label
var _text: RichTextLabel
var _wait: Label
var _dots: Label
var _next: Button
var _skip: Button
var _hooked: Control             ## วิดเจ็ตที่สเต็ปนี้ชี้อยู่ (ต่อสัญญาณ item_rect_changed ไว้)
var _placing := false            ## กันเรียกซ้อนตอนที่การจัดตำแหน่งไปเปลี่ยนขนาดการ์ดเอง


## วงแหวนไฮไลต์ — วาดเป็นกรอบอย่างเดียว ไม่ทึบทับวิดเจ็ต เพราะผู้เล่นต้องอ่านของข้างในได้
class _Ring extends Control:
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		visible = false

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		draw_rect(r, WQPalette.MONEY, false, 2.0)
		draw_rect(r.grow(3.0), Color(WQPalette.MONEY, 0.35), false, 2.0)


func _init() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# ทั้งแผ่นต้องปล่อยคลิกผ่านไปที่เกม ไม่งั้นการสอนจะกลายเป็นกำแพงขวางการเล่น
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false

	_ring = _Ring.new()
	add_child(_ring)

	_card = PanelContainer.new()
	# พื้นหลังทึบของตัวเอง + ขอบทอง — การ์ดลอยอยู่บนแผงอื่น ถ้าใช้พื้นหลังมาตรฐานซึ่งโปร่งแสง
	# ตัวหนังสือของแผงข้างล่างจะทะลุขึ้นมาปนกับข้อความสอนจนอ่านไม่ออกทั้งคู่
	var box := StyleBoxFlat.new()
	box.bg_color = WQPalette.BG_DEEP
	box.border_color = GOLD
	box.set_border_width_all(1)
	box.set_corner_radius_all(4)
	box.set_content_margin_all(2)
	_card.add_theme_stylebox_override("panel", box)
	_card.mouse_filter = Control.MOUSE_FILTER_STOP
	_card.custom_minimum_size = Vector2(CARD_W, 0)
	# ความสูงของการ์ดเปลี่ยนไปตามความยาวข้อความของแต่ละสเต็ป ต้องวางใหม่ทุกครั้งที่ขนาดเปลี่ยน
	# ไม่งั้นสเต็ปที่ข้อความยาวจะทะลุขอบล่างจอออกไป (ตอนแรกวางครั้งเดียวตอนที่ยังสูง 0)
	_card.resized.connect(_place_card)
	add_child(_card)

	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 14)
	_card.add_child(margin)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	margin.add_child(col)

	_title = Label.new()
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_title.add_theme_font_size_override("font_size", 17)
	_title.add_theme_color_override("font_color", GOLD)
	col.add_child(_title)

	_text = RichTextLabel.new()
	_text.bbcode_enabled = true
	_text.fit_content = true
	_text.custom_minimum_size = Vector2(CARD_W - 28, 0)
	_text.add_theme_font_size_override("normal_font_size", 13)
	_text.add_theme_font_size_override("bold_font_size", 13)
	col.add_child(_text)

	_wait = Label.new()
	_wait.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_wait.add_theme_font_size_override("font_size", 13)
	_wait.add_theme_color_override("font_color", WQPalette.TIME)
	col.add_child(_wait)

	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", 8)
	col.add_child(foot)

	_dots = Label.new()
	_dots.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_dots.add_theme_font_size_override("font_size", 12)
	_dots.add_theme_color_override("font_color", DIM)
	foot.add_child(_dots)

	_skip = Button.new()
	_skip.text = "ข้ามการสอน"
	_skip.pressed.connect(stop)
	foot.add_child(_skip)

	_next = Button.new()
	_next.text = "ถัดไป ▸"
	_next.pressed.connect(_on_next)
	foot.add_child(_next)


## ผูกกับหน้าจอจริง — `targets` คือ {คีย์: วิดเจ็ต} ที่สเต็ปอ้างถึง
func bind(player, match_ref: WQMatch, targets: Dictionary) -> void:
	_player = player
	_match = match_ref
	_targets = targets
	if _steps.is_empty(): _steps = _build_steps()


func start() -> void:
	step = 0
	running = true
	visible = true
	refresh()


## กลับมาสอนต่อจากสเต็ปเดิมหลังโหลดเกม — `saved < 0` แปลว่าเคยปิดการสอนไปแล้ว
func resume(saved: int) -> void:
	if saved < 0:
		stop()
		return
	step = clampi(saved, 0, _steps.size() - 1)
	running = true
	visible = true
	refresh()


func stop() -> void:
	running = false
	visible = false
	_unhook()
	finished.emit()


## ค่าที่เก็บลงไฟล์เซฟ — −1 = ปิดการสอนไปแล้ว
func save_state() -> int:
	return step if running else -1


func _on_next() -> void:
	step += 1
	if step >= _steps.size():
		stop()
		return
	refresh()


## เรียกทุกครั้งที่สถานะเกมเปลี่ยน — สเต็ปที่รอให้ลงมือทำจะข้ามเองเมื่อทำสำเร็จ
## และสเต็ปของเดือนที่ผ่านไปแล้วจะถูกข้ามให้ (ผู้เล่นเดินเร็วกว่าการสอนได้เสมอ)
func refresh() -> void:
	if not running or _player == null or _match == null: return

	# ข้ามสเต็ปของเดือนที่ผ่านไปแล้ว ยกเว้นสเต็ปที่รอให้ลงมือทำ (ของพวกนั้นต้องรอจริง)
	while step < _steps.size() - 1 and int(_steps[step].m) < _match.month \
			and not _steps[step].has("done"):
		step += 1
	var st: Dictionary = _steps[step]
	if st.has("done") and (st.done as Callable).call():
		step += 1
		if step >= _steps.size():
			stop()
			return
		refresh()
		return

	_title.text = String(st.t)
	_text.text = String(st.x)
	_wait.text = "▸ " + String(st.get("wait", ""))
	_wait.visible = st.has("done")
	_next.visible = not st.has("done")
	_next.text = "เริ่มเล่นเลย" if step == _steps.size() - 1 else "ถัดไป ▸"

	var dots := ""
	for i in _steps.size():
		dots += "●" if i <= step else "○"
	_dots.text = dots

	_point_at(String(st.get("target", "")))
	# ขนาดการ์ดเพิ่งเปลี่ยนตามข้อความสเต็ปใหม่ — วางตำแหน่งอีกทีตอนที่เลย์เอาต์นิ่งแล้ว
	_place_card.call_deferred()


## เลื่อนวิดเจ็ตเป้าหมายให้เห็น แล้ววางวงแหวนรอบมัน — ไม่มีเป้าหมายก็ซ่อนวงแหวนไปเลย
func _point_at(key: String) -> void:
	_unhook()
	var target: Control = _targets.get(key, null)
	if target == null or not is_instance_valid(target):
		_ring.visible = false
		_place_card()
		return

	# เลื่อนคอลัมน์ให้เห็นวิดเจ็ตก่อน — ของที่ถูกชี้แต่อยู่ใต้ขอบจอเท่ากับไม่ได้ชี้
	var scroll := _scroll_of(target)
	if scroll != null:
		var offset := target.global_position.y - scroll.global_position.y + scroll.scroll_vertical
		scroll.set_deferred("scroll_vertical", int(maxf(0.0, offset - 20.0)))

	# **ต้องเกาะ `item_rect_changed` ของวิดเจ็ตเอง** ไม่ใช่เกาะแถบสกรอลล์
	# เพราะตอนที่แถบสกรอลล์บอกว่าค่าเปลี่ยน ลูกๆ ของมันยังไม่ถูกจัดตำแหน่งใหม่
	# วงแหวนที่คำนวณตอนนั้นจะเพี้ยนไปเท่ากับระยะที่เพิ่งเลื่อน (เจอจริงตอนเขียนเทสต์)
	target.item_rect_changed.connect(_on_target_moved)
	_hooked = target
	_ring.visible = true
	_sync_ring(target)
	_sync_ring.call_deferred(target)
	_place_card()


func _sync_ring(target: Control) -> void:
	if not is_instance_valid(target) or not _ring.visible: return
	_ring.global_position = target.global_position - Vector2(RING_PAD, RING_PAD)
	_ring.size = target.size + Vector2(RING_PAD, RING_PAD) * 2.0
	_ring.queue_redraw()


func _on_target_moved() -> void:
	if _hooked != null: _sync_ring(_hooked)


func _unhook() -> void:
	if _hooked != null and is_instance_valid(_hooked) \
			and _hooked.item_rect_changed.is_connected(_on_target_moved):
		_hooked.item_rect_changed.disconnect(_on_target_moved)
	_hooked = null


## การ์ดอยู่มุมขวาล่างเสมอ (หนีบไม่ให้หลุดจอเมื่อข้อความยาว) — มุมนั้นเป็นคอลัมน์ "เกิดอะไรขึ้นแล้ว" ซึ่งเป็นของที่อ่านทีหลังได้
## ถ้าให้การ์ดลอยตามเป้าหมาย มันจะไปบังของที่กำลังชี้อยู่เองในหลายสเต็ป
func _place_card() -> void:
	if _placing: return
	_placing = true
	# **ต้องบีบขนาดการ์ดเองทุกครั้ง** — โหนดที่ไม่ได้อยู่ใน Container จะ "โตแล้วไม่ยอมหดกลับ"
	# ขนาดต่ำสุดเป็นแค่พื้น ไม่ใช่เพดาน สเต็ปที่ข้อความยาวจึงทิ้งการ์ดสูง 656 px ไว้ให้สเต็ปถัดไป
	# แล้วการ์ดจะไปโผล่กลางจอทั้งที่ข้อความสั้นนิดเดียว (เจอจริงตอนถ่ายภาพหน้าจอ)
	var h: float = _card.get_combined_minimum_size().y
	_card.size = Vector2(CARD_W, h)
	_card.position = Vector2(maxf(0.0, size.x - CARD_W - 16.0), maxf(0.0, size.y - h - 16.0))
	_placing = false


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and running: _place_card.call_deferred()


func _scroll_of(node: Node) -> ScrollContainer:
	var n := node.get_parent()
	while n != null:
		if n is ScrollContainer: return n
		n = n.get_parent()
	return null


## สเต็ปทั้งหมด — ข้อความชุดเดียวกับต้นแบบเว็บ ปรับให้ชี้ไปที่วิดเจ็ตจริงของฝั่ง Godot
## `m` = เดือนที่สเต็ปนี้ควรโผล่ · `done` = เงื่อนไขที่ทำให้ข้ามเอง (สเต็ปที่ให้ลงมือทำ)
func _build_steps() -> Array:
	var p = _player
	var mt := _match
	return [
		{"m": 1, "target": "time", "t": "นี่คือทรัพยากรจริงของเกม",
		"x": "หนึ่งเดือนมี [b]720 ชั่วโมง[/b] เท่ากันทุกอาชีพ แถบสีนี้บอกว่าชีวิตคุณหมดไปกับอะไร "
			+ "— นอน ทำงาน เดินทาง กินข้าว ธุระ\n\nส่วนที่เหลือคือเวลาที่คุณเอาไป"
			+ "[b]สร้างความมั่งคั่ง[/b]ได้จริง"},

		{"m": 1, "target": "time", "t": "เวลาว่างดิบ ≠ เวลาที่ใช้ได้จริง",
		"x": "ชั่วโมงว่างจะถูกคูณด้วย [b]ประสิทธิภาพ[/b] ซึ่งมาจากสุขภาพและการนอน\n\n"
			+ "สุขภาพ 90 ใช้เวลาได้ ~94% · สุขภาพ 40 เหลือ ~64% — "
			+ "[color=#e53935]สุขภาพตกแปลว่าชั่วโมงที่มีอยู่หายไปเฉยๆ[/color]"},

		{"m": 1, "target": "deals", "t": "ดูตัวเลขนี้ ไม่ใช่ราคา",
		"x": "ทุกการ์ดดีลบอก [color=#66bb6a]ผลตอบแทนต่อทุน %/เดือน[/color] ไว้ที่บรรทัดใหญ่\n\n"
			+ "ดีลราคาถูกไม่ได้แปลว่าดี และดีลแพงไม่ได้แปลว่าแย่ — เทียบที่ % เสมอ"},

		{"m": 1, "target": "city", "t": "ทุกอย่างมีที่ทางของมัน",
		"x": "นี่คือเมืองทั้งเมือง [b]คลิกอาคารเพื่อเดินทาง[/b] — และการเดินทาง"
			+ "[color=#e53935]กินเวลาจริง[/color]\n\nการวางลำดับว่าจะแวะที่ไหนก่อน "
			+ "คือเกมใหม่ที่ซ้อนอยู่บนเกมเดิม"},

		{"m": 1, "target": "shop", "t": "ของที่ซื้อเวลาคืนได้",
		"x": "ที่ [b]ห้างสรรพสินค้า[/b] มีของสองอย่างที่เปลี่ยนเกม:\n"
			+ "[b]รถ[/b] — ลดทั้งเวลาเดินทางและ[b]เวลาไปทำงานประจำ[/b] "
			+ "(ตัวหลังคือของจริง บางอาชีพประหยัดได้ 20–30 ชม./เดือน)\n"
			+ "[b]สมาร์ตโฟน[/b] — ทำธุรกรรมธนาคารจากที่ไหนก็ได้ ไม่ต้องเดินทางอีกเลย\n\n"
			+ "ทั้งคู่มีค่าใช้จ่ายรายเดือน — คำถามคือ 1 ชั่วโมงของคุณมีค่าเท่าไหร่"},

		{"m": 1, "target": "deals", "t": "ลองปิดดีลแรกของคุณ",
		"x": "เลือกการ์ดที่ปุ่มกดได้ (แปลว่าเงินและเวลาพอ) แล้วกด \"ปิดดีล\"\n\n"
			+ "เลือกอันที่ % ต่อทุนสูงที่สุดเท่าที่ซื้อไหว",
		"wait": "รอให้คุณปิดดีลแรก...", "done": func(): return p.assets.size() > 0},

		{"m": 1, "target": "hud", "t": "จบเดือนเมื่อพร้อม",
		"x": "ใช้เวลาที่เหลือให้คุ้มก่อน แล้วค่อยกด [b]จบตา[/b]\n\n"
			+ "ตอนสิ้นเดือนจะเกิด: ราคาตลาดขยับ → เงินเดือนเข้า → หักรายจ่าย → เหตุการณ์สุ่ม",
		"wait": "กด “จบตา” เพื่อไปเดือนถัดไป...", "done": func(): return mt.month > 1},

		{"m": 2, "target": "statement", "t": "นี่คือหัวใจของเกมทั้งหมด",
		"x": "[color=#4fc3f7]รายได้จากทรัพย์สิน[/color] คือเงินที่เข้ามาโดยคุณไม่ต้องทำงาน\n"
			+ "[color=#e53935]รวมรายจ่าย[/color] คือเงินที่ออกไปทุกเดือนไม่ว่าคุณจะทำอะไร\n\n"
			+ "ชนะด่านแรกเมื่อ [b]บรรทัดแรก ≥ บรรทัดที่สอง[/b] — แค่นั้นเลย"},

		{"m": 2, "target": "goal", "t": "ระวังกับดักข้อแรก",
		"x": "ดอกเบี้ยถูกนับเป็น[b]รายจ่าย[/b] แปลว่ายิ่งกู้เยอะ "
			+ "[color=#e53935]เส้นชัยยิ่งขยับหนี[/color]\n\n"
			+ "การกู้ช่วยให้โตเร็วขึ้นจริง แต่ก็ยกเป้าหมายสูงขึ้นพร้อมกัน — ความตึงตรงนี้คือเกมนี้"},

		{"m": 3, "target": "time", "t": "อาหารกับการนอนคือสองช่องที่ใหญ่ที่สุดในแถบ",
		"x": "ไม่มีตัวเลือกไหนดีทุกด้าน: [b]เดลิเวอรี[/b] เร็วสุดแต่แพงขึ้น 30% และสุขภาพลง · "
			+ "[b]สตรีทฟู้ด[/b] ทางสายกลาง · [b]ทำกินเอง[/b] ถูกสุดสุขภาพดีสุด "
			+ "แต่กิน 75 ชม./เดือน = ปิดดีลหายไป 3 ดีล\n\n"
			+ "การนอนก็มีเกณฑ์ของแต่ละอาชีพ นอนน้อยกว่าเกณฑ์โดนปรับ[b]สองชั้น[/b] "
			+ "ทั้งสุขภาพและประสิทธิภาพ\n\n"
			+ "ปุ่มเลือกอยู่ใต้แถบนี้เลย — [b]กดได้เฉพาะตอนอยู่ที่บ้าน[/b] "
			+ "แล้วดูแถบข้างบนขยับตาม"},

		{"m": 4, "target": "health", "t": "สุขภาพคือทรัพย์สินที่แพงที่สุด",
		"x": "สุขภาพไม่ใช่แค่ตัวเลขประดับ — มันคูณตรงเข้ากับเวลาที่คุณใช้ได้\n\n"
			+ "ต่ำกว่า 45 จะเจอเหตุการณ์เจ็บป่วยบ่อยขึ้นมาก และต่ำกว่า 25 "
			+ "มีโอกาสล้มป่วยหนักจนต้องหยุดงาน"},

		{"m": 4, "target": "actions", "t": "ป้องกันถูกกว่ารักษาเสมอ",
		"x": "แผง[b]ลงมือทำ[/b]นี้คือทุกอย่างที่คุณกดได้ — [b]ฟิตเนส[/b] เพิ่มสุขภาพ · "
			+ "[b]รีสอร์ต[/b] ลดโอกาสเกิดเรื่องร้ายในเดือนนั้น (ไปยืนที่นั่นแล้วจะเห็นทุกแพ็กเกจ)\n\n"
			+ "เทียบกับค่ารักษาตอนล้มป่วยที่แพงกว่ารายจ่ายทั้งเดือน 1–3 เท่า บวกเสียเวลาอีก 90 ชม."},

		{"m": 5, "target": "actions", "t": "กับดักสำคัญที่สุดของเกมนี้",
		"x": "[b]งานเสริม[/b] แลกเวลาเป็นเงิน[b]ก้อนเดียวจบ[/b]\n"
			+ "[b]ปิดดีล[/b] แลกเวลาเป็นเงิน[b]ทุกเดือนตลอดไป[/b]\n\n"
			+ "งานเสริมช่วยตอนเงินตึงจริง แต่ถ้าทำทุกเดือน คุณกำลังเอาเวลาไปแลกเงินซ้ำๆ "
			+ "แทนที่จะสร้างสิ่งที่จ่ายคุณเอง"},

		{"m": 5, "target": "standings", "t": "คู่แข่งแย่งดีลจริง",
		"x": "ทุกคนใช้[b]ตลาดเดียวกัน[/b] ดีลที่คุณลังเล คนอื่นคว้าไปได้จริงๆ\n\n"
			+ "แถบนี้บอกว่าแต่ละคนไปถึงกี่ % แล้ว — ใช้ดูว่าควรเร่งหรือควรระวัง"},

		{"m": 5, "target": "", "t": "จบการสอนแล้ว 🎉",
		"x": "สามอย่างที่อยากให้จำ:\n"
			+ "1. [color=#4fc3f7]เวลาคือคอขวดจริง[/color] ไม่ใช่เงิน\n"
			+ "2. [color=#4fc3f7]สุขภาพคือตัวคูณเวลา[/color] ปล่อยให้ตกแล้วทุกอย่างช้าลงหมด\n"
			+ "3. [color=#4fc3f7]ตัวเลขที่กำหนดชะตาคือสัดส่วน[/color] ไม่ใช่เงินเดือน\n\n"
			+ "ที่เหลือลองเองครับ — และอย่าลืมกด 💾 บันทึก ก่อนปิด"},
	]
