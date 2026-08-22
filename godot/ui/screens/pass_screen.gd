class_name WQPassScreen
extends Control
## ม่านส่งเครื่องของโต๊ะ hot-seat (GDD บทที่ 10 — MULTIPLAYER hot-seat)
##
## หน้าที่เดียวของมันคือ **ไม่ให้คนอื่นเห็นจอของคนที่ถึงตา** เงินสด หนี้ และดีลที่ถืออยู่
## คือข้อมูลที่ตัดสินเกม ถ้าเห็นของคู่แข่งได้ตลอดเวลา การแย่งดีลในตลาดกลางก็ไม่เหลืออะไร
##
## จึงต้องทึบ 100% ไม่ใช่โปร่งแสงแบบหน้าทอยความฝัน — หน้านั้นตั้งใจให้เห็นเกมรางๆ
## ข้างหลังเพื่อบอกว่าเกมยังอยู่ตรงนั้น แต่หน้านี้มีไว้ปิดตาคนอื่นโดยเฉพาะ

signal ready_pressed

const DIM := Color("8fa6bd")
const GOLD := Color("f2b233")

var _icon: Label
var _name: Label
var _btn: Button


func _init() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var bg := ColorRect.new()
	bg.color = WQPalette.BG_DEEP          # ทึบสนิท — ดูคอมเมนต์หัวไฟล์
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	center.add_child(col)

	_icon = Label.new()
	_icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_icon.add_theme_font_size_override("font_size", 52)
	col.add_child(_icon)

	_name = Label.new()
	_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name.add_theme_font_size_override("font_size", 26)
	_name.add_theme_color_override("font_color", GOLD)
	col.add_child(_name)

	var sub := Label.new()
	sub.text = "ส่งเครื่องให้ผู้เล่นคนนี้ แล้วกดปุ่มเพื่อเริ่มตา"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 14)
	sub.add_theme_color_override("font_color", DIM)
	col.add_child(sub)

	_btn = Button.new()
	_btn.text = "พร้อมแล้ว เริ่มตาของฉัน"
	_btn.custom_minimum_size = Vector2(260, 44)
	_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_btn.pressed.connect(func(): ready_pressed.emit())
	col.add_child(_btn)


## บอกว่าม่านนี้กั้นให้ใคร — เรียกทุกครั้งที่เปิดม่าน
func show_player(p) -> void:
	_icon.text = String(p.job.get("icon", "🎲"))
	_name.text = "ตาของ %s" % String(p.pname)
