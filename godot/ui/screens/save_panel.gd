class_name WQSavePanel
extends Control
## 💾 หน้าบันทึก / 📂 หน้าโหลด — หกช่องตาม GDD 14.3
##
## สามช่องแรกผู้เล่นกดเอง สามช่องหลังเกมเขียนให้เองทุกสิ้นเดือน (autosave)
## **ผู้เล่นเขียนทับช่อง autosave เองไม่ได้** เพราะจุดเดียวที่ autosave มีค่าคือ "ของที่ไม่ได้ตั้งใจเก็บ"
## ถ้าผู้เล่นเซฟทับมันได้ ตาข่ายนิรภัยจะหายไปตอนที่ต้องการมันที่สุด — แต่โหลดได้ทุกช่อง
##
## ทุกแถวต้องบอกให้พอตัดสินใจได้โดยไม่ต้องโหลดดูก่อน: เดือนที่เท่าไหร่ · ใคร/อาชีพอะไร
## · ความมั่งคั่งสุทธิ · ด่านไหน · บันทึกเมื่อไหร่ — ข้อมูลทั้งหมดมาจากหัวไฟล์ (`WQSave.slot_info`)
## ซึ่งอ่านได้โดยไม่ต้องประกอบแมตช์ขึ้นมาทั้งตัว
##
## หน้าจอนี้ไม่เขียนและไม่โหลดไฟล์เอง — ยิงสัญญาณให้ `ui/main.gd` เป็นคนทำ
## (main เป็นคนเดียวที่รู้ว่าตอนนี้แมตช์ไหนกำลังเล่นอยู่ และต้องเอาแมตช์ที่โหลดมาผูกกับอะไรบ้าง)

signal save_requested(slot: String)
signal load_requested(slot: String)
signal closed

const DIM := Color("8fa6bd")
const GOLD := Color("f2b233")
const TH_MONTHS := ["ม.ค.", "ก.พ.", "มี.ค.", "เม.ย.", "พ.ค.", "มิ.ย.",
	"ก.ค.", "ส.ค.", "ก.ย.", "ต.ค.", "พ.ย.", "ธ.ค."]

var mode := "save"               ## "save" = เลือกช่องเพื่อเขียน · "load" = เลือกช่องเพื่อโหลด

var _title: Label
var _rows: VBoxContainer
var _note: Label


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
	center.add_child(panel)

	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 18)
	panel.add_child(margin)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	col.custom_minimum_size = Vector2(620, 0)
	margin.add_child(col)

	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 20)
	col.add_child(_title)

	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override("separation", 4)
	col.add_child(_rows)

	_note = Label.new()
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_note.add_theme_font_size_override("font_size", 12)
	_note.add_theme_color_override("font_color", DIM)
	col.add_child(_note)

	var close := Button.new()
	close.text = "ปิด (Esc)"
	close.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close.pressed.connect(func(): closed.emit())
	col.add_child(close)


## `has_match` = ตอนนี้มีเกมกำลังเล่นอยู่ไหม — ไม่มีก็เซฟไม่ได้ (หน้า setup เปิดหน้านี้เพื่อโหลดอย่างเดียว)
func open(new_mode: String, has_match := true) -> void:
	mode = new_mode
	_title.text = "💾 บันทึกเกม" if mode == "save" else "📂 โหลดเกม"
	_note.text = "ช่องอัตโนมัติเกมเขียนให้เองทุกสิ้นเดือน วนสามช่อง — โหลดได้ แต่เขียนทับเองไม่ได้" \
		if mode == "save" else "โหลดแล้วเกมจะเดินต่อจากจุดที่บันทึกไว้ รวมถึงสถานะตัวสุ่มด้วย"
	refresh(has_match)


