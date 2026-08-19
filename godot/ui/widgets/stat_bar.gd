class_name WQStatBar
extends VBoxContainer
## แถบสถิติมาตรฐานของทั้งเกม — หน้าตาตามรูปอ้างอิง ../IMG_3632.jpg
## (ป้ายชื่อบรรทัดบน · เส้นรางบางสีจาง · เส้นเติมหนากว่าทับจากซ้าย)
##
## ART-DIRECTION ข้อ 2.5: UI แบนสนิท ไม่มี gradient ไม่มีเงา — ให้ 3D เป็นคนมีมิติ
## ใช้ตัวเดียวกันทุกที่: งบเวลา · สุขภาพ · ผลตอบแทนดีล · สเปกพาหนะ · ความคืบหน้าความฝัน
## เพื่อให้ผู้เล่นเรียนรู้การอ่านแถบครั้งเดียวแล้วใช้ได้ทั้งเกม (GDD 1.1 ข้อ 5)
##
## ตัวเลขที่ใส่เข้ามาต้องมาจาก core เสมอ — วิดเจ็ตนี้ไม่คำนวณสูตรเกมเอง

const TRACK_COLOR := Color(1, 1, 1, 0.22)   ## เส้นรางบางๆ = "เต็มแถบคือแค่ไหน"
const LABEL_COLOR := Color(1, 1, 1, 0.86)
const VALUE_COLOR := Color(1, 1, 1, 0.86)
const TRACK_H := 2.0
const FILL_H := 4.0

var label_text := "" : set = _set_label
var value_text := "" : set = _set_value
var fill := 0.0 : set = _set_fill          ## 0..1 — เกิน 1 จะถูกหนีบ แต่ยังเปลี่ยนสีเตือนไม่ได้
var color := Color.WHITE : set = _set_color

var _label: Label
var _value: Label
var _line: _Line


func _init(label := "", value := "", frac := 0.0, c := Color.WHITE) -> void:
	add_theme_constant_override("separation", 2)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	add_child(head)

	_label = Label.new()
	_label.add_theme_font_size_override("font_size", 12)
	_label.add_theme_color_override("font_color", LABEL_COLOR)
	_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(_label)

	_value = Label.new()
	_value.add_theme_font_size_override("font_size", 12)
	_value.add_theme_color_override("font_color", VALUE_COLOR)
	_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	head.add_child(_value)

	_line = _Line.new()
	_line.custom_minimum_size = Vector2(0, FILL_H + 2.0)
	add_child(_line)

	label_text = label
	value_text = value
	fill = frac
	color = c


## ตั้งค่าทั้งแถบในครั้งเดียว — วาดใหม่รอบเดียว ไม่ใช่สี่รอบ
func set_stat(label: String, value: String, frac: float, c: Color) -> void:
	_label.text = label
	_value.text = value
	label_text = label
	value_text = value
	fill = frac
	color = c


## แปลงจาก dictionary ที่ Showcase ส่งมา: {label, value, max, color, text?}
## `text` มีไว้ให้ผู้เรียกจัดรูปแบบตัวเลขเอง (บาท/ชั่วโมง/%) — ถ้าไม่ส่งมาจะโชว์ตัวเลขดิบ
static func from_stat(d: Dictionary) -> WQStatBar:
	var mx := float(d.get("max", 1.0))
	var v := float(d.get("value", 0.0))
	var bar := WQStatBar.new(
		String(d.get("label", "")),
		String(d.get("text", str(snappedf(v, 0.01)))),
		(v / mx) if mx > 0.0 else 0.0,
		d.get("color", Color.WHITE))
	return bar


func _set_label(v: String) -> void:
	label_text = v
	if _label != null: _label.text = v

func _set_value(v: String) -> void:
	value_text = v
	if _value != null: _value.text = v

func _set_fill(v: float) -> void:
	fill = v
	if _line != null:
		_line.frac = clampf(v, 0.0, 1.0)
		_line.queue_redraw()

func _set_color(v: Color) -> void:
	color = v
	if _line != null:
		_line.fill_color = v
		_line.queue_redraw()


## เส้นรางบาง + เส้นเติมหนากว่า วางชิดขอบล่างทั้งคู่ ให้ฐานตรงกันเหมือนในรูปอ้างอิง
class _Line extends Control:
	var frac := 0.0
	var fill_color := Color.WHITE

	func _draw() -> void:
		var y := size.y - WQStatBar.FILL_H
		draw_rect(Rect2(0, y + (WQStatBar.FILL_H - WQStatBar.TRACK_H) * 0.5,
			size.x, WQStatBar.TRACK_H), WQStatBar.TRACK_COLOR)
		if frac > 0.0:
			draw_rect(Rect2(0, y, size.x * frac, WQStatBar.FILL_H), fill_color)
