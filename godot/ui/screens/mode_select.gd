class_name WQModeSelect
extends Control
## หน้าแรกของเกม — เลือกว่าเล่นกันกี่คนบนเครื่องเดียว (GDD บทที่ 10)
##
## ก่อนหน้านี้เกมเปิดมาเจอหน้าทอยเต๋าเลย จึงไม่มีที่ว่างให้ถามคำถามนี้ และ hot-seat
## ที่ GDD ติ๊กว่าเสร็จแล้วก็ไม่เคยมีทางเข้าในเกมจริงสักทาง
##
## หน้าจอนี้ไม่รู้จัก `WQMatch` เลย — ตอนที่มันอยู่บนจอ ยังไม่มีแมตช์ให้รู้จัก
## หน้าที่เดียวคือคืนตัวเลข "คนจริงกี่คน" ให้ `ui/main.gd` ไปตั้งโต๊ะเอง

signal chosen(human_count: int)
signal load_requested

const DIM := Color("8fa6bd")
const GOLD := Color("f2b233")

var buttons: Array[Button] = []
var hints: Array[Label] = []


func _init() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var bg := ColorRect.new()
	bg.color = WQPalette.BG_DEEP
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	col.custom_minimum_size = Vector2(520, 0)
	center.add_child(col)

	var title := Label.new()
	title.text = "WEALTH QUEST"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", GOLD)
	col.add_child(title)

	var sub := Label.new()
	sub.text = "เงิน · เวลา · สุขภาพ — สามอย่างที่ขัดกันเอง"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 14)
	sub.add_theme_color_override("font_color", DIM)
	col.add_child(sub)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 18)
	col.add_child(spacer)

	for n in range(1, WQSetup.SEATS + 1):
		col.add_child(_seat_row(n))

	# โผล่เฉพาะตอนที่มีไฟล์เซฟจริง — ปุ่มที่กดแล้วเจอรายการว่างเปล่าคือปุ่มที่ไม่ควรมี
	# (กฎเดียวกับปุ่มโหลดในหน้าทอยเต๋า)
	var load_btn := Button.new()
	load_btn.text = "📂 โหลดเกมที่บันทึกไว้"
	load_btn.custom_minimum_size = Vector2(300, 36)
	load_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	load_btn.visible = WQSave.has_any()
	load_btn.pressed.connect(func(): load_requested.emit())
	col.add_child(load_btn)


## หนึ่งแถว = ปุ่มเลือกที่นั่ง + บรรทัดบอกว่าที่เหลือเป็นบอทกี่ตัว
func _seat_row(n: int) -> Control:
	var row := VBoxContainer.new()
	row.add_theme_constant_override("separation", 1)

	var btn := Button.new()
	btn.text = "เล่นคนเดียว" if n == 1 else "เล่น %d คน — ผลัดกันบนเครื่องเดียว" % n
	btn.custom_minimum_size = Vector2(300, 42)
	btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	btn.pressed.connect(func(): chosen.emit(n))
	row.add_child(btn)
	buttons.append(btn)

	# จำนวนคนในโต๊ะเปลี่ยนเกมจริง — `WQMatch.refill_market()` ตั้งเป้าจำนวนดีลใน
	# ตลาดจาก `4 + จำนวนผู้เล่น` โต๊ะที่คนเยอะจึงมีของให้แย่งมากกว่าและแย่งกันหนักกว่า
	var bots: int = WQSetup.SEATS - n
	var hint := Label.new()
	if bots == 0:
		hint.text = "ไม่มีบอท — คนจริงเต็มโต๊ะ"
	elif n == 1:
		hint.text = "คุณ + บอท %d ตัว" % bots
	else:
		hint.text = "คนจริง %d คน + บอท %d ตัว" % [n, bots]
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 12)
	hint.add_theme_color_override("font_color", DIM)
	row.add_child(hint)
	hints.append(hint)
	return row