func refresh(has_match := true) -> void:
	for c in _rows.get_children():
		_rows.remove_child(c)
		c.free()
	for slot in WQSave.MANUAL_SLOTS:
		_rows.add_child(_row(slot, "ช่อง %s" % slot, has_match))
	for i in WQSave.AUTO_SLOTS.size():
		_rows.add_child(_row(WQSave.AUTO_SLOTS[i], "อัตโนมัติ %d" % (i + 1), has_match))


func _row(slot: String, label: String, has_match: bool) -> Control:
	var info := WQSave.slot_info(slot)
	var empty: bool = info.get("empty", true)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)

	var name_label := Label.new()
	name_label.text = label
	name_label.custom_minimum_size = Vector2(110, 30)
	name_label.add_theme_color_override("font_color", GOLD if not empty else DIM)
	row.add_child(name_label)

	var desc := Label.new()
	desc.text = _describe(info)
	desc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	desc.add_theme_font_size_override("font_size", 13)
	desc.add_theme_color_override("font_color", Color.WHITE if not empty else DIM)
	row.add_child(desc)

	var btn := Button.new()
	btn.custom_minimum_size = Vector2(120, 30)
	if mode == "save":
		btn.text = "บันทึกทับ" if not empty else "บันทึก"
		# ช่อง autosave เป็นของเกม ห้ามให้ผู้เล่นเขียนทับ (เหตุผลอยู่หัวไฟล์)
		btn.disabled = WQSave.is_auto(slot) or not has_match
		btn.pressed.connect(func(): save_requested.emit(slot))
	else:
		btn.text = "โหลด"
		btn.disabled = empty or not bool(info.get("version_ok", false))
		btn.pressed.connect(func(): load_requested.emit(slot))
	row.add_child(btn)
	return row


func _describe(info: Dictionary) -> String:
	if info.get("empty", true):
		return "— ว่าง —" if not info.get("broken", false) else "— ไฟล์เสีย อ่านไม่ได้ —"
	if not bool(info.get("version_ok", false)):
		return "ไฟล์เซฟคนละเวอร์ชัน — โหลดไม่ได้"
	var phase: int = int(info.get("phase", 1))
	var stage := "ด่าน 1" if phase == 1 else ("ด่าน 2" if phase == 2 else "ทำความฝันสำเร็จ")
	# ไฟล์เซฟก่อนมี hot-seat ไม่มีช่อง humans — ของพวกนั้นคือเกมคนเดียวทั้งหมด
	var humans: int = int(info.get("humans", 1))
	var table := "" if humans <= 1 else "hot-seat %d คน · " % humans
	return "%sเดือนที่ %d · %s %s · สุทธิ %s฿ · %s · %s" % [
		table, int(info.get("month", 0)), String(info.get("job_icon", "")),
		String(info.get("job", "")), WQFmt.m(float(info.get("net_worth", 0))),
		stage, _when(int(info.get("saved_at", 0)))]


## เวลาแบบอ่านง่ายตามเขตเวลาของเครื่อง — `get_datetime_dict_from_unix_time` คืน UTC เสมอ
func _when(unix_time: int) -> String:
	if unix_time <= 0: return "ไม่ทราบเวลา"
	var bias: int = int(Time.get_time_zone_from_system().get("bias", 0)) * 60
	var d := Time.get_datetime_dict_from_unix_time(unix_time + bias)
	return "%d %s %02d:%02d" % [
		int(d.day), TH_MONTHS[clampi(int(d.month) - 1, 0, 11)], int(d.hour), int(d.minute)]


func _on_bg_input(e: InputEvent) -> void:
	# คลิกนอกกล่อง = ปิด (ทางออกที่คนหาโดยสัญชาตญาณก่อนจะไปหาปุ่มปิด)
	if e is InputEventMouseButton and (e as InputEventMouseButton).pressed:
		closed.emit()


func _unhandled_key_input(e: InputEvent) -> void:
	if e is InputEventKey and (e as InputEventKey).pressed \
			and (e as InputEventKey).keycode == KEY_ESCAPE:
		closed.emit()
		get_viewport().set_input_as_handled()
