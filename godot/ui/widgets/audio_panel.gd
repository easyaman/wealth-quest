class_name WQAudioPanel
extends Control
## แผงปรับเสียง — สไลเดอร์สองตัวกับปุ่มปิดเสียง ไม่มีอะไรมากกว่านั้น
##
## ค่าที่ขยับเขียนลงไฟล์ตั้งค่าทันที ไม่ต้องกดตกลง เพราะผู้เล่นปรับเสียงระหว่างที่เกม
## กำลังเล่นอยู่ ต้องได้ยินผลทันทีที่ลาก — ปุ่ม "ตกลง" จะทำให้ต้องลากแล้วกดแล้วฟัง
## แล้วลากใหม่ ซึ่งไม่มีใครทำ
##
## หน้าตาเดินตาม `ui/screens/save_panel.gd`: แผ่นคลุมเต็มจอ + พื้นหลังหรี่ + กล่องกลางจอ
## ตอนแรกทำเป็น PanelContainer ลอยๆ ตามแผน แล้วถ่ายภาพหน้าจอออกมาดู — กล่องโปร่งใสสนิท
## ตัวหนังสือของแผงข้างล่างทะลุขึ้นมาปนกันจนอ่านไม่ออกทั้งคู่ (ธีมของเกมนี้ไม่ได้ตั้ง StyleBox
## ให้ PanelContainer ไว้ ใครอยากมีพื้นหลังทึบต้องใส่เอง เหมือนที่การ์ดสอนทำ)

signal closed

var _master: HSlider
var _sfx: HSlider
var _mute: CheckBox
var _close: Button


func _init() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var bg := ColorRect.new()
	bg.color = Color(WQPalette.BG_DEEP, 0.94)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.gui_input.connect(_on_bg_input)
	add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	var box := StyleBoxFlat.new()
	box.bg_color = WQPalette.BG_DEEP
	box.border_color = WQPalette.MONEY
	box.set_border_width_all(1)
	box.set_corner_radius_all(4)
	panel.add_theme_stylebox_override("panel", box)
	center.add_child(panel)

	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 18)
	panel.add_child(margin)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	col.custom_minimum_size = Vector2(260, 0)
	margin.add_child(col)

	var title := Label.new()
	title.text = "🔊 เสียง"
	title.add_theme_font_size_override("font_size", 20)
	col.add_child(title)

	_master = _slider(col, "เสียงรวม", WQAudio.get_level("Master"))
	_master.value_changed.connect(func(v: float): WQAudio.set_level("Master", v))
	_sfx = _slider(col, "เอฟเฟกต์", WQAudio.get_level("SFX"))
	_sfx.value_changed.connect(func(v: float): WQAudio.set_level("SFX", v))

	_mute = CheckBox.new()
	_mute.text = "ปิดเสียงทั้งหมด"
	_mute.button_pressed = WQAudio.muted
	_mute.toggled.connect(func(on: bool): WQAudio.set_muted(on))
	col.add_child(_mute)

	_close = Button.new()
	_close.text = "ปิด"
	_close.pressed.connect(func(): WQAudio.ui("panel_close"); closed.emit())
	col.add_child(_close)


func _slider(col: VBoxContainer, label: String, value: float) -> HSlider:
	var l := Label.new()
	l.text = label
	l.add_theme_color_override("font_color", WQPalette.NEUTRAL_2)
	col.add_child(l)
	var s := HSlider.new()
	s.min_value = 0.0
	s.max_value = 1.0
	s.step = 0.05
	s.value = value
	s.custom_minimum_size.x = 200
	col.add_child(s)
	return s


func _on_bg_input(e: InputEvent) -> void:
	# คลิกนอกกล่อง = ปิด (ทางออกที่คนหาโดยสัญชาตญาณก่อนจะไปหาปุ่มปิด) — ท่าเดียวกับหน้าบันทึก
	if e is InputEventMouseButton and (e as InputEventMouseButton).pressed:
		closed.emit()


func _unhandled_key_input(e: InputEvent) -> void:
	if e is InputEventKey and (e as InputEventKey).pressed \
			and (e as InputEventKey).keycode == KEY_ESCAPE:
		closed.emit()
		get_viewport().set_input_as_handled()
